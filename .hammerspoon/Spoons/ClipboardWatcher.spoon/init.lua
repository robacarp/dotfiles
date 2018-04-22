local clipboard = {}
clipboard.__index = clipboard

clipboard.interval = 1
clipboard.dismissDelay = 10

clipboard.timer = nil
clipboard.watches = {}
clipboard.notification = nil
clipboard.dismissTimer = nil

inspect = dofile("/Users/robert/.dotfiles/.hammerspoon/downloaded_modules/inspect.lua")

function clipboard:init()
  self:markSeen(
    hs.pasteboard.readString()
  )
end

function clipboard:watch(fxn, fxn2)
  if type(fxn) == "function" and type(fxn2) == "function" then
    table.insert(self.watches, {fxn, fxn2})
  end
end

function clipboard:start()
  clipboard.timer = hs.timer.doEvery(self.interval, function()
    self:tick()
  end)
end

function clipboard:tick()
  if not hs.pasteboard.typesAvailable()["string"] then
    self:markSeen(contents)
    return
  end

  local contents = hs.pasteboard.readString()
  if self:haveSeen(contents) then return end

  self:markSeen(contents)
  self:dismissNotification()
  self:runWatches(contents)
end

function clipboard:runWatches(data)
  for i,watch in pairs(self.watches) do
    if watch[1](data) then
      self:displayNotification(data, i)
    end
  end
end

function clipboard:markSeen(contents)
  self.previousContents = contents
end

function clipboard:markUnseen()
  self.previousContents = nil
end

function clipboard:haveSeen(contents)
  return self.previousContents == contents
end



function clipboard:dismissNotification()
  if self.notification then
    self.notification:withdraw()
    self.notification = nil
  end
end

function clipboard:displayNotification(originalText, watchNumber)
  local result = self.watches[watchNumber][2](originalText)
  self:dismissNotification()

  self.notification = hs.notify.new(function()
      self:markSeen(result)
      hs.pasteboard.writeObjects(result)
    end
    ,
    {
      autoWithdraw = false,
      title = "Clipboard modification suggested",
      subTitle = "Replace your clipboard with: ",
      informativeText = result,
      hasActionButton = true,
      actionButtonTitle = "Replace!"
    }
  ):send()

  if self.dissmissDelay > 0 then
    self.dismissTimer = hs.timer.doAfter(self.dismissDelay, function()
      self:dismissNotification()
    end)
  end
end

function clipboard:stop()
  clipboard.timer:stop()
end

return clipboard
