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
import '../../parts/application/parts.dart';
import '../../production/domain/production_kind.dart';
import '../application/discover.dart';
import '../application/guides.dart';
import '../application/worlds.dart';
import 'guide_widgets.dart';
import 'world_widgets.dart';

/// Discover (P15a, P15b, P15l), the second tab: what Arke offers, installed or not (P15 rule 1).
/// Under `All · Listen · Watch · Play · Read`, New chapters, Stories, the worlds' Teasers and the
/// Worlds, every row in the one tile (rule 10). A production's tile names its kind and its world and
/// opens the world's page at it (rule 2); Check for updates is in the head (P13, moved here).
class DiscoverScreen extends ConsumerStatefulWidget {
  const DiscoverScreen({super.key});

  @override
  ConsumerState<DiscoverScreen> createState() => _DiscoverScreenState();
}

class _DiscoverScreenState extends ConsumerState<DiscoverScreen> {
  TakenAs? _kind;

  @override
  Widget build(BuildContext context) {
    final catalogue = (ref.watch(catalogueProvider).value ?? const <CatalogueWorld>[]).where((world) => world.package != null).toList();
    final installed = ref.watch(libraryWorldsProvider).value ?? const <LibraryWorld>[];
    final check = ref.watch(catalogueCheckProvider);
    final status = switch (check) {
      CatalogueCheck.idle => null,
      CatalogueCheck.checking => 'Checking for updates',
      CatalogueCheck.checked => 'Checked',
      CatalogueCheck.failed => 'Couldn’t check for updates',
    };
    // Opening Discover asks Arke's address for its list, at most once a day (P12 rule 1), and
    // fetches each world's guide alone for its teasers, as a world's page does (SPEC-059 R-31).
    ref.watch(catalogueRefreshProvider);
    for (final world in catalogue) {
      if (world.guide != null) ref.watch(guideFetchProvider(world.id));
    }
    final now = ref.watch(clockProvider)();
    final width = rowTileWidth(context);
    final wide = MediaQuery.sizeOf(context).width >= WindowBands.fold;
    final kind = _kind;
    bool shown(String kindLine) => kind == null || ProductionKind.ofLine(kindLine).takenAs == kind;
    LibraryWorld? installedAs(CatalogueWorld world) => installed.where((held) => world.covers(held.id)).firstOrNull;

    /// A production's world page, at the production once it is installed (rule 2).
    void openProduction(CatalogueWorld world, String? productionId) {
      final held = installedAs(world);
      final page = Routes.discoverWorld(held?.id ?? world.id);
      final there = productionId != null && (held?.productions.any((production) => production.id == productionId) ?? false);
      context.push(there ? Routes.production(page, productionId) : page);
    }

    final fresh = freshParts(catalogue, now).where((fresh) => fresh.production == null || shown(fresh.production!.kind)).toList();
    final stories = [
      for (final world in catalogue)
        for (final production in world.productions)
          if (shown(production.kind)) (world, production),
    ];
    final teasers = kind != null
        ? const <(CatalogueWorld, WorldGuide, GuideTeaser)>[]
        : [
            for (final world in catalogue)
              if (ref.watch(worldGuideProvider(installedAs(world)?.id ?? world.id)).value case final guide?)
                for (final teaser in guide.guide.teasers) (world, guide, teaser),
          ];

    Widget teaserTile(CatalogueWorld world, WorldGuide guide, GuideTeaser teaser) {
      final page = Routes.discoverWorld(installedAs(world)?.id ?? world.id);
      return switch (teaser) {
        EntryTeaser(entry: final GuideCharacter character) => ProductionTile(
          title: character.name,
          kind: 'Character · ${world.name}',
          picture: guidePicture(guide, character),
          initials: initials(character.name),
          pictureAlignment: const Alignment(0, -0.6),
          width: width,
          onOpen: () => context.push(Routes.guideEntry(page, character.id)),
        ),
        EntryTeaser(:final entry) => ProductionTile(
          title: entryName(entry),
          kind: '${entry is GuidePlace ? placeKind(entry) : 'Place'} · ${world.name}',
          picture: guidePicture(guide, entry),
          width: width,
          onOpen: () => context.push(Routes.guideEntry(page, entry.id)),
        ),
        ClipTeaser(:final title, :final picture, :final duration) => ProductionTile(
          title: title,
          kind: 'Clip · ${formatClock(duration)} · ${world.name}',
          picture: FileImage(File(guide.pathOf(picture))),
          glyph: Icons.play_arrow_rounded,
          width: width,
          onOpen: () => openTeaser(context, world, guide, teaser, worldPage: page),
        ),
        PictureTeaser(:final title, :final picture) => ProductionTile(
          title: title,
          kind: 'Picture · ${world.name}',
          picture: FileImage(File(guide.pathOf(picture))),
          width: width,
          onOpen: () => openTeaser(context, world, guide, teaser, worldPage: page),
        ),
      };
    }

    Widget worldCard(CatalogueWorld world, {bool mini = false}) {
      final held = installedAs(world);
      if (held == null) {
        return AvailableCard(world: world, mini: mini, width: mini ? width : null, onOpen: () => context.push(Routes.discoverWorld(world.id)));
      }
      // A world updating shows it as an install does (P9 rule 4, P12 rule 4); one with a newer
      // edition carries Update (P12a).
      final update = ref.watch(worldUpdateProvider(held.id));
      final state = ref.watch(installProvider(update?.id ?? held.id));
      final card = WorldCard(
        name: world.name,
        meta: state is Installing
            ? state.short
            : [
                'In Library',
                if (!mini) productionCount(held.productions.length),
                if (!mini)
                  if (ref.watch(worldGuideProvider(held.id)).value?.guide.characters.length case final count? when count > 0) characterCount(count),
              ].join(' · '),
        progress: state is Installing ? state.fraction : null,
        tag: update != null && state is! Installing ? 'Update' : null,
        picture: bundledPicture(world.keyArt) ?? libraryPicture(ref.watch(libraryStoreProvider).value, held.keyArt),
        mini: mini,
        width: mini ? width : null,
        onOpen: () => context.push(Routes.discoverWorld(held.id)),
      );
      return mini ? card : Padding(padding: const EdgeInsets.fromLTRB(16, 0, 16, 12), child: card);
    }

    return SafeArea(
      bottom: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ShelfHeader(
            title: 'Discover',
            trailing: RoundPress(
              icon: Icons.refresh,
              label: 'Check for updates',
              busy: check == CatalogueCheck.checking,
              onPressed: () => ref.read(catalogueCheckProvider.notifier).check(),
            ),
          ),
          if (status != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 6),
              child: Semantics(
                liveRegion: true,
                child: Text(status, style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: context.surface.mutedForeground)),
              ),
            ),
          LabelChips<TakenAs>(options: [for (final taken in TakenAs.values) (taken, taken.label)], selected: kind, onSelect: (value) => setState(() => _kind = value)),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.only(bottom: 24),
              children: [
                if (fresh.isNotEmpty) ...[
                  const SectionHead('New chapters'),
                  TileRow(
                    children: [
                      for (final item in fresh)
                        ProductionTile(
                          title: item.production?.title ?? item.world.name,
                          kind: '${chaptersLabel(item.part.chapters, episodes: item.episodes)} · ${item.world.name}',
                          picture: bundledPicture(item.production?.picture ?? item.world.keyArt),
                          fresh: releasedThisWeek(item.part, now),
                          width: width,
                          onOpen: () => openProduction(item.world, item.part.production),
                        ),
                    ],
                  ),
                ],
                if (stories.isNotEmpty) ...[
                  const SectionHead('Stories'),
                  TileRow(
                    children: [
                      for (final (world, production) in stories)
                        ProductionTile(
                          title: production.title,
                          kind: '${ProductionKind.ofLine(production.kind).label} · ${world.name}',
                          picture: bundledPicture(production.picture ?? world.keyArt),
                          width: width,
                          onOpen: () => openProduction(world, production.id),
                        ),
                    ],
                  ),
                ],
                if (teasers.isNotEmpty) ...[
                  const SectionHead('Teasers'),
                  TileRow(children: [for (final (world, guide, teaser) in teasers) teaserTile(world, guide, teaser)]),
                ],
                if (kind == null && catalogue.isNotEmpty) ...[
                  const SectionHead('Worlds'),
                  if (wide) TileRow(children: [for (final world in catalogue) worldCard(world, mini: true)]) else for (final world in catalogue) worldCard(world),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// A picture or clip teaser, full screen (SPEC-059 R-32): a clip plays with sound; either leads to
/// its world, opened in the tab it was found in.
Future<void> openTeaser(BuildContext context, CatalogueWorld world, WorldGuide guide, GuideTeaser teaser, {required String worldPage}) async {
  final toWorld = await Navigator.of(context, rootNavigator: true).push<bool>(
    MaterialPageRoute<bool>(
      fullscreenDialog: true,
      builder: (_) => TeaserScreen(world: world, guide: guide, teaser: teaser),
    ),
  );
  if (toWorld == true && context.mounted) await context.push(worldPage);
}

class TeaserScreen extends ConsumerStatefulWidget {
  const TeaserScreen({required this.world, required this.guide, required this.teaser, super.key});

  final CatalogueWorld world;
  final WorldGuide guide;
  final GuideTeaser teaser;

  @override
  ConsumerState<TeaserScreen> createState() => _TeaserScreenState();
}

class _TeaserScreenState extends ConsumerState<TeaserScreen> {
  late final TeaserAudio _audio = ref.read(teaserAudioProvider);

  @override
  void initState() {
    super.initState();
    if (widget.teaser case ClipTeaser(:final audio)) _audio.play(widget.guide.pathOf(audio)).catchError((Object _) {});
  }

  @override
  void dispose() {
    _audio.stop().catchError((Object _) {});
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const fg = ArkeColors.mediaOverlayForeground;
    final text = Theme.of(context).textTheme;
    final teaser = widget.teaser as PictureTeaser;
    final line = [
      if (teaser is ClipTeaser) 'Clip · ${formatClock(teaser.duration)}' else 'Picture',
      'Chapter ${teaser.from.number}',
      widget.world.name,
    ].join(' · ');
    return Scaffold(
      backgroundColor: ArkeColors.mediaOverlayBackground,
      body: Stack(
        fit: StackFit.expand,
        children: [
          InteractiveViewer(child: Image.file(File(widget.guide.pathOf(teaser.picture)), fit: BoxFit.contain)),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  GlassPress(icon: Icons.close_rounded, label: 'Close', onPressed: () => Navigator.of(context).pop()),
                  const Spacer(),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(teaser.title, style: text.titleLarge?.copyWith(color: fg)),
                        const SizedBox(height: 2),
                        Text(line, style: text.bodyMedium?.copyWith(color: fg.withValues(alpha: 0.78))),
                        const SizedBox(height: 14),
                        HeroSecondPress(
                          icon: Icons.public,
                          label: widget.world.name,
                          onPressed: () => Navigator.of(context).pop(true),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
