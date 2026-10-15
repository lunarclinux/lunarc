--!nonstrict
-- A 1px hairline between two of the bar's segments, where neither draws one.
local seg = require("./seg.luau")

barWidget.render(seg.divider())
