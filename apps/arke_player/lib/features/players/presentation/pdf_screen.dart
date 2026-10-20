import 'package:arke_library/arke_library.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pdfrx/pdfrx.dart';

import '../../../app/widgets/shelf.dart';
import '../application/players.dart';

/// A PDF in the page viewer (P7c): pages fit the width on the shelves' theme, one column that
/// scrolls, pinch to zoom; ⌄, the title, Contents when the file has an outline; at the foot the
/// page and its line. The page is kept on the device.
class PdfScreen extends ConsumerStatefulWidget {
  const PdfScreen({required this.item, required this.store, super.key});

  final LibraryItem item;
  final LibraryStore store;

  @override
  ConsumerState<PdfScreen> createState() => _PdfScreenState();
}

class _PdfScreenState extends ConsumerState<PdfScreen> {
  final _controller = PdfViewerController();
  List<PdfOutlineNode> _outline = const [];
  int _page = 1;
  int _pages = 0;

  void _changed(int? page) {
    if (page == null) return;
    setState(() => _page = page);
    final pages = _pages == 0 ? (widget.item.pages ?? page) : _pages;
    ref.read(placeKeeperProvider)(
      widget.item.id,
      Place(page: page, progress: pages <= 1 ? 1 : (page - 1) / (pages - 1), updatedAt: DateTime.now().toUtc()),
      finished: page >= pages,
    );
  }

  @override
  Widget build(BuildContext context) {
    final surface = context.surface;
    final text = Theme.of(context).textTheme;
    return Scaffold(
      backgroundColor: surface.secondary,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 4, 4, 4),
              child: Row(
                children: [
                  IconButton(onPressed: () => Navigator.of(context).maybePop(), tooltip: 'Close', icon: const Icon(Icons.keyboard_arrow_down, size: 28)),
                  Expanded(
                    child: Text(widget.item.title, textAlign: TextAlign.center, maxLines: 1, overflow: TextOverflow.ellipsis, style: text.bodyMedium),
                  ),
                  IconButton(onPressed: _outline.isEmpty ? null : () => _contents(context), tooltip: 'Contents', icon: const Icon(Icons.format_list_bulleted)),
                ],
              ),
            ),
            Expanded(
              child: PdfViewer.file(
                widget.store.resolve(widget.item.file),
                controller: _controller,
                params: PdfViewerParams(
                  backgroundColor: surface.secondary,
                  margin: 14,
                  onPageChanged: _changed,
                  onViewerReady: (document, controller) async {
                    setState(() => _pages = document.pages.length);
                    final kept = widget.item.finished ? null : widget.item.place?.page;
                    if (kept != null && kept > 1) await controller.goToPage(pageNumber: kept.clamp(1, document.pages.length));
                    final outline = await document.loadOutline();
                    if (mounted) setState(() => _outline = outline);
                  },
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 12),
              child: Row(
                children: [
                  Text(
                    _pages == 0 ? '' : '$_page of $_pages',
                    style: text.labelSmall?.copyWith(color: surface.mutedForeground, fontFeatures: const [FontFeature.tabularFigures()]),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: LinearProgressIndicator(
                      value: _pages <= 1 ? 1 : (_page - 1) / (_pages - 1),
                      minHeight: 4,
                      color: surface.foreground,
                      backgroundColor: surface.foreground.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(99),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _contents(BuildContext context) => showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (context) => ConstrainedBox(
      constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.7),
      child: ListView(
        shrinkWrap: true,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Text('Contents', style: Theme.of(context).textTheme.titleMedium),
          ),
          for (final (node, depth) in _flatten(_outline, 0))
            ListTile(
              contentPadding: EdgeInsets.only(left: 16.0 + depth * 16, right: 16),
              title: Text(node.title),
              onTap: node.dest == null
                  ? null
                  : () {
                      _controller.goToDest(node.dest);
                      Navigator.of(context).pop();
                    },
            ),
        ],
      ),
    ),
  );

  static Iterable<(PdfOutlineNode, int)> _flatten(List<PdfOutlineNode> nodes, int depth) sync* {
    for (final node in nodes) {
      yield (node, depth);
      yield* _flatten(node.children, depth + 1);
    }
  }
}
