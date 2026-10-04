--!nonstrict
-- Bar indicator: a bug glyph and the number of open crashes. Hidden when there
-- are none. Wiggles briefly when a crash comes in or repeats.
local common = require("./common.luau")

local count = 0
local lastTotal = nil
local wiggleTicks = 0

local function render()
  barWidget.setVisible(count > 0)
  if count == 0 then return end
  local shift = 0
  if wiggleTicks > 0 then shift = (wiggleTicks % 2 == 0) and 3 or 0 end
  local container = barWidget.isVertical() and ui.column or ui.row
  barWidget.render(container({ gap = 4, align = "center" }, {
    ui.box({ width = shift, height = 1 }),
    ui.glyph({ name = "bug", size = 15, color = "error" }),
    ui.row({ fill = "error/0.22", radius = 8, paddingH = 6, align = "center" }, {
      ui.label({ text = tostring(count), color = "error", fontWeight = "bold" }),
    }),
    ui.box({ width = 3 - shift, height = 1 }),
  }))
  barWidget.setTooltip(count == 1 and "1 open crash" or (tostring(count) .. " open crashes"))
end

local function refresh()
  common.load(function(list)
    count = #list
    local total = common.total(list)
    if lastTotal ~= nil and total > lastTotal then
      wiggleTicks = 10
      noctalia.setUpdateInterval(90)
    end
    lastTotal = total
    render()
  end)
end

function update()
  if wiggleTicks > 0 then
    wiggleTicks -= 1
    if wiggleTicks == 0 then noctalia.setUpdateInterval(20000) end
    render()
  else
    noctalia.setUpdateInterval(20000)
    refresh()
  end
end

function onClick()
  noctalia.togglePanel(common.cli .. "/crashes:viewer")
end

-- `noctalia msg plugin <id>/crashes:indicator all refresh`, sent by the watcher.
function onIpc(event, _payload)
  if event == "refresh" then refresh() end
end

refresh()
