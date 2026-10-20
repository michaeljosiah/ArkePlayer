# Design map

Every frame of the Arke Player design master (ArkeStudio `design-system/Arke Player.dc.html`), the route that shows it, and the file that will draw it. A screen is built when its frames match at the sizes drawn: 390 × 844 for a phone, 844 × 390 turned, 984 × 1092 for a Fold7 open.

| Frame | Screen | Route | File |
|---|---|---|---|
| P1a | First open | `/welcome` | `features/onboarding/presentation/first_open_screen.dart` |
| P1b | Home | `/` | `features/home/presentation/home_screen.dart` |
| P1c | Library | `/library` | `features/library/presentation/library_screen.dart` |
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

## Rules already in code

| Rule | Where | Test |
|---|---|---|
| P1 rule 3, P6 rule 5: tabs as a bar under 600, a rail over | `app/shell/adaptive_shell.dart` | `test/shell_test.dart` |
| P1 rule 6: Watch · Play · Listen · Read, empty groups absent | `features/production/domain/production_kind.dart` | `test/domain_test.dart` |
| P2 rule 6: every asset checked before play | `arke_publication` `verify.dart` | `verify_test.dart` |
| P2 rule 8: unknown profiles refused | `arke_publication` `manifest.dart` | `manifest_test.dart` |
| P6 rule 3: device settings and their defaults | `features/settings/domain/device_settings.dart` | `test/domain_test.dart` |
| P7 rules 1–3: formats, their players, DRM refused, `Add N` | `arke_publication` `probe.dart`, `features/players/domain/player_kind.dart`, `features/add_file/domain/added_file.dart` | `probe_test.dart`, `test/domain_test.dart` |
