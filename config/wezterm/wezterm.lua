-- WezTerm. Colours come from the desktop theme.
local wezterm = require("wezterm")
local config = wezterm.config_builder()

config.font = wezterm.font("JetBrainsMono Nerd Font")
config.font_size = 11
config.window_padding = { left = 10, right = 10, top = 8, bottom = 8 }
config.window_decorations = "NONE"
config.hide_tab_bar_if_only_one_tab = true
config.color_scheme = "Noctalia"

return config
