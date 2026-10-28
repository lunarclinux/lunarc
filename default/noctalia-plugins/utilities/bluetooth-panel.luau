--!nonstrict
-- The Bluetooth popover, under the bar's Bluetooth segment, in the stats
-- popover's look (pop.luau): the switch, then the paired devices (connected
-- first, with battery levels), each connecting or disconnecting on a click.
-- Pairing a new device opens Noctalia's Bluetooth panel, which scans and
-- handles PIN codes (this popover never pairs).
local pop = require("./pop.luau")
local bt = require("./bluetooth-common.luau")

local st = nil
local devs = {}
local busy = nil

local function changed() noctalia.state.set("bluetooth-changed", noctalia.nowMs()) end

local function run(args, after)
  noctalia.runAsync(args, function(r) if after then after(r) end end)
end

local function reload()
  bt.status(function(s)
    st = s
    if s.present and s.on then
      bt.devices(function(d) devs = d; render() end)
    else
      devs = {}
      render()
    end
  end)
end

local function toggle(d)
  if busy then return end
  busy = d.mac; render()
  run({ "bluetoothctl", "--timeout", "15", d.connected and "disconnect" or "connect", d.mac }, function(_r)
    busy = nil; changed(); reload()
  end)
end

local function setPower(on)
  run({ "noctalia", "msg", on and "bluetooth-enable" or "bluetooth-disable" }, function(_r) changed(); reload() end)
  st.on = on; render()
end

local function pairNew() run({ "noctalia", "msg", "panel-toggle", "control-center", "bluetooth" }) end

function render()
  if not st then
    panel.render(pop.panel({ pop.header("BLUETOOTH", nil), pop.muted("Reading…") }))
    return
  end
  if not st.present then
    panel.render(pop.panel({ pop.header("BLUETOOTH", nil), pop.muted("No Bluetooth on this computer.") }))
    return
  end
  local children = {}
  local connected = 0
  for _, d in ipairs(devs) do if d.connected then connected += 1 end end
  table.insert(children, ui.row({ gap = 10, align = "center" }, {
    ui.column({ flexGrow = 1 }, { pop.header("BLUETOOTH", st.on and (connected .. " connected") or "off") }),
    ui.toggle({ key = "bt-power", checked = st.on, onChange = function(_v) setPower(not st.on) end }),
  }))
  if st.on then
    local rows = {}
    for i, d in ipairs(devs) do
      if i > 10 then break end
      local state = busy == d.mac and "…" or (d.connected and (d.battery and (d.battery .. "%") or "on") or "")
      table.insert(rows, ui.row({ key = "d-" .. d.mac, gap = 10, align = "center", onClick = function() toggle(d) end }, {
        ui.glyph({ name = bt.deviceGlyph(d.kind), size = 13, color = d.connected and "primary" or "on_surface_variant" }),
        pop.text(d.name, { flexGrow = 1, maxLines = 1, color = d.connected and "primary" or "on_surface" }),
        d.battery and d.connected and ui.progress({ progress = d.battery / 100, fill = "primary", track = "on_surface/0.1",
          radius = 1, height = 3, width = 56 }) or ui.spacer({}),
        pop.muted(state, { width = 40, textAlign = "end", fontSize = 11 }),
      }))
    end
    if #rows == 0 then table.insert(rows, pop.muted("No paired devices yet.")) end
    table.insert(children, ui.column({ gap = 9 }, rows))
    table.insert(children, pop.muted("Click a device to connect or disconnect it.", { fontSize = 11 }))
  end
  table.insert(children, ui.row({ justify = "end", gap = 4 }, {
    st.on and pop.button("Pair a device", pairNew, { glyph = "plus" }) or ui.spacer({}),
    pop.button("More settings", pairNew, { glyph = "settings" }),
  }))
  panel.render(pop.panel(children, { gap = 14 }))
end

function onOpen(_context)
  noctalia.state.set("bluetooth-open", true)
  noctalia.setUpdateInterval(5000)
  reload()
  render()
end

function update() reload() end

function onClose() noctalia.state.set("bluetooth-open", false) end
function onExit(_signal, _reason) noctalia.state.set("bluetooth-open", false) end
