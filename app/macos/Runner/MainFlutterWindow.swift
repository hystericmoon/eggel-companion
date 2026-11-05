import Cocoa
import CoreAudio
import FlutterMacOS

class MainFlutterWindow: NSWindow {
  private var media: MediaChannel?

  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    let windowFrame = self.frame
    self.contentViewController = flutterViewController
    self.setFrame(windowFrame, display: true)

    RegisterGeneratedPlugins(registry: flutterViewController)
    media = MediaChannel(messenger: flutterViewController.engine.binaryMessenger)

    super.awakeFromNib()
  }
}

/// The "eggel/media" channel on macOS (same contract as Android and Windows):
/// default-output volume through CoreAudio, now-playing and transport through
/// the private MediaRemote framework, with media-key events as a fallback.
///
/// Kept in this file so it is compiled without editing the Xcode project.
final class MediaChannel {
  private let channel: FlutterMethodChannel
  private var timer: Timer?

  // Snapshot of the system now-playing session, refreshed by `timer`.
  private var title = ""
  private var artist = ""
  private var playing = false

  // MediaRemote (private, loaded at run time; may be missing or restricted).
  private typealias InfoFn = @convention(c) (
    DispatchQueue, @escaping @convention(block) (CFDictionary?) -> Void
  ) -> Void
  private typealias PlayingFn = @convention(c) (
    DispatchQueue, @escaping @convention(block) (Bool) -> Void
  ) -> Void
  private typealias SendFn = @convention(c) (UInt32, CFDictionary?) -> Bool

  private var getInfo: InfoFn?
  private var getPlaying: PlayingFn?
  private var sendCommand: SendFn?

  init(messenger: FlutterBinaryMessenger) {
    channel = FlutterMethodChannel(name: "eggel/media", binaryMessenger: messenger)
    loadMediaRemote()
    channel.setMethodCallHandler { [weak self] call, result in
      self?.handle(call, result)
    }
    refreshNowPlaying()
    timer = Timer.scheduledTimer(withTimeInterval: 0.7, repeats: true) { [weak self] _ in
      self?.refreshNowPlaying()
    }
  }

  deinit { timer?.invalidate() }

  // MARK: Channel

  private func handle(_ call: FlutterMethodCall, _ result: @escaping FlutterResult) {
    switch call.method {
    case "getState":
      let out = readOutput()
      result([
        "connected": out.ok,
        "name": out.name,
        "volume": out.percent,
        "steps": 0,
        "playing": playing,
        "title": title,
        "artist": artist,
        // Nothing to grant on macOS; title/artist are simply empty if the
        // system refuses to share them.
        "mediaAccess": true,
      ])
    case "play": send(command: 0, key: 16); result(nil)
    case "pause": send(command: 1, key: 16); result(nil)
    case "next": send(command: 4, key: 17); result(nil)
    case "previous": send(command: 5, key: 18); result(nil)
    case "setVolume":
      let args = call.arguments as? [String: Any]
      let pct = (args?["volume"] as? NSNumber)?.doubleValue ?? 0
      writeVolume(pct)
      result(nil)
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  // MARK: Now playing and transport

  private func loadMediaRemote() {
    let path = "/System/Library/PrivateFrameworks/MediaRemote.framework/MediaRemote"
    guard let handle = dlopen(path, RTLD_LAZY) else { return }
    if let s = dlsym(handle, "MRMediaRemoteGetNowPlayingInfo") {
      getInfo = unsafeBitCast(s, to: InfoFn.self)
    }
    if let s = dlsym(handle, "MRMediaRemoteGetNowPlayingApplicationIsPlaying") {
      getPlaying = unsafeBitCast(s, to: PlayingFn.self)
    }
    if let s = dlsym(handle, "MRMediaRemoteSendCommand") {
      sendCommand = unsafeBitCast(s, to: SendFn.self)
    }
  }

  private func refreshNowPlaying() {
    getInfo?(DispatchQueue.main) { [weak self] info in
      let d = info as? [String: Any]
      self?.title = d?["kMRMediaRemoteNowPlayingInfoTitle"] as? String ?? ""
      self?.artist = d?["kMRMediaRemoteNowPlayingInfoArtist"] as? String ?? ""
    }
    getPlaying?(DispatchQueue.main) { [weak self] isPlaying in
      self?.playing = isPlaying
    }
  }

  /// MediaRemote command first; if it is unavailable or refuses, post the
  /// equivalent media key (16 play/pause, 17 next, 18 previous).
  private func send(command: UInt32, key: Int) {
    if let send = sendCommand, send(command, nil) { return }
    postMediaKey(key)
  }

  private func postMediaKey(_ key: Int) {
    for down in [true, false] {
      let state = down ? 0xA : 0xB
      let event = NSEvent.otherEvent(
        with: .systemDefined,
        location: .zero,
        modifierFlags: NSEvent.ModifierFlags(rawValue: UInt(state << 8)),
        timestamp: 0,
        windowNumber: 0,
        context: nil,
        subtype: 8,
        data1: (key << 16) | (state << 8),
        data2: -1)
      event?.cgEvent?.post(tap: .cghidEventTap)
    }
  }

  // MARK: Volume of the default output device (CoreAudio)

  private struct Output {
    var ok = false
    var name = ""
    var percent = 0.0
  }

  private func defaultOutputDevice() -> AudioObjectID? {
    var id = AudioObjectID(0)
    var size = UInt32(MemoryLayout<AudioObjectID>.size)
    var addr = AudioObjectPropertyAddress(
      mSelector: kAudioHardwarePropertyDefaultOutputDevice,
      mScope: kAudioObjectPropertyScopeGlobal,
      mElement: kAudioObjectPropertyElementMain)
    let st = AudioObjectGetPropertyData(
      AudioObjectID(kAudioObjectSystemObject), &addr, 0, nil, &size, &id)
    return (st == noErr && id != 0) ? id : nil
  }

  // 'vmvc': the device's virtual main volume, which also works for devices
  // that have no per-channel volume controls.
  private let virtualMainVolume = AudioObjectPropertySelector(0x766D_7663)

  private func volumeAddress() -> AudioObjectPropertyAddress {
    AudioObjectPropertyAddress(
      mSelector: virtualMainVolume,
      mScope: kAudioDevicePropertyScopeOutput,
      mElement: kAudioObjectPropertyElementMain)
  }

  private func readOutput() -> Output {
    var out = Output()
    guard let dev = defaultOutputDevice() else { return out }

    var nameAddr = AudioObjectPropertyAddress(
      mSelector: kAudioObjectPropertyName,
      mScope: kAudioObjectPropertyScopeGlobal,
      mElement: kAudioObjectPropertyElementMain)
    var name: Unmanaged<CFString>?
    var nameSize = UInt32(MemoryLayout<Unmanaged<CFString>?>.size)
    if AudioObjectGetPropertyData(dev, &nameAddr, 0, nil, &nameSize, &name) == noErr,
      let n = name?.takeRetainedValue()
    {
      out.name = n as String
    }

    var addr = volumeAddress()
    var scalar = Float32(0)
    var size = UInt32(MemoryLayout<Float32>.size)
    guard AudioObjectGetPropertyData(dev, &addr, 0, nil, &size, &scalar) == noErr else {
      return out
    }
    out.percent = Double(scalar) * 100.0
    out.ok = true
    return out
  }

  private func writeVolume(_ percent: Double) {
    guard let dev = defaultOutputDevice() else { return }
    var addr = volumeAddress()
    var scalar = Float32(min(max(percent, 0), 100) / 100.0)
    AudioObjectSetPropertyData(
      dev, &addr, 0, nil, UInt32(MemoryLayout<Float32>.size), &scalar)
  }
}
