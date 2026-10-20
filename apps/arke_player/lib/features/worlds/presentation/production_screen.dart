import 'package:arke_library/arke_library.dart';
import 'package:arke_world/arke_world.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/routes.dart';
import '../../../app/services.dart';
import '../../../app/theme/tokens.dart';
import '../../../app/widgets/shelf.dart';
import '../../players/application/players.dart';
import '../application/worlds.dart';
import 'world_widgets.dart';

/// A production of an installed world: P1e's show page, for what the MVP's players open. The
/// picture, the title, one meta line, then `Play` — or `Continue · Chapter 3 · 12:04` when this
/// device holds a place — with `Read` beside it for a book with its narration (P9 rule 7), and
/// the narration's Chapters. What P1e draws for shares (the download and its size) is absent.
class ProductionScreen extends ConsumerWidget {
  const ProductionScreen({required this.worldId, required this.productionId, super.key});

  final String worldId;
  final String productionId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final world = ref.watch(libraryWorldsProvider).value?.where((world) => world.id == worldId).firstOrNull;
    final production = world?.productions.where((production) => production.id == productionId).firstOrNull;
    final store = ref.watch(libraryStoreProvider).value;
    final items = {for (final item in ref.watch(libraryItemsProvider).value ?? const <LibraryItem>[]) item.id: item};
    if (world == null || production == null) {
      return Scaffold(
        appBar: AppBar(),
        body: const Center(child: Text('Removed')),
      );
    }
    final narration = items[production.narration];
    final book = items[production.book];
    final kind = productionKind(book: book != null, narration: narration != null, length: narration?.duration);
    final first = narration ?? book;

    void open(LibraryItem item) => context.push(Routes.open(item.id));

    return Scaffold(
      body: ListView(
        padding: EdgeInsets.zero,
        children: [
          WorldHero(
            picture: libraryPicture(store, production.picture ?? narration?.cover ?? book?.cover ?? world.keyArt),
            title: production.title,
            meta: [kind, ?production.author].join(' · '),
            child: first == null
                ? null
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
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
          if (narration != null && narration.chapters.length > 1) ...[
            const SectionHead('Chapters'),
            for (final (i, chapter) in narration.chapters.indexed)
              _ChapterRow(
                number: i + 1,
                title: chapter.title,
                length: _chapterLength(narration, i),
                current: _chapterAt(narration) == i && narration.inProgress,
                onOpen: () async {
                  // A chapter opens the player at its start: the place is the chapter's.
                  final total = narration.duration?.inMilliseconds ?? 0;
                  await ref
                      .read(placeKeeperProvider)
                      .call(
                        narration.id,
                        Place(position: chapter.start, progress: total <= 0 ? 0 : chapter.start.inMilliseconds / total, updatedAt: DateTime.now().toUtc()),
                      );
                  if (context.mounted) open(narration);
                },
              ),
          ],
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  /// `Chapter 3 · 12:04` for narration, the time into its chapter; nothing for a book.
  static String? _where(LibraryItem item) {
    final position = item.place?.position;
    if (position == null) return null;
    final index = _chapterAt(item);
    if (index == null) return formatClock(position);
    return 'Chapter ${index + 1} · ${formatClock(position - item.chapters[index].start)}';
  }

  static int? _chapterAt(LibraryItem item) {
    final position = item.place?.position;
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

/// A chapter's row (P5b's grammar on the shelves): its number, title and length.
class _ChapterRow extends StatelessWidget {
  const _ChapterRow({required this.number, required this.title, required this.length, required this.current, required this.onOpen});

  final int number;
  final String title;
  final Duration? length;
  final bool current;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final muted = context.surface.mutedForeground;
    return InkWell(
      onTap: onOpen,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: ArkeSizes.press + 8),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              SizedBox(
                width: 28,
                child: Text('$number', style: text.bodyMedium?.copyWith(color: muted)),
              ),
              Expanded(
                child: Text(
                  title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: text.bodyMedium?.copyWith(fontSize: ArkeType.sizeBase, fontWeight: current ? FontWeight.w600 : FontWeight.w500),
                ),
              ),
              if (length != null) ...[const SizedBox(width: 12), Text(formatClock(length!), style: text.labelSmall?.copyWith(color: muted))],
            ],
          ),
        ),
      ),
    );
  }
}
