local WEBCOLORS = require "webcolors"
local fmodtable = require "defs.sound.fmodtable"
local kassert = require "util.kassert"
local krandom = require "util.krandom"
local lume = require "util.lume"
local mapgen = require "defs.mapgen"
local PropAutogenData = require "prefabs.prop_autogen_data"
require "strings.strings"
require "util.tableutil"


local biomes = {
	starting_region = nil,
	regions = {},
	locations = {},
	location_type = {
		DUNGEON = 1,
		TOWN = 2,
		SHRINE = 3,
		GATEWAY = 4,
	}
}
biomes.location_type_names = lume.invert(biomes.location_type)

local type_to_lock_icon = {
	[biomes.location_type.DUNGEON] = "images/mapicons_ftf/dungeon.tex",
	[biomes.location_type.TOWN]    = "images/mapicons_ftf/town.tex",
	[biomes.location_type.SHRINE]  = "images/mapicons_ftf/shrine.tex",
	[biomes.location_type.GATEWAY] = "images/mapicons_ftf/gateway.tex",
}

local default_room_audio = {
	-- See mapgen.lua for roomtype names.
	food = fmodtable.Event.mus_CookingLevel_LP,
	potion = fmodtable.Event.mus_SnakeOil_LP,
	powerupgrade = fmodtable.Event.mus_KonjineerLevel_LP,
	ranger = fmodtable.Event.mus_MinigameLevel_LP,
	wanderer = fmodtable.Event.mus_MysteriousWandererLevel_LP, -- we should find a way to properly nil this out
	market = fmodtable.Event.mus_Market_LP
}

local function Debug_GetRandomRoomWorld(biome_location, roomtype)
	if not biome_location.monsters or not biome_location.monsters.bosses then
		return
	end
	local world_prefix = krandom.PickValue(biome_location.worlds)
	local boss = krandom.PickValue(biome_location.monsters.bosses)
	if roomtype == "boss" then
		return ("%s_%s_boss_s"):format(world_prefix, boss)
	elseif roomtype == "hype" then
		return ("%s_%s_hype_ns"):format(world_prefix, boss)
	elseif roomtype == "miniboss" then
		return ("%s_miniboss_nesw"):format(world_prefix)
	elseif roomtype == "market" then
		return ("%s_market_nesw"):format(world_prefix)
	end
	return ("%s_arena_nesw"):format(world_prefix)
end

local function CollectPrefabs(biome_location)
	local prefabs = {}
	if biome_location.gate_prefab_fmt then
		for _,cardinal in ipairs(mapgen.Cardinal:Ordered()) do
			local dir = cardinal:sub(1,1)
			table.insert(prefabs, biome_location.gate_prefab_fmt:format(dir))
		end
	end
	if biome_location.monsters then
		for monster,list in pairs(biome_location.monsters) do
			table.appendarrays(prefabs, list)
		end
		for _,monster in ipairs(biome_location.monsters.mobs) do
			table.insert(prefabs, monster .."_elite")
		end
	end
	if biome_location.traps then
		for trap, list in pairs(biome_location.traps) do
			table.appendarrays(prefabs, list)
		end
	end
	return prefabs
end

-- Map of region_id to dependencies.
local function BuildDeps()
	local regions = {}
	local function CreateAnimAsset(anim)
		local bankfile_fmt = "anim/%s.zip"
		return Asset("ANIM", bankfile_fmt:format(anim))
	end
	for id,biome_location in pairs(biomes.locations) do
		local region = regions[biome_location.region_id] or {}
		region[id] = {
			prefabs = biome_location:CollectPrefabs(),
			tile_bank = CreateAnimAsset(biome_location:GetDungeonMapBgTileBankName())
		}
		regions[biome_location.region_id] = region
	end
	return regions
end

function biomes.GetLocationDeps(region, location)
	-- PERF(MEMORY): Could be more restrictive to avoid depending on all bosses
	-- a biome supports (startingforest_thatcher_boss_s doesn't need megatree).
	if not biomes.deps then
		-- Lazily build deps since they're accessed for every world on lua
		-- restart.
		biomes.deps = BuildDeps()
	end
	local region_deps = biomes.deps[region]
	return region_deps and region_deps[location]
end

local function GetDungeonMapBgTileBankName(biome_location)
	local bankname_fmt = "dungeon_map_tiles_%s"
	-- TODO @design #sedament_tundra - dungeon_map_tiles_ HACK
	-- HACK @chrisp #tundra - can't just duplicate the tiles .zip assets as they
	-- have identifying information written into their .bins and duplication is
	-- actively prevented based on those ids
	-- Thus, just map to forest tiles until we get our own assets...
	local HACK_region = biome_location.region_id == "tundra"
		and "forest"
		or biome_location.region_id
	return bankname_fmt:format(HACK_region)

	-- TODO @design #sedament_tundra - dungeon_map_tiles_
	-- restore this and delete the hack
	-- return bankname_fmt:format(biome_location.region_id)
end

-- The region where the player starts.
function biomes.SetStartingRegion(regionId)
	biomes.starting_region = regionId
end

function biomes.AddRegion(id, data)
	local regions = biomes.regions

	assert(STRINGS.BIOMES[id], "Missing STRINGS.BIOMES string set for ["..id.."]")
	local def = {
		id = id,
		-- DO NOT point directly to strings. Always point to tables so they can get fixed up by localization.
		pretty = STRINGS.BIOMES[id],
		title_ornament = data.title_ornament,
		icon = data.title_ornament,
		starting_location = nil,
		locations = {},
	}

	regions[id] = def
	return def
end

-- The location the player starts at when at this region
function biomes.SetStartingLocation(regionId, locationId)
	biomes.regions[regionId].starting_location = locationId
end

local function GetRegion_ForLocation(biome_location)
	return biomes.regions[biome_location.region_id]
end

local function GetSceneGen_ForLocation(biome_location, assert_on_failure)
	local scenegenutil = require "prefabs.scenegenutil"
	return scenegenutil.GetSceneGenForBiomeLocation(biome_location.region_id, biome_location.id, assert_on_failure)
end

local TRAP_ROLE_REMAPPER = {
	spike = "spike",
	exploding = "exploding",
	bomb = "exploding",
	zucco = "zucco",
	bananapeel = "bananapeel",
	spores = "spores",
	spore = "spores",
	acid = "acid",
	stalactite = "stalactite",
	wind = "wind",
	thorn = "thorn",
}

local function ChooseTrap(location_def, role, tier, count)
	local candidates = location_def.traps[TRAP_ROLE_REMAPPER[role]]
	if not next(candidates) then
		return nil, 0
	end
	candidates = lume(candidates)
		:filter(function(trap)
			local trap_prop = PropAutogenData[trap]
			return trap_prop.script_args.tier <= tier
		end)
		:result()
	local i = TheWorld.prop_rng:Integer(#candidates)  -- @chrisp #proc_rng
	local trap = candidates[i]
	return trap, count -- TODO @chrisp #scenegen - handle count more like monstertiers.ConvertRoleToMonster?
end

function biomes.AddLocation(regionId, locationId, locationType, args)
	assert(locationType)
	assert(args)

	assert(STRINGS.LOCATIONS[locationId], "Missing STRINGS.LOCATIONS string set for ["..locationId.."]")
	-- Assemble location data
	local locationDef = {
		id = locationId,
		region_id = regionId,
		type = locationType,
		pretty = STRINGS.LOCATIONS[locationId],
		has_combat = locationType == biomes.location_type.DUNGEON,
		gate_prefab_fmt = "forest_gate_root_%s", -- default
		CollectPrefabs = CollectPrefabs,
		Debug_GetRandomRoomWorld = Debug_GetRandomRoomWorld,
		GetDungeonMapBgTileBankName = GetDungeonMapBgTileBankName,
		GetRegion = GetRegion_ForLocation,
		GetSceneGen = GetSceneGen_ForLocation,
		ChooseTrap = ChooseTrap,
	}

	-- Add the locked icon based on the type of location
	locationDef.icon_locked = type_to_lock_icon[locationType]

	-- Merge other data into def.
	locationDef = lume.overlaymaps(locationDef, args)

	-- Overlay colors separately so they're all optional.
	local default_colors = {
		locator_tint = WEBCOLORS.WHITE, -- no add color because it's already white
		frame_tint = WEBCOLORS.WHITE,
		frame_add  = WEBCOLORS.TRANSPARENT_BLACK,
		bg_tint = WEBCOLORS.WHITE,
		bg_add  = WEBCOLORS.TRANSPARENT_BLACK,
		room_tint = WEBCOLORS.WHITE,
		room_add  = WEBCOLORS.TRANSPARENT_BLACK,
	}
	locationDef.map_colors = lume.overlaymaps({}, default_colors, locationDef.map_colors)

	locationDef.room_audio = locationDef.room_audio or default_room_audio

	if locationDef.monsters then
		-- Easy tag-like lookup: if biome_location.monsters.allowed_mobs[prefab] then spawn(prefab) end
		locationDef.monsters.allowed_mobs = lume.invert(locationDef.monsters.mobs)
	end

	-- See unlocktracker
	locationDef.required_unlocks = locationDef.required_unlocks or {}
	table.insert(locationDef.required_unlocks, locationId) -- always require self

	-- Add the location to the correct region
	biomes.regions[regionId].locations[locationId] = locationDef
	assert(biomes.locations[locationId] == nil, "Location name already in use.")
	biomes.locations[locationId] = locationDef

	return locationDef
end

function biomes.IsValid(regionId, locationId)
	return regionId and biomes.regions[regionId]
		and locationId and biomes.regions[regionId].locations[locationId]
end

function biomes.BiomeLocationPicker(ui, selected_id)
	local location_ids = lume(biomes.locations)
		:keys()
		:sort()
		:result()
	local changed
	changed, selected_id = ui:ComboAsString("Location", selected_id or location_ids[1], location_ids)
	if not selected_id then
		selected_id = TheDungeon:GetDungeonMap():GetBiomeLocation().id
	end
	ui:SameLineWithSpace()
	if ui:Button(ui.icon.playback_step_fwd, ui.icon.width) then
		local idx = (lume.find(location_ids, selected_id) or 0) + 1
		selected_id = location_ids[idx] or location_ids[1]
		changed = true
	end
	local location = biomes.locations[selected_id]
	return changed, selected_id, location
end
function biomes._BiomeLocationPicker(ui, selected_id)
	-- No changed version, like imgui_helpers.
	local changed, new_id, location = biomes.BiomeLocationPicker(ui, selected_id)
	return new_id, location
end


--- Regions are major maps, with their own background and multiple locations within them
biomes.AddRegion("town",
		{
			title_ornament = "images/ui_dungeonmap/title_ornament_forest.tex",
		})

biomes.AddRegion("forest",
		{
			title_ornament = "images/ui_dungeonmap/title_ornament_forest.tex",
		})
biomes.AddRegion("swamp",
		{
			title_ornament = "images/ui_dungeonmap/title_ornament_swamp.tex",
		})
biomes.AddRegion("desert",
		{
			title_ornament = "images/ui_dungeonmap/title_ornament_forest.tex",
		})
biomes.AddRegion("coral",
		{
			title_ornament = "images/ui_dungeonmap/title_ornament_forest.tex",
		})
biomes.AddRegion("tundra",
		{
			title_ornament = "images/ui_dungeonmap/title_ornament_forest.tex",
		})
biomes.AddRegion("volcano",
		{
			title_ornament = "images/ui_dungeonmap/title_ornament_forest.tex",
		})
biomes.AddRegion("crystal",
		{
			title_ornament = "images/ui_dungeonmap/title_ornament_forest.tex",
		})

biomes.SetStartingRegion("town")

--- Locations are visitable areas within a region. They can be dungeons, towns, temples, etc

--- SURRLAND
biomes.AddLocation("town", "brundle", biomes.location_type.TOWN,
{
	icon = "images/mapicons_ftf/town_start.tex",
	description_icon = "images/mapicons_ftf/desc_town_start.tex",
	map_x = 0.474,
	map_y = 0.359,
	worlds = { "home", },
	ambient_bed_sound = fmodtable.Event.amb_Town_LP,
	ambient_music = fmodtable.Event.mus_Town_LP
})

biomes.AddLocation("forest", "treemon_forest", biomes.location_type.DUNGEON,
{
	icon = "images/ui_ftf_pausescreen/ic_boss_megatreemon.tex",
	alternate_mapgens = { "treemon_forest_tutorial1", "treemon_forest_tutorial2", "treemon_forest_tutorial3" },
	-- treemon_forest_tutorial1: Tutorialized mapgen slowly introducing difficulty. Active until see miniboss.
	-- treemon_forest_tutorial2: Power spawns in Room 1. Start to open up randomness a bit. Guarantee small_token after miniboss. Active til after get small_token.
	-- treemon_forest_tutorial3: Introduce more difficulty, introduce Skills, introduce Mystery Rooms, add random small_tokens and large_tokens, stop guaranteeing small_token after miniboss.
	-- After that, go to normal mapgen. Don't guarantee small_token anymore so it can't be farmed.

	description_icon = "images/ui_ftf_pausescreen/ic_boss_megatreemon.tex",
	map_colors = {
		locator_tint = RGB(255, 235, 152, 105),
		frame_tint = RGB(176, 154, 108),
		frame_add  = RGB(0, 0, 0),
		bg_tint = RGB(220, 205, 160),
		bg_add  = RGB(7, 5, 0),
		room_tint = RGB(220, 205, 160),
		room_add  = RGB(7, 5, 0),
	},
	map_x = 0.271,
	map_y = 0.495,
	monsters =
	{
		bosses = { "megatreemon" },
		minibosses = { "yammo" },
		mobs = {
			"blarmadillo",
			"cabbageroll",
			"cabbagerolls2",
			"treemon",
			"yammo",
			"zucco",
			"beets",
		},
	},
	traps={
		exploding={ "trap_bomb_pinecone",},
		spike={ "trap_weed_spikes",},
	},
	required_unlocks = nil, -- { "scout_tent" }, -- no unlocks for completed_vertical_slice_jan2022
	worlds = { "startingforest", },
	gate_prefab_fmt = "forest_gate_root_%s",
	ambient_bed_sound = fmodtable.Event.amb_StartingForest_LP,
	ambient_birds_sound = fmodtable.Event.amb_StartingForest_Birds_LP,
	ambient_music = fmodtable.Event.mus_StartingForest_LP,
	miniboss_music_intro = fmodtable.Event.mus_StartingForest_Miniboss_Intro,
	miniboss_music_LP = fmodtable.Event.mus_StartingForest_Miniboss_LP,
	miniboss_music_victory = fmodtable.Event.mus_StartingForest_Miniboss_Victory,
})

biomes.AddLocation("forest", "owlitzer_forest", biomes.location_type.DUNGEON,
{
	icon = "images/ui_ftf_pausescreen/ic_boss_owlitzer.tex",
	alternate_mapgens = { },
	description_icon = "images/ui_ftf_pausescreen/ic_boss_owlitzer.tex",
	map_colors = {
		locator_tint = RGB(179, 255, 152, 125),
		frame_tint = RGB(80, 137, 130),
		frame_add  = RGB(0, 3, 7),
		bg_tint = RGB(114, 180, 170),
		bg_add  = RGB(0, 7, 3),
		room_tint = RGB(114, 180, 170),
		room_add  = RGB(0, 7, 3),
	},
	map_x = 0.090,
	map_y = 0.580,
	monsters =
	{
		bosses = { "owlitzer" },
		minibosses = { "gourdo" },
		mobs = {
			"cabbageroll",
			"cabbagerolls",
			"cabbagerolls2",
			"battoad",
			"gourdo",
			"zucco",
			"gnarlic",
			"windmon",
		},
	},
	traps = {
		wind = { "trap_windtotem",},
		spike = { "trap_weed_spikes",},
		thorn = {"trap_weed_thorns",}
	},
	required_unlocks = nil, -- { "scout_tent" }, -- no unlocks for completed_vertical_slice_jan2022
	worlds = { "owlforest", },
	gate_prefab_fmt = "forest_gate_root_%s",
	ambient_bed_sound =  fmodtable.Event.amb_StartingForest_LP,
	ambient_music = fmodtable.Event.mus_OwlitzerForest_LP,
	miniboss_music_intro = fmodtable.Event.mus_OwlitzerForest_Miniboss_Intro,
	miniboss_music_LP = fmodtable.Event.mus_OwlitzerForest_Miniboss_LP,
	miniboss_music_victory = fmodtable.Event.mus_OwlitzerForest_Miniboss_Victory,
})

biomes.AddLocation("tundra", "sedament_tundra", biomes.location_type.DUNGEON,
{
	icon = "images/ui_ftf_pausescreen/ic_boss_owlitzer.tex",
	alternate_mapgens = {},
	description_icon = "images/ui_ftf_pausescreen/ic_boss_owlitzer.tex",
	map_colors = {
		frame_tint = RGB(255, 255, 255),
		frame_add  = RGB(0, 0, 0),
		bg_tint    = RGB(240, 200, 240),
		bg_add     = RGB(0, 0, 0),
		room_tint  = RGB(240, 200, 240),
		room_add   = RGB(0, 0, 0),
	},
	map_x = 0.511,
	map_y = 0.741,
	monsters =
	{
		bosses = { "owlitzer" },
		minibosses = { "gourdo" },
		mobs = {
			"blarmadillo",
			"cabbageroll",
			"cabbagerolls",
			"cabbagerolls2",
			"battoad",
			"gourdo",
			"yammo",
			"zucco",
			"gnarlic",
		},
	},
	traps = {
		exploding = { "trap_bomb_pinecone", },
		spike = { "trap_weed_spikes", },
	},
	required_unlocks = nil, -- { "scout_tent" }, -- no unlocks for completed_vertical_slice_jan2022
	worlds = { "startingforest", },
	gate_prefab_fmt = "forest_gate_root_%s",
	ambient_bed_sound = fmodtable.Event.amb_StartingForest_LP,
	ambient_music = fmodtable.Event.mus_OwlitzerForest_LP,
		miniboss_music_intro = fmodtable.Event.mus_OwlitzerForest_Miniboss_Intro,
		miniboss_music_LP = fmodtable.Event.mus_OwlitzerForest_Miniboss_LP,
		miniboss_music_victory = fmodtable.Event.mus_OwlitzerForest_Miniboss_Victory,
})

biomes.AddLocation("swamp", "kanft_swamp", biomes.location_type.DUNGEON,
{
	icon = "images/ui_ftf_pausescreen/ic_boss_bandicoot.tex",
	description_icon = "images/ui_ftf_pausescreen/ic_boss_bandicoot.tex",
	map_colors = {
		locator_tint = RGB(49, 172, 255, 150),
		frame_tint = RGB(136, 146, 255),
		frame_add  = RGB(15, 0, 0),
		bg_tint = RGB(150, 141, 224),
		bg_add  = RGB(7, 0, 3),
		room_tint = RGB(150, 141, 224),
		room_add  = RGB(7, 0, 3),
	},
	map_x = 0.187,
	map_y = 0.179,
	monsters =
	{
		bosses = { "bandicoot" },
		minibosses = { "groak" },
		mobs = {
			"mothball",
			"mothball_teen",
			"mothball_spawner",
			"bulbug",
			"mossquito",
			"groak",
			"eyev",
			"sporemon",

			"swamp_stalactite",
			"swamp_stalagmite",
		},
	},
	traps={
		acid={ "trap_acid",},
		spores={
			"trap_spores_confused",
			"trap_spores_damage",
			"trap_spores_groak",
			"trap_spores_heal",
			"trap_spores_juggernaut",
			"trap_spores_smallify",
		},
		stalactite={ "trap_stalactite",},
	},
	required_unlocks = {},
	worlds = { "swamp", },
	gate_prefab_fmt = "bandiforest_gate_%s",
	ambient_bed_sound = fmodtable.Event.amb_Swamp_LP,
	ambient_music = fmodtable.Event.mus_Swamp_LP,
	miniboss_music_intro = fmodtable.Event.mus_Swamp_Miniboss_Intro,
	miniboss_music_LP = fmodtable.Event.mus_Swamp_Miniboss_LP,
	miniboss_music_victory = fmodtable.Event.mus_Swamp_Miniboss_Victory,
})

biomes.AddLocation("swamp", "thatcher_swamp", biomes.location_type.DUNGEON,
{
	icon = "images/ui_ftf_pausescreen/ic_boss_thatcher.tex",
	description_icon = "images/ui_ftf_pausescreen/ic_boss_thatcher.tex",
	map_colors = {
		locator_tint = RGB(145, 241, 135, 150),
		frame_tint = RGB(124, 163, 105),
		frame_add  = RGB(15, 0, 0),
		bg_tint = RGB(188, 204, 153),
		bg_add  = RGB(7, 5, 3),
		room_tint = RGB(188, 204, 153),
		room_add  = RGB(7, 5, 3),
	},
	map_x = 0.287,
	map_y = 0.100,
	monsters =
	{
		bosses = { "thatcher" },
		minibosses = { "floracrane" },
		mobs = {
			"mothball",
			"mothball_teen",
			"mothball_spawner",
			"bulbug",
			"floracrane",
			"woworm",
			"totolili",
			"slowpoke",
			"swarmy",

			"swamp_stalactite",
			"swamp_stalagmite",
		},
	},
	traps={
		acid={ "trap_acid",},
		stalactite={ "trap_stalactite",},
	},
	required_unlocks = {},
	worlds = { "acidswamp", },
	gate_prefab_fmt = "thatforest_gate_%s",
	ambient_bed_sound = fmodtable.Event.amb_Swamp_LP,
	ambient_music = fmodtable.Event.mus_Swamp_LP,
	miniboss_music_intro = fmodtable.Event.mus_ThatcherSwamp_Miniboss_Intro,
	miniboss_music_LP = fmodtable.Event.mus_ThatcherSwamp_Miniboss_LP,
	miniboss_music_victory = fmodtable.Event.mus_ThatcherSwamp_Miniboss_Victory,
})

-- biomes.AddLocation("tundra", "sedament_tundra", biomes.location_type.DUNGEON,
-- {
-- 	icon = "images/ui_ftf_pausescreen/ic_boss_bandicoot.tex",
-- 	description_icon = "images/ui_ftf_pausescreen/ic_boss_bandicoot.tex",
-- 	map_colors = {
-- 		locator_tint = RGB(49, 172, 255, 150),
-- 		frame_tint = RGB(136, 146, 255),
-- 		frame_add  = RGB(15, 0, 0),
-- 		bg_tint = RGB(150, 141, 224),
-- 		bg_add  = RGB(7, 0, 3),
-- 		room_tint = RGB(150, 141, 224),
-- 		room_add  = RGB(7, 0, 3),
-- 	},
-- 	map_x = 2500 / 3840,
-- 	map_y = 900 / 2610,
-- 	monsters =
-- 	{
-- 		bosses = { "thatcher" },
-- 		minibosses = { "groak" }, --floracrane -- TEMP for network test, to allow network testing more easily without disturbing rest of experience
-- 		mobs = {
-- 			"cabbageroll",
-- 		},
-- 	},
-- 	traps={
-- 	},
-- 	required_unlocks = {},
-- 	worlds = { "swamp", },
-- 	gate_prefab_fmt = "thatforest_gate_%s",
-- 	ambient_bed_sound = fmodtable.Event.amb_Swamp_LP, --TODO: LUCA
-- 	ambient_music = fmodtable.Event.mus_Swamp_LP, --TODO: LUCA
-- })

-- biomes.AddLocation("surrland", "caelden", biomes.location_type.DUNGEON,
-- {
-- 	icon = "images/mapicons_ftf/dungeon_cave.tex",
-- 	description_icon = "images/mapicons_ftf/desc_dungeon_cave.tex",
-- 	map_x = 0.20,
-- 	map_y = 0.70,
-- 	materials = {},
-- 	required_unlocks = { "DEBUG_LOCKED" },
-- 	worlds = { "startingforest", },
-- })
-- biomes.AddLocation("surrland", "erton", biomes.location_type.DUNGEON,
-- {
-- 	icon = "images/mapicons_ftf/dungeon_mountains.tex",
-- 	description_icon = "images/mapicons_ftf/desc_dungeon_mountains.tex",
-- 	map_x = 0.60,
-- 	map_y = 0.17,
-- 	materials = {},
-- 	required_unlocks = { "DEBUG_LOCKED" },
-- 	worlds = { "startingforest", },
-- })
-- biomes.AddLocation("surrland", "holbon_outskirts", biomes.location_type.DUNGEON,
-- {
-- 	icon = "images/mapicons_ftf/dungeon_forest.tex",
-- 	description_icon = "images/mapicons_ftf/desc_dungeon_forest.tex",
-- 	map_x = 0.03,
-- 	map_y = 0.40,
-- 	recommended_power = 10,
-- 	items = {},
-- 	materials = {},
-- 	required_unlocks = { "DEBUG_LOCKED" },
-- 	worlds = { "startingforest", },
-- 	ambient_bed_sound = fmodtable.Event.amb_StartingForest,
-- 	ambient_music = fmodtable.Event.mus_startingForest_LP,
-- })

biomes.SetStartingLocation("town", "brundle")

-- Validation
local required_keys = {
	all = {
		'description_icon', -- bg behind description
		'icon',             -- map icon
		'id',
		'map_x',
		'map_y',
		'pretty',           -- table from STRINGS
		'region_id',
		'type',             -- biomes.location_type
		'worlds',           -- arena from world_autogen_data with _nesw suffix removed
	},
	[biomes.location_type.DUNGEON] = {
		'monsters',
		'traps'
	},
}
for loc_name,loc in pairs(biomes.locations) do
	for _,key in ipairs(required_keys.all) do
		kassert.assert_fmt(loc[key], "Required key '%s' missing from location '%s' in region '%s'.", key, loc_name, loc.region_id)
	end
	for _,key in ipairs(required_keys[loc.type] or {}) do
		kassert.assert_fmt(loc[key], "Required key '%s' missing from %s location '%s' in region '%s'.", key, biomes.location_type_names[loc.type], loc_name, loc.region_id)
	end
	mapgen.validate.all_keys_are_roomtype(loc.room_audio)
end

return biomes
