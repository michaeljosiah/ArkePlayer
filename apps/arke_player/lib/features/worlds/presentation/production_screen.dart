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
import '../../comics/presentation/comic_production_screen.dart';
import '../../players/application/music.dart';
import '../../players/application/players.dart';
import '../../players/presentation/music_widgets.dart';
import '../../stories/presentation/story_production_screen.dart';
import '../application/discover.dart';
import '../application/guides.dart';
import '../application/worlds.dart';
import 'album_screen.dart';
import 'guide_widgets.dart';
import 'world_screen.dart';
import 'world_widgets.dart';

/// The author's schedule as written (SPEC-058 R-53, P15e, P15f): `Fridays`, `Daily`,
/// `Mondays · Next 26 Oct`; a `Next` that has passed is dropped, so nothing shown is stale.
String? scheduleLine(WorldSchedule? schedule, DateTime now) {
  if (schedule == null) return null;
  final day = switch (schedule.day) {
    null => null,
    ScheduleDay.daily => 'Daily',
    final ScheduleDay day => '${day.name[0].toUpperCase()}${day.name.substring(1)}s',
  };
  final next = upcoming(schedule, now);
  final line = [?day, if (next != null) 'Next ${shortDate(next)}'].join(' · ');
  return line.isEmpty ? null : line;
}

/// The schedule's next date, unless it has passed.
DateTime? upcoming(WorldSchedule? schedule, DateTime now) {
  final next = schedule?.next;
  return next == null || next.isBefore(DateTime.utc(now.year, now.month, now.day)) ? null : next;
}

/// `30 Oct`.
String shortDate(DateTime day) => '${day.day} ${const ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'][day.month - 1]}';

/// A production of an installed world: P1e's show page, for what the MVP's players open. The
/// picture, the title, one meta line and the author's schedule (P15e), then `Play` — or `Continue ·
/// Chapter 3 · 12:04` when this device holds a place — with `Read` beside it for a book with its
/// narration (P9 rule 7), and the narration's Chapters: each its length and, for one that came in a
/// part, its day; `New` until it plays (R-52); heard ones ticked; the author's next date as a dashed
/// last row (R-53). A book released in parts reads as one: Read opens the part being read, or the
/// first not finished (R-50). What P1e draws for shares (the download and its size) is absent.
///
/// The world's music heard in the production follows its chapters as its **Music**, and a chapter
/// that holds a song carries a note (SPEC-058 R-77, P17g). A music production's page is its album's
/// (R-74).
class ProductionScreen extends ConsumerWidget {
  const ProductionScreen({required this.worldId, required this.productionId, required this.worldLocation, super.key});

  final String worldId;
  final String productionId;

  /// The world page's path, which this page is pushed under.
  final String worldLocation;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Through a world's old id too (SPEC-058 R-30): a link from before it was updated still opens it.
    final world = ref.watch(installedWorldProvider(worldId));
    final production = world?.productions.where((production) => production.id == productionId).firstOrNull;
    final store = ref.watch(libraryStoreProvider).value;
    final items = {for (final item in ref.watch(libraryItemsProvider).value ?? const <LibraryItem>[]) item.id: item};
    if (world == null || production == null) {
      return Scaffold(
        appBar: AppBar(),
        body: const Center(child: Text('Removed')),
      );
    }
    if (production.music != null) return AlbumScreen(world: world, production: production, worldLocation: worldLocation);
    if (production.story != null) return StoryProductionScreen(world: world, production: production);
    if (production.comic != null) return ComicProductionScreen(world: world, production: production);
    final narration = items[production.narration];
    // A book released in parts reads as one: the part being read, else the first not finished.
    final books = [?items[production.book], for (final id in production.bookParts) ?items[id]];
    final book =
        books
            .where((book) => book.inProgress)
            .fold<LibraryItem?>(null, (latest, book) => latest == null || book.place!.updatedAt.isAfter(latest.place!.updatedAt) ? book : latest) ??
        books.where((book) => !book.finished).firstOrNull ??
        books.firstOrNull;
    final kind = productionKind(book: book != null, narration: narration != null, length: narration?.duration);
    final first = narration ?? book;
    final now = ref.watch(clockProvider)();
    final listed = listedFor(ref.watch(catalogueProvider).value ?? const [], world.id);
    final schedule = listed?.productions.where((listed) => listed.id == production.id).firstOrNull?.schedule;
    // The chapter the next date brings, by the author's numbering: after the last one a part named.
    final lastNamed = [
      for (final part in listed?.package?.parts ?? const <CataloguePart>[])
        if (part.production == production.id) ...part.chapters.map((chapter) => chapter.number),
    ].fold<int?>(null, (most, number) => most == null || number > most ? number : most);
    final scheduled = scheduleLine(schedule, now);
    final next = upcoming(schedule, now);
    final fresh = newChapters(world, production.id, narration);
    // The day each chapter that came in a part was released: its part's label.
    final released = <int, String>{};
    if (narration != null) {
      final parts = world.parts.where((part) => part.production == production.id).toList();
      var index = narration.chapters.length - parts.fold<int>(0, (sum, part) => sum + part.chapters.length);
      for (final part in parts) {
        for (final _ in part.chapters) {
          if (parseDay(part.edition.length >= 10 ? part.edition.substring(0, 10) : part.edition) case final day?) released[index] = shortDate(day);
          index++;
        }
      }
    }

    void open(LibraryItem item) => context.push(Routes.open(item.id));
    // The world's music heard here, in album order (R-77), and the chapters that hold a song.
    final heard = tracksHeardIn(ref.watch(worldMusicProvider(world.id)).value ?? const [], production.id);
    final songChapters = {for (final song in heard) song.heard.chapter};
    final engine = ref.watch(audioEngineProvider);
    final guide = ref.watch(worldGuideProvider(world.id)).value?.guide;

    return Scaffold(
      // Its chapters and its music run long: once the hero has gone, a head says whose they are (P17g).
      body: ScrolledHead(
        title: production.title,
        child: ListView(
          padding: EdgeInsets.only(bottom: footRoom(context)),
          children: [
            WorldHero(
              picture: libraryPicture(store, production.picture ?? narration?.cover ?? book?.cover ?? world.keyArt),
              title: production.title,
              meta: [kind, ?production.author].join(' · '),
              child: first == null && scheduled == null
                  ? null
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (scheduled != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Row(
                              children: [
                                const Icon(Icons.calendar_today_outlined, size: 15, color: ArkeColors.mediaOverlayForeground),
                                const SizedBox(width: 6),
                                Text(
                                  scheduled,
                                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: ArkeColors.mediaOverlayForeground.withValues(alpha: 0.74)),
                                ),
                              ],
                            ),
                          ),
                        if (first != null)
                          HeroPress(
                            icon: Icons.play_arrow_rounded,
                            label: first.inProgress ? 'Continue' : (narration != null ? 'Play' : 'Read'),
                            detail: first.inProgress ? _where(first) : null,
                            onPressed: () => open(first),
                          ),
                        if (narration != null && book != null) HeroSecondPress(icon: Icons.menu_book_rounded, label: 'Read', onPressed: () => open(book)),
                      ],
                    ),
            ),
            if (narration != null && (narration.chapters.length > 1 || next != null)) ...[
              const SectionHead('Chapters'),
              for (final (i, chapter) in narration.chapters.indexed)
                _ChapterRow(
                  number: i + 1,
                  title: chapter.title,
                  length: _chapterLength(narration, i),
                  day: released[i],
                  song: songChapters.contains(chapter.id),
                  fresh: fresh.contains(i),
                  heard: narration.finished || (narration.inProgress && (_chapterAt(narration) ?? 0) > i),
                  current: _chapterAt(narration) == i && narration.inProgress,
                  // A chapter is an explicit seek, not a saved-place update that an already
                  // loaded player can ignore. The engine keeps the selected chapter after seeking.
                  onOpen: () => context.push(Routes.open(narration.id, startAt: chapter.start)),
                ),
              if (next != null)
                _ChapterRow.soon(number: narration.chapters.length + 1, chapter: (lastNamed ?? narration.chapters.length) + 1, day: shortDate(next)),
            ],
            if (heard.isNotEmpty) ...[
              CountHead(title: 'Music', count: heard.length),
              for (final song in heard)
                SongRow(
                  title: song.album.tracks[song.track].title,
                  line: [
                    if (heardPlace(song.heard, world: world, items: items, guide: guide)?.number case final number?) 'Chapter $number',
                    if (song.album.document.kind == MusicKind.single) 'Single' else song.album.title,
                  ].join(' · '),
                  cover: song.album.cover == null ? null : FileImage(File(song.album.cover!)),
                  onPlay: engine == null ? null : () => engine.openMusic(song.album, index: song.track),
                  onOpen: () => context.push(Routes.production(worldLocation, song.album.production.id)),
                ),
            ],
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  /// `Chapter 3 · 12:04` for narration, the time into its chapter; nothing for a book.
  static String? _where(LibraryItem item) {
    final position = item.position;
    if (position == null) return null;
    final index = _chapterAt(item);
    if (index == null) return formatClock(position);
    return 'Chapter ${index + 1} · ${formatClock(position - item.chapters[index].start)}';
  }

  static int? _chapterAt(LibraryItem item) {
    final position = item.position;
    if (position == null || item.chapters.isEmpty) return null;
    var index = 0;
    for (final (i, chapter) in item.chapters.indexed) {
      if (chapter.start <= position) index = i;
    }
    return index;
  }

  static Duration? _chapterLength(LibraryItem item, int index) {
    final end = index + 1 < item.chapters.length ? item.chapters[index + 1].start : item.duration;
    return end == null ? null : end - item.chapters[index].start;
  }
}

/// A chapter's row (P5b's grammar on the shelves, P15e): its number, its title, and under it `New`
/// and its length and day as data; ticked once heard. The author's next date is the last row,
/// dashed and quiet, `Chapter 4 · 30 Oct`, which opens nothing (R-53).
class _ChapterRow extends StatelessWidget {
  const _ChapterRow({
    required this.number,
    required this.title,
    required this.length,
    required this.current,
    required this.onOpen,
    this.day,
    this.fresh = false,
    this.heard = false,
    this.song = false,
  }) : soon = false;

  const _ChapterRow.soon({required this.number, required int chapter, required this.day})
    : title = 'Chapter $chapter',
      length = null,
      current = false,
      onOpen = null,
      fresh = false,
      heard = false,
      song = false,
      soon = true;

  final int number;
  final String title;
  final Duration? length;
  final String? day;
  final bool current;
  final bool fresh;
  final bool heard;
  final bool soon;

  /// The chapter holds a song of the world's music: a note after its data (P17g).
  final bool song;
  final VoidCallback? onOpen;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final muted = context.surface.mutedForeground;
    final data = [if (length != null) formatClock(length!), ?day].join(' · ');
    final row = ConstrainedBox(
      constraints: const BoxConstraints(minHeight: ArkeSizes.press + 14),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          children: [
            SizedBox(
              width: 28,
              child: Text('$number', style: text.bodyMedium?.copyWith(color: muted)),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: text.bodyMedium?.copyWith(
                      fontSize: ArkeType.sizeBase,
                      fontWeight: current ? FontWeight.w600 : FontWeight.w500,
                      color: soon ? muted : null,
                    ),
                  ),
                  if (fresh || data.isNotEmpty || song) ...[
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        if (fresh) ...[const NewTag(), const SizedBox(width: 8)],
                        if (data.isNotEmpty) Text(data, style: text.labelSmall?.copyWith(color: muted)),
                        if (song) ...[const SizedBox(width: 5), Icon(Icons.music_note_rounded, size: 13, color: muted)],
                      ],
                    ),
                  ],
                ],
              ),
            ),
            if (soon)
              Icon(Icons.calendar_today_outlined, size: 20, color: muted)
            else if (heard)
              Icon(Icons.check_circle_outline_rounded, size: 22, color: muted)
            else if (current)
              Container(
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: context.surface.foreground.withValues(alpha: 0.16), width: 2),
                ),
              ),
          ],
        ),
      ),
    );
    final framed = soon
        ? DecoratedBox(
            decoration: BoxDecoration(
              border: Border(top: BorderSide(color: context.surface.foreground.withValues(alpha: 0.08))),
            ),
            child: CustomPaint(painter: _Dashed(context.surface.foreground.withValues(alpha: 0.16)), child: row),
          )
        : row;
    return Semantics(
      button: onOpen != null,
      label: [title, if (fresh) 'New', ?(data.isEmpty ? null : data), if (song) 'Music', if (heard) 'Heard'].join(', '),
      child: ExcludeSemantics(
        child: onOpen == null ? framed : InkWell(onTap: onOpen, child: framed),
      ),
    );
  }
}

/// The dashed line above the author's next date (P15e).
class _Dashed extends CustomPainter {
  const _Dashed(this.color);
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1;
    for (var x = 16.0; x < size.width - 16; x += 8) {
      canvas.drawLine(Offset(x, 0.5), Offset(x + 4, 0.5), paint);
    }
  }

  @override
  bool shouldRepaint(_Dashed old) => old.color != color;
}
