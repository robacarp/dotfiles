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

-- Main modal object
modal = ModalYoLo:new('f6')

-- Left, 80% wide
modal:bind('7', function(mutator)
  mutator:x(0):y(0):w(mutator.screen.w * 0.8):h(mutator.screen.h):commit()
end)

-- Left
modal:bind('8', function(mutator)
  mutator:x(0):y(0):w(mutator.screen.w * 0.5):h(mutator.screen.h):commit()
end)

-- Right
modal:bind('9', function(mutator)
  mutator:x(mutator.screen.w * 0.5):y(0):w(mutator.screen.w * 0.5):h(mutator.screen.h):commit()
end)

-- Right 80% wide
modal:bind('0', function(mutator)
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

hs.alert.show('HammerSpoon Activated.', 1)

