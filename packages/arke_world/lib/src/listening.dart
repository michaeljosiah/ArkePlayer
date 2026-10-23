import 'dart:convert';

import 'manifest.dart';

/// A world package's listening document (SPEC-058 R-10): a narration as the Studio's Listen plays
/// it, each chapter read whole with its own audio file, its pictures and their holds, focus and
/// motion, and its phrases with their word timing. Data only: nothing in it is run.
const listeningMediaType = 'application/vnd.arke.listening+json';
const listeningFormat = 'arke-listening';
const listeningVersion = 1;

/// Media by role in a listening document (R-12).
const chapterAudioMediaTypes = {'audio/mp4'};
const motionMediaTypes = {'video/mp4'};

/// A word as it was heard, on its chapter's clock.
class ListeningWord {
  const ListeningWord({required this.at, required this.end, required this.text});
  final Duration at;
  final Duration end;
  final String text;
}

/// A phrase of Text (SPEC-047 R-70): what shows, at most two lines, while it is heard.
class ListeningPhrase {
  const ListeningPhrase({required this.at, required this.end, required this.text, this.words = const []});
  final Duration at;
  final Duration end;
  final String text;

  /// Present only where the Studio measured them; otherwise a reader estimates by character weight.
  final List<ListeningWord> words;
}

/// The point of a picture Slow push keeps still, 0 to 1 across and down (SPEC-047 R-135).
class ListeningFocus {
  const ListeningFocus(this.x, this.y);
  final double x;
  final double y;
}

enum MotionBehavior { repeat, hold }

class ListeningMotion {
  const ListeningMotion({required this.video, required this.behavior});

  /// An asset id.
  final String video;
  final MotionBehavior behavior;
}

/// A picture of the moment: from [at] for [hold], else until the next picture or the chapter's end
/// (R-14).
class ListeningPicture {
  const ListeningPicture({required this.at, required this.picture, this.hold, this.tall, this.focus, this.motion});
  final Duration at;
  final Duration? hold;

  /// An asset id: the moment's picture, Wide, or Tall when a production makes only Tall.
  final String picture;

  /// An asset id: the same moment made at 9:16, which a phone in portrait shows over the whole
  /// screen (SPEC-058 R-37, R-39; Player P14).
  final String? tall;

  /// Applies to whichever of [picture] and [tall] is shown.
  final ListeningFocus? focus;
  final ListeningMotion? motion;
}

class ListeningChapter {
  const ListeningChapter({
    required this.id,
    required this.order,
    required this.title,
    required this.duration,
    required this.audio,
    this.book,
    this.opening,
    this.pictures = const [],
    this.phrases = const [],
  });

  final String id;
  final int order;
  final String title;
  final Duration duration;

  /// Asset ids.
  final String audio;
  final String? opening;

  /// The EPUB content document this chapter reads, so Read and Listen can move between them.
  final String? book;
  final List<ListeningPicture> pictures;
  final List<ListeningPhrase> phrases;

  /// The picture showing at [time]: the last one at or before it, while it holds; before the
  /// first, none (the chapter shows its opening, else the book's cover).
  ListeningPicture? pictureAt(Duration time) {
    ListeningPicture? showing;
    for (final (i, picture) in pictures.indexed) {
      if (picture.at > time) break;
      final until = picture.hold != null ? picture.at + picture.hold! : (i + 1 < pictures.length ? pictures[i + 1].at : duration);
      showing = time < until ? picture : null;
    }
    return showing;
  }

  /// The phrase being heard at [time], if any.
  ListeningPhrase? phraseAt(Duration time) {
    for (final phrase in phrases) {
      if (phrase.at > time) break;
      if (time < phrase.end) return phrase;
    }
    return null;
  }
}

class ListeningDocument {
  const ListeningDocument({required this.title, required this.chapters, this.cover});

  final String title;

  /// An asset id.
  final String? cover;

  /// In `order`.
  final List<ListeningChapter> chapters;

  Duration get duration => chapters.fold(Duration.zero, (sum, chapter) => sum + chapter.duration);

  /// Where each chapter starts on the book's clock: chapters back to back.
  List<Duration> get starts {
    final starts = <Duration>[];
    var at = Duration.zero;
    for (final chapter in chapters) {
      starts.add(at);
      at += chapter.duration;
    }
    return starts;
  }

  /// Every asset the document names.
  Set<String> get assetIds => {
    ?cover,
    for (final chapter in chapters) ...[
      chapter.audio,
      ?chapter.opening,
      for (final picture in chapter.pictures) ...[picture.picture, ?picture.tall, ?picture.motion?.video],
    ],
  };
}

sealed class ListeningRead {
  const ListeningRead();
}

class ListeningOk extends ListeningRead {
  const ListeningOk(this.document);
  final ListeningDocument document;
}

class ListeningRefused extends ListeningRead {
  const ListeningRefused(this.refusal, this.reason);
  final WorldRefusal refusal;

  /// For a log, never the screen.
  final String reason;
}

final _slug = RegExp(r'^[a-z0-9][a-z0-9-]{0,63}$');
const _maxChapters = 1000;
const _maxPictures = 2000;
const _maxPhrases = 20000;

class _Refuse implements Exception {
  const _Refuse(this.refusal, this.reason);
  final WorldRefusal refusal;
  final String reason;
}

/// Reads a listening document against its package's inventory, as strictly as `world.json`
/// (SPEC-058 R-13, R-15): an unknown key, a newer version or a required capability is `Made with a
/// newer Arke`; an asset it names that is missing or of the wrong kind, chapters out of order, a
/// picture outside its chapter, overlapping holds, or a word outside its phrase is not an Arke
/// package. Only `metadata` objects are ignorable.
ListeningRead readListening(String text, Map<String, WorldAsset> assets) {
  try {
    return ListeningOk(_read(text, assets));
  } on _Refuse catch (refused) {
    return ListeningRefused(refused.refusal, refused.reason);
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

String _text(Object? value, String what, {int max = 400}) => value is String && value.trim().isNotEmpty && value.length <= max ? value : _notAPackage(what);

int _ticks(Object? value, String what) => value is int && value >= 0 ? value : _notAPackage(what);

ListeningDocument _read(String text, Map<String, WorldAsset> assets) {
  final Object? decoded;
  try {
    decoded = jsonDecode(text);
  } on FormatException {
    _notAPackage('the listening document is not JSON');
  }
  if (decoded is! Map<String, Object?> || decoded['format'] != listeningFormat) _notAPackage('not an $listeningFormat');
  final version = decoded['version'];
  if (version is! int) _notAPackage('no version');
  if (version > listeningVersion) _newer('listening version $version');
  if (version != listeningVersion) _notAPackage('listening version $version');
  final requires = decoded['requires'] ?? const <Object?>[];
  if (requires is! List<Object?>) _notAPackage('requires is not a list');
  if (requires.isNotEmpty) _newer('requires ${requires.join(', ')}');
  final json = _object(decoded, 'the listening document', {'format', 'version', 'requires', 'timescale', 'title', 'cover', 'chapters'});

  final timescale = json['timescale'];
  if (timescale is! int || timescale <= 0 || timescale > 1000000) _notAPackage('timescale');
  Duration time(Object? value, String what) => Duration(microseconds: _ticks(value, what) * 1000000 ~/ timescale);

  String asset(Object? id, Set<String> mediaTypes, String what) {
    if (id is! String) _notAPackage(what);
    final found = assets[id];
    if (found == null) _notAPackage('$what names $id, which is not in the inventory');
    if (!mediaTypes.contains(found.mediaType)) _notAPackage('$what $id is ${found.mediaType}');
    return id;
  }

  final title = _text(json['title'], 'title', max: 200);
  final cover = json['cover'] == null ? null : asset(json['cover'], pictureMediaTypes, 'cover');

  final rawChapters = json['chapters'];
  if (rawChapters is! List<Object?> || rawChapters.isEmpty || rawChapters.length > _maxChapters) _notAPackage('chapters');
  final chapters = <ListeningChapter>[];
  final ids = <String>{};
  final orders = <int>{};
  for (final raw in rawChapters) {
    final c = _object(raw, 'a chapter', {'id', 'order', 'title', 'duration', 'audio', 'book', 'opening', 'pictures', 'phrases'});
    final id = c['id'];
    if (id is! String || !_slug.hasMatch(id) || !ids.add(id)) _notAPackage('chapter id $id');
    final order = c['order'];
    if (order is! int || order < 1 || !orders.add(order)) _notAPackage('chapter $id order');
    final duration = time(c['duration'], 'chapter $id duration');
    if (duration <= Duration.zero) _notAPackage('chapter $id duration');
    final book = c['book'];
    if (book != null && (book is! String || book.isEmpty || book.length > 512)) _notAPackage('chapter $id book');

    final rawPictures = c['pictures'] ?? const <Object?>[];
    if (rawPictures is! List<Object?> || rawPictures.length > _maxPictures) _notAPackage('chapter $id pictures');
    final pictures = <ListeningPicture>[];
    for (final rawPicture in rawPictures) {
      final p = _object(rawPicture, 'a picture of chapter $id', {'at', 'hold', 'picture', 'tall', 'focus', 'motion'});
      final at = time(p['at'], 'chapter $id picture at');
      final hold = p['hold'] == null ? null : time(p['hold'], 'chapter $id picture hold');
      if (at >= duration) _notAPackage('chapter $id: a picture after its end');
      if (hold != null && (hold <= Duration.zero || at + hold > duration)) _notAPackage('chapter $id: a hold past its end');
      if (pictures.isNotEmpty) {
        final before = pictures.last;
        if (at <= before.at) _notAPackage('chapter $id: pictures out of order');
        if (before.hold != null && before.at + before.hold! > at) _notAPackage('chapter $id: holds overlap');
      }
      ListeningFocus? focus;
      if (p['focus'] != null) {
        final f = _object(p['focus'], 'a focus', {'x', 'y'});
        final x = f['x'];
        final y = f['y'];
        if (x is! num || y is! num || x < 0 || x > 1 || y < 0 || y > 1) _notAPackage('chapter $id: a focus off its picture');
        focus = ListeningFocus(x.toDouble(), y.toDouble());
      }
      ListeningMotion? motion;
      if (p['motion'] != null) {
        final m = _object(p['motion'], 'a motion', {'video', 'behavior'});
        final behavior = switch (m['behavior']) {
          'repeat' => MotionBehavior.repeat,
          'hold' => MotionBehavior.hold,
          _ => _notAPackage('chapter $id: a motion behavior'),
        };
        motion = ListeningMotion(video: asset(m['video'], motionMediaTypes, 'a motion'), behavior: behavior);
      }
      pictures.add(
        ListeningPicture(
          at: at,
          hold: hold,
          picture: asset(p['picture'], pictureMediaTypes, 'a picture'),
          tall: p['tall'] == null ? null : asset(p['tall'], pictureMediaTypes, 'a tall picture'),
          focus: focus,
          motion: motion,
        ),
      );
    }

    final rawPhrases = c['phrases'] ?? const <Object?>[];
    if (rawPhrases is! List<Object?> || rawPhrases.length > _maxPhrases) _notAPackage('chapter $id phrases');
    final phrases = <ListeningPhrase>[];
    for (final rawPhrase in rawPhrases) {
      final p = _object(rawPhrase, 'a phrase of chapter $id', {'at', 'end', 'text', 'words'});
      final at = time(p['at'], 'chapter $id phrase at');
      final end = time(p['end'], 'chapter $id phrase end');
      if (at >= end || end > duration) _notAPackage('chapter $id: a phrase out of its chapter');
      // In time order and apart: Text shows the first phrase still being heard, so one starting
      // before the last has ended could never be shown.
      if (phrases.isNotEmpty && at < phrases.last.end) _notAPackage('chapter $id: phrases out of order or overlapping');
      final rawWords = p['words'] ?? const <Object?>[];
      if (rawWords is! List<Object?>) _notAPackage('chapter $id words');
      final words = <ListeningWord>[];
      for (final rawWord in rawWords) {
        final w = _object(rawWord, 'a word', {'at', 'end', 'text'});
        final wordAt = time(w['at'], 'a word at');
        final wordEnd = time(w['end'], 'a word end');
        if (wordAt >= wordEnd || wordAt < at || wordEnd > end) _notAPackage('chapter $id: a word outside its phrase');
        // Words follow one another too, or a highlight has no single way through them.
        if (words.isNotEmpty && wordAt < words.last.end) _notAPackage('chapter $id: words out of order or overlapping');
        words.add(ListeningWord(at: wordAt, end: wordEnd, text: _text(w['text'], 'a word', max: 200)));
      }
      phrases.add(ListeningPhrase(at: at, end: end, text: _text(p['text'], 'a phrase', max: 2000), words: List.unmodifiable(words)));
    }

    chapters.add(
      ListeningChapter(
        id: id,
        order: order,
        title: _text(c['title'], 'chapter $id title', max: 200),
        duration: duration,
        audio: asset(c['audio'], chapterAudioMediaTypes, 'chapter $id audio'),
        book: book as String?,
        opening: c['opening'] == null ? null : asset(c['opening'], pictureMediaTypes, 'chapter $id opening'),
        pictures: List.unmodifiable(pictures),
        phrases: List.unmodifiable(phrases),
      ),
    );
  }
  chapters.sort((a, b) => a.order.compareTo(b.order));
  return ListeningDocument(title: title, cover: cover, chapters: List.unmodifiable(chapters));
}
