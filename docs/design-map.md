# Design map

Every frame of the Arke Player design master (`design/Arke Player.dc.html`), the route that shows it, and the file that will draw it. A screen is built when its frames match at the sizes drawn: 390 × 844 for a phone, 844 × 390 turned, 984 × 1092 for a Fold7 open.

## The MVP (built)

| Frame | Screen | Route | File |
|---|---|---|---|
| P8a | First open, before sign-in | `/welcome` | `features/onboarding/presentation/first_open_screen.dart` |
| P8b, P8d | Home: nothing added; Continue and Added | `/` | `features/home/presentation/home_screen.dart` |
| P8c, P8e | Library, files only (two columns on a Fold) | `/library` | `features/library/presentation/library_screen.dart`, `item_menu.dart` |
| P7a | Adding files | (the picker, then a sheet) | `features/add_file/presentation/add_flow.dart`, `application/file_importer.dart` |
| P6a | Downloads, files only | `/downloads` | `features/downloads/presentation/downloads_screen.dart` |
| P8f | You, before sign-in | `/you` | `features/settings/presentation/you_screen.dart` |
| P7d, P5a–P5c | Audio player, chapters, speed and sleep | `/open/:itemId` | `features/players/presentation/audio_player_screen.dart` |
| P1 rule 8 | The dock | (over the tabs) | `features/players/presentation/dock.dart` |
| P5e | The reader (EPUB) | `/open/:itemId` | `features/players/presentation/reader_screen.dart` |
| P7c | The page viewer (PDF) | `/open/:itemId` | `features/players/presentation/pdf_screen.dart` |
| P3a, P3b, P3e | The film player | `/open/:itemId` | `features/players/presentation/film_screen.dart` |

## After the MVP (designed, not built)

| Frame | Screen | Route | File |
|---|---|---|---|
| P1a | First open, with Sign in | `/welcome` | `features/onboarding/` |
| P1b | Home with shares and worlds | `/` | `features/home/` |
| P1c | Library with worlds | `/library` | `features/library/` |
| P1d | A world, with the dock | `/library/world/:worldId` | `features/world/presentation/world_screen.dart` |
| P1e | A production: audiobook and book | `/library/world/:w/production/:p` | `features/production/presentation/production_screen.dart` |
| P1f | A production: micro drama | `/library/world/:w/production/:p` | `features/production/presentation/production_screen.dart` |
| P2a, P2b | A share link; waiting for the browser | `/share/:token` | `features/sharing/presentation/share_link_screen.dart` |
| P2c | Add | `/add` | `features/add_file/presentation/add_screen.dart` |
| P2d | Checking a package | `/add` | `features/add_file/presentation/add_screen.dart` |
| P2e | A package, ready | `/add` | `features/add_file/presentation/add_screen.dart` |
| P2f | A package, refused | `/add` | `features/add_file/presentation/add_screen.dart` |
| P2g | A share that ended | `/library` | `features/library/presentation/library_screen.dart` |
| P3a, P3b | A film, upright and turned | `/play/:productionId` | `features/players/` (hosted module) |
| P3c, P3d | A micro drama; episodes | `/play/:productionId` | `features/players/` (native feed) |
| P3e | Captions | `/play/:productionId` | `features/players/` |
| P4a–P4c | Interactive: choice, route, ending | `/play/:productionId` | `features/players/` (hosted module) |
| P4d, P4e | Visual novel: a line, the log | `/play/:productionId` | `features/players/` (hosted module) |
| P5a–P5c | Audiobook, chapters, speed and sleep | `/play/:productionId` | `features/players/` (hosted module) |
| P5d | Audio drama with its transcript | `/play/:productionId` | `features/players/` (native) |
| P5e | A book | `/open/:fileId` or `/play/:productionId` | `features/players/` (native reader) |
| P6a | Downloads | `/downloads` | `features/downloads/presentation/downloads_screen.dart` |
| P6b | You | `/you` | `features/settings/presentation/you_screen.dart` |
| P6c | Adult content | `/library/world/:worldId` | `features/world/` with `features/settings/` |
| P6d | Offline | `/` | `features/home/presentation/home_screen.dart` |
| P6e | Home on a Fold | `/` | `app/shell/adaptive_shell.dart` and Home |
| P6f | An audiobook on a Fold | `/play/:productionId` | `features/players/` |
| P7a | Adding files | `/add` | `features/add_file/presentation/add_screen.dart` |
| P7b | Library · Added, with files | `/library` | `features/library/presentation/library_screen.dart` |
| P7c | A PDF | `/open/:fileId` | `features/players/` (native page viewer) |
| P7d | An audiobook file | `/open/:fileId` | `features/players/` (hosted audiobook module) |

## Worlds to install (P9, approved, not built)

World import was left out of the MVP; whether P9 joins it is the owner's call. It needs a published world package (SPEC-048) before any of it is built.

| Frame | Screen | Route | File |
|---|---|---|---|
| P9a | First open, with Install a world | `/welcome` | `features/onboarding/presentation/first_open_screen.dart` |
| P9b | Available | `/available` | `features/available/presentation/available_screen.dart` |
| P9c–P9e, P9h | A world before it is installed, installing, refused; on a Fold | `/available/:worldId` | `features/available/presentation/install_screen.dart` |
| P9f | The Undersong, installed: one production at the full width | `/library/world/:worldId` | `features/world/presentation/world_screen.dart` |
| P9g | Home, ending with Available | `/` | `features/home/presentation/home_screen.dart` |

## Rules already in code

| Rule | Where | Test |
|---|---|---|
| P1 rule 3, P6 rule 5: tabs as a bar under 600, a rail over | `app/shell/adaptive_shell.dart` | `test/shell_test.dart` |
| P1 rule 6: Watch · Play · Listen · Read, empty groups absent | `features/production/domain/production_kind.dart` | `test/domain_test.dart` |
| P2 rule 6: every asset checked before play | `arke_publication` `verify.dart` | `verify_test.dart` |
| P2 rule 8: unknown profiles refused | `arke_publication` `manifest.dart` | `manifest_test.dart` |
| P6 rule 3: device settings and their defaults | `features/settings/domain/device_settings.dart` | `test/domain_test.dart` |
| P7 rules 1–3: formats, their players, DRM refused, `Add N` | `arke_publication` `probe.dart`, `features/players/domain/player_kind.dart`, `features/add_file/domain/added_file.dart` | `probe_test.dart`, `test/domain_test.dart` |
