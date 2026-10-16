--!nonstrict
-- Tonight's moon, right of the clock (opt-in: `@DISTRO_ID@ bar moon on`): its
-- phase and how much of it is lit. Worked out here from the date; nothing is
-- fetched. With the weather on too, the weather segment shows the moon after
-- the temperature (`☁ 52° · ◐ 62%`) and this one stays hidden.
local seg = require("./seg.luau")
local phase = require("./moon-phase.luau")

local function render()
  local shared = phase.inCentre("weather")
  barWidget.setVisible(not shared)
  if shared then barWidget.setTooltip("") return end
  local m = phase.now()
  barWidget.render(ui.row({ gap = 0, align = "center" }, {
    seg.segment({ paddingH = 12, gap = 7 }, phase.labels(seg, m)),
    seg.divider(),
  }))
  barWidget.setTooltip(m.name .. ", " .. tostring(m.lit) .. "% lit")
end

function update()
  noctalia.setUpdateInterval(30 * 60 * 1000)
  render()
end

update()
