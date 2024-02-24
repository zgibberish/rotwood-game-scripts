local Image = require "widgets.image"
local PlayerPuppet = require("widgets/playerpuppet")
local Widget = require("widgets/widget")

--- Displays a single player character's portrait with a frame
local PlayerPortrait =  Class(Widget, function(self)
	Widget._ctor(self, "PlayerPortrait")

	-- Setup player portrait widget
	self.root = self:AddChild(Widget())

	self.bg = self.root:AddChild(Image("images/ui_ftf_hud/UI_HUD_portraitBG.tex"))
	self.mask = self.root:AddChild(Image("images/ui_ftf_hud/UI_HUD_portraitMask.tex"))
		:SetMask()

	self.puppet = self.root:AddChild(PlayerPuppet())
		:SetPosition(-10, -200)
		:SetHiddenBoundingBox(true)
		:SetScale(.65, .65)
		:SetFacing(FACING_RIGHT)
		:SetMasked()
end)

function PlayerPortrait:Refresh(owner)
	dbassert(owner)
	-- Don't store owner or we'd also need to track onremove.
	self.bg:SetMultColor(owner.uicolor)
	self.puppet:CloneCharacterWithEquipment(owner)
end

function PlayerPortrait:TOP_LEFT()
	self.puppet:SetFacing(FACING_RIGHT)
end

function PlayerPortrait:TOP_RIGHT()
	self.puppet:SetFacing(FACING_LEFT)
end

function PlayerPortrait:BOTTOM_LEFT()
	self.puppet:SetFacing(FACING_RIGHT)
end

function PlayerPortrait:BOTTOM_RIGHT()
	self.puppet:SetFacing(FACING_LEFT)
end

return PlayerPortrait
