local SGCommon = require("stategraphs/sg_common")

local ROOT_DAMAGE = 10

local function OnRootHitBoxTriggered(inst, data)
	local hitstoplevel = HitStopLevel.LIGHT
	local hit = false
	local tick = GetTick()
	local dir = inst.Transform:GetFacingRotation()

	for i = 1, #data.targets do
		local v = data.targets[i]
		if (v.canownerhit or (v.owner or v) ~= inst.owner) and (inst.targets[v] or 0) < tick then
			inst.components.combat:DoKnockdownAttack({
				target = v,
				damage_mod = ROOT_DAMAGE,
				dir = dir
			})
			if v.components.hitstopper ~= nil then
				v.components.hitstopper:PushHitStop(hitstoplevel)
			end

			SpawnHitFx("fx_hit_player_side", inst, v, 0, 0, dir, hitstoplevel)
			SpawnHurtFx(inst, v, 0, dir, hitstoplevel)

			inst.targets[v] = tick + 7
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
		name = "extrude",
		tags = { "linked" },

		onenter = function(inst)
			inst.sg.mem.anim = "root_wave"..tostring(math.random(4))
			inst.sg.statemem.cancelstate = "extrude_cancel"
			inst.AnimState:PlayAnimation(inst.sg.mem.anim)
			inst.Physics:StartPassingThroughObjects()
			inst.Physics:SetRoundLine(.5)
			inst.Physics:StopPassingThroughObjects()
			inst.HitBox:SetEnabled(true)
			inst.components.hitbox:StartRepeatTargetDelay()
			inst.components.hitbox:PushBeam(-.9, 1, 1, HitPriority.BOSS_DEFAULT)
		end,

		timeline =
		{
			FrameEvent(0, function(inst)
				SGCommon.Fns.SpawnAtDist(inst, "fx_rotwood_debris_wave", 0)
			end),
			FrameEvent(1, function(inst)
				ConvertToStaticObstaclePhysics(inst)
				inst.components.hitbox:PushBeam(-.9, 1, 1, HitPriority.BOSS_DEFAULT)
			end),
			FrameEvent(2, function(inst)
				inst.sg.statemem.cancelstate = "extrude_pst"
				inst.components.hitbox:PushBeam(-.8, 1.8, 1, HitPriority.BOSS_DEFAULT)
			end),
			FrameEvent(3, function(inst)
				inst.components.hitbox:PushBeam(-.8, 1.8, 1, HitPriority.BOSS_DEFAULT)
			end),
		},

		events =
		{
			EventHandler("hitboxtriggered", OnRootHitBoxTriggered),
			EventHandler("interrupted", function(inst)
				if inst.sg.statemem.cancelstate ~= nil then
					inst.sg:GoToState(inst.sg.statemem.cancelstate)
				end
			end),
			EventHandler("animover", function(inst)
				inst.sg:GoToState("extrude_pst")
			end),
		},

		onexit = function(inst)
			ConvertToStaticObstaclePhysics(inst)
			inst.components.hitbox:StopRepeatTargetDelay()
		end,
	}),

	State({
		name = "extrude_pst",
		tags = { "linked" },

		onenter = function(inst)
			inst.AnimState:PlayAnimation(inst.sg.mem.anim.."_pst")
		end,

		timeline =
		{
			FrameEvent(6, function(inst)
				inst.Physics:SetEnabled(false)
				inst.HitBox:SetEnabled(false)
			end),
			FrameEvent(10, function(inst)
				inst.sg:RemoveStateTag("linked")
			end),
		},

		events =
		{
			EventHandler("animover", function(inst)
				inst:Remove()
			end),
		},
	}),

	State({
		name = "extrude_cancel",

		onenter = function(inst, frame)
			inst.AnimState:PlayAnimation(inst.sg.mem.anim.."_pst")
			inst.AnimState:SetFrame(2)
		end,

		timeline =
		{
			FrameEvent(4, function(inst)
				inst.Physics:SetEnabled(false)
				inst.HitBox:SetEnabled(false)
			end),
		},

		events =
		{
			EventHandler("animover", function(inst)
				inst:Remove()
			end),
		},
	}),
}

return StateGraph("sg_rotwood_growth_root", states, nil, "extrude")
