import 'dart:convert';
import 'dart:io';

import 'package:arke_world/arke_world.dart';

/// Packs a world for Available (Arke Player P9) and prints the catalogue entry that pins it.
///
///     dart run arke_world:pack_world <spec.json> <out.zip> [<url>]
///
/// The spec names the world and, per production, its book (EPUB), narration (M4B, M4A or MP3)
/// and picture; relative paths are relative to the spec. `<url>` is where the package will be
/// published, over HTTPS. Copy the key art and pictures to the paths the entry names under
/// `apps/arke_player/`.
Future<void> main(List<String> args) async {
  if (args.length < 2) {
    stderr.writeln('usage: dart run arke_world:pack_world <spec.json> <out.zip> [<url>]');
    exitCode = 64;
    return;
  }
  final specFile = File(args[0]);
  final spec = WorldSpec.fromJson(jsonDecode(await specFile.readAsString()) as Map<String, Object?>, base: specFile.parent.path);
  final packed = await packWorld(spec, args[1], url: args.length > 2 ? args[2] : 'https://');
  stdout.writeln(const JsonEncoder.withIndent('  ').convert(packed.catalogueEntry));
}
