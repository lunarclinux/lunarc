--!nonstrict
-- The network popover, under the bar's network segment, in the stats
-- popover's look (pop.luau): the active connection (device, address,
-- gateway), the Wi-Fi switch and the networks in range. A saved or open
-- network connects from here; a new one with a password opens Noctalia's
-- network panel, which asks for it (this popover never handles passwords).
local pop = require("./pop.luau")
local net = require("./network-common.luau")

local st = nil
local details = {}
local wifis = {}
local saved = {}
local busy = nil

local function changed() noctalia.state.set("network-changed", noctalia.nowMs()) end

local function run(args, after)
  noctalia.runAsync(args, function(r) if after then after(r) end end)
end

local function loadDetails()
  details = {}
  if not st or not st.device then render() return end
  run({ "nmcli", "-t", "-f", "IP4.ADDRESS,IP4.GATEWAY,IP4.DNS,GENERAL.HWADDR", "device", "show", st.device }, function(r)
    for line in string.gmatch(r.stdout or "", "[^\n]+") do
      local key, value = string.match(line, "^([^:]+):(.*)$")
      if key and value and value ~= "" then
        key = string.gsub(key, "%[%d+%]", "")
        if not details[key] then details[key] = value end
      end
    end
    render()
  end)
end

local function loadWifi()
  wifis = {}
  if not st or not st.radio then render() return end
  run({ "nmcli", "-t", "-f", "NAME,TYPE", "connection", "show" }, function(r)
    saved = {}
    for line in string.gmatch(r.stdout or "", "[^\n]+") do
      local f = net.fields(line)
      if f[2] == "802-11-wireless" then saved[f[1]] = true end
    end
    run({ "nmcli", "-t", "-f", "IN-USE,SSID,SIGNAL,SECURITY", "device", "wifi", "list", "--rescan", "no" }, function(r2)
      local seen = {}
      for line in string.gmatch(r2.stdout or "", "[^\n]+") do
        local f = net.fields(line)
        local ssid = f[2] or ""
        if ssid ~= "" and not seen[ssid] then
          seen[ssid] = true
          table.insert(wifis, { inUse = f[1] == "*", ssid = ssid, signal = tonumber(f[3]) or 0,
            secured = (f[4] or "") ~= "" and f[4] ~= "--" })
        end
      end
      table.sort(wifis, function(a, b)
        if a.inUse ~= b.inUse then return a.inUse end
        return a.signal > b.signal
      end)
      render()
    end)
  end)
end

local function reload()
  net.status(function(s) st = s; loadDetails(); loadWifi() end)
end

local function connect(w)
  if w.inUse then return end
  if w.secured and not saved[w.ssid] then
    -- A password is needed: Noctalia's network panel asks for it.
    run({ "noctalia", "msg", "panel-toggle", "control-center", "network" })
    return
  end
  busy = w.ssid; render()
  local args = saved[w.ssid] and { "nmcli", "connection", "up", "id", w.ssid } or { "nmcli", "device", "wifi", "connect", w.ssid }
  run(args, function(_r) busy = nil; changed(); reload() end)
end

function render()
  if not st then
    panel.render(pop.panel({ pop.header("NETWORK", nil), pop.muted("Reading…") }))
    return
  end
  local children = {}
  local title = st.kind == "ethernet" and "wired" or (st.kind == "wifi" and "Wi-Fi" or "offline")
  table.insert(children, pop.header("NETWORK", title))
  if st.kind then
    table.insert(children, ui.column({ gap = 8 }, {
      pop.row("NAME", st.connection or "–"),
      pop.row("DEVICE", st.device or "–"),
      pop.row("ADDRESS", details["IP4.ADDRESS"] or "–"),
      pop.row("GATEWAY", details["IP4.GATEWAY"] or "–"),
      pop.row("DNS", details["IP4.DNS"] or "–"),
    }))
  else
    table.insert(children, pop.muted("Not connected."))
  end

  if st.wifiDevice then
    table.insert(children, ui.row({ gap = 10, align = "center" }, {
      ui.column({ flexGrow = 1 }, { pop.header("WI-FI", st.radio and (#wifis .. " in range") or "off") }),
      ui.toggle({ key = "wifi-radio", checked = st.radio, onChange = function(_v)
        run({ "nmcli", "radio", "wifi", st.radio and "off" or "on" }, function(_r) changed(); reload() end)
        st.radio = not st.radio; render()
      end }),
    }))
    if st.radio then
      local rows = {}
      for i, w in ipairs(wifis) do
        if i > 8 then break end
        table.insert(rows, ui.row({ key = "w-" .. w.ssid, gap = 10, align = "center", onClick = function() connect(w) end }, {
          ui.glyph({ name = w.secured and "lock" or "wifi", size = 13, color = w.inUse and "primary" or "on_surface_variant" }),
          pop.text(w.ssid, { flexGrow = 1, maxLines = 1, color = w.inUse and "primary" or "on_surface" }),
          ui.progress({ progress = w.signal / 100, fill = w.inUse and "primary" or "primary/0.55", track = "on_surface/0.1",
            radius = 1, height = 3, width = 56 }),
          pop.muted(busy == w.ssid and "…" or (w.inUse and "on" or (saved[w.ssid] and "saved" or "")), { width = 40, textAlign = "end", fontSize = 11 }),
        }))
      end
      if #rows == 0 then table.insert(rows, pop.muted("No networks found.")) end
      table.insert(children, ui.column({ gap = 9 }, rows))
    end
  end

  table.insert(children, ui.row({ justify = "end", gap = 4 }, {
    st.radio and pop.button("Rescan", function()
      run({ "nmcli", "device", "wifi", "rescan" }, function(_r) loadWifi() end)
    end, { glyph = "refresh" }) or ui.spacer({}),
    pop.button("More settings", function()
      run({ "noctalia", "msg", "panel-toggle", "control-center", "network" })
    end, { glyph = "settings" }),
  }))
  panel.render(pop.panel(children, { gap = 14 }))
end

function onOpen(_context)
  noctalia.state.set("network-open", true)
  noctalia.setUpdateInterval(5000)
  reload()
  render()
end

function update() reload() end

function onClose() noctalia.state.set("network-open", false) end
function onExit(_signal, _reason) noctalia.state.set("network-open", false) end
