--!nonstrict
-- The network through NetworkManager (nmcli): the active connection, the
-- Wi-Fi radio and the networks in range. Used by the bar's network segment
-- and its popover.
local M = {}

local function lines(text)
  local out = {}
  for line in string.gmatch(text or "", "[^\n]+") do table.insert(out, line) end
  return out
end

-- nmcli -t escapes ":" inside fields as "\:".
local function fields(line)
  local out, cur, i = {}, "", 1
  while i <= #line do
    local ch = string.sub(line, i, i)
    if ch == "\\" and i < #line then cur ..= string.sub(line, i + 1, i + 1); i += 2
    elseif ch == ":" then table.insert(out, cur); cur = ""; i += 1
    else cur ..= ch; i += 1 end
  end
  table.insert(out, cur)
  return out
end
M.fields = fields

-- cb({ kind = "ethernet"|"wifi"|nil, device, connection, radio = true|false })
function M.status(cb)
  noctalia.runAsync({ "nmcli", "-t", "-f", "DEVICE,TYPE,STATE,CONNECTION", "device" }, function(r)
    local st = { radio = false }
    for _, l in ipairs(lines(r.stdout)) do
      local f = fields(l)
      if (f[2] == "ethernet" or f[2] == "wifi") and f[3] == "connected" and not st.kind then
        st.kind, st.device, st.connection = f[2], f[1], f[4]
      end
      if f[2] == "wifi" then st.wifiDevice = f[1] end
    end
    noctalia.runAsync({ "nmcli", "radio", "wifi" }, function(r2)
      st.radio = noctalia.string.trim(r2.stdout or "") == "enabled"
      cb(st)
    end)
  end)
end

function M.glyph(st)
  if not st or not st.kind then return st and st.radio and "wifi-question" or "wifi-off" end
  if st.kind == "ethernet" then return "network" end
  return "wifi"
end

return M
