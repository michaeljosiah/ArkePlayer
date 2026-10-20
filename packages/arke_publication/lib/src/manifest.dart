import 'asset_path.dart';

/// One file a publication carries, as its manifest describes it.
class PublicationAsset {
  const PublicationAsset({required this.href, required this.mediaType, required this.byteLength, required this.sha256});

  final String href;
  final String mediaType;
  final int byteLength;

  /// A full lowercase SHA-256 digest of the file's bytes.
  final String sha256;
}

/// A text track a video carries: captions or subtitles in one language.
class PublicationTextTrack {
  const PublicationTextTrack({required this.asset, required this.kind, required this.language, required this.label, required this.isDefault});

  final String asset;
  final String kind;
  final String language;
  final String label;
  final bool isDefault;
}

/// A publication's manifest: a frozen edition, never a world's source (Arke Player P1 rule 1).
///
/// Only the `video` profile, version 1, exists in ArkeStudio's contract today. Every other
/// profile is refused as unsupported rather than guessed at, which is what a viewer sees as
/// `Made with a newer Arke` (P2 rule 8).
class PublicationManifest {
  const PublicationManifest({
    required this.id,
    required this.edition,
    required this.profile,
    required this.title,
    required this.language,
    required this.requires,
    required this.assets,
    required this.video,
    required this.textTracks,
  });

  final String id;
  final String edition;
  final String profile;
  final String title;
  final String language;
  final List<String> requires;
  final Map<String, PublicationAsset> assets;

  /// The key of the video asset in [assets].
  final String video;
  final List<PublicationTextTrack> textTracks;
}

/// Why a manifest was refused. The names match `PublicationManifestRead` in ArkeStudio.
enum ManifestRefusal { invalidManifest, unsupportedSchema, unsupportedProfile, unsupportedCapability }

/// The result of reading a manifest: the manifest, or one refusal with its reason.
sealed class ManifestRead {
  const ManifestRead();
}

class ManifestReadOk extends ManifestRead {
  const ManifestReadOk(this.manifest);
  final PublicationManifest manifest;
}

class ManifestReadRefused extends ManifestRead {
  const ManifestReadRefused(this.code, this.reason);
  final ManifestRefusal code;
  final String reason;
}

/// The capabilities this reader can play. Anything else a manifest requires is refused.
const supportedCapabilities = {'video-v1', 'webvtt-v1'};

final _id = RegExp(r'^urn:uuid:[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$', caseSensitive: false);
final _key = RegExp(r'^[a-zA-Z0-9][a-zA-Z0-9_-]{0,127}$');
final _capability = RegExp(r'^[a-z][a-z0-9-]{0,79}$');
final _mediaType = RegExp(r'^[a-z0-9][a-z0-9!#$&^_.+-]*/[a-z0-9][a-z0-9!#$&^_.+-]*$');
final _digest = RegExp(r'^[0-9a-f]{64}$');

class _Invalid implements Exception {
  _Invalid(this.reason);
  final String reason;
}

/// Reads a decoded `publication.json`. Mirrors `VideoPublicationManifestSchema`; the TypeScript
/// contract in ArkeStudio is the authority, and a change there is a change here.
ManifestRead readManifest(Object? json) {
  try {
    final root = _map(json, 'manifest');
    if (root['format'] != 'arke-publication') throw _Invalid('format is not arke-publication');
    if (root['schemaVersion'] != 1) {
      return ManifestReadRefused(ManifestRefusal.unsupportedSchema, 'schemaVersion ${root['schemaVersion']}');
    }
    if (root['profile'] != 'video' || root['profileVersion'] != 1) {
      return ManifestReadRefused(ManifestRefusal.unsupportedProfile, 'profile ${root['profile']} v${root['profileVersion']}');
    }
    final id = _text(root, 'id');
    if (!_id.hasMatch(id)) throw _Invalid('id is not a urn:uuid');

    final requires = _list(root, 'requires').map((value) => value is String ? value : throw _Invalid('requires holds a non-string')).toList();
    if (requires.isEmpty || requires.length > 64) throw _Invalid('requires is empty or too long');
    if (requires.any((capability) => !_capability.hasMatch(capability))) throw _Invalid('requires holds a malformed capability');
    if (requires.toSet().length != requires.length) throw _Invalid('capabilities must be unique');
    if (!requires.contains('video-v1')) throw _Invalid('video-v1 is required');
    final unknown = requires.where((capability) => !supportedCapabilities.contains(capability)).toList();
    if (unknown.isNotEmpty) return ManifestReadRefused(ManifestRefusal.unsupportedCapability, unknown.join(', '));

    final assets = <String, PublicationAsset>{};
    final paths = <String>{};
    _map(root['assets'], 'assets').forEach((key, value) {
      if (!_key.hasMatch(key)) throw _Invalid('asset key $key is malformed');
      final entry = _map(value, 'asset $key');
      final asset = PublicationAsset(
        href: _text(entry, 'href'),
        mediaType: _text(entry, 'mediaType'),
        byteLength: _count(entry, 'byteLength'),
        sha256: _text(entry, 'sha256'),
      );
      if (!isPortableAssetPath(asset.href)) throw _Invalid('asset $key has a path that is not portable');
      if (!_mediaType.hasMatch(asset.mediaType)) throw _Invalid('asset $key has a malformed media type');
      if (!_digest.hasMatch(asset.sha256)) throw _Invalid('asset $key has no full lowercase SHA-256');
      if (!paths.add(asset.href.toLowerCase())) throw _Invalid('asset paths collide ignoring case');
      assets[key] = asset;
    });
    if (assets.isEmpty || assets.length > 4096) throw _Invalid('asset inventory is empty or too large');

    final content = _map(root['content'], 'content');
    final video = _text(content, 'video');
    final referenced = <String>{video};
    _reference(assets, video, const ['video/mp4', 'video/webm']);
    final tracks = <PublicationTextTrack>[];
    for (final value in _list(content, 'textTracks')) {
      final entry = _map(value, 'text track');
      final track = PublicationTextTrack(
        asset: _text(entry, 'asset'),
        kind: _text(entry, 'kind'),
        language: _text(entry, 'language'),
        label: _text(entry, 'label'),
        isDefault: entry['default'] == true,
      );
      if (track.kind != 'captions' && track.kind != 'subtitles') throw _Invalid('text track kind ${track.kind}');
      _reference(assets, track.asset, const ['text/vtt']);
      if (!referenced.add(track.asset)) throw _Invalid('a text track asset is listed more than once');
      tracks.add(track);
    }
    if (tracks.isNotEmpty && !requires.contains('webvtt-v1')) throw _Invalid('text tracks require webvtt-v1');
    if (tracks.where((track) => track.isDefault).length > 1) throw _Invalid('at most one text track may be default');
    for (final key in assets.keys) {
      if (!referenced.contains(key)) throw _Invalid('video-v1 does not carry unreferenced assets ($key)');
    }

    return ManifestReadOk(
      PublicationManifest(
        id: id,
        edition: _text(root, 'edition'),
        profile: 'video',
        title: _text(root, 'title'),
        language: _text(root, 'language'),
        requires: List.unmodifiable(requires),
        assets: Map.unmodifiable(assets),
        video: video,
        textTracks: List.unmodifiable(tracks),
      ),
    );
  } on _Invalid catch (invalid) {
    return ManifestReadRefused(ManifestRefusal.invalidManifest, invalid.reason);
  }
}

void _reference(Map<String, PublicationAsset> assets, String key, List<String> mediaTypes) {
  final asset = assets[key];
  if (asset == null) throw _Invalid('asset $key is not in the inventory');
  if (!mediaTypes.contains(asset.mediaType)) throw _Invalid('asset $key has an incompatible media type');
  if (asset.byteLength == 0) throw _Invalid('asset $key is empty');
}

Map<String, Object?> _map(Object? value, String what) {
  if (value is Map<String, Object?>) return value;
  if (value is Map) return value.map((key, item) => MapEntry('$key', item));
  throw _Invalid('$what is not an object');
}

List<Object?> _list(Map<String, Object?> map, String key) {
  final value = map[key];
  if (value is List) return value.cast<Object?>();
  throw _Invalid('$key is not a list');
}

String _text(Map<String, Object?> map, String key) {
  final value = map[key];
  if (value is String && value.trim().isNotEmpty && value.length <= 512) return value;
  throw _Invalid('$key is missing or blank');
}

int _count(Map<String, Object?> map, String key) {
  final value = map[key];
  if (value is int && value >= 0) return value;
  throw _Invalid('$key is not a non-negative integer');
}
