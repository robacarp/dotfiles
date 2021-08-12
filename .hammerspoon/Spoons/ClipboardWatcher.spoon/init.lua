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

function clipboard:watch(fxn, fxn2, automatic)
  automatic = automatic or false

  if type(fxn) == "function" and type(fxn2) == "function" then
    table.insert(self.watches, {fxn, fxn2, automatic})
  end
end

function clipboard:start()
  clipboard.timer = hs.timer.doEvery(self.interval, function()
    self:tick()
  end)
end

function clipboard:tick()
  local contents = hs.pasteboard.readString()
  if contents == nil then return end

  contents = miniTrim(contents)

  if self:haveSeen(contents) then return end

  self:markSeen(contents)
  self:dismissNotification()
  self:runWatches(contents)
end

function clipboard:runWatches(originalText)
  for i,watch in pairs(self.watches) do
    local matches = watch[1]
    local replace = watch[2]
    local autoReplace = watch[3]
    local replacement = replace(originalText)

    if matches(originalText) then
      if autoReplace then
        hs.pasteboard.writeObjects(replacement)
        self:markSeen(replacement)
        self:notifyReplaced(originalText, replacement)
      else
        hs.alert.show("requesting confirmation", 1)
        self:requestConfirmation(originalText, replacement)
      end
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



function clipboard:requestConfirmation(originalText, replacement)
  if replacement == originalText then
    return
  end

  self:dismissNotification()

  self.notification = hs.notify.new(function(notification)
      self:markSeen(replacement)
      self:clearDismissTimer()
      hs.pasteboard.writeObjects(replacement)
    end,
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
  self:setDismissalTimer()
end

function clipboard:notifyReplaced(originalText, result)
  if result == originalText then
    return
  end

  self:dismissNotification()

  self.notification = hs.notify.new(nil,
    {
      autoWithdraw = false,
      title = "Clipboard modified",
      informativeText = originalText .. " has been replaced with " .. result,
      hasActionButton = false
    }
  )
  self.notification:send()
  self:setDismissalTimer()
end


function clipboard:setDismissalTimer()
  if self.dismissDelay > 0 then
    self.dismissTimer = hs.timer.doAfter(self.dismissDelay, function()
      self:dismissNotification()
    end)
  end
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


function clipboard:stop()
  clipboard.timer:stop()
end

return clipboard
