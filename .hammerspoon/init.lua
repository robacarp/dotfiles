split = dofile('./downloaded_modules/split.lua').split
url   = dofile('./downloaded_modules/url.lua')
inspect = dofile("./downloaded_modules/inspect.lua")
streamdeck = dofile('./streamdeck-media.lua')

-- dismiss all active notifications
hs.notify.withdrawAll()
hs.window.animationDuration = 0

-- from the online examples, send the clipboard as regular keystrokes
hs.hotkey.bind({"cmd", "alt"}, "V", function()
  hs.alert.show('pasting the hard way...')
  hs.eventtap.keyStrokes(hs.pasteboard.getContents())
end)

hs.loadSpoon('ConfigReloader')
spoon.ConfigReloader:start()

-- hs.loadSpoon('ApplicationWatcher')
-- spoon.ApplicationWatcher:watchFor({
--   bundleID = 'com.onnlucky.antirsi',
--   name     = 'AntiRSI',
--   interval = 23
-- })
-- spoon.ApplicationWatcher:start()

hs.loadSpoon('ClipboardWatcher')
spoon.ClipboardWatcher.interval = 1
spoon.ClipboardWatcher.dismissDelay = 9
spoon.ClipboardWatcher:start()
spoon.ClipboardWatcher:watch(
  function(data)
    if string.len(data) > 2000 then
      return false
    end

    return string.match(data, "https?://www%.amazon%.com")
  end,

  function(original)
    local parsed_url = url.parse(original)
    -- Remove Amazon referral links
    -- parsed_url:setQuery({tag = "tornado01e-20"})

    local path_parts = split(parsed_url.path, "/")
    local new_path_parts = {}

    -- Remove extra url segments
    for i, part in pairs(path_parts) do
      local length = string.len(part)
      -- ASIN length = 10
      -- weird url prefix length = 2 (dp, gp, etc)
      if length == 10 or length == 2 or part == "product" then
        table.insert(new_path_parts, part)
      end
    end

    parsed_url.path = table.concat(new_path_parts, "/")
    return parsed_url:build()
  end,

  true
)

-- ClickUp "shared" notetaker for Google Meet links.
-- Auth token lives in Keychain (service below), not here - it's a session
-- bearer token that expires in ~24h. Refresh with:
--   security add-generic-password -U -a "clickup-notetaker" \
--     -s "hammerspoon-clickup-notetaker" -w "<bearer token>"
local CLICKUP_KEYCHAIN_SERVICE = "hammerspoon-clickup-notetaker"
local CLICKUP_WORKSPACE_ID = "90131407359"
local meetWatcherNotification = nil
local meetWatcherDismissTimer = nil
local meetWatcherDismissDelay = 10

local function clickupBearerToken()
  local output, status = hs.execute(
    "security find-generic-password -s " .. CLICKUP_KEYCHAIN_SERVICE .. " -w 2>/dev/null"
  )
  if not status or not output then return nil end
  local token = output:gsub("%s+$", "")
  if token == "" then return nil end
  return token
end

local function addClickupNotetaker(meetingUrl)
  local token = clickupBearerToken()
  if not token then
    hs.alert.show("No ClickUp token in Keychain - see init.lua for setup")
    return
  end

  local headers = {
    ["Content-Type"] = "application/json",
    ["Accept"] = "application/json",
    ["Authorization"] = "Bearer " .. token,
    ["X-Workspace-ID"] = CLICKUP_WORKSPACE_ID,
    ["X-CSRF"] = "1",
    ["Origin"] = "https://app.clickup.com",
    ["Referer"] = "https://app.clickup.com/",
  }

  local body = hs.json.encode({
    meetingUrl = meetingUrl,
    noteTakerLevel = "shared"
  })

  hs.http.asyncPost(
    "https://frontdoor-prod-us-east-2-1.clickup.com/data/v3/workspaces/" .. CLICKUP_WORKSPACE_ID .. "/meeting_bot/send",
    body,
    headers,
    function(status, responseBody, responseHeaders)
      if status >= 200 and status < 300 then
        hs.notify.new(nil, {
          autoWithdraw = true,
          title = "ClickUp Notetaker added",
          informativeText = "Shared notetaker is joining " .. meetingUrl
        }):send()
      elseif status == 401 or status == 403 then
        hs.alert.show("ClickUp auth expired - refresh token in Keychain")
      else
        hs.alert.show("ClickUp notetaker request failed (" .. status .. ")")
      end
    end
  )
end

local function isMeetLink(text)
  return string.match(text, "https?://meet%.google%.com/[%a%-]+") ~= nil
end

-- Registered through the same watch() the Amazon link cleanup uses above,
-- so it shares that one polling/dedup timer instead of running its own.
-- "replace" here doesn't change the clipboard text - it always returns the
-- input unchanged, so the Spoon's own auto-write/notifyReplaced end up as
-- harmless no-ops. Its real job is firing our own action notification,
-- gated by isMeetLink() since replace() runs on every clipboard change,
-- not just matches.
spoon.ClipboardWatcher:watch(
  isMeetLink,

  function(text)
    if not isMeetLink(text) then return text end

    local meetingUrl = string.match(text, "https?://meet%.google%.com/[%a%-]+")

    if meetWatcherDismissTimer then meetWatcherDismissTimer:stop() end
    if meetWatcherNotification then meetWatcherNotification:withdraw() end

    meetWatcherNotification = hs.notify.new(function()
        addClickupNotetaker(meetingUrl)
      end,
      {
        autoWithdraw = false,
        title = "Google Meet link copied",
        informativeText = "Add the ClickUp shared notetaker to this meeting?",
        hasActionButton = true,
        actionButtonTitle = "Add Notetaker"
      }
    )
    meetWatcherNotification:send()

    meetWatcherDismissTimer = hs.timer.doAfter(meetWatcherDismissDelay, function()
      if meetWatcherNotification then
        meetWatcherNotification:withdraw()
        meetWatcherNotification = nil
      end
    end)

    return text
  end,

  true
)

success_image = hs.image.imageFromPath(hs.configdir .. "/pass.png")
failure_image = hs.image.imageFromPath(hs.configdir .. "/fail.png")

hs.urlevent.bind("task_completed", function(eventName, params)
  local message = params['message']
  local status = params['status']
  local timeout = tonumber(params['timeout'])

  if not message or message:len() == 0 then
    message = "Long running command completed"
  end

  if not timeout then
    timeout = 11
  end

  local notification = hs.notify.new(function() end,
    {
      autoWithdraw = true,
      title = "Terminal Notification",
      informativeText = message,
      hasActionButton = false
    }
  )

  if status == "0" then
    if success_image then
      notification:setIdImage(success_image)
    end
  else
    if failure_image then
      notification:setIdImage(failure_image)
    end
  end

  notification:send()

  if timeout > 0 then
    hs.timer.doAfter(timeout, function()
      notification:withdraw()
    end)
  end
end)

hs.alert.show('HammerSpoon Activated.', 1)
