--!nonstrict
-- The notification popover, under the bell, in the stats popover's look
-- (pop.luau): Do Not Disturb, then recent notifications (app, how long ago,
-- summary and body), newest first, and Clear all. Opening it marks everything
-- seen, so the bell's dot goes. Reads Noctalia's own history; clearing goes
-- through Noctalia (noctalia msg notification-clear-history).
local pop = require("./pop.luau")
local nt = require("./notify-common.luau")

local list = nil
local dnd = false
local LIMIT = 30

local function reload()
  nt.load(function(l) list = l; nt.dnd(function(on) dnd = on; render() end) end)
end

function render()
  local children = { pop.header("NOTIFICATIONS", list and (#list > 0 and tostring(#list) or "none") or nil) }
  table.insert(children, ui.row({ gap = 10, align = "center" }, {
    ui.glyph({ name = dnd and "bell-off" or "bell", size = 14, color = dnd and "primary" or "on_surface_variant" }),
    pop.muted("Do Not Disturb", { flexGrow = 1 }),
    ui.toggle({ key = "dnd", checked = dnd, onChange = function(_v)
      noctalia.runAsync({ "noctalia", "msg", "notification-dnd-set", dnd and "off" or "on" }, function(_r) reload() end)
      dnd = not dnd; render()
    end }),
  }))

  local items = {}
  if list then
    for i, n in ipairs(list) do
      if i > LIMIT then break end
      local parts = {
        ui.row({ gap = 8, align = "center" }, {
          pop.text(n.app, { fontSize = 11, color = n.urgency == "critical" and "error" or "primary", flexGrow = 1, maxLines = 1 }),
          pop.muted(nt.ago(n.at), { fontSize = 10 }),
        }),
      }
      if n.summary ~= "" then table.insert(parts, pop.text(n.summary, { maxLines = 2 })) end
      if n.body ~= "" then table.insert(parts, pop.muted(n.body, { fontSize = 11, maxLines = 3 })) end
      table.insert(parts, ui.box({ height = 1, fill = "on_surface/0.08" }))
      table.insert(items, ui.column({ key = "n" .. i .. "-" .. n.at, gap = 3 }, parts))
    end
  end
  if list and #items == 0 then
    table.insert(items, pop.muted("Nothing here."))
  end
  table.insert(children, ui.scroll({ flexGrow = 1, gap = 10 }, items))

  table.insert(children, ui.row({ justify = "end", gap = 4 }, {
    pop.button("Clear all", function()
      noctalia.runAsync({ "noctalia", "msg", "notification-clear-history" }, function(_r) reload() end)
      list = {}; render()
    end, { glyph = "trash" }),
  }))
  panel.render(pop.panel(children, { gap = 12 }))
end

function onOpen(_context)
  noctalia.state.set("notify-open", true)
  nt.markSeen()
  noctalia.setUpdateInterval(3000)
  reload()
  render()
end

function update() reload() end

function onClose() noctalia.state.set("notify-open", false) end
function onExit(_signal, _reason) noctalia.state.set("notify-open", false) end
