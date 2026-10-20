# Arke Player

A phone and tablet app for what is made in [Arke Studio](https://github.com/michaeljosiah/ArkeStudio): worlds shared through an Arke account, plus Arke packages and standard files (EPUB, PDF, CBZ, M4B, M4A, MP3, MP4, MOV) added from the phone — watched, heard, read and played.

**The current goal is the MVP** ([docs/mvp.md](docs/mvp.md)): your own audiobooks and music, books and films, with no account and no network, on Android first. Arke worlds and sign-in come after it.

The design is in this repository: [design/Arke Player.dc.html](design/Arke%20Player.dc.html), turns P1–P7 approved on 20 October 2026 (first merged in ArkeStudio PR #1998, moved here the same day), P8 for the MVP, and P9, worlds to install, approved the same day. Open [design/review.html](design/review.html) for every frame without the dc runtime. Cite a frame by its id (`P3c`) and a rule by turn and number (`P2 rule 6`). [docs/design-map.md](docs/design-map.md) maps every frame to the route and file that will draw it.

## Layout

```
ArkePlayer/
  pubspec.yaml                 Dart pub workspace: one `flutter pub get` resolves everything
  apps/arke_player/            the Flutter app (Android and iOS; phones, tablets, the Fold7)
    lib/app/                   router, theme tokens, the adaptive shell (tab bar under 600, rail over)
    lib/features/<area>/       domain · application · presentation, one folder per area of the design
  packages/arke_publication/   pure Dart, no Flutter: publication.json, verify-before-play, format probing
  packages/arke_library/       the library on the device: items, places, installed worlds
  packages/arke_media/         tags, chapters and covers read from the files themselves
  packages/arke_world/         worlds to install: the catalogue, world packages, download and check
  design/                      the design master, its generator, frames, tokens and check
  docs/                        architecture, the design map, the MVP goal, decisions
  .github/workflows/ci.yml     format, analyze, test
```

| Area | Design | What it holds |
|---|---|---|
| `onboarding` | P1a | First open |
| `home` | P1b, P6d | Continue, New, Worlds; offline |
| `library` | P1c, P2g, P7b | Worlds, Shared and Added, Files |
| `world` | P1d, P6c | A world's page, grouped Watch · Play · Listen · Read |
| `production` | P1e, P1f | A production's show page |
| `sharing` | P2a, P2b | The Arke account and share links, behind the `ArkeCloud` seam |
| `add_file` | P2c–P2f, P7a | Add a file: read, checked, ready or refused |
| `players` | P3–P5, P7c–P7d | The hosted Studio players and the native ones |
| `downloads` | P6a | What is on the phone |
| `settings` | P6b, P6c | You: every setting is this device's |

## Getting started

You need Flutter 3.41 (Dart 3.11). On this machine one ships inside the `aonik` repository, at `aonik/.tools/flutter/bin`.

```bash
flutter pub get
dart analyze --fatal-infos
dart format --output=none --set-exit-if-changed .
(cd packages/arke_publication && dart test)
(cd apps/arke_player && flutter test)
(cd apps/arke_player && flutter run)
```

## State

- **Built (the MVP, M0–M4):** add your own audio, books and films (several at once, or through Share to / Open in), each read before it is added and refused in one clause if it can't be; Home, Library, Downloads and You as P8 draws them; the audio player with chapters, speed, sleep, the lock screen and the dock; the EPUB reader; the PDF page viewer; the film player with captions. Places are kept on the device. Worlds to install (P9): Available on first open and Home, Install with the download and check, the installed world and its production page. Packages: `arke_publication` (manifests, verification, format and DRM probe), `arke_library` (the library index), `arke_media` (tags, chapters, covers), `arke_world` (the catalogue, world packages, the installer and packer).
- **Builds:** CI's `android` job builds the release APK on every push (`studio.arke.player` 0.1.0) and keeps it 14 days: `arke-player-apk-arm64` (28 MiB, for the Fold7 and current phones) and `arke-player-apk` (79 MB, with arm64, armv7 and x86_64). Both are signed with one throwaway CI test key held in the repository's secrets (certificate SHA-256 `C1:61:B1:45:…`), so each CI build installs over the last and keeps the library. It is not the upload key: the upload-key-signed APK is built locally (`flutter build apk --release` with `android/key.properties`), and won't install over a CI build without an uninstall.
- **Icon:** the Studio's Arke icon, copied to `apps/arke_player/assets/icon/arke-512.png`. `apps/arke_player/tool/make_icon.py` (Pillow) makes every launcher, notification and iOS size from it; Android's is adaptive, the mark on the tile's black.
- **Not yet checked on a device:** the players and the share intake are compiled and unit-tested; the shelves are rendered and compared with P8 (`test/shoot_test.dart`). A run on the Fold7 is owed.
- **Not published yet:** The Undersong's world package, so Available is absent in builds until it is pinned ([docs/world-package.md](docs/world-package.md)).
- **Not built:** Arke packages added from a file, sign-in and shares — after the MVP.
- **Waiting on others:** the Arke cloud (accounts, shares, streaming), which does not exist yet; `NoArkeCloud` answers as the Studio's seam does. The world package format is owed to SPEC-048 in the ArkeStudio specs.
- **Undecided:** a licence. See [ADR 0001](docs/decisions/0001-host-the-studio-players.md) before choosing one.
