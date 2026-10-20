# 0001 · Host the Studio's players in a web view

**Status:** accepted 20 October 2026. This was the owner's call 2 on the design master, approved with P1–P7.

## Decision

Where the Studio already has a player — the interactive player (Studio 156), the visual novel (Studio 174) and the audiobook (Studio 186, 211, 212) — Arke Player hosts that same framework-free module in a web view (`WebPlayerHost`). It does not rewrite the module in Dart.

Studio 156 binds "one player, two homes": the preview in the Studio and the exported `player.html` are one piece of code. The Player becomes the third home. A package then plays the same in a browser, in the Studio and in the Player, and a fix in one is a fix in all three.

The Player adds only two things around a hosted module:

- its own close
- the phone's media session: lock screen and headset controls, background audio, picture in picture, casting

Players with no Studio module are native: the micro drama feed, the audio drama transcript, the EPUB reader and the PDF/CBZ page viewer.

## Work this creates in ArkeStudio

The modules need a small bridge, added once in the shared player code (`packages/contracts/src/audiobook-player.js` and the interactive player module):

- Post `{type: "place" | "ended" | "close", …}` to `window.ArkePlayer.postMessage` when that channel exists. A browser has no such channel and ignores it.
- Accept `window.arkePlayer.restore(place)` to resume where this device left off.

## Risks to settle first, in a spike, before any player screen is built

1. **Background audio and the lock screen on iOS.** WKWebView audio pauses when the app leaves the foreground unless the app holds an audio session, and its Media Session API support differs from Android's WebView. The spike plays a packaged audiobook with the screen locked on an iPhone and on the Fold7, and drives it from the lock screen and a headset. If the web view cannot keep playing, audio moves to a native engine (`just_audio` with `audio_service`) and the module keeps the picture, the words and the chrome, driven by the native clock.
2. **Picture in picture and casting for video.** These are native features. If a hosted film cannot hand its video element over, films play natively with Studio 156's chrome redrawn, and the decision is recorded here.
3. **Licence.** ArkeStudio is AGPL-3.0-only. Shipping its player modules inside an app-store binary brings AGPL obligations into an environment whose terms are widely held to conflict with them. The owner holds the copyright and can license the modules differently. That decision is owed before the first store build, not before development.

## Rejected

- **Dart rewrites of every player.** Two players to keep alike by hand is what Studio 156 exists to prevent, and a package would play differently on the phone than in the browser.
- **A browser-only Player.** It loses the library, offline downloads, the file system, the share sheet and the lock screen, which are what a phone app is for.
