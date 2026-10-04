--!nonstrict
-- Viewer panel: every open crash with its count and status, and buttons to
-- diagnose, resolve or ignore it. "Diagnose all" sends every open crash to the
-- AI agent together (in a terminal or in the background, per crash.diagnose_all).
local common = require("./common.luau")

local crashes = {}
local expanded = {}          -- id -> true when details are shown
local lastCounts = {}        -- id -> count at the previous load
local wiggle = {}            -- id -> remaining ms of the count-badge wiggle
local stateDir = noctalia.expandPath("~/.local/state/" .. common.cli .. "/crashes/")

local function ago(t)
  local s = math.max(0, math.floor(noctalia.nowMs() / 1000) - t)
  if s < 60 then return "just now" end
  if s < 3600 then return tostring(math.floor(s / 60)) .. " min ago" end
  if s < 86400 then return tostring(math.floor(s / 3600)) .. " h ago" end
  return tostring(math.floor(s / 86400)) .. " d ago"
end

local statusText = { new = "New", diagnosing = "Diagnosing…", diagnosed = "Diagnosed" }

local render

local function reload()
  common.load(function(list)
    for _, c in ipairs(list) do
      if lastCounts[c.id] ~= nil and c.count > lastCounts[c.id] then wiggle[c.id] = 600 end
      lastCounts[c.id] = c.count
    end
    crashes = list
    render()
  end)
end

local function act(args) common.run(args, reload) end

local function detailText(c)
  local diagnosis = noctalia.readFile(stateDir .. c.id .. "/diagnosis.md")
  if diagnosis and #diagnosis > 0 then return diagnosis end
  local capture = noctalia.readFile(c.last_capture)
  if capture then
    if #capture > 4000 then capture = string.sub(capture, 1, 4000) .. "\n…" end
    -- The capture is untrusted text; keep it inside the code block.
    capture = string.gsub(capture, "```", "'''")
    return "```\n" .. capture .. "\n```"
  end
  return "_No details captured._"
end

local function crashRow(c)
  local offset = 0
  if (wiggle[c.id] or 0) > 0 then offset = (math.floor(wiggle[c.id] / 60) % 2 == 0) and 3 or 0 end
  local children = {
    ui.row({ align = "center", gap = 8 }, {
      ui.glyph({ name = "bug", size = 16, color = "error" }),
      ui.label({ text = c.comm, fontWeight = "bold", flexGrow = 1 }),
      ui.box({ width = offset, height = 1, opacity = 0 }),
      ui.row({ fill = "error/0.22", radius = 8, paddingH = 7, align = "center" }, {
        ui.label({ text = "×" .. tostring(c.count), color = "error", fontWeight = "bold" }),
      }),
      ui.box({ width = 3 - offset, height = 1, opacity = 0 }),
    }),
    ui.label({
      text = c.signal .. " · " .. ago(c.last) .. " · " .. (statusText[c.status] or c.status),
      color = "on_surface_variant", fontSize = 12,
    }),
    ui.label({ text = c.exe, color = "on_surface_variant", fontSize = 11, maxLines = 1 }),
    ui.row({ gap = 6 }, {
      ui.button({ text = "Diagnose", glyph = "sparkles", variant = "primary", controlSize = "sm",
        enabled = c.status ~= "diagnosing", onClick = function() act({ "diagnose", c.id }) end }),
      ui.button({ text = "Resolve", glyph = "check", controlSize = "sm",
        onClick = function() act({ "resolve", c.id }) end }),
      ui.button({ text = "Ignore", glyph = "bell-off", variant = "ghost", controlSize = "sm",
        onClick = function() act({ "ignore", c.id }) end }),
      ui.spacer({ flexGrow = 1 }),
      ui.button({ glyph = expanded[c.id] and "chevron-up" or "chevron-down", variant = "ghost", controlSize = "sm",
        tooltip = "Details", onClick = function() expanded[c.id] = not expanded[c.id]; render() end }),
    }),
  }
  if expanded[c.id] then
    table.insert(children, ui.markdown({ text = detailText(c) }))
  end
  return ui.column({ key = c.id, gap = 6, padding = 12, radius = 10, fill = "surface_variant/0.6" }, children)
end

render = function()
  local rows = {}
  for _, c in ipairs(crashes) do table.insert(rows, crashRow(c)) end
  if #rows == 0 then
    table.insert(rows, ui.column({ align = "center", padding = 24, gap = 8 }, {
      ui.glyph({ name = "mood-happy", size = 28, color = "on_surface_variant" }),
      ui.label({ text = "No open crashes.", color = "on_surface_variant" }),
    }))
  end
  panel.render(ui.column({ flexGrow = 1, gap = 12 }, {
    ui.row({ align = "center", gap = 8 }, {
      ui.label({ text = "Crashes", fontSize = 16, fontWeight = "bold", flexGrow = 1 }),
      ui.button({ text = "Diagnose all", glyph = "sparkles", controlSize = "sm", enabled = #crashes > 0,
        onClick = function() act({ "diagnose", "--all" }) end }),
      ui.button({ glyph = "close", variant = "ghost", controlSize = "sm", onClick = function() panel.close() end }),
    }),
    ui.scroll({ flexGrow = 1, gap = 10 }, rows),
  }))
end

function onOpen(_context)
  panel.setNeedsFrameTick(true)
  reload()
end

function onClose()
  panel.setNeedsFrameTick(false)
end

function onFrameTick(deltaMs)
  local active = false
  for id, ms in pairs(wiggle) do
    wiggle[id] = ms - deltaMs
    if wiggle[id] <= 0 then wiggle[id] = nil end
    active = true
  end
  if active then render() end
end

function update()
  reload()
end

function onIpc(event, _payload)
  if event == "refresh" then reload() end
end
