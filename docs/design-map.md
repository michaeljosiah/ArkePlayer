# Design map

Every frame of the Arke Player design master (`design/Arke Player.dc.html`), the route that shows it, and the file that will draw it. A screen is built when its frames match at the sizes drawn: 390 × 844 for a phone, 844 × 390 turned, 984 × 1092 for a Fold7 open.

## The MVP (built)

| Frame | Screen | Route | File |
|---|---|---|---|
| P8a | First open, before sign-in | `/welcome` | `features/onboarding/presentation/first_open_screen.dart` |
| P8b, P8d | Home: nothing added; Continue and Added | `/` | `features/home/presentation/home_screen.dart` |
| P8c, P8e | Library, files only (two columns on a Fold) | `/library` | `features/library/presentation/library_screen.dart`, `item_menu.dart` |
| P7a | Adding files | (the picker, then a sheet) | `features/add_file/presentation/add_flow.dart`, `application/file_importer.dart` |
| P6a | Downloads, files only | `/downloads` | `features/downloads/presentation/downloads_screen.dart` |
| P8f | You, before sign-in | `/you` | `features/settings/presentation/you_screen.dart` |
| P7d, P5a–P5c | Audio player, chapters, speed and sleep | `/open/:itemId` | `features/players/presentation/audio_player_screen.dart` |
| P1 rule 8 | The dock | (over the tabs) | `features/players/presentation/dock.dart` |
| P5e | The reader (EPUB) | `/open/:itemId` | `features/players/presentation/reader_screen.dart` |
| P7c | The page viewer (PDF) | `/open/:itemId` | `features/players/presentation/pdf_screen.dart` |
| P3a, P3b, P3e | The film player | `/open/:itemId` | `features/players/presentation/film_screen.dart` |

## After the MVP (designed, not built)

| Frame | Screen | Route | File |
|---|---|---|---|
| P1a | First open, with Sign in | `/welcome` | `features/onboarding/` |
| P1b | Home with shares and worlds | `/` | `features/home/` |
| P1c | Library with worlds | `/library` | `features/library/` |
| P1d | A world, with the dock | `/library/world/:worldId` | `features/world/presentation/world_screen.dart` |
| P1e | A production: audiobook and book | `/library/world/:w/production/:p` | `features/production/presentation/production_screen.dart` |
| P1f | A production: micro drama | `/library/world/:w/production/:p` | `features/production/presentation/production_screen.dart` |
| P2a, P2b | A share link; waiting for the browser | `/share/:token` | `features/sharing/presentation/share_link_screen.dart` |
| P2c | Add | `/add` | `features/add_file/presentation/add_screen.dart` |
| P2d | Checking a package | `/add` | `features/add_file/presentation/add_screen.dart` |
| P2e | A package, ready | `/add` | `features/add_file/presentation/add_screen.dart` |
| P2f | A package, refused | `/add` | `features/add_file/presentation/add_screen.dart` |
| P2g | A share that ended | `/library` | `features/library/presentation/library_screen.dart` |
| P3a, P3b | A film, upright and turned | `/play/:productionId` | `features/players/` (hosted module) |
| P3c, P3d | A micro drama; episodes | `/play/:productionId` | `features/players/` (native feed) |
| P3e | Captions | `/play/:productionId` | `features/players/` |
| P4a–P4c | Interactive: choice, route, ending | `/play/:productionId` | `features/players/` (hosted module) |
| P4d, P4e | Visual novel: a line, the log | `/play/:productionId` | `features/players/` (hosted module) |
| P5a–P5c | Audiobook, chapters, speed and sleep | `/play/:productionId` | `features/players/` (hosted module) |
| P5d | Audio drama with its transcript | `/play/:productionId` | `features/players/` (native) |
| P5e | A book | `/open/:fileId` or `/play/:productionId` | `features/players/` (native reader) |
| P6a | Downloads | `/downloads` | `features/downloads/presentation/downloads_screen.dart` |
| P6b | You | `/you` | `features/settings/presentation/you_screen.dart` |
| P6c | Adult content | `/library/world/:worldId` | `features/world/` with `features/settings/` |
| P6d | Offline | `/` | `features/home/presentation/home_screen.dart` |
| P6e | Home on a Fold | `/` | `app/shell/adaptive_shell.dart` and Home |
| P6f | An audiobook on a Fold | `/play/:productionId` | `features/players/` |
| P7a | Adding files | `/add` | `features/add_file/presentation/add_screen.dart` |
| P7b | Library · Added, with files | `/library` | `features/library/presentation/library_screen.dart` |
| P7c | A PDF | `/open/:fileId` | `features/players/` (native page viewer) |
| P7d | An audiobook file | `/open/:fileId` | `features/players/` (hosted audiobook module) |

## Worlds to install (P9, built)

P9 joined the MVP on 20 October 2026. The world package is [ADR 0005](decisions/0005-world-packages.md); the install, check and catalogue are `packages/arke_world`. Library and Downloads show installed worlds (P9 rule 6, P6a).

| Frame | Screen | Route | File |
|---|---|---|---|
| P9a | First open, with Install a world | `/welcome` | `features/onboarding/presentation/first_open_screen.dart` |
| P9b | Available — replaced by the Worlds tab (P11a), now Discover (P15a) | `/discover` | `features/worlds/presentation/discover_screen.dart` |
| P9c–P9f, P9h | A world before, while and after it installs; refused; on a Fold | `/world/:worldId`, `/worlds/world/:worldId`, `/library/world/:worldId` | `features/worlds/presentation/world_screen.dart`, `world_widgets.dart`; `features/worlds/application/worlds.dart` |
| P1e (for P9) | A production of an installed world: Play or Continue, Read, Chapters | `…/world/:worldId/:productionId` | `features/worlds/presentation/production_screen.dart` |
| P9g | Home, ending with Worlds and Available | `/` | `features/home/presentation/home_screen.dart` |

## Worlds to explore (P11, built)

SPEC-059 R-17 – R-23, ArkePlayer #2. The guide is a world package's guide document (schema 3), read
by `arke_world`'s `guide.dart`; a guide alone is fetched against the catalogue's pin and kept under
`guides/` (`WorldInstaller.fetchGuide`, `LibraryStore.addGuide`). What a reader has reached is
`arke_world`'s `reach.dart`; what they revealed is kept in `library.json` with their places.

| Frame | Screen | Route | File |
|---|---|---|---|
| P11a | Worlds: In Library, then Available — now Discover (P15a) | `/discover` | `features/worlds/presentation/discover_screen.dart` |
| P11b, P11c, P11i | A world's page, before and after install, then its guide; the head once scrolled; on a Fold | `…/world/:worldId` | `features/worlds/presentation/world_screen.dart`, `guide_widgets.dart` (`GuideSections`); `features/worlds/application/guides.dart` |
| P11d, P11e, P11g | A character, a place, a lore entry | `…/world/:worldId/_guide/:entryId` | `features/worlds/presentation/guide_screens.dart` |
| P11f | Lore, by kind | `…/world/:worldId/_guide` | `features/worlds/presentation/guide_screens.dart` (`LoreScreen`) |
| P11h | Reveal, asked once | (a sheet over the page) | `features/worlds/presentation/guide_widgets.dart` (`askReveal`) |

## A world's newer edition (P12, built)

SPEC-058 R-30 – R-36, ArkePlayer #3. Arke's list is the shipped one or the one fetched from
`arkeWorldsList` (`HostedCatalogue`, at most once a day), whichever has the higher serial
(`newestCatalogue`); an installed world whose fingerprint is not its entry's has an update
(`hasUpdate`, `worldUpdateProvider`). `WorldInstaller.update` downloads and checks as an install,
then replaces as P10, after the world stops playing.

| Frame | Screen | Route | File |
|---|---|---|---|
| P12a | `Update` on the installed world's card, in Discover and Library | `/discover`, `/library` | `features/worlds/presentation/discover_screen.dart`, `features/library/presentation/library_screen.dart` |
| P12b, P12c, P12d, P12f | The world's page: Update, New edition and Space; updating in place; updated; refused | `…/world/:worldId` | `features/worlds/presentation/world_screen.dart`; `features/worlds/application/worlds.dart` (`InstallController`) |
| P12e | Downloads: `Updating · n%` under Worlds | `/downloads` | `features/downloads/presentation/downloads_screen.dart` |

## Check for updates now (P13)

The owner requested manual checks on 22 October 2026. The existing Worlds header gains its
shared round press; automatic checks remain daily. `CatalogueCheckController` waits for any
startup check, forces a fresh hosted-catalogue fetch, then invalidates the shared catalogue.
Failure keeps the list visible and permits an immediate retry. No world downloads automatically.

| Frame | Screen | Route | File |
|---|---|---|---|
| P13a–P13f | Manual check: idle, checking, checked and failed; phone, tablet and desktop — in Discover's head since P15 | `/discover` | `features/worlds/presentation/discover_screen.dart`, `features/worlds/application/worlds.dart`; `arke_world` `hosted.dart` |

## A picture made for the screen (P14, built)

Approved on 23 October 2026 with Studio 235 (SPEC-058 R-37 – R-40, ArkePlayer #8). A listening picture
may name `tall`, the same moment at 9:16. A phone in portrait shows it over the whole screen, cover
fit about the focus, on P14's foot scrim. Everything else shows the Wide picture as P5a and P6f do.

| Frame | Screen | Route | File |
|---|---|---|---|
| P14a, P14b | Audiobook on a phone, a Tall picture, Text off and on | `/open/:itemId` | `features/players/presentation/audio_player_screen.dart`, `picture_of_the_moment.dart`; `features/players/application/listening_plan.dart`; `arke_world` `listening.dart` |

## Discover, a world's kinds, and chapters released over time (P15, built)

Approved on 24 October 2026 with Studio 236 (SPEC-058 R-43 – R-56, SPEC-059 R-24 – R-34). Worlds
became Discover beside Library; a world comes as its edition and a part per release, each pinned in
Arke's list (`CataloguePart`, `CatalogueEdition.parts`) and installed as one (`WorldInstaller.install`
with parts, `installPart`, `LibraryWorld.parts`); a narration plays its edition's chapters then each
part's (`installedListening`, `loadListeningPlan`). A part arrives when the app opens or comes back
(`PartsController`, Wi-Fi only from You), and with a world's Notify on, a daily background check
(`dailyCheckDispatcher`, workmanager) fetches it ahead into `parts-inbox/` and tells of it
(`Notices`, flutter_local_notifications); the app adds it on its next check. Every row was one 16:9
tile, 240 on a phone and 300 on a Fold, until P16 gave rows their own sizes (below).
`test/shoot_discover_test.dart` renders the frames with `SHOOT=1`.

| Frame | Screen | Route | File |
|---|---|---|---|
| P15a, P15b, P15l | Discover: New chapters, Stories, Teasers, Worlds under the chips; on a Fold | `/discover` | `features/worlds/presentation/discover_screen.dart`; `features/worlds/application/discover.dart` |
| P15c, P15d | A world's page by kind, each head counted, one tile | `…/world/:worldId` | `features/worlds/presentation/world_screen.dart` (`_Groups`), `guide_widgets.dart` |
| P15e, P15f | A production released a chapter at a time: schedule, New, each part chapter's day, the next date dashed | `…/world/:worldId/:productionId` | `features/worlds/presentation/production_screen.dart` |
| P15g | Home: Continue with New, the installed worlds' New chapters, Discover | `/` | `features/home/presentation/home_screen.dart` |
| P15h | Library: Worlds with New or Update, then Added, under Discover's chips | `/library` | `features/library/presentation/library_screen.dart` |
| P15i | A new chapter, on the lock screen | (a notification) | `features/parts/application/notices.dart` |
| P15j | Notify, per world, in its ⋯ | (a sheet over the page) | `features/worlds/presentation/world_widgets.dart` (`showWorldMenu`, `setNotify`) |
| P15k | Downloads: a chapter arriving or waiting under Worlds | `/downloads` | `features/downloads/presentation/downloads_screen.dart`; `features/parts/application/parts.dart` |
| (P15 rule 4) | A picture or clip teaser, full screen; a clip with sound | (over the tabs) | `features/worlds/presentation/discover_screen.dart` (`TeaserScreen`) |

## Rows of different sizes and the pill (P16, built)

Approved on 24 October 2026 with calls 14 – 16 (SPEC-058 rev 9). Each row is one size and one shape
and the page mixes rows (`RowSizes`, `rowTileWidth`): the feature, posters, wide tiles, small
posters and a world's band. A poster shows a production's Tall cover, the list's `tall`, bundled
with the app; without one, its Wide whole over its blur (`WholeOverBlur`). The list names the
feature and the band (`Catalogue.feature`, `Catalogue.band`, `listPicksProvider`); without them
`discoverFeature` and `discoverBand` choose. The tabs are a pill floating over the page on a phone
and a Fold, the rail gone; a page gets its room as bottom padding (`footRoom`), the dock floats above
it, and sheets rise on the root navigator so the pill never covers them. `test/shoot_p16_test.dart`
renders the frames with `SHOOT=1`.

| Frame | Screen | Route | File |
|---|---|---|---|
| P16a – P16c, P16f, P16g | Discover: the feature, New chapters wide, Stories as posters, Teasers as small posters, a world's band, Worlds; on a Fold the feature wide | `/discover` | `features/worlds/presentation/discover_screen.dart`, `row_widgets.dart` (`FeatureCard`, `PosterTile`, `WorldBand`, `BandPress`); `features/worlds/application/discover.dart` |
| P16d, P16e | A world's page: Listen and Read as posters, Watch and Play wide, Characters as small upright posters, Places wide | `…/world/:worldId` | `features/worlds/presentation/world_screen.dart` (`_Groups`), `guide_widgets.dart` (`GuideSections`) |
| P16h – P16j | The tabs as a pill; the dock floating above it; on a Fold in the rail's place | (every tab) | `app/shell/adaptive_shell.dart` (`TabPill`), `features/players/presentation/dock.dart` |

## Music (P17, built)

Approved on 24 October 2026 with calls 17 – 20 (SPEC-058 rev 11, R-72 – R-78; SPEC-059 R-37,
R-38). A world's music is a production published alone beside its edition: installed with the
world, arriving later with the parts check (`addMissingParts`), and its `Update` pressed by hand
(`productionUpdateProvider`, `productionInstallProvider`). It has its own group, `TakenAs.music`,
after Listen and never a chip, in square tiles (`SquareTile`, `RowSizes.square`). An album plays in
the audio engine as one queue on one clock (`AudioEngine.openMusic`, `MusicAlbum`), keeping no
place; no library item stands for it, so it never joins Continue. `test/shoot_p17_test.dart`
renders the frames with `SHOOT=1`.

| Frame | Screen | Route | File |
|---|---|---|---|
| P17a | A world's page: `Listen · Music · Watch · Play · Read`, Music as squares | `…/world/:worldId` | `features/worlds/presentation/world_screen.dart` (`_Groups`), `row_widgets.dart` (`SquareTile`) |
| P17b | Discover: a Music row after Stories; a song as a teaser | `/discover` | `features/worlds/presentation/discover_screen.dart` (`TeaserScreen` plays a song's excerpt) |
| P17c, P17h | An album's page; on a Fold the cover beside the title, two columns, More from | `…/world/:worldId/:productionId` | `features/worlds/presentation/album_screen.dart`; `features/players/presentation/music_widgets.dart` (`TrackRow`) |
| P17c | The dock: the track over its album, Next in place of back 15 | (every tab) | `features/players/presentation/dock.dart` |
| P17d, P17e | A song playing: shuffle, previous, next, repeat, Lyrics, Tracks, the Heard in chapter | `/music/:worldId/:productionId` | `features/players/presentation/music_player_screen.dart`; `features/players/application/audio_engine.dart`, `music.dart` |
| P17f | A character's or place's Theme under its Voice | `…/world/:worldId/_guide/:entryId` | `features/worlds/presentation/guide_screens.dart` (`SongRow`) |
| P17g | A story's Music; a chapter holding a song carries a note | `…/world/:worldId/:productionId` | `features/worlds/presentation/production_screen.dart` |
| (R-72) | Downloads: a production package arriving or waiting | `/downloads` | `features/parts/application/parts.dart` (`PartArrival.production`) |

## A world already in Library (P10, approved, not built)

SPEC-058 R-21, with adding a world package from a file (ArkePlayer #1). Not built.

| Frame | Screen | Route | File |
|---|---|---|---|
| P10a, P10b | Another edition: Replace; the same edition: Already in Library | `/add` | `features/add_file/presentation/` |

## Rules already in code

| Rule | Where | Test |
|---|---|---|
| P16 rule 9, call 16: the tabs a pill, 358 × 64 on a phone and 520 on a Fold, in place of P1 rule 3's bar and P6 rule 5's rail | `app/shell/adaptive_shell.dart` | `test/shell_test.dart` |
| P11 rule 1, P15 rule 1: five tabs, Discover second | `app/shell/adaptive_shell.dart` | `test/guide_test.dart` |
| P11 rule 7, SPEC-059 R-20: a chapter is reached once its start is passed, heard or read; Reveal shows a production up to that chapter | `arke_world` `reach.dart`, `arke_library` `store.dart` | `guide_test.dart`, `store_test.dart`, `test/guide_test.dart` |
| P1 rule 6, P15 rule 3, P17 rule 2: Listen · Music · Watch · Play · Read, empty groups absent; Music under the Listen chip | `features/production/domain/production_kind.dart` | `test/domain_test.dart`, `test/music_test.dart` |
| P17 calls 19 and 20: lyrics as written, by stanza, without structure tags; a song keeps no place | `features/players/application/music.dart` (`lyricStanzas`, `MusicAlbum.asItem`) | `test/music_test.dart` |
| SPEC-058 R-72: production packages installed beside the edition, arriving later, updated when pressed, carried to a new edition | `arke_world` `install.dart`, `catalogue.dart`; `arke_library` `store.dart` (`addProduction`) | `production_install_test.dart`, `test/music_test.dart` |
| P16 rule 1 (replacing P15 rule 10): each row one size — the feature 358 × 476, posters 172, wide 240, small posters 112; on a Fold 424 high, 260, 300, 160 | `features/worlds/presentation/row_widgets.dart` (`RowSizes`), `world_widgets.dart` (`rowTileWidth`) | `test/discover_test.dart` |
| P16 calls 14 and 15: a production's Tall cover; the list's feature and band | `arke_world` `catalogue.dart`; `features/worlds/application/discover.dart` | `catalogue_test.dart`, `test/catalogue_test.dart`, `test/discover_test.dart` |
| SPEC-058 R-52: a chapter a part brought after install is New until it plays | `arke_library` `shelves.dart` (`newChapters`, `placeIsNew`, `worldHasNew`) | `part_install_test.dart`, `test/discover_test.dart` |
| P2 rule 6: every asset checked before play | `arke_publication` `verify.dart` | `verify_test.dart` |
| P2 rule 8: unknown profiles refused | `arke_publication` `manifest.dart` | `manifest_test.dart` |
| P6 rule 3: device settings and their defaults | `features/settings/domain/device_settings.dart` | `test/domain_test.dart` |
| P7 rules 1–3: formats, their players, DRM refused, `Add N` | `arke_publication` `probe.dart`, `features/players/domain/player_kind.dart`, `features/add_file/domain/added_file.dart` | `probe_test.dart`, `test/domain_test.dart` |
