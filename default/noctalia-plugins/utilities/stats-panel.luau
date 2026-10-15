--!nonstrict
-- The stats popover, under the bar's pulse icon: CPU, memory, network and
-- battery, each with a thin bar, under a `── SYSTEM` / `up 3d 4h ──` header.
-- Tells the bar icon when it is open (for its active look) and hovered (hover
-- mode keeps it open while the pointer is on it).
local fmt = require("./stats-format.luau")

local MONO = "Geist Mono"
local NET_FULL = 12.5 * 1024 * 1024 -- 100 Mbit/s fills the network bar
local battery = nil
local uptime = nil

local function row(label, value, progress, color)
  return ui.row({ gap = 10, align = "center" }, {
    ui.label({ text = label, fontSize = 12, fontFamily = MONO, color = "on_surface_variant", width = 34 }),
    ui.progress({ progress = math.clamp(progress or 0, 0, 1), fill = color, track = "on_surface/0.1",
      radius = 1, height = 3, flexGrow = 1 }),
    ui.label({ text = value, fontSize = 12, fontFamily = MONO, color = "on_surface", width = 64, textAlign = "end" }),
  })
end

local function render()
  local s = noctalia.systemStats()
  local rows = {}
  if s then
    table.insert(rows, row("CPU", string.format("%d%%", math.floor(s.cpu.usagePercent + 0.5)), s.cpu.usagePercent / 100, "primary"))
    table.insert(rows, row("MEM", fmt.gib(s.ram.usedMb), s.ram.usagePercent / 100, "secondary"))
    table.insert(rows, row("NET", "↓" .. fmt.rate(s.net.rxBytesPerSec), (s.net.rxBytesPerSec or 0) / NET_FULL, "tertiary"))
  end
  if battery then table.insert(rows, row("BAT", tostring(battery) .. "%", battery / 100, "on_surface")) end

  panel.render(ui.column({
    gap = 12, padding = 16,
    onHover = function(state) noctalia.state.set("stats-hover", state == "true") end,
  }, {
    ui.column({ gap = 6 }, {
      ui.row({ justify = "space_between", align = "center" }, {
        ui.label({ text = "── SYSTEM", fontSize = 11, fontFamily = MONO, color = "primary" }),
        ui.label({ text = uptime and ("up " .. uptime .. " ──") or "──", fontSize = 11, fontFamily = MONO, color = "primary" }),
      }),
      ui.box({ height = 1, fill = "primary/0.28" }),
    }),
    ui.column({ gap = 10 }, rows),
  }))
end

local function readSys()
  noctalia.readFileAsync("/proc/uptime", function(text, _err)
    local secs = tonumber(text and string.match(text, "^[%d.]+"))
    uptime = secs and fmt.uptime(secs) or nil
    render()
  end)
  local names = { "BAT0", "BAT1", "BAT" }
  local function try(i)
    if i > #names then battery = nil; render() return end
    noctalia.readFileAsync("/sys/class/power_supply/" .. names[i] .. "/capacity", function(text, _err)
      local n = tonumber(text and string.match(text, "%d+"))
      if n then battery = n; render() else try(i + 1) end
    end)
  end
  try(1)
end

function onOpen(_context)
  noctalia.state.set("stats-open", true)
  noctalia.setUpdateInterval(2000)
  readSys()
  render()
end

function onClose()
  noctalia.state.set("stats-open", false)
  noctalia.state.set("stats-hover", false)
end

function update()
  readSys()
end

function onExit(_signal, _reason)
  noctalia.state.set("stats-open", false)
end
