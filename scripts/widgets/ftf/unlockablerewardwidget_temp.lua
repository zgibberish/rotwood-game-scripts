local Widget = require("widgets/widget")
local Image = require('widgets/image')
local Text = require('widgets/text')

local PowerWidget = require("widgets/ftf/powerwidget")
local UnlockableRewardDetailsScreen = require("screens/unlockablerewarddetailsscreen")

local LockedMetaRewardWidget = require("widgets/ftf/lockedmetarewardwidget")

local itemforge = require"defs.itemforge"
local Power = require"defs.powers"
local Consumable = require"defs.consumable"

local easing = require "util.easing"

local UnlockableRewardWidget_TEMP = Class(Widget, function(self, owner, metarewardprogresswidget, level, def, size)
	Widget._ctor(self, "UnlockableRewardWidget_TEMP")

	self.owner = owner
	self.metarewardprogresswidget = metarewardprogresswidget

	self.icon_root = self:AddChild(Widget("Icon Root"))
	self.icon = nil -- created when SetUnlockableData is called

	self.level_root = self:AddChild(Widget("Level Indicator"))
	self.level_bg = self.level_root:AddChild(Image("images/ui_ftf/meta_level_bg.tex"))
		:SetSize(25 * HACK_FOR_4K, 25)
	self.level_text = self.level_root:AddChild(Text(FONTFACE.DEFAULT, 20, 0, UICOLORS.LIGHT_TEXT_TITLE))

	self.lock_icon = self:AddChild(Image("images/ui_ftf_dialog/convo_lock.tex"))
		:SetMultColor(0.9, 0.9, 0.9)
		:SetSize(25 * HACK_FOR_4K, 25)
		:Hide()

	self.new_unlock_indicator = self:AddChild(Image("images/ui_ftf_shop/item_unseen.tex"))
		:SetSize(25 * HACK_FOR_4K, 25)
		:Hide()

	if level or def then
		self:SetUnlockableData(level, def, size)
	end
end)

function UnlockableRewardWidget_TEMP:SetUnlockableData(level, def, size)
	local w = nil
	size = size or 70
	self.lock_icon:SetSize(size/3, size/3)
		:LayoutBounds("after", "above")
		:Offset(-size/6, -size/10)

	self.new_unlock_indicator:SetSize(size/2, size/2)
	if def.slot == Consumable.Slots.KEY_ITEMS then
		self.fake_item = itemforge.CreateKeyItem(def)
		w = LockedMetaRewardWidget(size, self.owner, self.fake_item)
	else
		self.fake_item = self.owner.components.powermanager:CreatePower(def)
		w = PowerWidget(size, self.owner, self.fake_item)
	end

	self.icon = self.icon_root:AddChild(w)

	if level then
		self:SetLevelText(level)
	else
		self.level_root:Hide()
	end

	self:Layout()
end

function UnlockableRewardWidget_TEMP:SetHidden()
	self.icon:SetSaturation(0)
	self.icon:DisableToolTip(true)
	self:SetToolTip("???")
	self.lock_icon:Show()
	self.lock_icon:SendToFront()
end

function UnlockableRewardWidget_TEMP:SetUnHidden(pres)
	self.lock_icon:Show()
	self.lock_icon:SendToFront()

	if not pres then
		self.icon:SetSaturation(1)
		self.icon:DisableToolTip(false)
	else
		table.insert(pres, Updater.Series{
			Updater.Ease(function(v) self.icon:SetSaturation(v) end, 0, 1, 0.5, easing.outQuad),
			Updater.Do(function() self.icon:DisableToolTip(false) end),
			Updater.Wait(0.33),
		})
	end
end

function UnlockableRewardWidget_TEMP:SetUnlocked(pres)
	self.lock_icon:SendToFront()
	table.insert(pres, Updater.Series{
		Updater.Do(function() self.owner:PushEvent("show_meta_reward", { widget = self.metarewardprogresswidget, showing = true }) end),
		Updater.Ease(function(v) self.lock_icon:SetScale(v) end, 1, 2.5, 0.5, easing.outQuad),
		Updater.Do(function()
			self.lock_icon:SetTexture("images/ui_ftf_dialog/convo_unlock.tex")
		end),
		Updater.Wait(0.33),
		Updater.Parallel({
			Updater.Ease(function(v) self.lock_icon:SetScale(v) end, 2.5, 0, 0.5, easing.outQuad),
		}),
		Updater.Do(function()
			self.lock_icon:Hide()
			self.new_unlock_indicator:Show()
		end),
		Updater.Parallel({
			Updater.Ease(function(v) self.new_unlock_indicator:SetScale(v) end, 1, 2, 0.2, easing.outQuad),
			Updater.Ease(function(v) self.new_unlock_indicator:SetRotation(v) end, 0, 10, 0.2, easing.inOutQuad),
		}),
		Updater.Parallel({
			Updater.Ease(function(v) self.new_unlock_indicator:SetScale(v) end, 2, 1, 0.2, easing.inQuad),
			Updater.Ease(function(v) self.new_unlock_indicator:SetRotation(v) end, 10, 0, 0.2 * 2, easing.outElastic),
		}),
		Updater.Do(function() self:ShowDetailsButton() end),
		Updater.While(function() return self.showing_bonus end),
		Updater.Do(function() self.owner:PushEvent("show_meta_reward", { widget = self.metarewardprogresswidget, showing = false }) end)
	})
end

function UnlockableRewardWidget_TEMP:ShowDetailsButton()
	self.showing_bonus = true

	local screen
	local cb_fn = function()
		self.showing_bonus = false
		TheFrontEnd:PopScreen(screen)
	end

	screen = UnlockableRewardDetailsScreen(self.owner, cb_fn)
	if self.fake_item.slot == Power.Slots.PLAYER then
		screen:ShowPowerDetails(self.fake_item)
	elseif self.fake_item.slot == Consumable.Slots.KEY_ITEMS then
		screen:ShowItemDetails(self.fake_item)
	end
	TheFrontEnd:PushScreen(screen)
end

function UnlockableRewardWidget_TEMP:SetLevelText(level)
	self.level_text:SetText(level)
	self.level_text:LayoutBounds("center", "center", self.level_bg)
end

function UnlockableRewardWidget_TEMP:Layout()
	self.level_root:LayoutBounds("left", "top", self.icon_root)
	self.new_unlock_indicator:LayoutBounds("right", "bottom", self.icon_root)
end

return UnlockableRewardWidget_TEMP
