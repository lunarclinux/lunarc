--!nonstrict
-- The menu (SUPER+Space; Frosted Terminal): one small
-- keyboard list. Typing filters the level you're on (at the top, deeper items
-- and apps too, shown under their group); Up and Down move; Return opens a
-- group in place or runs the item; Backspace on an empty filter goes up a
-- level; Ctrl+R starts over; Escape or a click outside closes.
--
-- Noctalia gives a panel a fixed size, so this one is drawn without the
-- shell's frame (decoration = false, a patch of the distro's Noctalia build):
-- the menu draws its own surface from the theme's tokens and grows with its
-- list, the rest of the panel stays clear. Typing goes into a hidden input;
-- the line shown is drawn here in Geist Mono. Backspace is taken by the panel
-- (to go up a level), so with text it puts the input back one character
-- shorter.
local items = require("./menu-items.luau")
local match = require("./menu-match.luau")
local look = require("./menu-look.luau")
local apps = require("./apps.luau")
local cli = "@DISTRO_ID@"
local ROWS = 9
local WIDTH = 560

local roots = {}
local stack = {}      -- the levels opened: { item, list, loading, sel }
local filter = ""
local inputRev = 0
local sel, top = 1, 1
local shown = {}      -- the rows: { item, root (for a deeper match) }
local countText = ""
local message, messageError = nil, false
local capture = nil   -- the binding being changed
local cache = {}
local searchGen = 0
local found = {}      -- Install: packages found for the current words
local isOpen = false
local topGap = 120
local render

local TAGS = { repo = "REPO", aur = "AUR", flathub = "FLATHUB" }

local function lv() return stack[#stack] end

local function trim(s) return noctalia.string.trim(s or "") end

-- Package names and words as pacman, the AUR and Flathub write them; nothing
-- else reaches a command.
local function safeName(src, name)
  if src == "flathub" then return string.match(name or "", "^[%w_][%w._-]*$") ~= nil end
  return string.match(name or "", "^[a-z0-9@._+][a-z0-9@._+-]*$") ~= nil
end
local function words(f)
  local out = {}
  for w in string.gmatch(f, "%S+") do
    if not string.match(w, "^[a-z0-9@._+-]+$") or #w > 64 then return nil end
    table.insert(out, w)
  end
  return #out > 0 and out or nil
end

-- Install: the catalog's apps that match, then what the package search found.
local function installRows(f)
  local out, taken = {}, {}
  for _, a in ipairs(items.catalog()) do
    -- Match first: building the item checks whether it's installed.
    local s = f == "" and 0 or match.score(f, a.name, a.id .. " " .. a.pkg)
    if s then
      local it = items.catalogItem(a, cache.installed or {})
      table.insert(out, { item = it, score = s })
      taken[it.pkg] = true
    end
  end
  if f ~= "" then
    table.sort(out, function(a, b) return a.score > b.score end)
    for _, it in ipairs(found) do
      if not taken[it.name] and match.positions(f, it.title) then
        taken[it.name] = true
        table.insert(out, { item = it })
      end
    end
  end
  return out
end

-- Works out the rows and the count for the level and the filter.
local function compute()
  local f = string.lower(trim(filter))
  local level = lv()
  shown = {}
  if not level then
    if f == "" then
      for _, n in ipairs(roots) do table.insert(shown, { item = n }) end
      countText = tostring(#roots)
    else
      local res, total = items.search(roots, f, cache)
      for _, r in ipairs(res) do table.insert(shown, { item = r.item, root = r.root }) end
      countText = #shown .. " of " .. total
    end
  elseif level.item.gen == "install" then
    shown = installRows(f)
    countText = #shown == 1 and "1 result" or (#shown .. " results")
  else
    local list = level.list or {}
    if f == "" then
      for _, it in ipairs(list) do table.insert(shown, { item = it }) end
      countText = level.loading and "…" or tostring(#list)
    else
      for i, it in ipairs(list) do
        local s
        if it.kind == "app" then s = apps.score(f, it.app) else s = match.score(f, it.title, it.desc or it.keys) end
        if s then table.insert(shown, { item = it, score = s, i = i }) end
      end
      table.sort(shown, function(a, b) if a.score ~= b.score then return a.score > b.score end return a.i < b.i end)
      countText = #shown .. " of " .. #list
    end
  end
  sel = math.clamp(sel, 1, math.max(1, #shown))
  if sel < top then top = sel end
  if sel > top + ROWS - 1 then top = sel - ROWS + 1 end
  top = math.clamp(top, 1, math.max(1, #shown - ROWS + 1))
end

local function refresh()
  compute()
  render()
end

local function reseed() inputRev += 1 end

local function say(text, isError)
  message, messageError = text, isError == true
end

-- Install: search the packages for the words typed, once typing pauses: the
-- repositories here after 0.2 s, the AUR (online) after 0.6 s and only once
-- a word has three letters. The pause is timed with frame ticks while a search
-- is due (a sleep process per key would run into Noctalia's limit on a
-- plugin's processes, and a panel's update() runs once a second at most).
local due = nil

local function parse(stdout, into)
  for _, line in ipairs(string.split(stdout or "", "\n")) do
    local f = string.split(line, "\t")
    if #f >= 3 and TAGS[f[1]] and safeName(f[1], f[2]) then
      local have = f[4] == "1"
      table.insert(into, { kind = "install", src = f[1], name = f[2], title = f[2], desc = f[3],
        tag = have and "INSTALLED" or TAGS[f[1]], installed = have })
    end
  end
end

local function searchPackages()
  searchGen += 1
  local level = lv()
  local w = words(string.lower(trim(filter)))
  if not level or level.item.gen ~= "install" or not w then
    found, due = {}, nil
    return
  end
  local longest = 0
  for _, x in ipairs(w) do longest = math.max(longest, #x) end
  local now = noctalia.nowMs()
  due = { words = w, gen = searchGen, here = now + 200, aur = longest >= 3 and (now + 600) or nil }
  panel.setNeedsFrameTick(true)
end

local function runSearch(w, gen, aur)
  local argv = { cli, "package", "search" }
  if aur then table.insert(argv, "--aur") end
  for _, x in ipairs(w) do table.insert(argv, x) end
  noctalia.runAsync(argv, function(result)
    if gen ~= searchGen then return end
    if aur then
      parse(result.stdout, found)
    else
      local list = {}
      parse(result.stdout, list)
      for _, it in ipairs(found) do if it.src == "aur" then table.insert(list, it) end end
      found = list
    end
    refresh()
  end)
end

function onFrameTick(_ms)
  if not due then
    panel.setNeedsFrameTick(false)
    return
  end
  local now = noctalia.nowMs()
  if due.here and now >= due.here then
    due.here = nil
    runSearch(due.words, due.gen, false)
  end
  if due.aur and now >= due.aur then
    due.aur = nil
    runSearch(due.words, due.gen, true)
  end
  if not due.here and not due.aur then
    due = nil
    panel.setNeedsFrameTick(false)
  end
end

-- Opens a level in place.
local function push(it)
  local level = { item = it, list = it.items, sel = sel, top = top }
  table.insert(stack, level)
  if it.gen and it.gen ~= "install" then
    level.loading = true
    items.generated(it.gen, cache, function(list)
      level.list, level.loading = list, false
      if lv() == level then refresh() end
    end)
  end
end

local function findIn(list, title)
  title = string.lower(trim(title))
  for _, it in ipairs(list or {}) do
    if string.lower(it.title) == title then return it end
  end
  return nil
end

-- Opens a path of titles ("Setup › Displays") from the top.
local function navigate(path)
  stack = {}
  local list = roots
  for _, part in ipairs(path) do
    local it = findIn(list, part)
    if not it or it.kind ~= "group" then break end
    push(it)
    list = it.items
  end
end

local function close() panel.close() end

local function terminal(argv)
  local cmd = { cli, "terminal", "run", "--" }
  for _, a in ipairs(argv) do table.insert(cmd, a) end
  noctalia.runAsync(cmd)
end

local function startCapture(it)
  if not it.editable then
    say("Mouse and lid bindings can't be changed here.")
    return render()
  end
  capture = it
  say(nil)
  noctalia.runAsync({ cli, "keys", "capture", "start" })
  render()
end

-- Return (or a click) on an item.
local function activate(entry)
  if not entry then return end
  local it, root = entry.item, entry.root
  if it.kind == "group" then
    if root and lv() == nil then push(root) end
    push(it)
    filter, sel, top = "", 1, 1
    found = {}
    say(nil)
    reseed()
    return refresh()
  elseif it.kind == "goto" then
    navigate(it.target)
    filter, sel, top = "", 1, 1
    reseed()
    return refresh()
  elseif it.kind == "app" then
    apps.open(it.path)
  elseif it.kind == "run" then
    if it.argv then noctalia.runAsync(it.argv) else noctalia.runAsync({ "sh", "-c", it.cmd }) end
  elseif it.kind == "term" then
    terminal(it.argv or { "bash", "-c", it.cmd })
  elseif it.kind == "launcher" then
    noctalia.runAsync({ "noctalia", "msg", "panel-open", "launcher", it.query })
  elseif it.kind == "bind" then
    return startCapture(it)
  elseif it.kind == "install" then
    if it.installed then
      say(it.title .. " is installed.")
      return render()
    end
    if it.src == "catalog" then
      if not string.match(it.name, "^[%w][%w._-]*$") then return end
      terminal({ cli, "app", "install", it.name })
    else
      if not safeName(it.src, it.name) then return end
      terminal({ cli, "package", "install", it.src, it.name })
    end
  elseif it.kind == "remove" then
    if it.src ~= "web" and not safeName(it.src, it.name) then return end
    if it.src == "web" and not string.match(it.name, "^[%w][%w._-]*$") then return end
    terminal({ cli, "package", "remove", it.src, it.name })
  else
    return
  end
  close()
end

local function back()
  local level = table.remove(stack)
  if not level then return end
  filter, sel, top = "", level.sel or 1, level.top or 1
  found, due = {}, nil
  say(nil)
  reseed()
  refresh()
end

local function startOver()
  stack, filter, sel, top, found, due = {}, "", 1, 1, {}, nil
  say(nil)
  reseed()
  refresh()
end

function onKey(chord, pressed)
  if not pressed or capture then return end
  if chord == "Down" then
    if #shown > 0 then sel = sel % #shown + 1 end
    refresh()
  elseif chord == "Up" then
    if #shown > 0 then sel = (sel - 2) % #shown + 1 end
    refresh()
  elseif chord == "Return" then
    activate(shown[sel])
  elseif chord == "BackSpace" then
    if filter ~= "" then
      local n = utf8.len(filter) or #filter
      filter = n > 1 and string.sub(filter, 1, (utf8.offset(filter, n) or #filter) - 1) or ""
      sel, top = 1, 1
      reseed()
      searchPackages()
      refresh()
    else
      back()
    end
  elseif chord == "ctrl+r" then
    startOver()
  end
end

local function onFilter(text)
  if capture then
    reseed()
    return render()
  end
  if text == filter then return end
  filter = text
  sel, top = 1, 1
  say(nil)
  searchPackages()
  refresh()
end

-- The words for Return, in the footer.
local function action(it)
  if not it then return "open" end
  local k = it.kind
  if k == "app" then return "launch" end
  if k == "bind" then return "edit binding" end
  if k == "install" then return it.installed and "installed" or "install in terminal" end
  if k == "remove" then return "remove in terminal" end
  if k == "term" then return "run in terminal" end
  if k == "run" then return "run" end
  return "open"
end

local function hitsFor(it, f)
  if f == "" then return nil end
  return match.positions(f, it.title)
end

-- How much a title may take before what's on its right, so a long one ends
-- in "…" instead of running into it (Geist Mono's advance is 0.6 em: 8.4px at
-- 14px, 7.2px at 12px).
local function chars(s) return utf8.len(s or "") or #(s or "") end
local function rightWidth(it, descMax)
  if capture and capture == it then return 18 * 7.2 + 10 end
  local w = 0
  if it.kind == "bind" then
    for part in string.gmatch(it.keys or "", "[^+]+") do w += chars(noctalia.string.trim(part)) * 6.6 + 18 end
  elseif it.desc and it.desc ~= "" then
    w += math.min(chars(it.desc) * 7.2, descMax) + 10
  end
  if it.badge and not lv() then w += chars(it.badge) * 6.9 + 26 end
  if it.tag then w += chars(it.tag) * 6.3 + 24 end
  return w
end
local function fit(title, room)
  local max = math.floor(room / 8.4)
  if chars(title) <= max then return title end
  if max < 2 then return "…" end
  return string.sub(title, 1, (utf8.offset(title, max) or (#title + 1)) - 1) .. "…"
end

-- One row: marker, glyph (top level), title (matched letters lit), then the
-- description, or the key caps, badge or source tag on the right.
local function row(entry, idx, selected, f)
  local p = look.p
  local it = entry.item
  local kids = {}
  table.insert(kids, look.label("▸", 14, selected and p.amber or "#00000000", { key = "m", width = 14 }))
  if not lv() then
    local glyph = entry.root and entry.root.glyph or it.glyph or "·"
    table.insert(kids, look.row({ key = "g", width = 18, justify = "center", align = "center" }, { look.label(glyph, 14, p.amber) }))
  end
  local descMax = it.tag and 200 or 240
  local pre = entry.root and (entry.root.title .. " › ") or ""
  local room = WIDTH - 2 - 12 - 24 - 24 - (lv() and 0 or 28) - rightWidth(it, descMax) - 10 - chars(pre) * 8.4
  local shownTitle = fit(it.title, room)
  local title = {}
  if pre ~= "" then
    table.insert(title, look.runs({ { text = pre, hit = false } }, 14, p.dim, "pre"))
  end
  table.insert(title, look.runs(match.runs(shownTitle, hitsFor({ title = shownTitle }, f)), 14, selected and p.amberLight or p.text, "title"))
  table.insert(kids, look.row({ key = "t", flexGrow = 1, gap = 0, align = "center" }, title))
  if capture and capture == it then
    table.insert(kids, look.label("press the new keys", 12, p.amber, { key = "d" }))
  elseif it.kind == "bind" then
    table.insert(kids, look.caps(it.keys, "c"))
  elseif it.desc and it.desc ~= "" then
    table.insert(kids, look.label(it.desc, 12, p.dim, { key = "d", maxWidth = descMax }))
  end
  if it.title == "Update" and not lv() and it.badge then table.insert(kids, look.badge(it.badge, "b")) end
  if it.tag then table.insert(kids, look.tag(it.tag, "x")) end
  return look.row({
    key = "slot" .. (idx - top + 1), height = 40, paddingH = 12, gap = 10, align = "center", radius = 6,
    fill = selected and p.selected or "#00000000", border = selected and p.ring or "#00000000", borderWidth = 1,
    onClick = function()
      sel = idx
      reseed()
      activate(shown[idx])
    end,
  }, kids)
end

render = function()
  local p = look.p
  local level = lv()
  local f = string.lower(trim(filter))

  -- The input line: ❯, the level's chip, the text and caret, the count.
  local line = { ui.glyph({ key = "prompt", name = "chevron-right", size = 18, color = p.amber }) }
  if level then
    local names = {}
    for _, l in ipairs(stack) do table.insert(names, string.lower(l.item.title)) end
    table.insert(line, look.row({ key = "chip", height = 24, paddingH = 8, gap = 6, radius = 5, fill = p.chip, align = "center" }, {
      look.label(table.concat(names, " › "), 13, p.amberLight),
      look.label("›", 13, p.amber),
    }))
  end
  local text = {}
  if filter ~= "" then table.insert(text, look.label(filter, 16, p.text, { key = "typed", fontWeight = "medium" })) end
  if not capture then table.insert(text, look.box({ key = "caret", width = 2, height = 19, fill = p.amberLight })) end
  if filter == "" then
    table.insert(text, look.label(capture and "" or (level and "filter" or "type to filter…"), 16, p.faint, { key = "hint", fontWeight = "medium" }))
  end
  table.insert(line, look.row({ key = "text", flexGrow = 1, gap = 1, align = "center" }, text))
  table.insert(line, ui.input({ key = "filter" .. inputRev, value = filter, focus = true, frameVisible = false,
    opacity = 0, width = 1, height = 20, onChange = onFilter }))
  table.insert(line, look.label(countText, 11.5, p.dim, { key = "count" }))

  local rows = {}
  for i = top, math.min(#shown, top + ROWS - 1) do
    table.insert(rows, row(shown[i], i, i == sel, f))
  end
  if #shown == 0 then
    local empty = "nothing here"
    if level and level.loading then empty = "loading…"
    elseif f ~= "" then empty = (level and level.item.gen == "install") and "searching…" or "no matches" end
    table.insert(rows, look.row({ key = "empty", height = 40, paddingH = 38, align = "center" }, { look.label(empty, 13, p.dim) }))
  end

  local frame = {
    -- The top-edge highlight: a 1px line inside the border.
    look.row({ key = "highlight", height = 1, paddingH = math.max(0, p.radius - 2) }, { look.box({ width = 0, height = 1, flexGrow = 1, fill = p.highlight }) }),
    look.row({ key = "line", height = 51, paddingH = 16, gap = 10, align = "center" }, line),
    look.box({ key = "under", width = 0, height = 1, fill = p.inputLine }),
    look.col({ key = "list", padding = 6, gap = 1 }, rows),
  }
  if message then
    table.insert(frame, look.row({ key = "message", paddingH = 18, paddingV = 6 }, {
      look.label(message, 12, messageError and p.coral or p.muted, { maxLines = 2 }),
    }))
  end
  table.insert(frame, look.box({ key = "divider", width = 0, height = 1, fill = p.divider }))
  local hints
  if capture then
    hints = { look.hint("esc", "cancel", "esc") }
  else
    hints = { look.hint("↵", action(shown[sel] and shown[sel].item), "enter"), look.hint("ctrl r", "start over", "reset") }
    if level then table.insert(hints, look.hint({ glyph = "backspace" }, "back", "back")) end
    table.insert(hints, ui.spacer({ key = "space", flexGrow = 1 }))
    table.insert(hints, look.hint("esc", "close", "esc"))
  end
  table.insert(frame, look.row({ key = "footer", paddingH = 14, paddingV = 8, gap = 14, align = "center" }, hints))

  panel.render(look.col({ gap = 0, width = WIDTH, flexGrow = 1 }, {
    look.box({ key = "above", height = topGap, fill = "#00000000", onClick = close }),
    look.col({ key = "menu", fill = p.fill, border = p.border, borderWidth = 1, radius = p.radius, padding = 1, gap = 0 }, frame),
    look.box({ key = "below", flexGrow = 1, fill = "#00000000", onClick = close }),
  }))
end

-- Where the menu starts: near the top third of the screen, as drawn in the
-- design (170px down a 900px screen); the panel itself opens under the bar.
local function gap()
  local h = 900
  for _, o in ipairs(noctalia.outputs() or {}) do
    if o.focused then h = o.height / math.max(o.scale or 1, 1) end
  end
  return math.max(0, math.floor(h * 0.19) - 46)
end

local function badge()
  local n = items.updatesWaiting()
  for _, r in ipairs(roots) do
    if r.title == "Update" then r.badge = n and (n .. " ready") or nil end
  end
end

-- Context: a path to open at ("Keybinds", "Setup › Displays").
function onOpen(context)
  isOpen = true
  look.load()
  items.forget()
  roots = items.build()
  badge()
  stack, filter, sel, top, found = {}, "", 1, 1, {}
  capture = nil
  cache = { installed = cache.installed }
  say(nil)
  reseed()
  topGap = gap()
  context = trim(context)
  if context ~= "" then
    local path = {}
    for part in string.gmatch(context, "[^›]+") do
      part = trim(part)
      if part ~= "" then table.insert(path, part) end
    end
    navigate(path)
  end
  refresh()
  -- Read the apps, bindings and installed packages again, so new ones show.
  apps.refresh(function()
    for _, l in ipairs(stack) do
      if l.item.gen == "apps" then items.generated("apps", cache, function(list) l.list = list end) end
    end
    if isOpen then refresh() end
  end)
  items.loadBinds(cache, function() if isOpen and not lv() and filter ~= "" then refresh() end end)
  items.loadInstalled(cache, function() if isOpen then refresh() end end)
end

function onClose()
  isOpen = false
  if capture then
    capture = nil
    noctalia.runAsync({ cli, "keys", "capture", "stop" })
  end
end

-- State for the VM test (vm/test-install): `noctalia msg plugin
-- <id>/utilities:menu all dump` writes what the menu shows to the runtime
-- directory. Matched letters are in [brackets].
local function dump()
  local rows = {}
  local f = string.lower(trim(filter))
  for i = top, math.min(#shown, top + ROWS - 1) do
    local e = shown[i]
    local marked = {}
    for _, r in ipairs(match.runs(e.item.title, hitsFor(e.item, f))) do
      table.insert(marked, r.hit and ("[" .. r.text .. "]") or r.text)
    end
    local extra = e.item.badge or e.item.tag or (e.item.kind == "bind" and e.item.keys) or nil
    table.insert(rows, (e.root and (e.root.title .. " › ") or "") .. table.concat(marked) .. (extra and (" · " .. extra) or ""))
  end
  local path = {}
  for _, l in ipairs(stack) do table.insert(path, l.item.title) end
  local dir = noctalia.getenv("XDG_RUNTIME_DIR")
  if not dir or dir == "" then return end
  noctalia.writeFile(dir .. "/" .. cli .. "-menu.json", noctalia.json.encode({
    open = isOpen, path = path, filter = filter, count = countText, rows = rows, selected = sel - top + 1,
    capture = capture and capture.title or "", message = message or "", gap = topGap,
  }))
end

function onIpc(event, payload)
  if event == "captured" then
    if not capture then return end
    local it = capture
    capture = nil
    if payload == "cancel" or payload == "" then
      say(nil)
      return render()
    end
    say("…")
    render()
    noctalia.runAsync({ cli, "keys", "set", it.chord, payload }, function(result)
      local out = trim(result.exitCode == 0 and result.stdout or result.stderr)
      say((string.gsub(out, "^" .. cli .. ": ", "")), result.exitCode ~= 0)
      items.loadBinds(cache, function()
        for _, l in ipairs(stack) do
          if l.item.gen == "keys" then l.list = cache.binds end
        end
        if isOpen then refresh() end
      end)
    end)
  elseif event == "dump" then
    dump()
  end
end
