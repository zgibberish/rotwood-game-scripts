local spawnutil = require "util.spawnutil"
local lume = require "util.lume"
local PropAutogenData = require "prefabs.prop_autogen_data"

local assets = spawnutil.GetEditableAssets()

local FALLBACK_PREVIEW_PHANTOM = "destructible_wood_shorty"
assert(PropAutogenData[FALLBACK_PREVIEW_PHANTOM],
	"Fallback preview phantom for spawner_propdestructible does not exist: "..FALLBACK_PREVIEW_PHANTOM)

local function SpawnPropDestructible(inst, prop)
	local ent = spawnutil.Spawn(inst, prop)
	return ent
end

local function OnPostLoadWorld(inst)
	-- If the placed spawner did not declare explicit destructibles...
	if not (inst.destructible_types and next(inst.destructible_types)) then
		-- ...then use the destructibles for this dungeon held in TheSceneGen.
		inst.destructible_types = TheSceneGen and TheSceneGen.components.scenegen:CollectDestructibles()
	end
	-- Only register the spawner if we have destructibles to spawn.
	if inst.destructible_types and next(inst.destructible_types) then
		TheWorld.components.spawncoordinator:AddPropDestructibleSpawner(inst, inst.destructible_types)
	end
end

local function LoadScriptArgs(inst, data)
	-- A placed spawner may explicitly state the destructibles that it may spawn.
	-- TODO @chrisp #scenegen - may want to allow level designers to edit likelihoods on spawner instances
	inst.destructible_types = lume(data.destructible_types)
		:map(function(destructible)
			return {
				prop = destructible,
				likelihood = 1
			}
		end)
		:result()
end

local function GetPreviewDestructible()
	if TheSceneGen then
		local destructibles = TheSceneGen.components.scenegen.destructibles
		if destructibles and next(destructibles) then
			return destructibles[1].prop
		end
	end
end

local function fn()
	local inst = spawnutil.CreateBasicSpawner()

	inst.components.snaptogrid:SetDimensions(4, 4, -1)
	inst.SpawnPropDestructible = SpawnPropDestructible
	inst.LoadScriptArgs = LoadScriptArgs; -- Assign this to handle loading of prop data from file

	if TheDungeon:GetDungeonMap():IsDebugMap() then
		spawnutil.MakeEditable(inst, "square")
		inst.AnimState:SetScale(1.5, 1.5)
		local preview_phantom = GetPreviewDestructible() or FALLBACK_PREVIEW_PHANTOM
		TheSim:LoadPrefabs({preview_phantom})
		spawnutil.SetupPreviewPhantom(inst, preview_phantom)
	else
		inst.OnPostLoadWorld = OnPostLoadWorld
	end

	return inst
end

return Prefab("spawner_propdestructible", fn, assets)
