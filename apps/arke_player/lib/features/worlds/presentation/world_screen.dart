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

/// A world's page (P9, P15c, P15d). Before it is installed: the hero with `Install · 386 MB`, its
/// productions grouped by how they are taken, `Listen · Watch · Play · Read`, each head with its
/// count (P15 rule 3), then Space; while it installs, the progress in the press's place (P9d); a
/// refusal as a sheet (P9e). Installed, the same groups open their productions, one production at
/// the full width (P9f), a production with a chapter not yet opened marked `New` (R-52). Every row
/// is the one tile (P15 rule 10). On a Fold the words keep to the left (P9h). Either way the
/// world's guide follows its productions (P11b, P11c, P11i). A newer edition in Arke's list puts
/// `Update` where Install was, with what it brings and the space it needs (P12b – P12f).
///
/// [location] is this page's own path, which a production's page and the guide's pages are pushed
/// under.
class WorldScreen extends ConsumerWidget {
  const WorldScreen({required this.worldId, required this.location, super.key});

  final String worldId;
  final String location;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final installed = ref.watch(installedWorldProvider(worldId));
    // A world updated to a new id while its page was open (SPEC-058 R-30), or opened from an old
    // link: the page moves to the world's own address. Under the old one, a production opened from
    // here looked for a world that had gone and said Removed.
    if (installed != null && installed.id != worldId && location.endsWith('/$worldId')) {
      final moved = '${location.substring(0, location.length - worldId.length)}${installed.id}';
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted) context.replace(moved);
      });
    }
    // Opening a world's page asks Arke's address for its list, at most once a day (P12 rule 1).
    ref.watch(catalogueRefreshProvider);
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
    // The edition and every part since it (SPEC-058 R-50).
    final bytes = package == null ? null : package.byteLength + package.parts.fold<int>(0, (sum, part) => sum + part.byteLength);
    final size = bytes == null ? null : formatBytes(bytes);
    final free = ref.watch(volumeProvider).value?.free;
    final wide = MediaQuery.sizeOf(context).width >= WindowBands.fold;
    final groups = groupByTakenAs(world.productions, (production) => ProductionKind.ofLine(production.kind));
    final single = world.productions.length == 1;

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
          // Nothing opens before it is installed (P9 rule 3); the tiles say what is inside.
          _Groups(
            groups: groups,
            single: single,
            tile: (production, width) => ProductionTile(
              title: production.title,
              kind: production.kind,
              picture: bundledPicture(production.picture ?? world.keyArt),
              width: width,
              onOpen: null,
            ),
          ),
          if (size != null && free != null)
            Align(
              alignment: Alignment.centerLeft,
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: wide ? 672 : double.infinity),
                child: Padding(
                  padding: EdgeInsets.fromLTRB(wide ? 16 : 0, 14, wide ? 16 : 0, 0),
                  child: GroupRow(label: 'Space', value: '$size of ${formatBytes(free)} free'),
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
    final update = ref.watch(worldUpdateProvider(world.id));
    final listed = listedFor(ref.watch(catalogueProvider).value ?? const [], world.id);
    final installing = update?.id ?? world.id;
    final state = ref.watch(installProvider(installing));
    ref.listen(installProvider(installing), (previous, next) {
      if (next is InstallFailed && previous is! InstallFailed && update != null) showInstallRefusal(context, ref, update, next.refusal, updating: true);
    });
    final newer = update?.package;
    final free = ref.watch(volumeProvider).value?.free;

    Widget tile(LibraryProduction production, double width) {
      final narration = items[production.narration];
      final picture = production.picture ?? narration?.cover ?? items[production.book]?.cover ?? world.keyArt;
      return ProductionTile(
        title: production.title,
        kind: productionKind(book: production.book != null, narration: production.narration != null, length: narration?.duration),
        picture: libraryPicture(store, picture),
        width: width,
        fresh: newChapters(world, production.id, narration).isNotEmpty,
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
            // A world from Arke's list says which edition is on the phone (P12b, P12d).
            meta: [
              'Installed',
              if (listed?.package?.edition != null) editionLabel(world.edition) else productionCount(world.productions.length),
              formatBytes(world.byteLength),
            ].join(' · '),
            logline: world.logline,
            onMore: () => showWorldMenu(context, ref, world),
            child: switch (state) {
              Installing() => InstallProgress(state: state, onCancel: () => ref.read(installProvider(installing).notifier).cancel()),
              _ when update != null && newer != null => HeroPress(
                icon: Icons.download_rounded,
                label: 'Update',
                detail: formatBytes(newer.byteLength),
                onPressed: () => ref.read(installProvider(installing).notifier).start(update),
              ),
              _ => null,
            },
          ),
          if (newer != null) ...[
            const SizedBox(height: 16),
            GroupRows(
              rows: [
                (label: 'New edition', value: [if (newer.edition != null) editionLabel(newer.edition!), formatBytes(newer.byteLength)].join(' · ')),
                if (free != null)
                  (
                    label: 'Space',
                    value:
                        '${newer.byteLength >= world.byteLength ? '+' : '−'}${formatBytes((newer.byteLength - world.byteLength).abs())} of ${formatBytes(free)} free',
                  ),
              ],
            ),
          ],
          _Groups(groups: groups, single: single, tile: tile),
          GuideSections(worldId: world.id, location: location),
        ],
      ),
    );
  }
}

/// A world's productions under `Listen · Watch · Play · Read`, each head with its count (P15 rule
/// 3), each row the one tile; a world of one production shows it at the full width (P9 rule 6).
class _Groups<T> extends StatelessWidget {
  const _Groups({required this.groups, required this.single, required this.tile});

  final Map<TakenAs, List<T>> groups;
  final bool single;
  final Widget Function(T production, double width) tile;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      for (final MapEntry(key: takenAs, value: productions) in groups.entries) ...[
        if (single) SectionHead(takenAs.label) else CountHead(title: takenAs.label, count: productions.length),
        if (single)
          LayoutBuilder(
            builder: (context, box) => Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Align(alignment: Alignment.centerLeft, child: tile(productions.single, (box.maxWidth - 32).clamp(0, 640))),
            ),
          )
        else
          TileRow(children: [for (final production in productions) tile(production, rowTileWidth(context))]),
      ],
    ],
  );
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
