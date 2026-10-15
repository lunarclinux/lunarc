--!nonstrict
-- Matching for the menu (menu-panel.luau): how well the filter matches a
-- label, and which of the label's characters to light up.
local M = {}

local function lower(s) return string.lower(s or "") end

-- Does the text contain filter (lower case) where a word starts?
local function atWord(t, f)
  local i = 1
  while true do
    local a = string.find(t, f, i, true)
    if not a then return nil end
    if a == 1 or not string.match(string.sub(t, a - 1, a - 1), "[%w]") then return a end
    i = a + 1
  end
end

-- Byte positions of the filter's characters in text, for highlighting: one
-- run where the text contains it (preferring a word start), else the
-- characters in order; nil when they aren't all there.
function M.positions(f, text)
  local t = lower(text)
  if f == "" then return {} end
  local a = atWord(t, f) or string.find(t, f, 1, true)
  local pos = {}
  if a then
    for i = a, a + #f - 1 do pos[i] = true end
    return pos
  end
  if string.find(f, "[\128-\255]") then return nil end
  local j = 1
  for k = 1, #f do
    local c = string.sub(f, k, k)
    if c ~= " " then
      local b = string.find(t, c, j, true)
      if not b then return nil end
      pos[b] = true
      j = b + 1
    end
  end
  return pos
end

-- A label split into runs: { { text, hit }, … }.
function M.runs(text, pos)
  local out, cur, hit = {}, {}, nil
  for i = 1, #text do
    local h = pos and pos[i] == true or false
    if hit ~= nil and h ~= hit then
      table.insert(out, { text = table.concat(cur), hit = hit })
      cur = {}
    end
    hit = h
    table.insert(cur, string.sub(text, i, i))
  end
  if #cur > 0 then table.insert(out, { text = table.concat(cur), hit = hit }) end
  return out
end

-- How well filter matches a title (and its description); nil for no match.
-- On the scale of the app search (apps.luau): a title containing the text is
-- 3000 + 5 × the fuzzy score, more where it starts; a word of the
-- description 1500+; a looser match of the title 1200+.
function M.score(f, title, desc)
  if f == "" then return 0 end
  local tl = lower(title)
  local fz = noctalia.fuzzyScore(f, tl)
  if fz and string.find(tl, f, 1, true) then
    local s = 3000 + fz * 5
    if string.sub(tl, 1, #f) == f then s += 500 elseif atWord(tl, f) then s += 250 end
    return s
  end
  if #f >= 3 and desc and desc ~= "" and atWord(lower(desc), f) then
    return 1500 + (noctalia.fuzzyScore(f, lower(desc)) or 0) * 2
  end
  if fz and M.positions(f, title) then return 1200 + fz end
  return nil
end

return M
