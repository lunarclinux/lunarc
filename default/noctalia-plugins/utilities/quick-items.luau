--!nonstrict
-- The quick settings: every switch the bar's toggles and the quick settings
-- popover (SUPER+S) can show, defined once so both look and act the same.
-- Where each one shows is the user's choice (`@DISTRO_ID@ quick`): the bar, the
-- popover, both, or neither. Noctalia's own controls (`noctalia msg`) do the
-- work where it has them; the `@DISTRO_ID@` command does the rest.
--
-- An item: id, label, title (tooltip), bar (the bar widget's instance name),
-- glyph(state) → name, read(cb) → cb(state), toggle(state, cb), optionally
-- alt(state, cb) (right-click), init(cb) (after a shell restart) and
-- interval(state) (seconds between reads). A state: { on, text?, color? }.
-- After an action, the state is shared (noctalia.state "quick:<id>"), so the
-- bar and the popover follow each other.
local common = require("./common.luau")
local M = {}

local function msg(args, cb)
  local argv = { "noctalia", "msg" }
  for _, a in ipairs(args) do table.insert(argv, a) end
  noctalia.runAsync(argv, function(r) if cb then cb(r.exitCode == 0 and noctalia.string.trim(r.stdout or "") or nil) end end)
end

local function sh(argv, cb)
  noctalia.runAsync(argv, function(r) cb(r.exitCode == 0 and noctalia.string.trim(r.stdout or "") or nil) end)
end

-- An on/off item backed by a status command and on/off commands.
local function switch(def)
  def.glyph = def.glyph or function(s) return s.on and def.icons[1] or def.icons[2] end
  def.toggle = def.toggle or function(s, cb) def.set(not s.on, cb) end
  return def
end

M.items = {
  switch({
    id = "wifi", label = "Wi-Fi", bar = "qs-wifi", icons = { "wifi", "wifi-off" },
    read = function(cb) msg({ "wifi-status" }, function(out) cb({ on = out == "on" }) end) end,
    set = function(on, cb) msg({ on and "wifi-enable" or "wifi-disable" }, function(_) cb() end) end,
  }),
  switch({
    id = "bluetooth", label = "Bluetooth", bar = "qs-bluetooth", icons = { "bluetooth", "bluetooth-off" },
    read = function(cb) msg({ "bluetooth-status" }, function(out) cb({ on = out == "on" }) end) end,
    set = function(on, cb) msg({ on and "bluetooth-enable" or "bluetooth-disable" }, function(_) cb() end) end,
  }),
  switch({
    id = "stay-awake", label = "Stay awake", title = "Keeps the screen on and the computer awake",
    bar = "stay-awake", icons = { "eye", "eye-off" },
    read = function(cb) common.run({ "awake", "status" }, function(out) cb({ on = out == "on" }) end) end,
    set = function(on, cb) common.run({ "awake", on and "on" or "off" }, function(_) cb() end) end,
    init = function(cb) common.run({ "awake", "apply" }, function(_) cb() end) end,
  }),
  switch({
    id = "nightlight", label = "Night light", title = "Warmer screen colours", bar = "night-light",
    icons = { "moon-filled", "moon" },
    read = function(cb) common.run({ "nightlight", "status" }, function(out) cb({ on = out == "on" }) end) end,
    set = function(on, cb) common.run({ "nightlight", on and "on" or "off" }, function(_) cb() end) end,
    init = function(cb) common.run({ "nightlight", "apply" }, function(_) cb() end) end,
  }),
  switch({
    id = "silence", label = "Do not disturb", title = "Notifications go to the list without popping up",
    bar = "silence", icons = { "bell-off", "bell" },
    read = function(cb) msg({ "notification-dnd-status" }, function(out) cb({ on = out == "on" }) end) end,
    set = function(on, cb) msg({ "notification-dnd-set", on and "on" or "off" }, function(_) cb() end) end,
    interval = function(_) return 5 end,
  }),
  {
    -- Not on/off: the power profile, stepped through on click. On (amber)
    -- when it isn't the everyday "balanced".
    id = "power", label = "Power profile", bar = "qs-power",
    read = function(cb)
      sh({ "powerprofilesctl", "get" }, function(out)
        if not out then cb({ on = false, text = "unavailable", missing = true }) return end
        local names = { ["power-saver"] = "Power saver", balanced = "Balanced", performance = "Performance" }
        cb({ on = out ~= "balanced", text = names[out] or out, profile = out })
      end)
    end,
    glyph = function(s)
      return s.profile == "performance" and "bolt" or s.profile == "power-saver" and "leaf" or "scale"
    end,
    toggle = function(_, cb) msg({ "power-cycle" }, function(_) cb() end) end,
  },
  switch({
    id = "dark", label = "Dark mode", title = "The theme's dark or light colours", bar = "qs-dark",
    icons = { "moon-stars", "sun" },
    read = function(cb) msg({ "theme-mode-get" }, function(out) cb({ on = out == "dark" }) end) end,
    set = function(on, cb) common.run({ "theme", "mode", on and "dark" or "light" }, function(_) cb() end) end,
  }),
  switch({
    id = "mic", label = "Mic off", title = "Mutes the microphone", bar = "qs-mic",
    icons = { "microphone-off", "microphone" },
    read = function(cb)
      sh({ "pactl", "get-source-mute", "@DEFAULT_SOURCE@" }, function(out) cb({ on = out == "Mute: yes" }) end)
    end,
    set = function(on, cb) sh({ "wpctl", "set-mute", "@DEFAULT_AUDIO_SOURCE@", on and "1" or "0" }, function(_) cb() end) end,
    interval = function(_) return 5 end,
  }),
  switch({
    id = "gravity", label = "Low Gravity", title = "Floats this workspace's windows; again to tile",
    bar = "gravity", icons = { "feather-filled", "feather" },
    read = function(cb)
      common.run({ "gravity", "status", "--json" }, function(out)
        local ok, d = pcall(noctalia.json.decode, out or "")
        if ok and type(d) == "table" then cb({ on = d.on == true, all = d.all == true }) else cb(nil) end
      end)
    end,
    toggle = function(_, cb) common.run({ "gravity", "toggle" }, function(_) cb() end) end,
    interval = function(_) return 15 end,
  }),
  {
    -- Reminders: the count of upcoming ones; a click opens the list.
    id = "reminders", label = "Reminders", bar = "reminders",
    glyph = function(_) return "alarm" end,
    read = function(cb)
      common.run({ "remind", "list", "--json" }, function(out)
        local ok, list = pcall(noctalia.json.decode, out or "[]")
        local n = ok and type(list) == "table" and #list or 0
        cb({ on = n > 0, text = n > 0 and tostring(n) or nil, count = n })
      end)
    end,
    toggle = function(_, cb) noctalia.togglePanel(common.cli .. "/utilities:reminders-panel"); cb() end,
    interval = function(_) return 30 end,
  },
  {
    -- Recording the screen: click to start or stop; right-click records a
    -- region. `● REC 02:14` in coral while recording.
    id = "recorder", label = "Record screen", title = "Right-click: a region", bar = "recorder",
    glyph = function(s) return s.on and "player-record" or "video" end,
    read = function(cb)
      common.run({ "capture", "status" }, function(out) cb({ on = out == "recording" }) end)
    end,
    toggle = function(_, cb) common.run({ "capture", "record-toggle", "screen" }, function(_) cb() end) end,
    alt = function(s, cb)
      common.run(s.on and { "capture", "stop" } or { "capture", "record", "region" }, function(_) cb() end)
    end,
    interval = function(s) return s.on and 1 or 15 end,
  },
  {
    -- Dictation: click, speak, click again. The first click sets it up
    -- (downloads the speech model once).
    id = "dictate", label = "Dictate", bar = "dictate",
    glyph = function(s) return s.listening and "microphone-filled" or "microphone" end,
    read = function(cb)
      common.run({ "dictate", "status" }, function(out)
        local st = out or "not set up"
        cb({ on = st == "listening" or st == "setting up", listening = st == "listening", status = st,
          color = st == "listening" and "error" or nil })
      end)
    end,
    toggle = function(_, cb) common.run({ "dictate", "toggle" }, function(_) cb() end) end,
    interval = function(s) return s.listening and 1 or s.status == "setting up" and 3 or 15 end,
  },
}

M.byId = {}
M.ids = {}
for _, it in ipairs(M.items) do
  M.byId[it.id] = it
  table.insert(M.ids, it.id)
end

-- Reads an item and shares the result; cb(state) gets it too.
function M.refresh(id, cb)
  local it = M.byId[id]
  if not it then return end
  it.read(function(s)
    if s then noctalia.state.set("quick:" .. id, s) end
    if cb then cb(s) end
  end)
end

-- Runs an item's action from its last state, then reads it again.
function M.act(id, alt)
  local it = M.byId[id]
  if not it then return end
  local s = noctalia.state.get("quick:" .. id) or { on = false }
  local fn = alt and it.alt or it.toggle
  if not fn then return end
  fn(s, function() M.refresh(id) end)
end

-- Where each item shows: the settings quick.bar and quick.panel, from
-- `@DISTRO_ID@ quick list --plain` ("id<TAB>bar|panel|both|off" per line).
function M.places(cb)
  common.run({ "quick", "list", "--plain" }, function(out)
    local bar, panel = {}, {}
    for _, line in ipairs(string.split(out or "", "\n")) do
      local id, where = string.match(line, "^([%w-]+)\t(%a+)$")
      if id then
        if where == "bar" or where == "both" then table.insert(bar, id) end
        if where == "panel" or where == "both" then table.insert(panel, id) end
      end
    end
    cb(bar, panel, out ~= nil)
  end)
end

return M
