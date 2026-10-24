/// The sleep choice (P5c): stop at the end of the chapter, or after a time.
enum SleepTimer {
  off('Off', null),
  endOfChapter('End of chapter', null),
  minutes15('15 min', Duration(minutes: 15)),
  minutes30('30 min', Duration(minutes: 30)),
  minutes60('60 min', Duration(minutes: 60));

  const SleepTimer(this.label, this.after);
  final String label;
  final Duration? after;
}

/// Caption size (P3e): a share of the picture's height, as the Studio's video captions use.
enum CaptionSize {
  small('S', 16),
  medium('M', 20),
  large('L', 26);

  const CaptionSize(this.label, this.points);
  final String label;
  final double points;
}

/// The reader's paper (P5e).
enum ReaderPaper {
  paper('Paper'),
  sepia('Sepia'),
  night('Night');

  const ReaderPaper(this.label);
  final String label;
}

/// Everything the device keeps (P6 rule 3, P8 rule 7). Nothing here is sent to an account or
/// written into a file.
class DeviceSettings {
  const DeviceSettings({
    this.captions = false,
    this.captionSize = CaptionSize.medium,
    this.speed = 1.0,
    this.sleep = SleepTimer.off,
    this.readerScale = 1.0,
    this.readerPaper = ReaderPaper.paper,
    this.seenFirstOpen = false,
    this.text = false,
    this.slowPush = true,
    this.autoplayNext = true,
    this.wifiOnly = true,
    this.adultContent = false,
    this.notify = const {},
  });

  /// Captions for films that carry them (a sidecar SRT or VTT). Off until turned on.
  final bool captions;
  final CaptionSize captionSize;

  /// Listening speed, 0.8× to 2× with the pitch kept (Studio 186).
  final double speed;
  final SleepTimer sleep;

  /// The reader's text size, as a multiple of the book's own, and its paper.
  final double readerScale;
  final ReaderPaper readerPaper;

  /// First open (P8a) has been passed; later opens land on Home.
  final bool seenFirstOpen;

  /// An illustrated narration's Text (off by default) and Slow push (on), kept on the device
  /// (SPEC-058 R-23, R-24).
  final bool text;
  final bool slowPush;

  // After the MVP (P8 rule 7): these return with the micro dramas, shares and adult-marked
  // productions they belong to. Kept here, with their designed defaults.
  final bool autoplayNext;
  final bool adultContent;

  /// Downloads only over Wi-Fi (P6b): a world's new chapters wait for it (SPEC-058 R-51).
  final bool wifiOnly;

  /// The worlds whose new chapters the phone tells of (SPEC-058 R-54, P15j): off until turned on.
  final Set<String> notify;

  DeviceSettings copyWith({
    bool? captions,
    CaptionSize? captionSize,
    double? speed,
    SleepTimer? sleep,
    double? readerScale,
    ReaderPaper? readerPaper,
    bool? seenFirstOpen,
    bool? text,
    bool? slowPush,
    bool? wifiOnly,
    Set<String>? notify,
  }) => DeviceSettings(
    captions: captions ?? this.captions,
    captionSize: captionSize ?? this.captionSize,
    speed: speed ?? this.speed,
    sleep: sleep ?? this.sleep,
    readerScale: readerScale ?? this.readerScale,
    readerPaper: readerPaper ?? this.readerPaper,
    seenFirstOpen: seenFirstOpen ?? this.seenFirstOpen,
    text: text ?? this.text,
    slowPush: slowPush ?? this.slowPush,
    autoplayNext: autoplayNext,
    wifiOnly: wifiOnly ?? this.wifiOnly,
    adultContent: adultContent,
    notify: notify ?? this.notify,
  );

  /// Slow push as it plays: the saved choice, unless the system asks for reduced motion.
  bool slowPushIn({required bool reducedMotion}) => slowPush && !reducedMotion;

  Map<String, Object> toPrefs() => {
    'captions': captions,
    'captionSize': captionSize.name,
    'speed': speed,
    'sleep': sleep.name,
    'readerScale': readerScale,
    'readerPaper': readerPaper.name,
    'seenFirstOpen': seenFirstOpen,
    'text': text,
    'slowPush': slowPush,
    'wifiOnly': wifiOnly,
    // World ids are slugs, so a comma never falls inside one.
    'notify': (notify.toList()..sort()).join(','),
  };

  static DeviceSettings fromPrefs(Object? Function(String key) read) {
    T pick<T extends Enum>(List<T> values, Object? name, T fallback) => values.where((value) => value.name == name).firstOrNull ?? fallback;
    final speed = read('speed');
    final scale = read('readerScale');
    return DeviceSettings(
      captions: read('captions') == true,
      captionSize: pick(CaptionSize.values, read('captionSize'), CaptionSize.medium),
      speed: speed is double ? speed.clamp(0.8, 2.0) : 1.0,
      sleep: pick(SleepTimer.values, read('sleep'), SleepTimer.off),
      readerScale: scale is double ? scale.clamp(0.7, 2.0) : 1.0,
      readerPaper: pick(ReaderPaper.values, read('readerPaper'), ReaderPaper.paper),
      seenFirstOpen: read('seenFirstOpen') == true,
      text: read('text') == true,
      slowPush: read('slowPush') != false,
      wifiOnly: read('wifiOnly') != false,
      notify: {
        for (final id in '${read('notify') ?? ''}'.split(','))
          if (id.isNotEmpty) id,
      },
    );
  }
}
