/// Everything You holds (Arke Player P6 rule 3). Every setting is this device's: nothing here is
/// sent to an account or written into a package.
class DeviceSettings {
  const DeviceSettings({
    this.captionsLanguage,
    this.text = false,
    this.slowPush = true,
    this.autoplayNext = true,
    this.wifiOnly = true,
    this.adultContent = false,
  });

  /// The captions language chosen once and applied to every production that carries it; null is
  /// Off (P3 rule 5).
  final String? captionsLanguage;

  /// The audiobook's two lines of words, off by default (Studio 186, 212).
  final bool text;

  /// On unless the system asks for reduced motion, which always wins (Studio 211).
  final bool slowPush;

  /// The next micro drama episode begins at the end of one (P3 rule 3).
  final bool autoplayNext;

  /// Downloads wait for Wi-Fi (P6 rule 1).
  final bool wifiOnly;

  /// Off until a person turns it on themselves, once, on this device (P6 rule 4).
  final bool adultContent;

  DeviceSettings copyWith({String? Function()? captionsLanguage, bool? text, bool? slowPush, bool? autoplayNext, bool? wifiOnly, bool? adultContent}) =>
      DeviceSettings(
        captionsLanguage: captionsLanguage != null ? captionsLanguage() : this.captionsLanguage,
        text: text ?? this.text,
        slowPush: slowPush ?? this.slowPush,
        autoplayNext: autoplayNext ?? this.autoplayNext,
        wifiOnly: wifiOnly ?? this.wifiOnly,
        adultContent: adultContent ?? this.adultContent,
      );

  /// Slow push as it plays: the saved choice, unless the system asks for reduced motion.
  bool slowPushIn({required bool reducedMotion}) => slowPush && !reducedMotion;
}
