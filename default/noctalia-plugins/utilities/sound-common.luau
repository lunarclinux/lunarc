--!nonstrict
-- Sound devices through PipeWire's PulseAudio interface (pactl): the outputs
-- and inputs with their volume and mute, and the defaults. Used by the bar's
-- sound segment and its popover.
local M = {}

local function percent(dev)
  local v = dev.volume
  if type(v) ~= "table" then return 0 end
  for _, ch in pairs(v) do
    local p = tonumber(string.match(tostring(ch.value_percent or ""), "%d+"))
    if p then return p end
  end
  return 0
end

-- cb({ sinks = {...}, sources = {...}, sink = <default name>, source = <default name> })
function M.load(cb)
  local out = { sinks = {}, sources = {}, sink = "", source = "" }
  local pending = 4
  local function done() pending -= 1; if pending == 0 then cb(out) end end
  local function list(kind, key)
    noctalia.runAsync({ "pactl", "-f", "json", "list", kind }, function(r)
      local ok, data = pcall(noctalia.json.decode, r.stdout or "")
      if ok and type(data) == "table" then
        for _, d in ipairs(data) do
          -- Inputs: not the monitors of outputs.
          if kind == "sinks" or (d.monitor_source == nil or d.monitor_source == "") and not string.find(d.name or "", "%.monitor$") then
            table.insert(out[key], { name = d.name, label = d.description or d.name, volume = percent(d),
              mute = d.mute == true })
          end
        end
      end
      done()
    end)
  end
  list("sinks", "sinks"); list("sources", "sources")
  noctalia.runAsync({ "pactl", "get-default-sink" }, function(r) out.sink = noctalia.trim(r.stdout or ""); done() end)
  noctalia.runAsync({ "pactl", "get-default-source" }, function(r) out.source = noctalia.trim(r.stdout or ""); done() end)
end

function M.find(list, name)
  for i, d in ipairs(list) do if d.name == name then return d, i end end
  return list[1], 1
end

function M.glyph(dev)
  if not dev or dev.mute or dev.volume == 0 then return "volume-mute" end
  if dev.volume < 50 then return "volume" end
  return "volume-high"
end

function M.run(args) noctalia.runAsync(args, function(_r) end) end

return M
