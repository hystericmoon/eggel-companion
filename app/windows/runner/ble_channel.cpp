#include "ble_channel.h"

#include <winrt/Windows.Devices.Bluetooth.Advertisement.h>
#include <winrt/Windows.Devices.Bluetooth.GenericAttributeProfile.h>
#include <winrt/Windows.Devices.Bluetooth.h>
#include <winrt/Windows.Foundation.Collections.h>
#include <winrt/Windows.Foundation.h>
#include <winrt/Windows.Storage.Streams.h>
#include <winrt/base.h>

#include <flutter/method_channel.h>
#include <flutter/standard_method_codec.h>

#include <atomic>
#include <chrono>
#include <condition_variable>
#include <deque>
#include <memory>
#include <mutex>
#include <string>
#include <thread>
#include <vector>

namespace {

using namespace winrt;
using namespace winrt::Windows::Devices::Bluetooth;
using namespace winrt::Windows::Devices::Bluetooth::Advertisement;
using namespace winrt::Windows::Devices::Bluetooth::GenericAttributeProfile;
using namespace winrt::Windows::Storage::Streams;

// Tuya BLE characteristics on service 0xFD50.
const guid kWriteChar{0x00000001, 0x0000, 0x1001,
                      {0x80, 0x01, 0x00, 0x80, 0x5f, 0x9b, 0x07, 0xd0}};
const guid kNotifyChar{0x00000002, 0x0000, 0x1001,
                       {0x80, 0x01, 0x00, 0x80, 0x5f, 0x9b, 0x07, 0xd0}};

struct Event {
  std::string type;     // status | packetSize | data
  std::string state;    // status
  std::string message;  // status
  int value = 0;        // packetSize
  std::vector<uint8_t> data;
};

std::mutex g_mutex;
std::condition_variable g_cv;
std::deque<Event> g_events;
std::deque<std::vector<uint8_t>> g_writes;
std::atomic<bool> g_running{false};
std::atomic<bool> g_stop{false};
std::thread g_worker;

void Push(Event e) {
  std::lock_guard<std::mutex> lock(g_mutex);
  g_events.push_back(std::move(e));
}

void Status(const std::string& state, const std::string& message = "") {
  Event e;
  e.type = "status";
  e.state = state;
  e.message = message;
  Push(std::move(e));
}

// Waits for an advertisement carrying service 0xFD50 (or a name starting with
// "Eggel"); returns 0 on timeout.
uint64_t FindSpeaker(std::chrono::seconds timeout) {
  struct Shared {
    std::mutex m;
    std::condition_variable cv;
    uint64_t found = 0;
  };
  auto shared = std::make_shared<Shared>();
  BluetoothLEAdvertisementWatcher watcher;
  watcher.ScanningMode(BluetoothLEScanningMode::Active);
  const guid service = BluetoothUuidHelper::FromShortId(0xFD50);
  watcher.Received([shared, service](auto const&, BluetoothLEAdvertisementReceivedEventArgs const& a) {
    bool match = false;
    for (auto const& u : a.Advertisement().ServiceUuids()) {
      if (u == service) match = true;
    }
    const std::wstring name{a.Advertisement().LocalName()};
    if (name.rfind(L"Eggel", 0) == 0) match = true;
    if (match) {
      std::lock_guard<std::mutex> lock(shared->m);
      shared->found = a.BluetoothAddress();
      shared->cv.notify_all();
    }
  });
  watcher.Start();
  uint64_t found = 0;
  {
    std::unique_lock<std::mutex> lock(shared->m);
    // Wake periodically so a stop request is noticed.
    const auto deadline = std::chrono::steady_clock::now() + timeout;
    while (shared->found == 0 && !g_stop &&
           std::chrono::steady_clock::now() < deadline) {
      shared->cv.wait_for(lock, std::chrono::milliseconds(200));
    }
    found = shared->found;
  }
  watcher.Stop();
  return found;
}

void Run() {
  init_apartment(apartment_type::multi_threaded);
  try {
    Status("scanning", "Looking for the speaker");
    const uint64_t address = FindSpeaker(std::chrono::seconds(20));
    if (g_stop) return;
    if (address == 0) {
      Status("failed", "Speaker not found. It must be on and not connected to a phone.");
      return;
    }
    Status("connecting", "Connecting");
    auto device = BluetoothLEDevice::FromBluetoothAddressAsync(address).get();
    if (!device) {
      Status("failed", "Could not open the speaker");
      return;
    }
    // Ask Windows to keep the link up and tell us the negotiated size.
    GattSession session = GattSession::FromDeviceIdAsync(device.BluetoothDeviceId()).get();
    session.MaintainConnection(true);

    auto services = device.GetGattServicesForUuidAsync(
                              BluetoothUuidHelper::FromShortId(0xFD50),
                              BluetoothCacheMode::Uncached)
                        .get();
    if (services.Status() != GattCommunicationStatus::Success ||
        services.Services().Size() == 0) {
      Status("failed", "Speaker service not found");
      return;
    }
    auto service = services.Services().GetAt(0);
    auto writes = service.GetCharacteristicsForUuidAsync(kWriteChar, BluetoothCacheMode::Uncached).get();
    auto notifies = service.GetCharacteristicsForUuidAsync(kNotifyChar, BluetoothCacheMode::Uncached).get();
    if (writes.Characteristics().Size() == 0 || notifies.Characteristics().Size() == 0) {
      Status("failed", "Speaker characteristics not found");
      return;
    }
    GattCharacteristic write_char = writes.Characteristics().GetAt(0);
    GattCharacteristic notify_char = notifies.Characteristics().GetAt(0);

    notify_char.ValueChanged([](GattCharacteristic const&, GattValueChangedEventArgs const& a) {
      auto reader = DataReader::FromBuffer(a.CharacteristicValue());
      Event e;
      e.type = "data";
      e.data.resize(reader.UnconsumedBufferLength());
      if (!e.data.empty()) reader.ReadBytes(e.data);
      Push(std::move(e));
    });
    auto sub = notify_char
                   .WriteClientCharacteristicConfigurationDescriptorAsync(
                       GattClientCharacteristicConfigurationDescriptorValue::Notify)
                   .get();
    if (sub != GattCommunicationStatus::Success) {
      Status("failed", "Could not subscribe (the speaker may need a power cycle)");
      return;
    }
    auto lost = std::make_shared<std::atomic<bool>>(false);
    device.ConnectionStatusChanged([lost](BluetoothLEDevice const& d, auto const&) {
      if (d.ConnectionStatus() == BluetoothConnectionStatus::Disconnected) {
        *lost = true;
        g_cv.notify_all();
      }
    });

    Event ps;
    ps.type = "packetSize";
    ps.value = static_cast<int>(session.MaxPduSize()) - 3;
    if (ps.value < 20) ps.value = 20;
    Push(std::move(ps));
    Status("connected");

    while (!g_stop && !*lost) {
      std::vector<uint8_t> next;
      {
        std::unique_lock<std::mutex> lock(g_mutex);
        g_cv.wait_for(lock, std::chrono::milliseconds(250), [] {
          return !g_writes.empty() || g_stop.load();
        });
        if (!g_writes.empty()) {
          next = std::move(g_writes.front());
          g_writes.pop_front();
        }
      }
      if (next.empty()) continue;
      DataWriter w;
      w.WriteBytes(next);
      auto st = write_char.WriteValueAsync(w.DetachBuffer(), GattWriteOption::WriteWithoutResponse).get();
      if (st != GattCommunicationStatus::Success) {
        Status("failed", "Write failed");
        break;
      }
    }
    session.MaintainConnection(false);
    session.Close();
    device.Close();
    if (!g_stop) Status("disconnected", "Connection lost");
  } catch (hresult_error const& e) {
    Status("failed", winrt::to_string(e.message()));
  } catch (...) {
    Status("failed", "Unexpected Bluetooth error");
  }
}

void JoinWorker() {
  g_stop = true;
  g_cv.notify_all();
  if (g_worker.joinable()) g_worker.join();
}

void StartWorker() {
  JoinWorker();
  {
    std::lock_guard<std::mutex> lock(g_mutex);
    g_writes.clear();
  }
  g_stop = false;
  g_running = true;
  g_worker = std::thread([] {
    Run();
    g_running = false;
  });
}

flutter::EncodableValue ToValue(const Event& e) {
  flutter::EncodableMap m;
  m[flutter::EncodableValue("type")] = flutter::EncodableValue(e.type);
  if (e.type == "status") {
    m[flutter::EncodableValue("state")] = flutter::EncodableValue(e.state);
    m[flutter::EncodableValue("message")] = flutter::EncodableValue(e.message);
  } else if (e.type == "packetSize") {
    m[flutter::EncodableValue("value")] = flutter::EncodableValue(e.value);
  } else {
    m[flutter::EncodableValue("data")] = flutter::EncodableValue(e.data);
  }
  return flutter::EncodableValue(m);
}

}  // namespace

void RegisterBleChannel(flutter::BinaryMessenger* messenger) {
  auto channel = std::make_shared<flutter::MethodChannel<flutter::EncodableValue>>(
      messenger, "eggel/ble", &flutter::StandardMethodCodec::GetInstance());
  channel->SetMethodCallHandler(
      [](const flutter::MethodCall<flutter::EncodableValue>& call,
         std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
        const std::string& m = call.method_name();
        if (m == "connect") {
          if (!g_running) StartWorker();
          result->Success();
        } else if (m == "disconnect") {
          JoinWorker();
          result->Success();
        } else if (m == "write") {
          if (const auto* args = std::get_if<flutter::EncodableMap>(call.arguments())) {
            auto it = args->find(flutter::EncodableValue("data"));
            if (it != args->end()) {
              if (const auto* bytes = std::get_if<std::vector<uint8_t>>(&it->second)) {
                std::lock_guard<std::mutex> lock(g_mutex);
                g_writes.push_back(*bytes);
              }
            }
          }
          g_cv.notify_all();
          result->Success();
        } else if (m == "poll") {
          flutter::EncodableList list;
          {
            std::lock_guard<std::mutex> lock(g_mutex);
            for (const auto& e : g_events) list.push_back(ToValue(e));
            g_events.clear();
          }
          result->Success(flutter::EncodableValue(list));
        } else {
          result->NotImplemented();
        }
      });
  static std::shared_ptr<flutter::MethodChannel<flutter::EncodableValue>> keep;
  keep = channel;
}
