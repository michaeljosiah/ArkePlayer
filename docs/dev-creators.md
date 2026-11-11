# Android Player Dev

Use **Arke Player Dev** for the invited-creator dev catalogue. It installs as
`studio.arke.player.dev`, alongside the ordinary Player, and keeps its library, preferences,
progress and background jobs separate. It requires no reader account.

The **Package Player Dev (Android)** Actions workflow produces `ArkePlayerDev-Android` with a
universal `ArkePlayerDev.apk` for Android phones and emulators, `SHA256SUMS.txt` and the source
commit in `build-info.txt`. It is signed with the existing stable CI test key, so later Dev
builds can update the app while retaining downloaded works and progress. A missing signing key
fails the distributable build instead of silently generating a different key.

Check the checksum and install the APK. For later updates, install over the same Dev application;
do not uninstall or clear its data. The existing CI arm64 dev APK uses the same unsplit version
code convention and stable key. The production Player and its library are separate.

Open Available/Discover to fetch approved releases from `arke-worlds-dev`. Submitted or merely
approved editions are not available until the authorised publisher releases them. Installed
editions remain usable offline after withdrawal; withdrawal removes catalogue discovery and
cannot recall previously downloaded copies. Do not treat the dev feed as private distribution.
