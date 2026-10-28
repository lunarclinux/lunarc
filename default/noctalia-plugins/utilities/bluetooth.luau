--!nonstrict
-- The bar's Bluetooth segment, in the bar's own look (seg.luau): off,
-- on, or connected (with the number of devices when more than one). Click
-- opens the Bluetooth popover (bluetooth-panel.luau). Nothing shows on a
-- computer without Bluetooth.
local seg = require("./seg.luau")
local bt = require("./bluetooth-common.luau")

local st = nil
local open = false

local function render()
  barWidget.setVisible(st ~= nil and st.present)
  if not st or not st.present then return end
  local on = st.on and st.connected > 0
  local children = { ui.glyph({ name = bt.glyph(st), size = seg.GLYPH, color = (open or on) and "primary" or seg.MUTED }) }
  if st.connected > 1 then
    table.insert(children, ui.label({ text = tostring(st.connected), fontSize = 11, color = seg.MUTED }))
  end
  barWidget.render(ui.row({ gap = 0, align = "center" }, {
    seg.divider(),
    seg.segment({ active = open, paddingH = 9, gap = 4 }, children),
  }))
  local tip = "Bluetooth off"
  if st.on then
    tip = st.connected == 0 and "Bluetooth on" or (st.connected == 1 and "Bluetooth: 1 device connected"
      or ("Bluetooth: " .. st.connected .. " devices connected"))
  end
  barWidget.setTooltip(tip)
end

local function refresh() bt.status(function(s) st = s; render() end) end

function onClick() noctalia.togglePanel("@DISTRO_ID@/utilities:bluetooth-panel") end

noctalia.state.watch("bluetooth-open", function(v) open = v == true; render() end)
noctalia.state.watch("bluetooth-changed", function(_v) refresh() end)

function update()
  noctalia.setUpdateInterval(5000)
  refresh()
end

render()
refresh()
