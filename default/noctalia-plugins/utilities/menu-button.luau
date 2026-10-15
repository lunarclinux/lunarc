--!nonstrict
-- The menu button: a solid amber square with a dark moon, at the bar's left
-- end (rounded along with the bar in the rounded shape). Click: the system
-- menu; right-click: apps (both set in the bar config's [widget.menu.actions]).
-- With the daily update check on (`@DISTRO_ID@ update auto-check on`), a small
-- dark dot beside the moon says updates are waiting (the menu's Update has
-- the count). `@DISTRO_ID@ update check` refreshes it.
local seg = require("./seg.luau")
local cli = "@DISTRO_ID@"

-- The waiting count `update check` last wrote, if the daily check is on and
-- the count is from the last three days.
local function waiting()
  local settings = noctalia.readFile(noctalia.expandPath("~/.config/" .. cli .. "/settings")) or ""
  if not string.find(settings, "\nupdate%.auto_check%s*=%s*on") and not string.find(settings, "^update%.auto_check%s*=%s*on") then
    return nil
  end
  local text = noctalia.readFile(noctalia.expandPath("~/.local/state/" .. cli .. "/updates")) or ""
  local n, at = string.match(text, "^(%d+)%s+(%d+)")
  n, at = tonumber(n), tonumber(at)
  if not n or n == 0 or not at or noctalia.nowMs() / 1000 - at > 3 * 86400 then return nil end
  return n
end

local function render()
  local h = seg.height()
  local n = waiting()
  barWidget.render(ui.row({
    align = "center", justify = "center", height = h, minWidth = h + 4, paddingH = 10, gap = 2,
    fill = "primary", radius = seg.rounded() and h / 2 or 0,
  }, {
    ui.glyph({ name = "moon", size = seg.GLYPH, color = "on_primary" }),
    ui.column({ width = 5, height = seg.GLYPH, flexGrow = 0, justify = "start" }, {
      ui.box({ width = 5, height = 5, radius = 2.5, fill = n and "on_primary" or "#00000000" }),
    }),
  }))
  barWidget.setTooltip(n and ("Menu (SUPER+Space) · " .. n .. " updates ready") or "Menu (SUPER+Space)")
end

function onIpc(event, _payload)
  if event == "refresh" then render() end
end

render()
