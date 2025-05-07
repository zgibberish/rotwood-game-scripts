local EffectEvents = require "effectevents"
local SGCommon = require("stategraphs/sg_common")
local monsterutil = require "util.monsterutil"
local ParticleSystemHelper = require "util.particlesystemhelper"

local soundutil = require "util.soundutil"
local fmodtable = require "defs.sound.fmodtable"

--[[local function OnWindGustHitboxTriggered(inst, data)
	if not inst.sg.statemem.is_attack then
		return
	end

	SGCommon.Events.OnHitboxTriggered(inst, data, {
		attackdata_id = "wind_gust",
		hitstoplevel = HitStopLevel.LIGHT,
		set_dir_angle_to_target = true,
		combat_attack_fn = "DoBasicAttack",
		hitflags = Attack.HitFlags.DEFAULT,
		hit_fx = monsterutil.defaultAttackHitFX,
		hit_fx_offset_x = -5,
	})
end

local function OnEliteWindGustHitboxTriggered(inst, data)
	if not inst.sg.statemem.is_attack then
		return
	end

	SGCommon.Events.OnHitboxTriggered(inst, data, {
		attackdata_id = "elite_wind_gust",
		hitstoplevel = HitStopLevel.LIGHT,
		set_dir_angle_to_target = true,
		combat_attack_fn = "DoBasicAttack",
		hitflags = Attack.HitFlags.DEFAULT,
		hit_fx = monsterutil.defaultAttackHitFX,
		hit_fx_offset_x = -5,
	})]
end]]

local function OnDeath(inst)
	--Spawn death fx
	EffectEvents.MakeEventFXDeath(inst, nil, "death_treemon")
	--Spawn loot (lootdropper will attach hitstopper)
	inst.components.lootdropper:DropLoot()
end

local SPIKEBALL_ANGLE_VARIANCE = 20 -- +/- degrees
local SPAWN_DISTANCE = 5
local SPAWN_OFFSET_Y = 4

local NUM_SHOOT_TRAPS = 1
local ELITE_NUM_SHOOT_TRAPS = 3

local function SpawnSpikeBalls(inst)
	local target = inst.components.combat:GetTarget()
	if not target then return end -- If target doesn't exist anymore, don't shoot anything

	local spikeball = SGCommon.Fns.SpawnAtDist(inst, "owlitzer_spikeball", 0)
	if spikeball then
		spikeball:Setup(inst)

		-- If elite, after the first two spikeballs, throw them at any angle
		local angle_to_target = inst:HasTag("elite") and inst.sg.mem.shoot_loops <= ELITE_NUM_SHOOT_TRAPS - 2 and math.random() * 360 or inst:GetAngleTo(target)
		local pos = inst:GetPosition()
		spikeball.Transform:SetPosition(pos.x, pos.y + SPAWN_OFFSET_Y, pos.z)
		local angle = math.rad( angle_to_target + (math.random() - 0.5) * 2 * SPIKEBALL_ANGLE_VARIANCE )
		local target_pos = pos + Vector3(math.cos(angle), 0, -math.sin(angle)) * ((math.random() - 0.5) * 2 + SPAWN_DISTANCE)
		spikeball.sg:GoToState("thrown", target_pos)
	end
end

local events =
{
}
monsterutil.AddStationaryMonsterCommonEvents(events, { ondeath_fn = OnDeath, })

local states =
{
	State({
		name = "idle",
		tags = { "idle" },

		onenter = function(inst)
			inst.AnimState:PlayAnimation("idle", true)
			--inst.sg.statemem.loops = math.min(3, math.random(5))
		end,

		events =
		{
			--[[EventHandler("animover", function(inst)
				if inst.sg.statemem.loops > 1 then
					inst.sg.statemem.loops = inst.sg.statemem.loops - 1
				else
					inst.sg:GoToState("behavior1")
				end
			end),]]
		},
	}),

	--[[State({
		name = "behavior1",
		tags = { "idle" },

		onenter = function(inst)
			inst.AnimState:PlayAnimation("behavior1")
		end,

		events =
		{
			EventHandler("animover", function(inst)
				inst.sg:GoToState("idle")
			end),
		},
	}),]]

	State({
		name = "wind_gust",
		tags = { "attack", "busy" },

		onenter = function(inst, target)
			inst.AnimState:PlayAnimation("wind_spin")

			-- Get angle to target. Use this to calculate the direction the wind blows.
			if target then
				local angle_to_target = inst:GetAngleTo(target)
				inst.components.attackangle:SetAttackAngle(angle_to_target)
			end
		end,

		events =
		{
			--EventHandler("hitboxtriggered", OnWindGustHitboxTriggered),
			EventHandler("animover", function(inst)
				inst.sg:GoToState("idle")
			end),
		},

		timeline =
		{
			--[[FrameEvent(9, function(inst)
				inst.sg.statemem.is_attack = true
				inst.components.hitbox:PushCircle(0, 0, 3, HitPriority.BOSS_DEFAULT)
			end),]]
			FrameEvent(9, function(inst)
				--inst.sg.statemem.is_attack = false

				inst.components.hitbox:SetHitFlags(HitGroup.ALL)
				--inst.components.hitbox:StartRepeatTargetDelay()

				inst.components.auraapplyer:SetEffect("windmon_gust")
				inst.components.auraapplyer:SetRadius(12)
				inst.components.auraapplyer:Enable()

				local wind_angle = inst.components.attackangle:GetAttackAngle()

				local fx_params =
				{
					name = "windmon_wind",
					particlefxname = "windmon_wind_gust",
					ischild = true,
					use_entity_facing = true,
					stopatexitstate = true,
					angle = wind_angle,
				}

				ParticleSystemHelper.MakeEventSpawnParticles(inst, fx_params)

				inst.components.attacktracker:CompleteActiveAttack()
			end),
			FrameEvent(23, function(inst)
				inst.components.auraapplyer:Disable()
				ParticleSystemHelper.MakeEventStopParticles(inst, { name = "windmon_wind" })
			end),
		},

		onexit = function(inst)
			local hitflags = inst:HasTag("playerminion") and HitGroup.CREATURES or HitGroup.CHARACTERS
			inst.components.hitbox:SetHitFlags(hitflags)
			inst.components.auraapplyer:Disable()

			ParticleSystemHelper.MakeEventStopParticles(inst, { name = "windmon_wind" })

			inst.components.hitbox:StopRepeatTargetDelay()
			inst.components.attacktracker:CompleteActiveAttack()
		end,
	}),

	State({
		name = "elite_wind_gust",
		tags = { "attack", "busy" },

		onenter = function(inst, target)
			inst.AnimState:PlayAnimation("wind_spin")
		end,

		events =
		{
			--EventHandler("hitboxtriggered", OnEliteWindGustHitboxTriggered),
			EventHandler("animover", function(inst)
				inst.sg:GoToState("idle")
			end),
		},

		timeline =
		{
			--[[FrameEvent(9, function(inst)
				inst.sg.statemem.is_attack = true
				--inst.components.hitbox:PushCircle(0, 0, 4, HitPriority.BOSS_DEFAULT)
			end),]]
			FrameEvent(9, function(inst)
				--inst.sg.statemem.is_attack = false

				inst.components.hitbox:SetHitFlags(HitGroup.ALL)
				--inst.components.hitbox:StartRepeatTargetDelay()

				inst.components.auraapplyer:SetEffect("elite_windmon_gust")
				inst.components.auraapplyer:SetRadius(12)
				inst.components.auraapplyer:Enable()

				local fx_params =
				{
					name = "elite_windmon_wind",
					particlefxname = "windmon_aoe_groundring",
					ischild = true,
					use_entity_facing = true,
					stopatexitstate = true,
				}

				ParticleSystemHelper.MakeEventSpawnParticles(inst, fx_params)

				inst.components.attacktracker:CompleteActiveAttack()
			end),
			FrameEvent(23, function(inst)
				inst.components.auraapplyer:Disable()
				ParticleSystemHelper.MakeEventStopParticles(inst, { name = "elite_windmon_wind" })
			end),
		},

		onexit = function(inst)
			local hitflags = inst:HasTag("playerminion") and HitGroup.CREATURES or HitGroup.CHARACTERS
			inst.components.hitbox:SetHitFlags(hitflags)
			inst.components.auraapplyer:Disable()

			ParticleSystemHelper.MakeEventStopParticles(inst, { name = "elite_windmon_wind" })

			inst.components.hitbox:StopRepeatTargetDelay()
			inst.components.attacktracker:CompleteActiveAttack()
		end,
	}),

	State({
		name = "shoot",
		tags = { "attack", "busy" },

		onenter = function(inst, target)
			inst.AnimState:PlayAnimation("trap_loop", true)
			inst.sg.statemem.target = target

			inst.sg.mem.shoot_loops = inst.sg.mem.shoot_loops or (inst:HasTag("elite") and ELITE_NUM_SHOOT_TRAPS or NUM_SHOOT_TRAPS)
		end,

		timeline =
		{
			FrameEvent(8, function(inst)
				inst.components.attacktracker:CompleteActiveAttack()
				inst.AnimState:HideSymbol("trap_owlitzer_hairball")
				SpawnSpikeBalls(inst)
			end),
		},

		events =
		{
			EventHandler("animover", function(inst)
				local target = inst.components.combat:GetTarget()
				if target then
					if inst.sg.mem.shoot_loops > 1 then
						inst.sg.mem.shoot_loops = inst.sg.mem.shoot_loops - 1
						inst.sg:GoToState("shoot", target)
					else
						inst.sg.mem.shoot_loops = nil

						-- Wind gust after spawning spikeballs.
						if inst:HasTag("elite") then
							inst.sg:GoToState("elite_wind_gust_pre", target)
						else
							inst.sg:GoToState("wind_gust_pre", target)
						end
					end
				else
					inst.sg.mem.shoot_loops = nil
					inst.sg:GoToState("idle")
				end
			end),
		},

		onexit = function(inst)
			inst.components.attacktracker:CompleteActiveAttack()
		end,
	}),
}

SGCommon.States.AddAttackPre(states, "wind_gust")
SGCommon.States.AddAttackHold(states, "wind_gust")

SGCommon.States.AddAttackPre(states, "shoot",
{
	onenter_fn = function(inst)
		inst.AnimState:ShowSymbol("trap_owlitzer_hairball")
	end,
})
SGCommon.States.AddAttackHold(states, "shoot")

-- Elite Attacks:
SGCommon.States.AddAttackHold(states, "elite_wind_gust")
SGCommon.States.AddAttackPre(states, "elite_wind_gust")

SGCommon.States.AddLeftRightHitStates(states)

SGCommon.States.AddMonsterDeathStates(states)

return StateGraph("sg_windmon", states, events, "idle")
