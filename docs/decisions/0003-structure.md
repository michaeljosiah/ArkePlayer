# 0003 · One workspace, features first, Riverpod and go_router

**Status:** accepted 20 October 2026.

## Decision

- **A Dart pub workspace** (root `pubspec.yaml`, members with `resolution: workspace`). It holds the app in `apps/arke_player` and pure-Dart packages in `packages/`. There is one lockfile, so `flutter pub get` at the root resolves every member. A second app (a TV app, a web build) or a second package is one more line under `workspace:`.
- **Feature-first app**: `lib/features/<area>/{domain,application,presentation}`, plus `lib/app/` for the router, theme and shell. This matches the owner's other Flutter app (`aonik/apps/payabo_mobile`), so the conventions carry between the two.
- **Riverpod 3** for state and dependency injection: `ArkeCloud`, `FileImporter` and stores are providers, overridden in tests.
- **go_router** with a stateful shell for the four tabs. Each tab keeps its own stack. Players, Add and share links are routes over the shell. Every path is built in `lib/app/router/routes.dart`.
- **Strict analysis**: `strict-casts`, `strict-inference` and `strict-raw-types`, with the house lint rules and a 160-column format. CI fails on any info.
- **Android and iOS** platforms only. Bundle and application id `studio.arke.player`, beside the desktop app's `studio.arke.app`.

## Not yet chosen, decided by the slice that needs it

- The EPUB reader, the PDF and CBZ viewer, and the native video and audio engines. Candidates to evaluate against the frames: an EPUB renderer that honours the reader's Aa (P5e); `pdfrx` for PDF; `media_kit` or `video_player`; `just_audio` with `audio_service`.
- The local store for the library index and places. Settings use `shared_preferences`; the index needs something queryable.
- The fonts. The design sets Geist Sans and, for the wordmark, Jost. Both are OFL. Vendor their TTFs into `apps/arke_player/assets/fonts` and declare them in the app's pubspec. Until then the platform font draws everything.
