package com.eggelcompanion.eggel_companion

import android.content.ComponentName
import android.content.Intent
import android.media.AudioDeviceInfo
import android.media.AudioManager
import android.media.session.MediaController
import android.media.session.MediaSessionManager
import android.media.session.PlaybackState
import android.provider.Settings
import android.view.KeyEvent
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import kotlin.math.roundToInt

class MainActivity : FlutterActivity() {
    private val audio by lazy { getSystemService(AUDIO_SERVICE) as AudioManager }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "eggel/media")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "getState" -> result.success(state())
                    "play" -> { send(KeyEvent.KEYCODE_MEDIA_PLAY) { it.play() }; result.success(null) }
                    "pause" -> { send(KeyEvent.KEYCODE_MEDIA_PAUSE) { it.pause() }; result.success(null) }
                    "next" -> { send(KeyEvent.KEYCODE_MEDIA_NEXT) { it.skipToNext() }; result.success(null) }
                    "previous" -> { send(KeyEvent.KEYCODE_MEDIA_PREVIOUS) { it.skipToPrevious() }; result.success(null) }
                    "setVolume" -> {
                        val pct = (call.argument<Double>("volume") ?: 0.0).coerceIn(0.0, 100.0)
                        val max = audio.getStreamMaxVolume(AudioManager.STREAM_MUSIC)
                        audio.setStreamVolume(AudioManager.STREAM_MUSIC, (pct * max / 100.0).roundToInt(), 0)
                        result.success(null)
                    }
                    "openAccessSettings" -> {
                        startActivity(Intent(Settings.ACTION_NOTIFICATION_LISTENER_SETTINGS))
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }
    }

    private fun hasListenerAccess(): Boolean {
        val enabled = Settings.Secure.getString(contentResolver, "enabled_notification_listeners") ?: return false
        return enabled.split(":").any { ComponentName.unflattenFromString(it)?.packageName == packageName }
    }

    /** The media session to talk to: a playing one if any, else the first. Null without access. */
    private fun controller(): MediaController? {
        if (!hasListenerAccess()) return null
        return try {
            val sessions = (getSystemService(MEDIA_SESSION_SERVICE) as MediaSessionManager)
                .getActiveSessions(ComponentName(this, MediaListenerService::class.java))
            sessions.firstOrNull { it.playbackState?.state == PlaybackState.STATE_PLAYING }
                ?: sessions.firstOrNull()
        } catch (e: SecurityException) {
            null
        }
    }

    /** Uses the session's transport controls when we can see one, else a plain media key. */
    private fun send(keyCode: Int, viaSession: (MediaController.TransportControls) -> Unit) {
        val c = controller()
        if (c != null) {
            viaSession(c.transportControls)
        } else {
            audio.dispatchMediaKeyEvent(KeyEvent(KeyEvent.ACTION_DOWN, keyCode))
            audio.dispatchMediaKeyEvent(KeyEvent(KeyEvent.ACTION_UP, keyCode))
        }
    }

    private fun state(): Map<String, Any?> {
        // 8 = A2DP, 26 = BLE headset, 27 = BLE speaker
        val btTypes = setOf(AudioDeviceInfo.TYPE_BLUETOOTH_A2DP, 26, 27)
        val device = audio.getDevices(AudioManager.GET_DEVICES_OUTPUTS).firstOrNull { it.type in btTypes }
        val max = audio.getStreamMaxVolume(AudioManager.STREAM_MUSIC).coerceAtLeast(1)
        val volume = (audio.getStreamVolume(AudioManager.STREAM_MUSIC) * 100.0 / max).roundToInt()
        val access = hasListenerAccess()
        val c = controller()
        val meta = c?.metadata
        return mapOf(
            "connected" to (device != null),
            "name" to (device?.productName?.toString() ?: ""),
            "volume" to volume,
            "mediaAccess" to access,
            "playing" to (c?.playbackState?.state?.let { it == PlaybackState.STATE_PLAYING } ?: audio.isMusicActive),
            "title" to (meta?.getString(android.media.MediaMetadata.METADATA_KEY_TITLE) ?: ""),
            "artist" to (meta?.getString(android.media.MediaMetadata.METADATA_KEY_ARTIST) ?: ""),
        )
    }
}
