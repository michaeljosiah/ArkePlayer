import 'dart:convert';
import 'dart:io';

import 'package:arke_world/arke_world.dart';

/// Prints the pin for a picture published beside Arke's list (SPEC-058 rev 10): its address, length
/// and SHA-256, to paste under a world's or a production's `pins` as `keyArt`, `picture` or `tall`.
/// Publish each picture under a new name and never replace one: a phone that kept it by its digest
/// would refuse other bytes at the same address.
///   `dart run arke_world:pin_picture <picture> <https url>`
Future<void> main(List<String> args) async {
  if (args.length != 2) {
    stderr.writeln('usage: dart run arke_world:pin_picture <picture> <https url>');
    exit(64);
  }
  try {
    final pin = await pinPicture(File(args[0]), Uri.parse(args[1]));
    stdout.writeln(const JsonEncoder.withIndent('  ').convert(pin));
  } on PictureRefused catch (refused) {
    stderr.writeln('not a picture the list can pin: ${refused.reason}');
    exit(65);
  } on FileSystemException catch (error) {
    stderr.writeln('cannot read ${args[0]}: ${error.message}');
    exit(66);
  }
}
