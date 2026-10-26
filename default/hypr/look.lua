-- Window look (Frosted Terminal): gaps, borders, corners,
-- blur and glow, and the header strip on terminal windows. The values come from
-- the current theme's design tokens and the shape and blur settings, written by
-- `@DISTRO_ID@ theme` to a small file; Moonlit's are the fallback until then.
local look = {
    gaps_in = 4, gaps_out = 8, border = 1, rounding = 6, blur = true,
    -- Hyprland draws no inset line, so the top-edge highlight is the border's
    -- own top: a vertical gradient (90°) from the highlight colour into the
    -- border colour over the first stop.
    active_border = { "rgba(f3e3b5eb)", "rgba(ebc77acc)" },
    inactive_border = { "rgba(ebc77a68)", "rgba(e6e2d621)" },
    glow = "rgba(ebc77a1f)", shadow = "rgba(00000066)", glow_range = 24,
    group_active = "rgba(ebc77acc)", group_inactive = "rgba(e6e2d621)", group_locked = "rgba(f0a39acc)",
    groupbar_text = "rgba(1a1405ff)", groupbar_text_inactive = "rgba(c9c5b9ff)",
    header = {
        height = 28, font = "Geist Mono", size = 11, padding = 12,
        fill = "rgba(25262b8d)", text = "rgba(b4bbd0ff)", text_focus = "rgba(ebc77aff)",
    },
}
local ok, generated = pcall(dofile, (os.getenv("XDG_CONFIG_HOME") or (os.getenv("HOME") .. "/.config")) .. "/@DISTRO_ID@/hypr/look.lua")
if ok and type(generated) == "table" then
    for k, v in pairs(generated) do look[k] = v end
end

-- Ten stops spread the gradient over the whole height; repeating the border
-- colour keeps the highlight to the top tenth.
local function top_lit(pair)
    local colors = { pair[1] }
    for _ = 2, 10 do colors[#colors + 1] = pair[2] end
    return { colors = colors, angle = 90 }
end

hl.config({
    general = {
        gaps_in = look.gaps_in,
        gaps_out = look.gaps_out,
        border_size = look.border,
        col = {
            active_border = top_lit(look.active_border),
            inactive_border = top_lit(look.inactive_border),
        },
    },
    decoration = {
        rounding = look.rounding,
        -- A faint glow of the accent around the focused window; a soft dark
        -- shadow under the others.
        shadow = { enabled = true, range = look.glow_range, render_power = 3,
                   color = look.glow, color_inactive = look.shadow },
        -- Blur behind translucent windows and the shell's surfaces. Off, the
        -- same translucent fills show the wallpaper unblurred.
        blur = { enabled = look.blur, size = 8, passes = 2, vibrancy = 0.25, vibrancy_darkness = 0.0,
                 new_optimizations = true },
    },
    group = {
        col = {
            border_active = look.group_active, border_inactive = look.group_inactive,
            border_locked_active = look.group_locked, border_locked_inactive = look.group_inactive,
        },
        groupbar = {
            col = { active = look.group_active, inactive = look.group_inactive,
                    locked_active = look.group_locked, locked_inactive = look.group_inactive },
            text_color = look.groupbar_text, text_color_inactive = look.groupbar_text_inactive,
            text_color_locked_active = look.groupbar_text, text_color_locked_inactive = look.groupbar_text_inactive,
        },
    },
})

-- Header strips (hyprbars, from the distro's repository): terminal windows get
-- a strip with their title in small mono type, amber while focused. The plugin
-- must be built for exactly this Hyprland; it records the Hyprland package it
-- was built for, and loads only when that is the one installed and running.
-- Otherwise windows simply have no strip.
local plugin_dir = "/usr/lib/hyprland-plugins/"
local function hyprbars_matches()
    local f = io.open(plugin_dir .. "hyprbars.hyprland")
    if not f then return false end
    local built = f:read("l"); f:close()
    if not built or not built:match("^[%w.+_:~-]+$") then return false end
    local installed = io.open("/var/lib/pacman/local/hyprland-" .. built .. "/desc")
    if not installed then return false end
    installed:close()
    return hl.version() == built:gsub("^%d+:", ""):match("^[^-]+")
end
if hyprbars_matches() then hl.plugin.load(plugin_dir .. "hyprbars.so") end

local hyprbars = false
for _, p in ipairs(hl.get_loaded_plugins()) do
    if p.name == "hyprbars" then hyprbars = true end
end
-- The plugin's options and rules exist once it has loaded (it reloads the
-- config right after).
if hyprbars then
    local h = look.header
    hl.config({
        plugin = {
            hyprbars = {
                bar_height = h.height,
                bar_color = h.fill,
                ["col.text"] = h.text,
                bar_text_font = h.font,
                bar_text_size = h.size,
                bar_text_align = "left",
                bar_padding = h.padding,
                bar_blur = look.blur,
                bar_part_of_window = true,
                bar_precedence_over_border = true,
                on_double_click = "",
            },
        },
    })
    local terminals = "com\\.mitchellh\\.ghostty|Alacritty|kitty|foot|org\\.wezfurlong\\.wezterm"
    hl.window_rule({
        name = "header-strip-off",
        match = { class = "negative:(" .. terminals .. ")" },
        ["hyprbars:no_bar"] = true,
    })
    hl.window_rule({
        name = "header-strip-focused",
        match = { class = terminals, focus = true },
        ["hyprbars:title_color"] = h.text_focus,
    })
end
