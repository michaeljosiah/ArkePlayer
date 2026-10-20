import 'package:flutter/material.dart';

import 'tokens.dart';

/// Builds the app's theme from the tokens. Monochrome on purpose: the creator's pictures carry
/// the colour, so the chrome never competes with them.
ThemeData arkeTheme(Brightness brightness) {
  final surface = brightness == Brightness.dark ? ArkeSurface.dark : ArkeSurface.light;
  final scheme = ColorScheme(
    brightness: brightness,
    primary: surface.foreground,
    onPrimary: surface.background,
    secondary: surface.secondary,
    onSecondary: surface.foreground,
    error: surface.destructive,
    onError: ArkeColors.neutral50,
    surface: surface.background,
    onSurface: surface.foreground,
    surfaceContainerHighest: surface.secondary,
    onSurfaceVariant: surface.mutedForeground,
    outline: surface.border,
  );

  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: surface.background,
    fontFamily: ArkeType.family,
    textTheme: const TextTheme(
      // The large title on a shelf (Home, Library, Downloads, You) and on a hero.
      headlineLarge: TextStyle(fontSize: ArkeType.size3xl, fontWeight: FontWeight.w700, height: 1.15, letterSpacing: -0.6),
      titleLarge: TextStyle(fontSize: ArkeType.size2xl, fontWeight: FontWeight.w600, height: 1.15),
      titleMedium: TextStyle(fontSize: ArkeType.sizeLg, fontWeight: FontWeight.w600, height: 1.3),
      bodyLarge: TextStyle(fontSize: ArkeType.sizeBase, height: 1.6),
      bodyMedium: TextStyle(fontSize: ArkeType.sizeSm, fontWeight: FontWeight.w500, height: 1.4),
      labelMedium: TextStyle(fontSize: ArkeType.sizeXs, fontWeight: FontWeight.w500, height: 1.2),
      labelSmall: TextStyle(fontSize: ArkeType.size2xs, height: 1.4),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: surface.background,
      indicatorColor: Colors.transparent,
      labelTextStyle: WidgetStatePropertyAll(TextStyle(fontSize: ArkeType.size2xs, fontWeight: FontWeight.w500, color: surface.foreground)),
    ),
    navigationRailTheme: NavigationRailThemeData(backgroundColor: surface.background, indicatorColor: surface.secondary, minWidth: ArkeSizes.rail),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size(ArkeSizes.press, ArkeSizes.press),
        shape: const StadiumBorder(),
        backgroundColor: surface.foreground,
        foregroundColor: surface.background,
      ),
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: surface.card,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(22))),
    ),
    dividerColor: surface.border,
  );
}
