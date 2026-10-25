--!nonstrict
-- The calendar, under the clock, in the popovers' look (pop.luau): the month
-- as a grid with today in amber, arrows for the months either side, and Today
-- to come back. The week starts on the locale's first day, as Noctalia's own
-- calendar does (`locale first_weekday`). Colours are palette roles, so it
-- follows the theme. Events from calendars added in Noctalia's settings stay
-- in Noctalia's calendar (its event cache is encrypted, out of a plugin's
-- reach): with any account set up, Events opens it.
local pop = require("./pop.luau")

local CELL_W, CELL_H = 40, 28
local NAMES = { "January", "February", "March", "April", "May", "June", "July", "August", "September",
  "October", "November", "December" }
local DAYS = { "Su", "Mo", "Tu", "We", "Th", "Fr", "Sa" }

local today = nil       -- { y, m, d }
local shown = nil       -- { y, m }
local firstDay = 0      -- 0 = Sunday … 6 = Saturday
local hasAccounts = false

local function isLeap(y) return (y % 4 == 0 and y % 100 ~= 0) or y % 400 == 0 end
local function daysIn(y, m)
  local n = { 31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31 }
  if m == 2 and isLeap(y) then return 29 end
  return n[m]
end
-- 0 = Sunday (Sakamoto's method).
local function weekday(y, m, d)
  local t = { 0, 3, 2, 5, 0, 3, 5, 1, 4, 6, 2, 4 }
  if m < 3 then y -= 1 end
  return (y + y // 4 - y // 100 + y // 400 + t[m] + d) % 7
end

local function readToday()
  local y, m, d = string.match(noctalia.formatTime("{:%Y %m %d}"), "(%d+) (%d+) (%d+)")
  today = { y = tonumber(y), m = tonumber(m), d = tonumber(d) }
end

local function move(by)
  local m = shown.m + by
  local y = shown.y
  while m < 1 do m += 12; y -= 1 end
  while m > 12 do m -= 12; y += 1 end
  shown = { y = y, m = m }
  render()
end

local function cell(key, text, props)
  return ui.row({ key = key, width = CELL_W, height = CELL_H, radius = 4, align = "center", justify = "center",
    fill = props.fill or "#00000000" }, {
    pop.text(text, { fontSize = 12, color = props.color, fontWeight = props.weight }),
  })
end

function render()
  if not today then readToday() end
  if not shown then shown = { y = today.y, m = today.m } end
  local y, m = shown.y, shown.m
  local children = { pop.header("CALENDAR", noctalia.formatTime("{:%a %d %b}")) }

  -- The month, with arrows either side.
  table.insert(children, ui.row({ key = "month", align = "center", gap = 4 }, {
    pop.button("", function() move(-1) end, { key = "prev", glyph = "chevron-left", tooltip = "Previous month" }),
    ui.row({ key = "title", flexGrow = 1, justify = "center" }, {
      pop.text(NAMES[m] .. " " .. y, { fontSize = 13, fontWeight = "semibold" }),
    }),
    pop.button("", function() move(1) end, { key = "next", glyph = "chevron-right", tooltip = "Next month" }),
  }))

  -- Weekday names, from the locale's first day.
  local head = {}
  for i = 0, 6 do
    local wd = (firstDay + i) % 7
    table.insert(head, cell("h" .. i, DAYS[wd + 1], { color = (wd == 0 or wd == 6) and "on_surface_variant/0.7" or "on_surface_variant" }))
  end
  local rows = { ui.row({ key = "names", gap = 0 }, head) }

  -- Six weeks: the end of last month, this month, the start of next.
  local offset = (weekday(y, m, 1) - firstDay + 7) % 7
  local py, pm = y, m - 1
  if pm < 1 then pm = 12; py -= 1 end
  local prevDays = daysIn(py, pm)
  local n = daysIn(y, m)
  for w = 0, 5 do
    local week = {}
    for i = 0, 6 do
      local idx = w * 7 + i - offset + 1
      local key = "c" .. (w * 7 + i)
      if idx < 1 then
        table.insert(week, cell(key, tostring(prevDays + idx), { color = "on_surface_variant/0.4" }))
      elseif idx > n then
        table.insert(week, cell(key, tostring(idx - n), { color = "on_surface_variant/0.4" }))
      elseif y == today.y and m == today.m and idx == today.d then
        table.insert(week, cell(key, tostring(idx), { fill = "primary", color = "on_primary", weight = "semibold" }))
      else
        local wd = (firstDay + i) % 7
        table.insert(week, cell(key, tostring(idx), { color = (wd == 0 or wd == 6) and "on_surface_variant" or "on_surface" }))
      end
    end
    table.insert(rows, ui.row({ key = "w" .. w, gap = 0 }, week))
  end
  table.insert(children, ui.column({ key = "grid", gap = 2 }, rows))

  -- Events (with a calendar account), and back to this month when looking at another.
  local away = y ~= today.y or m ~= today.m
  table.insert(children, ui.row({ key = "foot", height = 28, align = "center", gap = 4 }, {
    hasAccounts and pop.button("Events", function()
      panel.close()
      noctalia.runAsync({ "noctalia", "msg", "panel-toggle", "control-center", "calendar" }, function(_r) end)
    end, { key = "events", glyph = "list" }) or ui.box({ key = "events", height = 1, fill = "#00000000" }),
    ui.spacer({ key = "space", flexGrow = 1 }),
    away and pop.button("Today", function() shown = { y = today.y, m = today.m }; render() end,
      { key = "today", glyph = "calendar" }) or ui.box({ key = "today", height = 1, fill = "#00000000" }),
  }))
  panel.render(pop.panel(children, { gap = 10 }))
end

function onOpen(_context)
  noctalia.state.set("calendar-open", true)
  readToday()
  shown = { y = today.y, m = today.m }
  render()
  -- Any calendar account, in any of Noctalia's config files (asking
  -- getSetting for a key that isn't there logs a warning on every open).
  noctalia.runAsync({ "sh", "-c", 'grep -qs "^[[:space:]]*\\[calendar\\.account\\." "${XDG_CONFIG_HOME:-$HOME/.config}"/noctalia/*.toml' },
    function(r)
      local has = r.exitCode == 0
      if has ~= hasAccounts then hasAccounts = has; render() end
    end)
  -- The locale's first day of the week (1 = the day `locale week-1stday` names,
  -- a Sunday in glibc's locales).
  noctalia.runAsync({ "locale", "first_weekday" }, function(r)
    local f = tonumber(noctalia.string.trim(r.stdout or ""))
    if f and f >= 1 and f <= 7 and (f - 1) ~= firstDay then firstDay = f - 1; render() end
  end)
end

function onClose() noctalia.state.set("calendar-open", false) end
function onExit(_signal, _reason) noctalia.state.set("calendar-open", false) end

-- State for the VM test (vm/test-install): `noctalia msg plugin
-- <id>/utilities:calendar-panel all dump` writes what the popover shows.
function onIpc(event, _payload)
  if event ~= "dump" then return end
  local dir = noctalia.getenv("XDG_RUNTIME_DIR")
  if not dir or dir == "" or not shown then return end
  noctalia.writeFile(dir .. "/@DISTRO_ID@-calendar.json", noctalia.json.encode({
    year = shown.y, month = shown.m, first_day = firstDay, today = today and today.d or 0,
  }))
end
