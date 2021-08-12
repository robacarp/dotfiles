local reloader = {}
reloader.__index = reloader

reloader.name = "Config Reloader"
reloader.version = "0.1"
reloader.license = "MIT - https://opensource.org/licenses/MIT"

reloader.watcher = nil

function reloader:init()
end

function reloader:start()
  path = os.getenv('HOME') .. '/.hammerspoon/'
  self.watcher = hs.pathwatcher.new(
    path,

    function(files, flags)
      should_reload = false
      for _,file in pairs(files) do
        if file:sub(-4) == '.lua' then
          should_reload = true
        end
      end

      if should_reload then
        hs.reload()
      end
    end
  )

  self.watcher:start()
end

function reloader:stop()
  self.watcher:stop()
end

return reloader
