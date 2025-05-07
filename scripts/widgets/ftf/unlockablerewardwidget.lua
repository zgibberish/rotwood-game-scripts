local Widget = require("widgets/widget")
local Panel = require('widgets/panel')
local Text = require('widgets/text')

local PowerWidget = require("widgets/ftf/powerwidget")
local UnlockableRewardDetailsScreen = require("screens/unlockablerewarddetailsscreen")

local LockedMetaRewardWidget = require("widgets/ftf/lockedmetarewardwidget")

local itemforge = require"defs.itemforge"
local Power = require"defs.powers"
local Consumable = require"defs.consumable"

local easing = require "util.easing"

local UnlockableRewardWidget = Class(Widget, function(self, width, owner, level, def)
	Widget._ctor(self, "UnlockableRewardWidget")

	self.owner = owner
	self.level = level
	self.width = width or 107 * HACK_FOR_4K
	self.icon_width = 100 * HACK_FOR_4K
	self.text_padding_w = 70
	self.text_padding_h = 30
	self.details_w = self.width - self.icon_width*0.6
	self.details_h_min = self.icon_width*0.9
	self.text_w = self.details_w - self.text_padding_w*2

	self.icon_root = self:AddChild(Widget("Icon Root"))
	self.icon = nil -- created when SetUnlockableData is called

	self.details_bg = self:AddChild(Panel("images/ui_ftf_powers/PowerDetailsBg.tex"))
		:SetNineSliceCoords(84, 8, 502, 150)
		:SetMultColor(0x261E1Dff)
		:SetSize(self.details_w, self.details_h_min)
	self.instructions_label = self:AddChild(Text(FONTFACE.DEFAULT, FONTSIZE.ROOMBONUS_TEXT * 0.8))
		:SetGlyphColor(UICOLORS.LIGHT_TEXT_DARK)
	self.text_container = self:AddChild(Widget("text container"))
	self.title = self.text_container:AddChild(Text(FONTFACE.DEFAULT, FONTSIZE.DIALOG_SUBTITLE * 0.8))
		:SetGlyphColor(UICOLORS.LIGHT_TEXT)
		:SetAutoSize(self.text_w)
	self.description = self.text_container:AddChild(Text(FONTFACE.DEFAULT, FONTSIZE.ROOMBONUS_TEXT * 0.7))
		:SetGlyphColor(UICOLORS.LIGHT_TEXT_DARK)
		:SetAutoSize(self.text_w)

	if level or def then
		self:SetUnlockableData(level, def)
	end
end)

function UnlockableRewardWidget:SetUnlockableData(level, def)
	if def.slot == Consumable.Slots.KEY_ITEMS then
		self.fake_item = itemforge.CreateKeyItem(def)
		self.icon = self.icon_root:AddChild(LockedMetaRewardWidget(self.icon_width, self.owner, self.fake_item))
		self.title:SetText(def.pretty.name)
		self.description:SetText("description missing")
	else
		self.fake_item = self.owner.components.powermanager:CreatePower(def)
		self.icon = self.icon_root:AddChild(PowerWidget(self.icon_width, self.owner, self.fake_item))
			:DisableToolTip(true)
		self.title:SetText(def.pretty.name)
		self.description:SetText(Power.GetDescForPower(self.fake_item))
	end
	self:Layout()
end

function UnlockableRewardWidget:SetTitleColor(color)
	self.title:SetGlyphColor(color)
	return self
end

function UnlockableRewardWidget:SetBackgroundColor(color)
	self.details_bg:SetMultColor(color)
	return self
end

function UnlockableRewardWidget:SetInstructions(instructions)
	self.instructions_label:SetText(instructions)
		:SetShown(instructions)
	self:Layout()
	return self
end

function UnlockableRewardWidget:SetUnHidden(pres)
	self:SetInstructions(string.format(STRINGS.UI.DUNGEONLEVELWIDGET.REWARD_UNLOCK_LEVEL, self.level))
	self.text_container:SetMultColorAlpha(0)
	return self
end

function UnlockableRewardWidget:SetUnlocked(optional_text_above)

	local lock_label_x, lock_label_y = self.instructions_label:GetPos()
	local text_x, text_y = self.text_container:GetPos()

	-- Setup animation
	local animation = Updater.Series{
		Updater.Ease(function(v) self.instructions_label:SetScale(v) end, 1, 1.1, 0.5, easing.outQuad),
		Updater.Parallel{
			Updater.Ease(function(v) self.instructions_label:SetMultColorAlpha(v) end, 1, 0, 0.1, easing.outQuad),
			Updater.Ease(function(v) self.instructions_label:SetPos(lock_label_x, v) end, lock_label_y, lock_label_y+10 * HACK_FOR_4K, 0.1, easing.outQuad),
		},
		Updater.Wait(0.1),
		Updater.Parallel{
			Updater.Ease(function(v) self.text_container:SetMultColorAlpha(v) end, 0, 1, 0.2, easing.outQuad),
			Updater.Ease(function(v) self.text_container:SetPos(text_x, v) end, text_y-5, text_y, 0.2, easing.outQuad),
		}
	}

	-- If there's a label to show above the widget at the end, add it here
	if optional_text_above then
		animation:Add(Updater.Wait(0.1))
		animation:Add(Updater.Parallel{
			Updater.Do(function()
				self.instructions_label:SetText(optional_text_above)
					:LayoutBounds("center", nil, self)
					:LayoutBounds(nil, "above", self.details_bg)
					:Offset(0, 4)
			end),
			Updater.Ease(function(v) self.instructions_label:SetMultColorAlpha(v) end, 0, 1, 0.1, easing.outQuad),
		})
	end

	self:RunUpdater(animation)
end

function UnlockableRewardWidget:Layout()
	self.description:LayoutBounds("center", "below", self.title)
		:Offset(0, 1)
	-- Calculate text height and resize bg
	local t_w, t_h = self.text_container:GetSize()
	local details_h = math.max(self.details_h_min, t_h + self.text_padding_h*2)
	self.details_bg:SetSize(self.details_w, details_h)
		:LayoutBounds("left", "bottom", self.icon)
		:Offset(self.icon_width*0.5, -20)
	self.text_container:LayoutBounds("center", "center", self.details_bg)
		:Offset(20 * HACK_FOR_4K, 0)
	self.instructions_label:LayoutBounds("center", "center", self.text_container)
		:Offset(0, -1 * HACK_FOR_4K)

	return self
end

return UnlockableRewardWidget
