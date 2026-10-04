--!nonstrict
-- Bar widget: today's tokens across agents. Hidden until an agent has usage.
local common = require("./common.luau")

local function render(data)
  local agents = (data and data.agents) or {}
  barWidget.setVisible(#agents > 0)
  if #agents == 0 then return end
  local total = 0
  local tip = {}
  for _, a in ipairs(agents) do
    total += a.today.tokens
    table.insert(tip, (common.names[a.name] or a.name) .. ": " .. common.short(a.today.tokens) .. " tokens today")
  end
  barWidget.setGlyph("sparkles")
  barWidget.setText(common.short(total))
  barWidget.setTooltip(tip)
end

noctalia.state.watch("usage", render)

function update()
  noctalia.setUpdateInterval(300000)   -- every 5 minutes
  common.fetch(render)
end

function onClick()
  noctalia.togglePanel(common.cli .. "/agents:panel")
end

function onIpc(event, _payload)
  if event == "refresh" then common.fetch(render) end
end
