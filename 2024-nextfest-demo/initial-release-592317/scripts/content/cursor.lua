local Enum = require "util.enum"
local lume = require "util.lume"


local cursor = {}

local cursor_spec = {
	-- style_fmt: path within data. Requires all sizes.
	-- hot: hotx, hoty (where the clicking registers).
	pointer = { style_fmt = "cursors/pointer_%s.bmp", hot = { 2, 2 }, },
	interact = { style_fmt = "cursors/interact_%s.bmp", hot = { 3, 2 }, },

	-- From GLN
	--~ point_up        = { style_fmt = "cursors/cursor_up.bmp", hot = { 26, 4 }, },
	--~ point_down      = { style_fmt = "cursors/cursor_down.bmp", hot = { 26, 48 }, },
	--~ point_left      = { style_fmt = "cursors/cursor_left.bmp", hot = { 4, 26 }, },
	--~ point_right     = { style_fmt = "cursors/cursor_right.bmp", hot = { 48, 26 }, },
	--~ point_downleft  = { style_fmt = "cursors/cursor_down_left.bmp", hot = { 12, 38 }, },
	--~ point_downright = { style_fmt = "cursors/cursor_down_right.bmp", hot = { 44, 44 }, },
	--~ point_upleft    = { style_fmt = "cursors/cursor_up_left.bmp", hot = { 12, 12 }, },
	--~ point_upright   = { style_fmt = "cursors/cursor_up_right.bmp", hot = { 38, 16 }, },
}

-- List the names as styles to make TheFrontEnd:SetCursor(cursor.Style.s.pointer) easy.
local styles = lume.keys(cursor_spec)
cursor.Style = Enum(styles)

cursor.Size = Enum{
	"SYSTEM",
	"small",
	"normal",
	"large",
}

local system_cursors = {
	-- See kiln_sdl.cpp
	normal = "SYSTEM_ARROW",
	interact = "SYSTEM_HAND",
}

local cursor_list = {}
for style,data in pairs(cursor_spec) do
	cursor_list[style] = {}
	for _,size in ipairs(cursor.Size:Ordered()) do
		cursor_list[style][size] = {
			name = data.style_fmt:format(size),
			hot = data.hot,
		}
	end
	-- OS cursor is setup as a size instead of a style because that's what's
	-- configurable. System cursor offers accessiblity features provided by the
	-- OS, even if it's less pretty.
	cursor_list[style].SYSTEM.name = system_cursors[style] or system_cursors.normal
end

-- Customize per-size hot coords here (get these from artists):
cursor_list.interact.large.hot = {8, 5}
cursor_list.interact.normal.hot = {3, 2}
cursor_list.interact.small.hot = {1, 1}
cursor_list.pointer.large.hot = {5, 7}
cursor_list.pointer.normal.hot = {2, 2}
cursor_list.pointer.small.hot = {1, 1}



-- Call TheFrontEnd:SetCursor instead.
function cursor.SetCursor(style, size)
	TheLog.ch.FrontEnd:print("SetCursor", style, size)
	local c = cursor_list[style][size]
	return TheSim:SetCursor(c.name)
end

function cursor.CreateAllCursors()
	assert(RUN_GLOBAL_INIT)
	for style,data in pairs(cursor_list) do
		for size,c in pairs(data) do
			if size ~= cursor.Size.s.SYSTEM then
				TheSim:CreateCursor(c.name, c.name, table.unpack(c.hot))
			end
		end
	end
end

function cursor.GetCursorScaleRelativeToStandard()
	-- FTF uses huge cursors that are scaled up in source art and not dynamically.
	return 2
end

return cursor
