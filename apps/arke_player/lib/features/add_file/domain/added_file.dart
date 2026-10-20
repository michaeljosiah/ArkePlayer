import 'package:arke_publication/arke_publication.dart';

/// One picked file on the Add sheet (P7a): what was read from it, or why it was refused.
sealed class AddCandidate {
  const AddCandidate(this.name);

  /// The file's name as the system gave it.
  final String name;
}

/// Read and ready to add. [title] falls back to the file's name when the file carries none.
class Readable extends AddCandidate {
  const Readable(super.name, {required this.format, required this.title, required this.byteLength, this.author, this.pages, this.duration});

  final FileFormat format;
  final String title;
  final int byteLength;
  final String? author;
  final int? pages;
  final Duration? duration;
}

/// Refused in one clause and left out of the press's count (`Add 3`); never half-added.
class Refused extends AddCandidate {
  const Refused(super.name, this.refusal);

  final ProbeRefusal refusal;

  /// The clause the sheet shows.
  String get clause => switch (refusal) {
    ProbeRefusal.protectedFile => 'Protected file',
    ProbeRefusal.cannotOpen => 'Can’t open this file',
    ProbeRefusal.notSupported => 'Not a supported format',
  };
}

/// The press under the list: how many will be added.
String addLabel(Iterable<AddCandidate> candidates) => 'Add ${candidates.whereType<Readable>().length}';
