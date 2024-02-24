local Power = require "defs.powers.power"

function Power.AddDebugPower(id, data)
	data.can_drop = false
	data.show_in_ui = false
	data.power_type = Power.Types.RELIC
	Power.AddPower(Power.Slots.CHEAT, id, "player_powers", data)
end

Power.AddPowerFamily("CHEAT")

Power.AddDebugPower("crit_all_attacks",
{
	power_category = Power.Categories.DAMAGE,
	damage_mod_fn = function(pow, attack, output_data)
		attack:SetCrit(true)
		return true
	end,
})

Power.AddDebugPower("crit_all_incoming",
{
	power_category = Power.Categories.DAMAGE,
	defend_mod_fn = function(pow, attack, output_data)
		attack:SetCrit(true)
		return true
	end,
})

