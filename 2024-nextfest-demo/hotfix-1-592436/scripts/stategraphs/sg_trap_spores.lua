local SGCommon = require "stategraphs.sg_common"
local Power = require "defs.powers"
local ParticleSystemHelper = require "util.particlesystemhelper"
local EffectEvents = require "effectevents"

local WARN_FAR_DISTANCE = 7 -- how close do we have to be to trigger the warning?
local WARN_MEDIUM_DISTANCE = 5 -- how close do we have to be to trigger the warning?
local WARN_CLOSE_DISTANCE = 4 -- how close do we have to be to trigger the warning?
local TRIGGER_DISTANCE = 2.5 -- how close do we have to be to trigger the actual burst?

local KNOCKBACK_DISTANCE = 0.25
local HITSTUN = 4 -- anim frames

local function OnIdleHitBoxTriggered(inst, data)
	-- Spore is idle -- should it transition to warn phase?
	local should_warn = false
	for i=1,#data.targets do
		local v = data.targets[i]
		if v:HasTag("player") then
			should_warn = true
			break
		end
	end

	if should_warn then
		inst.sg:GoToState("warn")
	end
end

local function ShouldSpawnGroak(inst)
	return inst.sporedata and inst.sporedata.power == "override" and inst.sporedata.override_effect == "summon_groak"
end

local function SpawnGroak(inst)
	-- If the room is complete, explode like the spore you are decoying.
	-- If the room is not complete, spawn a groak.
	if inst.sg.mem.is_room_clear then
		inst.override_sporedata = inst.roomcleared_trapdata
		inst.sg:GoToState("gotoexplode")
	else
		inst.sg:GoToState("spawn_groak")
	end
end

local function OnWarnHitBoxTriggered(inst, data)
	-- Spore is warning -- should it transition to exploding, or possibly leave the warning phase?

	local should_burst = false
	local keep_warning = false -- By default, stop warning unless we successfully find some stuff
	for i=1,#data.targets do
		local v = data.targets[i]
		if not v:HasTag("player") then
			return
		end
		local dist = inst:GetDistanceSqTo(v)
		dist = math.sqrt(dist)
		if dist <= TRIGGER_DISTANCE then
			should_burst = true
			keep_warning = true
			break
		elseif dist <= WARN_CLOSE_DISTANCE then
			inst.sg.statemem.warn_anim = "warning_close"
			keep_warning = true
		elseif dist <= WARN_MEDIUM_DISTANCE then
			inst.sg.statemem.warn_anim = "warning_med"
			keep_warning = true
		else
			inst.sg.statemem.warn_anim = "warning_med"
			keep_warning = true
		end
	end

	if should_burst then
		-- Summoning Groak
		if ShouldSpawnGroak(inst) then
			SpawnGroak(inst)
		else
			inst.sg:GoToState("gotoexplode")
		end
	end

	inst.sg.statemem.keepwarning = keep_warning
end

local function OnExplodeHitBoxTriggered(inst, data)
	local disable_hit_reaction = inst.sporedata ~= nil and inst.sporedata.disable_hit_reaction or false

	-- If we are a groak trap, but the room is cleared, then use the trapdata from the trap we are decoying.
	if inst.override_sporedata ~= nil then
		inst.sporedata = inst.override_sporedata
	end

	SGCommon.Events.OnHitboxTriggered(inst, data, {
		hitstoplevel = disable_hit_reaction and 0 or HitStopLevel.HEAVIER,
		set_dir_angle_to_target = true,
		player_damage_mod = TUNING.TRAPS.DAMAGE_TO_PLAYER_MULTIPLIER,
		pushback = KNOCKBACK_DISTANCE,
		hitstun_anim_frames = disable_hit_reaction and 0 or HITSTUN,
		disable_damage_number = true,
		disable_hit_reaction = disable_hit_reaction,
		disable_self_hitstop = true,
		combat_attack_fn = "DoKnockbackAttack",
		hit_fx = nil,
		hit_fx_offset_x = 0.5,
		hit_target_pre_fn = function(attacker, v)
			local applied = false -- Whether or not we should play a "burst" FX on [v] to show it got tagged.
			if attacker.sporedata.power ~= "override" then
				-- Normal traps that apply a Power
				local pm = v.components.powermanager
				if pm ~= nil then
					local def = Power.FindPowerByName(attacker.sporedata.power)
					-- If they already have the power, only try to add more if it's a stackable power
					if pm:HasPower(def) then
						if def.stackable then
							pm:DeltaPowerStacks(def, attacker.sporedata.stacks)
							applied = true
						end
					-- If they don't already have it, then add a new instance.
					else
						pm:AddPowerByName(attacker.sporedata.power, attacker.sporedata.stacks)
						applied = true
					end
				end
			else
				-- Spore traps that don't apply a power, but instead do something else.
				if attacker.sporedata.override_effect == "damage" then
					local is_player = v:HasTag("player")
					local damage = TUNING.TRAPS.trap_spores.DAMAGE_VERSION_BASE_DAMAGE
					if is_player then
						damage = damage * TUNING.TRAPS.DAMAGE_TO_PLAYER_MULTIPLIER
					end

					local spore_attack = Attack(attacker, v)
					spore_attack:SetDamage(damage)
					-- spore_attack:SetIgnoresArmour(true) -- Do other traps ignore armour?
					attacker.components.combat:DoPowerAttack(spore_attack) -- Setup as a power_attack because we're already doing a Knockback Attack by default.
					applied = true
				elseif attacker.sporedata.override_effect == "heal" then
					local is_player = v:HasTag("player")
					local heal = TUNING.TRAPS.trap_spores.DAMAGE_VERSION_BASE_DAMAGE
					if is_player then
						if not v:IsAlive() then
							return
						end
						heal = heal * TUNING.TRAPS.DAMAGE_TO_PLAYER_MULTIPLIER
					end

					local spore_heal = Attack(attacker, v)
					spore_heal:SetHeal(heal)
					attacker.components.combat:ApplyHeal(spore_heal)

					applied = true
				end
			end

			-- If it successfully connected with the target, play the effect.
			if applied and attacker.sporedata.target_fx ~= nil then
				ParticleSystemHelper.MakeOneShotAtPosition(v:GetPosition(), attacker.sporedata.target_fx)
			end
		end,
	})
end

local events =
{
	EventHandler("attacked", function(inst, data)
		if ShouldSpawnGroak(inst) then
			SpawnGroak(inst)
		-- Don't go back into the 'hit' state if we're already being hit
		elseif inst.sg:HasStateTag("idle") then
			inst.sg:GoToState("hit", data)
		end
	end),
}

local GROW_TIME = 1
local function Grow(inst)
	local scale = math.min(inst.sg:GetTimeInState() / GROW_TIME, 1)
	inst.Transform:SetScale(scale, scale, scale)

	-- Grown to max, go to next state
	if scale >= GROW_TIME then
		inst.sg:GoToState("idle")
	else
		inst:DoTaskInAnimFrames(1, Grow)
	end
end

local function OnRoomComplete(inst)
	inst.sg.mem.is_room_clear = true
end

local states =
{
	State({
		name = "init",
		onenter = function(inst)
			-- Get all the data for this trap from the varieties table above
			-- e.g. power name, stacks, fx, etc
			if inst.prefab == "trap_spores_groak" then
				inst:ListenForEvent("room_complete", function() OnRoomComplete(inst) end, TheWorld)
				inst:DoTaskInTicks(0, function(inst)
					local x, z = inst.Transform:GetWorldXZ()
					local traps = TheSim:FindEntitiesXZ(x, z, 10000, nil, {"INLIMBO"}, {"trap"})

					for i,trap in ipairs(traps) do
						if trap.prefab ~= inst.prefab then
							inst.baseanim = trap.baseanim
							inst.roomcleared_trapdata = trap.sporedata -- What trapdata should we use if the room is already clear? Don't spawn a groak, just do the other effect.
							break
						end
					end

					-- Because of the next tick delay processing here, when a local entity is spawned on exploding, we need to prevent entering back into idle upon spawning.
					if not inst.sg:HasStateTag("exploding") then
						inst.sg:GoToState("idle")
					end
				end)
			else
				-- All other spores, just go to idle now.
				inst.sg:GoToState("idle")
			end
		end,
	}),

	State({
		name = "grow",
		tags = { "idle" },

		onenter = function(inst)
			inst.Transform:SetScale(0, 0, 0)
			inst:DoTaskInAnimFrames(1, Grow)
		end,
	}),

	State({
		name = "idle",
		tags = { "idle" },

		onenter = function(inst)
			SGCommon.Fns.PlayAnimOnAllLayers(inst, "idle", true)
			if inst.components.hitbox ~= nil then
				inst.components.hitbox:SetUtilityHitbox(true)
			end
		end,

		onupdate = function(inst)
			if inst.components.hitbox ~= nil then
				inst.components.hitbox:PushCircle(0, 0, WARN_FAR_DISTANCE, HitPriority.MOB_DEFAULT)
			end
		end,

		events =
		{
			EventHandler("hitboxtriggered", OnIdleHitBoxTriggered),
		},
	}),

	State({
		name = "warn",
		tags = { "idle" },

		onenter = function(inst)
			-- This happens locally for the host, ALWAYS remote for everyone else.
			SGCommon.Fns.PlayAnimOnAllLayers(inst, "warning_med", true)
			inst.sg.statemem.current_anim = "warning_med"
			inst.sg.statemem.warn_anim = "warning_med"

			-- These are updated in the OnWarnHitBoxTriggered, based on distance to nearest target.
			inst.components.hitbox:SetUtilityHitbox(true)
		end,

		onupdate = function(inst)
			inst.components.hitbox:PushCircle(0, 0, WARN_FAR_DISTANCE, HitPriority.MOB_DEFAULT)

			if inst.sg.statemem.current_anim ~= inst.sg.statemem.warn_anim then
				SGCommon.Fns.PlayAnimOnAllLayers(inst, inst.sg.statemem.warn_anim, true)
				inst.sg.statemem.current_anim = inst.sg.statemem.warn_anim
			end
		end,

		timeline =
		{
			FrameEvent(9, function(inst)
				if not inst.sg.statemem.keepwarning then
					inst.sg:GoToState("idle")
				end
				inst.sg.statemem.keepwarning = false
			end),
		},

		events =
		{
			EventHandler("hitboxtriggered", OnWarnHitBoxTriggered),
			EventHandler("animover", function(inst)
				if not inst.sg.statemem.keepwarning then
					inst.sg:GoToState("idle")
				end
				inst.sg.statemem.keepwarning = false
			end)
		},
	}),

	State({
		name = "hit",
		tags = { "hit", "busy" },

		onenter = function(inst, data)
			SGCommon.Fns.PlayAnimOnAllLayers(inst, "hit_hold")
			inst.sg:SetTimeoutAnimFrames(data and data.attack:GetHitstunAnimFrames() or 0)

		end,

		ontimeout = function(inst)
			inst.sg:GoToState("gotoexplode")
		end,
	}),

	State({
		name = "gotoexplode",
		tags = { "hit", "busy" },

		onenter = function(inst, data)
			-- Here, we spawn the local-only spore and send directly it to the explode_pre state to take over for this one
			EffectEvents.MakeEventSpawnLocalEntity(inst, inst.prefab, "explode_pre") -- NETWORK: replace this networked version with a local version on all machines
			inst:DelayedRemove()
		end,
	}),

	State({
		name = "explode_pre",
		tags = { "attack", "busy", "exploding" },

		onenter = function(inst, target)
			SGCommon.Fns.PlayAnimOnAllLayers(inst, "explode_pre")
		end,

		timeline =
		{

		},

		events =
		{
			EventHandler("animover", function(inst)
				inst.sg:GoToState("explode")
			end),
		},
	}),

	State({
		name = "explode",
		tags = { "attack", "busy", "exploding" },

		onenter = function(inst)
			-- This ALWAYS happens locally.
			SGCommon.Fns.PlayAnimOnAllLayers(inst, "explode")
			local burst_fx = inst.sporedata ~= nil and inst.sporedata.burst_fx or "fx_spores_burst_all"
			SGCommon.Fns.SpawnAtDist(inst, burst_fx, 0)
			inst.components.hitbox:SetUtilityHitbox(false)
		end,

		timeline =
		{
			FrameEvent(2, function(inst)
				inst.Physics:SetEnabled(false)
				inst.HitBox:SetEnabled(false)
				inst:Hide()
				inst.components.hitbox:StartRepeatTargetDelay()
				inst.components.hitbox:PushCircle(0, 0, 2.5, HitPriority.MOB_DEFAULT)
			end),
			FrameEvent(3, function(inst)
				if not inst.sg.statemem.explodeonland then
					inst.components.hitbox:PushCircle(0, 0, 3.5, HitPriority.MOB_DEFAULT)
				end
			end),
			FrameEvent(4, function(inst)
				if not inst.sg.statemem.explodeonland then
					inst.components.hitbox:PushCircle(0, 0, 3.5, HitPriority.MOB_DEFAULT)
				end
			end),
			FrameEvent(5, function(inst)
				if not inst.sg.statemem.explodeonland then
					inst.components.hitbox:PushCircle(0, 0, 3.5, HitPriority.MOB_DEFAULT)
				end
			end),
			FrameEvent(6, function(inst)
				if not inst.sg.statemem.explodeonland then
					inst.components.hitbox:PushCircle(0, 0, 3.5, HitPriority.MOB_DEFAULT)
				end
			end),
			FrameEvent(7, function(inst)
				if not inst.sg.statemem.explodeonland then
					inst.components.hitbox:PushCircle(0, 0, 3.5, HitPriority.MOB_DEFAULT)
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
		tags = { },

		onenter = function(inst)
			if inst ~= nil and inst:IsValid() then
				inst:Remove()
			end
		end,

		timeline =
		{
		},

		events =
		{
		},

		ontimeout = function(inst)
		end,
	}),

	State({
		name = "spawn_groak",
		tags = { },

		onenter = function(inst)
			SGCommon.Fns.PlayAnimOnAllLayers(inst, "explode_pre")
			inst.sg:SetTimeout(0.5)
			ShakeAllCameras(CAMERASHAKE.VERTICAL, 0.5, 0.02, 0.5)
		end,

		ontimeout = function(inst)
			local x, z = inst.Transform:GetWorldXZ()
			-- Possibly turn into elite if playing in a frenzy level.
			-- retruns either "groak" or "groak_elite"
			local prefab_id = TheWorld.components.spawncoordinator:_MakeEnemyElite("groak")
			local groak = SpawnPrefab(prefab_id)
			groak.Transform:SetPosition(x, 0, z)
			groak.sg:GoToState("spawn_pre")

			inst:Remove()
		end,
	}),
}

return StateGraph("sg_trap_exploding", states, events, "init")
