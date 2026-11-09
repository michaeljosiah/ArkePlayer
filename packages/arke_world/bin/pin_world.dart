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
///
/// A story (R-79, R-82), an interactive movie or a visual novel, is a production package too, pinned
/// with `--production`: it prints the pin with the story document's `version` as the production's
/// `story`, never as its `package`, which every Player of rev 11 would fetch and could not play.
/// A graphic novel (SPEC-064 R-51) is likewise pinned as `comic`, with its document's version.
///
///   `dart run arke_world:pin_world <package.zip> <https url>`
///   `dart run arke_world:pin_world <part.zip> <https url> --follows <edition fingerprint>`
///   `dart run arke_world:pin_world <production.zip> <https url> --production`
Future<void> main(List<String> args) async {
  try {
    stdout.writeln(const JsonEncoder.withIndent('  ').convert(await pinWorldPackage(args)));
  } on PinRefused catch (refused) {
    stderr.writeln(refused.reason);
    exitCode = refused.exitCode;
  }
}

/// Reads the package structure and documents, then hashes the outer archive. This does not verify
/// every inventory asset's bytes: admission and installation must still perform those checks.
/// Kept separate from stdout and process exit so pin compatibility is tested without a subprocess.
Future<Map<String, Object?>> pinWorldPackage(List<String> args) async {
  final follows = args.length == 4 && args[2] == '--follows' ? args[3] : null;
  final alone = args.length == 3 && args[2] == '--production';
  if (args.length != 2 && follows == null && !alone) {
    throw const PinRefused(64, 'usage: dart run arke_world:pin_world <package.zip> <https url> [--follows <edition fingerprint> | --production]');
  }
  final zip = File(args[0]);
  final url = Uri.tryParse(args[1]);
  if (url == null || url.scheme != 'https' || url.host.isEmpty) {
    throw const PinRefused(64, 'a world is published over HTTPS');
  }
  final WorldManifest manifest;
  try {
    manifest = readWorldPackage(zip.path);
  } on WorldPackageRefused catch (refused) {
    throw PinRefused(65, 'not a package the Player reads: ${refused.reason}');
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
    throw PinRefused(
      manifest.alone ? 64 : 65,
      manifest.alone
          ? 'a production published alone is pinned with --production, on its listed production'
          : 'not a production package: --production is for one',
    );
  }
  if (alone) {
    final production = manifest.productions.single;
    // readWorldPackage accepts only the document versions this Player understands. Dedicated keys
    // let older readers ignore unsupported stories/comics without fetching a generic package.
    return {
      'production': {
        'id': production.id,
        if (manifest.comics.containsKey(production.id))
          'comic': {...pin, 'version': comicVersion}
        else if (manifest.stories.containsKey(production.id))
          'story': {...pin, 'version': storyVersion}
        else ...{
          'package': pin,
          if (manifest.music[production.id] case final music?) 'music': music.kind.name,
        },
      },
    };
  }
  final part = manifest.part;
  if (part == null) {
    if (follows != null) {
      throw const PinRefused(64, 'not a part: --follows is for a part');
    }
    return pin;
  }
  if (follows == null) {
    throw const PinRefused(64, 'a part is pinned with --follows <the fingerprint of the edition in its list entry>');
  }
  if (part.fingerprint != follows) {
    throw PinRefused(65, 'this part follows another edition (${part.follows}), not the one given');
  }
  final production = manifest.productions.single;
  final document = manifest.listening[production.id];
  // The day it is released: its edition label's date, which the Studio writes.
  final released = parseDay(manifest.edition.length >= 10 ? manifest.edition.substring(0, 10) : manifest.edition);
  if (released == null) {
    throw PinRefused(65, 'the part is labelled ${manifest.edition}, which names no day');
  }
  return {
    'part': {
      ...pin,
      'released': dayText(released),
      'production': production.id,
      'chapters': [
        for (final chapter in document?.chapters ?? const <ListeningChapter>[]) {'id': chapter.id, 'number': chapter.order, 'title': chapter.title},
      ],
    },
    'production': {'id': production.id, if (part.schedule != null) 'schedule': part.schedule!.toJson()},
  };
}

class PinRefused implements Exception {
  const PinRefused(this.exitCode, this.reason);
  final int exitCode;
  final String reason;
}
