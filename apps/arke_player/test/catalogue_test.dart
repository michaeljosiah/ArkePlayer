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
    expect(undersong.package!.sha256, 'a1e1e38e967d01490c7fe471d56cb65234c87ed6491ef2091a8ff75899742dcc');
    expect(undersong.package!.edition, '2026-10-24');
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
    expect(dumah.package!.sha256, 'ec20646c486f1ef47b21119bfcc09692874d14256560085b77b52a8213a9c731');
    expect(dumah.package!.edition, '2026-10-23-4');
    expect(dumah.guide!.sha256, '99eb0e765e01eaf7421a0c690159480557c234c93cd47139ad901c2754315239');
    expect(dumah.productions.single.title, 'Whispers from the Void');
  });

  test('The Red Quiet is pinned to its published package and its guide alone', () {
    // The Studio's Export → Arke Player of the whole novel as a book, Chapter 1 narrated with Tall
    // pictures, and the guide alone beside it (SPEC-059 R-10).
    final quiet = catalogue.singleWhere((world) => world.id == 'the-red-quiet');
    expect(quiet.package!.sha256, 'dfaa5ac88c00df738deee7557596fecf08ad6504713f5e8d231ed78f9836be91');
    expect(quiet.package!.edition, '2026-10-24');
    expect(quiet.guide!.sha256, 'bba813092c1180e74c7cea42cb0c8fd1b98afe3b01790c536cfc732e9189fcc0');
    expect(quiet.productions.single.title, 'The Red Quiet');
  });

  test('Embers of the Fallen is pinned to its published package and its guide alone', () {
    // The Studio's Export → Arke Player of the whole book, Chapters 1–5 narrated and Chapter 1's
    // pictures made Tall, and the guide alone beside it (SPEC-059 R-10).
    final embers = catalogue.singleWhere((world) => world.id == 'embers-of-the-fallen');
    expect(embers.package!.sha256, '9e34eaf9ab65b4af5786fa63dd89f71465e8562346b55e32e1ea956205b849df');
    expect(embers.package!.edition, '2026-10-24');
    expect(embers.guide!.sha256, '9d99ecacc5350fadaab941f34992e77c3c9c385eb764b07d295cf450710c931a');
    expect(embers.productions.single.title, 'Threshold — Book One');
  });

  test('Na Love or Juju is pinned to its published package and its guide alone', () {
    // The Studio's Export → Arke Player of the whole novel as a book, all 26 chapters narrated,
    // Chapter 1's pictures made Tall, and the guide alone beside it (SPEC-059 R-10).
    final juju = catalogue.singleWhere((world) => world.id == 'na-love-or-juju');
    expect(juju.package!.sha256, '1e608147759cf0a947baf477111dbc0dd3f1d2407fdc9d7fcf2f8d232e404330');
    expect(juju.package!.edition, '2026-10-24');
    expect(juju.guide!.sha256, 'c4fa8e6882dd8fd33ba43d9425d1c93d7bf22411bfb23590896901c0ef2eceb6');
    expect(juju.productions.single.title, 'Na love or Juju');
  });
}
