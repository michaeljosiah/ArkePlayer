import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/tokens.dart';
import '../../../app/widgets/shelf.dart';
import '../application/settings_controller.dart';
import '../domain/device_settings.dart';

/// The one question an 18+ world asks (P22e, call 42): only when someone wants the title itself, and
/// before anything downloads. Answered yes, this device asks no more and it answers true at once;
/// Adult content in You turns it back off.
Future<bool> askAdult(BuildContext context, WidgetRef ref, {required String title, required String line, required String press}) async {
  final settings = ref.read(settingsProvider).value ?? const DeviceSettings();
  if (settings.adultContent) return true;
  final yes = await showArkeSheet<bool>(
    context,
    title: null,
    builder: (context) {
      final text = Theme.of(context).textTheme;
      final surface = context.surface;
      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(ArkeRadius.md),
                  border: Border.all(color: surface.foreground.withValues(alpha: 0.42)),
                ),
                child: Text('18+', style: text.titleMedium),
              ),
            ),
            const SizedBox(height: 14),
            Text(title, textAlign: TextAlign.center, style: text.titleMedium),
            const SizedBox(height: 4),
            Text(
              line,
              textAlign: TextAlign.center,
              style: text.bodyMedium?.copyWith(color: surface.mutedForeground),
            ),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(ArkeSizes.widePress)),
              child: Text(press),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              style: TextButton.styleFrom(minimumSize: const Size.fromHeight(ArkeSizes.widePress), foregroundColor: surface.foreground),
              child: const Text('Not now'),
            ),
          ],
        ),
      );
    },
  );
  if (yes != true) return false;
  await ref.read(settingsProvider.notifier).change((current) => current.copyWith(adultContent: true));
  return true;
}
