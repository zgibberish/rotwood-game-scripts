local easing = require("util/easing")

local states =
{
	State({
		name = "idle",
	}),

	State({
		name = "thrown",
		tags = { "airborne" },
		onenter = function(inst, targetpos)
			inst.AnimState:PlayAnimation("spin", true)
			local x, y, z = inst.Transform:GetWorldPosition()
		    local dx = targetpos.x - x
		    local dz = targetpos.z - z
		    local rangesq = dx * dx + dz * dz
		    local maxrange = 20
		    local speed = easing.linear(rangesq, 20, 3, maxrange * maxrange)
		    inst.components.complexprojectile:SetHorizontalSpeed(speed)
		    inst.components.complexprojectile:SetGravity(-40)
		    inst.components.complexprojectile:Launch(targetpos)
		    inst.components.complexprojectile.onhitfn = function() inst.sg:GoToState("land", targetpos) end

			local circle = SpawnPrefab("fx_ground_target_purple", inst)
			circle.Transform:SetPosition( targetpos.x, 0, targetpos.z )

			inst.sg.statemem.landing_pos = circle
		end,

		onexit = function(inst)
			if inst.sg.statemem.landing_pos then
				inst.sg.statemem.landing_pos:Remove()
			end
		end,
	}),

	State({
		name = "land",

		onenter = function(inst, pos)
			inst:Hide()
			inst.Transform:SetPosition(pos.x, 0, pos.z)
			inst.sg:SetTimeoutAnimFrames(3)

			local seed_prefab = inst:HasTag("elite") and "gourdo_elite_seed" or "gourdo_healing_seed"
			local heal_obj = SpawnPrefab(seed_prefab, inst)
			heal_obj.Transform:SetPosition(pos.x, 0, pos.z)
			heal_obj:Setup(inst.owner)
		end,

		ontimeout = function(inst)
			inst:Remove()
		end,
	})
}

return StateGraph("sg_gourdo_projectile", states, nil, "idle")
