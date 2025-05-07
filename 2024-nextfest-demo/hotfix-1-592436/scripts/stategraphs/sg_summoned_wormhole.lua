local events =
{
	EventHandler("unsummon", function(inst) inst.sg:GoToState("unsummon") end),
	EventHandler("teleported_to", function(inst) inst.sg:GoToState("teleport") end)
}

local states =
{
	State({
		name = "idle",
		tags = { },

		onenter = function(inst)
			inst.AnimState:PlayAnimation("loop_4", true)
		end,
	}),

	State({
		name = "teleport",
		tags = { },

		onenter = function(inst)
			inst.AnimState:PlayAnimation("pulse", true)
			inst.sg:SetTimeoutTicks(30)
		end,

		ontimeout = function(inst)
			inst.sg:GoToState("idle") --JAMBELL TEMP,
		end,
	}),

	State({
		name = "summon",
		tags = { },

		onenter = function(inst)
			inst.AnimState:PlayAnimation("in_4")
		end,

		events =
		{
			EventHandler("animover", function(inst)
				inst.sg:GoToState("idle")
			end),
		},

		onexit = function(inst)
			inst.components.wormhole:EnableTeleport(true)
		end,
	}),

	State({
		name = "unsummon",
		tags = { },

		onenter = function(inst)
			inst.AnimState:PlayAnimation("out_4")
			inst.AnimState:SetDeltaTimeMultiplier(2)
		end,

		events =
		{
			EventHandler("animover", function(inst)
				if inst:IsValid() then
					inst:Remove()
				end
			end),
		},
	}),
}

return StateGraph("sg_summoned_wormhole", states, events, "summon")
