local fmodtable = require "defs.sound.fmodtable"
local soundutil = require "util.soundutil"

local states =
{
	State({
		name = "thrown",
		tags = { "airborne" },
		timeline =
		{
			FrameEvent(0, function(inst)
				--sound
				local params = {}
				params.fmodevent = fmodtable.Event.Skill_ThrowStone_Travel
				params.sound_max_count = 1
				inst.sg.statemem.travel_sound_handle = soundutil.PlaySoundData(inst, params)
				if inst.faction_hunter_id then
					soundutil.SetInstanceParameter(inst, inst.sg.statemem.travel_sound_handle, "faction_player_id", inst.faction_hunter_id)
				end
			end),
		},
	}),
}

return StateGraph("sg_player_throwstone_projectile", states, nil, "thrown")