-- THIS ENTITY SHOULD ALWAYS BE SPAWNED ON ALL LOCAL MACHINES
local SGCommon = require "stategraphs.sg_common"

local function OnProximityHitBoxTriggered(inst, data)
	for _, target in ipairs(data.targets) do
		if target ~= inst.owner then
			-- If swallowed a prop, remove it.
			if target:HasTag("prop") then
				target:TakeControl()
				target:Remove()
			else
				--inst.owner:TakeControl()
				SGCommon.Fns.OnSwallowed(target, {swallower = inst.owner} )
			end
		end
	end
end

local events =
{
}

local states =
{
	State({
		name = "idle",
		tags = { "idle" },

		onenter = function(inst)
			inst.sg:SetTimeoutAnimFrames(5)
			inst.components.hitbox:StartRepeatTargetDelay()
		end,

		ontimeout = function(inst)
			inst.sg:GoToState("destroying")
		end,

		onupdate = function(inst)
			inst.components.hitbox:PushCircle(0.00, 0.00, 2.00, HitPriority.MOB_DEFAULT)
		end,

		events =
		{
			EventHandler("hitboxtriggered", OnProximityHitBoxTriggered),
		},

		onexit = function(inst)
			inst.components.hitbox:StopRepeatTargetDelay()
		end,
	}),

	State({
		name = "destroying",
		tags = { },

		onenter = function(inst)
			inst:DelayedRemove()
		end,
	}),
}

return StateGraph("sg_groak_spawn_swallow", states, events, "idle")
