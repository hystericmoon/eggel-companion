#include <initguid.h>

#include "media_channel.h"

#include <windows.h>
#include <propkeydef.h>
#include <propsys.h>
#include <audiopolicy.h>
#include <endpointvolume.h>
#include <functiondiscoverykeys_devpkey.h>
#include <mmdeviceapi.h>

#include <winrt/Windows.Foundation.h>
#include <winrt/Windows.Media.Control.h>
#include <winrt/base.h>

#include <flutter/method_channel.h>
#include <flutter/standard_method_codec.h>

#include <algorithm>
#include <atomic>
#include <chrono>
#include <memory>
#include <mutex>
#include <string>
#include <thread>

namespace {

using winrt::Windows::Media::Control::
    GlobalSystemMediaTransportControlsSession;
using winrt::Windows::Media::Control::
    GlobalSystemMediaTransportControlsSessionManager;
using winrt::Windows::Media::Control::
    GlobalSystemMediaTransportControlsSessionPlaybackStatus;

// ---- Media session snapshot, refreshed by a worker thread -----------------

struct Snapshot {
  bool has_session = false;
  bool playing = false;
  std::string title;
  std::string artist;
};

std::mutex g_mutex;
Snapshot g_snapshot;
GlobalSystemMediaTransportControlsSession g_session{nullptr};
std::once_flag g_worker_started;

void MediaWorker() {
  winrt::init_apartment(winrt::apartment_type::multi_threaded);
  GlobalSystemMediaTransportControlsSessionManager manager{nullptr};
  try {
    manager = GlobalSystemMediaTransportControlsSessionManager::RequestAsync()
                  .get();
  } catch (...) {
  }
  for (;;) {
    Snapshot snap;
    GlobalSystemMediaTransportControlsSession session{nullptr};
    try {
      if (manager) {
        session = manager.GetCurrentSession();
        if (session) {
          snap.has_session = true;
          snap.playing = session.GetPlaybackInfo().PlaybackStatus() ==
                         GlobalSystemMediaTransportControlsSessionPlaybackStatus::
                             Playing;
          auto props = session.TryGetMediaPropertiesAsync().get();
          snap.title = winrt::to_string(props.Title());
          snap.artist = winrt::to_string(props.Artist());
        }
      }
    } catch (...) {
    }
    {
      std::lock_guard<std::mutex> lock(g_mutex);
      g_snapshot = snap;
      g_session = session;
    }
    std::this_thread::sleep_for(std::chrono::milliseconds(700));
  }
}

void StartWorker() {
  std::call_once(g_worker_started, [] { std::thread(MediaWorker).detach(); });
}

// Sends a media key as a fallback when no media session is visible.
void SendMediaKey(WORD vk) {
  INPUT in[2] = {};
  in[0].type = INPUT_KEYBOARD;
  in[0].ki.wVk = vk;
  in[1].type = INPUT_KEYBOARD;
  in[1].ki.wVk = vk;
  in[1].ki.dwFlags = KEYEVENTF_KEYUP;
  SendInput(2, in, sizeof(INPUT));
}

enum class Command { kPlay, kPause, kNext, kPrevious };

void RunCommand(Command cmd) {
  GlobalSystemMediaTransportControlsSession session{nullptr};
  {
    std::lock_guard<std::mutex> lock(g_mutex);
    session = g_session;
  }
  if (session) {
    try {
      switch (cmd) {
        case Command::kPlay: session.TryPlayAsync(); return;
        case Command::kPause: session.TryPauseAsync(); return;
        case Command::kNext: session.TrySkipNextAsync(); return;
        case Command::kPrevious: session.TrySkipPreviousAsync(); return;
      }
    } catch (...) {
    }
  }
  switch (cmd) {
    case Command::kPlay:
    case Command::kPause: SendMediaKey(VK_MEDIA_PLAY_PAUSE); break;
    case Command::kNext: SendMediaKey(VK_MEDIA_NEXT_TRACK); break;
    case Command::kPrevious: SendMediaKey(VK_MEDIA_PREV_TRACK); break;
  }
}

// ---- System volume of the default output device (WASAPI) ------------------

struct Output {
  bool ok = false;
  std::string name;
  double percent = 0;  // 0..100, full precision
  UINT steps = 0;      // how many hardware steps the endpoint exposes
  double session_min = 1;  // lowest per-app volume (0..1) among other apps
  double session_max = 1;  // highest; differs from min when a new app started
};

winrt::com_ptr<IAudioEndpointVolume> OpenEndpoint(std::string* name) {
  winrt::com_ptr<IMMDeviceEnumerator> enumerator;
  if (FAILED(CoCreateInstance(__uuidof(MMDeviceEnumerator), nullptr, CLSCTX_ALL,
                              IID_PPV_ARGS(enumerator.put())))) {
    return nullptr;
  }
  winrt::com_ptr<IMMDevice> device;
  if (FAILED(enumerator->GetDefaultAudioEndpoint(eRender, eMultimedia,
                                                 device.put()))) {
    return nullptr;
  }
  if (name) {
    winrt::com_ptr<IPropertyStore> store;
    if (SUCCEEDED(device->OpenPropertyStore(STGM_READ, store.put()))) {
      PROPVARIANT pv;
      PropVariantInit(&pv);
      if (SUCCEEDED(store->GetValue(PKEY_Device_FriendlyName, &pv)) &&
          pv.vt == VT_LPWSTR && pv.pwszVal) {
        *name = winrt::to_string(pv.pwszVal);
      }
      PropVariantClear(&pv);
    }
  }
  winrt::com_ptr<IAudioEndpointVolume> endpoint;
  if (FAILED(device->Activate(__uuidof(IAudioEndpointVolume), CLSCTX_ALL,
                              nullptr, endpoint.put_void()))) {
    return nullptr;
  }
  return endpoint;
}

// Per-app ("session") volume on the default output, for every app but this
// one. This is how we go quieter than the output's lowest hardware step.
winrt::com_ptr<IAudioSessionEnumerator> OpenSessions() {
  winrt::com_ptr<IMMDeviceEnumerator> enumerator;
  if (FAILED(CoCreateInstance(__uuidof(MMDeviceEnumerator), nullptr, CLSCTX_ALL,
                              IID_PPV_ARGS(enumerator.put())))) {
    return nullptr;
  }
  winrt::com_ptr<IMMDevice> device;
  if (FAILED(enumerator->GetDefaultAudioEndpoint(eRender, eMultimedia,
                                                 device.put()))) {
    return nullptr;
  }
  winrt::com_ptr<IAudioSessionManager2> manager;
  if (FAILED(device->Activate(__uuidof(IAudioSessionManager2), CLSCTX_ALL,
                              nullptr, manager.put_void()))) {
    return nullptr;
  }
  winrt::com_ptr<IAudioSessionEnumerator> sessions;
  if (FAILED(manager->GetSessionEnumerator(sessions.put()))) return nullptr;
  return sessions;
}

// Calls fn(ISimpleAudioVolume&) for each other app's session.
template <typename Fn>
void ForEachSession(Fn fn) {
  auto sessions = OpenSessions();
  if (!sessions) return;
  int count = 0;
  if (FAILED(sessions->GetCount(&count))) return;
  for (int i = 0; i < count; ++i) {
    winrt::com_ptr<IAudioSessionControl> control;
    if (FAILED(sessions->GetSession(i, control.put()))) continue;
    auto control2 = control.try_as<IAudioSessionControl2>();
    if (!control2) continue;
    DWORD pid = 0;
    control2->GetProcessId(&pid);
    if (pid == GetCurrentProcessId()) continue;
    if (control2->IsSystemSoundsSession() == S_OK) continue;
    auto volume = control.try_as<ISimpleAudioVolume>();
    if (volume) fn(*volume);
  }
}

void ReadSessionScale(double* lo, double* hi) {
  *lo = 1;
  *hi = 1;
  bool first = true;
  ForEachSession([&](ISimpleAudioVolume& v) {
    float scalar = 1;
    if (FAILED(v.GetMasterVolume(&scalar))) return;
    if (first) {
      *lo = *hi = scalar;
      first = false;
    } else {
      *lo = std::min<double>(*lo, scalar);
      *hi = std::max<double>(*hi, scalar);
    }
  });
}

void WriteSessionScale(double scale) {
  const float s = static_cast<float>(std::clamp(scale, 0.0, 1.0));
  ForEachSession([&](ISimpleAudioVolume& v) {
    v.SetMasterVolume(s, nullptr);
  });
}

Output ReadOutput() {
  Output out;
  auto endpoint = OpenEndpoint(&out.name);
  if (!endpoint) return out;
  float scalar = 0;
  if (FAILED(endpoint->GetMasterVolumeLevelScalar(&scalar))) return out;
  UINT step = 0;
  endpoint->GetVolumeStepInfo(&step, &out.steps);
  BOOL muted = FALSE;
  endpoint->GetMute(&muted);
  out.percent = muted ? 0.0 : static_cast<double>(scalar) * 100.0;
  ReadSessionScale(&out.session_min, &out.session_max);
  out.ok = true;
  return out;
}

void WriteVolume(double percent) {
  auto endpoint = OpenEndpoint(nullptr);
  if (!endpoint) return;
  const float scalar =
      static_cast<float>(std::clamp(percent, 0.0, 100.0) / 100.0);
  if (scalar > 0) endpoint->SetMute(FALSE, nullptr);
  endpoint->SetMasterVolumeLevelScalar(scalar, nullptr);
}

}  // namespace

void RegisterMediaChannel(flutter::BinaryMessenger* messenger) {
  StartWorker();
  auto channel = std::make_shared<flutter::MethodChannel<flutter::EncodableValue>>(
      messenger, "eggel/media", &flutter::StandardMethodCodec::GetInstance());
  channel->SetMethodCallHandler(
      [](const flutter::MethodCall<flutter::EncodableValue>& call,
         std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
        const std::string& m = call.method_name();
        if (m == "getState") {
          const Output out = ReadOutput();
          Snapshot snap;
          {
            std::lock_guard<std::mutex> lock(g_mutex);
            snap = g_snapshot;
          }
          flutter::EncodableMap map;
          map[flutter::EncodableValue("connected")] = flutter::EncodableValue(out.ok);
          map[flutter::EncodableValue("name")] = flutter::EncodableValue(out.name);
          map[flutter::EncodableValue("volume")] = flutter::EncodableValue(out.percent);
          map[flutter::EncodableValue("steps")] =
              flutter::EncodableValue(static_cast<int>(out.steps));
          map[flutter::EncodableValue("sessionMin")] =
              flutter::EncodableValue(out.session_min);
          map[flutter::EncodableValue("sessionMax")] =
              flutter::EncodableValue(out.session_max);
          map[flutter::EncodableValue("playing")] = flutter::EncodableValue(snap.playing);
          map[flutter::EncodableValue("title")] = flutter::EncodableValue(snap.title);
          map[flutter::EncodableValue("artist")] = flutter::EncodableValue(snap.artist);
          map[flutter::EncodableValue("mediaAccess")] = flutter::EncodableValue(true);
          result->Success(flutter::EncodableValue(map));
        } else if (m == "play") {
          RunCommand(Command::kPlay);
          result->Success();
        } else if (m == "pause") {
          RunCommand(Command::kPause);
          result->Success();
        } else if (m == "next") {
          RunCommand(Command::kNext);
          result->Success();
        } else if (m == "previous") {
          RunCommand(Command::kPrevious);
          result->Success();
        } else if (m == "setVolume") {
          double pct = 0;
          double scale = 1;
          if (const auto* args = std::get_if<flutter::EncodableMap>(call.arguments())) {
            auto it = args->find(flutter::EncodableValue("volume"));
            if (it != args->end()) {
              if (const auto* d = std::get_if<double>(&it->second)) pct = *d;
              if (const auto* i = std::get_if<int32_t>(&it->second)) pct = *i;
            }
            auto sc = args->find(flutter::EncodableValue("sessionScale"));
            if (sc != args->end()) {
              if (const auto* d = std::get_if<double>(&sc->second)) scale = *d;
              if (const auto* i = std::get_if<int32_t>(&sc->second)) scale = *i;
            }
          }
          WriteVolume(pct);
          WriteSessionScale(scale);
          result->Success();
        } else {
          result->NotImplemented();
        }
      });
  // Keep the channel alive for the life of the process.
  static std::shared_ptr<flutter::MethodChannel<flutter::EncodableValue>> keep;
  keep = channel;
}
