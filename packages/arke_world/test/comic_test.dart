import 'dart:convert';
import 'dart:io';

import 'package:arke_world/arke_world.dart';
import 'package:test/test.dart';

// SPEC-064 R-50, R-51; P20: these fixtures are written by ArkeStudio's contracts
// (scripts/comic-fixtures.ts) and copied here verbatim, so both readers agree on every verdict and on
// what a comic document holds.
final _fixtures = '${Directory.current.path}/test/fixtures/comic';

String _read(String name) => File('$_fixtures/$name').readAsStringSync();

Map<String, WorldAsset> _assets() => {
  for (final MapEntry(:key, value: raw) in (jsonDecode(_read('assets.json')) as Map<String, Object?>).entries)
    if (raw case {'path': final String path, 'mediaType': final String mediaType, 'byteLength': final int byteLength, 'sha256': final String sha256})
      key: WorldAsset(path: path, mediaType: mediaType, byteLength: byteLength, sha256: sha256),
};

void main() {
  group('the shared comic cases (SPEC-064 R-50, R-51)', () {
    final cases = (jsonDecode(_read('cases.json')) as Map<String, Object?>)['cases']! as List<Object?>;
    for (final raw in cases.cast<Map<String, Object?>>()) {
      final file = raw['file']! as String;
      test(file, () {
        if (raw['reader'] == 'manifest') {
          final read = readWorldManifest(_read(file));
          _verdict(raw['expect']! as String, read is WorldManifestRefused ? read.refusal : null, read is WorldManifestRefused ? read.reason : null);
          if (read case WorldManifestOk(:final manifest)) {
            expect(manifest.alone, isTrue);
            expect(manifest.productions.single.comic, raw['comic']);
            expect(manifest.productions.single.picture, raw['picture']);
          }
          return;
        }
        final read = readComic(_read(file), _assets());
        _verdict(raw['expect']! as String, read is ComicRefused ? read.refusal : null, read is ComicRefused ? read.reason : null);
        if (read case ComicOk(:final document)) {
          expect(document.reading.name, raw['reading']);
          expect(document.aspect, raw['aspect']);
          expect(document.language, raw['language']);
          expect(document.chapters.map((chapter) => chapter.pages.length), raw['pages']);
        }
      });
    }
  });

  test('a comic names every page it shows, in reading order', () {
    final read = readComic(_read('low-water-drawn.json'), _assets());
    expect(read, isA<ComicOk>());
    final document = (read as ComicOk).document;
    expect(document.pages.map((page) => page.picture), ['p-0001', 'p-0002', 'p-0003', 'p-0004']);
    expect(document.assetIds, {'p-0001', 'p-0002', 'p-0003', 'p-0004'});
  });
}

void _verdict(String expected, WorldRefusal? refusal, String? reason) {
  switch (expected) {
    case 'ok':
      expect(refusal, isNull, reason: reason);
    case 'newerArke':
      expect(refusal, WorldRefusal.newerArke, reason: reason);
    case 'notAPackage':
      expect(refusal, WorldRefusal.notAPackage, reason: reason);
  }
}
