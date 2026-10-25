--!nonstrict
-- Weather helpers shared by the bar segment and its popover: Noctalia's glyphs
-- and plain names for Open-Meteo's weather codes, the unit setting, and the
-- reading Noctalia keeps on disk (nothing is fetched here).
local M = {}

do
  local cache = noctalia.getenv("XDG_CACHE_HOME")
  if not cache or cache == "" then cache = (noctalia.getenv("HOME") or "") .. "/.cache" end
  M.path = cache .. "/noctalia/weather.json"
end

-- Noctalia's own glyphs for the codes (WeatherService::glyphForCode).
function M.glyph(code, day)
  if code == 0 then return day and "weather-sun" or "weather-moon" end
  if code == 1 or code == 2 then return day and "weather-cloud-sun" or "weather-moon-stars" end
  if code >= 45 and code <= 48 then return "weather-cloud-haze" end
  if (code >= 51 and code <= 67) or (code >= 80 and code <= 82) then return "weather-cloud-rain" end
  if (code >= 71 and code <= 77) or (code >= 85 and code <= 86) then return "weather-cloud-snow" end
  if code >= 95 and code <= 99 then return "weather-cloud-lightning" end
  return "weather-cloud"
end

function M.condition(code)
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

function M.imperial()
  local ok, v = pcall(noctalia.getSetting, "weather.unit")
  return ok and v == "imperial"
end

function M.degrees(c)
  if type(c) ~= "number" then return nil end
  if M.imperial() then c = c * 9 / 5 + 32 end
  return math.floor(c + 0.5)
end

function M.speed(kmh)
  if type(kmh) ~= "number" then return nil end
  if M.imperial() then return string.format("%d mph", math.floor(kmh / 1.609 + 0.5)) end
  return string.format("%d km/h", math.floor(kmh + 0.5))
end

function M.compass(deg)
  if type(deg) ~= "number" then return "" end
  local names = { "N", "NE", "E", "SE", "S", "SW", "W", "NW" }
  return names[(math.floor((deg + 22.5) / 45) % 8) + 1]
end

-- The whole snapshot, or nil.
function M.parse(text)
  local ok, data = pcall(noctalia.json.decode, text or "")
  local s = ok and type(data) == "table" and data.snapshot
  if type(s) ~= "table" or not s.valid or type(s.current) ~= "table" then return nil end
  return s
end

return M
