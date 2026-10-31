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
    final quiet = catalogue.singleWhere((world) => world.id == 'the-red-quiet').productions.first;
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
    final ledger = catalogue.singleWhere((world) => world.id == 'the-undersong').productions.first;
    expect(ledger.tall, 'assets/worlds/undersong/cover-tall.jpg');
    expect(ledger.tallPin!.sha256, '198bf9b2f21fab778401622397efae22a57615a775ccd479736bc5e0004f6776');
  });

  test('The Undersong is pinned to its published package and its guide alone', () {
    // The revised manuscript edition begins with Chapter 1's current text, narration and 22
    // scene images. Parts from the earlier manuscript do not follow this new fingerprint.
    // The guide alone remains available before install (SPEC-059 R-10).
    final undersong = catalogue.singleWhere((world) => world.id == 'the-undersong');
    expect(undersong.package!.sha256, '6a5ccfb24e844867358254ac2385adf1484448deec57bae1e0c83888b3cb5a0f');
    expect(undersong.package!.edition, '2026-10-29-2');
    final slackWater = undersong.package!.parts.single;
    expect(slackWater.sha256, 'f98c11ecbafcb65537bc9b095c7081c7d64c26410ffa2a94c366606091f21db3');
    expect(slackWater.byteLength, 38246282);
    expect(slackWater.production, 'the-ledger-of-nights');
    expect(slackWater.chapters.single.id, 'slack-water');
    expect(slackWater.chapters.single.number, 2);
    expect(slackWater.url.pathSegments.last, 'the-undersong-part-2026-10-29.zip');
    expect(undersong.guide!.url.scheme, 'https');
    expect(undersong.guide!.sha256, 'ff02694633fa49e2a742e69a42dc5f87ae5f66dddd41e18c64f1b4e6a0115123');
    // The hand-packed editions were published as `undersong`: a phone holding one is offered Update.
    expect(undersong.replaces, ['undersong']);
    expect([for (final production in undersong.productions) production.title], ['The Ledger of Nights', 'The Ledger of Nights, drawn']);
  });

  test('The Undersong’s graphic novel is listed as its comic, never as a package (SPEC-064 R-50, P20)', () {
    // The Ledger of Nights, drawn: chapters 1 and 2 (Neap, Slack water), 11 pages in ink and grey
    // wash, made in the Studio on 2026-10-30 and exported from its Pages. The 2026-10-31 edition
    // redraws pages 3, 5, 6, 7, 9, 10 and 11 from a script rewritten for a reader who has only the
    // pages (SPEC-064 R-13a). Schema 7, alone; a
    // `package` here would be installed by every Player before schema 7, which cannot read it.
    final drawn = catalogue.singleWhere((world) => world.id == 'the-undersong').productions.last;
    expect(drawn.id, 'the-ledger-of-nights-drawn');
    expect(drawn.kind, 'Graphic novel · 11 pages');
    expect(drawn.package, isNull);
    expect(drawn.comic!.sha256, '4a3e4f55e4236b99e57d2ffa2a5869180f9f7f5d06393dcaf802fa7bf3341238');
    expect(drawn.comic!.version, 1);
    expect(drawn.comic!.edition, '2026-10-31');
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
    expect([for (final production in quiet.productions) production.title], ['The Red Quiet', 'First Contact']);
  });

  test('The Red Quiet’s First Contact is listed as its story, never as a package (SPEC-058 R-82)', () {
    // The visual novel's third edition, exported 2026-10-29: the second's story, now part-narrated —
    // scenes 1 to 8 in Ines Marr's voice and the six miners' own, 71 lines; 9 to 15 still read by
    // their reading time until their narration is made. 15 scenes, 208 routes, one ending of 104
    // variants, which a Player from before PR #25 refuses. A `package` here would be installed by
    // every Player of rev 11, which cannot play it.
    final story = catalogue.singleWhere((world) => world.id == 'the-red-quiet').productions.singleWhere((production) => production.id == 'first-contact');
    expect(story.package, isNull);
    expect(story.story!.sha256, '3d9bf6a53fafff6ba47a1bb306a4b80c9a3db260449503d36aff9288ca2e4d61');
    expect(story.story!.playable, isTrue);
    expect(story.picturePin, isNotNull);
    expect(story.tallPin, isNotNull);
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
    // The Studio's Export → Arke Player of the novel's final text as a book, all 26 chapters
    // narrated between opening and closing credits, chapter 23's lagoon night told in full, and the
    // guide alone beside it with its teasers (SPEC-059 R-10, R-24).
    final juju = catalogue.singleWhere((world) => world.id == 'na-love-or-juju');
    expect(juju.package!.sha256, '1688b1f011649519fc7d95df60ca03911643bff7ec923ce712ebbac4abc667d0');
    expect(juju.package!.edition, '2026-10-31');
    expect(juju.guide!.sha256, 'c18fcfbacc2eca18eed8d5663254eb354016bcbc528f45e32bbb1c40d5f2bb73');
    expect(juju.productions.single.title, 'Na love or Juju');
  });
}
