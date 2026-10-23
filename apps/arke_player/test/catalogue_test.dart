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
    expect(undersong.package!.sha256, 'b521f0c846c8f41d16fc1c1fb71cc5a8d8b333cbc6662c508f3968a6135815f3');
    expect(undersong.package!.edition, '2026-10-22-3');
    expect(undersong.guide!.url.scheme, 'https');
    expect(undersong.guide!.sha256, 'ff02694633fa49e2a742e69a42dc5f87ae5f66dddd41e18c64f1b4e6a0115123');
    // The hand-packed editions were published as `undersong`: a phone holding one is offered Update.
    expect(undersong.replaces, ['undersong']);
    expect(undersong.productions.single.title, 'The Ledger of Nights');
  });

  test('Legend of Dumah is pinned to its published package and its guide alone', () {
    // The Studio's Export → Arke Player of the Prologue and Chapters 1 and 2, narrated with Tall pictures, without the book,
    // and the guide alone beside it (SPEC-059 R-10).
    final dumah = catalogue.singleWhere((world) => world.id == 'legend-of-dumah');
    expect(dumah.package!.sha256, 'a914d0452131dd29a9f23d712866bbc4508d46c0782d391b582b25d9249137a8');
    expect(dumah.package!.edition, '2026-10-23-3');
    expect(dumah.guide!.sha256, 'b8fd89e57fdfc2df1307e4f84a6019eac5218013f21cfb8a2206de34448befe4');
    expect(dumah.productions.single.title, 'Whispers from the Void');
  });
}
