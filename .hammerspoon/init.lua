require('anti_rsi_watcher')
require('window_management')
require('config_reloader')
local timerManager = require('timers')

-- dismiss all active notifications
hs.notify.withdrawAll()

hs.window.animationDuration = 0

-- from the online examples, send the clipboard as regular keystrokes
hs.hotkey.bind({"cmd", "alt"}, "V", function() hs.eventtap.keyStrokes(hs.pasteboard.getContents()) end)

-- timerManager = timerManager:new()
-- timerManager:defineTrigger({
--   application = 'Terminal',
--   action = nil
-- })

local Toggl = require('toggl')

local toggle_api = Toggl:new({
  -- username = '',
  -- password = ''
  api_key = '8d3212a47f2cce22d46300d3ff75c7d6'
})

-- local api_key = toggle_api:fetch_api_key()
-- print("API key is " .. api_key)

workspaces = toggle_api:get_workspaces()
local inspect = require('downloaded_modules/inspect')
print("Got " .. #workspaces .. " workspaces")
hs.alert.show('HammerSpoon Activated.', 1)
