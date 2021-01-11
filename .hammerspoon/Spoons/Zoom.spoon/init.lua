--[[

 Known issues:
 * Mute is not detected properly during a Zoom Webinar
 * toggleMute() will stop working if the user changes state via the Zoom client

]]

local obj = {}
obj.__index = obj

-- Metadata
obj.name = "Unofficial Zoom Spoon"
obj.version = "1.0"
obj.author = "Joel Franusic"
obj.license = "MIT"
obj.homepage = "https://github.com/jpf/Zoom.spoon"

obj.callbackFunction = nil

function unpack (t, i)
  i = i or 1
  if t[i] ~= nil then
    return t[i], unpack(t, i + 1)
  end
end

-- via: https://github.com/kyleconroy/lua-state-machine/
local machine = dofile(hs.spoons.resourcePath("statemachine.lua"))

watcher = nil

zoomState = machine.create({
  initial = 'closed',
  events = {
    { name = 'start',        from = 'closed',  to = 'running' },
    { name = 'startMeeting', from = 'running', to = 'meeting' },
    { name = 'startShare',   from = 'meeting', to = 'sharing' },
    { name = 'endShare',     from = 'sharing', to = 'meeting' },
    { name = 'endMeeting',   from = 'meeting', to = 'running' },
    { name = 'stop',         from = 'running', to = 'closed' },
  },
  callbacks = {
    onstatechange = function(self, event, from, to)
      changeName = "from-" .. from .. "-to-" .. to

      if changeName == "from-running-to-meeting" then
        obj:_change(obj:getAudioStatus())
      end
      obj:_change(changeName)
    end,
  }
})

local endMeetingDebouncer = hs.timer.delayed.new(0.2, function()
  -- Only end the meeting if the "Meeting" menu is no longer present
  if not _check({"Meeting", "Invite"}) then
    zoomState:endMeeting()
  end
end)

function applicationWatcherEventReceived(appName, eventType, appObject)
  if (appName ~= "zoom.us") then return end

  -- if (eventType == hs.application.watcher.activated) then decoded = "activated" end
  -- if (eventType == hs.application.watcher.deactivated) then decoded = "deactivated" end
  -- if (eventType == hs.application.watcher.hidden) then decoded = "hidden" end
  -- if (eventType == hs.application.watcher.launched) then decoded = "launched" end
  -- if (eventType == hs.application.watcher.launching) then decoded = "launching" end
  -- if (eventType == hs.application.watcher.terminated) then decoded = "terminated" end
  -- if (eventType == hs.application.watcher.unhidden) then decoded = "unhidden" end

  if (eventType == hs.application.watcher.terminated) then
    hs.printf("deleting zoom watcher")
    if (watcher == nil) then return end

    watcher:stop()
    if zoomState:is('meeting') then endMeetingDebouncer:start() end
    zoomState:stop()
    watcher = nil

    return
  end

  if (watcher == nil) then
    hs.printf("creating zoom watcher")
    zoomState:start()
    watcher = appObject:newWatcher(zoomWatcher, { name = "zoom.us" })
    watcher:start({
      hs.uielement.watcher.windowCreated,
      hs.uielement.watcher.titleChanged,
      hs.uielement.watcher.elementDestroyed
    })
  end
end

function zoomWatcher(element, event, watcher, userData)
  local eventName = tostring(event)
  local windowTitle = ""
  if element['title'] ~= nil then
    windowTitle = element:title()
  end

  if(eventName == "AXTitleChanged" and windowTitle == "Zoom Meeting") then
    zoomState:startMeeting()
  elseif(eventName == "AXTitleChanged" and windowTitle == "Zoom Webinar") then
    zoomState:startMeeting()
  elseif(eventName == "AXWindowCreated" and windowTitle == "Zoom Meeting") then
    zoomState:endShare()
  elseif(eventName == "AXWindowCreated" and windowTitle == "Zoom Webinar") then
    zoomState:startMeeting()
  elseif(eventName == "AXWindowCreated" and windowTitle == "Zoom") then
    zoomState:start()
  elseif(eventName == "AXWindowCreated" and windowTitle:sub(1, #"zoom share") == "zoom share") then
    zoomState:startShare()
  elseif(eventName == "AXUIElementDestroyed") then
    endMeetingDebouncer:start()
  end
end

function obj:start()
  appWatcher:start()
end

function obj:stop()
  appWatcher:stop()
end

function _check(tbl)
  local application = hs.application.get("zoom.us")
  if (application ~= nil) then
    return application:findMenuItem(tbl) ~= nil
  end
end

function obj:_click(tbl)
  application = hs.application.get("zoom.us")
  if (application ~= nil) then
    return application:selectMenuItem(tbl)
  end
end

function obj:_change(changeEvent)
  if (self.callbackFunction) then
    self.callbackFunction(changeEvent)
  end
end

function obj:getAudioStatus()
  if _check({"Meeting", "Unmute Audio"}) then
    return 'muted'
  elseif _check({"Meeting", "Mute Audio"}) then
    return 'unmuted'
  else
    return 'off'
  end
end

--- Zoom:toggleMute()
--- Method
--- Toggles between the 'muted' and 'unmuted states'
function obj:toggleMute()
  audioStatus = self:getAudioStatus()

  if audioStatus == 'muted' then self:unmute() end
  if audioStatus == 'unmuted' then self:mute() end
end

--- Zoom:mute()
--- Method
--- Mutes the audio in Zoom, if Zoom is currently unmuted
function obj:mute()
  if obj:getAudioStatus() == 'unmuted' and self:_click({"Meeting", "Mute Audio"}) then
    hs.printf("seems like we muted")
    self:_change("muted")
  end
end

--- Zoom:unmute()
--- Method
--- Unmutes the audio in Zoom, if Zoom is currently muted
function obj:unmute()
  if obj:getAudioStatus() == 'muted' and self:_click({"Meeting", "Unmute Audio"}) then
    hs.printf("seems like we unmuted")
    self:_change("unmuted")
  end
end

function obj:inMeeting()
  return zoomState:is('meeting') or zoomState:is('sharing')
end

--- Zoom:setStatusCallback(func)
--- Method
--- Registers a function to be called whenever Zoom's state changes
---
--- Parameters:
--- * func - A function in the form "function(event)" where "event" is a string describing the state change event
function obj:setStatusCallback(func)
  self.callbackFunction = func
end

appWatcher = hs.application.watcher.new(applicationWatcherEventReceived)

return obj
