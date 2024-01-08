local states =
{
	State({
		name = "thrown",
		tags = { "airborne" },
		onenter = function(inst, targetpos)
			inst.AnimState:PlayAnimation("lily_hat_spin_loop", true)
		end,
	}),
}

return StateGraph("sg_totolili_projectile", states, nil, "thrown")
