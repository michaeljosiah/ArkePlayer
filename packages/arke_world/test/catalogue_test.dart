import 'dart:convert';

import 'package:arke_world/arke_world.dart';
import 'package:test/test.dart';

// SPEC-058 rev 9, Player P16 calls 14 and 15: a production's Tall cover in Arke's list, and the
// list naming Discover's feature and band.
String _list({required int serial, Object? tall, Object? feature, Object? band, String picture = 'assets/worlds/juju/cover.jpg'}) => jsonEncode({
  'version': 2,
  'serial': serial,
  'feature': ?feature,
  'band': ?band,
  'worlds': [
    {
      'id': 'na-love-or-juju',
      'name': 'Na Love or Juju',
      'productions': [
        {'id': 'na-love-or-juju', 'title': 'Na love or Juju', 'kind': 'Audiobook · Book · 11 h 55 m', 'picture': picture, 'tall': ?tall},
      ],
      'package': {'url': 'https://example.org/juju.zip', 'byteLength': 10, 'sha256': 'a' * 64},
    },
  ],
});

void main() {
  group('a production’s Tall cover', () {
    test('reads beside its picture, and is absent when the list names none', () {
      final tall = parseCatalogue(_list(serial: 1, tall: 'assets/worlds/juju/cover-tall.jpg')).worlds.single.productions.single;
      expect(tall.picture, 'assets/worlds/juju/cover.jpg');
      expect(tall.tall, 'assets/worlds/juju/cover-tall.jpg');
      expect(parseCatalogue(_list(serial: 1)).worlds.single.productions.single.tall, isNull);
    });

    test('one that is not a path is not a list', () {
      expect(() => parseCatalogue(_list(serial: 1, tall: 3)), throwsFormatException);
      expect(() => parseCatalogue(_list(serial: 1, tall: '')), throwsFormatException);
    });

    test('like its picture, it is the shipped list’s when a fetched one is newer', () {
      final shipped = parseCatalogue(_list(serial: 2, tall: 'assets/worlds/juju/cover-tall.jpg'));
      final kept = parseCatalogue(_list(serial: 3, tall: 'assets/remote/tall.jpg', picture: 'assets/remote/cover.jpg'));
      final production = newestCatalogue(shipped, kept).worlds.single.productions.single;
      expect(production.picture, 'assets/worlds/juju/cover.jpg');
      expect(production.tall, 'assets/worlds/juju/cover-tall.jpg');
    });
  });

  group('the feature and the band', () {
    test('a world and a production, or a world alone; a band by its world', () {
      final named = parseCatalogue(_list(serial: 1, feature: {'world': 'na-love-or-juju', 'production': 'na-love-or-juju'}, band: 'the-undersong'));
      expect(named.feature?.world, 'na-love-or-juju');
      expect(named.feature?.production, 'na-love-or-juju');
      expect(named.band, 'the-undersong');
      final worldAlone = parseCatalogue(_list(serial: 1, feature: {'world': 'na-love-or-juju'}));
      expect(worldAlone.feature?.production, isNull);
      expect(worldAlone.band, isNull);
    });

    test('a name no listed world answers to still reads; the reader ignores it', () {
      final unknown = parseCatalogue(_list(serial: 1, feature: {'world': 'not-yet'}, band: 'not-yet'));
      expect(unknown.feature?.world, 'not-yet');
      expect(unknown.band, 'not-yet');
    });

    test('the wrong shapes are not a list', () {
      expect(() => parseCatalogue(_list(serial: 1, feature: 'na-love-or-juju')), throwsFormatException);
      expect(() => parseCatalogue(_list(serial: 1, feature: {'production': 'na-love-or-juju'})), throwsFormatException);
      expect(() => parseCatalogue(_list(serial: 1, feature: {'world': 'Na Love'})), throwsFormatException);
      expect(() => parseCatalogue(_list(serial: 1, feature: {'world': 'na-love-or-juju', 'production': 4})), throwsFormatException);
      expect(() => parseCatalogue(_list(serial: 1, band: {'world': 'the-undersong'})), throwsFormatException);
    });

    test('they are the newer list’s, so a fetched list can move them', () {
      final shipped = parseCatalogue(_list(serial: 2, feature: {'world': 'na-love-or-juju'}, band: 'the-undersong'));
      final kept = parseCatalogue(_list(serial: 3, band: 'legend-of-dumah'));
      final newest = newestCatalogue(shipped, kept);
      expect(newest.feature, isNull);
      expect(newest.band, 'legend-of-dumah');
      expect(newestCatalogue(shipped, parseCatalogue(_list(serial: 2))).feature?.world, 'na-love-or-juju');
    });
  });
}
