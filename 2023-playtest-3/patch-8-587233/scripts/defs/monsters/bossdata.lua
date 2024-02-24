local bossdef = {
	boss = {
		megatreemon =
		{
			id = "megatreemon",
			name = STRINGS.NAMES.megatreemon,
			icon = "research_widget_megatreemon.tex",
			icon_locked = "research_widget_megatreemon.tex",
			icon_scale = 0.5,
		},

		rotwood =
		{
			id = "rotwood",
			name = STRINGS.NAMES.rotwood,
			icon = "rotwood.tex",
			icon_locked = "rotwood_locked.tex",
			icon_scale = 0.5,
		},

		bandicoot =
		{
			id = "bandicoot",
			name = STRINGS.NAMES.bandicoot,
			icon = "research_widget_bandicoot.tex",
			icon_locked = "research_widget_bandicoot.tex",
			icon_scale = 0.5,
		},

		thatcher =
		{
			id = "thatcher",
			name = STRINGS.NAMES.thatcher,
			icon = "thatcher.tex",
			icon_locked = "thatcher_locked.tex",
			icon_scale = 0.5,
		},

		bonejaw =
		{
			id = "bonejaw",
			name = STRINGS.NAMES.bonejaw,
			icon = "bonejaw.tex",
			icon_locked = "bonejaw_locked.tex",
			icon_scale = 0.5,
		},

		owlitzer =
		{
			id = "owlitzer",
			name = STRINGS.NAMES.owlitzer,
			icon = "research_widget_owlitzer.tex",
			icon_locked = "research_widget_owlitzer.tex",
			icon_scale = 0.5,
		},

		--[[
		arak =
		{
			id = "arak",
			name = STRINGS.NAMES.arak,
			icon = "arak.tex",
			icon_scale = 0.5,
		},

		quetz =
		{
			id = "quetz",
			name = STRINGS.NAMES.quetz,
			icon = "quetz.tex",
			icon_scale = 0.5,
		},
		]]

		yammo =
		{
			id = "yammo",
			name = STRINGS.NAMES.yammo,
			icon = "research_widget_yammo.tex",
			icon_locked = "research_widget_yammo.tex",
			icon_scale = 0.5,
		},

		floracrane =
		{
			id = "floracrane",
			name = STRINGS.NAMES.floracrane,
			icon = "research_widget_floracrane.tex",
			icon_locked = "research_widget_floracrane.tex",
			icon_scale = 0.5,
		},

		gourdo =
		{
			id = "gourdo",
			name = STRINGS.NAMES.gourdo,
			icon = "research_widget_gourdo.tex",
			icon_locked = "research_widget_gourdo.tex",
			icon_scale = 0.5,
		},

		groak =
		{
			id = "groak",
			name = STRINGS.NAMES.groak,
			icon = "research_widget_groak.tex",
			icon_locked = "research_widget_groak.tex",
			icon_scale = 0.5,
		},

	},
}

-- Returns a picture for the input boss entity.
function bossdef:GetBossPortrait(inst)
	local b = self.boss[inst.prefab]
	if b then
		return "images/icons_boss/"..b.icon
	end
	error(("WARNING: Missing bossdata for prefab '%s' inst '%s'"):format(inst.prefab, tostring(inst)))
	return "images/global/square.tex"
end


-- Returns a stylized icon for the input boss entity.
function bossdef:GetBossStylizedIcon(inst)
	local b = self.boss[inst.prefab]
	if b then
		return ("images/ui_ftf_pausescreen/ic_boss_%s.tex"):format(b.id)
	end
	error(("WARNING: Missing bossdata for prefab '%s' inst '%s'"):format(inst.prefab, tostring(inst)))
	return "images/global/square.tex"
end



local monster_pictures = require "gen.atlas.monster_pictures"

---
-- Returns the path for a boss' icon based on its id.
-- If locked is true, the icon returned will be a silhouette of that boss
function bossdef:GetBossIcon(id, locked)
	local picture_id = string.format("map_screen_%s", id)
	if monster_pictures.tex[picture_id] then
		return monster_pictures.tex[picture_id]
	end
	-- error(("WARNING: Missing bossdata for id '%s'"):format(id))
	return "images/global/square.tex"
end

function bossdef:GetBossIDs()
	local ids = {}
	for _,boss in pairs(self.boss) do
		table.insert(ids, boss.id)
	end
	return ids
end

return bossdef
