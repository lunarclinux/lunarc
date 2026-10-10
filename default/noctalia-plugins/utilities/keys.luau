--!nonstrict
-- Keyboard shortcuts, searchable: every Hyprland binding that has a
-- description, from `@DISTRO_ID@ keys --list --tsv`.
local cli = "@DISTRO_ID@"
local binds = nil

local function results(text)
  local out = {}
  for i, b in ipairs(binds or {}) do
    local score = 1000 - i
    if text ~= "" then score = noctalia.fuzzyScore(text, b.desc .. " " .. b.keys) end
    if score then
      table.insert(out, { id = tostring(i), title = b.desc, subtitle = b.keys, glyph = "keyboard", score = score })
    end
  end
  return out
end

function onQuery(text)
  -- Reload when the list opens, so newly added bindings show up.
  if text == "" then binds = nil end
  if binds then
    launcher.setResults(text, results(text))
    return
  end
  launcher.setResults(text, { { id = "loading", title = "Loading shortcuts…", glyph = "loader" } })
  noctalia.runAsync({ cli, "keys", "--list", "--tsv" }, function(result)
    binds = {}
    for _, line in ipairs(string.split(result.stdout or "", "\n")) do
      local parts = string.split(line, "\t")
      if #parts >= 2 then table.insert(binds, { keys = parts[1], desc = parts[2] }) end
    end
    launcher.setResults(text, results(text))
  end)
end

function onActivate(_id)
  -- Showing the list is the point; selecting closes the launcher.
end
