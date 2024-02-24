--[[
StateGraph for vending machine.
A vending machine has several sub-states representing how much currency has been deposited in it. Once the full cost has
been deposited, the vending machine will emit a ware and settle into a dormant state.
]]

local SGCommon = require "stategraphs.sg_common"
local Enum = require "util.enum"
local Lume = require "util.lume"
local animutil = require "util.animutil"
local soundutil = require "util.soundutil"
local fmodtable = require "defs.sound.fmodtable"

local Funding = Enum {
	"none",
	"small",
	"medium",
	"large",
	"complete"
}

-- All of the "active" states of a vending machine behave very similarly. Here we enumerate the prototypes for all of
-- the active states, which will will subsequently inflate into actual state objects that the state graph system expects.
local ACTIVE_PROTO_STATES <const> = {
	[Funding.s.none] = {
		idle_anim = "idle",
		interact_anim = "idle",
		threshold = 0,
	},
	[Funding.s.small] = {
		idle_anim = "smallcrack_idle",
		interact_anim = "smallcrack_loop",
		threshold = 0.33,
	},
	[Funding.s.medium] = {
		idle_anim = "mediumcrack_idle",
		interact_anim = "mediumcrack_loop",
		threshold = 0.66,
	},
	[Funding.s.large] = {
		idle_anim = "largecrack_idle",
		interact_anim = "largecrack_loop",
		threshold = 1,
	},
}

local function GetFunding(vending_machine)
	local deposited_total = vending_machine:GetTotalDeposited()
	if deposited_total >= vending_machine.cost then
		return Funding.id.complete
	end
	local percent_funded = deposited_total / vending_machine.cost
	for id, s in ipairs(Funding:Ordered()) do
		if percent_funded <= ACTIVE_PROTO_STATES[s].threshold then
			return id
		end
	end
	dbassert(false, "Failed to compute Funding level. Deposited more than the cost?")
end

local function PlayActiveAnim(inst, proto_state, sync)
	local is_interacting = inst.components.vendingmachine:IsAnyPlayerInteracting()

	-- Bail immediately if the state graph's is_interacting status matches that of the component's.
	if inst.sg.mem.is_interacting == is_interacting then
		return
	end
	inst.sg.mem.is_interacting = is_interacting

	local anim = is_interacting
		and proto_state.interact_anim
		or proto_state.idle_anim
	local frame = inst.AnimState:GetCurrentAnimationFrame()
	SGCommon.Fns.PlayAnimOnAllLayers(inst, anim, true)

	-- If sync is true, sync the new animation to whatever frame the previous animation was on.
	if sync then
		-- The animation will freeze if we set an out-of-range frame. It seems that for some idle/interact anim pairs,
		-- they do not have the same frame count.
		frame = frame <= inst.AnimState:GetCurrentAnimationNumFrames()
			and frame
			or 1
		animutil.ForEachAnimState(inst, function(anim_state)
			anim_state:SetFrame(frame)
		end)
	end

	if is_interacting then
		if not inst.sg.mem.interacting_sound_handle then
			local params = {}
			params.fmodevent = fmodtable.Event.vendingMachine_fill_LP
			params.max_count = 1
			params.is_autostop = true
			inst.sg.mem.interacting_sound_handle = soundutil.PlaySoundData(inst, params)
		end
	else
		if inst.sg.mem.interacting_sound_handle then
			soundutil.KillSound(inst, inst.sg.mem.interacting_sound_handle)
			inst.sg.mem.interacting_sound_handle = nil
		end
	end
end

-- Compute the desired state based on the current funding level of the vending machine.
local function DesiredState(inst)
	local funding = GetFunding(inst.components.vendingmachine)	
	return funding == Funding.id.complete
			and "emit_ware"
			or Funding:Ordered()[funding]
end

local events =
{
	EventHandler("initialized_ware", function(inst)
		local initial_state = DesiredState(inst)
		inst.sg:GoToState(initial_state)
	end)
}

-- Inflate active proto-states into actual States.
local active_states = Lume(ACTIVE_PROTO_STATES):enumerate(function(funding_name, proto_state)
	return State {
		name = funding_name,

		onenter = function(inst)
			inst.sg.mem.funding = Funding.id[funding_name]
			-- An initial is_interacting value of nil ensures an animation gets started on entry.
			inst.sg.mem.is_interacting = nil
			PlayActiveAnim(inst, proto_state, true)

			-- sets sound progress parameter (pitch) to match the funding level threshold
			-- rougher than doing in onupdate but more performant
			if inst.sg.mem.interacting_sound_handle then
				soundutil.SetInstanceParameter(inst, inst.sg.mem.interacting_sound_handle, "progress_vendingMachine",proto_state.threshold)
			end
		end,

		onupdate = function(inst)
			local desired_state = DesiredState(inst)
			if desired_state ~= funding_name then
				inst.sg:GoToState(desired_state)
			end
		end,

		events = {
			EventHandler("is_interacting_changed", function(inst)
				PlayActiveAnim(inst, proto_state, false)
			end),
		},

	}
end):values():result()

-- Concatenate active states with explicit states.
local states = Lume.concat(active_states, {
	State {
		name = "emit_ware",

		onenter = function(inst)
			inst.components.vendingmachine:ResetAnyPlayerInteractingStatus()
			SGCommon.Fns.PlayAnimOnAllLayers(inst, "shatter_fx", false)
			if inst.sg.mem.interacting_sound_handle then
				soundutil.KillSound(inst, inst.sg.mem.interacting_sound_handle)
				inst.sg.mem.interacting_sound_handle = nil
			end
		end,

		events = {
			EventHandler("animover", function(inst)	inst.sg:GoToState("dormant") end),
		},
	},

	State {
		name = "dormant",

		onenter = function(inst)
			SGCommon.Fns.PlayAnimOnAllLayers(inst, "open", true)
		end,
	},

	State{
		name = "idle",

		onenter = function(inst)
			inst.components.vendingmachine:ResetAnyPlayerInteractingStatus()
			SGCommon.Fns.PlayAnimOnAllLayers(inst, "idle", true)
		end,
	}
})

return StateGraph("sg_vending_machine", states, events, "idle")
