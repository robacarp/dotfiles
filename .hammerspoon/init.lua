function reloadConfig(files)
  doReload = false
  for _,file in pairs(files) do
    if file:sub(-4) == '.lua' then
      doReload = true
    end
  end

  if doReload then
    hs.reload()
  end
end

function environment()
  local win = hs.window.focusedWindow()
  local scr = win:screen()

  return {
    window = win,
    frame = win:frame(),
    screen = win:screen(),
    screen_size = scr:frame()
  }
end

hs.window.animationDuration = 0
hs.pathwatcher.new(os.getenv('HOME') .. '/.hammerspoon/', reloadConfig):start()
hs.alert.show('Config loaded')

activation_key = hs.hotkey.modal.new('', 'f6')
activation_key:bind('', 'escape', function()
  activation_key:exit()
end)

activation_key:bind('','9', function()
  local env = environment()

  env.frame.x = 0
  env.frame.y = 0
  env.frame.w = env.screen_size.w / 2
  env.frame.h = env.screen_size.h * 0.85

  env.window:setFrame(env.frame)
  activation_key:exit()
end)

activation_key:bind('','0', function()
  local env = environment()

  env.frame.x = env.screen_size.w / 2
  env.frame.y = 0
  env.frame.w = env.screen_size.w / 2
  env.frame.h = env.screen_size.h * 0.85

  env.window:setFrame(env.frame)
  activation_key:exit()
end)

activation_key:bind('','r', function()
  local env = environment()

  env.frame.x = 0
  env.frame.y = 0
  env.frame.w = env.screen_size.w / 2
  env.frame.h = env.screen_size.h

  env.window:setFrame(env.frame)
  activation_key:exit()
end)

activation_key:bind('','l', function()
  local env = environment()

  env.frame.x = env.screen_size.w / 2
  env.frame.y = 0
  env.frame.w = env.screen_size.w / 2
  env.frame.h = env.screen_size.h

  env.window:setFrame(env.frame)
  activation_key:exit()
end)

