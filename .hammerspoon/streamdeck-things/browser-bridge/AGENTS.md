# browser-bridge

A Manifest V3 browser extension (Chrome and Firefox) that Hammerspoon
(`../streamdeck-media.lua`) talks to over a local WebSocket, so Stream Deck
keys can drive a specific web page (starting with Google Meet call control)
that has no real automation API of its own. In the protocol sections below,
"plugin" means that Hammerspoon-side server.

## Why this exists

Google Meet has no public real-time call-control API: the Meet REST API only
manages meeting metadata/artifacts, the Meet Media API (Developer Preview) is
raw audio/video I/O for bots, and the Meet Add-ons SDK only runs your own
code inside an iframe *within* the Meet tab — none of that is reachable from
an external native process. So this extension does what a person would do:
it runs a content script inside the real Meet tab and fires Meet's own
keyboard shortcuts / clicks its real buttons.

The extension itself is generic, not Meet-specific — it's a message router
between a local socket and whichever tab's content script registered for a
given site. Adding a new site later means adding a new file under
`content-scripts/`, a `matches` entry in `manifest.json`, and nothing else.

## Architecture

**Hammerspoon hosts the WebSocket server** (`hs.httpserver` in
`streamdeck-media.lua`); the **extension is the client** (`background.js`,
connects to `ws://127.0.0.1:17721/`). This was chosen over the other
direction (extension hosts a server, native messaging, etc.) because
Hammerspoon is already a long-lived native process — it owning the port is
simpler than registering a native-messaging host per browser, and it means
the extension can just be "load unpacked" with zero install step outside the
browser.

```
Stream Deck key press
  -> Hammerspoon hs.streamdeck -> ws server on 127.0.0.1:17721
  -> background.js (ws client, routes by "site")
  -> content script registered for that site (e.g. meet.google.com)
  -> dispatches a keyboard shortcut / clicks a button on the real page
```

## Wire protocol

Plugin -> extension (`type: "command"`, forwarded to the registered tab's
content script):
```json
{ "id": "1", "type": "command", "site": "meet.google.com", "action": "toggleMic", "params": {} }
```

Plugin -> extension (`type: "focusTab"`, handled directly in `background.js`
— *not* forwarded, since a page's own content script can't raise its
browser window or switch tabs; that's an extension-privileged
`chrome.tabs`/`chrome.windows` operation):
```json
{ "id": "2", "type": "focusTab", "site": "meet.google.com" }
```

Extension -> plugin, one of:
```json
{ "type": "hello", "extension": "streamdeck-bridge", "version": "0.1.0" }
{ "type": "result", "id": "1", "ok": true, "data": null, "error": null }
{ "type": "result", "id": "1", "ok": false, "data": null, "error": "no open tab registered for \"meet.google.com\"" }
{ "type": "event", "site": "meet.google.com", "event": "micStateChanged", "data": { "muted": true } }
```

`site` is a bare hostname (`URL(tab.url).hostname`), matched against
whichever content script last called `register` for that hostname. Only one
tab per site is tracked at a time (last-registered wins) — fine for a single
active call, not for driving two Meet tabs at once.

## Site handler contract (`content-scripts/*.js`)

Each content script:
- Calls `chrome.runtime.sendMessage({ type: 'register', site })` on load and
  every ~20s after (the re-registration is also what re-establishes the
  socket if the background worker got evicted — see below).
- Listens via `chrome.runtime.onMessage` for `{ type: 'command', action,
  params }` and replies via `sendResponse({ ok: true, ... })` or
  `sendResponse({ error: "..." })`.
- May proactively push `chrome.runtime.sendMessage({ type: 'event', event,
  data })` at any time (e.g. state changes noticed via a `MutationObserver`).

## Google Meet actions (`content-scripts/google-meet.js`)

- `toggleMic` — dispatches Meet's own mic shortcut (⌘D / Ctrl+D). Meet binds
  this globally and doesn't check `event.isTrusted`, so a synthetic
  `KeyboardEvent` works and is more resilient to Meet's DOM/class churn than
  clicking a toolbar button would be.
- `toggleCamera` — same idea, ⌘E / Ctrl+E.
- `hangUp` — clicks the button matching `aria-label` `/leave call/i`. No
  keyboard shortcut exists for this one.
- `thumbsUp`/`heart`/`celebrate`/`clap` — send Meet's 👍/💖/🎉/👏
  reactions, all through one shared `sendReaction(emoji)`. Note `heart` is
  💖 (sparkling heart, U+1F496), not the more obvious ❤️ - confirmed live
  from real markup, not a guess. Meet has no keyboard shortcut for
  reactions, so each is a two-step click: the `/send a reaction/i` toolbar
  button opens the tray, then `waitForElement` polls for
  `` button[data-emoji^="<emoji>"] `` (tag-scoped, since each reaction is a
  real `<button data-emoji jsaction="click:...; mousedown:...;
  mouseup:...;">` wrapping a decorative `<img>` with the *same*
  `data-emoji` — an untagged selector risked resolving to the img) and
  `dispatchClickSequence`s it (mousedown → mouseup → click, not a bare
  `.click()` — confirmed live that jsaction's send action needs the
  down/up pair, not click alone). `^=` rather than `=` as cheap insurance
  against a variation-selector mismatch on whichever emoji end up
  unverified. Only `👍` and `💖`'s `data-emoji` values and the down/up/click
  requirement are confirmed against a live call; `🎉`/`👏` and the
  `/send a reaction/i` open-button pattern are inferred the same way the
  rest of this file is - see **Not yet verified** below. This is the first
  async action handler - `onMessage` now always resolves `sendResponse`
  through a
  `Promise.resolve().then(handler)...` chain and returns `true` to keep
  the channel open, so the sync actions above respond one microtask later
  than before but otherwise work exactly as they did.
- Emits `micStateChanged: { muted: bool }` whenever the mic button's
  aria-label flips between "Turn on microphone" / "Turn off microphone" —
  lets a Stream Deck key's icon reflect someone muting from the on-screen
  toolbar instead of the deck. `findButtonByLabel` must match the full
  `/turn (on|off) microphone/i` phrasing, not a bare `/microphone/i` — Meet's
  toolbar also has a "Camera & microphone settings" button, and DOM order
  isn't guaranteed to put the real toggle first. A bare pattern can latch
  onto that settings button, silently stop matching "turn on"/"turn off",
  and freeze the reported mic state (this was a real bug: the key color
  never updated because the wrong button was being watched — fixed by
  tightening the pattern; see the analogous camera comment below, which
  already had this hardening).
- Emits `cameraStateChanged: { off: bool }` on the same principle as
  `micStateChanged`, watching the camera button's aria-label flip between
  "Turn on camera" / "Turn off camera".
- Emits `callStateChanged: { active: bool }` whenever the leave-call button
  (present only once actually joined, not on the pre-join lobby screen)
  appears or disappears — lets the native side show a "Meet is active"
  indicator independent of mic/camera state. Detected via a `childList`
  mutation (joining/leaving adds/removes the whole toolbar, not an
  attribute change on an existing button), watched by the same observer
  `checkMicState` already uses.

Known fragility: this all rests on Meet's current keyboard shortcuts and
English aria-label text, neither of which is a documented/stable contract.
If Meet ships a UI change and this stops working, that's the first thing to
re-check (inspect the mic/camera/leave buttons' current `aria-label`s).

## Microsoft Teams (`content-scripts/teams.js`)

Detection only, no actions yet — this site handler exists purely to answer
"is a call active" for a Stream Deck status light, unlike Meet's full
toggleMic/toggleCamera/hangUp set.

- Emits `callStateChanged: { active: bool }` based on whether a button
  matching `/hang up|leave/i` is present, same `childList`-inclusive
  MutationObserver technique as Meet's `checkCallState`.
- **Unverified against a live call** — the aria-label pattern is a
  best-effort guess, not confirmed against Teams' actual DOM. If it never
  fires, inspect the real hang-up button's `aria-label`/`data-tid` in
  DevTools during a call and fix the pattern.
- No action handlers exist yet, but adding `toggleMic`/`toggleCamera`/
  `hangUp` later is low-risk if wanted: Teams' global keyboard shortcuts are
  official and documented (Cmd/Ctrl+Shift+M / O / H — see
  support.microsoft.com/en-us/accessibility/teams/keyboard-shortcuts-for-microsoft-teams),
  unlike the guesswork detection above.
- Desktop Teams (the native app) is a separate, harder problem handled
  outside this extension — see `../streamdeck-media.lua`. Microsoft deprecated the old third-party
  meeting-status API; the well-known log-scraping technique
  (github.com/mre/teams-call) only works against the old, non-sandboxed
  Teams client, not the current `com.microsoft.teams2` sandboxed rewrite.

## Files

- `manifest.json` — MV3 manifest. Declares `service_worker` *and* `scripts`
  in `background` so the same file works on Chrome (reads `service_worker`)
  and Firefox 121+ (reads `scripts`, ignores `service_worker`).
- `background.js` — the router described above.
- `content-scripts/google-meet.js` — the Meet handler.
- `content-scripts/teams.js` — the Teams web app handler (detection only).
- `tools/render-icon.swift` — SF-Symbol icon renderer (run with `swift
  tools/render-icon.swift <symbol> <pointSize> <pixelSize> <hexColor>
  <outPath>`); regenerated the `icons/*.png` toolbar icons (symbol
  `antenna.radiowaves.left.and.right`, `#4C6FFF`, sizes 16/32/48/128 — the
  standard WebExtension toolbar icon set, not Stream Deck's convention).
- `tools/dev-bridge-server.js` — dependency-free WebSocket test server
  standing in for Hammerspoon's server. Stop Hammerspoon's listener first
  (they share port 17721). Run with `node tools/dev-bridge-server.js` (use
  the mise Node at `~/.local/share/mise/installs/node/24.18.0/bin/node` —
  brew's is broken), then load the extension and type a JSON command line to
  send it. Single-frame/no-fragmentation only; a test tool, not a general WS
  server.
- `test/` — automated tests for `background.js` and the content scripts,
  run with `test/run.sh` (25 tests, no external deps). Each loads the real
  source file into a fresh `node:vm`
  context per test, with hand-rolled fakes (`test/fake-chrome.js`,
  `test/fake-websocket.js`, `test/fake-dom.js`) standing in for
  `chrome.*`/`WebSocket`/`document` — same "no npm dependency" style as
  `dev-bridge-server.js`. This is what actually gets exercised on every
  change; `dev-bridge-server.js` stays around for interactive poking against
  a real loaded extension. Gotcha hit while writing these: objects built
  inside the vm sandbox belong to a different realm than the test file's own
  object literals, so `assert.deepStrictEqual`/`node:assert/strict` reports
  structurally-identical objects as "not reference-equal" — `test-google-meet.js`
  uses the loose `node:assert` module instead, which doesn't compare
  prototypes.

## Installing for development

**Chrome/Edge/Brave**: `chrome://extensions` -> enable Developer mode ->
"Load unpacked" -> select this folder.

**Firefox**: `about:debugging#/runtime/this-firefox` -> "Load Temporary
Add-on" -> select `manifest.json`. Temporary add-ons unload on browser
restart; a permanent install needs either AMO signing or
`xpinstall.signatures.required=false` in Firefox Developer Edition/Nightly.

After loading, open `chrome://extensions` (or Firefox's equivalent) and
check the service worker/background page console for connection logs — it
retries every 30s via `chrome.alarms` if nothing is listening on port 17721
yet, so "not connected" before Hammerspoon/the dev-server is running is expected.

## Verified

- `node --check` passes on `background.js`, `content-scripts/google-meet.js`,
  and `tools/dev-bridge-server.js`; `manifest.json` is valid JSON.
- `test/run.sh` passes: 11 tests covering `background.js` (routing to the
  right tab, unregistered-site errors, a rejected `chrome.tabs.sendMessage`
  from a stale/navigated-away tab, content-script error responses, event
  relay tagged with hostname, tab-removal clearing its route, ignoring
  non-command messages, alarm-triggered reconnect, focusTab
  window/tab-activation and its unregistered-site error), 18 covering
  `content-scripts/google-meet.js` (registration, Mac vs. non-Mac shortcut
  modifiers for mic/camera, hang-up clicking only the right button, missing-
  button and unknown-action errors, mic-state-change dedup, camera-state-change
  dedup, mic/camera state each ignoring a decoy "Camera & microphone
  settings" button, call-state-change dedup, one `sendReaction` test per
  reaction (thumbsUp/heart/celebrate/clap) opening the tray then clicking
  the button it waits for - ignoring the decoy img with the same
  `data-emoji` - plus one shared missing-tray-button error test and one
  shared reaction-never-appears error test), and 2 covering
  `content-scripts/teams.js` (registration, call-state-change dedup).
- `tools/dev-bridge-server.js`'s handshake and frame parsing verified against
  a real Node `WebSocket` client round-trip: client `hello` (masked frame)
  parsed correctly by the server, and a server-sent `command` (unmasked
  frame) was received intact by the client.
- **Not yet verified**: `background.js` loaded into a real browser against
  a live Meet call — that needs a signed-in Google account and an actual
  call, which has to happen interactively. The `test/` suite covers the
  logic; it can't confirm Meet's actual current aria-labels/shortcuts
  still match what the content script assumes.
- `content-scripts/google-meet.js`'s `toggleMic`/`toggleCamera`/`hangUp`/
  mic-camera-call state detection: written by inspecting a real call at
  some point, not re-confirmed since.
  For `sendReaction`, confirmed live end-to-end for `thumbsUp` and `heart`:
  the `/send a reaction/i` open button, the `button[data-emoji^="<emoji>"]`
  tag-scoped selector (including heart's real value being 💖, not the
  guessed ❤️), and `dispatchClickSequence`'s mousedown/mouseup/click
  sequence (a plain `.click()` on that same correctly-selected button
  opened the tray but never sent the reaction). `celebrate` and `clap`
  reuse that exact mechanism unverified — if either doesn't send, check the
  `^=` prefix match against 🎉/👏's real `data-emoji` value first.
- **Not yet verified, and less confident than Meet's**:
  `content-scripts/teams.js`'s detection pattern is an unconfirmed guess at
  Teams' real DOM (built without access to a live call), unlike Meet's
  script which was at least written by inspecting the real thing at some
  point. Treat the hang-up/leave `aria-label` match as the first suspect if
  the Teams indicator never lights up.

## Open items

- Port 17721 is hardcoded in both `background.js` and
  `tools/dev-bridge-server.js`; no options UI to change it yet.
- No raise-hand action (Meet's shortcut is the less-standard Ctrl+Alt+H /
  Ctrl+⌘+H) — left out of v0 since it wasn't asked for; add to `ACTIONS` in
  `content-scripts/google-meet.js` if wanted.
