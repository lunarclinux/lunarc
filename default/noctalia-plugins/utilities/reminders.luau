--!nonstrict
-- Reminders: an alarm glyph with the number of upcoming reminders; click to
-- see them and add one.
local common = require("./common.luau")
local count = 0

local function render()
  barWidget.setGlyph("alarm")
  barWidget.setGlyphColor(count > 0 and "primary" or "on_surface")
  barWidget.setText(count > 0 and tostring(count) or "")
  barWidget.setTooltip(count == 0 and "Reminders" or (count == 1 and "1 reminder" or (tostring(count) .. " reminders")))
end

local function refresh()
  common.run({ "remind", "list", "--json" }, function(out)
    local list = out and noctalia.json.decode(out) or {}
    count = #list
    render()
  end)
end

function onClick()
  noctalia.togglePanel(common.cli .. "/utilities:reminders-panel")
end

function update()
  noctalia.setUpdateInterval(30000)
  refresh()
end

function onIpc(event, _payload)
  if event == "refresh" then refresh() end
end

render()
refresh()
