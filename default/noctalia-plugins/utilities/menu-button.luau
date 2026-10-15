--!nonstrict
-- The menu button: a solid amber square with a dark moon, at the bar's left
-- end (rounded along with the bar in the rounded shape). Click: the system
-- menu; right-click: apps (both set in the bar config's [widget.menu.actions]).
local seg = require("./seg.luau")

local function render()
  local h = seg.height()
  barWidget.render(ui.row({
    align = "center", justify = "center", height = h, minWidth = h + 4, paddingH = 12,
    fill = "primary", radius = seg.rounded() and h / 2 or 0,
  }, {
    ui.glyph({ name = "moon", size = seg.GLYPH, color = "on_primary" }),
  }))
  barWidget.setTooltip("Menu (SUPER+Space)")
end

function onIpc(event, _payload)
  if event == "refresh" then render() end
end

render()
