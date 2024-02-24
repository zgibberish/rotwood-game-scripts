local SGCommon = require "stategraphs.sg_common"


local function PlayAnim(inst, anim, instant)
	if instant then
		SGCommon.Fns.SetAnimPercentOnAllLayers(inst, anim, 1)
	else
		SGCommon.Fns.PlayAnimOnAllLayers(inst, anim)
	end
end


local states =
{
	State({
			name = "blocked",
			tags = { "idle" },

			onenter = function(inst)
				PlayAnim(inst, "blocked", true)
			end,
		}),

	State({
			-- The locked state.
			name = "idle",
			tags = { "idle" },

			onenter = function(inst, instant)
				PlayAnim(inst, "idle", instant)
			end,
		}),

	State({
			name = "open",
			tags = { "idle" },

			onenter = function(inst, instant)
				PlayAnim(inst, "open", instant)
				inst.Physics:SetEnabled(false)
			end,

			onexit = function(inst)
				inst.Physics:SetEnabled(true)
			end,
		}),
}

local events =
{
}

return StateGraph("sg_roomgate", states, events, "idle")
