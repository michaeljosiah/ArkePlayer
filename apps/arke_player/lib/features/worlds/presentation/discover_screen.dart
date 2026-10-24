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
import 'row_widgets.dart';
import 'world_widgets.dart';

/// Discover (P15a, P15b, P16a – P16g), the second tab: what Arke offers, installed or not (P15
/// rule 1). Under `All · Listen · Watch · Play · Read`, rows of different sizes, each row one size
/// (P16 rule 1): under `All` the feature first (rule 2), then New chapters as wide tiles, Stories as
/// posters (rule 3), the worlds' Teasers as small posters (rule 5), one world's band (rule 6) and the
/// Worlds. A production opens the world's page at it (P15 rule 2); Check for updates is in the head
/// (P13, moved here).
class DiscoverScreen extends ConsumerStatefulWidget {
  const DiscoverScreen({super.key});

  @override
  ConsumerState<DiscoverScreen> createState() => _DiscoverScreenState();
}

/// The data words of a kind line, without its lengths and counts: `Audiobook · Book`.
String kindWords(String kindLine) => kindLine.split(' · ').takeWhile((word) => !word.contains(RegExp(r'\d'))).join(' · ');

class _DiscoverScreenState extends ConsumerState<DiscoverScreen> {
  TakenAs? _kind;

  @override
  Widget build(BuildContext context) {
    final catalogue = (ref.watch(catalogueProvider).value ?? const <CatalogueWorld>[]).where((world) => world.package != null).toList();
    final installed = ref.watch(libraryWorldsProvider).value ?? const <LibraryWorld>[];
    final picks = ref.watch(listPicksProvider).value;
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
    final wideWidth = rowTileWidth(context);
    final posterWidth = RowSizes.poster(context);
    final smallWidth = RowSizes.small(context);
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

    /// The edition and every part since it (SPEC-058 R-50).
    String? sizeOf(CatalogueWorld world) => switch (world.package) {
      final package? => formatBytes(package.byteLength + package.parts.fold<int>(0, (sum, part) => sum + part.byteLength)),
      null => null,
    };

    final everyFresh = freshParts(catalogue, now);
    final fresh = everyFresh.where((fresh) => fresh.production == null || shown(fresh.production!.kind)).toList();
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
    // The feature and the band are drawn under All only (P16 rules 2 and 6).
    final feature = kind == null ? discoverFeature(catalogue, picks?.feature, everyFresh) : null;
    final band = kind == null ? discoverBand(catalogue, picks?.band, feature?.world) : null;
    // An install begun from the feature or the band is refused as on the world's page (P9e).
    for (final world in [?feature?.world, ?band]) {
      ref.listen(installProvider(world.id), (previous, next) {
        if (next is InstallFailed && previous is! InstallFailed && context.mounted) showInstallRefusal(context, ref, world, next.refusal);
      });
    }

    // A small poster has room for what a teaser is, not its world's name too (P16c); it opens into
    // its world all the same (P15 rule 4).
    Widget teaserPoster(CatalogueWorld world, WorldGuide guide, GuideTeaser teaser) {
      final page = Routes.discoverWorld(installedAs(world)?.id ?? world.id);
      return switch (teaser) {
        EntryTeaser(entry: final GuideCharacter character) => PosterTile(
          title: character.name,
          kind: 'Character',
          tall: guidePicture(guide, character),
          initials: initials(character.name),
          pictureAlignment: const Alignment(0, -0.6),
          width: smallWidth,
          onOpen: () => context.push(Routes.guideEntry(page, character.id)),
        ),
        EntryTeaser(:final entry) => PosterTile(
          title: entryName(entry),
          kind: entry is GuidePlace ? placeKind(entry) : 'Place',
          wide: guidePicture(guide, entry),
          width: smallWidth,
          onOpen: () => context.push(Routes.guideEntry(page, entry.id)),
        ),
        ClipTeaser(:final title, :final picture, :final duration) => PosterTile(
          title: title,
          kind: 'Clip · ${formatClock(duration)}',
          wide: FileImage(File(guide.pathOf(picture))),
          glyph: Icons.play_arrow_rounded,
          width: smallWidth,
          onOpen: () => openTeaser(context, world, guide, teaser, worldPage: page),
        ),
        PictureTeaser(:final title, :final picture) => PosterTile(
          title: title,
          kind: 'Picture',
          wide: FileImage(File(guide.pathOf(picture))),
          width: smallWidth,
          onOpen: () => openTeaser(context, world, guide, teaser, worldPage: page),
        ),
      };
    }

    Widget worldCard(CatalogueWorld world, {bool mini = false}) {
      final held = installedAs(world);
      if (held == null) {
        return AvailableCard(world: world, mini: mini, width: mini ? wideWidth : null, onOpen: () => context.push(Routes.discoverWorld(world.id)));
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
        picture: ref.keyArtOf(world) ?? libraryPicture(ref.watch(libraryStoreProvider).value, held.keyArt),
        mini: mini,
        width: mini ? wideWidth : null,
        onOpen: () => context.push(Routes.discoverWorld(held.id)),
      );
      return mini ? card : Padding(padding: const EdgeInsets.fromLTRB(16, 0, 16, 12), child: card);
    }

    /// The feature (rule 2): Install with the size before its world is installed, its progress in
    /// the press's place while it installs, then Play — at the new chapter, when one came.
    Widget featureCard(CatalogueWorld world, CatalogueProduction production) {
      final held = installedAs(world);
      final state = ref.watch(installProvider(world.id));
      final arrived = everyFresh.where((item) => item.world.id == world.id && item.production == production).firstOrNull;
      final chapter = arrived == null ? null : chaptersLabel(arrived.part.chapters, episodes: arrived.episodes);
      final heldProduction = held?.productions.where((item) => item.id == production.id || item.title == production.title).firstOrNull;
      final item = heldProduction?.narration ?? heldProduction?.book;
      return FeatureCard(
        title: production.title,
        meta: [kindWords(production.kind), world.name].where((word) => word.isNotEmpty).join(' · '),
        tall: ref.tallOf(production),
        wide: ref.pictureOf(world, production),
        fresh: arrived != null && releasedThisWeek(arrived.part, now),
        chapter: chapter,
        onOpen: () => openProduction(world, production.id ?? heldProduction?.id),
        press: switch (state) {
          Installing() when held == null => InstallProgress(state: state, onCancel: () => ref.read(installProvider(world.id).notifier).cancel()),
          _ when held != null && item != null => HeroPress(
            icon: Icons.play_arrow_rounded,
            label: 'Play',
            detail: chapter,
            onPressed: () => context.push(Routes.open(item)),
          ),
          _ when held != null || world.package == null => null,
          _ => HeroPress(
            icon: Icons.download_rounded,
            label: 'Install',
            detail: sizeOf(world),
            onPressed: () => ref.read(installProvider(world.id).notifier).start(world),
          ),
        },
      );
    }

    /// The band (rule 6): the world's productions and the characters it shows from the start.
    Widget worldBand(CatalogueWorld world) {
      final held = installedAs(world);
      final state = ref.watch(installProvider(world.id));
      final page = Routes.discoverWorld(held?.id ?? world.id);
      final guide = ref.watch(worldGuideProvider(held?.id ?? world.id)).value;
      return WorldBand(
        name: world.name,
        meta: [if (held != null) 'In Library', productionCount(world.productions.length), if (held == null) ?sizeOf(world)].join(' · '),
        keyArt: ref.keyArtOf(world) ?? libraryPicture(ref.watch(libraryStoreProvider).value, held?.keyArt),
        logline: world.logline,
        onOpen: () => context.push(page),
        press: switch (state) {
          _ when held != null || world.package == null => null,
          Installing() => BandPress(label: '${(state.fraction * 100).round()}%', progress: state.fraction, onPressed: () => context.push(page)),
          _ => BandPress(label: 'Install', onPressed: () => ref.read(installProvider(world.id).notifier).start(world)),
        },
        posters: [
          for (final production in world.productions)
            PosterTile(
              title: production.title,
              kind: kindWords(production.kind),
              tall: ref.tallOf(production),
              wide: ref.pictureOf(world, production),
              width: smallWidth,
              onMedia: true,
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
          LabelChips<TakenAs>(
            options: [for (final taken in TakenAs.values) (taken, taken.label)],
            selected: kind,
            onSelect: (value) => setState(() => _kind = value),
          ),
          Expanded(
            child: ListView(
              padding: EdgeInsets.only(bottom: 24 + footRoom(context)),
              children: [
                if (feature != null) featureCard(feature.world, feature.production),
                if (fresh.isNotEmpty) ...[
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
                        PosterTile(
                          title: production.title,
                          kind: '${ProductionKind.ofLine(production.kind).label} · ${world.name}',
                          tall: ref.tallOf(production),
                          wide: ref.pictureOf(world, production),
                          width: posterWidth,
                          onOpen: () => openProduction(world, production.id),
                        ),
                    ],
                  ),
                ],
                if (teasers.isNotEmpty) ...[
                  const SectionHead('Teasers'),
                  TileRow(children: [for (final (world, guide, teaser) in teasers) teaserPoster(world, guide, teaser)]),
                ],
                if (band != null) worldBand(band),
                if (kind == null && catalogue.isNotEmpty) ...[
                  const SectionHead('Worlds'),
                  if (wide)
                    TileRow(children: [for (final world in catalogue) worldCard(world, mini: true)])
                  else
                    for (final world in catalogue) worldCard(world),
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
                        HeroSecondPress(icon: Icons.public, label: widget.world.name, onPressed: () => Navigator.of(context).pop(true)),
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
