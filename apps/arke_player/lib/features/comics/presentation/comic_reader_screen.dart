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
const _bg = ArkeColors.mediaOverlayBackground;

/// The share of the width at either side where a tap turns the page (P21 rule 6).
const _edge = 0.3;

/// A graphic novel read (P21e – P21i). It opens with its controls showing, and they rest after
/// 2.5 s (rule 5). Resting, the page is whole on black with nothing over it; a tap in the outer 30 %
/// either side turns the page, the next on the side the book reads towards, and a tap in the middle
/// shows or hides the controls (rule 6, revising P20 rule 4). A swipe still turns. No double tap, so
/// no tap waits for a second; pinch zooms (rule 7). A Fold open, or any screen wider than it is tall,
/// shows two facing pages and a turn moves two (rule 9). A scrolling book is one column. The page you
/// are on is kept (P20 rule 8).
class ComicReaderScreen extends ConsumerStatefulWidget {
  const ComicReaderScreen({required this.worldId, required this.productionId, super.key});

  final String worldId;
  final String productionId;

  @override
  ConsumerState<ComicReaderScreen> createState() => _ComicReaderScreenState();
}

class _ComicReaderScreenState extends ConsumerState<ComicReaderScreen> {
  PageController? _pages;

  /// Whether [_pages] counts spreads: it is made again when the Fold opens or closes.
  bool? _spreads;

  /// The page you are on; on a Fold open, its spread's first.
  int _at = 0;
  bool _chrome = true;

  /// Where the bar is being dragged to, in turns, before it is let go.
  double? _dragging;
  Timer? _rest;

  (String, String) get _key => (widget.worldId, widget.productionId);

  @override
  void initState() {
    super.initState();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    _restLater();
  }

  @override
  void dispose() {
    _rest?.cancel();
    _pages?.dispose();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  void _restLater() {
    _rest?.cancel();
    if (_chrome) _rest = Timer(ArkeSizes.chromeRest, () => mounted && _dragging == null ? setState(() => _chrome = false) : null);
  }

  void _toggle() {
    setState(() => _chrome = !_chrome);
    _restLater();
  }

  /// A turn, in the PageView's own count: pages, or a Fold open's spreads.
  void _turned(int index) {
    final page = _spreads ?? false ? index * 2 : index;
    setState(() => _at = page);
    unawaited(keepComicPage(ref, widget.worldId, widget.productionId, page));
  }

  /// One turn on: [by] is +1 to the next, -1 back.
  void _step(int by, int turns) {
    final pages = _pages;
    if (pages == null || !pages.hasClients) return;
    final target = ((pages.page ?? 0).round() + by).clamp(0, turns - 1);
    unawaited(pages.animateToPage(target, duration: const Duration(milliseconds: 240), curve: Curves.easeOutCubic));
    if (_chrome) _restLater();
  }

  /// A press or tap on the left or the right of the screen: the next is on the side the book reads
  /// towards, so on the left for a book read right to left.
  void _side({required bool left, required bool rtl, required int turns}) => _step(left != rtl ? -1 : 1, turns);

  void _goTo(int page) {
    final index = _spreads ?? false ? page ~/ 2 : page;
    if (_pages?.hasClients ?? false) {
      _pages!.jumpToPage(index);
    } else {
      _turned(index);
    }
  }

  Future<void> _pickPage(LoadedComic comic) async {
    _rest?.cancel();
    final chosen = await showArkeSheet<int>(
      context,
      title: 'Pages',
      scrollable: true,
      builder: (sheet) => SingleChildScrollView(
        child: _PagesGrid(comic: comic, at: _at),
      ),
    );
    if (chosen != null) _goTo(chosen);
    _restLater();
  }

  Future<void> _chapters(LoadedComic comic) async {
    _rest?.cancel();
    final starts = comic.chapterStarts;
    final current = comic.pages[_at.clamp(0, comic.pages.length - 1)].chapter;
    final chosen = await showArkeSheet<int>(
      context,
      title: 'Chapters',
      scrollable: true,
      builder: (sheet) => SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final (index, chapter) in comic.document.chapters.indexed)
              ListTile(
                title: Text('${index + 1} · ${chapter.title}'),
                subtitle: Text('Pages ${starts[index] + 1} – ${starts[index] + chapter.pages.length}'),
                trailing: index == current ? const Icon(Icons.check_rounded) : null,
                onTap: () => Navigator.of(sheet).pop(starts[index]),
              ),
          ],
        ),
      ),
    );
    if (chosen != null) _goTo(chosen);
    _restLater();
  }

  @override
  Widget build(BuildContext context) {
    final comic = ref.watch(loadedComicProvider(_key)).value;
    if (comic == null) return const Scaffold(backgroundColor: Colors.black);
    final pages = comic.pages;
    final count = pages.length;
    final scroll = comic.document.reading == ComicReading.scroll;
    final rtl = comic.document.reading == ComicReading.rtl;
    final size = MediaQuery.sizeOf(context);
    final spreads = !scroll && (size.width >= WindowBands.fold || size.width > size.height);
    final pairs = comicSpreads(count);
    final turns = spreads ? pairs.length : count;
    if (!scroll && (_pages == null || _spreads != spreads)) {
      if (_pages == null) _at = (ref.read(comicPageProvider(_key)) ?? 0).clamp(0, count - 1);
      // The Fold opened or closed: the same page, now counted the other way. The old controller goes
      // once its PageView has let go of it.
      final old = _pages;
      if (old != null) WidgetsBinding.instance.addPostFrameCallback((_) => old.dispose());
      _spreads = spreads;
      _pages = PageController(initialPage: spreads ? _at ~/ 2 : _at);
    }
    final at = _at.clamp(0, count - 1);
    final turn = spreads ? at ~/ 2 : at;
    final shown = (_dragging?.round() ?? turn).clamp(0, turns - 1);
    final label = spreads ? pageOf(pairs[shown].$1, pairs[shown].$2, count) : pageOf(shown, null, count);
    final chapterIndex = pages[at].chapter;
    final chapter = comic.document.chapters[chapterIndex];

    File file(int index) => File(comic.pathOf(pages[index].page.picture));

    Widget page(int index) => spreads
        ? _ZoomSpread(
            first: (file: file(pairs[index].$1), alt: pages[pairs[index].$1].page.alt),
            second: switch (pairs[index].$2) {
              final second? => (file: file(second), alt: pages[second].page.alt),
              null => null,
            },
            rtl: rtl,
          )
        : _ZoomSpread(first: (file: file(index), alt: pages[index].page.alt), rtl: rtl);

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        // The screen, not the controls: sized by them, the page would have the top bar's height.
        fit: StackFit.expand,
        children: [
          Positioned.fill(
            child: scroll
                ? GestureDetector(
                    onTap: _toggle,
                    child: ListView.builder(
                      itemCount: count,
                      itemBuilder: (context, index) => Semantics(
                        image: true,
                        label: pages[index].page.alt,
                        child: Image.file(file(index), fit: BoxFit.fitWidth, width: double.infinity),
                      ),
                    ),
                  )
                : GestureDetector(
                    // A tap is read where it lands, at once: the edges turn, the middle shows the controls.
                    behavior: HitTestBehavior.opaque,
                    onTapUp: (details) {
                      final x = details.localPosition.dx / size.width;
                      if (x < _edge) {
                        _side(left: true, rtl: rtl, turns: turns);
                      } else if (x > 1 - _edge) {
                        _side(left: false, rtl: rtl, turns: turns);
                      } else {
                        _toggle();
                      }
                    },
                    child: PageView.builder(
                      key: ValueKey(spreads),
                      controller: _pages,
                      // Right to left: the next page comes from the left (P20 rule 5, P20d).
                      reverse: rtl,
                      itemCount: turns,
                      onPageChanged: _turned,
                      itemBuilder: (context, index) => page(index),
                    ),
                  ),
          ),
          IgnorePointer(
            ignoring: !_chrome,
            child: AnimatedOpacity(
              opacity: _chrome ? 1 : 0,
              duration: const Duration(milliseconds: 180),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  const _Scrim(top: true),
                  const _Scrim(top: false),
                  Positioned(
                    top: 0,
                    left: 0,
                    right: 0,
                    child: SafeArea(
                      bottom: false,
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
                                mainAxisSize: MainAxisSize.min,
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
                                    'Chapter ${chapterIndex + 1} · ${chapter.title}',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(fontFamily: ArkeType.family, fontSize: ArkeType.sizeBase, fontWeight: FontWeight.w600, color: _fg),
                                  ),
                                ],
                              ),
                            ),
                            IconButton(tooltip: 'Pages', color: _fg, icon: const Icon(Icons.grid_view_rounded), onPressed: () => _pickPage(comic)),
                            IconButton(tooltip: 'Chapters', color: _fg, icon: const Icon(Icons.more_horiz), onPressed: () => _chapters(comic)),
                          ],
                        ),
                      ),
                    ),
                  ),
                  if (!scroll)
                    Positioned(
                      left: 12,
                      right: 12,
                      bottom: 40 + MediaQuery.paddingOf(context).bottom,
                      child: Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 560),
                          child: Row(
                            children: [
                              _Round(
                                icon: Icons.chevron_left_rounded,
                                tooltip: rtl ? 'Next page' : 'Previous page',
                                onPressed: () => _side(left: true, rtl: rtl, turns: turns),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      label,
                                      style: const TextStyle(
                                        fontFamily: ArkeType.family,
                                        fontSize: ArkeType.sizeSm,
                                        fontWeight: FontWeight.w500,
                                        color: _fg,
                                        fontFeatures: [FontFeature.tabularFigures()],
                                      ),
                                    ),
                                    if (turns > 1)
                                      Directionality(
                                        // The bar fills the way the book reads (P20d).
                                        textDirection: rtl ? TextDirection.rtl : TextDirection.ltr,
                                        child: SliderTheme(
                                          data: SliderThemeData(
                                            trackHeight: 4,
                                            activeTrackColor: _fg,
                                            inactiveTrackColor: _fg.withValues(alpha: 0.24),
                                            thumbColor: _fg,
                                            overlayColor: _fg.withValues(alpha: 0.12),
                                            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
                                            trackShape: const RoundedRectSliderTrackShape(),
                                            tickMarkShape: SliderTickMarkShape.noTickMark,
                                            showValueIndicator: ShowValueIndicator.never,
                                          ),
                                          child: Slider(
                                            value: shown.toDouble(),
                                            max: (turns - 1).toDouble(),
                                            divisions: turns - 1,
                                            semanticFormatterCallback: (_) => label,
                                            onChangeStart: (_) => _rest?.cancel(),
                                            onChanged: (value) => setState(() => _dragging = value),
                                            onChangeEnd: (value) {
                                              setState(() => _dragging = null);
                                              final index = value.round();
                                              _goTo(spreads ? pairs[index].$1 : index);
                                              _restLater();
                                            },
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 10),
                              _Round(
                                icon: Icons.chevron_right_rounded,
                                tooltip: rtl ? 'Previous page' : 'Next page',
                                onPressed: () => _side(left: false, rtl: rtl, turns: turns),
                              ),
                            ],
                          ),
                        ),
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

/// Back or next at the foot (P21e): 48 round, in the overlay's quiet fill.
class _Round extends StatelessWidget {
  const _Round({required this.icon, required this.tooltip, required this.onPressed});
  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => IconButton(
    tooltip: tooltip,
    onPressed: onPressed,
    icon: Icon(icon, size: 26),
    style: IconButton.styleFrom(fixedSize: const Size(48, 48), backgroundColor: _fg.withValues(alpha: 0.16), foregroundColor: _fg),
  );
}

class _Scrim extends StatelessWidget {
  const _Scrim({required this.top});
  final bool top;

  // A scrim takes no taps, so an edge under it still turns.
  @override
  Widget build(BuildContext context) => Positioned(
    left: 0,
    right: 0,
    top: top ? 0 : null,
    bottom: top ? null : 0,
    height: top ? 150 : 180,
    child: IgnorePointer(
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: top ? Alignment.topCenter : Alignment.bottomCenter,
            end: top ? Alignment.bottomCenter : Alignment.topCenter,
            colors: [_bg.withValues(alpha: 0.7), _bg.withValues(alpha: 0)],
          ),
        ),
      ),
    ),
  );
}

/// Every page by chapter, 104 wide with its number, the one you are on ringed (P21g). Pressing one
/// opens it.
class _PagesGrid extends StatelessWidget {
  const _PagesGrid({required this.comic, required this.at});
  final LoadedComic comic;
  final int at;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final starts = comic.chapterStarts;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final (index, chapter) in comic.document.chapters.indexed) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
            child: Text(
              '${index + 1} · ${chapter.title}'.toUpperCase(),
              style: TextStyle(
                fontFamily: ArkeType.family,
                fontSize: ArkeType.size2xs,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.6,
                color: scheme.onSurfaceVariant,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                for (final (offset, page) in chapter.pages.indexed)
                  _PageTile(
                    number: starts[index] + offset + 1,
                    file: File(comic.pathOf(page.picture)),
                    on: starts[index] + offset == at || (MediaQuery.sizeOf(context).width >= WindowBands.fold && starts[index] + offset == at + 1),
                    onTap: () => Navigator.of(context).pop(starts[index] + offset),
                  ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class _PageTile extends StatelessWidget {
  const _PageTile({required this.number, required this.file, required this.on, required this.onTap});
  final int number;
  final File file;
  final bool on;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      button: true,
      selected: on,
      label: 'Page $number',
      child: ExcludeSemantics(
        child: GestureDetector(
          onTap: onTap,
          child: Container(
            width: 104,
            height: 156,
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              color: Colors.black,
              borderRadius: BorderRadius.circular(5),
              border: on ? Border.all(color: scheme.onSurface, width: 2.5, strokeAlign: BorderSide.strokeAlignOutside) : null,
            ),
            child: Stack(
              children: [
                Image.file(file, fit: BoxFit.contain, cacheWidth: 312, errorBuilder: (_, _, _) => const SizedBox.shrink()),
                Positioned(
                  left: 6,
                  bottom: 6,
                  child: Container(
                    constraints: const BoxConstraints(minWidth: 22),
                    height: 22,
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(color: _bg.withValues(alpha: 0.72), borderRadius: BorderRadius.circular(11)),
                    child: Text(
                      '$number',
                      style: const TextStyle(fontFamily: ArkeType.family, fontSize: ArkeType.sizeXs, color: _fg),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

typedef _Page = ({File file, String alt});

/// One page whole, or two facing as a book opens, never cropped (P20 rule 3, P21 rule 9). The two
/// meet at the spine: the first on the left, or on the right for a book read right to left. Pinch
/// zooms; there is no double tap (P21 rule 7).
class _ZoomSpread extends StatelessWidget {
  const _ZoomSpread({required this.first, required this.rtl, this.second});
  final _Page first;
  final _Page? second;
  final bool rtl;

  Widget _picture(_Page page, Alignment alignment) => Semantics(
    image: true,
    label: page.alt,
    child: Image.file(page.file, fit: BoxFit.contain, alignment: alignment),
  );

  @override
  Widget build(BuildContext context) {
    final second = this.second;
    return InteractiveViewer(
      maxScale: 4,
      child: second == null
          ? Center(child: _picture(first, Alignment.center))
          : Row(
              textDirection: rtl ? TextDirection.rtl : TextDirection.ltr,
              children: [
                Expanded(child: _picture(first, rtl ? Alignment.centerLeft : Alignment.centerRight)),
                Expanded(child: _picture(second, rtl ? Alignment.centerRight : Alignment.centerLeft)),
              ],
            ),
    );
  }
}
