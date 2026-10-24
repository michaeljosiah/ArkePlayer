import 'dart:convert';

import 'manifest.dart';

/// A music production's document (SPEC-058 R-70, Player P17): its kind and its tracks in order, each
/// with its audio, its length, its lyrics with their sections, and where in the world it is heard.
/// Data only: nothing in it is run.
const musicMediaType = 'application/vnd.arke.music+json';
const musicFormat = 'arke-music';
const musicVersion = 1;

/// Media by role in a music document: each track is AAC in M4A, rendered by the Studio's export.
const musicAudioMediaTypes = {'audio/mp4'};

/// A track is a song, not an hour (R-70), and an album at most 64 of them.
const maxMusicTrack = Duration(minutes: 15);
const maxMusicTracks = 64;

/// What a music production is (SPEC-060 R-1): tracks in order, one song, or tracks for one of the
/// world's productions.
enum MusicKind { album, single, soundtrack }

/// A part of a song as the Studio marked it: the label and where it starts on the track's clock.
/// Kept so the Player can time the lyrics by them later (P17 call 19); not shown yet.
class MusicSection {
  const MusicSection({required this.label, required this.at});
  final String label;
  final Duration at;
}

/// A track's words as written, with the sections they fall under.
class MusicLyrics {
  const MusicLyrics({required this.text, this.sections = const []});
  final String text;

  /// In order, each inside the track.
  final List<MusicSection> sections;
}

/// Where in the world a track is heard: a production, its chapter and the moment. The production may
/// be another package's; the Player shows the row only when it is installed (R-77).
class MusicHeardIn {
  const MusicHeardIn({required this.production, required this.chapter, required this.at});
  final String production;
  final String chapter;
  final Duration at;
}

class MusicTrack {
  const MusicTrack({required this.id, required this.title, required this.audio, required this.duration, this.lyrics, this.heardIn = const []});
  final String id;
  final String title;

  /// An asset id.
  final String audio;
  final Duration duration;
  final MusicLyrics? lyrics;
  final List<MusicHeardIn> heardIn;
}

class MusicDocument {
  const MusicDocument({required this.kind, required this.tracks, this.forProduction});
  final MusicKind kind;

  /// The production a soundtrack is for, by id; null on an album or a single.
  final String? forProduction;

  /// In order.
  final List<MusicTrack> tracks;

  Duration get duration => tracks.fold(Duration.zero, (sum, track) => sum + track.duration);

  /// Every asset the document names.
  Set<String> get assetIds => {for (final track in tracks) track.audio};
}

sealed class MusicRead {
  const MusicRead();
}

class MusicOk extends MusicRead {
  const MusicOk(this.document);
  final MusicDocument document;
}

class MusicRefused extends MusicRead {
  const MusicRefused(this.refusal, this.reason);
  final WorldRefusal refusal;

  /// For a log, never the screen.
  final String reason;
}

final _slug = RegExp(r'^[a-z0-9][a-z0-9-]{0,63}$');

class _Refuse implements Exception {
  const _Refuse(this.refusal, this.reason);
  final WorldRefusal refusal;
  final String reason;
}

/// Reads a music document against its package's inventory, as strictly as the listening document
/// (SPEC-058 R-70): an unknown key, a newer version or a required capability is `Made with a newer
/// Arke`; an id that repeats, an asset missing or not audio, a section outside its track or out of
/// order, a single with more than one track, or a `for` on anything but a soundtrack is not an Arke
/// package. `heardIn` names the world's productions, not only the package's, so it is not checked
/// against the package. Only `metadata` objects are ignorable.
MusicRead readMusic(String text, Map<String, WorldAsset> assets) {
  try {
    return MusicOk(_read(text, assets));
  } on _Refuse catch (refused) {
    return MusicRefused(refused.refusal, refused.reason);
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

String _text(Object? value, String what, {int max = 200}) => value is String && value.trim().isNotEmpty && value.length <= max ? value : _notAPackage(what);

String _id(Object? value, String what) => value is String && _slug.hasMatch(value) ? value : _notAPackage(what);

Duration _ms(Object? value, String what) => value is int && value >= 0 ? Duration(milliseconds: value) : _notAPackage(what);

MusicDocument _read(String text, Map<String, WorldAsset> assets) {
  final Object? decoded;
  try {
    decoded = jsonDecode(text);
  } on FormatException {
    _notAPackage('the music document is not JSON');
  }
  if (decoded is! Map<String, Object?> || decoded['format'] != musicFormat) _notAPackage('not an $musicFormat');
  final version = decoded['version'];
  if (version is! int) _notAPackage('no version');
  if (version > musicVersion) _newer('music version $version');
  if (version != musicVersion) _notAPackage('music version $version');
  final requires = decoded['requires'] ?? const <Object?>[];
  if (requires is! List<Object?>) _notAPackage('requires is not a list');
  if (requires.isNotEmpty) _newer('requires ${requires.join(', ')}');
  final json = _object(decoded, 'the music document', {'format', 'version', 'requires', 'kind', 'for', 'tracks'});

  final kind = MusicKind.values.where((kind) => kind.name == json['kind']).firstOrNull ?? _notAPackage('kind');
  final forProduction = json['for'] == null ? null : _id(json['for'], 'for');
  if (kind == MusicKind.soundtrack && forProduction == null) _notAPackage('a soundtrack names the production it is for');
  if (kind != MusicKind.soundtrack && forProduction != null) _notAPackage('an ${kind.name} is for no production');

  final rawTracks = json['tracks'];
  if (rawTracks is! List<Object?> || rawTracks.isEmpty || rawTracks.length > maxMusicTracks) _notAPackage('tracks');
  if (kind == MusicKind.single && rawTracks.length != 1) _notAPackage('a single holds one track');
  final tracks = <MusicTrack>[];
  final ids = <String>{};
  for (final raw in rawTracks) {
    final t = _object(raw, 'a track', {'id', 'title', 'audio', 'duration', 'lyrics', 'heardIn'});
    final id = _id(t['id'], 'track id');
    if (!ids.add(id)) _notAPackage('track $id repeats');
    final where = 'track $id';
    final duration = t['duration'];
    if (duration is! int || duration < 1 || Duration(milliseconds: duration) > maxMusicTrack) _notAPackage('$where duration');
    final length = Duration(milliseconds: duration);
    final audio = t['audio'];
    if (audio is! String || assets[audio] == null || !musicAudioMediaTypes.contains(assets[audio]!.mediaType)) _notAPackage('$where audio');

    MusicLyrics? lyrics;
    if (t['lyrics'] != null) {
      final l = _object(t['lyrics'], '$where lyrics', {'text', 'sections'});
      final rawSections = l['sections'] ?? const <Object?>[];
      if (rawSections is! List<Object?> || rawSections.length > 200) _notAPackage('$where sections');
      final sections = <MusicSection>[];
      for (final rawSection in rawSections) {
        final s = _object(rawSection, 'a section of $where', {'label', 'at'});
        final at = _ms(s['at'], '$where section at');
        if (at >= length) _notAPackage('$where: a section after its end');
        if (sections.isNotEmpty && at <= sections.last.at) _notAPackage('$where: sections out of order');
        sections.add(MusicSection(label: _text(s['label'], '$where section label', max: 100), at: at));
      }
      lyrics = MusicLyrics(text: _text(l['text'], '$where lyrics', max: 20000), sections: List.unmodifiable(sections));
    }

    final rawHeard = t['heardIn'] ?? const <Object?>[];
    if (rawHeard is! List<Object?> || rawHeard.length > 200) _notAPackage('$where heardIn');
    final heardIn = [
      for (final rawRow in rawHeard)
        () {
          final h = _object(rawRow, 'where $where is heard', {'production', 'chapter', 'at'});
          return MusicHeardIn(
            production: _id(h['production'], '$where heardIn'),
            chapter: _id(h['chapter'], '$where heardIn'),
            at: _ms(h['at'], '$where heardIn at'),
          );
        }(),
    ];

    tracks.add(
      MusicTrack(id: id, title: _text(t['title'], '$where title'), audio: audio, duration: length, lyrics: lyrics, heardIn: List.unmodifiable(heardIn)),
    );
  }
  return MusicDocument(kind: kind, forProduction: forProduction, tracks: List.unmodifiable(tracks));
}
