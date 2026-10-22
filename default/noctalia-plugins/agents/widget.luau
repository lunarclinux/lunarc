--!nonstrict
-- Bar widget: today's tokens across agents, as a bar segment like the system
-- stats' (muted icon, the amber active look while the panel is open). Hidden
-- until an agent has usage.
local common = require("./common.luau")
local seg = require("./seg.luau")

local usage = nil
local open = false

local function render()
  local agents = (usage and usage.agents) or {}
  barWidget.setVisible(#agents > 0)
  if #agents == 0 then return end
  local total = 0
  local tip = {}
  for _, a in ipairs(agents) do
    total += a.today.tokens
    table.insert(tip, (common.names[a.name] or a.name) .. ": " .. common.short(a.today.tokens) .. " tokens today")
  end
  barWidget.render(ui.row({ gap = 0, align = "center" }, {
    seg.divider(),
    seg.segment({ active = open, paddingH = 9, gap = 6 }, {
      ui.glyph({ name = "sparkles", size = seg.GLYPH, color = open and "primary" or seg.MUTED }),
      ui.label({ text = common.short(total), fontSize = seg.TEXT, fontFamily = common.MONO,
        color = open and "primary" or "on_surface" }),
    }),
  }))
  barWidget.setTooltip(tip)
end

noctalia.state.watch("usage", function(d) usage = d; render() end)
-- The panel says when it's open, for the active look.
noctalia.state.watch("panel-open", function(v) open = v == true; render() end)

function update()
  noctalia.setUpdateInterval(300000)   -- every 5 minutes
  common.fetch(function(d) usage = d; render() end)
end

function onClick()
  noctalia.togglePanel(common.cli .. "/agents:panel")
end

function onIpc(event, _payload)
  if event == "refresh" then common.fetch(function(d) usage = d; render() end) end
end
