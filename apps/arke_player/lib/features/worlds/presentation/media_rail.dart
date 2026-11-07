import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';

import '../../../app/theme/tokens.dart';

const _fg = ArkeColors.mediaOverlayForeground;
const _bg = ArkeColors.mediaOverlayBackground;

/// A press on the rail over what plays (P23 rule 4, P24 rule 6): round glass with its word under it,
/// filled when on.
class RailPress extends StatelessWidget {
  const RailPress({required this.icon, required this.label, required this.onPressed, this.on = false, this.toggles = false, super.key});

  final IconData icon;
  final String label;
  final VoidCallback onPressed;
  final bool on;

  /// It stays as it is pressed, so a reader of the screen is told which way it is.
  final bool toggles;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    toggled: toggles ? on : null,
    label: label,
    child: ExcludeSemantics(
      child: GestureDetector(
        onTap: onPressed,
        behavior: HitTestBehavior.opaque,
        child: SizedBox(
          width: 60,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ClipOval(
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                  child: Container(
                    width: ArkeSizes.press,
                    height: ArkeSizes.press,
                    color: on ? _fg : _bg.withValues(alpha: 0.42),
                    child: Icon(icon, size: 21, color: on ? _bg : _fg),
                  ),
                ),
              ),
              const SizedBox(height: 3),
              Text(label, style: Theme.of(context).textTheme.labelSmall?.copyWith(color: _fg)),
            ],
          ),
        ),
      ),
    ),
  );
}

/// The thin line of a playing thing's time, over what plays.
class ThinLine extends StatelessWidget {
  const ThinLine({required this.value, super.key});

  final double value;

  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(ArkeRadius.pill),
    child: LinearProgressIndicator(value: value.clamp(0.0, 1.0), minHeight: 3, color: _fg, backgroundColor: _fg.withValues(alpha: 0.26)),
  );
}
