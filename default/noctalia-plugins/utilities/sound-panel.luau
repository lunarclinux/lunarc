--!nonstrict
-- The sound popover, under the bar's sound segment, in the stats popover's
-- look (pop.luau): the output and the microphone, each with its device, a
-- volume slider and mute. Changes go straight to PipeWire through pactl.
local pop = require("./pop.luau")
local snd = require("./sound-common.luau")

local state = nil

local function changed()
  noctalia.state.set("sound-changed", noctalia.nowMs())
end

local function reload()
  snd.load(function(s) state = s; render() end)
end

-- One device block: a header, the device picker (when there's a choice), the
-- volume slider with its value, and mute.
local function block(title, list, default, kind)
  local dev = snd.find(list, default)
  if not dev then
    return ui.column({ gap = 8 }, { pop.header(title, nil), pop.muted("None found") })
  end
  local children = { pop.header(title, dev.mute and "muted" or (tostring(dev.volume) .. "%")) }
  if #list > 1 then
    local labels, selected = {}, 0
    for i, d in ipairs(list) do
      table.insert(labels, d.label)
      if d.name == dev.name then selected = i - 1 end
    end
    table.insert(children, ui.select({ key = kind .. "-device", options = labels, selectedIndex = selected,
      onChange = function(a, b)
        local pick = nil
        for _, d in ipairs(list) do if d.label == b then pick = d end end
        if not pick then pick = list[(tonumber(a) or 0) + 1] end
        if pick then
          snd.run({ "pactl", kind == "out" and "set-default-sink" or "set-default-source", pick.name })
          if kind == "out" then state.sink = pick.name else state.source = pick.name end
          changed(); render()
        end
      end }))
  else
    table.insert(children, pop.muted(dev.label, { maxLines = 1 }))
  end
  table.insert(children, ui.row({ gap = 10, align = "center" }, {
    ui.glyph({ name = kind == "out" and snd.glyph(dev) or (dev.mute and "microphone-mute" or "microphone"),
      size = 16, color = dev.mute and "on_surface_variant" or "primary" }),
    ui.slider({ key = kind .. "-volume", min = 0, max = 100, step = 1, value = dev.volume, flexGrow = 1,
      onChange = function(v)
        local n = math.floor((tonumber(v) or dev.volume) + 0.5)
        dev.volume = n
        snd.run({ "pactl", kind == "out" and "set-sink-volume" or "set-source-volume", dev.name, tostring(n) .. "%" })
        changed()
      end }),
    pop.text(tostring(dev.volume) .. "%", { width = 40, textAlign = "end" }),
  }))
  table.insert(children, ui.row({ gap = 10, align = "center" }, {
    pop.muted("Mute", { flexGrow = 1 }),
    ui.toggle({ key = kind .. "-mute", checked = dev.mute, onChange = function(_v)
      dev.mute = not dev.mute
      snd.run({ "pactl", kind == "out" and "set-sink-mute" or "set-source-mute", dev.name, dev.mute and "1" or "0" })
      changed(); render()
    end }),
  }))
  return ui.column({ gap = 10 }, children)
end

function render()
  if not state then
    panel.render(pop.panel({ pop.header("SOUND", nil), pop.muted("Reading devices…") }))
    return
  end
  panel.render(pop.panel({
    block("OUTPUT", state.sinks, state.sink, "out"),
    block("MICROPHONE", state.sources, state.source, "in"),
    ui.row({ justify = "end" }, {
      pop.button("More settings", function()
        noctalia.runAsync({ "noctalia", "msg", "panel-toggle", "control-center", "audio" }, function(_r) end)
      end, { glyph = "settings" }),
    }),
  }, { gap = 16 }))
end

function onOpen(_context)
  noctalia.state.set("sound-open", true)
  noctalia.setUpdateInterval(3000)
  reload()
  render()
end

-- Devices plugged in or out while it's open.
function update()
  reload()
end

function onClose()
  noctalia.state.set("sound-open", false)
end

function onExit(_signal, _reason)
  noctalia.state.set("sound-open", false)
end
