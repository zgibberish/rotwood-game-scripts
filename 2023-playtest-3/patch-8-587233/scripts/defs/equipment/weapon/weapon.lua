local Enum = require "util.enum"
local Item = require "defs.equipment.item"
local Lume = require "util.Lume"
local Slots = require "defs.equipment.slots"
local Weight = require "components/weight"

local Slot = Enum(Lume(Slots):map(function(slot) return slot.name end):sort():result())

local Weapon = {}

function Weapon.Construct(weapon_type, name, build, rarity, data)
	return Item.Construct(Slot.s.WEAPON, name, build, Lume.merge( 
	-- Defaults.
	{
		weight = Weight.EquipmentWeight.s.Normal,
	},

	data,

	{
		tags = Lume.concat(data.tags or {}, { string.lower(weapon_type) }),
		weapon_type = weapon_type,
		rarity = rarity,
	}))
end

return Weapon
