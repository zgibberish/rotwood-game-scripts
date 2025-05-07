local Power = require "defs.powers.power"
local lume = require "util.lume"
local playerutil = require "util.playerutil"
local powerdrops = require "prefabs.customscript.powerdrops"

require "constants"

-- A power pickup that allows multiple players to collect the pickup.

local powerdrop_prefabs =
{
	"power_drop_generic_1p",
	"power_drop_generic_2p",
	"power_drop_generic_3p",
	"power_drop_generic_4p",
}

local skilldrop_prefabs =
{
	"skill_drop_generic_1p",
	"skill_drop_generic_2p",
	"skill_drop_generic_3p",
	"skill_drop_generic_4p",
}

local function DEBUG_SpawnDrops(inst, num)
	local drops = {}

	for i = 1, num do
		drops[i] = inst.drop_prefabs[i]
	end

	inst.components.powerdrop.appear_delay = TUNING.POWERS.DROP_SPAWN_INITIAL_DELAY_FRAMES
	inst.components.rotatingdrop:SpawnDrops(drops)
end

local function EditEditable(inst, ui)
	for i=1,4 do
		if ui:Button("SpawnDrops ".. i) then
			DEBUG_SpawnDrops(inst, i)
		end
		ui:SameLineWithSpace()
	end
	ui:NewLine()
end

local function _BuildDropsTable(inst)
	local players = TheNet:GetPlayersOnRoomChange()
	local drops = {}
	for i, player in ipairs(players) do
		drops[player] = inst.drop_prefabs[i]
	end
	return drops
end

local function OnEditorSpawn(inst)
	inst.components.powerdrop:PrepareToShowGem({
			appear_delay_ticks = TUNING.POWERS.DROP_SPAWN_INITIAL_DELAY_FRAMES,
		})
	inst.components.rotatingdrop:PrepareToShowDrops()
end

-- This is the constructor for the "core power drop" that controls the sub-drops (i.e. crystals)
-- For networking purposes, this is host-spawned, but the sub-drops are local entities
local function fn(name, opts)
	local inst = CreateEntity()
	inst:SetPrefabName(name)

	inst.entity:AddTransform()

	inst.persists = false

	inst.drop_prefabs = opts.drop_prefabs

	powerdrops.ConfigurePowerDrop(inst, opts)

	inst.EditEditable = EditEditable
	inst.DebugDrawEntity = EditEditable
	inst.OnEditorSpawn = OnEditorSpawn

	-- In order to work as a lead actor in a cinematic, we need to give this entity a dummy stategraph.
	inst:SetStateGraph(inst.prefab, GenerateStateGraph(inst.prefab))

	return inst
end

local function relic_fn(name)
	local opts = {
		power_type = Power.Types.RELIC,
		power_category = Power.Categories.ALL,
		interact_radius = 4,
		drop_prefabs = powerdrop_prefabs,
		build_drops_fn = _BuildDropsTable
	}

	return fn(name, opts)
end

local function skill_fn(name)
	local opts = {
		power_type = Power.Types.SKILL,
		power_category = Power.Categories.ALL,
		interact_radius = 4,
		drop_prefabs = skilldrop_prefabs,
		build_drops_fn = _BuildDropsTable,
	}

	return fn(name, opts)
end

return 	Prefab("power_drop_player", relic_fn, nil, powerdrop_prefabs, nil, NetworkType_HostAuth),
		Prefab("power_drop_skill", skill_fn, nil, skilldrop_prefabs, nil, NetworkType_HostAuth)
