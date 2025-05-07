local MetaProgress = require "defs.metaprogression.metaprogress"

local Power = require"defs.powers"
local Consumable = require"defs.consumable"

function MetaProgress.AddCoreRelationship(id, data)
	data.show_in_ui = false

	data.base_exp = { 1, 50, 100, 200, 300 }
	data.exp_growth = 0

	-- possible things a CoreRelationship can define

	-- should I show up in a dungeon?
	-- data.dungeon_spawner_fn

	-- should I show up in your village?
	-- data.village_spawner_fn

	MetaProgress.AddProgression(MetaProgress.Slots.RELATIONSHIP_CORE, id, data)
end

MetaProgress.AddProgressionType("RELATIONSHIP_CORE")

-- Village NPCs

MetaProgress.AddCoreRelationship("npc_scout",
{
	dungeon_spawner_fn = function(progress, inst)
		-- if TheWorld:GetDungeonProgress() == 0 then
		-- 	return NPC_SPAWN_PRIORITY.DEFAULT
		-- end

		return NPC_SPAWN_PRIORITY.NONE
	end,
})

MetaProgress.AddCoreRelationship("npc_refiner",
{
	dungeon_spawner_fn = function(progress, inst)
		return NPC_SPAWN_PRIORITY.NONE
	end,
})

MetaProgress.AddCoreRelationship("npc_armorsmith",
{
	dungeon_spawner_fn = function(progress, inst)
		-- if TheWorld:GetDungeonProgress() > 0 then
		-- 	return NPC_SPAWN_PRIORITY.DEFAULT
		-- end

		return NPC_SPAWN_PRIORITY.NONE
	end,
})

MetaProgress.AddCoreRelationship("npc_blacksmith",
{
	dungeon_spawner_fn = function(progress, inst)
		return NPC_SPAWN_PRIORITY.NONE
	end,
})

MetaProgress.AddCoreRelationship("npc_apothecary",
{
	dungeon_spawner_fn = function(progress, inst)
		return NPC_SPAWN_PRIORITY.NONE
	end,

	village_spawner_fn = function(progress, inst)
		return false
	end,
})

MetaProgress.AddCoreRelationship("npc_cook",
{
	dungeon_spawner_fn = function(progress, inst)
		return NPC_SPAWN_PRIORITY.NONE
	end,

	village_spawner_fn = function(progress, inst)
		return false
	end,
})

-- Dungeon NPCs

MetaProgress.AddCoreRelationship("npc_specialeventhost", {})

MetaProgress.AddCoreRelationship("npc_potionmaker_dungeon", {})

MetaProgress.AddCoreRelationship("npc_konjurist", {})
