import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:arke_world/arke_world.dart';
import 'package:crypto/crypto.dart';
import 'package:test/test.dart';

// SPEC-058 R-68 – R-70: these fixtures are the ones ArkeStudio's contracts read too, so both readers
// agree on every verdict, on what a music document holds and on what a production package names.
final _fixtures = '${Directory.current.path}/test/fixtures/music';

String _read(String name) => File('$_fixtures/$name').readAsStringSync();

Map<String, WorldAsset> _assets() => {
  for (final MapEntry(:key, value: raw) in (jsonDecode(_read('assets.json')) as Map<String, Object?>).entries)
    if (raw case {'path': final String path, 'mediaType': final String mediaType, 'byteLength': final int byteLength, 'sha256': final String sha256})
      key: WorldAsset(path: path, mediaType: mediaType, byteLength: byteLength, sha256: sha256),
};

void main() {
  group('the shared music cases (SPEC-058 R-68 – R-70)', () {
    final cases = (jsonDecode(_read('cases.json')) as Map<String, Object?>)['cases']! as List<Object?>;
    for (final raw in cases.cast<Map<String, Object?>>()) {
      final file = raw['file']! as String;
      test(file, () {
        if (raw['reader'] == 'manifest') {
          final read = readWorldManifest(_read(file));
          _verdict(raw['expect']! as String, read is WorldManifestRefused ? read.refusal : null, read is WorldManifestRefused ? read.reason : null);
          if (read case WorldManifestOk(:final manifest)) {
            expect(manifest.alone, raw['alone'] ?? false);
            if (raw['music'] case final String music) expect(manifest.productions.single.music, music);
          }
          return;
        }
        final read = readMusic(_read(file), _assets());
        _verdict(raw['expect']! as String, read is MusicRefused ? read.refusal : null, read is MusicRefused ? read.reason : null);
        if (read case MusicOk(:final document)) {
          if (raw['kind'] case final String kind) expect(document.kind.name, kind);
          if (raw['tracks'] case final List<Object?> tracks) expect(document.tracks.map((track) => track.id), tracks);
          if (raw['sections'] case final int sections) expect(document.tracks.first.lyrics?.sections.length, sections);
        }
      });
    }
  });

  test('an album reads its tracks, words, sections and where each is heard', () {
    final document = (readMusic(_read('album.json'), _assets()) as MusicOk).document;
    final verse = document.tracks.first;
    expect((verse.title, verse.duration, verse.audio), ('The Drowned Verse', const Duration(milliseconds: 238000), 'a-drowned-verse'));
    expect(verse.lyrics!.sections.map((section) => (section.label, section.at.inSeconds)), [('Intro', 0), ('Verse', 14), ('Chorus', 62), ('Outro', 220)]);
    expect(verse.heardIn.single.production, 'the-ledger-of-nights');
    expect(verse.heardIn.single.at, const Duration(milliseconds: 730000));
    expect(document.duration, const Duration(milliseconds: 238000 + 185000 + 222000));
    expect(document.assetIds, {'a-drowned-verse', 'a-slack-water', 'a-saltmouth-bells'});
  });

  group('a production package on disk (SPEC-058 R-68, R-70)', () {
    late Directory dir;
    setUp(() => dir = Directory.systemTemp.createTempSync('music-package-'));
    tearDown(() => dir.deleteSync(recursive: true));

    // Packs world.json and the given files, stored, as the Studio writes a package.
    String pack(Map<String, Object?> world, Map<String, List<int>> files) {
      final assets = <String, Object?>{};
      for (final MapEntry(:key, :value) in (world['assets']! as Map<String, Object?>).entries) {
        final path = (value! as Map<String, Object?>)['path']! as String;
        final bytes = files[path]!;
        assets[key] = {...value as Map<String, Object?>, 'byteLength': bytes.length, 'sha256': sha256.convert(bytes).toString()};
      }
      final archive = Archive()
        ..add(ArchiveFile.bytes(worldManifestFile, utf8.encode(jsonEncode({...world, 'assets': assets})))..compression = CompressionType.none);
      for (final MapEntry(:key, :value) in files.entries) {
        archive.add(ArchiveFile.bytes(key, value)..compression = CompressionType.none);
      }
      final zip = '${dir.path}/album.zip';
      File(zip).writeAsBytesSync(ZipEncoder().encode(archive));
      return zip;
    }

    final world = jsonDecode(_read('world-album.json')) as Map<String, Object?>;
    Map<String, List<int>> files(String musicText) => {
      'songs-of-the-drowned-quarter/music.json': utf8.encode(musicText),
      'songs-of-the-drowned-quarter/cover.jpg': [0xff, 0xd8, 0xff, 0xe0],
      'songs-of-the-drowned-quarter/tracks/the-drowned-verse.m4a': [1, 2, 3],
      'songs-of-the-drowned-quarter/tracks/slack-water.m4a': [4, 5, 6],
      'songs-of-the-drowned-quarter/tracks/saltmouth-bells.m4a': [7, 8, 9],
    };

    test('reads its music document, and every file it names is used', () {
      final manifest = readWorldPackage(pack(world, files(_read('album.json'))));
      expect(manifest.alone, isTrue);
      expect(manifest.music['songs-of-the-drowned-quarter']!.tracks, hasLength(3));
    });

    test('a track file nothing names is refused', () {
      final single = jsonDecode(_read('single.json')) as Map<String, Object?>;
      expect(() => readWorldPackage(pack(world, files(jsonEncode(single)))), throwsA(isA<WorldPackageRefused>()));
    });

    test('a music document that is not one refuses the package', () {
      expect(
        () => readWorldPackage(pack(world, files(_read('section-past-end.json')))),
        throwsA(isA<WorldPackageRefused>().having((refused) => refused.refusal, 'refusal', WorldRefusal.notAPackage)),
      );
    });
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
