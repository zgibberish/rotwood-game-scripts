local SGCommon = require("stategraphs/sg_common")
local monsterutil = require "util.monsterutil"

local ATTACK_DAMAGE =
{
	SPIN = 15,
}

local function OnSpinHitBoxTriggered(inst, data)
	local hitstoplevel = HitStopLevel.HEAVY
	inst.components.hitstopper:PushHitStop(hitstoplevel)

	local dir = inst.Transform:GetFacingRotation()
	for i = 1, #data.targets do
		local v = data.targets[i]
		inst.components.combat:DoKnockdownAttack({
			target = v,
			damage_mod = ATTACK_DAMAGE.SPIN,
			dir = dir
		 })

		if v.components.hitstopper ~= nil then
			v.components.hitstopper:PushHitStop(hitstoplevel)
		end

		SpawnHitFx("fx_hit_player_round", inst, v, inst.sg.statemem.fxdist, 0, dir, hitstoplevel)
		SpawnHurtFx(inst, v, 0, dir, hitstoplevel)
	end
end

local function ChooseAttack(inst, data)
	return false
end

local events =
{
}
monsterutil.AddMonsterCommonEvents(events,
{
	locomote_data = { run = true, turn = true },
})

local states =
{
	State({
		name = "idle",
		tags = { "idle" },

		onenter = function(inst)
			inst.AnimState:PlayAnimation("idle", true)

			--Used by brain behaviors in case our size varies a lot
			if inst.sg.mem.idlesize == nil then
				inst.sg.mem.idlesize = inst.Physics:GetSize()
			end
		end,
	}),

	State({
		name = "hit",
		tags = { "hit", "busy" },

		onenter = function(inst)
			inst.AnimState:PlayAnimation("hit")
		end,

		timeline =
		{
			FrameEvent(7, function(inst)
				inst.sg:RemoveStateTag("busy")
				SGCommon.Fns.TryQueuedAttack(inst, ChooseAttack)
			end),
		},

		events =
		{
			SGCommon.Events.OnQueueAttack(ChooseAttack),
			EventHandler("animover", function(inst)
				inst.sg:GoToState("idle")
			end),
		},
	}),

	State({
		name = "knockback",
		tags = { "hit", "knockback", "busy", "nointerrupt" },

		onenter = function(inst)
			inst.AnimState:PlayAnimation("flinch")
			inst.Physics:SetMotorVel(-16)
		end,

		timeline =
		{
			FrameEvent(1, function(inst) inst.Physics:SetMotorVel(-12) end),
			FrameEvent(2, function(inst) inst.Physics:SetMotorVel(-8) end),
			FrameEvent(3, function(inst) inst.Physics:SetMotorVel(-4) end),
			FrameEvent(4, function(inst) inst.Physics:SetMotorVel(-2) end),
			FrameEvent(5, function(inst) inst.Physics:SetMotorVel(-1) end),
			FrameEvent(6, function(inst) inst.Physics:SetMotorVel(-.5) end),
			FrameEvent(7, function(inst) inst.Physics:SetMotorVel(-.25) end),
			FrameEvent(8, function(inst) inst.Physics:SetMotorVel(-.125) end),
			FrameEvent(9, function(inst) inst.Physics:Stop() end),
			FrameEvent(14, function(inst)
				inst.sg:RemoveStateTag("nointerrupt")
			end),
			FrameEvent(30, function(inst)
				inst.sg:AddStateTag("caninterrupt")
			end),
			FrameEvent(36, function(inst)
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
		name = "knockdown",
		tags = { "hit", "knockdown", "busy", "nointerrupt" },

		onenter = function(inst)
			inst.AnimState:PlayAnimation("knockdown")
			if not inst.components.timer:HasTimer("knockdown") then
				--Force permanent knockdown state when debugging
				inst.components.timer:StartTimerAnimFrames("knockdown", 1)
				inst.components.timer:PauseTimer("knockdown")
			end
			inst.Physics:SetMotorVel(-16)
		end,

		timeline =
		{
			FrameEvent(1, function(inst) inst.Physics:SetMotorVel(-12) end),
			FrameEvent(2, function(inst) inst.Physics:SetMotorVel(-8) end),
			FrameEvent(3, function(inst) inst.Physics:SetMotorVel(-4) end),
			FrameEvent(4, function(inst) inst.Physics:SetMotorVel(-2) end),
			FrameEvent(5, function(inst) inst.Physics:SetMotorVel(-1) end),
			FrameEvent(6, function(inst) inst.Physics:SetMotorVel(-.5) end),
			FrameEvent(7, function(inst) inst.Physics:SetMotorVel(-.25) end),
			FrameEvent(8, function(inst)
				inst.Physics:Stop()
				inst.Physics:MoveRelFacing(10 / 150)
			end),
			FrameEvent(11, function(inst) inst.Physics:MoveRelFacing(20 / 150) end),
			FrameEvent(13, function(inst)
				inst.Physics:SetSize(2.8)
				inst.Physics:MoveRelFacing(40 / 150)
			end),
			FrameEvent(15, function(inst)
				inst.Physics:MoveRelFacing(40 / 150)
				inst.Physics:SetSize(4)
			end),
			FrameEvent(19, function(inst)
				inst.sg:RemoveStateTag("nointerrupt")
				inst.sg:AddStateTag("caninterrupt")
			end),
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
			inst.Physics:Stop()
			if not inst.sg.statemem.knockdown then
				inst.Physics:SetSize(2.4)
				inst.components.timer:StopTimer("knockdown")
			end
		end,
	}),

	State({
		name = "knockdown_idle",
		tags = { "knockdown", "busy", "caninterrupt" },

		onenter = function(inst)
			inst.AnimState:PlayAnimation("knockdown_idle", true)
			inst.Physics:SetSize(4)
		end,

		events =
		{
			EventHandler("getup", function(inst)
				inst.sg.statemem.knockdown = true
				inst.sg:GoToState("knockdown_getup")
			end),
		},

		onexit = function(inst)
			if not inst.sg.statemem.knockdown then
				inst.Physics:SetSize(2.4)
				inst.components.timer:StopTimer("knockdown")
			end
		end,
	}),

	State({
		name = "knockdown_hit_front",
		tags = { "hit", "knockdown", "busy" },

		onenter = function(inst, getup)
			inst.AnimState:PlayAnimation("knockdown_hit_head")
			inst.Physics:SetSize(4)
			inst.sg.statemem.getup = getup
		end,

		timeline =
		{
			FrameEvent(6, function(inst)
				if inst.sg.statemem.getup then
					inst.sg.statemem.knockdown = true
					inst.sg:GoToState("knockdown_getup")
				else
					inst.sg:AddStateTag("caninterrupt")
				end
			end),
		},

		events =
		{
			EventHandler("getup", function(inst)
				if inst.sg:HasStateTag("caninterrupt") then
					inst.sg.statemem.knockdown = true
					inst.sg:GoToState("knockdown_getup")
				else
					inst.sg.statemem.getup = true
				end
			end),
			EventHandler("animover", function(inst)
				inst.sg.statemem.knockdown = true
				inst.sg:GoToState("knockdown_idle")
			end),
		},

		onexit = function(inst)
			if not inst.sg.statemem.knockdown then
				inst.Physics:SetSize(2.4)
				inst.components.timer:StopTimer("knockdown")
			end
		end,
	}),

	State({
		name = "knockdown_hit_back",
		tags = { "hit", "knockdown", "busy" },

		onenter = function(inst, getup)
			inst.AnimState:PlayAnimation("knockdown_hit_back")
			inst.Physics:SetSize(4)
			inst.sg.statemem.getup = getup
		end,

		timeline =
		{
			FrameEvent(7, function(inst)
				if inst.sg.statemem.getup then
					inst.sg.statemem.knockdown = true
					inst.sg:GoToState("knockdown_getup")
				else
					inst.sg:AddStateTag("caninterrupt")
				end
			end),
		},

		events =
		{
			EventHandler("getup", function(inst)
				if inst.sg:HasStateTag("caninterrupt") then
					inst.sg.statemem.knockdown = true
					inst.sg:GoToState("knockdown_getup")
				else
					inst.sg.statemem.getup = true
				end
			end),
			EventHandler("animover", function(inst)
				inst.sg.statemem.knockdown = true
				inst.sg:GoToState("knockdown_idle")
			end),
		},

		onexit = function(inst)
			if not inst.sg.statemem.knockdown then
				inst.Physics:SetSize(2.4)
				inst.components.timer:StopTimer("knockdown")
			end
		end,
	}),

	State({
		name = "knockdown_getup",
		tags = { "getup", "knockdown", "busy", "nointerrupt" },

		onenter = function(inst)
			inst.AnimState:PlayAnimation("knockdown_getup")
			inst.Physics:SetSize(4)
			inst.components.timer:StopTimer("knockdown")
		end,

		timeline =
		{
			FrameEvent(2, function(inst)
				inst.Physics:SetSize(1150 / 300)
				inst.Physics:MoveRelFacing(-40 / 150)
			end),
			FrameEvent(4, function(inst)
				inst.sg:RemoveStateTag("knockdown")
				inst.sg:AddStateTag("nointerrupt")
				inst.Physics:SetSize(1100 / 300)
				inst.Physics:MoveRelFacing(-40 / 150)
			end),
			FrameEvent(6, function(inst) inst.Physics:MoveRelFacing(-20 / 150) end),
			FrameEvent(8, function(inst) inst.Physics:MoveRelFacing(-6 / 150) end),
			FrameEvent(10, function(inst) inst.Physics:MoveRelFacing(-14 / 150) end),
			FrameEvent(12, function(inst) inst.Physics:MoveRelFacing(-40 / 150) end),
			FrameEvent(14, function(inst)
				inst.Physics:SetSize(760 / 300)
				inst.Physics:MoveRelFacing(-170 / 150)
				inst.components.offsethitboxes:Move("offsethitbox", 1.9)
				inst.components.offsethitboxes:SetEnabled("offsethitbox", true)
			end),
			FrameEvent(17, function(inst)
				inst.Physics:SetSize(740 / 300)
				inst.Physics:MoveRelFacing(-10 / 150)
				inst.components.offsethitboxes:Move("offsethitbox", 1.6)
			end),
			FrameEvent(19, function(inst)
				inst.sg:RemoveStateTag("nointerrupt")
			end),
			FrameEvent(20, function(inst)
				inst.Physics:SetSize(2.4)
				inst.Physics:MoveRelFacing(-10 / 150)
				inst.components.offsethitboxes:Move("offsethitbox", .8)
			end),
			FrameEvent(22, function(inst)
				inst.sg:AddStateTag("caninterrupt")
				inst.components.offsethitboxes:SetEnabled("offsethitbox", false)
			end),
		},

		events =
		{
			EventHandler("animover", function(inst)
				inst.sg:GoToState("idle")
			end),
		},

		onexit = function(inst)
			if not inst.sg.statemem.knockdown then
				inst.Physics:SetSize(2.4)
			end
			inst.components.offsethitboxes:SetEnabled("offsethitbox", false)
		end,
	}),

	State({
		name = "death",
		tags = { "death", "busy", "nointerrupt" },

		onenter = function(inst)
			inst.components.lootdropper:DropLoot()
			inst:Remove()
		end,
	}),

	State({
		name = "spin_pre",
		tags = { "attack", "busy" },

		onenter = function(inst)
			inst.AnimState:PlayAnimation("spin_attack_pre")
		end,

		onupdate = function(inst)
			if inst.sg.statemem.hitting then
				inst.components.hitbox:StartRepeatTargetDelayTicks(inst.sg.statemem.delayticks)
				if inst.sg.statemem.delayticks > 9 * ANIM_FRAMES then
					inst.sg.statemem.delayticks = inst.sg.statemem.delayticks - 1
				end
				inst.components.hitbox:PushBeam(-2.7, 2.7, 2, HitPriority.BOSS_DEFAULT)
			end
		end,

		timeline =
		{
			FrameEvent(4, function(inst)
				inst.sg:AddStateTag("nointerrupt")
			end),
			FrameEvent(5, function(inst) inst.Physics:SetMotorVel(.75) end),
			FrameEvent(6, function(inst)
				inst.sg:AddStateTag("airborne")
				inst.Physics:SetSize(2)
				inst.Physics:SetMotorVel(1.5)
			end),
			FrameEvent(10, function(inst) inst.Physics:SetMotorVel(6) end),
			FrameEvent(15, function(inst) inst.Physics:SetMotorVel(10) end),
			FrameEvent(16, function(inst)
				inst.sg:RemoveStateTag("airborne")
				inst.Physics:SetMotorVel(12)
			end),
			FrameEvent(17, function(inst)
				inst.sg.statemem.hitting = true
				inst.sg.statemem.delayticks = (13 + 3) * ANIM_FRAMES --account for hitstop
			end),
			FrameEvent(19, function(inst) inst.Physics:SetMotorVel(6) end),
			FrameEvent(20, function(inst) inst.Physics:SetMotorVel(5) end),
			FrameEvent(21, function(inst) inst.Physics:SetMotorVel(4) end),
			FrameEvent(22, function(inst) inst.Physics:SetMotorVel(3) end),
			FrameEvent(23, function(inst) inst.Physics:SetMotorVel(2) end),
			FrameEvent(24, function(inst) inst.Physics:SetMotorVel(1) end),
			FrameEvent(28, function(inst) inst.Physics:SetMotorVel(36) end),
		},

		events =
		{
			EventHandler("hitboxtriggered", OnSpinHitBoxTriggered),
			EventHandler("animover", function(inst)
				inst.sg.statemem.spinning = true
				inst.sg:GoToState("spin")
			end),
		},

		onexit = function(inst)
			if not inst.sg.statemem.spinning then
				inst.Physics:Stop()
				inst.Physics:SetSize(2.4)
				inst.components.hitbox:StopRepeatTargetDelay()
			end
		end,
	}),

	State({
		name = "spin",
		tags = { "attack", "busy", "nointerrupt" },

		onenter = function(inst)
			inst.AnimState:PlayAnimation("spin_attack")
			inst.Physics:SetSize(2)
			inst.Physics:SetMotorVel(50)
			inst.components.hitbox:StartRepeatTargetDelay()
		end,

		onupdate = function(inst)
			inst.components.hitbox:PushBeam(-2.7, 2.7, 2, HitPriority.BOSS_DEFAULT)
		end,

		timeline =
		{
			FrameEvent(2, function(inst) inst.Physics:SetMotorVel(46) end),
			FrameEvent(3, function(inst) inst.Physics:SetMotorVel(36) end),
			FrameEvent(4, function(inst) inst.Physics:SetMotorVel(32) end),
			FrameEvent(5, function(inst) inst.Physics:SetMotorVel(30) end),
			FrameEvent(6, function(inst) inst.Physics:SetMotorVel(28) end),
			FrameEvent(7, function(inst) inst.Physics:SetMotorVel(26) end),
		},

		events =
		{
			EventHandler("hitboxtriggered", OnSpinHitBoxTriggered),
			EventHandler("animover", function(inst)
				inst.sg.statemem.spinning = true
				inst.sg:GoToState("spin_pst")
			end),
		},

		onexit = function(inst)
			if not inst.sg.statemem.spinning then
				inst.Physics:Stop()
				inst.Physics:SetSize(2.4)
				inst.components.hitbox:StopRepeatTargetDelay()
			end
		end,
	}),

	State({
		name = "spin_pst",
		tags = { "attack", "busy", "airborne", "nointerrupt" },

		onenter = function(inst)
			inst.AnimState:PlayAnimation("spin_attack_pst")
			inst.Physics:SetSize(2)
			inst.Physics:SetMotorVel(20)
			inst.components.hitbox:StartRepeatTargetDelay()
			inst.sg.statemem.hitting = true
		end,

		onupdate = function(inst)
			if inst.sg.statemem.hitting then
				inst.components.hitbox:PushBeam(0, 2.4, 2, HitPriority.BOSS_DEFAULT)
			end
		end,

		timeline =
		{
			FrameEvent(1, function(inst) inst.Physics:SetMotorVel(16) end),
			FrameEvent(5, function(inst) inst.Physics:SetMotorVel(14) end),
			FrameEvent(6, function(inst) inst.Physics:SetMotorVel(12) end),
			FrameEvent(7, function(inst)
				inst.Physics:SetMotorVel(11)
				inst.sg.statemem.hitting = false
			end),
			FrameEvent(8, function(inst) inst.Physics:SetMotorVel(10) end),
			FrameEvent(9, function(inst) inst.Physics:SetMotorVel(9) end),
			FrameEvent(10, function(inst) inst.Physics:SetMotorVel(8) end),
			FrameEvent(15, function(inst)
				inst.sg:RemoveStateTag("airborne")
				inst.Physics:SetSize(2.4)
				inst.Physics:SetMotorVel(7)
			end),
			FrameEvent(16, function(inst)
				inst.sg:RemoveStateTag("nointerrupt")
				inst.Physics:SetMotorVel(3)
			end),
			FrameEvent(17, function(inst) inst.Physics:SetMotorVel(2) end),
			FrameEvent(18, function(inst) inst.Physics:SetMotorVel(1) end),
			FrameEvent(19, function(inst) inst.Physics:SetMotorVel(.5) end),
			FrameEvent(21, function(inst) inst.Physics:Stop() end),
			FrameEvent(23, function(inst)
				inst.sg:RemoveStateTag("busy")
			end),
		},

		events =
		{
			EventHandler("hitboxtriggered", OnSpinHitBoxTriggered),
			EventHandler("animover", function(inst)
				inst.sg:GoToState("idle")
			end),
		},

		onexit = function(inst)
			inst.Physics:Stop()
			inst.Physics:SetSize(2.4)
			inst.components.hitbox:StopRepeatTargetDelay()
		end,
	}),
}

SGCommon.States.AddRunStates(states,
{
	onenterturnpre = function(inst) inst.Physics:Stop() end,
	turnpsttimeline =
	{
		FrameEvent(5, function(inst)
			inst.sg:RemoveStateTag("busy")
		end),
	},
})

SGCommon.States.AddTurnStates(states)

return StateGraph("sg_magmadillo", states, events, "idle")
