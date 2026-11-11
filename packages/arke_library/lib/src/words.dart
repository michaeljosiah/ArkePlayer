import 'item.dart';

/// Sizes as the design writes them: `8 MB`, `2.1 MB`, `410 MB`, `2.4 GB` — one decimal under ten.
String formatBytes(int bytes) {
  const units = ['B', 'KB', 'MB', 'GB', 'TB'];
  var value = bytes.toDouble();
  var unit = 0;
  while (value >= 1000 && unit < units.length - 1) {
    value /= 1000;
    unit++;
  }
  if (unit == 0) return '$bytes B';
  final text = value < 10 ? value.toStringAsFixed(1).replaceFirst(RegExp(r'\.0$'), '') : value.round().toString();
  return '$text ${units[unit]}';
}

/// Lengths as the design writes them: `3:42` under ten minutes, `12 min` under an hour, `6 h 12 m`.
String formatLength(Duration length) {
  if (length < const Duration(minutes: 10)) {
    final seconds = length.inSeconds % 60;
    return '${length.inMinutes}:${seconds.toString().padLeft(2, '0')}';
  }
  if (length < const Duration(hours: 1)) return '${length.inMinutes} min';
  final minutes = length.inMinutes % 60;
  return '${length.inHours} h ${minutes.toString().padLeft(2, '0')} m';
}

/// A clock for a transport: `13:58`, `1:02:14`.
String formatClock(Duration time) {
  final hours = time.inHours;
  final minutes = time.inMinutes % 60;
  final seconds = (time.inSeconds % 60).toString().padLeft(2, '0');
  return hours > 0 ? '$hours:${minutes.toString().padLeft(2, '0')}:$seconds' : '$minutes:$seconds';
}

/// A library row's data line (P7b): the format, then the author, pages or length, then the size.
String rowLine(LibraryItem item) => [item.format.label, ?item.author, ?_extent(item), formatBytes(item.byteLength)].join(' · ');

/// A tile's short line (P8d): the format, then the author, pages or length.
String tileLine(LibraryItem item) => [item.format.label, item.author ?? _extent(item)].whereType<String>().join(' · ');

String? _extent(LibraryItem item) {
  if (item.pages != null) return '${item.pages} pages';
  if (item.duration != null) return formatLength(item.duration!);
  return null;
}

final _outsideTheCount = RegExp(r'^(?:prologue|epilogue|interlude|preface|foreword|afterword)(?![\p{L}\p{N}])', caseSensitive: false, unicode: true);

/// The number a chapter is called by (SPEC-047 R-2): its place among the chapters, counted without a prologue, an
/// interlude or an epilogue before it, and none for one of those itself. The Studio's `chapterNumber`, read from the
/// titles alone, so a package made before the rule is counted as the Studio now counts it.
int? chapterNumber(List<Chapter> chapters, int index) {
  if (_outsideTheCount.hasMatch(chapters[index].title.trim())) return null;
  return index + 1 - chapters.take(index).where((chapter) => _outsideTheCount.hasMatch(chapter.title.trim())).length;
}

/// How many of the chapters take a number: the one after them is the next.
int numberedChapters(List<Chapter> chapters) => chapters.where((chapter) => !_outsideTheCount.hasMatch(chapter.title.trim())).length;

/// `Chapter 3`, or a prologue's own title: what a place in the book is called.
String chapterName(List<Chapter> chapters, int index) => switch (chapterNumber(chapters, index)) {
  final number? => 'Chapter $number',
  null => chapters[index].title.trim(),
};

/// `3 · The Bell`, or a prologue's title alone.
String numberedTitle(List<Chapter> chapters, int index) => switch (chapterNumber(chapters, index)) {
  final number? => '$number · ${chapters[index].title}',
  null => chapters[index].title,
};

/// Where a person is, for a Continue card (P1 rule 4): a chapter and the time left in it, else the
/// time left; a page for a document.
String whereLine(LibraryItem item) {
  final place = item.place;
  if (place == null) return '';
  if (place.page != null) return item.pages != null ? 'Page ${place.page} of ${item.pages}' : 'Page ${place.page}';
  if (item.position case final position? when item.duration != null) {
    if (item.chapters.length > 1) {
      final index = item.chapters.lastIndexWhere((chapter) => chapter.start <= position);
      if (index >= 0) {
        final end = index + 1 < item.chapters.length ? item.chapters[index + 1].start : item.duration!;
        return '${chapterName(item.chapters, index)} · ${_left(end - position)}';
      }
    }
    return _left(item.duration! - position);
  }
  return '${(place.progress * 100).round()}%';
}

String _left(Duration remaining) {
  final minutes = (remaining.inSeconds / 60).ceil();
  if (minutes < 60) return '$minutes min left';
  return '${minutes ~/ 60} h ${(minutes % 60).toString().padLeft(2, '0')} m left';
}
