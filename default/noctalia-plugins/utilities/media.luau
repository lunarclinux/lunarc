--!nonstrict
-- What's playing, after the window title: `▶ Title · Artist`, only while
-- something plays (paused: ❚❚, hidden when stopped or nothing is open). Click:
-- the now playing popover (media-panel.luau), with the active look while it is
-- open; right-click: play/pause ([widget.media.actions]).
-- Follows playerctl, which reports every change on its own line, and hands
-- the whole line to the popover (state "media"). The text is one line of at
-- most MAX_WIDTH px ending in an ellipsis; when the bar's left lane is short of
-- room (several toggles on beside the clock), Noctalia shortens it further
-- (our bar-fit patch shortens a single-line label with a maxWidth).
local seg = require("./seg.luau")

local PANEL = "@DISTRO_ID@/utilities:now-playing"
local MAX_WIDTH = 320
local status, title, artist = "", "", ""
local open = false

local function render()
  local playing = status == "Playing"
  local show = (playing or status == "Paused") and title ~= ""
  barWidget.setVisible(show)
  if not show then return end
  local text = title
  if artist ~= "" then text ..= " · " .. artist end
  barWidget.render(ui.row({ gap = 0, align = "center" }, {
    seg.segment({ paddingH = 12, active = open }, {
      ui.label({ text = playing and "▶" or "❚❚", fontSize = 10, color = "primary" }),
      ui.label({ text = text, fontSize = seg.TEXT, maxWidth = MAX_WIDTH, maxLines = 1,
        color = open and seg.amberLight() or seg.MUTED }),
    }),
    seg.divider(),
  }))
  barWidget.setTooltip(open and "" or (playing and "Playing" or "Paused"))
end

function onClick()
  noctalia.togglePanel(PANEL)
end

-- The popover says when it is open.
noctalia.state.watch("media-open", function(v) open = v == true; render() end)

-- A fixed command (no values from outside go into it); fields are separated
-- by a tab, which titles don't contain.
noctalia.runStream("playerctl --follow metadata --format '{{status}}\t{{xesam:title}}\t{{xesam:artist}}\t{{playerInstance}}\t{{xesam:album}}\t{{mpris:artUrl}}\t{{mpris:length}}\t{{mpris:trackid}}' 2>/dev/null", function(line)
  local f = string.split(line or "", "\t")
  status, title, artist = f[1] or "", f[2] or "", f[3] or ""
  noctalia.state.set("media", {
    status = status, title = title, artist = artist, player = f[4] or "", album = f[5] or "",
    art = f[6] or "", length = tonumber(f[7]) or 0,
    track = (string.gsub(f[8] or "", "^'(.*)'$", "%1")), -- playerctl quotes object paths
  })
  render()
end)

render()
