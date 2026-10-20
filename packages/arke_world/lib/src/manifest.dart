import 'dart:convert';

import 'package:arke_publication/arke_publication.dart';

/// The manifest at a world package's root.
const worldManifestFile = 'world.json';

/// The format a world package names itself by. This is the Player's proposal: SPEC-048 defines a
/// publication package but no package of a world, and owes one (Arke Player ADR 0005).
const worldPackageFormat = 'arke-world-package';
const worldSchemaVersion = 1;

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

/// A production a world package carries: a book, its narration, or both (P9 rule 7). Each names
/// an asset by its id.
class WorldProduction {
  const WorldProduction({required this.id, required this.title, this.author, this.picture, this.book, this.narration});

  final String id;
  final String title;
  final String? author;
  final String? picture;
  final String? book;
  final String? narration;

  Map<String, Object?> toJson() => {
    'id': id,
    'title': title,
    if (author != null) 'author': author,
    if (picture != null) 'picture': picture,
    if (book != null) 'book': book,
    if (narration != null) 'narration': narration,
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
  });

  final String id;
  final String edition;
  final String name;
  final String? logline;
  final String? keyArt;
  final List<WorldProduction> productions;
  final Map<String, WorldAsset> assets;

  Map<String, Object?> toJson() => {
    'format': worldPackageFormat,
    'schemaVersion': worldSchemaVersion,
    'id': id,
    'edition': edition,
    'name': name,
    if (logline != null) 'logline': logline,
    if (keyArt != null) 'keyArt': keyArt,
    'productions': [for (final production in productions) production.toJson()],
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
const _productionKeys = {'id', 'title', 'author', 'picture', 'book', 'narration', 'metadata'};
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
  if (version != worldSchemaVersion) return notAPackage('schema version $version');
  final requires = json['requires'] ?? const <Object?>[];
  if (requires is! List<Object?>) return notAPackage('requires is not a list');
  if (requires.isNotEmpty) return newer('requires ${requires.join(', ')}');
  final unknown = json.keys.where((key) => !_topKeys.contains(key));
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

  final rawProductions = json['productions'];
  if (rawProductions is! List<Object?> || rawProductions.isEmpty || rawProductions.length > 64) return notAPackage('productions');
  final productions = <WorldProduction>[];
  final productionIds = <String>{};
  for (final raw in rawProductions) {
    if (raw is! Map<String, Object?>) return notAPackage('production');
    final extra = raw.keys.where((key) => !_productionKeys.contains(key));
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
    if ((raw['picture'] != null && picture == null) || (raw['book'] != null && book == null) || (raw['narration'] != null && narration == null)) {
      return notAPackage('production $productionId names an asset it cannot use');
    }
    if (book == null && narration == null) return notAPackage('production $productionId has nothing to play');
    productions.add(WorldProduction(id: productionId, title: title, author: author as String?, picture: picture, book: book, narration: narration));
  }
  // Every file is one the world uses: nothing unreferenced rides along (SPEC-048 R-13).
  final unused = assets.keys.where((assetId) => !used.contains(assetId));
  if (unused.isNotEmpty) return notAPackage('unused assets ${unused.join(', ')}');

  return WorldManifestOk(
    WorldManifest(
      id: id,
      edition: edition,
      name: name,
      logline: logline as String?,
      keyArt: keyArt as String?,
      productions: List.unmodifiable(productions),
      assets: Map.unmodifiable(assets),
    ),
  );
}
