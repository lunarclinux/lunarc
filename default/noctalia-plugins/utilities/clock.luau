--!nonstrict
-- The clock, in the middle of the bar (it is the centre lane's anchor, so it
-- stays at the exact centre whatever shows beside it): a slightly tinted
-- segment between two hairlines, the date muted and the time in light amber.
-- Click: the calendar ([widget.clock.actions]). The time follows Noctalia's
-- [shell] time_format.
local seg = require("./seg.luau")

local function render()
  local fmt = noctalia.timeFormat()
  if type(fmt) ~= "string" or fmt == "" then fmt = "{:%H:%M}" end
  barWidget.render(ui.row({ gap = 0, align = "center" }, {
    seg.divider(),
    seg.segment({ paddingH = 18, gap = 10, fill = "primary/0.08" }, {
      ui.label({ text = noctalia.formatTime("{:%a %d %b}"), fontSize = 12.5, color = seg.MUTED }),
      ui.label({ text = noctalia.formatTime(fmt), fontSize = 12.5, fontWeight = "semibold", color = seg.amberLight() }),
    }),
    seg.divider(),
  }))
  barWidget.setTooltip(noctalia.formatTime("{:%A, %B %d, %Y}"))
end

-- On the minute (a minute ahead of a slow tick would show the wrong time).
function update()
  local ms = noctalia.nowMs()
  noctalia.setUpdateInterval(60000 - (ms % 60000) + 50)
  render()
end

-- The theme changed (from `@DISTRO_ID@ theme`): the time's colour is mixed here.
function onIpc(event, _payload)
  if event == "refresh" then render() end
end

update()
