local states =
{
	State({ name = "idle",	}),
}

SGRegistry:AddData("sg_blank", states)

return StateGraph("sg_blank", states, nil, "idle")