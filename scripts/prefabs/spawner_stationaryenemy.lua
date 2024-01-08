local spawnutil = require "util.spawnutil"
local creaturespawner = require "prefabs.customscript.creaturespawner"
local monstertiers = require "defs.monstertiers"
local krandom = require "util.krandom"
local biomes = require "defs.biomes"
local SceneGen = require "components.scenegen"

local assets = spawnutil.GetEditableAssets()

local FALLBACK_PREVIEW_PHANTOM = "treemon"

local function SpawnStationaryEnemy(inst, prefab)
	local ent = spawnutil.Spawn(inst, prefab)
	return ent
end

local function OnPostLoadWorld(inst)
	TheWorld.components.spawncoordinator:AddStationarySpawner(inst)
end

local function GetPreviewStationaryEnemy()
	if TheSceneGen then
		return monstertiers.ConvertRoleToMonster(
			biomes.locations[TheSceneGen.components.scenegen.dungeon],
			"turret",
			1,
			1,
			krandom.CreateGenerator()
		)
	end
end
local function fn()
	local inst = spawnutil.CreateBasicSpawner()

	inst.components.snaptogrid:SetDimensions(2, 2, -1)
	inst.SpawnStationaryEnemy = SpawnStationaryEnemy

	creaturespawner.InitSpawner(inst)

	if TheDungeon:GetDungeonMap():IsDebugMap() then
		spawnutil.MakeEditable(inst, "square")
		inst.AnimState:SetScale(1, 1)
		inst.AnimState:SetMultColor(table.unpack(UICOLORS.PURPLE))
		local preview_phantom = GetPreviewStationaryEnemy() or FALLBACK_PREVIEW_PHANTOM
		TheSim:LoadPrefabs({ preview_phantom })
		spawnutil.SetupPreviewPhantom(inst, preview_phantom)
	else
		inst.OnPostLoadWorld = OnPostLoadWorld
	end

	return inst
end

return Prefab("spawner_stationaryenemy", fn, assets)
