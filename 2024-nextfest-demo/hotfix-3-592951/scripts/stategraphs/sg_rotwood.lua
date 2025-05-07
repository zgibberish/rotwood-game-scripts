local SGCommon = require "stategraphs.sg_common"
local TargetRange = require "targetrange"
local monsterutil = require "util.monsterutil"

local ATTACK_DAMAGE =
{
	DRILL = 20,
	SPIKE = 25,
}

local function OnDrillHitBoxTriggered(inst, data)
	local hitstoplevel = HitStopLevel.MEDIUM
	local hit = false
	local x, z = inst.Transform:GetWorldXZ()
	local facing = inst.Transform:GetFacing()

	for i = 1, #data.targets do
		local v = data.targets[i]
		if v.canownerhit or v.owner ~= inst then
			if v.sg and v.sg:HasStateTag("hit") then
				inst.components.combat:DoKnockdownAttack({
					target = v,
					damage_mod = ATTACK_DAMAGE.DRILL
				})
			else
				inst.components.combat:DoKnockbackAttack({
					target = v,
					damage_mod = ATTACK_DAMAGE.DRILL,
					speedmult = .75
				})
			end

			if v.components.hitstopper ~= nil then
				v.components.hitstopper:PushHitStop(hitstoplevel)
			end

			local x1, z1 = v.Transform:GetWorldXZ()
			local offset
			if facing == FACING_RIGHT then
				offset = x1 >= x and 4 or -4
			else
				offset = x1 <= x and 4 or -4
			end
			SpawnHitFx("fx_hit_player_horizontal", inst, v, offset, 0, nil, hitstoplevel)
			SpawnHurtFx(inst, v, offset, nil, hitstoplevel)

			hit = true
		end
	end

	if hit then
		inst.components.hitstopper:PushHitStop(hitstoplevel)
	end
end

local function OnSpikeHitBoxTriggered(inst, data)
	local hitstoplevel = inst.sg.statemem.heavyhit and HitStopLevel.HEAVY or HitStopLevel.MEDIUM
	local hit = false

	for i = 1, #data.targets do
		local v = data.targets[i]
		if v.canownerhit or v.owner ~= inst then
			inst.components.combat:DoKnockdownAttack({
				target = v,
				damage_mod = ATTACK_DAMAGE.SPIKE
			})

			if v.components.hitstopper ~= nil then
				v.components.hitstopper:PushHitStop(hitstoplevel)
			end

			SpawnHitFx("fx_hit_player_round", inst, v, 0, 0, nil, hitstoplevel)
			SpawnHurtFx(inst, v, 0, nil, hitstoplevel)

			hit = true
		end
	end

	if hit then
		inst.components.hitstopper:PushHitStop(hitstoplevel)
	end
end

local function ChooseAttack(inst, data)
	if data.target ~= nil and data.target:IsValid() then
		local trange = TargetRange(inst, data.target)
		if not inst.components.timer:HasTimer("block_cd") then
			if inst.sg:HasStateTag("hit") and trange:IsFacingTarget() then
				inst.sg:GoToState("block_pre")
				return true
			end
		end
		if not inst.components.timer:HasTimer("saplings_cd") then
			if trange:IsBetweenRange(8, 14) then
				if trange:IsInRange(12) then
					SGCommon.Fns.FaceActionTarget(inst, data, true)
				end
				inst.sg:GoToState("burrow_back_pre")
				return true
			end
		end
		if not inst.components.timer:HasTimer("drill_cd") then
			if trange:TestBeam(4, 7, 1.9) then
				SGCommon.Fns.FaceActionTarget(inst, data, true)
				inst.sg:GoToState("drill")
				return true
			end
		end
		if not inst.components.timer:HasTimer("spike_cd") then
			if trange:TestBeam(0, 6, 2.2) then
				SGCommon.Fns.FaceActionTarget(inst, data, true)
				inst.sg:GoToState("spike")
				return true
			end
		end
		if not inst.components.timer:HasTimer("rootwave_cd") then
			if trange:TestBeam(4, 12, 1) then
				SGCommon.Fns.FaceActionTarget(inst, data, true)
				inst.sg:GoToState("burrow_pre")
				return true
			end
		end
		if not inst.components.timer:HasTimer("fist_cd") then
			if trange:TestCone(60, 6, 12) then
				SGCommon.Fns.FaceActionTarget(inst, data, true)
				inst.sg:GoToState("burrow_front_pre", data.target)
				return true
			end
		end
		if not inst.components.timer:HasTimer("saplings_cd") then
			if trange:IsInRange(14) then
				if trange:IsInRange(12) then
					SGCommon.Fns.FaceActionTarget(inst, data, true)
				end
				inst.sg:GoToState("burrow_back_pre")
				return true
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
	chooseattack_fn = ChooseAttack,
	locomote_data = { walk = true },
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
			inst.Physics:SetMotorVel(-6)
		end,

		timeline =
		{
			FrameEvent(2, function(inst)
				inst.sg:AddStateTag("airborne")
			end),
			FrameEvent(4, function(inst)
				inst.sg:RemoveStateTag("airborne")
				inst.Physics:SetSize(3.9)
			end),
			FrameEvent(6, function(inst)
				inst.sg:RemoveStateTag("nointerrupt")
				inst.sg:AddStateTag("vulnerable")
				inst.Physics:SetMotorVel(-3)
			end),
			FrameEvent(8, function(inst)
				inst.Physics:SetMotorVel(-1.5)
				inst.Physics:SetSize(3.6)
			end),
			FrameEvent(11, function(inst)
				inst.sg:RemoveStateTag("vulnerable")
				inst.sg:AddStateTag("caninterrupt")
				inst.Physics:SetMotorVel(-1)
				inst.Physics:SetSize(3.4)
			end),
			FrameEvent(12, function(inst) inst.Physics:SetMotorVel(-.5) end),
			FrameEvent(13, function(inst)
				inst.sg:RemoveStateTag("busy")
				inst.Physics:Stop()
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
			inst.Physics:SetSize(3.4)
		end,
	}),

	State({
		name = "knockdown",
		tags = { "hit", "knockdown", "busy", "nointerrupt" },

		onenter = function(inst)
			inst.AnimState:PlayAnimation("knockdown")
			inst.Physics:SetMotorVel(-6)
			if not inst.components.timer:HasTimer("knockdown") then
				--Force permanent knockdown state when debugging
				inst.components.timer:StartTimerAnimFrames("knockdown", 1)
				inst.components.timer:PauseTimer("knockdown")
			end
			inst.sg.statemem.fx = SGCommon.Fns.SpawnAtDist(inst, "fx_rotwood_knockdown", 0)
			inst.components.bloomer:AttachChild(inst.sg.statemem.fx)
			inst.components.colormultiplier:AttachChild(inst.sg.statemem.fx)
			inst.components.coloradder:AttachChild(inst.sg.statemem.fx)
			inst.components.hitstopper:AttachChild(inst.sg.statemem.fx)
		end,

		timeline =
		{
			FrameEvent(2, function(inst)
				inst.sg:AddStateTag("airborne")
				inst.Physics:SetSize(3.1)
				inst.components.hitstopper:DetachChild(inst.sg.statemem.fx)
				inst.sg.statemem.fx = nil
			end),
			FrameEvent(9, function(inst)
				inst.sg:RemoveStateTag("airborne")
				inst.sg:RemoveStateTag("nointerrupt")
				inst.sg:AddStateTag("caninterrupt")
				inst.Physics:SetMotorVel(-3)
			end),
			FrameEvent(11, function(inst) inst.Physics:SetMotorVel(-1.5) end),
			FrameEvent(12, function(inst) inst.Physics:SetMotorVel(-.75) end),
			FrameEvent(13, function(inst) inst.Physics:SetMotorVel(-.375) end),
			FrameEvent(14, function(inst) inst.Physics:Stop() end),
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
				inst.Physics:SetSize(3.4)
				inst.components.timer:StopTimer("knockdown")
			end
			if inst.sg.statemem.fx ~= nil then
				inst.components.hitstopper:DetachChild(inst.sg.statemem.fx)
			end
		end,
	}),

	State({
		name = "knockdown_idle",
		tags = { "knockdown", "busy", "caninterrupt" },

		onenter = function(inst)
			inst.AnimState:PlayAnimation("knockdown_idle", true)
			inst.Physics:SetSize(3.1)
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
				inst.Physics:SetSize(3.4)
				inst.components.timer:StopTimer("knockdown")
			end
		end,
	}),

	State({
		name = "knockdown_hit_front",
		tags = { "hit", "knockdown", "busy" },

		onenter = function(inst, getup)
			inst.AnimState:PlayAnimation("knockdown_hit_head")
			inst.Physics:SetSize(3.1)
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
				inst.Physics:SetSize(3.4)
				inst.components.timer:StopTimer("knockdown")
			end
		end,
	}),

	State({
		name = "knockdown_hit_back",
		tags = { "hit", "knockdown", "busy" },

		onenter = function(inst, getup)
			inst.AnimState:PlayAnimation("knockdown_hit_back")
			inst.Physics:SetSize(3.1)
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
				inst.Physics:SetSize(3.4)
				inst.components.timer:StopTimer("knockdown")
			end
		end,
	}),

	State({
		name = "knockdown_getup",
		tags = { "getup", "knockdown", "busy", "nointerrupt" },

		onenter = function(inst)
			inst.AnimState:PlayAnimation("knockdown_getup")
			inst.Physics:SetSize(3.1)
			inst.components.timer:StopTimer("knockdown")
		end,

		timeline =
		{
			FrameEvent(7, function(inst)
				inst.sg:RemoveStateTag("knockdown")
				inst.sg:AddStateTag("nointerrupt")
			end),
			FrameEvent(9, function(inst) inst.Physics:SetSize(3.2) end),
			FrameEvent(18, function(inst)
				inst.sg:RemoveStateTag("nointerrupt")
			end),
			FrameEvent(23, function(inst)
				inst.sg:AddStateTag("caninterrupt")
				inst.Physics:SetSize(3.4)
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
				inst.Physics:SetSize(3.4)
			end
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
		name = "drill",
		tags = { "attack", "busy" },

		onenter = function(inst)
			inst.AnimState:PlayAnimation("drill")
		end,

		onupdate = function(inst)
			if inst.sg.statemem.hitting then
				inst.components.hitbox:PushBeam(4, 8.2, 1.9, HitPriority.BOSS_DEFAULT)
				inst.components.hitbox:PushBeam(-4, -8.2, 1.9, HitPriority.BOSS_DEFAULT)
			end
		end,

		timeline =
		{
			FrameEvent(8, function(inst) inst.HitBox:SetNonPhysicsRect(4) end),
			FrameEvent(10, function(inst)
				inst.HitBox:SetNonPhysicsRect(5)
				inst.components.timer:StartTimer("drill_cd", 4, true)
			end),
			FrameEvent(13, function(inst)
				inst.sg:AddStateTag("nointerrupt")
				inst.components.combat:StartCooldown(3)
				inst.HitBox:SetNonPhysicsRect(7.2)
				inst.Physics:SetSize(4)
				inst.components.hitbox:StartRepeatTargetDelayAnimFrames(8)
				inst.sg.statemem.hitting = true
			end),
			FrameEvent(23, function(inst)
				inst.sg:RemoveStateTag("nointerrupt")
				inst.HitBox:SetNonPhysicsRect(7)
				inst.sg.statemem.hitting = false
			end),
			FrameEvent(25, function(inst) inst.HitBox:SetNonPhysicsRect(5.2) end),
			FrameEvent(27, function(inst) inst.HitBox:SetNonPhysicsRect(4.7) end),
			FrameEvent(29, function(inst) inst.HitBox:UsePhysicsShape() end),
			FrameEvent(31, function(inst) inst.Physics:SetSize(3.4) end),
			FrameEvent(33, function(inst)
				inst.sg:RemoveStateTag("busy")
			end),
		},

		events =
		{
			EventHandler("hitboxtriggered", OnDrillHitBoxTriggered),
			EventHandler("animover", function(inst)
				inst.sg:GoToState("idle")
			end),
		},

		onexit = function(inst)
			inst.HitBox:UsePhysicsShape()
			inst.Physics:SetSize(3.4)
			inst.components.hitbox:StopRepeatTargetDelay()
		end,
	}),

	State({
		name = "spike",
		tags = { "attack", "busy" },

		onenter = function(inst)
			inst.AnimState:PlayAnimation("close_spike")
		end,

		onupdate = function(inst)
			if inst.sg.statemem.hitsize ~= nil then
				inst.components.hitbox:PushBeam(-inst.sg.statemem.hitsize, inst.sg.statemem.hitsize, 2.2, HitPriority.BOSS_DEFAULT)
			end
		end,

		timeline =
		{
			FrameEvent(2, function(inst) inst.Physics:SetSize(2.8) end),
			FrameEvent(12, function(inst)
				inst.Physics:SetSize(3.1)
				inst.components.timer:StartTimer("spike_cd", 7, true)
				SGCommon.Fns.SpawnAtDist(inst, "fx_rotwood_debris_spike", 0)
			end),
			FrameEvent(13, function(inst)
				inst.sg:AddStateTag("nointerrupt")
				inst.components.combat:StartCooldown(3)
				inst.HitBox:SetNonPhysicsRect(5.1)
				inst.Physics:SetSize(3.5)
				inst.components.hitbox:StartRepeatTargetDelay()
				inst.sg.statemem.hitsize = 7.3
				inst.sg.statemem.heavyhit = true
			end),
			FrameEvent(15, function(inst)
				inst.sg.statemem.hitsize = 6.7
			end),
			FrameEvent(17, function(inst)
				inst.sg.statemem.hitsize = 6.2
				inst.sg.statemem.heavyhit = nil
			end),
			FrameEvent(19, function(inst)
				inst.sg.statemem.hitsize = 6
			end),
			FrameEvent(24, function(inst)
				inst.sg.statemem.hitsize = 5.9
			end),
			FrameEvent(26, function(inst)
				inst.sg.statemem.hitsize = nil
				inst.HitBox:SetNonPhysicsRect(4.5)
			end),
			FrameEvent(28, function(inst) inst.HitBox:SetNonPhysicsRect(3.9) end),
			FrameEvent(30, function(inst)
				inst.sg:RemoveStateTag("nointerrupt")
				inst.HitBox:UsePhysicsShape()
				inst.Physics:SetSize(3.3)
			end),
			FrameEvent(32, function(inst)
				inst.Physics:SetSize(3.1)
				SGCommon.Fns.SpawnAtDist(inst, "fx_rotwood_debris_pullout", 2.3)
				SGCommon.Fns.SpawnAtDist(inst, "fx_rotwood_debris_pullout", -2.15, true)
			end),
			FrameEvent(39, function(inst) inst.Physics:SetSize(3.2) end),
			FrameEvent(41, function(inst) inst.Physics:SetSize(3.4) end),
			FrameEvent(44, function(inst)
				inst.sg:RemoveStateTag("busy")
			end),
		},

		events =
		{
			EventHandler("hitboxtriggered", OnSpikeHitBoxTriggered),
			EventHandler("animover", function(inst)
				inst.sg:GoToState("idle")
			end),
		},

		onexit = function(inst)
			inst.HitBox:UsePhysicsShape()
			inst.Physics:SetSize(3.4)
			inst.components.hitbox:StopRepeatTargetDelay()
		end,
	}),

	State({
		name = "burrow_pre",
		tags = { "attack", "busy" },

		onenter = function(inst)
			inst.AnimState:PlayAnimation("burrow_pre")
		end,

		timeline =
		{
			FrameEvent(12, function(inst)
				SGCommon.Fns.SpawnAtDist(inst, "fx_rotwood_debris_burrow", 2.8)
				SGCommon.Fns.SpawnAtDist(inst, "fx_rotwood_debris_burrow", -2.8, true)
				inst.components.timer:StartTimer("rootwave_cd", 10, true)
			end),
			FrameEvent(16, function(inst)
				inst.sg.statemem.targets = {}
				inst.sg.statemem.growth = SGCommon.Fns.SpawnAtDist(inst, "rotwood_growth_root", 4.9)
				inst.sg.statemem.growth:Setup(inst, inst.sg.statemem.targets)
			end),
		},

		events =
		{
			EventHandler("animover", function(inst)
				local targets = inst.sg.statemem.targets
				inst.sg:GoToState("burrow_loop", inst.sg.statemem.growth:IsValid() and inst.sg.statemem.growth or nil)
				if inst.sg:GetCurrentState() == "burrow_loop" then
					--transfer target tracking to next state
					inst.sg.statemem.targets = targets
				end
			end),
		},
	}),

	State({
		name = "burrow_loop",
		tags = { "attack", "busy" },

		onenter = function(inst, growth)
			inst.AnimState:PlayAnimation("burrow_loop", true)
			inst.sg.statemem.growth = growth
			inst.sg.statemem.delay = 6
			inst.sg.statemem.step = 0

			--inst.sg.statemem.targets is transferred from burrow_pre
		end,

		onupdate = function(inst)
			if inst.sg.statemem.step < 7 then
				if inst.sg.statemem.delay > 0 then
					inst.sg.statemem.delay = inst.sg.statemem.delay - 1
				else
					inst.sg.statemem.delay = 5
					inst.sg.statemem.step = inst.sg.statemem.step + 1
					inst.sg.statemem.growth = SGCommon.Fns.SpawnAtDist(inst, "rotwood_growth_root", 4.9 + inst.sg.statemem.step * 1.7)
					inst.sg.statemem.growth:Setup(inst, inst.sg.statemem.targets)
				end
			end
		end,

		events =
		{
			EventHandler("animover", function(inst)
				if not (inst.sg.statemem.growth:IsValid() and inst.sg.statemem.growth.sg:HasStateTag("linked")) then
					inst.sg.statemem.growth = nil
					inst.sg:GoToState("burrow_pst")
				elseif not inst.AnimState:IsCurrentAnimation("burrow_loop") then
					inst.AnimState:PlayAnimation("burrow_loop", true)
				end
			end),
		},

		onexit = function(inst)
			if inst.sg.statemem.growth ~= nil then
				inst:PushEvent("rotwood_growth_interrupted")
			end
		end,
	}),

	State({
		name = "burrow_pst",
		tags = { "attack", "busy" },

		onenter = function(inst)
			inst.AnimState:PlayAnimation("burrow_pst")
		end,

		timeline =
		{
			FrameEvent(11, function(inst)
				SGCommon.Fns.SpawnAtDist(inst, "fx_rotwood_debris_pullout", 2.8)
				SGCommon.Fns.SpawnAtDist(inst, "fx_rotwood_debris_pullout", -2.8, true)
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
		name = "burrow_back_pre",
		tags = { "attack", "busy" },

		onenter = function(inst)
			inst.AnimState:PlayAnimation("burrow1_pre")
		end,

		timeline =
		{
			FrameEvent(12, function(inst)
				SGCommon.Fns.SpawnAtDist(inst, "fx_rotwood_debris_burrow", -2.8, true)
			end),
		},

		events =
		{
			EventHandler("animover", function(inst)
				inst.sg:GoToState("burrow_back_loop")
			end),
		},
	}),

	State({
		name = "burrow_back_loop",
		tags = { "attack", "busy" },

		onenter = function(inst)
			inst.AnimState:PlayAnimation("burrow1_loop", true)
			inst.sg.statemem.delay = 0
			local count = math.random(6, 7)
			local theta = math.random() * 2 * math.pi
			local dtheta = 2 * math.pi / count
			local thetavar = dtheta / 3
			local x, z = inst.Transform:GetWorldXZ()
			inst.sg.statemem.spawnpts = {}
			for i = 1, count do
				local angle = theta + math.random() * thetavar
				local dist = 6 + math.random()
				inst.sg.statemem.spawnpts[#inst.sg.statemem.spawnpts + 1] = Vector3(x + dist * math.cos(angle), 0, z - dist * math.sin(angle))
				theta = theta + dtheta
			end
			theta = theta + dtheta * .5
			for i = 1, count do
				local angle = theta + math.random() * thetavar
				local dist = 8 + math.random() * 2
				inst.sg.statemem.spawnpts[#inst.sg.statemem.spawnpts + 1] = Vector3(x + dist * math.cos(angle), 0, z - dist * math.sin(angle))
				theta = theta + dtheta
			end
			inst.components.timer:StartTimer("saplings_cd", 25, true)
		end,

		onupdate = function(inst)
			local num = #inst.sg.statemem.spawnpts
			if num > 0 then
				if inst.sg.statemem.delay > 0 then
					inst.sg.statemem.delay = inst.sg.statemem.delay - 1
				else
					inst.sg.statemem.delay = math.random(4, 6)

					local i = math.random(num)
					local pt = inst.sg.statemem.spawnpts[i]
					inst.sg.statemem.spawnpts[i] = inst.sg.statemem.spawnpts[num]
					inst.sg.statemem.spawnpts[num] = nil

					local sapling = SpawnPrefab("rotwood_growth_sapling", inst)
					sapling.Transform:SetPosition(pt:Get())
					local target = inst.components.combat:GetTarget()
					if target then
						sapling:Face(target)
					end
					sapling:Setup(inst)
				end
			end
		end,

		events =
		{
			EventHandler("animover", function(inst)
				if #inst.sg.statemem.spawnpts <= 0 then
					inst.sg:GoToState("burrow_back_pst")
				end
			end),
		},
	}),

	State({
		name = "burrow_back_pst",
		tags = { "attack", "busy" },

		onenter = function(inst)
			inst.AnimState:PlayAnimation("burrow1_pst")
		end,

		timeline =
		{
			FrameEvent(11, function(inst)
				SGCommon.Fns.SpawnAtDist(inst, "fx_rotwood_debris_pullout", -2.8, true)
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
		name = "burrow_front_pre",
		tags = { "attack", "busy" },

		onenter = function(inst, target)
			inst.AnimState:PlayAnimation("burrow2_pre")
			inst.sg.statemem.target = target
		end,

		timeline =
		{
			FrameEvent(12, function(inst)
				SGCommon.Fns.SpawnAtDist(inst, "fx_rotwood_debris_burrow", 2.8)
				inst.components.timer:StartTimer("fist_cd", 5, true)
			end),
		},

		events =
		{
			EventHandler("animover", function(inst)
				inst.sg:GoToState("burrow_front_loop", inst.sg.statemem.target)
			end),
		},
	}),

	State({
		name = "burrow_front_loop",
		tags = { "attack", "busy" },

		onenter = function(inst, target)
			inst.AnimState:PlayAnimation("burrow2_loop", true)
			inst.components.combat:StartCooldown(3)

			local x, z = inst.Transform:GetWorldXZ()
			local facingrot = inst.Transform:GetFacingRotation()
			local angle = facingrot
			local dist = 6
			if target ~= nil and target:IsValid() then
				local x1, z1 = target.Transform:GetWorldXZ()
				if x ~= x1 or z ~= z1 then
					local dx = x1 - x
					local dz = z1 - z
					local rot = math.deg(math.atan(-dz, dx))
					local drot = ReduceAngle(rot - facingrot)
					if drot > -180 and drot < 180 then
						angle = facingrot + math.clamp(drot, -60, 60)
						dist = math.clamp(math.sqrt(dx * dx + dz * dz), 6, 13)
						drot = math.abs(drot)
						if drot > 90 then
							local k = (180 - drot) / 90
							k = k * k
							dist = k * dist + (1 - k) * 6
						end
						if drot > 135 then
							local k = 1 - (180 - drot) / 45
							k = k * k
							angle = (1 - k) * angle + k * facingrot
						end
					end
				end
			end
			angle = math.rad(angle)
			inst.sg.statemem.growth = SpawnPrefab("rotwood_growth_punch", inst)
			inst.sg.statemem.growth.Transform:SetPosition(x + dist * math.cos(angle), 0, z - dist * math.sin(angle))
			inst.sg.statemem.growth.Transform:SetRotation(facingrot)
			inst.sg.statemem.growth:Setup(inst)
		end,

		events =
		{
			EventHandler("animover", function(inst)
				if not (inst.sg.statemem.growth:IsValid() and inst.sg.statemem.growth.sg:HasStateTag("linked")) then
					inst.sg.statemem.growth = nil
					inst.sg:GoToState("burrow_front_pst")
				end
			end),
		},

		onexit = function(inst)
			if inst.sg.statemem.growth ~= nil then
				inst:PushEvent("rotwood_growth_interrupted")
			end
		end,
	}),

	State({
		name = "burrow_front_pst",
		tags = { "attack", "busy" },

		onenter = function(inst)
			inst.AnimState:PlayAnimation("burrow2_pst")
		end,

		timeline =
		{
			FrameEvent(11, function(inst)
				SGCommon.Fns.SpawnAtDist(inst, "fx_rotwood_debris_pullout", 2.8)
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
		name = "block_pre",
		tags = { "busy" },

		onenter = function(inst)
			inst.AnimState:PlayAnimation("block_pre")
			inst.components.timer:StartTimer("block_min_time", 2, true)
			inst.components.timer:StartTimer("block_max_time", math.random(5, 6), true)
		end,

		timeline =
		{
			FrameEvent(2, function(inst) inst.Physics:SetSize(2.8) end),
			FrameEvent(6, function(inst)
				inst.sg:AddStateTag("block")
			end),
			FrameEvent(7, function(inst)
				inst.sg:AddStateTag("caninterrupt")
			end),
		},

		events =
		{
			EventHandler("animover", function(inst)
				inst.sg.statemem.blocking = true
				inst.sg:GoToState("block_loop")
			end),
		},

		onexit = function(inst)
			if not inst.sg.statemem.blocking then
				inst.Physics:SetSize(3.4)
			else
				inst.components.timer:StartTimer("block_cd", 20, true)
			end
		end,
	}),

	State({
		name = "block_loop",
		tags = { "block", "busy", "caninterrupt" },

		onenter = function(inst)
			inst.AnimState:PlayAnimation("block_loop", true)
			inst.Physics:SetSize(2.8)
		end,

		events =
		{
			EventHandler("animover", function(inst)
				if not inst.components.timer:HasTimer("block_max_time") then
					inst.sg.statemem.blocking = true
					inst.sg:GoToState("block_pst")
				end
			end),
		},

		onexit = function(inst)
			if not inst.sg.statemem.blocking then
				inst.Physics:SetSize(3.4)
			end
		end,
	}),

	State({
		name = "block_hit_front",
		tags = { "hit", "block", "busy" },

		onenter = function(inst, unblock)
			inst.AnimState:PlayAnimation("block_hit")
			inst.Physics:SetSize(2.8)
			inst.sg.statemem.unblock = unblock
		end,

		timeline =
		{
			FrameEvent(5, function(inst)
				if inst.sg.statemem.unblock then
					inst.sg.statemem.blocking = true
					inst.sg:GoToState("block_pst")
				elseif inst.components.timer:HasTimer("block_max_time") then
					inst.sg:AddStateTag("caninterrupt")
				end
			end),
		},

		events =
		{
			EventHandler("animover", function(inst)
				inst.sg.statemem.blocking = true
				if inst.components.timer:HasTimer("block_max_time") then
					inst.sg:GoToState("block_loop")
				else
					inst.sg:GoToState("block_pst")
				end
			end),
		},

		onexit = function(inst)
			if not inst.sg.statemem.blocking then
				inst.Physics:SetSize(3.4)
			end
		end,
	}),

	State({
		name = "block_hit_back",
		tags = { "hit", "block", "busy" },

		onenter = function(inst, unblock)
			inst.AnimState:PlayAnimation("block_hit_back")
			inst.Physics:SetSize(2.8)
			inst.sg.statemem.unblock = unblock
		end,

		timeline =
		{
			FrameEvent(6, function(inst)
				if inst.sg.statemem.unblock then
					inst.sg.statemem.blocking = true
					inst.sg:GoToState("block_pst")
				elseif inst.components.timer:HasTimer("block_min_time") then
					inst.sg:AddStateTag("caninterrupt")
				end
			end),
		},

		events =
		{
			EventHandler("animover", function(inst)
				inst.sg.statemem.blocking = true
				if inst.components.timer:HasTimer("block_min_time") then
					inst.sg:GoToState("block_loop")
				else
					inst.sg:GoToState("block_pst")
				end
			end),
		},

		onexit = function(inst)
			if not inst.sg.statemem.blocking then
				inst.Physics:SetSize(3.4)
			end
		end,
	}),

	State({
		name = "block_knockback",
		tags = { "hit", "knockback", "busy", "nointerrupt" },

		onenter = function(inst)
			inst.AnimState:PlayAnimation("block_flinch")
			inst.Physics:SetMotorVel(-6)
			inst.Physics:SetSize(2.8)
		end,

		timeline =
		{
			FrameEvent(2, function(inst)
				inst.sg:AddStateTag("airborne")
			end),
			FrameEvent(4, function(inst)
				inst.sg:RemoveStateTag("airborne")
				inst.Physics:SetSize(3.9)
			end),
			FrameEvent(6, function(inst)
				inst.sg:RemoveStateTag("nointerrupt")
				inst.sg:AddStateTag("vulnerable")
				inst.Physics:SetMotorVel(-3)
			end),
			FrameEvent(8, function(inst)
				inst.Physics:SetMotorVel(-1.5)
				inst.Physics:SetSize(3.6)
			end),
			FrameEvent(11, function(inst)
				inst.sg:RemoveStateTag("vulnerable")
				inst.sg:AddStateTag("caninterrupt")
				inst.Physics:SetMotorVel(-1)
				inst.Physics:SetSize(3.4)
			end),
			FrameEvent(12, function(inst) inst.Physics:SetMotorVel(-.5) end),
			FrameEvent(13, function(inst)
				inst.sg:RemoveStateTag("busy")
				inst.Physics:Stop()
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
			inst.Physics:SetSize(3.4)
		end,
	}),

	State({
		name = "block_pst",
		tags = { "unblock", "block", "busy" },

		onenter = function(inst)
			inst.AnimState:PlayAnimation("block_pst")
			inst.Physics:SetSize(2.8)
		end,

		timeline =
		{
			FrameEvent(4, function(inst)
				inst.sg:RemoveStateTag("block")
			end),
			FrameEvent(13, function(inst) inst.Physics:SetSize(3.4) end),
			FrameEvent(15, function(inst)
				inst.sg:AddStateTag("caninterrupt")
			end),
			FrameEvent(19, function(inst)
				inst.sg:RemoveStateTag("busy")
			end),
		},

		events =
		{
			EventHandler("animover", function(inst)
				inst.sg:GoToState("idle")
			end),
		},

		onexit = function(inst) inst.Physics:SetSize(3.4) end,
	}),
}

SGCommon.States.AddWalkStates(states,
{
	onenterpre = function(inst) inst.Physics:SetSize(3.2) end,
	pretimeline =
	{
		FrameEvent(1, function(inst) inst.Physics:SetSize(3.1) end),
		FrameEvent(3, function(inst) inst.Physics:SetSize(2.8) end),
		FrameEvent(5, function(inst) inst.Physics:SetSize(2.5) end),
		FrameEvent(8, function(inst) inst.Physics:SetSize(2.2) end),
		FrameEvent(10, function(inst) inst.Physics:SetSize(2) end),
	},
	onexitpre = function(inst)
		if not inst.sg.statemem.moving then
			inst.Physics:SetSize(3.4)
		end
	end,

	onenterloop = function(inst) inst.Physics:SetSize(2) end,
	looptimeline =
	{
		FrameEvent(10, function(inst) inst.Physics:SetSize(2.7) end),
		FrameEvent(12, function(inst) inst.Physics:SetSize(3) end),
		FrameEvent(15, function(inst) inst.Physics:SetSize(3.5) end),
		FrameEvent(21, function(inst) inst.Physics:SetSize(3.1) end),
		FrameEvent(24, function(inst) inst.Physics:SetSize(2.7) end),
		FrameEvent(27, function(inst) inst.Physics:SetSize(2.3) end),
		FrameEvent(29, function(inst) inst.Physics:SetSize(2) end),
	},
	onexitloop = function(inst)
		if not inst.sg.statemem.moving then
			inst.Physics:SetSize(3.4)
		end
	end,
})

return StateGraph("sg_rotwood", states, events, "idle")
