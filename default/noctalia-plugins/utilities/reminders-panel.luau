--!nonstrict
-- Reminders panel: upcoming reminders, and a field to add one
-- ("stretch in 20m", "call Sam at 15:30").
local common = require("./common.luau")

local reminders = {}
local message = ""
local inputRev = 0

local render

local function reload()
  common.run({ "remind", "list", "--json" }, function(out)
    reminders = out and noctalia.json.decode(out) or {}
    render()
  end)
end

-- "stretch in 20m" -> { "stretch", "in", "20m" }
local function parse(text)
  local body, word, value = string.match(text, "^%s*(.-)%s+(in)%s+(%S+)%s*$")
  if not body then body, word, value = string.match(text, "^%s*(.-)%s+(at)%s+(.-)%s*$") end
  if not body or body == "" then return nil end
  return { body, word, value }
end

local function add(text)
  local parts = parse(text)
  if not parts then
    message = "Write it like: stretch in 20m, or: call Sam at 15:30"
    render()
    return
  end
  noctalia.runAsync({ common.cli, "remind", parts[1], parts[2], parts[3] }, function(result)
    if result.exitCode == 0 then
      message = ""
      inputRev += 1
    else
      message = string.gsub(result.stderr or "Couldn't add that reminder.", "^%S+: ", "")
    end
    reload()
  end)
end

local function when(due)
  local mins = math.floor((due - math.floor(noctalia.nowMs() / 1000)) / 60)
  local clock = noctalia.formatTime("{:%a %H:%M}", due)
  if mins < 1 then return clock .. " · now" end
  if mins < 60 then return clock .. " · in " .. tostring(mins) .. " min" end
  return clock
end

render = function()
  local rows = {}
  for _, r in ipairs(reminders) do
    table.insert(rows, ui.row({ key = r.id, align = "center", gap = 10, padding = 10, radius = 10, fill = "surface_container_low" }, {
      ui.glyph({ name = "alarm", size = 16, color = "primary" }),
      ui.column({ flexGrow = 1, gap = 2 }, {
        ui.label({ text = r.text, fontWeight = "bold", maxLines = 2 }),
        ui.label({ text = when(r.due), color = "on_surface_variant", fontSize = 12 }),
      }),
      ui.button({ glyph = "x", variant = "ghost", controlSize = "sm", tooltip = "Cancel",
        onClick = function() common.run({ "remind", "cancel", r.id }, function(_) reload() end) end }),
    }))
  end
  if #rows == 0 then
    table.insert(rows, ui.label({ text = "No reminders.", color = "on_surface_variant" }))
  end
  local children = {
    ui.row({ align = "center", gap = 8 }, {
      ui.label({ text = "Reminders", fontSize = 16, fontWeight = "bold", flexGrow = 1 }),
      ui.button({ glyph = "close", variant = "ghost", controlSize = "sm", onClick = function() panel.close() end }),
    }),
    ui.input({ key = "add-" .. tostring(inputRev), placeholder = "stretch in 20m · call Sam at 15:30",
      submitOnEnter = true, focus = true, onSubmit = add }),
  }
  if message ~= "" then
    table.insert(children, ui.row({ fill = "error_container", radius = 6, paddingH = 8, paddingV = 4 }, {
      ui.label({ text = message, color = "on_error_container", fontSize = 12 }),
    }))
  end
  table.insert(children, ui.scroll({ flexGrow = 1, gap = 8 }, rows))
  panel.render(ui.column({ flexGrow = 1, gap = 12 }, children))
end

-- While it's open the bar's toggles stay revealed, so the alarm it hangs from
-- doesn't hide (toggles.luau).
function onOpen(_context) noctalia.state.set("hold", true); reload() end
function onClose() noctalia.state.set("hold", false) end
function update() reload() end
function onIpc(event, _payload) if event == "refresh" then reload() end end
