# 0002 · Nothing plays before it is checked

**Status:** accepted 20 October 2026, from P2 rule 6 and P7 rule 3.

## Decision

- **An Arke package** is checked before anything in it is shown as playable:
  1. Check the free space, and refuse before copying if there is not enough.
  2. Copy the file into the Player's own storage.
  3. Read each `publication.json` (`readManifest`).
  4. Check every asset's byte length, then its SHA-256 (`verifyPublication`). The check reports progress as the Checking sheet shows it: `212 of 418 files`.

  Any failure refuses the package in one clause and deletes the copy.
- **A standard file** has no manifest. The Player recognises it from its first bytes and name (`probeFile`), then opens it to read its title, author, cover, length or pages, and chapters. DRM is refused by name, as `Protected file` (`epubIsProtected`, `pdfIsProtected`, FairPlay's `M4P` brand). MOBI/AZW, DOCX and plain text are not opened.
- **Nothing is half-added.** The Add press counts only what was read (`Add 3`).

## Why

A package that fails its manifest may be damaged or altered. Playing part of it would show the viewer something its author did not publish. The manifest is a frozen edition's promise, and the Player is where it is kept. The Studio's own verifier (`packages/coordinator/src/publications/verify.ts`) holds the same line on the desktop.

## Consequences

- `arke_publication` mirrors the TypeScript contract (`packages/contracts/src/publication.ts`). The contract is the authority: a change there is a change here, in the same week.
- Only the `video` profile exists in the contract today. Every other profile (audiobook, story and drama editions, world packages) is refused as unsupported until its schema lands in SPEC-048. The viewer sees `Made with a newer Arke`.
- The DRM checks are heuristics, documented in `probe.dart`. A false negative only means a file that then fails to open is refused as `Can't open this file`. The probe never decrypts anything.
