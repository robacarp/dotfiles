require('anti_rsi_watcher')
require('window_management')
local timerManager = require('timers')

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

})


hs.alert.show('HammerSpoon Activated.', 1)
