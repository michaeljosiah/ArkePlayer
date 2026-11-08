import 'dart:io';

import 'package:arke_library/arke_library.dart';
import 'package:flutter/material.dart';

import '../../../app/theme/tokens.dart';
import '../../../app/widgets/shelf.dart';
import '../application/listening_plan.dart';

const _fg = ArkeColors.mediaOverlayForeground;

/// A title's episodes come in ranges of 50, past which a list is too long to find a place in (P24 rule 2).
const _range = 50;

/// `1–50`, `51–100` … `201–248`: the ranges of [count] episodes, none when there is only one.
List<(int first, int last)> episodeRanges(int count) =>
    count <= _range ? const [] : [for (var first = 0; first < count; first += _range) (first, first + _range > count ? count - 1 : first + _range - 1)];

/// The range holding episode [index].
int rangeOf(int index) => index ~/ _range;

/// An episode's upright picture: its first Tall, else its first Wide, else what opens it.
ImageProvider? episodePicture(ListeningPlan plan, int index) {
  final chapter = plan.chapters[index];
  final first = chapter.pictures.firstOrNull;
  final asset = first?.tall ?? first?.picture ?? chapter.opening;
  if (asset != null) return FileImage(File(plan.pathIn(index, asset)));
  final cover = plan.document.cover;
  return cover == null ? null : FileImage(File(plan.pathOf(cover)));
}

/// The ranges' chips, the same in the player and on the Story tab.
class RangeChips extends StatelessWidget {
  const RangeChips({required this.count, required this.selected, required this.onSelect, super.key});

  final int count;
  final int selected;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) => LabelChips<int>(
    all: false,
    options: [for (final (i, (first, last)) in episodeRanges(count).indexed) (i, '${first + 1}–${last + 1}')],
    selected: selected,
    onSelect: (value) {
      if (value != null) onSelect(value);
    },
  );
}

/// Episodes over what plays (P24f), or beside it: in ranges, the one playing marked, each heard ticked.
class EpisodeRows extends StatefulWidget {
  const EpisodeRows({required this.plan, required this.position, required this.onOpen, super.key});

  final ListeningPlan plan;
  final Duration position;
  final ValueChanged<int> onOpen;

  @override
  State<EpisodeRows> createState() => _EpisodeRowsState();
}

class _EpisodeRowsState extends State<EpisodeRows> {
  late int _shownRange = rangeOf(_playing);

  int get _playing => widget.plan.locate(widget.position).$1;

  @override
  Widget build(BuildContext context) {
    final plan = widget.plan;
    final count = plan.chapters.length;
    final ranges = episodeRanges(count);
    final (first, last) = ranges.isEmpty ? (0, count - 1) : ranges[_shownRange];
    final (playing, into) = plan.locate(widget.position);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (ranges.isNotEmpty) RangeChips(count: count, selected: _shownRange, onSelect: (value) => setState(() => _shownRange = value)),
        Flexible(
          child: ListView.builder(
            shrinkWrap: true,
            padding: const EdgeInsets.only(top: 4),
            itemCount: last - first + 1,
            itemBuilder: (context, offset) {
              final index = first + offset;
              final chapter = plan.chapters[index];
              return _EpisodeRow(
                number: index + 1,
                title: chapter.title,
                length: chapter.duration,
                picture: episodePicture(plan, index),
                now: index == playing,
                heard: index < playing,
                into: index == playing ? into : null,
                onOpen: () => widget.onOpen(index),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _EpisodeRow extends StatelessWidget {
  const _EpisodeRow({
    required this.number,
    required this.title,
    required this.length,
    required this.picture,
    required this.now,
    required this.heard,
    required this.into,
    required this.onOpen,
  });

  final int number;
  final String title;
  final Duration length;
  final ImageProvider? picture;
  final bool now;
  final bool heard;
  final Duration? into;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final left = into == null ? null : length - into!;
    return Semantics(
      button: true,
      selected: now,
      label: ['$number · $title', formatClock(length), if (heard) 'Heard'].join(', '),
      child: ExcludeSemantics(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          child: Material(
            color: now ? _fg.withValues(alpha: 0.12) : Colors.transparent,
            borderRadius: BorderRadius.circular(16),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: onOpen,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(8, 7, 12, 7),
                child: Row(
                  children: [
                    EpisodeThumb(picture: picture),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '$number · $title',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: text.bodyMedium?.copyWith(
                              fontSize: ArkeType.sizeBase,
                              color: heard ? _fg.withValues(alpha: 0.56) : _fg,
                              fontWeight: now ? FontWeight.w600 : FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            [formatClock(length), if (left != null) '${formatClock(left)} left'].join(' · '),
                            style: text.labelSmall?.copyWith(color: _fg.withValues(alpha: 0.66), fontFeatures: const [FontFeature.tabularFigures()]),
                          ),
                          if (now) ...[
                            const SizedBox(height: 7),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(ArkeRadius.pill),
                              child: LinearProgressIndicator(
                                value: length.inMilliseconds == 0 ? 0 : (into ?? Duration.zero).inMilliseconds / length.inMilliseconds,
                                minHeight: 3,
                                color: _fg,
                                backgroundColor: _fg.withValues(alpha: 0.2),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    if (now)
                      Icon(Icons.equalizer_rounded, size: 18, color: _fg.withValues(alpha: 0.8))
                    else if (heard)
                      Icon(Icons.check_rounded, size: 18, color: _fg.withValues(alpha: 0.66)),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// An episode's picture in a row: 44 × 66, upright (P24 rule 2).
class EpisodeThumb extends StatelessWidget {
  const EpisodeThumb({required this.picture, super.key});

  final ImageProvider? picture;

  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(9),
    child: SizedBox(
      width: 44,
      height: 66,
      child: ColoredBox(
        color: ArkeColors.neutral800,
        child: picture == null ? null : Image(image: picture!, fit: BoxFit.cover, errorBuilder: (context, error, stack) => const SizedBox.shrink()),
      ),
    ),
  );
}
