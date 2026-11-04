/// What the app knows about the speaker right now.
class SpeakerState {
  const SpeakerState({
    this.connected = false,
    this.name = 'Active 3',
    this.playing = false,
    this.volume = 0,
    this.title = '',
    this.artist = '',
    this.mediaAccess = true,
  });

  /// False when the OS hasn't let the app read now-playing info yet.
  final bool mediaAccess;
  final bool connected;
  final String name;
  final bool playing;

  /// 0 to 100, fractional values allowed.
  final double volume;
  final String title;
  final String artist;

  SpeakerState copyWith({
    bool? connected,
    String? name,
    bool? playing,
    double? volume,
    String? title,
    String? artist,
    bool? mediaAccess,
  }) {
    return SpeakerState(
      connected: connected ?? this.connected,
      name: name ?? this.name,
      playing: playing ?? this.playing,
      volume: volume ?? this.volume,
      title: title ?? this.title,
      artist: artist ?? this.artist,
      mediaAccess: mediaAccess ?? this.mediaAccess,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is SpeakerState &&
      other.connected == connected &&
      other.name == name &&
      other.playing == playing &&
      other.volume == volume &&
      other.title == title &&
      other.artist == artist &&
      other.mediaAccess == mediaAccess;

  @override
  int get hashCode =>
      Object.hash(connected, name, playing, volume, title, artist, mediaAccess);
}

/// The app talks to the speaker only through this interface.
///
/// Today only media controls and volume exist. EQ, rename and TWS are added
/// once the control protocol is known (see docs/protocol.md).
abstract class Speaker {
  SpeakerState get state;
  Stream<SpeakerState> get states;

  Future<void> play();
  Future<void> pause();
  Future<void> next();
  Future<void> previous();

  /// Percent, clamped to 0..100. Fractions are used where the OS supports them.
  Future<void> setVolume(double volume);

  /// Shape of the volume slider; see `sliderToPercent`.
  double get volumeExponent;

  /// Opens the OS screen where the user grants now-playing access.
  Future<void> requestMediaAccess();

  void dispose();
}
