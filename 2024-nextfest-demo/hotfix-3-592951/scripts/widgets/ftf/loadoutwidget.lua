local Widget = require("widgets/widget")
local EquipmentPanel = require("widgets/ftf/equipmentpanel")

local Enum = require "util/enum"
local easing = require "util/easing"

local WIDGET_STATE = Enum{
	"CLOSED",
	"OPENING",
	"OPEN",
	"CLOSING",
}

local LoadoutWidget = Class(Widget, function(self, player)
	Widget._ctor(self, "LoadoutWidget")

	self:SetOwningPlayer(player)

	self.equipmentPanel = self:AddChild(EquipmentPanel())

	self:SetPlayer(player)

	local w, h = self:GetSize()
	self.offscreen_x = RES_X/2 + w/2
	self.onscreen_x = RES_X/2 - w/2

	self:SetMultColorAlpha(0)
	self:SetPosition(self.offscreen_x, 0)

	self.state = WIDGET_STATE.s.CLOSED
	self.should_show = false
end)

function LoadoutWidget:SetPlayer(player)
	-- LoadoutWidget should get destroyed if player is destroyed, so not listening for remove.
	self.player = player
	self:Refresh()
	self.player:ListenForEvent("loadout_changed", function() self:Refresh() end)
end

function LoadoutWidget:Refresh()
	self.equipmentPanel:Refresh(self.player)
	return self
end

function LoadoutWidget:SetState(state)
	self.state = state
end

function LoadoutWidget:OnLoadoutKey(toggle_mode)
	if TheWorld:HasTag("town") then return end

	-- Check whether the emote-key is being held down or not
	self.should_show = (toggle_mode == "down")

	if self.should_show and self.state == WIDGET_STATE.s.CLOSED then
		self:AnimateIn()
	elseif not self.should_show and self.state == WIDGET_STATE.s.OPEN then
		self:AnimateOut()
	end
end

local animate_time = 0.25

function LoadoutWidget:AnimateIn()
	-- Get default positions
	self:SetState(WIDGET_STATE.s.OPENING)
	self:SetMultColorAlpha(0)

	-- Start animating
	self:RunUpdater(Updater.Series({
		-- Animate in the character panel
		Updater.Wait(0.1),
		Updater.Parallel({
			Updater.Ease(function(v) self:SetMultColorAlpha(v) end, 0, 1, animate_time, easing.outCubic),
			Updater.Ease(function(v) self:SetPosition(v, 0) end, self.offscreen_x, self.onscreen_x, animate_time, easing.outCubic),
		}),
		Updater.Do(function()
			self:SetState(WIDGET_STATE.s.OPEN)
			if not self.should_show then
				self:AnimateOut()
			end
		end),
	}))

	return self
end

function LoadoutWidget:AnimateOut()
	-- Start animating
	self:SetState(WIDGET_STATE.s.CLOSING)
	self:RunUpdater(Updater.Series({
		-- Animate in the character panel
		Updater.Parallel({
			Updater.Ease(function(v) self:SetMultColorAlpha(v) end, 1, 0, animate_time, easing.inCubic),
			Updater.Ease(function(v) self:SetPosition(v, 0) end, self.onscreen_x, self.offscreen_x, animate_time, easing.inCubic),
		}),
		Updater.Do(function()
			self:SetState(WIDGET_STATE.s.CLOSED)
			if self.should_show then
				self:AnimateIn()
			end
		end),
	}))

	return self
end

return LoadoutWidget
