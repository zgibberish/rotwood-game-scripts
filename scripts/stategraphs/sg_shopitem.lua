local SGCommon = require "stategraphs.sg_common"
local Enum = require "util.enum"
local Strict = require "util.strict"

local STATES = Enum {
	"spawn",
	"idle",
	"despawn"
}

local STANDARD_ANIMATIONS <const> = {
	[STATES.s.spawn] = "pop",
	[STATES.s.idle] = "idle",
	[STATES.s.despawn] = "shatter",
}
Strict.strictify(STANDARD_ANIMATIONS)

local ALTERNATE_ANIMATIONS <const> = {
	[STATES.s.spawn] = "pop",
	[STATES.s.idle] = "idle",
	[STATES.s.despawn] = "despawn",
}
Strict.strictify(ALTERNATE_ANIMATIONS)

local function PlayAnimForState(inst, state, loop)
	local anim = inst.sg.mem.use_alternate_anims
		and ALTERNATE_ANIMATIONS[state]
		or STANDARD_ANIMATIONS[state]
	TheLog.ch.AnimSpam:printf("sg_shopitem:PlayAnim() %s -> %s", state, anim)
	SGCommon.Fns.PlayAnimOnAllLayers(inst, anim, loop)
end

-- This state graph is induced locally for the despawn state. When this occurs, the local instance has lost all state
-- that the original host-owned state graph had: do our best to resurrect that state.
local function InitializeForLocalPlayback(inst, params)
	local interactable = inst.components.interactable
	if interactable then
		interactable:SetInteractCondition_Never()
	end

	local source_ware_visualizer = params.instigator.components.warevisualizer
	if source_ware_visualizer then
		inst:PushEvent("initialized_ware", {
			ware_name = source_ware_visualizer.ware_name,
			power = source_ware_visualizer.power,
			power_type = source_ware_visualizer.power_type
		})
	end
end

local events =
{
	EventHandler("despawn", function(inst) inst.sg:GoToState(STATES.s.despawn) end),
	EventHandler("spawned_local_entity", function(inst, params) InitializeForLocalPlayback(inst, params) end),
}

local states =
{
	State({
		name = STATES.s.spawn,
		tags = { "busy" },

		onenter = function(inst)
			PlayAnimForState(inst, STATES.s.spawn)
		end,

		events =
		{
			EventHandler("animover", function(inst)
				inst.sg:GoToState(STATES.s.idle)
			end),
		},
	}),

	State({
		name = STATES.s.idle,
		tags = { "idle" },

		onenter = function(inst)
			PlayAnimForState(inst, STATES.s.idle, true)
			-- enable interaction
		end,
	}),

	State({
		name = STATES.s.despawn,
		tags = { "busy" },

		onenter = function(inst)
			PlayAnimForState(inst,  STATES.s.despawn)
		end,

		events =
		{
			EventHandler("animover", function(inst)
				inst:DelayedRemove()
			end),
		},
	}),
}

return StateGraph("sg_shopitem", states, events, STATES.s.spawn)
