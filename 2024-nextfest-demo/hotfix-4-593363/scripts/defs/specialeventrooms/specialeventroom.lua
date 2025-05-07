--require "strings.strings"

local SpecialEventRoom = {
	-- Populated in defs/specialeventrooms/
	Events = {}
}

SpecialEventRoom.Types = MakeEnum{ "MINIGAME", "CONVERSATION" }

function SpecialEventRoom.CollectPrefabs(tbl)
	for _, event in pairs(SpecialEventRoom.Events) do
		if event.prefabs then
			for _, prefab in ipairs(event.prefabs) do
				table.insert(tbl, prefab)
			end
		end
	end
end

function SpecialEventRoom.AddSpecialEventRoom(category, name, data)
	local events = SpecialEventRoom.Events

	local def = {
		category = category,
		name = name,
		tags = data.tags or {},
		prefabs = data.prefabs,
		assets = data.assets,
		event_triggers = data.event_triggers or {},
		prerequisite_fn = data.prerequisite_fn,
		on_init_fn = data.on_init_fn,
		on_start_fn = data.on_start_fn,
		on_update_fn = data.on_update_fn,
		on_scorewrapup_fn = data.on_scorewrapup_fn,
		on_finish_fn = data.on_finish_fn,

		score_type = data.score_type,
		score_thresholds = data.score_thresholds,
	}

	events[name] = def
	return def
end

SpecialEventRoom.ScoreType = MakeEnum{ "HIGHSCORE", "TIMELEFT", "SCORELEFT" }
SpecialEventRoom.RewardLevel = MakeEnum{ "BRONZE", "SILVER", "GOLD" }
SpecialEventRoom.RewardLevelIdx =
{
	[1] = SpecialEventRoom.RewardLevel.BRONZE,
	[2] = SpecialEventRoom.RewardLevel.SILVER,
	[3] = SpecialEventRoom.RewardLevel.GOLD,
}

return SpecialEventRoom