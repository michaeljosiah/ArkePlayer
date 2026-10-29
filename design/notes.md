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

On first review the owner found the rows unkempt: each section had its own tile width, a character
teaser was a portrait card, and the micro drama was an upright tile beside the film. So every row
now takes one tile (rule 10), 16:9 and 240 wide on a phone, 300 on a Fold, which is the width of a
world's card in a row. A micro drama's upright episodes stay on its own page.
Approved by the owner on 24 October 2026, with the one tile and calls 11–13. Built the same day in ArkePlayer PR #11 (Studio half: ArkeStudio PR #2173); not built: a clip's moving loop in Discover's row, and the daily background check on iOS.

Legend of Dumah, The Red Quiet and Embers of the Fallen are Arke's worlds on Available, their
pictures recompressed from the app's own list (`apps/arke_player/assets/worlds`). The Undersong's
six productions are P1's sample. Chapter dates, schedules and episode counts are samples.

## Rows of different sizes (P16)

The owner, on 24 October 2026, with screenshots of Netflix's Home on a phone and a tablet: the
boxes of different sizes are great, with emphasis on some titles. That reads against P15's one
tile, but Netflix never mixes sizes inside a row. It changes the size from one row to the next,
and P15's first draw had mixed them inside a row. So P16 keeps each row to one size and one shape
and lets the page mix rows: a feature, posters, wide tiles, small posters and a world's band.

Netflix's posters are upright, and Arke's covers are all wide today. A poster therefore needs a
production's Tall cover, made in the Studio as a moment's Tall picture is (call 14). Until a
production has one, its poster shows the Wide cover whole over its own blur, because the owner
chose making shapes over cropping in P14. Characters gain the most: a portrait stays upright
instead of being cut to 16:9.

Na Love or Juju is Arke's world as published (list serial 16). Its poster is the book cover that
sits in the middle of its published wide cover, cut out at 480 × 720, and its characters are the
Studio's `nloj-*` portraits. The Ledger of Nights' Tall is P14's `maren-ledger-tall.jpg`. The Bell
Watch and The Red Quiet use pictures that are already upright. Every other poster shows the fallback.

Approved by the owner on 24 October 2026, with calls 14 and 15: "We need to support upright. It
seems to be an industry norm. But we can always mix and match." In the same message they asked to
see the pill, so P16h – P16j draw it. On a phone, the page runs under the pill to the foot. A
playing chapter's dock floats above the pill. On a Fold, the pill takes the rail's place, which
gives the page the full width. Seeing it, the owner chose the pill: "Pill is a better design."
Built the same day in ArkePlayer PR #14. Not built: a Tall cover in the package — the list's,
bundled with the app, is the one there is until the Studio's Publish makes one.

## Music (P17)

The owner, on 24 October 2026, asked how music would be shown within a world if it were
supported as a production, or just an artifact. They said "Yes" to the recommendations, and P17
draws them:

- Music is a production: Album, Single or Soundtrack. A song is never a loose take, because only a
  production has a cover, a size and a place in Arke's list.
- It has its own group after Listen, and a Discover row, under the `Listen` chip.
- Its tiles are square, as album art is everywhere, so its rows keep P16's one shape per row.
- It plays in the audio player, with the cover in place of the moment's picture.
- A track says where it is heard and whose theme it is, and a song can be a teaser.

Studio 238 draws the author's half.

The samples are The Undersong's: Songs of the Drowned Quarter (an album of 9 tracks), Saltmouth Bells
(a single), and The Bell Watch — Soundtrack. Their covers are nearly square pictures already in this
master. The track names, lengths and lyrics are samples, written for this turn.

The owner then asked whether a music production should have a Bench of its own and an editor of
its own. Studio 238 gained three frames: a track's composer and takes, a light track editor whose
sections can later time the Player's lyrics, and the album's sequence. The owner approved P17 and
Studio 238 as drawn on 24 October 2026 ("Approved."), with calls 17–20.

Built on 25 October 2026 in ArkePlayer PR #19 (SPEC-058 R-72 – R-78, slice 13). Not built: the ⋯
that P17c and P17d draw at the top of the album and the player, for which no rule names a use, and
a soundtrack's production on Discover before it is installed, because Arke's list does not say
what a soundtrack is for (`Soundtrack · The Undersong` until then).

## Interactive stories (P18)

The owner, on 28 October 2026, asked whether the interface for interactive stories had been
designed. P4 had, on 20 October, but it was never built. It predates the pill, the rows, the picture
shapes and the Studio's remembered choices (SPEC-063, Studio 240). It also cropped a 16:9
interactive movie to fill an upright phone, where P3a letterboxes a film. The owner said "Draw it",
and P18 brings P4 up to date:

- A story plays at the shape it was made in. Upright, a 16:9 movie sits whole with its choices
  under it; turned or on a Fold, two choices sit side by side; a 9:16 movie fills the phone.
- Choices are full width where the thumb is. Three or more are always one list, as in the Studio's
  player.
- A choice an earlier choice closed shows only when the author wrote a reason for it, dimmed and
  with a dash for its number. The facts a story remembers are never shown.
- `Choose again` takes back everything after that choice, what the story remembers included.
- A visual novel's beat uses its Tall picture upright when it has one, as an audiobook's moments do.

It also proposes how a story reaches a phone (calls 21 – 24): as its own production package with
one story document compiled from the Studio's routing, played natively with its rules held to the
Studio's by shared fixtures. The Studio exports stories only as a web folder today, and SPEC-063
leaves an Arke Player format out of scope.

The production P18 is for is The Red Quiet: First Contact (202 scene variants, 201 choices, five
families of ending). The samples stay The Undersong's: Low Water and The Lantern Road from P4, and
Ring Once, a 9:16 movie drawn on Odile's picture. Its scene names, choice labels and the reason are
samples, written for this turn.

The owner approved P18 as drawn on 28 October 2026 ("Approve"), with calls 21–24.

## A story plays itself (P19)

The owner, on 28 October 2026, after playing First Contact: "Whenever an option is provided to the
user it must be at least two as a minimum", and "The interactive story should play like a video,
going through the video with optional narration and only pausing when an option is displayed. There
should not be a need to tap to move forward." The design said the opposite, and the build followed
it: P4d's tap moved on, P18's `Auto` was a toggle off by default, and nothing kept a lone option off
the screen, so First Contact showed `1 Several weeks later` as its only button.

The owner approved P19 as drawn on 28 October 2026 ("Approve all"), with calls 25–27 and Studio turn 246. Its first five rules are shared with a Studio turn drawn the same day, so the
author's preview and the Player agree:

1. **A story plays itself.** A visual novel moves from beat to beat on its own: a voiced beat when
   its voice ends, an unvoiced beat after 1.5 s + 45 ms per character (the timing P18 shipped with
   `Auto`). An interactive movie already plays its clips. A story opens playing.
2. **No tap moves on.** A tap shows or hides the controls, as a film's do: Play/Pause, Back (the
   previous beat), Log, and Narration where the story has voices. `Auto` is gone.
3. **It stops only for a choice of two or more.** A closed choice shown with its reason counts as
   one of the two.
4. **A lone option is never shown.** When only one way on is open, the story plays straight through,
   with no pause and no label.
5. **Narration is optional.** On where a story carries voices; off, or without voices, each beat
   holds for its reading time. The control shows only when the story has voices.

The Player's own rules place the controls (P19b, P19c, P19g), keep the box still when they come and
go, give an interactive movie a film's transport (P19f), and leave a lone way out of the route
(P19h): it is still taken, with what it sets, so a route replays, but it has no row and no
`Choose again`.

The samples are P18's. The Lantern Road is voiced; The Red Quiet's First Contact is not (its package
holds 64 pictures and no audio), so it draws the story without Narration (P19d), its choice of two
(P19e, scene 5) and its route (P19h). Its lines, scene names and choice labels are the author's own.
In First Contact, scene 3's first line already reads "Several weeks later.", so playing through the
lone way loses nothing there. The shipped player waits 0.6 s after a voice ends before the next beat;
P19 keeps that as part of "when its voice ends".

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
11. **Worlds becomes Discover** (P15, asked and approved 24 October 2026). Discover is what Arke offers, and
   Library is what is on the phone. Discover leads with productions and new chapters, and its
   teasers are the author's choice.
12. **A world comes as a base and a part per release** (P15, approved). A new part comes on its own over
   Wi-Fi, because a part only adds. A new edition still waits for Update (call 9 holds for
   editions).
13. **A new chapter is notified by the phone itself** (P15, approved). Notifications are per world, off
   until turned on, and come from the daily check of Arke's list, so they need no account and no
   server.
14. **A production's cover comes Wide and Tall** (P16, approved). The Tall is made in the Studio
   from the Wide, as a moment's is (Studio 235). Posters and a phone's feature show the Tall, and a
   production without one shows the Wide whole over its blur. The Studio half needs a turn of its own.
15. **Discover's feature and band are named in Arke's list** (P16, approved), one line each. With
   neither named, the feature is the newest release and the band the newest world.
16. **The tabs as a pill** (P16h – P16j, chosen by the owner). Netflix floats its tabs as a pill
   over the page on both a phone and a tablet. The pill replaces P1's bar and P6e's rail.
17. **Music is a production** (P17, asked and approved 24 October 2026): Album, Single or
   Soundtrack, with its own group in a world, never a loose take.
18. **A music cover is square** (P17, approved), 1:1 at 1024 × 1024, the fourth picture shape.
19. **Lyrics are shown as written** (P17e, approved). They are not timed to the song; timing waits
   for the sections a track keeps in the Studio (238 call 8).
20. **A song keeps no place** (P17, approved). It starts from its beginning and never joins
   Continue, because a song is heard again rather than finished.
21. **A story is a production package** (P18, approved). An interactive movie or visual novel comes
   as its own package, holding one story document compiled from the Studio's routing with its clips
   or pictures. The Player says which versions of that document it reads, and Arke's list offers a
   story only to a Player that can read it.
22. **Stories play natively** (P18, approved), their rules written again in Dart and held to the
   Studio's by shared fixtures: every route of First Contact replays through both and must reach
   the same scenes and facts. This revises call 2 for stories. Hosting the Studio's web player is
   the alternative, with one engine but a web page's controls, offline files and lock screen.
23. **A closed choice shows only with the author's reason** (P18d, approved), and a listener is
   never shown the facts.
24. **Export → Arke Player for stories is a Studio turn** (approved), drawn next.
25. **A story plays itself** (P19, approved at the owner's direction, 28 October 2026). It stops only
   for a choice of two or more, a closed choice shown with its reason counting as one. A tap shows
   its controls and never moves on. A lone way on plays straight through, with no pause, no label and
   no row in the route. This withdraws P4d's tap and P18's `Auto`.
26. **Narration stays off for that story** (P19b, approved). It is on wherever a story has voices;
   turned off, it stays off for that story on this device, kept with where you are. The alternative
   is one setting for every story, in You beside Captions; then a story with voices could open
   silent, against rule 5.
27. **An interactive movie's controls are a film's** (P19f, approved), P3a's back 10 and forward 10
   included. Rule 2's list is the visual novel's: a movie has no beats, Log or Narration.

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
