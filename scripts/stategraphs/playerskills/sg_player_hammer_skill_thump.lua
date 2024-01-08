local SGCommon = require "stategraphs.sg_common"
local SGPlayerCommon = require "stategraphs.sg_player_common"
local fmodtable = require "defs.sound.fmodtable"
local PlayerSkillState = require "playerskillstate"
local combatutil = require "util.combatutil"

-- The "CHARGE" feature of this skill is modelled after the Golf Swing (reverse heavy attack) and Overhead Slam of the hammer.
-- Same frame thresholds, same presentation.

-- Recovery windows:
-- Frame0, Frame7, Frame10 for TIER0, TIER1, TIER2

local events = {}

local ATTACKS =
{
	-- Attack damage is tuned the same as reverse heavy attack
	TIER0 =
	{
		DAMAGE_NORMAL = 1.66,
		DAMAGE_FOCUS = 2.5,
		HITSTUN = 2,
		PUSHBACK = 1,
		HITSTOP = HitStopLevel.MEDIUM,
		RADIUS = 3,
		FOCUS = false,
		COMBAT_FN = "DoKnockbackAttack",
	},

	TIER1 =
	{
		DAMAGE_NORMAL = 2.5,
		DAMAGE_FOCUS = 2.91,
		HITSTUN = 2,
		PUSHBACK = 1.25,
		HITSTOP = HitStopLevel.MEDIUM,
		RADIUS = 3.25,
		FOCUS = false,
		COMBAT_FN = "DoKnockbackAttack",
	},

	TIER2 =
	{
		DAMAGE_NORMAL = 2.91,
		DAMAGE_FOCUS = 4.58,
		HITSTUN = 3.5,
		PUSHBACK = 1.5,
		HITSTOP = HitStopLevel.MAJOR,
		RADIUS = 4,
		FOCUS = true,
		COMBAT_FN = "DoKnockdownAttack",
	},
}

local CHARGE_THRESHOLD_TIER1 = 8 -- How many frames have we held the attack for? 3 different damage tiers based on how long you held.
local CHARGE_THRESHOLD_TIER2 = 16 -- These thresholds match the other hammer attacks
local FOCUS_TARGETS_THRESHOLD = 1 -- When more than this amount of targets are struck in one swing, every subsequent hit should be a focus

local function OnThumpHitBoxTriggered(inst, data)
	local attack = ATTACKS[inst.sg.statemem.attackid]

	local focushit = false
	local numtargets = 0
	-- We have to check every target before we start iterating over them to do damage, so we know before we damage the first target whether we've got a focus
	for i = 1, #data.targets do
		local v = data.targets[i] -- TODO: add this target to a inst.sg.statemem.targetlist and only count v as another numtarget if we haven't hit them before? or, leave as is so hammer has a few ways to focus against single enemies
		if v.components.health then
			numtargets = numtargets + 1
		end
	end

	local damage_mod
	if numtargets > FOCUS_TARGETS_THRESHOLD or attack.FOCUS then
		focushit = true
		damage_mod = attack.DAMAGE_FOCUS
	else
		damage_mod = attack.DAMAGE_NORMAL
	end

	local damage_override
	local buff_power = inst.components.powermanager:GetPowerByName("jury_and_executioner") -- 100 damage per stack
	if buff_power then
		if buff_power.persistdata.stacks ~= nil and buff_power.persistdata.stacks > 0 then
			damage_override = buff_power.persistdata:GetVar("damage_per_consecutive_hit") * buff_power.persistdata.stacks
		end
	end

	local hit = SGCommon.Events.OnHitboxTriggered(inst, data, {
		attackdata_id = "hammer_thump",
		damage_mod = damage_mod,
		damage_override = damage_override ~= nil and damage_override or nil,
		hitstoplevel = attack.HITSTOP,
		pushback = attack.PUSHBACK,
		focus_attack = focushit,
		hitflags = Attack.HitFlags.GROUND,
		combat_attack_fn = attack.COMBAT_FN,
		hit_fx = "hits_player_blunt",
		hit_fx_offset_x = 0,
		hit_fx_offset_y = 0.5,
		set_dir_angle_to_target = true,
	})

	if hit then
		inst:PushEvent("hammer_thumped")
	end
end

local states =
{
	PlayerSkillState({
		name = "skill_hammer_thump",
		tags = { "busy" },

		onenter = function(inst)
			inst.AnimState:PlayAnimation("hammer_skill_thump_pre")
			if not inst.components.playercontroller:IsControlHeld("skill") then
				inst.sg.statemem.mustexit = true
				inst.sg.statemem.earlyheldframes = 0
			end
			-- inst.components.combat:SetDamageReceivedMult("superarmor", .2)
		end,

		timeline =
		{
			FrameEvent(14, function(inst)
				if inst.sg.statemem.mustexit then
					inst.sg:GoToState("skill_hammer_thump_atk", inst.sg.statemem.earlyheldframes) -- We released early, so send the amount of frames we held for
				else
					inst.sg.statemem.canexit = true
				end
			end),

			FrameEvent(CHARGE_THRESHOLD_TIER2, function(inst)
				SGCommon.Fns.FlickerSymbolBloom(inst, "weapon_back01", TUNING.FLICKERS.WEAPONS.HAMMER.CHARGE_COMPLETE.COLOR, TUNING.FLICKERS.WEAPONS.HAMMER.CHARGE_COMPLETE.FLICKERS, TUNING.FLICKERS.WEAPONS.HAMMER.CHARGE_COMPLETE.FADE, TUNING.FLICKERS.WEAPONS.HAMMER.CHARGE_COMPLETE.TWEENS)
			end),
			FrameEvent(CHARGE_THRESHOLD_TIER2+4, function(inst)
				inst.AnimState:SetSymbolBloom("weapon_back01", TUNING.FLICKERS.WEAPONS.HAMMER.FOCUS_SWING.COLOR[1], TUNING.FLICKERS.WEAPONS.HAMMER.FOCUS_SWING.COLOR[2], TUNING.FLICKERS.WEAPONS.HAMMER.FOCUS_SWING.COLOR[3], TUNING.FLICKERS.WEAPONS.HAMMER.FOCUS_SWING.COLOR[4])
			end),

			FrameEvent(10, SGPlayerCommon.Fns.SetCanDodge),
		},

		onexit = function(inst)
			inst.AnimState:SetSymbolBloom("weapon_back01", 0, 0, 0, 0)
		end,

		events =
		{
			EventHandler("controlupevent", function(inst, data)
				if data.control == "skill" then
					if inst.sg.statemem.canexit then
						-- This is after frame 10, so let's exit now
						inst.sg:GoToState("skill_hammer_thump_atk", inst.sg:GetAnimFramesInState())
					else
						-- If the player has released SKILL before frame 10, then set a flag so that once we hit frame 10 we MUST exit.
						inst.sg.statemem.mustexit = true
						inst.sg.statemem.earlyheldframes = inst.sg:GetAnimFramesInState()
					end
				end
			end),

			EventHandler("animover", function(inst)
				inst.sg:GoToState("skill_hammer_thump_atk_fullycharged", inst.sg:GetAnimFramesInState())
			end),
		},
	}),

	PlayerSkillState({
		name = "skill_hammer_thump_atk",
		tags = { "attack", "busy", "nointerrupt" },

		onenter = function(inst, frames)
			-- A fully charged attack CANNOT be in this state -- fully charged is guaranteed to be in the "fullycharged" state. This is for tier0 or tier1
			inst:PushEvent("attack_state_start")
			inst.AnimState:PlayAnimation("hammer_skill_thump_atk")
			-- inst.components.combat:SetDamageReceivedMult("superarmor", .2) -- Disabling this because other charge attacks don't use it

			if frames > CHARGE_THRESHOLD_TIER1 then
				inst.sg.statemem.attackid = "TIER1"
			else
				inst.sg.statemem.attackid = "TIER0"
			end
		end,

		timeline =
		{
			FrameEvent(3, function(inst)
				inst.components.hitbox:PushCircle(1, 0, ATTACKS[inst.sg.statemem.attackid].RADIUS, HitPriority.PLAYER_DEFAULT)
				inst.AnimState:SetSymbolBloom("weapon_back01", 0, 0, 0, 0)
				combatutil.StartMeleeAttack(inst)
			 end),

			FrameEvent(4, function(inst)
				combatutil.EndMeleeAttack(inst)
			 end),

			FrameEvent(5, function(inst) --FRAME0, FRAME7, FRAME10 FOR THREE RECOVERY WINDOWS for TIER0, TIER1, TIER2. This is frame0. Frame7 is in pst
				if inst.sg.statemem.attackid == "TIER0" then
					SGPlayerCommon.Fns.SetCanDodge(inst)
					SGPlayerCommon.Fns.SetCanAttackOrAbility(inst)
					SGPlayerCommon.Fns.TryQueuedAction(inst, "dodge")
				end
			end),
		},

		events =
		{
			EventHandler("hitboxtriggered", OnThumpHitBoxTriggered),
			EventHandler("animover", function(inst)
				inst.sg:GoToState("skill_hammer_thump_pst", inst.sg.statemem.attackid)
			end),
		},
	}),

	PlayerSkillState({
		name = "skill_hammer_thump_atk_fullycharged",
		tags = { "attack", "busy", "nointerrupt" },

		onenter = function(inst, frames)
			-- This entire state is guaranteed to be a fully charged focus hit
			inst:PushEvent("attack_state_start")
			inst.AnimState:PlayAnimation("hammer_skill_thump_strong_atk")
			-- inst.components.combat:SetDamageReceivedMult("superarmor", .2) -- Disabling this because other charge attacks don't use it
			inst.sg.statemem.attackid = "TIER2"
			inst.AnimState:SetSymbolBloom("weapon_back01", TUNING.FLICKERS.WEAPONS.HAMMER.FOCUS_SWING.COLOR[1], TUNING.FLICKERS.WEAPONS.HAMMER.FOCUS_SWING.COLOR[2], TUNING.FLICKERS.WEAPONS.HAMMER.FOCUS_SWING.COLOR[3], TUNING.FLICKERS.WEAPONS.HAMMER.FOCUS_SWING.COLOR[4])
		end,

		timeline =
		{
			FrameEvent(7, function(inst)
				inst.components.hitbox:PushCircle(1, 0, ATTACKS.TIER2.RADIUS, HitPriority.PLAYER_DEFAULT)
				inst.AnimState:SetSymbolBloom("weapon_back01", 0, 0, 0, 0)
			 end),
		},

		events =
		{
			EventHandler("hitboxtriggered", OnThumpHitBoxTriggered),
			EventHandler("animover", function(inst)
				inst.sg:GoToState("skill_hammer_thump_pst", inst.sg.statemem.attackid)
			end),
		},
	}),

	PlayerSkillState({
		name = "skill_hammer_thump_pst",
		tags = { "busy" },

		onenter = function(inst, chargetier)
			inst.AnimState:PlayAnimation("hammer_skill_thump_pst")
			inst.sg.statemem.attackid = chargetier

			if inst.sg.statemem.attackid == "TIER0" or inst.sg.statemem.attackid == "TIER1" then
				SGPlayerCommon.Fns.SetCanDodge(inst)
				SGPlayerCommon.Fns.SetCanAttackOrAbility(inst)
			end
		end,

		timeline =
		{
			-- Same cancel windows as hammer reverse heavy swing
			FrameEvent(7, function(inst)
				if inst.sg.statemem.attackid == "TIER2" then
					SGPlayerCommon.Fns.SetCanDodge(inst)
					SGPlayerCommon.Fns.SetCanAttackOrAbility(inst)
				end
			end),

			FrameEvent(16, SGPlayerCommon.Fns.RemoveBusyState)
		},

		events =
		{
			EventHandler("animover", function(inst)
				inst.sg:GoToState("idle")
			end),
		},
	}),
}

return StateGraph("sg_player_hammer_skill_thump", states, events, "skill_hammer_thump")
