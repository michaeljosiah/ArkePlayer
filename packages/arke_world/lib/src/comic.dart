import 'dart:convert';

import 'manifest.dart';

/// A graphic novel's document (SPEC-064 R-50, R-51; P20): its chapters and their pages in reading
/// order, the way the book reads, its page shape and language, and each page's picture with its alt
/// text. Every page is one picture with its lettering drawn in it. Data only: nothing in it is run.
/// The Studio writes it (ArkeStudio contracts `readComic` is the other reader of the same fixtures).
const comicMediaType = 'application/vnd.arke.comic+json';
const comicFormat = 'arke-comic';
const comicVersion = 1;

/// The comic document versions this Player reads (P20 call 28): Arke's list offers a graphic novel
/// only to a Player that can read it, and shows `Update app` otherwise.
const supportedComicVersions = {comicVersion};

const maxComicChapters = 500;
const maxComicPages = 5000;

/// How a book turns (P20 rules 5, 6): left to right, right to left as manga, or one column.
enum ComicReading { ltr, rtl, scroll }

class ComicPage {
  const ComicPage({required this.picture, required this.alt});

  /// An asset id: a JPEG or PNG.
  final String picture;

  /// What the page shows and says, in reading order (SPEC-064 R-53).
  final String alt;
}

class ComicChapter {
  const ComicChapter({required this.title, required this.pages});
  final String title;

  /// In reading order, at least one.
  final List<ComicPage> pages;
}

class ComicDocument {
  const ComicDocument({required this.reading, required this.aspect, required this.language, required this.chapters});
  final ComicReading reading;

  /// The page shape, `2:3`.
  final String aspect;
  final String language;
  final List<ComicChapter> chapters;

  /// Every page in reading order.
  List<ComicPage> get pages => [for (final chapter in chapters) ...chapter.pages];

  /// Every asset the document names.
  Set<String> get assetIds => {for (final page in pages) page.picture};
}

sealed class ComicRead {
  const ComicRead();
}

class ComicOk extends ComicRead {
  const ComicOk(this.document);
  final ComicDocument document;
}

class ComicRefused extends ComicRead {
  const ComicRefused(this.refusal, this.reason);
  final WorldRefusal refusal;

  /// For a log, never the screen.
  final String reason;
}

final _slug = RegExp(r'^[a-z0-9][a-z0-9-]{0,63}$');
final _aspect = RegExp(r'^[0-9]+(?:\.[0-9]+)?:[0-9]+(?:\.[0-9]+)?$');

class _Refuse implements Exception {
  const _Refuse(this.refusal, this.reason);
  final WorldRefusal refusal;
  final String reason;
}

/// Reads a comic document against its package's inventory, as strictly as a story's: an unknown
/// key, a newer version or a required capability is `Made with a newer Arke`; a page whose picture is
/// not a picture of the package, an empty chapter, a blank title or alt text, or more pages than the
/// limit is not an Arke package. Only `metadata` is ignorable. No panel boundaries are carried: guided
/// view is not in this version (P20 call 29).
ComicRead readComic(String text, Map<String, WorldAsset> assets) {
  try {
    return ComicOk(_read(text, assets));
  } on _Refuse catch (refused) {
    return ComicRefused(refused.refusal, refused.reason);
  }
}

Never _notAPackage(String reason) => throw _Refuse(WorldRefusal.notAPackage, reason);
Never _newer(String reason) => throw _Refuse(WorldRefusal.newerArke, reason);

Map<String, Object?> _object(Object? value, String what, Set<String> keys) {
  if (value is! Map<String, Object?>) _notAPackage('$what is not an object');
  final unknown = value.keys.where((key) => !keys.contains(key) && key != 'metadata');
  if (unknown.isNotEmpty) _newer('$what keys ${unknown.join(', ')}');
  return value;
}

String _text(Object? value, String what, {required int max}) => value is String && value.trim().isNotEmpty && value.length <= max ? value : _notAPackage(what);

ComicDocument _read(String text, Map<String, WorldAsset> assets) {
  final Object? decoded;
  try {
    decoded = jsonDecode(text);
  } on FormatException {
    _notAPackage('the comic document is not JSON');
  }
  if (decoded is! Map<String, Object?> || decoded['format'] != comicFormat) _notAPackage('not an $comicFormat');
  final version = decoded['version'];
  if (version is! int) _notAPackage('no version');
  if (version > comicVersion) _newer('comic version $version');
  if (version != comicVersion) _notAPackage('comic version $version');
  final requires = decoded['requires'] ?? const <Object?>[];
  if (requires is! List<Object?>) _notAPackage('requires is not a list');
  if (requires.isNotEmpty) _newer('requires ${requires.join(', ')}');
  final json = _object(decoded, 'the comic document', {'format', 'version', 'requires', 'reading', 'aspect', 'language', 'chapters'});

  final reading = ComicReading.values.where((value) => value.name == json['reading']).firstOrNull ?? _notAPackage('reading');
  final aspect = json['aspect'];
  if (aspect is! String || !_aspect.hasMatch(aspect)) _notAPackage('aspect');
  final language = json['language'];
  if (language is! String || language.length < 2 || language.length > 35) _notAPackage('language');

  final rawChapters = json['chapters'];
  if (rawChapters is! List<Object?> || rawChapters.isEmpty || rawChapters.length > maxComicChapters) _notAPackage('chapters');
  final chapters = <ComicChapter>[];
  var count = 0;
  for (final raw in rawChapters) {
    final c = _object(raw, 'a chapter', {'title', 'pages'});
    final title = _text(c['title'], 'chapter title', max: 200);
    final rawPages = c['pages'];
    if (rawPages is! List<Object?> || rawPages.isEmpty || rawPages.length > maxComicPages) _notAPackage('chapter $title pages');
    final pages = <ComicPage>[];
    for (final rawPage in rawPages) {
      count += 1;
      final p = _object(rawPage, 'a page', {'picture', 'alt'});
      final picture = p['picture'];
      final alt = _text(p['alt'], 'page $count alt', max: 4000);
      if (picture is! String || !_slug.hasMatch(picture)) _notAPackage('page $count picture');
      final asset = assets[picture];
      if (asset == null || !pictureMediaTypes.contains(asset.mediaType)) _notAPackage('page $count names a picture it cannot show');
      pages.add(ComicPage(picture: picture, alt: alt));
    }
    chapters.add(ComicChapter(title: title, pages: List.unmodifiable(pages)));
  }
  if (count > maxComicPages) _notAPackage('pages');
  return ComicDocument(reading: reading, aspect: aspect, language: language, chapters: List.unmodifiable(chapters));
}
