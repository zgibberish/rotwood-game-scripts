local Widget = require "widgets/widget"
local Image = require "widgets.image"

local Equipment = require "defs.equipment"

WEAPON_TYPE_TO_TEX =
{
	[WEAPON_TYPES.HAMMER] = "images/icons_ftf/inventory_weapon_hammer.tex",
	[WEAPON_TYPES.POLEARM] = "images/icons_ftf/inventory_weapon_polearm.tex",
	[WEAPON_TYPES.GREATSWORD] = "images/icons_ftf/inventory_weapon_sword.tex",
	[WEAPON_TYPES.CANNON] = "images/icons_ftf/inventory_weapon_cannon.tex",
	[WEAPON_TYPES.SHOTPUT] = "images/icons_ftf/inventory_weapon_balls.tex",
}

--- Displays a single player character's portrait with a frame
local PlayerWeaponWidget =  Class(Widget, function(self, owner)
	Widget._ctor(self, "PlayerWeaponWidget")

	-- Widgets container
	self.container = self:AddChild(Widget())
	self.bg = self.container:AddChild(Image("images/ui_ftf_hud/UI_HUD_playerTagBG.tex"))
	self.icon = self.container:AddChild(Image(WEAPON_TYPE_TO_TEX[WEAPON_TYPES.HAMMER]))
		:SetMultColor(UICOLORS.BLACK)

	if owner then
		self:SetOwner(owner)
	end
end)

function PlayerWeaponWidget:FillWithPlaceholder()
	self.icon:SetTexture(WEAPON_TYPE_TO_TEX.POLEARM)
	return self
end

function PlayerWeaponWidget:SetOwner(owner)
	self.owner = owner
		self:RefreshWeapon()
	self.inst:ListenForEvent("loadout_changed", function(_, data) self:RefreshWeapon() end, self.owner)
end

function PlayerWeaponWidget:RefreshWeapon()
	-- get equipped weapon & set icon texture to match.
	self.bg:SetMultColor(self.owner.uicolor)
	local weapon_type = self.owner.components.inventory:GetEquippedWeaponType()
	if WEAPON_TYPE_TO_TEX[weapon_type] then
		self.icon:SetTexture(WEAPON_TYPE_TO_TEX[weapon_type])
	end
end

function PlayerWeaponWidget:SetSize(size)
	self.bg:SetSize(size, size)
	self.icon:SetSize(size*0.8, size*0.8)
end

return PlayerWeaponWidget
