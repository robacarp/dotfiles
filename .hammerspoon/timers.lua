local timerManager = {}

local windowWatcher = require('application_window_watcher')

function timerManager:new()
  local struct = {
    triggers = {},
    watcher = windowWatcher:new()
  }

  local object = setmetatable(struct, self)

  object.watcher:onWindowChange(function (application, window)
    object:triggerByApplicationWindow(application:name(), window:title())
  end)

  self.__index = self
  return object
end

  function timerManager:defineTrigger(config)
    table.insert(self.triggers, config)
  end

  function timerManager:triggerByApplicationWindow(application_name, window_name)
    print("Current Application: " .. application_name .. " Window: " .. window_name)
    for i = 1, #self.triggers do
      trigger = self.triggers[i]
      if trigger.application and trigger.window then
        print("checking for " .. trigger.application .. " with a window " .. trigger.window)
      elseif trigger.application then
        print("checking for " .. trigger.application)
        if trigger.application == application_name then
          print "success"
        end
      elseif trigger.window then
        print("checking for a window called" .. trigger.window)
      end
    end
  end

return timerManager
