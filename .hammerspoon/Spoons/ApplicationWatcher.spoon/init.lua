local function script_path()
    local str = debug.getinfo(2, "S").source:sub(2)
    return str:match("(.*/)")
end

local appWatcher = {}
appWatcher.__index = appWatcher

appWatcher.name = "Application Watcher"
appWatcher.version = "0.1"
appWatcher.author = "Robert Carpenter"
appWatcher.license = "MIT - https://opensource.org/licenses/MIT"

spoonDir = script_path()
watcher = dofile(spoonDir.."watcher.lua")
inspect = dofile("/Users/robert/.hammerspoon/downloaded_modules/inspect.lua")

appWatcher.watchers = {}

function appWatcher:init()
end

function appWatcher:watchFor(options)
  table.insert(self.watchers, watcher:new(options))
end

function appWatcher:start()
  for i, watcher in pairs(self.watchers) do
    watcher:start()
  end
end

function appWatcher:stop()
  for i, watcher in pairs(self.watchers) do
    watcher:start()
  end
end

return appWatcher

