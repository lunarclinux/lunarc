--!nonstrict
-- The "reminders" quick setting in the bar's toggles (quick-items.luau, quick-widget.luau).
local w = require("./quick-widget.luau").new("reminders")
function onClick() w.click() end
function onRightClick() w.rightClick() end
function update() w.update() end
function onIpc(event, _payload) w.ipc(event) end
