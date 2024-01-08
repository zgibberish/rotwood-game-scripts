local SGCommon = require "stategraphs.sg_common"
local Power = require "defs.powers.power"

local events =
{
	EventHandler("despawn", function(inst) inst.sg:GoToState("despawn") end),
	EventHandler("selfdestruct_hint", function(inst) inst.sg:GoToState("1p_selfdestruct_hint") end),
	EventHandler("selfdestruct_abort", function(inst) inst.sg:GoToState("idle") end),
}

local states =
{
	State({
		-- Can't do anything with powerdrop until it's fully created.
		name = "uninit",
		tags = { "busy" },

		onenter = function(inst)
			inst:Hide()
		end,
	}),
	State({
		-- We must spawn this object immediately to keep the room locked, so
		-- let it sit hidden until it should actually appear.
		name = "spawn_pre",
		tags = { "busy" },

		onenter = function(inst)
			inst:Hide()
			local powerdrop = inst.core_drop.components.souldrop ~= nil and inst.core_drop.components.souldrop or inst.core_drop.components.powerdrop
			local initial_ticks = powerdrop:GetAppearDelay()
			local spawn_order = powerdrop:GetSpawnOrder()
			local sequence_ticks = spawn_order > 1 and spawn_order * TUNING.POWERS.DROP_SPAWN_SEQUENCE_DELAY_FRAMES_FABLED or 0
			inst.sg:SetTimeoutTicks(initial_ticks + sequence_ticks)
		end,

		ontimeout = function(inst)
			inst.sg:GoToState("spawn")
		end,

		onexit = function(inst)
			inst:Show()
		end,

		events =
		{
		},
	}),
	State({
		name = "spawn",
		tags = { "busy" },

		onenter = function(inst)
			SGCommon.Fns.PlayAnimOnAllLayers(inst, "spawn")
		end,

		timeline =
		{
		},
		events =
		{
			EventHandler("animover", function(inst)
				inst.sg:GoToState("idle")
			end),
		},
	}),

	State({
		name = "idle",
		tags = { "idle" },

		onenter = function(inst)
			SGCommon.Fns.PlayAnimOnAllLayers(inst, "idle", true)
			local powerdrop = inst.core_drop.components.souldrop ~= nil and inst.core_drop.components.souldrop or inst.core_drop.components.powerdrop
			powerdrop:AllowInteraction()
		end,
	}),

	State({
		name = "despawn",
		tags = { "busy" },

		onenter = function(inst)
			SGCommon.Fns.PlayAnimOnAllLayers(inst, "shatter")
		end,

		events =
		{
			EventHandler("animover", function(inst)
				-- TODO: networking2022, this code is kind of gross and needs to be sorted out more robustly
				if inst.core_drop and inst.core_drop:IsValid() and inst.core_drop:IsLocal() and not inst.core_drop:IsInLimbo() then
					if inst.core_drop.components.rotatingdrop:GetDropCount() == 0 then
						TheLog.ch.RotatingDrop:printf("Scheduling delayed removal of core drop")
						local core_drop = inst.core_drop
						core_drop:DoTaskInTime(2, function()
							TheLog.ch.RotatingDrop:printf("Starting delayed removal of core drop")
							if core_drop and core_drop:IsValid() then
								core_drop:DelayedRemove()
							end
						end)
					end
				end
				if inst:IsLocal() then
					inst:DelayedRemove()
				end
			end),
		},
	}),

	State({
		-- When the powerdrop is going to destroy itself because single player
		-- only gets to pick one.
		name = "1p_selfdestruct_hint",
		tags = { "idle" },

		onenter = function(inst)
			SGCommon.Fns.PlayAnimOnAllLayers(inst, "shake", true)
			inst.components.colormultiplier:PushColor("1p_selfdestruct_hint", 1,1,1, 0.25)
		end,

		onexit = function(inst, currentstate, nextstate)
			if nextstate.name == "idle" then
				inst.components.colormultiplier:PopColor("1p_selfdestruct_hint")
			end
		end,
	}),

}

return StateGraph("sg_rotating_drop", states, events, "uninit")
