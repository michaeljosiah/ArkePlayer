import '../domain/added_file.dart';

/// Brings picked files into the Player's own storage. One implementation per platform pairing of
/// the system picker and the app's storage; the screens only see this.
///
/// The order is the design's (P2 rule 6, P7 rule 3): check free space first and refuse before
/// copying; copy into the Player's storage; then for an Arke package verify every asset against
/// its manifest, or for a standard file open it and read what it carries. Nothing is shown as
/// playable before that passes, and a refusal deletes the copy.
abstract interface class FileImporter {
  /// Reads each picked file and says what it is, without adding any.
  Future<List<AddCandidate>> read(List<Uri> picked, {void Function(int done, int total)? onProgress});

  /// Adds the readable ones to the library. Returns how many were added.
  Future<int> add(List<Readable> candidates);

  /// Abandons a read in progress and deletes its copies.
  Future<void> cancel();
}
