local SGCommon = require "stategraphs.sg_common"
local ease = require "util.ease"
local combatutil = require "util.combatutil"
local soundutil = require "util.soundutil"
local fmodtable = require "defs.sound.fmodtable"

-- storing these values here for now, likely will move into trap.lua though
local COOLDOWN_TIME = 0.4
local KNOCKBACK_DISTANCE = 1.2
local HITSTUN = 10 -- anim frames
local WARNING_FRAMES = 25
local TRAP_DAMAGE_RADIUS = .5 -- manually set up by luca for the test

-- default values, these are set in prop editor, but storing them here as well
-- so we can transition back to original bloom values if the trap un-dormants
-- in debug
local bloom_r = 167/255
local bloom_g = 0/255
local bloom_b = 255/255
local bloom_a = .55

local function IsAPlayerInTheTrap(inst)
	local is_player_in_trap
	local is_local_player_in_trap
	for k, player in pairs(AllPlayers) do
		if player:IsAlive() then
			local dist = inst:GetDistanceSqTo(player) / 10
			if dist <= TRAP_DAMAGE_RADIUS then
				is_player_in_trap = true
				if player:IsLocal() and not player.HitBox:IsInvincible() then
					is_local_player_in_trap = true
				end
			end
		end
	end
	return is_player_in_trap, is_local_player_in_trap
end

local function OnProximityHitBoxTriggered(inst, data)
	local triggered = false
	for i = 1, #data.targets do
		local v = data.targets[i]
		if v.entity:HasTag("player") then
			triggered = true
			break
		end
	end

	if(triggered) then
		inst.sg:GoToState("stab_pre")
	end

end

local function OnTrapHitBoxTriggered(inst, data)
	SGCommon.Events.OnHitboxTriggered(inst, data, {
		hitstoplevel = HitStopLevel.HEAVY,
		set_dir_angle_to_target = true,
		player_damage_mod = TUNING.TRAPS.DAMAGE_TO_PLAYER_MULTIPLIER,
		pushback = KNOCKBACK_DISTANCE,
		hitflags = Attack.HitFlags.LOW_ATTACK,
		hitstun_anim_frames = HITSTUN,
		combat_attack_fn = "DoKnockbackAttack",
		hit_fx = "fx_hit_player_round",
		hit_fx_offset_x = 0.5,
	})
end

local function OnDormantStart(inst)
	inst.sg:GoToState("idle_to_dormant")
end

local events =
{
	EventHandler("dormant_start", OnDormantStart),
}

local states =
{

	State({
		name = "idle",
		tags = { "idle" },

		onenter = function(inst)
			if not inst.AnimState:IsCurrentAnimation("idle_"..inst.baseanim) then
				SGCommon.Fns.PlayAnimOnAllLayers(inst, "idle", true)
			end
			inst.components.hitbox:SetUtilityHitbox(true)
		end,

		onexit = function(inst)
			inst.components.hitbox:SetUtilityHitbox(false)
		end,

		onupdate = function(inst)
			inst.components.hitbox:PushBeam(-1.4, 1.4, 1.6, HitPriority.MOB_DEFAULT)
		end,

		events =
		{
			EventHandler("hitboxtriggered", OnProximityHitBoxTriggered),
		},
	}),

	State({
		name = "idle_to_dormant",
		tags = { "idle" },

		onenter = function(inst)
			local duration = 1
			inst.sg:SetTimeout(duration)
			local function fn(t)
				return 1 - ease.linear(t)
			end
			inst.components.bloomer:PushFadingBloom(fn, duration, "prop_autogen", bloom_r, bloom_g, bloom_b, bloom_a)
		end,

		ontimeout = function(inst)
			inst.sg.statemem.can_transition = true
		end,

		events =
		{
			EventHandler("animover", function(inst)
				if inst.sg.statemem.can_transition then
					inst.sg:GoToState("dormant")
				end
			end),
		},
	}),

	State({
		name = "dormant",
		tags = { "idle" },

		onenter = function(inst)
			SGCommon.Fns.PlayAnimOnAllLayers(inst, "dormant", true)
			inst.components.bloomer:PopBloom("prop_autogen")
		end,

		events =
		{
			EventHandler("dormant_stop", function(inst)
				inst.sg:GoToState("dormant_to_idle")
			end),
		},
	}),

	State({
		name = "dormant_to_idle",
		tags = { "idle" },

		onenter = function(inst)
			local duration = .25
			inst.sg:SetTimeout(duration)
			inst.components.bloomer:PushFadingBloom(ease.linear, duration, "prop_autogen", bloom_r, bloom_g, bloom_b, bloom_a)
		end,

		ontimeout = function(inst)
			inst.sg.statemem.can_transition = true
		end,

		events =
		{
			EventHandler("animover", function(inst)
				if inst.sg.statemem.can_transition then
					inst.sg:GoToState("idle")
				end
			end),
		},
	}),

	State({
		name = "stab_pre",
		tags = { "attack", "busy" },

		onenter = function(inst, target)
			SGCommon.Fns.PlayAnimOnAllLayers(inst, "shoot_pre")
		end,

		events =
		{
			EventHandler("animover", function(inst)
				inst.sg:GoToState("stab_hold")
			end),
		},
	}),

	State({
		name = "stab_hold",
		tags = { "attack", "busy" },

		onenter = function(inst, target)
			SGCommon.Fns.PlayAnimOnAllLayers(inst, "shoot_hold", true)
			inst.sg:SetTimeoutAnimFrames(WARNING_FRAMES)

			--sound
			local is_player_in_trap, is_local_player_in_trap = IsAPlayerInTheTrap(inst)
			local params = {}
			params.fmodevent = fmodtable.Event.Trap_Weed_Spikes_hold
			inst.sg.statemem.warning_sound = soundutil.PlaySoundData(inst, params)
			soundutil.SetLocalInstanceParameter(inst, inst.sg.statemem.warning_sound, "isInTrap", is_player_in_trap and 1 or 0)
			soundutil.SetLocalInstanceParameter(inst, inst.sg.statemem.warning_sound, "isLocalPlayerInTrap", is_local_player_in_trap and 1 or 0)
		end,

		onupdate = function(inst)
			-- sound
			if inst.sg.statemem.warning_sound then
				local is_player_in_trap, is_local_player_in_trap = IsAPlayerInTheTrap(inst)
				soundutil.SetLocalInstanceParameter(inst, inst.sg.statemem.warning_sound, "isInTrap", is_player_in_trap and 1 or 0)
				soundutil.SetLocalInstanceParameter(inst, inst.sg.statemem.warning_sound, "isLocalPlayerInTrap", is_local_player_in_trap and 1 or 0)
			end

			if WARNING_FRAMES * ANIM_FRAMES - inst.sg:GetTicksInState() == 14 then
				SGCommon.Fns.FlickerColor(inst, TUNING.FLICKERS.SPIKE_WARNING.COLOR, TUNING.FLICKERS.SPIKE_WARNING.FLICKERS, TUNING.FLICKERS.SPIKE_WARNING.FADE, TUNING.FLICKERS.SPIKE_WARNING.TWEENS)
			end
		end,

		events =
		{
		},

		ontimeout = function(inst)
			inst.sg:GoToState("stab")
		end,
	}),


	State({
		name = "stab",
		tags = { "attack", "busy" },

		onenter = function(inst, target)
			SGCommon.Fns.PlayAnimOnAllLayers(inst, "shoot")
			--sound
			local is_player_in_trap, is_local_player_in_trap = IsAPlayerInTheTrap(inst)
			local params = {}
			params.fmodevent = fmodtable.Event.Trap_Weed_Spikes_shoot
			inst.sg.statemem.stab_sound = soundutil.PlaySoundData(inst, params)
			soundutil.SetLocalInstanceParameter(inst, inst.sg.statemem.stab_sound, "isInTrap", is_player_in_trap and 1 or 0)
			soundutil.SetLocalInstanceParameter(inst, inst.sg.statemem.stab_sound, "isLocalPlayerInTrap", is_local_player_in_trap and 1 or 0)
		end,

		timeline =
		{
			FrameEvent(3, function(inst)
				inst.components.hitbox:StartRepeatTargetDelay()
				inst.components.hitbox:PushBeam(-1.4, 1.4, 1.6, HitPriority.MOB_DEFAULT)
			end),
			FrameEvent(4, function(inst)
				inst.components.hitbox:PushBeam(-1.4, 1.4, 1.6, HitPriority.MOB_DEFAULT)
			end),
			-- FrameEvent(5, function(inst)
			-- 	inst.components.hitbox:PushBeam(-1.6, 1.6, 1.6, HitPriority.MOB_DEFAULT)
			-- end),
			FrameEvent(19, function(inst)
				inst.sg:RemoveStateTag("busy")
			end),
		},

		events =
		{
			EventHandler("hitboxtriggered", OnTrapHitBoxTriggered),
			EventHandler("animover", function(inst)
				if inst.sg.mem.dormant then
					inst.sg:GoToState("dormant")
				else
					inst.sg:GoToState("idle")
				end
			end),
		},

		onexit = function(inst)
			inst.components.hitbox:StopRepeatTargetDelay()
			inst.components.combat:StartCooldown(COOLDOWN_TIME)
		end,
	}),
}

return StateGraph("sg_trap_spike", states, events, "idle")
