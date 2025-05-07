local Mastery = require "defs.mastery.mastery"

Mastery.AddMasteryPath(WEAPON_TYPES.HAMMER)

function Mastery.AddHammerMastery(id, data)
	Mastery.AddMasteryToPath(WEAPON_TYPES.HAMMER, id)
	Mastery.AddMastery(Mastery.Slots.WEAPON_MASTERY, id, WEAPON_TYPES.HAMMER, data)
end

-- FOCUS HITS
Mastery.AddHammerMastery("hammer_focus_hits",
{
	-- Get kills with focus hits
	event_triggers =
	{
		["kill"] = function(mst, inst, data)
			if data.attack:GetFocus() then
				mst:DeltaProgress(1)
			end
		end,
	},

	next_step = "hammer_focus_hits_destructibles",
})

local function _check_included_destructible(mst, inst, data)
	if #data.targets_hit >= 2 then
		local included_destructible = false
		for k,v in pairs(data.targets_hit) do
			if v:HasTag("prop_destructible") then
				included_destructible = true
				break
			end
		end

		if included_destructible then
			mst:DeltaProgress(1)
		end
	end
end

Mastery.AddHammerMastery("hammer_focus_hits_destructibles",
{
	-- Use props to get focus hits
	max_progress = 15,
	event_triggers =
	{
		["heavy_attack"] = _check_included_destructible,
		["light_attack"] = _check_included_destructible,
	},
})

-- BASIC MOVES
Mastery.AddHammerMastery("hammer_fading_light",
{
	-- Kill enemies with fading light
	event_triggers =
	{
		["kill"] = function(mst, inst, data)
			local attack_name = data.attack:GetNameID()
			if attack_name == "FADING_LIGHT" then
				mst:DeltaProgress(1)
			end
		end,
	},
})

Mastery.AddHammerMastery("hammer_golf_swing",
{
	-- Kill enemies with Golf Swing
	event_triggers =
	{
		["kill"] = function(mst, inst, data)
			local attack_name = data.attack:GetNameID()
			if attack_name == "GOLF_SWING_FULL" or attack_name == "GOLF_SWING_MID" or attack_name == "GOLF_SWING_LIGHT" then
				mst:DeltaProgress(1)
			end
		end,
	},
})

Mastery.AddHammerMastery("hammer_air_spin",
{
	-- Kill enemies with LLHH
	event_triggers =
	{
		["kill"] = function(mst, inst, data)
			local attack_name = data.attack:GetNameID()
			if attack_name == "HEAVY_AIR_SPIN" then
				mst:DeltaProgress(1)
			end
		end,
	},
})

Mastery.AddHammerMastery("hammer_heavy_slam",
{
	-- Kill enemies with Lariat
	event_triggers =
	{
		["kill"] = function(mst, inst, data)
			local attack_name = data.attack:GetNameID()
			if attack_name == "HEAVY_SLAM" then
				mst:DeltaProgress(1)
			end
		end,
	},
})

Mastery.AddHammerMastery("hammer_lariat",
{
	-- Kill enemies with Lariat
	event_triggers =
	{
		["kill"] = function(mst, inst, data)
			local attack_name = data.attack:GetNameID()
			if attack_name == "LARIAT" then
				mst:DeltaProgress(1)
			end
		end,
	},
})


-- ADVANCED MOVES
Mastery.AddHammerMastery("hammer_hitstreak_dodge_L",
{
	-- Start a hit streak with Dodge xx L
	event_triggers =
	{
		["hitstreak_killed"] = function(mst, inst, data)
			local hitstreak = data.hitstreak
			if hitstreak >= 10 then
				local first_attack = data.attacks[1]
				if first_attack == "LIGHT_ATTACK_3" then
					mst:DeltaProgress(1)
				end
			end
		end,
	},
})

Mastery.AddHammerMastery("hammer_hitstreak_fading_L",
{
	-- Get a hitstreak containing more than one Fading Light's
	event_triggers =
	{
		["hitstreak_killed"] = function(mst, inst, data)
			local hitstreak = data.hitstreak
			if hitstreak >= 10 then
				local fading_lights = 0
				for i,attack_id in ipairs(data.attacks) do
					if attack_id == "FADING_LIGHT" then
						fading_lights = fading_lights + 1
					end
				end

				if fading_lights >= 3 then
					mst:DeltaProgress(1)
				end
			end
		end,
	},
})

Mastery.AddHammerMastery("hammer_counterattack",
{
	-- Kill enemies while they are attacking
	event_triggers =
	{
		["kill"] = function(mst, inst, data)
			local target = data.attack:GetTarget()
			if table.contains(target.sg.laststate.tags, "attack") then
				mst:DeltaProgress(1)
			end
		end,
	},
})