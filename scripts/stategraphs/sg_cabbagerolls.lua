local EffectEvents = require "effectevents"
local SGCommon = require "stategraphs.sg_common"
local monsterutil = require "util.monsterutil"


local function OnSmashHitBoxTriggered(inst, data)
	SGCommon.Events.OnHitboxTriggered(inst, data, {
		attackdata_id = "smash",
		hitstoplevel = HitStopLevel.MEDIUM,
		dir_flipped = inst.sg.statemem.backhit,
		combat_attack_fn = "DoKnockdownAttack",
		hit_fx = monsterutil.defaultAttackHitFX,
	})
end

local function OnBodySlamHitBoxTriggered(inst, data)
	SGCommon.Events.OnHitboxTriggered(inst, data, {
		attackdata_id = "bodyslam",
		hitstoplevel = HitStopLevel.MEDIUM,
		dir_flipped = inst.sg.statemem.backhit,
		combat_attack_fn = "DoKnockdownAttack",
		hit_fx = monsterutil.defaultAttackHitFX,
	})
end

local function ChooseIdleBehavior(inst)
	local target = inst.components.combat:GetTarget()
	if target ~= nil then
		if not inst.components.timer:HasTimer("taunt_cd") then
			SGCommon.Fns.TurnAndActOnTarget(inst, target, true, "taunt")
			return true
		end
	end
	return false
end

-- this doesn't get played except for "instant death" of towers
local function OnDeath(inst, data)
	inst.components.cabbagerollstracker:Unregister()
	--Spawn death fx
	EffectEvents.MakeEventFXDeath(inst, data.attack, "death_cabbageroll")
end

local function OnDeathTask(inst)
	if inst:IsLocal() and inst:HasTag("nokill") then
		inst.components.timer:StartTimer("knockdown", inst.components.combat:GetKnockdownDuration(), true)
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
	idlebehavior_fn = ChooseIdleBehavior,
	spawn_battlefield = true,
})
SGCommon.Fns.AddCommonSwallowedEvents(events)

local states =
{
	State({
		name = "idle",
		tags = { "idle" },

		onenter = function(inst)
			--Used by brain behaviors in case our size varies a lot
			if inst.sg.mem.idlesize == nil then
				inst.sg.mem.idlesize = inst.Physics:GetSize()
			end

			if SGCommon.Fns.TryIdleBehavior(inst, ChooseIdleBehavior) then
				return
			end

			if not inst.AnimState:IsCurrentAnimation("idle") then
				inst.AnimState:PlayAnimation("idle", true)
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

			local rolls = {}
			local animframes = inst.components.timer:GetAnimFramesRemaining("knockdown") or 0
			-- Top Roll

			local top = inst.components.cabbagetower:RemoveTopRoll()
			if top then
				top:TakeControl()
				top.components.cabbagetower:SetSingle()
				top.sg:GoToState("knockdown_top")
				table.insert(rolls, top)
			end

			local mid = inst.components.cabbagetower:RemoveTopRoll()
			if mid then
				mid:TakeControl()
				mid.components.cabbagetower:SetSingle()
				mid.sg:GoToState("knockdown_mid")
				table.insert(rolls, mid)
			end

			for _, spawn in ipairs(rolls) do
				spawn.Transform:SetPosition(x, 0, z)
				spawn.Transform:SetRotation(rot + math.random(-20, 20))
				spawn.components.health:SetPercent(hp, true)
				spawn.components.combat:SetTarget(target)
				spawn.components.timer:StartTimerAnimFrames("knockdown", animframes + math.random(3, 8), true)
				spawn.Network:FlushAllHistory()
			end

			inst.components.cabbagetower:SetSingle()
			inst.sg:GoToState("knockdown_btm")
			inst.components.health:SetPercent(hp, true)
		end,
	}),

	State({
		name = "taunt",
		tags = { "busy" },

		onenter = function(inst)
			inst.AnimState:PlayAnimation("behavior1")
		end,

		timeline =
		{
			--physics
			FrameEvent(5, function(inst) inst.Physics:MoveRelFacing(30 / 150) end),
			FrameEvent(5, function(inst) inst.Physics:SetSize(1.1) end),
			FrameEvent(6, function(inst) inst.Physics:MoveRelFacing(30 / 150) end),
			FrameEvent(6, function(inst) inst.Physics:SetSize(1.3) end),
			FrameEvent(34, function(inst) inst.Physics:SetSize(370 / 300) end),
			FrameEvent(34, function(inst) inst.Physics:MoveRelFacing(-10 / 150) end),
			FrameEvent(36, function(inst) inst.Physics:SetSize(1.1) end),
			FrameEvent(36, function(inst) inst.Physics:MoveRelFacing(-20 / 150) end),
			FrameEvent(38, function(inst) inst.Physics:SetSize(.9) end),
			FrameEvent(38, function(inst) inst.Physics:MoveRelFacing(-30 / 150) end),
			--

			--head hitbox
			FrameEvent(6, function(inst) inst.components.offsethitboxes:SetEnabled("offsethitbox", true) end),
			FrameEvent(6, function(inst) inst.components.offsethitboxes:Move("offsethitbox", .1) end),
			FrameEvent(34, function(inst) inst.components.offsethitboxes:Move("offsethitbox", 25/150) end),
			FrameEvent(36, function(inst) inst.components.offsethitboxes:SetEnabled("offsethitbox", false) end),
			--

			FrameEvent(5, function(inst)
				inst.components.timer:StartTimer("taunt_cd", 12, true)
			end),
			FrameEvent(38, function(inst)
				inst.sg:AddStateTag("caninterrupt")
			end),
			FrameEvent(42, function(inst)
				inst.sg:RemoveStateTag("busy")
			end),
		},

		events =
		{
			EventHandler("animover", function(inst)
				inst.sg:GoToState("idle")
			end),
		},

		onexit = function(inst)
			inst.components.offsethitboxes:SetEnabled("offsethitbox", false)
			inst.Physics:SetSize(.9)
			inst.components.hitbox:StopRepeatTargetDelay()
		end,
	}),

	State({
		name = "smash",
		tags = { "attack", "busy" },

		onenter = function(inst)
			inst.AnimState:PlayAnimation("smash")
		end,

		timeline =
		{

			-- Forward Strike

			FrameEvent(8, function(inst)
				inst.components.offsethitboxes:SetEnabled("offsethitbox", true)
				inst.components.offsethitboxes:Move("offsethitbox", 2.1)
			end),
			FrameEvent(10, function(inst) inst.components.offsethitboxes:Move("offsethitbox", 2.3) end),

			FrameEvent(9, function(inst)
				inst.components.attacktracker:CompleteActiveAttack()
				inst.sg.statemem.backpush = false
				inst.components.hitbox:StopRepeatTargetDelay()
				inst.components.hitbox:StartRepeatTargetDelay()
				inst.components.hitbox:PushBeam(1, 5.6, 1, HitPriority.MOB_DEFAULT)
			end),
			FrameEvent(10, function(inst)
				inst.components.hitbox:PushBeam(1, 5, 1, HitPriority.MOB_DEFAULT)
			end),
			FrameEvent(11, function(inst)
				inst.components.hitbox:PushBeam(1, 5, 1, HitPriority.MOB_DEFAULT)
			end),

			-- Backward Strike

			FrameEvent(15, function(inst)
				inst.sg:AddStateTag("knockback_becomes_knockdown")
			end),
			FrameEvent(20, function(inst) inst.components.offsethitboxes:Move("offsethitbox", 1.8) end),
			FrameEvent(21, function(inst) inst.components.offsethitboxes:Move("offsethitbox", -2.2) end),
			FrameEvent(22, function(inst) inst.components.offsethitboxes:Move("offsethitbox", -2.3) end),

			FrameEvent(21, function(inst)
				inst.sg.statemem.backhit = true
				inst.components.hitbox:StopRepeatTargetDelay()
				inst.components.hitbox:StartRepeatTargetDelay()
				inst.components.hitbox:PushBeam(0, -5.6, 1, HitPriority.MOB_DEFAULT)
			end),
			FrameEvent(22, function(inst)
				inst.components.hitbox:PushBeam(0, -5, 1, HitPriority.MOB_DEFAULT)
			end),
			FrameEvent(23, function(inst)
				inst.components.hitbox:PushBeam(0, -5, 1, HitPriority.MOB_DEFAULT)
			end),

			FrameEvent(34, function(inst) inst.components.offsethitboxes:SetEnabled("offsethitbox", false) end),
			FrameEvent(44, function(inst)
				inst.sg:AddStateTag("caninterrupt")
			end),
			FrameEvent(56, function(inst)
				inst.sg:RemoveStateTag("busy")
			end),
		},

		events =
		{
			EventHandler("hitboxtriggered", OnSmashHitBoxTriggered),
			EventHandler("animover", function(inst)
				inst.sg:GoToState("idle")
			end),
		},

		onexit = function(inst)
			inst.components.offsethitboxes:SetEnabled("offsethitbox", false)
			inst.components.hitbox:StopRepeatTargetDelay()
		end,
	}),

	State({
		name = "bodyslam",
		tags = { "attack", "busy" },

		onenter = function(inst, target)
			inst.AnimState:PlayAnimation("bodyslam")
			inst.sg.statemem.target = target
			local jump_time = 18/30 -- # of frames in the air / frames in a second
			local jump_dist = 5 -- desired distance for jump to travel
			if target ~= nil and target:IsValid() then
				local facingrot = inst.Transform:GetFacingRotation()
				local dir = inst:GetAngleTo(target)
				local diff = ReduceAngle(dir - facingrot)
				if math.abs(diff) > 90 then
					jump_dist = 3 -- desired distance for jump to travel
					inst.sg.statemem.jump_speed = jump_dist/jump_time
				else
					diff = math.clamp(diff, -60, 60)
					inst.Transform:SetRotation(facingrot + diff)

					local dist = math.sqrt(inst:GetDistanceSqTo(target))
					inst.sg.statemem.speedmult = math.clamp(dist / (64 / 30), .5, 2.5)

					jump_dist = math.min(jump_dist, dist) -- desired distance for jump to travel
					inst.sg.statemem.jump_speed = jump_dist/jump_time
				end
			else
				inst.sg.statemem.jump_speed = jump_dist/jump_time
			end
		end,

		timeline =
		{

			FrameEvent(2, function(inst) SGCommon.Fns.SetMotorVelScaled(inst, inst.sg.statemem.jump_speed) end),

			FrameEvent(2, function(inst)
				inst.sg:AddStateTag("airborne")
				inst.Physics:StartPassingThroughObjects()
				inst.components.attacktracker:CompleteActiveAttack()
			end),

			FrameEvent(20, function(inst)
				inst.sg:RemoveStateTag("airborne")
				inst.Physics:StopPassingThroughObjects()
				inst.Physics:Stop()
				inst.components.hitbox:StartRepeatTargetDelay()
				inst.components.hitbox:PushBeam(-2.5, 2.65, 1, HitPriority.MOB_DEFAULT)
			end),

			FrameEvent(21, function(inst)
				inst.components.hitbox:PushBeam(-2.5, 2.65, 1, HitPriority.MOB_DEFAULT)
			end),
		},

		events =
		{
			EventHandler("hitboxtriggered", OnBodySlamHitBoxTriggered),
			EventHandler("animover", function(inst)
				local rot = inst.Transform:GetFacingRotation()
				local hp = inst.components.health:GetPercent()
				local target = inst.components.combat:GetTarget()
				local rolls = {}

				local top = inst.components.cabbagetower:RemoveTopRoll()
				if top then
					top:TakeControl()
					top.components.cabbagetower:SetSingle()
					SGCommon.Fns.MoveToDist(inst, top, 346 / 150)
					top.sg:GoToState("bodyslam_top")
					table.insert(rolls, top)
				end

				local btm = inst.components.cabbagetower:RemoveTopRoll()
				if btm then
					btm:TakeControl()
					btm.components.cabbagetower:SetSingle()
					SGCommon.Fns.MoveToDist(inst, btm, -312 / 150)
					btm.sg:GoToState("bodyslam_btm")
					table.insert(rolls, btm)
				end

				inst.sg:GoToState("idle")
				inst.components.cabbagetower:SetSingle()
				inst.sg:GoToState("bodyslam_mid")

				for _, spawn in ipairs(rolls) do
					spawn.Transform:SetRotation(rot + math.random(-20, 20))
					spawn.components.health:SetPercent(hp, true)
					spawn.components.hitbox:CopyRepeatTargetDelays(inst)
					spawn.components.combat:SetTarget(target)
				end
			end),
		},

		onexit = function(inst)
			inst.Physics:Stop()
			inst.Physics:StopPassingThroughObjects()
			inst.components.hitbox:StopRepeatTargetDelay()
		end,
	}),

	State({
		name = "combine3",
		tags = { "busy" },

		onenter = function(inst)
			inst.AnimState:PlayAnimation("combine3")
		end,

		timeline =
		{
			--physics
			FrameEvent(16, function(inst) inst.Physics:MoveRelFacing(20 / 150) end),
			--

			FrameEvent(21, function(inst)
				inst.sg:AddStateTag("caninterrupt")
			end),
			FrameEvent(27, function(inst)
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

SGCommon.States.AddAttackPre(states, "smash")
SGCommon.States.AddAttackHold(states, "smash")

SGCommon.States.AddAttackPre(states, "bodyslam")
SGCommon.States.AddAttackHold(states, "bodyslam")

SGCommon.States.AddKnockbackStates(states,
{
	movement_frames = 13,
})

SGCommon.States.AddHitStates(states, SGCommon.Fns.ChooseAttack)

SGCommon.States.AddSpawnBattlefieldStates(states,
{
	anim = "spawn3",

	fadeduration = 0.5,
	fadedelay = 0.1,

	timeline =
	{
		FrameEvent(0, function(inst) inst.sg:RemoveStateTag("nointerrupt") end),
		FrameEvent(0, function(inst) SGCommon.Fns.SetMotorVelScaled(inst, 5) end),
		FrameEvent(16, function(inst) inst.Physics:Stop() end),

		FrameEvent(2, function(inst) inst:PushEvent("leave_spawner") end),

		FrameEvent(49, function(inst) inst.sg:RemoveStateTag("busy") end),
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
	},
})

SGCommon.States.AddTurnStates(states)

SGCommon.States.AddMonsterDeathStates(states)
SGRegistry:AddData("sg_cabbagerolls", states, StateGraphRegistry.Hints.SerializeMetadata)

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

return StateGraph("sg_cabbagerolls", states, events, "idle", fns)
