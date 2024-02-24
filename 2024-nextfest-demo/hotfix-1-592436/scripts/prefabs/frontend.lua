local assets = {
	-- Assets used only in mainmenu.
	--
	-- If it's not used in mainmenu, see hud.lua
	-- TODO: Rename this file deps_frontend.lua and use GroupPrefab.


	--FE Music
	--Asset("SOUND", "sound/music_frontend.bank"),

	--From the Forge
	Asset("ATLAS", "images/bg_title.xml"),
	Asset("IMAGE", "images/bg_title.tex"),

	Asset("ATLAS", "images/ui_ftf.xml"),
	Asset("IMAGE", "images/ui_ftf.tex"),

	-- This file isn't being loaded in game, just on the title screen
}

return Prefab("frontend", function() end, assets)
