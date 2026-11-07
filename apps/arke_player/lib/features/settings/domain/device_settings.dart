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

/// The theme (P25 rule 8, call 51): dark on a new install whatever the phone's setting, until changed
/// in You. A hero, a picture card and every player stay on the media colours in either.
enum AppTheme {
  dark('Dark'),
  light('Light');

  const AppTheme(this.label);
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
    this.theme = AppTheme.dark,
    this.text = false,
    this.slowPush = true,
    this.autoplayNext = true,
    this.wifiOnly = true,
    this.adultContent = false,
    this.notify = const {},
    this.opened = const {},
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

  final AppTheme theme;

  /// An illustrated narration's Text (off by default) and Slow push (on), kept on the device
  /// (SPEC-058 R-23, R-24).
  final bool text;
  final bool slowPush;

  /// The next episode comes on its own at the end (P24 rule 4).
  final bool autoplayNext;

  /// Answered once: an 18+ world's Start, Play and Read ask no more on this device (P22e, call 42).
  final bool adultContent;

  /// Downloads only over Wi-Fi (P6b): a world's new chapters wait for it (SPEC-058 R-51).
  final bool wifiOnly;

  /// The worlds whose new chapters the phone tells of (SPEC-058 R-54, P15j): off until turned on.
  final Set<String> notify;

  /// The guide entries opened since they were found, as `world/entry`: the rest keep `New` (P23 rule 7).
  final Set<String> opened;

  DeviceSettings copyWith({
    bool? captions,
    CaptionSize? captionSize,
    double? speed,
    SleepTimer? sleep,
    double? readerScale,
    ReaderPaper? readerPaper,
    AppTheme? theme,
    bool? text,
    bool? slowPush,
    bool? autoplayNext,
    bool? wifiOnly,
    bool? adultContent,
    Set<String>? notify,
    Set<String>? opened,
  }) => DeviceSettings(
    captions: captions ?? this.captions,
    captionSize: captionSize ?? this.captionSize,
    speed: speed ?? this.speed,
    sleep: sleep ?? this.sleep,
    readerScale: readerScale ?? this.readerScale,
    readerPaper: readerPaper ?? this.readerPaper,
    theme: theme ?? this.theme,
    text: text ?? this.text,
    slowPush: slowPush ?? this.slowPush,
    autoplayNext: autoplayNext ?? this.autoplayNext,
    wifiOnly: wifiOnly ?? this.wifiOnly,
    adultContent: adultContent ?? this.adultContent,
    notify: notify ?? this.notify,
    opened: opened ?? this.opened,
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
    'theme': theme.name,
    'text': text,
    'slowPush': slowPush,
    'autoplayNext': autoplayNext,
    'wifiOnly': wifiOnly,
    'adultContent': adultContent,
    // World ids are slugs, so a comma never falls inside one.
    'notify': (notify.toList()..sort()).join(','),
    'opened': (opened.toList()..sort()).join(','),
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
      theme: pick(AppTheme.values, read('theme'), AppTheme.dark),
      text: read('text') == true,
      slowPush: read('slowPush') != false,
      autoplayNext: read('autoplayNext') != false,
      wifiOnly: read('wifiOnly') != false,
      adultContent: read('adultContent') == true,
      notify: {
        for (final id in '${read('notify') ?? ''}'.split(','))
          if (id.isNotEmpty) id,
      },
      opened: {
        for (final id in '${read('opened') ?? ''}'.split(','))
          if (id.isNotEmpty) id,
      },
    );
  }
}
