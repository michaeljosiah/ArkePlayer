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

## Engines (to confirm in M0)

| | Pick | Confirmed |
|---|---|---|
| Audio | `just_audio` + `audio_service` | — |
| Chapters, tags, covers | pure-Dart reader in `packages/` | — |
| Video and captions | `video_player` | — |
| EPUB | `flutter_epub_viewer` | — |
| PDF | `pdfrx` | — |
| Open in / Share to | `receive_sharing_intent` | — |

Fill in **Confirmed** with the date and the Fold7 result, or replace the pick and say why.
