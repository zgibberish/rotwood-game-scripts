local SGCommon = require "stategraphs.sg_common"

local SHUDDER_ANIMFRAMES = 10

local function OnSpawnedCreature(inst, creature)
	inst.sg:GoToState("spawn_creature")
end

local events =
{
	EventHandler("spawned_creature", OnSpawnedCreature)
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
		name = "spawn_creature",
		tags = { "idle" },

		onenter = function(inst)
			inst.components.hitshudder:DoShudder(15, SHUDDER_ANIMFRAMES)
			inst.sg:SetTimeoutAnimFrames(10)
		end,

		onexit = function(inst)
			inst:FreeSpawner()
		end,

		ontimeout = function(inst)
			inst.sg:GoToState("idle")
		end,
	}),
}

return StateGraph("sg_spawner_small", states, events, "idle")
