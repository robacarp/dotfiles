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
      mutator(Mutation:new())
    end)
  end

-- a mutation object is what allows chainable transforms
Mutation = {}
function Mutation:new()
  local obby = {
    frame_x = 0,
    frame_y = 0,
    frame_w = 1000,
    frame_h = 1000,
    screen  = hs.screen.mainScreen():fullFrame(),
    window  = hs.window.focusedWindow()
  }

  self.__index = self
  return setmetatable(obby, self)
end

  function Mutation:debug()
   -- hs.alert.show(
    --   "Heights: frame:" .. scr:frame().h .. ", fullFrame:" .. scr:fullFrame().h .. "\n" ..
    --   "\tframe / fullFrame:" .. scr:frame().h / scr:fullFrame().h
    -- )

    hs.alert.show(
      "X / Y: " .. self.frame_x .. ", " .. self.frame_y .. "\n" ..
      "W / H: " .. self.frame_w .. ", " .. self.frame.h
    , 3)
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

  function Mutation:adjust_frame()
    screen = hs.screen.mainScreen()
    local y_offset = screen:fullFrame().h - screen:frame().h
    local x_offset = screen:fullFrame().w - screen:frame().w

    h_multiplier = screen:frame().h / screen:fullFrame().h
    w_multiplier = screen:frame().w / screen:fullFrame().w

    self.frame_x = self.frame_x * w_multiplier + x_offset
    self.frame_y = self.frame_y * h_multiplier + y_offset
    self.frame_w = self.frame_w * w_multiplier
    self.frame_h = self.frame_h * h_multiplier
  end

  function Mutation:commit()
    self:adjust_frame()
    self.window:setFrame(self:buildFrame())
  end

  function Mutation:buildFrame()
    return hs.geometry(
      self.frame_x,
      self.frame_y,
      self.frame_w,
      self.frame_h
    )
  end


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

