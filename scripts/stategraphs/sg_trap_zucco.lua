local EffectEvents = require "effectevents"

local TRAP_WARNING_FRAMES = 15
local TRAP_TRIGGER_RADIUS = 1.8
local TRAP_DAMAGE_RADIUS = 4
local KNOCKBACK_DISTANCE = 1.2
local HITSTUN = 10 -- anim frames

local SGCommon = require "stategraphs.sg_common"

local monsterutil = require "util.monsterutil"

local soundutil = require "util.soundutil"
local fmodtable = require "defs.sound.fmodtable"

local function IsAPlayerInTheTrap(inst)
	local is_player_in_trap
	local is_local_player_in_trap
	for k, player in pairs(AllPlayers) do
		if player:IsAlive() then
			local dist = inst:GetDistanceSqTo(player) / 10
			if dist + 2 <= (TRAP_DAMAGE_RADIUS) then
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
		inst.sg:GoToState("explode_prepare")
	end
end

local function OnExplodeHitBoxTriggered(inst, data)
	SGCommon.Events.OnHitboxTriggered(inst, data, {
		hitstoplevel = HitStopLevel.HEAVIER,
		player_damage_mod = TUNING.TRAPS.DAMAGE_TO_PLAYER_MULTIPLIER,
		set_dir_angle_to_target = true,
		pushback = KNOCKBACK_DISTANCE,
		hitstun_anim_frames = HITSTUN,
		combat_attack_fn = "DoKnockdownAttack",
		hit_fx = monsterutil.defaultAttackHitFX,
	})
end

local events =
{
	EventHandler("spawn", function(inst)
		inst:AddTag("trap_zucco")
		if not inst.sg:HasStateTag("busy") then
			inst.sg:GoToState("spawn")
		end
	end),
}

local states =
{
	State({
		name = "spawn",
		tags = { "busy" },

		onenter = function(inst)
			SGCommon.Fns.PlayAnimOnAllLayers(inst, "spawn")
		end,

		events =
		{
			EventHandler("animover", function(inst) inst.sg:GoToState("idle") end),
		}
	}),

	State({
		name = "idle",
		tags = { "idle" },

		onenter = function(inst)
			SGCommon.Fns.PlayAnimOnAllLayers(inst, "idle", true)
		end,

		onupdate = function(inst)
			inst.components.hitbox:PushCircle(0, 0, TRAP_TRIGGER_RADIUS, HitPriority.MOB_DEFAULT)
		end,

		events =
		{
			EventHandler("hitboxtriggered", OnProximityHitBoxTriggered),
			EventHandler("dormant_start", function(inst)
				-- Do this immediately rather than on animover so we can be in
				-- sync with the rest of the 'room clear' visuals.
				inst.sg:GoToState("dormant")
			end),
		},
	}),

	State({
		name = "dormant_pre",
		tags = { "busy" },

		onenter = function(inst)
			SGCommon.Fns.PlayAnimOnAllLayers(inst, "dormant_pre")
			inst.components.bloomer:PopBloom("prop_autogen")
		end,

		events =
		{
			EventHandler("animover", function(inst)
				if inst.sg.mem.dormant then
					inst.sg:GoToState("dormant")
				else
					inst.sg:GoToState("idle")
				end
			end),
		}
	}),

	State({
		name = "dormant",
		tags = { "idle" },

		onenter = function(inst)
			SGCommon.Fns.PlayAnimOnAllLayers(inst, "dormant", true)
		end,

		events =
		{
			EventHandler("dormant_stop", function(inst)
				-- TODO: We need to turn bloom back on somehow.
				inst.sg:GoToState("idle")
			end),
		},
	}),

	State({
		name = "explode_prepare",
		tags = { "busy" },

		onenter = function(inst)
			-- Here, we spawn the local-only bomb and send it to the explode_pre state to take over for this one
			EffectEvents.MakeEventSpawnLocalEntity(inst, "trap_zucco", "explode_pre")
			inst:DelayedRemove()
		end,

		events =
		{
		}
	}),

	State({
		name = "explode_pre",
		tags = { "busy" },

		onenter = function(inst)
			SGCommon.Fns.PlayAnimOnAllLayers(inst, "explode_pre")

			--sound
			local is_player_in_trap, is_local_player_in_trap = IsAPlayerInTheTrap(inst)
			local params = {}
			params.fmodevent = fmodtable.Event.zucco_trap_pre
			inst.sg.mem.warning_sound = soundutil.PlaySoundData(inst, params)
			soundutil.SetLocalInstanceParameter(inst, inst.sg.mem.warning_sound, "isInTrap", is_player_in_trap and 1 or 0)
			soundutil.SetLocalInstanceParameter(inst, inst.sg.mem.warning_sound, "isLocalPlayerInTrap", is_local_player_in_trap and 1 or 0)
		end,

		events =
		{
			EventHandler("animover", function(inst) inst.sg:GoToState("explode_hold") end),
		}
	}),

	State({
		name = "explode_hold",
		tags = { "busy" },

		onenter = function(inst)
			SGCommon.Fns.PlayAnimOnAllLayers(inst, "explode_hold")
			inst.sg:SetTimeoutAnimFrames(TRAP_WARNING_FRAMES)
		end,

		onupdate = function(inst)
			-- sound
			local is_player_in_trap, is_local_player_in_trap = IsAPlayerInTheTrap(inst)
			if inst.sg.mem.warning_sound then
				soundutil.SetLocalInstanceParameter(inst, inst.sg.mem.warning_sound, "isInTrap", is_player_in_trap and 1 or 0)
				soundutil.SetLocalInstanceParameter(inst, inst.sg.mem.warning_sound, "isLocalPlayerInTrap", is_local_player_in_trap and 1 or 0)
			end
		end,

		ontimeout = function(inst)
			inst.sg:GoToState("explode")
		end,
	}),

	State({
		name = "explode",
		tags = { "busy" },

		onenter = function(inst)
			SGCommon.Fns.PlayAnimOnAllLayers(inst, "explode")
			--sound
			local params = {}
			params.fmodevent = fmodtable.Event.zucco_trap_explode
			params.autostop = false
			local handle = soundutil.PlaySoundData(inst, params)
			soundutil.SetLocalInstanceParameter(inst, handle, "isInTrap", IsAPlayerInTheTrap(inst) and 1 or 0)

			if inst.owner then
				inst.owner:PushEvent("exploded", inst)
			end
		end,

		timeline =
		{
			FrameEvent(2, function(inst)
				inst.components.hitbox:StartRepeatTargetDelay()
				inst.components.hitbox:PushCircle(0, 0, TRAP_DAMAGE_RADIUS, HitPriority.MOB_DEFAULT)
			end),
			FrameEvent(3, function(inst)
				inst.components.hitbox:PushCircle(0, 0, TRAP_DAMAGE_RADIUS, HitPriority.MOB_DEFAULT)
			end),
			FrameEvent(4, function(inst)
				inst.components.hitbox:PushCircle(0, 0, TRAP_DAMAGE_RADIUS, HitPriority.MOB_DEFAULT)
			end),
			FrameEvent(5, function(inst)
				inst.components.hitbox:PushCircle(0, 0, TRAP_DAMAGE_RADIUS, HitPriority.MOB_DEFAULT)
			end),
			FrameEvent(6, function(inst)
				inst.components.hitbox:PushCircle(0, 0, TRAP_DAMAGE_RADIUS, HitPriority.MOB_DEFAULT)
			end),
			FrameEvent(7, function(inst)
				inst.components.hitbox:PushCircle(0, 0, TRAP_DAMAGE_RADIUS, HitPriority.MOB_DEFAULT)
			end),
		},

		events =
		{
			EventHandler("hitboxtriggered", OnExplodeHitBoxTriggered),
			EventHandler("animover", function(inst) inst:Remove() end),
		}
	}),

}

return StateGraph("sg_trap_zucco", states, events, "idle")
