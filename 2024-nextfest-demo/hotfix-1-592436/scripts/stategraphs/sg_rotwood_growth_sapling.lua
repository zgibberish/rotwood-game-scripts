local SGCommon = require("stategraphs/sg_common")

local EXPLOSION_DAMAGE = 20

local function OnExplodeHitBoxTriggered(inst, data)
	local hitstoplevel = HitStopLevel.MEDIUM
	local hit = false

	for i = 1, #data.targets do
		local v = data.targets[i]
		if v.canownerhit or (v.owner or v) ~= inst.owner then
			inst.components.combat:DoKnockdownAttack({
				target = v,
				damage_mod = EXPLOSION_DAMAGE
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

local events =
{
	SGCommon.Events.OnAttacked(),
}

local states =
{
	State({
		name = "grow1",
		tags = { "busy" },

		onenter = function(inst)
			inst.AnimState:PlayAnimation("sapling_grow1")
			inst.Physics:StartPassingThroughObjects()
			inst.HitBox:SetEnabled(false)
			inst.sg.mem.earlygrowth = 1
		end,

		timeline =
		{
			FrameEvent(2, function(inst)
				inst.Physics:SetRoundLine(.1)
				inst.Physics:StopPassingThroughObjects()
				inst.sg.statemem.physicsinit = true
				SGCommon.Fns.SpawnAtDist(inst, "fx_rotwood_debris_pullout", 0)
			end),
			FrameEvent(4, function(inst) inst.Physics:SetSize(.2) end),
			FrameEvent(6, function(inst)
				inst.Physics:SetSize(.3)
				inst.HitBox:SetEnabled(true)
			end),
			FrameEvent(7, ConvertToStaticObstaclePhysics),
			FrameEvent(8, function(inst)
				inst.sg:AddStateTag("caninterrupt")
			end),
		},

		events =
		{
			EventHandler("animover", function(inst)
				inst.sg:GoToState("idle1")
			end),
		},

		onexit = function(inst)
			if inst.sg.statemem.physicsinit then
				ConvertToStaticObstaclePhysics(inst, .3)
			else
				ConvertToStaticObstaclePhysics(inst)
				inst.Physics:SetRoundLine(.3)
				inst.Physics:StopPassingThroughObjects()
			end
			inst.HitBox:SetEnabled(true)
		end,
	}),

	State({
		name = "idle1",
		tags = { "idle" },

		onenter = function(inst)
			inst.AnimState:PlayAnimation("sapling_idle1")
			inst.Physics:SetSize(.3)
		end,

		events =
		{
			EventHandler("animover", function(inst)
				inst.sg:GoToState("grow2")
			end),
		},
	}),

	State({
		name = "grow2",
		tags = { "busy" },

		onenter = function(inst)
			inst.AnimState:PlayAnimation("sapling_grow2")
			inst.sg.mem.earlygrowth = nil
		end,

		timeline =
		{
			FrameEvent(9, function(inst)
				SGCommon.Fns.SpawnAtDist(inst, "fx_rotwood_debris_pullout", 0)
			end),
			FrameEvent(11, function(inst) ConvertToDynamicObstaclePhysics(inst, .55) end),
			FrameEvent(12, ConvertToStaticObstaclePhysics),
			FrameEvent(14, function(inst)
				inst.sg:AddStateTag("caninterrupt")
			end),
		},

		events =
		{
			EventHandler("animover", function(inst)
				inst.sg:GoToState("idle2")
			end),
		},

		onexit = function(inst) ConvertToStaticObstaclePhysics(inst, .55) end,
	}),

	State({
		name = "idle2",
		tags = { "idle" },

		onenter = function(inst)
			inst.AnimState:PlayAnimation("sapling_idle2", true)
			inst.Physics:SetSize(.55)

			inst.sg:SetTimeout(9 + math.random() * 3)
		end,

		ontimeout = function(inst)
			inst.sg:GoToState("bomb")
		end,
	}),

	State({
		name = "hit1",
		tags = { "hit", "busy" },

		onenter = function(inst)
			inst.AnimState:PlayAnimation("sapling_hit1")
			inst.Physics:SetSize(.3)
			inst.sg.mem.earlygrowth = (inst.sg.mem.earlygrowth or 3) + 1
		end,

		timeline =
		{
			FrameEvent(5, function(inst)
				inst.sg:RemoveStateTag("busy")
			end),
		},

		events =
		{
			EventHandler("animover", function(inst)
				inst.sg:GoToState(inst.sg.mem.earlygrowth < 3 and "idle1" or "grow2")
			end),
		},
	}),

	State({
		name = "hit",
		tags = { "hit", "busy" },

		onenter = function(inst)
			if inst.sg.mem.earlygrowth ~= nil then
				inst.sg:GoToState("hit1")
				return
			end
			inst.AnimState:PlayAnimation("sapling_hit2")
			inst.Physics:SetSize(.55)
		end,

		timeline =
		{
			FrameEvent(5, function(inst)
				inst.sg:RemoveStateTag("busy")
			end),
		},

		events =
		{
			EventHandler("animover", function(inst)
				inst.sg:GoToState("hit_bomb")
			end),
		},
	}),

	State({
		name = "hit_bomb",
		tags = { "attack", "busy", "nointerrupt" },

		onenter = function(inst)
			inst.AnimState:PlayAnimation("sapling_bomb_hit")
			inst.Physics:SetSize(.55)
		end,

		timeline =
		{
			FrameEvent(13, function(inst) ConvertToDynamicObstaclePhysics(inst, .72) end),
			FrameEvent(14, ConvertToStaticObstaclePhysics),
		},

		events =
		{
			EventHandler("animover", function(inst)
				inst.sg:GoToState("explode")
			end),
		},

		onexit = ConvertToStaticObstaclePhysics,
	}),

	State({
		name = "bomb",
		tags = { "attack", "busy", "nointerrupt" },

		onenter = function(inst)
			inst.AnimState:PlayAnimation("sapling_bomb")
			inst.Physics:SetSize(.55)
		end,

		timeline =
		{
			FrameEvent(13, function(inst) ConvertToDynamicObstaclePhysics(inst, .72) end),
			FrameEvent(14, ConvertToStaticObstaclePhysics),
			FrameEvent(33, function(inst) ConvertToDynamicObstaclePhysics(inst, .85) end),
			FrameEvent(34, ConvertToStaticObstaclePhysics),
		},

		events =
		{
			EventHandler("animover", function(inst)
				inst.sg:GoToState("explode")
			end),
		},

		onexit = ConvertToStaticObstaclePhysics,
	}),

	State({
		name = "explode",
		tags = { "attack", "busy", "nointerrupt" },

		onenter = function(inst)
			inst.AnimState:PlayAnimation("sapling_explode")
			inst.Physics:SetSize(.85)
		end,

		timeline =
		{
			FrameEvent(2, function(inst)
				inst.Physics:SetEnabled(false)
				inst.HitBox:SetEnabled(false)
				inst.components.hitbox:StartRepeatTargetDelay()
				inst.components.hitbox:PushBeam(-2, 2, 1.5, HitPriority.BOSS_DEFAULT)
			end),
			FrameEvent(3, function(inst)
				inst.components.hitbox:PushBeam(-3.4, 3.4, 2, HitPriority.BOSS_DEFAULT)
			end),
			FrameEvent(4, function(inst)
				inst.components.hitbox:PushBeam(-3.4, 3.4, 2, HitPriority.BOSS_DEFAULT)
			end),
		},

		events =
		{
			EventHandler("hitboxtriggered", OnExplodeHitBoxTriggered),
			EventHandler("animover", function(inst)
				inst:Remove()
			end),
		},

		onexit = function(inst)
			inst.components.hitbox:StopRepeatTargetDelay()
		end,
	}),
}

return StateGraph("sg_rotwood_growth_sapling", states, events, "grow1")
