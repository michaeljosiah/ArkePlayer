import 'package:arke_publication/arke_publication.dart';
import 'package:test/test.dart';

const _digest = '0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef';

Map<String, Object?> _manifest({Map<String, Object?>? override}) => {
  'format': 'arke-publication',
  'schemaVersion': 1,
  'id': 'urn:uuid:12345678-1234-1234-1234-123456789abc',
  'edition': 'First',
  'profile': 'video',
  'profileVersion': 1,
  'title': 'Saltlight',
  'language': 'en',
  'requires': ['video-v1', 'webvtt-v1'],
  'assets': {
    'film': {'href': 'media/film.mp4', 'mediaType': 'video/mp4', 'byteLength': 1024, 'sha256': _digest},
    'en': {'href': 'media/en.vtt', 'mediaType': 'text/vtt', 'byteLength': 64, 'sha256': _digest},
  },
  'content': {
    'video': 'film',
    'textTracks': [
      {'asset': 'en', 'kind': 'captions', 'language': 'en', 'label': 'English', 'default': true},
    ],
  },
  'build': {'compiler': 'arke', 'compilerVersion': '0.5.90', 'dependencyFingerprint': _digest},
  ...?override,
};

void main() {
  test('reads a video publication', () {
    final read = readManifest(_manifest());
    expect(read, isA<ManifestReadOk>());
    final manifest = (read as ManifestReadOk).manifest;
    expect(manifest.title, 'Saltlight');
    expect(manifest.textTracks.single.label, 'English');
  });

  test('a profile it does not know is refused, never guessed at', () {
    final read = readManifest(_manifest(override: {'profile': 'audiobook'}));
    expect((read as ManifestReadRefused).code, ManifestRefusal.unsupportedProfile);
  });

  test('a capability it cannot play is refused by name', () {
    final read = readManifest(
      _manifest(
        override: {
          'requires': ['video-v1', 'webvtt-v1', 'spatial-v1'],
        },
      ),
    );
    expect((read as ManifestReadRefused).code, ManifestRefusal.unsupportedCapability);
    expect(read.reason, 'spatial-v1');
  });

  test('text tracks need webvtt-v1', () {
    final read = readManifest(
      _manifest(
        override: {
          'requires': ['video-v1'],
        },
      ),
    );
    expect((read as ManifestReadRefused).code, ManifestRefusal.invalidManifest);
  });

  test('an asset path that is not portable is refused', () {
    final manifest = _manifest();
    (manifest['assets']! as Map<String, Object?>)['film'] = {'href': '../film.mp4', 'mediaType': 'video/mp4', 'byteLength': 1, 'sha256': _digest};
    expect(readManifest(manifest), isA<ManifestReadRefused>());
  });

  group('portable asset paths', () {
    test('accepts plain relative paths', () => expect(isPortableAssetPath('media/film-01.mp4'), isTrue));
    test('refuses traversal, devices and the manifest itself', () {
      expect(isPortableAssetPath('../film.mp4'), isFalse);
      expect(isPortableAssetPath('media/CON.mp4'), isFalse);
      expect(isPortableAssetPath('media/trailing.'), isFalse);
      expect(isPortableAssetPath('publication.json'), isFalse);
    });
  });
}
