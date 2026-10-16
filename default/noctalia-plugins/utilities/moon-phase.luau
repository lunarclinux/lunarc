--!nonstrict
-- Tonight's moon, worked out from the date (nothing is fetched): its glyph,
-- how much of it is lit and its name. Shared by the moon and weather segments.
local M = {}

-- Same glyphs as the workspaces (Nerd Font weather icons): new, waxing
-- crescent, first quarter, waxing gibbous, full, waning gibbous, last quarter,
-- waning crescent.
local GLYPHS = { "\u{e38d}", "\u{e391}", "\u{e394}", "\u{e397}", "\u{e39b}", "\u{e39e}", "\u{e3a2}", "\u{e3a6}" }
local NAMES = { "New moon", "Waxing crescent", "First quarter", "Waxing gibbous", "Full moon",
  "Waning gibbous", "Last quarter", "Waning crescent" }
M.FONT = "JetBrainsMono Nerd Font"
local SYNODIC = 29.530588853
local NEW_MOON = 947182440 -- 2000-01-06 18:14 UTC

function M.now()
  local age = ((os.time() - NEW_MOON) / 86400) % SYNODIC
  local frac = age / SYNODIC
  local lit = math.floor((1 - math.cos(2 * math.pi * frac)) / 2 * 100 + 0.5)
  local i = math.floor(frac * 8 + 0.5) % 8 + 1
  return { glyph = GLYPHS[i], lit = lit, name = NAMES[i] }
end

-- The moon's two labels, as the moon segment draws them.
function M.labels(seg, m)
  return {
    ui.label({ text = m.glyph, fontFamily = M.FONT, fontSize = 13, color = "primary" }),
    ui.label({ text = tostring(m.lit) .. "%", fontSize = seg.TEXT, color = "primary" }),
  }
end

-- Whether a widget entry is in the bar's centre lane.
function M.inCentre(name)
  local ok, list = pcall(noctalia.getSetting, "bar.default.center")
  if not ok or type(list) ~= "table" then return false end
  for _, n in ipairs(list) do
    if n == name then return true end
  end
  return false
end

return M
