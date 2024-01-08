--[[
This file implements a Prefab whose instantiation functions as a proxy for a
creature spawner in edit mode, but manifests as a dungeon-specific creature
spawner in game.
]]

local SpawnUtil = require "util.spawnutil"
local Lume = require "util.lume"
local CreatureSpawner = require "prefabs.customscript.creaturespawner"
local PropAutogenData = require "prefabs.prop_autogen_data"
local SceneGen = require "components.scenegen"

local FALLBACK_PREVIEW_PHANTOM = "spawner_plant1"
assert(PropAutogenData[FALLBACK_PREVIEW_PHANTOM],
	"Fallback preview phantom for spawner_creature does not exist: "..FALLBACK_PREVIEW_PHANTOM)

local function RandomSpawner(creature_spawner_type)
	if TheSceneGen then
		local creature_spawners = TheSceneGen.components.scenegen.creature_spawners[creature_spawner_type]
		if creature_spawners and next(creature_spawners) then
			return TheWorld.prop_rng:PickValue(creature_spawners) -- @chrisp #proc_rng
		end
	else
		dbassert(TheDungeon:GetDungeonMap():IsDebugMap(), "Without TheSceneGen, this spawner will not spawn anything.")
	end
end

-- After we have loaded, we have access to our creature_spawner_type so we can spawn our representation.
local function OnPostLoadWorld(inst)
	local creature_spawner = RandomSpawner(inst.components.prop.script_args.creature_spawner_type)
	local creature_spawner_prop = creature_spawner and creature_spawner.prop
	if TheDungeon:GetDungeonMap():IsDebugMap() then
		-- Set up a phantom preview
		local preview_phantom = creature_spawner_prop or FALLBACK_PREVIEW_PHANTOM
		TheSim:LoadPrefabs({ preview_phantom })
		SpawnUtil.SetupPreviewPhantom(inst, preview_phantom)
	elseif creature_spawner_prop then
		local prop_prefab = Prefabs[creature_spawner_prop]
		if prop_prefab and prop_prefab:CanBeSpawned() then
			-- Replace the spawner proxy by an actual prop realization.
			local prop = SpawnPrefab(creature_spawner_prop)

			if creature_spawner.sole_occupant_radius then
				SceneGen.ClaimSoleOccupancy(prop, creature_spawner.sole_occupant_radius)
			end

			-- Inherit the creaturespawner script.
			prop.components.prop.script = inst.components.prop.script
			prop.components.prop.script_args = inst.components.prop.script_args

			-- Inherit the transform of the proxy.
			prop.Transform:SetPosition(inst.Transform:GetWorldPosition())

			if creature_spawner.color then
				prop.components.prop:ShiftHsb(creature_spawner.color)
			end
		end
		-- Discard the proxy.
		SpawnUtil.FlagForRemoval(inst)
	end
end

local function Ui(inst, ui)
	local creature_spawner_types = Lume(CreatureSpawner.default.GetSpawnerTypes())
		:map(function(spawner_type)
			return spawner_type:match("spawner_(%a+)")
		end)
		:result()
	local changed, new_creature_spawner_type = ui:ComboAsString(
		"Creature Spawner Type",
		inst.components.prop.script_args.creature_spawner_type,
		creature_spawner_types
	)
	if changed then
		inst.components.prop.script_args.creature_spawner_type = new_creature_spawner_type
	end
	return changed
end

local function Construct()
	local inst = CreateEntity()
	inst.OnPostLoadWorld = OnPostLoadWorld
	-- TODO: This should use LivePropEdit via customscript instead of setting
	-- up its own EditEditable.
	inst.EditEditable = Ui

	inst.entity:AddTransform()
	inst:AddComponent("prop")

	-- Initialize as a creature spawner.
	inst.components.prop.script = "creaturespawner"
	inst.components.prop.script_args = inst.components.prop.script_args or {}
	inst.components.prop.script_args.creature_spawner_type =
		inst.components.prop.script_args.creature_spawner_type
		or "battlefield"

	if TheDungeon:GetDungeonMap():IsDebugMap() then
		SpawnUtil.MakeEditable(inst, "square")
		inst.AnimState:SetScale(1, 1)
		inst.AnimState:SetMultColor(table.unpack(UICOLORS.BLUE))
	end

	return inst
end

return Prefab("spawner_creature", Construct)
