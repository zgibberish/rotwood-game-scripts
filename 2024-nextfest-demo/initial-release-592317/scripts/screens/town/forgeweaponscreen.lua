local Equipment = require("defs.equipment")
local EquipmentGem = require("defs.equipmentgems")
local RecipeScreen = require("screens.town.recipescreen")

local function get_slots()
	return {
		{ slot = Equipment.Slots.WEAPON },
		{ slot = EquipmentGem.Slots.GEMS },
		-- { slot = Equipment.Slots.WEAPON, filters = { "polearm" } , icon = "images/icons_ftf/inventory_weapon_polearm.tex" },
		-- { slot = Equipment.Slots.WEAPON, filters = { "hammer" } , icon = "images/icons_ftf/inventory_weapon_hammer.tex" }
	}
end

local ForgeWeaponScreen = Class(RecipeScreen, function(self, player)
	RecipeScreen._ctor(self, "ForgeWeaponScreen", player, get_slots())
	self:SetTitle(STRINGS.UI.FORGEWEAPONSCREEN.MENU_TITLE)
end)

function ForgeWeaponScreen:ApplySkin()
	ForgeWeaponScreen._base.ApplySkin(self)
	-- print("HEY THERE")
	self.skinPanelIllustration:SetTexture(self.skinDirectory .. "panel_weapon.tex")

	return self
end

return ForgeWeaponScreen
