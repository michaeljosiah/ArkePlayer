import 'dart:convert';

import 'package:arke_publication/arke_publication.dart';

import 'guide.dart';
import 'listening.dart';

/// The manifest at a world package's root.
const worldManifestFile = 'world.json';

/// The format a world package names itself by. This is the Player's proposal: SPEC-048 defines a
/// publication package but no package of a world, and owes one (Arke Player ADR 0005).
const worldPackageFormat = 'arke-world-package';

/// Schema 2 (SPEC-058 R-9) adds a production's `listening` document; schema 3 (SPEC-059 R-9, R-10)
/// adds the world's `guide`, and a package with the guide alone; schema 4 (SPEC-058 R-46) is a part,
/// the chapters released since an edition. Schemas 1 to 3 are still read.
const worldSchemaVersion = 4;

/// A world package's media, by the role it plays: the book a reader opens, the narration the
/// audio player plays, and the pictures shown around them.
const bookMediaTypes = {'application/epub+zip': FileFormat.epub};
const narrationMediaTypes = {'audio/mp4': FileFormat.m4b, 'audio/x-m4b': FileFormat.m4b, 'audio/mpeg': FileFormat.mp3};
const pictureMediaTypes = {'image/jpeg', 'image/png'};

/// A file a world package carries: where it is, what it is, and the bytes it must have (SPEC-048
/// R-13: a package-relative path, media type, byte length and SHA-256).
class WorldAsset {
  const WorldAsset({required this.path, required this.mediaType, required this.byteLength, required this.sha256});

  final String path;
  final String mediaType;
  final int byteLength;

  /// A full lowercase SHA-256 digest of the file's bytes.
  final String sha256;

  /// The same asset as arke_publication checks it, so a world's files and a publication's are
  /// checked by one function.
  PublicationAsset get asPublicationAsset => PublicationAsset(href: path, mediaType: mediaType, byteLength: byteLength, sha256: sha256);

  Map<String, Object?> toJson() => {'path': path, 'mediaType': mediaType, 'byteLength': byteLength, 'sha256': sha256};
}

/// The days an author's schedule names (SPEC-058 R-48): a weekday, or every day.
enum ScheduleDay { monday, tuesday, wednesday, thursday, friday, saturday, sunday, daily }

final _date = RegExp(r'^\d{4}-\d{2}-\d{2}$');

/// A calendar date written `YYYY-MM-DD`, as UTC midnight; null when it is not one.
DateTime? parseDay(Object? value) {
  if (value is! String || !_date.hasMatch(value)) return null;
  final day = DateTime.tryParse('${value}T00:00:00Z');
  // DateTime.parse rolls 2026-02-30 over into March; a date that does not write back is not one.
  return day != null && dayText(day) == value ? day : null;
}

String dayText(DateTime day) => '${day.year.toString().padLeft(4, '0')}-${day.month.toString().padLeft(2, '0')}-${day.day.toString().padLeft(2, '0')}';

/// When an author says new chapters come: a day, the next date, or both. The author's word, shown
/// as written (R-53), never a promise the app keeps.
class WorldSchedule {
  const WorldSchedule({this.day, this.next});
  final ScheduleDay? day;

  /// UTC midnight of the date.
  final DateTime? next;

  Map<String, Object?> toJson() => {if (day != null) 'day': day!.name, if (next != null) 'next': dayText(next!)};

  /// Reads a schedule's values; throws [FormatException] when one is malformed. Keys it does not
  /// know are the caller's to judge: a package refuses them, Arke's list ignores them.
  static WorldSchedule read(Object? raw) {
    if (raw is! Map<String, Object?>) throw const FormatException('schedule');
    final day = raw['day'];
    final next = raw['next'];
    final parsedDay = day == null ? null : ScheduleDay.values.where((value) => value.name == day).firstOrNull;
    final parsedNext = next == null ? null : parseDay(next);
    if ((day != null && parsedDay == null) || (next != null && parsedNext == null)) throw const FormatException('schedule');
    return WorldSchedule(day: parsedDay, next: parsedNext);
  }
}

/// What makes a package a part (R-46): the edition it was made after, by label and fingerprint, its
/// number among the parts after that edition, and the author's schedule.
class WorldPart {
  const WorldPart({required this.follows, required this.fingerprint, required this.number, this.schedule});
  final String follows;
  final String fingerprint;
  final int number;
  final WorldSchedule? schedule;

  Map<String, Object?> toJson() => {'follows': follows, 'fingerprint': fingerprint, 'number': number, if (schedule != null) 'schedule': schedule!.toJson()};
}

/// A production a world package carries: a book, its narration, or both (P9 rule 7). Each names
/// an asset by its id. The narration is one audio file (`narration`) or, from schema 2, a listening
/// document (`listening`) with a file a chapter and its pictures and phrases; never both.
class WorldProduction {
  const WorldProduction({required this.id, required this.title, this.author, this.picture, this.book, this.narration, this.listening});

  final String id;
  final String title;
  final String? author;
  final String? picture;
  final String? book;
  final String? narration;
  final String? listening;

  Map<String, Object?> toJson() => {
    'id': id,
    'title': title,
    if (author != null) 'author': author,
    if (picture != null) 'picture': picture,
    if (book != null) 'book': book,
    if (narration != null) 'narration': narration,
    if (listening != null) 'listening': listening,
  };
}

/// A world package's manifest: the world as its author published it — its name, logline and key
/// art — and its productions, each made of files the Player already plays. Never a world's source
/// (P1 rule 1): no sheets, takes, prompts or unpublished work.
class WorldManifest {
  const WorldManifest({
    required this.id,
    required this.edition,
    required this.name,
    required this.productions,
    required this.assets,
    this.logline,
    this.keyArt,
    this.guide,
    this.schemaVersion = worldSchemaVersion,
    this.listening = const {},
    this.guideDocument,
    this.part,
  });

  final String id;
  final String edition;
  final String name;
  final String? logline;
  final String? keyArt;

  /// Empty in a guide alone (R-10).
  final List<WorldProduction> productions;
  final Map<String, WorldAsset> assets;
  final int schemaVersion;

  /// The guide document's asset id.
  final String? guide;

  /// The guide, once the package reader has read it; null from `readWorldManifest` alone.
  final Guide? guideDocument;

  /// A package that carries a world's guide and nothing to play (R-10).
  bool get isGuideAlone => productions.isEmpty;

  /// Set when this package is a part, the chapters released after an edition (SPEC-058 R-46).
  final WorldPart? part;

  /// Each production's listening document, by production id, once the package reader has read
  /// them (`readWorldPackage`); empty from `readWorldManifest` alone.
  final Map<String, ListeningDocument> listening;

  /// The assets `world.json` itself names.
  Set<String> get namedAssets => {
    ?keyArt,
    ?guide,
    for (final production in productions) ...[?production.picture, ?production.book, ?production.narration, ?production.listening],
  };

  WorldManifest withDocuments(Map<String, ListeningDocument> documents, Guide? guide) => WorldManifest(
    id: id,
    edition: edition,
    name: name,
    logline: logline,
    keyArt: keyArt,
    guide: this.guide,
    productions: productions,
    assets: assets,
    schemaVersion: schemaVersion,
    listening: Map.unmodifiable(documents),
    guideDocument: guide,
    part: part,
  );

  Map<String, Object?> toJson() => {
    'format': worldPackageFormat,
    'schemaVersion': schemaVersion,
    'id': id,
    'edition': edition,
    'name': name,
    if (logline != null) 'logline': logline,
    if (keyArt != null) 'keyArt': keyArt,
    'productions': [for (final production in productions) production.toJson()],
    if (guide != null) 'guide': guide,
    if (part != null) 'part': part!.toJson(),
    'assets': {for (final MapEntry(:key, :value) in assets.entries) key: value.toJson()},
  };
}

/// Why a world package was refused, in the clauses P2 rule 8 shows.
enum WorldRefusal { notAPackage, newerArke }

sealed class WorldManifestRead {
  const WorldManifestRead();
}

class WorldManifestOk extends WorldManifestRead {
  const WorldManifestOk(this.manifest);
  final WorldManifest manifest;
}

class WorldManifestRefused extends WorldManifestRead {
  const WorldManifestRefused(this.refusal, this.reason);
  final WorldRefusal refusal;

  /// For a log, never the screen.
  final String reason;
}

final _slug = RegExp(r'^[a-z0-9][a-z0-9-]{0,63}$');
final _digest = RegExp(r'^[a-f0-9]{64}$');
const _topKeys = {'format', 'schemaVersion', 'id', 'edition', 'name', 'logline', 'keyArt', 'productions', 'assets', 'requires', 'metadata', 'provenance'};
const _topKeys3 = {..._topKeys, 'guide'};
const _topKeys4 = {..._topKeys3, 'part'};
const _partKeys = {'follows', 'fingerprint', 'number', 'schedule'};
const _scheduleKeys = {'day', 'next'};
const _productionKeys = {'id', 'title', 'author', 'picture', 'book', 'narration', 'metadata'};
const _productionKeys2 = {..._productionKeys, 'listening'};
const _assetKeys = {'path', 'mediaType', 'byteLength', 'sha256'};
const _maxAssets = 4096;
const _maxAssetBytes = 64 * 1024 * 1024 * 1024;

/// Reads `world.json`. Strict, as SPEC-048 R-17 asks of a reader: an unknown instruction — a key it
/// does not know, a schema or a required capability it does not have — is refused as made with a
/// newer Arke, never skipped; only `metadata` and `provenance` are ignorable. Everything else wrong
/// is not an Arke package.
WorldManifestRead readWorldManifest(String text) {
  WorldManifestRefused notAPackage(String reason) => WorldManifestRefused(WorldRefusal.notAPackage, reason);
  WorldManifestRefused newer(String reason) => WorldManifestRefused(WorldRefusal.newerArke, reason);

  final Object? decoded;
  try {
    decoded = jsonDecode(text);
  } on FormatException {
    return notAPackage('world.json is not JSON');
  }
  if (decoded is! Map<String, Object?>) return notAPackage('world.json is not an object');
  final json = decoded;
  if (json['format'] != worldPackageFormat) return notAPackage('not an $worldPackageFormat');
  final version = json['schemaVersion'];
  if (version is! int) return notAPackage('no schema version');
  if (version > worldSchemaVersion) return newer('schema version $version');
  if (version < 1) return notAPackage('schema version $version');
  final requires = json['requires'] ?? const <Object?>[];
  if (requires is! List<Object?>) return notAPackage('requires is not a list');
  if (requires.isNotEmpty) return newer('requires ${requires.join(', ')}');
  final unknown = json.keys.where((key) => !(version >= 4 ? _topKeys4 : (version >= 3 ? _topKeys3 : _topKeys)).contains(key));
  if (unknown.isNotEmpty) return newer('unknown keys ${unknown.join(', ')}');

  String? textOf(Object? value, int max) => value is String && value.trim().isNotEmpty && value.length <= max ? value : null;
  final id = json['id'];
  if (id is! String || !_slug.hasMatch(id)) return notAPackage('id');
  final edition = textOf(json['edition'], 64);
  final name = textOf(json['name'], 200);
  if (edition == null || name == null) return notAPackage('edition or name');
  final logline = json['logline'];
  if (logline != null && textOf(logline, 400) == null) return notAPackage('logline');

  final rawAssets = json['assets'];
  if (rawAssets is! Map<String, Object?> || rawAssets.isEmpty || rawAssets.length > _maxAssets) return notAPackage('assets');
  final assets = <String, WorldAsset>{};
  final paths = <String>{};
  for (final MapEntry(key: assetId, value: raw) in rawAssets.entries) {
    if (!_slug.hasMatch(assetId) || raw is! Map<String, Object?>) return notAPackage('asset $assetId');
    final extra = raw.keys.where((key) => !_assetKeys.contains(key));
    if (extra.isNotEmpty) return newer('asset $assetId keys ${extra.join(', ')}');
    final path = raw['path'];
    final mediaType = raw['mediaType'];
    final byteLength = raw['byteLength'];
    final sha256 = raw['sha256'];
    if (path is! String || !isPortableAssetPath(path) || path.split('/').first.toLowerCase() == worldManifestFile) return notAPackage('asset $assetId path');
    // Unique after case folding, so no two assets are one file on a case-insensitive phone.
    if (!paths.add(path.toLowerCase())) return notAPackage('asset $assetId path repeats');
    if (mediaType is! String || byteLength is! int || byteLength < 0 || byteLength > _maxAssetBytes) return notAPackage('asset $assetId');
    if (sha256 is! String || !_digest.hasMatch(sha256)) return notAPackage('asset $assetId digest');
    assets[assetId] = WorldAsset(path: path, mediaType: mediaType, byteLength: byteLength, sha256: sha256);
  }

  final used = <String>{};
  String? role(Object? assetId, Set<String> mediaTypes) {
    if (assetId is! String) return null;
    final asset = assets[assetId];
    if (asset == null || !mediaTypes.contains(asset.mediaType)) return null;
    used.add(assetId);
    return assetId;
  }

  final keyArt = json['keyArt'];
  if (keyArt != null && role(keyArt, pictureMediaTypes) == null) return notAPackage('keyArt');
  final guide = json['guide'];
  if (guide != null && role(guide, const {guideMediaType}) == null) return notAPackage('guide');

  // Schema 4 is a part, and a part is nothing else: one production's new chapters and no guide (a
  // guide reaches a phone alone, or in the next edition).
  WorldPart? part;
  if (version >= 4) {
    final raw = json['part'];
    if (raw is! Map<String, Object?>) return notAPackage('schema 4 without a part');
    final extra = raw.keys.where((key) => !_partKeys.contains(key));
    if (extra.isNotEmpty) return newer('part keys ${extra.join(', ')}');
    final follows = textOf(raw['follows'], 64);
    final fingerprint = raw['fingerprint'];
    final number = raw['number'];
    if (follows == null) return notAPackage('part follows');
    if (fingerprint is! String || !_digest.hasMatch(fingerprint)) return notAPackage('part fingerprint');
    if (number is! int || number < 1) return notAPackage('part number');
    WorldSchedule? schedule;
    final rawSchedule = raw['schedule'];
    if (rawSchedule != null) {
      if (rawSchedule is! Map<String, Object?>) return notAPackage('part schedule');
      final unknownSchedule = rawSchedule.keys.where((key) => !_scheduleKeys.contains(key));
      if (unknownSchedule.isNotEmpty) return newer('schedule keys ${unknownSchedule.join(', ')}');
      try {
        schedule = WorldSchedule.read(rawSchedule);
      } on FormatException {
        return notAPackage('part schedule');
      }
    }
    if (guide != null) return notAPackage('a part carries a guide');
    part = WorldPart(follows: follows, fingerprint: fingerprint, number: number, schedule: schedule);
  }

  // A guide alone carries no production (R-10); anything else carries one at least.
  final rawProductions = json['productions'];
  if (rawProductions is! List<Object?> || (rawProductions.isEmpty && guide == null) || rawProductions.length > 64) return notAPackage('productions');
  final productions = <WorldProduction>[];
  final productionIds = <String>{};
  for (final raw in rawProductions) {
    if (raw is! Map<String, Object?>) return notAPackage('production');
    final extra = raw.keys.where((key) => !(version >= 2 ? _productionKeys2 : _productionKeys).contains(key));
    if (extra.isNotEmpty) return newer('production keys ${extra.join(', ')}');
    final productionId = raw['id'];
    final title = textOf(raw['title'], 200);
    if (productionId is! String || !_slug.hasMatch(productionId) || !productionIds.add(productionId) || title == null) {
      return notAPackage('production id or title');
    }
    final author = raw['author'];
    if (author != null && textOf(author, 200) == null) return notAPackage('production $productionId author');
    final picture = raw['picture'] == null ? null : role(raw['picture'], pictureMediaTypes);
    final book = raw['book'] == null ? null : role(raw['book'], bookMediaTypes.keys.toSet());
    final narration = raw['narration'] == null ? null : role(raw['narration'], narrationMediaTypes.keys.toSet());
    final listening = raw['listening'] == null ? null : role(raw['listening'], const {listeningMediaType});
    if ((raw['picture'] != null && picture == null) ||
        (raw['book'] != null && book == null) ||
        (raw['narration'] != null && narration == null) ||
        (raw['listening'] != null && listening == null)) {
      return notAPackage('production $productionId names an asset it cannot use');
    }
    if (narration != null && listening != null) return notAPackage('production $productionId names a narration and a listening document');
    if (book == null && narration == null && listening == null) return notAPackage('production $productionId has nothing to play');
    // A single narration file cannot be added to: a part's chapters come as a listening document.
    if (part != null && narration != null) return notAPackage('part production $productionId names a narration');
    productions.add(
      WorldProduction(id: productionId, title: title, author: author as String?, picture: picture, book: book, narration: narration, listening: listening),
    );
  }
  if (part != null && productions.length != 1) return notAPackage('a part carries one production');
  // Every file is one the world uses: nothing unreferenced rides along (SPEC-048 R-13). The files a
  // listening document or a guide names are known only once it is read, so with one the package
  // reader makes this check instead.
  if (guide == null && productions.every((production) => production.listening == null)) {
    final unused = assets.keys.where((assetId) => !used.contains(assetId));
    if (unused.isNotEmpty) return notAPackage('unused assets ${unused.join(', ')}');
  }

  return WorldManifestOk(
    WorldManifest(
      id: id,
      edition: edition,
      name: name,
      logline: logline as String?,
      keyArt: keyArt as String?,
      guide: guide as String?,
      productions: List.unmodifiable(productions),
      assets: Map.unmodifiable(assets),
      schemaVersion: version,
      part: part,
    ),
  );
}
