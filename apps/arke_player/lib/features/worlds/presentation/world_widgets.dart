import 'dart:io';

import 'package:arke_library/arke_library.dart';
import 'package:arke_world/arke_world.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/services.dart';
import '../../../app/theme/tokens.dart';
import '../../../app/widgets/shelf.dart';
import '../application/worlds.dart';

const _fg = ArkeColors.mediaOverlayForeground;
const _bg = ArkeColors.mediaOverlayBackground;

/// `1 production`, `3 productions`.
String productionCount(int count) => count == 1 ? '1 production' : '$count productions';

/// A picture named relative to the library's root.
ImageProvider? libraryPicture(LibraryStore? store, String? relative) => store == null || relative == null ? null : FileImage(File(store.resolve(relative)));

/// A picture bundled with the app, for a world not installed yet.
ImageProvider? bundledPicture(String? asset) => asset == null ? null : AssetImage(asset);

/// A world as a card: 358 × 190 on Available and in Library (P9b, P7b), 240 × 135 on Home (P9g).
/// While it installs, its meta line is `Installing · 42%` over a line of progress (P9 rule 4).
class WorldCard extends StatelessWidget {
  const WorldCard({required this.name, required this.meta, required this.picture, required this.onOpen, this.mini = false, this.progress, super.key});

  final String name;
  final String meta;
  final ImageProvider? picture;
  final VoidCallback onOpen;
  final bool mini;
  final double? progress;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final card = ClipRRect(
      borderRadius: BorderRadius.circular(mini ? ArkeRadius.xl : 16),
      child: SizedBox(
        width: mini ? 240 : double.infinity,
        height: mini ? 135 : 190,
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (picture != null) Image(image: picture!, fit: BoxFit.cover) else const ColoredBox(color: ArkeColors.neutral800),
            const _Shade(),
            Positioned(
              left: mini ? 12 : 14,
              right: mini ? 12 : 14,
              bottom: mini ? 11 : 14,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: (mini ? text.titleMedium : text.titleMedium?.copyWith(fontSize: ArkeType.sizeXl))?.copyWith(color: _fg),
                  ),
                  const SizedBox(height: 1),
                  Text(
                    meta,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: text.bodyMedium?.copyWith(color: _fg.withValues(alpha: 0.8)),
                  ),
                ],
              ),
            ),
            if (progress != null)
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                height: 3,
                child: LinearProgressIndicator(value: progress, backgroundColor: _fg.withValues(alpha: 0.26), color: _fg, minHeight: 3),
              ),
          ],
        ),
      ),
    );
    return Semantics(
      button: true,
      label: '$name, $meta',
      child: ExcludeSemantics(
        child: GestureDetector(onTap: onOpen, child: card),
      ),
    );
  }
}

class _Shade extends StatelessWidget {
  const _Shade();

  @override
  Widget build(BuildContext context) => const DecoratedBox(
    decoration: BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.bottomCenter,
        end: Alignment.topCenter,
        colors: [Color(0xE00A0A0A), Color(0x4D0A0A0A), Color(0x000A0A0A)],
        stops: [0.06, 0.52, 0.74],
      ),
    ),
  );
}

/// A round glass press on a picture: back, ⋯.
class GlassPress extends StatelessWidget {
  const GlassPress({required this.icon, required this.label, required this.onPressed, super.key});

  final IconData icon;
  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: label,
    child: InkWell(
      onTap: onPressed,
      customBorder: const CircleBorder(),
      child: Container(
        width: ArkeSizes.press,
        height: ArkeSizes.press,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: _bg.withValues(alpha: 0.42),
          border: Border.all(color: _fg.withValues(alpha: 0.16)),
        ),
        child: Icon(icon, color: _fg, size: 22),
      ),
    ),
  );
}

/// A world's or a production's hero (P1d, P9c): the picture under the status bar fading into the
/// overlay colour, back and ⋯ at the top, the title in text-3xl, one meta line, the logline in at
/// most two lines — the author's words or nothing — and what goes under them. On a Fold the
/// picture is 400 high and the words keep to 640 at the left (P9h).
class WorldHero extends StatelessWidget {
  const WorldHero({required this.picture, required this.title, required this.meta, this.logline, this.onMore, this.child, super.key});

  final ImageProvider? picture;
  final String title;
  final String meta;
  final String? logline;
  final VoidCallback? onMore;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final top = MediaQuery.paddingOf(context).top;
    final wide = MediaQuery.sizeOf(context).width >= WindowBands.fold;
    final pictureHeight = wide ? 400.0 : 290.0;
    final side = wide ? 32.0 : 16.0;
    return ColoredBox(
      color: _bg,
      child: Stack(
        children: [
          Positioned(
            left: 0,
            right: 0,
            top: 0,
            height: pictureHeight,
            child: picture == null ? const SizedBox() : Image(image: picture!, fit: BoxFit.cover, alignment: const Alignment(0.2, 0)),
          ),
          Positioned(
            left: 0,
            right: 0,
            top: pictureHeight - 200,
            height: 201,
            child: const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0x000A0A0A), _bg]),
              ),
            ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(side, (wide ? 300.0 : 218.0).clamp(top + 120, double.infinity), side, wide ? 28 : 20),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 640),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Semantics(
                    header: true,
                    child: Text(title, style: text.headlineLarge?.copyWith(color: _fg)),
                  ),
                  const SizedBox(height: 6),
                  Text(meta, style: text.bodyMedium?.copyWith(color: _fg.withValues(alpha: 0.74))),
                  if (logline != null) ...[
                    const SizedBox(height: 10),
                    Text(
                      logline!,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: text.bodyLarge?.copyWith(color: _fg.withValues(alpha: 0.86)),
                    ),
                  ],
                  ?child,
                ],
              ),
            ),
          ),
          Positioned(
            left: 12,
            right: 12,
            top: top + 8,
            child: Row(
              children: [
                if (context.canPop()) GlassPress(icon: Icons.chevron_left_rounded, label: 'Back', onPressed: () => context.pop()),
                const Spacer(),
                if (onMore != null) GlassPress(icon: Icons.more_horiz, label: 'More', onPressed: onMore!),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// The hero's primary press: full width and 50 high on a phone, 320 on a Fold (P9c, P9h).
class HeroPress extends StatelessWidget {
  const HeroPress({required this.icon, required this.label, required this.onPressed, this.detail, super.key});

  final IconData icon;
  final String label;
  final String? detail;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= WindowBands.fold;
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: SizedBox(
        width: wide ? 320 : double.infinity,
        child: FilledButton.icon(
          onPressed: onPressed,
          icon: Icon(icon, size: 18),
          label: Text.rich(
            TextSpan(
              text: label,
              children: [
                if (detail != null)
                  TextSpan(
                    text: ' · $detail',
                    style: TextStyle(fontWeight: FontWeight.w400, color: _bg.withValues(alpha: 0.72)),
                  ),
              ],
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          style: FilledButton.styleFrom(
            minimumSize: const Size.fromHeight(ArkeSizes.widePress),
            backgroundColor: _fg,
            foregroundColor: _bg,
            // A button's textStyle replaces the theme's rather than merging, so it names the family.
            textStyle: const TextStyle(fontFamily: ArkeType.family, fontSize: ArkeType.sizeBase, fontWeight: FontWeight.w500),
          ),
        ),
      ),
    );
  }
}

/// A second press on a hero, in the overlay's quiet fill: Read beside Continue (P1e).
class HeroSecondPress extends StatelessWidget {
  const HeroSecondPress({required this.icon, required this.label, required this.onPressed, super.key});

  final IconData icon;
  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= WindowBands.fold;
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: SizedBox(
        width: wide ? 320 : double.infinity,
        child: FilledButton.icon(
          onPressed: onPressed,
          icon: Icon(icon, size: 18),
          label: Text(label),
          style: FilledButton.styleFrom(
            minimumSize: const Size.fromHeight(ArkeSizes.press),
            backgroundColor: _fg.withValues(alpha: 0.16),
            foregroundColor: _fg,
            textStyle: const TextStyle(fontFamily: ArkeType.family, fontSize: ArkeType.sizeBase, fontWeight: FontWeight.w500),
          ),
        ),
      ),
    );
  }
}

/// Install's progress in its place (P9d): the line, what is happening as data, and Cancel.
class InstallProgress extends StatelessWidget {
  const InstallProgress({required this.state, required this.onCancel, super.key});

  final Installing state;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= WindowBands.fold;
    return Padding(
      padding: const EdgeInsets.only(top: 20),
      child: SizedBox(
        width: wide ? 320 : double.infinity,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(ArkeRadius.pill),
              child: LinearProgressIndicator(value: state.fraction, minHeight: 4, backgroundColor: _fg.withValues(alpha: 0.22), color: _fg),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: Text(state.line, style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: _fg.withValues(alpha: 0.72))),
                ),
                const SizedBox(width: 10),
                FilledButton(
                  onPressed: onCancel,
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(0, 40),
                    backgroundColor: _fg.withValues(alpha: 0.16),
                    foregroundColor: _fg,
                    textStyle: const TextStyle(fontFamily: ArkeType.family, fontSize: ArkeType.sizeBase, fontWeight: FontWeight.w500),
                  ),
                  child: const Text('Cancel'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// A row of Inside (P9c, as P2e): the picture at 128 × 72, the title, the kind and length.
class InsideRow extends StatelessWidget {
  const InsideRow({required this.title, required this.kind, required this.picture, super.key});

  final String title;
  final String kind;
  final ImageProvider? picture;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(ArkeRadius.md),
            child: SizedBox(
              width: 128,
              height: 72,
              child: picture == null ? ColoredBox(color: context.surface.secondary) : Image(image: picture!, fit: BoxFit.cover),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: text.bodyMedium?.copyWith(fontSize: ArkeType.sizeBase),
                ),
                const SizedBox(height: 3),
                Text(
                  kind,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: text.labelSmall?.copyWith(color: context.surface.mutedForeground),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// One setting-like row of data in a group: `Space · 386 MB of 41 GB free` (P9c).
class GroupRow extends StatelessWidget {
  const GroupRow({required this.label, required this.value, super.key});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      constraints: const BoxConstraints(minHeight: 50),
      decoration: BoxDecoration(color: context.surface.secondary, borderRadius: BorderRadius.circular(ArkeRadius.xl)),
      child: Row(
        children: [
          Text(label, style: text.bodyMedium?.copyWith(fontSize: ArkeType.sizeBase)),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: text.bodyMedium?.copyWith(fontSize: ArkeType.sizeBase, color: context.surface.mutedForeground),
            ),
          ),
        ],
      ),
    );
  }
}

/// A production of an installed world (P1d, P9f): 16:9 with its title and kind; 160 wide, or the
/// full width when the world has only the one (P9 rule 6).
class ProductionTile extends StatelessWidget {
  const ProductionTile({required this.title, required this.kind, required this.picture, required this.width, required this.onOpen, super.key});

  final String title;
  final String kind;
  final ImageProvider? picture;
  final double width;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Semantics(
      button: true,
      label: '$title, $kind',
      child: ExcludeSemantics(
        child: GestureDetector(
          onTap: onOpen,
          child: SizedBox(
            width: width,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(ArkeRadius.lg),
                  child: AspectRatio(
                    aspectRatio: 16 / 9,
                    child: picture == null ? ColoredBox(color: context.surface.secondary) : Image(image: picture!, fit: BoxFit.cover),
                  ),
                ),
                const SizedBox(height: 7),
                Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: text.bodyMedium),
                Text(
                  kind,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: text.labelSmall?.copyWith(color: context.surface.mutedForeground),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A refusal (P9e, as P2f): the clause, the world and its size, then Try again and Close.
Future<void> showInstallRefusal(BuildContext context, WidgetRef ref, CatalogueWorld world, InstallRefusal refusal) async {
  final again = await showArkeSheet<bool>(
    context,
    title: null,
    builder: (context) {
      final text = Theme.of(context).textTheme;
      final network = refusal is NoConnection || refusal is DownloadStopped;
      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Icon(
              network ? Icons.wifi_off_rounded : Icons.warning_amber_rounded,
              size: 34,
              color: network ? context.surface.mutedForeground : ArkeColors.warning,
            ),
            const SizedBox(height: 12),
            Text(refusal.clause, textAlign: TextAlign.center, style: text.titleMedium),
            const SizedBox(height: 4),
            Text(
              [world.name, if (world.package != null) formatBytes(world.package!.byteLength)].join(' · '),
              textAlign: TextAlign.center,
              style: text.bodyMedium?.copyWith(color: context.surface.mutedForeground),
            ),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(ArkeSizes.widePress)),
              child: const Text('Try again'),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              style: TextButton.styleFrom(minimumSize: const Size.fromHeight(ArkeSizes.widePress), foregroundColor: context.surface.foreground),
              child: const Text('Close'),
            ),
          ],
        ),
      );
    },
  );
  final controller = ref.read(installProvider(world.id).notifier);
  controller.dismiss();
  if (again == true) await controller.start(world);
}

/// ⋯ on an installed world (P9 rule 6): Details and Remove.
Future<void> showWorldMenu(BuildContext context, WidgetRef ref, LibraryWorld world) async {
  final choice = await showArkeSheet<String>(
    context,
    title: world.name,
    builder: (context) => Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ListTile(leading: const Icon(Icons.info_outline), title: const Text('Details'), onTap: () => Navigator.of(context).pop('details')),
        ListTile(leading: const Icon(Icons.delete_outline), title: const Text('Remove'), onTap: () => Navigator.of(context).pop('remove')),
      ],
    ),
  );
  if (!context.mounted || choice == null) return;
  if (choice == 'details') {
    await showArkeSheet<void>(
      context,
      title: 'Details',
      builder: (context) {
        final text = Theme.of(context).textTheme;
        final muted = context.surface.mutedForeground;
        final installed = world.installedAt.toLocal();
        Widget row(String label, String value) => Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 96,
                child: Text(label, style: text.bodyMedium?.copyWith(color: muted)),
              ),
              Expanded(child: Text(value, style: text.bodyLarge)),
            ],
          ),
        );
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            row('Name', world.name),
            row('Edition', world.edition),
            row('Productions', '${world.productions.length}'),
            row('Size', formatBytes(world.byteLength)),
            row('Installed', '${installed.day} ${_months[installed.month - 1]} ${installed.year}'),
          ],
        );
      },
    );
  } else if (choice == 'remove') {
    final confirmed = await showArkeSheet<bool>(
      context,
      title: null,
      builder: (context) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Remove ${world.name}', textAlign: TextAlign.center, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 4),
            Text(
              formatBytes(world.byteLength),
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: context.surface.mutedForeground),
            ),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(ArkeSizes.widePress), backgroundColor: context.surface.destructive),
              child: const Text('Remove'),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              style: TextButton.styleFrom(minimumSize: const Size.fromHeight(ArkeSizes.widePress), foregroundColor: context.surface.foreground),
              child: const Text('Cancel'),
            ),
          ],
        ),
      ),
    );
    if (confirmed != true) return;
    final store = await ref.read(libraryStoreProvider.future);
    await store.removeWorld(world.id);
  }
}

const _months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
