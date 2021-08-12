split = dofile('./downloaded_modules/split.lua').split
url   = dofile('./downloaded_modules/url.lua')
inspect = dofile("./downloaded_modules/inspect.lua")

-- dismiss all active notifications
hs.notify.withdrawAll()
hs.window.animationDuration = 0

-- from the online examples, send the clipboard as regular keystrokes
hs.hotkey.bind({"cmd", "alt"}, "V", function()
  hs.alert.show('pasting the hard way...')
  hs.eventtap.keyStrokes(hs.pasteboard.getContents())
end)

hs.loadSpoon('ConfigReloader')
spoon.ConfigReloader:start()

hs.loadSpoon('ApplicationWatcher')
spoon.ApplicationWatcher:watchFor({
  bundleID = 'com.onnlucky.antirsi',
  name     = 'AntiRSI',
  interval = 23
})
spoon.ApplicationWatcher:start()

hs.loadSpoon('ClipboardWatcher')
spoon.ClipboardWatcher.interval = 1
spoon.ClipboardWatcher.dismissDelay = 9
spoon.ClipboardWatcher:watch(
  function(data)
    if string.len(data) > 2000 then
      return false
    end

    return string.match(data, "https?://www%.amazon%.com")
  end,

  function(original)
    local parsed_url = url.parse(original)
    -- Remove Amazon referral links
    parsed_url:setQuery({})

    local path_parts = split(parsed_url.path, "/")
    local new_path_parts = {}

    -- Remove extra url segments
    for i, part in pairs(path_parts) do
      local length = string.len(part)
      -- ASIN length = 10
      -- weird url prefix length = 2 (dp, gp, etc)
      if length == 10 or length == 2 or part == "product" then
        table.insert(new_path_parts, part)
      end
    end

    parsed_url.path = table.concat(new_path_parts, "/")
    return parsed_url:build()
  end
)

spoon.ClipboardWatcher:watch(
  function(data)
    if string.len(data) > 150 then return false end
    return string.match(data, "^https://music%.apple%.com.+")
  end,

  function(original)
    return "https://songwhip.com/" .. original
  end,

  true
)
spoon.ClipboardWatcher:start()

success_image = hs.image.imageFromPath("/Users/robert/.hammerspoon/pass.png")
failure_image = hs.image.imageFromPath("/Users/robert/.hammerspoon/fail.png")

hs.urlevent.bind("task_completed", function(eventName, params)
  local message = params['message']
  local status = params['status']
  local timeout = tonumber(params['timeout'])

  if not message or message:len() == 0 then
    message = "Long running command completed"
  end

  if not timeout then
    timeout = 11
  end

  local notification = hs.notify.new(function() end,
    {
      autoWithdraw = true,
      title = "Terminal Notification",
      informativeText = message,
      hasActionButton = false
    }
  )

  if status == "0" then
    if success_image then
      notification:setIdImage(success_image)
    end
  else
    if failure_image then
      notification:setIdImage(failure_image)
    end
  end

  notification:send()

  if timeout > 0 then
    hs.timer.doAfter(timeout, function()
      notification:withdraw()
    end)
  end
end)

-- Zoom stuff

hs.loadSpoon("Zoom")

-- This lets you click on the menu bar item to toggle the mute state
zoomStatusMenuBarItem = hs.menubar.new(nil)
zoomStatusMenuBarItem:setClickCallback(function()
    spoon.Zoom:toggleMute()
end)

updateZoomStatus = function(event)
  if (event == "from-running-to-meeting") then
    zoomStatusMenuBarItem:returnToMenuBar()
  elseif (event == "muted") then
    zoomStatusMenuBarItem:setTitle("🔴")
  elseif (event == "unmuted") then
    zoomStatusMenuBarItem:setTitle("🟢")
  elseif (event == "from-meeting-to-running") or (event == "from-running-to-closed") then
    zoomStatusMenuBarItem:removeFromMenuBar()
  end
end
spoon.Zoom:setStatusCallback(updateZoomStatus)
spoon.Zoom:start()

-- Next up:
-- https://github.com/adamyonk/PushToTalk.spoon/blob/master/init.lua
hs.hotkey.bind('', 'f13', function()
  spoon.Zoom:toggleMute()
end)

----------------------------------------------------------------

hs.alert.show('HammerSpoon Activated.', 1)
