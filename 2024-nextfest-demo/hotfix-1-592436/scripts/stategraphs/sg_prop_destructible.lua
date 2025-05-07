local SGCommon = require "stategraphs.sg_common"

local BROKEN_HEALTH_PERCENT = 0.5

local HITSTUN_FRAMES = 1 -- Set to 0 to skip the 'hold' anim entirely.
						 -- Set to 1 to hold the 'hold' anim only for hitstop frames.
						 -- Set >1 to hold 'hold' for longer.

						 -- Breaking the precedent of the rest of the game, this prop actually decides how much hitstun applies to it.
						 -- I had a bunch of other modifiers and min/maxes to adjust the incoming hitstun, but ultimately this is easier and more reliable.

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

local function GetNextState(inst)
	local nextstate
	if inst.sg.mem.broken then
		nextstate = "idle_broken"
	else
		nextstate = "idle"
	end
	return nextstate
end

local events =
{
	EventHandler("attacked", function(inst, data)
		local health = inst.components.health:GetPercent()
		if health <= 0 then
			inst.sg:ForceGoToState("death", data)
		else
			SGCommon.Fns.OnAttacked(inst, data)
			local right = not IsRightDir(data ~= nil and data.attack:GetDir() or nil)
			data.right = right

			if inst.sg.mem.broken then
				inst.sg:GoToState("hit_hold_broken", data)
			elseif health <= BROKEN_HEALTH_PERCENT then
				inst:SpawnHitRubble(data.right)
				inst.sg:GoToState("hit_hold_broken", data)
				inst.sg.mem.broken = true
			else
				inst.sg:GoToState("hit_hold_healthy", data)
			end
		end
	end),
	SGCommon.Events.OnDying(),
}

local states =
{
	State({
		name = "idle",
		tags = { "idle" },

		onenter = function(inst)
			inst.sg.mem.broken = false
			if not inst.AnimState:IsCurrentAnimation(inst.baseanim) then
				SGCommon.Fns.PlayAnimOnAllLayers(inst, "", true)
			end
		end,
	}),

	State({
		name = "idle_broken",
		tags = { "idle" },

		onenter = function(inst)
			SGCommon.Fns.PlayAnimOnAllLayers(inst, "broken", true)
		end,
	}),

	State({ name = "hit" }),

	State({
		name = "hit_hold_healthy",
		tags = { "hit", "busy" },

		onenter = function(inst, data)
			SGCommon.Fns.PlayAnimOnAllLayers(inst, data.right and "hit_r_hold" or "hit_l_hold")
			inst:SpawnHitRubble(data.right)

			inst.sg.statemem.attackdata = data

			inst.sg:SetTimeoutAnimFrames(HITSTUN_FRAMES)
		end,

		ontimeout = function(inst)
			inst.sg:GoToState("hit_healthy", inst.sg.statemem.attackdata)
		end,
	}),

	State({
		name = "hit_healthy",
		tags = { "hit", "busy" },

		onenter = function(inst, data)
			SGCommon.Fns.PlayAnimOnAllLayers(inst, data.right and "hit_r" or "hit_l")
		end,

		onexit = function(inst)
			inst.sg:RemoveStateTag("busy")
			inst.sg.statemem.nextstate = "idle"
		end,

		events =
		{
			EventHandler("animover", function(inst)
				inst.sg:GoToState(GetNextState(inst))
			end),
		},
	}),

	State({
		name = "hit_hold_broken",
		tags = { "hit", "busy" },

		onenter = function(inst, data)
			-- play some FX
			SGCommon.Fns.PlayAnimOnAllLayers(inst, data.right and "broken_hit_r_hold" or "broken_hit_l_hold")
			inst:SpawnHitRubble(data.right)

			inst.sg.statemem.attackdata = data

			inst.sg:SetTimeoutAnimFrames(HITSTUN_FRAMES)
		end,

		ontimeout = function(inst)
			inst.sg:GoToState("hit_broken", inst.sg.statemem.attackdata)
		end,
	}),

	State({
		name = "hit_broken",
		tags = { "hit", "busy" },

		onenter = function(inst, data)
			-- play some FX
			SGCommon.Fns.PlayAnimOnAllLayers(inst, data.right and "broken_hit_r" or "broken_hit_l")
		end,

		onexit = function(inst)
			inst.sg:RemoveStateTag("busy")
		end,

		events =
		{
			EventHandler("animover", function(inst)
				inst.sg:GoToState(GetNextState(inst))
			end),
		},
	}),

	State({
		name = "death",
		tags = { "busy" },

		onenter = function(inst, right)
			SGCommon.Fns.PlayAnimOnAllLayers(inst, "shatter_fx")
			inst.Physics:SetEnabled(false)
			inst.HitBox:SetEnabled(false)
		end,

		onexit = function(inst)

		end,

		events =
		{
			EventHandler("animover", function(inst)
				inst.sg:GoToState("dead")
			end),
		},
	}),

	State({
		name = "dead",
		tags = { "busy" },

		onenter = function(inst)
			SGCommon.Fns.PlayAnimOnAllLayers(inst, "shattered")
		end,

		events =
		{
			EventHandler("animover", function(inst)
				inst:PushControlToHost()
			end),
		},
	}),

}

return StateGraph("sg_prop_destructible", states, events, "idle")
