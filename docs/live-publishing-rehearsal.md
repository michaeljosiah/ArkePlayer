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

## Native interactive movie (AONIK #403, Player #73)

`integration_test/publishing_movie_dev_test.dart` is separately opt-in with
`ARKE_LIVE_MOVIE_REHEARSAL=true` and the development channel. It is pinned to
Motion Garden's exact synthetic archive. It uses the real app, normal Start install,
native `VideoPlayer` controllers, real widget gestures and file-backed saves. No
provider, HTTP or media fake is installed. The install phase verifies all three clips and both
choices/endings and leaves a mid-scene friend-route save. Android screenshots and
native controller positions are written beneath `files/arke-worlds-dev/movie-evidence`.
An interrupted playback run can use the existing verified installation and the ending's
ordinary Start again control; it never injects a saved position or clears the library.

The live run also exposed #75: a late final-frame decoder load could pause the clip
selected from a new choice. Native reel requests are serialized and stale requests cannot
seek, play or pause the latest scene. A delayed-load regression fails on the old code and
passes with the repair; the native replay exercises Back to last choice and the same branch again.

Build with the same profile/ABI and replace-only procedure above, changing the target
to this test and the opt-in define to `ARKE_LIVE_MOVIE_REHEARSAL=true`. Connect the
existing VM service with the same driver. The test-control file
`files/arke-worlds-dev/movie-rehearsal-phase.txt` selects `install` (default), `offline`,
`refresh` or `withdrawn`. This file is test orchestration, not a saved library record.

After `install`, back up all app files, disable both emulator radios, verify no default
network, force-stop and launch the same APK with `offline`. It checks Continue resumes
the saved native video time and route, observes advancement and pauses again. Restore
networking, withdraw through AONIK's normal authorised workflow, and run `refresh` to
check a newer catalogue without this world. Disable radios and cold-start `withdrawn`
to repeat retained playback. Restore networking and the normal dev APK in place.
Each pass file is written only after all assertions. Record the OS network observations
separately; a phase named `offline` does not itself disable connectivity.
If a test interruption leaves the movie at its ending, the optional `replay` phase uses
Continue, Back to last choice and the friend choice to prepare a new paused position.
Then repeat the cold `withdrawn` phase. It does not seed, restore or edit a saved position.

The first movie batch used a fresh 12 GiB Android 16 emulator after the older device
refused replacement for insufficient storage. Its original library remained byte-identical.
Record Windows capture failures separately from on-device screenshots and native decoder
results; emulator evidence does not qualify physical Android or iOS.

## Android background chapter notices (P15i)

Use an ordinary dev APK and a separate synthetic world with one installed audio
chapter. Keep the earlier reader-progress checkpoints. Confirm Notify defaults
off, deny the first Android permission request, and check that no daily work is
scheduled. Grant the subsequent request and check that one uniquely named daily
WorkManager task exists with the Wi-Fi-only constraint.

Background the app before publishing the verified next part through AONIK. For
an accelerated rehearsal, stop the background dev process, back up all private
directories, and advance only its WorkSpec `last_enqueue_time` and hosted-cache
`fetchedAt` into the past. Preserve task identity, interval, inputs and constraints;
do not change the device clock or another app. Invoke the real Android scheduler
job. This qualifies the native worker, not a natural 24-hour wait or OEM scheduling.

Before tapping the notification, verify that the complete library index is
unchanged, the inbox ZIP matches the approved archive, and the single notification
names the correct world, chapter and production. A repeated check must not notify
again for an existing inbox ZIP. Tapping must open the named production, import
the part once and consume the inbox without changing other worlds' saved places.
Exercise both a warmed background engine and a cold process, then turn Notify off
and verify the daily job is cancelled. Withdraw the dev publication and retain
the downloaded material for the offline/retention checks.

The 9 November rehearsal exposed two linked startup failures: audio-service plugin
registration warmed the main engine during a worker, allowing Home to install the
part prematurely; a cancelled worker could also strand the early media handshake.
`main()` now waits for the first resumed lifecycle before media/UI initialization.
Already-started playback is unaffected by later pauses. The AONIK evidence record
distinguishes the failed attempts, corrected reruns, timing acceleration and the
emulator-only scope.
