import 'dart:io';

import 'package:arke_library/arke_library.dart';
import 'package:arke_world/arke_world.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/routes.dart';
import '../../../app/services.dart';
import '../../../app/theme/tokens.dart';
import '../../../app/widgets/shelf.dart';
import '../../add_file/presentation/add_flow.dart';
import '../../comics/application/comics.dart';
import '../../library/presentation/item_menu.dart';
import '../../parts/application/parts.dart';
import '../../players/application/music.dart';
import '../../production/domain/production_kind.dart';
import '../../settings/application/settings_controller.dart';
import '../../worlds/application/discover.dart';
import '../../worlds/application/found.dart';
import '../../worlds/application/guides.dart';
import '../../worlds/application/teaser_feed.dart';
import '../../worlds/application/worlds.dart';
import '../../worlds/presentation/guide_widgets.dart';
import '../../worlds/presentation/row_widgets.dart';
import '../../worlds/presentation/teaser_screen.dart';
import '../../worlds/presentation/world_shelf.dart';
import '../../worlds/presentation/world_widgets.dart';

const _fg = ArkeColors.mediaOverlayForeground;

/// Home (P22a – P22c, P25b, P25c, P26a – P26c): the door. Nothing to set up, so it opens on worlds, a
/// cover at a time, in the colour of the first (P22 rule 6). Coming back, Continue comes first, in the
/// colour of the world you are in, then New chapters, then the covers. Under them, Discover's rows at
/// P16's sizes: Stories as posters, Music, Teasers as small posters, one world's band. A brand-new
/// install has no Continue, and its faces and teasers arrive as the guides do (P25 rule 3).
class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  final _scroll = ScrollController();

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // The app opens here, so here the list is first asked for, at most once a day (P12 rule 1), and
    // each world's guide alone, for its faces and teasers (SPEC-059 R-31).
    ref.watch(catalogueRefreshProvider);
    final catalogue = (ref.watch(catalogueProvider).value ?? const <CatalogueWorld>[]).where((world) => world.installable).toList();
    for (final world in catalogue) {
      if (world.guide != null) ref.watch(guideFetchProvider(world.id));
    }
    final items = ref.watch(libraryItemsProvider).value ?? const <LibraryItem>[];
    final store = ref.watch(libraryStoreProvider).value;
    final installed = ref.watch(libraryWorldsProvider).value ?? const <LibraryWorld>[];
    final picks = ref.watch(listPicksProvider).value;
    final now = ref.watch(clockProvider)();
    final going = continueShelf(items);
    final offline = !(ref.watch(onlineProvider).value ?? true);
    final media = MediaQuery.of(context);
    final fold = media.size.width >= WindowBands.fold;

    LibraryWorld? installedAs(CatalogueWorld world) => installed.where((held) => world.covers(held.id)).firstOrNull;
    String pageOf(CatalogueWorld world) => Routes.world(installedAs(world)?.id ?? world.id);

    // The world the list names leads, as it named Discover's feature (call 15).
    final covers = [...catalogue.where((world) => world.id == picks?.feature?.world), ...catalogue.where((world) => world.id != picks?.feature?.world)];

    // No list to draw covers from and nothing begun: Home has only the way to what is on the phone.
    if (catalogue.isEmpty && going.isEmpty) {
      return SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _Head(ink: null, offline: offline),
            Expanded(
              child: items.isEmpty
                  ? EmptyShelf(onAdd: () => addFiles(context, ref))
                  : Center(
                      child: FilledButton(onPressed: () => context.go(Routes.library), child: const Text('Library')),
                    ),
            ),
          ],
        ),
      );
    }

    final worldInHand = going.isEmpty ? null : installed.where((world) => world.id == going.first.worldId).firstOrNull;
    // A file has no world: its own cover is the colour it has.
    final fileCover = going.isEmpty ? null : coverOf(store, going.first);
    final glow = going.isEmpty
        ? (covers.isEmpty ? null : (ref.tallOf(covers.first.startsAt) ?? ref.keyArtOf(covers.first)))
        : libraryPicture(store, worldInHand?.keyArt) ?? (fileCover == null ? null : FileImage(fileCover));
    final goingSpace = media.padding.top + 52 + (fold ? 236 : 169) + 56;
    final glowHeight = going.isEmpty ? 720.0 : goingSpace + 60;

    final fresh = freshParts(catalogue, now);
    ProductionKind kindOf(CatalogueProduction production) =>
        production.music != null ? ProductionKind.ofMusic(production.music!.name) : ProductionKind.ofLine(production.kind);
    final stories = [
      for (final world in catalogue)
        for (final production in world.productions)
          if (kindOf(production).takenAs != TakenAs.music) (world, production),
    ];
    final music = [
      for (final world in catalogue)
        for (final production in world.productions)
          if (kindOf(production).takenAs == TakenAs.music) (world, production),
    ];
    final teasers = [
      for (final world in catalogue)
        if (ref.watch(worldGuideProvider(installedAs(world)?.id ?? world.id)).value case final guide?)
          for (final teaser in guide.guide.teasers) (guide, teaser),
    ];
    // The feed behind Home's Teasers (P23 rule 1): each world's chosen, then its open people and places.
    final feed = teaserFeed([
      for (final world in catalogue)
        if (ref.watch(worldGuideProvider(installedAs(world)?.id ?? world.id)).value case final guide?)
          (world: world, worldId: installedAs(world)?.id ?? world.id, worldPage: pageOf(world), guide: guide),
    ]);
    void openAt(GuideTeaser teaser) {
      final at = feed.indexWhere((page) => identical(page.teaser, teaser));
      if (at >= 0) openFeed(context, feed, at);
    }

    // What the reader has found and not yet opened (P23 rule 7, P23h).
    final opened = ref.watch(settingsProvider).value?.opened ?? const <String>{};
    final found = [
      for (final held in installed)
        if (ref.watch(worldGuideProvider(held.id)).value case final guide? when hasWaiting(guide.guide))
          if (ref.watch(guideReachProvider(held.id)).value case final reach?)
            for (final entry in [...guide.guide.characters, ...guide.guide.places])
              if (isNewEntry(held.id, entry, reach, opened)) (held, guide, entry),
    ];
    final band = discoverBand(catalogue, picks?.band, covers.firstOrNull);
    final wideWidth = rowTileWidth(context);
    final posterWidth = RowSizes.poster(context);
    final smallWidth = RowSizes.small(context);

    /// A production's world page, at the production once it is here. A graphic novel opens its own page
    /// whether or not it is here, with Get (P21 call 35).
    void openProduction(CatalogueWorld world, String? productionId) {
      final held = installedAs(world);
      final page = pageOf(world);
      final there =
          productionId != null &&
          ((held?.productions.any((production) => production.id == productionId) ?? false) ||
              world.productions.any((production) => production.id == productionId && production.comic != null && production.alone != null));
      context.push(there ? Routes.production(page, productionId) : page);
    }

    ImageProvider? tallFor(CatalogueWorld world, CatalogueProduction production) =>
        ref.tallOf(production) ??
        (production.comic == null ? null : ref.watch(comicFirstPageProvider((installedAs(world)?.id ?? world.id, production.id ?? ''))));

    String musicLine(CatalogueWorld world, CatalogueProduction production) {
      final kind = production.music!;
      final held = installedAs(world);
      final heldMusic = held == null ? null : installedProduction(production, held)?.music;
      final of = kind == MusicKind.soundtrack ? soundtrackFor(heldMusic?.forProduction, world: held, listed: world) : null;
      return '${musicKindLabel(kind.name)} · ${of ?? world.name}';
    }

    Widget teaserPoster(WorldGuide guide, GuideTeaser teaser) {
      return switch (teaser) {
        EntryTeaser(entry: final GuideCharacter character) => PosterTile(
          title: character.name,
          kind: 'Character',
          tall: guidePicture(guide, character),
          initials: initials(character.name),
          pictureAlignment: const Alignment(0, -0.6),
          width: smallWidth,
          onOpen: () => openAt(teaser),
        ),
        EntryTeaser(:final entry) => PosterTile(
          title: entryName(entry),
          kind: entry is GuidePlace ? placeKind(entry) : 'Place',
          wide: guidePicture(guide, entry),
          width: smallWidth,
          onOpen: () => openAt(teaser),
        ),
        ClipTeaser(:final title, :final picture, :final duration) => PosterTile(
          title: title,
          kind: 'Clip · ${formatClock(duration)}',
          wide: FileImage(File(guide.pathOf(picture))),
          glyph: Icons.play_arrow_rounded,
          width: smallWidth,
          onOpen: () => openAt(teaser),
        ),
        PictureTeaser(:final title, :final picture) => PosterTile(
          title: title,
          kind: 'Picture',
          wide: FileImage(File(guide.pathOf(picture))),
          width: smallWidth,
          onOpen: () => openAt(teaser),
        ),
        SongTeaser(:final title, :final picture, :final duration) => PosterTile(
          title: title,
          kind: 'Song · ${formatClock(duration)}',
          wide: FileImage(File(guide.pathOf(picture))),
          glyph: Icons.music_note_rounded,
          width: smallWidth,
          onOpen: () => openAt(teaser),
        ),
      };
    }

    Widget worldBand(CatalogueWorld world) {
      final held = installedAs(world);
      final state = ref.watch(installProvider(world.id));
      final page = pageOf(world);
      final guide = ref.watch(worldGuideProvider(held?.id ?? world.id)).value;
      return WorldBand(
        name: world.name,
        meta: [
          titleCount(world.productions.length),
          if (guide != null && guide.guide.characters.isNotEmpty) characterCount(guide.guide.characters.length),
        ].join(' · '),
        keyArt: ref.keyArtOf(world) ?? libraryPicture(store, held?.keyArt),
        logline: world.logline,
        onOpen: () => context.push(page),
        press: switch (state) {
          _ when held != null || !world.installable => null,
          Installing() => BandPress(label: '${(state.fraction * 100).round()}%', progress: state.fraction, onPressed: () => context.push(page)),
          _ => BandPress(
            label: 'Start',
            onPressed: () async {
              if (!await mayOpen(context, ref, world, press: 'Start') || !context.mounted) return;
              await ref.read(installProvider(world.id).notifier).start(world);
            },
          ),
        },
        posters: [
          for (final production in world.productions)
            PosterTile(
              title: production.title,
              kind: kindWords(production.kind),
              tall: tallFor(world, production),
              wide: ref.pictureOf(world, production),
              width: smallWidth,
              onMedia: true,
              mark: kindOf(production),
              onOpen: () => openProduction(world, production.id),
            ),
          if (guide != null)
            for (final character in guide.guide.characters)
              if (character.after == null)
                PosterTile(
                  title: character.name,
                  kind: 'Character',
                  tall: guidePicture(guide, character),
                  initials: initials(character.name),
                  pictureAlignment: const Alignment(0, -0.6),
                  width: smallWidth,
                  onMedia: true,
                  onOpen: () => context.push(Routes.guideEntry(page, character.id)),
                ),
        ],
      );
    }

    final coverRow = SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final (i, world) in covers.indexed) ...[
            if (i > 0) const SizedBox(width: 12),
            WorldCover(world: world, onGlow: going.isEmpty, onOpen: () => context.push(pageOf(world))),
          ],
        ],
      ),
    );
    final newInWorlds = found.isEmpty
        ? null
        : Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SectionHead('New in your worlds'),
              TileRow(
                children: [
                  for (final (held, guide, entry) in found)
                    PosterTile(
                      title: entryName(entry),
                      kind: held.name,
                      tall: entry is GuideCharacter ? guidePicture(guide, entry) : null,
                      wide: entry is GuideCharacter ? null : guidePicture(guide, entry),
                      initials: initials(entryName(entry)),
                      pictureAlignment: const Alignment(0, -0.6),
                      width: smallWidth,
                      fresh: true,
                      onOpen: () => context.push(Routes.guideEntry(Routes.world(held.id), entry.id)),
                    ),
                ],
              ),
            ],
          );
    final newChapters = fresh.isEmpty
        ? null
        : Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SectionHead('New chapters'),
              TileRow(
                children: [
                  for (final item in fresh)
                    ProductionTile(
                      title: item.production?.title ?? item.world.name,
                      kind: '${chaptersLabel(item.part.chapters, episodes: item.episodes)} · ${item.world.name}',
                      picture: ref.pictureOf(item.world, item.production),
                      fresh: releasedThisWeek(item.part, now),
                      width: wideWidth,
                      mark: item.production == null ? null : kindOf(item.production!),
                      onOpen: () => openProduction(item.world, item.part.production),
                    ),
                ],
              ),
            ],
          );

    return AnimatedBuilder(
      animation: _scroll,
      builder: (context, list) {
        final offset = _scroll.hasClients ? _scroll.offset : 0.0;
        return Stack(
          children: [
            Positioned(
              left: 0,
              right: 0,
              top: -offset,
              height: glowHeight,
              child: PictureGlow(picture: glow),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Over the colour the head is in the overlay's ink; as the page passes under it, the
                // theme's, on its ground, so it reads in either theme.
                Container(
                  color: context.surface.background.withValues(alpha: (offset / 160).clamp(0, 1)),
                  padding: EdgeInsets.only(top: media.padding.top),
                  child: _Head(ink: offset > 160 ? null : _fg, offline: offline),
                ),
                Expanded(child: list!),
              ],
            ),
          ],
        );
      },
      child: MediaQuery.removePadding(
        context: context,
        removeTop: true,
        child: ListView(
          controller: _scroll,
          padding: EdgeInsets.only(bottom: 24 + footRoom(context)),
          children: [
            if (going.isNotEmpty) ...[
              const _ContinueHead(),
              SizedBox(
                height: (fold ? 420.0 : 300.0) * 9 / 16,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: going.length,
                  separatorBuilder: (context, index) => const SizedBox(width: 12),
                  itemBuilder: (context, index) => ContinueCard(
                    item: going[index],
                    cover: coverOf(store, going[index]),
                    width: fold ? 420 : 300,
                    fresh: installed.where((world) => world.id == going[index].worldId).any((world) => placeIsNew(world, going[index])),
                    onOpen: () => openItem(context, going[index]),
                  ),
                ),
              ),
              ?newInWorlds,
              ?newChapters,
              if (covers.isNotEmpty) const SectionHead('Worlds'),
              coverRow,
            ] else ...[
              coverRow,
              ?newInWorlds,
              ?newChapters,
            ],
            if (stories.isNotEmpty) ...[
              const SectionHead('Stories'),
              TileRow(
                children: [
                  for (final (world, production) in stories)
                    PosterTile(
                      title: production.title,
                      kind: '${ProductionKind.ofLine(production.kind).label} · ${world.name}',
                      tall: tallFor(world, production),
                      wide: ref.pictureOf(world, production),
                      width: posterWidth,
                      mark: kindOf(production),
                      onOpen: () => openProduction(world, production.id),
                    ),
                ],
              ),
            ],
            if (music.isNotEmpty) ...[
              const SectionHead('Music'),
              TileRow(
                children: [
                  for (final (world, production) in music)
                    SquareTile(
                      title: production.title,
                      kind: musicLine(world, production),
                      picture: ref.pictureOf(world, production),
                      width: RowSizes.square(context),
                      onOpen: () => openProduction(world, production.id),
                    ),
                ],
              ),
            ],
            if (teasers.isNotEmpty) ...[
              const SectionHead('Teasers'),
              TileRow(children: [for (final (guide, teaser) in teasers) teaserPoster(guide, teaser)]),
            ],
            if (band != null) worldBand(band),
          ],
        ),
      ),
    );
  }
}

/// Continue's head sits on the colour, in the overlay's ink whatever the theme.
class _ContinueHead extends StatelessWidget {
  const _ContinueHead();

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 22, 16, 10),
    child: Semantics(
      header: true,
      child: Text('Continue', style: Theme.of(context).textTheme.titleMedium?.copyWith(color: _fg)),
    ),
  );
}

/// Home's head (P22a): the wordmark, small, and Search. With no connection it says so (P25h).
class _Head extends StatelessWidget {
  const _Head({required this.ink, required this.offline});

  /// Null: the theme's.
  final Color? ink;
  final bool offline;

  @override
  Widget build(BuildContext context) {
    final surface = context.surface;
    final color = ink ?? surface.foreground;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 6, 12, 6),
      child: Row(
        children: [
          Semantics(
            header: true,
            label: 'Arke Player',
            child: ExcludeSemantics(
              child: Text(
                'ARKE',
                style: TextStyle(
                  fontFamily: ArkeType.wordmarkFamily,
                  fontWeight: FontWeight.w300,
                  fontSize: ArkeType.sizeLg,
                  letterSpacing: ArkeType.sizeLg * 0.42,
                  color: color,
                  height: 1,
                ),
              ),
            ),
          ),
          const Spacer(),
          if (offline) ...[
            Container(
              height: 28,
              padding: const EdgeInsets.symmetric(horizontal: 10),
              decoration: BoxDecoration(
                color: ink == null ? surface.secondary : color.withValues(alpha: 0.16),
                borderRadius: BorderRadius.circular(ArkeRadius.pill),
              ),
              child: Row(
                children: [
                  Icon(Icons.wifi_off_rounded, size: 14, color: color),
                  const SizedBox(width: 5),
                  Text('Offline', style: Theme.of(context).textTheme.labelMedium?.copyWith(color: color)),
                ],
              ),
            ),
            const SizedBox(width: 8),
          ],
          Semantics(
            button: true,
            label: 'Search',
            child: ExcludeSemantics(
              // Its own Material: Home's colour lies over the Scaffold's, which would hide an Ink's circle.
              child: Material(
                type: MaterialType.transparency,
                child: InkWell(
                  onTap: () => context.go(Routes.search),
                  customBorder: const CircleBorder(),
                  child: Ink(
                    width: ArkeSizes.press,
                    height: ArkeSizes.press,
                    decoration: BoxDecoration(shape: BoxShape.circle, color: ink == null ? surface.secondary : color.withValues(alpha: 0.16)),
                    child: Icon(Icons.search_rounded, size: 22, color: color),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
