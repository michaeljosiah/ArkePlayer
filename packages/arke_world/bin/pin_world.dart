import 'dart:convert';
import 'dart:io';

import 'package:arke_world/arke_world.dart';
import 'package:crypto/crypto.dart';

/// Prints the catalogue pin for a world package where it is published (SPEC-058 R-30, R-36): its
/// address, length and SHA-256, and the edition and fingerprint an installed world is compared by
/// to see an update. Any package the Player reads will do, the Studio's Export → Arke Player or
/// `pack_world`'s.
///
/// A part (SPEC-058 R-46, R-49) is pinned with the fingerprint of the edition it must follow, the
/// one in its world's list entry: a part made after another edition is refused. It prints the part's
/// pin for the entry's `parts`, and its production's id and schedule for the listed production.
///
/// A production published alone (R-68, R-71), such as an album, is pinned with `--production`: it
/// prints the production's id, its `package` pin and, for music, its `music` kind, to set on the
/// listed production. An edition is never pinned as a production, nor a production as an edition.
///   `dart run arke_world:pin_world <package.zip> <https url>`
///   `dart run arke_world:pin_world <part.zip> <https url> --follows <edition fingerprint>`
///   `dart run arke_world:pin_world <production.zip> <https url> --production`
Future<void> main(List<String> args) async {
  final follows = args.length == 4 && args[2] == '--follows' ? args[3] : null;
  final alone = args.length == 3 && args[2] == '--production';
  if (args.length != 2 && follows == null && !alone) {
    stderr.writeln('usage: dart run arke_world:pin_world <package.zip> <https url> [--follows <edition fingerprint> | --production]');
    exit(64);
  }
  final zip = File(args[0]);
  final url = Uri.parse(args[1]);
  if (url.scheme != 'https') {
    stderr.writeln('a world is published over HTTPS');
    exit(64);
  }
  final WorldManifest manifest;
  try {
    manifest = readWorldPackage(zip.path);
  } on WorldPackageRefused catch (refused) {
    stderr.writeln('not a package the Player reads: ${refused.reason}');
    exit(65);
  }
  final digest = await sha256.bind(zip.openRead()).first;
  final pin = {
    'url': url.toString(),
    'byteLength': await zip.length(),
    'sha256': digest.toString(),
    'edition': manifest.edition,
    'fingerprint': editionFingerprint(manifest),
  };
  if (alone != manifest.alone) {
    stderr.writeln(
      manifest.alone
          ? 'a production published alone is pinned with --production, on its listed production'
          : 'not a production package: --production is for one',
    );
    exit(manifest.alone ? 64 : 65);
  }
  if (alone) {
    final production = manifest.productions.single;
    stdout.writeln(
      const JsonEncoder.withIndent('  ').convert({
        'production': {'id': production.id, 'package': pin, if (manifest.music[production.id] case final music?) 'music': music.kind.name},
      }),
    );
    return;
  }
  final part = manifest.part;
  if (part == null) {
    if (follows != null) {
      stderr.writeln('not a part: --follows is for a part');
      exit(64);
    }
    stdout.writeln(const JsonEncoder.withIndent('  ').convert(pin));
    return;
  }
  if (follows == null) {
    stderr.writeln('a part is pinned with --follows <the fingerprint of the edition in its list entry>');
    exit(64);
  }
  if (part.fingerprint != follows) {
    stderr.writeln('this part follows another edition (${part.follows}), not the one given');
    exit(65);
  }
  final production = manifest.productions.single;
  final document = manifest.listening[production.id];
  // The day it is released: its edition label's date, which the Studio writes.
  final released = parseDay(manifest.edition.length >= 10 ? manifest.edition.substring(0, 10) : manifest.edition);
  if (released == null) {
    stderr.writeln('the part is labelled ${manifest.edition}, which names no day');
    exit(65);
  }
  stdout.writeln(
    const JsonEncoder.withIndent('  ').convert({
      'part': {
        ...pin,
        'released': dayText(released),
        'production': production.id,
        'chapters': [
          for (final chapter in document?.chapters ?? const <ListeningChapter>[]) {'id': chapter.id, 'number': chapter.order, 'title': chapter.title},
        ],
      },
      'production': {'id': production.id, if (part.schedule != null) 'schedule': part.schedule!.toJson()},
    }),
  );
}
