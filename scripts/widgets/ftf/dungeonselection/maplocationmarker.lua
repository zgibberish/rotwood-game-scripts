local Clickable = require("widgets/clickable")
local ImageButton = require("widgets/imagebutton")
local Panel = require("widgets/panel")
local Text = require("widgets/text")
local easing = require "util.easing"
local Image = require"widgets/image"

local playerutil = require"util/playerutil"

------------------------------------------------------------------------------------------
--- A map location marker
----
local MapLocationMarker = Class(Clickable, function(self, player, locationId, locationData)
	Clickable._ctor(self)
	self:SetName("MapLocationMarker")

	self:SetOwningPlayer(player)
	self:SetFocusBracketsOffset(0, 10)

	self.badge = self:AddChild(Image("images/mapicons_ftf/biome_bg.tex"))
		:SetName("Badge")
		:SetSize(160, 160)

	self.boss_icon = self:AddChild(Image(locationData.icon))
		:SetName("Boss icon")
		:SetSize(100, 100)
		:SetMultColor(UICOLORS.BACKGROUND_DARK)
		:SetPos(0, 8)

	-- self:SetOnGainFocus(function()
	-- 	if TheFrontEnd:IsRelativeNavigation() then
	-- 		-- Immediately select self so brackets indicate current focus.
	-- 		self.onclick(true)
	-- 	end
	-- end)

	self.quest_marker = self:AddChild(Image("images/ui_ftf_pausescreen/room_passage.tex"))
		:SetName("Quest marker")
		:SetSize(30 * HACK_FOR_4K, 30 * HACK_FOR_4K)
		:SetHiddenBoundingBox(true)
		:SetToolTip("You have a quest here")
		:LayoutBounds("right", "top", self.badge)
		:Offset(6, 8)

	-- self:SetOnHighlight( function()
	-- end )
	-- self:SetOnUnHighlight( function()
	-- end )

	if locationData then self:SetLocationData(locationId, locationData) end
end)

function MapLocationMarker:IsUnlocked(locationData)
	return playerutil.GetLocationUnlockInfo(locationData)
end

function MapLocationMarker:SetLocationData(locationId, locationData)

	-- Save data
	self.locationId = locationId
	self.locationData = locationData


	self.boss_icon:SetTexture(locationData.icon)

	-- Update image
	-- self:SetTextures(self.locationData.icon)

	-- Show the locked icon if any
	self:RefreshLockedState()

	self:Layout()

	self:StartUpdating()

	return self
end

function MapLocationMarker:GetLocationData()
	return self.locationData
end

function MapLocationMarker:OnUpdate()
	self:RefreshLockedState()
end

function MapLocationMarker:RefreshQuestMarks()
	self.quest_marker:Hide()

	if TheWorld.components.questmarkmanager:IsLocationMarked(self.locationId) then
		self.quest_marker:Show()
	end
end

function MapLocationMarker:RefreshLockedState()
	local is_unlocked = playerutil.GetLocationUnlockInfo(self.locationData)

	if not is_unlocked and self.locationData.icon_locked then
		self.badge:SetTexture("images/mapicons_ftf/biome_unknown.tex")
		self.boss_icon:Hide()
		self.quest_marker:Hide()
	else
		self.badge:SetTexture("images/mapicons_ftf/biome_bg.tex")
		self.boss_icon:SetTexture(self.locationData.icon)
			:Show()

		self:RefreshQuestMarks()
	end
end

function MapLocationMarker:GetId()
	return self.locationId
end

function MapLocationMarker:Layout()

	return self
end

function MapLocationMarker:SetOwningPlayer(player)
	self.owningplayer = player
	return self
end

function MapLocationMarker:GetOwningPlayer()
	return self.owningplayer
end

return MapLocationMarker
