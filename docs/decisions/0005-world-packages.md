# 0005 · Worlds install as world packages of standard files

**Status:** accepted 20 October 2026, with design turn P9 (worlds to install), which the owner approved and asked to be built in the MVP. The format is the Player's proposal until SPEC-048 defines a package of a world; SPEC-048 is owed the amendment.

## Context

P9 lets a person install a world Arke publishes, starting with the demo world, The Undersong. P2 rule 5 always assumed a "world package", a ZIP of a world's name, logline, key art and its publications, but no specification defines one:

- SPEC-048 defines one *publication* package (`publication.json`, profile `video` v1 only). Its book, narrated-book and audiobook profiles (R-24, R-25) are proposed, not approved.
- The Studio's story Publish (SPEC-048 §2.11, Studio turn 224) makes an **EPUB** and an **AAC M4B** with chapter markers and a cover. These are standalone files, not publication profiles.
- The Studio's Sample world download (ArkeStudio #1949, release `undersong-2026-10-19-r3`, 1.6 GB) is the *editable world*. It is a world's source, and the Player never opens one (P1 rule 1).

## Decision

A world package (`arke-world-package`, schema version 1) is a ZIP with `world.json` at its root and the files it names. Each production is made of files the MVP's native players already open (ADR 0004):

| Role | Media types | Opens in |
|---|---|---|
| `book` | `application/epub+zip` | the reader (P5e) |
| `narration` | `audio/mp4` (M4B, M4A), `audio/mpeg` (MP3) | the audio player (P7d, P5a–P5c) |
| `picture`, `keyArt` | `image/jpeg`, `image/png` | the world's and production's pages |

A production with a book and its narration is one production under Listen, with Read beside Play (P1 rule 6, P9 rule 7).

The rules follow SPEC-048 where it already speaks:

- **Every file inventoried** with path, media type, byte length and SHA-256, and nothing unreferenced (R-13).
- **Paths portable and inside the package.** The reader refuses traversal, absolute paths, backslashes, symbolic links, duplicate entries after case folding, and any file the manifest does not name (R-14).
- **Strict reading.** A key, schema version or required capability the reader does not know is refused as `Made with a newer Arke`. Only `metadata` and `provenance` may be ignored (R-17).
- **Stored, not compressed.** Media is compressed already, and a stored entry is exactly as long as its directory says, so a package can't unpack to more than it declared.

The list of worlds to install ships with the app (`apps/arke_player/assets/worlds/catalogue.json`): each world's name, logline, bundled key art, and its package's HTTPS address, byte length and SHA-256. The Studio pins its Sample world the same way. The download must match the pin before it is opened, and each file must match `world.json` before anything plays (P2 rule 6).

`packages/arke_world` holds all of it with no Flutter: the manifest reader, the catalogue, the safe reader, the installer and the packer (`dart run arke_world:pack_world`).

## Why

- **It plays today.** EPUB and M4B are exactly what the Studio's Publish makes and what the MVP's players open. A world package needs no new profile or player, and no hosted module (ADR 0001 stays for interactive and visual-novel productions).
- **It is checked twice.** The pin proves the download is the package the build expected, and the manifest proves each file is the one the package declared.
- **It is replaceable.** When SPEC-048 approves book and audiobook profiles, a production can name a `publication.json` instead. That is a schema version 2, and version 1 readers refuse it cleanly.

## Consequences

- SPEC-048 needs an amendment defining the package of a world, or adopting this one. Until then, any change to `world.json` is a change to this ADR.
- Installing needs the network: the release manifest has `INTERNET`, used for nothing else.
- The download and what it unpacks to are both on the phone until the download is deleted, so twice the package's size is checked before the first byte.
