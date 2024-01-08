local EffectEvents = require "effectevents"
local SGCommon = require "stategraphs.sg_common"
local TargetRange = require "targetrange"
local easing = require "util.easing"
local playerutil = require "util.playerutil"
local monsterutil = require "util.monsterutil"

local KNOCKDOWN_SPEED = 10

local function OnSwipeHitBoxTriggered(inst, data)
	SGCommon.Events.OnHitboxTriggered(inst, data, {
		attackdata_id = inst.sg.statemem.currentattack,
		hitstoplevel = HitStopLevel.MEDIUM,
		pushback = 0.4,
		custom_attack_fn = function(attacker, attack)
			local hit = false
			if attacker.sg.statemem.currentattack == "swipe3" or attacker.sg.statemem.currentattack == "swipe4" then
				hit = attacker.components.combat:DoKnockdownAttack(attack)
			else
				hit = attacker.components.combat:DoKnockbackAttack(attack)
			end

			attacker.sg.statemem.connected = true
			return hit
		end,
		hit_fx = monsterutil.defaultAttackHitFX,
		hit_fx_offset_x = 0.5,
	})

	if inst.sg.statemem.currentattack == "swipe4" and inst.sg.statemem.connected then
		local velocity = inst.Physics:GetMotorVel()
		SGCommon.Fns.SetMotorVelScaled(inst, velocity * 0.25)
		if inst.sg:GetTicksInState() % inst.AnimState:GetCurrentAnimationNumFrames() < inst.AnimState:GetCurrentAnimationNumFrames() * 0.5 then --if we just started the anim, stop rolling sooner and pop into the _pst
			inst.sg:GoToState("swipe4_pst")
		end
		inst.sg.statemem.attack_finished = true
	end
end

local function OnWindmillHitBoxTriggered(inst, data)
	SGCommon.Events.OnHitboxTriggered(inst, data, {
		attackdata_id = "windmill",
		hitstoplevel = HitStopLevel.MEDIUM,
		multiplehitstop = true,
		pushback = 1.25,
		combat_attack_fn = "DoKnockdownAttack",
		hit_fx = monsterutil.defaultAttackHitFX,
	})

	local velocity = inst.Physics:GetMotorVel()
	SGCommon.Fns.SetMotorVelScaled(inst, velocity * 0.25)
	if inst.sg:GetTicksInState() % inst.AnimState:GetCurrentAnimationNumFrames() < inst.AnimState:GetCurrentAnimationNumFrames() * 0.5 then --if we just started the anim, stop rolling sooner and pop into the _pst
		inst.sg:GoToState("windmill_pst_hit")
	end
	inst.sg.statemem.attack_finished = true
end

local function ChooseAttack(inst, data)
	if data.target ~= nil and data.target:IsValid() then
		local attacktracker = inst.components.attacktracker
		local trange = TargetRange(inst, data.target)
		local next_attack = data.next_attack or attacktracker:PickNextAttack(data, trange)

		if next_attack == "swipe" then
			local state_name = attacktracker:GetStateNameForAttack(next_attack)
			SGCommon.Fns.TurnAndActOnTarget(inst, data, false, state_name, data.target)
			return true
		end

		if next_attack == "windmill" then
			local state_name = attacktracker:GetStateNameForAttack(next_attack)
			SGCommon.Fns.TurnAndActOnTarget(inst, data, false, state_name, data.target)
			return true
		end
	end
	return false
end

local function ChooseIdleBehavior(inst)
	if not inst.components.timer:HasTimer("idlebehavior_cd") then
		local target = nil-- inst.components.combat:GetTarget()
		if target == nil then
			local victim = playerutil.GetRandomLivingPlayer()
			if not victim then
				-- Probably all players are dead, so can't do anything.
				return false
			end

			if not inst.components.timer:HasTimer("taunt_cd") then
				if inst.components.health:GetPercent() >= 0.9 then
					SGCommon.Fns.TurnAndActOnTarget(inst, victim, true, "taunt")
					return true
				end
			end

			if not inst.components.timer:HasTimer("laugh_cd") then
				if inst.components.health:GetPercent() >= 0.9 then
					SGCommon.Fns.TurnAndActOnTarget(inst, victim, true, "laugh")
					return true
				end
			end
		end
	end
	return false
end

local function OnDeath(inst, data)
	--Spawn death fx
	EffectEvents.MakeEventFXDeath(inst, data.attack, "death_zucco")

	inst.components.lootdropper:DropLoot()
end

local function OnEscape(inst, target)
	if not inst.sg:HasStateTag("busy") then
		SGCommon.Fns.TurnAndActOnTarget(inst, target, true, "escape", target)
	end
end

local function OnPlaceTrap(inst, targetpos)
	if not inst.sg:HasStateTag("busy") then
		SGCommon.Fns.TurnAndActOnLocation(inst, targetpos.x, targetpos.z, true, "trap")
	end
end

local events =
{
	EventHandler("doescape", OnEscape),
	EventHandler("placetrap", OnPlaceTrap),
}
monsterutil.AddMonsterCommonEvents(events,
{
	locomote_data = { walk = true, run = true, turn = true },
	chooseattack_fn = ChooseAttack,
	ondeath_fn = OnDeath,
})
monsterutil.AddOptionalMonsterEvents(events,
{
	idlebehavior_fn = ChooseIdleBehavior,
	spawn_battlefield = true,
})
SGCommon.Fns.AddCommonSwallowedEvents(events)

local states =
{
	State({
		name = "escape",
		tags = { "busy" },

		onenter = function(inst, target)
			inst.AnimState:PlayAnimation("leap")
			inst.sg.statemem.target = target
		end,

		onupdate = function(inst)
			if inst.sg:HasStateTag("airborne") then
				inst.sg.statemem.jump_data.ticks_passed = math.min(inst.sg.statemem.jump_data.ticks_passed + 1, inst.sg.statemem.jump_data.total_jump_ticks)
				local x = easing.outSine(inst.sg.statemem.jump_data.ticks_passed, inst.sg.statemem.jump_data.startpos[1], inst.sg.statemem.jump_data.endpos[1] - inst.sg.statemem.jump_data.startpos[1], inst.sg.statemem.jump_data.total_jump_ticks)
				local z = easing.outSine(inst.sg.statemem.jump_data.ticks_passed, inst.sg.statemem.jump_data.startpos[2], inst.sg.statemem.jump_data.endpos[2] - inst.sg.statemem.jump_data.startpos[2], inst.sg.statemem.jump_data.total_jump_ticks)
				inst.Transform:SetPosition(x, 0, z)
			end
		end,

		timeline =
		{
			-- zucco is in the air frames 8-25 and we can scale how fast he moves to change how far he leaps
			FrameEvent(8, function(inst)
				inst.sg.statemem.jump_data = {
					startpos = { inst.Transform:GetWorldXZ() },
					endpos = { inst.sg.statemem.target.Transform:GetWorldXZ() },
					ticks_passed = 0,
					total_jump_ticks = 17,
				}
				inst.sg:AddStateTag("airborne")
			end),

			FrameEvent(18, function(inst)
				inst.sg.statemem.target:PushEvent("spawned_creature", inst.sg.statemem.target:GetAngleTo(inst) + 180)
			end),

			-- zucco is fully in the bush at this point and can no longer be seen
			FrameEvent(25, function(inst)
				inst.sg:RemoveStateTag("airborne")
				inst.Transform:SetPosition(inst.sg.statemem.jump_data.endpos[1], 0, inst.sg.statemem.jump_data.endpos[2])
			end),
		},

		events =
		{
			EventHandler("animover", function(inst) inst.sg:GoToState("hide") end)
		}
	}),

	State({
		name = "hide",
		tags = { "busy", "nointerrupt" },

		onenter = function(inst)
			inst:Hide()
			inst.sg:SetTimeout(6, 10)
			if inst.brain.brain then
				inst.brain.brain:ResetTrapData()
			end
			inst.Physics:SetEnabled(false)
		end,

		onupdate = function(inst)
			if not inst:ShouldHide() then
				inst.sg:SetTimeout(0)
			end
		end,

		ontimeout = function(inst)
			-- find a new bush to spawn @, teleport there, do spawn logic.
			local sc = TheWorld.components.spawncoordinator
			local spawners = {}
			for i, spawner in pairs(sc.spawners) do
				if spawner:CanSpawnCreature(inst) and inst:GetDistanceSqTo(spawner) > 5*5 then
					table.insert(spawners, spawner)
				end
			end

			local spawner = nil
			if #spawners > 0 then
				local best_weight = 0
				for _, sp in ipairs(spawners) do
					local weight = inst.CalculateSpawnerWeight(sp)
					if weight > best_weight then
						best_weight = weight
						spawner = sp
					end
				end
			end

			if spawner then
				spawner:ReserveSpawner(inst)
				spawner:SpawnCreature(inst, false)
			else
				assert(true, "Could not find a spawner for Zucco to respawn in!")
			end
		end,

		onexit = function(inst)
			inst.Physics:SetEnabled(true)
			inst:Show()
		end,
	}),

	State({
		name = "trap",
		tags = { "busy", "caninterrupt" },
		onenter = function(inst)
			inst.AnimState:PlayAnimation("trap")
		end,

		timeline =
		{
			FrameEvent(62, function(inst)
				local trap = SGCommon.Fns.SpawnAtDist(inst, "trap_zucco", 398/150)

				-- Sometimes the trap will fail to spawn due to a remote client taking control of Zucco while Zucco is in this state.
				if trap ~= nil then
					trap:PushEvent("spawn")
					if inst.brain and inst.brain.brain then
						inst.brain.brain:OnSetTrap(trap)
					end
				end
			end)
		},

		events =
		{
			EventHandler("animover", function(inst)
				if inst:IsValid() and not inst.components.health:IsDead() then
					if inst.brain and inst.brain.brain and inst.brain.brain:DonePlacingTraps() then
						if not ChooseIdleBehavior(inst) then
							inst.sg:GoToState("idle")
						end
					else
						inst.sg:GoToState("idle")
					end
				end
			end),
		},
	}),

	State({
		name = "taunt",
		tags = { "busy" },

		onenter = function(inst)
			inst.AnimState:PlayAnimation("behavior1")
		end,

		timeline =
		{
			FrameEvent(2, function(inst)
				inst.components.timer:StartTimer("taunt_cd", 25, true)
				inst.components.timer:StartTimer("idlebehavior_cd", 8, true)
			end),
			FrameEvent(10, function(inst)
				inst.sg:AddStateTag("caninterrupt")
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
		name = "laugh",
		tags = { "busy" },

		onenter = function(inst)
			inst.AnimState:PlayAnimation("behavior2")
		end,

		timeline =
		{
			FrameEvent(2, function(inst)
				inst.components.timer:StartTimer("laugh_cd", 25, true)
				inst.components.timer:StartTimer("idlebehavior_cd", 8, true)
			end),
			FrameEvent(10, function(inst)
				inst.sg:AddStateTag("caninterrupt")
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
		name = "swipe",
		tags = { "attack", "busy" },

		onenter = function(inst, target)
			inst.AnimState:PlayAnimation("swipe")
			inst.sg.statemem.target = target
			inst.sg.statemem.chainattack = 2
			inst.sg.statemem.currentattack = "swipe"
		end,

		timeline =
		{
			--physics
			FrameEvent(5, function(inst) SGCommon.Fns.MoveRelFacingScaled(inst, 65 / 150) end),
			FrameEvent(8, function(inst) SGCommon.Fns.MoveRelFacingScaled(inst, 78 / 150) end),
			FrameEvent(11, function(inst) SGCommon.Fns.MoveRelFacingScaled(inst, 96 / 150) end),
			FrameEvent(13, function(inst) SGCommon.Fns.MoveRelFacingScaled(inst, 44 / 150) end),
			--
			FrameEvent(13, function(inst)
				inst.components.hitbox:StartRepeatTargetDelay()
				inst.components.hitbox:PushBeam(-0.3, 4, 2, HitPriority.MOB_DEFAULT)
			end),
			FrameEvent(14, function(inst)
				inst.components.hitbox:PushBeam(-0.3, 3.5, 2, HitPriority.MOB_DEFAULT)
				inst.components.attacktracker:CompleteActiveAttack()
			end),
		},

		events =
		{
			EventHandler("hitboxtriggered", OnSwipeHitBoxTriggered),
			EventHandler("animover", function(inst)
				if inst.sg.statemem.target ~= nil and inst.sg.statemem.target:IsValid() then
					local attacktracker = inst.components.attacktracker
					local trange = TargetRange(inst, inst.sg.statemem.target)
					local next_attack = attacktracker:PickNextAttack(nil, trange)

					if next_attack == "swipe2" then
						SGCommon.Fns.FaceTarget(inst, inst.sg.statemem.target, true)
						inst.sg:GoToState("swipe2_pre", inst.sg.statemem.target)
					else
						inst.sg:GoToState("swipe_pst")
					end
				else
					inst.sg:GoToState("swipe_pst")
				end
			end),
		},

		onexit = function(inst)
			inst.components.hitbox:StopRepeatTargetDelay()
		end,
	}),

	State({
		name = "swipe_pst",
		tags = { "busy" },

		onenter = function(inst, target)
			inst.AnimState:PlayAnimation("swipe_pst")
		end,

		timeline =
		{
			FrameEvent(2, function(inst) SGCommon.Fns.MoveRelFacingScaled(inst, -80 / 150) end),
			FrameEvent(4, function(inst) SGCommon.Fns.MoveRelFacingScaled(inst, -17 / 150) end),
			FrameEvent(6, function(inst) SGCommon.Fns.MoveRelFacingScaled(inst, -123 / 150) end),
			FrameEvent(8, function(inst) SGCommon.Fns.MoveRelFacingScaled(inst, -39 / 150) end),
			FrameEvent(10, function(inst) SGCommon.Fns.MoveRelFacingScaled(inst, -20 / 150) end),

			FrameEvent(10, function(inst) inst.sg:RemoveStateTag("busy") end),
		},

		events =
		{
			EventHandler("animover", function(inst)
				inst.sg:GoToState("idle")
			end),
		},
	}),

	State({
		name = "swipe2",
		tags = { "attack", "busy" },

		onenter = function(inst, target)
			inst.AnimState:PlayAnimation("swipe2")
			inst.sg.statemem.chainattack = 3
			inst.sg.statemem.target = target
			inst.sg.statemem.currentattack = "swipe2"
		end,

		timeline =
		{
			--physics
			FrameEvent(4, function(inst) SGCommon.Fns.MoveRelFacingScaled(inst, 46 / 150) end),
			FrameEvent(7, function(inst) SGCommon.Fns.MoveRelFacingScaled(inst, 132 / 150) end),
			FrameEvent(9, function(inst) SGCommon.Fns.MoveRelFacingScaled(inst, 66 / 150) end),
			--
			FrameEvent(11, function(inst)
				inst.components.hitbox:StartRepeatTargetDelay()
				inst.components.hitbox:PushBeam(-0.3, 3.6, 2.0, HitPriority.MOB_DEFAULT)
			end),
			FrameEvent(12, function(inst)
				inst.components.hitbox:PushBeam(-0.3, 3.0, 2.0, HitPriority.MOB_DEFAULT)
				inst.components.attacktracker:CompleteActiveAttack()
			end),
		},

		events =
		{
			EventHandler("hitboxtriggered", OnSwipeHitBoxTriggered),
			EventHandler("animover", function(inst)
				if inst.sg.statemem.target ~= nil and inst.sg.statemem.target:IsValid() then
					local attacktracker = inst.components.attacktracker
					local trange = TargetRange(inst, inst.sg.statemem.target)
					local next_attack = attacktracker:PickNextAttack(nil, trange)

					if next_attack == "swipe3" then
						SGCommon.Fns.FaceTarget(inst, inst.sg.statemem.target, true)
						inst.sg:GoToState("swipe3_pre", inst.sg.statemem.target)
					else
						inst.sg:GoToState("swipe2_pst")
					end
				else
					inst.sg:GoToState("swipe2_pst")
				end
			end),
		},

		onexit = function(inst)
			inst.components.hitbox:StopRepeatTargetDelay()
		end,
	}),

	State({
		name = "swipe2_pst",
		tags = { "busy" },

		onenter = function(inst, target)
			inst.AnimState:PlayAnimation("swipe2_pst")
		end,

		timeline =
		{
			FrameEvent(8, function(inst) inst.sg:RemoveStateTag("busy") end),
		},

		events =
		{
			EventHandler("animover", function(inst)
				inst.sg:GoToState("idle")
			end),
		},
	}),

	State({
		name = "swipe3",
		tags = { "attack", "busy" },

		onenter = function(inst, target)
			inst.AnimState:PlayAnimation("swipe3")
			inst.sg.statemem.currentattack = "swipe3"
			inst.sg.statemem.chainattack = 4
			inst.sg.statemem.target = target
		end,

		timeline =
		{
			-- Physics
			FrameEvent(14, function(inst) SGCommon.Fns.MoveRelFacingScaled(inst, 136 / 150) end),
			FrameEvent(17, function(inst) SGCommon.Fns.MoveRelFacingScaled(inst, 154 / 150) end),
			FrameEvent(18, function(inst) inst.sg:AddStateTag("airborne") end),
			FrameEvent(19, function(inst) SGCommon.Fns.SetMotorVelScaled(inst, 10) end),
			FrameEvent(29, function(inst) inst.Physics:Stop() end),
			FrameEvent(29, function(inst) inst.sg:RemoveStateTag("airborne") end),

			--Hit Boxes
			FrameEvent(17, function(inst)
				inst.components.hitbox:StartRepeatTargetDelay()
				inst.components.hitbox:PushBeam(-0.3, 3, 2.0, HitPriority.MOB_DEFAULT)
			end),
			FrameEvent(18, function(inst)
				inst.components.hitbox:PushBeam(-0.3, 2.7, 2.0, HitPriority.MOB_DEFAULT)
			end),

			FrameEvent(29, function(inst)
				inst.components.hitbox:PushBeam(-0.3, 2.5, 2.0, HitPriority.MOB_DEFAULT)
			end),

			-- Logic

			FrameEvent(19, function(inst)
				inst.sg:AddStateTag("vulnerable") --vulnerable means any knockDOWN hits can connect
				inst.sg:AddStateTag("knockback_becomes_knockdown") --this means any knockBACK hits will get upgraded to knockDOWN hits
			end),
		},

		events =
		{
			EventHandler("hitboxtriggered", OnSwipeHitBoxTriggered),
			EventHandler("animover", function(inst)
				inst.components.attacktracker:CompleteActiveAttack()
				if inst.sg.statemem.target ~= nil and inst.sg.statemem.target:IsValid() then
					local attacktracker = inst.components.attacktracker
					local trange = TargetRange(inst, inst.sg.statemem.target)
					local next_attack = attacktracker:PickNextAttack(nil, trange)

					if next_attack == "swipe4" then
						inst.sg:GoToState("swipe4_pre", inst.sg.statemem.target)
					else
						inst.sg:GoToState("swipe3_loop")
					end
				else
					inst.sg:GoToState("swipe3_loop")
				end
			end),
		},

		onexit = function(inst)
			inst.Physics:Stop()
			inst.components.hitbox:StopRepeatTargetDelay()
		end,
	}),

	State({
		name = "swipe3_loop",
		tags = { "busy", "vulnerable", "knockback_becomes_knockdown", "attack" },

		onenter = function(inst, target)
			monsterutil.StartCannotBePushed(inst)
			inst.AnimState:PlayAnimation("swipe3_loop", true)
		end,

		onexit = function(inst)
			monsterutil.StopCannotBePushed(inst)
		end,

		events =
		{
			EventHandler("animover", function(inst)
				inst.sg:GoToState("swipe3_pst")
			end),
		},
	}),

	State({
		name = "swipe3_pst",
		tags = { "busy", "vulnerable", "knockback_becomes_knockdown" },

		onenter = function(inst, target)
			monsterutil.StartCannotBePushed(inst)
			inst.AnimState:PlayAnimation("swipe3_pst")
		end,

		timeline =
		{
			FrameEvent(9, function(inst)
				inst.sg:RemoveStateTag("vulnerable")
				inst.sg:RemoveStateTag("knockback_becomes_knockdown")
				monsterutil.StopCannotBePushed(inst)
			end),
		},

		onexit = function(inst)
			monsterutil.StopCannotBePushed(inst)
		end,

		events =
		{
			EventHandler("animover", function(inst)
				inst.sg:GoToState("idle")
			end),
		},
	}),

	State({
		name = "swipe4",
		tags = { "attack", "busy" },

		onenter = function(inst, target)
			inst.AnimState:PlayAnimation("swipe4_pre_loop")
			inst.AnimState:PushAnimation("swipe4_loop", true)
			inst.sg.statemem.currentattack = "swipe4"
			inst.sg.statemem.chainattack = 5
			inst.sg:SetTimeoutTicks(30)
			inst.sg.statemem.target = target
		end,

		ontimeout = function(inst)
			inst.sg.statemem.attack_finished = true -- don't transition yet... set a flag that it -can- transition on the next anim loop
		end,

		onupdate = function(inst)
			if inst.sg.statemem.hitting then
				SGCommon.Fns.FaceTarget(inst, inst.sg.statemem.target, true) -- we should rate limit this
				inst.components.hitbox:PushBeam(-1.75, 3.0, 2, HitPriority.MOB_DEFAULT)
			end
		end,

		timeline =
		{
			FrameEvent(3, function(inst)
				SGCommon.Fns.FaceTarget(inst, inst.sg.statemem.target, true)
				inst.sg.statemem.hitting = true
				inst.components.hitbox:StartRepeatTargetDelay()
				SGCommon.Fns.SetMotorVelScaled(inst, 10)
			end),
		},

		events =
		{
			EventHandler("hitboxtriggered", OnSwipeHitBoxTriggered),
			EventHandler("animover", function(inst)
				if inst.sg.statemem.attack_finished then
					inst.sg:GoToState("swipe4_pst")
				end
			end),
		},

		onexit = function(inst)
			inst.components.attacktracker:CompleteActiveAttack()
			inst.Physics:Stop()
			inst.components.hitbox:StopRepeatTargetDelay()
		end,
	}),

	State({
		name = "swipe4_pst",
		tags = { "busy", "vulnerable", "knockback_becomes_knockdown" },

		onenter = function(inst, target)
			inst.AnimState:PlayAnimation("swipe4_pst")
		end,

		timeline =
		{
			FrameEvent(0, function(inst) SGCommon.Fns.SetMotorVelScaled(inst, 8) end),
			FrameEvent(2, function(inst) SGCommon.Fns.SetMotorVelScaled(inst, 6) end),
			FrameEvent(4, function(inst) SGCommon.Fns.SetMotorVelScaled(inst, 4) end),
			FrameEvent(6, function(inst) SGCommon.Fns.SetMotorVelScaled(inst, 2) end),
			FrameEvent(8, function(inst) inst.Physics:Stop() end),
		},

		events =
		{
			EventHandler("animover", function(inst)
				inst.sg:GoToState("idle")
			end),
		},

		onexit = function(inst) inst.Physics:Stop() end,
	}),

	State({
		name = "windmill",
		tags = { "attack", "busy" },

		onenter = function(inst, target)
			inst.sg.statemem.move_mod = 0.85
			inst.AnimState:PlayAnimation("windmill")
			inst.AnimState:PushAnimation("windmill_loop", true)
			inst.sg.statemem.attack_finished = false
			inst.sg:SetTimeoutAnimFrames(45)

			inst.sg.statemem.old_physics = inst.Physics:GetSize()
			inst.sg.statemem.old_hitbox = inst.HitBox:GetSize()

			inst.Physics:SetSize(math.max(0.1, inst.sg.statemem.old_physics * 0.2))
			inst.HitBox:SetNonPhysicsRect(inst.sg.statemem.old_hitbox)
		end,

		onupdate = function(inst)
			if inst.sg.statemem.moving then
				SGCommon.Fns.SetMotorVelScaled(inst, KNOCKDOWN_SPEED * inst.sg.statemem.move_mod)
				inst.components.hitbox:PushBeam(-.5, 3.0, 1.2, HitPriority.MOB_DEFAULT)
			end
		end,

		ontimeout = function(inst)
			-- must mean you missed the target
			if inst.sg.statemem.attack_finished then
				inst.sg:GoToState("windmill_pst_hit")
			else
				inst.sg:GoToState("windmill_pst_miss", inst.sg.statemem.move_mod)
			end
		end,

		timeline =
		{
			FrameEvent(6, function(inst)
				inst.components.hitbox:StartRepeatTargetDelay()
				inst.sg.statemem.moving = true
			end),
		},

		events =
		{
			EventHandler("hitboxtriggered", OnWindmillHitBoxTriggered),
			EventHandler("animover", function(inst)
				if inst.sg.statemem.attack_finished then
					inst.sg:GoToState("windmill_pst_hit")
				end
			end),
		},

		onexit = function(inst)
			inst.Physics:Stop()
			inst.components.attacktracker:CompleteActiveAttack()
			inst.components.hitbox:StopRepeatTargetDelay()
			inst.Physics:SetSize(inst.sg.statemem.old_physics)
			inst.HitBox:UsePhysicsShape()
		end,
	}),

	State({
		name = "windmill_pst_hit",
		tags = { "busy" },

		onenter = function(inst, target)
			inst.AnimState:PlayAnimation("windmill_pst_hit")
		end,

		events =
		{
			EventHandler("animover", function(inst)
				inst.sg:GoToState("idle")
			end),
		},
	}),

	State({
		name = "windmill_pst_miss",
		tags = { "busy" },

		onenter = function(inst, move_mod)
			inst.AnimState:PlayAnimation("windmill_pst_miss")
			inst.sg.statemem.move_mod = move_mod
			inst.sg.statemem.trip_timer = 3
			SGCommon.Fns.SetMotorVelScaled(inst, KNOCKDOWN_SPEED * inst.sg.statemem.move_mod)
		end,

		events =
		{
			EventHandler("animover", function(inst)
				inst:FlipFacingAndRotation()
				local pushback = Attack(inst, inst)
				pushback:SetPushback(inst.sg.statemem.move_mod)
				inst.components.timer:StartTimer("knockdown", inst.sg.statemem.trip_timer, true)
				inst.sg:GoToState("windmill_knockdown", { attack = pushback })
				-- flip facing & go to knockdown_pre
			end),
		},
	}),

	State({
		name = "windmill_knockdown",
		tags = { "hit", "knockdown", "busy", "nointerrupt", "airborne" },

		onenter = function(inst, data)
			inst.AnimState:PlayAnimation("windmill_knockdown")
			local move_speed_mod = data and data.attack and data.attack:GetPushback()
			inst.sg.statemem.move_data =
			{
				total_movement_ticks = 4 * ANIM_FRAMES,
				move_start_speed = KNOCKDOWN_SPEED * move_speed_mod,
				move_end_speed = 0,
			}
		end,

		onupdate = function(inst)
			if inst.sg:HasStateTag("airborne") then
				local ticks = math.min(inst.sg:GetTicksInState(), inst.sg.statemem.move_data.total_movement_ticks)
				local speed = easing.linear(ticks, inst.sg.statemem.move_data.move_start_speed, inst.sg.statemem.move_data.move_end_speed - inst.sg.statemem.move_data.move_start_speed, inst.sg.statemem.move_data.total_movement_ticks )
				SGCommon.Fns.SetMotorVelScaled(inst, -speed)
			else
				inst.Physics:Stop()
			end
		end,

		timeline =
		{
			FrameEvent(0, function(inst) inst.Physics:SetSize(2.0) end),
			FrameEvent(2, function(inst) inst.Physics:SetSize(2.1) end),
			FrameEvent(4, function(inst) inst.Physics:SetSize(2.3) end),
			FrameEvent(4, function(inst) inst.sg:RemoveStateTag("airborne") end),
		},

		events =
		{
			EventHandler("getup", function(inst)
				inst.sg.statemem.getup = true
			end),
			EventHandler("animover", function(inst)
				inst.sg.statemem.knockdown = true
				inst.sg:GoToState(inst.sg.statemem.getup and "knockdown_getup" or "knockdown_idle")
			end),
		},

		onexit = function(inst)
			inst.Physics:SetSize(inst.sg.mem.idlesize)
			inst.Physics:Stop()
		end,
	}),
}

SGCommon.States.AddAttackPre(states, "swipe")
SGCommon.States.AddAttackHold(states, "swipe")

SGCommon.States.AddAttackPre(states, "swipe2")
SGCommon.States.AddAttackHold(states, "swipe2")

SGCommon.States.AddAttackPre(states, "swipe3")
SGCommon.States.AddAttackHold(states, "swipe3")

SGCommon.States.AddAttackPre(states, "swipe4")
SGCommon.States.AddAttackHold(states, "swipe4")

SGCommon.States.AddAttackPre(states, "windmill")
SGCommon.States.AddAttackHold(states, "windmill")

SGCommon.States.AddHitStates(states, ChooseAttack)

SGCommon.States.AddSpawnBattlefieldStates(states,
{
	anim = "spawn",
	fadeduration = 0.5,
	fadedelay = 0.1,

	timeline =
	{
		FrameEvent(42, function(inst)
			printf("[%s] leave_spawner", inst)
			inst:PushEvent("leave_spawner")
		end),
		FrameEvent(42, function(inst) SGCommon.Fns.SetMotorVelScaled(inst, 6) end),
		FrameEvent(52, function(inst) inst.Physics:Stop() end),
		--
		FrameEvent(42, function(inst)
			inst.sg:AddStateTag("airborne")
		end),
		FrameEvent(52, function(inst)
			inst.sg:RemoveStateTag("airborne")
		end),
		FrameEvent(56, function(inst)
			inst.sg:AddStateTag("caninterrupt")
		end),
		FrameEvent(58, function(inst)
			inst.sg:RemoveStateTag("busy")
		end),
	},

	onexit_fn = function(inst)
		inst.Physics:Stop()
	end,
})

SGCommon.States.AddKnockdownHitStates(states,
{
	hit_pst_busy_frames = 4,
})

SGCommon.States.AddWalkStates(states)

SGCommon.States.AddRunStates(states)

SGCommon.States.AddIdleStates(states)

SGCommon.States.AddKnockbackStates(states,
{
	movement_frames = 8
})

SGCommon.States.AddKnockdownStates(states,
{
	movement_frames = 10,
	getup_frames = 17,
	knockdown_size = 2.3,
	knockdown_pre_timeline =
	{
		FrameEvent(13, function(inst) inst.Physics:MoveRelFacing(10 / 150) end),
		FrameEvent(14, function(inst) inst.Physics:MoveRelFacing(10 / 150) end),
	},
	knockdown_getup_timeline =
	{
		FrameEvent(10, function(inst) inst.Physics:MoveRelFacing(37 / 150) end),
		FrameEvent(15, function(inst) inst.Physics:MoveRelFacing(54 / 150) end),
		FrameEvent(18, function(inst) inst.Physics:MoveRelFacing(51 / 150) end),
		FrameEvent(21, function(inst) inst.Physics:MoveRelFacing(15 / 150) end),
		FrameEvent(24, function(inst) inst.Physics:MoveRelFacing(56 / 150) end),
		FrameEvent(27, function(inst) inst.Physics:MoveRelFacing(-19 / 150) end),
		FrameEvent(34, function(inst) inst.Physics:MoveRelFacing(10 / 150) end),
		FrameEvent(38, function(inst) inst.Physics:MoveRelFacing(6 / 150) end),
		FrameEvent(40, function(inst) inst.Physics:MoveRelFacing(13 / 150) end),
		FrameEvent(42, function(inst) inst.Physics:MoveRelFacing(-13 / 150) end),
	}
})

SGCommon.States.AddTurnStates(states, {	chooseattack_fn = ChooseAttack })

SGCommon.States.AddMonsterDeathStates(states)

local fns =
{
	CanTakeControl = function(sg)
		if sg:GetCurrentState() == "escape" or sg:GetCurrentState() == "hide" then
			return false
		end
		return SGCommon.Fns.CanTakeControlDefault(sg)
	end,

	OnResumeFromRemote = SGCommon.Fns.ResumeFromRemoteHandleKnockingAttack,
}

SGRegistry:AddData("sg_zucco", states)

return StateGraph("sg_zucco", states, events, "idle", fns)
