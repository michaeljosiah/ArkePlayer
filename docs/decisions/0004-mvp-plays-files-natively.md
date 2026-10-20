# 0004 · The MVP plays standard files natively

**Status:** accepted 20 October 2026, with the MVP goal ([docs/mvp.md](../mvp.md)). The engine picks are confirmed in M0 and recorded here.

## Decision

The MVP plays only the person's own files: M4B, M4A, MP3, EPUB, PDF, MP4 and MOV. There is no Arke package and so no Studio `player.html` to host. Every MVP player is therefore native Flutter, drawn to match its frames:

| Player | Frames |
|---|---|
| Audio | P7d, P5a–P5c |
| Reader | P5e |
| Page viewer | P7c |
| Film | P3a, P3b, P3e |

ADR 0001 still holds for Arke worlds after the MVP. Their interactive, visual novel and audiobook productions are hosted Studio modules, and ADR 0001's spike runs when that work starts.

## Why

- Native audio (`just_audio` with `audio_service`) gives background play, the lock screen, the headset and the notification directly. That was the open risk in hosting a web module, and the MVP doesn't need to take it.
- The look is the design's either way. The frames bind sizes, order and words, not an implementation.

## Engines

Picked on 20 October 2026 and built into the app. **The release APK builds (CI `android` job, green from `f082fcb`); not yet played on a device** — the local disk was full, so neither a local Gradle build nor the Pixel 9 Pro Fold emulator could run; a device check on the owner's Fold7 is owed (docs/mvp.md, acceptance 4–6).

Two build fixes the engines needed: `receive_sharing_intent` is pinned to 1.8.1 (1.9.0 puts AGP 9 and Kotlin 2.4 on the classpath), and `kotlin.jvm.target.validation.mode=warning` lets 1.8.1's Java 1.8 and Kotlin 17 halves build.

| | Pick | Where |
|---|---|---|
| Audio, background, lock screen, headset | `just_audio` inside an `audio_service` handler; `audio_session` for focus | `features/players/application/audio_engine.dart`, `MainActivity` (an `AudioServiceActivity`) |
| Chapters, tags, covers | `packages/arke_media`, pure Dart: MP4 atoms (Nero `chpl` and the QuickTime chapter track), ID3v2 (`CHAP`, `APIC`), EPUB package documents | `packages/arke_media` |
| Video and captions | `video_player` with its own SRT and WebVTT parsers; `wakelock_plus` keeps the screen on while a film plays | `features/players/presentation/film_screen.dart` |
| EPUB | `flutter_epub_viewer` (epub.js): paginated, CFI places, page-in-chapter | `features/players/presentation/reader_screen.dart` |
| PDF | `pdfrx` (PDFium): the viewer, the outline, and the first page and page count at import; a password-protected PDF is refused | `features/players/presentation/pdf_screen.dart`, `features/add_file/application/pdfrx_peek.dart` |
| Picking and Share to / Open in | `file_picker` 13 (several files, streamed — it may hand over `content://` with no path); `receive_sharing_intent` | `features/add_file/presentation/add_flow.dart`, `app/app.dart` |
| Free space | a `StatFs` method channel in `MainActivity` | `app/services.dart` |

One deviation, recorded: the MVP's Captions setting is **On or Off** (with S, M, L), not a language. A sidecar SRT or VTT names no language, so there is nothing to choose between; P3 rule 5's per-language choice returns with publications' text tracks.
