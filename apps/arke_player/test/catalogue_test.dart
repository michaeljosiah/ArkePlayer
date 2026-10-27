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

  test('every picture comes with the list too, from Arke’s own release under a name of its own (SPEC-058 R-63, R-67)', () {
    // Pinned on 2026-10-24, the day three upright covers reached the list and phones running that
    // morning's build showed none of them. A pin per slot, so a new cover needs no app release.
    final name = RegExp(r'^[a-z0-9-]+-(keyArt|picture|tall)-\d{8}\.(jpg|png|webp)$');
    for (final world in catalogue) {
      final pinned = <(String, String?, PicturePin?)>[
        ('keyArt', world.keyArt, world.keyArtPin),
        for (final production in world.productions) ...[('picture', production.picture, production.picturePin), ('tall', production.tall, production.tallPin)],
      ];
      for (final (slot, bundled, pin) in pinned) {
        if (bundled == null) continue;
        expect(pin, isNotNull, reason: '${world.id} $slot');
        expect(pin!.url.toString(), startsWith('https://github.com/michaeljosiah/ArkeStudio/releases/download/arke-player-worlds/${world.id}-$slot-'));
        expect(name.hasMatch(pin.url.pathSegments.last), isTrue, reason: pin.url.toString());
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

  test('Legend of Dumah’s Tall cover is its own poster, title at the foot (P16 call 14)', () {
    // Made upright with Codex Image from Pricilla's, Brackus's, Sora's and Lucien's main photos, the
    // author's name at the top. Pinned as well as bundled, so a phone with list pictures shows it
    // without a build.
    final dumah = catalogue.singleWhere((world) => world.id == 'legend-of-dumah').productions.single;
    expect(dumah.tall, 'assets/worlds/legend-of-dumah/cover-tall.jpg');
    expect(dumah.tallPin!.sha256, '612938f535be0f3445ccbc0533e0bbef1e3a6b37e096c9c2b9e945276439aec8');
  });

  test('The Undersong’s Tall cover is its own poster, title at the foot (P16 call 14)', () {
    // Made upright with Codex Image from Maren's, Bray's, Perrin's and the Chorister's main photos,
    // the drowned god's face under the title. Pinned as well as bundled, like Dumah's.
    final ledger = catalogue.singleWhere((world) => world.id == 'the-undersong').productions.single;
    expect(ledger.tall, 'assets/worlds/undersong/cover-tall.jpg');
    expect(ledger.tallPin!.sha256, '198bf9b2f21fab778401622397efae22a57615a775ccd479736bc5e0004f6776');
  });

  test('The Undersong is pinned to its published package and its guide alone', () {
    // The native Chapters 1–3 edition adds Chapter 3's six picture pairs. Parts only append
    // chapters, so revising an installed chapter requires a new edition rather than a replacement
    // part. The guide alone remains available before install (SPEC-059 R-10).
    final undersong = catalogue.singleWhere((world) => world.id == 'the-undersong');
    expect(undersong.package!.sha256, '5cd345dce0f497883c36c6509faf595c178d68c0a613dee7298f885f51117cdb');
    expect(undersong.package!.edition, '2026-10-26');
    expect(undersong.package!.parts, hasLength(2));
    expect(undersong.package!.parts.first.sha256, '56b408526a384ce34435ca45a52a31f07020314fd7c5df436571fd11d5393f42');
    expect(undersong.package!.parts.first.chapters.single.id, 'the-same-ink');
    expect(undersong.package!.parts.last.sha256, 'daf83567861183d9e43aad8fe19f93ff4c369f7df614c6f5be99619336dde99c');
    expect(undersong.package!.parts.last.chapters.single.id, 'independent-record');
    expect(undersong.package!.parts.last.chapters.single.number, 5);
    expect(undersong.guide!.url.scheme, 'https');
    expect(undersong.guide!.sha256, 'ff02694633fa49e2a742e69a42dc5f87ae5f66dddd41e18c64f1b4e6a0115123');
    // The hand-packed editions were published as `undersong`: a phone holding one is offered Update.
    expect(undersong.replaces, ['undersong']);
    expect(undersong.productions.single.title, 'The Ledger of Nights');
  });

  test('Legend of Dumah is pinned to its published package and its guide alone', () {
    // The Studio's Export → Arke Player of the Prologue and Chapters 1 to 4, narrated with 110 Tall pictures, without the book,
    // and the guide alone beside it (SPEC-059 R-10).
    final dumah = catalogue.singleWhere((world) => world.id == 'legend-of-dumah');
    expect(dumah.package!.sha256, '81c5f6b8c296753fe21f5c0c4cf93540496d1aac73b50793475dec4dd7a03613');
    expect(dumah.package!.edition, '2026-10-25');
    expect(dumah.guide!.sha256, '99eb0e765e01eaf7421a0c690159480557c234c93cd47139ad901c2754315239');
    expect(dumah.productions.single.title, 'Whispers from the Void');
  });

  test('The Red Quiet is pinned to its published package and its guide alone', () {
    // The Studio's Export → Arke Player of the whole novel as a book, Chapter 1 narrated with Tall
    // pictures, and the guide alone beside it (SPEC-059 R-10). Its production's picture is the
    // face-off poster, so an installed phone shows it after Update without a new build.
    final quiet = catalogue.singleWhere((world) => world.id == 'the-red-quiet');
    expect(quiet.package!.sha256, '1781cb578e2dd1755020840dd4b39dc11ca926e1436a372e8016218c490ae579');
    expect(quiet.package!.edition, '2026-10-24-2');
    expect(quiet.guide!.sha256, 'bba813092c1180e74c7cea42cb0c8fd1b98afe3b01790c536cfc732e9189fcc0');
    expect(quiet.productions.single.title, 'The Red Quiet');
  });

  test('Embers of the Fallen is pinned to its published package and its guide alone', () {
    // The Studio's Export → Arke Player of the whole book, Chapters 1–5 narrated and Chapter 1's
    // pictures made Tall, and the guide alone beside it (SPEC-059 R-10). Its production's picture
    // is the key-art poster, so an installed phone shows it after Update without a new build.
    final embers = catalogue.singleWhere((world) => world.id == 'embers-of-the-fallen');
    expect(embers.package!.sha256, '6f9715e501fc2c88cc530bc7629e5e25b8b1ee3e62e195bfbad956c859625404');
    expect(embers.package!.edition, '2026-10-24-3');
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
