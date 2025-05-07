local Mastery = require "defs.mastery.mastery"

function Mastery.AddPolearmMastery(id, data)
	Mastery.AddMastery(Mastery.Slots.WEAPON_MASTERY, id, WEAPON_TYPES.POLEARM, data)
end

local POLEARM_TIP_ATTACKS =
{
	"LIGHT_ATTACK_1",
	"LIGHT_ATTACK_2",
	"LIGHT_ATTACK_3",
	"REVERSE",
	"HEAVY_ATTACK",
	"MULTITHRUST",
}

-- FOCUS HITS
Mastery.AddPolearmMastery("polearm_focus_hits_tip",
{
	-- Kill 15 enemies with Focus Hits
	event_triggers =
	{
		["kill"] = function(mst, inst, data)
			local attack_name = data.attack:GetNameID()
			if data.attack:GetFocus() and table.contains(POLEARM_TIP_ATTACKS, attack_name) then
				mst:DeltaProgress(1)
			end
		end,
	},
})

-- BASIC MOVES
Mastery.AddPolearmMastery("polearm_fading_light",
{
	-- Kill enemies with Fading Light
	event_triggers =
	{
		["kill"] = function(mst, inst, data)
			local attack_name = data.attack:GetNameID()
			if attack_name == "REVERSE" then
				mst:DeltaProgress(1)
			end
		end,
	},
})

Mastery.AddPolearmMastery("polearm_drill",
{
	-- Kill enemies with Spinning Drill
	event_triggers =
	{
		["kill"] = function(mst, inst, data)
			local attack_name = data.attack:GetNameID()
			if attack_name == "DRILL" then
				mst:DeltaProgress(1)
			end
		end,
	},
})

Mastery.AddPolearmMastery("polearm_multithrust",
{
	-- Kill enemies with Multithrust
	event_triggers =
	{
		["kill"] = function(mst, inst, data)
			local attack_name = data.attack:GetNameID()
			if attack_name == "MULTITHRUST" then
				mst:DeltaProgress(1)
			end
		end,
	},
})

Mastery.AddPolearmMastery("polearm_heavy_attack",
{
	-- Kill enemies with Heavy Attack
	event_triggers =
	{
		["kill"] = function(mst, inst, data)
			local attack_name = data.attack:GetNameID()
			if attack_name == "HEAVY_ATTACK" then
				mst:DeltaProgress(1)
			end
		end,
	},
})

-- ADVANCED MOVES
Mastery.AddPolearmMastery("polearm_single_hit",
{
	-- Start a hit streak with Dodge xx L

	on_add_fn = function(mst, inst, is_upgrade)
		mst.mem.targets_health = {}
	end,

	event_triggers =
	{
		["do_damage"] = function(mst, inst, attack)
			local target = attack:GetTarget()
			local health = target.components.health

			if health then
				mst.mem.targets_health[inst] = health:GetCurrent() -- Store their health on this hit, so we can compare later and see if they died in one hit.
			end
		end,

		["kill"] = function(mst, inst, data)
			local target = data.attack:GetTarget()

			if mst.mem.targets_health[inst] and target.components.health then
				local health = mst.mem.targets_health[inst]
				local max_health = target.components.health:GetMax()

				if health == max_health	then
					mst:DeltaProgress(1)
				end
			end
		end,
	},
})

Mastery.AddPolearmMastery("polearm_drill_multiple_enemies_basic",
{
	-- Start a hit streak with Dodge xx L
	event_triggers =
	{
		["light_attack"] = function(mst, inst, data)
			local attack_id = data.attack_id
			local targets_hit = data.targets_hit
			
			if attack_id == "DRILL" and #targets_hit >= 3 then
				mst:DeltaProgress(1)
			end
		end,
	},
})

Mastery.AddPolearmMastery("polearm_drill_multiple_enemies_advanced",
{
	-- Start a hit streak with Dodge xx L
	event_triggers =
	{
		["light_attack"] = function(mst, inst, data)
			local attack_id = data.attack_id
			local targets_hit = data.targets_hit
			
			if attack_id == "DRILL" and #targets_hit >= 5 then
				mst:DeltaProgress(1)
			end
		end,
	},
})

Mastery.AddPolearmMastery("polearm_hitstreak_basic",
{
	-- Get a hitstreak containing more than one Fading Light's
	event_triggers =
	{
		["hitstreak_killed"] = function(mst, inst, data)
			local hitstreak = data.hitstreak
			if hitstreak >= 15 then
				local drills = 0
				for i,attack_id in ipairs(data.attacks) do
					if attack_id == "DRILL" then
						drills = drills + 1
					end
				end

				if drills >= 3 then
					mst:DeltaProgress(1)
				end
			end
		end,
	},
})

Mastery.AddPolearmMastery("polearm_hitstreak_advanced",
{
	-- Get a hitstreak containing more than one Drill's
	event_triggers =
	{
		["hitstreak_killed"] = function(mst, inst, data)
			local hitstreak = data.hitstreak
			if hitstreak >= 30 then
				local drills = 0
				for i,attack_id in ipairs(data.attacks) do
					if attack_id == "DRILL" then
						drills = drills + 1
					end
				end

				if drills >= 3 then
					mst:DeltaProgress(1)
				end
			end
		end,
	},
})

Mastery.AddPolearmMastery("polearm_hitstreak_expert",
{
	-- Get a long hitstreak
	event_triggers =
	{
		["hitstreak_killed"] = function(mst, inst, data)
			local hitstreak = data.hitstreak
			if hitstreak >= 100 then
				mst:DeltaProgress(1)
			end
		end,
	},
})

-- Mastery.AddPolearmMastery("polearm_counterattack",
-- {
-- 	-- Kill enemies while they are attacking
-- 	tags = { },
-- 	tuning = {
-- 	},
-- 	event_triggers =
-- 	{
-- 		["kill"] = function(mst, inst, data)
-- 			local target = data.attack:GetTarget()
-- 			if table.contains(target.sg.laststate.tags, "attack") then
-- 				mst:DeltaProgress(1)
-- 			end
-- 		end,
-- 	},
-- })