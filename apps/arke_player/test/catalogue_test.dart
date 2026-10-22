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

  test('The Undersong is pinned to its published package', () {
    // The Studio's Export → Arke Player of the 23-chapter edition, named by the world's own slug.
    final undersong = catalogue.singleWhere((world) => world.id == 'the-undersong');
    expect(undersong.package!.sha256, 'fb45df559fff41d25a20150bc7b936671b97b3e7b1a354d37f8ccb2a41ba3559');
    expect(undersong.package!.edition, '2026-10-22');
    // The hand-packed editions were published as `undersong`: a phone holding one is offered Update.
    expect(undersong.replaces, ['undersong']);
    expect(undersong.productions.single.title, 'The Ledger of Nights');
  });
}
