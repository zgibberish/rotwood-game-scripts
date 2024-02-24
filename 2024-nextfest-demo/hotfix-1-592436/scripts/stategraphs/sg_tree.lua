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
	EventHandler("attacked", function(inst, data)
		if data ~= nil and data.attacker ~= nil then
			inst.sg.mem.lasthitdir = inst:GetAngleTo(data.attacker)
		end
		SGCommon.Fns.OnAttacked(inst, data)
		if inst.sg:GetCurrentState() == "hit" then
			local right = not IsRightDir(data ~= nil and data.attack:GetDir() or nil)
			inst.sg:GoToState("hit_actual", right)
		end
	end),
	EventHandler("knockback", function(inst, data)
		if data ~= nil and data.attacker ~= nil then
			inst.sg.mem.lasthitdir = inst:GetAngleTo(data.attacker)
		end
		SGCommon.Fns.OnKnockback(inst, data)
	end),
}

local states =
{
	State({
		name = "idle",
		tags = { "idle" },

		onenter = function(inst)
			if not inst.AnimState:IsCurrentAnimation(inst.baseanim) then
				SGCommon.Fns.PlayAnimOnAllLayers(inst, "", true)
			end
		end,
	}),

	State({ name = "hit" }),
	State({
		name = "hit_actual",
		tags = { "hit", "busy" },

		onenter = function(inst, right)
			SGCommon.Fns.PlayAnimOnAllLayers(inst, right and "hit_r" or "hit_l")
		end,

		timeline =
		{
			FrameEvent(8, function(inst)
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

		onenter = function(inst)
			local right = IsRightDir(inst.Transform:GetRotation())
			inst.Transform:SetRotation(0)
			inst.sg:GoToState("hit_actual", right)
		end,
	}),
}

return StateGraph("sg_tree", states, events, "idle")
