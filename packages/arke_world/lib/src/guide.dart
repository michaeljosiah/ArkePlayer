import 'dart:convert';

import 'manifest.dart';

/// A world's guide (SPEC-059 R-11): what its author made public of the world's characters, places
/// and settled lore, each from the start or after a chapter. Data only, and only what a reader is
/// given (R-12): no notes, no canon status, nothing unpublished.
const guideMediaType = 'application/vnd.arke.guide+json';
const guideFormat = 'arke-guide';
const guideVersion = 1;

/// Media by role in a guide (R-13).
const guideVoiceMediaTypes = {'audio/mp4'};

/// A line in a character's voice is a sentence, not a scene (R-6).
const maxGuideVoice = Duration(seconds: 15);

/// Canon's entry types (SPEC-059 §1.3). Lore files them under Lore, Rules and Timeline; the rest
/// show under All.
enum LoreKind { lore, rule, timeline, location, faction, tone, thread }

/// A chapter an entry or section waits for: a production of the guide and one of its chapters.
class GuideAfter {
  const GuideAfter({required this.production, required this.chapter, required this.number});
  final String production;
  final String chapter;

  /// The chapter's number as a reader knows it, After Chapter [number].
  final int number;
}

/// A chapter of a production the guide names, with the number a reader knows it by.
class GuideChapter {
  const GuideChapter({required this.id, required this.number, this.book});
  final String id;
  final int number;

  /// The EPUB content document this chapter reads, so a place in the book finds its chapter.
  final String? book;
}

/// What the guide's `after`s and voice lines name: a production's chapters in manuscript order.
/// The guide carries them because a guide alone has no production to read them from.
class GuideProduction {
  const GuideProduction({required this.id, required this.title, required this.chapters});
  final String id;
  final String title;

  /// In manuscript order.
  final List<GuideChapter> chapters;
}

class GuideSection {
  const GuideSection({required this.heading, required this.text, this.after});
  final String heading;
  final String text;
  final GuideAfter? after;
}

/// A line the character speaks in a take of a chapter read whole, as it was heard.
class GuideVoice {
  const GuideVoice({required this.audio, required this.text, required this.duration, required this.production, required this.chapter});

  /// An asset id.
  final String audio;
  final String text;
  final Duration duration;
  final String production;
  final String chapter;
}

/// An entry of the guide: a character, a place or a piece of lore. [links] name other entries.
sealed class GuideEntry {
  const GuideEntry({required this.id, required this.links, this.after});
  final String id;
  final GuideAfter? after;
  final List<String> links;
}

class GuideCharacter extends GuideEntry {
  const GuideCharacter({
    required super.id,
    required this.name,
    required this.sections,
    super.links = const [],
    super.after,
    this.role,
    this.portrait,
    this.voice,
  });
  final String name;
  final String? role;

  /// An asset id.
  final String? portrait;
  final List<GuideSection> sections;
  final GuideVoice? voice;
}

/// A place, or a faction, which follows the places (SPEC-059 R-1).
class GuidePlace extends GuideEntry {
  const GuidePlace({required super.id, required this.name, required this.sections, super.links = const [], super.after, this.role, this.picture});
  final String name;
  final String? role;

  /// An asset id.
  final String? picture;
  final List<GuideSection> sections;
}

/// A settled canon entry: its statement, with no sections.
class GuideLore extends GuideEntry {
  const GuideLore({required super.id, required this.kind, required this.title, required this.text, super.links = const [], super.after});
  final LoreKind kind;
  final String title;
  final String text;
}

class Guide {
  const Guide({required this.productions, required this.characters, required this.places, required this.lore});
  final List<GuideProduction> productions;
  final List<GuideCharacter> characters;
  final List<GuidePlace> places;
  final List<GuideLore> lore;

  List<GuideEntry> get entries => [...characters, ...places, ...lore];

  GuideEntry? entry(String id) {
    for (final entry in entries) {
      if (entry.id == id) return entry;
    }
    return null;
  }

  /// Every asset the guide names.
  Set<String> get assetIds => {
    for (final character in characters) ...[?character.portrait, ?character.voice?.audio],
    for (final place in places) ?place.picture,
  };
}

sealed class GuideRead {
  const GuideRead();
}

class GuideOk extends GuideRead {
  const GuideOk(this.guide);
  final Guide guide;
}

class GuideRefused extends GuideRead {
  const GuideRefused(this.refusal, this.reason);
  final WorldRefusal refusal;

  /// For a log, never the screen.
  final String reason;
}

final _slug = RegExp(r'^[a-z0-9][a-z0-9-]{0,63}$');
const _maxProductions = 64;
const _maxChapters = 1000;
const _maxEntries = 2000;
const _maxSections = 64;
const _maxLinks = 200;

class _Refuse implements Exception {
  const _Refuse(this.refusal, this.reason);
  final WorldRefusal refusal;
  final String reason;
}

/// Reads a guide document against its package's inventory, as strictly as the listening document
/// (SPEC-059 R-14): an unknown key, a newer version or a required capability is `Made with a newer
/// Arke`; an id that repeats anywhere in the guide (a link names an entry without its kind), a link
/// or `after` that names nothing, an empty section, an asset that is missing or of the wrong kind,
/// or a voice line over 15 seconds is not an Arke package. Only `metadata` objects are ignorable.
GuideRead readGuide(String text, Map<String, WorldAsset> assets) {
  try {
    return GuideOk(_read(text, assets));
  } on _Refuse catch (refused) {
    return GuideRefused(refused.refusal, refused.reason);
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

List<Object?> _list(Object? value, String what, int max) => value is List<Object?> && value.length <= max ? value : _notAPackage(what);

String _text(Object? value, String what, {int max = 200}) => value is String && value.trim().isNotEmpty && value.length <= max ? value : _notAPackage(what);

String _id(Object? value, String what) => value is String && _slug.hasMatch(value) ? value : _notAPackage(what);

Guide _read(String text, Map<String, WorldAsset> assets) {
  final Object? decoded;
  try {
    decoded = jsonDecode(text);
  } on FormatException {
    _notAPackage('the guide is not JSON');
  }
  if (decoded is! Map<String, Object?> || decoded['format'] != guideFormat) _notAPackage('not an $guideFormat');
  final version = decoded['version'];
  if (version is! int) _notAPackage('no version');
  if (version > guideVersion) _newer('guide version $version');
  if (version != guideVersion) _notAPackage('guide version $version');
  final requires = decoded['requires'] ?? const <Object?>[];
  if (requires is! List<Object?>) _notAPackage('requires is not a list');
  if (requires.isNotEmpty) _newer('requires ${requires.join(', ')}');
  final json = _object(decoded, 'the guide', {'format', 'version', 'requires', 'productions', 'characters', 'places', 'lore'});

  final productions = <GuideProduction>[];
  final numbers = <String, Map<String, int>>{};
  for (final raw in _list(json['productions'], 'productions', _maxProductions)) {
    final p = _object(raw, 'a production', {'id', 'title', 'chapters'});
    final id = _id(p['id'], 'production id');
    if (numbers.containsKey(id)) _notAPackage('production $id repeats');
    final chapters = <GuideChapter>[];
    final byId = <String, int>{};
    for (final rawChapter in _list(p['chapters'], 'production $id chapters', _maxChapters)) {
      final c = _object(rawChapter, 'a chapter of $id', {'id', 'number', 'book'});
      final chapterId = _id(c['id'], 'production $id chapter id');
      final number = c['number'];
      if (number is! int || number < 1) _notAPackage('production $id chapter $chapterId number');
      if (byId.containsKey(chapterId)) _notAPackage('production $id: chapter $chapterId repeats');
      if (chapters.isNotEmpty && number <= chapters.last.number) _notAPackage('production $id: chapters out of order');
      final book = c['book'];
      if (book != null && (book is! String || book.isEmpty || book.length > 512)) _notAPackage('production $id chapter $chapterId book');
      byId[chapterId] = number;
      chapters.add(GuideChapter(id: chapterId, number: number, book: book as String?));
    }
    numbers[id] = byId;
    productions.add(GuideProduction(id: id, title: _text(p['title'], 'production $id title'), chapters: List.unmodifiable(chapters)));
  }

  GuideAfter? after(Object? value, String what) {
    if (value == null) return null;
    final a = _object(value, '$what after', {'production', 'chapter'});
    final production = _id(a['production'], '$what after');
    final chapter = _id(a['chapter'], '$what after');
    final number = numbers[production]?[chapter];
    if (number == null) _notAPackage('$what: after names no chapter of the guide');
    return GuideAfter(production: production, chapter: chapter, number: number);
  }

  String? asset(Object? id, Set<String> mediaTypes, String what) {
    if (id == null) return null;
    if (id is! String) _notAPackage(what);
    final found = assets[id];
    if (found == null || !mediaTypes.contains(found.mediaType)) _notAPackage(what);
    return id;
  }

  List<GuideSection> sections(Object? value, String what) => List.unmodifiable([
    for (final raw in _list(value, '$what sections', _maxSections))
      () {
        final s = _object(raw, 'a section of $what', {'heading', 'text', 'after'});
        return GuideSection(
          heading: _text(s['heading'], '$what section heading'),
          text: _text(s['text'], '$what section text', max: 20000),
          after: after(s['after'], "$what's section"),
        );
      }(),
  ]);

  List<String> links(Object? value, String what) => [
    for (final link in _list(value ?? const <Object?>[], '$what links', _maxLinks)) link is String ? link : _notAPackage('$what links'),
  ];

  final characters = <GuideCharacter>[];
  for (final raw in _list(json['characters'], 'characters', _maxEntries)) {
    final c = _object(raw, 'a character', {'id', 'name', 'role', 'portrait', 'after', 'sections', 'voice', 'links'});
    final id = _id(c['id'], 'character id');
    final where = 'entry $id';
    GuideVoice? voice;
    if (c['voice'] != null) {
      final v = _object(c['voice'], '$where voice', {'audio', 'text', 'duration', 'production', 'chapter'});
      final duration = v['duration'];
      if (duration is! int || duration < 1 || Duration(milliseconds: duration) > maxGuideVoice) _notAPackage('$where: voice duration');
      final production = _id(v['production'], '$where voice');
      final chapter = _id(v['chapter'], '$where voice');
      if (numbers[production]?[chapter] == null) _notAPackage('$where: the voice names no chapter of the guide');
      voice = GuideVoice(
        audio: asset(v['audio'], guideVoiceMediaTypes, '$where: voice') ?? _notAPackage('$where: voice'),
        text: _text(v['text'], '$where voice text', max: 2000),
        duration: Duration(milliseconds: duration),
        production: production,
        chapter: chapter,
      );
    }
    final role = c['role'];
    characters.add(
      GuideCharacter(
        id: id,
        name: _text(c['name'], '$where name'),
        role: role == null ? null : _text(role, '$where role'),
        portrait: asset(c['portrait'], pictureMediaTypes, '$where: portrait'),
        after: after(c['after'], where),
        sections: sections(c['sections'], where),
        voice: voice,
        links: links(c['links'], where),
      ),
    );
  }

  final places = <GuidePlace>[];
  for (final raw in _list(json['places'], 'places', _maxEntries)) {
    final p = _object(raw, 'a place', {'id', 'name', 'role', 'picture', 'after', 'sections', 'links'});
    final id = _id(p['id'], 'place id');
    final where = 'entry $id';
    final role = p['role'];
    places.add(
      GuidePlace(
        id: id,
        name: _text(p['name'], '$where name'),
        role: role == null ? null : _text(role, '$where role'),
        picture: asset(p['picture'], pictureMediaTypes, '$where: picture'),
        after: after(p['after'], where),
        sections: sections(p['sections'], where),
        links: links(p['links'], where),
      ),
    );
  }

  final lore = <GuideLore>[];
  for (final raw in _list(json['lore'], 'lore', _maxEntries)) {
    final l = _object(raw, 'a lore entry', {'id', 'kind', 'title', 'text', 'after', 'links'});
    final id = _id(l['id'], 'lore id');
    final where = 'entry $id';
    final kind = LoreKind.values.where((kind) => kind.name == l['kind']).firstOrNull ?? _notAPackage('$where kind');
    lore.add(
      GuideLore(
        id: id,
        kind: kind,
        title: _text(l['title'], '$where title'),
        text: _text(l['text'], '$where text', max: 20000),
        after: after(l['after'], where),
        links: links(l['links'], where),
      ),
    );
  }

  final guide = Guide(
    productions: List.unmodifiable(productions),
    characters: List.unmodifiable(characters),
    places: List.unmodifiable(places),
    lore: List.unmodifiable(lore),
  );
  final ids = <String>{};
  for (final entry in guide.entries) {
    if (!ids.add(entry.id)) _notAPackage('entry ${entry.id} repeats');
  }
  for (final entry in guide.entries) {
    for (final link in entry.links) {
      if (!ids.contains(link)) _notAPackage('entry ${entry.id}: a link to $link, which is not in the guide');
    }
  }
  return guide;
}
