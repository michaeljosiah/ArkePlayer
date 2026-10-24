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

  test('every picture it names is bundled, Tall covers too', () {
    for (final world in catalogue) {
      for (final picture in [
        world.keyArt,
        for (final production in world.productions) ...[production.picture, production.tall],
      ].whereType<String>()) {
        expect(File(picture).existsSync(), isTrue, reason: picture);
      }
    }
  });

  test('Discover’s feature and band name listed worlds (P16 call 15)', () {
    final list = parseCatalogue(File('assets/worlds/catalogue.json').readAsStringSync());
    final ids = {for (final world in list.worlds) world.id};
    expect(ids, contains(list.feature?.world));
    expect(ids, contains(list.band));
  });

  test('Na Love or Juju’s Tall cover is its book cover, upright (P16 call 14)', () {
    final juju = catalogue.singleWhere((world) => world.id == 'na-love-or-juju').productions.single;
    expect(juju.tall, 'assets/worlds/na-love-or-juju/cover-tall.jpg');
  });

  test('The Red Quiet’s Tall cover is its own poster, title at the top (P16 call 14)', () {
    // Made upright rather than cut from the Wide cover: Ines Marr and the Mistress, with the title
    // below the 51 px the phone's feature takes from a poster's top.
    final quiet = catalogue.singleWhere((world) => world.id == 'the-red-quiet').productions.single;
    expect(quiet.tall, 'assets/worlds/the-red-quiet/cover-tall.jpg');
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
    // The Studio's Export → Arke Player of the Prologue and Chapters 1 to 3, narrated with Tall pictures, without the book,
    // and the guide alone beside it (SPEC-059 R-10).
    final dumah = catalogue.singleWhere((world) => world.id == 'legend-of-dumah');
    expect(dumah.package!.sha256, 'dbaad8bc67d8cc095fc4338a3a2420094f965a1a6a3c660702f3b9596ac4898a');
    expect(dumah.package!.edition, '2026-10-24');
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
    // Chapter 1's new pictures set on their sentences, every picture made Tall, and the guide
    // alone beside it with its teasers (SPEC-059 R-10, R-24).
    final juju = catalogue.singleWhere((world) => world.id == 'na-love-or-juju');
    expect(juju.package!.sha256, '83c120b93095ea0cb1a05e5c709af0d40d0a3b209eb65bcb80f472e69c9af7ff');
    expect(juju.package!.edition, '2026-10-24');
    expect(juju.guide!.sha256, '3c4e5df3a6389f66824ebdd4b56c59736242f6b13a0ecb3006fa8961bde6e1e8');
    expect(juju.productions.single.title, 'Na love or Juju');
  });
}
