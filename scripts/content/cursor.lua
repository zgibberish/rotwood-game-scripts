local lume = require "util.lume"


local cursor = {}

local cursor_list = {
	-- path, hotx, hoty (where the clicking registers)
	pointer = {"cursors/pointer.bmp", 2, 2},
	interact = {"cursors/interact.bmp", 18, 3},

	-- From GLN
	--~ point_up        = {"cursors/cursor_up.bmp", 26, 4},
	--~ point_down      = {"cursors/cursor_down.bmp", 26, 48},
	--~ point_left      = {"cursors/cursor_left.bmp", 4, 26},
	--~ point_right     = {"cursors/cursor_right.bmp", 48, 26},
	--~ point_downleft  = {"cursors/cursor_down_left.bmp", 12, 38},
	--~ point_downright = {"cursors/cursor_down_right.bmp", 44, 44},
	--~ point_upleft    = {"cursors/cursor_up_left.bmp", 12, 12},
	--~ point_upright   = {"cursors/cursor_up_right.bmp", 38, 16},
}

-- list the names as styles to make TheFrontEnd:SetCursor(cursor.style.pointer) easy.
cursor.style = lume.enumerate(cursor_list, function(k,v)
	return k
end)
cursor.style.SYSTEM = "SYSTEM" -- see kiln_sdl.cpp

function cursor.CreateAllCursors()
	assert(RUN_GLOBAL_INIT)
	for key,val in pairs(cursor_list) do
		TheSim:CreateCursor(key, table.unpack(val))
	end
end

function cursor.GetCursorScaleRelativeToStandard()
	-- FTF uses huge cursors that are scaled up in source art and not dynamically.
	return 2
end

return cursor
