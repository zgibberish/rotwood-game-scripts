local SpawnUtil = require "util.spawnutil"
local PropAutogenData = require "prefabs.prop_autogen_data"
local Biomes = require "defs.biomes"
local KRandom = require "util.krandom"
local WareDispenser = require "prefabs.customscript.waredispenser"
local lume = require "util.lume"
local Enum = require "util.enum"

local assets = SpawnUtil.GetEditableAssets()

MetaWareDispenser = Enum {
	"ARMOUR",
	WEAPON_TYPES.HAMMER,
	WEAPON_TYPES.POLEARM,
	WEAPON_TYPES.SHOTPUT,
	WEAPON_TYPES.CANNON,
}

-- TODO @chrisp #vending - for now, we just hard-code a mapping from market to prop
-- We may want to defer this decision to SceneGens
local WARE_DISPENSER_PROPS <const> = {
	[Market.s.Run] = "run_item_shop",
	[Market.s.Dye] = "dye_bottle_shop",
	[Market.s.Meta] = "meta_item_shop",
}

local function GatherPrefabs()
	local prefabs = lume(WARE_DISPENSER_PROPS):values():result()
	table.insert(prefabs, GroupPrefab("shop_items"))
	return prefabs
end

local FALLBACK_PREVIEW_PHANTOM = WARE_DISPENSER_PROPS[Market.s.Run]
assert(PropAutogenData[FALLBACK_PREVIEW_PHANTOM],
	"Fallback preview phantom for spawner_waredispenser does not exist: "..FALLBACK_PREVIEW_PHANTOM)



local function ChooseWareDispenser(rng)
	return FALLBACK_PREVIEW_PHANTOM
	-- TODO @chrisp #vending - Do we want per-dungeon ware dispenser looks?
	-- if not TheSceneGen then
	-- 	return
	-- end
	-- local vending_machines = Biomes.locations[TheSceneGen.components.scenegen.dungeon].vending_machines
	-- return next(vending_machines)
	-- 	and vending_machines[rng:Integer(#vending_machines)]
end

-- local function OnPostLoadWorld(inst)
-- 	TheDungeon:GetDungeonMap().shopmanager:SpawnWareDispenser(inst.Transform, inst.components.prop.script_args)
-- 	inst:Remove()
-- end

local function GetPreviewPhantom()
	return ChooseWareDispenser(KRandom._SystemRng)
end

local function fn()
	if not TheNet:IsHost() then return end

	local inst = SpawnUtil.CreateBasicSpawner()
	inst.components.prop.script = WareDispenser
	inst.components.prop.script_args = WareDispenser(inst)
	setmetatable(inst.components.prop.script_args, nil)
	inst.components.snaptogrid:SetDimensions(1, 1, -10)
	if TheDungeon:GetDungeonMap():IsDebugMap() then
		SpawnUtil.MakeEditable(inst, "square")
		local preview_phantom = GetPreviewPhantom() or FALLBACK_PREVIEW_PHANTOM
		TheSim:LoadPrefabs({preview_phantom})
		SpawnUtil.SetupPreviewPhantom(inst, preview_phantom)
	else
		inst:ListenForEvent("on_hud_created", function()
			TheDungeon:GetDungeonMap().shopmanager:SpawnWareDispenser(
				WARE_DISPENSER_PROPS[inst.components.prop.script_args.market],
				inst.Transform,
				inst.components.prop.script_args
			)
			inst:Remove()
		end, TheDungeon)
		-- inst.OnPostLoadWorld = OnPostLoadWorld
	end
	return inst
end

return Prefab("spawner_waredispenser", fn, assets, GatherPrefabs())
