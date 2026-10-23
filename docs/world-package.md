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
   A world's guide alone (SPEC-059 R-10), the Studio's Export of a world with nothing to play, is pinned the same way beside it, as `"guide": { "url", "byteLength", "sha256" }`. Its world page fetches it the first time it opens and keeps it, so the world can be explored before it is installed; a package installed later that carries the guide supersedes it.
   Pin a package made by the Studio's Export → Arke Player with `dart run arke_world:pin_world <package.zip> <https url>`: it prints the same entry with the package's `edition` and `fingerprint`, which is how a phone sees an update (SPEC-058 R-30). Every pin carries them.
6. **Ship a build, and publish the list.** The list ships with the app (P9 rule 1) and is also fetched from Arke's address (`arkeWorldsList` in `features/worlds/application/worlds.dart`, P12 rule 1), at most once a day. Raise the list's `serial` with every change, commit it, and upload the same `catalogue.json` there, the one file that is replaced in place (`gh release upload arke-player-worlds apps/arke_player/assets/worlds/catalogue.json --clobber --repo michaeljosiah/ArkeStudio`; the release, made 22 October 2026 at serial 1, is never marked Latest, so the Studio's own update check never sees it); a phone takes the list with the higher serial, so a new edition shows on installed phones without a build. A world appears on Available, or an installed world shows `Update`, once its package is pinned in the list a phone has.
7. **Check it on a phone:** install it from Available, play the narration, and Read the book.

## The Undersong

**Pinned now: the 22 October 2026 editorial edition** (list serial 5): `the-undersong-player-2026-10-22-3.zip`, 359,819,305 bytes, SHA-256 `b521f0c846c8f41d16fc1c1fb71cc5a8d8b333cbc6662c508f3968a6135815f3`, fingerprint `00a891bd6e611dbf5bc05777687ef59f1c8a1d6790b0b71217c0e12995629216`, on story release `undersong-2026-10-22-r1`. Schema 3: all 23 chapters, 4 h 50 m 34.84 s of narration, 243 pictures, the complete book and the public Guide. Chapters 1–5 contain the accepted prose revisions and 34 new narration passages; chapters 6–23 retain byte-identical audio. The native exporter omits illustration placements no longer current after revision; no new pictures were generated for this edition. The Guide is unchanged, so its existing guide-alone pin is retained.

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

**Pinned now: the 23 October 2026 edition** (list serial 7), the Studio's Export → Arke Player of a copy of the owner's world, without the book: `legend-of-dumah-player-2026-10-23.zip`, 35,606,920 bytes, SHA-256 `969dfa0f4b65bb81339e65a8e1f29b7bf948d60b81df9da65d48c6ba8265c25e`, on ArkeStudio release `legend-of-dumah-2026-10-22-r1`. Schema 3, world id `legend-of-dumah`: the Prologue and Chapter 1 of *Whispers from the Void* narrated in one designed Gemini voice (28 m 47 s), Chapter 1's 17 pictures, the key art, and the guide. Its guide alone, `legend-of-dumah-guide-2026-10-23.zip` (1,486,733 bytes, SHA-256 `b8fd89e57fdfc2df1307e4f84a6019eac5218013f21cfb8a2206de34448befe4`), is on the same release. The 22 October edition (list serial 6) is still there; it lacked the places' pictures and Zeth's and Lucien's portraits, so a phone holding it is offered `Update`.

The guide shows six characters, three places, three factions and four lore entries. Each shows only an `In the story` section written for readers on the copy, and links that give nothing away. The world's own sheets and canon carry the whole book's secrets, so a later edition should be made the same way: from a copy whose reader text and links are checked against the chapters it narrates. Lucien's portrait keeps his face hidden, because Book One never describes him. The factions have no pictures yet.

## Check immediately (P13)

In **Worlds**, press the round **Check for updates** control in the header. It fetches a fresh
catalogue even inside the 24-hour automatic interval, updates the visible list without a restart,
and leaves world downloads to the existing **Update** press. While checking, the control is
disabled and the current worlds remain visible. **Checked** confirms a successful catalogue
check; **Couldn’t check for updates** keeps the current list and permits an immediate retry.
