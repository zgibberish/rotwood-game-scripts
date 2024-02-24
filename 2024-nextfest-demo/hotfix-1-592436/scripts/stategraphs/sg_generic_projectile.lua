local states =
{
	State({
		name = "thrown",
		tags = { "airborne" },
	}),
}

return StateGraph("sg_generic_projectile", states, nil, "thrown")