local wezterm = require 'wezterm'

function get_appearance()
  if wezterm.gui then
    return wezterm.gui.get_appearance()
  end

  return 'Dark'
end

function scheme_for_appearance(appearance)
  if appearance:find 'Dark' then
    return 'Builtin Solarized Dark'
  else
    return 'Builtin Solarized Light'
  end
end

config = wezterm.config_builder()
config.mouse_bindings = {
  {
    action = wezterm.action.OpenLinkAtMouseCursor,
    event = { Up = { streak = 1, button = 'Left' } },
    mods = 'CMD',
  },
  {
    action = wezterm.action.Nop,
    event = { Down = { streak = 1, button = 'Left' } },
    mods = 'CMD',
  }
}

config.keys = {
  {
    key = 'f',
    mods = 'CMD|SHIFT',
    action = wezterm.action.ToggleFullScreen,
  }
}

config.bypass_mouse_reporting_modifiers = 'CMD'

config.hide_tab_bar_if_only_one_tab = true
config.window_decorations = "RESIZE"
config.font = wezterm.font('Fira Code')
config.font_size = 14.5

if wezterm.target_triple == 'aarch64-apple-darwin' then
  config.native_macos_fullscreen_mode = true
  config.color_scheme = scheme_for_appearance(get_appearance())
end

return config
