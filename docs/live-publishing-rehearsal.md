# Live development reader acceptance

`apps/arke_player/integration_test/publishing_formats_dev_test.dart` is an opt-in
Android test for the synthetic Paper Garden fixtures in AONIK #403. It runs the
real app, receives new standalone productions through its foreground check, follows the visual novel's friend
choice, turns the comic to page 2, reopens both from their Continue presses with
Dart HTTP creation denied, and reloads the on-device library to check persistence.
The base audiobook/part position and unrelated worlds must remain unchanged.

This is separate from the normal offline unit/widget suite. It refuses to start
without `ARKE_LIVE_PUBLISHING_REHEARSAL=true`, the development channel, Android,
and the already-installed `paper-garden-dev-403` base/part. It makes no publishing
or approval request and uses no account credentials. The fixed fixture IDs and
choice/page assertions deliberately prevent running against arbitrary content.

Prepare the original synthetic base, artwork-free audio part, visual novel and
graphic novel through the Studio/AONIK dev workflow first. The install phase
requires all four in the live catalogue (serial at least 12); the withdrawn phase
requires the world absent (serial at least 15) and its downloads still present.
Those serials belong to this recorded rehearsal, not a general production rule.

## Device procedure

Use Flutter 3.41.3. Back up the dev app's **entire private files and preferences**
before replacing an APK and verify sufficient device space. Never uninstall or
clear data to solve an install failure. `flutter test -d` and ordinary `flutter
drive` can automatically uninstall after a failed install, even for insufficient
space; do not use that launch path with a library that must be preserved.

From `apps/arke_player`, build without installing:

```sh
flutter build apk --profile --target=integration_test/publishing_formats_dev_test.dart \
  --target-platform=android-x64 \
  --dart-define=ARKE_CATALOGUE_CHANNEL=development \
  --dart-define=ARKE_LIVE_PUBLISHING_REHEARSAL=true
```

Choose the ABI of the test device. Verify the APK's application ID is
`studio.arke.player.dev`. Install using `adb -s <device> install -r <apk>` and
**stop if it fails**. Launch the dev activity, read its Dart VM service URI from
the app's log, and forward that device TCP port to an available local port.
Connect without invoking an installer:

```sh
flutter drive --profile --driver=test_driver/integration_test.dart \
  --use-existing-app=http://127.0.0.1:<forwarded-port>/<service-path>/
```

The service URI is temporary and stays local. The test's result is also written
to `files/arke-worlds-dev/publishing-formats-install.json`. A failed assertion
does not produce a passing evidence file. Preserve runner logs as well.

After the operator withdraws comic, story and the part through the normal
exact-edition endpoints (the part withdrawal also retires the base sequence), repeat with
`--dart-define=ARKE_REHEARSAL_PHASE=withdrawn`. This writes
`publishing-formats-withdrawn.json`. The test does not withdraw anything itself.
Keep the full private-directory backup and use the same replace-only install
procedure. Finally restore the normal dev APK, preserving data.

## Scope

HTTP denial covers these installed Dart readers; it is not a physical-radio or
OS-background-scheduler test. The test uses real widget gestures, native plugins,
file-backed media and library services, with no provider overrides. Emulator
results do not qualify physical devices, interactive-movie video, OS notification
delivery, or a nontechnical creator/reviewer pilot. The AONIK runbook records
package provenance, release/withdrawal operations and any device interruptions
separately.
