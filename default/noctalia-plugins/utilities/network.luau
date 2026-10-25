--!nonstrict
-- The bar's network segment, in the bar's own look (seg.luau): the
-- connection's icon. Click opens the network popover (network-panel.luau),
-- with the active look while it's open.
local seg = require("./seg.luau")
local net = require("./network-common.luau")

local st = nil
local open = false

local function render()
  barWidget.render(ui.row({ gap = 0, align = "center" }, {
    seg.divider(),
    seg.segment({ active = open, paddingH = 9 }, {
      ui.glyph({ name = net.glyph(st), size = seg.GLYPH, color = open and "primary" or seg.MUTED }),
    }),
  }))
  barWidget.setTooltip(st and st.kind and (st.connection or st.kind) or "Not connected")
end

local function refresh() net.status(function(s) st = s; render() end) end

function onClick() noctalia.togglePanel("@DISTRO_ID@/utilities:network-panel") end

noctalia.state.watch("network-open", function(v) open = v == true; render() end)
noctalia.state.watch("network-changed", function(_v) refresh() end)

function update()
  noctalia.setUpdateInterval(5000)
  refresh()
end

render()
refresh()
