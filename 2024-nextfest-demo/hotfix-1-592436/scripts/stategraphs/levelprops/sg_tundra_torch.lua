local SGCommon = require("stategraphs/sg_common")
local ParticleSystemHelper = require "util.particlesystemhelper"
local EffectEvents = require "effectevents"
local fmodtable = require "defs.sound.fmodtable"
local soundutil = require "util.soundutil"

local function OnTorchHitBoxTriggered(inst, data)
end

local events =
{
	EventHandler("attacked", function(inst, data)
		inst.sg:GoToState("hit", data)
	end),
}

local states =
{
    State({
		name = "idle",
		tags = { "idle" },

		onenter = function(inst)
			SGCommon.Fns.PlayAnimOnAllLayers(inst, "1", true)
		end,
	}),

	State({
        name = "hit",
        tags = { "hit", "busy" },

		default_data_for_tools = { front = true },

        onenter = function(inst, data)
			local anim = data.front and "hit_r_1" or "hit_l_1"
			SGCommon.Fns.PlayAnimOnAllLayers(inst, anim)
        end,

        events =
		{
			EventHandler("animover", function(inst)
				inst.sg:GoToState("idle")
			end),
		},
    }),

	State({
		name = "light_up",
		tags = { "busy" },

		onenter = function(inst)
			SGCommon.Fns.PlayAnimOnAllLayers(inst, "hidden_1")
		end,

		events =
		{
			EventHandler("animover", function(inst)
				inst.sg:GoToState("light_up_idle")
			end),
		},
	}),

	State({
		name = "light_up_idle",
		tags = { "idle" },

		onenter = function(inst)
			SGCommon.Fns.PlayAnimOnAllLayers(inst, "hidden_1", true)
		end,
	}),

	State({
		name = "turn_off",
		tags = { "idle" },

		onenter = function(inst)
			SGCommon.Fns.PlayAnimOnAllLayers(inst, "hit_r_1", true)
		end,

		events =
		{
			EventHandler("animover", function(inst)
				inst.sg:GoToState("idle")
			end),
		},
	}),
}

return StateGraph("sg_tundra_torch", states, events, "idle")
