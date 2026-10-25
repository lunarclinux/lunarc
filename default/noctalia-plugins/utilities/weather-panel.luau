--!nonstrict
-- The weather popover, under the bar's weather segment: now (temperature,
-- conditions, feels like, wind, humidity, UV), the next hours and the next
-- days, in the stats popover's look (pop.luau). Reads only the reading
-- Noctalia keeps on disk (weather-common.luau); nothing is fetched here.
local pop = require("./pop.luau")
local wx = require("./weather-common.luau")

local snap = nil

local function deg(c)
  local d = wx.degrees(c)
  return d and (tostring(d) .. "°") or "–"
end

local function hours(s)
  local out = {}
  local now = s.current and s.current.time_iso or ""
  local hour = string.sub(now, 1, 13)   -- "2026-10-24T16"
  for _, h in ipairs(s.forecast_hours or {}) do
    if #out >= 8 then break end
    if string.sub(h.time_iso or "", 1, 13) > hour then table.insert(out, h) end
  end
  return out
end

local function render()
  if not snap then
    panel.render(pop.panel({
      pop.header("WEATHER", nil),
      pop.muted("No reading yet. Weather is off, or the first lookup hasn't finished."),
      pop.muted("Turn it on: @DISTRO_ID@ privacy weather on", { fontSize = 11 }),
    }))
    return
  end
  local c = snap.current
  local place = string.gsub(snap.location_name or "", ", United States$", "")
  local today = (snap.forecast_days or {})[1] or {}
  local children = { pop.header("WEATHER", place) }

  -- Now: the big temperature with its conditions, then the details.
  table.insert(children, ui.row({ gap = 12, align = "center" }, {
    ui.glyph({ name = wx.glyph(tonumber(c.weather_code) or 3, c.is_day ~= false), size = 30, color = "primary" }),
    ui.column({ gap = 2, flexGrow = 1 }, {
      pop.text(deg(c.temperature_c), { fontSize = 22 }),
      pop.muted(wx.condition(tonumber(c.weather_code) or 3) .. " · " .. deg(today.temperature_min_c) .. " to "
        .. deg(today.temperature_max_c), { fontSize = 11 }),
    }),
  }))
  local details = {
    pop.row("FEELS", deg(c.apparent_temperature_c)),
    pop.row("WIND", (wx.speed(c.wind_speed_kmh) or "–") .. " " .. wx.compass(c.wind_direction_deg)),
    pop.row("HUMID", tostring(c.relative_humidity_percent or "–") .. "%",
      (tonumber(c.relative_humidity_percent) or 0) / 100, "tertiary"),
  }
  if type(c.uv_index) == "number" then
    table.insert(details, pop.row("UV", string.format("%.0f", c.uv_index), math.min(1, c.uv_index / 11), "secondary"))
  end
  table.insert(children, ui.column({ gap = 8 }, details))

  -- The next hours: time, glyph, temperature, chance of rain.
  local hs = hours(snap)
  if #hs > 0 then
    local cells = {}
    for _, h in ipairs(hs) do
      table.insert(cells, ui.column({ key = h.time_iso, gap = 4, align = "center", flexGrow = 1 }, {
        pop.muted(string.sub(h.time_iso or "", 12, 13), { fontSize = 11 }),
        ui.glyph({ name = wx.glyph(tonumber(h.weather_code) or 3, h.is_day ~= false), size = 15, color = "on_surface_variant" }),
        pop.text(deg(h.temperature_c), { fontSize = 11 }),
        pop.muted((tonumber(h.precipitation_probability_percent) or 0) > 0
          and (tostring(h.precipitation_probability_percent) .. "%") or " ", { fontSize = 10, color = "tertiary" }),
      }))
    end
    table.insert(children, ui.column({ gap = 8 }, { pop.header("NEXT HOURS", nil), ui.row({ gap = 0 }, cells) }))
  end

  -- The next days: name, glyph, low, a bar across the week's range, high.
  local days = snap.forecast_days or {}
  if #days > 1 then
    local lo, hi = math.huge, -math.huge
    for i = 1, math.min(#days, 6) do
      lo = math.min(lo, days[i].temperature_min_c or lo); hi = math.max(hi, days[i].temperature_max_c or hi)
    end
    local span = math.max(1, hi - lo)
    local rows = {}
    local nowSec = math.floor(noctalia.nowMs() / 1000)
    for i = 1, math.min(#days, 6) do
      local d = days[i]
      local name = i == 1 and "Today" or noctalia.formatTime("{:%a}", nowSec + (i - 1) * 86400)
      table.insert(rows, ui.row({ key = d.date_iso, gap = 10, align = "center" }, {
        pop.muted(name, { width = 44 }),
        ui.glyph({ name = wx.glyph(tonumber(d.weather_code) or 3, true), size = 14, color = "on_surface_variant" }),
        pop.muted(deg(d.temperature_min_c), { width = 34, textAlign = "end" }),
        ui.row({ flexGrow = 1, gap = 0, align = "center" }, {
          ui.box({ width = 1, height = 3, flexGrow = math.max(0.01, ((d.temperature_min_c or lo) - lo) / span), fill = "#00000000" }),
          ui.box({ height = 3, flexGrow = math.max(0.05, ((d.temperature_max_c or hi) - (d.temperature_min_c or lo)) / span),
            fill = i == 1 and "primary" or "primary/0.55", radius = 1 }),
          ui.box({ width = 1, height = 3, flexGrow = math.max(0.01, (hi - (d.temperature_max_c or hi)) / span), fill = "#00000000" }),
        }),
        pop.text(deg(d.temperature_max_c), { width = 34, textAlign = "end" }),
      }))
    end
    table.insert(children, ui.column({ gap = 8 }, { pop.header("DAYS", nil), ui.column({ gap = 7 }, rows) }))
  end

  table.insert(children, pop.muted("Open-Meteo · place: @DISTRO_ID@ privacy weather location", { fontSize = 10, color = "on_surface_variant/0.7" }))
  panel.render(pop.panel(children, { gap = 14 }))
end

local function load()
  noctalia.readFileAsync(wx.path, function(text, _err)
    snap = wx.parse(text)
    render()
  end)
end

function onOpen(_context)
  noctalia.state.set("weather-open", true)
  load()
  render()
end

function onClose()
  noctalia.state.set("weather-open", false)
end

function onExit(_signal, _reason)
  noctalia.state.set("weather-open", false)
end
