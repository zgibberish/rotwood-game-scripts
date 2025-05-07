local EffectEvents = require "effectevents"
local SGCommon = require "stategraphs.sg_common"
local playerutil = require "util.playerutil"
local monsterutil = require "util.monsterutil"

local function OnEscapeHitBoxTriggered(inst, data)
	SGCommon.Events.OnHitboxTriggered(inst, data, {
		attackdata_id = "escape",
		hitstoplevel = HitStopLevel.MEDIUM,
		pushback = 0.5,
		hitflags = Attack.HitFlags.LOW_ATTACK,
		combat_attack_fn = "DoKnockdownAttack",
		hit_fx = monsterutil.defaultAttackHitFX,
	})
end

local function ChooseBattleCry(inst, data)
	if data.target ~= nil and data.target:IsValid() then
		if not inst.components.timer:HasTimer("battlecry_cd") then
			if not inst:IsNear(data.target, 6) then
				SGCommon.Fns.TurnAndActOnTarget(inst, data.target, true, "taunt")
				return true
			end
		end
	end
	return false
end

local function ChooseIdleBehavior(inst)
	if not inst.components.timer:HasTimer("idlebehavior_cd") then
		local threat = playerutil.GetRandomLivingPlayer()
		if not threat then
			if not inst.components.timer:HasTimer("behaviour1_cd") then
				inst.sg:GoToState("behavior1")
				return true
			end

			if not inst.components.timer:HasTimer("behaviour2_cd") then
				inst.sg:GoToState("behavior2")
				return true
			end
		end
	end
	return false
end

local function OnDeath(inst, data)
	--Spawn death fx
	EffectEvents.MakeEventFXDeath(inst, data.attack, "death_mothball_teen")

	inst.components.lootdropper:DropLoot()
end

local function OnProjectileRemoved(inst)
	-- inst is the projectile and inst.owner is the mothball_teen.
	if inst.owner
		and inst.owner:IsValid()
		and inst.owner.sg
		and inst.owner.sg:HasStateTag("attack")
	then
		inst.owner.sg:GoToState("attack_pst")
	end
end

local function OnMapCollision(inst)
	-- If it hit a wall while escaping, select a new run away position.
	local pos = TheWorld.Map:GetRandomPointInWalkable(inst.Physics:GetSize())
	local angle_to_pos = inst:GetAngleToXZ(pos.x, pos.z)
	inst.components.locomotor:TurnToDirection(angle_to_pos)

	if inst.brain.brain then
		inst.brain.brain:SetEscapePos(pos)
	end
end

local function OnEscape(inst, pos)
	SGCommon.Fns.TurnAndActOnLocation(inst, pos.x, pos.z, true, "escape_pre")
end

local events =
{
	EventHandler("mapcollision", OnMapCollision),
	EventHandler("escape", OnEscape),
	EventHandler("attack_interrupted", function(inst) -- TODO: Fix logic that actually processes attack_interrupted in SGCommon to destroy teen mothball projectiles when hitting the teen mothball.
		inst:PushEvent("ownerhit")
	end)
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
		name = "taunt",
		tags = { "busy", "caninterrupt" },

		onenter = function(inst)
			inst.AnimState:PlayAnimation("taunt")
			inst.components.timer:StartTimer("battlecry_cd", 12 + math.random() * 5, true)
			inst.components.timer:StartTimer("idlebehavior_cd", 8 + math.random() * 5, true)
		end,

		timeline =
		{
			FrameEvent(25, function(inst)
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
		name = "behavior1",
		tags = { "busy", "caninterrupt", "flying" },

		onenter = function(inst)
			inst.AnimState:PlayAnimation("behavior1")
			inst.components.timer:StartTimer("behaviour1_cd", 12 + math.random() * 5, true)
			inst.components.timer:StartTimer("idlebehavior_cd", 8 + math.random() * 5, true)
		end,

		timeline =
		{
			FrameEvent(18, function(inst)
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
		name = "behavior2",
		tags = { "busy", "caninterrupt" },

		onenter = function(inst)
			inst.AnimState:PlayAnimation("behavior2")
			inst.components.timer:StartTimer("behaviour2_cd", 12 + math.random() * 5, true)
			inst.components.timer:StartTimer("idlebehavior_cd", 8 + math.random() * 5, true)
		end,

		timeline =
		{
			FrameEvent(50, function(inst)
				inst.sg:AddStateTag("flying")
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
		name = "attack",
		tags = { "attack", "busy", "caninterrupt" },

		onenter = function(inst, target)
			inst.AnimState:PlayAnimation("attack_loop", true)
			inst.sg.statemem.target = target
		end,

		timeline =
		{
			FrameEvent(0, function(inst)
				local function SetupProjectile(projectile)
					projectile:Setup(inst, inst.sg.statemem.target)
					projectile:ListenForEvent("projectileremoved", OnProjectileRemoved)
					projectile:ListenForEvent("onremove", OnProjectileRemoved)
					return projectile
				end

				-- Elite mothball spawns two projectiles, with slightly different move properties to prevent overlap when following their target.
				if inst:HasTag("elite") then
					local projectile = SGCommon.Fns.SpawnAtAngleDist(inst, "mothball_teen_projectile_elite", 2, -45)
					if projectile == nil then return end
					SetupProjectile(projectile)

					local projectile2 = SGCommon.Fns.SpawnAtAngleDist(inst, "mothball_teen_projectile2_elite", 2, 45)
					if projectile2 == nil then return end
					SetupProjectile(projectile2)
				else
					local projectile = SGCommon.Fns.SpawnAtDist(inst, "mothball_teen_projectile", 2)
					if projectile == nil then return end
					SetupProjectile(projectile)
				end
			end),
		},

		onexit = function(inst)
			inst.components.attacktracker:CompleteActiveAttack()
		end
	}),

	State({
		name = "attack_pst",
		tags = { "busy" },

		onenter = function(inst, target)
			inst.AnimState:PlayAnimation("attack_pst")
		end,

		timeline =
		{
			FrameEvent(9, function(inst)
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
		name = "escape",
		tags = { "busy", "escaping", "nointerrupt" },

		onenter = function(inst)
			inst.sg.statemem.target = inst.components.combat:GetTarget()

			inst.AnimState:PlayAnimation("walk_attack_pst")
			inst.AnimState:PushAnimation("walk_loop", true)
			inst.Physics:StartPassingThroughObjects()
			inst.AnimState:SetDeltaTimeMultiplier(1.8)
			inst.sg:SetTimeout(inst.tuning.escape_time)

			inst.components.hitbox:StartRepeatTargetDelay()
			inst.sg.mem.wants_to_escape = false
			inst.sg.statemem.timer = 0
		end,

		onupdate = function(inst)
			inst.sg.statemem.timer = inst.sg.statemem.timer + 1
			if (inst.sg.statemem.timer > 0.1 * SECONDS) then
				SGCommon.Fns.SetMotorVelScaled(inst, inst.tuning.escape_speed)
				inst.components.hitbox:PushBeam(0.5, 1.25, 0.25, HitPriority.MOB_DEFAULT)
			end
		end,

		ontimeout = function(inst)
			inst.sg.statemem.target = SGCommon.Fns.SanitizeTarget(inst.sg.statemem.target)
			if inst.sg.statemem.target then
				SGCommon.Fns.FaceTarget(inst, inst.sg.statemem.target, true)
			end
			inst.sg:GoToState("escape_pst")
		end,

		onexit = function(inst)
			inst.Physics:StopPassingThroughObjects()
			inst.components.hitbox:StopRepeatTargetDelay()
			inst.AnimState:SetDeltaTimeMultiplier(1)
			inst.components.attacktracker:CompleteActiveAttack()
			SGCommon.Fns.SetMotorVelScaled(inst, 0)
		end,

		events =
		{
			EventHandler("hitboxtriggered", OnEscapeHitBoxTriggered),
		}
	}),

	State({
		name = "escape_pst",
		tags = { "busy" },

		onenter = function(inst)
			inst.AnimState:PlayAnimation("walk_pst")
			inst.brain.brain:OnEscaped()
		end,

		events =
		{
			--EventHandler("hitboxtriggered", OnEscapeHitBoxTriggered),
			EventHandler("animover", function(inst)
				local target = inst.components.combat:GetTarget()
				if target then
					inst.sg:GoToState("attack_pre", target)
				else
					inst.sg:GoToState("idle")
				end
			end),
		},

		--[[onupdate = function(inst)
			inst.components.hitbox:PushBeam(-1.00, 1.00, 1.00, HitPriority.MOB_DEFAULT)
		end,]]
	}),
}

SGCommon.States.AddAttackPre(states, "attack")
-- No hold animation, since the attack state is a looping state.
SGCommon.States.AddAttackPre(states, "escape")
SGCommon.States.AddAttackHold(states, "escape")

SGCommon.States.AddSpawnBattlefieldStates(states,
{
	anim = "taunt",
	fadeduration = 0.5,
	fadedelay = 0.1,

	timeline =
	{
		FrameEvent(0, function(inst) inst:PushEvent("leave_spawner") end),
	},

})

SGCommon.States.AddHitStates(states, SGCommon.Fns.ChooseAttack,
{
	onenterhit = function(inst, data)
		inst.sg.mem.wants_to_escape = true
	end,
})
SGCommon.States.AddKnockbackStates(states,
{
	movement_frames = 7,
})
SGCommon.States.AddKnockdownStates(states,
{
	movement_frames = 8,
})
SGCommon.States.AddKnockdownHitStates(states)

SGCommon.States.AddIdleStates(states)
SGCommon.States.AddLocomoteStates(states, "walk",
{
	walk_move_delay = 9,
	turn_move_delay = 7,
})
SGCommon.States.AddTurnStates(states)

SGCommon.States.AddMonsterDeathStates(states)

SGRegistry:AddData("sg_mothball_teen", states)


return StateGraph("sg_mothball_teen", states, events, "idle")
