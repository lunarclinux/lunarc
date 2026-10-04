-- Look, input and behaviour defaults.

hl.monitor({ output = "", mode = "preferred", position = "auto", scale = "auto" })

hl.env("XCURSOR_SIZE", "24")
hl.env("HYPRCURSOR_SIZE", "24")

hl.config({
    general = {
        gaps_in = 4,
        gaps_out = 8,
        border_size = 2,
        col = {
            active_border = "rgba(d8a657ff)",
            inactive_border = "rgba(3c3836ff)",
        },
        layout = "dwindle",
    },
    decoration = {
        rounding = 6,
        shadow = { enabled = true, range = 6, render_power = 3, color = 0x99000000 },
        blur = { enabled = true, size = 4, passes = 2 },
    },
    animations = { enabled = true },
    dwindle = { preserve_split = true },
    input = {
        kb_layout = "us",
        follow_mouse = 1,
        touchpad = { natural_scroll = true },
    },
    misc = {
        force_default_wallpaper = 0,
        disable_hyprland_logo = true,
        background_color = 0x1d2021,
    },
})

hl.curve("settle", { type = "bezier", points = { {0.22, 1}, {0.36, 1} } })
hl.animation({ leaf = "global", enabled = true, speed = 6, bezier = "settle" })
hl.animation({ leaf = "workspaces", enabled = true, speed = 4, bezier = "settle", style = "slide" })
