local SGCommon = require "stategraphs.sg_common"
local Enum = require "util.enum"

local HeliState = Enum{ "ON", "OFF" }

local function SetHeliState(inst, state)
	inst.heli_state = state
end

local function GetHeliState(inst)
	return inst.heli_state
end

local function GoToHeliState(inst, heli_state, endstate, animoverride)
	if GetHeliState(inst) == heli_state then
		-- If you're already in this state, we don't have to do anything
		return true
	end

	-- Enter the locomotion transition state & then return back to the state that called this.
	inst.sg:GoToState(string.lower(heli_state), { endstate = endstate or inst.sg.currentstate.name, animoverride = animoverride })
end

local events =
{
	EventHandler("start_heli", function(inst) GoToHeliState(inst, HeliState.s.ON, "idle") end),
	EventHandler("stop_heli", function(inst) GoToHeliState(inst, HeliState.s.OFF, "idle") end),
}

local states =
{
	State{
		name = "idle",

		onenter = function(inst)
			local heli_state = GetHeliState(inst)
			if not heli_state then
				heli_state = HeliState.s.OFF
				SetHeliState(inst, heli_state)
			end

			local state_to_anim =
			{
				[HeliState.s.OFF] = "idle",
				[HeliState.s.ON] = "spin_loop",
			}

			-- play idle anim depending on state
			SGCommon.Fns.PlayAnimOnAllLayers(inst, state_to_anim[heli_state], true)
		end,
	},

	State{
		name = "on",
        tags = {"busy", "nointerrupt"},

        onenter = function(inst, data)
            inst.Physics:Stop()
            inst.sg.statemem.endstate = data.endstate
            local anim = data.animoverride or "spin_pre"
            SGCommon.Fns.PlayAnimOnAllLayers(inst, anim)
        end,

        events =
        {
            EventHandler("animover", function(inst)
                inst.sg:GoToState(inst.sg.statemem.endstate)
            end)
        },

        onexit = function(inst)
            SetHeliState(inst, HeliState.s.ON)
        end,
	},

	State{
		name = "off",
        tags = {"busy", "nointerrupt"},

        onenter = function(inst, data)
            inst.Physics:Stop()
            inst.sg.statemem.endstate = data.endstate
            local anim = data.animoverride or "spin_pst"
            SGCommon.Fns.PlayAnimOnAllLayers(inst, anim)
        end,

        events =
        {
            EventHandler("animover", function(inst)
                inst.sg:GoToState(inst.sg.statemem.endstate)
            end)
        },

        onexit = function(inst)
            SetHeliState(inst, HeliState.s.OFF)
        end,
	},
}

return StateGraph("sg_flying_machine", states, events, "idle")