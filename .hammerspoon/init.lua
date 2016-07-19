hs.notify.withdrawAll()

local ModalYoLo = require('yolo')

hs.window.animationDuration = 0
function reloadConfig(files)
  doReload = false
  for _,file in pairs(files) do
    if file:sub(-4) == '.lua' then
      doReload = true
    end
  end

  if doReload then
    hs.reload()
  end
end
hs.pathwatcher.new(os.getenv('HOME') .. '/.hammerspoon/', reloadConfig):start()

-- from the example, send the clipboard as regular keystrokes
hs.hotkey.bind({"cmd", "alt"}, "V", function() hs.eventtap.keyStrokes(hs.pasteboard.getContents()) end)

-- AntiRSI watcher
local antiRSINotification = nil
function checkAntiRSI()
  if hs.application.find('com.onnlucky.antirsi') == nil then

    if antiRSINotification ~= nil then
      antiRSINotification:withdraw()
    end

    antiRSINotification = hs.notify.new('AntiRSI launcher',
      {
        autoWithdraw = true,
        title = 'PRACABOR HEAVY INDUSTRIES',
        subTitle = 'Department of Health and Safety',
        informativeText = 'AntiRSI is not running',
        hasActionButton = true,
        actionButtonTitle = 'Launch!'
      }
    ):send()
  end
end

local applicationWatcher = hs.timer.new(60 * 15, checkAntiRSI)
applicationWatcher:start()
applicationWatcher:setNextTrigger(3)

hs.notify.register('AntiRSI launcher', function()
  antiRSINotification = nil
  hs.application.launchOrFocusByBundleID('com.onnlucky.antirsi')
end)

-- Main modal object
modal = ModalYoLo:new('f6')



-- Left Columns
-- 20% wide
modal:bind('h', function(mutator)
  mutator:x(0):y(0):w(mutator.screen.w * 0.2):h(mutator.screen.h):commit()
end)

-- 50% wide
modal:bind('g', function(mutator)
  mutator:x(0):y(0):w(mutator.screen.w * 0.5):h(mutator.screen.h):commit()
end)

-- 80% wide
modal:bind('7', function(mutator)
  mutator:x(0):y(0):w(mutator.screen.w * 0.8):h(mutator.screen.h):commit()
end)


-- Centered Column
-- 20% wide
modal:bind('t', function(mutator)
  mutator:x(mutator.screen.w * 0.4):y(0):w(mutator.screen.w * 0.2):h(mutator.screen.h):commit()
end)

-- 50% wide
modal:bind('c', function(mutator)
  mutator:x(mutator.screen.w * 0.25):y(0):w(mutator.screen.w * 0.5):h(mutator.screen.h):commit()
end)

-- 80% wide
modal:bind('8', function(mutator)
  mutator:x(mutator.screen.w * 0.1):y(0):w(mutator.screen.w * 0.8):h(mutator.screen.h):commit()
end)



-- Right Columns
-- 20% wide
modal:bind('n', function(mutator)
  mutator:x(mutator.screen.w * 0.8):y(0):w(mutator.screen.w * 0.2):h(mutator.screen.h):commit()
end)

-- 50% wide
modal:bind('r', function(mutator)
  mutator:x(mutator.screen.w * 0.5):y(0):w(mutator.screen.w * 0.5):h(mutator.screen.h):commit()
end)

-- 80% wide
modal:bind('9', function(mutator)
  mutator:x(mutator.screen.w * 0.2):y(0):w(mutator.screen.w * 0.8):h(mutator.screen.h):commit()
end)



-- 4 corners grid view
-- top left
modal:bind('1', function(mutator)
  mutator:x(0):y(0):w(mutator.screen.w * 0.5):h(mutator.screen.h * 0.5):commit()
end)

-- top right
modal:bind('2', function(mutator)
  mutator:x(mutator.screen.w * 0.5):y(0):w(mutator.screen.w * 0.5):h(mutator.screen.h * 0.5):commit()
end)

-- bottom left
modal:bind('\'', function(mutator)
  mutator:x(0):y(mutator.screen.h * 0.5):w(mutator.screen.w * 0.5):h(mutator.screen.h * 0.5):commit()
end)

-- bottom right
modal:bind(',', function(mutator)
  mutator:x(mutator.screen.w * 0.5):y(mutator.screen.h * 0.5):w(mutator.screen.w * 0.5):h(mutator.screen.h * 0.5):commit()
end)

-- full screen
modal:bind('5', function(mutator)
  mutator:x(0):y(0):w(mutator.screen.w):h(mutator.screen.h):commit()
end)


-- Top and bottom split view
-- Top
modal:bind('d', function(mutator)
  mutator:x(0):y(0):w(mutator.screen.w):h(mutator.screen.h * 0.5):commit()
end)

-- Bottom
modal:bind('b', function(mutator)
  mutator:x(0):y(mutator.screen.h * 0.5):w(mutator.screen.w):h(mutator.screen.h * 0.5):commit()
end)


hs.alert.show('HammerSpoon Activated.', 1)

