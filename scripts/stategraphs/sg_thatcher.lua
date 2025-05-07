local SGCommon = require "stategraphs.sg_common"
local TargetRange = require "targetrange"
local monsterutil = require "util.monsterutil"

local ATTACK_DAMAGE =
{
	SWING_SHORT = 1,
	SWING_LONG = 1,
	SWING_UP = 1.25,
	HOOK_BACK = 0.5,
	HOOK_FRONT = 0.5,
	HOOK_PULL = 0.5,
	SPIN = 0.5,
}

local function OnHitBoxTriggered(inst, data)
	local hitstoplevel = HitStopLevel.HEAVY
	inst.components.hitstopper:PushHitStop(hitstoplevel)

	local dir = inst.Transform:GetFacingRotation()
	for i = 1, #data.targets do
		local v = data.targets[i]

		inst.components.combat:DoKnockdownAttack(
			Attack(inst, v)
				:SetDamageMod(inst.sg.statemem.damage)
				:SetDir(dir)
				--~ :SetSpeedMult(1.2)
			)

		if v.components.hitstopper ~= nil then
			v.components.hitstopper:PushHitStop(hitstoplevel)
		end

		SpawnHitFx("fx_hit_player_round", inst, v, inst.sg.statemem.fxdist, 0, dir, hitstoplevel)
		SpawnHurtFx(inst, v, inst.sg.statemem.fxdist, dir, hitstoplevel)

		inst.sg.statemem.hit = true
	end
end

local function OnHookHitBoxTriggered(inst, data)
	local hitstoplevel = inst.sg.statemem.hitstoplevel
	inst.components.hitstopper:PushHitStop(hitstoplevel)

	local dir = inst.Transform:GetFacingRotation()
	local x, z
	if inst.sg.statemem.back then
		dir = dir + 180
		x, z = inst.Transform:GetWorldXZ()
	end
	local hit = false
	for i = 1, #data.targets do
		local v = data.targets[i]
		local knockback = inst.sg.statemem.pull
		if knockback ~= nil then
			if v.sg ~= nil and v.sg:HasStateTag("airborne") then
				knockback = knockback * .65
			end
		elseif inst.sg.statemem.back then
			local x1, z1 = v.Transform:GetWorldXZ()
			knockback = z1 - v.HitBox:GetDepth() > z + .75 and -.5 or .7
		else
			knockback = .1
		end
			inst.components.combat:DoKnockbackAttack(
				Attack(inst, v)
					:SetDamageMod(inst.sg.statemem.damage)
					:SetDir(dir)
					--~ :SetSpeedMult(knockback)
				)

		if v.components.hitstopper ~= nil then
			v.components.hitstopper:PushHitStop(hitstoplevel)
		end

		SpawnHitFx("fx_hit_player_round", inst, v, inst.sg.statemem.fxdist, 0, dir, hitstoplevel)
		SpawnHurtFx(inst, v, inst.sg.statemem.fxdist, dir, hitstoplevel)

		if inst.sg.statemem.targets ~= nil then
			inst.sg.statemem.targets[#inst.sg.statemem.targets + 1] = v
		end
	end
end

local function OnSpinHitBoxTriggered(inst, data)
	local hitstoplevel = HitStopLevel.HEAVY
	inst.components.hitstopper:PushHitStop(hitstoplevel)

	for i = 1, #data.targets do
		local v = data.targets[i]
		inst.components.combat:DoKnockbackAttack(
			Attack(inst, v)
				:SetDamageMod(ATTACK_DAMAGE.SPIN))

		if v.components.hitstopper ~= nil then
			v.components.hitstopper:PushHitStop(hitstoplevel)
		end

		SpawnHitFx("fx_hit_player_round", inst, v, 0, 0, nil, hitstoplevel)
		SpawnHurtFx(inst, v, 0, nil, hitstoplevel)
	end
end

local function ChooseAttack(inst, data)
	if data.target ~= nil and data.target:IsValid() then
		local trange = TargetRange(inst, data.target)
		if not inst.components.timer:HasTimer("hook_cd") then
			if trange:TestBeam(3.5, 8.5, 2) then
				SGCommon.Fns.TurnAndActOnTarget(inst, data, true, "hook")
				return true
			end
		end
		if not inst.components.timer:HasTimer("acid_cd") then
		end
		if not inst.components.timer:HasTimer("swing_cd") then
			--Use swing if target is aligned and close enough
			if trange:TestBeam(6, 13, 3) then
				SGCommon.Fns.TurnAndActOnTarget(inst, data, true, "swing_long_pre")
				return true
			elseif trange:TestBeam(.5, 9, 3) then
				SGCommon.Fns.TurnAndActOnTarget(inst, data, true, "swing_short_pre")
				return true
			end
		end
		if not inst.components.timer:HasTimer("alert_cd") then
			if trange:IsInRange(5) then
				if not (data.target.sg ~= nil and data.target.sg:HasStateTag("knockdown")) then
					SGCommon.Fns.TurnAndActOnTarget(inst, data, true, "alert")
					return true
				end
			end
		end
	end
	return false
end

local function ChooseSwingComboAttack(inst)
	if not inst.components.timer:HasTimer("swingup_cd") then
		for i = 1, #AllPlayers do
			local target = AllPlayers[i]
			local trange = TargetRange(inst, target)
			if trange:IsFacingTarget() then
				if trange:TestBeam(0, 20, 2) then
					inst.Physics:MoveRelFacing(80 / 150)
					inst.sg:GoToState("swing_up")
					return true
				end
			end
		end
	end
	return false
end

local function ChooseCounterAttack(inst)
	local swinglong = false
	for i = 1, #AllPlayers do
		local target = AllPlayers[i]
		local trange = TargetRange(inst, target)
		if trange:IsFacingTarget() then
			if trange:TestBeam(.5, 9, 3) then
				inst:SnapToFacingRotation()
				inst.sg:GoToState("swing_short_pre", true)
				return true
			elseif trange:TestBeam(.5, 13, 3) then
				swinglong = true
			end
		end
	end
	if swinglong then
		inst:SnapToFacingRotation()
		inst.sg:GoToState("swing_long_pre", true)
		return true
	end
	return false
end

local function ChooseHookComboAttack(inst, targets)
	if #targets > 0 then
		for i = 1, #targets do
			local target = targets[i]
			local trange = TargetRange(inst, target)
			if trange:IsFacingTarget() then
				if trange:TestBeam(.5, 9, 3) then
					inst:SnapToFacingRotation()
					inst.sg:GoToState("swing_short_pre", true)
					return true
				end
			end
		end
	end
	--#TODO: acid
	return false
end

local function ChooseBattleCry(inst, data)
	if data.target ~= nil and data.target:IsValid() then
		if not inst.components.timer:HasTimer("taunt_cd") then
			SGCommon.Fns.TurnAndActOnTarget(inst, data.target, true, "taunt")
			return true
		end
	end
	return false
end

local function ChooseIdleBehavior(inst)
	if not inst.components.timer:HasTimer("idlebehavior_cd") then
		if not inst.components.timer:HasTimer("inspect_cd") then
			inst.sg:GoToState("inspect")
			return true
		end
	end
	return false
end

local events =
{
	EventHandler("dodge", function(inst, dir)
		if not (inst.sg:HasStateTag("busy") or inst.components.timer:HasTimer("dodge_cd")) then
			if dir == nil then
				local target = inst.components.combat:GetTarget()
				if target ~= nil then
					local facing = inst.Transform:GetFacing()
					local x, z = inst.Transform:GetWorldXZ()
					local x1, z1 = target.Transform:GetWorldXZ()
					local dx = x1 - x
					local dz = z1 - z
					local absdz = math.abs(dz)
					local right = x > x1 or (x == x1 and facing == FACING_LEFT)
					if absdz < inst.Physics:GetDepth() + target.Physics:GetDepth() + 2 then
						--Too close, so dodge horizontally to avoid clipping
						dir = right and 0 or 180
					else
						local turn = right == (facing == FACING_RIGHT)
						local dist = turn and 6.85 or 6.25
						if absdz < dist then
							local xdist = math.sqrt(dist * dist - dz * dz)
							if xdist + math.abs(dx) > inst.Physics:GetSize() + target.Physics:GetSize() + 1 then
								--Close enough to dodge diagonally without clipping
								dir = math.deg(math.atan(-dz, right and xdist or -xdist))
							end
						end
					end
				else
					dir = inst.Transform:GetFacingRotation() + 180
				end
			end
			if dir ~= nil then
				if DiffAngle(inst.Transform:GetFacingRotation(), dir) < 90 then
					inst.Transform:SetRotation(dir)
					inst.sg:GoToState("turn_dodge_pre")
				else
					inst.Transform:SetRotation(dir + 180)
					inst.sg:GoToState("dodge")
				end
			end
		end
	end),
}
monsterutil.AddBossCommonEvents(events,
{
	chooseattack_fn = ChooseBattleCry,
	locomote_data = { run = true, turn = true },
})
monsterutil.AddOptionalMonsterEvents(events,
{
	idlebehavior_fn = ChooseIdleBehavior,
	battlecry_fn = ChooseBattleCry,
})

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

			inst.AnimState:PlayAnimation("idle", true)
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
			FrameEvent(6, function(inst)
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
		end,

		timeline =
		{
			--physics
			FrameEvent(0, function(inst) inst.Physics:SetMotorVel(-28) end),
			FrameEvent(1, function(inst) inst.Physics:SetMotorVel(-24) end),
			FrameEvent(2, function(inst) inst.Physics:SetMotorVel(-12) end),
			FrameEvent(4, function(inst) inst.Physics:SetMotorVel(-6) end),
			FrameEvent(6, function(inst) inst.Physics:SetMotorVel(-3) end),
			FrameEvent(7, function(inst) inst.Physics:SetMotorVel(-2) end),
			FrameEvent(8, function(inst) inst.Physics:SetMotorVel(-1) end),
			FrameEvent(9, function(inst) inst.Physics:SetMotorVel(-.5) end),
			FrameEvent(10, function(inst) inst.Physics:Stop() end),
			FrameEvent(28, function(inst) inst.Physics:MoveRelFacing(40 / 150) end),
			FrameEvent(30, function(inst) inst.Physics:MoveRelFacing(40 / 150) end),
			FrameEvent(32, function(inst) inst.Physics:MoveRelFacing(20 / 150) end),
			--

			FrameEvent(14, function(inst)
				inst.sg:RemoveStateTag("nointerrupt")
				inst.sg:AddStateTag("vulnerable")
			end),
			FrameEvent(28, function(inst)
				inst.sg:RemoveStateTag("vulnerable")
				inst.sg:AddStateTag("caninterrupt")
			end),
			FrameEvent(32, function(inst)
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
		end,

		timeline =
		{
			--physics
			FrameEvent(0, function(inst) inst.Physics:SetMotorVel(-6) end),
			FrameEvent(2, function(inst) inst.Physics:SetSize(1.5) end),
			FrameEvent(16, function(inst) inst.Physics:SetSize(2) end),
			FrameEvent(17, function(inst) inst.Physics:SetMotorVel(-4) end),
			FrameEvent(17, function(inst) inst.Physics:SetSize(2.3) end),
			FrameEvent(18, function(inst) inst.Physics:SetMotorVel(-2) end),
			FrameEvent(19, function(inst) inst.Physics:SetMotorVel(-1) end),
			FrameEvent(20, function(inst) inst.Physics:SetMotorVel(-.5) end),
			FrameEvent(21, function(inst) inst.Physics:Stop() end),
			--

			FrameEvent(2, function(inst)
				inst.sg:AddStateTag("airborne")
			end),
			FrameEvent(17, function(inst)
				inst.sg:RemoveStateTag("airborne")
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
				inst.Physics:SetSize(1.9)
				inst.components.timer:StopTimer("knockdown")
			end
		end,
	}),

	State({
		name = "knockdown_idle",
		tags = { "knockdown", "busy", "caninterrupt" },

		onenter = function(inst)
			inst.AnimState:PlayAnimation("knockdown_idle", true)
		end,

		timeline =
		{
			--physics
			FrameEvent(0, function(inst) inst.Physics:SetSize(2.3) end),
			--
		},

		events =
		{
			EventHandler("getup", function(inst)
				inst.sg.statemem.knockdown = true
				inst.sg:GoToState("knockdown_getup")
			end),
		},

		onexit = function(inst)
			if not inst.sg.statemem.knockdown then
				inst.Physics:SetSize(1.9)
				inst.components.timer:StopTimer("knockdown")
			end
		end,
	}),

	State({
		name = "knockdown_hit_front",
		tags = { "hit", "knockdown", "busy" },

		onenter = function(inst, getup)
			inst.AnimState:PlayAnimation("knockdown_hit_head")
			inst.sg.statemem.getup = getup
		end,

		timeline =
		{
			--physics
			FrameEvent(0, function(inst) inst.Physics:SetSize(2.3) end),
			--

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
				inst.Physics:SetSize(1.9)
				inst.components.timer:StopTimer("knockdown")
			end
		end,
	}),

	State({
		name = "knockdown_hit_back",
		tags = { "hit", "knockdown", "busy" },

		onenter = function(inst, getup)
			inst.AnimState:PlayAnimation("knockdown_hit_back")
			inst.sg.statemem.getup = getup
		end,

		timeline =
		{
			--physics
			FrameEvent(0, function(inst) inst.Physics:SetSize(2.3) end),
			--

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
				inst.Physics:SetSize(1.9)
				inst.components.timer:StopTimer("knockdown")
			end
		end,
	}),

	State({
		name = "knockdown_getup",
		tags = { "getup", "knockdown", "busy", "nointerrupt" },

		onenter = function(inst)
			inst.AnimState:PlayAnimation("knockdown_getup")
			inst.components.timer:StopTimer("knockdown")
		end,

		timeline =
		{
			--physics
			FrameEvent(0, function(inst) inst.Physics:SetSize(1.9) end),
			FrameEvent(4, function(inst) inst.Physics:SetSize(1.5) end),
			FrameEvent(14, function(inst) inst.Physics:SetSize(1.3) end),
			FrameEvent(24, function(inst) inst.Physics:SetSize(1.5) end),
			FrameEvent(26, function(inst) inst.Physics:SetSize(1.9) end),
			--

			FrameEvent(4, function(inst)
				inst.sg:RemoveStateTag("knockdown")
				inst.sg:AddStateTag("airborne")
				inst.sg:AddStateTag("nointerrupt")
			end),
			FrameEvent(26, function(inst)
				inst.sg:RemoveStateTag("airborne")
				inst.sg:RemoveStateTag("nointerrupt")
			end),
			FrameEvent(30, function(inst)
				inst.sg:AddStateTag("caninterrupt")
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
				inst.Physics:SetSize(1.9)
			end
		end,
	}),

	State({
		name = "death",
		tags = { "death", "busy", "nointerrupt" },

		onenter = function(inst)
			inst.AnimState:PlayAnimation("death")
			if inst.brain ~= nil then
				inst.brain:Pause("death")
			end
			inst.AnimState:SetLightOverride(1)
			inst.components.colormultiplier:PushColor("death", 0, 0, 0, 1)
			inst.components.coloradder:PushColor("death", 1, 1, .4, 0)
			TheWorld.components.lightcoordinator:SetIntensity(0)
		end,

		onupdate = function(inst)
			if inst.sg.statemem.darkness ~= nil then
				local d = inst.sg.statemem.darkness - .05
				inst.sg.statemem.darkness = d > 0 and d or nil
				d = d * d * .8 + .2
				TheWorld.components.lightcoordinator:SetIntensity(d)
			end
			if inst.sg.statemem.whiteness ~= nil then
				local w = inst.sg.statemem.whiteness + .03
				inst.sg.statemem.whiteness = w
				inst.components.coloradder:PushColor("death", w, w, w, 0)
				w = 1 - w
				inst.components.colormultiplier:PushColor("death", w, w, w, 1)
			end
		end,

		timeline =
		{
			--physics
			FrameEvent(3, function(inst) inst.Physics:MoveRelFacing(-50 / 150) end),
			FrameEvent(3, function(inst) inst.Physics:SetSize(1.6) end),
			FrameEvent(6, function(inst) inst.Physics:MoveRelFacing(-25 / 150) end),
			FrameEvent(6, function(inst) inst.Physics:SetSize(1.5) end),
			FrameEvent(8, function(inst) inst.Physics:MoveRelFacing(-25 / 150) end),
			--

			FrameEvent(1, function(inst)
				inst.components.colormultiplier:PopColor("death")
				inst.components.coloradder:PopColor("death")
				inst.sg.statemem.darkness = 1
			end),
			FrameEvent(2, function(inst)
				inst.components.colormultiplier:PushColor("death", .3, .3, .3, 1)
				inst.components.coloradder:PushColor("death", .7, .7, .28, 0)
			end),
			FrameEvent(3, function(inst)
				inst.components.colormultiplier:PopColor("death")
				inst.components.coloradder:PopColor("death")
			end),
			FrameEvent(4, function(inst)
				inst.components.colormultiplier:PushColor("death", .6, .6, .6, 1)
				inst.components.coloradder:PushColor("death", .4, .4, .16, 0)
			end),
			FrameEvent(5, function(inst)
				inst.components.colormultiplier:PopColor("death")
				inst.components.coloradder:PopColor("death")
			end),
			FrameEvent(6, function(inst)
				inst.components.colormultiplier:PushColor("death", .9, .9, .9, 1)
				inst.components.coloradder:PushColor("death", .1, .1, .04, 0)
			end),
			FrameEvent(7, function(inst)
				inst.components.colormultiplier:PopColor("death")
				inst.components.coloradder:PopColor("death")
			end),
			FrameEvent(14, function(inst)
				inst.sg.statemem.whiteness = 0
			end),
		},

		events =
		{
			EventHandler("animover", function(inst)
				TheWorld.components.lightcoordinator:ResetColor()
				SpawnPrefab("fx_death_thatcher", inst):SetupDeathFxFor(inst)
				inst.components.lootdropper:DropLoot()
				inst:Remove()
			end),
		},

		onexit = function(inst)
			assert(DEV_MODE)
			inst.Physics:SetSize(1.9)
			if inst.brain ~= nil then
				inst.brain:Resume("death")
			end
			if inst.components.health:IsDead() then
				inst.components.health:SetCurrent(1, true)
			end
			inst.AnimState:SetLightOverride(0)
			inst.components.colormultiplier:PopColor("death")
			inst.components.coloradder:PopColor("death")
			TheWorld.components.lightcoordinator:ResetColor()
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
			FrameEvent(4, function(inst) inst.Physics:SetSize(510 / 300) end),
			FrameEvent(4, function(inst) inst.Physics:MoveRelFacing(-30 / 150) end),
			FrameEvent(6, function(inst) inst.Physics:SetSize(450 / 300) end),
			FrameEvent(6, function(inst) inst.Physics:MoveRelFacing(-30 / 150) end),
			FrameEvent(36, function(inst) inst.Physics:MoveRelFacing(10 / 150) end),
			FrameEvent(36, function(inst) inst.Physics:SetSize(470 / 300) end),
			FrameEvent(38, function(inst) inst.Physics:MoveRelFacing(50 / 150) end),
			FrameEvent(38, function(inst) inst.Physics:SetSize(1.9) end),
			--

			FrameEvent(6, function(inst)
				inst.components.timer:StartTimer("taunt_cd", 10, true)
				inst.components.timer:StartTimer("idlebehavior_cd", 6, true)
			end),
			FrameEvent(38, function(inst)
				inst.sg:AddStateTag("caninterrupt")
			end),
			FrameEvent(42, function(inst)
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

		onexit = function(inst) inst.Physics:SetSize(1.9) end,
	}),

	State({
		name = "alert",
		tags = { "busy", "caninterrupt" },

		onenter = function(inst)
			inst.AnimState:PlayAnimation("behavior2")
		end,

		timeline =
		{
			FrameEvent(4, function(inst)
				inst.sg:RemoveStateTag("caninterrupt")
				inst.components.timer:StartTimer("alert_cd", 16, true)
			end),
			FrameEvent(13, function(inst)
				inst.sg.statemem.counter = true
			end),
			FrameEvent(17, function(inst)
				inst.sg:AddStateTag("caninterrupt")
			end),
			FrameEvent(55, function(inst)
				inst.sg.statemem.counter = false
			end),
			FrameEvent(66, function(inst)
				inst.sg:RemoveStateTag("busy")
				SGCommon.Fns.TryQueuedAttack(inst, ChooseAttack)
			end),
		},

		events =
		{
			SGCommon.Events.OnQueueAttack(ChooseAttack),
			EventHandler("attacked", function(inst, data)
				if inst.sg.statemem.counter and ChooseCounterAttack(inst) then
					return
				end
				SGCommon.Fns.OnAttacked(inst, data)
			end),
			EventHandler("animover", function(inst)
				inst.sg:GoToState("idle")
			end),
		},
	}),

	State({
		name = "inspect",
		tags = { "busy", "caninterrupt" },

		onenter = function(inst)
			inst.AnimState:PlayAnimation("behavior3")
			inst.components.timer:StartTimer("inspect_cd", 12, true)
		end,

		events =
		{
			SGCommon.Events.OnQueueAttack(ChooseAttack),
			EventHandler("animover", function(inst)
				if not SGCommon.Fns.TryQueuedAttack(inst, ChooseAttack) then
					inst.sg:GoToState("idle")
				end
			end),
		},
	}),

	State({
		name = "swing_short_pre",
		tags = { "attack", "busy" },

		onenter = function(inst, fast)
			inst.AnimState:PlayAnimation("swing_short_pre")
			if fast then
				inst.sg:SetTimeoutAnimFrames(12)
			elseif inst.components.health:GetPercent() < .5 then
				inst.sg:SetTimeoutAnimFrames(11 + math.random(7))
			end
		end,

		timeline =
		{
			--physics
			FrameEvent(2, function(inst) inst.Physics:MoveRelFacing(-70 / 150) end),
			FrameEvent(4, function(inst) inst.Physics:MoveRelFacing(-90 / 150) end),
			FrameEvent(6, function(inst) inst.Physics:MoveRelFacing(-30 / 150) end),
			FrameEvent(8, function(inst) inst.Physics:MoveRelFacing(-20 / 150) end),
			FrameEvent(10, function(inst) inst.Physics:MoveRelFacing(-10 / 150) end),
			--
		},

		ontimeout = function(inst)
			inst.Physics:MoveRelFacing(70 / 150)
			inst.sg:GoToState("swing_short")
		end,

		events =
		{
			EventHandler("animover", function(inst)
				inst.Physics:MoveRelFacing(70 / 150)
				inst.sg:GoToState("swing_short")
			end),
		},
	}),

	State({
		name = "swing_short",
		tags = { "attack", "busy" },

		onenter = function(inst)
			inst.AnimState:PlayAnimation("swing_short")
		end,

		timeline =
		{
			--physics
			FrameEvent(0, function(inst) inst.Physics:SetMotorVel(7) end),
			FrameEvent(8, function(inst) inst.Physics:SetMotorVel(4) end),
			FrameEvent(9, function(inst) inst.Physics:SetMotorVel(3) end),
			FrameEvent(10, function(inst) inst.Physics:SetMotorVel(2) end),
			FrameEvent(11, function(inst) inst.Physics:SetMotorVel(1) end),
			FrameEvent(12, function(inst) inst.Physics:SetMotorVel(.5) end),
			FrameEvent(13, function(inst) inst.Physics:Stop() end),
			--

			--head hitbox
			FrameEvent(4, function(inst) inst.components.offsethitboxes:SetEnabled("offsethitbox", true) end),
			FrameEvent(4, function(inst) inst.components.offsethitboxes:Move("offsethitbox", 1.1) end),
			FrameEvent(6, function(inst) inst.components.offsethitboxes:Move("offsethitbox", 2) end),
			FrameEvent(8, function(inst) inst.components.offsethitboxes:Move("offsethitbox", 1.8) end),
			FrameEvent(10, function(inst) inst.components.offsethitboxes:Move("offsethitbox", 1.6) end),
			FrameEvent(12, function(inst) inst.components.offsethitboxes:Move("offsethitbox", 1.5) end),
			--

			FrameEvent(4, function(inst)
				inst.components.combat:StartCooldown(3)
				inst.components.timer:StartTimer("swing_cd", 4, true)
			end),
			FrameEvent(6, function(inst)
				inst.components.hitbox:StartRepeatTargetDelay()
				inst.sg.statemem.damage = ATTACK_DAMAGE.SWING_SHORT
				inst.sg.statemem.fxdist = 7.4
				inst.components.hitbox:PushBeam(0, 9, 3, HitPriority.BOSS_DEFAULT)
			end),
			FrameEvent(7, function(inst)
				inst.components.hitbox:PushBeam(0, 9, 3, HitPriority.BOSS_DEFAULT)
			end),
			FrameEvent(8, function(inst)
				inst.sg:AddStateTag("vulnerable")
			end),
		},

		events =
		{
			EventHandler("hitboxtriggered", OnHitBoxTriggered),
			EventHandler("animover", function(inst)
				inst.sg.statemem.swinging = true
				if not ChooseSwingComboAttack(inst) then
					inst.sg:GoToState("swing_pst", inst.sg.statemem.hit)
				end
			end),
		},

		onexit = function(inst)
			inst.Physics:Stop()
			if not inst.sg.statemem.swinging then
				inst.components.offsethitboxes:SetEnabled("offsethitbox", false)
			end
			inst.components.hitbox:StopRepeatTargetDelay()
		end,
	}),

	State({
		name = "swing_long_pre",
		tags = { "attack", "busy" },

		onenter = function(inst, fast)
			inst.AnimState:PlayAnimation("swing_long_pre")
			if fast then
				inst.sg:SetTimeoutAnimFrames(15)
			elseif inst.components.health:GetPercent() < .5 then
				inst.sg:SetTimeoutAnimFrames(14 + math.random(10))
			end
		end,

		timeline =
		{
			--physics
			FrameEvent(3, function(inst) inst.Physics:MoveRelFacing(-70 / 150) end),
			FrameEvent(5, function(inst) inst.Physics:MoveRelFacing(-70 / 150) end),
			FrameEvent(8, function(inst) inst.Physics:MoveRelFacing(-30 / 150) end),
			FrameEvent(10, function(inst) inst.Physics:MoveRelFacing(-30 / 150) end),
			FrameEvent(12, function(inst) inst.Physics:MoveRelFacing(-20 / 150) end),
			--
		},

		ontimeout = function(inst)
			inst.sg:GoToState("swing_long")
		end,

		events =
		{
			EventHandler("animover", function(inst)
				inst.sg:GoToState("swing_long")
			end),
		},
	}),

	State({
		name = "swing_long",
		tags = { "attack", "busy" },

		onenter = function(inst)
			inst.AnimState:PlayAnimation("swing_long")
		end,

		timeline =
		{
			--physics
			FrameEvent(0, function(inst) inst.Physics:SetMotorVel(4) end),
			FrameEvent(6, function(inst) inst.Physics:SetMotorVel(6) end),
			FrameEvent(10, function(inst) inst.Physics:SetMotorVel(10) end),
			FrameEvent(11, function(inst) inst.Physics:SetMotorVel(8) end),
			FrameEvent(13, function(inst) inst.Physics:SetMotorVel(4) end),
			FrameEvent(14, function(inst) inst.Physics:SetMotorVel(3) end),
			FrameEvent(15, function(inst) inst.Physics:SetMotorVel(2) end),
			FrameEvent(16, function(inst) inst.Physics:SetMotorVel(1) end),
			FrameEvent(17, function(inst) inst.Physics:SetMotorVel(.5) end),
			FrameEvent(18, function(inst) inst.Physics:Stop() end),
			--

			--head hitbox
			FrameEvent(9, function(inst) inst.components.offsethitboxes:SetEnabled("offsethitbox", true) end),
			FrameEvent(9, function(inst) inst.components.offsethitboxes:Move("offsethitbox", 1.7) end),
			FrameEvent(11, function(inst) inst.components.offsethitboxes:Move("offsethitbox", 2.8) end),
			FrameEvent(13, function(inst) inst.components.offsethitboxes:Move("offsethitbox", 2.2) end),
			FrameEvent(15, function(inst) inst.components.offsethitboxes:Move("offsethitbox", 1.5) end),
			--

			FrameEvent(9, function(inst)
				inst.components.combat:StartCooldown(3)
				inst.components.timer:StartTimer("swing_cd", 4, true)
			end),
			FrameEvent(11, function(inst)
				inst.components.hitbox:StartRepeatTargetDelay()
				inst.sg.statemem.damage = ATTACK_DAMAGE.SWING_LONG
				inst.sg.statemem.fxdist = 11
				inst.components.hitbox:PushBeam(0, 13.1, 3, HitPriority.BOSS_DEFAULT)
			end),
			FrameEvent(12, function(inst)
				inst.components.hitbox:PushBeam(5.2, 13.1, 3, HitPriority.BOSS_DEFAULT)
			end),
			FrameEvent(13, function(inst)
				inst.sg:AddStateTag("vulnerable")
			end),
		},

		events =
		{
			EventHandler("hitboxtriggered", OnHitBoxTriggered),
			EventHandler("animover", function(inst)
				inst.sg.statemem.swinging = true
				if not ChooseSwingComboAttack(inst) then
					inst.sg:GoToState("swing_pst", inst.sg.statemem.hit)
				end
			end),
		},

		onexit = function(inst)
			inst.Physics:Stop()
			if not inst.sg.statemem.swinging then
				inst.components.offsethitboxes:SetEnabled("offsethitbox", false)
			end
			inst.components.hitbox:StopRepeatTargetDelay()
		end,
	}),

	State({
		name = "swing_up",
		tags = { "attack", "busy" },

		onenter = function(inst)
			inst.AnimState:PlayAnimation("swing_uppercut")
		end,

		timeline =
		{
			--physics
			FrameEvent(0, function(inst) inst.Physics:SetMotorVel(10) end),
			FrameEvent(6, function(inst) inst.Physics:SetMotorVel(8) end),
			FrameEvent(10, function(inst) inst.Physics:SetMotorVel(6) end),
			FrameEvent(13, function(inst) inst.Physics:Stop() end),
			FrameEvent(16, function(inst) inst.Physics:SetMotorVel(4) end),
			FrameEvent(22, function(inst) inst.Physics:SetMotorVel(6) end),
			FrameEvent(25, function(inst) inst.Physics:SetMotorVel(5) end),
			FrameEvent(28, function(inst) inst.Physics:SetMotorVel(4) end),
			FrameEvent(30, function(inst) inst.Physics:SetMotorVel(8) end),
			FrameEvent(33, function(inst) inst.Physics:SetMotorVel(6) end),
			FrameEvent(34, function(inst) inst.Physics:SetMotorVel(5) end),
			FrameEvent(35, function(inst) inst.Physics:SetMotorVel(4) end),
			FrameEvent(36, function(inst) inst.Physics:SetMotorVel(3) end),
			FrameEvent(37, function(inst) inst.Physics:SetMotorVel(2) end),
			FrameEvent(38, function(inst) inst.Physics:SetMotorVel(1) end),
			FrameEvent(39, function(inst) inst.Physics:SetMotorVel(.5) end),
			FrameEvent(40, function(inst) inst.Physics:Stop() end),
			--

			--headhitbox
			FrameEvent(0, function(inst) inst.components.offsethitboxes:SetEnabled("offsethitbox", true) end),
			FrameEvent(0, function(inst) inst.components.offsethitboxes:Move("offsethitbox", .7) end),
			FrameEvent(2, function(inst) inst.components.offsethitboxes:SetEnabled("offsethitbox", false) end),
			FrameEvent(28, function(inst) inst.components.offsethitboxes:SetEnabled("offsethitbox", true) end),
			FrameEvent(28, function(inst) inst.components.offsethitboxes:Move("offsethitbox", 2.5) end),
			FrameEvent(30, function(inst) inst.components.offsethitboxes:Move("offsethitbox", 3) end),
			FrameEvent(32, function(inst) inst.components.offsethitboxes:SetEnabled("offsethitbox", false) end),
			FrameEvent(51, function(inst) inst.components.offsethitboxes:SetEnabled("offsethitbox", true) end),
			FrameEvent(51, function(inst) inst.components.offsethitboxes:Move("offsethitbox", .7) end),
			FrameEvent(53, function(inst) inst.components.offsethitboxes:Move("offsethitbox", .4) end),
			FrameEvent(55, function(inst) inst.components.offsethitboxes:SetEnabled("offsethitbox", false) end),
			--

			FrameEvent(25, function(inst)
				local healthpct = inst.components.health:GetPercent()
				if healthpct > .25 then
					local cd = (healthpct > .75 and 16) or (healthpct > .5 and 12) or 6
					inst.components.timer:StartTimer("swingup_cd", cd, true)
				end
			end),
			FrameEvent(30, function(inst)
				inst.components.combat:StartCooldown(3)
				inst.components.timer:StartTimer("swing_cd", 4, true)
			end),
			FrameEvent(32, function(inst)
				inst.components.hitbox:StartRepeatTargetDelay()
				inst.sg.statemem.high = true
				inst.sg.statemem.damage = ATTACK_DAMAGE.SWING_UP
				inst.sg.statemem.fxdist = 11.7
				inst.components.hitbox:PushBeam(0, 13.6, 2, HitPriority.BOSS_DEFAULT)
			end),
			FrameEvent(33, function(inst)
				inst.components.hitbox:PushBeam(0, 13.6, 2, HitPriority.BOSS_DEFAULT)
			end),
			FrameEvent(55, function(inst)
				inst.sg:AddStateTag("caninterrupt")
			end),
			FrameEvent(57, function(inst)
				inst.sg:RemoveStateTag("busy")
			end),
		},

		events =
		{
			EventHandler("hitboxtriggered", OnHitBoxTriggered),
			EventHandler("animover", function(inst)
				if inst.sg.statemem.hit and not inst.components.timer:HasTimer("taunt_cd") then
					inst.sg:GoToState("taunt")
				else
					inst.sg:GoToState("idle")
				end
			end),
		},

		onexit = function(inst)
			inst.Physics:Stop()
			inst.components.offsethitboxes:SetEnabled("offsethitbox", false)
			inst.components.hitbox:StopRepeatTargetDelay()
		end,
	}),

	State({
		name = "swing_pst",
		tags = { "busy", "vulnerable" },

		onenter = function(inst, hit)
			inst.AnimState:PlayAnimation("swing_pst")
			inst.sg.statemem.hit = hit
		end,

		timeline =
		{
			--head hitbox
			FrameEvent(0, function(inst) inst.components.offsethitboxes:SetEnabled("offsethitbox", true) end),
			FrameEvent(0, function(inst) inst.components.offsethitboxes:Move("offsethitbox", 1.3) end),
			FrameEvent(2, function(inst) inst.components.offsethitboxes:Move("offsethitbox", 1.1) end),
			FrameEvent(4, function(inst) inst.components.offsethitboxes:Move("offsethitbox", .6) end),
			FrameEvent(6, function(inst) inst.components.offsethitboxes:Move("offsethitbox", .4) end),
			FrameEvent(8, function(inst) inst.components.offsethitboxes:SetEnabled("offsethitbox", false) end),
			--

			FrameEvent(2, function(inst)
				inst.sg:RemoveStateTag("vulnerable")
			end),
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
				if inst.sg.statemem.hit and not inst.components.timer:HasTimer("taunt_cd") then
					inst.sg:GoToState("taunt")
				else
					inst.sg:GoToState("idle")
				end
			end),
		},

		onexit = function(inst) inst.components.offsethitboxes:SetEnabled("offsethitbox", false) end,
	}),

	State({
		name = "hook",
		tags = { "attack", "busy" },

		onenter = function(inst)
			inst.AnimState:PlayAnimation("hook")
		end,

		timeline =
		{
			--physics
			FrameEvent(9, function(inst) inst.Physics:SetMotorVel(4.8) end),
			FrameEvent(19, function(inst) inst.Physics:Stop() end),
			FrameEvent(27, function(inst) inst.Physics:MoveRelFacing(-40 / 150) end),
			FrameEvent(29, function(inst) inst.Physics:MoveRelFacing(-160 / 150) end),
			FrameEvent(31, function(inst) inst.Physics:MoveRelFacing(-40 / 150) end),
			--

			FrameEvent(10, function(inst)
				inst.components.combat:StartCooldown(3)
				inst.components.timer:StartTimer("hook_cd", 12, true)
			end),
			FrameEvent(12, function(inst)
				inst.sg.statemem.damage = ATTACK_DAMAGE.HOOK_BACK
				inst.sg.statemem.hitstoplevel = HitStopLevel.MEDIUM
				inst.sg.statemem.fxdist = -5
				inst.sg.statemem.back = true
				inst.components.hitbox:PushBeam(-1, -6.35, 3, HitPriority.BOSS_DEFAULT)
			end),
			FrameEvent(19, function(inst)
				inst.components.hitbox:StartRepeatTargetDelay()
				inst.sg.statemem.damage = ATTACK_DAMAGE.HOOK_FRONT
				inst.sg.statemem.hitstoplevel = HitStopLevel.LIGHT
				inst.sg.statemem.fxdist = 2
				inst.sg.statemem.back = false
				inst.components.hitbox:PushBeam(2, 8.7, 2, HitPriority.BOSS_DEFAULT)
			end),
			FrameEvent(20, function(inst)
				inst.components.hitbox:PushBeam(2, 8.7, 2, HitPriority.BOSS_DEFAULT)
			end),
			FrameEvent(27, function(inst)
				inst.components.hitbox:StopRepeatTargetDelay()
				inst.components.hitbox:StartRepeatTargetDelay()
				inst.sg.statemem.damage = ATTACK_DAMAGE.HOOK_PULL
				inst.sg.statemem.hitstoplevel = HitStopLevel.MEDIUM
				inst.sg.statemem.fxdist = 4.1
				inst.sg.statemem.pull = -3
				inst.sg.statemem.targets = {}
				inst.components.hitbox:PushBeam(5.9, 7.7, 2, HitPriority.BOSS_DEFAULT)
			end),
			FrameEvent(28, function(inst)
				inst.sg.statemem.pull = -2
				inst.components.hitbox:PushBeam(3.5, 7.7, 2, HitPriority.BOSS_DEFAULT)
			end),
			FrameEvent(29, function(inst)
				inst.sg.statemem.fxdist = 1.5
				inst.sg.statemem.pull = -1
				inst.components.hitbox:PushBeam(2.8, 4.6, 2, HitPriority.BOSS_DEFAULT)
			end),
			FrameEvent(30, function(inst)
				inst.sg.statemem.pull = -.5
				inst.components.hitbox:PushBeam(1.6, 4.6, 2, HitPriority.BOSS_DEFAULT)
			end),
			FrameEvent(39, function(inst)
				ChooseHookComboAttack(inst, inst.sg.statemem.targets)
			end),
			FrameEvent(43, function(inst)
				inst.sg:AddStateTag("caninterrupt")
			end),
			FrameEvent(45, function(inst)
				inst.sg:RemoveStateTag("busy")
			end),
		},

		events =
		{
			EventHandler("hitboxtriggered", OnHookHitBoxTriggered),
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
		name = "acid",
		tags = { "attack", "busy" },

		onenter = function(inst)
			inst.AnimState:PlayAnimation("acid")
		end,

		timeline =
		{
			--physics
			FrameEvent(2, function(inst) inst.Physics:MoveRelFacing(-30 / 150) end),
			FrameEvent(4, function(inst) inst.Physics:MoveRelFacing(-30 / 150) end),
			FrameEvent(6, function(inst) inst.Physics:MoveRelFacing(-60 / 150) end),
			FrameEvent(8, function(inst) inst.Physics:MoveRelFacing(-60 / 150) end),
			FrameEvent(10, function(inst) inst.Physics:MoveRelFacing(-30 / 150) end),
			FrameEvent(12, function(inst) inst.Physics:MoveRelFacing(-30 / 150) end),
			FrameEvent(18, function(inst) inst.Physics:MoveRelFacing(70 / 150) end),
			FrameEvent(20, function(inst) inst.Physics:MoveRelFacing(140 / 150) end),
			FrameEvent(22, function(inst) inst.Physics:MoveRelFacing(170 / 150) end),
			FrameEvent(38, function(inst) inst.Physics:MoveRelFacing(-100 / 150) end),
			FrameEvent(40, function(inst) inst.Physics:MoveRelFacing(-40 / 150) end),
			--

			--head hitbox
			FrameEvent(22, function(inst) inst.components.offsethitboxes:SetEnabled("offsethitbox", true) end),
			FrameEvent(22, function(inst) inst.components.offsethitboxes:Move("offsethitbox", .8) end),
			FrameEvent(24, function(inst) inst.components.offsethitboxes:Move("offsethitbox", 1) end),
			FrameEvent(26, function(inst) inst.components.offsethitboxes:Move("offsethitbox", 1.2) end),
			FrameEvent(34, function(inst) inst.components.offsethitboxes:Move("offsethitbox", 1) end),
			FrameEvent(36, function(inst) inst.components.offsethitboxes:Move("offsethitbox", .5) end),
			FrameEvent(42, function(inst) inst.components.offsethitboxes:SetEnabled("offsethitbox", false) end),
			--

			FrameEvent(4, function(inst)
				inst.sg:AddStateTag("nointerrupt")
			end),
			FrameEvent(22, function(inst)
				inst.sg:RemoveStateTag("nointerrupt")
				inst.sg:AddStateTag("vulnerable")
				--Attack!
			end),
			FrameEvent(36, function(inst)
				inst.sg:RemoveStateTag("vulnerable")
			end),
			FrameEvent(42, function(inst)
				inst.sg:AddStateTag("caninterrupt")
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

		onexit = function(inst) inst.components.offsethitboxes:SetEnabled("offsethitbox", false) end,
	}),

	State({
		name = "dodge",
		tags = { "busy" },

		onenter = function(inst)
			inst.AnimState:PlayAnimation("backhop")
		end,

		timeline =
		{
			--physics
			FrameEvent(1, function(inst) inst.Physics:SetMotorVel(-8) end),
			FrameEvent(2, function(inst) inst.Physics:SetMotorVel(-12) end),
			FrameEvent(3, function(inst) inst.Physics:SetMotorVel(-18) end),
			FrameEvent(6, function(inst) inst.Physics:SetMotorVel(-16) end),
			FrameEvent(8, function(inst) inst.Physics:SetMotorVel(-12) end),
			FrameEvent(13, function(inst) inst.Physics:SetMotorVel(-6) end),
			FrameEvent(14, function(inst) inst.Physics:SetMotorVel(-5) end),
			FrameEvent(15, function(inst) inst.Physics:SetMotorVel(-4) end),
			FrameEvent(16, function(inst) inst.Physics:SetMotorVel(-3) end),
			FrameEvent(17, function(inst) inst.Physics:SetMotorVel(-2) end),
			FrameEvent(18, function(inst) inst.Physics:SetMotorVel(-1) end),
			FrameEvent(19, function(inst) inst.Physics:SetMotorVel(-.5) end),
			FrameEvent(20, function(inst) inst.Physics:Stop() end),
			--

			FrameEvent(2, function(inst)
				inst.sg:AddStateTag("airborne")
				if inst.components.timer:HasTimer("dodgerepeat_cd") then
					inst.components.timer:StartTimer("dodge_cd", 4, true)
				else
					inst.components.timer:StartTimer("dodgerepeat_cd", 2)
				end
			end),
			FrameEvent(4, function(inst)
				inst.sg:AddStateTag("nointerrupt")
			end),
			FrameEvent(13, function(inst)
				inst.sg:RemoveStateTag("airborne")
				inst.sg:RemoveStateTag("nointerrupt")
			end),
			FrameEvent(20, function(inst)
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
		name = "turn_dodge_pre",
		tags = { "turning", "busy" },

		onenter = function(inst)
			inst.AnimState:PlayAnimation("turn_backhop_pre")
		end,

		timeline =
		{
			--physics
			FrameEvent(1, function(inst) inst.Physics:SetMotorVel(14) end),
			FrameEvent(2, function(inst) inst.Physics:SetMotorVel(18) end),
			FrameEvent(4, function(inst) inst.Physics:SetMotorVel(16) end),
			--

			FrameEvent(2, function(inst)
				if inst.components.timer:HasTimer("dodgerepeat_cd") then
					inst.components.timer:StartTimer("dodge_cd", 4, true)
				else
					inst.components.timer:StartTimer("dodgerepeat_cd", 2)
				end
			end),
			FrameEvent(4, function(inst)
				inst.sg:AddStateTag("airborne")
				inst.sg:AddStateTag("nointerrupt")
			end),
		},

		events =
		{
			EventHandler("animover", function(inst)
				inst.sg.statemem.dodging = true
				inst:FlipFacingAndRotation()
				inst.sg:GoToState("turn_dodge_pst")
			end),
		},

		onexit = function(inst)
			if not inst.sg.statemem.dodging then
				inst.Physics:Stop()
			end
		end,
	}),

	State({
		name = "turn_dodge_pst",
		tags = { "busy", "airborne", "nointerrupt" },

		onenter = function(inst)
			inst.AnimState:PlayAnimation("turn_backhop_pst")
		end,

		timeline =
		{
			--physics
			FrameEvent(0, function(inst) inst.Physics:SetMotorVel(-14) end),
			FrameEvent(3, function(inst) inst.Physics:SetMotorVel(-12) end),
			FrameEvent(8, function(inst) inst.Physics:SetMotorVel(-6) end),
			FrameEvent(9, function(inst) inst.Physics:SetMotorVel(-5) end),
			FrameEvent(10, function(inst) inst.Physics:SetMotorVel(-4) end),
			FrameEvent(11, function(inst) inst.Physics:SetMotorVel(-3) end),
			FrameEvent(12, function(inst) inst.Physics:SetMotorVel(-2) end),
			FrameEvent(13, function(inst) inst.Physics:SetMotorVel(-1) end),
			FrameEvent(14, function(inst) inst.Physics:SetMotorVel(-.5) end),
			FrameEvent(15, function(inst) inst.Physics:Stop() end),
			--

			FrameEvent(8, function(inst)
				inst.sg:RemoveStateTag("airborne")
				inst.sg:RemoveStateTag("nointerrupt")
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

		onexit = function(inst) inst.Physics:Stop() end,
	}),

	State({
		name = "dormant_idle",
		tags = { "dormant", "busy", "caninterrupt" },

		onenter = function(inst)
			inst.AnimState:PlayAnimation("dormant_idle", true)
			inst.sg.statemem.task = inst:DoPeriodicTask(1, function()
				local target = inst:GetClosestPlayerInRange(12, true)
				if target ~= nil then
					inst.components.combat:SetTarget(target)

					local facingrot = inst.Transform:GetFacingRotation()
					local rot = inst:GetAngleTo(target)
					if DiffAngle(facingrot, rot) < 90 then
						inst.sg:GoToState("dormant_look_front")
					else
						inst.sg:GoToState("dormant_look_back")
					end
				end
			end)
		end,

		timeline =
		{
			--physics
			FrameEvent(0, function(inst) inst.Physics:SetSize(1.8) end),
			--
		},

		onexit = function(inst)
			inst.sg.statemem.task:Cancel()
			if not inst.sg.statemem.dormant then
				inst.Physics:SetSize(1.9)
			end
		end,
	}),

	State({
		name = "dormant_hit",
		tags = { "dormant", "hit", "busy" },

		onenter = function(inst)
			inst.AnimState:PlayAnimation("dormant_hit")
		end,

		timeline =
		{
			--physics
			FrameEvent(0, function(inst) inst.Physics:SetSize(1.8) end),
			--

			FrameEvent(7, function(inst)
				inst.sg:AddStateTag("caninterrupt")
			end),
		},

		events =
		{
			EventHandler("animover", function(inst)
				inst.sg.statemem.dormant = true
				inst.sg:GoToState("dormant_getup_pre")
			end),
		},

		onexit = function(inst)
			if not inst.sg.statemem.dormant then
				inst.Physics:SetSize(1.9)
			end
		end,
	}),

	State({
		name = "dormant_look_front",
		tags = { "dormant", "busy", "caninterrupt" },

		onenter = function(inst)
			inst.AnimState:PlayAnimation("dormant_look_front")
		end,

		timeline =
		{
			--physics
			FrameEvent(0, function(inst) inst.Physics:SetSize(1.8) end),
			--
		},

		events =
		{
			EventHandler("animover", function(inst)
				inst.sg.statemem.dormant = true
				inst.sg:GoToState("dormant_getup_pre")
			end),
		},

		onexit = function(inst)
			if not inst.sg.statemem.dormant then
				inst.Physics:SetSize(1.9)
			end
		end,
	}),

	State({
		name = "dormant_look_back",
		tags = { "dormant", "busy", "caninterrupt" },

		onenter = function(inst)
			inst.AnimState:PlayAnimation("dormant_look_back")
		end,

		timeline =
		{
			--physics
			FrameEvent(0, function(inst) inst.Physics:SetSize(1.8) end),
			--
		},

		events =
		{
			EventHandler("animover", function(inst)
				inst.sg.statemem.dormant = true
				inst.sg:GoToState("dormant_getup_pre", true)
			end),
		},

		onexit = function(inst)
			if not inst.sg.statemem.dormant then
				inst.Physics:SetSize(1.9)
			end
		end,
	}),

	State({
		name = "dormant_getup_pre",
		tags = { "dormant", "busy" },

		onenter = function(inst, turn)
			local target = inst.components.combat:GetTarget()
			if target ~= nil then
				local oldfacing = inst.Transform:GetFacing()
				inst:Face(target)
				turn = oldfacing ~= inst.Transform:GetFacing()
			end
			inst.AnimState:PlayAnimation(turn and "dormant_getup_pre_turn" or "dormant_getup_pre")
		end,

		timeline =
		{
			--physics
			FrameEvent(0, function(inst) inst.Physics:SetSize(1.8) end),
			FrameEvent(8, function(inst) inst.Physics:SetSize(1.5) end),
			--

			FrameEvent(6, function(inst)
				inst.sg:AddStateTag("nointerrupt")
			end),
			FrameEvent(7, function(inst)
				inst.sg:RemoveStateTag("dormant")
			end),
			FrameEvent(8, function(inst)
				inst.sg:AddStateTag("airborne")
			end),
		},

		events =
		{
			EventHandler("animover", function(inst)
				inst.sg.statemem.dormant = true
				inst.sg:GoToState("dormant_getup_pst")
			end),
		},

		onexit = function(inst)
			if not inst.sg.statemem.dormant then
				inst.Physics:SetSize(1.9)
			end
		end,
	}),

	State({
		name = "dormant_getup_pst",
		tags = { "busy", "airborne", "nointerrupt" },

		onenter = function(inst)
			inst.AnimState:PlayAnimation("dormant_getup_pst")
		end,

		timeline =
		{
			--physics
			FrameEvent(0, function(inst) inst.Physics:SetSize(1.8) end),
			FrameEvent(16, function(inst) inst.Physics:SetSize(1.9) end),
			--

			FrameEvent(0, function(inst)
				inst.components.hitbox:StartRepeatTargetDelayAnimFrames(6)
				inst.components.hitbox:PushBeam(-5, -1, 2, HitPriority.BOSS_DEFAULT)
			end),
			FrameEvent(1, function(inst)
				inst.components.hitbox:PushBeam(-5, 0, 2, HitPriority.BOSS_DEFAULT)
			end),
			FrameEvent(2, function(inst)
				inst.components.hitbox:PushBeam(0, 3.5, 2, HitPriority.BOSS_DEFAULT)
			end),
			FrameEvent(6, function(inst)
				inst.components.hitbox:PushBeam(-3.6, 1.7, 2, HitPriority.BOSS_DEFAULT)
			end),
			FrameEvent(7, function(inst)
				inst.components.hitbox:PushBeam(0, 2.8, 2, HitPriority.BOSS_DEFAULT)
			end),
			FrameEvent(8, function(inst)
				inst.components.hitbox:PushBeam(1, 4, 2, HitPriority.BOSS_DEFAULT)
			end),
			FrameEvent(16, function(inst)
				inst.sg:RemoveStateTag("airborne")
			end),
			FrameEvent(18, function(inst)
				inst.sg:RemoveStateTag("nointerrupt")
			end),
			FrameEvent(24, function(inst)
				inst.sg:AddStateTag("caninterrupt")
			end),
		},

		events =
		{
			EventHandler("hitboxtriggered", OnSpinHitBoxTriggered),
			EventHandler("animover", function(inst)
				SGCommon.Fns.TurnAndActOnTarget(inst, inst.components.combat:GetTarget(), true, "taunt")
			end),
		},

		onexit = function(inst)
			inst.Physics:SetSize(1.9)
			inst.components.hitbox:StopRepeatTargetDelay()
		end,
	}),
}

SGCommon.States.AddRunStates(states,
{
	turnpsttimeline =
	{
		--physics
		FrameEvent(0, function(inst) inst.Physics:MoveRelFacing(182 / 150) end),
		--

		FrameEvent(2, function(inst)
			inst.sg:RemoveStateTag("busy")
		end),
	},
})

SGCommon.States.AddTurnStates(states,
{
	chooseattack_fn = ChooseAttack,
	psttimeline =
	{
		--physics
		FrameEvent(0, function(inst) inst.Physics:MoveRelFacing(124 / 150) end),
	},
})

SGCommon.States.AddMonsterDeathStates(states)
SGCommon.States.AddBossDeathStates(states)

return StateGraph("sg_thatcher", states, events, "idle")
