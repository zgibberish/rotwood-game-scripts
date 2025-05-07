local states =
{
	State({
		name = "thrown",
		tags = { "airborne" },
		onenter = function(inst, targetpos)
			inst.AnimState:PlayAnimation("bullet", true)
		end,
	}),
}

return StateGraph("sg_blarmadillo_projectile", states, nil, "thrown")
