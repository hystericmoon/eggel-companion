#ifndef RUNNER_MEDIA_CHANNEL_H_
#define RUNNER_MEDIA_CHANNEL_H_

#include <flutter/binary_messenger.h>

// Registers the "eggel/media" method channel: system volume (WASAPI) and the
// current media session (Windows SMTC) for play/pause/skip and now-playing.
void RegisterMediaChannel(flutter::BinaryMessenger* messenger);

#endif  // RUNNER_MEDIA_CHANNEL_H_
