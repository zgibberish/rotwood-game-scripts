local soundutil = require "util.soundutil"
local fmodtable = require "defs.sound.fmodtable"
local lume = require "util.lume"
local Power = require("defs.powers.power")
local SGCommon = require "stategraphs.sg_common"

---------------------------------------------------------------------------------------
--Custom script for auto-generated prop prefabs
---------------------------------------------------------------------------------------

-- Totem specialized script for prop prefab
-- This was originally based off traps, and many functions were pulled from sg_player_hammer_skill_totem
local totem = {
	default = {},
}

function totem.default.CollectPrefabs(prefabs, args)
	table.insert(prefabs, "hammer_totem_buff")
	table.insert(prefabs, "fx_ground_heal_area")
end

-- function trap.default.GetTrapTypes()
-- 	-- These must match the stategraph names.
-- 	return {
-- 		"trap_spike",
-- 		"trap_exploding",
-- 		"trap_zucco",
-- 		"trap_bananapeel",
-- 		"trap_spores",
-- 		"trap_acid",
-- 		"trap_stalactite",
-- 	}
-- end

local function HealKiller(inst, killer)
	if killer ~= nil and killer:IsValid() and killer.components.combat ~= nil then
		TheLog.ch.Totem:printf("Heal Killer")
		local totem_skill_def = Power.FindPowerByName("hammer_totem")
		local healthtocreate = totem_skill_def.tuning.COMMON.healthtocreate

		local power_heal = Attack(inst, killer)
		power_heal:SetHeal(healthtocreate)
		power_heal:SetSource(totem_skill_def.name)
		killer.components.combat:ApplyHeal(power_heal)
	end
end

local function CreateSpawnFx(inst, ignore_parent_remove)
	local fx = SGCommon.Fns.SpawnChildAtDist(inst, "impact_dirt_totem", 0)
	fx:ListenForEvent("onremove", function() fx:Remove() end, inst)
	fx:DoTaskInTime(3, function(_inst)
		if fx and fx:IsValid() then
			fx:Remove()
		end
	end)
end

local function KillTotem(inst, attacker)
	--cleanup loop
	if inst.owner then
		soundutil.KillSound(inst.owner, inst.owner.sg.mem.totem_snapshot_lp)
		inst.owner.sg.mem.totem_snapshot_lp = nil
	end

	TheAudio:SetGlobalParameter(fmodtable.GlobalParameter.isLocalPlayerInTotem, 0)

	--sound if you don't hear anything it's because this is -inf dB in the FMOD project
	local params = {}
	params.fmodevent = fmodtable.Event.Skill_Hammer_Totem_Death
	soundutil.PlaySoundData(inst, params)

	if inst and inst:IsValid() then
		-- need to test for valid attack data in case it was outright removed instead of killed
		-- don't allow double heals since this teardown happens on both local and remote
		if attacker and attacker:IsValid() and inst:IsLocal() then
			HealKiller(inst, attacker)
		end

		if inst.radius and inst.radius:IsValid() then
			inst.radius:Remove()
		end

		if inst.owner and inst.owner:IsLocal() then
			inst.owner.sg.mem.hammerskilltotem = nil
		end

		SGCommon.Fns.SpawnAtDist(inst, "fx_dust_up2", 0)
		inst.components.auraapplyer:Disable()
		if inst:IsLocal() then
			inst:DoTaskInTicks(0, inst.Remove) -- need to delay like mobs to allow combat to finish
		end
	end
end

local function StartLoopingTotemSnapshot(inst, owner)
	--sound
	local params = {}
	params.fmodevent = fmodtable.Event.Skill_Hammer_Totem_Snapshot_LP
	inst.owner.sg.mem.totem_snapshot_lp = soundutil.PlaySoundData(inst.owner, params)
end

local function HandleSetup(inst, owner)
	inst.owner = owner
	StartLoopingTotemSnapshot(inst, owner)
end

local function HandleTeardown(inst, attacker)
	KillTotem(inst, attacker)
end

local function Setup(inst, owner)
	if inst:ShouldSendNetEvents() then
		TheNet:HandleSetup(inst.GUID, owner.GUID)
	else
		HandleSetup(inst, owner)
	end
end

local function Teardown(inst, attacker)
	if inst:ShouldSendNetEvents() then
		TheNetEvent:EntityTeardownFunction(inst.GUID, attacker and attacker.GUID or nil)
	else
		HandleTeardown(inst, attacker)
	end
end

function totem.default.CustomInit(inst, opts)
	inst.entity:AddHitBox()

	inst:AddComponent("hitbox")
	inst.components.hitbox:SetHitGroup(HitGroup.ALL)
	inst.components.hitbox:SetHitFlags(HitGroup.ALL)

	inst:AddComponent("combat")

	inst:AddComponent("health")
	inst.components.health:SetMax(800, true)
	-- this will only be "heard" on the auth client
	inst:ListenForEvent("dying", function(xinst, data)
		local attacker
		if data and data.attack then
			attacker = data.attack:GetAttacker()
		end
		TheLog.ch.Totem:printf("handle on death event: attacker=%s", attacker)
		xinst:Teardown(attacker)
	end)

	inst:AddComponent("powermanager")

	local totem_skill_def = Power.FindPowerByName("hammer_totem")
	inst:AddComponent("auraapplyer")
	inst.components.auraapplyer:SetEffect("hammer_totem_buff")
	inst.components.auraapplyer:SetRadius(totem_skill_def.tuning.COMMON.radius)
	inst.components.auraapplyer:Enable()

	local radius = SGCommon.Fns.SpawnChildAtDist(inst, "fx_ground_heal_area", 0)
	if radius then
		radius.AnimState:SetScale(5.5, 5.5)
		radius.AnimState:SetAddColor(1, 0, 0, .5)
		radius.AnimState:SetFrame(1)
		radius.AnimState:Pause()
		inst.radius = radius
	end

	inst.spawnfx = CreateSpawnFx(inst)

	-- Entity lifetime function configuration
	inst.Setup = Setup
	inst.HandleSetup = HandleSetup
	inst.Teardown = Teardown
	inst.HandleTeardown = HandleTeardown
end

-- function totem.PropEdit(editor, ui, params)
	-- local all_traps = trap.default.GetTrapTypes()
	-- local no_trap = 1
	-- table.insert(all_traps, no_trap, "")

	-- --~ dumptable(params.script_args)

	-- local is_trap = params.script == "trap"
	-- local idx = lume.find(all_traps, is_trap and params.script_args and params.script_args.trap_type)
	-- local changed
	-- changed, idx = ui:Combo("Trap Type", idx or no_trap, all_traps)
	-- if changed then
	-- 	if idx == no_trap then
	-- 		params.script = nil
	-- 		params.script_args = nil
	-- 	else
	-- 		params.script = "trap"
	-- 		params.script_args = {
	-- 			trap_type = all_traps[idx],
	-- 		}
	-- 	end
	-- 	editor:SetDirty()
	-- end
	-- if is_trap and params.parallax then
	-- 	if params.parallax_use_baseanim_for_idle then
	-- 		editor:WarningMsg(ui,
	-- 			"!!! Warning !!!",
	-- 			"Traps using parallax should be setup with idle animations. Each parallax item should have a name used as a suffix to their animations. So you might have 'spike1', 'spike2' in the parallax list and 'idle_spike1', 'idle_spike2' in the flash file.")
	-- 	end
	-- 	if editor.main_layer_count == 0 then
	-- 		editor:WarningMsg(ui,
	-- 			"!!! Warning !!!",
	-- 			"Traps using parallax need one parallax layer at dist 0 so it can act as the main anim that drives the stategraph. Otherwise we never receive animover and animations loop infinitely.")
	-- 	end
	-- end
-- end

return totem
