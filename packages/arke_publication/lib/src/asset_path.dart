/// The manifest file every publication carries at its root.
const publicationManifestFile = 'publication.json';

final _segment = RegExp(r'^[A-Za-z0-9][A-Za-z0-9._-]{0,119}$');
final _windowsDevice = RegExp(r'^(con|prn|aux|nul|com[0-9]|lpt[0-9])(?:\.|$)', caseSensitive: false);

/// Whether [path] is a portable asset path inside a publication.
///
/// Mirrors `PublicationAssetPathSchema` in ArkeStudio's `packages/contracts/src/publication.ts`,
/// which is the authority. Package paths have a smaller vocabulary than world filenames so that
/// URL decoding, Unicode normalisation and Windows filename aliases can never change which file
/// an asset names — on a phone as much as on the desktop that wrote it.
bool isPortableAssetPath(String path) {
  if (path.isEmpty || path.length > 512) return false;
  final segments = path.split('/');
  for (final segment in segments) {
    if (!_segment.hasMatch(segment)) return false;
    if (segment.endsWith('.')) return false;
    if (_windowsDevice.hasMatch(segment)) return false;
  }
  return segments.first.toLowerCase() != publicationManifestFile;
}
