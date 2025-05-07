---------------------------------------------------------------------------------------
--Custom script for auto-generated prop prefabs
---------------------------------------------------------------------------------------

local lume = require "util.lume"
local spawnutil = require "util.spawnutil"
local monsterutil = require "util.monsterutil"
local Enum = require "util.enum"

-- Spawners are just props. They call into here to add trap behaviour to their
-- existing setup. Currently, we want them to have mostly the same setup.
local creaturespawner = {
	default = {},
}

function creaturespawner.default.CollectPrefabs(prefabs, args)
	-- Don't add creatures here. They're added as world dependencies in biomes.lua
	table.insert(prefabs, "spawn_light_strips")
end

function creaturespawner.default.GetSpawnerTypes()
	-- These must match the stategraph names.
	return {
		"spawner_battlefield",
		"spawner_perimeter",
		"spawner_miniboss",
	}
end

local function SetSpawnAngle(inst, angle)
	inst._spawn_angle = angle
end

local function GetSpawnAngle(inst)
	if not inst._spawn_angle then
		local rng = TheWorld.components.spawncoordinator:GetRNG()
		inst:SetSpawnAngle(rng:Integer(1, 360))
	end

	return inst._spawn_angle
end

local function ReserveSpawner(inst, creature)
	inst._pending_spawn = creature

	inst._on_creature_spawned_fn = function()
		inst:PushEvent("spawned_creature")
	end

	inst:ListenForEvent("leave_spawner", inst._on_creature_spawned_fn, creature)
end

local function FreeSpawner(inst, source)
	if inst._pending_spawn then
		inst:RemoveEventCallback("leave_spawner", inst._on_creature_spawned_fn, inst._pending_spawn)
	end

	inst._on_creature_spawned_fn = nil
	inst._pending_spawn = nil
end

local function CanSpawnCreature(inst, prefab) -- this is horrible, we need a proper system later.
	if inst._pending_spawn ~= nil then
		return false, "["..prefab.prefab.."] spawn already pending on ["..inst.prefab.."]"
	end

	if inst.invalid_tags then
		for i, tag in ipairs(inst.invalid_tags) do
			if prefab:HasTag(tag) then
				return false, "["..prefab.prefab.."] has ["..inst.prefab.."]'s invalid tag ["..tag.."]"
			end
		end
	end

	if inst.required_tags then
		for i, tag in ipairs(inst.required_tags) do
			if not prefab:HasTag(tag) then
				return false, "["..prefab.prefab.."] does not have ["..inst.prefab.."]'s required tag ["..tag.."]"
			end
		end
	end

	return true, ""
end

local function SpawnCreaturePerimeter(spawner, creature, is_first_wave)
	local x, z = spawner.Transform:GetWorldXZ()
	local target_pos = TheWorld.Map:FindClosestWalkablePoint(spawner:GetPosition())

	local padding_from_edge = 2
	local _, _, distsq = TheWorld.Map:FindClosestXZOnWalkableBoundaryToXZ(target_pos.x, target_pos.z)
	if distsq < padding_from_edge * padding_from_edge then
		-- Pull back from outside edges.
		local to_point, len = target_pos:normalized()
		-- Double padding to ensure we've backed up enough.
		len = math.abs(len - padding_from_edge * 2)
		target_pos = to_point:scale(len)
	end

	creature.Transform:SetPosition(x, 0, z)
	creature:AddComponent("spawnfader")

	if is_first_wave then
		spawner:FreeSpawner()

		-- If the tile it was planning to spawn on is impassable, find an actually walkable tile.
		-- This is because when we make a Tiled map that has 'holes' in it, those are considered 'walkable'
		local tile = TheWorld.Map:GetNamedTileAtXZ(target_pos.x, target_pos.z)
		if tile == "IMPASSABLE" then
			local final_x, final_z = monsterutil.BruteForceFindWalkableTileFromXZ(target_pos.x, target_pos.z, 10, 5)
			target_pos.x = final_x
			target_pos.z = final_z
		end

		creature:PushEvent("spawn_initialwave", { spawner = spawner, target_pos = target_pos, })
		creature.Transform:SetPosition(target_pos.x, target_pos.y, target_pos.z)
	else
		creature:PushEvent("spawn_perimeter", target_pos)
	end

	creature:PushEvent("spawn_anyspawner")
	spawner:PushEvent("spawned_creature", creature)
	if creature.components.combat then
		creature.components.combat:SetTarget(creature:GetClosestEntityByTagInRange(100, creature.components.combat:GetTargetTags(), true))
	end
	return creature
end

local function SpawnCreatureBattlefield(spawner, creature, is_first_wave)
	-- local ent = spawnutil.Spawn(inst, prefab)
	creature.Transform:SetPosition(spawner.Transform:GetWorldPosition())

	local rng = TheWorld.components.spawncoordinator:GetRNG()
	if is_first_wave then
		local x, z = creature.Transform:GetWorldXZ()
		local dist_mod = 2
		local randomOffset,angle = rng:Vec3_FlatOffset(dist_mod)
		angle = math.deg(angle)
		creature.Transform:SetPosition(x + randomOffset.x, 0, z + randomOffset.y)
		spawner:FreeSpawner() -- don't have to wait for visual to complete
		creature:PushEvent("spawn_initialwave", { spawner = spawner, dir = angle })
	else
		local angle = rng:Integer(1, 360)
		creature.Transform:SetRotation(angle)
		spawner:SetSpawnAngle(angle)
		creature:AddComponent("spawnfader")
		creature:PushEvent("spawn_battlefield")
		if creature.components.combat then
			creature.components.combat:SetTarget(creature:GetClosestEntityByTagInRange(creature.tuning.vision.aggro_range * 2, creature.components.combat:GetTargetTags(), true))
		end
	end
	creature:PushEvent("spawn_anyspawner")
	return creature
end

local function SpawnCreatureMiniboss(spawner, creature, is_first_wave)
	-- print("SpawnCreatureMiniboss")
	creature.Transform:SetPosition(spawner.Transform:GetWorldPosition())

	local rng = TheWorld.components.spawncoordinator:GetRNG()

	local dist_mod = 2
	local target_pos = spawner:GetPosition()
	target_pos.y = 0
	target_pos = target_pos + rng:Vec3_FlatOffset(dist_mod)
	creature.Transform:SetPosition(target_pos:unpack())
	spawner:FreeSpawner()
	creature:PushEvent("spawn_anyspawner")

	spawner:DoTaskInTicks(15, function() creature:PushEvent("miniboss_introduction") end)
	return creature
end

local function OnEditorSpawn(inst, editor)

end

function creaturespawner.default.CustomInit(inst, opts)
	if not opts then
		TheLog.ch.Spawn:print("Skipping CustomInit for creaturespawner:", inst)
		dbassert(false, "Please @forge-prog in reply to this crash in #fromtheforge-crashes or submit feedback. We skipped init of a creaturespawner and spawning will likely fail.")
		return
	end

	inst:SetStateGraph("sg_".. opts.spawner_type)
	inst.OnEditorSpawn = OnEditorSpawn
	inst.CanSpawnCreature = CanSpawnCreature

	inst.ReserveSpawner = ReserveSpawner
	inst.FreeSpawner = FreeSpawner
	inst.SetSpawnAngle = SetSpawnAngle
	inst.GetSpawnAngle = GetSpawnAngle

	creaturespawner.InitSpawner(inst)

	TheWorld.components.spawncoordinator:AddSpawner(inst)

	if opts.spawner_type == "spawner_perimeter" then
		inst:AddComponent("hitshudder")
		inst.components.hitshudder.scale_amount = 0.1
		inst.required_tags = { "large" }
		inst.SpawnCreature = SpawnCreaturePerimeter
	elseif opts.spawner_type == "spawner_miniboss" then
		inst.required_tags = { "miniboss" }
		inst.SpawnCreature = SpawnCreatureMiniboss
	else
		inst.required_tags = { }
		inst.invalid_tags = { "large" }
		inst.SpawnCreature = SpawnCreatureBattlefield
	end

	if opts.is_invisible then
		local shape = "square"
		if TheDungeon:GetDungeonMap():IsDebugMap() then
			spawnutil.MakeEditable(inst, shape)
		else
			inst:Hide()
		end
		inst.baseanim = shape
	end

	--[[
		if TheDungeon:GetDungeonMap():IsDebugMap() then
			-- Game is sluggish with this enabled.
			spawnutil.SetupPreviewPhantom(inst, inst.valid_spawns[1], 0.3)
		end
	--]]
	if TheDungeon:GetDungeonMap():IsDebugMap() then
		-- purplish leaves to stand out against other leaves
		inst.AnimState:SetMultColor(245/255, 66/255, 230/255, 1)
	end
end

function creaturespawner.PropEdit(editor, ui, params)
	local opts = params.script_args

	local all_spawners = creaturespawner.default.GetSpawnerTypes()
	local no_spawner = 1
	table.insert(all_spawners, no_spawner, "")

	-- dumptable(all_spawners)

	local is_spawner = params.script == "creaturespawner"
	local idx = lume.find(all_spawners, is_spawner and opts.spawner_type)
	local changed
	changed, idx = ui:Combo("Spawner Type", idx or no_spawner, all_spawners)
	if changed then
		if idx == no_spawner then
			params.script = nil
		else
			params.script = "creaturespawner"
			opts.spawner_type = all_spawners[idx]
		end
		editor:SetDirty()
	end
	opts.is_invisible = ui:_Checkbox("Invisible", opts.is_invisible) or nil

	if is_spawner and params.parallax and not opts.is_invisible then
		if params.parallax_use_baseanim_for_idle then
			editor:WarningMsg(ui, "!!! Warning !!!", "Spawners using parallax should be setup with idle animations. Each parallax item should have a name used as a suffix to their animations. So you might have 'spike1', 'spike2' in the parallax list and 'idle_spike1', 'idle_spike2' in the flash file.")
		end
		if editor.main_layer_count == 0 then
			editor:WarningMsg(ui, "!!! Warning !!!", "Spawners using parallax need one parallax layer at dist 0 so it can act as the main anim that drives the stategraph. Otherwise we never receive animover and animations loop infinitely.")
		end
	end

	params.script_args = opts
end

---------------------------------------------------------------------
-- Code for handling stationary enemy spawner data
---------------------------------------------------------------------
local SPAWN_AREAS = Enum
{
	"battlefield",
	"perimeter",
	"center",
	"top",
	"bottom",
	"left",
	"right",
}

function creaturespawner.InitSpawner(inst)
	inst.spawn_areas = {} -- A lookup list of currently selected spawn areas.
	inst.components.prop.script_args = {}

	-- TODO: This should use LivePropEdit and Apply in this customscript
	-- instead of setting EditEditable and LoadScriptArgs.
	inst.EditEditable = creaturespawner.EditEditable -- Assign this for handling editable UI for this
	inst.LoadScriptArgs = creaturespawner.LoadScriptArgs; -- Assign this to handle loading of prop data from file
end


function creaturespawner.LoadScriptArgs(inst, data)
	for i, spawn_area in ipairs(data.spawn_areas or {}) do
		inst.spawn_areas[spawn_area] = true
	end
end

-- Editor UI for trap spawners.
function creaturespawner.EditEditable(inst, ui)
	ui:Separator()
	if ui:FlagRadioButtons("Spawn Area", SPAWN_AREAS:Ordered(), inst.components.prop.script_args.spawn_areas) then
		inst.components.prop:OnPropChanged()
	end
end

return creaturespawner
