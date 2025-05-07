local SGCommon = require "stategraphs.sg_common"
local Enum = require "util.enum"

local PillarState = Enum{ "CLOSED", "OPEN" }

local function SetPillarState(inst, state)
	inst.pillar_state = state
end

local function GetPillarState(inst)
	return inst.pillar_state
end

local function GoToPillarState(inst, pillar_state, endstate, animoverride)
	if GetPillarState(inst) == pillar_state then
		-- If you're already in this state, we don't have to do anything
		return true
	end

	-- Enter the locomotion transition state & then return back to the state that called this.
	inst.sg:GoToState(string.lower(pillar_state), { endstate = endstate or inst.sg.currentstate.name, animoverride = animoverride })
end

local events =
{
	EventHandler("open_pillar", function(inst) GoToPillarState(inst, PillarState.s.OPEN, "idle") end),
	EventHandler("close_pillar", function(inst) GoToPillarState(inst, PillarState.s.CLOSED, "idle") end),
	EventHandler("deposit_heart", function(inst) inst.sg:GoToState("activate") end),
}

local states =
{
	State{
		name = "idle",

		onenter = function(inst)
			local pillar_state = GetPillarState(inst)
			if not pillar_state then
				pillar_state = PillarState.s.CLOSED
				SetPillarState(inst, pillar_state)
			end

			local state_to_anim =
			{
				[PillarState.s.CLOSED] = "closed",
				[PillarState.s.OPEN] = "idle",
			}

			-- play idle anim depending on pillar state
			SGCommon.Fns.PlayAnimOnAllLayers(inst, state_to_anim[pillar_state], true)
		end,

		events =
		{
			EventHandler("animover", function(inst)
				-- double check your state and transition if needed
				local players = inst.components.playerproxradial:FindPlayersInRange()
				local nearby_player_can_deposit = inst.components.heartdeposit:IsAnyPlayerEligible(players)
				if not nearby_player_can_deposit and GetPillarState(inst) == PillarState.s.OPEN then
					inst:PushEvent("close_pillar")
				elseif nearby_player_can_deposit and GetPillarState(inst) == PillarState.s.CLOSED then
					inst:PushEvent("open_pillar")
				end
			end),
		},
	},

	State{
		name = "open",
        tags = {"busy", "nointerrupt"},

        onenter = function(inst, data)
            inst.Physics:Stop()
            inst.sg.statemem.endstate = data.endstate
            local anim = data.animoverride or "open"
            SGCommon.Fns.PlayAnimOnAllLayers(inst, anim)
        end,

        events =
        {
            EventHandler("animover", function(inst)
                inst.sg:GoToState(inst.sg.statemem.endstate)
            end)
        },

        onexit = function(inst)
            SetPillarState(inst, PillarState.s.OPEN)
        end,
	},

	State{
		name = "closed",
        tags = {"busy", "nointerrupt"},

        onenter = function(inst, data)
            inst.Physics:Stop()
            inst.sg.statemem.endstate = data.endstate
            local anim = data.animoverride or "closing"
            SGCommon.Fns.PlayAnimOnAllLayers(inst, anim)
        end,

        events =
        {
            EventHandler("animover", function(inst)
                inst.sg:GoToState(inst.sg.statemem.endstate)
            end)
        },

        onexit = function(inst)
            SetPillarState(inst, PillarState.s.CLOSED)
        end,
	},

	State{
		-- is entered through the cutscene.
		name = "activate",

		onenter = function(inst)
			SGCommon.Fns.PlayAnimOnAllLayers(inst, "activate")
		end,

        events =
        {
            EventHandler("animover", function(inst)
                inst.sg:GoToState("idle")
            end)
        },
	}
}

return StateGraph("sg_town_pillar", states, events, "idle")