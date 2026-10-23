import 'dart:io';

import 'package:arke_library/arke_library.dart';
import 'package:arke_world/arke_world.dart';

/// What shows at a moment of an illustrated narration: a picture with the span it shows for, on
/// the book's clock, so Slow push can move across it (SPEC-058 R-22, R-23).
class ShownPicture {
  const ShownPicture({
    required this.path,
    required this.start,
    required this.end,
    this.tallPath,
    this.focus,
    this.motionPath,
    this.motionRepeats = true,
    this.pushes = true,
  });

  final String path;
  final Duration start;
  final Duration end;

  /// The same moment made at 9:16, which a phone in portrait shows over the whole screen
  /// (SPEC-058 R-37, R-39; Player P14). Null for a picture made Wide alone, an opening and the cover.
  final String? tallPath;
  final ListeningFocus? focus;
  final String? motionPath;
  final bool motionRepeats;

  /// Slow push moves stills only: a loop keeps its own movement, and the cover stays still
  /// (SPEC-047 R-75).
  final bool pushes;

  /// The Tall picture in this one's place, over the same span, so turning the phone keeps the
  /// place in the hold (P14 rule 4). A loop is made from the Wide picture and would not cover the
  /// Tall one, so the Tall picture shows as a still and Slow push moves it.
  ShownPicture get tall => ShownPicture(path: tallPath ?? path, start: start, end: end, tallPath: tallPath, focus: focus, pushes: tallPath != null || pushes);

  /// How far through its span [time] is, 0 to 1.
  double progressAt(Duration time) {
    final span = (end - start).inMilliseconds;
    return span <= 0 ? 0 : ((time - start).inMilliseconds / span).clamp(0.0, 1.0);
  }
}

/// An installed world's listening document with its files resolved (SPEC-058 R-10). Every time
/// here is on the book's clock: the chapters back to back, as the library item's chapters are.
class ListeningPlan {
  ListeningPlan({required this.document, required this.pathOf}) : starts = document.starts;

  final ListeningDocument document;
  final String Function(String assetId) pathOf;
  final List<Duration> starts;

  List<ListeningChapter> get chapters => document.chapters;

  /// The chapter playing at [time], and how far into it.
  (int, Duration) locate(Duration time) {
    var index = 0;
    for (final (i, start) in starts.indexed) {
      if (start <= time) index = i;
    }
    final offset = time - starts[index];
    final duration = chapters[index].duration;
    return (index, offset < Duration.zero ? Duration.zero : (offset > duration ? duration : offset));
  }

  /// The picture of the moment: the chapter's picture showing, else before its first its opening,
  /// else the book's cover (SPEC-047 R-69); null with none at all.
  ShownPicture? shownAt(Duration time) {
    final (index, offset) = locate(time);
    final chapter = chapters[index];
    final start = starts[index];
    final picture = chapter.pictureAt(offset);
    if (picture != null) {
      final next = chapter.pictures.where((p) => p.at > picture.at).firstOrNull;
      final end = picture.hold != null ? picture.at + picture.hold! : (next?.at ?? chapter.duration);
      return ShownPicture(
        path: pathOf(picture.picture),
        start: start + picture.at,
        end: start + end,
        tallPath: picture.tall == null ? null : pathOf(picture.tall!),
        focus: picture.focus,
        motionPath: picture.motion == null ? null : pathOf(picture.motion!.video),
        motionRepeats: picture.motion?.behavior != MotionBehavior.hold,
        pushes: picture.motion == null,
      );
    }
    final still = chapter.opening ?? document.cover;
    if (still == null) return null;
    // From the chapter's start, or the end of the hold that left this gap, until the next picture
    // or the chapter's end: so a push across a gap starts with the gap, not with the chapter.
    final before = chapter.pictures.where((p) => p.at <= offset).lastOrNull;
    final from = before?.hold == null ? Duration.zero : before!.at + before.hold!;
    final next = chapter.pictures.where((p) => p.at > offset).firstOrNull;
    return ShownPicture(path: pathOf(still), start: start + from, end: start + (next?.at ?? chapter.duration), pushes: chapter.opening != null);
  }

  /// The phrase being heard at [time], for Text (SPEC-047 R-70).
  ListeningPhrase? phraseAt(Duration time) {
    final (index, offset) = locate(time);
    return chapters[index].phraseAt(offset);
  }

  /// Where a place kept as a chapter and an offset is on the book's clock; a chapter this edition
  /// no longer has is its start.
  Duration timeOf(String? chapterId, Duration offset) {
    final index = chapters.indexWhere((chapter) => chapter.id == chapterId);
    return index < 0 ? Duration.zero : starts[index] + offset;
  }
}

/// Reads an installed world's listening document against the manifest kept beside its files.
Future<ListeningPlan> loadListeningPlan(LibraryStore store, LibraryItem item) async {
  final folder = store.worldDirectory(item.worldId!).path;
  final manifest = switch (readWorldManifest(await File('$folder${Platform.pathSeparator}$worldManifestFile').readAsString())) {
    WorldManifestOk(:final manifest) => manifest,
    WorldManifestRefused(:final reason) => throw FormatException(reason),
  };
  final document = switch (readListening(await File(store.resolve(item.file)).readAsString(), manifest.assets)) {
    ListeningOk(:final document) => document,
    ListeningRefused(:final reason) => throw FormatException(reason),
  };
  String pathOf(String assetId) => '$folder${Platform.pathSeparator}${manifest.assets[assetId]!.path.replaceAll('/', Platform.pathSeparator)}';
  return ListeningPlan(document: document, pathOf: pathOf);
}
