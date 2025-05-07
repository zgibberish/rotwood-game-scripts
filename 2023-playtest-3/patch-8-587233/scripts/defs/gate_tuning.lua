local gate_tuning = {}

local cardinal_data = {
	east = {
		world = {
			gate = Vector3(3.4, 0, 0),
			hitbox = { 1, -6, 20, 6 },
			indicator = Vector3(-1, 0, 0),
			-- Rotation seems like it will just be confusing with the new wide
			-- array of indicators.
			--~ indicator_rot = 360 / 12,
			indicator_scale = 1.1,
		},
	},
	west = {
		world = {
			gate = Vector3(-3.54, 0, 0),
			hitbox = { -1, -6, -20, 6 },
			indicator = Vector3(1, 0, 0),
		},
	},
	north = {
		world = {
			gate = Vector3(0, 0, 2.96),
			hitbox = { -6, 1, 6, 20 },
			indicator = Vector3(-0, 0, -1.2),
			indicator_scale = 1.15,
		},
	},
	south = {
		world = {
			gate = Vector3(0, 0, -2),
			hitbox = { -6, -20, 6, -1 },
			indicator = Vector3(-0, 0, 1),
		},
	},
}
function gate_tuning.GetTuningForCardinal(cardinal)
	assert(cardinal)
	return cardinal_data[cardinal]
end

return gate_tuning
