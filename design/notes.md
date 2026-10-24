# Arke Player · design master notes

Drawn and approved by the owner on 20 October 2026 (P1–P6, then P7 on request). Asked: a new mobile application,
Arke Player, where people play productions from worlds shared in Arke and upload packaged Arke
worlds to play, reusing the player designs already in the Studio master, drawn as a new file in
the design-system folder.

`Arke Player.dc.html` is that file. It was drawn in ArkeStudio's `design-system/` beside
`Arke Studio.dc.html` and moved here, to `ArkePlayer/design/`, on 20 October 2026. It keeps the Studio
master's document chrome (frozen in `dv-chrome.css`) and has its own turns. Turns are
P1, P2… and frames P1a… so an issue or commit citing one never collides with a Studio turn number.

## The shape, in one paragraph

The Player plays **publications** — frozen editions with their own manifest (SPEC-048) — and never
a world's source. Things arrive two ways: a **share** through an Arke account, which streams until
downloaded, or a **file** added from the phone — an Arke package, checked file by file against
its manifest before it plays, or a standard file (EPUB, PDF, CBZ, M4B, M4A, MP3, MP4, MOV),
opened and read before it is added (P7). Four
tabs: Home (Continue, New, Worlds), Library (every world, Shared and Added), Downloads, You. A
world's page groups its productions by what a person does — Watch, Play, Listen, Read. A
production's page is Studio 199's show page on a phone. The players are the Studio's own modules
(156 interactive, 174 visual novel, 186/211/212 audiobook), so a package plays the same in a
browser and in the Player; the Player adds its close and the phone's media session around them.

## What is drawn

| Frame | Screen |
|---|---|
| P1a | First open: the wordmark over a world's picture, Sign in with Arke ↗, Add a file |
| P1b | Home: Continue, New, Worlds |
| P1c | Library: All · Shared · Added, a card per world, + |
| P1d | A world: the hero, its logline, Watch and Play; the dock playing an audiobook |
| P1e | A production: an audiobook with its book — Continue, Read, the download, Chapters |
| P1f | A production: a micro drama — Continue · Episode 13, Episodes as 9:16 thumbnails |
| P2a | A share link opened while signed out |
| P2b | Waiting for the browser |
| P2c | Add: Choose files, Paste a link, and the formats it takes as one data line |
| P2d | Checking a package: 212 of 418 files |
| P2e | A package, ready: what is inside, the space, Add to library |
| P2f | A package, refused: 3 files do not match |
| P2g | A share that ended: No longer shared, Remove |
| P3a | A film held upright |
| P3b | A film turned (844 × 390) |
| P3c | A micro drama as a feed |
| P3d | Episodes: numbered tiles, 1–20 · 21–40 |
| P3e | Captions: the publication's text tracks, Size |
| P4a | An interactive movie: the choice (156i in the Player) |
| P4b | The route |
| P4c | An ending |
| P4d | A visual novel: a line (174g in the Player) |
| P4e | The log |
| P5a | An audiobook: picture, Slow push, two-line Text, the transport |
| P5b | Chapters |
| P5c | Speed and sleep |
| P5d | An audio drama with its transcript |
| P5e | A book, with Listen |
| P6a | Downloads |
| P6b | You |
| P6c | Adult content, off |
| P6d | Offline |
| P6e | Home on a Fold7 (984 × 1092), the tabs as a rail |
| P6f | An audiobook on a Fold7 |
| P7a | Adding files: three read, one refused as Protected file, Add 3 |
| P7b | Library · Added: an added world, then Files |
| P7c | A PDF in the page viewer |
| P7d | An audiobook file (M4B): its cover, its chapter markers |
| P8a | First open, before sign-in: Add a file only |
| P8b | Home, nothing added |
| P8c | Library, files only: kind chips, rows |
| P8d | Home with files: Continue, Added |
| P8e | Library on a Fold, files only, two columns |
| P8f | You, before sign-in |
| P9a | First open, with Install a world |
| P9b | Available: a world card with its count and size |
| P9c | A world before it is installed: Install · 386 MB, Inside, Space |
| P9d | Installing: Downloading · 162 MB of 386 MB, Cancel |
| P9e | Not installed: No connection |
| P9f | The Undersong installed: one production at the full width |
| P9g | Home, ending with Available |
| P9h | A world to install, on a Fold |
| P10a | A package of a world already in Library, another edition: In Library, Space, Replace |
| P10b | The same edition: Already in Library, Open |

## Added after the first review (P7)

The owner, on seeing P1–P6: support uploading the formats the industry already uses, such as PDF
and EPUB. P7 draws it. Standard files are not worlds: they sit under Library's Added as Files,
open straight into the players already drawn (EPUB in P5e's reader, audio in the audiobook
player, video in the film player) and a new page viewer for PDF and CBZ. DRM-protected files are
refused by name (`Protected file`); MOBI/AZW, DOCX and plain text are not opened. P1a and P2c
were relabelled in place — `Add a package` became `Add a file`, and the sheet takes several files
and lists the formats as one data line — since nothing was merged yet.

## Worlds to install (P9)

The owner, on 20 October 2026: let the Player show worlds that can be installed; one demo world
exists. Approved as drawn the same day. P9 draws it with no account, beside P8's states: a second press on first open
(`Install a world`), an `Available` page and a section at the end of Home, a world's page with
`Install` and what is inside, the download and check in place of the press, refusals in one
clause, and the installed world, whose one production is shown at the full width.

The demo is The Undersong: The Ledger of Nights, 16 chapters with narration for 12 (3 h 49 m),
from the Studio's own EPUB and M4B, packed as `the-undersong-player-2026-10-20.zip` (182 MB) and
published on ArkeStudio release `undersong-2026-10-19-r3` beside the Studio's Sample world. That
1.6 GB download is the editable world, a world's source, and the Player never opens one. The
frames' size (386 MB) and file count are samples.

## A world's newer edition (P12)

The owner, on 22 October 2026: if an audiobook is updated in the Studio, does the Player see it and
offer the download? Only from a file (P10). A world installed from Arke's list never shows a newer
edition: the list ships with the app, names no edition, and leaves Available once a world is
installed. P12 draws the answer, approved as drawn the same day with calls 8 and 9: Arke's list fetched as well as shipped, each entry
naming its edition; `Update` on the world's card and page; the download and check in place of the
press, the installed edition playing until the new one is checked; and P10's Replace underneath,
places kept by chapter. Updates are pressed, never automatic.

## A picture made for the screen (P14)

The owner, on 23 October 2026: on a phone the listen screen letterboxes a wide picture into the top
62% (P5a), and the picture should fill the screen. The owner chose pictures made in more than one
shape over cropping one: the Studio makes a moment's picture Wide (16:9) and Tall (9:16), the Tall
from the Wide (Studio 235), and the package carries both. P14 draws the phone in portrait with a
Tall picture over the whole screen, Text off and on; everything else shows the Wide picture as
before, and a package without Tall pictures plays as today. The Tall sample in the frames is
real: The Undersong's p004, Maren at the ledger, made at 9:16 with its 16:9 picture as the
reference (`assets/maren-ledger-tall.jpg`). Approved as drawn by the owner on 23 October 2026, with
Studio 235; SPEC-058 is amended for the package next.

## Discover and chapters released over time (P15)

The owner, on 24 October 2026: should Worlds become Discover, showing worlds, their productions and
other things made for them; and a world may release its story a chapter at a time to bring its
audience back, so how is that shown? Also asked: a world's page with several kinds of production, a
micro drama among them. The owner approved five recommendations the same day, and P15 draws them:

- Discover is what you can get, and Library is what you have.
- Discover leads with productions and new chapters.
- Teasers are the author's choice.
- A new chapter comes on its own over Wi-Fi.
- Notifications are the phone's own, per world.

The real cost of a serial was delivery: a 20 MB chapter meant re-downloading a 360 MB package. So a
world becomes a base plus one part per release, each pinned as a package is. The author's half is
Studio 236: releasing a chapter as a part, and choosing teasers.

Legend of Dumah, The Red Quiet and Embers of the Fallen are Arke's worlds on Available, their
pictures recompressed from the app's own list (`apps/arke_player/assets/worlds`). The Undersong's
six productions are P1's sample. Chapter dates, schedules and episode counts are samples.

## Calls for the owner

1. **When a share ends, its downloads go too.** Drawn so (P2g). The alternative — keeping
   downloaded copies — contradicts the owner having stopped sharing; a package added from a file
   is the person's and is never removed.
2. **The Player runs the Studio's web player modules inside a native shell.** Drawn so (P3). It
   keeps 156's one-player rule — what is previewed is what is played — at the price of a web view
   inside the app; the shell supplies the lock screen, background audio, picture in picture and
   casting.
3. **A world package is the file people add**: a ZIP of a world's name, logline and key art and
   its publications, each with its own `publication.json`. Its extension (the frames say
   `.arke`) and schema are owed to SPEC-048 before it is built.
4. **The Studio's Share sheet** — who a world is shared with, and which productions — is a turn of
   its own in the Studio master.
5. **The worlds to install ship with the app.** Drawn so (P9), approved with it. Each is pinned by its package's
   address and SHA-256, as the Studio pins its Sample world, so the list shows offline and needs
   no Arke cloud; a catalogue served by the cloud can replace it.
6. **The Undersong is published as a world package** (182 MB, ADR 0005). Its format is owed to
   SPEC-048.
7. **Whether P9 joins the MVP.** The MVP left world import out; P9 needs no account.
8. **Arke's list of worlds is fetched as well as shipped** (P12, approved): from one Arke
   address over HTTPS, at most once a day, the list in the app as the floor, so a newer edition
   shows without an app update. Each entry stays pinned by length and SHA-256.
9. **An update downloads only when pressed** (P12, approved). A world is the person's, and a
   new edition can change what they are partway through; `Wi-Fi only` applies to it.
10. **A moment's picture comes Wide and Tall** (P14, approved). The Tall is made in the Studio
   from the Wide; a phone in portrait shows it over the whole screen, a tablet, a Fold and a phone
   turned show the Wide. No setting in the Player: the shape follows the screen.
11. **Worlds becomes Discover** (P15, asked 24 October 2026). Discover is what Arke offers, and
   Library is what is on the phone. Discover leads with productions and new chapters, and its
   teasers are the author's choice.
12. **A world comes as a base and a part per release** (P15). A new part comes on its own over
   Wi-Fi, because a part only adds. A new edition still waits for Update (call 9 holds for
   editions).
13. **A new chapter is notified by the phone itself** (P15). Notifications are per world, off
   until turned on, and come from the daily check of Arke's list, so they need no account and no
   server.

## What this rests on

- Publications, `publication.json` and the verify-before-play rule: `packages/contracts/src/publication.ts`,
  `packages/coordinator/src/publications/`.
- The account and its browser handoff: Studio turn 151 and `AccountService` (`NoArkeCloud` today:
  `Arke cloud is not available yet`). Shares and streaming need the Arke cloud, which does not
  exist yet; the first build can ship packages, the players and downloads.
- The players: Studio 156 (interactive), 174 (visual novel), 186 (audiobook), 211 (Slow push),
  212 (two-line Text), 199 (show page), 224 (story editions), 230 (audio drama transcripts),
  154 (adult content), 149 (row grammar), 137 (no captions under controls).

## The pictures

Every picture is already in `design-system/assets`; nothing was generated. The sample is The
Undersong (shared by Helen Marsh, 151's sample identity, with Jonah Pike), Copper Saints (shared by
Ama Mensah) and Meridian Dust (added from a file).

## To regenerate

    node design/build.mjs          # writes Arke Player.dc.html and review.html
    node design/check.mjs          # the gate CI runs; --record after adding a turn, --render to prove Geist

`build.mjs` checks every frame before writing: balanced `<div>` and `<span>`, type through the tokens
only, every picture present, unique ids, every anchor resolving. `check.mjs` checks the written master,
with `turns.json` as its ledger so no turn or rule can drop out unnoticed. Studio turns are linked into a
sibling ArkeStudio checkout (`../../ArkeStudio/design-system/Arke Studio.dc.html#tNNN`).
