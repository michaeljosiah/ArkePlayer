import 'dart:typed_data';

/// A chapter from the file's own markers.
class MediaChapter {
  const MediaChapter(this.title, this.start);

  final String title;
  final Duration start;

  @override
  String toString() => 'MediaChapter($title, $start)';
}

/// A picture the file carries: an audiobook's or a song's cover, a book's cover.
class MediaCover {
  const MediaCover(this.bytes, this.mimeType);

  final Uint8List bytes;
  final String mimeType;

  /// The extension to save it with.
  String get extension => mimeType == 'image/png' ? 'png' : 'jpg';
}

/// What was read from a file before it was added (Arke Player P7 rule 3). Every field is what the
/// file says about itself, or null: nothing here is guessed or invented.
class MediaInfo {
  const MediaInfo({this.title, this.author, this.album, this.duration, this.chapters = const [], this.cover, this.protectedFile = false});

  final String? title;

  /// The artist, or a book's creator.
  final String? author;
  final String? album;
  final Duration? duration;
  final List<MediaChapter> chapters;
  final MediaCover? cover;

  /// DRM was found; the file is refused as `Protected file`.
  final bool protectedFile;
}

/// The file is not a well-formed instance of the format it claims: `Can't open this file`.
class UnreadableFile implements Exception {
  const UnreadableFile(this.reason);
  final String reason;

  @override
  String toString() => 'UnreadableFile: $reason';
}

/// Text that names nothing is no title.
String? cleanText(String? text) {
  final trimmed = text?.replaceAll('\u0000', '').trim();
  return trimmed == null || trimmed.isEmpty ? null : trimmed;
}
