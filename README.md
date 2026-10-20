# Arke Player

A phone and tablet app for what is made in [Arke Studio](https://github.com/michaeljosiah/ArkeStudio): worlds shared through an Arke account, plus Arke packages and standard files (EPUB, PDF, CBZ, M4B, M4A, MP3, MP4, MOV) added from the phone — watched, heard, read and played.

**The current goal is the MVP** ([docs/mvp.md](docs/mvp.md)): your own audiobooks and music, books and films, with no account and no network, on Android first. Arke worlds and sign-in come after it.

The app is designed, not built. The approved design is the Arke Player design master in the ArkeStudio repository: `design-system/Arke Player.dc.html`, turns P1–P7, merged in ArkeStudio PR #1998 on 20 October 2026. Cite a frame by its id (`P3c`) and a rule by turn and number (`P2 rule 6`). [docs/design-map.md](docs/design-map.md) maps every frame to the route and file that will draw it.

## Layout

```
ArkePlayer/
  pubspec.yaml                 Dart pub workspace: one `flutter pub get` resolves everything
  apps/arke_player/            the Flutter app (Android and iOS; phones, tablets, the Fold7)
    lib/app/                   router, theme tokens, the adaptive shell (tab bar under 600, rail over)
    lib/features/<area>/       domain · application · presentation, one folder per area of the design
  packages/arke_publication/   pure Dart, no Flutter: publication.json, verify-before-play, format probing
  docs/                        architecture, the design map, decisions
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

- **Built:** the workspace, the app shell and routes (every screen a placeholder that names its frames), the theme tokens, and the domain rules: production groups, which player opens what, device-setting defaults, Add's count. `arke_publication` is built too: manifest reader, asset verifier, format and DRM probe.
- **Not built:** every screen's real UI, the importer, storage, downloads and the players.
- **Waiting on others:** the Arke cloud (accounts, shares, streaming), which does not exist yet; `NoArkeCloud` answers as the Studio's seam does. The world package format is owed to SPEC-048 in the ArkeStudio specs.
- **Undecided:** a licence. See [ADR 0001](docs/decisions/0001-host-the-studio-players.md) before choosing one.
