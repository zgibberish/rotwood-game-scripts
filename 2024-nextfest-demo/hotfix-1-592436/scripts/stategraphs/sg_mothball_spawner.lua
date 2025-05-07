local EffectEvents = require "effectevents"
local SGCommon = require "stategraphs.sg_common"
local monsterutil = require "util.monsterutil"

local function OnDeath(inst, data)
	--Spawn death fx
	EffectEvents.MakeEventFXDeath(inst, data.attack, "death_mothball_spawner")

	local banked = inst.components.periodicspawner:GetSpawnsAvailable()
	if banked > 0 then
		-- Only spawn remaining mothballs if there are more enemies
		-- Slightly awkward logic to handle whether or not "death" event
		-- is processed by roomclear first due to non-deterministic event handling
		local roomclear = TheWorld.components.roomclear
		local should_spawn_remaining = (roomclear:GetEnemyCount() > 1)
			or (roomclear:GetEnemyCount() == 1 and not roomclear:GetEnemies()[inst])

		if should_spawn_remaining then
			for _i=1, banked do
				local angle = math.random(1, 360)
				inst.components.periodicspawner:DoSpawn("mothball", angle)
			end
		end
	end

	inst.components.lootdropper:DropLoot()
end

local events =
{
}
monsterutil.AddStationaryMonsterCommonEvents(events, { ondeath_fn = OnDeath, })

local states =
{
	State({
		name = "spawn",
		tags = { "attack", "busy" },

		onenter = function(inst, target)
			local angle = math.random(1, 360)

			if angle < 90 then
				SGCommon.Fns.PlayAnimOnAllLayers(inst, "spawn_r")
			else
				SGCommon.Fns.PlayAnimOnAllLayers(inst, "spawn_l")
			end

			inst.components.attacktracker:CompleteActiveAttack()
			inst.components.periodicspawner:DoSpawn("mothball", angle)
		end,

		events =
		{
			EventHandler("animover", function(inst)
				inst.sg:GoToState("idle")
			end),
		},
	}),
}

SGCommon.States.AddAttackPre(states, "spawn")
SGCommon.States.AddAttackHold(states, "spawn")

SGCommon.States.AddLeftRightHitStates(states)
SGCommon.States.AddIdleStates(states)

SGCommon.States.AddMonsterDeathStates(states)

return StateGraph("sg_mothball_spawner", states, events, "idle")
