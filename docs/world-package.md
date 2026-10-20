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

The Undersong is in the catalogue with `"package": null`, so Available, first open's `Install a world` and Home's section all stay absent until these steps are done.

Facts below come from ArkeStudio release `undersong-2026-10-19-r3` (listed with range requests, 20 October 2026) and SPEC-048 §2.11.

1. **The book.** In Arke Studio (0.5.61 or later), open The Undersong. Publish *The Ledger of Nights* as a story edition: all 16 chapters, output EPUB only.
   - The Studio's EPUB writer puts in the cover and the text, not the 244 chapter illustrations, so the book reads unillustrated.
   - An illustrated book needs the Studio's EPUB writer to place illustrations inline. That is Studio work and an amendment to SPEC-048 §2.11.
   - The release's own EPUB (110 KB) predates the illustration pass.
2. **The narration.** Publish a second edition with chapters 1–6 only, output M4B only.
   - An edition takes one chapter list for all its outputs. Publishing refuses chapters without takes and never generates narration, so all 16 chapters with an M4B would be blocked.
   - The result is an AAC M4B at 192 kb/s with six chapter markers, about 2 h 3 m.
   - The release holds the same six chapters as separate M4A files (17–24 MB each, about 120 MB). An interim M4B could be joined from them with ffmpeg, but Publish is the authority for the mix, the markers and the metadata.
3. **The pictures.** Pick the world's key art and one 16:9 illustration for *The Ledger of Nights*. The release's 431 pictures (1.15 GB) are mostly the Studio's working PNGs and stay out.
4. **Pack, publish, pin, ship,** as above.
5. **SPEC-048.** Amend it to define the package of a world, or to adopt ADR 0005's.

What the Player will not have, and why:
- **The pictures of the moment and Slow push.** These come from Studio 186's illustrated audiobook player, and an M4B carries only a cover, which the native player shows (P7d). They need the hosted Studio audiobook module (ADR 0001), after the MVP.
- **The video pilot.** It is unfinished and not in the package.
