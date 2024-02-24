local SGCommon = require "stategraphs.sg_common"

local events =
{
	EventHandler("despawn", function(inst) inst.sg:GoToState("despawn") end),
}

local function OnProximityHitBoxTriggered(inst, data)
	local triggered = false
	for i = 1, #data.targets do
		local v = data.targets[i]
		if v.entity:HasTag("player") then
			triggered = true
			break
		end
	end

	if(triggered and not inst.sg.statemem.noautoburst) then
		inst.sg.statemem.noautoburst = true
		inst:DoTaskInAnimFrames(5, function(xinst)
			xinst.sg:GoToState("shatter_pre_proximity")
		end)
	end

end

-- 3 frames of animation, programmatically scaling it down and then bursting it
local proximity_burst_ticks_to_scale =
{
	1,
	0.95,
	0.95,
	0.95,
	0.95,
	1.05,
	1.05,
}
local IDLE_SECONDS_BEFORE_SHATTERING = 5

local states =
{
	State({
		-- We must spawn this object immediately to keep the room locked, so
		-- let it sit hidden until it should actually appear.
		name = "spawn_pre",
		tags = { "busy" },

		onenter = function(inst)
			inst:Hide()
			local initial_ticks = TUNING.POWERS.DROP_SPAWN_INITIAL_DELAY_FRAMES
			inst.sg:SetTimeoutTicks(initial_ticks)
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
			inst.sg:SetTimeoutTicks(60 * IDLE_SECONDS_BEFORE_SHATTERING)
			inst.components.hitbox:SetUtilityHitbox(true)
		end,

		onupdate = function(inst)
			inst.components.hitbox:PushCircle(0, 0, 4, HitPriority.PLAYER_DEFAULT)
		end,

		ontimeout = function(inst)
			if not inst.sg.statemem.noautoburst then
				inst.sg:GoToState("shatter")
			end
		end,

		events =
		{
			EventHandler("hitboxtriggered", OnProximityHitBoxTriggered),
		},
	}),

	State({
		name = "shatter_pre_proximity", -- for when the player stands near it, a little jiggle first
		tags = { "busy" },

		onenter = function(inst)
			SGCommon.Fns.BlinkAndFadeColor(inst, TUNING.BLINK_AND_FADES.POWER_DROP_KONJUR_PROXIMITY.COLOR, TUNING.BLINK_AND_FADES.POWER_DROP_KONJUR_PROXIMITY.FRAMES)
			inst.sg:SetTimeoutTicks(8)
		end,

		onupdate = function(inst)
			local ticks_in_state = inst.sg:GetTicksInState()
			local scale = proximity_burst_ticks_to_scale[ticks_in_state+1]
			inst.AnimState:SetScale(scale, scale)
		end,

		ontimeout = function(inst)
			inst.sg:GoToState("shatter")
		end,
	}),

	State({
		name = "shatter",
		tags = { "busy" },

		onenter = function(inst)
			SGCommon.Fns.PlayAnimOnAllLayers(inst, "shatter")
			TheWorld.components.konjurrewardmanager:SpawnRoomRewardKonjur(inst)
			inst:RemoveComponent("roomlock")
		end,

		events =
		{
			EventHandler("animover", function(inst)
				inst:Remove()
			end),
		},
	}),
}

return StateGraph("sg_konjur_reward_drop", states, events, "spawn_pre")
