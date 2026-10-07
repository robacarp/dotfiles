local ICON_DIR = hs.configdir .. "/streamdeck-icons/"
local BRIGHTNESS_STEP = 10
local MIN_BRIGHTNESS = 10 -- keep keys visible even at "all the way down"
local MAX_BRIGHTNESS = 100

local currentDevice = nil
local currentBrightness = 100 -- no getter exists; this just tracks what we've set
-- Tracks physical connection, separate from the user's own kill-switch
-- choice (soundHelperPaused below) - see ensureSoundHelperRunning/
-- checkSoundHelperHealth/hs.streamdeck.init for how this gates SoundHelper.
local streamdeckConnected = false

-- The right-hand column (buttons 8/16/24/32) is fixed page-nav chrome; the
-- other 28 buttons are modal - their icon/action depends on currentPage.
-- Declared up top since every indicator below needs to check it before
-- painting (see the "PAGE GUARD" comments) - a status-row button's
-- physical number is reused for something unrelated on other pages, so an
-- indicator update firing while its page isn't visible must not paint.
local currentPage = "misc" -- home screen

local PAGE_RETURN_TIMEOUT = 3 -- seconds of inactivity on a non-default page before returning home
local returnToDefaultTimer = nil
local lastConferenceActive = false
-- Forward-declared: used by code above their real definitions further down.
local switchPage
local checkConferenceAutoSwitch

-- A timer/watcher object whose return value isn't stored anywhere becomes
-- eligible for Lua's garbage collector, which silently stops it firing -
-- a well-known Hammerspoon footgun (see
-- github.com/asmagill/hammerspoon/wiki/Variable-Scope-and-Garbage-Collection).
-- Every timer/watcher this script creates gets routed through here so
-- something always keeps a reference alive for the life of the script.
local keepAlive = {}
local function keptAlive(obj)
  table.insert(keepAlive, obj)
  return obj
end

local function tapMediaKey(key)
  hs.eventtap.event.newSystemKeyEvent(key, true):post()
  hs.eventtap.event.newSystemKeyEvent(key, false):post()
end

local function toggleDarkMode()
  hs.osascript.applescript([[
    tell application "System Events"
      tell appearance preferences
        set dark mode to not dark mode
      end tell
    end tell
  ]])
end

local function adjustBrightness(delta)
  if not currentDevice then return end
  currentBrightness = math.max(MIN_BRIGHTNESS, math.min(MAX_BRIGHTNESS, currentBrightness + delta))
  currentDevice:setBrightness(currentBrightness)
end

--------------------------------------------------------------------------
-- Indicators - each lives on one particular page (see the Pages section
-- near the bottom) and is a colored/iconed key when active, blank/black
-- when not. Button numbers here are positions *within* that page's
-- content area (1-7), not absolute Stream Deck button numbers - see
-- PAGES and the PAGE GUARD comment on each updateXIndicator.
--------------------------------------------------------------------------

local INDICATOR_IDLE_COLOR = { red = 0, green = 0, blue = 0, alpha = 1 }

-- Renders the actual badge count onto the tile - the Stream Deck/hs.streamdeck
-- have no separate "show this number" primitive (everything is just pixels,
-- same as Elgato's own title-text feature under the hood), so this draws
-- text onto a canvas exactly like blankImage() draws a blank square.
local function badgeCountImage(size, text, bgColor)
  local canvas = hs.canvas.new({ x = 0, y = 0, w = size, h = size })
  canvas:appendElements({
    type = "rectangle",
    action = "fill",
    fillColor = bgColor,
    roundedRectRadii = { xRadius = size * 0.15, yRadius = size * 0.15 },
    frame = { x = 0, y = 0, w = size, h = size },
  })
  local fontSize = (#text > 2) and (size * 0.32) or (size * 0.42)
  canvas:appendElements({
    type = "text",
    text = text,
    textColor = { red = 1, green = 1, blue = 1, alpha = 1 },
    textAlignment = "center",
    textSize = fontSize,
    frame = { x = 0, y = (size - fontSize * 1.2) / 2, w = size, h = fontSize * 1.2 },
  })
  local image = canvas:imageFromCanvas()
  canvas:delete()
  return image
end

-- Google Meet indicator (conferencing page, position 1): lit by
-- browser-bridge's extension via a callStateChanged event over the bridge
-- websocket (see below) - reflects an actual joined Meet call, not just
-- mic/camera state.
local MEET_INDICATOR_BUTTON = 1
local meetCallActive = false

local function updateMeetIndicator()
  if not currentDevice or currentPage ~= "conferencing" then return end -- PAGE GUARD
  if meetCallActive then
    currentDevice:setButtonImage(MEET_INDICATOR_BUTTON, hs.image.imageFromPath(ICON_DIR .. "meet-active.png"))
  else
    currentDevice:setButtonColor(MEET_INDICATOR_BUTTON, INDICATOR_IDLE_COLOR)
  end
end

-- Call-control buttons: live on the media page, stacked in the column
-- that per-app soundboard slot 6 gave up (positions 6/14/22/30 - see
-- PAGES.media below). Target whichever backend activeConferenceService()
-- below says is live - Meet, over browser-bridge, or Zoom, over the
-- Zoom.spoon loaded below - and blank/no-op while neither is active.
-- Mic/camera state reflects the target's real state (browser-bridge's
-- micStateChanged/cameraStateChanged events for Meet; Zoom.spoon's live
-- getAudioStatus/getVideoStatus for Zoom), so the icon tracks reality
-- even if someone mutes from the app's own UI instead of the deck.
-- White-on-green = active (unmuted/camera on), white-on-black = inactive
-- (muted/camera off).
local CALL_FOCUS_BUTTON = 6
local CALL_MIC_BUTTON = 14
local CALL_CAMERA_BUTTON = 22
local CALL_HANGUP_BUTTON = 30
-- Meet reaction buttons: a full vertical strip in column 5 (5/13/21/29),
-- the column immediately left of the mic/camera/hangup column so they read
-- as one cluster - given up by the per-app soundboard, which now only
-- spans columns 1-4 (see SOUND_SLOT_COUNT). Meet-only (no Zoom equivalent
-- requested), so unlike CALL_MIC_BUTTON etc. these check meetCallActive
-- directly rather than activeConferenceService(). PAGES.media's entries
-- for these buttons are generated from this table below, not written out
-- by hand.
local REACTION_BUTTONS = {
  { button = 5, command = "thumbsUp", icon = "meet-thumbs-up.png" },
  { button = 13, command = "heart", icon = "meet-heart.png" },
  { button = 21, command = "celebrate", icon = "meet-party.png" },
  { button = 29, command = "clap", icon = "meet-clap.png" },
}
local MEET_BG_COLOR = { red = 0.0, green = 0.52, blue = 0.29, alpha = 1 } -- Google Meet green
local ZOOM_BG_COLOR = { red = 0.176, green = 0.549, blue = 1.0, alpha = 1 } -- Zoom blue
local meetMicMuted = false
local meetCameraOff = false

-- Meet and Zoom are mutually exclusive in practice, so first-match-wins.
-- nil means no call is active on either backend.
local function activeConferenceService()
  if meetCallActive then return "meet" end
  if spoon.Zoom and spoon.Zoom:inMeeting() then return "zoom" end
  return nil
end

local function updateCallMicIndicator()
  if not currentDevice or currentPage ~= "media" then return end -- PAGE GUARD
  local service = activeConferenceService()
  if not service then
    currentDevice:setButtonColor(CALL_MIC_BUTTON, INDICATOR_IDLE_COLOR)
    return
  end
  -- Deliberately if/else, not `(service=="meet") and meetMicMuted or (...)`
  -- - that and/or idiom breaks whenever the "true" branch's own value is
  -- falsy: meetMicMuted/meetCameraOff being `false` is a perfectly valid,
  -- common state ("live"/"on"), and and/or would fall through to the
  -- Zoom branch in that exact case, evaluating the wrong service's status
  -- entirely. Confirmed live: this is exactly what made the camera
  -- indicator never show "on" while on a Meet call - the mic version of
  -- the same bug just happened to be masked, since Zoom's own status
  -- check coincidentally lands on the right answer when not in a Zoom call.
  local muted
  if service == "meet" then
    muted = meetMicMuted
  else
    muted = spoon.Zoom:getAudioStatus() == "muted"
  end
  local icon = muted and "meet-mic-off.png" or "meet-mic-on.png"
  currentDevice:setButtonImage(CALL_MIC_BUTTON, hs.image.imageFromPath(ICON_DIR .. icon))
end

local function updateCallCameraIndicator()
  if not currentDevice or currentPage ~= "media" then return end -- PAGE GUARD
  local service = activeConferenceService()
  if not service then
    currentDevice:setButtonColor(CALL_CAMERA_BUTTON, INDICATOR_IDLE_COLOR)
    return
  end
  local off
  if service == "meet" then
    off = meetCameraOff
  else
    off = spoon.Zoom:getVideoStatus() ~= "videoStarted"
  end
  local icon = off and "meet-camera-off.png" or "meet-camera-on.png"
  currentDevice:setButtonImage(CALL_CAMERA_BUTTON, hs.image.imageFromPath(ICON_DIR .. icon))
end

local function updateCallHangupIndicator()
  if not currentDevice or currentPage ~= "media" then return end -- PAGE GUARD
  if activeConferenceService() then
    currentDevice:setButtonImage(CALL_HANGUP_BUTTON, hs.image.imageFromPath(ICON_DIR .. "meet-hangup.png"))
  else
    currentDevice:setButtonColor(CALL_HANGUP_BUTTON, INDICATOR_IDLE_COLOR)
  end
end

local function updateReactionIndicators()
  if not currentDevice or currentPage ~= "media" then return end -- PAGE GUARD
  for _, reaction in ipairs(REACTION_BUTTONS) do
    if meetCallActive then
      currentDevice:setButtonImage(reaction.button, hs.image.imageFromPath(ICON_DIR .. reaction.icon))
    else
      currentDevice:setButtonColor(reaction.button, INDICATOR_IDLE_COLOR)
    end
  end
end

-- Fourth button in the call-control column (row 4, completing 6/14/22/30):
-- brings the actual call window/tab forward, labeled with which app it is.
local function updateCallFocusIndicator()
  if not currentDevice or currentPage ~= "media" then return end -- PAGE GUARD
  local service = activeConferenceService()
  if not service then
    currentDevice:setButtonColor(CALL_FOCUS_BUTTON, INDICATOR_IDLE_COLOR)
    return
  end
  local label = (service == "meet") and "Meet" or "Zoom"
  local color = (service == "meet") and MEET_BG_COLOR or ZOOM_BG_COLOR
  currentDevice:setButtonImage(CALL_FOCUS_BUTTON, badgeCountImage(currentDevice:imageSize().w, label, color))
end

-- Zoom indicator (conferencing page, position 3): Zoom has no public
-- local API for meeting status, so this relies on the third-party
-- Zoom.spoon (~/.hammerspoon/Spoons/Zoom.spoon, github.com/jpf/Zoom.spoon),
-- which detects meetings via macOS accessibility events (window
-- title/menu-item changes) - it needs Hammerspoon to have Accessibility
-- permission under System Settings > Privacy & Security. Also used
-- directly (not just for this indicator) by the call-control buttons
-- above.
local ZOOM_INDICATOR_BUTTON = 3

local function updateZoomIndicator()
  if not currentDevice or currentPage ~= "conferencing" then return end -- PAGE GUARD
  if spoon.Zoom:inMeeting() then
    currentDevice:setButtonImage(ZOOM_INDICATOR_BUTTON, hs.image.imageFromPath(ICON_DIR .. "zoom-active.png"))
  else
    currentDevice:setButtonColor(ZOOM_INDICATOR_BUTTON, INDICATOR_IDLE_COLOR)
  end
end

-- Ends the current Zoom meeting. There's no menu item for this in current
-- Zoom ("Zoom Workplace" dropped Leave/End Meeting from the Meeting menu -
-- confirmed live against a real call), so this uses the keyboard shortcut
-- instead (confirmed in Settings > Keyboard Shortcuts: Cmd+W). That
-- shortcut isn't enabled as a *global* one, so Zoom's meeting window has
-- to actually be focused first, or the keystroke would hit whatever
-- window really is frontmost instead. As host, this may still open
-- Zoom's own confirm sheet ("Leave Meeting" / "End Meeting for All" /
-- "Cancel") rather than leaving directly - that's a safe outcome (nothing
-- destructive happens until you click something there), unlike guessing
-- which button to click on that sheet ourselves would be.
-- Looks for the actual meeting window by title rather than trusting
-- app:mainWindow() - same "Zoom Meeting"/"Zoom Webinar" title signature
-- Zoom.spoon's own watcher already keys off of above, so if Zoom has more
-- than one window open (e.g. its home/dashboard window alongside the
-- meeting), Cmd+W targets the meeting specifically instead of whichever
-- window happened to be main.
local function zoomMeetingWindow(app)
  for _, w in ipairs(app:allWindows()) do
    local title = w:title()
    if title == "Zoom Meeting" or title == "Zoom Webinar" then
      return w
    end
  end
  return app:mainWindow()
end

local function zoomLeaveMeeting()
  local app = hs.application.get("zoom.us")
  if not app then return end
  app:activate(true)
  local win = zoomMeetingWindow(app)
  if win then win:focus() end
  hs.eventtap.keyStroke({ "cmd" }, "w")
end

local function startZoomWatching()
  hs.loadSpoon("Zoom")
  -- Zoom.spoon's audio/video snapshot is otherwise only taken once, right
  -- when the meeting-joined AX signal fires - if an org policy (e.g. mute
  -- on join) applies with any lag relative to that signal, or the AX
  -- event just races Zoom's own menu catching up, that one snapshot can
  -- be stale forever with nothing to correct it. pollStatus makes it
  -- recheck the real menu state every second and fire the status
  -- callback on any drift - must be called before start() (see
  -- Zoom.spoon's obj:start()/handleAppEvent, which only arms the timer if
  -- pollingInterval is already set).
  spoon.Zoom:pollStatus(1)
  -- event is one of several possible transition/status strings (see
  -- Zoom.spoon's init.lua) - rather than parse which, just recompute the
  -- actual state fresh via inMeeting()/getAudioStatus()/getVideoStatus()
  -- on every callback.
  spoon.Zoom:setStatusCallback(function(_event)
    updateZoomIndicator()
    updateCallMicIndicator()
    updateCallCameraIndicator()
    updateCallHangupIndicator()
    updateCallFocusIndicator()
    updateReactionIndicators()
    checkConferenceAutoSwitch()
  end)
  spoon.Zoom:start()
end

-- Teams indicator (conferencing page, position 4): combines two sources -
-- (1) the Teams *web app*, via browser-bridge's callStateChanged event
--     (teamsWebCallActive, set from handleBridgeMessage below) - real and
--     working, same mechanism as the Meet indicator.
-- (2) the Teams *desktop app* - not wired up yet. The known log-scraping
--     technique (github.com/mre/teams-call) only applies to the old,
--     non-sandboxed Teams client; this machine runs the new
--     com.microsoft.teams2 sandboxed client, which has no equivalent log
--     file. The realistic fallback is accessibility-based UI detection
--     (same idea as Zoom.spoon), but that needs a real window
--     title/AX signature captured during a live call, which requires your
--     help - see startTeamsDesktopCalibration below.
local TEAMS_INDICATOR_BUTTON = 4
local teamsWebCallActive = false
local teamsDesktopInMeeting = false -- always false until calibrated - see below

local function updateTeamsIndicator()
  if not currentDevice or currentPage ~= "conferencing" then return end -- PAGE GUARD
  if teamsWebCallActive or teamsDesktopInMeeting then
    currentDevice:setButtonImage(TEAMS_INDICATOR_BUTTON, hs.image.imageFromPath(ICON_DIR .. "teams-active.png"))
  else
    currentDevice:setButtonColor(TEAMS_INDICATOR_BUTTON, INDICATOR_IDLE_COLOR)
  end
end

-- Diagnostic only, not wired to teamsDesktopInMeeting yet: logs every
-- window-title/creation event for the Teams app to the Hammerspoon Console
-- (menu bar icon > Console) so the real in-call title/signature can be
-- captured next time an actual Teams call happens on the desktop app, the
-- same way Zoom.spoon's window-title matching was worked out for Zoom.
-- Once we know the real signature, replace this with a proper detector.
local function startTeamsDesktopCalibration()
  local appWatcher = hs.application.watcher.new(function(appName, eventType, appObject)
    if not appName or not appName:find("Teams") then return end
    if eventType ~= hs.application.watcher.launched then return end

    local uiWatcher = appObject:newWatcher(function(element, event)
      local title = ""
      if element and element.title then
        local ok, t = pcall(function() return element:title() end)
        if ok and t then title = t end
      end
      print(string.format("[teams-detect] event=%s title=%q", tostring(event), title))
    end, { name = appName })
    keptAlive(uiWatcher)
    uiWatcher:start({
      hs.uielement.watcher.windowCreated,
      hs.uielement.watcher.titleChanged,
      hs.uielement.watcher.elementDestroyed,
    })
  end)
  keptAlive(appWatcher)
  appWatcher:start()
end

-- Unread-count indicators ("misc" page: Slack position 2, Messages
-- position 3): read each app's Dock badge via accessibility (AXStatusLabel
-- on its Dock icon), the same technique tools like SketchyBar use - needs
-- Accessibility permission (already granted, for Zoom.spoon above) but no
-- Full Disk Access, unlike reading Messages' chat.db directly would.
-- Caveat: this only sees a badge if the app has a Dock icon at all (pinned
-- or running) - if it's not in the Dock, this always reads "no unread"
-- even if unread messages genuinely exist.
local SLACK_INDICATOR_BUTTON = 2
local SLACK_BG_COLOR = { red = 0.29, green = 0.08, blue = 0.29, alpha = 1 } -- Slack aubergine
local MESSAGES_INDICATOR_BUTTON = 3
local MESSAGES_BG_COLOR = { red = 0.20, green = 0.78, blue = 0.35, alpha = 1 }

-- Returns the named app's Dock badge text ("3", "99+", ...), or nil if it
-- has no badge (including "app isn't in the Dock at all"). Once a badge
-- clears, AXStatusLabel returns AppleScript's `missing value` rather than
-- throwing - that doesn't hit `on error`, so it's checked for explicitly
-- and normalized to "" here rather than trusting how it'd otherwise cross
-- the AppleScript/Lua boundary.
local function dockBadgeText(appName)
  local ok, result = hs.osascript.applescript(string.format([[
    tell application "System Events"
      tell process "Dock"
        tell list 1
          try
            set theLabel to value of attribute "AXStatusLabel" of (first UI element whose name is "%s")
            if theLabel is missing value then
              return ""
            else
              return theLabel as string
            end if
          on error
            return ""
          end try
        end tell
      end tell
    end tell
  ]], appName))
  if not ok or type(result) ~= "string" or result == "" then return nil end
  return result
end

local function updateDockBadgeIndicator(button, appName, bgColor)
  if not currentDevice or currentPage ~= "misc" then return end -- PAGE GUARD (both Messages and Slack live on "misc")
  local badgeText = dockBadgeText(appName)
  if badgeText then
    currentDevice:setButtonImage(button, badgeCountImage(currentDevice:imageSize().w, badgeText, bgColor))
  else
    currentDevice:setButtonColor(button, INDICATOR_IDLE_COLOR)
  end
end

local function updateMessagesIndicator()
  updateDockBadgeIndicator(MESSAGES_INDICATOR_BUTTON, "Messages", MESSAGES_BG_COLOR)
end

local function updateSlackIndicator()
  updateDockBadgeIndicator(SLACK_INDICATOR_BUTTON, "Slack", SLACK_BG_COLOR)
end

-- No push notification for Dock badge changes exists, so this polls - 5s
-- is plenty responsive for "did I get a text/DM" without hammering
-- osascript/System Events. One shared timer for both badges.
local function startDockBadgeWatching()
  keptAlive(hs.timer.doEvery(5, function()
    updateMessagesIndicator()
    updateSlackIndicator()
  end))
end

-- Keyboard layout indicator (status page, position 2): shows "dv" for
-- Dvorak, "en" for anything else. Unlike the other indicators, this one is
-- never blank - there's always some active input source - and it's
-- event-driven, not polled: hs.keycodes.inputSourceChanged(fn) fires on
-- every switch. Pressing it toggles to "the other kind" (see
-- toggleKeyboardLayout below).
local KEYBOARD_INDICATOR_BUTTON = 7
local KEYBOARD_BG_COLOR = { red = 0, green = 0, blue = 0, alpha = 1 }

local function keyboardLayoutCode()
  local layout = hs.keycodes.currentLayout() or ""
  if layout:lower():find("dvorak") then return "dv" end
  return "en"
end

local function updateKeyboardLayoutIndicator()
  if not currentDevice or currentPage ~= "misc" then return end -- PAGE GUARD
  currentDevice:setButtonImage(
    KEYBOARD_INDICATOR_BUTTON,
    badgeCountImage(currentDevice:imageSize().w, keyboardLayoutCode(), KEYBOARD_BG_COLOR)
  )
end

-- Switches to the first installed layout whose "is it Dvorak" doesn't
-- match the current one - not hardcoded to specific layout names (which
-- vary by machine/locale, e.g. "U.S." vs "ABC"), just "the other kind" out
-- of whatever's actually installed. inputSourceChanged (already wired up
-- above) fires from this and repaints the indicator on its own.
local function toggleKeyboardLayout()
  local currentlyDvorak = (hs.keycodes.currentLayout() or ""):lower():find("dvorak") ~= nil
  for _, name in ipairs(hs.keycodes.layouts()) do
    local isDvorak = name:lower():find("dvorak") ~= nil
    if isDvorak ~= currentlyDvorak then
      hs.keycodes.setLayout(name)
      return
    end
  end
end

local function startKeyboardLayoutWatching()
  hs.keycodes.inputSourceChanged(updateKeyboardLayoutIndicator)
end

-- Volume level indicator (media page, position 9) - also doubles as the
-- mute button: shows the current volume 0-100 while unmuted, swaps to a
-- mute glyph (same blue tile, no color change) while muted, and pressing
-- it toggles mute. hs.audiodevice.watcher only covers device-connection-
-- level events (not volume/mute), so per-device watching uses
-- device:watcherCallback/watcherStart instead - and since the *default*
-- device can change (e.g. plugging in headphones), hs.audiodevice.watcher's
-- callback is used to know when to re-attach the per-device watcher to
-- whichever device is now the default. Also polled every 5s as a
-- backstop, same defensive pattern as the camera/Dock-badge indicators
-- above (untested whether CoreAudio property watchers are as reliable as
-- they should be).
-- Moved to column 7 (the rightmost content column on the media page) so
-- the per-app dynamic slots below can occupy columns 1-6.
local VOLUME_LEVEL_BUTTON = 15
local VOLUME_BG_COLOR = { red = 0.20, green = 0.50, blue = 0.85, alpha = 1 }
local watchedOutputDevice = nil

local function updateVolumeIndicator()
  if not currentDevice or currentPage ~= "media" then return end -- PAGE GUARD
  local device = hs.audiodevice.defaultOutputDevice()
  if device and device:outputMuted() then
    currentDevice:setButtonImage(VOLUME_LEVEL_BUTTON, hs.image.imageFromPath(ICON_DIR .. "volume-muted.png"))
    return
  end
  local level = device and device:outputVolume()
  local text = level and tostring(math.floor(level + 0.5)) or "--"
  currentDevice:setButtonImage(VOLUME_LEVEL_BUTTON, badgeCountImage(currentDevice:imageSize().w, text, VOLUME_BG_COLOR))
end

local function watchCurrentOutputDevice()
  local device = hs.audiodevice.defaultOutputDevice()
  if not device then return end
  if watchedOutputDevice then
    watchedOutputDevice:watcherStop()
  end
  device:watcherCallback(updateVolumeIndicator)
  device:watcherStart()
  watchedOutputDevice = device
  keptAlive(device) -- otherwise nothing else references this device object
end

local function startVolumeWatching()
  watchCurrentOutputDevice()
  hs.audiodevice.watcher.setCallback(function()
    watchCurrentOutputDevice() -- the default output device may have changed
    updateVolumeIndicator()
  end)
  hs.audiodevice.watcher.start()
  keptAlive(hs.timer.doEvery(5, function()
    updateVolumeIndicator()
  end))
end

-- Universal per-app volume soundboard (media page, columns 1-6: each
-- column N is buttons N / N+8 / N+16 for up / level+mute / down). Backed
-- by SoundHelper.app, a separate compiled+signed helper (not Lua/Hammerspoon
-- code - CoreAudio's Process Tap API isn't exposed to hs.*) that taps
-- whichever processes are actually producing audio output right now,
-- system-wide, and re-renders each through a per-process gain multiplier.
-- This replaced the earlier AppleScript-only Music/VLC columns entirely -
-- Music and VLC now just show up as regular dynamic slots like anything
-- else, no app-specific scripting.
--
-- Real, meaningful risk accepted here (unlike everything else on this
-- page): once running, this helper becomes a mandatory relay for *all*
-- system audio, not just apps you're actively adjusting - a bug or crash
-- in it is a bug or crash in your Mac's audio path. It was built and
-- tested carefully (see the session this was built in for the full
-- diagnostic trail: process-tap creation, multi-tap lifecycle with
-- staggered start/stop, mid-flight gain changes, all verified live), but
-- flagging this plainly since it's a different risk category than an
-- AppleScript call or a Dock-badge read.
local SOUND_HELPER_PORT = 17722
local SOUND_HELPER_APP = hs.configdir .. "/SoundHelper.app"
local SOUND_SLOT_STEP = 6
-- Column 6 (device buttons 6/14/22/30) belongs to the Meet mic/camera/
-- hang-up buttons, and column 5 to the Meet reaction buttons - see
-- PAGES.media below - so only 4 soundboard columns remain.
local SOUND_SLOT_COUNT = 4

-- Fixed per-slot-index colors (not per-app identity - a slot's color can
-- represent a different app after reassignment). Reuses the Apple
-- Music/VLC brand colors from the old columns for continuity, plus a few
-- more distinct hues.
local SOUND_SLOT_COLORS = {
  { red = 0.98, green = 0.14, blue = 0.23, alpha = 1 }, -- red
  { red = 1.00, green = 0.53, blue = 0.00, alpha = 1 }, -- orange
  { red = 0.60, green = 0.80, blue = 0.20, alpha = 1 }, -- yellow-green
  { red = 0.10, green = 0.65, blue = 0.60, alpha = 1 }, -- teal
  { red = 0.55, green = 0.25, blue = 0.85, alpha = 1 }, -- purple
}

-- soundSlots[i] = { pid, name, gain, lastGainBeforeMute } or nil (empty).
-- A pid keeps its data across snapshots while it stays active, but its
-- column can shift left over time - see handleSoundHelperSnapshot, which
-- re-packs survivors starting at column 1 on every snapshot so a slot
-- going away collapses the gap instead of leaving a hole.
local soundSlots = {}
for i = 1, SOUND_SLOT_COUNT do soundSlots[i] = nil end

local function truncateName(name)
  name = name:match("([^/]+)$") or name -- last path component, if it's a full path
  return name:sub(1, 6)
end

-- Each slot now takes the full column height: name (press = focus that
-- process's window) / up / level+mute / down.
local function updateSoundSlot(i)
  if not currentDevice or currentPage ~= "media" then return end -- PAGE GUARD
  local nameButton, upButton, levelButton, downButton = i, i + 8, i + 16, i + 24
  local slot = soundSlots[i]
  if not slot then
    currentDevice:setButtonColor(nameButton, INDICATOR_IDLE_COLOR)
    currentDevice:setButtonColor(upButton, INDICATOR_IDLE_COLOR)
    currentDevice:setButtonColor(levelButton, INDICATOR_IDLE_COLOR)
    currentDevice:setButtonColor(downButton, INDICATOR_IDLE_COLOR)
    return
  end
  local color = SOUND_SLOT_COLORS[i]
  local size = currentDevice:imageSize().w
  currentDevice:setButtonImage(nameButton, badgeCountImage(size, truncateName(slot.name), color))
  currentDevice:setButtonImage(upButton, badgeCountImage(size, "+", color))
  local levelText = slot.gain <= 0 and "mute" or tostring(math.floor(slot.gain * 100 + 0.5))
  currentDevice:setButtonImage(levelButton, badgeCountImage(size, levelText, color))
  currentDevice:setButtonImage(downButton, badgeCountImage(size, "-", color))
end

local function updateAllSoundSlots()
  for i = 1, SOUND_SLOT_COUNT do updateSoundSlot(i) end
end

local soundHelperServer = nil
local nextSoundHelperCommandId = 0

local function sendSoundHelperMessage(fields)
  if not soundHelperServer then return end
  nextSoundHelperCommandId = nextSoundHelperCommandId + 1
  fields.id = tostring(nextSoundHelperCommandId)
  soundHelperServer:send(hs.json.encode(fields))
end

local function sendSetGain(pid, gain)
  sendSoundHelperMessage({ type = "setGain", pid = pid, gain = gain })
end

-- Bumped on every received snapshot; the health-check timer below
-- compares this against its last-seen value rather than needing a
-- wall-clock API - if it hasn't moved in 15s (helper sends one roughly
-- every 1s), the helper is presumed dead/stuck and gets relaunched.
local soundHelperSnapshotCount = 0

-- One-off, append-only record of every new process that ever claims a
-- soundboard slot - lets you identify something you noticed light up but
-- didn't catch the name of in time (e.g. a system-sound blip from a Mail
-- notification) by checking this file afterward instead of having to
-- watch the deck at the exact moment it happens again.
local SOUND_ACTIVITY_LOG = hs.configdir .. "/soundboard-activity.log"
local function logNewSoundSlotProcess(name, pid)
  local f = io.open(SOUND_ACTIVITY_LOG, "a")
  if not f then return end
  f:write(("%s  new audio process: %s (pid %d)\n"):format(os.date("%Y-%m-%d %H:%M:%S"), name, pid))
  f:close()
end

-- Reconciles the live snapshot from the helper against current slot
-- assignments: drops slots whose pid is no longer active, then re-packs
-- the survivors starting at column 1 (in their prior left-to-right order)
-- so a slot going away collapses the gap instead of leaving a hole, and
-- finally appends newly-active pids into whatever columns are left
-- (dropped silently if all slots are full - no queueing/eviction).
local function handleSoundHelperSnapshot(processes)
  soundHelperSnapshotCount = soundHelperSnapshotCount + 1
  local activeByPID = {}
  for _, p in ipairs(processes) do activeByPID[p.pid] = p end

  local kept = {}
  local trackedPIDs = {}
  for i = 1, SOUND_SLOT_COUNT do
    local slot = soundSlots[i]
    if slot and activeByPID[slot.pid] then
      slot.gain = activeByPID[slot.pid].gain
      slot.name = activeByPID[slot.pid].name
      table.insert(kept, slot)
      trackedPIDs[slot.pid] = true
    end
  end

  for _, p in ipairs(processes) do
    if not trackedPIDs[p.pid] and #kept < SOUND_SLOT_COUNT then
      table.insert(kept, { pid = p.pid, name = p.name, gain = p.gain, lastGainBeforeMute = 1.0 })
      trackedPIDs[p.pid] = true
      logNewSoundSlotProcess(p.name, p.pid)
    end
  end

  for i = 1, SOUND_SLOT_COUNT do
    soundSlots[i] = kept[i]
  end

  updateAllSoundSlots()
end

local function handleSoundHelperMessage(message)
  local ok, msg = pcall(hs.json.decode, message)
  if not ok or type(msg) ~= "table" then
    print("[streamdeck-media] sound helper sent malformed JSON: " .. tostring(message))
    return
  end
  if msg.type == "snapshot" and type(msg.processes) == "table" then
    handleSoundHelperSnapshot(msg.processes)
  end
end

local function startSoundHelperServer()
  soundHelperServer = hs.httpserver.new()
  soundHelperServer:setPort(SOUND_HELPER_PORT)
  soundHelperServer:websocket("/", handleSoundHelperMessage)
  soundHelperServer:start()
end

-- SoundHelper.app is a background-only (LSUIElement) app, not something
-- Hammerspoon can just dofile/require - `open` is the standard way to
-- launch a .app bundle from a script. `-g` keeps it from stealing focus.
-- Harmless (a no-op via `open`'s normal single-instance behavior) if it's
-- already running.
-- Kill switch for both the startup launch and the health-check relaunch
-- below - see toggleSoundHelperKillSwitch (misc page, position 6) for the
-- on-deck emergency stop this backs. Originally added as a one-off debug
-- flag during a 2026-08-26 distortion incident (traced to the output-
-- device-follow poll rebuilding the mixer on a self-inflicted feedback
-- loop, fixed with a two-poll debounce); promoted to a real button since
-- a from-the-deck kill switch is generally worth having if this ever
-- distorts mid-call again, not just for that one incident.
--
-- Persisted to a flag file, NOT just an in-memory local - Hammerspoon
-- reloads (ConfigReloader fires on every file save, including ones made
-- while iterating on unrelated things) re-run this whole script from
-- scratch, which would silently reset a plain local back to false and
-- relaunch SoundHelper out from under you mid-call. Confirmed live: this
-- is exactly what happened after the kill switch was pressed once and a
-- later reload brought it back.
local SOUND_HELPER_PAUSE_FLAG = hs.configdir .. "/soundhelper-paused.flag"

local function readSoundHelperPaused()
  local f = io.open(SOUND_HELPER_PAUSE_FLAG, "r")
  if not f then return false end
  f:close()
  return true
end

local function writeSoundHelperPaused(paused)
  if paused then
    local f = io.open(SOUND_HELPER_PAUSE_FLAG, "w")
    if f then f:close() end
  else
    os.remove(SOUND_HELPER_PAUSE_FLAG)
  end
end

local soundHelperPaused = readSoundHelperPaused()
local SOUND_HELPER_KILLSWITCH_BUTTON = 6

-- Tried launching the binary directly via hs.task for a real :pid() to
-- target precisely instead of pattern-matching. Reverted - confirmed live
-- that TCC's audio-capture grant does NOT carry over to a direct spawn
-- (posix_spawn under the hood, bypassing LaunchServices): the resulting
-- process logged "TCC granted=false" and exited immediately, silently
-- breaking per-app volume control. TCC's grant for this app is tied
-- specifically to being launched via `open`/LaunchServices, so `open -g`
-- stays required here, and pattern-matching stays the only way to target
-- the resulting process - `open` itself exits right after handing off,
-- so it never hands back the real app's pid either.
local function ensureSoundHelperRunning()
  if soundHelperPaused or not streamdeckConnected then return end
  print("[streamdeck-media] launching sound helper")
  hs.execute(string.format('open -g "%s"', SOUND_HELPER_APP))
end

local function stopSoundHelper()
  print("[streamdeck-media] stopping sound helper")
  hs.execute('pkill -f "SoundHelper.app/Contents/MacOS/SoundHelper"')
end

local function updateSoundHelperKillSwitchIndicator()
  if not currentDevice or currentPage ~= "misc" then return end -- PAGE GUARD
  local icon = soundHelperPaused and "soundhelper-stopped.png" or "soundhelper-running.png"
  currentDevice:setButtonImage(SOUND_HELPER_KILLSWITCH_BUTTON, hs.image.imageFromPath(ICON_DIR .. icon))
end

local function toggleSoundHelperKillSwitch()
  soundHelperPaused = not soundHelperPaused
  writeSoundHelperPaused(soundHelperPaused)
  if soundHelperPaused then
    stopSoundHelper()
    hs.alert.show("Sound Helper stopped")
    -- Nothing will report these as gone anymore (the process that would
    -- tell us so is the one just killed) - clear them now rather than
    -- leaving stale slots on screen.
    for i = 1, SOUND_SLOT_COUNT do soundSlots[i] = nil end
    updateAllSoundSlots()
  else
    hs.alert.show("Sound Helper resuming")
    ensureSoundHelperRunning()
  end
  updateSoundHelperKillSwitchIndicator()
end

-- No crash-restart supervision otherwise existed: if the helper died,
-- ensureSoundHelperRunning only ever ran once at Hammerspoon startup, so
-- it stayed dead until the next full reload. This polls for a stalled
-- snapshot stream and relaunches.
local lastCheckedSoundHelperSnapshotCount = -1

local function checkSoundHelperHealth()
  if soundHelperPaused then return end -- intentionally stopped via the kill switch - not "stalled"
  if not streamdeckConnected then return end -- intentionally stopped - no deck to control/monitor it
  if soundHelperSnapshotCount == lastCheckedSoundHelperSnapshotCount then
    print("[streamdeck-media] sound helper appears stalled/dead - relaunching")
    ensureSoundHelperRunning()
  end
  lastCheckedSoundHelperSnapshotCount = soundHelperSnapshotCount
end

local function startSoundHelperHealthCheck()
  keptAlive(hs.timer.doEvery(15, checkSoundHelperHealth))
end

-- The tapped pid is whichever process actually opened the CoreAudio
-- stream, which for multi-process apps (browsers, Electron apps, Safari
-- "Add to Dock" web-app containers, ...) is very often a helper/child
-- process, not the main window-owning one - hs.application.applicationForPID
-- only recognizes real top-level apps, so it'd silently return nil for a
-- helper. This walks up the process tree until it finds an ancestor
-- Hammerspoon actually recognizes as an application, or gives up after a
-- bounded number of hops.
--
-- One `ps -axo pid=,ppid=` snapshot of the whole process table, walked in
-- Lua, rather than a separate `ps -o ppid= -p <pid>` shell-out per hop (up
-- to maxHops subprocess spawns for one button press) - same result, one
-- process spawn instead of up to ten.
local function findFocusableAncestorApp(pid, maxHops)
  local app = hs.application.applicationForPID(pid)
  if app then return app end

  local ppidByPid = {}
  local out = hs.execute("ps -axo pid=,ppid= 2>/dev/null")
  if out then
    for p, pp in out:gmatch("(%d+)%s+(%d+)") do
      ppidByPid[tonumber(p)] = tonumber(pp)
    end
  end

  local currentPid = pid
  for _ = 1, (maxHops or 10) do
    local parentPid = ppidByPid[currentPid]
    if not parentPid or parentPid <= 1 or parentPid == currentPid then return nil end
    currentPid = parentPid
    local app = hs.application.applicationForPID(currentPid)
    if app then return app end
  end
  return nil
end

local function focusSoundSlot(i)
  local slot = soundSlots[i]
  if not slot then return end
  local app = findFocusableAncestorApp(slot.pid)
  if not app then return end
  app:activate(true)
  -- activate() alone can leave the app frontmost without actually
  -- raising its window (e.g. minimized, or on another Space) - explicit
  -- focus on its main window covers that gap.
  local win = app:mainWindow()
  if win then win:focus() end
end

local function adjustSoundSlot(i, delta)
  local slot = soundSlots[i]
  if not slot then return end
  local newGain = math.max(0, math.min(1, slot.gain + delta / 100))
  slot.gain = newGain
  sendSetGain(slot.pid, newGain)
  updateSoundSlot(i)
end

local function toggleSoundSlotMute(i)
  local slot = soundSlots[i]
  if not slot then return end
  if slot.gain > 0 then
    slot.lastGainBeforeMute = slot.gain
    slot.gain = 0
  else
    slot.gain = slot.lastGainBeforeMute or 1.0
  end
  sendSetGain(slot.pid, slot.gain)
  updateSoundSlot(i)
end

-- Order matters: updateMessagesIndicator/updateSlackIndicator each block
-- on a live, synchronous AppleScript round-trip through System Events to
-- read a Dock badge - real, perceptible latency compared to every other
-- indicator here, which just does a direct setButtonImage. Hammerspoon is
-- single-threaded, so whatever's queued after those two visibly waits on
-- them. Keep the fast, no-AppleScript indicators first so they paint
-- immediately; only the two that genuinely need to wait on the OS do.
local function updateAllIndicators()
  updateMeetIndicator()
  updateCallMicIndicator()
  updateCallCameraIndicator()
  updateCallHangupIndicator()
  updateCallFocusIndicator()
  updateReactionIndicators()
  updateZoomIndicator()
  updateTeamsIndicator()
  updateKeyboardLayoutIndicator()
  updateSoundHelperKillSwitchIndicator()
  updateVolumeIndicator()
  updateAllSoundSlots()
  updateMessagesIndicator()
  updateSlackIndicator()
end

--------------------------------------------------------------------------
-- browser-bridge WebSocket bridge - hosts the WS server background.js
-- connects out to (ws://127.0.0.1:17721/); see
-- streamdeckthings/browser-bridge/AGENTS.md for the wire protocol. This
-- script is standing in for the "native plugin" that repo doesn't have
-- built yet.
--------------------------------------------------------------------------

local BRIDGE_PORT = 17721
local bridgeServer = nil
local nextCommandId = 0

local function sendBridgeMessage(fields)
  if not bridgeServer then return end
  nextCommandId = nextCommandId + 1
  fields.id = tostring(nextCommandId)
  bridgeServer:send(hs.json.encode(fields))
end

local function sendMeetCommand(action)
  sendBridgeMessage({ type = "command", site = "meet.google.com", action = action, params = {} })
end

-- See browser-bridge/AGENTS.md - handled by background.js directly, not
-- forwarded to a content script (a page can't raise its own browser
-- window or switch tabs).
local function sendFocusTab(site)
  sendBridgeMessage({ type = "focusTab", site = site })
end

local function handleBridgeMessage(message)
  local ok, msg = pcall(hs.json.decode, message)
  if not ok or type(msg) ~= "table" then
    print("[streamdeck-media] bridge sent malformed JSON: " .. tostring(message))
    return
  end

  if msg.type == "result" and msg.ok == false then
    hs.alert.show("Bridge: " .. tostring(msg.error))
  elseif msg.type == "event" and msg.event == "callStateChanged" then
    local active = msg.data and msg.data.active or false
    if msg.site == "meet.google.com" then
      meetCallActive = active
      updateMeetIndicator()
      updateCallMicIndicator()
      updateCallCameraIndicator()
      updateCallHangupIndicator()
      updateCallFocusIndicator()
      updateReactionIndicators()
      checkConferenceAutoSwitch()
    elseif msg.site == "teams.microsoft.com" then
      teamsWebCallActive = active
      updateTeamsIndicator()
    end
  elseif msg.type == "event" and msg.event == "micStateChanged" and msg.site == "meet.google.com" then
    meetMicMuted = msg.data and msg.data.muted or false
    updateCallMicIndicator()
  elseif msg.type == "event" and msg.event == "cameraStateChanged" and msg.site == "meet.google.com" then
    meetCameraOff = msg.data and msg.data.off or false
    updateCallCameraIndicator()
  end
end

local function startBridgeServer()
  bridgeServer = hs.httpserver.new()
  bridgeServer:setPort(BRIDGE_PORT)
  bridgeServer:websocket("/", handleBridgeMessage)
  bridgeServer:start()
end

-- Jumps to whichever app/tab is actually running the active call. Zoom and
-- (once calibrated) desktop Teams are native apps, so launchOrFocus is
-- enough; Meet and Teams-web live in a browser tab, which needs the
-- extension's focusTab (background.js can raise a window/activate a tab -
-- the content script running the call can't do that itself).
local function focusCallService(service)
  if service == "zoom" then
    local app = hs.application.get("zoom.us") -- matches the process name Zoom.spoon itself watches for
    if app then
      app:activate(true)
      local win = zoomMeetingWindow(app) -- the meeting window specifically, not just whichever Zoom window is main
      if win then win:focus() end
    else
      hs.application.launchOrFocus("zoom.us")
    end
  elseif service == "meet" then
    sendFocusTab("meet.google.com")
  elseif service == "teams" then
    if teamsWebCallActive then
      sendFocusTab("teams.microsoft.com")
    else
      hs.application.launchOrFocus("Microsoft Teams")
    end
  end
end

--------------------------------------------------------------------------
-- Pages - the right-hand column (8/16/24/32, top to bottom) is fixed
-- page-nav chrome; the other 28 buttons are modal, defined per page below.
--------------------------------------------------------------------------

local REPEAT_DELAY = 0.4 -- seconds held before repeat kicks in
local REPEAT_INTERVAL = 0.1 -- seconds between repeats while held
local SOUND_SLOT_REPEAT_INTERVAL = 0.2 -- slower than REPEAT_INTERVAL: finer control now that SOUND_SLOT_STEP is smaller

-- Buttons 24 and 32 (formerly the conferencing page's nav button, and
-- misc's before it moved to the top of the list) are unclaimed - both
-- fall through paint()'s default content-button handling on every page
-- (blank, since no page defines button 24 or 32).
local PAGE_NAV_BUTTON = { misc = 8, media = 16 }
local NAV_ICON_FILE = {
  misc = "nav-misc",
  media = "nav-media",
}
local NAV_BUTTON_PAGE = {}
for page, button in pairs(PAGE_NAV_BUTTON) do
  NAV_BUTTON_PAGE[button] = page
end

local PAGES = {
  media = {
    -- Columns 1-4: universal per-app dynamic soundboard slots, each using
    -- the full column height (name/up/level+mute/down = i/i+8/i+16/i+24) -
    -- generated below the table (see the SOUND_SLOT_COUNT loop right after
    -- this literal) rather than spelled out by hand, so SOUND_SLOT_COUNT
    -- is the only thing that has to change if the slot count ever does.
    -- No `icon` on any of these on purpose - owned by updateSoundSlot,
    -- which also blanks a column entirely when no process is assigned to
    -- it. Pressing the name button focuses that process's window (a
    -- no-op if it has none, e.g. a CLI tool or background helper). Was
    -- columns 1-5 until column 5 was given up for Meet reactions (see
    -- REACTION_BUTTONS) - one fewer simultaneous per-app slot in exchange
    -- for a vertical strip right next to the call-control column.
    -- Column 5: Meet reaction buttons, generated below from
    -- REACTION_BUTTONS - deliberately placed immediately left of column 6
    -- so they read as part of the same call-control cluster.
    -- Column 6: call-control focus/mic/camera/hang-up, stacked top to
    -- bottom, targeting whichever of Meet/Zoom activeConferenceService()
    -- says is live. No `icon` on purpose - owned by updateCallFocusIndicator/
    -- updateCallMicIndicator/updateCallCameraIndicator/
    -- updateCallHangupIndicator, repainted whenever this page becomes
    -- active and by the bridge's mic/camera/call-state events or
    -- Zoom.spoon's status callback. All four are no-ops and stay blanked
    -- while no call is active on either backend.
    [6] = { action = function()
      local service = activeConferenceService()
      if service then focusCallService(service) end
    end },
    [14] = { action = function()
      local service = activeConferenceService()
      if service == "meet" then sendMeetCommand("toggleMic")
      elseif service == "zoom" then spoon.Zoom:toggleMute() end
    end },
    [22] = { action = function()
      local service = activeConferenceService()
      if service == "meet" then sendMeetCommand("toggleCamera")
      elseif service == "zoom" then spoon.Zoom:toggleVideo() end
    end },
    [30] = { action = function()
      local service = activeConferenceService()
      if service == "meet" then sendMeetCommand("hangUp")
      elseif service == "zoom" then zoomLeaveMeeting() end
    end },
    -- Column 7 (rightmost content column): system master volume + mute.
    -- Volume itself is unaffected by the 4-row change above - stays
    -- conceptually 3 rows, no name/focus concept applies to the system as
    -- a whole. Row 4 (31) is unclaimed, same as 24/32 (see PAGE_NAV_BUTTON
    -- above).
    [7]  = { icon = "volume-up.png",   action = function() tapMediaKey("SOUND_UP") end, repeatable = true },
    -- No `icon`: owned by updateVolumeIndicator - also doubles as the mute
    -- toggle (shows the number unmuted, a mute glyph while muted).
    [15] = { action = function() tapMediaKey("MUTE") end },
    [23] = { icon = "volume-down.png", action = function() tapMediaKey("SOUND_DOWN") end, repeatable = true },
  },

  -- Home screen (see currentPage/PAGE_NAV_BUTTON above). Merged former
  -- "status" page (dark mode, keyboard layout) into this one - both were
  -- single-row pages with room to spare, not worth a whole dedicated page
  -- each.
  misc = {
    [1] = { icon = "dark-mode.png", action = toggleDarkMode },
    -- No `icon`: owned by updateSlackIndicator/updateMessagesIndicator.
    [2] = { action = function() hs.application.launchOrFocus("Slack") end },
    [3] = { action = function() hs.application.launchOrFocus("Messages") end },
    [4] = { icon = "brightness-down.png", action = function() adjustBrightness(-BRIGHTNESS_STEP) end, repeatable = true },
    [5] = { icon = "brightness-up.png",   action = function() adjustBrightness(BRIGHTNESS_STEP) end, repeatable = true },
    -- No `icon`: owned by updateSoundHelperKillSwitchIndicator - emergency
    -- stop for SoundHelper (see soundHelperPaused above), e.g. if it starts
    -- distorting audio mid-call. Toggles, not one-way: pressing again while
    -- stopped relaunches it.
    [6] = { action = toggleSoundHelperKillSwitch },
    -- No `icon`: owned by updateKeyboardLayoutIndicator.
    [7] = { action = toggleKeyboardLayout },
  },
}

-- Generates PAGES.media's per-slot buttons (name/up/mute/down = i/i+8/
-- i+16/i+24) instead of writing all SOUND_SLOT_COUNT slots out by hand -
-- see the comment on PAGES.media above. Lua's numeric `for` gives each
-- iteration its own `i`, so each closure correctly captures its own slot
-- index.
for i = 1, SOUND_SLOT_COUNT do
  PAGES.media[i] = { action = function() focusSoundSlot(i) end }
  PAGES.media[i + 8] = { action = function() adjustSoundSlot(i, SOUND_SLOT_STEP) end, repeatable = true, repeatInterval = SOUND_SLOT_REPEAT_INTERVAL }
  PAGES.media[i + 16] = { action = function() toggleSoundSlotMute(i) end }
  PAGES.media[i + 24] = { action = function() adjustSoundSlot(i, -SOUND_SLOT_STEP) end, repeatable = true, repeatInterval = SOUND_SLOT_REPEAT_INTERVAL }
end

-- Generates PAGES.media's 3 reaction buttons from REACTION_BUTTONS instead
-- of writing each one out by hand. No `icon` here - owned by
-- updateReactionIndicators, blanked while no Meet call is active.
for _, reaction in ipairs(REACTION_BUTTONS) do
  PAGES.media[reaction.button] = { action = function()
    if meetCallActive then sendMeetCommand(reaction.command) end
  end }
end

local activeTimers = {}

local function stopRepeat(button)
  local timer = activeTimers[button]
  if timer then
    timer:stop()
    activeTimers[button] = nil
  end
end

local function startRepeat(button, def)
  stopRepeat(button)
  local interval = def.repeatInterval or REPEAT_INTERVAL
  activeTimers[button] = hs.timer.doAfter(REPEAT_DELAY, function()
    activeTimers[button] = hs.timer.doEvery(interval, def.action)
  end)
end

local function blankImage(size)
  local canvas = hs.canvas.new({ x = 0, y = 0, w = size, h = size })
  canvas:appendElements({
    type = "rectangle",
    action = "fill",
    fillColor = { red = 0, green = 0, blue = 0, alpha = 1 },
    frame = { x = 0, y = 0, w = size, h = size },
  })
  local image = canvas:imageFromCanvas()
  canvas:delete()
  return image
end

local function paintNavButtons(dev)
  for page, button in pairs(PAGE_NAV_BUTTON) do
    local suffix = (page == currentPage) and "-on.png" or "-off.png"
    dev:setButtonImage(button, hs.image.imageFromPath(ICON_DIR .. NAV_ICON_FILE[page] .. suffix))
  end
end

-- setButtonImage persists on the device until something overwrites it, so
-- every content button not currently assigned an icon on the active page
-- must be explicitly blanked each time we paint - otherwise a button
-- that's an icon on one page but bare (indicator-owned) or unused on
-- another keeps showing its last image forever ("ghost" buttons).
--
-- Three phases, in this order: (1) nav buttons - fixed chrome, painted
-- first so it appears immediately regardless of which page is loading;
-- (2) blank every other button in one ascending sweep, so nothing from
-- the previous page lingers even briefly; (3) paint this page's actual
-- icon-bearing buttons column by column, right to left - a deliberate
-- "wipe" sweep across the deck, rather than the plain ascending fill
-- order phases 1-2 use.
local function paint(dev)
  local columns, rows = dev:buttonLayout()
  local size = dev:imageSize()
  local blank = blankImage(size.w)
  local content = PAGES[currentPage]

  paintNavButtons(dev)

  for button = 1, columns * rows do
    if not NAV_BUTTON_PAGE[button] then
      dev:setButtonImage(button, blank)
    end
  end

  for col = columns, 1, -1 do
    for row = 0, rows - 1 do
      local button = row * columns + col
      if not NAV_BUTTON_PAGE[button] then
        local def = content[button]
        if def and def.icon then
          dev:setButtonImage(button, hs.image.imageFromPath(ICON_DIR .. def.icon))
        end
      end
    end
  end
end

local function currentDefaultPage()
  return activeConferenceService() and "media" or "misc"
end

local function cancelReturnToDefaultTimer()
  if returnToDefaultTimer then
    returnToDefaultTimer:stop()
    returnToDefaultTimer = nil
  end
end

local function armReturnToDefaultTimer()
  cancelReturnToDefaultTimer()
  returnToDefaultTimer = hs.timer.doAfter(PAGE_RETURN_TIMEOUT, function()
    returnToDefaultTimer = nil
    switchPage(currentDefaultPage())
  end)
end

-- Called on navigation, every button press, and conference state changes,
-- so the idle-return timer stays in sync and resets on activity.
local function refreshPageForCurrentMode()
  if currentPage == currentDefaultPage() then
    cancelReturnToDefaultTimer()
  else
    armReturnToDefaultTimer()
  end
end

switchPage = function(newPage)
  if not PAGES[newPage] or newPage == currentPage then return end
  currentPage = newPage
  if not currentDevice then return end
  paint(currentDevice)
  updateAllIndicators() -- repaints whichever indicator-owned buttons just became visible
  refreshPageForCurrentMode()
end

-- Edge-triggered on call start so it fires once, not on every status poll.
checkConferenceAutoSwitch = function()
  local active = activeConferenceService() ~= nil
  if active and not lastConferenceActive then
    switchPage("media")
  end
  lastConferenceActive = active
  refreshPageForCurrentMode()
end

-- If any one of these throws, an unprotected call would abort the whole
-- script right here - meaning hs.streamdeck.init below would never run,
-- silently breaking every button (not just whatever the failing
-- subsystem was), while the deck keeps showing whatever it last painted.
-- pcall keeps one bad subsystem from taking the rest down, and surfaces
-- exactly which one and why instead of failing silently.
local function safeStart(name, fn)
  local ok, err = pcall(fn)
  if not ok then
    print(string.format("[streamdeck-media] %s failed to start: %s", name, tostring(err)))
    hs.alert.show(name .. " failed to start - see Hammerspoon Console")
  end
end

safeStart("bridge server", startBridgeServer)
safeStart("zoom watching", startZoomWatching)
safeStart("teams desktop calibration", startTeamsDesktopCalibration)
safeStart("dock badge watching", startDockBadgeWatching)
safeStart("keyboard layout watching", startKeyboardLayoutWatching)
safeStart("volume watching", startVolumeWatching)
safeStart("sound helper server", startSoundHelperServer)
safeStart("sound helper health check", startSoundHelperHealthCheck)

-- SoundHelper's own launch is no longer triggered here at startup - it's
-- gated entirely on streamdeckConnected now (see ensureSoundHelperRunning),
-- which only becomes true once hs.streamdeck.init's callback below actually
-- fires for a connected device, so a call here would always be a no-op.
hs.streamdeck.init(function(connected, dev)
  if not connected then
    print("[streamdeck-media] deck disconnected")
    if currentDevice == dev then currentDevice = nil end
    streamdeckConnected = false
    -- No deck left to reach the kill switch from, so stop SoundHelper the
    -- same way the kill switch itself does - NOT touching soundHelperPaused/
    -- the persisted flag, since that's a deliberate user choice that should
    -- survive a temporary unplug and not get silently flipped by it either way.
    stopSoundHelper()
    for i = 1, SOUND_SLOT_COUNT do soundSlots[i] = nil end
    return
  end

  print("[streamdeck-media] deck connected")
  currentDevice = dev
  streamdeckConnected = true
  ensureSoundHelperRunning() -- resumes automatically unless soundHelperPaused (the deliberate kill-switch state)
  paint(dev)
  updateAllIndicators()
  dev:buttonCallback(function(_, button, isDown)
    if isDown then refreshPageForCurrentMode() end -- resets the idle-return clock
    local navPage = NAV_BUTTON_PAGE[button]
    if navPage then
      if isDown then
        if navPage == currentPage and navPage == "media" then
          -- Re-pressing the already-active media page button doubles as
          -- play/pause, replacing the old dedicated playhead cluster.
          tapMediaKey("PLAY")
        else
          switchPage(navPage)
        end
      end
      return
    end

    local def = PAGES[currentPage][button]
    if not def or not def.action then
      if not isDown then stopRepeat(button) end
      return
    end

    if isDown then
      def.action()
      if def.repeatable then startRepeat(button, def) end
    else
      stopRepeat(button)
    end
  end)
end)
