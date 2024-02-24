local SGCommon = require "stategraphs.sg_common"
local soundutil = require "util.soundutil"
local fmodtable = require "defs.sound.fmodtable"

local function UpdateLoopingSound(inst)
	local nearest_living_player = inst:GetClosestPlayer(true)
	if nearest_living_player then
		local dist = inst:GetDistanceSqTo(nearest_living_player) / 10

		soundutil.SetInstanceParameter(inst, inst.sg.mem.looping_sound, "distanceToNearestPlayer", dist)
	end
end

local states = {
	State {
		name = "idle",
		onenter = function(inst)
			SGCommon.Fns.PlayAnimOnAllLayers(inst, "idle", true)
			if inst.components.vendingmachine:IsAnyPlayerInteracting() then
				inst.sg:GoToState("heal_loop")
			end
			--sound
			if not inst.sg.mem.looping_sound then
				local params = {}
				params.fmodevent = fmodtable.Event.healingFountain_LP
				params.max_count = 1
				inst.sg.mem.looping_sound = soundutil.PlaySoundData(inst, params)
				soundutil.SetInstanceParameter(inst, inst.sg.mem.looping_sound, "isInteracting", 0)
				--soundutil.SetInstanceParameter(source, handle, "parameter", value)
			elseif inst.sg.mem.looping_sound then
				soundutil.SetInstanceParameter(inst, inst.sg.mem.looping_sound, "isInteracting", 0)
			end
		end,
		onupdate = function(inst)
			UpdateLoopingSound(inst)
		end,
		events = {
			EventHandler("is_interacting_changed", function(inst) 
				if inst.components.vendingmachine:IsAnyPlayerInteracting() then 
					inst.sg:GoToState("heal_loop") 
					if inst.sg.mem.looping_sound then
						soundutil.SetInstanceParameter(inst, inst.sg.mem.looping_sound, "isInteracting", 1)
					end
				end
			end),
		},
	},
	State {
		name = "heal_loop",
		onenter = function(inst)
			SGCommon.Fns.PlayAnimOnAllLayers(inst, "heal_loop", false)
			if not inst.components.vendingmachine:IsAnyPlayerInteracting() then
				if inst.sg.mem.looping_sound then
					soundutil.SetInstanceParameter(inst, inst.sg.mem.looping_sound, "isInteracting", 0)
				end
				inst.sg:GoToState("idle")
			end

			-- local params = {}
			-- params.fmodevent = fmodtable.Event.healingFountain_sip
			-- soundutil.PlaySoundData(inst, params)
		end,
		onupdate = function(inst)
			-- vending_machine:GetRemainingCost() is the health remaining in the healing fountain.
			local vending_machine = inst.components.vendingmachine
			if vending_machine:GetRemainingCost() == 0 then
				inst.sg:GoToState("finish")
			end			
			-- -- TODO @luca #heal
			-- soundutil.SetInstanceParameter(
			-- 	inst,
			-- 	inst.sg.mem.interacting_sound_handle, 
			-- 	"progress", 
			-- 	fountain.health / fountain.max
			-- )
		end,
		onexit = function(inst)			
		end,
		events = {
			EventHandler("animover", function(inst)	
				if inst.components.vendingmachine:IsAnyPlayerInteracting() then 
					SGCommon.Fns.PlayAnimOnAllLayers(inst, "heal_loop", false)
				else
					inst.sg:GoToState("idle") 
				end
			end),
		},
	},
	State {
		name = "finish",
		onenter = function(inst)
			SGCommon.Fns.PlayAnimOnAllLayers(inst, "finish", false)
			if inst.sg.mem.looping_sound then
				soundutil.KillSound(inst, inst.sg.mem.looping_sound)
				inst.sg.mem.looping_sound = nil
			end
			soundutil.PlayCodeSound(inst,fmodtable.Event.healingFountain_finished)
		end,
		events = {
			EventHandler("animover", function(inst)	inst.sg:GoToState("finished") end),
		},
	},
	State {
		name = "finished",
		onenter = function(inst)
			SGCommon.Fns.PlayAnimOnAllLayers(inst, "finished", true)
			if inst.sg.mem.looping_sound then
				soundutil.KillSound(inst, inst.sg.mem.looping_sound)
				inst.sg.mem.looping_sound = nil
			end
		end
	}
}

local events = nil

return StateGraph("sg_healing_fountain", states, events, "idle")
