import 'package:arke_library/arke_library.dart';
import 'package:arke_world/arke_world.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/routes.dart';
import '../../../app/services.dart';
import '../../../app/theme/tokens.dart';
import '../../../app/widgets/shelf.dart';
import '../../production/domain/production_kind.dart';
import '../application/worlds.dart';
import 'guide_widgets.dart';
import 'world_widgets.dart';

/// A world's page (P9). Before it is installed: the hero with `Install · 386 MB`, then Inside and
/// Space (P9c); while it installs, the progress in the press's place (P9d); a refusal as a sheet
/// (P9e). Installed, the same page becomes P1d's: its productions grouped by what a person does,
/// one production at the full width (P9f). On a Fold the words keep to the left (P9h). Either
/// way the world's guide follows its productions (P11b, P11c, P11i).
///
/// [location] is this page's own path, which a production's page and the guide's pages are pushed
/// under.
class WorldScreen extends ConsumerWidget {
  const WorldScreen({required this.worldId, required this.location, super.key});

  final String worldId;
  final String location;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final installed = ref.watch(libraryWorldsProvider).value?.where((world) => world.id == worldId).firstOrNull;
    return Scaffold(
      body: installed != null ? _Installed(world: installed, location: location) : _ToInstall(worldId: worldId, location: location),
    );
  }
}

class _ToInstall extends ConsumerWidget {
  const _ToInstall({required this.worldId, required this.location});

  final String worldId;
  final String location;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final world = ref.watch(catalogueProvider).value?.where((world) => world.id == worldId).firstOrNull;
    final state = ref.watch(installProvider(worldId));
    ref.listen(installProvider(worldId), (previous, next) {
      if (next is InstallFailed && previous is! InstallFailed && world != null) showInstallRefusal(context, ref, world, next.refusal);
    });
    if (world == null) return const _Gone();
    final package = world.package;
    final size = package == null ? null : formatBytes(package.byteLength);
    final free = ref.watch(volumeProvider).value?.free;
    final wide = MediaQuery.sizeOf(context).width >= WindowBands.fold;

    return ScrolledHead(
      title: world.name,
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          WorldHero(
            picture: bundledPicture(world.keyArt),
            title: world.name,
            meta: [productionCount(world.productions.length), ?size].join(' · '),
            logline: world.logline,
            child: switch (state) {
              Installing() => InstallProgress(state: state, onCancel: () => ref.read(installProvider(worldId).notifier).cancel()),
              _ when package == null => null,
              _ => HeroPress(
                icon: Icons.download_rounded,
                label: 'Install',
                detail: size,
                onPressed: () => ref.read(installProvider(worldId).notifier).start(world),
              ),
            },
          ),
          Align(
            alignment: Alignment.centerLeft,
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: wide ? 672 : double.infinity),
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: wide ? 16 : 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SectionHead('Inside'),
                    for (final production in world.productions)
                      InsideRow(title: production.title, kind: production.kind, picture: bundledPicture(production.picture)),
                    if (size != null && free != null) ...[const SizedBox(height: 14), GroupRow(label: 'Space', value: '$size of ${formatBytes(free)} free')],
                  ],
                ),
              ),
            ),
          ),
          GuideSections(worldId: worldId, location: location),
        ],
      ),
    );
  }
}

class _Installed extends ConsumerWidget {
  const _Installed({required this.world, required this.location});

  final LibraryWorld world;
  final String location;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final store = ref.watch(libraryStoreProvider).value;
    final items = {for (final item in ref.watch(libraryItemsProvider).value ?? const <LibraryItem>[]) item.id: item};
    final groups = groupByTakenAs(world.productions, (production) => production.narration != null ? ProductionKind.audiobook : ProductionKind.book);
    final single = world.productions.length == 1;

    Widget tile(LibraryProduction production, double width) {
      final narration = items[production.narration];
      final picture = production.picture ?? narration?.cover ?? items[production.book]?.cover ?? world.keyArt;
      return ProductionTile(
        title: production.title,
        kind: productionKind(book: production.book != null, narration: production.narration != null, length: narration?.duration),
        picture: libraryPicture(store, picture),
        width: width,
        onOpen: () => context.push(Routes.production(location, production.id)),
      );
    }

    return ScrolledHead(
      title: world.name,
      onMore: () => showWorldMenu(context, ref, world),
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          WorldHero(
            picture: libraryPicture(store, world.keyArt),
            title: world.name,
            meta: 'Installed · ${productionCount(world.productions.length)} · ${formatBytes(world.byteLength)}',
            logline: world.logline,
            onMore: () => showWorldMenu(context, ref, world),
          ),
          for (final MapEntry(key: takenAs, value: productions) in groups.entries) ...[
            SectionHead(takenAs.label),
            if (single)
              LayoutBuilder(
                builder: (context, box) => Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Align(alignment: Alignment.centerLeft, child: tile(productions.single, (box.maxWidth - 32).clamp(0, 640))),
                ),
              )
            else
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (final (i, production) in productions.indexed) ...[if (i > 0) const SizedBox(width: 12), tile(production, 160)],
                  ],
                ),
              ),
          ],
          GuideSections(worldId: world.id, location: location),
        ],
      ),
    );
  }
}

/// Once the hero has scrolled away, a head in the shelf's colours with back, the world's name and
/// ⋯ (P11c, P11i), so the guide never runs under the status bar.
class ScrolledHead extends StatefulWidget {
  const ScrolledHead({required this.title, required this.child, this.onMore, super.key});

  final String title;
  final VoidCallback? onMore;
  final Widget child;

  @override
  State<ScrolledHead> createState() => _ScrolledHeadState();
}

class _ScrolledHeadState extends State<ScrolledHead> {
  /// About where the hero's title passes under the head.
  static const _after = 240.0;
  bool _shown = false;

  @override
  Widget build(BuildContext context) {
    final surface = context.surface;
    return Stack(
      children: [
        NotificationListener<ScrollUpdateNotification>(
          onNotification: (notification) {
            final shown = notification.depth == 0 && notification.metrics.axis == Axis.vertical && notification.metrics.pixels > _after;
            if (notification.depth == 0 && notification.metrics.axis == Axis.vertical && shown != _shown) setState(() => _shown = shown);
            return false;
          },
          child: widget.child,
        ),
        if (_shown)
          Positioned(
            left: 0,
            right: 0,
            top: 0,
            child: ColoredBox(
              color: surface.background,
              child: SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 6, 12, 6),
                  child: Row(
                    children: [
                      if (context.canPop()) RoundPress(icon: Icons.chevron_left_rounded, label: 'Back', onPressed: () => context.pop()),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(widget.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: Theme.of(context).textTheme.titleMedium),
                      ),
                      if (widget.onMore != null) RoundPress(icon: Icons.more_horiz, label: 'More', onPressed: widget.onMore!),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// The world is in neither the library nor the list: removed, or a link from an older build.
class _Gone extends StatelessWidget {
  const _Gone();

  @override
  Widget build(BuildContext context) => SafeArea(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (context.canPop()) IconButton(onPressed: () => context.pop(), tooltip: 'Back', icon: const Icon(Icons.chevron_left_rounded)),
        Expanded(
          child: Center(
            child: Text('Not available', style: Theme.of(context).textTheme.titleMedium?.copyWith(color: context.surface.mutedForeground)),
          ),
        ),
      ],
    ),
  );
}
