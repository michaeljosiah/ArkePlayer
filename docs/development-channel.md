# Isolated AONIK development channel

Player #50 retains P9/P12/P13/P15 screens and package readers. The default build
continues to use the production GitHub catalogue and existing device storage.
Android rehearsal builds select the fixed AONIK `arke-worlds-dev` endpoint:

```sh
cd apps/arke_player
flutter build apk --debug --dart-define=ARKE_CATALOGUE_CHANNEL=development
flutter test --dart-define=ARKE_CATALOGUE_CHANNEL=development test/catalogue_channel_test.dart
```

The Android application ID is `studio.arke.player.dev`, labelled **Arke Player Dev**.
The same Dart definition selects the native ID and the catalogue authority; unknown
or duplicate definitions refuse the build. Install it alongside production.
Do not uninstall production to run the rehearsal. Development is Android-only
until a separate iOS bundle ID and scheduler configuration are qualified.

Foreground discovery, manual checks and the background isolate read one profile.
Development ships an empty serial-zero baseline and has its own catalogue cache,
pictures, library, downloads/inbox, settings and daily task identity. Production
serials therefore cannot mask test serials. There is no runtime arbitrary URL field
or creator/admin token in the Player. Install and offline playback continue through
the existing pinned length/hash readers; unavailable, malformed, equal and older
feeds cannot replace a newer cached list. Forced refresh keeps its cache-busting
query and no-cache request.

Home starts the shared catalogue refresh, and the app opens on Home (P25). So a fresh
dev install with an empty bundled baseline shows a published world's cover and **Start**
once the hosted channel publishes it. An unavailable list leaves **Add a file** usable
in Library; nothing requires a local import before discovering hosted worlds.

For AONIK #403, record the exact APK commit/application ID, feed serial and package
pins, then discover, install, open the book, restart offline, publish an approved
part/update, force refresh and withdraw from discovery. Check background notification
delivery separately on Android; a unit test or successful HTTP fetch does not prove
the operating system's scheduler ran. Production catalogue migration and historical
rights review remain separate, and this build does not change the production feed.
