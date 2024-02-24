local SGCommon = require("stategraphs/sg_common")

local function IsRightDir(dir)
	if dir ~= nil then
		if dir > -90 and dir < 90 then
			return true
		elseif dir < -90 or dir > 90 then
			return false
		end
	end
	return math.random() < .5
end

local events =
{
	SGCommon.Events.OnKnockback(),

	EventHandler("attacked", function(inst, data)
		SGCommon.Fns.OnAttacked(inst, data)
		if inst.sg:GetCurrentState() == "hit" then
			local right = not IsRightDir(data ~= nil and data.attack ~= nil and data.attack:GetDir())
			inst.sg:GoToState("hit_actual", right)
		end
	end),
}

local states =
{
	State({
		name = "idle",
		tags = { "idle", "nokill" },

		onenter = function(inst)
			SGCommon.Fns.PlayAnimOnAllLayers(inst, "")
		end,
	}),

	State({ name = "hit" }),
	State({
		name = "hit_actual",
		tags = { "hit", "busy", "nokill" },

		onenter = function(inst, right)
			SGCommon.Fns.PlayAnimOnAllLayers(inst, right and "hit_r" or "hit_l")
		end,

		timeline =
		{
			FrameEvent(6, function(inst)
				inst.sg:RemoveStateTag("busy")
			end),
		},

		events =
		{
			EventHandler("animover", function(inst)
				inst.sg:GoToState("idle")
			end),
		},
	}),

	State({
		name = "knockback",
		tags = { "hit", "knockback", "busy", "nointerrupt", "nokill" },

		onenter = function(inst)
			local right = IsRightDir(inst.Transform:GetRotation())
			inst.Transform:SetRotation(0)
			SGCommon.Fns.PlayAnimOnAllLayers(inst, right and "hit_hard_r" or "hit_hard_l")
		end,

		timeline =
		{
			FrameEvent(6, function(inst)
				inst.sg:RemoveStateTag("busy")
				inst.sg:RemoveStateTag("nointerrupt")
			end),
		},

		events =
		{
			EventHandler("animover", function(inst)
				inst.sg:GoToState("idle")
			end),
		},
	}),
}

return StateGraph("sg_dummy", states, events, "idle")
