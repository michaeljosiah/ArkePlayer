import 'dart:io';

import 'package:arke_world/arke_world.dart';
import 'package:flutter_test/flutter_test.dart';

// The list of worlds ships with the app (P9 rule 1). A malformed one, or one naming a picture the
// app does not bundle, is a build error, so it is caught here rather than on a phone.
void main() {
  final catalogue = readCatalogue(File('assets/worlds/catalogue.json').readAsStringSync());

  test('the bundled catalogue reads, every world pinned over HTTPS', () {
    expect(catalogue, isNotEmpty);
    for (final world in catalogue) {
      expect(world.package?.url.scheme, 'https', reason: world.id);
    }
  });

  test('every picture it names is bundled', () {
    for (final world in catalogue) {
      for (final picture in [world.keyArt, for (final production in world.productions) production.picture].whereType<String>()) {
        expect(File(picture).existsSync(), isTrue, reason: picture);
      }
    }
  });

  test('The Undersong is pinned to its published package and its guide alone', () {
    // The Studio's Export → Arke Player of the 23-chapter edition with its guide, named by the
    // world's own slug, and the guide alone that lets it be explored before install (SPEC-059 R-10).
    final undersong = catalogue.singleWhere((world) => world.id == 'the-undersong');
    expect(undersong.package!.sha256, 'cb4975f9e0edc147fdf77ef2b356479d6c5007b6a503f43f96b322c31d9e7acd');
    expect(undersong.package!.edition, '2026-10-22-2');
    expect(undersong.guide!.url.scheme, 'https');
    expect(undersong.guide!.sha256, 'ff02694633fa49e2a742e69a42dc5f87ae5f66dddd41e18c64f1b4e6a0115123');
    // The hand-packed editions were published as `undersong`: a phone holding one is offered Update.
    expect(undersong.replaces, ['undersong']);
    expect(undersong.productions.single.title, 'The Ledger of Nights');
  });
}
