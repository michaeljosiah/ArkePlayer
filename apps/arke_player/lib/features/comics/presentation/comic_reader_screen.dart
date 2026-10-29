import 'dart:async';
import 'dart:io';

import 'package:arke_world/arke_world.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/tokens.dart';
import '../../../app/widgets/shelf.dart';
import '../application/comics.dart';

const _fg = ArkeColors.mediaOverlayForeground;

/// A graphic novel read (P20b – P20g): a page whole on black with nothing over it; a tap shows the
/// controls and a second hides them, and a tap never turns the page (P20 rule 4); a swipe turns it the
/// way the book reads (rule 5), or the book scrolls as one column (rule 6). Pinch and double-tap zoom
/// (rule 3). The page you are on is kept (rule 8).
class ComicReaderScreen extends ConsumerStatefulWidget {
  const ComicReaderScreen({required this.worldId, required this.productionId, super.key});

  final String worldId;
  final String productionId;

  @override
  ConsumerState<ComicReaderScreen> createState() => _ComicReaderScreenState();
}

class _ComicReaderScreenState extends ConsumerState<ComicReaderScreen> {
  PageController? _pages;
  int _at = 0;
  bool _chrome = false;
  Timer? _rest;

  (String, String) get _key => (widget.worldId, widget.productionId);

  @override
  void initState() {
    super.initState();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  }

  @override
  void dispose() {
    _rest?.cancel();
    _pages?.dispose();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  void _toggle() {
    setState(() => _chrome = !_chrome);
    _rest?.cancel();
    if (_chrome) _rest = Timer(ArkeSizes.chromeRest, () => mounted ? setState(() => _chrome = false) : null);
  }

  void _turned(int page) {
    setState(() => _at = page);
    unawaited(keepComicPage(ref, widget.worldId, widget.productionId, page));
  }

  void _goTo(int page) {
    if (_pages?.hasClients ?? false) {
      _pages!.jumpToPage(page);
    } else {
      _turned(page);
    }
  }

  Future<void> _chapters(LoadedComic comic) async {
    final starts = comic.chapterStarts;
    final current = comic.pages[_at.clamp(0, comic.pages.length - 1)].chapter;
    final chosen = await showArkeSheet<int>(
      context,
      title: 'Chapters',
      scrollable: true,
      builder: (sheet) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final (index, chapter) in comic.document.chapters.indexed)
            ListTile(
              leading: ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: Image.file(File(comic.pathOf(chapter.pages.first.picture)), width: 40, height: 60, fit: BoxFit.cover, cacheWidth: 120),
              ),
              title: Text('${index + 1} · ${chapter.title}'),
              subtitle: Text('Pages ${starts[index] + 1} – ${starts[index] + chapter.pages.length}'),
              trailing: index == current ? const Icon(Icons.check_rounded) : null,
              onTap: () => Navigator.of(sheet).pop(starts[index]),
            ),
        ],
      ),
    );
    if (chosen != null) _goTo(chosen);
  }

  @override
  Widget build(BuildContext context) {
    final comic = ref.watch(loadedComicProvider(_key)).value;
    if (comic == null) return const Scaffold(backgroundColor: Colors.black);
    final pages = comic.pages;
    final scroll = comic.document.reading == ComicReading.scroll;
    if (_pages == null && !scroll) {
      final kept = (ref.read(comicPageProvider(_key)) ?? 0).clamp(0, pages.length - 1);
      _at = kept;
      _pages = PageController(initialPage: kept);
    }
    final chapter = comic.document.chapters[pages[_at.clamp(0, pages.length - 1)].chapter];
    final chapterNumber = pages[_at.clamp(0, pages.length - 1)].chapter + 1;
    final rtl = comic.document.reading == ComicReading.rtl;

    Widget picture(int index) => _ZoomPage(file: File(comic.pathOf(pages[index].page.picture)), alt: pages[index].page.alt, onTap: _toggle);

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          Positioned.fill(
            child: scroll
                ? GestureDetector(
                    onTap: _toggle,
                    child: ListView.builder(
                      itemCount: pages.length,
                      itemBuilder: (context, index) => Semantics(
                        image: true,
                        label: pages[index].page.alt,
                        child: Image.file(File(comic.pathOf(pages[index].page.picture)), fit: BoxFit.fitWidth, width: double.infinity),
                      ),
                    ),
                  )
                : PageView.builder(
                    controller: _pages,
                    // Right to left: the next page comes from the left (P20 rule 5, P20d).
                    reverse: rtl,
                    itemCount: pages.length,
                    onPageChanged: _turned,
                    itemBuilder: (context, index) => picture(index),
                  ),
          ),
          IgnorePointer(
            ignoring: !_chrome,
            child: AnimatedOpacity(
              opacity: _chrome ? 1 : 0,
              duration: const Duration(milliseconds: 180),
              child: Stack(
                children: [
                  const _Scrim(top: true),
                  const _Scrim(top: false),
                  SafeArea(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      child: Row(
                        children: [
                          IconButton(
                            tooltip: 'Close',
                            color: _fg,
                            icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 28),
                            onPressed: () => Navigator.of(context).maybePop(),
                          ),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  comic.production.title.toUpperCase(),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontFamily: ArkeType.family,
                                    fontSize: ArkeType.size2xs,
                                    fontWeight: FontWeight.w600,
                                    color: _fg,
                                    letterSpacing: 0.6,
                                  ),
                                ),
                                Text(
                                  'Chapter $chapterNumber · ${chapter.title}',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(fontFamily: ArkeType.family, fontSize: ArkeType.sizeBase, fontWeight: FontWeight.w600, color: _fg),
                                ),
                              ],
                            ),
                          ),
                          IconButton(tooltip: 'Chapters', color: _fg, icon: const Icon(Icons.format_list_bulleted_rounded), onPressed: () => _chapters(comic)),
                        ],
                      ),
                    ),
                  ),
                  if (!scroll)
                    Positioned(
                      left: 20,
                      right: 20,
                      bottom: 44,
                      child: Row(
                        children: [
                          Text(
                            '${_at + 1} of ${pages.length}',
                            style: const TextStyle(
                              fontFamily: ArkeType.family,
                              fontSize: ArkeType.sizeXs,
                              color: _fg,
                              fontFeatures: [FontFeature.tabularFigures()],
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Directionality(
                              // The book's progress fills the way it reads (P20d).
                              textDirection: rtl ? TextDirection.rtl : TextDirection.ltr,
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(2),
                                child: LinearProgressIndicator(
                                  value: (_at + 1) / pages.length,
                                  minHeight: 4,
                                  color: _fg,
                                  backgroundColor: _fg.withValues(alpha: 0.22),
                                ),
                              ),
                            ),
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

class _Scrim extends StatelessWidget {
  const _Scrim({required this.top});
  final bool top;

  @override
  Widget build(BuildContext context) => Positioned(
    left: 0,
    right: 0,
    top: top ? 0 : null,
    bottom: top ? null : 0,
    height: top ? 150 : 160,
    child: DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: top ? Alignment.topCenter : Alignment.bottomCenter,
          end: top ? Alignment.bottomCenter : Alignment.topCenter,
          colors: [ArkeColors.mediaOverlayBackground.withValues(alpha: 0.7), ArkeColors.mediaOverlayBackground.withValues(alpha: 0)],
        ),
      ),
    ),
  );
}

/// One page, whole and never cropped (P20 rule 3); pinch zooms, and a double tap zooms in and back.
class _ZoomPage extends StatefulWidget {
  const _ZoomPage({required this.file, required this.alt, required this.onTap});
  final File file;
  final String alt;
  final VoidCallback onTap;

  @override
  State<_ZoomPage> createState() => _ZoomPageState();
}

class _ZoomPageState extends State<_ZoomPage> {
  final _zoom = TransformationController();
  TapDownDetails? _down;

  @override
  void dispose() {
    _zoom.dispose();
    super.dispose();
  }

  void _doubleTap() {
    if (_zoom.value.getMaxScaleOnAxis() > 1) {
      _zoom.value = Matrix4.identity();
      return;
    }
    final at = _down?.localPosition ?? Offset.zero;
    _zoom.value = Matrix4.identity()
      ..translateByDouble(-at.dx, -at.dy, 0, 1)
      ..scaleByDouble(2, 2, 1, 1);
  }

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: widget.onTap,
    onDoubleTapDown: (details) => _down = details,
    onDoubleTap: _doubleTap,
    child: InteractiveViewer(
      transformationController: _zoom,
      maxScale: 4,
      child: Center(
        child: Semantics(
          image: true,
          label: widget.alt,
          child: Image.file(widget.file, fit: BoxFit.contain),
        ),
      ),
    ),
  );
}
