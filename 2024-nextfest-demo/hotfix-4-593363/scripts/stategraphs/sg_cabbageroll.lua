local EffectEvents = require "effectevents"
local SGCommon = require "stategraphs.sg_common"
local monsterutil = require "util.monsterutil"

local function OnBiteHitBoxTriggered(inst, data)
	SGCommon.Events.OnHitboxTriggered(inst, data, {
		attackdata_id = "bite",
		hitstoplevel = HitStopLevel.MEDIUM,
		pushback = 0.4,
		hitflags = Attack.HitFlags.LOW_ATTACK,
		combat_attack_fn = "DoKnockbackAttack",
		hit_fx = monsterutil.defaultAttackHitFX,
		hit_fx_offset_x = 0.5,
	})
end

local function OnRollHitBoxTriggered(inst, data)
	SGCommon.Events.OnHitboxTriggered(inst, data, {
		attackdata_id = inst.sg.statemem.active_attack or "roll",
		hitstoplevel = HitStopLevel.MEDIUM,
		hitflags = Attack.HitFlags.LOW_ATTACK,
		combat_attack_fn = "DoKnockbackAttack",
		hit_fx = monsterutil.defaultAttackHitFX,
		hit_fx_offset_x = 0.5,
		custom_attack_fn = function(attacker, attack)
			local hit = false
			if attacker.sg.statemem.knockbackonly then
				attack:SetPushback(1.25)
				hit = attacker.components.combat:DoKnockbackAttack(attack)
			else
				hit = attacker.components.combat:DoKnockdownAttack(attack)
			end

			if hit then
				attacker.sg.statemem.connected = true
			end

			return hit
		end,
	})

	if inst.sg.statemem.connected then
		local velocity = inst.Physics:GetMotorVel()
		inst.Physics:SetMotorVel(velocity * 0.25)
		if inst.sg.statemem.exit_state and inst.sg:GetTicksInState() % inst.AnimState:GetCurrentAnimationNumFrames() < inst.AnimState:GetCurrentAnimationNumFrames() * 0.5 then --if we just started the anim, stop rolling sooner and pop into the _pst
			inst.sg:GoToState(inst.sg.statemem.exit_state)
		end
		inst.sg.statemem.roll_finished = true
	end
end

local function OnCombineRequest(inst, other)
	if not inst.sg:HasStateTag("busy") then
		if other ~= nil and other:IsValid() and other:TryToTakeControl() and inst.components.combat:CanFriendlyTargetEntity(other) then
			other.components.timer:StartTimer("combine_cd", 9, true)
			inst.components.timer:StartTimer("combine_cd", 9, true)
			if inst.brain ~= nil then
				inst.brain.brain:SetCombineTarget(other)
			end
			SGCommon.Fns.TurnAndActOnTarget(inst, other, false, "calling")
		end
	end
end

local function OnCombine(inst, other)
	if not inst.sg:HasStateTag("busy") then
		if other ~= nil and other:IsValid() and other:TryToTakeControl() and other.components.cabbagerollstracker ~= nil then
			local othernum = other.components.cabbagerollstracker:GetNum()
			local state =
				(othernum == 1 and "combine") or
				(othernum == 2 and "combine3") or
				nil
			if state ~= nil then
				other:PushEvent("combinewait")
				SGCommon.Fns.TurnAndActOnTarget(inst, other, false, state, other)
			end
		end
	end
end

local function ChooseBattleCry(inst, data)
	if data.target ~= nil and data.target:IsValid() then
		if not inst.components.timer:HasTimer("whistle_cd") then
			if not inst:IsNear(data.target, 6) then
				SGCommon.Fns.TurnAndActOnTarget(inst, data.target, true, "whistle")
				return true
			end
		end
	end
	return false
end

local function ChooseIdleBehavior(inst)
	if not inst.components.timer:HasTimer("idlebehavior_cd") then
		local target = inst.components.combat:GetTarget()
		if target ~= nil then
			if not inst.components.timer:HasTimer("taunt_cd") then
				if inst.components.health:GetPercent() < .75 and not inst:IsNear(target, 6) then
					SGCommon.Fns.TurnAndActOnTarget(inst, target, true, "taunt")
					return true
				end
			end
		end
	end
	return false
end

local function OnDeath(inst, data)
	inst.components.cabbagerollstracker:Unregister()

	--Spawn death fx
	EffectEvents.MakeEventFXDeath(inst, data.attack, "death_cabbageroll")
	--Spawn loot (lootdropper will attach hitstopper)
	inst.components.lootdropper:DropLoot()

	--[[Golden bonion test
	if (inst.sg.mem.golden_mob) then
		local pos = Vector2(inst.Transform:GetWorldXZ())
		for i = 1, 20 do
			local drop = SpawnPrefab("drop_konjur")
			drop.Transform:SetPosition(pos.x, 1, pos.y)
		end
	end
	--]]
end

local events =
{
	EventHandler("combine_req", OnCombineRequest),
	EventHandler("docombine", OnCombine),
}
monsterutil.AddMonsterCommonEvents(events,
{
	ondeath_fn = OnDeath,
})
monsterutil.AddOptionalMonsterEvents(events,
{
	battlecry_fn = ChooseBattleCry,
	idlebehavior_fn = ChooseIdleBehavior,
	spawn_battlefield = true,
})
SGCommon.Fns.AddCommonSwallowedEvents(events)

local states =
{
	State({
		name = "knockdown_top",
		tags = { "knockdown", "busy", "airborne", "nointerrupt", "airborne_high" },

		onenter = function(inst)
			inst.AnimState:PlayAnimation("knockdown_top_pre")
			inst.AnimState:PushAnimation("knockdown_top_pst")
		end,

		timeline =
		{
			--physics
			FrameEvent(0, function(inst) inst.Physics:SetMotorVel(-6) end),
			FrameEvent(0, function(inst) inst.Physics:StartPassingThroughObjects() end),
			FrameEvent(23, function(inst) inst.Physics:SetMotorVel(-3) end),
			FrameEvent(24, function(inst) inst.Physics:SetMotorVel(-2) end),
			FrameEvent(25, function(inst) inst.Physics:SetMotorVel(-1) end),
			FrameEvent(26, function(inst) inst.Physics:SetMotorVel(-.5) end),
			FrameEvent(27, function(inst) inst.Physics:Stop() end),
			FrameEvent(23, function(inst) inst.Physics:StopPassingThroughObjects() end),
			--

			FrameEvent(21, function(inst)
				inst.sg:RemoveStateTag("airborne_high")
				inst.sg:RemoveStateTag("nointerrupt")
			end),
			FrameEvent(23, function(inst)
				inst.sg:RemoveStateTag("airborne")
				inst.sg:AddStateTag("caninterrupt")
			end),
		},

		events =
		{
			EventHandler("getup", function(inst)
				inst.sg.statemem.getup = true
			end),
			EventHandler("animqueueover", function(inst)
				inst.sg.statemem.knockdown = true
				inst.sg:GoToState(inst.sg.statemem.getup and "knockdown_getup" or "knockdown_idle")
			end),
		},

		onexit = function(inst)
			inst.Physics:Stop()
			inst.Physics:StopPassingThroughObjects()
		end,
	}),

	State({
		name = "knockdown_mid",
		tags = { "knockdown", "busy", "airborne", "nointerrupt" },

		onenter = function(inst)
			inst.AnimState:PlayAnimation("knockdown_pre")
		end,

		timeline =
		{
			--physics
			FrameEvent(0, function(inst) inst.Physics:SetMotorVel(-3) end),
			FrameEvent(0, function(inst) inst.Physics:StartPassingThroughObjects() end),
			FrameEvent(18, function(inst) inst.Physics:SetMotorVel(-2) end),
			FrameEvent(18, function(inst) inst.Physics:StopPassingThroughObjects() end),
			FrameEvent(19, function(inst) inst.Physics:SetMotorVel(-1) end),
			FrameEvent(20, function(inst) inst.Physics:SetMotorVel(-.5) end),
			FrameEvent(21, function(inst) inst.Physics:Stop() end),
			--

			FrameEvent(16, function(inst)
				inst.sg:RemoveStateTag("nointerrupt")
			end),
			FrameEvent(18, function(inst)
				inst.sg:RemoveStateTag("airborne")
				inst.sg:AddStateTag("caninterrupt")
			end),
		},

		events =
		{
			EventHandler("getup", function(inst)
				inst.sg.statemem.getup = true
			end),
			EventHandler("animqueueover", function(inst)
				inst.sg.statemem.knockdown = true
				inst.sg:GoToState(inst.sg.statemem.getup and "knockdown_getup" or "knockdown_idle")
			end),
		},

		onexit = function(inst)
			inst.Physics:Stop()
			inst.Physics:StopPassingThroughObjects()
		end,
	}),

	State({
		name = "knockdown_btm",
		tags = { "knockdown", "busy", "nointerrupt" },

		onenter = function(inst)
			inst.AnimState:PlayAnimation("knockdown_btm_pre")
			inst.AnimState:PushAnimation("knockdown_btm_pst")
		end,

		timeline =
		{
			--physics
			FrameEvent(0, function(inst) inst.Physics:SetMotorVel(-6) end),
			FrameEvent(12, function(inst) inst.Physics:SetMotorVel(-3) end),
			FrameEvent(14, function(inst) inst.Physics:SetMotorVel(-2) end),
			FrameEvent(15, function(inst) inst.Physics:SetMotorVel(-1) end),
			FrameEvent(16, function(inst) inst.Physics:SetMotorVel(-.5) end),
			FrameEvent(17, function(inst) inst.Physics:Stop() end),
			--

			FrameEvent(6, function(inst)
				inst.sg:RemoveStateTag("nointerrupt")
			end),
			FrameEvent(12, function(inst)
				inst.sg:AddStateTag("caninterrupt")
			end),
		},

		events =
		{
			EventHandler("getup", function(inst)
				inst.sg.statemem.getup = true
			end),
			EventHandler("animqueueover", function(inst)
				inst.sg.statemem.knockdown = true
				inst.sg:GoToState(inst.sg.statemem.getup and "knockdown_getup" or "knockdown_idle")
			end),
		},

		onexit = function(inst)
			inst.Physics:Stop()
		end,
	}),

	State({
		name = "angry",
		tags = { "busy" },

		onenter = function(inst)
			inst.AnimState:PlayAnimation("behavior")
		end,

		timeline =
		{
			--physics
			FrameEvent(4, function(inst) inst.Physics:MoveRelFacing(10 / 150) end),
			FrameEvent(5, function(inst) inst.Physics:MoveRelFacing(10 / 150) end),
			FrameEvent(34, function(inst) inst.Physics:MoveRelFacing(-10 / 150) end),
			FrameEvent(36, function(inst) inst.Physics:MoveRelFacing(-10 / 150) end),
			--

			FrameEvent(5, function(inst)
				inst.components.timer:StartTimer("angry_cd", 12, true)
				inst.components.timer:StartTimer("idlebehavior_cd", 8, true)
			end),
			FrameEvent(22, function(inst)
				inst.sg:AddStateTag("caninterrupt")
			end),
			FrameEvent(47, function(inst)
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
		name = "whistle",
		tags = { "busy" },

		onenter = function(inst)
			inst.AnimState:PlayAnimation("behavior3")
		end,

		timeline =
		{
			--physics
			FrameEvent(2, function(inst) inst.Physics:MoveRelFacing(20 / 150) end),
			FrameEvent(41, function(inst) inst.Physics:MoveRelFacing(-20 / 150) end),
			--

			FrameEvent(2, function(inst)
				inst.components.timer:StartTimer("whistle_cd", 12, true)
				inst.components.timer:StartTimer("idlebehavior_cd", 8, true)
			end),
			FrameEvent(28, function(inst)
				inst.sg:AddStateTag("caninterrupt")
			end),
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
		name = "calling",
		tags = { "busy", "cancombine" },

		onenter = function(inst)
			inst.AnimState:PlayAnimation("gather")
		end,

		timeline =
		{
			FrameEvent(10, function(inst)
				if inst.sg.statemem.queuedcombine ~= nil and inst.sg.statemem.queuedcombine:IsValid() then
					inst.sg.statemem.queuedcombine:PushEvent("combinewait")
				else
					inst.sg.statemem.queuedcombine = nil
				end
			end),
			FrameEvent(30, function(inst)
				inst.sg:AddStateTag("caninterrupt")
			end),
			FrameEvent(35, function(inst)
				if inst.sg.statemem.queuedcombine ~= nil and inst.sg.statemem.queuedcombine:IsValid() then
					inst.sg.statemem.queuedcombine:PushEvent("combinewait")
				else
					inst.sg.statemem.queuedcombine = nil
				end
			end),
			FrameEvent(55, function(inst)
				inst.sg:RemoveStateTag("busy")
				OnCombine(inst, inst.sg.statemem.queuedcombine)
			end),
		},

		events =
		{
			EventHandler("docombine", function(inst, other)
				if inst.sg:HasStateTag("busy") then
					if other ~= nil then
						inst.sg.statemem.queuedcombine = other
						other:PushEvent("combinewait")
					end
				else
					OnCombine(inst, other)
				end
			end),
			EventHandler("animover", function(inst)
				inst.sg:GoToState("idle")
			end),
		},
	}),

	State({
		name = "taunt",
		tags = { "busy", "caninterrupt" },

		onenter = function(inst)
			inst.AnimState:PlayAnimation("behavior2")
		end,

		timeline =
		{
			--physics
			FrameEvent(4, function(inst) inst.Physics:MoveRelFacing(6 / 150) end),
			FrameEvent(6, function(inst) inst.Physics:MoveRelFacing(8 / 150) end),
			FrameEvent(8, function(inst) inst.Physics:MoveRelFacing(8 / 150) end),
			FrameEvent(40, function(inst) inst.Physics:MoveRelFacing(-22 / 150) end),
			--

			FrameEvent(6, function(inst)
				inst.components.timer:StartTimer("taunt_cd", 12, true)
				inst.components.timer:StartTimer("idlebehavior_cd", 8, true)
			end),
			FrameEvent(44, function(inst)
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
			inst.components.hitbox:StopRepeatTargetDelay()
		end,
	}),

	State({
		name = "bite",
		tags = { "attack", "busy" },

		onenter = function(inst, target)
			inst.AnimState:PlayAnimation("bite")
			inst.sg.statemem.speedmult = 1
			if target ~= nil and target:IsValid() then
				local facingrot = inst.Transform:GetFacingRotation()
				local diff
				local dir = inst:GetAngleTo(target)
				diff = ReduceAngle(dir - facingrot)

				if math.abs(diff) < 90 then
					local x, z = inst.Transform:GetWorldXZ()
					local x1, z1 = target.Transform:GetWorldXZ()
					local dx = math.abs(x1 - x)
					local dz = math.abs(z1 - z)
					local dx1 = math.max(0, dx - inst.Physics:GetSize() - target.Physics:GetSize())
					local dz1 = math.max(0, dz - inst.Physics:GetDepth() - target.Physics:GetDepth())
					local mult = math.max(dx1 ~= 0 and dx1 / dx or 0, dz1 ~= 0 and dz1 / dz or 0)
					local dist = math.sqrt(dx * dx + dz * dz) * mult

					inst.sg.statemem.speedmult = math.clamp(dist / 2.5, .25, 2.0)
				end
			end
		end,

		timeline =
		{
			--physics
			FrameEvent(1, function(inst) inst.Physics:MoveRelFacing(18 / 150) end),
			FrameEvent(2, function(inst) SGCommon.Fns.SetMotorVelScaled(inst, 5 * inst.sg.statemem.speedmult) end),
			FrameEvent(3, function(inst) SGCommon.Fns.SetMotorVelScaled(inst, 6 * inst.sg.statemem.speedmult) end),
			FrameEvent(11, function(inst) inst.sg.statemem.speedmult = math.sqrt(inst.sg.statemem.speedmult) end),
			FrameEvent(11, function(inst) SGCommon.Fns.SetMotorVelScaled(inst, 3 * inst.sg.statemem.speedmult) end),
			FrameEvent(13, function(inst) SGCommon.Fns.SetMotorVelScaled(inst, 2 * inst.sg.statemem.speedmult) end),
			FrameEvent(14, function(inst) SGCommon.Fns.SetMotorVelScaled(inst, 1 * inst.sg.statemem.speedmult) end),
			FrameEvent(15, function(inst) SGCommon.Fns.SetMotorVelScaled(inst, .5 * inst.sg.statemem.speedmult) end),
			FrameEvent(16, function(inst) inst.Physics:Stop() end),
			--

			FrameEvent(2, function(inst)
				inst.sg:AddStateTag("airborne")
				inst.Physics:StartPassingThroughObjects()
			end),
			FrameEvent(13, function(inst)
				inst.sg:RemoveStateTag("airborne")
				inst.Physics:StopPassingThroughObjects()
				inst.components.attacktracker:CompleteActiveAttack()
				inst.components.hitbox:StartRepeatTargetDelay()
				inst.components.hitbox:PushBeam(0, 1.5, 1.3, HitPriority.MOB_DEFAULT)
			end),
			FrameEvent(14, function(inst)
				inst.components.hitbox:PushBeam(0, 1.3, 1.2, HitPriority.MOB_DEFAULT)
			end),
			FrameEvent(15, function(inst)
				inst.components.hitbox:PushBeam(0, 1.2, 1.1, HitPriority.MOB_DEFAULT)
			end),
			FrameEvent(23, function(inst)
				inst.sg:AddStateTag("caninterrupt")
			end),
			FrameEvent(29, function(inst)
				inst.sg:RemoveStateTag("busy")
			end),
		},

		events =
		{
			EventHandler("hitboxtriggered", OnBiteHitBoxTriggered),
			EventHandler("animover", function(inst)
				inst.sg:GoToState("idle")
			end),
		},

		onexit = function(inst)
			inst.Physics:StopPassingThroughObjects()
			inst.Physics:Stop()
			inst.components.hitbox:StopRepeatTargetDelay()
			inst.components.attacktracker:CompleteActiveAttack()
		end,
	}),

	State({
		name = "roll",
		tags = { "attack", "busy" },

		onenter = function(inst, target)
			inst.AnimState:PlayAnimation("roll_loop", true)
			inst.sg.statemem.target = target
			inst.sg.statemem.knockbackonly = true
			SGCommon.Fns.SetMotorVelScaled(inst, 10)
			inst.sg:SetTimeoutAnimFrames(TUNING.cabbageroll.roll_animframes)
			inst.sg.statemem.roll_finished = false
			inst.Physics:StartPassingThroughObjects()
			inst.sg.statemem.exit_state = "roll_pst"
			inst.sg.statemem.active_attack = "roll"
		end,

		onupdate = function(inst)
			if inst.sg.statemem.hitting then
				inst.components.hitbox:PushBeam(0.25, 1.25, 1.25, HitPriority.MOB_DEFAULT)
			end
		end,

		timeline =
		{
			--physics
			FrameEvent(0, function(inst)
				local facingrot = inst.Transform:GetFacingRotation()
				local target = inst.sg.statemem.target
				local diff
				if target ~= nil and target:IsValid() then
					local dir = inst:GetAngleTo(target)
					diff = ReduceAngle(dir - facingrot)
					if math.abs(diff) >= 90 then
						diff = nil
					end
				end
				if diff == nil then
					local dir = inst.Transform:GetRotation()
					diff = ReduceAngle(dir - facingrot)
				end
				diff = math.clamp(diff, -30, 30)
				inst.Transform:SetRotation(facingrot + diff)
			end),
			--
			FrameEvent(0, function(inst)
				inst.sg:AddStateTag("airborne")
				inst.components.hitbox:StartRepeatTargetDelay()
				inst.components.attacktracker:CompleteActiveAttack()
			end),

			FrameEvent(2, function(inst)
				inst.sg.statemem.hitting = true
			end),
		},

		events =
		{
			EventHandler("hitboxtriggered", OnRollHitBoxTriggered),
			EventHandler("animover", function(inst)
				if inst.sg.statemem.roll_finished then
					inst.sg:GoToState(inst.sg.statemem.exit_state)
				end
			end),
		},


		ontimeout = function(inst)
			inst.sg.statemem.roll_finished = true -- don't transition yet... set a flag that it -can- transition on the next anim loop
		end,

		onexit = function(inst)
			inst.components.hitbox:StopRepeatTargetDelay()
			inst.Physics:StopPassingThroughObjects()
			inst.components.attacktracker:CompleteActiveAttack()
		end,
	}),

		State({
		name = "roll_pst",
		tags = { "busy", "airborne" },

		onenter = function(inst)
			inst.AnimState:PlayAnimation("roll_pst")
		end,

		timeline =
		{
			--physics
			FrameEvent(0, function(inst) SGCommon.Fns.SetMotorVelScaled(inst, 5) end),
			FrameEvent(3, function(inst) SGCommon.Fns.SetMotorVelScaled(inst, 4) end),
			FrameEvent(4, function(inst) SGCommon.Fns.SetMotorVelScaled(inst, 3) end),
			FrameEvent(5, function(inst) SGCommon.Fns.SetMotorVelScaled(inst, 2) end),
			FrameEvent(6, function(inst) SGCommon.Fns.SetMotorVelScaled(inst, 1) end),
			FrameEvent(7, function(inst) SGCommon.Fns.SetMotorVelScaled(inst, .5) end),
			FrameEvent(8, function(inst) inst.Physics:Stop() end),

			--
			FrameEvent(0, function(inst)
				inst.sg:RemoveStateTag("airborne")
			end),

			FrameEvent(5, function(inst)
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
			EventHandler("hitboxtriggered", OnRollHitBoxTriggered),
		},

		onexit = function(inst) inst.Physics:Stop() end,
	}),

State({
		name = "elite_roll",
		tags = { "attack", "busy" },

		onenter = function(inst, target)
			inst.AnimState:PlayAnimation("elite_roll_loop", true)
			inst.sg.statemem.target = target
			inst.sg.statemem.knockbackonly = true
			SGCommon.Fns.SetMotorVelScaled(inst, 30, SGCommon.SGSpeedScale.LIGHT) -- This attack is already so fast, don't let speedmult scale it much more
			inst.sg:SetTimeoutAnimFrames(inst.tuning.roll_animframes)
			inst.sg.statemem.roll_finished = false
			inst.Physics:StartPassingThroughObjects()
			inst.sg.statemem.active_attack = "elite_roll"
			inst.sg.statemem.exit_state = "elite_roll_pst"
		end,

		onupdate = function(inst)
			if inst.sg.statemem.hitting then
				inst.components.hitbox:PushBeam(0.25, 1.25, 1.25, HitPriority.MOB_DEFAULT)
			end
		end,

		timeline =
		{
			-- --physics
			FrameEvent(0, function(inst)
				local facingrot = inst.Transform:GetFacingRotation()
				local target = inst.sg.statemem.target
				local diff
				if target ~= nil and target:IsValid() then
					local dir = inst:GetAngleTo(target)
					diff = ReduceAngle(dir - facingrot)
					if math.abs(diff) >= 90 then
						diff = nil
					end
				end
				if diff == nil then
					local dir = inst.Transform:GetRotation()
					diff = ReduceAngle(dir - facingrot)
				end
				diff = math.clamp(diff, -30, 30)
				inst.Transform:SetRotation(facingrot + diff)
			end),

			--
			FrameEvent(0, function(inst)
				inst.sg:AddStateTag("airborne")
				inst.components.hitbox:StartRepeatTargetDelay()
				inst.components.attacktracker:CompleteActiveAttack()
			end),

			FrameEvent(2, function(inst)
				inst.sg.statemem.hitting = true
			end),
		},

		events =
		{
			EventHandler("hitboxtriggered", OnRollHitBoxTriggered),
			EventHandler("animover", function(inst)
				if inst.sg.statemem.roll_finished then
					inst.sg:GoToState("elite_roll_pst")
				end
			end),
		},


		ontimeout = function(inst)
			inst.sg.statemem.roll_finished = true -- don't transition yet... set a flag that it -can- transition on the next anim loop
		end,

		onexit = function(inst)
			inst.components.hitbox:StopRepeatTargetDelay()
			inst.Physics:StopPassingThroughObjects()
			inst.components.attacktracker:CompleteActiveAttack()
		end,
	}),

		State({
		name = "elite_roll_pst",
		tags = { "busy", "airborne" },

		onenter = function(inst)
			inst.AnimState:PlayAnimation("elite_roll_pst")
		end,

		timeline =
		{
			--physics
			FrameEvent(0, function(inst) SGCommon.Fns.SetMotorVelScaled(inst, 5, SGCommon.SGSpeedScale.LIGHT) end),
			FrameEvent(3, function(inst) SGCommon.Fns.SetMotorVelScaled(inst, 4, SGCommon.SGSpeedScale.LIGHT) end),
			FrameEvent(4, function(inst) SGCommon.Fns.SetMotorVelScaled(inst, 3, SGCommon.SGSpeedScale.LIGHT) end),
			FrameEvent(5, function(inst) SGCommon.Fns.SetMotorVelScaled(inst, 2, SGCommon.SGSpeedScale.LIGHT) end),
			FrameEvent(6, function(inst) SGCommon.Fns.SetMotorVelScaled(inst, 1, SGCommon.SGSpeedScale.LIGHT) end),
			FrameEvent(7, function(inst) SGCommon.Fns.SetMotorVelScaled(inst, .5, SGCommon.SGSpeedScale.LIGHT) end),
			FrameEvent(8, function(inst) inst.Physics:Stop() end),

			--
			FrameEvent(0, function(inst)
				inst.sg:RemoveStateTag("airborne")
			end),

			FrameEvent(5, function(inst)
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
			EventHandler("hitboxtriggered", OnRollHitBoxTriggered),
		},

		onexit = function(inst) inst.Physics:Stop() end,
	}),

	State({
		name = "bodyslam_top",
		tags = { "busy" },

		onenter = function(inst)
			inst.AnimState:PlayAnimation("bodyslam_top")
		end,

		timeline =
		{
			--physics
			FrameEvent(0, function(inst) SGCommon.Fns.SetMotorVelScaled(inst, 7) end),
			FrameEvent(10, function(inst) SGCommon.Fns.SetMotorVelScaled(inst, 5) end),
			FrameEvent(18, function(inst) SGCommon.Fns.SetMotorVelScaled(inst, 2) end),
			FrameEvent(19, function(inst) SGCommon.Fns.SetMotorVelScaled(inst, 1) end),
			FrameEvent(20, function(inst) inst.Physics:Stop() end),
			FrameEvent(20, function(inst) inst.Physics:MoveRelFacing(-10 / 150) end),
			FrameEvent(22, function(inst) inst.Physics:MoveRelFacing(-10 / 150) end),
			--
			FrameEvent(2, function(inst)
				inst.sg:AddStateTag("airborne")
			end),
			FrameEvent(10, function(inst)
				inst.sg:RemoveStateTag("airborne")
			end),
			FrameEvent(22, function(inst)
				inst.sg:RemoveStateTag("caninterrupt")
			end),
			FrameEvent(24, function(inst)
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
			inst.Physics:Stop()
			inst.components.hitbox:StopRepeatTargetDelay()
		end,
	}),

	State({
		name = "bodyslam_mid",
		tags = { "busy", "airborne", "nointerrupt" },

		onenter = function(inst)
			inst.AnimState:PlayAnimation("bodyslam_mid")
		end,

		timeline =
		{
			--physics
			FrameEvent(0, function(inst) SGCommon.Fns.SetMotorVelScaled(inst, 2) end),
			FrameEvent(4, function(inst) SGCommon.Fns.SetMotorVelScaled(inst, 1.5) end),
			FrameEvent(10, function(inst) SGCommon.Fns.SetMotorVelScaled(inst, 1) end),
			FrameEvent(12, function(inst) SGCommon.Fns.SetMotorVelScaled(inst, .5) end),
			FrameEvent(19, function(inst) inst.Physics:Stop() end),
			--

			FrameEvent(12, function(inst)
				inst.sg:RemoveStateTag("nointerrupt")
			end),
			FrameEvent(19, function(inst)
				inst.sg:RemoveStateTag("airborne")
			end),
			FrameEvent(23, function(inst)
				inst.sg:RemoveStateTag("caninterrupt")
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

		onexit = function(inst) inst.Physics:Stop() end,
	}),

	State({
		name = "bodyslam_btm",
		tags = { "busy" },

		onenter = function(inst)
			inst.AnimState:PlayAnimation("bodyslam_btm")
		end,

		timeline =
		{
			--physics
			FrameEvent(0, function(inst) SGCommon.Fns.SetMotorVelScaled(inst, -3.5) end),
			--
			FrameEvent(2, function(inst)
				inst.sg:AddStateTag("airborne")
			end),
		},

		events =
		{
			EventHandler("animover", function(inst)
				inst.sg.statemem.pst = true
				inst:FlipFacingAndRotation()
				inst.sg:GoToState("bodyslam_btm_pst")
			end),
		},

		onexit = function(inst)
			if not inst.sg.statemem.pst then
				inst.Physics:Stop()
			end
		end,
	}),

	State({
		name = "bodyslam_btm_pst",
		tags = { "busy", "airborne" },

		onenter = function(inst)
			inst.AnimState:PlayAnimation("bodyslam_btm_flip_pst")
		end,

		timeline =
		{
			--physics
			FrameEvent(0, function(inst) SGCommon.Fns.SetMotorVelScaled(inst, -3.5) end),
			FrameEvent(2, function(inst) SGCommon.Fns.SetMotorVelScaled(inst, 2.5) end),
			FrameEvent(10, function(inst) SGCommon.Fns.SetMotorVelScaled(inst, 2) end),
			FrameEvent(11, function(inst) SGCommon.Fns.SetMotorVelScaled(inst, 1) end),
			FrameEvent(12, function(inst) SGCommon.Fns.SetMotorVelScaled(inst, .5) end),
			FrameEvent(13, function(inst) inst.Physics:Stop() end),
			FrameEvent(15, function(inst) inst.Physics:MoveRelFacing(-10 / 150) end),
			--

			FrameEvent(2, function(inst)
				inst.sg:RemoveStateTag("airborne")
			end),
			FrameEvent(12, function(inst)
				inst.sg:RemoveStateTag("caninterrupt")
			end),
			FrameEvent(15, function(inst)
				inst.sg:RemoveStateTag("busy")
			end),
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
		name = "catapult",
		tags = { "attack", "busy", "airborne", "nointerrupt" },

		onenter = function(inst, btm)
			inst.AnimState:PlayAnimation("catapult")
			if btm ~= nil and btm:IsValid() then
				inst.sg.statemem.btm = btm
				inst.components.hitstopper:AttachChild(btm)
			end
		end,

		onupdate = function(inst)
			if inst.sg.statemem.hitting then
				if inst.sg.statemem.btm ~= nil then
					if inst.sg.statemem.btm:IsValid() then
						inst.components.hitbox:PushBeam(-3, 1, 1, HitPriority.MOB_DEFAULT)
						return
					end
					inst.sg.statemem.btm = nil
				end
				inst.components.hitbox:PushBeam(-1, 1, 1, HitPriority.MOB_DEFAULT)
			end
		end,

		timeline =
		{
			--physics
			FrameEvent(0, function(inst) SGCommon.Fns.SetMotorVelScaled(inst, 32) end),
			FrameEvent(4, function(inst) SGCommon.Fns.SetMotorVelScaled(inst, 26) end),
			FrameEvent(5, function(inst) SGCommon.Fns.SetMotorVelScaled(inst, 22) end),
			FrameEvent(6, function(inst) SGCommon.Fns.SetMotorVelScaled(inst, 18) end),
			FrameEvent(14, function(inst) SGCommon.Fns.SetMotorVelScaled(inst, 8) end),
			FrameEvent(22, function(inst) SGCommon.Fns.SetMotorVelScaled(inst, 2) end),
			FrameEvent(23, function(inst) SGCommon.Fns.SetMotorVelScaled(inst, 1) end),
			FrameEvent(24, function(inst) inst.Physics:Stop() end),
			FrameEvent(24, function(inst) inst.Physics:MoveRelFacing(-10 / 150) end),
			FrameEvent(26, function(inst) inst.Physics:MoveRelFacing(-10 / 150) end),
			--

			FrameEvent(0, function(inst)
				inst.components.hitbox:StartRepeatTargetDelay()
				inst.sg.statemem.hitting = true
			end),
			FrameEvent(2, function(inst)
				if inst.sg.statemem.btm ~= nil then
					inst.components.hitstopper:DetachChild(inst.sg.statemem.btm)
					inst.sg.statemem.btm = nil
				end
			end),
			FrameEvent(4, function(inst)
				inst.sg:RemoveStateTag("airborne")
			end),
			FrameEvent(6, function(inst)
				inst.sg:AddStateTag("airborne")
			end),
			FrameEvent(10, function(inst)
				inst.sg:RemoveStateTag("nointerrupt")
			end),
			FrameEvent(14, function(inst)
				inst.sg:RemoveStateTag("airborne")
			end),
			FrameEvent(16, function(inst)
				inst.sg.statemem.knockbackonly = true
			end),
			FrameEvent(22, function(inst)
				inst.sg.statemem.hitting = false
			end),
			FrameEvent(26, function(inst)
				inst.sg:AddStateTag("caninterrupt")
			end),
			FrameEvent(28, function(inst)
				inst.sg:RemoveStateTag("busy")
			end),
		},

		events =
		{
			EventHandler("hitboxtriggered", OnRollHitBoxTriggered),
			EventHandler("animover", function(inst)
				inst.sg:GoToState("idle")
			end),
		},

		onexit = function(inst)
			inst.Physics:Stop()
			inst.components.hitbox:StopRepeatTargetDelay()
			if inst.sg.statemem.btm ~= nil then
				inst.components.hitstopper:DetachChild(inst.sg.statemem.btm)
			end
		end,
	}),

	State({
		name = "thrown",
		tags = { "attack", "busy", "airborne", "nointerrupt" },

		onenter = function(inst, btm)
			inst.AnimState:PlayAnimation("thrown")
			if btm ~= nil and btm:IsValid() then
				inst.sg.statemem.btm = btm
				inst.components.hitstopper:AttachChild(btm)
			end
			inst.Physics:StartPassingThroughObjects()
		end,

		onupdate = function(inst)
			if inst.sg.statemem.hitting then
				if inst.sg.statemem.btm ~= nil then
					if inst.sg.statemem.btm:IsValid() then
						inst.components.hitbox:PushBeam(-2, 1.5, 1, HitPriority.MOB_DEFAULT)
						return
					end
					inst.sg.statemem.btm = nil
				end
				inst.components.hitbox:PushBeam(0.20, 1.50, 1.00, HitPriority.MOB_DEFAULT)
			end
		end,

		timeline =
		{
			--physics
			FrameEvent(0, function(inst) SGCommon.Fns.SetMotorVelScaled(inst, 24) end),
			FrameEvent(4, function(inst) SGCommon.Fns.SetMotorVelScaled(inst, 20) end),
			FrameEvent(5, function(inst) SGCommon.Fns.SetMotorVelScaled(inst, 18) end),
			FrameEvent(6, function(inst) SGCommon.Fns.SetMotorVelScaled(inst, 16) end),
			FrameEvent(14, function(inst) SGCommon.Fns.SetMotorVelScaled(inst, 8) end),
			FrameEvent(22, function(inst) SGCommon.Fns.SetMotorVelScaled(inst, 2) end),
			FrameEvent(23, function(inst) SGCommon.Fns.SetMotorVelScaled(inst, 1) end),
			FrameEvent(24, function(inst) inst.Physics:Stop() end),
			FrameEvent(24, function(inst) inst.Physics:MoveRelFacing(-10 / 150) end),
			FrameEvent(26, function(inst) inst.Physics:MoveRelFacing(-10 / 150) end),
			--

			FrameEvent(0, function(inst)
				inst.components.hitbox:StartRepeatTargetDelay()
				inst.sg.statemem.hitting = true
			end),
			FrameEvent(2, function(inst)
				if inst.sg.statemem.btm ~= nil then
					inst.components.hitstopper:DetachChild(inst.sg.statemem.btm)
					inst.sg.statemem.btm = nil
				end
			end),
			FrameEvent(4, function(inst)
				inst.sg:RemoveStateTag("airborne")
			end),
			FrameEvent(6, function(inst)
				inst.sg:AddStateTag("airborne")
			end),
			FrameEvent(10, function(inst)
				inst.sg:RemoveStateTag("caninterrupt")
			end),
			FrameEvent(14, function(inst)
				inst.sg:RemoveStateTag("airborne")
				inst.Physics:StopPassingThroughObjects()
			end),
			FrameEvent(16, function(inst)
				inst.sg.statemem.knockbackonly = true
			end),
			FrameEvent(22, function(inst)
				inst.sg.statemem.hitting = false
			end),
			FrameEvent(26, function(inst)
				inst.sg:AddStateTag("caninterrupt")
			end),
			FrameEvent(28, function(inst)
				inst.sg:RemoveStateTag("busy")
			end),
		},

		events =
		{
			EventHandler("hitboxtriggered", OnRollHitBoxTriggered),
			EventHandler("animover", function(inst)
				inst.sg:GoToState("idle")
			end),
		},

		onexit = function(inst)
			inst.Physics:Stop()
			inst.Physics:StartPassingThroughObjects()
			inst.components.hitbox:StopRepeatTargetDelay()
		end,
	}),

	State({
		name = "throw_pst",
		tags = { "attack", "busy", "airborne", "nointerrupt" },

		onenter = function(inst, speed)
			inst.AnimState:PlayAnimation("throw_pst")
			inst.sg.statemem.speed = speed or 4
			inst.Physics:StartPassingThroughObjects()
		end,

		timeline =
		{
			--physics
			FrameEvent(0, function(inst) SGCommon.Fns.SetMotorVelScaled(inst, inst.sg.statemem.speed) end),
			FrameEvent(4, function(inst) SGCommon.Fns.SetMotorVelScaled(inst, 1) end),
			FrameEvent(5, function(inst) SGCommon.Fns.SetMotorVelScaled(inst, .5) end),
			FrameEvent(6, function(inst) inst:SnapToFacingRotation() end),
			FrameEvent(6, function(inst) SGCommon.Fns.SetMotorVelScaled(inst, 4) end),
			FrameEvent(11, function(inst) SGCommon.Fns.SetMotorVelScaled(inst, 3) end),
			FrameEvent(14, function(inst) SGCommon.Fns.SetMotorVelScaled(inst, 2) end),
			FrameEvent(17, function(inst) SGCommon.Fns.SetMotorVelScaled(inst, 1) end),
			FrameEvent(21, function(inst) inst.Physics:Stop() end),
			--

			FrameEvent(2, function(inst)
				inst.sg:RemoveStateTag("nointerrupt")
			end),
			FrameEvent(4, function(inst)
				inst.sg:RemoveStateTag("airborne")
				inst.Physics:StopPassingThroughObjects()
			end),
			FrameEvent(25, function(inst)
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

		onexit = function(inst)
			inst.Physics:Stop()
			inst.Physics:StopPassingThroughObjects()
		end,
	}),

	State({
		name = "combine",
		tags = { "busy" },

		onenter = function(inst, target)
			inst.AnimState:PlayAnimation("combine")
			if target ~= nil and target:IsValid() then
				local dist = math.sqrt(inst:GetDistanceSqTo(target))
				--constant speed over 14 frames
				inst.sg.statemem.speed = math.min(6, dist / 14 * 30)
				inst.sg.statemem.target = target
			else
				inst.sg.statemem.speed = 6
			end
		end,

		timeline =
		{
			--physics
			FrameEvent(3, function(inst)
				local target = inst.sg.statemem.target
				if target ~= nil and target:IsValid() then
					local dir = inst:GetAngleTo(target)
					local facingrot = inst.Transform:GetFacingRotation()
					if DiffAngle(dir, facingrot) < 90 then
						inst.Transform:SetRotation(dir)
					end
				else
					inst.sg.statemem.target = nil
				end
			end),
			FrameEvent(3, function(inst) inst.Physics:StartPassingThroughObjects() end),
			FrameEvent(3, function(inst) inst.Physics:SetMotorVel(inst.sg.statemem.speed) end), -- TODO #speedmult will changing this make them way more likely to miss?
			--

			FrameEvent(6, function(inst)
				inst.sg:AddStateTag("airborne")
				inst.sg:AddStateTag("nointerrupt")
			end),
		},

		events =
		{
			EventHandler("animover", function(inst)
				local target = inst.sg.statemem.target
				if target ~= nil and target:IsValid() then
					if (target:TryToTakeControl() and
						(not target.sg:HasStateTag("busy")
							or target.sg:HasStateTag("caninterrupt")
							or target.sg:HasStateTag("cancombine"))
							and target:IsNear(inst, .5)) then

						-- calculate absolute hp before Set[Double/Triple] as that changes things on target
						local hp = inst.components.health:GetCurrent() + target.components.health:GetCurrent()

						target.components.cabbagetower:SetDouble(inst)
						target.sg:GoToState("combine")

						target.components.health:SetCurrent(hp, true)
						target.components.cabbagetower:SetStartingHealthPercentage(target.components.health:GetPercent())

						local tgt = target.components.combat:GetTarget() or inst.components.combat:GetTarget()
						target.components.combat:SetTarget(tgt)

						target.Transform:SetRotation(inst.Transform:GetFacingRotation())
						target.Transform:SetRotation(inst.Transform:GetRotation())
						return
					end
				end

				inst.sg.statemem.combining = true
				inst.sg:GoToState("combine_miss", inst.sg.statemem.speed)
			end),
		},

		onexit = function(inst)
			if not inst.sg.statemem.combining then
				inst.Physics:Stop()
			end
			inst.Physics:StopPassingThroughObjects()
		end,
	}),

	State({
		name = "combine_miss",
		tags = { "busy", "airborne", "nointerrupt" },

		onenter = function(inst, speed)
			inst.AnimState:PlayAnimation("combine_miss")
			inst.sg.statemem.speed = speed or 0
			inst.sg.statemem.speedmult = math.min(2, inst.sg.statemem.speed / 2) / 2
		end,

		timeline =
		{
			--physics
			FrameEvent(0, function(inst) inst.Physics:SetMotorVel(inst.sg.statemem.speed) end),
			FrameEvent(3, function(inst) inst.Physics:SetMotorVel(2 * inst.sg.statemem.speedmult) end),
			FrameEvent(4, function(inst) inst.Physics:SetMotorVel(1 * inst.sg.statemem.speedmult) end),
			FrameEvent(5, function(inst) inst.Physics:SetMotorVel(.5 * inst.sg.statemem.speedmult) end),
			FrameEvent(6, function(inst) inst.Physics:Stop() end),
			--

			FrameEvent(1, function(inst)
				inst.sg:RemoveStateTag("nointerrupt")
			end),
			FrameEvent(3, function(inst)
				inst.sg:RemoveStateTag("airborne")
			end),
			FrameEvent(7, function(inst)
				inst.sg:AddStateTag("caninterrupt")
			end),
			FrameEvent(11, function(inst)
				inst.sg:RemoveStateTag("busy")
			end),
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
		name = "combine3",
		tags = { "busy" },

		onenter = function(inst, target)
			inst.AnimState:PlayAnimation("combine3")
			if target ~= nil and target:IsValid() and target:TryToTakeControl() then
				local dist = math.sqrt(inst:GetDistanceSqTo(target))
				--constant speed over 16 frames
				inst.sg.statemem.speed = math.min(6, dist / 16 * 30)
				inst.sg.statemem.target = target
			else
				inst.sg.statemem.speed = 6
			end
		end,

		timeline =
		{
			--physics
			FrameEvent(3, function(inst)
				local target = inst.sg.statemem.target
				if target ~= nil and target:IsValid() and target:TryToTakeControl() then
					local dir = inst:GetAngleTo(target)
					local facingrot = inst.Transform:GetFacingRotation()
					if DiffAngle(dir, facingrot) < 90 then
						inst.Transform:SetRotation(dir)
					end
				else
					inst.sg.statemem.target = nil
				end
			end),
			FrameEvent(3, function(inst) inst.Physics:StartPassingThroughObjects() end),
			FrameEvent(3, function(inst) inst.Physics:SetMotorVel(inst.sg.statemem.speed) end),
			--

			FrameEvent(6, function(inst)
				inst.sg:AddStateTag("airborne")
				inst.sg:AddStateTag("nointerrupt")
			end),
			FrameEvent(7, function(inst) inst.sg:AddStateTag("airborne_high") end),
			FrameEvent(17, function(inst) inst.sg:RemoveStateTag("airborne_high") end),
		},

		events =
		{
			EventHandler("animover", function(inst)
				local target = inst.sg.statemem.target
				if target ~= nil and target:IsValid() then
					if (target:TryToTakeControl() and
						(not target.sg:HasStateTag("busy")
							or target.sg:HasStateTag("caninterrupt")
							or target.sg:HasStateTag("cancombine"))
							and target:IsNear(inst, .5)) then

						-- calculate absolute hp before Set[Double/Triple] as that changes things on target
						local hp = inst.components.health:GetCurrent() + target.components.health:GetCurrent()

						target.components.cabbagetower:SetTriple(inst)
						target.sg:GoToState("combine3")

						target.components.health:SetCurrent(hp, true)
						target.components.cabbagetower:SetStartingHealthPercentage(target.components.health:GetPercent())

						local tgt = target.components.combat:GetTarget() or inst.components.combat:GetTarget()
						target.components.combat:SetTarget(tgt)

						--my facing/rotation
						target.Transform:SetRotation(inst.Transform:GetFacingRotation())
						target.Transform:SetRotation(inst.Transform:GetRotation())
						return
					end
				end

				inst.sg.statemem.combining = true
				inst.sg:GoToState("combine3_miss", inst.sg.statemem.speed)
			end),
		},

		onexit = function(inst)
			if not inst.sg.statemem.combining then
				inst.Physics:Stop()
			end
			inst.Physics:StopPassingThroughObjects()
		end,
	}),

	State({
		name = "combine3_miss",
		tags = { "busy", "airborne", "nointerrupt" },

		onenter = function(inst, speed)
			inst.AnimState:PlayAnimation("combine3_miss")
			inst.sg.statemem.speed = speed or 0
			inst.sg.statemem.speedmult = math.min(2, inst.sg.statemem.speed / 2) / 2
		end,

		timeline =
		{
			--physics
			FrameEvent(0, function(inst) inst.Physics:SetMotorVel(inst.sg.statemem.speed) end),
			FrameEvent(2, function(inst) inst.Physics:SetMotorVel(2 * inst.sg.statemem.speedmult) end),
			FrameEvent(3, function(inst) inst.Physics:SetMotorVel(1 * inst.sg.statemem.speedmult) end),
			FrameEvent(4, function(inst) inst.Physics:SetMotorVel(.5 * inst.sg.statemem.speedmult) end),
			FrameEvent(5, function(inst) inst.Physics:Stop() end),
			--

			FrameEvent(1, function(inst)
				inst.sg:RemoveStateTag("nointerrupt")
			end),
			FrameEvent(2, function(inst)
				inst.sg:RemoveStateTag("airborne")
			end),
			FrameEvent(6, function(inst)
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

		onexit = function(inst) inst.Physics:Stop() end,
	}),
}

SGCommon.States.AddAttackPre(states, "bite")
SGCommon.States.AddAttackHold(states, "bite")

SGCommon.States.AddAttackPre(states, "roll")
SGCommon.States.AddAttackHold(states, "roll")

SGCommon.States.AddAttackPre(states, "elite_roll")
SGCommon.States.AddAttackHold(states, "elite_roll")

SGCommon.States.AddHitStates(states, SGCommon.Fns.ChooseAttack)

SGCommon.States.AddIdleStates(states)

SGCommon.States.AddKnockbackStates(states,
{
	movement_frames = 9,
})

SGCommon.States.AddKnockdownStates(states,
{
	movement_frames = 18,
	knockdown_pre_timeline =
	{
		FrameEvent(0, function(inst)
			inst.Physics:StartPassingThroughObjects()
			SGCommon.Fns.StartJumpingOverHoles(inst)
		end),
		FrameEvent(16, function(inst)
			inst.Physics:StopPassingThroughObjects()
			SGCommon.Fns.StopJumpingOverHoles(inst)
		end),
	},

	knockdown_pre_onexit = function(inst)
		inst.Physics:StopPassingThroughObjects()
	end,

	knockdown_getup_timeline =
	{
		FrameEvent(2, function(inst) SGCommon.Fns.SetMotorVelScaled(inst, 6, SGCommon.SGSpeedScale.LIGHT) end),
		FrameEvent(4, function(inst) SGCommon.Fns.SetMotorVelScaled(inst, 5, SGCommon.SGSpeedScale.LIGHT) end),
		FrameEvent(6, function(inst) SGCommon.Fns.SetMotorVelScaled(inst, 4, SGCommon.SGSpeedScale.LIGHT) end),
		FrameEvent(9, function(inst) SGCommon.Fns.SetMotorVelScaled(inst, 3, SGCommon.SGSpeedScale.LIGHT) end),
		FrameEvent(11, function(inst) SGCommon.Fns.SetMotorVelScaled(inst, 2, SGCommon.SGSpeedScale.LIGHT) end),
		FrameEvent(13, function(inst) SGCommon.Fns.SetMotorVelScaled(inst, 1, SGCommon.SGSpeedScale.LIGHT) end),
		FrameEvent(14, function(inst) inst.Physics:Stop() end),
		FrameEvent(18, function(inst) inst.Physics:MoveRelFacing(-24 / 150) end),
		--

		FrameEvent(2, function(inst)
			inst.sg:RemoveStateTag("knockdown")
			inst.sg:AddStateTag("airborne")
			inst.sg:AddStateTag("nointerrupt")
		end),
		FrameEvent(11, function(inst)
			inst.sg:RemoveStateTag("nointerrupt")
		end),
		FrameEvent(14, function(inst)
			inst.sg:RemoveStateTag("airborne")
		end),
		FrameEvent(20, function(inst)
			inst.sg:AddStateTag("caninterrupt")
		end),
	}
})

SGCommon.States.AddKnockdownHitStates(states,
{
	hit_pst_busy_frames = 8,
})

SGCommon.States.AddSpawnBattlefieldStates(states,
{
	anim = "spawn",

	fadeduration = 0.5,
	fadedelay = 0.1,

	timeline =
	{
		FrameEvent(1, function(inst) inst.Physics:SetMotorVel(10) end),
		FrameEvent(5, function(inst) inst.Physics:SetMotorVel(5) end),
		FrameEvent(8, function(inst) inst.Physics:SetMotorVel(4) end),
		FrameEvent(9, function(inst) inst.Physics:SetMotorVel(3) end),
		FrameEvent(10, function(inst) inst.Physics:SetMotorVel(2) end),
		FrameEvent(11, function(inst) inst.Physics:SetMotorVel(1) end),
		FrameEvent(12, function(inst) inst.Physics:SetMotorVel(.5) end),
		FrameEvent(16, function(inst) inst.Physics:Stop() end),
		--
		FrameEvent(16, function(inst)
			inst.sg:RemoveStateTag("airborne")
		end),
		FrameEvent(16, function(inst)
			inst.sg:AddStateTag("caninterrupt")
		end),
		FrameEvent(27, function(inst)
			inst.sg:RemoveStateTag("busy")
		end),

		FrameEvent(2, function(inst) inst:PushEvent("leave_spawner") end),
	},
	onexit_fn = function(inst)
		inst.Physics:Stop()
	end,
})

SGCommon.States.AddWalkStates(states,
{
	onenterpre = function(inst) inst.Physics:Stop() end,
	pretimeline =
	{
		FrameEvent(1, function(inst) inst.Physics:SetMotorVel(inst.components.locomotor:GetWalkSpeed()) end),
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

SGCommon.States.AddTurnStates(states, {
	onenterpre = function(inst)
		inst.sg:AddStateTag("cancombine")
	end,
	onenterpst = function(inst)
		inst.sg:AddStateTag("cancombine")
	end,
})

SGCommon.States.AddMonsterDeathStates(states)
SGRegistry:AddData("sg_cabbageroll", states, StateGraphRegistry.Hints.SerializeMetadata)

return StateGraph("sg_cabbageroll", states, events, "idle")
