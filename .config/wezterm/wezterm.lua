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

local mouse_bindings = {
  {
    action = wezterm.action.OpenLinkAtMouseCursor,
    event = { Up = { streak = 1, button = 'Left' } },
    mods = 'CMD',
  },
  {
    action = wezterm.action.Nop,
    event = { Down = { streak = 1, button = 'Left' } },
    mods = 'CMD',
  },
}

local keyboard_bidings = {
  {
    key = 'f',
    mods = 'CMD|SHIFT',
    action = wezterm.action.ToggleFullScreen,
  }
}

local macos_config = {
  native_macos_fullscreen_mode = true,
}

local base_config = {
  mouse_bindings = mouse_bindings,
  keys = keyboard_bidings,
  bypass_mouse_reporting_modifiers = 'CMD',

  hide_tab_bar_if_only_one_tab = true,
  window_decorations = "RESIZE"
  color_scheme = scheme_for_appearance(get_appearance()),
  font = wezterm.font('Fira Code'),
  font_size = 14.5,

  check_for_updates = true,
}

if wezterm.target_triple == 'x86_64-apple-darwin' then
  for k, v in pairs(macos_config) do
    base_config[k] = v
  end
end

return base_config
