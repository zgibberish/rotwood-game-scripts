local EffectEvents = require "effectevents"
local SGCommon = require "stategraphs.sg_common"
local soundutil = require "util.soundutil"
local fmodtable = require "defs.sound.fmodtable"

-- storing these values here for now, likely will move into trap.lua though
local KNOCKBACK_DISTANCE = 1.5
local HITSTUN = 4              -- anim frames
local WARNING_LOOPS = 3
local SCORCH_MARK_SECONDS = 0  --set to 0 to stay active forever, set to 1 to slowly fade out
local HIT_TRAIL_LIFETIME = 2.5 --seconds
local TRAP_DAMAGE_RADIUS = 6.5

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

local function CreateHitTrail(target, effectName, attachSymbol)
	local pfx = SpawnPrefab(effectName, target)
	pfx.entity:SetParent(target.entity)
	pfx.entity:AddFollower()
	if attachSymbol then
		pfx.Follower:FollowSymbol(target.GUID, attachSymbol)
	end

	pfx.OnTimerDone = function(source, data)
		if source == pfx and data ~= nil and data.name == "hitexpiry" then
			source.components.particlesystem:StopAndNotify()
		end
	end

	pfx.OnParticlesDone = function(source, data)
		if source == pfx then
			local parent = source.entity:GetParent()
			if parent and parent.hitTrailEntity == source then
				-- clear the entry if it is us, otherwise leave it alone
				-- another trail may have started while waiting for the emitter to stop
				parent.hitTrailEntity = nil
			end
			source:Remove()
		end
	end

	pfx:ListenForEvent("timerdone", pfx.OnTimerDone)
	pfx:ListenForEvent("particles_stopcomplete", pfx.OnParticlesDone)

	local timer = pfx:AddComponent("timer")
	timer:StartTimer("hitexpiry", HIT_TRAIL_LIFETIME)
end

local function OnExplodeHitBoxTriggered(inst, data)
	SGCommon.Events.OnHitboxTriggered(inst, data, {
		hitstoplevel = HitStopLevel.HEAVIER,
		set_dir_angle_to_target = true,
		player_damage_mod = TUNING.TRAPS.DAMAGE_TO_PLAYER_MULTIPLIER,
		pushback = KNOCKBACK_DISTANCE,
		hitstun_anim_frames = HITSTUN,
		combat_attack_fn = "DoKnockdownAttack",
		hit_fx = "hits_bomb",
		hit_fx_offset_x = 0.5,
		hit_target_pre_fn = function(attacker, v)
			if v.entity:HasTag("player") then
				if v:IsLocal() then -- Only spawn the hurt_explosion for local players
					TheDungeon.HUD.effects.hurt_explosion:StartOneShot()
				end

				local createHitTrail = false
				if not v.hitTrailEntity or not v.hitTrailEntity:IsValid() then
					createHitTrail = true
				else
					local timer = v.hitTrailEntity.components.timer
					if timer:GetTimeRemaining() > 0 then
						timer:SetTimeRemaining("hitexpiry", HIT_TRAIL_LIFETIME)
					else
						-- handle corner case of timer finished but emitter has not stopped
						-- just forget about it and create a new trail entity
						createHitTrail = true
					end
				end

				if createHitTrail then
					v.hitTrailEntity = CreateHitTrail(v, "bomb_hit_trail", "weapon_back01")
				end
			end
		end,
		hit_target_pst_fn = function(attacker, v)
			local hit_ground = SpawnHitFx("hits_bomb_ground", attacker, v, 0, 0, nil, HitStopLevel.HEAVIER)
			if hit_ground then
				hit_ground.AnimState:SetScale(0.25, 0.25)
			end
		end,
	})
end

local events =
{
	EventHandler("attacked", function(inst, data)
		if inst.sg:GetCurrentState() == "idle"
		-- Explosive traps don't go dormant since player has to hit them to trigger.
		--~ and not inst.sg.mem.dormant
		then
			--[[

			This is for networking purposes:
			This bomb is a networked entity by default, but when it is triggered we create a local version of it on every player's machine, as a
			non-networked entity.

			We will remove THIS bomb after hitstop is over to create some visual overlap in case of latency.

			--]]

			-- Then, we flag this bomb to be removed after hitstop so the other local bomb takes its place. After hitstop, it will be replaced with a new local entity.

			inst.sg.mem.removeafterhitstop = true
			inst.sg:GoToState("hit", data)
		end
	end),
}


local states =
{
	State({
		name = "idle",
		tags = { "idle" },

		onenter = function(inst)
			SGCommon.Fns.PlayAnimOnAllLayers(inst, "idle", true)
		end,
	}),

	State({
		name = "hit",
		tags = { "hit", "busy" },

		onenter = function(inst, data)
			SGCommon.Fns.PlayAnimOnAllLayers(inst, "hit_hold")
			inst.sg:SetTimeoutAnimFrames(data.attack:GetHitstunAnimFrames() or 0)

			if inst.components.hitshudder then
				inst.components.hitshudder:DoShudder(TUNING.HITSHUDDER_AMOUNT_LIGHT, data.attack:GetHitstunAnimFrames())
			end
		end,


		onexit = function(inst)
			if inst.components.hitshudder then
				inst.components.hitshudder:Stop()
			end
		end,

		ontimeout = function(inst)
			-- If this was a networked entity primed for replacement for the local version, remove it. Otherwise, we know it's the 'good' bomb so it should live.
			if inst.sg.mem.removeafterhitstop then
				-- Here, we spawn the local-only bomb and send it to the hit_pst state to take over for this one
				EffectEvents.MakeEventSpawnLocalEntity(inst, "trap_bomb_pinecone", "hit_pst")
				inst:DelayedRemove()

				-- NETWORKING: if there is a visual "seam" between the two when latency is present, try hiding the transition during the hitstop frames
				-- make sure you do these, so this doesn't stick around as an interactable object. NetworkBomb should only be around as an anim.
				-- inst.HitBox:SetEnabled(false)
				-- inst.Physics:SetEnabled(false)
			else
				inst.sg:GoToState("hit_pst")
			end
		end,
	}),

	State({
		name = "hit_pst",
		tags = { "hit", "busy" },

		onenter = function(inst, front)
			SGCommon.Fns.PlayAnimOnAllLayers(inst, "hit_pst")
		end,

		timeline =
		{
			FrameEvent(0, function(inst) inst.sg:RemoveStateTag("busy") end),
		},

		events =
		{
			EventHandler("animover", function(inst)
				inst.sg:GoToState("explode_pre")
			end),
		},
	}),


	State({
		name = "explode_pre",
		tags = { "attack", "busy" },

		onenter = function(inst, target)
			SGCommon.Fns.PlayAnimOnAllLayers(inst, "explode_pre")
		end,

		timeline =
		{

		},

		events =
		{
			EventHandler("animover", function(inst)
				inst.sg:GoToState("explode_hold")
			end),
		},
	}),

	State({
		name = "explode_hold",
		tags = { "attack", "busy" },

		onenter = function(inst, target)
			SGCommon.Fns.PlayAnimOnAllLayers(inst, "explode_hold", true)
			inst.sg.statemem.warningfx = SGCommon.Fns.SpawnAtDist(inst, "bomb_explosion_warning", 0)
			inst.sg.statemem.warninganimlengthticks = inst.sg.statemem.warningfx.AnimState:GetCurrentAnimationNumFrames() *
				ANIM_FRAMES
			inst.sg.statemem.warningticks = inst.sg.statemem.warninganimlengthticks * WARNING_LOOPS

			inst.sg:SetTimeoutTicks(inst.sg.statemem.warningticks)
		end,

		onupdate = function(inst)
			-- sound
			local is_player_in_trap, is_local_player_in_trap = IsAPlayerInTheTrap(inst)
			if inst.sg.statemem.warning_sound then
				soundutil.SetLocalInstanceParameter(inst, inst.sg.statemem.warning_sound, "isInTrap", is_player_in_trap and 1 or 0)
				-- doesn't matter that we're evaluating this using networked sound code because the bomb itself is local, so everyone evaluates this
				soundutil.SetLocalInstanceParameter(inst, inst.sg.statemem.warning_sound, "isLocalPlayerInTrap", is_local_player_in_trap and 1 or 0)
			end

			if inst.sg.ticksinstate % inst.sg.statemem.warninganimlengthticks == 0 then
				inst.sg.statemem.currentwarningloop = inst.sg.statemem.currentwarningloop == nil and 1 or
					inst.sg.statemem.currentwarningloop + 1
				local r, g, b, a = table.unpack(TUNING.TRAPS.trap_exploding.WARNING_COLORS
					[inst.sg.statemem.currentwarningloop])
				inst.sg.statemem.warningfx.components.coloradder:PushColor("warning_colors", r, g, b, a)

				--sound
				local params = {}
				params.fmodevent = fmodtable.Event.pinecone_bomb_traps_warning
				inst.sg.statemem.warning_sound = soundutil.PlaySoundData(inst, params)
				soundutil.SetLocalInstanceParameter(inst, inst.sg.statemem.warning_sound, "Count", inst.sg.statemem.currentwarningloop)
				soundutil.SetLocalInstanceParameter(inst, inst.sg.statemem.warning_sound, "isInTrap", is_player_in_trap and 1 or 0)
				soundutil.SetLocalInstanceParameter(inst, inst.sg.statemem.warning_sound, "isLocalPlayerInTrap", is_local_player_in_trap and 1 or 0)

				-- jambell: an idea, make a reverse version of this function to fade INTO white right before the bomb explodes
				if inst.sg.statemem.currentwarningloop == WARNING_LOOPS then
					SGCommon.Fns.FlickerColor(inst, TUNING.FLICKERS.BOMB_WARNING.COLOR,
						TUNING.FLICKERS.BOMB_WARNING.FLICKERS, TUNING.FLICKERS.BOMB_WARNING.FADE,
						TUNING.FLICKERS.BOMB_WARNING.TWEENS)
				end
			end
		end,

		onexit = function(inst, target)
		end,

		events =
		{
		},

		ontimeout = function(inst)
			SGCommon.Fns.DestroyFx(inst, "warningfx")
			inst.sg:GoToState("explode")
		end,
	}),

	State({
		name = "explode",
		tags = { "attack", "busy" },

		onenter = function(inst)
			SGCommon.Fns.PlayAnimOnAllLayers(inst, "explode")
			SGCommon.Fns.SpawnAtDist(inst, "bomb_explosion", 0)
			SGCommon.Fns.SpawnAtDist(inst, "bomb_explosion_ground", 0)
			inst.sg.mem.scorchmark = SGCommon.Fns.SpawnAtDist(inst, "bomb_explosion_scorch_mark", 0)

			--sound
			local is_player_in_trap, is_local_player_in_trap = IsAPlayerInTheTrap(inst)
			local params = {}
			params.fmodevent = fmodtable.Event.pinecone_bomb_traps_explode
			params.autostop = false
			local explosion_sound = soundutil.PlaySoundData(inst, params)
			soundutil.SetLocalInstanceParameter(inst, explosion_sound, "isInTrap", is_player_in_trap and 1 or 0)
			soundutil.SetLocalInstanceParameter(inst, explosion_sound, "isLocalPlayerInTrap", is_local_player_in_trap and 1 or 0)
		end,

		timeline =
		{
			FrameEvent(2, function(inst)
				inst.Physics:SetEnabled(false)
				inst.HitBox:SetEnabled(false)
				inst.components.hitbox:StartRepeatTargetDelay()
				inst.components.hitbox:PushCircle(0, 0, TRAP_DAMAGE_RADIUS, HitPriority.MOB_DEFAULT)
			end),
			FrameEvent(3, function(inst)
				-- Bombs that explode on land should have less active frames
				if not inst.sg.statemem.explodeonland then
					inst.components.hitbox:PushCircle(0, 0, TRAP_DAMAGE_RADIUS, HitPriority.MOB_DEFAULT)
				end
			end),
			FrameEvent(4, function(inst)
				if not inst.sg.statemem.explodeonland then
					inst.components.hitbox:PushCircle(0, 0, TRAP_DAMAGE_RADIUS, HitPriority.MOB_DEFAULT)
				end
			end),
			FrameEvent(5, function(inst)
				if not inst.sg.statemem.explodeonland then
					inst.components.hitbox:PushCircle(0, 0, TRAP_DAMAGE_RADIUS, HitPriority.MOB_DEFAULT)
				end
			end),
			FrameEvent(6, function(inst)
				if not inst.sg.statemem.explodeonland then
					inst.components.hitbox:PushCircle(0, 0, TRAP_DAMAGE_RADIUS, HitPriority.MOB_DEFAULT)
				end
			end),
			FrameEvent(7, function(inst)
				if not inst.sg.statemem.explodeonland then
					inst.components.hitbox:PushCircle(0, 0, TRAP_DAMAGE_RADIUS, HitPriority.MOB_DEFAULT)
				end
			end),
		},

		events =
		{
			EventHandler("hitboxtriggered", OnExplodeHitBoxTriggered),
			EventHandler("animover", function(inst)
				inst.sg:GoToState("exploded")
			end),
		},
	}),

	State({
		name = "exploded",
		tags = {},

		onenter = function(inst)
			if SCORCH_MARK_SECONDS > 0 then
				inst.sg:SetTimeoutAnimFrames(SCORCH_MARK_SECONDS * 30)
			end
		end,

		timeline =
		{
		},

		events =
		{
		},

		ontimeout = function(inst)
			inst.sg:GoToState("scorch_mark_fade")
		end,
	}),


	State({
		name = "scorch_mark_fade",
		tags = {},

		onenter = function(inst)
			inst.sg.mem.scorchmark.AnimState:PlayAnimation("scorch_mark_fade")
			inst.sg.statemem.fadeanimframes = inst.sg.mem.scorchmark.AnimState:GetCurrentAnimationNumFrames()
			inst.sg:SetTimeoutAnimFrames(inst.sg.statemem.fadeanimframes)
		end,

		timeline =
		{
		},

		events =
		{
		},

		ontimeout = function(inst)
			inst.sg.mem.scorchmark:Remove()
			inst:Remove()
		end,
	}),
}

return StateGraph("sg_trap_exploding", states, events, "idle")
