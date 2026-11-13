#ifndef RUNNER_BLE_CHANNEL_H_
#define RUNNER_BLE_CHANNEL_H_

#include <flutter/binary_messenger.h>

// Registers the "eggel/ble" method channel: finds the Eggel Active 3 by its
// Tuya service (0xFD50), connects, subscribes to notifications and moves raw
// bytes. The protocol itself lives in Dart. All BLE work happens on a worker
// thread; Dart polls for events.
void RegisterBleChannel(flutter::BinaryMessenger* messenger);

#endif  // RUNNER_BLE_CHANNEL_H_
