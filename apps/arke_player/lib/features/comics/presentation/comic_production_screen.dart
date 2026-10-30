import 'dart:io';
import 'dart:ui';

import 'package:arke_library/arke_library.dart';
import 'package:arke_world/arke_world.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/routes.dart';
import '../../../app/theme/tokens.dart';
import '../../../app/widgets/shelf.dart';
import '../../worlds/application/worlds.dart';
import '../../worlds/presentation/world_screen.dart';
import '../../worlds/presentation/world_widgets.dart';
import '../application/comics.dart';

const _fg = ArkeColors.mediaOverlayForeground;
const _bg = ArkeColors.mediaOverlayBackground;

/// A graphic novel's page (P21b – P21d): its cover upright over its own blur, the title,
/// `Graphic novel · The Undersong · 11 pages` and one press. Before it is on the phone the press is
/// `Get · 4.3 MB`, pressed at once and never waiting for Wi-Fi (rule 3), and its download takes the
/// press's place; on the phone it is `Read`, or `Continue · Page 3` once begun, with its size and a
/// newer package in Arke's list as its `Update` (SPEC-058 R-83). Then its chapters, each a row.
///
/// [world] and [production] are what the phone holds; [listed] and [listedProduction] what Arke's list
/// says. A book Discover opens before it is here has only the second pair (P21 call 35).
class ComicProductionScreen extends ConsumerWidget {
  const ComicProductionScreen({this.world, this.production, this.listed, this.listedProduction, super.key})
    : assert(production != null || listedProduction != null);

  final LibraryWorld? world;
  final LibraryProduction? production;
  final CatalogueWorld? listed;
  final CatalogueProduction? listedProduction;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final worldId = world?.id ?? listed!.id;
    final productionId = production?.id ?? listedProduction!.id ?? '';
    final key = (worldId, productionId);
    final title = production?.title ?? listedProduction!.title;
    final loaded = ref.watch(loadedComicProvider(key)).value;
    final kept = ref.watch(comicPageProvider(key));
    final catalogue = ref.watch(catalogueProvider).value ?? const <CatalogueWorld>[];
    final inList = listed ?? listedFor(catalogue, worldId);
    final inListProduction =
        listedProduction ?? inList?.productions.where((item) => item.id == productionId || (item.id == null && item.title == title)).firstOrNull;
    final update = production == null ? null : ref.watch(productionUpdateProvider(key));
    final state = ref.watch(productionInstallProvider(key));
    // Not here, and its world not either: Get brings the world, which brings the book with it.
    final worldState = ref.watch(installProvider(inList?.id ?? worldId));
    ref.listen(productionInstallProvider(key), (previous, next) {
      final production = update ?? inListProduction;
      if (next is InstallFailed && previous is! InstallFailed && inList != null && production != null) {
        showInstallRefusal(context, ref, inList, next.refusal, updating: update != null, production: production);
      }
    });
    if (inList != null && world == null) {
      ref.listen(installProvider(inList.id), (previous, next) {
        if (next is InstallFailed && previous is! InstallFailed && context.mounted) showInstallRefusal(context, ref, inList, next.refusal);
      });
    }

    void open() => context.push(Routes.comic(worldId, productionId));

    // A chapter opens the reader at its first page.
    Future<void> openAt(int page) async {
      await keepComicPage(ref, worldId, productionId, page);
      if (context.mounted) open();
    }

    final pages = production?.comic?.pages ?? listedPages(inListProduction?.kind ?? '');
    final cover = ref.tallOf(inListProduction) ?? ref.watch(comicFirstPageProvider(key));
    final here = production?.comic != null && loaded != null;
    final starts = loaded?.chapterStarts;

    final Widget press;
    if (here) {
      press = Column(
        children: [
          if (kept != null && kept > 0 && kept < pages!)
            HeroPress(icon: Icons.menu_book_rounded, label: 'Continue', detail: 'Page ${kept + 1}', onPressed: open)
          else
            HeroPress(icon: Icons.menu_book_rounded, label: 'Read', onPressed: () => openAt(0)),
          Padding(
            padding: const EdgeInsets.only(top: 10),
            child: SizedBox(
              width: MediaQuery.sizeOf(context).width >= WindowBands.fold ? 320 : double.infinity,
              child: _Size(bytes: production!.package?.byteLength ?? 0),
            ),
          ),
          switch (state) {
            Installing() => InstallProgress(state: state, onCancel: () => ref.read(productionInstallProvider(key).notifier).cancel()),
            _ when update != null && inList != null => HeroSecondPress(
              icon: Icons.download_rounded,
              label: 'Update',
              detail: formatBytes(update.alone!.byteLength),
              onPressed: () => ref.read(productionInstallProvider(key).notifier).start(inList, update),
            ),
            _ => const SizedBox.shrink(),
          },
        ],
      );
    } else if (state is Installing) {
      press = InstallProgress(state: state, onCancel: () => ref.read(productionInstallProvider(key).notifier).cancel());
    } else if (world == null && worldState is Installing) {
      press = InstallProgress(state: worldState, onCancel: () => ref.read(installProvider(inList!.id).notifier).cancel());
    } else if (inList != null && inListProduction?.alone != null) {
      // Its world is here: the book alone. Otherwise the world's install, which fetches it too.
      final bytes = world != null
          ? inListProduction!.alone!.byteLength
          : (inList.package?.byteLength ?? 0) +
                (inList.package?.parts.fold<int>(0, (sum, part) => sum + part.byteLength) ?? 0) +
                inList.productions.fold<int>(0, (sum, item) => sum + (item.alone?.byteLength ?? 0));
      press = HeroPress(
        icon: Icons.download_rounded,
        label: 'Get',
        detail: formatBytes(bytes),
        onPressed: () => world != null
            ? ref.read(productionInstallProvider(key).notifier).start(inList, inListProduction!)
            : ref.read(installProvider(inList.id).notifier).start(inList),
      );
    } else {
      press = const SizedBox.shrink();
    }

    return Scaffold(
      body: ScrolledHead(
        title: title,
        child: ListView(
          padding: EdgeInsets.only(bottom: footRoom(context)),
          children: [
            _Head(
              cover: cover,
              title: title,
              meta: ['Graphic novel', world?.name ?? inList?.name ?? '', if (pages != null) pageCount(pages)].where((word) => word.isNotEmpty).join(' · '),
              press: press,
            ),
            if (here && starts != null) ...[
              const SectionHead('Chapters'),
              for (final (index, chapter) in loaded.document.chapters.indexed)
                _ChapterRow(
                  number: index + 1,
                  chapter: chapter,
                  picture: File(loaded.pathOf(chapter.pages.first.picture)),
                  // `Page 3` on the chapter you are in; a tick on one read past (rule 4).
                  at: kept != null && kept >= starts[index] && kept < starts[index] + chapter.pages.length ? kept : null,
                  read: kept != null && kept >= starts[index] + chapter.pages.length,
                  onTap: () => openAt(starts[index]),
                ),
            ],
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}

/// The page's head (P21b): the cover 168 wide and whole, over its own blur, then the title, the meta
/// line and the press. A book with no cover yet shows its first page; one not here yet, a blank 2:3.
class _Head extends StatelessWidget {
  const _Head({required this.cover, required this.title, required this.meta, required this.press});

  final ImageProvider? cover;
  final String title;
  final String meta;
  final Widget press;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final top = MediaQuery.paddingOf(context).top;
    return ColoredBox(
      color: _bg,
      child: Stack(
        children: [
          if (cover != null)
            Positioned.fill(
              child: ClipRect(
                child: ImageFiltered(
                  imageFilter: ImageFilter.blur(sigmaX: 28, sigmaY: 28, tileMode: TileMode.decal),
                  child: ColorFiltered(
                    colorFilter: const ColorFilter.mode(Color(0x80000000), BlendMode.darken),
                    child: Image(image: cover!, fit: BoxFit.cover),
                  ),
                ),
              ),
            ),
          const Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, stops: [0.4, 1], colors: [Color(0x000A0A0A), _bg]),
              ),
            ),
          ),
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 640),
              child: Padding(
                padding: EdgeInsets.fromLTRB(16, top + 56, 16, 20),
                child: Column(
                  children: [
                    Container(
                      width: 168,
                      height: 252,
                      clipBehavior: Clip.antiAlias,
                      decoration: BoxDecoration(
                        color: Colors.black,
                        borderRadius: BorderRadius.circular(6),
                        boxShadow: const [BoxShadow(color: Color(0x66000000), blurRadius: 32, offset: Offset(0, 16))],
                      ),
                      // Whole, never cropped: a 2:3 cover fills it, a first page of another shape sits in it.
                      child: cover == null ? null : Image(image: cover!, fit: BoxFit.contain, semanticLabel: title),
                    ),
                    const SizedBox(height: 18),
                    Semantics(
                      header: true,
                      child: Text(
                        title,
                        textAlign: TextAlign.center,
                        style: text.headlineLarge?.copyWith(color: _fg),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      meta,
                      textAlign: TextAlign.center,
                      style: text.bodyMedium?.copyWith(color: _fg.withValues(alpha: 0.74)),
                    ),
                    press,
                  ],
                ),
              ),
            ),
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
}

/// A chapter as a row (P21d): its first page at 56 × 84, its title and pages, and `Page 3` on the one
/// you are in or a tick on one read. Its lettering need not be read at this size; its title is there.
class _ChapterRow extends StatelessWidget {
  const _ChapterRow({required this.number, required this.chapter, required this.picture, required this.at, required this.read, required this.onTap});
  final int number;
  final ComicChapter chapter;
  final File picture;
  final int? at;
  final bool read;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      button: true,
      label: ['Chapter $number, ${chapter.title}, ${pageCount(chapter.pages.length)}', if (at != null) 'Page ${at! + 1}', if (read) 'Read'].join(', '),
      child: ExcludeSemantics(
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                Container(
                  width: 56,
                  height: 84,
                  clipBehavior: Clip.antiAlias,
                  decoration: BoxDecoration(
                    color: Colors.black,
                    borderRadius: BorderRadius.circular(5),
                    border: at != null ? Border.all(color: scheme.onSurface, width: 2, strokeAlign: BorderSide.strokeAlignOutside) : null,
                  ),
                  child: Image.file(picture, fit: BoxFit.contain, cacheWidth: 168, errorBuilder: (_, _, _) => const SizedBox.shrink()),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '$number · ${chapter.title}',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontFamily: ArkeType.family, fontSize: ArkeType.sizeLg, fontWeight: FontWeight.w600, color: scheme.onSurface),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        pageCount(chapter.pages.length),
                        style: TextStyle(fontFamily: ArkeType.family, fontSize: ArkeType.sizeXs, color: scheme.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
                if (at != null)
                  Text(
                    'Page ${at! + 1}',
                    style: TextStyle(fontFamily: ArkeType.family, fontSize: ArkeType.sizeSm, color: scheme.onSurface),
                  )
                else if (read)
                  Icon(Icons.check_rounded, size: 20, color: scheme.onSurfaceVariant),
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
