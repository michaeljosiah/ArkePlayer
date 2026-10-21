import 'package:arke_publication/arke_publication.dart';

/// What a person does with a file: the chips of a library of files (Arke Player P8 rule 4), in
/// the order a world's groups take (P1 rule 6).
enum LibraryKind {
  listen('Listen'),
  read('Read'),
  watch('Watch');

  const LibraryKind(this.label);
  final String label;

  static LibraryKind of(FileFormat format) => switch (format) {
    FileFormat.m4b || FileFormat.m4a || FileFormat.mp3 || FileFormat.listening => LibraryKind.listen,
    FileFormat.epub || FileFormat.pdf || FileFormat.cbz => LibraryKind.read,
    FileFormat.mp4 || FileFormat.mov => LibraryKind.watch,
    FileFormat.arkePackage || FileFormat.srt || FileFormat.vtt => throw ArgumentError('$format is not a library file'),
  };
}

/// A chapter of an audiobook, from the file's own markers.
class Chapter {
  const Chapter({required this.title, required this.start});

  final String title;
  final Duration start;

  Map<String, Object?> toJson() => {'title': title, 'startMs': start.inMilliseconds};

  static Chapter fromJson(Map<String, Object?> json) => Chapter(
    title: json['title']! as String,
    start: Duration(milliseconds: json['startMs']! as int),
  );
}

/// Where a person is in a file. Only one of [position], [locator] and [page] means anything for
/// a given file: a time for audio and video, an EPUB location for a book, a page for a PDF.
class Place {
  const Place({required this.progress, required this.updatedAt, this.position, this.locator, this.page});

  final Duration? position;

  /// An EPUB CFI.
  final String? locator;
  final int? page;

  /// 0 to 1, for Continue's line of progress.
  final double progress;
  final DateTime updatedAt;

  Map<String, Object?> toJson() => {
    'progress': progress,
    'updatedAt': updatedAt.toUtc().toIso8601String(),
    if (position != null) 'positionMs': position!.inMilliseconds,
    if (locator != null) 'locator': locator,
    if (page != null) 'page': page,
  };

  static Place fromJson(Map<String, Object?> json) => Place(
    progress: (json['progress']! as num).toDouble(),
    updatedAt: DateTime.parse(json['updatedAt']! as String),
    position: json['positionMs'] == null ? null : Duration(milliseconds: json['positionMs']! as int),
    locator: json['locator'] as String?,
    page: json['page'] as int?,
  );
}

/// One added file and what was read from it before it was added (P7 rule 3).
class LibraryItem {
  const LibraryItem({
    required this.id,
    required this.format,
    required this.title,
    required this.byteLength,
    required this.addedAt,
    required this.file,
    this.author,
    this.duration,
    this.pages,
    this.cover,
    this.captions,
    this.chapters = const [],
    this.place,
    this.finished = false,
    this.worldId,
  });

  final String id;
  final FileFormat format;

  /// What the file names itself, else the file's own name.
  final String title;
  final String? author;
  final Duration? duration;
  final int? pages;
  final int byteLength;
  final DateTime addedAt;

  /// Paths relative to the library's root: the file, its cover, a video's captions.
  final String file;
  final String? cover;
  final String? captions;
  final List<Chapter> chapters;

  final Place? place;
  final bool finished;

  /// The installed world this item's file came with, or null for a file added from the phone.
  /// A world's items play and keep places as files do, but show under their world, never as
  /// files of their own (P9 rule 6).
  final String? worldId;

  LibraryKind get kind => LibraryKind.of(format);

  /// In progress: opened, not finished, and somewhere past the start.
  bool get inProgress => place != null && !finished && place!.progress > 0;

  LibraryItem copyWith({Place? place, bool? finished}) => LibraryItem(
    id: id,
    format: format,
    title: title,
    byteLength: byteLength,
    addedAt: addedAt,
    file: file,
    author: author,
    duration: duration,
    pages: pages,
    cover: cover,
    captions: captions,
    chapters: chapters,
    place: place ?? this.place,
    finished: finished ?? this.finished,
    worldId: worldId,
  );

  Map<String, Object?> toJson() => {
    'id': id,
    'format': format.name,
    'title': title,
    if (author != null) 'author': author,
    if (duration != null) 'durationMs': duration!.inMilliseconds,
    if (pages != null) 'pages': pages,
    'byteLength': byteLength,
    'addedAt': addedAt.toUtc().toIso8601String(),
    'file': file,
    if (cover != null) 'cover': cover,
    if (captions != null) 'captions': captions,
    if (chapters.isNotEmpty) 'chapters': [for (final chapter in chapters) chapter.toJson()],
    if (place != null) 'place': place!.toJson(),
    if (finished) 'finished': true,
    if (worldId != null) 'worldId': worldId,
  };

  static LibraryItem fromJson(Map<String, Object?> json) => LibraryItem(
    id: json['id']! as String,
    format: FileFormat.values.byName(json['format']! as String),
    title: json['title']! as String,
    author: json['author'] as String?,
    duration: json['durationMs'] == null ? null : Duration(milliseconds: json['durationMs']! as int),
    pages: json['pages'] as int?,
    byteLength: json['byteLength']! as int,
    addedAt: DateTime.parse(json['addedAt']! as String),
    file: json['file']! as String,
    cover: json['cover'] as String?,
    captions: json['captions'] as String?,
    chapters: [for (final chapter in (json['chapters'] as List<Object?>? ?? const [])) Chapter.fromJson((chapter! as Map).cast<String, Object?>())],
    place: json['place'] == null ? null : Place.fromJson((json['place']! as Map).cast<String, Object?>()),
    finished: json['finished'] == true,
    worldId: json['worldId'] as String?,
  );
}
