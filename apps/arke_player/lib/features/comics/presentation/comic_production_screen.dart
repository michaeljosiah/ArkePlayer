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
import '../../worlds/application/worlds.dart';
import '../../worlds/presentation/world_screen.dart';
import '../../worlds/presentation/world_widgets.dart';
import '../application/comics.dart';

const _fg = ArkeColors.mediaOverlayForeground;

/// A graphic novel's page (P20a): the hero, `Graphic novel · The Undersong · 24 pages`, `Continue ·
/// Page 9` — `Read` before the first page turns — its size, and a newer package in Arke's list as its
/// `Update` (SPEC-058 R-83); then its chapters, each as its first page.
class ComicProductionScreen extends ConsumerWidget {
  const ComicProductionScreen({required this.world, required this.production, super.key});

  final LibraryWorld world;
  final LibraryProduction production;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final comic = production.comic!;
    final key = (world.id, production.id);
    final loaded = ref.watch(loadedComicProvider(key)).value;
    final kept = ref.watch(comicPageProvider(key));
    final store = ref.watch(libraryStoreProvider).value;
    final listed = listedFor(ref.watch(catalogueProvider).value ?? const [], world.id);
    final update = ref.watch(productionUpdateProvider(key));
    final state = ref.watch(productionInstallProvider(key));
    ref.listen(productionInstallProvider(key), (previous, next) {
      if (next is InstallFailed && previous is! InstallFailed && listed != null && update != null) {
        showInstallRefusal(context, ref, listed, next.refusal, updating: true, production: update);
      }
    });

    void open() => context.push(Routes.comic(world.id, production.id));

    // A chapter opens the reader at its first page.
    Future<void> openAt(int page) async {
      await keepComicPage(ref, world.id, production.id, page);
      if (context.mounted) open();
    }

    final bytes = production.package?.byteLength ?? 0;
    final wide = MediaQuery.sizeOf(context).width >= WindowBands.fold;
    final starts = loaded?.chapterStarts;

    return Scaffold(
      body: ScrolledHead(
        title: production.title,
        child: ListView(
          padding: EdgeInsets.only(bottom: footRoom(context)),
          children: [
            WorldHero(
              picture: libraryPicture(store, production.picture ?? world.keyArt),
              title: production.title,
              meta: ['Graphic novel', world.name, pageCount(comic.pages)].join(' · '),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (kept != null && kept > 0 && kept < comic.pages)
                    HeroPress(icon: Icons.menu_book_rounded, label: 'Continue', detail: 'Page ${kept + 1}', onPressed: open)
                  else
                    HeroPress(icon: Icons.menu_book_rounded, label: 'Read', onPressed: () => openAt(0)),
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: SizedBox(
                      width: wide ? 320 : double.infinity,
                      child: _Size(bytes: bytes),
                    ),
                  ),
                  switch (state) {
                    Installing() => InstallProgress(state: state, onCancel: () => ref.read(productionInstallProvider(key).notifier).cancel()),
                    _ when update != null && listed != null => HeroSecondPress(
                      icon: Icons.download_rounded,
                      label: 'Update',
                      detail: formatBytes(update.alone!.byteLength),
                      onPressed: () => ref.read(productionInstallProvider(key).notifier).start(listed, update),
                    ),
                    _ => const SizedBox.shrink(),
                  },
                ],
              ),
            ),
            if (loaded != null && starts != null) ...[
              const SectionHead('Chapters'),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Wrap(
                  spacing: 12,
                  runSpacing: 16,
                  children: [
                    for (final (index, chapter) in loaded.document.chapters.indexed)
                      _ChapterTile(
                        number: index + 1,
                        chapter: chapter,
                        picture: File(loaded.pathOf(chapter.pages.first.picture)),
                        width: wide ? 150 : (MediaQuery.sizeOf(context).width - 32 - 24) / 3,
                        onTap: () => openAt(starts[index]),
                      ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}

/// A chapter as its first page, 2:3, with its number and title under it (P20a).
class _ChapterTile extends StatelessWidget {
  const _ChapterTile({required this.number, required this.chapter, required this.picture, required this.width, required this.onTap});
  final int number;
  final ComicChapter chapter;
  final File picture;
  final double width;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      button: true,
      label: 'Chapter $number, ${chapter.title}, ${pageCount(chapter.pages.length)}',
      child: ExcludeSemantics(
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(ArkeRadius.md),
          child: SizedBox(
            width: width,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(ArkeRadius.md),
                  child: AspectRatio(
                    aspectRatio: 2 / 3,
                    child: ColoredBox(
                      color: Colors.black,
                      child: Image.file(picture, fit: BoxFit.contain, cacheWidth: 400, errorBuilder: (_, _, _) => const SizedBox.shrink()),
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '$number · ${chapter.title}',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontFamily: ArkeType.family, fontSize: ArkeType.sizeSm, fontWeight: FontWeight.w600, color: scheme.onSurface),
                ),
                Text(
                  pageCount(chapter.pages.length),
                  style: TextStyle(fontFamily: ArkeType.family, fontSize: ArkeType.sizeXs, color: scheme.onSurfaceVariant),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// What the book takes on the phone, in the hero's quiet fill, as a story's is.
class _Size extends StatelessWidget {
  const _Size({required this.bytes});
  final int bytes;

  @override
  Widget build(BuildContext context) => Semantics(
    label: '${formatBytes(bytes)} downloaded',
    child: ExcludeSemantics(
      child: Container(
        height: ArkeSizes.press,
        alignment: Alignment.center,
        decoration: BoxDecoration(color: _fg.withValues(alpha: 0.16), borderRadius: BorderRadius.circular(ArkeRadius.pill)),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.check_circle_outline_rounded, size: 18, color: _fg),
            const SizedBox(width: 8),
            Text(
              formatBytes(bytes),
              style: const TextStyle(fontFamily: ArkeType.family, fontSize: ArkeType.sizeBase, fontWeight: FontWeight.w500, color: _fg),
            ),
          ],
        ),
      ),
    ),
  );
}
