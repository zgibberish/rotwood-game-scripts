local events =
{
}

local states =
{
	State({
		name = "idle",
		tags = { "idle" },
	}),
}

return StateGraph("sg_spawner_miniboss", states, events, "idle")