local SGCommon = require "stategraphs.sg_common"
local easing = require("util.easing")

local function OnSpawnedCreature(inst, dir)
	inst.sg:GoToState("spawn_creature")
end

local events =
{
	EventHandler("spawned_creature", OnSpawnedCreature),
	EventHandler("do_tell", function(inst, time) inst.sg:GoToState("spawn_tell", time) end)
}

local states =
{
	State({
		name = "idle",
		tags = { "idle" },

		onenter = function(inst)
			SGCommon.Fns.PlayAnimOnAllLayers(inst, "idle", true)
		end,
	}),

	State({
		name = "spawn_tell",
		tags = { "busy" },

		onenter = function(inst, time)
			time = time or 1
			SGCommon.Fns.PlayAnimOnAllLayers(inst, "rustle", true)
			inst.sg.statemem.time = time
			inst.sg:SetTimeout(time)
		end,

		ontimeout = function(inst)
			inst.sg:GoToState("idle")
		end,

--[[		onupdate = function(inst)
			local s = GetSineValForState(1/inst.sg.statemem.time, true, inst.sg)
			local target_r = 100
			local target_b = 100
			local r = easing.linear(s, 0, target_r, 1)
			local g = 0
			local b = easing.linear(s, 0, target_b, 1)
			inst.components.coloradder:PushColor("tell", r/255, g/255, b/255, 1)
		end,

		onexit = function(inst)
			inst.components.coloradder:PopColor("tell")
		end,--]]

	}),

	State({
		name = "spawn_creature",
		tags = { "busy" },

		onenter = function(inst, dir)
			SGCommon.Fns.PlayAnimOnAllLayers(inst, "exit")
		end,

		onexit = function(inst)
			inst:FreeSpawner()
		end,

		events =
		{
			EventHandler("animover", function(inst)
				inst.sg:GoToState("idle")
			end),
		},
	}),
}

return StateGraph("sg_spawner_perimeter", states, events, "idle")