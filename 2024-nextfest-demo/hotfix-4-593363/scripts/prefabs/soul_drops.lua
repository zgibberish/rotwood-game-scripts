local Power = require "defs.powers.power"
local lume = require "util.lume"
local konjursouls = require "prefabs.customscript.konjursouls"
require "constants"

-- A power pickup that allows multiple players to collect the pickup.

local lesserdrop_prefabs =
{
	"soul_drop_konjur_soul_lesser",
}

local greaterdrop_prefabs =
{
	"soul_drop_konjur_soul_greater",
}

local heartdrop_prefabs =
{
	"soul_drop_boss_megatreemon",
	"soul_drop_boss_owlitzer",
	"soul_drop_boss_thatcher",
	"soul_drop_boss_bandicoot",
	"soul_drop_konjur_soul_greater",
	"soul_drop_konjur_soul_lesser",
}

local function DEBUG_SpawnDrops(inst, num)
	local drops = {}

	for i = 1, num do
		drops[i] = inst.drop_prefabs[i]
	end

	inst.components.souldrop.appear_delay = TUNING.POWERS.DROP_SPAWN_INITIAL_DELAY_FRAMES
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

local function _BuildDropsTable_Generic(inst)
	local drops = {}
	local players = TheNet:GetPlayersOnRoomChange()
	for _i, player in ipairs(players) do
		drops[player] = inst.drop_prefabs[1]
	end
	return drops
end

local function _BuildDropsTable_Boss(inst)
	local drops = {}
	local boss = TheWorld:GetCurrentBoss()
	local heart_drop = string.format("soul_drop_boss_%s", boss) -- Get boss from TheWorld

	-- TODO: This logic needs to be per player and per item. This should be saved on a player level, not a world level.
	local players = TheNet:GetPlayersOnRoomChange()
	for _i, player in ipairs(players) do
		local is_eligible = boss and TheDungeon.progression.components.ascensionmanager:IsEligibleForHeart(player)
		drops[player] = is_eligible and heart_drop or "soul_drop_konjur_soul_lesser"
	end
	return drops
end

local function OnEditorSpawn(inst)
	inst.components.souldrop:PrepareToShowGem({
			appear_delay_ticks = TUNING.POWERS.DROP_SPAWN_INITIAL_DELAY_FRAMES,
		})
	inst.components.rotatingdrop:PrepareToShowDrops()
end

-- This is the constructor for the "core drop" that controls the sub-drops (i.e. souls)
-- For networking purposes, this is host-spawned, but the sub-drops are local entities
local function fn(name, opts)
	local inst = CreateEntity()
	inst:SetPrefabName(name)

	inst.entity:AddTransform()

	inst.persists = false

	inst.drop_prefabs = opts.drop_prefabs

	konjursouls.ConfigureKonjurSoul(inst, opts)

	inst.EditEditable = EditEditable
	inst.DebugDrawEntity = EditEditable
	inst.OnEditorSpawn = OnEditorSpawn

	return inst
end

local function lesser_fn(name)
	local opts = {
		soul_type = "konjur_soul_lesser",
		interact_radius = 4,
		drop_prefabs = lesserdrop_prefabs,
		build_drops_fn = _BuildDropsTable_Generic,
	}

	return fn(name, opts)
end

local function greater_fn(name)
	local opts = {
		soul_type = "konjur_soul_greater",
		interact_radius = 4,
		drop_prefabs = greaterdrop_prefabs,
		build_drops_fn = _BuildDropsTable_Generic,
	}

	return fn(name, opts)
end

local function heart_fn(name)
	local opts = {
		soul_type = "konjur_heart",
		interact_radius = 4,
		drop_prefabs = heartdrop_prefabs,
		build_drops_fn = _BuildDropsTable_Boss,
	}

	return fn(name, opts)
end

return 	Prefab("soul_drop_lesser", lesser_fn, nil, lesserdrop_prefabs, nil, NetworkType_HostAuth),
		Prefab("soul_drop_greater", greater_fn, nil, greaterdrop_prefabs, nil, NetworkType_HostAuth),
		Prefab("soul_drop_heart", heart_fn, nil, heartdrop_prefabs, nil, NetworkType_HostAuth)
