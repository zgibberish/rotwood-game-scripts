local states =
{
	State({
		name = "spawn",

		onenter = function(inst)
			inst.sg.statemem.fx = SpawnPrefab("fx_battoad_acid_ground_land", inst)
			inst.sg.statemem.fx.entity:SetParent(inst.entity)
			inst.sg:SetTimeoutTicks(24)
		end,

		onexit = function(inst)
			inst.sg.statemem.fx:Remove()
		end,

		ontimeout = function(inst)
			inst.sg:GoToState("aoe")
		end,
	}),

	State({
		name = "aoe",

		onenter = function(inst, pos)
			inst.sg.statemem.fx = SpawnPrefab("fx_battoad_acid_ground_loop", inst)
			inst.sg.statemem.fx.entity:SetParent(inst.entity)
			inst.sg:SetTimeout(4)
		end,

		onupdate = function(inst)
			inst.components.jointaoechild:PushHitBox()
		end,

		ontimeout = function(inst)
			inst.sg:GoToState("despawn")
		end,

		onexit = function(inst)
			inst.sg.statemem.fx:Remove()
		end,
	}),

	State({
		name = "despawn",

		onenter = function(inst, pos)
			-- inst.sg.statemem.fx = SpawnPrefab("fx_battoad_acid_ground_pst", inst)
			-- inst.sg.statemem.fx.entity:SetParent(inst.entity)
			inst.sg:SetTimeoutTicks(52)
		end,

		ontimeout = function(inst)
			inst:Remove()
		end,
	}),
}

return StateGraph("sg_mossquito_aoe", states, nil, "spawn")
