import 'dart:convert';
import 'dart:io';

import 'package:arke_world/arke_world.dart';
import 'package:crypto/crypto.dart';

/// Prints the catalogue pin for a world package where it is published (SPEC-058 R-30, R-36): its
/// address, length and SHA-256, and the edition and fingerprint an installed world is compared by
/// to see an update. Any package the Player reads will do, the Studio's Export → Arke Player or
/// `pack_world`'s.
///   `dart run arke_world:pin_world <package.zip> <https url>`
Future<void> main(List<String> args) async {
  if (args.length != 2) {
    stderr.writeln('usage: dart run arke_world:pin_world <package.zip> <https url>');
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
  stdout.writeln(
    const JsonEncoder.withIndent('  ').convert({
      'url': url.toString(),
      'byteLength': await zip.length(),
      'sha256': digest.toString(),
      'edition': manifest.edition,
      'fingerprint': editionFingerprint(manifest),
    }),
  );
}
