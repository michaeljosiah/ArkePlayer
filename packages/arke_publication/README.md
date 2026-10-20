# arke_publication

Pure Dart, no Flutter. It holds what the Player must get right before anything plays:

- `readManifest`: reads a `publication.json`. It mirrors `VideoPublicationManifestSchema` in ArkeStudio's `packages/contracts/src/publication.ts`, which is the authority.
- `verifyPublication` / `checkAsset`: every asset's length, then its SHA-256, with progress.
- `probeFile`: recognises EPUB, PDF, CBZ, M4B, M4A, MP3, MP4, MOV, SRT, VTT and Arke packages from their first bytes. `epubIsProtected` and `pdfIsProtected` refuse DRM.

```bash
dart test
```
