local spawnutil = require "util.spawnutil"
local trapdata = require "prefabs.customscript.trap" -- This contains the list of trap types
local PropAutogenData = require "prefabs.prop_autogen_data"
local Biomes = require "defs.biomes"
local Lume = require "util.lume"
local KRandom = require "util.krandom"

local assets = spawnutil.GetEditableAssets()

local FALLBACK_PREVIEW_PHANTOM = "trap_weed_spikes"
assert(PropAutogenData[FALLBACK_PREVIEW_PHANTOM],
	"Fallback preview phantom for spawner_trap does not exist: "..FALLBACK_PREVIEW_PHANTOM)

local function SpawnTrap(inst, trap)
	local ent = spawnutil.Spawn(inst, trap)

	-- If a trap direction is defined at this spawner, set the facing of the trap to be spawned.
	if ent and inst.trap_directions then
		-- Choose a facing direction if multiple directions are defined.
		local keys = Lume.keys(inst.trap_directions)
		local facing = #keys > 0 and keys[math.random(1, #keys)] or FACING_RIGHT
		spawnutil.SetFacing(ent, facing)
	end

	return ent
end

local function OnPostLoadWorld(inst)
	TheWorld.components.spawncoordinator:AddTrapSpawner(inst, inst.trap_types)
end

local function GetPreviewTrap()
	if not TheSceneGen then
		return
	end

	local biome_location = Biomes.locations[TheSceneGen.components.scenegen.dungeon]

	-- Just return the first trap in the first category.
	local traps = {}
	for _, category in pairs(biome_location.traps) do
		traps = table.appendarrays(traps, Lume(category):values():result())
	end
	if next(traps) then
		traps = KRandom.Shuffle(traps)
		return traps[1]
	end
end

local function fn()
	local inst = spawnutil.CreateBasicSpawner()

	inst.components.snaptogrid:SetDimensions(1, 1, -1)
	inst.SpawnTrap = SpawnTrap

	trapdata.InitSpawner(inst)

	if TheDungeon:GetDungeonMap():IsDebugMap() then
		spawnutil.MakeEditable(inst, "square")
		inst.AnimState:SetScale(1.5, 1.5)

		local preview_phantom = GetPreviewTrap() or FALLBACK_PREVIEW_PHANTOM
		TheSim:LoadPrefabs({preview_phantom})
		spawnutil.SetupPreviewPhantom(inst, preview_phantom)
	else
		inst.OnPostLoadWorld = OnPostLoadWorld
	end

	return inst
end

return Prefab("spawner_trap", fn, assets)
