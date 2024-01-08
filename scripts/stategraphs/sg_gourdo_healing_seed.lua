local EffectEvents = require "effectevents"
local SGCommon = require("stategraphs/sg_common")
local soundutil = require "util.soundutil"
local fmodtable = require "defs.sound.fmodtable"

local function OnDeath(inst, data)
	--Spawn death fx
	inst.components.healingzone:Disable()
	EffectEvents.MakeEventFXDeath(inst, data.attack, "fx_death_cabbageroll")
	--sound
	local params = {}
	params.fmodevent = fmodtable.Event.gourdo_seed_death
	soundutil.PlaySoundData(inst, params)
end

local events =
{
	SGCommon.Events.OnQuickDeath(OnDeath),
	SGCommon.Events.OnAttacked(),
	EventHandler("zone_heal", function(inst, rad)
		if not inst.sg:HasStateTag("busy") then
			inst.sg:GoToState("heal", rad)
		end
	end),
	SGCommon.Events.OnDying(),
}

local states =
{
	State({
		name = "land",
		tags = { "idle" },

		onenter = function(inst)
			inst.AnimState:PlayAnimation("open")
			inst.components.hitbox:StartRepeatTargetDelay()
		end,

		timeline = {
			FrameEvent(3, function(inst)
				--inst.components.hitbox:PushCircle(0, 0, inst.components.healingzone.heal_radius, HitPriority.MOB_DEFAULT)
			end),
		},

		events =
		{
			EventHandler("animover", function(inst)
				inst.sg:GoToState("idle")
			end),
		},

		onexit = function(inst)
			inst.components.hitbox:StopRepeatTargetDelay()
		end,
	}),

	State({
		name = "idle",
		tags = { "idle" },

		onenter = function(inst)
			inst.AnimState:PlayAnimation("idle", true)
			inst.components.healingzone:Enable()
		end,
	}),

	State({
		name = "heal",
		tags = { "idle", "busy" },

		onenter = function(inst, rad)
			-- Just flicker with warning
		end,

		timeline = {
			FrameEvent(0, function(inst) SGCommon.Fns.BlinkAndFadeColor(inst, { 0/255, 100/255, 0/255, 0.2}, 4) end),
			FrameEvent(8, function(inst) SGCommon.Fns.BlinkAndFadeColor(inst, { 0/255, 100/255, 0/255, 0.2}, 4) end),
			FrameEvent(12, function(inst) inst.sg:GoToState("heal_execute") end),
		},

		events =
		{
		}
	}),

	State({
		name = "heal_execute",
		tags = { "idle", "busy" },

		onenter = function(inst, rad)
			inst.AnimState:PlayAnimation("heal")
		end,

		timeline = {
			FrameEvent(0, function(inst) SGCommon.Fns.BlinkAndFadeColor(inst, { 0/255, 100/255, 0/255, 0.2}, 2) end),
			FrameEvent(4, function(inst) SGCommon.Fns.BlinkAndFadeColor(inst, { 0/255, 100/255, 0/255, 0.2}, 2) end),
			FrameEvent(8, function(inst) SGCommon.Fns.BlinkAndFadeColor(inst, { 0/255, 100/255, 0/255, 0.2}, 1) end),
			FrameEvent(12, function(inst) SGCommon.Fns.BlinkAndFadeColor(inst, { 0/255, 100/255, 0/255, 0.2}, 1) end),

			FrameEvent(14, function(inst)
				inst.components.hitbox:StartRepeatTargetDelay()
				inst.components.hitbox:PushCircle(0, 0, inst.components.healingzone.heal_radius, HitPriority.MOB_DEFAULT)
				inst.sg:RemoveStateTag("busy")
				inst.components.healingzone:DoHeal(inst) -- heal self
			end),
		},

		onexit = function(inst)
			inst.components.hitbox:StopRepeatTargetDelay()
			--inst.components.health:Kill()
		end,

		events =
		{
			EventHandler("animover", function(inst)
				inst.sg:GoToState("idle")
			end),
		}
	}),

	State({
		name = "death",
		tags = { "busy", "death" },

		onenter = function(inst)
			if (inst:HasTag("elite")) then
				EffectEvents.MakeEventSpawnLocalEntity(inst, "death_gourdo_seed_elite_frnt", "idle")
				EffectEvents.MakeEventSpawnLocalEntity(inst, "death_gourdo_seed_elite_grnd", "idle")
			else
				EffectEvents.MakeEventSpawnLocalEntity(inst, "death_gourdo_seed_frnt", "idle")
				EffectEvents.MakeEventSpawnLocalEntity(inst, "death_gourdo_seed_grnd", "idle")
			end
			inst.AnimState:PlayAnimation("idle", true)
		end,
	}),
}

SGCommon.States.AddHitStates(states)

return StateGraph("sg_gourdo_healing_seed", states, events, "land")
