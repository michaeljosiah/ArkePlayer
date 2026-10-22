import 'dart:convert';
import 'dart:io';

import 'package:arke_library/arke_library.dart';
import 'package:arke_publication/arke_publication.dart';
import 'package:arke_world/arke_world.dart';
import 'package:crypto/crypto.dart';
import 'package:test/test.dart';

// SPEC-058 R-30 – R-36, Player P12: a world's newer edition, named in Arke's list, fetched as well
// as shipped, and installed over the edition on the phone with its places kept.
final _fixtures = '${Directory.current.path}/../arke_media/test/fixtures';

Future<WorldSpec> _spec(Directory dir, String edition, {String id = 'undersong'}) async {
  final art = File('${dir.path}/key-art.jpg');
  await art.writeAsBytes([0xFF, 0xD8, 0xFF, 0xE0, 1, 2, 3, 4, 0xFF, 0xD9]);
  return WorldSpec(
    id: id,
    edition: edition,
    name: 'The Undersong',
    keyArt: art.path,
    productions: [ProductionSpec(id: 'ledger-of-nights', title: 'The Ledger of Nights', book: '$_fixtures/book.epub', narration: '$_fixtures/chapters.m4b')],
  );
}

/// Serves whatever [body] holds, at any path; [status] answers instead when set.
class _Server {
  _Server._(this._server);
  final HttpServer _server;
  List<int> body = const [];
  int? status;
  int hits = 0;

  Uri url(String path) => Uri.parse('http://127.0.0.1:${_server.port}/$path');

  static Future<_Server> start() async {
    final server = _Server._(await HttpServer.bind(InternetAddress.loopbackIPv4, 0));
    server._server.listen((request) async {
      server.hits++;
      final response = request.response;
      if (server.status != null) {
        response.statusCode = server.status!;
      } else {
        response.contentLength = server.body.length;
        response.add(server.body);
      }
      await response.close();
    });
    return server;
  }

  Future<void> close() => _server.close(force: true);
}

String _list({
  required int serial,
  String? fingerprint,
  String edition = '2026-10-22',
  String? keyArt,
  String name = 'The Undersong',
  List<Map<String, Object?>> more = const [],
}) => jsonEncode({
  'version': 2,
  'serial': serial,
  'worlds': [
    {
      'id': 'undersong',
      'name': name,
      'keyArt': ?keyArt,
      'productions': [
        {'title': 'The Ledger of Nights', 'kind': 'Audiobook · Book · 8 h 2 m', 'picture': 'assets/remote/ledger.jpg'},
      ],
      'package': {'url': 'https://example.org/the-undersong.zip', 'byteLength': 10, 'sha256': 'a' * 64, 'edition': edition, 'fingerprint': ?fingerprint},
    },
    ...more,
  ],
});

void main() {
  group('editions in the list (R-30)', () {
    test('version 1 still reads, with serial 0 and no editions', () {
      final list = parseCatalogue(
        jsonEncode({
          'version': 1,
          'worlds': [
            {
              'id': 'undersong',
              'name': 'The Undersong',
              'productions': <Object?>[],
              'package': {'url': 'https://example.org/w.zip', 'byteLength': 1, 'sha256': 'b' * 64},
            },
          ],
        }),
      );
      expect(list.serial, 0);
      expect(list.worlds.single.package?.edition, isNull);
    });

    test('version 2 names each package edition and fingerprint', () {
      final list = parseCatalogue(_list(serial: 4, fingerprint: 'c' * 64));
      expect(list.serial, 4);
      expect((list.worlds.single.package?.edition, list.worlds.single.package?.fingerprint), ('2026-10-22', 'c' * 64));
    });

    test('a broken fingerprint, a repeated world or a newer version is not a list', () {
      expect(() => parseCatalogue(_list(serial: 1, fingerprint: 'nope')), throwsFormatException);
      final twice = jsonDecode(_list(serial: 1)) as Map<String, Object?>;
      twice['worlds'] = [...(twice['worlds']! as List<Object?>), ...(twice['worlds']! as List<Object?>)];
      expect(() => parseCatalogue(jsonEncode(twice)), throwsFormatException);
      expect(() => parseCatalogue(jsonEncode({'version': 3, 'serial': 1, 'worlds': <Object?>[]})), throwsFormatException);
    });

    test('the app ships version 2', () {
      final shipped = parseCatalogue(File('${Directory.current.path}/../../apps/arke_player/assets/worlds/catalogue.json').readAsStringSync());
      expect(shipped.serial, greaterThan(0));
      for (final world in shipped.worlds) {
        expect(world.package?.fingerprint, isNotNull, reason: '${world.id} names its edition');
      }
    });
  });

  group('a world under a new id (R-30)', () {
    final renamed = parseCatalogue(
      jsonEncode({
        'version': 2,
        'serial': 3,
        'worlds': [
          {
            'id': 'the-undersong',
            'name': 'The Undersong',
            'replaces': ['undersong'],
            'productions': [
              {'title': 'The Ledger of Nights', 'kind': 'Audiobook · Book · 5 h 33 m'},
            ],
            'package': {'url': 'https://example.org/w.zip', 'byteLength': 1, 'sha256': 'b' * 64, 'edition': '2026-10-22', 'fingerprint': 'c' * 64},
          },
        ],
      }),
    );

    test('names the ids it replaces, never its own', () {
      expect(renamed.worlds.single.replaces, ['undersong']);
      expect(listedFor(renamed.worlds, 'undersong')?.id, 'the-undersong');
      final self = jsonDecode(_list(serial: 1)) as Map<String, Object?>;
      ((self['worlds']! as List<Object?>).single! as Map<String, Object?>)['replaces'] = ['undersong'];
      expect(() => parseCatalogue(jsonEncode(self)), throwsFormatException);
    });

    test('keeps the shipped pictures of the world it replaces', () {
      final shipped = parseCatalogue(_list(serial: 2, keyArt: 'assets/worlds/undersong/key-art.jpg'));
      expect(newestCatalogue(shipped, renamed).worlds.single.keyArt, 'assets/worlds/undersong/key-art.jpg');
    });
  });

  group('the newest list (R-31)', () {
    final shipped = parseCatalogue(_list(serial: 2, edition: '2026-10-20', keyArt: 'assets/worlds/undersong/key-art.jpg'));

    test('a kept list with a higher serial is the list, its pictures the app’s', () {
      final kept = parseCatalogue(
        _list(
          serial: 3,
          keyArt: 'assets/remote/key-art.jpg',
          more: [
            {'id': 'copper-saints', 'name': 'Copper Saints', 'keyArt': 'assets/remote/copper.jpg', 'productions': <Object?>[]},
          ],
        ),
      );
      final newest = newestCatalogue(shipped, kept);
      expect(newest.serial, 3);
      final undersong = newest.worlds.first;
      expect(undersong.package?.edition, '2026-10-22');
      expect(undersong.keyArt, 'assets/worlds/undersong/key-art.jpg');
      // Pictures are the shipped list's, never the fetched one's.
      expect(undersong.productions.single.picture, shipped.worlds.single.productions.single.picture);
      expect(undersong.productions.single.kind, 'Audiobook · Book · 8 h 2 m');
      // A world the app does not ship is shown without pictures.
      expect(newest.worlds.last.keyArt, isNull);
    });

    test('a kept list no newer than the shipped one is not', () {
      expect(newestCatalogue(shipped, parseCatalogue(_list(serial: 2))).worlds.single.package?.edition, '2026-10-20');
      expect(newestCatalogue(shipped, parseCatalogue(_list(serial: 1))).serial, 2);
      expect(newestCatalogue(shipped, null).serial, 2);
    });
  });

  group('an update (R-32)', () {
    LibraryWorld installed({String edition = '2026-10-20', String? fingerprint}) => LibraryWorld(
      id: 'undersong',
      edition: edition,
      name: 'The Undersong',
      byteLength: 1,
      installedAt: DateTime.utc(2026, 10, 20),
      productions: const [],
      fingerprint: fingerprint,
    );
    final listed = parseCatalogue(_list(serial: 2, fingerprint: 'd' * 64)).worlds.single;

    test('by fingerprint', () {
      expect(hasUpdate(listed, installed(fingerprint: 'e' * 64)), isTrue);
      expect(hasUpdate(listed, installed(fingerprint: 'd' * 64)), isFalse);
    });

    test('by label, for a world installed before fingerprints were kept', () {
      expect(hasUpdate(listed, installed()), isTrue);
      expect(hasUpdate(listed, installed(edition: '2026-10-22')), isFalse);
    });

    test('none when the list names no edition, or another world', () {
      final unnamed = parseCatalogue(
        jsonEncode({
          'version': 1,
          'worlds': [
            {
              'id': 'undersong',
              'name': 'The Undersong',
              'package': {'url': 'https://example.org/w.zip', 'byteLength': 1, 'sha256': 'b' * 64},
            },
          ],
        }),
      ).worlds.single;
      expect(hasUpdate(unnamed, installed(fingerprint: 'e' * 64)), isFalse);
      expect(
        hasUpdate(
          listed,
          LibraryWorld(id: 'copper-saints', edition: 'x', name: 'Copper Saints', byteLength: 1, installedAt: DateTime.utc(2026), productions: const []),
        ),
        isFalse,
      );
    });
  });

  group('the hosted list (R-31)', () {
    late Directory dir;
    late _Server server;
    var now = DateTime.utc(2026, 10, 22, 9);
    setUp(() async {
      dir = await Directory.systemTemp.createTemp('arke_hosted_');
      server = await _Server.start();
      now = DateTime.utc(2026, 10, 22, 9);
    });
    tearDown(() async {
      await server.close();
      await dir.delete(recursive: true);
    });
    HostedCatalogue hosted() => HostedCatalogue(url: server.url('catalogue.json'), kept: File('${dir.path}/catalogue.json'), now: () => now);

    test('is fetched at most once a day and kept', () async {
      server.body = utf8.encode(_list(serial: 3));
      expect((await hosted().refresh())?.serial, 3);
      expect(server.hits, 1);
      now = now.add(const Duration(hours: 23));
      expect((await hosted().refresh())?.serial, 3);
      expect(server.hits, 1, reason: 'asked within the day');
      // Kept across a restart, offline.
      server.status = 503;
      expect((await hosted().keptList())?.serial, 3);
    });

    test('keeps what it had when the fetch fails, the list breaks, or the list is older', () async {
      server.body = utf8.encode(_list(serial: 5));
      await hosted().refresh();
      for (final next in [utf8.encode('{"version": 2'), utf8.encode(_list(serial: 4))]) {
        server.body = next;
        now = now.add(const Duration(days: 2));
        expect((await hosted().refresh())?.serial, 5);
      }
      server.status = 404;
      now = now.add(const Duration(days: 2));
      expect((await hosted().refresh())?.serial, 5);
      expect(server.hits, 4);
    });

    test('a list far larger than a list is not one', () async {
      server.body = List.filled(HostedCatalogue.maxBytes + 10, 0x20);
      expect(await hosted().refresh(), isNull);
    });
  });

  group('updating (R-33)', () {
    late Directory dir;
    late LibraryStore store;
    late _Server server;
    setUp(() async {
      dir = await Directory.systemTemp.createTemp('arke_update_');
      store = LibraryStore(Directory('${dir.path}/library'));
      await store.load();
      server = await _Server.start();
    });
    tearDown(() async {
      await server.close();
      await store.close();
      await dir.delete(recursive: true);
    });

    Future<CatalogueWorld> published(String edition, {String id = 'undersong', List<String> replaces = const []}) async {
      final made = Directory('${dir.path}/$id-$edition')..createSync();
      await packWorld(await _spec(made, edition, id: id), '${made.path}/world.zip');
      final bytes = await File('${made.path}/world.zip').readAsBytes();
      server.body = bytes;
      return CatalogueWorld(
        id: id,
        name: 'The Undersong',
        productions: const [],
        replaces: replaces,
        package: CataloguePackage(
          url: server.url('$edition.zip'),
          byteLength: bytes.length,
          sha256: sha256.convert(bytes).toString(),
          edition: edition,
          fingerprint: editionFingerprint(readWorldPackage('${made.path}/world.zip')),
        ),
      );
    }

    test('replaces the installed edition once the new one is checked, its places kept', () async {
      final installer = WorldInstaller(store: store, freeBytes: (_) async => null);
      await installer.install(await published('2026-10-20'));
      final narration = store.items.singleWhere((item) => item.format == FileFormat.m4b);
      await store.keepPlace(narration.id, Place(progress: 0.4, position: const Duration(seconds: 2), locator: '1', updatedAt: DateTime.utc(2026, 10, 21)));

      final newer = await published('2026-10-22');
      expect(hasUpdate(newer, store.worlds.single), isTrue);
      var swapped = false;
      final steps = <InstallStep>[];
      final world = await installer.update(
        newer,
        onStep: steps.add,
        beforeSwap: () async {
          // Until the swap, the phone still has the edition it had.
          expect(store.worlds.single.edition, '2026-10-20');
          swapped = true;
        },
      );
      expect(swapped, isTrue);
      expect(steps.whereType<Downloading>(), isNotEmpty);
      expect(steps.whereType<Checking>(), isNotEmpty);
      expect(world.edition, '2026-10-22');
      expect(store.worlds.single.edition, '2026-10-22');
      expect(hasUpdate(newer, store.worlds.single), isFalse);
      expect(store.items.singleWhere((item) => item.id == narration.id).place?.progress, 0.4);
    });

    test('changes nothing when the package is the edition installed', () async {
      final installer = WorldInstaller(store: store, freeBytes: (_) async => null);
      final same = await published('2026-10-20');
      await installer.install(same);
      var swapped = false;
      await installer.update(same, beforeSwap: () async => swapped = true);
      expect(swapped, isFalse);
    });

    test('a world installed under an id the new one replaces is updated to it, the old one gone (R-30)', () async {
      final installer = WorldInstaller(store: store, freeBytes: (_) async => null);
      await installer.install(await published('2026-10-20'));
      final renamed = await published('2026-10-22', id: 'the-undersong', replaces: ['undersong']);
      expect(hasUpdate(renamed, store.worlds.single), isTrue);
      expect(availableWorlds([renamed], store.worlds), isEmpty, reason: 'not a second world on Available');
      var released = false;
      final world = await installer.update(renamed, beforeSwap: () async => released = true);
      expect(released, isTrue);
      expect(world.id, 'the-undersong');
      expect(store.worlds.map((installed) => installed.id), ['the-undersong']);
      expect(store.items.every((item) => item.worldId == 'the-undersong'), isTrue);
      expect(store.worldDirectory('undersong').existsSync(), isFalse);
    });

    test('a refusal leaves the installed edition (R-35)', () async {
      final installer = WorldInstaller(store: store, freeBytes: (_) async => null);
      await installer.install(await published('2026-10-20'));
      final newer = await published('2026-10-22');
      server.status = 404;
      await expectLater(installer.update(newer), throwsA(isA<InstallRefusal>()));
      expect(store.worlds.single.edition, '2026-10-20');
    });
  });
}
