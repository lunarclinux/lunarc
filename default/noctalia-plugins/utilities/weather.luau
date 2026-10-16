--!nonstrict
-- The weather, right of the clock (opt-in: `@DISTRO_ID@ privacy weather on`),
-- as one of the bar's segments: `☁ 52°` (decision record 0043). With the moon
-- on, the moon follows in the same segment (`☁ 52° · ◐ 62%`) and draws the
-- hairline after both. Noctalia's own weather service does the lookup; this
-- only reads the reading it keeps on disk, so nothing new is fetched. Click:
-- the weather tab ([widget.weather.actions]).
local seg = require("./seg.luau")
local phase = require("./moon-phase.luau")

local path
do
  local cache = noctalia.getenv("XDG_CACHE_HOME")
  if not cache or cache == "" then cache = (noctalia.getenv("HOME") or "") .. "/.cache" end
  path = cache .. "/noctalia/weather.json"
end

local now = nil -- the reading: { temp, code, day, feels, high, low, humidity, place }
local seen = -1 -- the cache file's mtime when it was last read

-- Noctalia's own glyphs for Open-Meteo's weather codes (WeatherService::glyphForCode).
local function glyph(code, day)
  if code == 0 then return day and "weather-sun" or "weather-moon" end
  if code == 1 or code == 2 then return day and "weather-cloud-sun" or "weather-moon-stars" end
  if code >= 45 and code <= 48 then return "weather-cloud-haze" end
  if (code >= 51 and code <= 67) or (code >= 80 and code <= 82) then return "weather-cloud-rain" end
  if (code >= 71 and code <= 77) or (code >= 85 and code <= 86) then return "weather-cloud-snow" end
  if code >= 95 and code <= 99 then return "weather-cloud-lightning" end
  return "weather-cloud"
end

local function condition(code)
  if code == 0 then return "Clear" end
  if code == 1 then return "Mostly clear" end
  if code == 2 then return "Partly cloudy" end
  if code == 3 then return "Overcast" end
  if code == 45 or code == 48 then return "Fog" end
  if code >= 51 and code <= 67 then return "Drizzle" end
  if code >= 71 and code <= 77 then return "Snow" end
  if code >= 80 and code <= 82 then return "Showers" end
  if code >= 85 and code <= 86 then return "Snow showers" end
  if code >= 95 and code <= 99 then return "Storm" end
  return "Weather"
end

local function setting(p)
  local ok, v = pcall(noctalia.getSetting, p)
  if ok then return v end
  return nil
end

local function degrees(c)
  if type(c) ~= "number" then return nil end
  if setting("weather.unit") == "imperial" then c = c * 9 / 5 + 32 end
  return math.floor(c + 0.5)
end

local function render()
  local temp = now and degrees(now.temp)
  local children = {
    ui.glyph({ name = now and glyph(now.code, now.day) or "weather-cloud", size = seg.GLYPH, color = seg.MUTED }),
    ui.label({ text = temp and (tostring(temp) .. "°") or "–", fontSize = seg.TEXT,
      color = temp and "on_surface" or seg.FAINT }),
  }
  local moon = phase.inCentre("moon") and phase.now() or nil
  if moon then
    table.insert(children, ui.label({ text = "·", fontSize = seg.TEXT, color = seg.FAINT }))
    for _, l in ipairs(phase.labels(seg, moon)) do table.insert(children, l) end
  end
  barWidget.render(ui.row({ gap = 0, align = "center" }, {
    seg.segment({ paddingH = 12, gap = 7 }, children),
    seg.divider(),
  }))
  local rows = {}
  local unit = "°"
  if now then
    table.insert(rows, { "Now", condition(now.code) .. (temp and (", " .. tostring(temp) .. unit) or "") })
  else
    table.insert(rows, { "Weather", "no reading yet" })
  end
  if now and now.feels then table.insert(rows, { "Feels like", tostring(degrees(now.feels)) .. unit }) end
  if now and now.high and now.low then
    table.insert(rows, { "Today", tostring(degrees(now.low)) .. unit .. " to " .. tostring(degrees(now.high)) .. unit })
  end
  if now and now.humidity then table.insert(rows, { "Humidity", tostring(now.humidity) .. "%" }) end
  if now and now.place and now.place ~= "" then table.insert(rows, { "Place", now.place }) end
  if moon then table.insert(rows, { "Moon", moon.name .. ", " .. tostring(moon.lit) .. "% lit" }) end
  barWidget.setTooltip(rows)
end

local function parse(text)
  local ok, data = pcall(noctalia.json.decode, text or "")
  local s = ok and type(data) == "table" and data.snapshot
  if type(s) ~= "table" or not s.valid or type(s.current) ~= "table" then return nil end
  local c, day = s.current, (type(s.forecast_days) == "table" and s.forecast_days[1]) or {}
  return {
    temp = c.temperature_c, code = tonumber(c.weather_code) or 3, day = c.is_day ~= false,
    feels = type(c.apparent_temperature_c) == "number" and c.apparent_temperature_c or nil,
    high = type(day.temperature_max_c) == "number" and day.temperature_max_c or nil,
    low = type(day.temperature_min_c) == "number" and day.temperature_min_c or nil,
    humidity = tonumber(c.relative_humidity_percent), place = s.location_name,
  }
end

-- Reads the cache only when it changed (Noctalia rewrites it on each lookup).
local function refresh()
  local info = noctalia.fileInfo(path)
  if not info then
    if now ~= nil or seen ~= 0 then now = nil; seen = 0; render() end
    return
  end
  if info.mtime == seen then return end
  seen = info.mtime
  noctalia.readFileAsync(path, function(text, _err)
    now = parse(text)
    render()
  end)
end

function update()
  noctalia.setUpdateInterval(60 * 1000)
  refresh()
  render() -- the moon moves on too
end

-- `@DISTRO_ID@ theme` and `bar` send this.
function onIpc(event, _payload)
  if event == "refresh" then seen = -1; refresh(); render() end
end

render()
update()
