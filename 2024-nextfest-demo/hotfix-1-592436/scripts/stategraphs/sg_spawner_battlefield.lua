local SGCommon = require "stategraphs.sg_common"

local function OnSpawnedCreature(inst)
	local dir = inst:GetSpawnAngle()
	inst.sg:GoToState("spawn_creature", dir)
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
			SGCommon.Fns.PlayAnimOnAllLayers(inst, "rustle", true)
			inst.sg.statemem.time = time
			inst.sg:SetTimeout(time)
		end,

		ontimeout = function(inst)
			inst.sg:GoToState("waiting_to_spawn")
		end,
	}),

	State({
		name = "waiting_to_spawn",
		tags = {"busy"},

		onenter = function(inst)
			SGCommon.Fns.PlayAnimOnAllLayers(inst, "idle", true)
			inst.sg:SetTimeout(5)
		end,

		ontimeout = function(inst)
			-- ideally, this will never happen
			-- if it does, something went wrong and we just want to go back to idle.
			inst:FreeSpawner()
			inst.sg:GoToState("idle")
		end,
	}),

	State({
		name = "spawn_creature",
		tags = { "busy" },

		onenter = function(inst, dir)
			dir = DiffAngle(0, dir)
			if dir < 90 then
				SGCommon.Fns.PlayAnimOnAllLayers(inst, "exit_east")
			else
				SGCommon.Fns.PlayAnimOnAllLayers(inst, "exit_west")
			end
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

return StateGraph("sg_spawner_battlefield", states, events, "idle")