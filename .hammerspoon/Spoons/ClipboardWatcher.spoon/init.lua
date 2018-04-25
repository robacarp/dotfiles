-- poor mans trim. only trims up to one character and only from the end.
local function miniTrim(str)
  local length = str:len()
  local lastChar = str:sub(length)
  if lastChar == "\n" then
    return str:sub(1, -2)
  end
  return str
end

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
  local contents = miniTrim(hs.pasteboard.readString())

  if not hs.pasteboard.typesAvailable()["string"] then
    self:markSeen(contents)
    return
  end

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
    self:clearDismissTimer()
    self.notification:withdraw()
    self.notification = nil
  end
end

function clipboard:clearDismissTimer()
  if self.dismissTimer then
    self.dismissTimer:stop()
    self.dismissTimer = nil
  end
end

function clipboard:displayNotification(originalText, watchNumber)
  local result = self.watches[watchNumber][2](originalText)

  if result == originalText then
    return
  end

  self:dismissNotification()

  self.notification = hs.notify.new(function(notification)
      self:markSeen(result)
      self:clearDismissTimer()
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
  )
  self.notification:send()

  if self.dismissDelay > 0 then
    self.dismissTimer = hs.timer.doAfter(self.dismissDelay, function()
      self:dismissNotification()
    end)
  end
end

function clipboard:stop()
  clipboard.timer:stop()
end

return clipboard
