--!nonstrict
-- The bar's notification bell, in the bar's own look (seg.luau): the bell
-- (crossed out with Do Not Disturb on) and an amber dot while there's
-- something you haven't looked at. Click opens the notification popover
-- (notify-panel.luau), which marks everything seen.
local seg = require("./seg.luau")
local nt = require("./notify-common.luau")

local unread = 0
local dnd = false
local open = false

local function render()
  local icon = ui.glyph({ name = dnd and "bell-off" or "bell", size = seg.GLYPH, color = open and "primary" or seg.MUTED })
  local cell = unread > 0 and ui.row({ gap = 2, align = "start" }, {
    icon, ui.box({ width = 5, height = 5, radius = 3, fill = "primary" }),
  }) or icon
  barWidget.render(ui.row({ gap = 0, align = "center" }, {
    seg.divider(),
    seg.segment({ active = open, paddingH = 9 }, { cell }),
  }))
  barWidget.setTooltip(dnd and "Do Not Disturb is on" or (unread > 0 and (unread .. " new") or "Notifications"))
end

local function refresh()
  nt.seen(function(seenAt)
    nt.load(function(list)
      unread = 0
      for _, n in ipairs(list) do if n.at > seenAt then unread += 1 end end
      nt.dnd(function(on) dnd = on; render() end)
    end)
  end)
end

function onClick() noctalia.togglePanel("@DISTRO_ID@/utilities:notify-panel") end

function onRightClick()
  noctalia.runAsync({ "noctalia", "msg", "notification-dnd-toggle" }, function(_r) refresh() end)
end

noctalia.state.watch("notify-open", function(v) open = v == true; render() end)
noctalia.state.watch("notifications-seen", function(_v) refresh() end)

function update()
  noctalia.setUpdateInterval(3000)
  refresh()
end

render()
refresh()
