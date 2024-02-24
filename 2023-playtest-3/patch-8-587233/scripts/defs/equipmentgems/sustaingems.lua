local EquipmentGem = require "defs.equipmentgems.equipmentgem"

local Power = require"defs.powers"
local Consumable = require"defs.consumable"

function EquipmentGem.AddSustainGem(id, data)
	data.gem_type = EquipmentGem.Type.SUSTAIN
	EquipmentGem.AddEquipmentGem("GEMS", id, data)
end

EquipmentGem.AddSustainGem("max_health",
{
	stat_mods =
	{
		[EQUIPMENT_STATS.s.HP] = { 25, 50, 75, 100, 125 },
	},
	tags = { "tutorial_gem", "default_unlocked" },
})
