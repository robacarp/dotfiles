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

return Mutation
