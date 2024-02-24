local SGCommon = require "stategraphs.sg_common"
local fmodtable = require "defs.sound.fmodtable"
local soundutil = require "util.soundutil"

local SGMiniBossCommon =
{
	States = {},
	Events = {},
	Fns = {},
}

function SGMiniBossCommon.Fns.OnMinibossDying(inst, data)
	SGCommon.Fns.OnMonsterDying(inst, data)

	-- Go to miniboss death state; this state should send out the done_dying event upon completion.
	if inst:HasTag("miniboss") then
		if not inst.sg:HasStateTag("death_miniboss") then
			inst.sg:ForceGoToState("death_miniboss")
		end
	else
		-- We're a regular enemy; go straight to death
		inst.sg:ForceGoToState("death")
		inst:PushEvent("done_dying")
	end
end

--------------------------------------------------------------------------
-- AddMinibossDeathStates
--------------------
-- Possible parameters for 'data':
-- anim: The spawn in anim to play.
-- addtags: Add additional tags to each state defined here.
-- timeout: The length to remain in this state before removing itself.

-- onenter_fn: A function that runs additional actions in onenter.
-- onupdate_fn: As above, but in onupdate.
-- timeline: A table of FrameEvents that get called in the state defined here.
function SGMiniBossCommon.States.AddMinibossDeathStates(states, data)
	if not data then data = {} end

	states[#states + 1] = State({
		name = "death_miniboss",
		tags = table.appendarrays({ "busy", "nointerrupt", "death_miniboss" }, data.addtags or {}),

		default_data_for_tools = function(inst, cleanup)
			return { timeout = 10000, }
		end,

		onenter = function(inst, spawn_data)
			SGCommon.Fns.PlayAnimOnAllLayers(inst, data.anim or "elite_death_hit_hold")
			SGCommon.Fns.BlinkAndFadeColor(inst, { 255/255, 255/255, 255/255, 1 }, 15)

			--death_miniboss
			local params = {}
			params.fmodevent = fmodtable.Event.miniboss_death
			params.autostop = false
			soundutil.PlaySoundData(inst, params)

			local audioid = require "defs.sound.audioid"
			local enemies = TheWorld.components.roomclear:GetEnemies()
			local num_minibosses = 0
			for enemy in pairs(enemies) do
				if (enemy:HasTag("miniboss")) then
					num_minibosses = num_minibosses + 1
				end
			end

			if num_minibosses >= 1 then
				TheAudio:SetPersistentSoundParameter(audioid.persistent.boss_music, "local_discreteBinary", 0) -- more intense music after miniboss is dead
			end

			if data ~= nil and data.onenter_fn ~= nil then
				data.onenter_fn(inst)
			end

			inst.components.hitshudder:DoShudder(TUNING.HITSHUDDER_AMOUNT_HEAVY * 2, 30)

			inst:DoTaskInTime(data.timeout or (spawn_data and spawn_data.timeout) or 1, function()
				-- Using DoTaskInTime instead of ontimeout to better sync with death presentation FX
				--inst.sg.mem.deathtask = inst:DoTaskInTicks(0, inst.DelayedRemove)
				inst:PushEvent("done_dying")
			end)
		end,

		onupdate = data ~= nil and data.onupdate_fn or nil,

		timeline = data ~= nil and data.timeline or nil,
	})
end

return SGMiniBossCommon
