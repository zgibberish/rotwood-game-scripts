local SGCommon = require "stategraphs.sg_common"
local SGPlayerCommon = require "stategraphs.sg_player_common"
local fmodtable = require "defs.sound.fmodtable"

local events = {}
SGPlayerCommon.Events.AddAllBasicEvents(events)

local states =
{
	State({
		name = "default_light_attack",
		onenter = function(inst)
			return
			--inst.sg:GoToState("light_attack")
		end,
	}),

	State({
		name = "default_heavy_attack",
		onenter = function(inst)
			return
			--inst.sg:GoToState("heavy_attack")
		end,
	}),

	State({
		name = "default_dodge",
		onenter = function(inst) inst.sg:GoToState("roll_pre") end,
	}),
}
SGPlayerCommon.States.AddAllBasicStates(states)
SGPlayerCommon.States.AddRollStates(states)

return StateGraph("sg_player_weaponprototype", states, events, "idle")
