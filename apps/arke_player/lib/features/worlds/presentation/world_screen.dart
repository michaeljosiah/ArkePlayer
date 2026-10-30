import 'package:arke_library/arke_library.dart';
import 'package:arke_world/arke_world.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/routes.dart';
import '../../../app/services.dart';
import '../../../app/theme/tokens.dart';
import '../../../app/widgets/shelf.dart';
import '../../comics/application/comics.dart';
import '../../players/application/music.dart';
import '../../production/domain/production_kind.dart';
import '../../stories/application/stories.dart';
import '../application/worlds.dart';
import 'guide_widgets.dart';
import 'row_widgets.dart';
import 'world_widgets.dart';

/// A world's page (P9, P15c, P15d, P16d, P16e, P17a). Before it is installed: the hero with `Install ·
/// 386 MB`, its productions grouped by how they are taken, `Listen · Music · Watch · Play · Read`, each head
/// with its count (P15 rule 3), then Space; while it installs, the progress in the press's place
/// (P9d); a refusal as a sheet (P9e). Installed, the same groups open their productions, a
/// production with a chapter not yet opened marked `New` (R-52). Listen and Read are posters from a
/// production's Tall cover, Watch and Play wide tiles, a lone one at the full width (P16 rules 3 and
/// 4, P9f). On a Fold the words keep to the left (P9h). Either way the world's guide follows its
/// productions (P11b, P11c, P11i). A newer edition in Arke's list puts `Update` where Install was,
/// with what it brings and the space it needs (P12b – P12f).
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
    final groups = groupByTakenAs(
      world.productions,
      (production) => production.music != null ? ProductionKind.ofMusic(production.music!.name) : ProductionKind.ofLine(production.kind),
    );
    final single = world.productions.length == 1;

    return ScrolledHead(
      title: world.name,
      child: ListView(
        padding: EdgeInsets.only(bottom: footRoom(context)),
        children: [
          WorldHero(
            picture: ref.keyArtOf(world),
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
            tile: (production, width, shape) => switch (shape) {
              _Shape.poster => PosterTile(
                title: production.title,
                kind: production.kind,
                tall: ref.tallOf(production),
                wide: ref.pictureOf(world, production),
                width: width,
                onOpen: null,
              ),
              _Shape.square => SquareTile(
                title: production.title,
                kind: production.kind,
                picture: ref.pictureOf(world, production),
                width: width,
                onOpen: null,
              ),
              _Shape.wide => ProductionTile(
                title: production.title,
                kind: production.kind,
                picture: ref.pictureOf(world, production),
                width: width,
                // A story this Player cannot play is shown, and never fetched (R-82).
                tag: production.needsNewerApp ? 'Update app' : null,
                onOpen: null,
              ),
            },
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
    final update = ref.watch(worldUpdateProvider(world.id));
    final listed = listedFor(ref.watch(catalogueProvider).value ?? const [], world.id);
    // A production published on its own and not on the phone yet still shows, opening nothing until
    // it arrives (SPEC-058 R-72, R-73, R-83); so does a story this Player cannot play, with `Update
    // app`, never fetched (R-82).
    final coming = [
      if (listed != null) ...missingProductions(listed, world).where((production) => installedProduction(production, world) == null),
      for (final production in listed?.productions ?? const <CatalogueProduction>[])
        if (production.needsNewerApp && installedProduction(production, world) == null) production,
    ];
    final groups = groupByTakenAs<Object>([...world.productions, ...coming], (production) {
      return switch (production) {
        CatalogueProduction(:final music?) => ProductionKind.ofMusic(music.name),
        CatalogueProduction(:final kind) => ProductionKind.ofLine(kind),
        LibraryProduction(:final music?) => ProductionKind.ofMusic(music.kind),
        LibraryProduction(story: LibraryStory(kind: 'novel')) => ProductionKind.visualNovel,
        LibraryProduction(story: _?) => ProductionKind.interactiveMovie,
        LibraryProduction(comic: _?) => ProductionKind.graphicNovel,
        LibraryProduction(:final narration) => narration != null ? ProductionKind.audiobook : ProductionKind.book,
        _ => ProductionKind.book,
      };
    });
    final single = world.productions.length + coming.length == 1;
    final installing = update?.id ?? world.id;
    final state = ref.watch(installProvider(installing));
    ref.listen(installProvider(installing), (previous, next) {
      if (next is InstallFailed && previous is! InstallFailed && update != null) showInstallRefusal(context, ref, update, next.refusal, updating: true);
    });
    final newer = update?.package;
    final free = ref.watch(volumeProvider).value?.free;

    Widget tile(Object entry, double width, _Shape shape) {
      if (entry is CatalogueProduction) {
        final picture = listed == null ? null : ref.pictureOf(listed, entry);
        final tag = entry.needsNewerApp ? 'Update app' : null;
        return shape == _Shape.square
            ? SquareTile(title: entry.title, kind: entry.kind, picture: picture, width: width, tag: tag, onOpen: null)
            : ProductionTile(title: entry.title, kind: entry.kind, picture: picture, width: width, tag: tag, onOpen: null);
      }
      final production = entry as LibraryProduction;
      void open() => context.push(Routes.production(location, production.id));
      if (production.story case final story?) {
        final updating = ref.watch(productionUpdateProvider((world.id, production.id))) != null;
        return ProductionTile(
          title: production.title,
          kind: storyTileKind(story),
          picture: libraryPicture(store, production.picture ?? world.keyArt),
          width: width,
          tag: updating ? 'Update' : null,
          onOpen: open,
        );
      }
      if (production.comic case final comic?) {
        final updating = ref.watch(productionUpdateProvider((world.id, production.id))) != null;
        return ProductionTile(
          title: production.title,
          kind: comicTileKind(comic),
          picture: libraryPicture(store, production.picture ?? world.keyArt),
          width: width,
          tag: updating ? 'Update' : null,
          onOpen: open,
        );
      }
      if (production.music case final music?) {
        final updating = ref.watch(productionUpdateProvider((world.id, production.id))) != null;
        return SquareTile(
          title: production.title,
          kind: musicTileKind(music.kind, tracks: music.tracks, length: music.duration),
          picture: libraryPicture(store, production.picture ?? world.keyArt),
          width: width,
          tag: updating ? 'Update' : null,
          onOpen: open,
        );
      }
      final narration = items[production.narration];
      final picture = production.picture ?? narration?.cover ?? items[production.book]?.cover ?? world.keyArt;
      final kind = productionKind(book: production.book != null, narration: production.narration != null, length: narration?.duration);
      final fresh = newChapters(world, production.id, narration).isNotEmpty;
      if (shape != _Shape.poster) {
        return ProductionTile(title: production.title, kind: kind, picture: libraryPicture(store, picture), width: width, fresh: fresh, onOpen: open);
      }
      // The package carries no Tall cover yet: the list's, fetched with it or bundled with the app, is
      // the one there is.
      final tall = ref.tallOf(
        listed?.productions.where((listedProduction) => listedProduction.id == production.id || listedProduction.title == production.title).firstOrNull,
      );
      return PosterTile(title: production.title, kind: kind, tall: tall, wide: libraryPicture(store, picture), width: width, fresh: fresh, onOpen: open);
    }

    return ScrolledHead(
      title: world.name,
      onMore: () => showWorldMenu(context, ref, world),
      child: ListView(
        padding: EdgeInsets.only(bottom: footRoom(context)),
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

/// The shape a group's row takes (P16 rule 1: a row is one shape).
enum _Shape { poster, wide, square }

/// A world's productions under `Listen · Music · Watch · Play · Read`, each head with its count (P15
/// rule 3, P17 rule 2). Listen and Read are posters, where audiobooks and books sit (P16 rule 3);
/// Music is squares (P17 rule 3); Watch and Play are wide tiles, and a world of one production shows
/// a wide one at the full width (P9 rule 6). A lone poster keeps the poster's size: at the full width
/// it would be the feature.
class _Groups<T> extends StatelessWidget {
  const _Groups({required this.groups, required this.single, required this.tile});

  final Map<TakenAs, List<T>> groups;
  final bool single;
  final Widget Function(T production, double width, _Shape shape) tile;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      for (final MapEntry(key: takenAs, value: productions) in groups.entries) ...[
        if (single) SectionHead(takenAs.label) else CountHead(title: takenAs.label, count: productions.length),
        if (takenAs == TakenAs.listen || takenAs == TakenAs.read)
          TileRow(children: [for (final production in productions) tile(production, RowSizes.poster(context), _Shape.poster)])
        else if (takenAs == TakenAs.music)
          TileRow(children: [for (final production in productions) tile(production, RowSizes.square(context), _Shape.square)])
        else if (single)
          LayoutBuilder(
            builder: (context, box) => Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Align(alignment: Alignment.centerLeft, child: tile(productions.single, (box.maxWidth - 32).clamp(0, 640), _Shape.wide)),
            ),
          )
        else
          TileRow(children: [for (final production in productions) tile(production, rowTileWidth(context), _Shape.wide)]),
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
