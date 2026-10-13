# streamdeckthings

Each subfolder is a standalone OpenDeck (Elgato Stream Deck-compatible) plugin,
with one exception: `browser-bridge/` is a Manifest V3 browser extension (not
an `.sdPlugin`) that a plugin talks to over a local WebSocket, for driving web
pages that have no automation API of their own (first use: Google Meet call
control) — see `browser-bridge/AGENTS.md`. This file holds notes that apply
across the OpenDeck plugins; plugin-specific notes live in an `AGENTS.md`
inside that plugin's own folder.

## Environment

- OpenDeck (nekename/OpenDeck) is installed at `/Applications/OpenDeck.app`.
  Its plugin directory is `~/Library/Application Support/opendeck/plugins/`.
- Hardware is a Stream Deck XL (32 keys, 8×4 grid).
- macOS on this machine is Apple Silicon (arm64). Xcode Command Line Tools
  (swiftc) are installed and used to build native plugin binaries — no extra
  toolchain install required.
- Homebrew's `node` (`/opt/homebrew/bin/node`) is currently **broken**
  (missing `libsimdjson` dylib after an incomplete brew upgrade). A working
  Node 24 exists via mise at
  `~/.local/share/mise/installs/node/24.18.0/bin/node`, but that path is
  version-pinned and will break if that mise version is removed. Prefer
  native (Swift-compiled) plugins over Node-runtime plugins on this machine
  until brew node is fixed (`brew reinstall node` or `brew install simdjson`).

## OpenDeck plugin format (ground truth, verified from installed plugins)

OpenDeck plugins are `<reverse-dns>.sdPlugin` folders using the Elgato Stream
Deck SDK manifest format, with a `manifest.json` at the root. Confirmed via
plugins already installed on this machine:

- **Native binary runtime** (`com.amansprojects.starterpack.sdPlugin`,
  `me.amankhanna.oasystem.sdPlugin`): manifest sets `CodePathMac` (and
  optionally `CodePaths`, a map of Rust target triples to binaries, for
  cross-arch distribution) to a compiled executable. OpenDeck just execs it
  directly — no runtime needed. This is what we use for anything that needs
  to shell out (e.g. `osascript`), since the webview runtime below has no
  shell access.
- **Webview runtime** (`net.ellreka.slack-status.sdPlugin`): manifest's
  `CodePath` points to an `.html` file, loaded in a hidden webview. It calls
  a global `connectElgatoStreamDeckSocket(port, uuid, registerEvent, info)`
  that OpenDeck injects, and speaks the WebSocket protocol with plain
  browser JS (`WebSocket`, `fetch`). No filesystem/process access — fine for
  HTTP-API plugins, useless for anything needing local shell commands.

**Protocol** (same for both runtimes): the plugin process/webview connects
to `ws://127.0.0.1:<port>` (port passed via `-port` launch arg, along with
`-pluginUUID`, `-registerEvent`, `-info`), and on open sends
`{"event": "<registerEvent>", "uuid": "<pluginUUID>"}`. After that it
receives events like `keyDown`/`keyUp`/`willAppear` as JSON with an `event`
field, and can send `setImage`/`setSettings`/`setState`/`setTitle` etc.

Manifest Action `States[].Image` etc. use a base path with no extension —
OpenDeck/Elgato looks for `<path>.png` and `<path>@2x.png` for retina.
Icon size conventions (verified against Elgato's manifest docs):
plugin `Icon` 256/512px, `CategoryIcon` 28/56px (monochrome), action `Icon`
20/40px, state `Image` 72/144px.

## Icon generation

No image-generation tool is available in this environment, so icons for
these plugins are rendered from SF Symbols using AppKit via a small Swift
script (`tools/render-icon.swift` in each plugin, or shared — see
`music-playpause/tools/render-icon.swift`). Run with the `swift` interpreter
(no compile step needed): `swift tools/render-icon.swift <symbol>
<pointSize> <pixelSize> <hexColor> <outPath>`. Note:
`NSImage(size:)` + `lockFocus()` rasterizes at the screen's backing scale
(2x on this Retina Mac), so exact pixel dimensions require building an
`NSBitmapImageRep` explicitly and drawing into an `NSGraphicsContext` wrapping
it, rather than lockFocus — lockFocus silently doubled every dimension here.

## Known gotcha: install plugins by copy, not symlink

Plugins in this repo live under `streamdeckthings/<plugin>/<uuid>.sdPlugin/`
and get installed by copying that folder into
`~/Library/Application Support/opendeck/plugins/`. **Do not symlink it
there instead** (e.g. `ln -s` from the app-support plugins dir back to this
repo) — the plugin itself still loads and registers fine (manifest/binary
are read via plain filesystem calls), but every icon (`CategoryIcon`,
action `Icon`, state `Image`) renders as a broken-image placeholder, in
OpenDeck's own UI *and* on the physical device. Diagnosed on
`music-playpause`: its profile.json key entry resolved the symlink to the
real repo path just fine, and that exact file had correct, valid PNG bytes
on disk — but the icon still failed to load until the bundle was installed
as a real (non-symlinked) copy, matching how every other pre-existing
plugin on this machine (`starterpack`, `oasystem`, `slack-status`) is
installed. Most likely cause: OpenDeck's webview asset server scopes served
files to its own plugins directory and won't follow a symlink out of it,
even though the plugin process itself (spawned directly, no scoping) and
manifest parsing (plain `fs::read`) don't care. Each plugin's `install.sh`
here does `rsync -a --delete`, not `ln -s`, for this reason — re-run it
after every change, since it's a copy, not a live link.

## Known gotcha: AppleScript automation permission

`osascript -e 'tell application "Music" to ...'` can hang or time out
(`AppleEvent timed out (-1712)`) the first time an app under Claude Code's
sandboxed shell tries to send Apple Events to Music.app, if a macOS "would
like to control Music" permission dialog is pending and nothing can click it
non-interactively. If a plugin's Music/AppleScript action doesn't seem to
fire, check System Settings → Privacy & Security → Automation for a pending
or denied entry before assuming the plugin code is wrong.
