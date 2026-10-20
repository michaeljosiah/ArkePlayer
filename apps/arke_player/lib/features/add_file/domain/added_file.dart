import 'dart:io';

import 'package:arke_library/arke_library.dart';

/// A file a person picked, as the system handed it over: a name, a size, and its bytes. The
/// system's picker may hand over a document with no path on disk, so the bytes are read as a
/// stream and copied straight into the library — never through a second temporary copy.
class PickedFile {
  const PickedFile({required this.name, required this.size, required this.open});

  /// A file already on disk, e.g. one handed over by Share to Arke Player.
  factory PickedFile.path(String path, {String? name}) {
    final file = File(path);
    return PickedFile(name: name ?? file.uri.pathSegments.last, size: file.existsSync() ? file.lengthSync() : 0, open: file.openRead);
  }

  final String name;
  final int size;
  final Stream<List<int>> Function() open;
}

/// One picked file on the Add sheet (P7a): read and ready, or refused.
sealed class AddCandidate {
  const AddCandidate(this.name);

  /// The file's name as the system gave it.
  final String name;
}

/// Read and ready to add: its files are already copied into a reserved folder of the library, and
/// [item] is what was read from it. It joins the library only when Add is pressed.
class Readable extends AddCandidate {
  const Readable(super.name, this.item);

  final LibraryItem item;
}

/// Refused in one clause (P7 rule 3) and left out of the press's count; never half-added.
class Refused extends AddCandidate {
  const Refused(super.name, this.clause);

  final String clause;

  static const protectedFile = 'Protected file';
  static const cannotOpen = 'Can’t open this file';
  static const notSupported = 'Not a supported format';
  static const packageLater = 'Arke packages come in a later version';
  static const captionsAlone = 'Add it with its film';

  /// `Needs 4.1 GB · 2.0 GB free` (docs/mvp.md acceptance 3).
  static String needsSpace(int needed, int free) => 'Needs ${formatBytes(needed)} · ${formatBytes(free)} free';
}

/// The press under the list: how many will be added.
String addLabel(Iterable<AddCandidate> candidates) => 'Add ${candidates.whereType<Readable>().length}';
