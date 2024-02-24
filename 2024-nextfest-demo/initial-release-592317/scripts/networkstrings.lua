
-- A list of manually entered strings that will be added to the string list for faster and more compact network syncing
local manual_str_list = {
	-- attack chain sources;
	"default",
	"attacker",
	"damage_to_attacker",
	"luck",
	"projectile",
	"water",

	-- generic attack types
	"light_attack",
	"heavy_attack",

	-- roombonusscreen:
	"health",
	"armour",
	"luck",
	"movespeed",
	"weapondamage",
	"focusdamage",
	"critchance",
	"critdamage",
	"drops",
	"skipFocus",
	"buttonFocus",
	"buttonPicked",
	"name",
	"slot",
	"rarity",
	"lucky",
	"currentskillID",
	"continueButtonFocus",
	"konjurButtonFocus",
	"confirmedChoice",

	-- runsummaryscreen:
		-- screen management
	"LOADING",
	"REWARDS",
	"SUMMARY",
	"DONE",
	"dynamic",
	"requested_page",
		--equipment
	"equipment",
	"equipped_weapon",
	"equipped_potion",
	"equipped_tonic",
	"equipped_food",
		-- stats
	"stats",
	"total_kills",
	"total_damage_done",
	"nemesis",
	"total_damage_taken",
	"total_deaths",
	"duration_millis",
	"duration_show_hours",
	"rooms_discovered",
		-- biome exploration
	"biome_exploration",
	"meta_level",
	"meta_exp",
	"meta_exp_max",
	"meta_reward_log",
	"reward",
	"reward_name",
		-- loot
	"loot",
	-- "name", but another exists above so this would be redundant
	"count",
	"bonus_loot",

	-- cinematic
	"roles",
	"subactors",
	"lead",

	-- particlesystemhelper
	"amount_mult",
	"scale_mult",

	-- worldmap / mystery result
	"selected_wanderer",
	"selected_ranger",

	-- weight
	"equipment_head",
	"equipment_body",
	"equipment_waist",
	"equipment_weapon",
}



function FindAllNetworkStrings()
	TheSim:AddKnownStrings(require("gen.allprefabs"))
	TheSim:AddKnownStrings(require("gen.eventslist"))
	TheSim:AddKnownStrings(require("gen.timerslist"))
	TheSim:AddKnownStrings(require("gen.sgnameslist"))

	-- Equipment:
	local Equipment = require("defs.equipment")
	local strings = {}

	for slotname, v in pairs(Equipment.Slots) do
		table.insert(strings, slotname);
	end

	for slotname, items in pairs(Equipment.Items) do
		for itemname, v in pairs(items) do
			table.insert(strings, itemname);
		end
	end

	local Cosmetic = require ("defs.cosmetics.cosmetics")
	for _, species in ipairs(Cosmetic.Species) do
		table.insert(strings, species)
	end

	for slot, collection in pairs(Cosmetic.Items) do
		for cosmetic_name, v in pairs(collection) do
			table.insert(strings, cosmetic_name)
		end
	end

	for bodypart, _ in pairs(Cosmetic.BodyPartGroups) do
		table.insert(strings, bodypart)
	end

	for color, _ in pairs(Cosmetic.ColorGroups) do
		table.insert(strings, color)
	end

	-- Add all fmod events:
	local fmod = require "defs.sound.fmodtable"
	for eventname, fulleventpath in pairs(fmod.Event) do	-- event names
		table.insert(strings, eventname);
		table.insert(strings, fulleventpath);
	end
	for paramname, fullparamname in pairs(fmod.LocalParameter) do	-- Local parameters
		table.insert(strings, paramname);
		table.insert(strings, fullparamname);
	end
	for paramname, fullparamname in pairs(fmod.GlobalParameter) do	-- Global parameters
		table.insert(strings, paramname);
		table.insert(strings, fullparamname);
	end

	-- Special case: All fx prefabs:
	local fx = require("prefabs/fx_autogen_data")
	for fxprefabname, v in pairs(fx) do	-- event names
		table.insert(strings, fxprefabname);
	end

	-- Special case: All particle fx param set names:
	local pfx = require("prefabs/particles_autogen_data")
	for pfxprefabname, v in pairs(pfx) do	-- event names
		table.insert(strings, pfxprefabname);
	end

	-- all power id / name values for powermanager
	local Power = require("defs.powers.power")
	for slot, items in pairs(Power.Items) do
		table.insert(strings, slot)
		for name, _def in pairs(items) do
			table.insert(strings, name)
		end
	end

	for k, v in pairs(Power.Types) do
		table.insert(strings, v)
	end

	for k, v in pairs(Power.Categories) do
		table.insert(strings, v)
	end

	for k, v in pairs(Power.Rarities.s) do
		table.insert(strings, v)
	end

	-- all player attack names like LIGHT_ATTACK_1, LIGHT_ATTACK_2, etc.
	for _weapon,names in pairs(STRINGS.PLAYER_ATTACKS) do
		-- likely duplicates for common ids but expecting them to get internally filtered
		for id,_desc in pairs(names) do
			table.insert(strings, id)
		end
	end

	-- all potion names for usetracker
	local potions = require("defs.potions")
	for _i,potion_data in ipairs(potions) do
		table.insert(strings, potion_data.name)
	end

	-- for items synced during gameplay (i.e. konjur)
	local Consumable = require("defs.consumable")
	for id,itemdef in pairs(Consumable.Items.MATERIALS) do
		if itemdef.tags["netserialize"] then
			table.insert(strings, id)
		end
	end

	-- special event room names
	local SpecialEventRooms = require("defs.specialeventrooms")
	for eventname,_def in pairs(SpecialEventRooms.Events) do
		table.insert(strings, eventname)
	end

	-- mapgen room types (i.e. mystery, monster, powerupgrade, etc.)
	local mapgen = require("defs.mapgen")
	for roomtype,_ in pairs(mapgen.roomtypes.RoomType) do
		table.insert(strings, roomtype)
	end

	-- VendingMachine ware_ids (equipment, dye, healing_fountain, etc.)
	local vending_machine_wares = require("defs.vendingmachine_wares")
	for ware_id, _ in pairs(vending_machine_wares) do
		table.insert(strings, ware_id)
	end

	-- Add the list of manually entered strings at the top of this file:
	for k, v in ipairs(manual_str_list) do
		table.insert(strings, v);
	end

	TheSim:AddKnownStrings(strings)
	TheSim:FinalizeStrings();

	-- Tags:
	local tags = require("gen.tagslist")	-- Add the list of known tags
	require("constants")
	for _,pwrtag in pairs(POWER_TAGS) do	-- Add all the power tags
		table.insert(tags, pwrtag)
	end
	
	local scenegen = require("components.scenegen")
	tags = table.appendarrays(tags, DecorTags)
	table.insert(tags, scenegen.ROOM_PARTICLE_SYSTEM_TAG)

--	print("*** BEGIN TAGS ***")
--	dumptable(tags)
--	print("*** END TAGS ***")
	TheSim:SetKnownTagNames(tags)	-- tags are saved as individual bits, so this can't easily be combined with the prefabs
end



if RUN_GLOBAL_INIT then
	FindAllNetworkStrings()
end
