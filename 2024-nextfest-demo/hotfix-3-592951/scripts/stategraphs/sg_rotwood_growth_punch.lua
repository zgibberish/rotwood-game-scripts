local SGCommon = require("stategraphs/sg_common")

local PUNCH_DAMAGE = 20

local function OnPunchHitBoxTriggered(inst, data)
	local hitstoplevel = HitStopLevel.MEDIUM
	local hit = false

	for i = 1, #data.targets do
		local v = data.targets[i]
		if v.canownerhit or (v.owner or v) ~= inst.owner then
			inst.components.combat:DoKnockdownAttack({
				target = v,
				damage_mod = PUNCH_DAMAGE,
				speedmult = .7
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

local states =
{
	State({
		name = "punch",
		tags = { "linked" },

		onenter = function(inst)
			inst.AnimState:PlayAnimation("punch_pre")
			inst.AnimState:PushAnimation("punch_idle")
			inst.sg.statemem.cancelframe = 14
		end,

		timeline =
		{
			FrameEvent(2, function(inst)
				inst.sg.statemem.cancelframe = 11
			end),
			FrameEvent(4, function(inst)
				inst.sg.statemem.cancelframe = 9
				inst.HitBox:SetNonPhysicsRect(1)
				inst.HitBox:SetEnabled(true)
				SGCommon.Fns.SpawnAtDist(inst, "fx_rotwood_debris_punch", 0)
			end),
			FrameEvent(6, function(inst)
				inst.sg:AddStateTag("canshatter")
				inst.HitBox:SetNonPhysicsRect(.75)
			end),
			FrameEvent(7, function(inst)
				inst.Physics:StartPassingThroughObjects()
				inst.Physics:SetRoundLine(1)
				inst.Physics:StopPassingThroughObjects()
				inst.HitBox:UsePhysicsShape()
				inst.components.hitbox:StartRepeatTargetDelay()
				inst.components.hitbox:PushBeam(-1.2, 1.2, 1, HitPriority.BOSS_DEFAULT)
			end),
			FrameEvent(8, function(inst)
				ConvertToStaticObstaclePhysics(inst)
				inst.components.hitbox:PushBeam(-1.2, 1.2, 1, HitPriority.BOSS_DEFAULT)
			end),
		},

		events =
		{
			EventHandler("hitboxtriggered", OnPunchHitBoxTriggered),
			EventHandler("interrupted", function(inst)
				if inst.sg:HasStateTag("canshatter") then
					inst.sg:GoToState("punch_shatter")
				else
					inst.sg:GoToState("punch_cancel", inst.sg.statemem.cancelframe)
				end
			end),
			EventHandler("animqueueover", function(inst)
				inst.sg:GoToState("punch_pst")
			end),
		},

		onexit = function(inst)
			inst.components.hitbox:StopRepeatTargetDelay()
		end,
	}),

	State({
		name = "punch_pst",
		tags = { "linked", "canshatter" },

		onenter = function(inst)
			inst.AnimState:PlayAnimation("punch_pst")
		end,

		timeline =
		{
			FrameEvent(7, function(inst)
				inst.sg:RemoveStateTag("canshatter")
				inst.Physics:SetSize(.85)
			end),
			FrameEvent(9, function(inst) inst.Physics:SetSize(.5) end),
			FrameEvent(11, function(inst)
				inst.Physics:SetEnabled(false)
				inst.HitBox:SetEnabled(false)
			end),
			FrameEvent(14, function(inst)
				inst.sg:RemoveStateTag("linked")
			end),
		},

		events =
		{
			EventHandler("interrupted", function(inst)
				if inst.sg:HasStateTag("canshatter") then
					inst.sg:GoToState("punch_shatter")
				end
			end),
			EventHandler("animover", function(inst)
				inst:Remove()
			end),
		},
	}),

	State({
		name = "punch_cancel",

		onenter = function(inst, frame)
			inst.AnimState:PlayAnimation("punch_pst")
			inst.AnimState:SetFrame(frame)
			inst.Physics:SetEnabled(false)
			inst.HitBox:SetEnabled(false)
		end,

		events =
		{
			EventHandler("animover", function(inst)
				inst:Remove()
			end),
		},
	}),

	State({
		name = "punch_shatter",

		onenter = function(inst)
			inst.AnimState:PlayAnimation("punch_shatter")
			inst.Physics:SetEnabled(false)
			inst.HitBox:SetEnabled(false)
		end,

		events =
		{
			EventHandler("animover", function(inst)
				inst:Remove()
			end),
		},
	}),
}

return StateGraph("sg_rotwood_growth_punch", states, nil, "punch")
