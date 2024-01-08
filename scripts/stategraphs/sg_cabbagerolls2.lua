local EffectEvents = require "effectevents"
local SGCommon = require "stategraphs.sg_common"
local monsterutil = require "util.monsterutil"


local function OnSlamHitBoxTriggered(inst, data)
	SGCommon.Events.OnHitboxTriggered(inst, data, {
		attackdata_id = "slam",
		hitstoplevel = HitStopLevel.MEDIUM,
		combat_attack_fn = "DoKnockbackAttack",
		hit_fx = monsterutil.defaultAttackHitFX,
		hit_fx_offset_x = 2,
	})
end

-- this doesn't get played except for "instant death" of towers
local function OnDeath(inst, data)
	inst.components.cabbagerollstracker:Unregister()
	--Spawn death fx
	EffectEvents.MakeEventFXDeath(inst, data.attack, "death_cabbageroll")
end

local function OnDeathTask(inst)
	if inst:IsLocal() and inst:HasTag("nokill") then
		inst.components.timer:StartTimer("knockdown", inst.components.combat.knockdownduration, true)
		SGCommon.Fns.OnKnockdown(inst)
	else
		TheLog.ch.StateGraph:printf("Warning: %s EntityID %d tried to run OnDeathTask while remote",
			inst, inst:IsNetworked() and inst.Network:GetEntityID() or -1)
	end
	inst.sg.mem.deathtask = nil
end

local function ShouldSplit(inst, data)
	if data and not data.hurt then return false end
	return inst.components.health:GetPercent() <= inst.components.cabbagetower:GetHealthSplitPercentage()
end

local events =
{
	EventHandler("attacked", function(inst, data)
		if inst.sg.mem.deathtask ~= nil then
			inst.sg.mem.deathtask:Cancel()
			inst.sg.mem.deathtask = nil
		end
		if ShouldSplit(inst) then
			data.attack:SetKnockdownDuration(inst.components.combat:GetKnockdownDuration())
			SGCommon.Fns.OnKnockdown(inst, data)
		else
			SGCommon.Fns.OnAttacked(inst, data)
		end
	end),

	EventHandler("knockback", function(inst, data)
		if inst.sg.mem.deathtask ~= nil then
			inst.sg.mem.deathtask:Cancel()
			inst.sg.mem.deathtask = nil
		end
		if ShouldSplit(inst) then
			data.attack:SetKnockdownDuration(inst.components.combat:GetKnockdownDuration())
			SGCommon.Fns.OnKnockdown(inst, data)
		else
			SGCommon.Fns.OnKnockback(inst, data)
		end
	end),

	EventHandler("knockdown", function(inst, data)
		if inst.sg.mem.deathtask ~= nil then
			inst.sg.mem.deathtask:Cancel()
			inst.sg.mem.deathtask = nil
		end
		SGCommon.Fns.OnKnockdown(inst, data)
	end),

	EventHandler("healthchanged", function(inst, data)
		if ShouldSplit(inst, data) then
			if inst.sg.mem.deathtask == nil then
				inst.sg.mem.deathtask = inst:DoTaskInTicks(0, OnDeathTask)
			end
		end
	end),
}
monsterutil.AddMonsterCommonEvents(events,
{
	ondeath_fn = OnDeath,
})
monsterutil.AddOptionalMonsterEvents(events,
{
	spawn_battlefield = true,
})
SGCommon.Fns.AddCommonSwallowedEvents(events)

local states =
{
	State({
		name = "idle",
		tags = { "idle" },

		onenter = function(inst)
			if not inst.AnimState:IsCurrentAnimation("idle") then
				inst.AnimState:PlayAnimation("idle", true)
			end

			--Used by brain behaviors in case our size varies a lot
			if inst.sg.mem.idlesize == nil then
				inst.sg.mem.idlesize = inst.Physics:GetSize()
			end
		end,

		onupdate = function(inst)
			-- TODO: networking2022 hack: Why does this happen??
			if inst.sg:HasStateTag("nointerrupt")
				and inst.sg:HasStateTag("knockdown")
				and inst.sg:HasStateTag("hit")
				and inst.sg:HasStateTag("busy") then
					TheLog.ch.CabbageRoll:printf("Warning: %s EntityID %d Removing leftover knockdown tags in idle state tick=%d",
						inst,
						inst:IsNetworked() and inst.Network:GetEntityID() or -1,
						inst.sg:GetTicksInState())
				inst.sg:RemoveStateTag("nointerrupt")
				inst.sg:RemoveStateTag("knockdown")
				inst.sg:RemoveStateTag("hit")
				inst.sg:RemoveStateTag("busy")
			end
		end,
	}),

	State({
		name = "knockdown",
		tags = { "hit", "knockdown", "busy", "nointerrupt" },

		onenter = function(inst, data)
			inst.AnimState:PlayAnimation("knockdown")
			local timeout_animframes = data and data.attack:GetHitstunAnimFrames() or 5
			inst.sg:SetTimeoutAnimFrames(timeout_animframes)
			if inst.components.hitshudder then
				inst.components.hitshudder:DoShudder(TUNING.HITSHUDDER_AMOUNT_HEAVY, timeout_animframes)
			end
		end,

		ontimeout = function(inst)
			inst.sg:GoToState("idle")
		end,

		onexit = function(inst)
			local x, z = inst.Transform:GetWorldXZ()
			local rot = inst.Transform:GetFacingRotation()
			local target = inst.components.combat:GetTarget()
			local hp = inst.components.health:GetPercent()
			hp = math.max(0.01, hp)

			local animframes = inst.components.timer:GetAnimFramesRemaining("knockdown") or 0
			local paused = inst.components.timer:IsPaused("knockdown")

			local mid = inst.components.cabbagetower:RemoveTopRoll()
			if mid then
				mid:TakeControl()
				mid.components.cabbagetower:SetSingle()
				mid.sg:GoToState("knockdown_mid")
				mid.Transform:SetPosition(x, 0, z)
				mid.Transform:SetRotation(rot + math.random(-20, 20))
				mid.components.health:SetPercent(hp, true)
				mid.components.combat:SetTarget(target)

				mid.components.timer:StartTimerAnimFrames("knockdown", animframes + math.random(3, 8))
				if paused then
					mid.components.timer:PauseTimer("knockdown")
				end

				mid.Network:FlushAllHistory()
			end

			local tower_sg = inst.sg
			inst.components.cabbagetower:SetSingle()
			-- at this point, inst.sg is now sg_cabbageroll, NOT sg_cabbagerolls!
			assert(tower_sg.retired and tower_sg ~= inst.sg)

			inst.sg:GoToState("knockdown_btm")
			inst.components.health:SetPercent(hp, true)

			inst.components.timer:StartTimerAnimFrames("knockdown", animframes + math.random(3, 8))
			if paused then
				inst.components.timer:PauseTimer("knockdown")
			end
		end,
	}),

	State({
		name = "catapult_pst",
		tags = { "attack", "busy" },

		onenter = function(inst)
			inst.AnimState:PlayAnimation("catapult_pst")
		end,

		timeline =
		{
			--head hitbox
			FrameEvent(0, function(inst)inst.components.offsethitboxes:SetEnabled("offsethitbox", true) end),
			FrameEvent(0, function(inst) inst.components.offsethitboxes:Move("offsethitbox", 2.1) end),
			FrameEvent(2, function(inst) inst.components.offsethitboxes:Move("offsethitbox", 2.3) end),
			FrameEvent(6, function(inst) inst.components.offsethitboxes:Move("offsethitbox", 1.8) end),
			FrameEvent(8, function(inst) inst.components.offsethitboxes:Move("offsethitbox", .8) end),
			FrameEvent(10, function(inst) inst.components.offsethitboxes:SetEnabled("offsethitbox", false) end),
			--

			FrameEvent(14, function(inst)
				inst.sg:AddStateTag("caninterrupt")
			end),
			FrameEvent(16, function(inst)
				inst.sg:RemoveStateTag("busy")
			end),
		},

		events =
		{
			EventHandler("animover", function(inst)
				inst.sg:GoToState("idle")
			end),
		},

		onexit = function(inst) inst.components.offsethitboxes:SetEnabled("offsethitbox", false) end,
	}),

	State({
		name = "slam",
		tags = { "attack", "busy" },

		onenter = function(inst, target)
			inst.AnimState:PlayAnimation("slam")
			inst.sg.statemem.target = target
		end,

		timeline =
		{
			FrameEvent(6, function(inst)
				inst.components.offsethitboxes:SetEnabled("offsethitbox", true)
				inst.components.offsethitboxes:Move("offsethitbox", 3)
			end),

			FrameEvent(7, function(inst) -- hit 1
				inst.components.attacktracker:CompleteActiveAttack()
				inst.components.hitbox:StartRepeatTargetDelayAnimFrames(10)
				inst.components.hitbox:PushBeam(-1, 5, 1, HitPriority.MOB_DEFAULT)
			end),
			FrameEvent(8, function(inst) -- hit 1
				inst.components.hitbox:PushBeam(-1, 5, 1, HitPriority.MOB_DEFAULT)
			end),

			FrameEvent(12, function(inst) -- bounce 1 start
				inst.sg:AddStateTag("airborne")
				inst.Physics:StartPassingThroughObjects()
				SGCommon.Fns.SetMotorVelScaled(inst, 7)
				inst.components.offsethitboxes:SetEnabled("offsethitbox", false)
			end),

			FrameEvent(28, function(inst) -- bounce 1 end
				inst.sg:RemoveStateTag("airborne")
				inst.Physics:StopPassingThroughObjects()
				inst.Physics:Stop()
				inst.components.offsethitboxes:SetEnabled("offsethitbox", true)
				inst.components.offsethitboxes:Move("offsethitbox", 3)
			end),

			FrameEvent(28, function(inst) -- hit 2
				inst.components.hitbox:PushBeam(-1, 5, 1, HitPriority.MOB_DEFAULT)
			end),
			FrameEvent(29, function(inst) -- hit 2
				inst.components.hitbox:PushBeam(-1, 5, 1, HitPriority.MOB_DEFAULT)
			end),

			FrameEvent(32, function(inst) -- bounce 2 start
				inst.sg:AddStateTag("airborne")
				inst.Physics:StartPassingThroughObjects()
				SGCommon.Fns.SetMotorVelScaled(inst, 6)
				inst.components.offsethitboxes:Move("offsethitbox", 0)
				inst.components.offsethitboxes:SetEnabled("offsethitbox", false)
			end),
			FrameEvent(44, function(inst) -- bounce 2 end
				inst.sg:RemoveStateTag("airborne")
				inst.Physics:StopPassingThroughObjects()
				inst.Physics:Stop()
			end),

			FrameEvent(55, function(inst) inst.sg:RemoveStateTag("busy") end), -- not busy
		},

		events =
		{
			EventHandler("hitboxtriggered", OnSlamHitBoxTriggered),
			EventHandler("animover", function(inst)
				inst.sg:GoToState("idle")
			end),
		},

		onexit = function(inst)
			inst.components.offsethitboxes:SetEnabled("offsethitbox", false)
			inst.Physics:Stop()
			inst.Physics:StopPassingThroughObjects()
			inst.components.hitbox:StopRepeatTargetDelay()
		end,
	}),

	State({
		name = "throw",
		tags = { "attack", "busy" },

		onenter = function(inst, target)
			inst.AnimState:PlayAnimation("throw")
			inst.sg.statemem.target = target
			inst.sg.mem.speed = inst.sg.mem.speed or 4
		end,

		timeline =
		{
			FrameEvent(4, function(inst) inst.sg:AddStateTag("airborne") end),
			FrameEvent(6, function(inst) inst.sg:AddStateTag("airborne_high") end),


			--physics
			FrameEvent(4, function(inst) inst.Physics:StartPassingThroughObjects() end),
			FrameEvent(4, function(inst) SGCommon.Fns.SetMotorVelScaled(inst, inst.sg.mem.speed) end),
			--
		},

		events =
		{
			EventHandler("animover", function(inst)
				inst.components.attacktracker:CompleteActiveAttack()
				local facingrot = inst.Transform:GetFacingRotation()
				local rot = inst.Transform:GetRotation()
				local hp = inst.components.health:GetPercent()
				local target = inst.components.combat:GetTarget()
				local rolls = {}

				local diff = ReduceAngle(rot - facingrot)
				diff = math.clamp(diff, -15, 15)
				rot = facingrot + diff

				local top = inst.components.cabbagetower:RemoveTopRoll()

				if top then
					top:TakeControl()
					top.components.cabbagetower:SetSingle()
					SGCommon.Fns.MoveToDist(inst, top, 3)
					top.sg:GoToState("thrown", inst)
					table.insert(rolls, top)
				end

				inst.sg:GoToState("idle")
				inst.components.cabbagetower:SetSingle()
				inst.sg:GoToState("throw_pst", inst.sg.mem.speed)
				table.insert(rolls, inst)

				for _, spawn in ipairs(rolls) do
					spawn.Transform:SetRotation(rot)
					spawn.components.health:SetPercent(hp, true)
					spawn.components.combat:SetTarget(target)
					spawn.components.hitbox:CopyRepeatTargetDelays(inst)
				end
			end),
		},

		onexit = function(inst)
			inst.Physics:Stop()
			inst.Physics:StopPassingThroughObjects()
		end,
	}),

	State({
		name = "combine",
		tags = { "busy" },

		onenter = function(inst)
			inst.AnimState:PlayAnimation("combine")
		end,

		timeline =
		{
			--physics
			FrameEvent(2, function(inst) inst.Physics:MoveRelFacing(20 / 150) end),
			--

			FrameEvent(8, function(inst)
				inst.sg:AddStateTag("caninterrupt")
			end),
			FrameEvent(10, function(inst)
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
}

SGCommon.States.AddAttackPre(states, "slam")
SGCommon.States.AddAttackHold(states, "slam")

SGCommon.States.AddAttackPre(states, "throw",
{
	timeline =
	{
		FrameEvent(1, function(inst) inst.Physics:MoveRelFacing(10 / 150) end),
		FrameEvent(4, function(inst)
			inst.sg.mem.speed = 4
			local target = inst.sg.statemem.target
			if target ~= nil and target:IsValid() then
				local x, z = inst.Transform:GetWorldXZ()
				local x1, z1 = target.Transform:GetWorldXZ()
				if x1 > x then
					x1 = math.max(x, x1 - target.HitBox:GetSize() - 1)
				else
					x1 = math.min(x, x1 + target.HitBox:GetSize() + 1)
				end
				local dir = inst:GetAngleToXZ(x1, z1)
				local facingrot = inst.Transform:GetFacingRotation()
				if DiffAngle(dir, facingrot) < 90 then
					inst.Transform:SetRotation(dir)

					--constant speed over 14 frames
					local dist = math.sqrt(DistSq2D(x, z, x1, z1))
					inst.sg.mem.speed = math.min(6, dist / 14 * 30)
				end
			else
				inst.sg.statemem.target = nil
			end
		end),
		FrameEvent(4, function(inst) inst.Physics:MoveRelFacing(20 / 150) end),
		FrameEvent(4, function(inst) SGCommon.Fns.SetMotorVelScaled(inst, inst.sg.mem.speed) end),
		--
	},
	onexit_fn = function(inst)
		inst.Physics:Stop()
	end,
})
SGCommon.States.AddAttackHold(states, "throw")

SGCommon.States.AddKnockbackStates(states,
{
	movement_frames = 13,
})

SGCommon.States.AddHitStates(states, SGCommon.Fns.ChooseAttack)

SGCommon.States.AddSpawnBattlefieldStates(states,
{
	anim = "spawn2",

	fadeduration = 0.2,
	fadedelay = 0.1,

	timeline =
	{
		FrameEvent(0, function(inst) inst.sg:RemoveStateTag("nointerrupt") end),
		FrameEvent(0, function(inst) SGCommon.Fns.SetMotorVelScaled(inst, 5) end),
		FrameEvent(16, function(inst) inst.Physics:Stop() end),

		FrameEvent(2, function(inst) inst:PushEvent("leave_spawner") end),

		FrameEvent(27, function(inst) inst.sg:RemoveStateTag("busy") end),
	},
})

SGCommon.States.AddWalkStates(states,
{
	onenterpre = function(inst) inst.Physics:Stop() end,
	pretimeline =
	{
		FrameEvent(2, function(inst) inst.Physics:SetMotorVel(inst.components.locomotor:GetWalkSpeed()) end),
	},

	onenterturnpre = function(inst) inst.Physics:Stop() end,
	onenterturnpst = function(inst) inst.Physics:Stop() end,
	turnpsttimeline =
	{
		FrameEvent(1, function(inst) inst.Physics:SetMotorVel(inst.components.locomotor:GetWalkSpeed()) end),
		FrameEvent(4, function(inst)
			inst.sg:RemoveStateTag("busy")
		end),
	},
})

SGCommon.States.AddTurnStates(states,
{
	onenterpre = function(inst)
		inst.sg:AddStateTag("cancombine")
	end,
	onenterpst = function(inst)
		inst.sg:AddStateTag("cancombine")
	end,
})

SGCommon.States.AddMonsterDeathStates(states)
SGRegistry:AddData("sg_cabbagerolls2", states, StateGraphRegistry.Hints.SerializeMetadata)

local fns =
{
	OnResumeFromRemote = function(sg)
		if sg.inst.components.health:GetPercent() <= sg.inst.components.cabbagetower:GetHealthSplitPercentage() then
			TheLog.ch.StateGraph:printf("%s EntityID %d resuming into knockdown due to split",
				sg.inst,
				sg.inst:IsNetworked() and sg.inst.Network:GetEntityID() or -1)
			return "knockdown"
		end
	end,
}
return StateGraph("sg_cabbagerolls2", states, events, "idle", fns)
