import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:arke_world/arke_world.dart';
import 'package:crypto/crypto.dart';
import 'package:test/test.dart';

import '../bin/pin_world.dart' as cli;

// Local structural fixtures only: these pins do not certify media decoding or inventory integrity.
Map<String, dynamic> fixture(String folder, String name) => jsonDecode(File('test/fixtures/$folder/$name.json').readAsStringSync()) as Map<String, dynamic>;

void main() {
  late Directory directory;
  setUp(() => directory = Directory.systemTemp.createTempSync('arke-pin-'));
  tearDown(() => directory.deleteSync(recursive: true));
  const url = 'https://example.test/package.zip';

  String pack(String kind, {void Function(Map<String, dynamic>, Map<String, dynamic>?)? change, bool omitDocument = false}) {
    final (folder, name, documentName) = switch (kind) {
      'comic' => ('comic', 'world-comic', 'low-water-drawn'),
      'story' => ('story', 'world-story', 'synthetic'),
      'music' => ('music', 'world-album', 'album'),
      'part' => ('part', 'part', 'valid'),
      'guide' => ('guide', 'world-guide-alone', 'valid'),
      _ => ('part', 'part', ''),
    };
    final world = fixture(folder, name);
    final productions = (world['productions'] as List).cast<Map<String, dynamic>>();
    final documentKind = kind == 'part' ? 'listening' : kind;
    final document = documentName.isEmpty ? null : fixture(kind == 'part' ? 'listening' : folder, documentName);
    if (document == null) {
      world.remove('part');
      world['schemaVersion'] = kind == 'production' ? 5 : 2;
      if (kind == 'production') world['alone'] = true;
      productions.single.remove('listening');
      (world['assets'] as Map).remove('listening');
    }
    final inventory = <String, dynamic>{
      ...world['assets'] as Map<String, dynamic>,
      if (document != null) ...fixture(kind == 'part' ? 'listening' : folder, 'assets'),
    };
    if (document != null) {
      final assets = {
        for (final entry in inventory.entries)
          entry.key: WorldAsset(
            path: entry.value['path'] as String,
            mediaType: entry.value['mediaType'] as String,
            byteLength: entry.value['byteLength'] as int,
            sha256: entry.value['sha256'] as String,
          ),
      };
      final used = switch (kind) {
        'comic' => (readComic(jsonEncode(document), assets) as ComicOk).document.assetIds,
        'story' => (readStory(jsonEncode(document), assets) as StoryOk).document.assetIds,
        'music' => (readMusic(jsonEncode(document), assets) as MusicOk).document.assetIds,
        'part' => (readListening(jsonEncode(document), assets) as ListeningOk).document.assetIds,
        'guide' => (readGuide(jsonEncode(document), assets) as GuideOk).guide.assetIds,
        _ => <String>{},
      };
      final named = {...(world['assets'] as Map).keys, ...used};
      inventory.removeWhere((id, _) => !named.contains(id));
    }
    world['assets'] = inventory;
    change?.call(world, document);
    final archive = Archive();
    for (final entry in inventory.entries) {
      final asset = entry.value as Map<String, dynamic>;
      final bytes = entry.key == documentKind ? utf8.encode(jsonEncode(document)) : [1, 2, 3];
      asset['byteLength'] = bytes.length;
      asset['sha256'] = sha256.convert(bytes).toString();
      if (!omitDocument || entry.key != documentKind) archive.add(ArchiveFile.bytes(asset['path'] as String, bytes)..compression = CompressionType.none);
    }
    archive.add(ArchiveFile.bytes(worldManifestFile, utf8.encode(jsonEncode(world)))..compression = CompressionType.none);
    final path = '${directory.path}/$kind.zip';
    File(path).writeAsBytesSync(ZipEncoder().encode(archive));
    return path;
  }

  Map<String, Object?> expectedPin(String path) => {
    'url': url,
    'byteLength': File(path).lengthSync(),
    'sha256': sha256.convert(File(path).readAsBytesSync()).toString(),
    'edition': readWorldPackage(path).edition,
    'fingerprint': editionFingerprint(readWorldPackage(path)),
  };

  CatalogueProduction listed(Map<String, Object?> production) => parseCatalogue(
    jsonEncode({
      'version': 2,
      'serial': 1,
      'worlds': [
        {
          'id': 'the-undersong',
          'name': 'The Undersong',
          'productions': [
            {...production, 'title': 'Local fixture', 'kind': 'Test'},
          ],
        },
      ],
    }),
  ).worlds.single.productions.single;

  for (final kind in ['comic', 'story', 'music', 'production']) {
    test('$kind pins round-trip with exact outer bytes and the correct production capability', () async {
      final path = pack(kind);
      final result = await cli.pinWorldPackage([path, url, '--production']);
      final production = result['production']! as Map<String, Object?>;
      final key = kind == 'comic' || kind == 'story' ? kind : 'package';
      expect(production, {
        'id': readWorldPackage(path).productions.single.id,
        key: {...expectedPin(path), if (key != 'package') 'version': 1},
        if (kind == 'music') 'music': 'album',
      });
      final read = listed(production);
      expect(read.alone?.sha256, expectedPin(path)['sha256']);
      expect(read.needsNewerApp, isFalse);
      if (key != 'package') {
        expect(read.package, isNull);
        final newer = listed({
          ...production,
          key: {...expectedPin(path), 'version': 999},
        });
        expect(newer.needsNewerApp, isTrue);
        expect(newer.alone, isNull, reason: 'unsupported documents must not become generic downloads');
      }
    });
  }

  for (final kind in ['world', 'guide']) {
    test('$kind remains an edition pin', () async {
      final path = pack(kind);
      expect(await cli.pinWorldPackage([path, url]), expectedPin(path));
      await expectLater(cli.pinWorldPackage([path, url, '--production']), throwsA(isA<cli.PinRefused>().having((e) => e.exitCode, 'exit', 65)));
    });
  }

  test('parts retain their chapters, schedule and exact base-edition guard', () async {
    final path = pack('part');
    final manifest = readWorldPackage(path);
    final result = await cli.pinWorldPackage([path, url, '--follows', manifest.part!.fingerprint]);
    expect(result['part'], {
      ...expectedPin(path),
      'released': '2026-10-30',
      'production': manifest.productions.single.id,
      'chapters': [
        for (final c in manifest.listening.values.single.chapters) {'id': c.id, 'number': c.order, 'title': c.title},
      ],
    });
    expect(result['production'], {'id': manifest.productions.single.id, 'schedule': manifest.part!.schedule!.toJson()});
    await expectLater(cli.pinWorldPackage([path, url, '--follows', 'b' * 64]), throwsA(isA<cli.PinRefused>().having((e) => e.exitCode, 'exit', 65)));
    await expectLater(cli.pinWorldPackage([path, url]), throwsA(isA<cli.PinRefused>().having((e) => e.exitCode, 'exit', 64)));
  });

  for (final fault in ['version', 'missing', 'identity', 'malformed']) {
    test('a $fault comic document produces no pin', () async {
      final path = pack(
        'comic',
        omitDocument: fault == 'missing',
        change: (world, document) {
          if (fault == 'version') document!['version'] = 999;
          if (fault == 'malformed') document!['chapters'] = <Object?>[];
          if (fault == 'identity') (world['productions'] as List).single['comic'] = 'cover';
        },
      );
      await expectLater(cli.pinWorldPackage([path, url, '--production']), throwsA(isA<cli.PinRefused>().having((e) => e.exitCode, 'exit', 65)));
    });
  }

  test('standalone and HTTPS usage guards remain in place', () async {
    final path = pack('comic');
    for (final args in [
      [path, url],
      [path, 'http://example.test/a.zip', '--production'],
      [path, 'https:', '--production'],
      <String>[],
    ]) {
      await expectLater(cli.pinWorldPackage(args), throwsA(isA<cli.PinRefused>().having((e) => e.exitCode, 'exit', 64)));
    }
  });
}
