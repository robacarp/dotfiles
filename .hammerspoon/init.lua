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
spoon.ClipboardWatcher.dismissDelay = 0
spoon.ClipboardWatcher:watch(
  function(data)
    return string.match(data, "https?://www%.amazon%.com")
  end,

  function(original)
    local parsed_url = url.parse(original)

    local path_parts = split(parsed_url.path, "/")
    local new_path_parts = {}

    for i, part in pairs(path_parts) do
      local length = string.len(part)
      -- ASIN length = 10
      -- weird url prefix length = 2
      if length == 10 or length == 2 then
        table.insert(new_path_parts, part)
      end
    end

    parsed_url.path = table.concat(new_path_parts, "/")
    return parsed_url:build()
  end
)
spoon.ClipboardWatcher:start()

hs.alert.show('HammerSpoon Activated.', 1)
