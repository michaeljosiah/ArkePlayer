# Architecture

The design is in [design/](../design/Arke%20Player.dc.html). Arke Player plays **publications**: frozen editions an author makes in Arke Studio, each with its own manifest (SPEC-048 in the ArkeStudio specs). It never sees a world's source, and nothing in it edits, generates or spends.

## Where things come from

| Arrives as | How | Checked by |
|---|---|---|
| A **share** | A link, through an Arke account (P2a). It streams from the Arke cloud until downloaded. | The cloud's own access, then the manifest on download |
| An **Arke package** | A file the person adds (P2c): a world package or one publication, as a ZIP | `verifyPublication`: every asset's length and SHA-256 against `publication.json` (P2 rule 6) |
| A **standard file** | EPUB, PDF, CBZ, M4B, M4A, MP3, MP4 or MOV (P7) | `probeFile`, plus opening it to read its title, cover, length and chapters; DRM is refused (P7 rule 3) |

All three end in one library on the phone:

- A share or a package becomes a **world**.
- A standard file becomes a **file** under Library → Added → Files.

## Layers

```
apps/arke_player
  lib/app/            router (go_router, a stateful shell for the four tabs), theme tokens, AdaptiveShell
  lib/features/<area>/
    domain/           the area's types and pure rules, e.g. ProductionKind → TakenAs, playerForFile
    application/      services behind interfaces: ArkeCloud, FileImporter; Riverpod providers
    presentation/     screens and widgets, one per design frame or group of frames
packages/arke_publication   (pure Dart)
  manifest.dart       readManifest — mirrors ArkeStudio's VideoPublicationManifestSchema
  verify.dart         checkAsset / verifyPublication — length first, then SHA-256, with progress
  probe.dart          probeFile, epubIsProtected, pdfIsProtected — formats and DRM
  asset_path.dart     isPortableAssetPath — the contract's path vocabulary
packages/arke_library       (pure Dart) the library index: items, places, installed worlds, shelves
packages/arke_media         (pure Dart) tags, chapters and covers from MP4/M4B, MP3 and EPUB
packages/arke_world         (pure Dart) worlds to install (P9, ADR 0005)
  manifest.dart       readWorldManifest — world.json, read strictly
  catalogue.dart      readCatalogue, availableWorlds — the list that ships with the app
  package.dart        readWorldPackage, extractAsset — the ZIP checked before use
  install.dart        WorldInstaller — space, download, pin, check, one write to the library
  pack.dart           packWorld, and `dart run arke_world:pack_world`
```

Domain code does not import Flutter where it can avoid it. Rules that need no widget belong in a package and are tested with `dart test`.

## The players

| Player | Design | Implementation |
|---|---|---|
| Film | P3a, P3b (Studio 156's chrome) | Hosted Studio module |
| Micro drama | P3c, P3d | Native: a vertical feed is the phone's own idiom |
| Interactive movie | P18b – P18e, P18h; P4c's ending | Native since P18 call 22: `arke_world`'s evaluator, held to the Studio's by shared fixtures (SPEC-058 R-81) |
| Visual novel | P18f, P18g; P4d's box, P4e's log | Native, as the interactive movie |
| Audiobook, audio files | P5a–P5c, P7d (Studio 186, 211, 212) | Hosted Studio module |
| Audio drama | P5d | Native (the audiobook transport over a transcript) |
| Book (EPUB) | P5e | Native reader |
| PDF, CBZ | P7c | Native page viewer |

A hosted module is the same framework-free `player.html` a package carries. `WebPlayerHost` loads it from the Player's own storage. It talks to the app over the `ArkePlayer` JavaScript channel (events: `place`, `ended`, `close`) and restores a kept place through `window.arkePlayer.restore(place)`. That bridge does not exist in the Studio's modules yet; adding it is the first build task ([ADR 0001](decisions/0001-host-the-studio-players.md)). The app wraps the host in the phone's media session: lock screen, headset, background audio, picture in picture, casting.

## Layout bands

Under 600 wide is a phone: four tabs in a bar, sheets from the foot. From 600 to 1099 is a Fold7 open or a tablet, and from 1100 up is wide: the tabs become an 88-wide rail and the shelves widen (P6 rule 5). `AdaptiveShell` decides by window width, never by device type, so a Fold changes shell when it unfolds.

## Storage (to build)

- **App support directory:** added packages and files, each in its own folder, copied before they are checked, and deleted when refused or removed.
- **Downloads of shares:** the same, keyed by publication id. They are deleted when a share ends (P2 rule 4).
- **Device state:** places, settings, captions choice, Text, Slow push. It stays on the device (`shared_preferences` for settings; a small local store for places and the library index).

## The Arke cloud

Accounts, shares and streaming need the Arke cloud, which does not exist yet. `ArkeCloud` is the seam and `NoArkeCloud` its only implementation. It answers `Arke cloud is not available yet`, as the Studio's `AccountService` does. Packages, standard files, the players and downloads of what is on the phone need no cloud, so they ship first.
