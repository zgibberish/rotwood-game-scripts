local SGCommon = require "stategraphs.sg_common"
local TargetRange = require "targetrange"
local monsterutil = require "util.monsterutil"

local ATTACK_DAMAGE =
{
	CHARGE_HEAVY = 15,
	CHARGE_LIGHT = 10,
	THROW = 25,
	HEADBUTT = 15,
	BITE = 20,
	ROAR = 10,
}

local function OnChargeHitBoxTriggered(inst, data)
	local damage, hitstoplevel
	if inst.sg.statemem.lightcharge then
		damage = ATTACK_DAMAGE.CHARGE_LIGHT
		hitstoplevel = HitStopLevel.MINOR
	else
		damage = ATTACK_DAMAGE.CHARGE_HEAVY
		hitstoplevel = HitStopLevel.MEDIUM
	end

	inst.components.hitstopper:PushHitStop(hitstoplevel)

	local dir = inst.Transform:GetFacingRotation()
	if inst.sg.statemem.flipped then
		dir = dir + 180
	end

	for i = 1, #data.targets do
		local v = data.targets[i]
		inst.components.combat:DoKnockdownAttack({
			target = v,
			damage_mod = damage,
			dir = dir,
			speedmult = 1.0,
			hitstun = 10,
		})

		if v.components.hitstopper ~= nil then
			v.components.hitstopper:PushHitStop(hitstoplevel)
		end

		SpawnHitFx("fx_hit_player_round", inst, v, 0, 0, dir, hitstoplevel)
		SpawnHurtFx(inst, v, 0, dir, hitstoplevel)
	end
end

local function OnThrowHitBoxTriggered(inst, data)
	local hitstoplevel = HitStopLevel.HEAVY
	inst.components.hitstopper:PushHitStop(hitstoplevel)

	local dir = inst.Transform:GetFacingRotation()
	for i = 1, #data.targets do
		local v = data.targets[i]
		inst.components.combat:DoKnockdownAttack({
			target = v,
			damage_mod = ATTACK_DAMAGE.THROW,
			dir = dir,
			speedmult = 1.5,
			hitstun = 10,
		})

		if v.components.hitstopper ~= nil then
			v.components.hitstopper:PushHitStop(hitstoplevel)
		end

		SpawnHitFx("fx_hit_player_round", inst, v, 3.2, 0, dir, hitstoplevel)
		SpawnHurtFx(inst, v, 3.2, dir, hitstoplevel)
	end
end

local function OnHeadbuttHitBoxTriggered(inst, data)
	local hitstoplevel = HitStopLevel.HEAVY
	inst.components.hitstopper:PushHitStop(hitstoplevel)

	local dir = inst.Transform:GetFacingRotation()
	for i = 1, #data.targets do
		local v = data.targets[i]
		inst.components.combat:DoKnockdownAttack({
			target = v,
			damage_mod = ATTACK_DAMAGE.HEADBUTT,
			dir = dir,
			speedmult = 1.0,
			hitstun = 10,
		})

		if v.components.hitstopper ~= nil then
			v.components.hitstopper:PushHitStop(hitstoplevel)
		end

		SpawnHitFx("fx_hit_player_round", inst, v, 3, 0, dir, hitstoplevel)
		SpawnHurtFx(inst, v, 3, dir, hitstoplevel)
	end
end

local function OnBiteHitBoxTriggered(inst, data)
	local hitstoplevel = HitStopLevel.MEDIUM
	inst.components.hitstopper:PushHitStop(hitstoplevel)

	local dir = inst.Transform:GetFacingRotation()
	for i = 1, #data.targets do
		local v = data.targets[i]
		inst.sg.statemem.bitetargets[v] = true
		inst.components.combat:DoKnockbackAttack({
			target = v,
			damage_mod = ATTACK_DAMAGE.BITE,
			dir = dir,
			speedmult = 1.0,
			hitstun = 10,
		})

		if v.components.hitstopper ~= nil then
			v.components.hitstopper:PushHitStop(hitstoplevel)
		end

		SpawnHitFx("fx_hit_player_round", inst, v, 4.5, 0, dir, hitstoplevel)
		SpawnHurtFx(inst, v, 4.5, dir, hitstoplevel)
	end
end

local function OnBite2HitBoxTriggered(inst, data)
	local hitstoplevel = HitStopLevel.MEDIUM
	inst.components.hitstopper:PushHitStop(hitstoplevel)

	local dir = inst.Transform:GetFacingRotation()
	for i = 1, #data.targets do
		local v = data.targets[i]
		if inst.sg.statemem.bitetargets[v] then
			inst.components.combat:DoKnockdownAttack({
				target = v,
				damage_mod = ATTACK_DAMAGE.BITE,
				dir = dir,
				speedmult = 1.0,
				hitstun = 10,
			})
		else
			inst.components.combat:DoKnockbackAttack({
				target = v,
				damage_mod = ATTACK_DAMAGE.BITE,
				dir = dir,
				speedmult = 1.0,
				hitstun = 10,
			})
		end

		if v.components.hitstopper ~= nil then
			v.components.hitstopper:PushHitStop(hitstoplevel)
		end

		SpawnHitFx("fx_hit_player_round", inst, v, 6.1, 0, dir, hitstoplevel)
		SpawnHurtFx(inst, v, 6.1, dir, hitstoplevel)
	end
end

local function OnRoarHitBoxTriggered(inst, data)
	if inst.sg.statemem.roarhits ~= nil then
		local closetargets = inst.components.hitbox:TriggerBeam(3.7, 7.7, 3)
		if closetargets ~= nil then
			local hitstoplevel = HitStopLevel.MINOR
			local hit = false
			local dir = inst.Transform:GetFacingRotation()
			for i = 1, #closetargets do
				local v = closetargets[i]
				if v.sg and not inst.sg.statemem.roarhits[v] then
					inst.sg.statemem.roarhits[v] = true
					if v.sg:HasStateTag("airborne") or not v.sg:HasStateTag("knockdown") then
						inst.components.combat:DoLoudAttack({
							target = v,
							damage_mod = ATTACK_DAMAGE.ROAR,
							dir = dir,
							speedmult = .6,
							hitstun = 10,
						})

						if v.components.hitstopper ~= nil then
							v.components.hitstopper:PushHitStop(hitstoplevel)
						end

						hit = true
					end
				end
			end
			if hit then
				inst.components.hitstopper:PushHitStop(hitstoplevel)
			end
		end
	end

	for i = 1, #data.targets do
		local v = data.targets[i]
		if not inst.sg.statemem.endroar or (v.sg and v.sg:HasStateTag("deafen")) then
			v:PushEvent("deafen", inst)
		end
	end
end

local function ChooseAttack(inst, data)
	if data.target ~= nil and data.target:IsValid() then
		local trange = TargetRange(inst, data.target)
		if not (inst.components.timer:HasTimer("roar_cd") or data.target.sg:HasStateTag("knockdown")) then
			SGCommon.Fns.FaceActionTarget(inst, data, true)
			inst.sg:GoToState("roar")
			return true
		end
		if not inst.components.timer:HasTimer("bite_cd") then
			if trange:TestBeam(4.4, 7, 2) then
				SGCommon.Fns.FaceActionTarget(inst, data, true)
				inst.sg:GoToState("bite")
				return true
			end
		end
		if not inst.components.timer:HasTimer("headbutt_cd") then
			if not trange:IsOverlapped() then
				if trange:TestCone45(0, 9, 2) then
					SGCommon.Fns.FaceActionTarget(inst, data, false)
					inst.sg:GoToState("headbutt")
					return true
				end
			end
		end
		if not (inst.components.timer:HasTimer("charge_cd") or inst.components.timer:HasTimer("doublecharge_cd")) then
			local facingrot = inst.Transform:GetFacingRotation()
			local shouldcharge = false
			for i = 1, #AllPlayers do
				local target = AllPlayers[i]
				local trange2 = TargetRange(inst, target)
				local maxrange = trange2:IsFacingTarget() and 30 or 8
				if trange2:TestCone(30, 0, maxrange, 2) then
					--Targeted rotation happens midway through charge_pre state
					inst.sg:GoToState("charge_pre")
					return true
				end
			end
		end
	end
	return false
end

local events =
{
}
monsterutil.AddMonsterCommonEvents(events,
{
	locomote_data = { run = true },
	chooseattack_fn = ChooseAttack,
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
			FrameEvent(10, function(inst)
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
			inst.Physics:SetSize(3.8)
			inst.Physics:MoveRelFacing(-90 / 150)
			inst.Physics:SetMotorVel(-10)
		end,

		timeline =
		{
			FrameEvent(2, function(inst) inst.Physics:SetMotorVel(-4) end),
			FrameEvent(3, function(inst) inst.Physics:SetMotorVel(-3) end),
			FrameEvent(4, function(inst) inst.Physics:SetMotorVel(-2) end),
			FrameEvent(5, function(inst) inst.Physics:SetMotorVel(-1) end),
			FrameEvent(6, function(inst) inst.Physics:SetMotorVel(-.5) end),
			FrameEvent(7, function(inst) inst.Physics:Stop() end),
			FrameEvent(10, function(inst)
				inst.sg:RemoveStateTag("nointerrupt")
				inst.sg:AddStateTag("vulnerable")
				inst.Physics:MoveRelFacing(90 / 150)
				inst.Physics:SetSize(4.4)
			end),
			FrameEvent(12, function(inst)
				inst.components.offsethitboxes:Move("offsethitbox", 2.5)
				inst.components.offsethitboxes:SetEnabled("offsethitbox", true)
			end),
			FrameEvent(15, function(inst)
				inst.components.offsethitboxes:Move("offsethitbox", 2.7)
			end),
			FrameEvent(17, function(inst)
				inst.components.offsethitboxes:Move("offsethitbox", 2.8)
			end),
			FrameEvent(25, function(inst)
				inst.sg:RemoveStateTag("vulnerable")
				inst.sg:AddStateTag("caninterrupt")
			end),
			FrameEvent(27, function(inst)
				inst.components.offsethitboxes:Move("offsethitbox", 2.5)
			end),
			FrameEvent(29, function(inst)
				inst.components.offsethitboxes:SetEnabled("offsethitbox", false)
			end),
			FrameEvent(31, function(inst)
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

		onexit = function(inst)
			inst.Physics:Stop()
			inst.Physics:SetSize(4.4)
			inst.components.offsethitboxes:SetEnabled("offsethitbox", false)
		end,
	}),

	State({
		name = "knockdown",
		tags = { "hit", "knockdown", "busy", "nointerrupt" },

		onenter = function(inst)
			inst.AnimState:PlayAnimation("knockdown")
			inst.Physics:SetMotorVel(-8)
			if not inst.components.timer:HasTimer("knockdown") then
				--Force permanent knockdown state when debugging
				inst.components.timer:StartTimerAnimFrames("knockdown", 1)
				inst.components.timer:PauseTimer("knockdown")
			end
		end,

		timeline =
		{
			FrameEvent(1, function(inst) inst.Physics:SetMotorVel(-6) end),
			FrameEvent(2, function(inst)
				inst.Physics:SetMotorVel(-4)
				inst.Physics:SetSize(3.6)
			end),
			FrameEvent(4, function(inst) inst.Physics:SetSize(3.2) end),
			FrameEvent(8, function(inst)
				inst.sg:AddStateTag("airborne")
			end),
			FrameEvent(9, function(inst) inst.Physics:SetSize(3.4) end),
			FrameEvent(11, function(inst) inst.Physics:SetSize(3.6) end),
			FrameEvent(13, function(inst) inst.Physics:SetSize(4.2) end),
			FrameEvent(15, function(inst)
				inst.sg:RemoveStateTag("airborne")
				inst.sg:RemoveStateTag("nointerrupt")
				inst.sg:AddStateTag("caninterrupt")
				inst.Physics:SetMotorVel(-2)
				inst.Physics:SetSize(5)
			end),
			FrameEvent(16, function(inst) inst.Physics:SetMotorVel(-1) end),
			FrameEvent(17, function(inst) inst.Physics:SetMotorVel(-.5) end),
			FrameEvent(18, function(inst) inst.Physics:Stop() end),
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
				inst.Physics:SetSize(4.4)
				inst.components.timer:StopTimer("knockdown")
			end
		end,
	}),

	State({
		name = "knockdown_idle",
		tags = { "knockdown", "busy", "caninterrupt" },

		onenter = function(inst)
			inst.AnimState:PlayAnimation("knockdown_idle", true)
			inst.Physics:SetSize(5)
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
				inst.Physics:SetSize(4.4)
				inst.components.timer:StopTimer("knockdown")
			end
		end,
	}),

	State({
		name = "knockdown_hit_front",
		tags = { "hit", "knockdown", "busy" },

		onenter = function(inst, getup)
			inst.AnimState:PlayAnimation("knockdown_hit_head")
			inst.Physics:SetSize(5)
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
				inst.Physics:SetSize(4.4)
				inst.components.timer:StopTimer("knockdown")
			end
		end,
	}),

	State({
		name = "knockdown_hit_back",
		tags = { "hit", "knockdown", "busy" },

		onenter = function(inst, getup)
			inst.AnimState:PlayAnimation("knockdown_hit_back")
			inst.Physics:SetSize(5)
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
				inst.Physics:SetSize(4.4)
				inst.components.timer:StopTimer("knockdown")
			end
		end,
	}),

	State({
		name = "knockdown_getup",
		tags = { "getup", "knockdown", "busy", "nointerrupt" },

		onenter = function(inst)
			inst.AnimState:PlayAnimation("knockdown_getup")
			inst.Physics:SetSize(5)
			inst.components.timer:StopTimer("knockdown")
		end,

		timeline =
		{
			FrameEvent(9, function(inst) inst.Physics:SetSize(4.7) end),
			FrameEvent(12, function(inst)
				inst.sg:RemoveStateTag("knockdown")
				inst.sg:AddStateTag("nointerrupt")
				inst.Physics:SetSize(4.4)
			end),
			FrameEvent(16, function(inst)
				inst.sg:RemoveStateTag("nointerrupt")
				inst.components.offsethitboxes:Move("offsethitbox", 3.4)
				inst.components.offsethitboxes:SetEnabled("offsethitbox", true)
			end),
			FrameEvent(18, function(inst)
				inst.sg:AddStateTag("caninterrupt")
			end),
			FrameEvent(19, function(inst)
				inst.components.offsethitboxes:Move("offsethitbox", 3.2)
			end),
			FrameEvent(22, function(inst)
				inst.components.offsethitboxes:Move("offsethitbox", 2.8)
			end),
			FrameEvent(24, function(inst)
				inst.sg:RemoveStateTag("busy")
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
				inst.Physics:SetSize(4.4)
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
		name = "roar",
		tags = { "busy" },

		onenter = function(inst)
			inst.AnimState:PlayAnimation("roar")
			inst:SnapToFacingRotation()
			inst.Physics:SetSize(1240 / 300)
			inst.Physics:MoveRelFacing(-40 / 150)
			inst.sg.statemem.intensity = 0
		end,

		onupdate = function(inst)
			if inst.sg.statemem.reduceroar then
				inst.sg.statemem.intensity = inst.sg.statemem.intensity - 1
			end
			if inst.sg.statemem.intensity > 0 then
				local k = 1 - inst.sg.statemem.intensity / 8
				k = 1 - k * k
				inst.components.hitbox:PushCircle(3.7, 0, k * 12, HitPriority.BOSS_DEFAULT)
			end
		end,

		timeline =
		{
			FrameEvent(2, function(inst)
				inst.Physics:SetSize(1020 / 300)
				inst.Physics:MoveRelFacing(-110 / 150)
			end),
			FrameEvent(10, function(inst)
				inst.Physics:MoveRelFacing(190 / 150)
				inst.Physics:SetSize(1400 / 300)
			end),
			FrameEvent(12, function(inst)
				inst.sg.statemem.intensity = 8
				inst.sg.statemem.roarhits = {}
				inst.components.timer:StartTimer("roar_cd", 16, true)
				inst.components.timer:StopTimer("bite_cd")
				inst.components.timer:StopTimer("bite2_cd")
				inst.components.timer:StopTimer("headbutt_cd")
			end),
			FrameEvent(17, function(inst)
				inst.sg.statemem.roarhits = nil
				--Don't deafen new targets that move into range after this point
				inst.sg.statemem.endroar = true
				inst.sg.statemem.reduceroar = true
			end),
			FrameEvent(24, function(inst)
				inst.sg.statemem.intensity = 0
				inst.sg.statemem.reduceroar = false
			end),
			FrameEvent(31, function(inst)
				inst.sg.statemem.intensity = 0
				inst.sg.statemem.reduceroar = false
				inst.Physics:SetSize(4.4)
				inst.Physics:MoveRelFacing(-40 / 150)
			end),
			FrameEvent(34, function(inst)
				inst.sg:AddStateTag("caninterrupt")
			end),
		},

		events =
		{
			EventHandler("hitboxtriggered", OnRoarHitBoxTriggered),
			EventHandler("animover", function(inst)
				inst.sg:GoToState("idle")
			end),
		},

		onexit = function(inst)
			inst.Physics:SetSize(4.4)
			inst.components.hitbox:StopRepeatTargetDelay()
		end,
	}),

	State({
		name = "charge_pre",
		tags = { "attack", "busy" },

		onenter = function(inst)
			inst.AnimState:PlayAnimation("charge_pre")
			if inst.sg.mem.lastchargepst ~= nil and GetTick() - inst.sg.mem.lastchargepst < 60 then
				--Prevent running back and forth indefinitely if we never reach
				--any targets. We DO want him to do it once or twice, so there
				--is no charge_cd if it ends with no action (ie. charge_flip_pst).
				inst.components.timer:StartTimer("doublecharge_cd", 6, true)
			end
		end,

		timeline =
		{
			FrameEvent(2, function(inst)
				inst.Physics:SetSize(1280 / 300)
				inst.Physics:MoveRelFacing(-20 / 150)
			end),
			FrameEvent(4, function(inst)
				inst.Physics:SetSize(1200 / 300)
				inst.Physics:MoveRelFacing(-40 / 150)
			end),
			FrameEvent(7, function(inst)
				inst.Physics:SetSize(1140 / 300)
				inst.Physics:MoveRelFacing(-30 / 150)
			end),
			FrameEvent(10, function(inst)
				inst.Physics:SetSize(1100 / 300)
				inst.Physics:MoveRelFacing(-20 / 150)
			end),
			FrameEvent(18, function(inst)
				local facingrot = inst.Transform:GetFacingRotation()
				local targetrot = facingrot
				local mindistsq = math.huge
				for i = 1, #AllPlayers do
					local target = AllPlayers[i]
					local x1, z1 = target.Transform:GetWorldXZ()
					local rot = inst:GetAngleToXZ(x1, z1)
					if DiffAngle(facingrot, rot) < 45 then
						local distsq = inst:GetDistanceSqToXZ(x1, z1)
						if distsq < mindistsq then
							mindistsq = distsq
							targetrot = rot
						end
					end
				end
				inst.Transform:SetRotation(targetrot)
				inst.Physics:SetMotorVel(18.5)
			end),
			FrameEvent(19, function(inst)
				inst.Physics:MoveRelFacing(110 / 150 - 18.5 / 30)
				inst.Physics:SetSize(1250 / 300)
				inst.components.hitbox:StartRepeatTargetDelayAnimFrames(24)
				inst.components.hitbox:PushBeam(-1.9, 4.3, 2, HitPriority.BOSS_DEFAULT)
			end),
			FrameEvent(20, function(inst)
				inst.components.hitbox:PushBeam(-1.9, 4.3, 2, HitPriority.BOSS_DEFAULT)
			end),
		},

		events =
		{
			EventHandler("hitboxtriggered", OnChargeHitBoxTriggered),
			EventHandler("animover", function(inst)
				inst.Physics:MoveRelFacing(18.5 / 30)
				inst.sg.statemem.charging = true
				inst.sg:GoToState("charge_loop")
			end),
		},

		onexit = function(inst)
			if not inst.sg.statemem.charging then
				inst.Physics:Stop()
				inst.Physics:SetSize(4.4)
				inst.components.hitbox:StopRepeatTargetDelay()
			end
		end,
	}),

	State({
		name = "charge_loop",
		tags = { "attack", "busy" },

		onenter = function(inst)
			if not inst.AnimState:IsCurrentAnimation("charge_loop") then
				inst.AnimState:PlayAnimation("charge_loop", true)
			end
			inst.Physics:SetMotorVel(18.5)
			inst.Physics:SetSize(5)
			--hitbox continues from charge_pre/charge_loop
			inst.components.hitbox:StartRepeatTargetDelayAnimFrames(24)
			inst.components.timer:StartTimer("charge_cd", 4, true)
		end,

		onupdate = function(inst)
			inst.components.hitbox:PushBeam(-.5, 5.5, 2, HitPriority.BOSS_DEFAULT)
		end,

		timeline =
		{
			FrameEvent(10, function(inst)
				for i = 1, #AllPlayers do
					local target = AllPlayers[i]
					local trange = TargetRange(inst, target)
					if trange:IsInRotation(45) then
						if trange:TestBeam(0, 7.5, 2) then
							inst.sg.statemem.charging = true
							inst.components.hitbox:StopRepeatTargetDelay()
							inst.sg:GoToState("charge_throw")
							return
						end
					end
				end
			end),
			FrameEvent(14, function(inst)
				local x, z = inst.Transform:GetWorldXZ()
				local facingrot = inst.Transform:GetFacingRotation()
				local hasinfront = false
				local hasbehind = false
				for i = 1, #AllPlayers do
					local target = AllPlayers[i]
					local trange = TargetRange(inst, target)
					if trange:IsFacingTarget() then
						local targetsize = target.HitBox:GetSize()
						if trange.absdx > 5 + trange.targetsize then
							hasinfront = true
							if trange.absdx >= 12 + trange.targetsize then
								--There's still a target far in front of me
								return
							elseif trange:TestBeam(0, 12, 2) then
								--There's still a target in front of my hitbox
								return
							end
						end
					else
						hasbehind = true
					end
				end
				if hasbehind or not hasinfront then
					inst.sg.statemem.charging = true
					inst.sg:GoToState("charge_to_flip")
				end
			end),
		},

		events =
		{
			EventHandler("hitboxtriggered", OnChargeHitBoxTriggered),
			EventHandler("animover", function(inst)
				inst.sg.statemem.charging = true
				inst.sg:GoToState("charge_loop")
			end),
		},

		onexit = function(inst)
			if not inst.sg.statemem.charging then
				inst.Physics:Stop()
				inst.Physics:SetSize(4.4)
				inst.components.hitbox:StopRepeatTargetDelay()
			end
		end,
	}),

	State({
		name = "charge_throw",
		tags = { "attack", "busy" },

		onenter = function(inst)
			inst.AnimState:PlayAnimation("charge_throw")
			inst.Physics:SetMotorVel(18.5)
			inst.Physics:SetSize(4)
			inst.components.offsethitboxes:Move("offsethitbox", 3.6)
			inst.components.offsethitboxes:SetEnabled("offsethitbox", true)
		end,

		timeline =
		{
			FrameEvent(1, function(inst) inst.Physics:SetMotorVel(8.5) end),
			FrameEvent(2, function(inst)
				inst.Physics:SetMotorVel(10)
				inst.components.combat:StartCooldown(3)
				inst.components.timer:StartTimer("charge_cd", 6, true)
				inst.components.offsethitboxes:SetEnabled("offsethitbox", false)
				inst.components.hitbox:StartRepeatTargetDelay()
				inst.components.hitbox:PushBeam(.8, 7, 2, HitPriority.BOSS_DEFAULT)
			end),
			FrameEvent(3, function(inst)
				inst.sg:AddStateTag("nointerrupt")
				inst.Physics:SetMotorVel(8)
				inst.Physics:SetSize(1170 / 300)
				inst.components.hitbox:PushBeam(.8, 4.3, 2, HitPriority.BOSS_DEFAULT)
			end),
			FrameEvent(4, function(inst)
				inst.Physics:SetMotorVel(6)
				inst.components.hitbox:PushBeam(.8, 4.3, 2, HitPriority.BOSS_DEFAULT)
			end),
			FrameEvent(5, function(inst) inst.Physics:SetMotorVel(4) end),
			FrameEvent(6, function(inst) inst.Physics:SetMotorVel(2) end),
			FrameEvent(7, function(inst) inst.Physics:SetMotorVel(1) end),
			FrameEvent(8, function(inst) inst.Physics:SetMotorVel(.5) end),
			FrameEvent(9, function(inst) inst.Physics:Stop() end),
			FrameEvent(10, function(inst)
				inst.Physics:MoveRelFacing(10 / 150)
				inst.Physics:SetSize(1200 / 300)
			end),
			FrameEvent(13, function(inst)
				inst.Physics:MoveRelFacing(10 / 150)
				inst.Physics:SetSize(1235/ 300)
			end),
			FrameEvent(16, function(inst)
				inst.Physics:MoveRelFacing(10 / 150)
				inst.Physics:SetSize(1270 / 300)
			end),
			FrameEvent(18, function(inst)
				inst.sg:RemoveStateTag("nointerrupt")
				inst.Physics:MoveRelFacing(10 / 150)
				inst.Physics:SetSize(1300 / 300)
			end),
			FrameEvent(20, function(inst)
				inst.sg:RemoveStateTag("busy")
				inst.Physics:MoveRelFacing(10 / 150)
				inst.Physics:SetSize(4.4)
			end),
		},

		events =
		{
			EventHandler("hitboxtriggered", OnThrowHitBoxTriggered),
			EventHandler("animover", function(inst)
				inst.sg:GoToState("idle")
			end),
		},

		onexit = function(inst)
			inst.Physics:Stop()
			inst.Physics:SetSize(4.4)
			inst.components.hitbox:StopRepeatTargetDelay()
			inst.components.offsethitboxes:SetEnabled("offsethitbox", false)
		end,
	}),

	State({
		name = "charge_to_flip",
		tags = { "attack", "busy" },

		onenter = function(inst)
			inst.AnimState:PlayAnimation("charge_to_flip")
			inst.Physics:SetMotorVel(18.5)
			inst.Physics:SetSize(5)
			--hitbox continues from charge_loop
			inst.components.hitbox:StartRepeatTargetDelayAnimFrames(20)
			inst.components.timer:StopTimer("charge_cd")
			inst.sg.statemem.hitrange = 5.5
		end,

		onupdate = function(inst)
			inst.components.hitbox:PushBeam(-.5, inst.sg.statemem.hitrange, 2, HitPriority.BOSS_DEFAULT)
		end,

		timeline =
		{
			FrameEvent(2, function(inst)
				inst.sg.statemem.hitrange = 5.1
				inst.Physics:SetSize(4.5)
			end),
			FrameEvent(4, function(inst)
				inst.sg:AddStateTag("airborne")
				inst.sg:AddStateTag("nointerrupt")
				inst.sg.statemem.hitrange = 4.7
				inst.Physics:SetMotorVel(19)
				inst.Physics:SetSize(4.1)
			end),
			FrameEvent(5, function(inst) inst.Physics:SetMotorVel(19.5) end),
			FrameEvent(6, function(inst)
				inst.sg.statemem.hitrange = 4.4
				inst.sg.statemem.lightcharge = true
				inst.Physics:SetMotorVel(20)
				inst.Physics:SetSize(3.9)
			end),
			FrameEvent(9, function(inst)
				inst.sg.statemem.hitrange = 4
				inst.Physics:SetSize(3.7)
			end),
		},

		events =
		{
			EventHandler("hitboxtriggered", OnChargeHitBoxTriggered),
			EventHandler("animover", function(inst)
				inst.sg.statemem.charging = true
				if not inst.components.timer:HasTimer("trip_cd") and inst.components.health:GetPercent() < .5 then
					inst.sg:GoToState("charge_flip_trip")
				else
					for i = 1, #AllPlayers do
						local target = AllPlayers[i]
						local trange = TargetRange(inst, target)
						if not trange:IsFacingTarget() then
							if trange:TestBeam(0, 7, 4) then
								inst.sg:GoToState("charge_flip_throw_pre")
								return
							end
						end
					end
					inst.sg:GoToState("charge_flip_pst")
				end
			end),
		},

		onexit = function(inst)
			if not inst.sg.statemem.charging then
				inst.Physics:Stop()
				inst.Physics:SetSize(4.4)
				inst.components.hitbox:StopRepeatTargetDelay()
			end
		end,
	}),

	State({
		name = "charge_flip_pst",
		tags = { "attack", "busy", "airborne", "nointerrupt" },

		onenter = function(inst)
			inst.AnimState:PlayAnimation("charge_flip_pst")
			inst:FlipFacingAndRotation()
			inst.Physics:SetMotorVel(-20)
			inst.Physics:SetSize(3.6)
			--hitbox continues from charge_to_flip
			inst.components.hitbox:StartRepeatTargetDelay()
			inst.sg.statemem.hitrange = 3.9
			inst.sg.statemem.lightcharge = true
			inst.sg.statemem.flipped = true
			inst.sg.mem.lastchargepst = GetTick()
		end,

		onupdate = function(inst)
			if inst.sg.statemem.hitrange ~= nil then
				inst.components.hitbox:PushBeam(.5, -inst.sg.statemem.hitrange, 2, HitPriority.BOSS_DEFAULT)
			end
		end,

		timeline =
		{
			FrameEvent(2, function(inst)
				inst.sg:RemoveStateTag("airborne")
				inst.sg.statemem.hitrange = 5.1
				inst.Physics:SetSize(4.6)
			end),
			FrameEvent(4, function(inst)
				inst.sg:RemoveStateTag("nointerrupt")
				inst.sg.statemem.hitrange = 5.9
				inst.Physics:SetSize(5.5)
			end),
			FrameEvent(7, function(inst) inst.Physics:SetMotorVel(-10) end),
			FrameEvent(9, function(inst)
				inst.sg.statemem.hitrange = nil
				inst.Physics:SetMotorVel(-8)
			end),
			FrameEvent(10, function(inst) inst.Physics:SetMotorVel(-6) end),
			FrameEvent(11, function(inst) inst.Physics:SetMotorVel(-4) end),
			FrameEvent(12, function(inst) inst.Physics:SetMotorVel(-2) end),
			FrameEvent(13, function(inst) inst.Physics:SetMotorVel(-1) end),
			FrameEvent(14, function(inst) inst.Physics:SetMotorVel(-.5) end),
			FrameEvent(15, function(inst)
				inst.Physics:Stop()
				inst.Physics:SetSize(5.4)
				inst.Physics:MoveRelFacing(-30 / 150)
			end),
			FrameEvent(17, function(inst)
				inst.Physics:SetSize(5.3)
				inst.Physics:MoveRelFacing(-60 / 150)
			end),
			FrameEvent(19, function(inst)
				inst.Physics:SetSize(5.1)
				inst.Physics:MoveRelFacing(-60 / 150)
			end),
			FrameEvent(22, function(inst)
				inst.Physics:SetSize(4.72)
				inst.Physics:MoveRelFacing(-90 / 150)
			end),
			FrameEvent(24, function(inst)
				inst.sg:AddStateTag("caninterrupt")
				inst.Physics:SetSize(4.56)
				inst.Physics:MoveRelFacing(-24 / 150)
			end),
		},

		events =
		{
			SGCommon.Events.OnQueueAttack(ChooseAttack),
			EventHandler("hitboxtriggered", OnChargeHitBoxTriggered),
			EventHandler("animover", function(inst)
				inst.Physics:MoveRelFacing(-24 / 150)
				if not SGCommon.Fns.TryQueuedAttack(inst, ChooseAttack) then
					inst.sg:GoToState("idle")
				end
			end),
		},

		onexit = function(inst)
			inst.Physics:Stop()
			inst.Physics:SetSize(4.4)
			inst.components.hitbox:StopRepeatTargetDelay()
		end,
	}),

	State({
		name = "charge_flip_trip",
		tags = { "attack", "busy", "airborne", "nointerrupt" },

		onenter = function(inst)
			inst.AnimState:PlayAnimation("charge_flip_trip")
			inst:FlipFacingAndRotation()
			inst.Physics:SetSize(2.6)
			inst.components.timer:StartTimer("charge_cd", 9)
			inst.components.timer:StartTimer("knockdown", 2)
			inst.sg.statemem.speed = 20
			inst.sg.statemem.decel = 0
			--hitbox continues from charge_to_flip
			inst.components.hitbox:StartRepeatTargetDelay()
			inst.sg.statemem.hitrange = 2.8
			inst.sg.statemem.lightcharge = true
			inst.sg.statemem.flipped = true
		end,

		onupdate = function(inst)
			if inst.sg.statemem.lastspeed ~= inst.sg.statemem.speed then
				inst.Physics:SetMotorVel(-inst.sg.statemem.speed)
				inst.sg.statemem.lastspeed = inst.sg.statemem.speed
			end
			if inst.sg.statemem.decel ~= 0 then
				if inst.sg.statemem.speed > inst.sg.statemem.decel then
					inst.sg.statemem.speed = inst.sg.statemem.speed - inst.sg.statemem.decel
				else
					inst.sg.statemem.speed = inst.sg.statemem.speed * .5
				end
			end
			if inst.sg.statemem.hitrange ~= nil then
				inst.components.hitbox:PushBeam(.5, -inst.sg.statemem.hitrange, 2, HitPriority.BOSS_DEFAULT)
			end
		end,

		timeline =
		{
			FrameEvent(1, function(inst)
				inst.sg.statemem.decel = .5
			end),
			FrameEvent(2, function(inst)
				inst.Physics:SetSize(2.2)
				inst.sg.statemem.hitrange = 2.6
			end),
			FrameEvent(4, function(inst)
				inst.sg.statemem.hitrange = 2.4
			end),
			FrameEvent(6, function(inst)
				inst.Physics:SetSize(2.6)
				inst.sg.statemem.hitrange = 2.9
			end),
			FrameEvent(8, function(inst)
				inst.sg:AddStateTag("knockdown")
				inst.Physics:SetSize(3.2)
				inst.sg.statemem.hitrange = 3.6
				inst.components.timer:StartTimer("trip_cd", 30, true)
			end),
			FrameEvent(11, function(inst)
				inst.sg:RemoveStateTag("airborne")
				inst.Physics:SetSize(4.2)
				inst.sg.statemem.speed = 10
				inst.sg.statemem.decel = 1
				inst.sg.statemem.hitrange = 4.9
			end),
			FrameEvent(13, function(inst)
				inst.Physics:SetSize(4.4)
				inst.sg.statemem.decel = 0
				inst.sg.statemem.hitrange = 6.2
			end),
			FrameEvent(15, function(inst)
				inst.sg:AddStateTag("airborne")
				inst.Physics:SetSize(4.7)
				inst.sg.statemem.hitrange = 7
			end),
			FrameEvent(17, function(inst)
				inst.sg.statemem.hitrange = nil
			end),
			FrameEvent(19, function(inst)
				inst.sg.statemem.decel = .25
			end),
			FrameEvent(23, function(inst)
				inst.sg.statemem.decel = .5
			end),
			FrameEvent(25, function(inst)
				inst.sg:RemoveStateTag("airborne")
				inst.sg:RemoveStateTag("nointerrupt")
				inst.sg:AddStateTag("caninterrupt")
				inst.Physics:SetSize(5)
				inst.sg.statemem.decel = 1
			end),
		},

		events =
		{
			EventHandler("hitboxtriggered", OnChargeHitBoxTriggered),
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
				inst.Physics:SetSize(4.4)
				inst.components.timer:StopTimer("knockdown")
			end
			inst.components.hitbox:StopRepeatTargetDelay()
		end,
	}),

	State({
		name = "charge_flip_throw_pre",
		tags = { "attack", "busy", "airborne", "nointerrupt" },

		onenter = function(inst)
			inst.AnimState:PlayAnimation("charge_flip_throw_pre")
			inst:FlipFacingAndRotation()
			inst.Physics:SetMotorVel(-20)
			inst.Physics:SetSize(3.6)
			--hitbox continues from charge_to_flip
			inst.components.hitbox:StartRepeatTargetDelay()
			inst.sg.statemem.hitrange = 3.9
			inst.sg.statemem.lightcharge = true
			inst.sg.statemem.flipped = true
		end,

		onupdate = function(inst)
			if inst.sg.statemem.hitrange ~= nil then
				inst.components.hitbox:PushBeam(.5, -inst.sg.statemem.hitrange, 2, HitPriority.BOSS_DEFAULT)
			end
		end,

		timeline =
		{
			FrameEvent(2, function(inst)
				inst.sg:RemoveStateTag("airborne")
				inst.sg.statemem.hitrange = 4.6
				inst.Physics:SetSize(4.2)
			end),
			FrameEvent(4, function(inst)
				inst.sg:RemoveStateTag("nointerrupt")
				inst.sg.statemem.hitrange = 5
				inst.Physics:SetSize(4.6)
				inst.components.offsethitboxes:Move("offsethitbox", 3.1)
				inst.components.offsethitboxes:SetEnabled("offsethitbox", true)
			end),
			FrameEvent(7, function(inst)
				inst.Physics:SetMotorVel(-10)
				inst.components.offsethitboxes:Move("offsethitbox", 4)
			end),
			FrameEvent(9, function(inst)
				inst.sg.statemem.hitrange = nil
				inst.Physics:SetMotorVel(-8)
			end),
			FrameEvent(10, function(inst) inst.Physics:SetMotorVel(-6) end),
			FrameEvent(11, function(inst) inst.Physics:SetMotorVel(-4) end),
			FrameEvent(12, function(inst) inst.Physics:SetMotorVel(-2) end),
			FrameEvent(13, function(inst) inst.Physics:SetMotorVel(-1) end),
			FrameEvent(14, function(inst) inst.Physics:SetMotorVel(-.5) end),
			FrameEvent(15, function(inst)
				inst.Physics:Stop()
				inst.components.offsethitboxes:Move("offsethitbox", 4.3)
			end),
		},

		events =
		{
			EventHandler("hitboxtriggered", OnChargeHitBoxTriggered),
			EventHandler("animover", function(inst)
				inst.sg.statemem.throwing = true
				inst.sg:GoToState("charge_flip_throw")
			end),
		},

		onexit = function(inst)
			if not inst.sg.statemem.throwing then
				inst.Physics:Stop()
				inst.Physics:SetSize(4.4)
			end
			inst.components.hitbox:StopRepeatTargetDelay()
			inst.components.offsethitboxes:SetEnabled("offsethitbox", false)
		end,
	}),

	State({
		name = "charge_flip_throw",
		tags = { "attack", "busy", "nointerrupt" },

		onenter = function(inst)
			inst.AnimState:PlayAnimation("charge_flip_throw")
			inst:SnapToFacingRotation()
			inst.Physics:SetSize(1370 / 300)
			--Don't offset back, just let him jump forward here
			--inst.Physics:MoveRelFacing(-120 / 150)
			inst.Physics:SetMotorVel(16)
			inst.components.combat:StartCooldown(3)
			inst.components.timer:StartTimer("charge_cd", 6, true)
			inst.components.hitbox:StartRepeatTargetDelay()
			inst.components.hitbox:PushBeam(.5, 6.4, 2, HitPriority.BOSS_DEFAULT)
		end,

		timeline =
		{
			FrameEvent(1, function(inst)
				inst.Physics:SetSize(1290 / 300)
				inst.Physics:MoveRelFacing(-40 / 150)
				inst.Physics:SetMotorVel(10)
				inst.components.hitbox:PushBeam(.5, 4.9, 2, HitPriority.BOSS_DEFAULT)
			end),
			FrameEvent(2, function(inst)
				inst.Physics:SetMotorVel(6)
				inst.components.hitbox:PushBeam(.5, 4.9, 2, HitPriority.BOSS_DEFAULT)
			end),
			FrameEvent(3, function(inst)
				inst.Physics:SetSize(1170 / 300)
				inst.Physics:MoveRelFacing(-60 / 150)
				inst.Physics:SetMotorVel(4)
			end),
			FrameEvent(4, function(inst) inst.Physics:SetMotorVel(2) end),
			FrameEvent(5, function(inst) inst.Physics:SetMotorVel(1) end),
			FrameEvent(6, function(inst) inst.Physics:SetMotorVel(.5) end),
			FrameEvent(7, function(inst) inst.Physics:Stop() end),
			FrameEvent(8, function(inst)
				inst.Physics:MoveRelFacing(10 / 150)
				inst.Physics:SetSize(1200 / 300)
			end),
			FrameEvent(11, function(inst)
				inst.Physics:MoveRelFacing(10 / 150)
				inst.Physics:SetSize(1235/ 300)
			end),
			FrameEvent(14, function(inst)
				inst.Physics:MoveRelFacing(10 / 150)
				inst.Physics:SetSize(1270 / 300)
			end),
			FrameEvent(16, function(inst)
				inst.sg:RemoveStateTag("nointerrupt")
				inst.Physics:MoveRelFacing(10 / 150)
				inst.Physics:SetSize(1300 / 300)
			end),
			FrameEvent(18, function(inst)
				inst.sg:RemoveStateTag("busy")
				inst.Physics:MoveRelFacing(10 / 150)
				inst.Physics:SetSize(4.4)
			end),
		},

		events =
		{
			EventHandler("hitboxtriggered", OnThrowHitBoxTriggered),
			EventHandler("animover", function(inst)
				inst.sg:GoToState("idle")
			end),
		},

		onexit = function(inst)
			inst.Physics:Stop()
			inst.Physics:SetSize(4.4)
			inst.components.hitbox:StopRepeatTargetDelay()
		end,
	}),

	State({
		name = "headbutt",
		tags = { "attack", "busy" },

		onenter = function(inst)
			inst.AnimState:PlayAnimation("headbutt")
		end,

		onupdate = function(inst)
			if inst.sg.statemem.speed ~= nil then
				if inst.sg.statemem.speed > 0 then
					inst.Physics:SetMotorVel(inst.sg.statemem.speed)
					if inst.sg.statemem.speed > 2 then
						inst.sg.statemem.speed = inst.sg.statemem.speed - inst.sg.statemem.decel
					elseif inst.sg.statemem.speed > 1 then
						inst.sg.statemem.speed = inst.sg.statemem.speed - 1
					elseif inst.sg.statemem.speed > .5 then
						inst.sg.statemem.speed = inst.sg.statemem.speed - .5
					else
						inst.sg.statemem.speed = 0
					end
				else
					inst.Physics:Stop()
					inst.sg.statemem.speed = nil
				end
			end
			if inst.sg.statemem.hitting then
				inst.components.hitbox:PushBeam(-.8, 5.4, 2, HitPriority.BOSS_DEFAULT)
			end
		end,

		timeline =
		{
			FrameEvent(3, function(inst)
				inst.Physics:SetSize(1260 / 300)
				inst.Physics:MoveRelFacing(-30 / 150)
			end),
			FrameEvent(7, function(inst) inst.Physics:SetMotorVel(11.2) end),
			FrameEvent(8, function(inst)
				inst.Physics:MoveRelFacing(30 / 150)
				inst.Physics:SetSize(1360 / 300)
			end),
			FrameEvent(9, function(inst)
				inst.sg:AddStateTag("nointerrupt")
				inst.Physics:SetMotorVel(40)
				inst.components.combat:StartCooldown(3)
			end),
			FrameEvent(10, function(inst)
				inst.sg:AddStateTag("airborne")
				inst.Physics:SetMotorVel(24)
				inst.components.hitbox:StartRepeatTargetDelay()
				inst.components.timer:StartTimer("headbutt_cd", 8, true)
				inst.sg.statemem.hitting = true
			end),
			FrameEvent(12, function(inst)
				inst.components.offsethitboxes:Move("offsethitbox", 3.4)
				inst.components.offsethitboxes:SetEnabled("offsethitbox", true)
				inst.sg.statemem.speed = 20
				inst.sg.statemem.decel = 1
			end),
			FrameEvent(16, function(inst)
				inst.Physics:SetSize(4.4)
			end),
			FrameEvent(20, function(inst)
				inst.sg:RemoveStateTag("airborne")
				inst.components.offsethitboxes:Move("offsethitbox", 3.6)
				inst.sg.statemem.hitting = false
				inst.sg.statemem.speed = 8
				inst.sg.statemem.decel = 2
			end),
			FrameEvent(22, function(inst)
				inst.sg:RemoveStateTag("nointerrupt")
			end),
			FrameEvent(26, function(inst)
				inst.components.offsethitboxes:Move("offsethitbox", 3)
			end),
			FrameEvent(29, function(inst)
				inst.sg:AddStateTag("caninterrupt")
				inst.components.offsethitboxes:SetEnabled("offsethitbox", false)
			end),
		},

		events =
		{
			EventHandler("hitboxtriggered", OnHeadbuttHitBoxTriggered),
			EventHandler("animover", function(inst)
				inst.sg:GoToState("idle")
			end),
		},

		onexit = function(inst)
			inst.Physics:Stop()
			inst.Physics:SetSize(4.4)
			inst.components.hitbox:StopRepeatTargetDelay()
			inst.components.offsethitboxes:SetEnabled("offsethitbox", false)
		end,
	}),

	State({
		name = "bite",
		tags = { "attack", "busy" },

		onenter = function(inst)
			inst.AnimState:PlayAnimation("bite")
		end,

		timeline =
		{
			FrameEvent(6, function(inst)
				inst.components.combat:StartCooldown(3)
			end),
			FrameEvent(9, function(inst)
				inst.components.offsethitboxes:Move("offsethitbox", 3.2)
				inst.components.offsethitboxes:SetEnabled("offsethitbox", true)
				inst.components.timer:StartTimer("bite_cd", 4, true)
			end),
			FrameEvent(11, function(inst)
				inst.sg:AddStateTag("vulnerable")
				inst.components.offsethitboxes:Move("offsethitbox", 5.3)
				inst.sg.statemem.bitetargets = {}
				inst.components.hitbox:StartRepeatTargetDelay()
				inst.components.hitbox:PushBeam(4.2, 7.5, 2, HitPriority.BOSS_DEFAULT)
			end),
			FrameEvent(12, function(inst)
				inst.components.hitbox:PushBeam(4.2, 7.5, 2, HitPriority.BOSS_DEFAULT)
			end),
			FrameEvent(13, function(inst)
				inst.components.hitbox:PushBeam(4.2, 7.5, 2, HitPriority.BOSS_DEFAULT)
			end),
		},

		events =
		{
			EventHandler("hitboxtriggered", OnBiteHitBoxTriggered),
			EventHandler("animover", function(inst)
				inst.sg.statemem.biting = true
				if not inst.components.timer:HasTimer("bite2_cd") then
					for i = 1, #AllPlayers do
						local target = AllPlayers[i]
						local trange = TargetRange(inst, target)
						if trange:IsInRotation(45) then
							if trange:TestBeam(4.4, 8.5, 2) then
								inst.sg:GoToState("bite2", inst.sg.statemem.bitetargets)
								return
							end
						end
					end
				end
				inst.sg:GoToState("bite_pst")
			end),
		},

		onexit = function(inst)
			inst.components.hitbox:StopRepeatTargetDelay()
			if not inst.sg.statemem.biting then
				inst.components.offsethitboxes:SetEnabled("offsethitbox", false)
			end
		end,
	}),

	State({
		name = "bite2",
		tags = { "attack", "busy", "vulnerable" },

		onenter = function(inst, targets)
			inst.AnimState:PlayAnimation("bite_second")
			inst.components.offsethitboxes:Move("offsethitbox", 4.9)
			inst.components.offsethitboxes:SetEnabled("offsethitbox", true)
			inst.sg.statemem.bitetargets = targets
		end,

		timeline =
		{
			FrameEvent(2, function(inst)
				inst.sg:RemoveStateTag("vulnerable")
				inst.Physics:MoveRelFacing(80 / 150)
				inst.Physics:SetSize(1480 / 300)
				inst.components.offsethitboxes:Move("offsethitbox", 3.5)
				inst.components.combat:StartCooldown(3)
				inst.components.timer:StartTimer("bite_cd", 4, true)
			end),
			FrameEvent(4, function(inst)
				inst.Physics:MoveRelFacing(80 / 150)
				inst.Physics:SetSize(1640 / 300)
				inst.components.offsethitboxes:Move("offsethitbox", 4)
			end),
			FrameEvent(6, function(inst)
				inst.components.offsethitboxes:Move("offsethitbox", 5.2)
			end),
			FrameEvent(7, function(inst)
				inst.components.timer:StartTimer("bite2_cd", 9, true)
			end),
			FrameEvent(9, function(inst)
				inst.sg:AddStateTag("vulnerable")
				inst.components.offsethitboxes:Move("offsethitbox", 6.6)
				inst.components.hitbox:StartRepeatTargetDelay()
				inst.components.hitbox:PushBeam(5.6, 8.9, 2, HitPriority.BOSS_DEFAULT)
			end),
			FrameEvent(10, function(inst)
				inst.components.hitbox:PushBeam(5.6, 8.9, 2, HitPriority.BOSS_DEFAULT)
			end),
			FrameEvent(11, function(inst)
				inst.components.offsethitboxes:Move("offsethitbox", 5.8)
			end),
			FrameEvent(14, function(inst)
				inst.components.offsethitboxes:Move("offsethitbox", 5.3)
			end),
			FrameEvent(16, function(inst)
				inst.sg:RemoveStateTag("vulnerable")
				inst.Physics:SetSize(1480 / 300)
				inst.Physics:MoveRelFacing(-80 / 150)
				inst.components.offsethitboxes:Move("offsethitbox", 4.6)
			end),
			FrameEvent(18, function(inst)
				inst.Physics:SetSize(4.4)
				inst.Physics:MoveRelFacing(-80 / 150)
				inst.components.offsethitboxes:Move("offsethitbox", 3.1)
			end),
			FrameEvent(20, function(inst)
				inst.components.offsethitboxes:SetEnabled("offsethitbox", false)
			end),
			FrameEvent(24, function(inst)
				inst.sg:RemoveStateTag("busy")
			end),
		},

		events =
		{
			EventHandler("hitboxtriggered", OnBite2HitBoxTriggered),
			EventHandler("animover", function(inst)
				inst.sg:GoToState("idle")
			end),
		},

		onexit = function(inst)
			inst.components.hitbox:StopRepeatTargetDelay()
			inst.components.offsethitboxes:SetEnabled("offsethitbox", false)
		end,
	}),

	State({
		name = "bite_pst",
		tags = { "attack", "busy" },

		onenter = function(inst)
			inst.AnimState:PlayAnimation("bite_pst")
			inst.components.offsethitboxes:Move("offsethitbox", 4)
			inst.components.offsethitboxes:SetEnabled("offsethitbox", true)
		end,

		timeline =
		{
			FrameEvent(2, function(inst)
				inst.components.offsethitboxes:Move("offsethitbox", 3.2)
			end),
			FrameEvent(4, function(inst)
				inst.components.offsethitboxes:SetEnabled("offsethitbox", false)
			end),
			FrameEvent(8, function(inst)
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
		end,
	}),
}

SGCommon.States.AddRunStates(states,
{
	onenterpre = function(inst) inst.Physics:SetMotorVel(8.5) end,
	onenterpst = function(inst)
		inst.components.offsethitboxes:Move("offsethitbox", 3.2)
		inst.components.offsethitboxes:SetEnabled("offsethitbox", true)
	end,
	psttimeline =
	{
		FrameEvent(2, function(inst)
			inst.components.offsethitboxes:Move("offsethitbox", 3.5)
		end),
		FrameEvent(5, function(inst)
			inst.components.offsethitboxes:Move("offsethitbox", 2.9)
		end),
		FrameEvent(7, function(inst)
			inst.components.offsethitboxes:SetEnabled("offsethitbox", false)
		end),
	},
	onexitpst = function(inst)
		inst.components.offsethitboxes:SetEnabled("offsethitbox", false)
	end,
})

return StateGraph("sg_bonejaw", states, events, "idle")
