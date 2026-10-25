import 'dart:io';
import 'dart:ui' show ImageFilter;

import 'package:arke_library/arke_library.dart';
import 'package:arke_world/arke_world.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/services.dart';
import '../../../app/theme/tokens.dart';
import '../../worlds/application/guides.dart';
import '../../worlds/application/worlds.dart';
import '../../worlds/presentation/guide_widgets.dart';
import '../application/audio_engine.dart';
import '../application/music.dart';
import '../application/players.dart';
import 'chrome.dart';
import 'music_widgets.dart';

const _fg = ArkeColors.mediaOverlayForeground;
const _bg = ArkeColors.mediaOverlayBackground;

/// A world's music in the audio player (SPEC-058 R-75, P17d): the cover where the moment's picture
/// would be, over its own blur; the track and whose theme it is; the scrubber across the track;
/// shuffle, previous, play, next and repeat; then `Lyrics` when the track has words, `Tracks`, and
/// the chapter it is heard in, which opens there. Lyrics (R-76, P17e) are the words as written over
/// the dimmed cover, scrolled by hand: not timed to the song (call 19).
///
/// [track] starts the album there in order (Play all is track 0) and [shuffle] in a shuffled order;
/// with neither, as the dock opens it, the screen shows what plays.
class MusicPlayerScreen extends ConsumerStatefulWidget {
  const MusicPlayerScreen({required this.worldId, required this.productionId, this.track, this.shuffle = false, super.key});

  final String worldId;
  final String productionId;
  final int? track;
  final bool shuffle;

  @override
  ConsumerState<MusicPlayerScreen> createState() => _MusicPlayerScreenState();
}

class _MusicPlayerScreenState extends ConsumerState<MusicPlayerScreen> {
  bool _started = false;
  bool _lyrics = false;

  /// Starts the album as the press that opened the screen asked, once it is read; after the frame,
  /// so the engine's news never lands mid-build.
  void _start(AudioEngine engine, MusicAlbum album) {
    if (_started) return;
    _started = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (widget.shuffle) {
        engine.openMusic(album, shuffle: true);
      } else if (widget.track != null) {
        engine.openMusic(album, index: widget.track!.clamp(0, album.tracks.length - 1), shuffle: false);
      } else if (engine.music?.id != album.id) {
        engine.openMusic(album, shuffle: false);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final engine = ref.watch(audioEngineProvider);
    final album = ref.watch(musicAlbumProvider((widget.worldId, widget.productionId))).value;
    if (engine == null || album == null) {
      return Scaffold(
        backgroundColor: _bg,
        appBar: AppBar(backgroundColor: Colors.transparent, foregroundColor: _fg),
        body: const Center(child: CircularProgressIndicator(color: _fg)),
      );
    }
    _start(engine, album);
    return StreamBuilder<int?>(
      stream: engine.trackStream,
      builder: (context, _) {
        final index = engine.music?.id == album.id ? engine.track : 0;
        return _body(context, engine, album, index);
      },
    );
  }

  Widget _body(BuildContext context, AudioEngine engine, MusicAlbum album, int index) {
    final track = album.tracks[index];
    final world = ref.watch(installedWorldProvider(widget.worldId));
    final guide = ref.watch(worldGuideProvider(album.worldId)).value?.guide;
    final reach = ref.watch(guideReachProvider(album.worldId)).value ?? GuideReach.none;
    final items = {for (final item in ref.watch(libraryItemsProvider).value ?? const <LibraryItem>[]) item.id: item};
    final listed = listedFor(ref.watch(catalogueProvider).value ?? const [], album.worldId);
    final theme = themeEntry(guide, reach, album.production.id, track.id);
    final heard = [for (final heard in track.heardIn) ?heardPlace(heard, world: world, items: items, listed: listed, guide: guide)];
    final opens = heard.where((place) => place.opens && place.number != null).firstOrNull;
    final line = theme != null ? 'Theme · ${entryName(theme)}' : (heard.firstOrNull?.line ?? album.worldName);
    final words = track.lyrics?.text.trim().isNotEmpty ?? false;
    final lyrics = _lyrics && words;
    final cover = album.cover == null ? null : FileImage(File(album.cover!));

    return Scaffold(
      backgroundColor: _bg,
      body: Stack(
        fit: StackFit.expand,
        children: [
          if (cover != null)
            ClipRect(
              child: ImageFiltered(
                imageFilter: ImageFilter.blur(sigmaX: 36, sigmaY: 36, tileMode: TileMode.clamp),
                child: Transform.scale(
                  scale: 1.35,
                  child: ColorFiltered(
                    colorFilter: _darker,
                    child: Image(image: cover, fit: BoxFit.cover),
                  ),
                ),
              ),
            ),
          ColoredBox(color: _bg.withValues(alpha: lyrics ? 0.5 : 0.3)),
          SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                PlayerTop(eyebrow: album.title, title: '${index + 1} of ${album.tracks.length}'),
                Expanded(
                  child: lyrics
                      ? _Lyrics(text: track.lyrics!.text)
                      : LayoutBuilder(
                          builder: (context, box) {
                            final side = (box.maxWidth - 64).clamp(120.0, box.maxHeight - 24).clamp(120.0, 520.0);
                            return Align(
                              alignment: Alignment.topCenter,
                              child: Padding(
                                padding: const EdgeInsets.only(top: 16),
                                child: Container(
                                  width: side,
                                  height: side,
                                  clipBehavior: Clip.antiAlias,
                                  decoration: BoxDecoration(
                                    color: ArkeColors.neutral800,
                                    borderRadius: BorderRadius.circular(ArkeRadius.xl),
                                    boxShadow: const [BoxShadow(color: Color(0x80000000), blurRadius: 50, offset: Offset(0, 24))],
                                  ),
                                  child: cover == null ? const Icon(Icons.music_note_rounded, color: _fg, size: 48) : Image(image: cover, fit: BoxFit.cover),
                                ),
                              ),
                            );
                          },
                        ),
                ),
                Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 640),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            track.title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(color: _fg, fontSize: lyrics ? ArkeType.sizeLg : ArkeType.size2xl, fontWeight: FontWeight.w700, height: 1.15),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            line,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(color: _fg.withValues(alpha: 0.74), fontSize: ArkeType.sizeSm, fontWeight: FontWeight.w500),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                _transport(context, engine, album, opens: opens, words: words, lyrics: lyrics),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// The cover's blur, darkened and fuller as the design's is: saturate 150%, brightness 50%.
  static const _darker = ColorFilter.matrix([
    0.72, 0.25, 0.03, 0, 0, //
    0.11, 0.86, 0.03, 0, 0, //
    0.11, 0.25, 0.64, 0, 0, //
    0, 0, 0, 1, 0,
  ]);

  Widget _transport(BuildContext context, AudioEngine engine, MusicAlbum album, {required HeardPlace? opens, required bool words, required bool lyrics}) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 640),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
          child: StreamBuilder<Duration>(
            stream: engine.position,
            builder: (context, snapshot) {
              final position = engine.music?.id == album.id ? (snapshot.data ?? engine.now) : Duration.zero;
              final (start, end) = engine.music?.id == album.id ? engine.chapterBounds(position) : (Duration.zero, album.tracks.first.duration);
              return Column(
                children: [
                  Scrubber(position: position - start, length: end - start, onSeek: (offset) => engine.seek(start + offset)),
                  const SizedBox(height: 14),
                  StreamBuilder<bool>(
                    stream: engine.playingStream,
                    initialData: engine.playing,
                    builder: (context, playing) => Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        StreamBuilder<bool>(
                          stream: engine.shuffleStream,
                          initialData: engine.shuffling,
                          builder: (context, on) =>
                              PlayerPress(icon: Icons.shuffle_rounded, label: 'Shuffle', on: on.data ?? false, size: 20, onPressed: engine.toggleShuffle),
                        ),
                        PlayerPress(icon: Icons.skip_previous_rounded, label: 'Previous', onPressed: engine.skipToPrevious),
                        PlayPause(playing: playing.data ?? false, onPressed: () => (playing.data ?? false) ? engine.pause() : engine.play()),
                        PlayerPress(icon: Icons.skip_next_rounded, label: 'Next', onPressed: engine.skipToNext),
                        StreamBuilder<Object?>(
                          stream: engine.repeatStream,
                          builder: (context, _) => PlayerPress(
                            icon: engine.repeat == MusicRepeat.one ? Icons.repeat_one_rounded : Icons.repeat_rounded,
                            label: engine.repeat.label,
                            on: engine.repeat != MusicRepeat.off,
                            size: 20,
                            onPressed: engine.cycleRepeat,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  Wrap(
                    alignment: WrapAlignment.center,
                    spacing: 10,
                    children: [
                      if (words) PlayerLabelPress(label: 'Lyrics', icon: Icons.notes_rounded, on: lyrics, onPressed: () => setState(() => _lyrics = !_lyrics)),
                      PlayerLabelPress(label: 'Tracks', icon: Icons.format_list_bulleted, onPressed: () => _tracks(context, engine, album)),
                      if (opens != null)
                        PlayerLabelPress(
                          label: 'Chapter ${opens.number}',
                          icon: Icons.menu_book_rounded,
                          onPressed: () => openHeard(context, ref, opens, replace: true),
                        ),
                    ],
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  /// Tracks (P17d, as Chapters is P5b): each its number, title and length, the playing one marked.
  Future<void> _tracks(BuildContext context, AudioEngine engine, MusicAlbum album) => showPlayerSheet<void>(
    context,
    title: 'Tracks',
    count: '${album.tracks.length}',
    builder: (context) {
      final playing = engine.music?.id == album.id ? engine.track : -1;
      return ListView.builder(
        shrinkWrap: true,
        itemCount: album.tracks.length,
        itemBuilder: (context, index) {
          final track = album.tracks[index];
          final now = index == playing;
          return Material(
            color: now ? _fg.withValues(alpha: 0.08) : Colors.transparent,
            child: InkWell(
              onTap: () {
                engine.openMusic(album, index: index);
                Navigator.of(context).pop();
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(
                  children: [
                    SizedBox(
                      width: 26,
                      child: now
                          ? const Icon(Icons.equalizer_rounded, size: 18, color: _fg)
                          : Text(
                              '${index + 1}',
                              style: TextStyle(color: _fg.withValues(alpha: 0.56), fontSize: ArkeType.sizeSm),
                            ),
                    ),
                    Expanded(
                      child: Text(
                        track.title,
                        style: TextStyle(color: _fg, fontSize: ArkeType.sizeBase, fontWeight: now ? FontWeight.w600 : FontWeight.w500),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      formatClock(track.duration),
                      style: TextStyle(color: _fg.withValues(alpha: 0.62), fontSize: ArkeType.size2xs),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      );
    },
  );
}

/// The words as written (P17e): by stanza, the structure tags left out, scrolled by hand and faded
/// at their foot, where the track's title sits.
class _Lyrics extends StatelessWidget {
  const _Lyrics({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) => ShaderMask(
    shaderCallback: (bounds) => const LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [Color(0xFF000000), Color(0xFF000000), Color(0x00000000)],
      stops: [0, 0.78, 1],
    ).createShader(bounds),
    blendMode: BlendMode.dstIn,
    child: SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 18, 24, 48),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final stanza in lyricStanzas(text))
                Padding(
                  padding: const EdgeInsets.only(bottom: 18),
                  child: Text(
                    stanza,
                    style: const TextStyle(color: _fg, fontSize: ArkeType.sizeXl, fontWeight: FontWeight.w600, height: 1.45, letterSpacing: -0.2),
                  ),
                ),
            ],
          ),
        ),
      ),
    ),
  );
}
