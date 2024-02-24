local Widget = require("widgets/widget")
local Image = require("widgets/image")
local Panel = require("widgets/panel")
local PlayerPuppet = require("widgets/playerpuppet")

------------------------------------------------------------------------------------------
--- Displays a panel with a player's character info
----

local MannequinPanel = Class(Widget, function(self, player)
	Widget._ctor(self, "MannequinPanel")

	self.width = 540
	self.contentWidth = self.width - 50
	self.height = RES_Y

	-- SIDEBAR BACKGROUND

	self.bg = self:AddChild(Panel("images/ui_ftf_forging/forge_sidebar.tex"))
		:SetNineSliceCoords(50, 450, 60, 620)
		:SetNineSliceBorderScale(0.5)
		:SetSize(self.width, self.height + 20 * HACK_FOR_4K)
		:LayoutBounds("left", "center", -RES_X / 2, 0)
		:Offset(40 * HACK_FOR_4K, 0)

	-- CHARACTER PUPPET

	self.puppetContainer = self.bg:AddChild(Widget("Puppet Container"))
	self.puppetMask = self.puppetContainer:AddChild(Image("images/global/square.tex"))
		:SetMultColor(UICOLORS.WHITE)
		:SetSize(self.width - 10 * HACK_FOR_4K, RES_Y * 2)
		:SetMask()
	self.puppet = self.puppetContainer:AddChild(PlayerPuppet())
		:SetMasked()
		:SetScale(1.25, 1.25)
		:SetFacing(FACING_RIGHT)

	--- PANEL CONTENTS

	self:ApplySkin()
		:LayoutSkin()

	if player then
		self:Refresh(player)
	end
end)

function MannequinPanel:Refresh(player)
	self.player = player
	self:RefreshPuppet()
	return self
end

function MannequinPanel:RefreshPuppet()
	self.puppet:CloneCharacterWithEquipment(self.player)

	-- Position puppet
	self.puppetContainer:LayoutBounds("center", "center", self.bg)
		:Offset(0, -250)

	return self
end

function MannequinPanel:OnEquipItem(slot, name)
	-- Update puppet
	self.puppet.components.inventory:Equip(slot, name)
end

function MannequinPanel:DoCheer()
	self.puppet:PlayAnimSequence({"emote_pump", "idle"})
end

---
-- Instantiates all the skin texture elements to this screen.
-- Call this at the start
--
function MannequinPanel:ApplySkin()

	self.skinDirectory = "images/ui_ftf_skin/" -- Defines what skin to use

	-- Add chain edges to the bg panel
	self.skinEdgeLeft = self:AddChild(Image(self.skinDirectory .. "panel_left.tex"))
		:SetHiddenBoundingBox(true)
	self.skinEdgeRight = self:AddChild(Image(self.skinDirectory .. "panel_right.tex"))
		:SetHiddenBoundingBox(true)

	-- Add glow at the bottom
	self.skinPanelGlow = self:AddChild(Image(self.skinDirectory .. "panel_glow.tex"))
		:SetHiddenBoundingBox(true)
		:PulseAlpha(0.6, 1, 0.003)

	return self
end

---
-- Lays out all the skin texture elements to this screen
-- Call this when the size/layout changes
--

function MannequinPanel:LayoutSkin()

	-- Edge textures
	local textureW, textureH = 100, 1280
	local targetH = RES_Y
	local targetW = targetH / textureH * textureW
	self.skinEdgeLeft:SetSize(targetW, RES_Y)
		:LayoutBounds("before", "center", self.bg)
		:Offset(targetW * 0.5, 0)
	self.skinEdgeRight:SetSize(targetW, RES_Y)
		:LayoutBounds("after", "center", self.bg)
		:Offset(-targetW * 0.5, 0)

	-- Bottom glow
	self.skinPanelGlow:SetSize(self.width * 1.2, self.width * 1.2)
		:LayoutBounds("center", "bottom", self.bg)

	return self
end

return MannequinPanel
