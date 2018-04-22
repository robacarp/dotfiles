local watcher = {}
watcher.__index = watcher

watcher.notification = {}
watcher.notification.title = 'Watcher'
watcher.notification.subTitle = ''
watcher.notification.hasActionButton = true
watcher.notification.actionButtonTitle = 'Launch!'
watcher.notification.autoWithdraw = true

watcher.applicationBundleID = ''
watcher.applicationName = ''
watcher.watchInterval = 60 * 15

watcher.timer = nil
watcher.currentNotification = nil

-- Merge table B into table A. Destructive.
local function deepTableMerge(a, b)
  for k,v in pairs(b) do
    if type(a[k]) == 'table' then
      deepTableMerge(a[k], v)
    else
      a[k] = v
    end
  end

  return a
end

function watcher:new(config)
  local struct = {
    notification = {
      title = 'Watcher',
      subTitle = '',
      hasActionButton = true,
      actionButtonTitle = 'Launch!',
      autoWithdraw = true
    },

    bundleID = '',
    name = '',
    interval = 60 * 15
  }

  local internals = {
    timer = nil,
    currentNotification = nil
  }

  deepTableMerge(struct, config)
  deepTableMerge(struct, internals)

  local object = setmetatable(struct, self)
  self.__index = self
  return object
end

function watcher:start()
  self.timer = hs.timer.new(self.watchInterval, function()
    self:look()
  end)
  self.timer:start()
  self.timer:setNextTrigger(1)
end

function watcher:stop()
  self.timer:stop()
end

function watcher:look()
  if hs.application.find( self.bundleID ) == nil then
    self:notify()
  end
end

function watcher:notify()
  if self.currentNotification then
    self.currentNotification:withdraw()
  end

  self.currentNotification = hs.notify.new(function()
      self:launch()
    end,
    {
      autoWithdraw = self.notification.autoWithdraw,
      title = self.notification.title,
      subTitle = self.notification.subTitle,
      informativeText = self.name..' is not running!',
      hasActionButton = self.notification.hasActionButton,
      actionButtonTitle = self.notification.actionButtonTitle
    }
  ):send()
end

function watcher:launch()
  hs.application.launchOrFocusByBundleID( self.bundleID )
end

return watcher

