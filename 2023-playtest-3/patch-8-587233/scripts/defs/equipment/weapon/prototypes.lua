local Weapon = require "defs.equipment.weapon.weapon"

-- MIKERproto: replace the ['PROTOTYPE'] weapon type in constants.lua too!

local weaponprototype_build = "weapon_back_template" --MIKERproto: replace with whatever build you want to test
--MIKERproto: Remember to add the bank to CollectAssets above!

-- Weapon Prototyper, for testing basic anim sets before they have actual stategraphs:

return {
	Weapon.Construct(WEAPON_TYPES.PROTOTYPE, "weaponprototype", weaponprototype_build, ITEM_RARITY.s.COMMON, {
		tags = { "weaponprototype" },
		fx_type = "basic",
	})
}
