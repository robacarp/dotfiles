local applicationWindowWatcher = {}

function applicationWindowWatcher:new()
  local watcher = {
    currentApplication = nil,
    windowTitle = 'hi',
    applicationWatcher = nil,
    windowWatcher = nil,
    callOnWindowChange = {}
  }

  local object = setmetatable(watcher, self)

  object.windowWatcher = hs.timer.doEvery(1, function()
    object:_checkIfWindowChanged()
  end)

  self.__index = self
  return watcher
end

  function applicationWindowWatcher:onWindowChange(callback)
    table.insert(self.callOnWindowChange, callback)
  end

  function applicationWindowWatcher:_checkIfWindowChanged()
    if not (self.currentApplication == hs.application.frontmostApplication()) then
      self.currentApplication = hs.application.frontmostApplication()
    end

    if not (self.windowTitle == self.currentApplication:focusedWindow():title()) then
      self.windowTitle = self.currentApplication:focusedWindow():title()

      for i = 1, #self.callOnWindowChange do
        self.callOnWindowChange[i](self.currentApplication, self.currentApplication:focusedWindow())
      end
    end
  end

return applicationWindowWatcher
