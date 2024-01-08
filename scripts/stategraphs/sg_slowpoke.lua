local EffectEvents = require "effectevents"
local SGCommon = require "stategraphs.sg_common"
local playerutil = require "util.playerutil"
local monsterutil = require "util.monsterutil"
local combatutil = require "util.combatutil"

local function OnSneezeHitBoxTriggered(inst, data)
	SGCommon.Events.OnHitboxTriggered(inst, data, {
		attackdata_id = inst.sg.statemem.attack_id or "sneeze",
		hitstoplevel = HitStopLevel.HEAVY,
		pushback = 2,
		combat_attack_fn = "DoKnockdownAttack",
		hit_fx = monsterutil.defaultAttackHitFX,
	})
end

--[[local function ChooseIdleBehavior(inst)
	if not inst.components.timer:HasTimer("idlebehavior_cd") then
		local threat = playerutil.GetRandomLivingPlayer()
		if not threat then
			inst.sg:GoToState("idle_behaviour")
			return true
		end
	end
	return false
end]]

local function OnDeath(inst, data)
	--Spawn death fx
	local fx_name = inst:HasTag("elite") and "death_slowpoke_elite" or "death_slowpoke"
	EffectEvents.MakeEventFXDeath(inst, data.attack, fx_name)

	inst.components.lootdropper:DropLoot()
end

local function OnLocomote(inst, data)
	local shouldturn
	if data ~= nil and data.dir ~= nil then
		local oldfacing = inst.Transform:GetFacing()
		if inst.sg:HasStateTag("turning") then
			inst.Transform:SetRotation(data.dir + 180)
		else
			inst.Transform:SetRotation(data.dir)
		end
		shouldturn = oldfacing ~= inst.Transform:GetFacing()
	end
	if inst.sg:HasStateTag("busy") then
		return
	elseif data ~= nil and data.move then
		if not inst.sg:HasStateTag("moving") or shouldturn then
			if shouldturn then
				if not inst.sg:HasStateTag("turning") then
					inst:FlipFacingAndRotation()
				end
				inst.sg:GoToState("turn_pre_walk_pre")
			else
				inst.sg:GoToState("walk_pre")
			end
		end
	elseif shouldturn then
		if not inst.sg:HasStateTag("turning") then
			inst:FlipFacingAndRotation()
		end
		if inst:IsSitting() then
			inst.sg:GoToState("turn_sit_pre")
		else
			inst.sg:GoToState("turn_pre")
		end
	elseif inst.sg:HasStateTag("moving") then
		if inst.sg:HasStateTag("turning") then
			inst:FlipFacingAndRotation()
		end
		inst.sg:GoToState("walk_pst")
	end
end

local function SpawnSpitBall(inst, type, target_pos, offset_x, offset_y)
	local projectile = SpawnPrefab("slowpoke_spit", inst)
	projectile:Setup(inst)

	if inst.Transform:GetFacing() == FACING_LEFT then
		offset_x = offset_x and offset_x * -1 or 0
	end

	local offset = Vector3(offset_x or 0, offset_y or 0, 0)
	local x, z = inst.Transform:GetWorldXZ()
	projectile.Transform:SetPosition(x + offset.x, offset.y, z + offset.z)
	projectile:PushEvent(type, target_pos)
end

local events =
{
	EventHandler("locomote", OnLocomote)
}
monsterutil.AddMonsterCommonEvents(events,
{
	ondeath_fn = OnDeath,
})
monsterutil.AddOptionalMonsterEvents(events,
{
	--idlebehavior_fn = ChooseIdleBehavior,
	spawn_perimeter = true,
})
SGCommon.Fns.AddCommonSwallowedEvents(events)

local states =
{

	----------------------
	-- Transition states to go from sit -> stand or stand -> sit

	State{
		name = "sitting",
        tags = {"busy", "nointerrupt"},
        onenter = function(inst, data)
            inst.Physics:Stop()
            inst.sg.statemem.data = data
            inst.sg.statemem.endstate = data.endstate
            local anim = "sit_pre"
            inst.AnimState:PlayAnimation(data.animoverride or anim)
        end,

        events =
        {
            EventHandler("animover", function(inst)
                inst.sg:GoToState(inst.sg.statemem.endstate, table.unpack( inst.sg.statemem.data.data ))
            end)
        },

        onexit = function(inst)
            inst:SetLocoState(inst.LocoState.s.SITTING)
        end,
	},

	State{
		name = "standing",
        tags = {"busy", "nointerrupt"},
        onenter = function(inst, data)
            inst.Physics:Stop()
            inst.sg.statemem.data = data
            inst.sg.statemem.endstate = data.endstate
            local anim = "sit_pst"
            inst.AnimState:PlayAnimation(data.animoverride or anim)
        end,

        events =
        {
            EventHandler("animover", function(inst)
                inst.sg:GoToState(inst.sg.statemem.endstate, table.unpack( inst.sg.statemem.data.data ))
            end)
        },

        onexit = function(inst)
            inst:SetLocoState(inst.LocoState.s.STANDING)
        end,
	},

	------- Sitting Turn States

	State({
		name = "turn_sit_pre",
		tags = { "turning", "busy" },

		onenter = function(inst, nextstate)
			SGCommon.Fns.PlayAnimOnAllLayers(inst, "turn_sit_pre")
			inst.sg.statemem.nextstate = nextstate
		end,

		events =
		{
			EventHandler("animover", function(inst)
				inst.sg:GoToState("turn_sit_pst", inst.sg.statemem.nextstate)
			end),
		},
	}),

	State({
		name = "turn_sit_pst",
		tags = { "busy" },

		onenter = function(inst, nextstate)
			SGCommon.Fns.PlayAnimOnAllLayers(inst, "turn_sit_pst")
			inst:FlipFacingAndRotation()
			inst.sg.statemem.nextstate = nextstate
		end,

		timeline = {
			FrameEvent(2, function(inst)
				if inst.sg.statemem.nextstate ~= nil then
					inst.sg:GoToState(table.unpack(inst.sg.statemem.nextstate))
				else
					inst.sg:RemoveStateTag("busy")
					inst.sg:AddStateTag("idle")
					SGCommon.Fns.TryQueuedAttack(inst, SGCommon.Fns.ChooseAttack)
				end
			end),
		},

		events =
		{
			EventHandler("animover", function(inst)
				if inst.sg.statemem.nextstate ~= nil then
					inst.sg:GoToState(table.unpack(inst.sg.statemem.nextstate))
				else
					inst.sg:GoToState("idle")
				end
			end),
			SGCommon.Events.OnQueueAttack(SGCommon.Fns.ChooseAttack),
		},
	}),

	-------

	State({
		name = "mortar",
		tags = { "attack", "busy" },

		default_data_for_tools = function(inst, cleanup)
			inst.sg.statemem.target_pos = Vector3.zero
		end,

		onenter = function(inst, target)
			inst.AnimState:PlayAnimation("spit_bomb")

			local target_pos
			target = SGCommon.Fns.SanitizeTarget(target)
			if target then
				inst.sg.statemem.target = target
				target_pos = combatutil.GetWalkableOffsetPositionFromEnt(target, 1, 3)

				if inst:IsNearXZ(target_pos.x, target_pos.z, 7) then
					-- By the time we're ready to attack, if the target is too close to us, cancel and go to a body_slam instead.
					-- Prevent slowpoke from shooting acid onto itself and then just sitting in it, make it better at defending.
					inst.sg:GoToState("from_mortar_to_bodyslam", target)
				end
				inst.sg.statemem.target_pos = target_pos
			else
				-- If their target is invalid, just pick a random spot to shoot, in the direction they're facing.
				local pos = inst:GetPosition()
				local facing = inst.Transform:GetFacing() == FACING_LEFT and -1 or 1
				local target_x = 10 * facing
				pos.x = pos.x + target_x

				target_pos = combatutil.GetWalkableOffsetPosition(pos, 0, 7, -30, 30)
				inst.sg.statemem.target_pos = target_pos
			end

		end,

		timeline =
		{
			FrameEvent(13, function(inst)
				inst.components.attacktracker:CompleteActiveAttack()
				local offset_x = 0.93 -- 140/150
				local offset_y = 5 -- 750/150
				SpawnSpitBall(inst, "spit", inst.sg.statemem.target_pos, offset_x, offset_y)

				-- if elite, shoot another projectile at the halfway point between shooter and target
				if inst:HasTag("elite") then
					local targetpos = (inst:GetPosition() + inst.sg.statemem.target_pos) * 0.5
					SpawnSpitBall(inst, "spit", targetpos, offset_x, offset_y)
				end
			end),
		},

		events =
		{
			EventHandler("animover", function(inst)
				inst.sg:GoToState("idle")
			end),
		},
	}),

	State({
		name = "from_mortar_to_bodyslam",
		tags = { "attack", "busy" },

		-- This state is for when the mortar spit was interrupted by the player standing too close to the slowpoke.
		-- Slowpoke changes their mind and switches to a bodyslam attack if the target comes too close.

		onenter = function(inst, target)
			inst.AnimState:PlayAnimation("spit_bomb_to_body_slam")
			inst.sg.statemem.target = target
			inst:SetLocoState(inst.LocoState.s.STANDING)
		end,

		timeline =
		{
		},

		events =
		{
			EventHandler("animover", function(inst)
				-- Elite slowpoke goes to the elite version of the body slam attack.
				if inst:HasTag("elite") then
					inst.sg.mem.num_slams = 1
					inst.sg:GoToState("elite_body_slam", inst.sg.statemem.target)
				else
					inst.sg:GoToState("body_slam", inst.sg.statemem.target)
				end
			end),
		},
	}),

	State({
		name = "body_slam",
		tags = { "attack", "busy", "nointerrupt" },

		onenter = function(inst, target)
			inst.AnimState:PlayAnimation("body_slam")
			target = SGCommon.Fns.SanitizeTarget(target)
			if target then
				inst.sg.statemem.dir = inst:GetAngleTo(target)
				inst.sg.statemem.target = target
			end

			inst.Physics:StartPassingThroughObjects()
		end,

		timeline = {
			FrameEvent(9, function(inst)
				if inst.sg.statemem.dir ~= nil then
					local velocity = 0
					inst.Transform:SetRotation(inst.sg.statemem.dir)

					local target = SGCommon.Fns.SanitizeTarget(inst.sg.statemem.target) -- Sanitize again in case the target got killed between onenter and this frame9.
					if target ~= nil then
						local distsq = inst:GetDistanceSqTo(target)
						if distsq > 30 then
							velocity = 20
						elseif distsq > 10 then
							velocity = 10
						elseif distsq > 5 then
							velocity = 6
						else
							velocity = 3
						end
					end

					SGCommon.Fns.SetMotorVelScaled(inst, velocity, SGCommon.SGSpeedScale.TINY)
				end
			end),

			FrameEvent(21, function(inst)
				SGCommon.Fns.StartCounterHitKnockdownWindow(inst)
			end),
			FrameEvent(25, function(inst)
				SGCommon.Fns.StopCounterHitKnockdownWindow(inst)
				inst.Physics:Stop()
				inst.Physics:StopPassingThroughObjects()
				EffectEvents.MakeEventSpawnLocalEntity(inst, "slowpoke_aoe", "idle") -- This passes idle state in only because a state is required in order for the entity to spawn
			end),
			FrameEvent(26, function(inst)
				inst.sg.statemem.hit_flags = Attack.HitFlags.GROUND -- For the second active frame, don't hit things that are airborne -- this is the outer ring of the attack.
			end),
		},

		events =
		{
			EventHandler("animover", function(inst)
				inst.sg:GoToState("idle")
			end),
		},

		onexit = function(inst)
			inst.components.hitbox:StopRepeatTargetDelay()
			inst.Physics:StopPassingThroughObjects()
			inst.components.attacktracker:CompleteActiveAttack()
		end,
	}),

	State({
		name = "elite_body_slam",
		tags = { "attack", "busy", "nointerrupt" },

		default_data_for_tools = function(inst, cleanup)
			inst.sg.mem.num_slams = 1
			inst.tuning.num_slams = 3
		end,

		onenter = function(inst, target)
			inst.AnimState:PlayAnimation("elite_body_slam_loop")
			target = SGCommon.Fns.SanitizeTarget(target)
			if target then
				inst.sg.statemem.dir = inst:GetAngleTo(target)
				inst.sg.statemem.target = target
			end

			inst.Physics:StartPassingThroughObjects()
		end,

		timeline = {
			FrameEvent(9, function(inst)
				if inst.sg.statemem.dir ~= nil then
					local velocity = 0
					inst.Transform:SetRotation(inst.sg.statemem.dir)

					local target = SGCommon.Fns.SanitizeTarget(inst.sg.statemem.target) -- Sanitize again in case the target got killed between onenter and this frame9.
					if target ~= nil then
						local distsq = inst:GetDistanceSqTo(target)
						if distsq > 30 then
							velocity = 20
						elseif distsq > 10 then
							velocity = 10
						elseif distsq > 5 then
							velocity = 6
						else
							velocity = 3
						end
					end

					SGCommon.Fns.SetMotorVelScaled(inst, velocity, SGCommon.SGSpeedScale.TINY)
				end
			end),

			FrameEvent(21, function(inst)
				SGCommon.Fns.StartCounterHitKnockdownWindow(inst)
			end),
			FrameEvent(25, function(inst)
				SGCommon.Fns.StopCounterHitKnockdownWindow(inst)
				inst.Physics:Stop()
				inst.Physics:StopPassingThroughObjects()
				EffectEvents.MakeEventSpawnLocalEntity(inst, "slowpoke_elite_aoe", "idle")
			end),
			FrameEvent(26, function(inst)
				-- Spew out acid from both ends
				local target_pos = inst:GetPosition()
				local target_x = 4
				local facing = inst.Transform:GetFacing() == FACING_LEFT and -1 or 1
				SpawnSpitBall(inst, "slam_spit", Vector3(target_pos.x + target_x * facing, target_pos.y, target_pos.z), 1.5, 1)
				SpawnSpitBall(inst, "slam_spit", Vector3(target_pos.x - target_x * facing, target_pos.y, target_pos.z), -2, 1)
			end),
		},

		events =
		{
			EventHandler("animover", function(inst)
				if not inst.sg.mem.num_slams then
					-- TODO: networking2022, sync specific sg.mem data somehow
					-- For now, end the slams
					TheLog.ch.StateGraph:printf("Warning: sg.mem.num_slams not synced.  Setting to %d", inst.tuning.num_slams)
					inst.sg.mem.num_slams = inst.tuning.num_slams
				end

				-- If doing more slams, go to elite body slam loop pre state, otherwise the pst state.
				if inst.sg.mem.num_slams < inst.tuning.num_slams then
					inst.sg.mem.num_slams = inst.sg.mem.num_slams + 1
					inst.sg:GoToState("elite_body_slam_loop_pre", inst.sg.statemem.target)
				else
					inst.sg.mem.num_slams = nil
					inst.sg:GoToState("elite_body_slam_pst")
				end
			end),
		},

		onexit = function(inst)
			inst.Physics:StopPassingThroughObjects()
			inst.components.attacktracker:CompleteActiveAttack()
		end,
	}),

	State({
		name = "elite_body_slam_loop_pre",
		tags = { "attack", "busy" },

		-- This state is for having a smooth transition to consecutive body slams.

		onenter = function(inst, target)
			inst.AnimState:PlayAnimation("elite_body_slam_loop_pre")
			inst.sg.statemem.target = target
		end,

		events =
		{
			EventHandler("animover", function(inst)
				inst.sg:GoToState("elite_body_slam", inst.sg.statemem.target)
			end),
		},
	}),

	State({
		name = "elite_body_slam_pst",
		tags = { "attack", "busy" },

		onenter = function(inst, target)
			inst.AnimState:PlayAnimation("elite_body_slam_pst")
		end,

		timeline =
		{
			FrameEvent(46, function(inst)
				inst.sg:RemoveStateTag("busy")
			end),
		},


		events =
		{
			EventHandler("animover", function(inst)
				inst.sg:GoToState("idle")
			end),
		},
	}),

	State({
		name = "sneeze",
		tags = { "attack", "busy" },

		onenter = function(inst, target)
			inst.AnimState:PlayAnimation("sneeze")
			inst.components.attacktracker:CompleteActiveAttack()
		end,

		timeline = {
			FrameEvent(4, function(inst)
				inst.components.hitbox:PushBeam(0.00, 2.50, 1.30, HitPriority.MOB_DEFAULT)
				inst.components.hitbox:PushBeam(2.50, 4.00, 2.00, HitPriority.MOB_DEFAULT)
				inst.components.hitbox:PushBeam(4.00, 5.00, 2.50, HitPriority.MOB_DEFAULT)
			end),
			FrameEvent(5, function(inst)
				inst.components.hitbox:PushBeam(0.00, 2.50, 1.30, HitPriority.MOB_DEFAULT)
				inst.components.hitbox:PushBeam(2.50, 4.00, 2.00, HitPriority.MOB_DEFAULT)
			end),
			FrameEvent(6, function(inst)
				inst.components.hitbox:PushBeam(0.00, 2.50, 1.30, HitPriority.MOB_DEFAULT)
			end),
		},

		events =
		{
			EventHandler("hitboxtriggered", OnSneezeHitBoxTriggered),
			EventHandler("animover", function(inst)
				inst.sg:GoToState("idle")
			end),
		},

		onexit = function(inst)
			inst.components.hitbox:StopRepeatTargetDelay()
		end,
	}),

}

SGCommon.States.AddAttackPre(states, "mortar",
{
	onenter_fn = function(inst, ...)
		inst:GoToLocoState(inst.LocoState.s.SITTING, nil, ...)
	end,
})
SGCommon.States.AddAttackHold(states, "mortar")

SGCommon.States.AddAttackPre(states, "body_slam")
SGCommon.States.AddAttackHold(states, "body_slam")

SGCommon.States.AddAttackPre(states, "elite_body_slam",
{
	onenter_fn = function(inst)
		inst.sg.mem.num_slams = 1
	end
})
SGCommon.States.AddAttackHold(states, "elite_body_slam")

SGCommon.States.AddAttackPre(states, "sneeze")
SGCommon.States.AddAttackHold(states, "sneeze")

SGCommon.States.AddSpawnPerimeterStates(states,
{
	pre_anim = "spawn_pre",
	hold_anim = "spawn_hold",
	land_anim = "spawn_land",
	pst_anim = "spawn_pst",

	fadeduration = 0.5,
	fadedelay = 0,
	jump_time = 0.66,

	pst_timeline =
	{
		FrameEvent(1, function(inst)
			EffectEvents.MakeEventSpawnLocalEntity(inst, "slowpoke_aoe", "idle")
		end),
	},
})

SGCommon.States.AddHitStates(states, nil,
{
	onenterhit = function(inst)
		inst:SetLocoState(inst.LocoState.s.STANDING)
	end,
})
SGCommon.States.AddKnockbackStates(states,
{
	movement_frames = 7,
	onenter_fn = function(inst)
		inst:SetLocoState(inst.LocoState.s.STANDING)
	end,
})
SGCommon.States.AddKnockdownStates(states,
{
	movement_frames = 12,
	onexit_getup_fn = function(inst)
		inst:SetLocoState(inst.LocoState.s.STANDING)
	end,
})
SGCommon.States.AddKnockdownHitStates(states)

SGCommon.States.AddIdleStates(states,
{
	modifyanim = function(inst)
		local animname = ""
		if inst:IsSitting() then
			animname = "sit_"
		end
		return animname
	end,
})
SGCommon.States.AddWalkStates(states,
{
	onenterpre = function(inst, ...)
		inst:GoToLocoState(inst.LocoState.s.STANDING, nil, ...)
	end,
})
SGCommon.States.AddTurnStates(states,
{
	onenterpre = function(inst, ...)
		inst:GoToLocoState(inst.LocoState.s.STANDING, nil, ...)
	end,
})

SGCommon.States.AddMonsterDeathStates(states)

local fns =
{
	OnResumeFromRemote = SGCommon.Fns.ResumeFromRemoteHandleKnockingAttack,
}

SGRegistry:AddData("sg_slowpoke", states)

return StateGraph("sg_slowpoke", states, events, "idle", fns)
