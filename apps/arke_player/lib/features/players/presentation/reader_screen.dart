import 'dart:io';

import 'package:arke_library/arke_library.dart';
import 'package:flutter/material.dart';
import 'package:flutter_epub_viewer/flutter_epub_viewer.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/tokens.dart';
import '../../settings/application/settings_controller.dart';
import '../../settings/domain/device_settings.dart';
import '../application/players.dart';

/// An EPUB in the reader (P5e): ⌄, the chapter, Aa and Contents at the top; the text on the
/// reader's paper; at the foot the page in the chapter (`12 of 30`) and its line. The place is an
/// EPUB location, kept on the device as the pages turn.
class ReaderScreen extends ConsumerStatefulWidget {
  const ReaderScreen({required this.item, required this.store, super.key});

  final LibraryItem item;
  final LibraryStore store;

  @override
  ConsumerState<ReaderScreen> createState() => _ReaderScreenState();
}

class _ReaderScreenState extends ConsumerState<ReaderScreen> {
  final _controller = EpubController();
  List<EpubChapter> _chapters = const [];
  EpubLocation? _location;

  static const _papers = {
    ReaderPaper.paper: (background: Color(0xFFFFFFFF), ink: Color(0xFF0A0A0A)),
    ReaderPaper.sepia: (background: Color(0xFFF4ECD8), ink: Color(0xFF3B2F20)),
    ReaderPaper.night: (background: Color(0xFF0A0A0A), ink: Color(0xFFE5E5E5)),
  };

  /// The book's own size at 1.0; Aa scales it.
  static const _baseSize = 18.0;

  EpubTheme _theme(ReaderPaper paper) {
    final colours = _papers[paper]!;
    return EpubTheme(
      backgroundDecoration: BoxDecoration(color: colours.background),
      foregroundColor: colours.ink,
      themeType: EpubThemeType.custom,
    );
  }

  void _relocated(EpubLocation location) {
    setState(() => _location = location);
    ref.read(placeKeeperProvider)(
      widget.item.id,
      Place(locator: location.startCfi, progress: location.progress.clamp(0.0, 1.0), updatedAt: DateTime.now().toUtc()),
      finished: location.progress >= 0.999,
    );
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider).value ?? const DeviceSettings();
    final colours = _papers[settings.readerPaper]!;
    final muted = colours.ink.withValues(alpha: 0.55);
    final location = _location;
    return Scaffold(
      backgroundColor: colours.background,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 4, 4, 0),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.of(context).maybePop(),
                    tooltip: 'Close',
                    color: colours.ink,
                    icon: const Icon(Icons.keyboard_arrow_down, size: 28),
                  ),
                  Expanded(
                    child: Text(
                      widget.item.title,
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: muted, fontSize: ArkeType.sizeSm, fontWeight: FontWeight.w500),
                    ),
                  ),
                  TextButton(
                    onPressed: () => _aa(context),
                    style: TextButton.styleFrom(foregroundColor: colours.ink, minimumSize: const Size(44, 44)),
                    child: const Text(
                      'Aa',
                      style: TextStyle(fontSize: ArkeType.sizeMd, fontWeight: FontWeight.w500),
                    ),
                  ),
                  IconButton(
                    onPressed: _chapters.isEmpty ? null : () => _contents(context),
                    tooltip: 'Contents',
                    color: colours.ink,
                    icon: const Icon(Icons.format_list_bulleted),
                  ),
                ],
              ),
            ),
            Expanded(
              child: EpubViewer(
                epubController: _controller,
                epubSource: EpubSource.fromFile(File(widget.store.resolve(widget.item.file))),
                initialCfi: widget.item.finished ? null : widget.item.place?.locator,
                displaySettings: EpubDisplaySettings(
                  flow: EpubFlow.paginated,
                  snap: true,
                  fontSize: (_baseSize * settings.readerScale).round(),
                  theme: _theme(settings.readerPaper),
                ),
                onChaptersLoaded: (chapters) => setState(() => _chapters = chapters),
                onRelocated: _relocated,
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
              child: Row(
                children: [
                  Text(
                    location?.chapterPage != null && location?.chapterTotalPages != null ? '${location!.chapterPage} of ${location.chapterTotalPages}' : '',
                    style: TextStyle(color: muted, fontSize: ArkeType.size2xs, fontFeatures: const [FontFeature.tabularFigures()]),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: LinearProgressIndicator(
                      value: location?.progress ?? 0,
                      minHeight: 4,
                      color: colours.ink,
                      backgroundColor: colours.ink.withValues(alpha: 0.12),
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

  /// Contents: the book's own chapters.
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
          for (final chapter in _flatten(_chapters))
            ListTile(
              title: Text(chapter.title),
              onTap: () {
                _controller.display(cfi: chapter.href);
                Navigator.of(context).pop();
              },
            ),
        ],
      ),
    ),
  );

  static Iterable<EpubChapter> _flatten(List<EpubChapter> chapters) sync* {
    for (final chapter in chapters) {
      yield chapter;
      yield* _flatten(chapter.subitems);
    }
  }

  /// Aa: the size and the paper, both kept on the device.
  Future<void> _aa(BuildContext context) => showModalBottomSheet<void>(
    context: context,
    builder: (context) => Consumer(
      builder: (context, ref, _) {
        final settings = ref.watch(settingsProvider).value ?? const DeviceSettings();
        final controller = ref.read(settingsProvider.notifier);
        Future<void> scale(double by) async {
          final next = (settings.readerScale + by).clamp(0.7, 2.0);
          await controller.change((current) => current.copyWith(readerScale: next));
          await _controller.setFontSize(fontSize: _baseSize * next);
        }

        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: settings.readerScale > 0.7 ? () => scale(-0.1) : null,
                      style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(ArkeSizes.widePress)),
                      child: const Text('A', style: TextStyle(fontSize: ArkeType.sizeSm)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: settings.readerScale < 2.0 ? () => scale(0.1) : null,
                      style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(ArkeSizes.widePress)),
                      child: const Text('A', style: TextStyle(fontSize: ArkeType.sizeXl)),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              SegmentedButton<ReaderPaper>(
                segments: [for (final paper in ReaderPaper.values) ButtonSegment(value: paper, label: Text(paper.label))],
                selected: {settings.readerPaper},
                showSelectedIcon: false,
                onSelectionChanged: (value) async {
                  await controller.change((current) => current.copyWith(readerPaper: value.first));
                  await _controller.updateTheme(theme: _theme(value.first));
                },
              ),
            ],
          ),
        );
      },
    ),
  );
}
