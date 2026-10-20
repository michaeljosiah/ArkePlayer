# MVP goal

**On an Android phone or a Fold7, with no account and no network, a person adds their own audiobooks and music, books and films from the phone and plays each one — and picks up where they left off.**

Set 20 October 2026. The full design is the Arke Player design master (`design/Arke Player.dc.html`, P1–P7, with P8 for the MVP's states). The MVP is the part of it that needs no Arke account and no Arke package.

## In

| | Formats | Player | Design |
|---|---|---|---|
| **Listen** | M4B, M4A, MP3 | The audio player: cover, transport, chapters, speed, sleep, lock screen | P7d, P5a, P5b, P5c |
| **Read** | EPUB | The reader: Aa, contents, the page in the chapter | P5e |
| **Read** | PDF | The page viewer: one column, pinch to zoom, outline | P7c |
| **Watch** | MP4, MOV, plus an SRT or VTT of the same name as captions | The film player, held upright and turned, with captions | P3a, P3b, P3e |

Around the players:

- **Getting files in.** Add a file: the system picker, several at once (P2c, P7a). Files also arrive through the system's Open in and Share to Arke Player.
- **Checks before adding.** The space is checked before copying. Each file is read before it is added. A file that can't be added is refused in one clause, and nothing is half-added (P7 rule 3).
- **Library.** Your files: covers, titles, kinds and sizes (P7b), with Remove.
- **Home.** Continue: what is in progress, last played first (P1b).
- **Downloads.** The space Arke Player takes and what is on the phone (P6a).
- **You.** Playback (Captions, Text, Autoplay next), Storage and About (P6b, without the account).
- **Places.** Every file keeps its place on this device: a time, a chapter, a page.
- **Layout.** Light and dark; a tab bar on a phone, a rail on the unfolded Fold7 or a tablet (P6e, P6f).

## Out, until after the MVP

| | Designed in |
|---|---|
| Sign-in, shares, share links, a share that ended, the account in You | P2a, P2b, P2g, P6b (account) |
| Arke worlds: packages, verification, a world's page, a production's page, the hosted Studio players (interactive, visual novel, Arke audiobooks), micro drama, audio drama | P1d–P1f, P2d–P2f, P3c, P3d, P4, P5d, ADR 0001 |
| Paste a link; CBZ comics; casting; adult content | P2c, P7, P3, P6c |
| An audiobook made of several MP3 files (each file is its own item for now) | P7 rule 2 |

`packages/arke_publication`'s manifest reader and verifier stay in the repository for the worlds that follow. The MVP uses only its format probe and DRM checks.

## What changes because of that

1. **Every MVP player is native**, not a hosted Studio module ([ADR 0004](decisions/0004-mvp-plays-files-natively.md)). There is no Arke package to host, and native engines give background audio, the lock screen and the headset directly. ADR 0001's spike moves to the worlds work.
2. **A few states the design never drew are needed first:** first open without Sign in, Home with nothing added, and Library holding files and no worlds. P1–P7 always drew worlds beside files. These go into a small design turn, **P8**, in the Player master before those screens are built, as CLAUDE.md asks. Until then, anything that needs an account or a world is absent, never shown disabled.

## Milestones

Each one ends in a build installed on the Fold7 and checked against its frames.

| | Milestone | Done when | State (20 October 2026) |
|---|---|---|---|
| M0 | **Groundwork.** P8 drawn and approved. The library index and places, in drift/SQLite. Settings saved. Geist and Jost vendored. A short spike for each engine (below), its pick recorded in ADR 0004. | The app opens on P8a and lists nothing (P8b), and each engine has played a file on the Pixel 9 Pro Fold emulator. The Fold7 itself is checked by the owner. | P8 drawn (design/, `#p8`). The index is a JSON file written atomically (`arke_library`), the simplest store that works; SQLite waits until a query needs it. Settings, fonts, engines (ADR 0004) and signing in. |
| M1 | **Add your files.** The Add sheet (Choose files), several at once, Open in and Share to; the space check, copy, probe and metadata; refusals; Library's files; Remove; Downloads' space. | Acceptance 1–3 and 8. | Built; the importer is tested over real ffmpeg-made files. |
| M2 | **Listen.** The audio player with chapters, speed and sleep. Background play, the lock screen and the headset. Its place, and Continue on Home. | Acceptance 4 and 7. | Built; device check owed. |
| M3 | **Read.** The EPUB reader and the PDF page viewer, each keeping its place. | Acceptance 5. | Built; device check owed. |
| M4 | **Watch.** The film player upright and turned, captions from a sidecar SRT or VTT, its place. | Acceptance 6. | Built; device check owed. |
| M5 | **Release candidate.** Fold and tablet layouts, light and dark, accessibility, large and low-space cases, You, and a signed release build on the chosen channel. | Acceptance 9 and 10, and every earlier item rechecked. | Fold rail and two columns, light and dark, and text at 200% are tested; low space is refused before copying; CI builds the release APK green. Owed: the upload-key-signed APK (needs local disk) and the device run. |

Listen comes first: it carries the most risk (background play and the lock screen) and the most use.

### Engines to confirm in M0

| Need | Candidate | Why |
|---|---|---|
| Audio, background, lock screen, headset | `just_audio` with `audio_service` | A media session and notification on Android, Now Playing on iOS. Speed with the pitch kept. |
| M4B chapters, audio tags and covers | A pure-Dart reader in `packages/` (MP4 `chpl` and the QuickTime chapter track, `ilst` atoms, ID3v2 `APIC`) | `just_audio` plays M4B but does not expose its chapter markers. The reader is testable with `dart test`. |
| Video | `video_player` | ExoPlayer and AVPlayer. It already parses SRT and WebVTT as closed captions. |
| EPUB | `flutter_epub_viewer` (epub.js) | Reflowable text, themes, font size, and CFI locations for a kept place. |
| PDF | `pdfrx` (PDFium) | Continuous scroll, zoom, the outline and page rendering, with a first-page thumbnail for Library. |
| Open in / Share to | `receive_sharing_intent` | A file handed over from Files, Drive or a download. |

## Acceptance: the MVP is done when

1. **No account, no network.** On a fresh install on the Fold7 and on one mid-range Android phone, in airplane mode, first open shows the wordmark and Add a file. No sign-in or share control appears anywhere.
2. **Every format adds.** M4B, M4A, MP3, EPUB, PDF, MP4, MOV, and a MOV with its SRT, each added through the picker (several at once) and through Share to Arke Player. Each shows in Library with the title, the author, length or pages, the cover or first page, and the size, all read from the file. Without a title the file's name is used.
3. **Refusals.** Each of these is refused in one clause, and nothing is added:
   - a DRM EPUB: `Protected file`
   - a MOBI: `Not a supported format`
   - a truncated MP4: `Can't open this file`
   - a file larger than the free space: `Needs 4.1 GB · 2.0 GB free`, refused before any copying
4. **Listen.**
   - An M4B lists its chapters.
   - It plays for 30 minutes with the screen locked.
   - The lock screen and a Bluetooth headset play, pause and skip.
   - Speed runs from 0.8× to 2× with the pitch kept.
   - Sleep at End of chapter stops at the chapter's end.
   - Reopening resumes within 2 seconds of where it stopped.
5. **Read.**
   - An EPUB reopens at its place; Aa size and Paper, Sepia or Night apply and are kept; Contents jumps.
   - A PDF scrolls, pinch-zooms, fits again on a double tap, shows its outline when it has one, and reopens at its page.
6. **Watch.** MP4 and MOV play letterboxed upright and full height turned; SRT and VTT captions show at S, M or L; reopening resumes; the chrome rests after 2.5 seconds while playing.
7. **Continue.** Home lists what is in progress, last played first, and a press resumes in the player.
8. **Remove.** Remove deletes the copy and its place. Downloads shows Arke Player's space against what is free.
9. **Layout and access.** A tab bar under 600 wide and a rail on the unfolded Fold7; light and dark. TalkBack names every press, and text at 200% clips no press.
10. **Shipped.** CI is green, and a signed release build is installed from the chosen channel.

## Decided

1. **Android first** (owner, 20 October 2026). The release target is Android: the Fold7 and phones. iOS keeps compiling in CI, and TestFlight comes after the MVP.
2. **A signed APK, installed by hand** (owner, 20 October 2026). The upload key lives outside the repository (`android/key.properties` and the keystore are gitignored). A Play Console track can follow.
3. **P8 drawn** ([design/Arke Player.dc.html#p8](../design/Arke%20Player.dc.html)): first open without Sign in, nothing added, Home and Library with files only, and You without an account. The build proceeds on it, as the owner asked, and the owner reviews it alongside the build.
