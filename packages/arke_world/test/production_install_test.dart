import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:arke_library/arke_library.dart';
import 'package:arke_world/arke_world.dart';
import 'package:crypto/crypto.dart';
import 'package:test/test.dart';

// SPEC-058 R-68, R-72: a production published on its own, beside its world's edition. Install brings
// it with the world; one listed later arrives on its own; a changed one is its Update; a new edition
// carries it across; and it is never a world of its own.
final _media = '${Directory.current.path}/../arke_media/test/fixtures';
final _fixtures = '${Directory.current.path}/test/fixtures/music';

/// Serves a file per path.
class _Server {
  _Server._(this._server);
  final HttpServer _server;
  final files = <String, List<int>>{};

  Uri url(String path) => Uri.parse('http://127.0.0.1:${_server.port}/$path');

  static Future<_Server> start() async {
    final server = _Server._(await HttpServer.bind(InternetAddress.loopbackIPv4, 0));
    server._server.listen((request) async {
      final body = server.files[request.uri.path.substring(1)];
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
    dir = await Directory.systemTemp.createTemp('arke_production_');
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

  /// The world's edition: one illustrated narration.
  Future<CataloguePackage> edition(String label) async {
    final made = Directory('${dir.path}/edition-$label')..createSync();
    File('$_media/chapters.m4b').copySync('${made.path}/neap.m4a');
    final zip = '${dir.path}/edition-$label.zip';
    await packWorld(
      WorldSpec(
        id: 'the-undersong',
        edition: label,
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
    server.files['edition-$label.zip'] = bytes;
    return CataloguePackage(
      url: server.url('edition-$label.zip'),
      byteLength: bytes.length,
      sha256: sha256.convert(bytes).toString(),
      edition: label,
      fingerprint: editionFingerprint(readWorldPackage(zip)),
    );
  }

  /// The album published alone, as the Studio writes it (SPEC-060 R-17): the shared fixture's
  /// `world.json` and music document, with [tracks] as its tracks' bytes.
  Future<CataloguePackage> album(String label, {String world = 'the-undersong', int tracks = 1}) async {
    final manifest = jsonDecode(File('$_fixtures/world-album.json').readAsStringSync()) as Map<String, Object?>;
    final files = <String, List<int>>{
      'songs-of-the-drowned-quarter/music.json': utf8.encode(File('$_fixtures/album.json').readAsStringSync()),
      'songs-of-the-drowned-quarter/cover.jpg': [0xff, 0xd8, 0xff, 0xe0, tracks],
      'songs-of-the-drowned-quarter/tracks/the-drowned-verse.m4a': [1, 2, 3, tracks],
      'songs-of-the-drowned-quarter/tracks/slack-water.m4a': [4, 5, 6, tracks],
      'songs-of-the-drowned-quarter/tracks/saltmouth-bells.m4a': [7, 8, 9, tracks],
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
        ArchiveFile.bytes(worldManifestFile, utf8.encode(jsonEncode({...manifest, 'id': world, 'edition': label, 'assets': assets})))
          ..compression = CompressionType.none,
      );
    for (final MapEntry(:key, :value) in files.entries) {
      archive.add(ArchiveFile.bytes(key, value)..compression = CompressionType.none);
    }
    final zip = '${dir.path}/album-$label-$world.zip';
    File(zip).writeAsBytesSync(ZipEncoder().encode(archive));
    final bytes = File(zip).readAsBytesSync();
    server.files['album-$label-$world.zip'] = bytes;
    return CataloguePackage(
      url: server.url('album-$label-$world.zip'),
      byteLength: bytes.length,
      sha256: sha256.convert(bytes).toString(),
      edition: label,
      fingerprint: editionFingerprint(readWorldPackage(zip)),
    );
  }

  CatalogueWorld listed(CataloguePackage edition, [CataloguePackage? albumPin]) => CatalogueWorld(
    id: 'the-undersong',
    name: 'The Undersong',
    productions: [
      const CatalogueProduction(title: 'The Ledger of Nights', kind: 'Audiobook', id: 'the-ledger-of-nights'),
      if (albumPin != null)
        CatalogueProduction(
          title: 'Songs of the Drowned Quarter',
          kind: 'Album · 3 tracks',
          id: 'songs-of-the-drowned-quarter',
          package: albumPin,
          music: MusicKind.album,
        ),
    ],
    package: edition,
  );

  LibraryProduction? albumOf(LibraryWorld world) => world.productions.where((production) => production.id == 'songs-of-the-drowned-quarter').firstOrNull;

  test('a world installed with its album has both, the album beside the edition (R-72)', () async {
    final pin = await edition('2026-10-22');
    final albumPin = await album('2026-10-24');
    await installer.install(listed(pin, albumPin));
    final world = store.worlds.single;
    final held = albumOf(world)!;
    expect(held.music!.kind, 'album');
    expect((held.music!.tracks, held.music!.duration), (3, const Duration(milliseconds: 238000 + 185000 + 222000)));
    expect(held.package!.fingerprint, albumPin.fingerprint);
    expect(held.package!.folder, 'worlds/the-undersong/_productions/songs-of-the-drowned-quarter');
    expect(File(store.resolve(held.music!.document)).existsSync(), isTrue);
    expect(File(store.resolve(held.picture!)).existsSync(), isTrue);
    expect(File('${store.resolve(held.package!.folder)}/world.json').existsSync(), isTrue, reason: 'the manifest is kept beside its files');
    expect(world.byteLength >= albumPin.byteLength, isTrue);
    // A song keeps no place, so no item stands for the album (P17 call 20).
    expect(store.items.where((item) => item.id.contains('songs-of-the-drowned-quarter')), isEmpty);
    expect(missingProductions(listed(pin, albumPin), world), isEmpty);
  });

  test('an album listed after the world was installed arrives on its own, beside what is there', () async {
    final pin = await edition('2026-10-22');
    await installer.install(listed(pin));
    final narration = store.items.single;
    final albumPin = await album('2026-10-24');
    expect(missingProductions(listed(pin, albumPin), store.worlds.single).map((production) => production.id), ['songs-of-the-drowned-quarter']);

    await installer.installProduction(listed(pin, albumPin), listed(pin, albumPin).productions.last);
    final world = store.worlds.single;
    expect(albumOf(world)?.music?.tracks, 3);
    expect(world.edition, '2026-10-22', reason: 'a production package does not change the edition');
    expect(store.items.single.id, narration.id, reason: 'what is there is untouched');
    expect(missingProductions(listed(pin, albumPin), world), isEmpty);
    // The same package again changes nothing.
    await installer.installProduction(listed(pin, albumPin), listed(pin, albumPin).productions.last);
    expect(albumOf(store.worlds.single)!.package!.installedAt, albumOf(world)!.package!.installedAt);
  });

  test('a changed album is its Update, pressed: the new package replaces the old', () async {
    final pin = await edition('2026-10-22');
    final first = await album('2026-10-24');
    await installer.install(listed(pin, first));
    final second = await album('2026-11-02', tracks: 2);
    expect(productionUpdates(listed(pin, second), store.worlds.single).map((production) => production.id), ['songs-of-the-drowned-quarter']);
    expect(missingProductions(listed(pin, second), store.worlds.single), isEmpty, reason: 'an installed album is updated, not missing');

    var swapped = false;
    await installer.installProduction(listed(pin, second), listed(pin, second).productions.last, beforeSwap: () async => swapped = true);
    final held = albumOf(store.worlds.single)!;
    expect((held.package!.edition, held.package!.fingerprint, swapped), ('2026-11-02', second.fingerprint, true));
    expect(productionUpdates(listed(pin, second), store.worlds.single), isEmpty);
  });

  test('a new edition of the world carries its album across, nothing fetched again', () async {
    final pin = await edition('2026-10-22');
    final albumPin = await album('2026-10-24');
    await installer.install(listed(pin, albumPin));
    final newer = await edition('2026-11-06');
    server.files.removeWhere((name, _) => name.startsWith('album-'));
    await installer.update(listed(newer, albumPin));
    final world = store.worlds.single;
    expect(world.edition, '2026-11-06');
    final held = albumOf(world)!;
    expect(held.package!.fingerprint, albumPin.fingerprint);
    expect(File(store.resolve(held.music!.document)).existsSync(), isTrue);
  });

  test('a production package is never a world of its own, nor added to another world', () async {
    final albumPin = await album('2026-10-24');
    await expectLater(installer.install(listed(albumPin)), throwsA(isA<NotAPackage>()));
    expect(store.worlds, isEmpty);

    final pin = await edition('2026-10-22');
    await installer.install(listed(pin));
    final stranger = await album('2026-10-24', world: 'copper-saints');
    await expectLater(installer.installProduction(listed(pin, stranger), listed(pin, stranger).productions.last), throwsA(isA<NotAPackage>()));
    expect(albumOf(store.worlds.single), isNull);
    expect(Directory('${store.worldDirectory('the-undersong').path}/_productions').existsSync(), isFalse);
  });

  test('the library keeps a music production through a reload', () async {
    final pin = await edition('2026-10-22');
    final albumPin = await album('2026-10-24');
    await installer.install(listed(pin, albumPin));
    final again = LibraryStore(store.root);
    await again.load();
    final held = albumOf(again.worlds.single)!;
    expect((held.music!.kind, held.music!.tracks, held.package!.edition), ('album', 3, '2026-10-24'));
    expect(Directory(again.resolve(held.package!.folder)).existsSync(), isTrue, reason: 'a load clears nothing it names');
    await again.close();
  });
}
