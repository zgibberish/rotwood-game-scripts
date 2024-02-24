local EffectEvents = require "effectevents"
local SGCommon = require "stategraphs.sg_common"
local TargetRange = require "targetrange"
local krandom = require "util.krandom"
local monsterutil = require "util.monsterutil"


local function OnPierceHitBoxTriggered(inst, data)
	SGCommon.Events.OnHitboxTriggered(inst, data, {
		attackdata_id = "pierce",
		hitstoplevel = inst.sg.statemem.hit_light and HitStopLevel.LIGHT or HitStopLevel.MEDIUM,
		pushback = 0.4,
		hitflags = Attack.HitFlags.LOW_ATTACK,
		combat_attack_fn = "DoKnockbackAttack",
		hit_fx = monsterutil.defaultAttackHitFX,
		hit_fx_offset_x = 0.5,
	})
end

local function SlowDownBeforeStop(inst)
	local velocity = inst.Physics:GetMotorVel()
	SGCommon.Fns.SetMotorVelScaled(inst, (velocity * 0.25))
end

local function OnDashHitBoxTriggered(inst, data)
	SGCommon.Events.OnHitboxTriggered(inst, data, {
		attackdata_id = "dash",
		hitstoplevel = HitStopLevel.MAJOR,
		hitflags = Attack.HitFlags.LOW_ATTACK,
		custom_attack_fn = function(attacker, attack)
			local hit = attacker.components.combat:DoKnockdownAttack(attack)
			if hit then
				attacker.sg.statemem.connected = true
			end
			return hit
		end,
		hit_fx = monsterutil.defaultAttackHitFX,
	})

	if inst.sg.statemem.connected then
		inst.sg.statemem.fire_projectiles = true

		-- This slowdown when you hit feels weird when it doesn't result in stopping.
		--~ SlowDownBeforeStop(inst)
		if inst.sg:GetCurrentState() == "dash_loop"
			and inst.sg:GetTicksInState() % inst.AnimState:GetCurrentAnimationNumFrames() < inst.AnimState:GetCurrentAnimationNumFrames() * 0.5
		then
			-- we just started the anim, stop rolling sooner and pop into the _pst
			--~ inst.sg:GoToState("tired")
		end
		--~ inst.sg.statemem.roll_finished = true
	end
end

local function ChooseAttack(inst, data)
	if data.target ~= nil and data.target:IsValid() then
		local attacktracker = inst.components.attacktracker
		local trange = TargetRange(inst, data.target)
		local next_attack = attacktracker:PickNextAttack(data, trange)

		if next_attack == "dash" then
			local target_pos = data.target:GetPosition()
			local pos = inst:GetPosition()
			local dir, dist = (target_pos - pos):normalized()
			local dash_len = dist > 10 and inst.tuning.dash.max_dash_distance or inst.tuning.dash.min_dash_distance
			local dest = TheWorld.Map:FindClosestWalkablePoint(pos + dir * dash_len)
			local nextdata = {
				dash_midpoint = dest:lerp(pos, 0.5),
				dash_dest = dest,
			}
			local state_name = attacktracker:GetStateNameForAttack(next_attack)
			SGCommon.Fns.TurnAndActOnLocation(inst, target_pos.x, target_pos.z, false, state_name, nextdata)
			return true
		end

		if next_attack == "pierce" then
			local state_name = attacktracker:GetStateNameForAttack(next_attack)
			SGCommon.Fns.TurnAndActOnTarget(inst, data, true, state_name)
			return true
		end

		if next_attack == "elite_shoot" then
			local state_name = attacktracker:GetStateNameForAttack(next_attack)
			SGCommon.Fns.TurnAndActOnTarget(inst, data, true, state_name)
			return true
		end
	end
	return false
end

local function ChooseIdleBehavior(inst)
	if not inst.components.timer:HasTimer("idlebehavior_cd") then
		if not inst.components.timer:HasTimer("sneeze_cd") then
			inst.sg:GoToState("sneeze")
			return true
		end
	end
	return false
end

local function OnDeath(inst, data)
	--Spawn death fx
	EffectEvents.MakeEventFXDeath(inst, data.attack, "fx_death_blarmadillo")
	--Spawn loot (lootdropper will attach hitstopper)
	inst.components.lootdropper:DropLoot()
end

local function CreateDirtAt(dirtparams, anim, dist)
	local inst = CreateEntity()

	inst.entity:AddTransform()
	inst.entity:AddAnimState()

	inst:AddTag("FX")
	inst:AddTag("NOCLICK")
	inst.persists = false

	inst.Transform:SetTwoFaced()

	inst.AnimState:SetBank("blarmadillo_dirt")
	inst.AnimState:SetBuild("blarmadillo_dirt")
	inst.AnimState:PlayAnimation(anim)
	inst.AnimState:SetShadowEnabled(true)
	inst.AnimState:SetFinalOffset(1)

	inst:ListenForEvent("animover", inst.Remove)

	local theta = math.rad(dirtparams.rot)
	inst.Transform:SetPosition(dirtparams.x + dist * math.cos(theta), 0, dirtparams.z - dist * math.sin(theta))
	inst.Transform:SetRotation(dirtparams.rot)

	return inst
end

local function StartDash(inst, target)
	if inst.sg:HasStateTag("busy")
		or inst.components.timer:HasTimer("dash_cd")
	then
		return false
	end

	SGCommon.Fns.TurnAndActOnTarget(inst, target, true, "dash_tell")
	return true
end

local events =
{
	EventHandler("start_dash", StartDash),
}
monsterutil.AddMonsterCommonEvents(events,
{
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
		name = "knockdown_getup",
		tags = { "getup", "knockdown", "busy", "nointerrupt" },

		onenter = function(inst)
			inst.AnimState:PlayAnimation("knockdown_getup")
		end,

		timeline =
		{
			--physics
			FrameEvent(0, function(inst) inst:SnapToFacingRotation() end),
			FrameEvent(0, function(inst) inst.Physics:MoveRelFacing(-3 / 150) end),
			FrameEvent(0, function(inst) inst.Physics:SetSize(1.45) end),
			FrameEvent(2, function(inst) inst.Physics:MoveRelFacing(-5 / 150) end),
			FrameEvent(4, function(inst) inst.Physics:MoveRelFacing(-6 / 150) end),
			FrameEvent(6, function(inst) inst.Physics:MoveRelFacing(-6 / 150) end),
			FrameEvent(8, function(inst) inst.Physics:MoveRelFacing(-3 / 150) end),
			FrameEvent(9, function(inst) SGCommon.Fns.SetMotorVelScaled(inst, .8) end),
			FrameEvent(12, function(inst) SGCommon.Fns.SetMotorVelScaled(inst, 3.2) end),
			FrameEvent(14, function(inst) inst.Physics:SetSize(1.3) end),
			FrameEvent(16, function(inst) inst.Physics:SetSize(1.1) end),
			FrameEvent(16, function(inst) SGCommon.Fns.SetMotorVelScaled(inst, 1.6) end),
			FrameEvent(18, function(inst) SGCommon.Fns.SetMotorVelScaled(inst, .8) end),
			FrameEvent(20, function(inst) SGCommon.Fns.SetMotorVelScaled(inst, .4) end),
			FrameEvent(22, function(inst) SGCommon.Fns.SetMotorVelScaled(inst, .2) end),
			FrameEvent(24, function(inst) inst.Physics:Stop() end),
			FrameEvent(25, function(inst) SGCommon.Fns.SetMotorVelScaled(inst, -1.6) end),
			FrameEvent(26, function(inst) SGCommon.Fns.SetMotorVelScaled(inst, -2.4) end),
			FrameEvent(28, function(inst) SGCommon.Fns.SetMotorVelScaled(inst, -4.8) end),
			FrameEvent(32, function(inst) SGCommon.Fns.SetMotorVelScaled(inst, -6.4) end),
			FrameEvent(36, function(inst) SGCommon.Fns.SetMotorVelScaled(inst, -8) end),
			FrameEvent(40, function(inst) SGCommon.Fns.SetMotorVelScaled(inst, -5) end),
			FrameEvent(42, function(inst) SGCommon.Fns.SetMotorVelScaled(inst, -3.333) end),
			FrameEvent(44, function(inst) SGCommon.Fns.SetMotorVelScaled(inst, -2.4) end),
			FrameEvent(47, function(inst) inst.Physics:Stop() end),
			FrameEvent(49, function(inst) inst.Physics:MoveRelFacing(-16 / 150) end),
			FrameEvent(51, function(inst) inst.Physics:MoveRelFacing(-8 / 150) end),
			--

			FrameEvent(35, function(inst)
				inst.sg:AddStateTag("nointerrupt")
			end),
			FrameEvent(36, function(inst)
				inst.sg:RemoveStateTag("knockdown")
			end),
			FrameEvent(41, function(inst)
				inst.sg:RemoveStateTag("nointerrupt")
			end),
			FrameEvent(45, function(inst)
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
			inst.Physics:Stop()
			if not inst.sg.statemem.knockdown then
				inst.Physics:SetSize(1.1)
			end
		end,
	}),

	State({
		name = "sneeze",
		tags = { "busy", "caninterrupt" },

		onenter = function(inst)
			inst.AnimState:PlayAnimation("behavior1")
			inst.components.timer:StartTimer("sneeze_cd", 15 + math.random() * 5, true)
		end,

		timeline =
		{
			--physics
			FrameEvent(4, function(inst) inst.Physics:MoveRelFacing(16 / 150) end),
			FrameEvent(6, function(inst) inst.Physics:MoveRelFacing(12 / 150) end),
			FrameEvent(52, function(inst) inst.Physics:SetSize(1.05) end),
			FrameEvent(52, function(inst) inst.Physics:MoveRelFacing(-28 / 150) end),
			FrameEvent(54, function(inst) inst.Physics:SetSize(1) end),
			FrameEvent(54, function(inst) inst.Physics:MoveRelFacing(-48 / 150) end),
			FrameEvent(67, function(inst) inst.Physics:MoveRelFacing(48 / 150) end),
			FrameEvent(69, function(inst) inst.Physics:SetSize(1.1) end),
			--

			FrameEvent(42, function(inst)
				inst.sg:RemoveStateTag("caninterrupt")
			end),
			FrameEvent(67, function(inst)
				inst.sg:AddStateTag("airborne")
			end),
			FrameEvent(79, function(inst)
				inst.sg:RemoveStateTag("airborne")
			end),
			FrameEvent(85, function(inst)
				inst.sg:AddStateTag("caninterrupt")
			end),
			FrameEvent(89, function(inst)
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
			inst.Physics:SetSize(1.1)
			inst.components.hitbox:StopRepeatTargetDelay()
		end,
	}),

	State({
		name = "dash_tell",
		tags = { "busy", "caninterrupt" },

		onenter = function(inst)
			inst.AnimState:PlayAnimation("behavior2")
		end,

		timeline =
		{
			--physics
			FrameEvent(0, function(inst) inst.Physics:MoveRelFacing(-24 / 150) end),
			FrameEvent(2, function(inst) inst.Physics:MoveRelFacing(-12 / 150) end),
			FrameEvent(4, function(inst) inst.Physics:MoveRelFacing(-6 / 150) end),
			FrameEvent(8, function(inst) inst.Physics:MoveRelFacing(6 / 150) end),
			FrameEvent(10, function(inst) inst.Physics:MoveRelFacing(36 / 150) end),
		},

		events =
		{
			EventHandler("animover", function(inst)
				inst.sg:GoToState("dash_pre")
			end),
		},
	}),

	State({
		name = "dash",
		tags = { "attack", "busy"},

		onenter = function(inst, dash_params)
			assert(dash_params and dash_params.dash_midpoint)
			inst.AnimState:PlayAnimation("roll")
			inst.sg.statemem.dash_params = dash_params
		end,

		timeline =
		{
			--physics
			FrameEvent(1, function(inst) inst.Physics:MoveRelFacing(36 / 150) end),
		},

		events =
		{
			EventHandler("animover", function(inst)
				inst.sg:GoToState("dash_loop", inst.sg.statemem.dash_params)
			end),
		},
	}),

	State({
		name = "dash_loop",
		tags = { "attack", "busy"},

		onenter = function(inst, dash_params)
			assert(dash_params and dash_params.dash_midpoint)
			inst.AnimState:PlayAnimation("roll_loop", true)
			inst.sg.statemem.dash_params = dash_params
			inst.sg.statemem.roll_finished = false
			inst.sg.statemem.fire_projectiles = false
			inst.sg:SetTimeoutAnimFrames(inst.tuning.dash.duration_frames)
			inst.Physics:StartPassingThroughObjects()
			inst.components.hitbox:StartRepeatTargetDelay()
		end,

		onupdate = function(inst)
			inst.components.hitbox:PushBeam(0.5, 1.8, .5, HitPriority.MOB_DEFAULT)
			local pos = inst:GetPosition()

			-- TODO(dbriscoe): Somehow we got the player (our combat target)
			-- instead of dash_params. How?
			local delta = pos - inst.sg.statemem.dash_params.dash_midpoint
			if delta:len2() < inst.tuning.dash.fire_distance^2 then
				inst.sg.statemem.fire_projectiles = true
			end

			delta = pos - inst.sg.statemem.dash_params.dash_dest
			if delta:len2() < inst.tuning.dash.stopping_distance^2 then
				SlowDownBeforeStop(inst)
				inst.sg.statemem.roll_finished = true
			end

			if inst.sg.statemem.fire_projectiles
				and not inst.components.timer:HasTimer("dash_shoot_cd")
			then
				inst.components.timer:StartTimer("dash_shoot_cd", krandom.Float(0.7, 1.0))
				local bullet = SGCommon.Fns.SpawnAtAngleDist(inst, "blarmadillo_bullet", 3.5, 180 - 15)
				bullet:Setup(inst, "dash")

				bullet = SGCommon.Fns.SpawnAtAngleDist(inst, "blarmadillo_bullet", 3.5, 180)
				bullet:Setup(inst, "dash")

				bullet = SGCommon.Fns.SpawnAtAngleDist(inst, "blarmadillo_bullet", 3.5, 180 + 15)
				bullet:Setup(inst, "dash")

				if not inst.sg.statemem.started_blastmode then
					inst.sg.statemem.started_blastmode = true
					inst.face:RollingBlastMode()
				end
			end
		end,

		ontimeout = function(inst)
			SlowDownBeforeStop(inst)
			-- don't transition yet... set a flag that it -can- transition on the next anim loop
			inst.sg.statemem.roll_finished = true
		end,

		timeline =
		{
			--physics
			FrameEvent(0, function(inst) SGCommon.Fns.SetMotorVelScaled(inst, 6) end),
			FrameEvent(1, function(inst) SGCommon.Fns.SetMotorVelScaled(inst, 10) end),
			FrameEvent(2, function(inst) SGCommon.Fns.SetMotorVelScaled(inst, inst.tuning.dash.movespeed) end),
			FrameEvent(4, function(inst) inst.Physics:SetSize(.9) end),
			--
			FrameEvent(0, function(inst)
				inst.components.attacktracker:CompleteActiveAttack()
				inst.sg:AddStateTag("airborne")
			end),
		},

		events =
		{
			EventHandler("hitboxtriggered", OnDashHitBoxTriggered),
			EventHandler("animover", function(inst)
				if inst.sg.statemem.roll_finished then
					inst.sg:GoToState("tired")
				end
			end),
		},

		onexit = function(inst)
			inst.Physics:StopPassingThroughObjects()
			inst.face:GoIdle()
		end,

	}),

	State({
		name = "tired",
		tags = { "busy", "vulnerable", },

		onenter = function(inst)
			inst.AnimState:PlayAnimation("knockdown_idle")
			inst.sg:SetTimeoutAnimFrames(120)
		end,

		timeline =
		{
			FrameEvent(25, function(inst)
				inst.components.colormultiplier:PushColor("vulnerable_attack", table.unpack(WEBCOLORS.FUCHSIA))
				inst.sg:RemoveStateTag("vulnerable")
			end),
			FrameEvent(25 + 5, function(inst)
				for angle=0,360,45 do
					local bullet = SGCommon.Fns.SpawnAtAngleDist(inst, "blarmadillo_bullet", 3.5, angle)
					bullet:Setup(inst, "tired")
				end
				inst.components.colormultiplier:PopColor("vulnerable_attack")
				inst.sg:AddStateTag("vulnerable")
			end),

			FrameEvent(100, function(inst)
				inst.components.colormultiplier:PushColor("vulnerable_attack", table.unpack(WEBCOLORS.FUCHSIA))
				inst.sg:RemoveStateTag("vulnerable")
			end),
			FrameEvent(100 + 5, function(inst)
				for angle=0,360,45 do
					local bullet = SGCommon.Fns.SpawnAtAngleDist(inst, "blarmadillo_bullet", 3.5, angle)
					bullet:Setup(inst, "tired")
				end
				inst.components.colormultiplier:PopColor("vulnerable_attack")
				inst.sg:AddStateTag("vulnerable")
			end),
		},

		events =
		{
		},

		ontimeout = function(inst)
			inst.sg:RemoveStateTag("busy") -- necessary?
			inst.sg:GoToState("knockdown_getup")
		end,
	}),

	State({
		name = "pierce",
		tags = { "busy", "caninterrupt" },

		onenter = function(inst, target)
			inst.sg.statemem.target = target
			inst.AnimState:PlayAnimation("pierce")
			inst.sg:SetTimeoutAnimFrames(30)

			SGCommon.Fns.SetMotorVelScaled(inst, inst.tuning.pierce.movespeed)
			--~ inst.components.attacktracker:CompleteActiveAttack()
			--~ inst.components.hitbox:StartRepeatTargetDelayAnimFrames(2)
		end,

		onupdate = function(inst)
			if inst.sg.statemem.hit_light then
				inst.components.hitbox:PushBeam(0, 2.5, 1, HitPriority.MOB_DEFAULT)
			elseif inst.sg.statemem.hit_heavy then
				inst.components.hitbox:PushBeam(0.5, 5, 1, HitPriority.MOB_DEFAULT)
			end
		end,

		ontimeout = function(inst)
			inst.sg:GoToState("idle")
		end,

		timeline =
		{
			FrameEvent(11, function(inst)
				inst.components.attacktracker:CompleteActiveAttack()
				inst.components.hitbox:StartRepeatTargetDelayAnimFrames(2)
				inst.sg.statemem.hit_light = true
			end),
			FrameEvent(13, function(inst)
				inst.sg.statemem.hit_light = false
				inst.sg.statemem.hit_heavy = true
			end),
			FrameEvent(21, function(inst)
				SGCommon.Fns.SetMotorVelScaled(inst, inst.tuning.pierce.movespeed * 0.25)
				inst.sg.statemem.hit_heavy = false
			end),
		},

		events =
		{
			EventHandler("hitboxtriggered", OnPierceHitBoxTriggered),
			EventHandler("animover", function(inst)
				inst.sg:GoToState("idle")
			end),
		},

		onexit = function(inst)
			inst.Physics:Stop()
			inst.components.hitbox:StopRepeatTargetDelay()
			inst.face:GoIdle()
		end,
	}),

	State({
		name = "shoot",
		tags = { "attack", "busy" },

		onenter = function(inst, dist)
			inst.AnimState:PlayAnimation("shoot_single")
		end,

		timeline =
		{
			--physics
			FrameEvent(0, function(inst) inst.Physics:MoveRelFacing(-28 / 150) end),
			FrameEvent(1, function(inst) inst.Physics:MoveRelFacing(-56 / 150) end),
			FrameEvent(2, function(inst) inst.Physics:MoveRelFacing(-56 / 150) end),
			FrameEvent(4, function(inst) inst.Physics:MoveRelFacing(-16 / 150) end),
			FrameEvent(6, function(inst) inst.Physics:MoveRelFacing(-8 / 150) end),
			FrameEvent(8, function(inst) inst.Physics:MoveRelFacing(-4 / 150) end),

			FrameEvent(12, function(inst) inst.Physics:MoveRelFacing(20 / 150) end),
			FrameEvent(14, function(inst) inst.Physics:MoveRelFacing(44 / 150) end),
			FrameEvent(16, function(inst) inst.Physics:MoveRelFacing(44 / 150) end),

			FrameEvent(22, function(inst) inst.Physics:MoveRelFacing(-16 / 150) end),
			FrameEvent(24, function(inst) inst.Physics:MoveRelFacing(-12 / 150) end),
			FrameEvent(26, function(inst) inst.Physics:MoveRelFacing(-8 / 150) end),
			FrameEvent(28, function(inst) inst.Physics:MoveRelFacing(-4 / 150) end),
			--

			FrameEvent(16, function(inst)
				inst.components.attacktracker:CompleteActiveAttack()

				local bullet = SGCommon.Fns.SpawnAtAngleDist(inst, "blarmadillo_bullet", 3.5, nil)
				bullet:Setup(inst, "shoot")

				bullet = SGCommon.Fns.SpawnAtAngleDist(inst, "blarmadillo_bullet", 3.5, nil)
				bullet:Setup(inst, "shoot")
			end),
			FrameEvent(25, function(inst)
				inst.sg:AddStateTag("caninterrupt")
			end),
			FrameEvent(30, function(inst)
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
		name = "elite_shoot",
		tags = { "attack", "busy" },

		onenter = function(inst, dist)
			inst.AnimState:PlayAnimation("elite_shoot")
		end,

		timeline =
		{
			--physics
			FrameEvent(0, function(inst) inst.Physics:MoveRelFacing(-28 / 150) end),
			FrameEvent(1, function(inst) inst.Physics:MoveRelFacing(-56 / 150) end),
			FrameEvent(2, function(inst) inst.Physics:MoveRelFacing(-56 / 150) end),
			FrameEvent(4, function(inst) inst.Physics:MoveRelFacing(-16 / 150) end),
			FrameEvent(6, function(inst) inst.Physics:MoveRelFacing(-8 / 150) end),
			FrameEvent(8, function(inst) inst.Physics:MoveRelFacing(-4 / 150) end),

			FrameEvent(12, function(inst) inst.Physics:MoveRelFacing(20 / 150) end),
			FrameEvent(14, function(inst) inst.Physics:MoveRelFacing(44 / 150) end),
			FrameEvent(16, function(inst) inst.Physics:MoveRelFacing(44 / 150) end),

			FrameEvent(40, function(inst) inst.Physics:MoveRelFacing(-16 / 150) end),
			FrameEvent(42, function(inst) inst.Physics:MoveRelFacing(-12 / 150) end),
			FrameEvent(44, function(inst) inst.Physics:MoveRelFacing(-8 / 150) end),
			FrameEvent(46, function(inst) inst.Physics:MoveRelFacing(-4 / 150) end),
			--

			FrameEvent(16, function(inst) -- up
				inst.components.attacktracker:CompleteActiveAttack()
				local bullet = SGCommon.Fns.SpawnAtAngleDist(inst, "blarmadillo_bullet", 3.5, -15)
				bullet:Setup(inst, "elite_shoot")
			end),

			FrameEvent(25, function(inst) -- straight
				inst.components.attacktracker:CompleteActiveAttack()
				local bullet = SGCommon.Fns.SpawnAtAngleDist(inst, "blarmadillo_bullet", 3.5, nil)
				bullet:Setup(inst, "elite_shoot")
			end),

			FrameEvent(34, function(inst) -- down
				inst.components.attacktracker:CompleteActiveAttack()
				local bullet = SGCommon.Fns.SpawnAtAngleDist(inst, "blarmadillo_bullet", 3.5, 15)
				bullet:Setup(inst, "elite_shoot")
			end),

			FrameEvent(47, function(inst)
				inst.sg:AddStateTag("caninterrupt")
			end),
			FrameEvent(51, function(inst)
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
		name = "block_pre",
		tags = { "busy" },

		onenter = function(inst)
			inst.AnimState:PlayAnimation("block_pre")
			inst.components.timer:StartTimer("block_min_time", 2.7 + math.random() * .8, true)
			inst.components.timer:StartTimer("block_max_time", 6, true)
		end,

		timeline =
		{
			--physics
			FrameEvent(11, function(inst) inst.Physics:MoveRelFacing(52 / 150) end),
			FrameEvent(12, function(inst) inst.Physics:SetSize(1.2) end),
			FrameEvent(12, function(inst) inst.Physics:SetMass(60000) end),
			--

			FrameEvent(12, function(inst)
				inst.sg:AddStateTag("block")
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
				inst.Physics:SetSize(1.1)
				inst.Physics:SetMass(inst.sg.mem.idlemass)
			else
				inst.components.timer:StartPausedTimer("block_cd", 8, true)
			end
		end,
	}),

	State({
		name = "block_loop",
		tags = { "block", "busy", "caninterrupt" },

		onenter = function(inst)
			inst.AnimState:PlayAnimation("block_loop", true)
		end,

		timeline =
		{
			FrameEvent(0, function(inst) inst.Physics:SetSize(1.2) end),
			FrameEvent(0, function(inst) inst.Physics:SetMass(60000) end),
		},

		events =
		{
			EventHandler("timerdone", function(inst, data)
				if data ~= nil and data.name == "block_min_time" then
					inst.sg.statemem.blocking = true
					inst.sg:GoToState("block_pst")
				end
			end),
			EventHandler("animover", function(inst)
				if not inst.components.timer:HasTimer("block_min_time") then
					inst.sg.statemem.blocking = true
					inst.sg:GoToState("block_pst")
				end
			end),
		},

		onexit = function(inst)
			if not inst.sg.statemem.blocking then
				inst.Physics:SetSize(1.1)
				inst.Physics:SetMass(inst.sg.mem.idlemass)
			end
		end,
	}),

	State({
		name = "block_hit",
		tags = { "hit", "block", "busy" },

		onenter = function(inst, unblock)
			inst.AnimState:PlayAnimation("block_hit")
			if inst.components.timer:HasTimer("block_max_time") then
				local t = inst.components.timer:GetTimeRemaining("block_min_time")
				if t == nil then
					inst.components.timer:StartTimer("block_min_time", .4 + .2 * math.random())
				elseif t < .5 then
					inst.components.timer:SetTimeRemaining("block_min_time", t + .4 + .2 * math.random())
				end
			else
				inst.sg.statemem.unblock = unblock
			end
		end,

		timeline =
		{
			--physics
			FrameEvent(0, function(inst) inst.Physics:SetSize(1.2) end),
			FrameEvent(0, function(inst) inst.Physics:SetMass(60000) end),
			--

			FrameEvent(5, function(inst)
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
				inst.Physics:SetSize(1.1)
				inst.Physics:SetMass(inst.sg.mem.idlemass)
			end
		end,
	}),

	State({
		name = "block_pst",
		tags = { "unblock", "block", "busy" },

		onenter = function(inst)
			inst.AnimState:PlayAnimation("block_pst")
			if inst.components.timer:HasTimer("block_max_time") then
				inst.sg:AddStateTag("caninterrupt")
			end
		end,

		timeline =
		{
			--physics
			FrameEvent(0, function(inst) inst.Physics:SetSize(1.2) end),
			FrameEvent(0, function(inst) inst.Physics:SetMass(60000) end),
			FrameEvent(12, function(inst) inst.Physics:SetMass(inst.sg.mem.idlemass) end),
			FrameEvent(12, function(inst) inst.Physics:MoveRelFacing(16 / 150) end),
			FrameEvent(14, function(inst) inst.Physics:MoveRelFacing(16 / 150) end),
			FrameEvent(24, function(inst) inst.Physics:MoveRelFacing(-20 / 150) end),
			FrameEvent(27, function(inst) inst.Physics:MoveRelFacing(-16 / 150) end),
			FrameEvent(29, function(inst) inst.Physics:SetSize(1.1) end),
			FrameEvent(29, function(inst) inst.Physics:MoveRelFacing(-16 / 150) end),
			FrameEvent(31, function(inst) inst.Physics:MoveRelFacing(-16 / 150) end),
			FrameEvent(33, function(inst) inst.Physics:MoveRelFacing(-16 / 150) end),
			--

			FrameEvent(12, function(inst)
				inst.sg:RemoveStateTag("block")
				inst.sg:RemoveStateTag("caninterrupt")
			end),
			FrameEvent(31, function(inst)
				inst.sg:AddStateTag("caninterrupt")
			end),
			FrameEvent(35, function(inst)
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
			inst.Physics:SetSize(1.1)
			inst.Physics:SetMass(inst.sg.mem.idlemass)
		end,
	}),
}

SGCommon.States.AddAttackPre(states, "elite_shoot",
{
	timeline = 	{ -- timeline
		--physics
		FrameEvent(0, function(inst) inst.Physics:MoveRelFacing(-30 / 150) end),
		FrameEvent(2, function(inst) inst.Physics:MoveRelFacing(-17 / 150) end),
		FrameEvent(4, function(inst) inst.Physics:MoveRelFacing(-12 / 150) end),

		FrameEvent(6, function(inst) inst.Physics:MoveRelFacing(23 / 150) end),
		FrameEvent(8, function(inst) inst.Physics:MoveRelFacing(52 / 150) end),
		FrameEvent(10, function(inst) inst.Physics:MoveRelFacing(61 / 150) end),
		FrameEvent(11, function(inst) inst.Physics:MoveRelFacing(15 / 150) end),
		----

		FrameEvent(11, function(inst)
			local dirtparams = inst.sg.statemem.dirtparams
			dirtparams.x, dirtparams.z = inst.Transform:GetWorldXZ()
			dirtparams.rot = inst.Transform:GetFacingRotation()
			inst.sg.statemem.dirtparams = nil

			inst.sg.statemem.fx = CreateDirtAt(dirtparams, "dirt_out", 148 / 150)
			inst.components.hitstopper:AttachChild(inst.sg.statemem.fx)
		end),

		FrameEvent(12, function(inst)
			if inst.sg.statemem.fx ~= nil then
				inst.components.hitstopper:DetachChild(inst.sg.statemem.fx)
				inst.sg.statemem.fx = nil
			end
		end),
	},
	onenter_fn = function(inst) -- enter
		local dirtparams = {}
		dirtparams.x, dirtparams.z = inst.Transform:GetWorldXZ()
		dirtparams.rot = inst.Transform:GetFacingRotation()
		inst.sg.statemem.dirtparams = dirtparams
	end,
	onexit_fn = function(inst) -- exit
		if inst.sg.statemem.fx ~= nil then
			inst.components.hitstopper:DetachChild(inst.sg.statemem.fx)
			inst.sg.statemem.fx = nil
		end
	end
})

SGCommon.States.AddAttackHold(states, "elite_shoot",
{
	onenter_fn = function(inst) -- enter
		local dirtparams = {}
		dirtparams.x, dirtparams.z = inst.Transform:GetWorldXZ()
		dirtparams.rot = inst.Transform:GetFacingRotation()
		inst.sg.statemem.dirtparams = dirtparams
	end,
	onexit_fn = function(inst) -- exit
		if inst.sg.statemem.fx ~= nil then
			inst.components.hitstopper:DetachChild(inst.sg.statemem.fx)
			inst.sg.statemem.fx = nil
		end

		if inst.sg.statemem.dirtparams ~= nil then
			CreateDirtAt(inst.sg.statemem.dirtparams, "dirt_out", 148 / 150)
		end
	end,
	onupdate_fn = function(inst) -- update
		local dirtparams = inst.sg.statemem.dirtparams
		if dirtparams ~= nil then
			--Update dirt position; used in case this state gets interrupted
			dirtparams.x, dirtparams.z = inst.Transform:GetWorldXZ()
			dirtparams.rot = inst.Transform:GetFacingRotation()
		end
	end
})


SGCommon.States.AddAttackPre(states, "shoot",
{
	timeline = 	{ -- timeline
		--physics
		FrameEvent(0, function(inst) inst.Physics:MoveRelFacing(-30 / 150) end),
		FrameEvent(2, function(inst) inst.Physics:MoveRelFacing(-17 / 150) end),
		FrameEvent(4, function(inst) inst.Physics:MoveRelFacing(-12 / 150) end),

		FrameEvent(6, function(inst) inst.Physics:MoveRelFacing(23 / 150) end),
		FrameEvent(8, function(inst) inst.Physics:MoveRelFacing(52 / 150) end),
		FrameEvent(10, function(inst) inst.Physics:MoveRelFacing(61 / 150) end),
		FrameEvent(11, function(inst) inst.Physics:MoveRelFacing(15 / 150) end),
		----

		FrameEvent(11, function(inst)
			local dirtparams = inst.sg.statemem.dirtparams
			dirtparams.x, dirtparams.z = inst.Transform:GetWorldXZ()
			dirtparams.rot = inst.Transform:GetFacingRotation()
			inst.sg.statemem.dirtparams = nil

			inst.sg.statemem.fx = CreateDirtAt(dirtparams, "dirt_out", 148 / 150)
			inst.components.hitstopper:AttachChild(inst.sg.statemem.fx)
		end),

		FrameEvent(12, function(inst)
			if inst.sg.statemem.fx ~= nil then
				inst.components.hitstopper:DetachChild(inst.sg.statemem.fx)
				inst.sg.statemem.fx = nil
			end
		end),
	},
	onenter_fn = function(inst) -- enter
		local dirtparams = {}
		dirtparams.x, dirtparams.z = inst.Transform:GetWorldXZ()
		dirtparams.rot = inst.Transform:GetFacingRotation()
		inst.sg.statemem.dirtparams = dirtparams
	end,
	onexit_fn = function(inst) -- exit
		if inst.sg.statemem.fx ~= nil then
			inst.components.hitstopper:DetachChild(inst.sg.statemem.fx)
			inst.sg.statemem.fx = nil
		end
	end
})

SGCommon.States.AddAttackHold(states, "shoot",
{
	onenter_fn = function(inst) -- enter
		local dirtparams = {}
		dirtparams.x, dirtparams.z = inst.Transform:GetWorldXZ()
		dirtparams.rot = inst.Transform:GetFacingRotation()
		inst.sg.statemem.dirtparams = dirtparams
	end,
	onexit_fn = function(inst) -- exit
		if inst.sg.statemem.fx ~= nil then
			inst.components.hitstopper:DetachChild(inst.sg.statemem.fx)
			inst.sg.statemem.fx = nil
		end

		if inst.sg.statemem.dirtparams ~= nil then
			CreateDirtAt(inst.sg.statemem.dirtparams, "dirt_out", 148 / 150)
		end
	end,
	onupdate_fn = function(inst) -- update
		local dirtparams = inst.sg.statemem.dirtparams
		if dirtparams ~= nil then
			--Update dirt position; used in case this state gets interrupted
			dirtparams.x, dirtparams.z = inst.Transform:GetWorldXZ()
			dirtparams.rot = inst.Transform:GetFacingRotation()
		end
	end
})

SGCommon.States.AddAttackPre(states, "dash",
{
	timeline =
	{
		--physics
		FrameEvent(1, function(inst) inst.Physics:MoveRelFacing(-12 / 150) end),
		FrameEvent(3, function(inst) inst.Physics:SetSize(1) end),
		FrameEvent(3, function(inst) inst.Physics:MoveRelFacing(-32 / 150) end),
		FrameEvent(5, function(inst) inst.Physics:MoveRelFacing(-16 / 150) end),
	},
})

SGCommon.States.AddAttackHold(states, "dash",
{
	timeline =
	{
		FrameEvent(3, function(inst) inst.Physics:MoveRelFacing(-8 / 150) end),
		FrameEvent(9, function(inst) inst.Physics:MoveRelFacing(-4 / 150) end),
	}
})

SGCommon.States.AddAttackPre(states, "pierce",
{
})
SGCommon.States.AddAttackHold(states, "pierce",
{
})

SGCommon.States.AddHitStates(states, ChooseAttack)


SGCommon.States.AddSpawnBattlefieldStates(states,
{
		anim = "spawn",
		fadeduration = 0.5,
		fadedelay = 0.1,
		timeline =
		{
			--physics
			--TODO #speedmult ?
			FrameEvent(1, function(inst) SGCommon.Fns.SetMotorVelScaled(inst, 10) end),
			FrameEvent(2, function(inst) SGCommon.Fns.SetMotorVelScaled(inst, 8) end),
			FrameEvent(3, function(inst) SGCommon.Fns.SetMotorVelScaled(inst, 7.5) end),
			FrameEvent(5, function(inst) SGCommon.Fns.SetMotorVelScaled(inst, 7) end),
			FrameEvent(13, function(inst) SGCommon.Fns.SetMotorVelScaled(inst, 3) end),
			FrameEvent(14, function(inst) SGCommon.Fns.SetMotorVelScaled(inst, 1.5) end),
			FrameEvent(15, function(inst) SGCommon.Fns.SetMotorVelScaled(inst, .5) end),
			FrameEvent(16, function(inst) inst.Physics:Stop() end),
			FrameEvent(22, function(inst) inst.Physics:MoveRelFacing(-24 / 150) end),
			FrameEvent(24, function(inst) inst.Physics:MoveRelFacing(-54 / 150) end),
			FrameEvent(27, function(inst) inst.Physics:MoveRelFacing(-18 / 150) end),
			FrameEvent(29, function(inst) inst.Physics:MoveRelFacing(-12 / 150) end),
			FrameEvent(31, function(inst) inst.Physics:MoveRelFacing(-12 / 150) end),
			--
			FrameEvent(2, function(inst)
				inst.sg:AddStateTag("airborne")
				inst.sg:AddStateTag("nointerrupt")
			end),
			FrameEvent(14, function(inst)
				inst.sg:RemoveStateTag("airborne")
				inst.sg:RemoveStateTag("nointerrupt")
			end),
			FrameEvent(31, function(inst)
				inst.sg:AddStateTag("caninterrupt")
			end),
			FrameEvent(35, function(inst)
				inst.sg:RemoveStateTag("busy")
			end),

			FrameEvent(2, function(inst) inst:PushEvent("leave_spawner") end),
		},

		onexit_fn = function(inst)
			inst.Physics:Stop()
		end
})

SGCommon.States.AddWalkStates(states,
{
	turnpsttimeline =
	{
		FrameEvent(2, function(inst)
			inst.sg:RemoveStateTag("busy")
		end),
	},
})

SGCommon.States.AddTurnStates(states, { chooseattack_fn = ChooseAttack })

SGCommon.States.AddIdleStates(states)

SGCommon.States.AddKnockbackStates(states,
{
	movement_frames = 10,
	knockback_pst_timeline =
	{
		FrameEvent(4, function(inst)
			inst.sg:AddStateTag("airborne")
		end),
		FrameEvent(11, function(inst)
			inst.sg:RemoveStateTag("airborne")
			inst.sg:RemoveStateTag("nointerrupt")
		end),
		FrameEvent(19, function(inst)
			inst.sg:AddStateTag("caninterrupt")
		end),
		FrameEvent(54, function(inst)
			inst.sg:RemoveStateTag("busy")
		end),

		-- Do not scale knockdown state
		FrameEvent(36, function(inst) inst.Physics:MoveRelFacing(18 / 150) end),
		FrameEvent(38, function(inst) inst.Physics:MoveRelFacing(24 / 150) end),
		FrameEvent(40, function(inst) inst.Physics:MoveRelFacing(30 / 150) end),
		FrameEvent(50, function(inst) inst.Physics:MoveRelFacing(-22 / 150) end),
		FrameEvent(52, function(inst) inst.Physics:MoveRelFacing(-22 / 150) end),
	}
})

SGCommon.States.AddKnockdownStates(states,
{
	movement_frames = 15,
	knockdown_size = 1.45,
	getup_frames = 37,
	knockdown_pre_timeline =
	{
		FrameEvent(18, function(inst) inst.Physics:MoveRelFacing(6 / 150) end),
		FrameEvent(20, function(inst) inst.Physics:MoveRelFacing(8 / 150) end),
		FrameEvent(22, function(inst) inst.Physics:MoveRelFacing(10 / 150) end),
		FrameEvent(24, function(inst) inst.Physics:MoveRelFacing(12 / 150) end),
		FrameEvent(26, function(inst) inst.Physics:MoveRelFacing(14 / 150) end),
		FrameEvent(28, function(inst) inst.Physics:MoveRelFacing(36 / 150) end),
		FrameEvent(30, function(inst) inst.Physics:MoveRelFacing(24 / 150) end),
		--
		FrameEvent(10, function(inst)
			inst.sg:RemoveStateTag("nointerrupt")
		end),
		FrameEvent(30, function(inst)
			inst.sg:AddStateTag("caninterrupt")
		end),
	},

	knockdown_getup_timeline =
	{
		FrameEvent(0, function(inst) inst:SnapToFacingRotation() end),
		FrameEvent(0, function(inst) inst.Physics:MoveRelFacing(-3 / 150) end),
		FrameEvent(2, function(inst) inst.Physics:MoveRelFacing(-5 / 150) end),
		FrameEvent(4, function(inst) inst.Physics:MoveRelFacing(-6 / 150) end),
		FrameEvent(6, function(inst) inst.Physics:MoveRelFacing(-6 / 150) end),
		FrameEvent(8, function(inst) inst.Physics:MoveRelFacing(-3 / 150) end),
		FrameEvent(9, function(inst) SGCommon.Fns.SetMotorVelScaled(inst, .8, SGCommon.SGSpeedScale.LIGHT) end),
		FrameEvent(12, function(inst) SGCommon.Fns.SetMotorVelScaled(inst, 3.2, SGCommon.SGSpeedScale.LIGHT) end),
		FrameEvent(16, function(inst) SGCommon.Fns.SetMotorVelScaled(inst, 1.6, SGCommon.SGSpeedScale.LIGHT) end),
		FrameEvent(18, function(inst) SGCommon.Fns.SetMotorVelScaled(inst, .8, SGCommon.SGSpeedScale.LIGHT) end),
		FrameEvent(20, function(inst) SGCommon.Fns.SetMotorVelScaled(inst, .4, SGCommon.SGSpeedScale.LIGHT) end),
		FrameEvent(22, function(inst) SGCommon.Fns.SetMotorVelScaled(inst, .2, SGCommon.SGSpeedScale.LIGHT) end),
		FrameEvent(24, function(inst) inst.Physics:Stop() end),
		FrameEvent(25, function(inst) SGCommon.Fns.SetMotorVelScaled(inst, -1.6, SGCommon.SGSpeedScale.LIGHT) end),
		FrameEvent(26, function(inst) SGCommon.Fns.SetMotorVelScaled(inst, -2.4, SGCommon.SGSpeedScale.LIGHT) end),
		FrameEvent(28, function(inst) SGCommon.Fns.SetMotorVelScaled(inst, -4.8, SGCommon.SGSpeedScale.LIGHT) end),
		FrameEvent(32, function(inst) SGCommon.Fns.SetMotorVelScaled(inst, -6.4, SGCommon.SGSpeedScale.LIGHT) end),
		FrameEvent(36, function(inst) SGCommon.Fns.SetMotorVelScaled(inst, -8, SGCommon.SGSpeedScale.LIGHT) end),
		FrameEvent(40, function(inst) SGCommon.Fns.SetMotorVelScaled(inst, -5, SGCommon.SGSpeedScale.LIGHT) end),
		FrameEvent(42, function(inst) SGCommon.Fns.SetMotorVelScaled(inst, -3.333, SGCommon.SGSpeedScale.LIGHT) end),
		FrameEvent(44, function(inst) SGCommon.Fns.SetMotorVelScaled(inst, -2.4, SGCommon.SGSpeedScale.LIGHT) end),
		FrameEvent(47, function(inst) inst.Physics:Stop() end),
		FrameEvent(49, function(inst) inst.Physics:MoveRelFacing(-16 / 150) end),
		FrameEvent(51, function(inst) inst.Physics:MoveRelFacing(-8 / 150) end),
		--

		FrameEvent(35, function(inst)
			inst.sg:AddStateTag("nointerrupt")
		end),
		FrameEvent(36, function(inst)
			inst.sg:RemoveStateTag("knockdown")
		end),
		FrameEvent(41, function(inst)
			inst.sg:RemoveStateTag("nointerrupt")
		end),
		FrameEvent(45, function(inst)
			inst.sg:AddStateTag("caninterrupt")
		end),
	},
})

SGCommon.States.AddKnockdownHitStates(states,
{
	hit_pst_busy_frames = 6,
	onenter_pst_fn = function(inst) inst.Physics:SetSize(1.45) end,
	onexit_pst_fn = function(inst)
		if not inst.sg.statemem.knockdown then
			inst.Physics:SetSize(1.1)
		end
	end,
})

SGCommon.States.AddMonsterDeathStates(states)

return StateGraph("sg_shellsquid", states, events, "idle")
