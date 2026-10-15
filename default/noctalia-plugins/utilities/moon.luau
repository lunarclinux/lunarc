--!nonstrict
-- Tonight's moon, right of the clock (opt-in: `@DISTRO_ID@ bar moon on`): its
-- phase and how much of it is lit. Worked out here from the date; nothing is
-- fetched.
local seg = require("./seg.luau")

-- Same glyphs as the workspaces (Nerd Font weather icons): new, waxing
-- crescent, first quarter, waxing gibbous, full, waning gibbous, last quarter,
-- waning crescent.
local GLYPHS = { "\u{e38d}", "\u{e391}", "\u{e394}", "\u{e397}", "\u{e39b}", "\u{e39e}", "\u{e3a2}", "\u{e3a6}" }
local NAMES = { "New moon", "Waxing crescent", "First quarter", "Waxing gibbous", "Full moon",
  "Waning gibbous", "Last quarter", "Waning crescent" }
local MOON_FONT = "JetBrainsMono Nerd Font"
local SYNODIC = 29.530588853
local NEW_MOON = 947182440 -- 2000-01-06 18:14 UTC

local function render()
  local age = ((os.time() - NEW_MOON) / 86400) % SYNODIC
  local frac = age / SYNODIC
  local lit = math.floor((1 - math.cos(2 * math.pi * frac)) / 2 * 100 + 0.5)
  local i = math.floor(frac * 8 + 0.5) % 8 + 1
  barWidget.render(ui.row({ gap = 0, align = "center" }, {
    seg.segment({ paddingH = 12, gap = 7 }, {
      ui.label({ text = GLYPHS[i], fontFamily = MOON_FONT, fontSize = 13, color = "primary" }),
      ui.label({ text = tostring(lit) .. "%", fontSize = seg.TEXT, color = "primary" }),
    }),
    seg.divider(),
  }))
  barWidget.setTooltip(NAMES[i] .. ", " .. tostring(lit) .. "% lit")
end

function update()
  noctalia.setUpdateInterval(30 * 60 * 1000)
  render()
end

update()
