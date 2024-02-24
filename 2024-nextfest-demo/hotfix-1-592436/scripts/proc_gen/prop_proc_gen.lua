local lume = require "util.lume"
local enum = require "util.enum"
local mapgen = require "defs.mapgen"
local bossdata = require "defs.monsters.bossdata"
local biomes = require "defs.biomes"

return {
	Region = enum(lume(biomes.regions):keys():result()),
	Zone = enum {
		"near_bg",
		"bg",
		"distant_bg",
		"near_underlay",
		"underlay",
		"near_fg",
		"fg",
		"distant_fg",
		"fg_side",
		"near_side",
		"side",
		"distant_side",
		"center",
		"middle",
		"inside_perimeter",
		"front_perimeter",
		"back_corner",
		"exit",
		"non_walkable_fg",
		"non_walkable_bg",
		"side_inlet",
		"side_inlet_two"
	},
	Role = enum {
		"decor",
		"decor_large",
		"spawner",
		"stationary_creature",
		"trap",
		"destructible",
		"stationary_creature_spawner",
		"trap_spawner",
		"destructible_spawner",
		"light",
		"shadow",
		"room_loot_spawner",
		"npc_spawner",
		"room_decor",
		"group",
		"miniboss_spawner",
		"ceiling_decor"
	},
	Boss = enum(lume(bossdata.boss):keys():result()),
	Tile = enum { "path", "rough" },
	RoomType = mapgen.roomtypes.RoomType,
	Tag = enum { "unique", "required", "centered", "tall" },
}
