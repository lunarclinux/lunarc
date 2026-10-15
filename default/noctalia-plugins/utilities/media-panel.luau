--!nonstrict
-- Now playing (Frosted Terminal §5, reference 04), under the bar's media
-- segment: the art, title, artist and album, the controls, progress drawn as
-- `━━━╸───`, up next (only from players that publish their track list) and
-- the sound output, which a click moves to the next one. Space plays or
-- pauses, Left and Right seek.
--
-- What plays comes from the media segment (state "media", one playerctl
-- stream for both); the position is read when it opens or changes and counted
-- on from there. Art is shown only when the player gives a local file:
-- nothing is downloaded here.
local look = require("./menu-look.luau")
local cli = "@DISTRO_ID@"
local WIDTH = 480
local ART = 128

local m = {}
local isOpen = false
local pos, posAt = 0, 0   -- seconds, at noctalia.nowMs()
local queue = {}          -- up next: { title, length }
local sinks, sink = {}, nil
local render

local function close() panel.close() end

-- The art, when the player names a local file (checked once per track).
local artFor, artPath = nil, nil
local function artFile()
  if m.art ~= artFor then
    artFor = m.art
    local file = string.match(m.art or "", "^file://(/.+)$")
    file = file and noctalia.string.urlDecode(file) or nil
    artPath = file and noctalia.fileExists(file) and file or nil
  end
  return artPath
end

local function player()
  local p = m.player or ""
  return string.match(p, "^[%w._-]+$") and p or nil
end

local function clock(s)
  s = math.max(0, math.floor(s or 0))
  if s >= 3600 then return string.format("%d:%02d:%02d", s // 3600, (s // 60) % 60, s % 60) end
  return string.format("%02d:%02d", s // 60, s % 60)
end

local function now()
  if m.status == "Playing" then return pos + (noctalia.nowMs() - posAt) / 1000 end
  return pos
end

local function playerctl(args, cb)
  local p = player()
  if not p then return end
  local argv = { "playerctl", "-p", p }
  for _, a in ipairs(args) do table.insert(argv, a) end
  noctalia.runAsync(argv, cb)
end

local function readPosition()
  playerctl({ "position" }, function(r)
    pos, posAt = tonumber(noctalia.string.trim(r.stdout or "")) or 0, noctalia.nowMs()
    if isOpen then render() end
  end)
end

-- busctl's JSON: a value is { type, data }.
local function busctl(args, cb)
  local argv = { "busctl", "--user", "--json=short" }
  for _, a in ipairs(args) do table.insert(argv, a) end
  noctalia.runAsync(argv, function(r)
    local ok, v = pcall(noctalia.json.decode, r.exitCode == 0 and r.stdout or "")
    cb(ok and type(v) == "table" and v.data or nil)
  end)
end

-- Up next: the tracks after this one, for players with a track list (most
-- have none, and then the section isn't shown).
local function readQueue()
  local p = player()
  if not p then queue = {}; return end
  local bus, path = "org.mpris.MediaPlayer2." .. p, "/org/mpris/MediaPlayer2"
  busctl({ "get-property", bus, path, "org.mpris.MediaPlayer2", "HasTrackList" }, function(has)
    if has ~= true then queue = {}; if isOpen then render() end; return end
    busctl({ "get-property", bus, path, "org.mpris.MediaPlayer2.TrackList", "Tracks" }, function(ids)
      if type(ids) ~= "table" then return end
      local after, seen = {}, false
      for _, id in ipairs(ids) do
        if seen and #after < 3 and string.match(id, "^/[%w_/]*$") then table.insert(after, id) end
        if id == m.track then seen = true end
      end
      if #after == 0 then queue = {}; if isOpen then render() end; return end
      local args = { "call", bus, path, "org.mpris.MediaPlayer2.TrackList", "GetTracksMetadata", "ao", tostring(#after) }
      for _, id in ipairs(after) do table.insert(args, id) end
      busctl(args, function(data)
        queue = {}
        for _, t in ipairs(type(data) == "table" and data[1] or {}) do
          local function field(k) return type(t[k]) == "table" and t[k].data or nil end
          local length = tonumber(field("mpris:length"))
          table.insert(queue, { title = tostring(field("xesam:title") or "?"), length = length and length / 1e6 or nil })
        end
        if isOpen then render() end
      end)
    end)
  end)
end

-- The outputs, from PipeWire's PulseAudio side.
local function readSinks()
  noctalia.runAsync({ "pactl", "-f", "json", "list", "sinks" }, function(r)
    local ok, list = pcall(noctalia.json.decode, r.exitCode == 0 and r.stdout or "")
    sinks = {}
    for _, s in ipairs(ok and type(list) == "table" and list or {}) do
      if type(s.name) == "string" then table.insert(sinks, { name = s.name, desc = s.description or s.name }) end
    end
    noctalia.runAsync({ "pactl", "get-default-sink" }, function(d)
      local name = noctalia.string.trim(d.stdout or "")
      sink = nil
      for _, s in ipairs(sinks) do if s.name == name then sink = s end end
      if isOpen then render() end
    end)
  end)
end

local function nextSink()
  if #sinks < 2 then return end
  local i = 1
  for k, s in ipairs(sinks) do if sink and s.name == sink.name then i = k end end
  local to = sinks[i % #sinks + 1]
  if not string.match(to.name, "^[%w._:-]+$") then return end
  noctalia.runAsync({ "pactl", "set-default-sink", to.name }, function() readSinks() end)
end

local function playPause()
  playerctl({ "play-pause" }, function() readPosition() end)
end

local function seek(by)
  playerctl({ "position", by }, function() readPosition() end)
end

local function button(key, glyph, size, onClick, primary)
  local p = look.p
  return look.row({ key = key, width = size, height = size, radius = size / 2, align = "center", justify = "center",
    fill = primary and p.amber or p.button, border = primary and p.amber or p.buttonBorder, borderWidth = 1,
    onClick = onClick }, {
    ui.glyph({ name = glyph, size = primary and 22 or 18, color = primary and p.onAmber or p.text }),
  })
end

-- `━━━━╸────`: the played part amber, the rest dim; as many characters as fit
-- the row (Geist Mono's advance is 0.6 em).
local function progress()
  local p = look.p
  local length = (m.length or 0) / 1e6
  local cells = 42
  local done = length > 0 and math.clamp(math.floor(now() / length * cells + 0.5), 0, cells - 1) or 0
  return look.row({ key = "progress", paddingH = 18, gap = 10, align = "center" }, {
    look.label(clock(now()), 12, p.text, { key = "at" }),
    look.row({ key = "bar", gap = 0, flexGrow = 1, align = "center" }, {
      look.label(string.rep("━", done) .. "╸", 12, p.amber, { key = "done" }),
      look.label(string.rep("━", cells - done - 1), 12, p.track, { key = "left" }),
    }),
    look.label(length > 0 and clock(length) or "--:--", 12, p.dim, { key = "length" }),
  })
end

render = function()
  local p = look.p
  local rows = {}
  local playing = m.status == "Playing"
  table.insert(rows, look.header("NOW PLAYING", player() and string.lower(string.match(player(), "^[^.]+")) or nil))

  if m.status ~= "Playing" and m.status ~= "Paused" then
    table.insert(rows, look.row({ key = "none", paddingH = 18, paddingV = 22 }, { look.label("Nothing is playing", 13, p.dim) }))
  else
    local art
    local file = artFile()
    if file then
      art = ui.image({ key = "art", path = file, width = ART, height = ART, radius = 8, fit = "cover",
        border = p.buttonBorder, borderWidth = 1 })
    else
      art = look.col({ key = "art", width = ART, height = ART, radius = 8, fill = p.button, border = p.buttonBorder,
        borderWidth = 1, align = "center", justify = "center" }, {
        ui.glyph({ name = "music", size = 28, color = p.faint }),
      })
    end
    local info = {
      ui.label({ key = "title", text = m.title ~= "" and m.title or "Unknown", fontFamily = "Geist", fontSize = 22,
        fontWeight = "semibold", color = p.text, maxLines = 2, flexGrow = 0 }),
    }
    if m.artist ~= "" then
      table.insert(info, ui.label({ key = "artist", text = m.artist, fontFamily = "Geist", fontSize = 14,
        color = p.secondary, maxLines = 1, flexGrow = 0 }))
    end
    if m.album ~= "" then table.insert(info, look.label(m.album, 11.5, p.dim, { key = "album" })) end
    table.insert(info, ui.spacer({ key = "space", flexGrow = 1 }))
    table.insert(info, look.row({ key = "controls", gap = 10, align = "center" }, {
      button("prev", "player-skip-back", 36, function() playerctl({ "previous" }) end),
      button("play", playing and "player-pause" or "player-play", 52, playPause, true),
      button("next", "player-skip-forward", 36, function() playerctl({ "next" }) end),
    }))
    table.insert(rows, look.row({ key = "now", padding = 18, gap = 18 }, {
      art,
      look.col({ key = "info", gap = 4, flexGrow = 1 }, info),
    }))
    table.insert(rows, progress())
    table.insert(rows, look.box({ key = "progress-gap", width = 0, height = 16, fill = "#00000000" }))

    if #queue > 0 then
      local list = { look.box({ key = "line", width = 0, height = 1, fill = p.divider }),
        look.row({ key = "label", paddingH = 14, paddingV = 6 }, { look.label("── UP NEXT", 11, p.dim) }) }
      for i, t in ipairs(queue) do
        table.insert(list, look.row({ key = "q" .. i, paddingH = 14, paddingV = 4, gap = 12, align = "center" }, {
          look.label(string.format("%02d", i), 12, p.faint, { width = 18 }),
          look.label(t.title, 12.5, p.body, { flexGrow = 1 }),
          look.label(t.length and clock(t.length) or "", 12, p.dim),
        }))
      end
      table.insert(list, look.box({ key = "end", width = 0, height = 6, fill = "#00000000" }))
      table.insert(rows, look.col({ key = "queue", gap = 0 }, list))
    end
  end

  -- The output, then the keys.
  table.insert(rows, look.box({ key = "divider", width = 0, height = 1, fill = p.divider }))
  local out = {
    look.label("→", 12, p.dim, { key = "arrow" }),
    look.label(sink and sink.desc or "no sound output", 12, p.secondary, { key = "sink", maxWidth = 250 }),
  }
  if #sinks > 1 then table.insert(out, ui.glyph({ key = "more", name = "chevron-down", size = 14, color = p.dim })) end
  table.insert(rows, look.row({ key = "footer", paddingH = 14, paddingV = 8, gap = 14, align = "center" }, {
    look.row({ key = "output", gap = 8, align = "center", onClick = #sinks > 1 and nextSink or nil }, out),
    ui.spacer({ key = "space", flexGrow = 1 }),
    look.hint("space", playing and "pause" or "play", "space-hint"),
    look.hint("←→", "seek", "seek-hint"),
  }))

  panel.render(look.col({ gap = 0, width = WIDTH, flexGrow = 1 }, {
    look.surface({ key = "popover" }, rows),
    look.box({ key = "below", flexGrow = 1, fill = "#00000000", onClick = close }),
  }))
end

local lastTrack = nil
noctalia.state.watch("media", function(v)
  m = type(v) == "table" and v or {}
  if not isOpen then return end
  if m.track ~= lastTrack then lastTrack = m.track; readQueue() end
  readPosition()
end)

function onOpen(_context)
  isOpen = true
  look.load()
  m = noctalia.state.get("media") or {}
  lastTrack = m.track
  queue = {}
  noctalia.state.set("media-open", true)
  noctalia.setUpdateInterval(1000)
  render()
  readPosition()
  readQueue()
  readSinks()
end

function onClose()
  isOpen = false
  noctalia.state.set("media-open", false)
end

-- Once a second while open: the progress moves on.
function update()
  if isOpen and m.status == "Playing" then render() end
end

function onKey(chord, pressed)
  if not pressed then return end
  if chord == "space" then playPause()
  elseif chord == "Left" then seek("5-")
  elseif chord == "Right" then seek("5+") end
end

-- State for the VM test (vm/test-install): `noctalia msg plugin
-- <id>/utilities:now-playing all dump` writes what the popover shows.
function onIpc(event, _payload)
  if event ~= "dump" then return end
  local dir = noctalia.getenv("XDG_RUNTIME_DIR")
  if not dir or dir == "" then return end
  local q = {}
  for _, t in ipairs(queue) do table.insert(q, t.title) end
  noctalia.writeFile(dir .. "/" .. cli .. "-now-playing.json", noctalia.json.encode({
    open = isOpen, status = m.status or "", title = m.title or "", artist = m.artist or "", player = m.player or "",
    position = math.floor(now()), queue = q, output = sink and sink.desc or "", outputs = #sinks,
  }))
end

function onExit(_signal, _reason)
  noctalia.state.set("media-open", false)
end
