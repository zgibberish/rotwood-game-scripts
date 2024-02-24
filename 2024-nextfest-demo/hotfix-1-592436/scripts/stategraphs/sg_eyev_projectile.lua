local states =
{
	State({
		name = "thrown",
		tags = { "airborne" },
		onenter = function(inst)
			inst.AnimState:PlayAnimation("razor_leaf", true)
		end,
	}),
}

return StateGraph("sg_eyev_projectile", states, nil, "thrown")
