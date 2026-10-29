import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:arke_library/arke_library.dart';
import 'package:arke_world/arke_world.dart';
import 'package:crypto/crypto.dart';
import 'package:test/test.dart';

// SPEC-058 R-82, R-83: a story published alone installs as a production package does — with the
// world, on its own when listed later, and again on a new fingerprint — and one whose version this
// Player does not read is never fetched.
final _media = '${Directory.current.path}/../arke_media/test/fixtures';
final _fixtures = '${Directory.current.path}/test/fixtures/story';

class _Server {
  _Server._(this._server);
  final HttpServer _server;
  final files = <String, List<int>>{};
  final asked = <String>[];

  Uri url(String path) => Uri.parse('http://127.0.0.1:${_server.port}/$path');

  static Future<_Server> start() async {
    final server = _Server._(await HttpServer.bind(InternetAddress.loopbackIPv4, 0));
    server._server.listen((request) async {
      final name = request.uri.path.substring(1);
      server.asked.add(name);
      final body = server.files[name];
      final response = request.response;
      if (body == null) {
        response.statusCode = HttpStatus.notFound;
      } else {
        response.contentLength = body.length;
        response.add(body);
      }
      await response.close();
    });
    return server;
  }

  Future<void> close() => _server.close(force: true);
}

void main() {
  late Directory dir;
  late LibraryStore store;
  late _Server server;
  late WorldInstaller installer;
  setUp(() async {
    dir = await Directory.systemTemp.createTemp('arke_story_');
    store = LibraryStore(Directory('${dir.path}/library'));
    await store.load();
    server = await _Server.start();
    installer = WorldInstaller(store: store, freeBytes: (_) async => null);
  });
  tearDown(() async {
    await server.close();
    await store.close();
    await dir.delete(recursive: true);
  });

  Future<CataloguePackage> edition() async {
    final made = Directory('${dir.path}/edition')..createSync();
    File('$_media/chapters.m4b').copySync('${made.path}/neap.m4a');
    final zip = '${dir.path}/edition.zip';
    await packWorld(
      WorldSpec(
        id: 'the-undersong',
        edition: '2026-10-22',
        name: 'The Undersong',
        productions: [
          ProductionSpec(
            id: 'the-ledger-of-nights',
            title: 'The Ledger of Nights',
            listening: {
              'title': 'The Ledger of Nights',
              'chapters': [
                {'id': 'a-choir-underwater', 'order': 1, 'title': 'A Choir Underwater', 'audio': '${made.path}/neap.m4a', 'pictures': <Object?>[]},
              ],
            },
          ),
        ],
      ),
      zip,
    );
    final bytes = File(zip).readAsBytesSync();
    server.files['edition.zip'] = bytes;
    return CataloguePackage(
      url: server.url('edition.zip'),
      byteLength: bytes.length,
      sha256: sha256.convert(bytes).toString(),
      edition: '2026-10-22',
      fingerprint: editionFingerprint(readWorldPackage(zip)),
    );
  }

  /// Ring Once published alone, as the Studio writes it: the shared `world.json` and the synthetic
  /// story, every file it names, [mark] making each edition's bytes its own.
  Future<CatalogueStory> story(String label, {int mark = 1, int version = 1}) async {
    final manifest = jsonDecode(File('$_fixtures/world-story.json').readAsStringSync()) as Map<String, Object?>;
    final files = <String, List<int>>{
      for (final MapEntry(:key, :value) in (manifest['assets']! as Map<String, Object?>).entries)
        (value! as Map<String, Object?>)['path']! as String: key == 'story'
            ? utf8.encode(File('$_fixtures/synthetic.json').readAsStringSync())
            : [key.length, mark, 2],
    };
    final assets = <String, Object?>{
      for (final MapEntry(:key, :value) in (manifest['assets']! as Map<String, Object?>).entries)
        key: {
          ...value! as Map<String, Object?>,
          'byteLength': files[(value as Map<String, Object?>)['path']]!.length,
          'sha256': sha256.convert(files[value['path']]!).toString(),
        },
    };
    final archive = Archive()
      ..add(
        ArchiveFile.bytes(worldManifestFile, utf8.encode(jsonEncode({...manifest, 'edition': label, 'assets': assets})))..compression = CompressionType.none,
      );
    for (final MapEntry(:key, :value) in files.entries) {
      archive.add(ArchiveFile.bytes(key, value)..compression = CompressionType.none);
    }
    final zip = '${dir.path}/ring-once-$label.zip';
    File(zip).writeAsBytesSync(ZipEncoder().encode(archive));
    final bytes = File(zip).readAsBytesSync();
    server.files['ring-once-$label.zip'] = bytes;
    return CatalogueStory(
      url: server.url('ring-once-$label.zip'),
      byteLength: bytes.length,
      sha256: sha256.convert(bytes).toString(),
      edition: label,
      fingerprint: editionFingerprint(readWorldPackage(zip)),
      version: version,
    );
  }

  CatalogueWorld listed(CataloguePackage edition, [CatalogueStory? pin]) => CatalogueWorld(
    id: 'the-undersong',
    name: 'The Undersong',
    productions: [
      const CatalogueProduction(title: 'The Ledger of Nights', kind: 'Audiobook', id: 'the-ledger-of-nights'),
      if (pin != null) CatalogueProduction(title: 'Ring Once', kind: 'Interactive movie · 6 scenes', id: 'ring-once', story: pin),
    ],
    package: edition,
  );

  LibraryProduction? ringOf(LibraryWorld world) => world.productions.where((production) => production.id == 'ring-once').firstOrNull;

  test('a world installed with its story has both, the story beside the edition (R-83)', () async {
    final pin = await edition();
    final ring = await story('2026-10-28');
    await installer.install(listed(pin, ring));
    final held = ringOf(store.worlds.single)!;
    expect((held.story!.kind, held.story!.shape, held.story!.scenes), ('movie', '9:16', 6));
    expect(held.story!.fingerprint, startsWith('sha256:'));
    expect(held.package!.fingerprint, ring.fingerprint);
    expect(File(store.resolve(held.story!.document)).existsSync(), isTrue);
    expect(File(store.resolve(held.story!.tall!)).existsSync(), isTrue);
    expect(File('${store.resolve(held.package!.folder)}/world.json').existsSync(), isTrue, reason: 'the manifest is kept, to read the document against');
    // A story keeps its place by route, so no item stands for it.
    expect(store.items.where((item) => item.id.contains('ring-once')), isEmpty);
    expect(missingProductions(listed(pin, ring), store.worlds.single), isEmpty);
  });

  test('a story listed after the world was installed arrives on its own; a new fingerprint is its Update', () async {
    final pin = await edition();
    await installer.install(listed(pin));
    final first = await story('2026-10-28');
    expect(missingProductions(listed(pin, first), store.worlds.single).map((production) => production.id), ['ring-once']);
    await installer.installProduction(listed(pin, first), listed(pin, first).productions.last);
    expect(ringOf(store.worlds.single)!.package!.edition, '2026-10-28');

    final second = await story('2026-10-29', mark: 2);
    expect(productionUpdates(listed(pin, second), store.worlds.single).map((production) => production.id), ['ring-once']);
    await installer.installProduction(listed(pin, second), listed(pin, second).productions.last);
    expect(ringOf(store.worlds.single)!.package!.fingerprint, second.fingerprint);
    expect(productionUpdates(listed(pin, second), store.worlds.single), isEmpty);
  });

  test('a story whose version this Player does not read is never fetched (R-82)', () async {
    final pin = await edition();
    final later = await story('2026-10-28', version: storyVersion + 1);
    final world = listed(pin, later);
    expect(world.productions.last.needsNewerApp, isTrue);
    expect(world.productions.last.alone, isNull);
    await installer.install(world);
    expect(server.asked, ['edition.zip']);
    expect(ringOf(store.worlds.single), isNull);
    expect(missingProductions(world, store.worlds.single), isEmpty);
    await expectLater(installer.installProduction(world, world.productions.last), throwsA(isA<NotAPackage>()));
  });

  test('a story pinned as a production’s package is refused, as before schema 6', () async {
    final pin = await edition();
    await installer.install(listed(pin));
    final ring = await story('2026-10-28');
    final misfiled = CatalogueProduction(title: 'Ring Once', kind: 'Interactive movie', id: 'ring-once', package: ring);
    await expectLater(installer.installProduction(listed(pin), misfiled), throwsA(isA<NotAPackage>()));
    expect(ringOf(store.worlds.single), isNull);
  });
}
