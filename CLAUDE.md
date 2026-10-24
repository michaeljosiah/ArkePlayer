# Working in this repo

Arke Player is the phone and tablet app for what Arke Studio makes. Flutter, a Dart pub workspace, Android and iOS. Read [README.md](README.md) for the layout and [docs/architecture.md](docs/architecture.md) before changing structure.

## The current goal

The MVP, [docs/mvp.md](docs/mvp.md): your own audio, books and films, with no account and native players (ADR 0004), plus the worlds Arke publishes, installed from Available (P9, ADR 0005, [docs/world-package.md](docs/world-package.md)). Work in its milestone order, M0 to M6. Don't build sign-in, shares or package import until the MVP is done; where the design needs an account or a world, leave that part absent rather than disabled.

## The design comes first

The design is in this repository: `design/Arke Player.dc.html` (turns P1–P9), written by `node design/build.mjs` from `design/frames.mjs`, `design/view.mjs` and `design/frames.css`, and gated by `node design/check.mjs` in CI. Every screen here implements frames there; [docs/design-map.md](docs/design-map.md) says which. Before building a screen:

- Open the frames it names, and read its turn's rules.
- Match the frames' sizes, order and words.
- A screen that needs something the design does not draw gets a design turn first (P9, P10… — never a Studio `t` number), not an improvised UI. Add the turn to `design/frames.mjs` and `design/build.mjs`, rebuild, run `node design/check.mjs --record`, then shoot every frame and look at it before asking for approval.
- Frames type through the tokens only (`var(--text-*)`, `var(--type-*)`); a raw `font-size` fails the check. Pictures go in `design/assets`, recompressed.

Cite design as `P3c` or `P2 rule 6` in code and commits. Studio turns are `Studio 156`.

The house rules carry over from the Studio:

- **Labels over sentences.** No caption under a control, no sentence under a title.
- **A refusal is one clause**: `Protected file`, `3 files do not match`.
- Small lines are data only: a size, a count, a time. Never a promise about what will or will not happen.

## Toolchain

Flutter 3.41.3 / Dart 3.11.1. On this machine Flutter lives in another repository: `C:\Users\mjosi\source\repos\aonik\.tools\flutter\bin`. Use it, or install the same version. Run everything from the workspace root unless a command says otherwise:

```
flutter pub get                                     # the whole workspace, one lockfile
dart format --output=none --set-exit-if-changed .   # 160 columns, set in analysis_options.yaml
dart analyze --fatal-infos                          # strict casts, inference and raw types
cd packages/arke_publication && dart test        # likewise arke_library, arke_media, arke_world
cd apps/arke_player && flutter test
```

CI runs exactly these on ubuntu-latest. `dart format` uses the page width from `analysis_options.yaml`. Don't pass `--line-length`.

## Structure rules

- **Pure rules go in packages, not the app.** `arke_publication` has no Flutter dependency: manifests, verification, format probing. Anything that can be tested without a widget belongs in a package.
- **Feature-first app.** `lib/features/<area>/{domain,application,presentation}`, as in the owner's other Flutter app (`aonik/apps/payabo_mobile`). The app-wide parts are in `lib/app/`: router, theme, shell. Riverpod 3 for state, go_router for routes, and paths are built only in `lib/app/router/routes.dart`.
- **Tokens, not literals.** Colours, type sizes, radii and the bands (600, 1100) come from `lib/app/theme/tokens.dart`, which mirrors the Studio's design tokens. Change the Studio's token first.
- **No placeholder screens.** The MVP's routes are only what is built (`lib/app/router/routes.dart`); a designed screen that is not built has no route.

## Things that must stay true

- **The Player never opens a world's source.** It plays publications: frozen editions with their own manifest. Nothing in it edits, generates or spends.
- **Nothing in a package plays before every asset matches its manifest** (`verifyPublication`). A standard file is opened and read before it is added. A refusal deletes the copy, and nothing is added half-way.
- **The players are the Studio's own modules wherever one exists**: interactive, visual novel, audiobook. They are hosted in a web view, so a package plays the same here as in a browser (ADR 0001). Don't write a second copy of one in Dart.
- **Every setting is this device's.** Nothing is uploaded to an account, and an added file is never uploaded.
- **Accounts are a seam.** `ArkeCloud` has one implementation today, `NoArkeCloud`. Don't scatter cloud calls through the screens.

## Publishing a world (Available and Update)

Arke's list of worlds is `apps/arke_player/assets/worlds/catalogue.json`, shipped in the app and
also published on the public ArkeStudio release `arke-player-worlds`, which phones fetch at most
once a day (SPEC-058 R-30 – R-36, P12). Of the two, a phone keeps the higher `serial`. Details are
in [docs/world-package.md](docs/world-package.md); the Studio half — the export and its upload — is
in ArkeStudio's CLAUDE.md. **Ask the owner before any public upload.**

1. **The package** is the Studio's Export → Arke Player (ArkeStudio `scripts/export-arke-player.mts`
   on a copy of the world), uploaded under a new file name to the world's public ArkeStudio
   release. A published package is never replaced.
2. **Pin it:** `dart run arke_world:pin_world <package.zip> <its https url>` (from
   `packages/arke_world`). It reads the package as the Player does and prints `url`, `byteLength`,
   `sha256`, `edition` and `fingerprint`. Paste that as the world's `package` in the list, keep its
   `keyArt` and `picture` paths (bundled assets; a fetched list takes its pictures from the app),
   and update the production's kind line (`Audiobook · Book · 5 h 33 m`). A world with a public
   Guide also has a guide alone (the export script's `--guide-alone`, SPEC-059 R-10): upload and
   pin it the same way and paste it as the world's `guide`, beside `package`.
3. **Raise `serial`** by one. A list whose serial is not higher is ignored by every phone.
4. **Gates, commit, push**, as for any change: the app's tests guard the shipped list.
5. **Publish the list:** `gh release upload arke-player-worlds apps/arke_player/assets/worlds/catalogue.json --clobber --repo michaeljosiah/ArkeStudio`.
   It is the one file replaced in place. Check that
   `https://github.com/michaeljosiah/ArkeStudio/releases/download/arke-player-worlds/catalogue.json`
   is byte-identical to the commit. The release is never marked Latest.

Installed phones show `Update` once they fetch the list; new installs and the next build ship it.

**A part** (Release · New chapters, SPEC-058 R-46) is published the same way: uploaded under its own
name, pinned with `dart run arke_world:pin_world <part.zip> <https url> --follows <the entry's
package fingerprint>`, its printed `part` appended to the entry's `package.parts` and its
`production` (id and schedule) set on the listed production, then `serial` raised and the list
published. Phones fetch it on their own; a new edition empties `parts`. See
[docs/world-package.md](docs/world-package.md#releasing-new-chapters-as-a-part-spec-058-r-43--r-56-p15).

## Specs

The ArkeStudio specs are a private sibling repository (`arke-studio-specs`). Cite them by id (`SPEC-048`), never by path. If a spec isn't present, say you can't read it rather than reconstructing it.
