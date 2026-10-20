import 'package:flutter/painting.dart';

/// The Arke design tokens, as the design master draws with them (`design/tokens/*.css`, which mirror
/// ArkeStudio's). Change a value there first, then here.
///
/// The shelves — Home, Library, Downloads, You and the sheets over them — follow the phone's
/// light or dark. Heroes, picture cards and every player stay on the media overlay colours
/// whatever the theme (Arke Player P1 rule 9).
abstract final class ArkeColors {
  static const neutral50 = Color(0xFFFAFAFA);
  static const neutral100 = Color(0xFFF5F5F5);
  static const neutral200 = Color(0xFFE5E5E5);
  static const neutral300 = Color(0xFFD4D4D4);
  static const neutral400 = Color(0xFFA1A1A1);
  static const neutral500 = Color(0xFF737373);
  static const neutral600 = Color(0xFF525252);
  static const neutral700 = Color(0xFF404040);
  static const neutral800 = Color(0xFF262626);
  static const neutral900 = Color(0xFF171717);
  static const neutral950 = Color(0xFF0A0A0A);

  static const mediaOverlayBackground = neutral950;
  static const mediaOverlayForeground = neutral50;
  static const captionCurrentWord = Color(0xFFFFDF63);

  static const success = Color(0xFF16A34A);
  static const warning = Color(0xFFD97706);
}

/// The semantic colours of one theme. The neutral ramp never changes with the theme; only these do.
class ArkeSurface {
  const ArkeSurface({
    required this.background,
    required this.foreground,
    required this.card,
    required this.secondary,
    required this.mutedForeground,
    required this.border,
    required this.destructive,
  });

  final Color background;
  final Color foreground;
  final Color card;
  final Color secondary;
  final Color mutedForeground;
  final Color border;
  final Color destructive;

  static const light = ArkeSurface(
    background: Color(0xFFFFFFFF),
    foreground: ArkeColors.neutral950,
    card: Color(0xFFFFFFFF),
    secondary: ArkeColors.neutral100,
    mutedForeground: ArkeColors.neutral500,
    border: ArkeColors.neutral200,
    destructive: Color(0xFFE7000B),
  );

  static const dark = ArkeSurface(
    background: ArkeColors.neutral950,
    foreground: ArkeColors.neutral50,
    card: ArkeColors.neutral900,
    secondary: ArkeColors.neutral800,
    mutedForeground: ArkeColors.neutral400,
    border: Color(0xFF2A2A2A),
    destructive: Color(0xFFEF4444),
  );
}

/// The type scale (design turn 139): 11 · 12 · 13 · 14 · 15 · 18 · 20 · 24 · 30 · 36 · 48.
/// There is no size between these; a screen that needs one is drawn first.
abstract final class ArkeType {
  static const family = 'Geist Sans';
  static const wordmarkFamily = 'Jost';

  static const size2xs = 11.0;
  static const sizeXs = 12.0;
  static const sizeSm = 13.0;
  static const sizeBase = 14.0;
  static const sizeMd = 15.0;
  static const sizeLg = 18.0;
  static const sizeXl = 20.0;
  static const size2xl = 24.0;
  static const size3xl = 30.0;
  static const size4xl = 36.0;
  static const size5xl = 48.0;
}

/// Radii in the tokens' steps.
abstract final class ArkeRadius {
  static const sm = 6.0;
  static const md = 8.0;
  static const lg = 10.0;
  static const xl = 14.0;
  static const xxl = 18.0;
  static const pill = 999.0;
}

/// Sizes the design binds. Each names the rule it comes from.
abstract final class ArkeSizes {
  /// Every press is at least this high; a full-width press under the thumb is [widePress] (P1 rule 7).
  static const press = 44.0;
  static const widePress = 50.0;

  /// The dock above the tabs (P1 rule 8).
  static const dock = 60.0;

  /// The rail that replaces the tabs at [WindowBands.fold] and over (P6 rule 5).
  static const rail = 88.0;

  /// A player's chrome rests after this long while playing, and never while paused (Studio 156).
  static const chromeRest = Duration(milliseconds: 2500);
}

/// Width bands (P6 rule 5): under 600 a phone; 600 to 1099 a Fold or a tablet; 1100 and over wide.
abstract final class WindowBands {
  static const fold = 600.0;
  static const wide = 1100.0;
}
