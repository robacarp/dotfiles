-- AntiRSI watcher
local antiRSINotification = nil
function checkAntiRSI()
  if hs.application.find('com.onnlucky.antirsi') == nil then

    if antiRSINotification ~= nil then
      antiRSINotification:withdraw()
    end

    antiRSINotification = hs.notify.new('AntiRSI launcher',
      {
        autoWithdraw = true,
        title = 'PRACABOR HEAVY INDUSTRIES',
        subTitle = 'Department of Health and Safety',
        informativeText = 'AntiRSI is not running',
        hasActionButton = true,
        actionButtonTitle = 'Launch!'
      }
    ):send()
  end
end

local applicationWatcher = hs.timer.new(60 * 15, checkAntiRSI)
applicationWatcher:start()
applicationWatcher:setNextTrigger(3)

hs.notify.register('AntiRSI launcher', function()
  antiRSINotification = nil
  hs.application.launchOrFocusByBundleID('com.onnlucky.antirsi')
end)
