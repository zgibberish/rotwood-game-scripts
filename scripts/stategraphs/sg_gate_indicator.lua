local soundutil = require "util.soundutil"
local fmodtable = require "defs.sound.fmodtable"

local RADIUS = 5
local function OnNear(inst)
	inst.sg:GoToState("excited")
end

local function OnFar(inst)
	inst.sg:GoToState("unlocked")
end

local function CancelUnlock(inst)
	local task = inst.sg.mem.unlock_task
	if task then
		inst.sg.mem.unlock_task = nil
		task:Cancel()
	end
end

local function CancelExcite(inst)
	local task = inst.sg.mem.excite_task
	if task then
		inst.sg.mem.excite_task = nil
		task:Cancel()
	end
end

local function IsAPlayerInTheTrap(gate, radius)
	local is_player_in_trap
	local is_local_player_in_trap
	local dist
	for k, player in pairs(AllPlayers) do
		if player:IsAlive() then
			dist = gate:GetDistanceSqTo(player)
			if dist <= radius then
				is_player_in_trap = true
				if player:IsLocal() then
					is_local_player_in_trap = true
				end
			end
		end
	end
	return is_player_in_trap, is_local_player_in_trap, dist
end

local states =
{
	State({
			name = "init",
			tags = { "idle" },

			onenter = function(inst)
				-- Add component here to ensure it's available in sg.
				inst:AddComponent("playerproxradial")
					:SetRadius(RADIUS) -- overridden by indicator_bloom.nearby_radius
					:SetBuffer(2)
			end,
		}),

	State({
			name = "locked",
			tags = { "idle" },

			onenter = function(inst)
				CancelUnlock(inst)
				CancelExcite(inst)
				-- Disable proximity.
				inst.components.playerproxradial:SetOnNearFn()
				inst.components.playerproxradial:SetOnFarFn()
				-- Might not have it if spawned from propeditor
				if inst.SetIndicatorUnlockProgress then
					inst:SetIndicatorUnlockProgress(0)
					inst:SetIndicatorExciteProgress(0)
				end
			end,

			onexit = function(inst)
				-- If we're not locked, then we want unlock effect applied.
				inst.sg.mem.unlock_task = inst:UnlockIndicator()
				inst.components.playerproxradial:SetOnNearFn(OnNear)
				inst.components.playerproxradial:SetOnFarFn(OnFar)
			end,
		}),

	State({
			name = "unlocked",
			tags = { "busy" },

			onenter = function(inst)
			end,
		}),

	State({
			name = "excited",
			tags = { "idle" },

			onenter = function(inst)
				CancelExcite(inst)
				inst.sg.mem.excite_task = inst:ExciteIndicator()
				--sound
				local params = {}
				params.fmodevent = fmodtable.Event.gateIndicator_particles_LP
				params.autostop = true
				inst.sg.statemem.looping_sound = soundutil.PlaySoundData(inst, params)
			end,

			onupdate = function(inst)
				--local is_player_in_trap, is_local_player_in_trap, dist = IsAPlayerInTheTrap(inst, RADIUS)
				--soundutil.SetLocalInstanceParameter(inst, inst.sg.statemem.looping_sound, "isLocalPlayerInTrap", is_local_player_in_trap and 1 or 0)
				--soundutil.SetLocalInstanceParameter(inst, inst.sg.statemem.looping_sound, "distanceToNearestPlayer", dist)
			end,

			onexit = function(inst)
				CancelExcite(inst)
				inst.sg.mem.excite_task = inst:ExciteIndicator("invert")
				--sound
				soundutil.KillSound(inst, inst.sg.statemem.looping_sound)
				local params = {}
				params.fmodevent = fmodtable.Event.gateIndicator_fade
				soundutil.PlaySoundData(inst, params)
			end,
		}),
}

local events =
{
}

return StateGraph("sg_gate_indicator", states, events, "init")
