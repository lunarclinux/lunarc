--!nonstrict
-- Bluetooth through BlueZ (bluetoothctl): the controller, whether it's on,
-- and the paired devices (connected or not, with a battery level when the
-- device reports one). Used by the bar's Bluetooth segment and its popover.
-- Turning it on and off goes through Noctalia (rfkill included), as the
-- quick setting does.
local M = {}

local function lines(text)
  local out = {}
  for line in string.gmatch(text or "", "[^\n]+") do table.insert(out, line) end
  return out
end

-- cb({ present = bool, on = bool, connected = <count> })
function M.status(cb)
  noctalia.runAsync({ "bluetoothctl", "show" }, function(r)
    local out = r.stdout or ""
    local st = { present = string.find(out, "^Controller ") ~= nil or string.find(out, "\nController ") ~= nil,
      on = string.find(out, "Powered: yes") ~= nil, connected = 0 }
    if not st.present or not st.on then cb(st) return end
    noctalia.runAsync({ "bluetoothctl", "devices", "Connected" }, function(r2)
      for _, l in ipairs(lines(r2.stdout)) do
        if string.match(l, "^Device ") then st.connected += 1 end
      end
      cb(st)
    end)
  end)
end

-- cb(list of { mac, name, connected, battery = <percent or nil>, kind = <icon name> })
function M.devices(cb)
  noctalia.runAsync({ "bluetoothctl", "devices", "Paired" }, function(r)
    local devs = {}
    for _, l in ipairs(lines(r.stdout)) do
      local mac, name = string.match(l, "^Device (%x%x:%x%x:%x%x:%x%x:%x%x:%x%x) (.*)$")
      if mac then table.insert(devs, { mac = mac, name = name }) end
    end
    local left = #devs
    if left == 0 then cb(devs) return end
    for _, d in ipairs(devs) do
      noctalia.runAsync({ "bluetoothctl", "info", d.mac }, function(ri)
        local info = ri.stdout or ""
        d.connected = string.find(info, "Connected: yes") ~= nil
        d.battery = tonumber(string.match(info, "Battery Percentage: 0x%x+ %((%d+)%)") or "")
        d.kind = string.match(info, "Icon: (%S+)") or ""
        left -= 1
        if left == 0 then
          table.sort(devs, function(a, b)
            if a.connected ~= b.connected then return a.connected end
            return string.lower(a.name) < string.lower(b.name)
          end)
          cb(devs)
        end
      end)
    end
  end)
end

-- The glyph for a device, from the icon name BlueZ gives it.
function M.deviceGlyph(kind)
  if string.find(kind, "audio") or string.find(kind, "headset") or string.find(kind, "headphone") then return "headphones" end
  if string.find(kind, "keyboard") then return "keyboard" end
  if string.find(kind, "mouse") or string.find(kind, "pointing") then return "mouse" end
  if string.find(kind, "phone") then return "device-mobile" end
  if string.find(kind, "gaming") or string.find(kind, "joystick") then return "device-gamepad-2" end
  return "bluetooth"
end

function M.glyph(st)
  if not st or not st.on then return "bluetooth-off" end
  if st.connected > 0 then return "bluetooth-connected" end
  return "bluetooth"
end

return M
