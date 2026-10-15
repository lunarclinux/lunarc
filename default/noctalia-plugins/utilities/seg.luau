--!nonstrict
-- The bar's segments (Frosted Terminal, decision record 0043): flat, full
-- height, separated by 1px hairlines. Colours are palette roles, so they follow
-- the theme; the height comes from the bar's own settings, which `@DISTRO_ID@
-- theme shape` writes (bar_apply).
local M = {}

M.GLYPH = 15
M.TEXT = 12
M.DIVIDER = "on_surface/0.12"
M.MUTED = "on_surface_variant"
M.FAINT = "on_surface_variant/0.55"
M.TINT = "primary/0.2"

local function num(path, fallback)
  local ok, v = pcall(noctalia.getSetting, path)
  if ok and type(v) == "number" then return v end
  return fallback
end

-- The height inside the bar's border.
function M.height()
  return num("bar.default.thickness", 30) - 2 * num("bar.default.border_width", 1)
end

function M.rounded()
  return num("bar.default.radius", 0) > 0
end

function M.divider()
  return ui.box({ width = 1, height = M.height(), fill = M.DIVIDER })
end

-- A segment: children in a full-height row. active: the design's active
-- treatment (amber tint, 2px amber underline), for a segment whose panel is
-- open or the workspace you're on.
function M.segment(props, children)
  local h = M.height()
  local row = ui.row({ gap = props.gap or 7, align = "center", justify = "center",
    paddingH = props.paddingH or 10, flexGrow = 1 }, children)
  return ui.column({
    key = props.key, gap = 0, height = h, minWidth = props.minWidth,
    fill = props.active and M.TINT or props.fill,
    onClick = props.onClick, onHover = props.onHover, tooltip = props.tooltip,
  }, {
    ui.box({ height = 2, fill = "#00000000" }),
    row,
    ui.box({ height = 2, fill = props.active and "primary" or "#00000000" }),
  })
end

-- "#rrggbb" mixes, for the colours the palette has no role for.
local function rgb(hex)
  hex = string.gsub(hex or "", "#", "")
  if #hex < 6 then return nil end
  return { tonumber(string.sub(hex, 1, 2), 16), tonumber(string.sub(hex, 3, 4), 16), tonumber(string.sub(hex, 5, 6), 16) }
end

local function mix(a, b, t)
  local ca, cb = rgb(a), rgb(b)
  if not ca or not cb then return a end
  local out = "#"
  for i = 1, 3 do out ..= string.format("%02x", math.floor(ca[i] + (cb[i] - ca[i]) * t + 0.5)) end
  return out
end

-- amberLight: the primary colour 45% of the way to white (dark themes) or to
-- the text colour (light ones), as in the theme tokens.
function M.amberLight()
  local primary = noctalia.getColor("primary") or "#ebc77a"
  local toward = noctalia.isDarkMode() and "#ffffff" or (noctalia.getColor("on_surface") or "#000000")
  return mix(primary, toward, 0.45)
end

return M
