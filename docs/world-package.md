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
6. **Ship a build.** The list ships with the app (P9 rule 1). A world appears on Available in the next build, and only once its package is pinned.
7. **Check it on a phone:** install it from Available, play the narration, and Read the book.

## The Undersong

Published on 20 October 2026 as `the-undersong-player-2026-10-20.zip`: 182,182,066 bytes, SHA-256 `46ff9dbaf5fed13ca3f5c795ad4aed0ba7165ee84cc3bcfec6730e9451504a8b`. It sits on ArkeStudio release `undersong-2026-10-19-r3`, beside the Studio's Sample world, and is pinned in the catalogue. Packed from these files on that release, unchanged:

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
