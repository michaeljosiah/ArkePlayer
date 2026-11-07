import 'package:arke_library/arke_library.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/routes.dart';
import '../../../app/services.dart';
import '../../../app/theme/tokens.dart';
import '../../../app/widgets/shelf.dart';
import '../../worlds/application/worlds.dart';
import '../application/settings_controller.dart';
import '../domain/device_settings.dart';
import 'adult_ask.dart';

/// You (P25g): Appearance with Theme, dark until changed (call 51); Playback; Downloads with Wi-Fi only
/// (a world's new chapters wait for it, SPEC-058 R-51) and what is on the phone; Content; About with
/// Check for updates, moved from Discover's head (P22 rule 7). Every setting is this device's (P6 rule
/// 3); nothing here needs or names an account (P8 rule 1).
class YouScreen extends ConsumerWidget {
  const YouScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider).value ?? const DeviceSettings();
    final items = ref.watch(libraryItemsProvider).value ?? const [];
    // Two columns on a tablet sideways, one upright (P26r, P26x).
    final first = <Widget>[
      const _GroupLabel('Appearance'),
      _Group(
        children: [
          _ThemeRow(
            value: settings.theme,
            onChanged: (theme) => ref.read(settingsProvider.notifier).change((current) => current.copyWith(theme: theme)),
          ),
        ],
      ),
      const _GroupLabel('Playback'),
      _Group(
        children: [
          _Row(label: 'Captions', value: settings.captions ? 'On · ${settings.captionSize.label}' : 'Off', onTap: () => _captions(context, ref)),
          _SwitchRow(
            label: 'Text',
            value: settings.text,
            onChanged: (on) => ref.read(settingsProvider.notifier).change((current) => current.copyWith(text: on)),
          ),
          _SwitchRow(
            label: 'Slow push',
            value: settings.slowPush,
            onChanged: (on) => ref.read(settingsProvider.notifier).change((current) => current.copyWith(slowPush: on)),
          ),
          _SwitchRow(
            label: 'Autoplay next',
            value: settings.autoplayNext,
            onChanged: (on) => ref.read(settingsProvider.notifier).change((current) => current.copyWith(autoplayNext: on)),
          ),
        ],
      ),
    ];
    final second = <Widget>[
      const _GroupLabel('Downloads'),
      _Group(
        children: [
          _SwitchRow(
            label: 'Wi-Fi only',
            value: settings.wifiOnly,
            onChanged: (on) => ref.read(settingsProvider.notifier).change((current) => current.copyWith(wifiOnly: on)),
          ),
          _Row(
            label: 'On this phone',
            value: formatBytes(bytesUsed(items, ref.watch(libraryWorldsProvider).value ?? const [])),
            onTap: () => context.go(Routes.downloads),
          ),
        ],
      ),
      const _GroupLabel('Content'),
      _Group(
        children: [
          _Row(
            label: 'Adult content',
            value: settings.adultContent ? 'On' : 'Off',
            onTap: () => settings.adultContent
                ? ref.read(settingsProvider.notifier).change((current) => current.copyWith(adultContent: false))
                : askAdult(context, ref, title: 'Adult content', line: '18+', press: 'I am 18 or older · Turn on'),
          ),
        ],
      ),
      const _GroupLabel('About'),
      _Group(
        children: [
          _Row(
            label: 'Check for updates',
            value: switch (ref.watch(catalogueCheckProvider)) {
              CatalogueCheck.idle => null,
              CatalogueCheck.checking => 'Checking',
              CatalogueCheck.checked => 'Checked',
              CatalogueCheck.failed => 'Couldn’t check',
            },
            onTap: () => ref.read(catalogueCheckProvider.notifier).check(),
          ),
          const _Row(label: 'Version', value: appVersion),
          _Row(
            label: 'Licences',
            onTap: () => showLicensePage(context: context, applicationName: 'Arke Player', applicationVersion: appVersion),
          ),
        ],
      ),
    ];
    return SafeArea(
      bottom: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const ShelfHeader(title: 'You'),
          Expanded(
            child: ListView(
              padding: EdgeInsets.only(top: 8, bottom: 24 + footRoom(context)),
              children: MediaQuery.sizeOf(context).width >= WindowBands.wide
                  ? [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: first),
                          ),
                          Expanded(
                            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: second),
                          ),
                        ],
                      ),
                    ]
                  : [...first, ...second],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _captions(BuildContext context, WidgetRef ref) => showArkeSheet<void>(
    context,
    title: 'Captions',
    builder: (context) => Consumer(
      builder: (context, ref, _) {
        final settings = ref.watch(settingsProvider).value ?? const DeviceSettings();
        final controller = ref.read(settingsProvider.notifier);
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final on in [false, true])
              ListTile(
                title: Text(on ? 'On' : 'Off'),
                trailing: settings.captions == on ? const Icon(Icons.check) : null,
                onTap: () => controller.change((current) => current.copyWith(captions: on)),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
              child: Text('Size', style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: context.surface.mutedForeground)),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: SegmentedButton<CaptionSize>(
                segments: [for (final size in CaptionSize.values) ButtonSegment(value: size, label: Text(size.label))],
                selected: {settings.captionSize},
                showSelectedIcon: false,
                onSelectionChanged: (value) => controller.change((current) => current.copyWith(captionSize: value.first)),
              ),
            ),
          ],
        );
      },
    ),
  );
}

/// A group's label in 149's grammar: small, uppercase, muted.
class _GroupLabel extends StatelessWidget {
  const _GroupLabel(this.label);
  final String label;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(30, 22, 30, 8),
    child: Text(
      label.toUpperCase(),
      style: Theme.of(context).textTheme.labelSmall?.copyWith(color: context.surface.mutedForeground, letterSpacing: 0.55, fontWeight: FontWeight.w500),
    ),
  );
}

class _Group extends StatelessWidget {
  const _Group({required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.symmetric(horizontal: 16),
    decoration: BoxDecoration(color: context.surface.secondary, borderRadius: BorderRadius.circular(ArkeRadius.xl)),
    clipBehavior: Clip.antiAlias,
    child: Column(
      children: [
        for (var i = 0; i < children.length; i++) ...[
          if (i > 0) Divider(height: 1, thickness: 1, color: context.surface.foreground.withValues(alpha: 0.08)),
          children[i],
        ],
      ],
    ),
  );
}

/// Theme, in the group's row (P25g): its two choices side by side, the current one raised.
class _ThemeRow extends StatelessWidget {
  const _ThemeRow({required this.value, required this.onChanged});

  final AppTheme value;
  final ValueChanged<AppTheme> onChanged;

  @override
  Widget build(BuildContext context) {
    final surface = context.surface;
    final text = Theme.of(context).textTheme.bodyMedium;
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 50),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        child: Row(
          children: [
            Expanded(
              child: Text('Theme', style: text?.copyWith(fontSize: ArkeType.sizeBase)),
            ),
            Container(
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(color: surface.foreground.withValues(alpha: 0.10), borderRadius: BorderRadius.circular(ArkeRadius.lg)),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (final theme in AppTheme.values)
                    Semantics(
                      button: true,
                      selected: theme == value,
                      child: GestureDetector(
                        onTap: () => onChanged(theme),
                        child: Container(
                          width: 75,
                          height: 32,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(color: theme == value ? surface.background : null, borderRadius: BorderRadius.circular(ArkeRadius.md)),
                          child: Text(theme.label, style: text?.copyWith(color: surface.foreground)),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A label and its switch (P6b).
class _SwitchRow extends StatelessWidget {
  const _SwitchRow({required this.label, required this.value, required this.onChanged});

  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) => MergeSemantics(
    child: ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 50),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 4, 8, 4),
        child: Row(
          children: [
            Expanded(
              child: Text(label, style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontSize: ArkeType.sizeBase)),
            ),
            Switch(value: value, onChanged: onChanged),
          ],
        ),
      ),
    ),
  );
}

/// A label, its value, its state (Studio 149).
class _Row extends StatelessWidget {
  const _Row({required this.label, this.value, this.onTap});

  final String label;
  final String? value;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final muted = context.surface.mutedForeground;
    return InkWell(
      onTap: onTap,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 50),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          child: Row(
            children: [
              Expanded(
                child: Text(label, style: text.bodyMedium?.copyWith(fontSize: ArkeType.sizeBase)),
              ),
              // Flexible: at 200% text `Couldn’t check` is wider than the row has room for.
              if (value != null)
                Flexible(
                  child: Text(
                    value!,
                    textAlign: TextAlign.end,
                    style: text.bodyMedium?.copyWith(fontSize: ArkeType.sizeBase, color: muted),
                  ),
                ),
              if (onTap != null) ...[const SizedBox(width: 6), Icon(Icons.chevron_right, size: 18, color: muted)],
            ],
          ),
        ),
      ),
    );
  }
}
