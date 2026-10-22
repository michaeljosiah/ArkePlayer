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

**Pinned now: the 22 October 2026 edition** (list serial 2), the Studio's Export → Arke Player of the 23-chapter world from story release `undersong-2026-10-22-r1` (*Perrin's awakening*): `the-undersong-player-2026-10-22.zip`, 413,454,398 bytes, SHA-256 `fb45df559fff41d25a20150bc7b936671b97b3e7b1a354d37f8ccb2a41ba3559`, fingerprint `6d657eca…e9d0`, on that release. Schema 2, world id `the-undersong` (the Studio's slug): the whole book, and all 23 chapters narrated with their 290 pictures and Text, 5 h 33 m. Made with `scripts/export-arke-player.mts` on a copy of the release's import, checked with the Player's own installer (every chapter's audio within 0 ms of its document), and published with the list on `arke-player-worlds`.

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
