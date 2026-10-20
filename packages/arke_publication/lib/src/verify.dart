import 'package:crypto/crypto.dart';

import 'manifest.dart';

/// How one asset compared with its manifest entry.
enum AssetCheck { matches, missing, wrongLength, wrongDigest }

/// Checks one asset's bytes against what the manifest says: its length first, which is cheap,
/// then its SHA-256. Nothing in a package plays before every asset matches (Arke Player P2 rule 6).
///
/// [open] returns the file's bytes as a stream, or null when the file is absent.
Future<AssetCheck> checkAsset(PublicationAsset asset, Stream<List<int>>? Function() open) async {
  final stream = open();
  if (stream == null) return AssetCheck.missing;
  var length = 0;
  final digest = await sha256
      .bind(
        stream.map((chunk) {
          length += chunk.length;
          return chunk;
        }),
      )
      .first;
  if (length != asset.byteLength) return AssetCheck.wrongLength;
  return digest.toString() == asset.sha256 ? AssetCheck.matches : AssetCheck.wrongDigest;
}

/// The outcome of checking a whole publication: which assets did not match, by key.
class VerifyReport {
  const VerifyReport(this.checked, this.failed);

  final int checked;
  final Map<String, AssetCheck> failed;

  bool get passes => failed.isEmpty;
}

/// Checks every asset of [manifest] in turn, reporting progress as `checked of total` — the
/// numbers the Checking sheet shows (P2d). It stops early when [cancelled] says so, and a
/// cancelled check never passes.
Future<VerifyReport> verifyPublication(
  PublicationManifest manifest,
  Stream<List<int>>? Function(String href) open, {
  void Function(int checked, int total)? onProgress,
  bool Function()? cancelled,
}) async {
  final failed = <String, AssetCheck>{};
  var checked = 0;
  final total = manifest.assets.length;
  for (final MapEntry(key: key, value: asset) in manifest.assets.entries) {
    if (cancelled?.call() ?? false) {
      failed['(cancelled)'] = AssetCheck.missing;
      break;
    }
    final result = await checkAsset(asset, () => open(asset.href));
    if (result != AssetCheck.matches) failed[key] = result;
    checked++;
    onProgress?.call(checked, total);
  }
  return VerifyReport(checked, Map.unmodifiable(failed));
}
