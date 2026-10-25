import 'dart:ui' show ImageFilter;

import 'package:arke_library/arke_library.dart';
import 'package:arke_world/arke_world.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/routes.dart';
import '../../../app/services.dart';
import '../../../app/theme/tokens.dart';
import '../../../app/widgets/shelf.dart';
import '../../players/application/music.dart';
import '../../players/application/players.dart';
import '../../players/presentation/music_widgets.dart';
import '../application/guides.dart';
import '../application/worlds.dart';
import 'guide_widgets.dart';
import 'row_widgets.dart';
import 'world_screen.dart';
import 'world_widgets.dart';

const _fg = ArkeColors.mediaOverlayForeground;
const _bg = ArkeColors.mediaOverlayBackground;

/// An album's page, a single's or a soundtrack's (SPEC-058 R-74, P17c, P17h): the cover over its own
/// blur, the title, `Album · The Undersong · 9 tracks · 34 min` — a soundtrack names what it is for
/// in the world's place — then `Play all` and `Shuffle`. Then the tracks, numbered, each with its
/// length and at most one line: whose theme it is, or where it is heard; the one playing shows bars.
/// On a Fold the cover sits beside the title and the tracks run in two columns. Under them, `More
/// from` the world: its other music. A newer package in Arke's list is its `Update` (R-72).
///
/// A track pressed plays where it is, the page staying under the dock; Play all and Shuffle open
/// the player, as Play does for a story.
class AlbumScreen extends ConsumerWidget {
  const AlbumScreen({required this.world, required this.production, required this.worldLocation, super.key});

  final LibraryWorld world;
  final LibraryProduction production;

  /// The world page's path, which the world's other music opens under.
  final String worldLocation;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final music = production.music!;
    final album = ref.watch(musicAlbumProvider((world.id, production.id))).value;
    final engine = ref.watch(audioEngineProvider);
    final store = ref.watch(libraryStoreProvider).value;
    final guide = ref.watch(worldGuideProvider(world.id)).value?.guide;
    final reach = ref.watch(guideReachProvider(world.id)).value ?? GuideReach.none;
    final items = {for (final item in ref.watch(libraryItemsProvider).value ?? const <LibraryItem>[]) item.id: item};
    final listed = listedFor(ref.watch(catalogueProvider).value ?? const [], world.id);
    final key = (world.id, production.id);
    final update = ref.watch(productionUpdateProvider(key));
    final state = ref.watch(productionInstallProvider(key));
    ref.listen(productionInstallProvider(key), (previous, next) {
      if (next is InstallFailed && previous is! InstallFailed && listed != null && update != null) {
        showInstallRefusal(context, ref, listed, next.refusal, updating: true, production: update);
      }
    });
    final fold = MediaQuery.sizeOf(context).width >= WindowBands.fold;
    final cover = libraryPicture(store, production.picture);
    final meta = musicMeta(
      music.kind,
      of: music.kind == 'soundtrack' ? soundtrackFor(music.forProduction, world: world, listed: listed, guide: guide) ?? world.name : world.name,
      tracks: music.tracks,
      length: music.duration,
    );
    final others = [
      for (final other in world.productions)
        if (other.music != null && other.id != production.id) other,
    ];

    void play({int track = 0, bool shuffle = false}) => context.push(Routes.music(world.id, production.id, track: shuffle ? null : track, shuffle: shuffle));

    String? lineOf(MusicTrack track) {
      if (themeEntry(guide, reach, production.id, track.id) case final entry?) return 'Theme · ${entryName(entry)}';
      for (final heard in track.heardIn) {
        if (heardPlace(heard, world: world, items: items, listed: listed, guide: guide) case final place?) return place.line;
      }
      return null;
    }

    Future<void> more(MusicAlbum album, int index) async {
      final track = album.tracks[index];
      final places = [
        for (final heard in track.heardIn) ?heardPlace(heard, world: world, items: items, listed: listed, guide: guide),
      ].where((place) => place.opens);
      final theme = themeEntry(guide, reach, production.id, track.id);
      await showArkeSheet<void>(
        context,
        title: track.title,
        builder: (sheet) => Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.play_arrow_rounded),
              title: const Text('Play'),
              onTap: () {
                Navigator.of(sheet).pop();
                engine?.openMusic(album, index: index);
              },
            ),
            for (final place in places)
              ListTile(
                leading: const Icon(Icons.menu_book_rounded),
                title: Text(place.line),
                onTap: () {
                  Navigator.of(sheet).pop();
                  openHeard(context, ref, place);
                },
              ),
            if (theme != null)
              ListTile(
                leading: const Icon(Icons.person_outline_rounded),
                title: Text('Theme · ${entryName(theme)}'),
                onTap: () {
                  Navigator.of(sheet).pop();
                  context.push(Routes.guideEntry(worldLocation, theme.id));
                },
              ),
          ],
        ),
      );
    }

    Widget tracks(MusicAlbum album) => StreamBuilder<int?>(
      stream: engine?.trackStream,
      builder: (context, _) {
        final playing = engine?.music?.id == album.id ? engine!.track : -1;
        Widget row(int index) => TrackRow(
          number: index + 1,
          title: album.tracks[index].title,
          line: lineOf(album.tracks[index]),
          length: album.tracks[index].duration,
          now: index == playing,
          onPlay: () => engine?.openMusic(album, index: index),
          onMore: () => more(album, index),
        );
        if (!fold) return Column(children: [for (var i = 0; i < album.tracks.length; i++) row(i)]);
        // Two columns, the first half down the left as the design's columns flow (P17h).
        final half = (album.tracks.length + 1) ~/ 2;
        return Padding(
          padding: const EdgeInsets.fromLTRB(8, 12, 8, 0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: Column(children: [for (var i = 0; i < half; i++) row(i)])),
              const SizedBox(width: 24),
              Expanded(child: Column(children: [for (var i = half; i < album.tracks.length; i++) row(i)])),
            ],
          ),
        );
      },
    );

    return Scaffold(
      body: ScrolledHead(
        title: production.title,
        child: ListView(
          padding: EdgeInsets.only(bottom: footRoom(context)),
          children: [
            _Head(
              cover: cover,
              title: production.title,
              meta: meta,
              fold: fold,
              presses: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: _Press(icon: Icons.play_arrow_rounded, label: 'Play all', primary: true, onPressed: album == null ? null : play),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _Press(icon: Icons.shuffle_rounded, label: 'Shuffle', onPressed: album == null ? null : () => play(shuffle: true)),
                      ),
                    ],
                  ),
                  switch (state) {
                    Installing() => InstallProgress(state: state, onCancel: () => ref.read(productionInstallProvider(key).notifier).cancel()),
                    _ when update != null && listed != null => HeroSecondPress(
                      icon: Icons.download_rounded,
                      label: 'Update',
                      detail: formatBytes(update.package!.byteLength),
                      onPressed: () => ref.read(productionInstallProvider(key).notifier).start(listed, update),
                    ),
                    _ => const SizedBox.shrink(),
                  },
                ],
              ),
            ),
            if (album != null) tracks(album),
            if (others.isNotEmpty) ...[
              SectionHead('More from ${world.name}'),
              TileRow(
                children: [
                  for (final other in others)
                    SquareTile(
                      title: other.title,
                      kind: musicTileKind(other.music!.kind, tracks: other.music!.tracks, length: other.music!.duration),
                      picture: libraryPicture(store, other.picture ?? world.keyArt),
                      width: RowSizes.square(context),
                      onOpen: () => context.push(Routes.production(worldLocation, other.id)),
                    ),
                ],
              ),
            ],
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}

/// The head (P17c, P17h): the cover over its own blur, darkened, on the media colours whatever the
/// theme; back at its top. On a phone the cover is 220 and centred over the words; on a Fold 320
/// beside them, the words at its foot.
class _Head extends StatelessWidget {
  const _Head({required this.cover, required this.title, required this.meta, required this.fold, required this.presses});

  final ImageProvider? cover;
  final String title;
  final String meta;
  final bool fold;
  final Widget presses;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final top = MediaQuery.paddingOf(context).top;
    final side = fold ? 320.0 : 220.0;
    final art = Container(
      width: side,
      height: side,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: ArkeColors.neutral800,
        borderRadius: BorderRadius.circular(12),
        boxShadow: const [BoxShadow(color: Color(0x73000000), blurRadius: 40, offset: Offset(0, 18))],
      ),
      child: cover == null ? const Icon(Icons.music_note_rounded, color: _fg, size: 48) : Image(image: cover!, fit: BoxFit.cover),
    );
    final heading = Semantics(
      header: true,
      child: Text(
        title,
        textAlign: fold ? TextAlign.start : TextAlign.center,
        style: text.headlineMedium?.copyWith(color: _fg, fontWeight: FontWeight.w700, fontSize: ArkeType.size2xl, height: 1.15, letterSpacing: -0.5),
      ),
    );
    final line = Text(
      meta,
      textAlign: fold ? TextAlign.start : TextAlign.center,
      style: text.bodyMedium?.copyWith(color: _fg.withValues(alpha: 0.74), fontFeatures: const [FontFeature.tabularFigures()]),
    );
    return ClipRect(
      child: Stack(
        children: [
          const Positioned.fill(child: ColoredBox(color: _bg)),
          if (cover != null)
            Positioned.fill(
              child: ImageFiltered(
                imageFilter: ImageFilter.blur(sigmaX: 30, sigmaY: 30, tileMode: TileMode.clamp),
                child: Transform.scale(
                  scale: 1.3,
                  child: ColorFiltered(
                    colorFilter: _darker,
                    child: Image(image: cover!, fit: BoxFit.cover),
                  ),
                ),
              ),
            ),
          Padding(
            padding: fold ? EdgeInsets.fromLTRB(32, top + 64, 32, 28) : EdgeInsets.fromLTRB(16, top + 56, 16, 20),
            child: fold
                ? Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      art,
                      const SizedBox(width: 32),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            heading,
                            const SizedBox(height: 5),
                            line,
                            const SizedBox(height: 16),
                            ConstrainedBox(constraints: const BoxConstraints(maxWidth: 360), child: presses),
                          ],
                        ),
                      ),
                    ],
                  )
                : Column(children: [art, const SizedBox(height: 18), heading, const SizedBox(height: 5), line, const SizedBox(height: 16), presses]),
          ),
          Positioned(
            left: 12,
            top: top + 8,
            child: context.canPop() ? GlassPress(icon: Icons.chevron_left_rounded, label: 'Back', onPressed: () => context.pop()) : const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }

  /// Saturate 140%, brightness 55%, as the design's blur is.
  static const _darker = ColorFilter.matrix([
    0.77, 0.21, 0.02, 0, 0, //
    0.11, 0.85, 0.02, 0, 0, //
    0.11, 0.21, 0.66, 0, 0, //
    0, 0, 0, 1, 0,
  ]);
}

/// `Play all`, in the overlay's ink, and `Shuffle` in its quiet fill: 44 high, round.
class _Press extends StatelessWidget {
  const _Press({required this.icon, required this.label, required this.onPressed, this.primary = false});

  final IconData icon;
  final String label;
  final VoidCallback? onPressed;
  final bool primary;

  @override
  Widget build(BuildContext context) => FilledButton.icon(
    onPressed: onPressed,
    icon: Icon(icon, size: 18),
    label: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
    style: FilledButton.styleFrom(
      minimumSize: const Size.fromHeight(ArkeSizes.press),
      backgroundColor: primary ? _fg : _fg.withValues(alpha: 0.16),
      foregroundColor: primary ? _bg : _fg,
      textStyle: const TextStyle(fontFamily: ArkeType.family, fontSize: ArkeType.sizeBase, fontWeight: FontWeight.w500),
    ),
  );
}
