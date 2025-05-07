local SGCommon = require("stategraphs/sg_common")

local states =
{
	State({
		name = "thrown",
		tags = { "airborne" },
		onenter = function(inst, targetpos)
			inst.components.hitbox:StartRepeatTargetDelay()

			-- Spawn an attack area in front of the player upon spawning the projectile.
			inst.components.hitbox:PushBeam(-1.5, 1, 1.25, HitPriority.MOB_PROJECTILE)
		end,
	}),
}

return StateGraph("sg_minion_ranged_projectile", states, nil, "thrown")