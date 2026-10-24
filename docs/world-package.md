# Publishing a world to Available

How a world gets onto Available (P9). The format is [ADR 0005](decisions/0005-world-packages.md), and the code is `packages/arke_world`.

## The steps

1. **Make the files.** In Arke Studio, Publish each production's book as an EPUB and its narration as an M4B (SPEC-048 §2.11). The narration can also be an M4A or MP3. Pick a 16:9 picture for each production and the world's key art, as JPEG or PNG.
2. **Write a spec.** Paths are relative to the spec file:

   ```json
   {
     "id": "undersong",
     "edition": "2026-10-21",
     "name": "The Undersong",
     "logline": "A drowned god still sings beneath the harbour.",
     "keyArt": "key-art.jpg",
     "productions": [
       {
         "id": "ledger-of-nights",
         "title": "The Ledger of Nights",
         "author": "…",
         "picture": "ledger-of-nights.jpg",
         "book": "the-ledger-of-nights.epub",
         "narration": "the-ledger-of-nights.m4b"
       }
     ]
   }
   ```

3. **Pack it.** From the workspace root:

   ```
   dart run arke_world:pack_world undersong.json undersong-r1.zip https://<public host>/undersong-r1.zip
   ```

   This writes the ZIP (`world.json` plus the files, stored) and prints the catalogue entry, with the package's byte length and SHA-256. The packer reads its own manifest back and refuses to write one the Player would refuse.
4. **Publish the ZIP over HTTPS, publicly.** The Player downloads with no login, and the ArkePlayer repository is private, so its release assets need one. Use a public release instead, as the Studio's Sample world does (`github.com/michaeljosiah/ArkeStudio/releases`). Never replace a published file. A changed package is a new file with a new name.
5. **Pin it.** Paste the printed entry into `apps/arke_player/assets/worlds/catalogue.json` in place of the world's `"package": null`. Copy the key art and pictures to the `assets/worlds/<id>/` paths the entry names.
   A world's guide alone (SPEC-059 R-10), the Studio's Export of a world with nothing to play, is pinned the same way beside it, as `"guide": { "url", "byteLength", "sha256" }`. Its world page fetches it the first time it opens and keeps it, so the world can be explored before it is installed; a package installed later that carries the guide supersedes it. A guide with teasers (SPEC-059 R-28, P15) is guide version 2, and a Player from before ArkePlayer PR #11 (24 October 2026) refuses it as made with a newer Arke, and a package carrying it too: pin a guide or package with teasers only once phones have that Player.
   Pin a package made by the Studio's Export → Arke Player with `dart run arke_world:pin_world <package.zip> <https url>`: it prints the same entry with the package's `edition` and `fingerprint`, which is how a phone sees an update (SPEC-058 R-30). Every pin carries them.
   A production may also name `"tall"`, its Tall cover (P16 call 14, SPEC-058 rev 9): an upright picture bundled at `assets/worlds/<id>/`, which a poster in Stories and a world's Listen and Read, and a phone's feature, show. Without one they show its `picture` whole over its own blur. Like `picture`, it is always the app's own: a fetched list's is ignored, so a new Tall cover needs a build. Na Love or Juju's is its book cover, cut from the middle of its published cover. The Red Quiet's (list serial 19) was made upright with Codex Image from Ines Marr's and the Mistress's main photos, with its title at the top: the phone's feature takes 51 px from the top of a 1024 × 1536 poster and shades its foot under the Player's own words, so a title must start below row 70. The Studio does not make a Tall cover yet; until it does, make it from the cover by hand.
   The list may name what Discover opens on, `"feature": { "world": "<id>", "production": "<id>" }` (the production is optional: the world's first), and the world across its band, `"band": "<id>"` (P16 call 15). They are read from whichever list is newer, so they can be moved by publishing the list alone. A name no listed world answers to is ignored; with neither named, Discover features the newest part's production and bands the last world that is not the feature's.
6. **Ship a build, and publish the list.** The list ships with the app (P9 rule 1) and is also fetched from Arke's address (`arkeWorldsList` in `features/worlds/application/worlds.dart`, P12 rule 1), at most once a day. Raise the list's `serial` with every change, commit it, and upload the same `catalogue.json` there, the one file that is replaced in place (`gh release upload arke-player-worlds apps/arke_player/assets/worlds/catalogue.json --clobber --repo michaeljosiah/ArkeStudio`; the release, made 22 October 2026 at serial 1, is never marked Latest, so the Studio's own update check never sees it); a phone takes the list with the higher serial, so a new edition shows on installed phones without a build. A world appears on Available, or an installed world shows `Update`, once its package is pinned in the list a phone has.
7. **Check it on a phone:** install it from Available, play the narration, and Read the book.

## Releasing new chapters as a part (SPEC-058 R-43 – R-56, P15)

A world released a chapter at a time is its edition and one part per release. A part is the
Studio's Export → Arke Player with Release · New chapters: a schema 4 package of one production's
chapters read whole since the last release, naming the edition it follows by label and fingerprint
(`part`), with the author's schedule. It carries only its own files: the new chapters' audio,
pictures, phrases and loops, and an EPUB of those chapters alone; never a guide.

1. **Upload it** under its own name to the world's public story release, as a package is. Never
   replace a published part.
2. **Pin it** with the fingerprint of the edition in the world's list entry:

   ```
   dart run arke_world:pin_world <part.zip> <https url> --follows <the entry's package fingerprint>
   ```

   It refuses a part made after another edition, and prints `part` — the pin with `released`,
   `production` and `chapters` — and `production`, its id and schedule.
3. **Add it to the entry:** append `part` to the world's `package.parts`, in release order, and set
   the listed production's `id` and `schedule` from `production`. The list stays `version: 2`: a
   Player from before parts ignores both keys and offers the edition alone.
4. **Raise `serial` and publish the list**, as for an edition. Installed phones fetch the part on
   their own when the app opens (over Wi-Fi only unless You says otherwise), or ahead in the daily
   check while a world's Notify is on; new installs fetch the edition and every part.

A new Whole world edition holds every chapter released: pin it as an edition and empty the entry's
`parts`. Installed phones offer it as `Update`, and their parts fall away once it is checked.

## The Undersong

**Pinned now: the 24 October 2026 cover edition** (list serial 14): `the-undersong-player-2026-10-24.zip`, 360,101,640 bytes, SHA-256 `a1e1e38e967d01490c7fe471d56cb65234c87ed6491ef2091a8ff75899742dcc`, on the same release. The editorial edition below with one change: *The Ledger of Nights* has its own picture, given as Publish's cover (`--cover`), where before the export used the key art. It was made with Codex Image from Maren Kest's and Perrin Tallow's portraits and the Bell House's view: Maren on the sea-wall steps with a lantern over the drowned god's sleeping face, rings of light rising towards the bells, Perrin at his lit window above. The narration, book, pictures and guide are byte for byte the editorial edition's (290.58 minutes, 23 chapters); it was exported from the same copy, `D:\ArkePlayerEditorialPublication-20261022\the-undersong`, with only the cover added. The app bundles the picture as `assets/worlds/undersong/ledger-of-nights.jpg`, the path the list already named, so a build without it keeps the old picture rather than missing one.

**Before it, the 22 October 2026 editorial edition** (list serial 5): `the-undersong-player-2026-10-22-3.zip`, 359,819,305 bytes, SHA-256 `b521f0c846c8f41d16fc1c1fb71cc5a8d8b333cbc6662c508f3968a6135815f3`, fingerprint `00a891bd6e611dbf5bc05777687ef59f1c8a1d6790b0b71217c0e12995629216`, on story release `undersong-2026-10-22-r1`. Schema 3: all 23 chapters, 4 h 50 m 34.84 s of narration, 243 pictures, the complete book and the public Guide. Chapters 1–5 contain the accepted prose revisions and 34 new narration passages; chapters 6–23 retain byte-identical audio. The native exporter omits illustration placements no longer current after revision; no new pictures were generated for this edition. The Guide is unchanged, so its existing guide-alone pin is retained.

Made with the Studio exporter at `d63bf5ca897709e0fac37bccd5522dc21e14a892`, from a copy of the release import with only the five approved chapter/audio records and verified new clips overlaid. The Player reader and installer verified all 296 assets; every EPUB chapter matches the manuscript, every audio duration matches its listening document, and the first five chapter exports decode fully. Full human listening qualification remains pending; no physical-device check is claimed. The video pilot is excluded. This Player edition supersedes the previous Player pin; the separate Studio sample archive and standalone EPUB/M4B downloads are unchanged.

The world's id moved from the hand-packed `undersong` to the Studio's `the-undersong` with this edition. The list's entry says `"replaces": ["undersong"]` (list serial 3), so a phone holding the 20 October package or the 21 October illustrated one is offered `Update`: the new world is installed and the old one removed, its places starting over. Every edition from here on is the Studio's export, under `the-undersong`.

**The first edition**, superseded: published on 20 October 2026 as `the-undersong-player-2026-10-20.zip`: 182,182,066 bytes, SHA-256 `46ff9dbaf5fed13ca3f5c795ad4aed0ba7165ee84cc3bcfec6730e9451504a8b`. It sits on ArkeStudio release `undersong-2026-10-19-r3`, beside the Studio's Sample world, and is pinned in the catalogue. Packed from these files on that release, unchanged:

| | File | What the Player reads |
|---|---|---|
| Book | `the-undersong-the-ledger-of-nights-2026-10-20.epub` | *The Ledger of Nights*, 16 chapters, a cover |
| Narration | `the-undersong-chapters-01-12-partial-2026-10-20.m4b` | 3 h 49 m, 12 chapter markers, from *Neap* to *Practical transport* |
| Key art and picture | the app's bundled `assets/worlds/undersong/` | the world's key art, the production's picture |

Neither file names an author, so none is shown.

**A new edition**, for example when chapters 13–16 are narrated:
1. Publish again from the Studio.
2. Pack with a new `edition` and a new file name.
3. Upload it beside the old one.
4. Pin it and ship a build.

Never replace the published ZIP: a build pinned to it would refuse the new bytes as `1 file does not match`.

Still owed:
- **SPEC-048** should define the package of a world, or adopt ADR 0005's.
- **An illustrated book.** The Studio's EPUB writer carries the cover and the text, not the chapter illustrations. Placing them inline is Studio work, and an amendment to SPEC-048 §2.11.
- **The pictures of the moment and Slow push.** These come from Studio 186's illustrated audiobook player, and an M4B carries only a cover, which the native player shows (P7d). They need the hosted Studio audiobook module (ADR 0001), after the MVP.
- **The video pilot.** It is unfinished and not in the package.

The spec it was packed from:

```json
{
  "id": "undersong",
  "edition": "2026-10-20",
  "name": "The Undersong",
  "logline": "A drowned god still sings beneath the harbour.",
  "keyArt": "files/key-art.jpg",
  "productions": [
    {
      "id": "ledger-of-nights",
      "title": "The Ledger of Nights",
      "picture": "files/ledger-of-nights.jpg",
      "book": "files/the-undersong-the-ledger-of-nights-2026-10-20.epub",
      "narration": "files/the-undersong-chapters-01-12-partial-2026-10-20.m4b"
    }
  ]
}
```

## Legend of Dumah

**Pinned now: the 24 October 2026 edition** (list serial 18), the Studio's Export → Arke Player of a copy of the owner's world, without the book: `legend-of-dumah-player-2026-10-24.zip`, 122,331,214 bytes, SHA-256 `dbaad8bc67d8cc095fc4338a3a2420094f965a1a6a3c660702f3b9596ac4898a`, on ArkeStudio release `legend-of-dumah-2026-10-22-r1`. Schema 3, world id `legend-of-dumah`: the Prologue and Chapters 1 to 3 of *Whispers from the Void* narrated in one designed Gemini voice (1 h 23 m), the chapters' 59 pictures each with its Tall (P14, made from the picture by the Studio's Make tall, turn 235), the key art, and the guide. A Player without P14 refuses the package as made with a newer Player, since its listening reader takes an unknown key as newer (R-13), so a phone needs a P14 build to install this edition or update to it. The copy's `exports/` starts empty, so its first export took the edition `2026-10-23` already published; the copy was given the used names and exported again, since a published package is never replaced. Its guide alone, `legend-of-dumah-guide-2026-10-23-2.zip` (1,934,982 bytes, SHA-256 `99eb0e765e01eaf7421a0c690159480557c234c93cd47139ad901c2754315239`), is on the same release, and is the guide alone of the fourth 23 October edition: this edition's guide is the same but for its edition stamp, so the list keeps it. Its production is shown by its own picture, Chapter 1's opening view of Zeel, given as Publish's cover (`--cover`, ArkeStudio PR #2160): before it, the export always used the key art, and the world and its Listen showed the same picture. The earlier editions are still there (22 October, serial 6, without the places' pictures or Zeth's and Lucien's portraits; 23 October, serial 7; 23 October second, serial 8, Prologue and Chapter 1 without Talls; 23 October third, serial 9, to Chapter 2; 23 October fourth, serial 11, to Chapter 2 with the author's designs), and a phone holding any of them is offered `Update`. This edition adds Chapter 3, *Nightfall Breach* (22 m, 15 pictures with their Talls), and every chapter's spoken heading now names its place once (ArkeStudio PR #2174): the fourth 23 October edition said "Chapter 4 · Chapter 3 — Nightfall Breach" and "Chapter 1 · Prologue — Whispers from the Void". The fourth 23 October edition carried the author's designs of 23 October: Lucien's portrait, made from his character sheet; the Moonstone Forge and the hidden escape route as places of their own, their views made from the author's boards; and Chapter 2's seven forge and tunnel pictures made again in them. The escape route's guide entry waits for Chapter 2 (`after`), since the chapter reveals it.

The guide shows six characters, three places, three factions and four lore entries. Each shows only an `In the story` section written for readers on the copy, and links that give nothing away. The world's own sheets and canon carry the whole book's secrets, so a later edition should be made the same way: from a copy whose reader text and links are checked against the chapters it narrates. Lucien's portrait keeps his face hidden, because Book One never describes him. The factions have no pictures yet.

## The Red Quiet

**Pinned now: the 24 October 2026 cover edition** (list serial 14): `the-red-quiet-player-2026-10-24.zip`, 22,805,992 bytes, SHA-256 `dfaa5ac88c00df738deee7557596fecf08ad6504713f5e8d231ed78f9836be91`, on the same release. The edition below with *The Red Quiet* given its own picture as Publish's cover: made with Codex Image from Ines Marr's and the Mistress's portraits and the key art, Ines walking the floodlit perimeter with her lamp while the Mistress rises out of the spires behind her. Exported from the same copy with only the cover added, so Chapter 1 is still the narration below (15 m 29 s); the rewritten Chapter 1 is read separately. The app bundles the picture as `assets/worlds/the-red-quiet/cover.jpg`; a build without that file shows no picture on the world's `Inside` row until it is updated.

**Before it, the 23 October 2026 edition** (list serial 10), the Studio's Export → Arke Player of a copy of the owner's world, with the book: `the-red-quiet-player-2026-10-23-2.zip`, 22,583,065 bytes, SHA-256 `c490b30cb868a6fd4cd085f26c74f76b52ef90e0607ca9ffc49fdcdb095e9753`, on ArkeStudio release `the-red-quiet-2026-10-23-r1`. Schema 3, world id `the-red-quiet`: all 17 chapters as the book, Chapter 1 (*Landfall*) narrated by Ines Marr's designed Gemini voice (15 m 29 s), its 9 pictures each with its Tall (P14), the key art, and the guide. Part Two is narrated by the Mistress's own voice (a chapter narrator, ArkeStudio PR #2168) once it is read. As with Legend of Dumah, a Player without P14 refuses the package, since it carries Talls. The copy's first export, `-2026-10-23`, was never published: it carried the old logline and no guide. Its guide alone, `the-red-quiet-guide-2026-10-23.zip` (1,131,799 bytes, SHA-256 `bba813092c1180e74c7cea42cb0c8fd1b98afe3b01790c536cfc732e9189fcc0`), is on the same release.

The guide shows all seven characters and both places. Each character's Appearance is public from the start, and each Essence waits for the chapter that tells it: Lark's after Chapter 12, Bode's after Chapter 6, Ines's, Venn's and Kit's after Chapter 15, and the Mistress's and the Young's after Chapter 16. The Mistress herself appears after Chapter 5, the Young after Chapter 4 and the Ossuary Ship after Chapter 9. No lore: the world's canon threads are open, not settled. The logline is new for this edition. The world's own logline still says the old one, and the copy was given the new one before export, so a later edition needs it changed in the world first.

## Embers of the Fallen

**Pinned now: the 24 October 2026 cover edition** (list serial 14): `embers-of-the-fallen-player-2026-10-24.zip`, 126,827,906 bytes, SHA-256 `9e34eaf9ab65b4af5786fa63dd89f71465e8562346b55e32e1ea956205b849df`, on the same release. The edition below with *Threshold — Book One* given its own picture as Publish's cover: made with Codex Image from Jace Sinclair's and Reina Okafor's portraits and Chapter 1's opening picture, the two at the lip of the opening in the snow, a sunlit valley that cannot be there far below and ancient round doors in its walls. Exported from the same copy with only the cover added (113.88 minutes, Chapters 1–5). The app bundles the picture as `assets/worlds/embers-of-the-fallen/cover.jpg`; a build without that file shows no picture on the world's `Inside` row until it is updated.

**Before it, the fourth 23 October 2026 edition** (list serial 13), the Studio's Export → Arke Player of a copy of the owner's world, with the book: `embers-of-the-fallen-player-2026-10-23-4.zip`, 126,323,097 bytes, SHA-256 `466e33ca699ec47df2b56ae5f8d2f3f80609bf06056a39094d421bb85feb4087`, on ArkeStudio release `embers-of-the-fallen-2026-10-23-r1`. Schema 3, world id `embers-of-the-fallen`: all 19 chapters of *Threshold — Book One* as the book, Chapters 1–5 narrated in one ElevenLabs v4 voice (1 h 54 m), Chapter 1's 16 pictures each with its Tall (P14), Chapter 2's 12 pictures, the key art, and the guide. As with Legend of Dumah, a Player without P14 refuses the package, since it carries Talls. Chapter 1 is grouped by beats, as Chapters 2–5 already were.

The first published edition, `-2026-10-23-2` (serial 12), said several of Chapter 1's lines twice: a 101-character chapter note led every block as a v4 tag, and the reader repeated each block's first line. That chapter was read again without the note (the Studio no longer writes chapter notes), and its takes were measured, so its pictures and words follow the audio; the earlier edition's Chapter 1 timing was an estimate about two minutes long. A phone holding it is offered `Update`. Exports `-2026-10-23` (Chapters 2–5 only) and `-3` (unmeasured takes) were never published. Its guide alone, `embers-of-the-fallen-guide-2026-10-23-2.zip` (648,495 bytes, SHA-256 `9d99ecacc5350fadaab941f34992e77c3c9c385eb764b07d295cf450710c931a`), is on the same release.

The guide shows eight characters, no places and no lore. Jace's and Reina's Appearance and Essence are public from the start, as are Jono's and Tala's Appearance. Zeb's Appearance waits for *The Observation Post*, Mag's Essence for *What the Count Missed*, Mercer's Appearance and Relationships for *The Brood*, and Aurora appears after the Epilogue. The logline is new for this edition, written to the world's Echoes lore rather than the old dimensional-Tears premise; as with The Red Quiet, only the copy carries it, so a later edition needs it set in the world first.

## Na Love or Juju

**Pinned now: the third 24 October 2026 edition** (list serial 17): `na-love-or-juju-player-2026-10-24.zip`, 859,155,524 bytes, SHA-256 `83c120b93095ea0cb1a05e5c709af0d40d0a3b209eb65bcb80f472e69c9af7ff`, on ArkeStudio release `na-love-or-juju-2026-10-24-r3`, exported from the copy `C:\Users\mjosi\ArkePlayerExport-20261024d\na-love-or-juju`. It completes the second edition: every one of its 369 pictures has its Tall. Codex Image made all of them but four close portraits of Ife, which it refused; those four were made on the owner's machine by Qwen Image 2.1 through ComfyUI, from their Wide pictures with the Studio's own Tall brief. Its guide alone, `na-love-or-juju-guide-2026-10-24.zip` (3,755,683 bytes, SHA-256 `3c4e5df3a6389f66824ebdd4b56c59736242f6b13a0ecb3006fa8961bde6e1e8`), is on the same release, with the same content as the second edition's.

**Before it, the second 24 October 2026 edition** (list serial 16): `na-love-or-juju-player-2026-10-24.zip`, 807,915,482 bytes, SHA-256 `021e161add6e3d8073518863088b8f8cb9453cbe9b58e00d7d63c73882ff9677`, on ArkeStudio release `na-love-or-juju-2026-10-24-r2`. It has the same name as the first edition's file but sits on a release of its own, because a published package is never replaced; phones see `Update` by its fingerprint. It is exported from the copy `C:\Users\mjosi\ArkePlayerExport-20261024c\na-love-or-juju` (D: was full) and differs from the first edition in four ways:
- Chapter 1 has eight new pictures (SPEC-047 R-202, Studio turn 237), each starting on the sentence it shows. Its 23 pictures come one every 53 s, where they came every 89 s.
- 191 of the 370 pictures have their Tall: Chapters 2–5 and 7–11 whole, and Chapters 1, 6 and 12 in part. Codex Image refused three close portraits of Ife, which keep their wide picture. Chapters 13–26 follow in the next edition.
- The production has its own picture, given as Publish's cover (`--cover`). It is the book cover centred on a blurred copy of itself, so its title survives the 16:9 tiles. The app bundles it as `assets/worlds/na-love-or-juju/cover.jpg`.
- The guide has six teasers (SPEC-059 R-24), which makes it guide version 2: a Player from before PR #11 refuses the package and the guide alone. The teasers are three clips (Ade hears Ife before he sees her, her thumb in the car, the folded napkin), Ife, Ade and the picture under the caged bulb.

Its guide alone, `na-love-or-juju-guide-2026-10-24.zip` (3,755,683 bytes, SHA-256 `f5153d5b8998366c4bb1cce5e0698d6f0de7c7f9b1845e3baf4f50f492817856`), is on the same release.

**Before it, the 24 October 2026 edition** (list serial 15), the Studio's Export → Arke Player of a copy of the owner's world, with the book: `na-love-or-juju-player-2026-10-24.zip`, 767,521,724 bytes, SHA-256 `1e608147759cf0a947baf477111dbc0dd3f1d2407fdc9d7fcf2f8d232e404330`, on ArkeStudio release `na-love-or-juju-2026-10-24-r1`. Schema 3, world id `na-love-or-juju`: all 26 chapters of *Na love or Juju* as the book, every chapter narrated in the designed Gemini voice Nigerian Woman 2 (11 h 55 m), 361 pictures, Chapter 1's with their Talls (13 of 15: Codex Image's safety filter refused to recompose two close photorealistic portraits of Ife, which keep their wide picture), the key art and the guide. As with the other Tall editions, a Player without P14 refuses the package. Its guide alone, `na-love-or-juju-guide-2026-10-24.zip` (2,048,690 bytes, SHA-256 `c4fa8e6882dd8fd33ba43d9425d1c93d7bf22411bfb23590896901c0ef2eceb6`), is on the same release.

The guide shows fourteen characters and three places. Every character's Essence names what happens to them, so each waits for the last chapter, *Every Day*; each Appearance shows from the chapter that brings them in, and Ife's mother waits for *Ayoka*, which gives Ife's real name. The places show their Look and Atmosphere only. The canon's four open questions stay off. The copy, `D:\ArkePlayerExport-20261024\na-love-or-juju`, left out the world's `.cache` and Bench sessions, which the export does not read.

## Check immediately (P13)

In **Worlds**, press the round **Check for updates** control in the header. It fetches a fresh
catalogue even inside the 24-hour automatic interval, updates the visible list without a restart,
and leaves world downloads to the existing **Update** press. While checking, the control is
disabled and the current worlds remain visible. **Checked** confirms a successful catalogue
check; **Couldn’t check for updates** keeps the current list and permits an immediate retry.
