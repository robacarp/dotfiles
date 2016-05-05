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

-- modalyolo keeps track of bindings and allows us to wrap all events
ModalYoLo = {}
function ModalYoLo:new(modal_key)
  local obby = {
    binding = hs.hotkey.modal.new('',modal_key)
  }

  -- disable binding on escape key
  obby.binding:bind('', 'escape', function()
    obby.binding:exit()
  end)

  -- automatically disable modal key after 1 second
  function obby.binding:entered()
    hs.timer.doAfter(1, function()
      obby.binding:exit()
    end)
  end

  self.__index = self
  return setmetatable(obby, self)
end

  -- bind a key to an action under the modal
  function ModalYoLo:bind(key, mutator)
    self.binding:bind('', key, function()
      self.binding:exit()
      mutator(State:new(), Mutation:new())
    end)
  end

-- a mutation object is what allows chainable transforms
Mutation = {}
function Mutation:new()
  local win = hs.window.focusedWindow()
  local scr = win:screen()

  local obby = {
    frame_x = 0,
    frame_y = 0,
    frame_w = 1000,
    frame_h = 1000,
    frame   = win:frame(),
    screen  = scr,
    window  = win
  }

  self.__index = self
  return setmetatable(obby, self)
end

  function Mutation:debug()
    hs.alert.show( table.tostring(self), 6 )
  end

  function Mutation:x(ex)
    self.frame_x = ex
    return self
  end

  function Mutation:y(ey)
    self.frame_y = ey
    return self
  end

  function Mutation:h(eh)
    self.frame_h = eh
    return self
  end

  function Mutation:w(ew)
    self.frame_w = ew
    return self
  end

  function Mutation:commit()
    self.frame.x = self.frame_x
    self.frame.y = self.frame_y
    self.frame.w = self.frame_w
    self.frame.h = self.frame_h

    self.window:setFrame(self.frame)
  end


-- State objects are constructed before each key responder
State = {}
function State:new()
  local win = hs.window.focusedWindow()
  local scr = win:screen()

  local obby = {
    frame_x = win:frame().x,
    frame_y = win:frame().y,
    frame_h = win:frame().h,
    frame_w = win:frame().w,

    scr_half_w  = scr:frame().w / 2,
    scr_half_h  = scr:frame().h / 2,

    scr_w   = scr:frame().w,
    scr_h   = scr:frame().h
  }

  self.__index = self
  return setmetatable(obby, self)
end


-- Main modal object

modal = ModalYoLo:new('f6')

-- Left and right columns (80% and full)
-- Right, 80% tall
modal:bind('0', function(s,mutator)
  mutator:x(s.scr_half_w):y(0):w(s.scr_half_w):h(s.scr_h * 0.8):commit()
end)

-- Right, 80% tall
modal:bind('9', function(s,mutator)
  mutator:x(0):y(0):w(s.scr_half_w):h(s.scr_h * 0.8):commit()
end)

-- Left, full height
modal:bind('r', function(s, mutator)
  mutator:x(0):y(0):w(s.scr_half_w):h(s.scr_h):commit()
end)

-- Right, full height
modal:bind('l', function(s, mutator)
  mutator:x(s.scr_half_w):y(0):w(s.scr_half_w):h(s.scr_h):commit()
end)

-- 4 corners grid view
-- top left
modal:bind('1', function(s, mutator)
  mutator:x(0):y(0):w(s.scr_half_w):h(s.scr_half_h):commit()
end)

-- top right
modal:bind('2', function(s, mutator)
  mutator:x(s.scr_half_w):y(0):w(s.scr_half_w):h(s.scr_half_h):commit()
end)

-- bottom left
modal:bind('\'', function(s, mutator)
  mutator:x(0):y(s.scr_half_h):w(s.scr_half_w):h(s.scr_half_h):commit()
end)

-- bottom right
modal:bind(',', function(s, mutator)
  mutator:x(s.scr_half_w):y(s.scr_half_h):w(s.scr_half_w):h(s.scr_half_h):commit()
end)

-- full screen
modal:bind('5', function(s, mutator)
  mutator:x(0):y(0):w(s.scr_w):h(s.scr_h):commit()
end)

hs.alert.show('Config loaded', 1)

