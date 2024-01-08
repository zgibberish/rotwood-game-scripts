local Widget = require("widgets/widget")
local Panel = require('widgets/panel')
local Image = require('widgets/image')
local ImageButton = require('widgets/imagebutton')
local Text = require('widgets/text')
local HotkeyWidget = require('widgets/hotkeywidget')
local PowerWidget = require("widgets/ftf/powerwidget")
local UnlockableRewardDetailsScreen = require("screens/unlockablerewarddetailsscreen")
local UnlockableRewardWidget = require("widgets/ftf/unlockablerewardwidget")
local LockedMetaRewardWidget = require("widgets/ftf/lockedmetarewardwidget")

local itemforge = require"defs.itemforge"
local Power = require"defs.powers"
local Consumable = require"defs.consumable"

local easing = require "util.easing"

------------------------------------------------------------------------------------
-- Shows a widget for the run summary screen, with the power rewards earned,
-- along with the next one
--
-- ┌───────────────────────────────────────────────┐
-- │            ┌─────────────────────┐            │
-- │            │ info_label          │            │
-- │            └─────────────────────┘            │
-- │      ┌─────────────────────────────────┐      │ ◄ rewards_container
-- │ ┌──┐ │ UnlockableRewardWidget          │ ┌──┐ │
-- │ │  │ │                                 │ │  │ │ ◄ hotkey_next
-- │ └──┘ │                                 │ └──┘ │
-- │      └─────────────────────────────────┘      │
-- │                ┌┐ ┌┐ ┌┐ ┌┐ ┌┐ 			       │ ◄ navigation_dots_container
-- │                └┘ └┘ └┘ └┘ └┘                 │
-- └───────────────────────────────────────────────┘
--                                                 ▲ width
--
-- It allows the player to navigate between the various powers
local UnlockableRewardsContainer = Class(Widget, function(self, width, owner)
	Widget._ctor(self, "UnlockableRewardsContainer")

	self.owner = owner
	self.width = width or 300
	self.reward_width = self.width - 100

	self.current_idx = 1

	self.hitbox = self:AddChild(Image("images/global/square.tex"))
		:SetName("Hitbox")
		:SetSize(self.width, 340)
		:SetMultColor(UICOLORS.DEBUG)
		:SetMultColorAlpha(0.0)

	self.info_label = self:AddChild(Text(FONTFACE.DEFAULT, FONTSIZE.ROOMBONUS_TEXT * 0.8))
		:SetName("Info label")
		:SetGlyphColor(UICOLORS.LIGHT_TEXT_DARK)
		:SetHiddenBoundingBox(true)
		:SetMultColorAlpha(0)

	self.rewards_container = self:AddChild(Widget())
		:SetName("Rewards container")
		:SetHiddenBoundingBox(true)

	self.nav_buttons = self:AddChild(Widget())
		:SetName("Nav buttons") -- Only shown if there is more than one reward widget
		:Hide()
		:IgnoreInput(true)
	self.button_prev = self.nav_buttons:AddChild(ImageButton("images/ui_ftf_runsummary/pagination_left.tex"))
		:SetName("Button prev")
		:SetSize(90, 90)
		:SetMultColor(UICOLORS.LIGHT_TEXT_DARK)
		:SetNavFocusable(false)
		:SetOnClickFn(function() self:OnClickPrev() end)
	self.button_next = self.nav_buttons:AddChild(ImageButton("images/ui_ftf_runsummary/pagination_right.tex"))
		:SetName("Button next")
		:SetSize(90, 90)
		:SetMultColor(UICOLORS.LIGHT_TEXT_DARK)
		:SetNavFocusable(false)
		:SetOnClickFn(function() self:OnClickNext() end)
	self.hotkey_prev = self.nav_buttons:AddChild(HotkeyWidget(Controls.Digital.MENU_TAB_PREV))
		:SetName("Hotkey prev")
		-- :SetOnlyShowForGamepad()
		:SetMultColor(UICOLORS.LIGHT_TEXT_DARK)
		:SetHiddenBoundingBox(true)
	self.hotkey_next = self.nav_buttons:AddChild(HotkeyWidget(Controls.Digital.MENU_TAB_NEXT))
		:SetName("Hotkey next")
		-- :SetOnlyShowForGamepad()
		:SetMultColor(UICOLORS.LIGHT_TEXT_DARK)
		:SetHiddenBoundingBox(true)

	self.navigation_dots_container = self:AddChild(Widget())
		:SetName("Navigation dots container")
		:SetHiddenBoundingBox(true)
		:SetMultColorAlpha(0)
		:IgnoreInput(true)

	self:OnInputModeChanged(nil, TheInput.last_input.device_type)

	self:Layout()
end)

function UnlockableRewardsContainer:RemoveAllPowers()
	self.rewards_container:RemoveAllChildren()
	self.navigation_dots_container:RemoveAllChildren()
		:IgnoreInput(true)
	self.current_idx = 1
	self.nav_buttons:Hide()
		:IgnoreInput(true)
	self.nav_was_visible = false
	self:Layout()
end

function UnlockableRewardsContainer:AddRewardPower(power_def, slot, level_num, has_earned_reward)

	-- Create reward widget
	local reward_widget = self.rewards_container:AddChild(UnlockableRewardWidget(self.reward_width, self.owner, level_num, power_def))
		:SetTitleColor(UICOLORS.LIGHT_TEXT_DARKER)
		:SetBackgroundColor(0xCEB6A5ff)
		:SetMultColorAlpha(0)

	-- Save important info on it
	reward_widget.reward_idx = #self.rewards_container.children
	if has_earned_reward then
		reward_widget.info_text = STRINGS.UI.DUNGEONLEVELWIDGET.REWARD_UNLOCKED
	else
		reward_widget.info_text = string.format(STRINGS.UI.DUNGEONLEVELWIDGET.REWARD_UPCOMING, level_num)
	end

	-- Add corresponding navigation dot
	self.navigation_dots_container:AddChild(ImageButton("images/ui_ftf_runsummary/pagination_dot.tex"))
		:SetName("Nav dot " .. reward_widget.reward_idx)
		:SetSize(60, 60)
		:SetMultColor(UICOLORS.LIGHT_TEXT_DARK)
		:SetNavFocusable(false)
		:SetScaleOnFocus(false)
		:SetOnClickFn(function() if self.current_idx ~= reward_widget.reward_idx then self:AnimateToIdx(reward_widget.reward_idx) end end)

	-- If this is the first and not last power, show the dots from the beginning
	if #self.rewards_container.children == 1 and has_earned_reward then
		self.navigation_dots_container:SetShown(true)
			:SetMultColorAlpha(0)
			:AlphaTo(1, 0.3, easing.outQuad)
			:IgnoreInput(true)
	end

	-- Layout everything again
	self:Layout()

	-- Save its position, for animation purposes
	reward_widget.center_x, reward_widget.center_y = reward_widget:GetPos()

	-- And now animate it!
	self:AnimateToIdx(#self.rewards_container.children)
	return reward_widget
end

function UnlockableRewardsContainer:AnimateToIdx(new_idx, moving_right)
	if self.animating_to_idx then return self end

	self.animating_to_idx = true
	local old_idx = self.current_idx

	if #self.rewards_container.children == 1 then
		-- There's only one child
		local reward_widget = self.rewards_container.children[1]
		-- Animate it!
		local from_right = true
		self:_AnimateIn(reward_widget, from_right)
	else
		-- Animate out old_idx
		local from_right = new_idx > old_idx or new_idx == 1
		if moving_right ~= nil then
			from_right = moving_right
		end
		self:_AnimateOut(self.rewards_container.children[old_idx], from_right, function()
			self:_AnimateIn(self.rewards_container.children[new_idx], from_right)
		end)
	end
	self.current_idx = new_idx

	-- Highlight corresponding nav dot
	for k, v in ipairs(self.navigation_dots_container.children) do
		v:SetMultColorAlpha(k == self.current_idx and 1 or 0.4)
	end

	self:_RefreshShownButtons()

	return self
end

function UnlockableRewardsContainer:_RefreshShownButtons()

	-- Showing clickable buttons or hotkeys?
	local showing_clickable = not TheFrontEnd:IsRelativeNavigation()
	local can_go_forward = self.current_idx ~= #self.navigation_dots_container.children
	local can_go_backward = self.current_idx ~= 1

	self.button_prev:SetShown(can_go_backward and showing_clickable)
	self.button_next:SetShown(can_go_forward and showing_clickable)

	self.hotkey_prev:SetShown(can_go_backward and not showing_clickable)
	self.hotkey_next:SetShown(can_go_forward and not showing_clickable)

end

function UnlockableRewardsContainer:_AnimateIn(reward_widget, from_right)

	self.info_label:SetText(reward_widget.info_text)
		:LayoutBounds("center", nil, self.hitbox)
		:LayoutBounds(nil, "above", reward_widget)
		:Offset(0, 10)
	local info_label_x, info_label_y = self.info_label:GetPos()

	self.rewards_container:RunUpdater(Updater.Parallel{
		Updater.Ease(function(v) self.info_label:SetMultColorAlpha(v) end, self.info_label:GetMultColorAlpha(), 1, 0.2, easing.outQuad),
		Updater.Ease(function(v) self.info_label:SetPos(info_label_x, v) end, info_label_y-20, info_label_y, 0.6, easing.outElastic),
		Updater.Series{
			Updater.Wait(0.2),
			Updater.Do(function()
				self.animating_to_idx = false
			end),
			Updater.Parallel{
				Updater.Ease(function(v) reward_widget:SetMultColorAlpha(v) end, reward_widget:GetMultColorAlpha(), 1, 0.4, easing.outQuad),
				Updater.Ease(function(v) reward_widget:SetPos(v, reward_widget.center_y) end, reward_widget.center_x + (from_right and 80 or -80), reward_widget.center_x, 0.6, easing.outElastic),
			}
		}
	})
	return self
end

-- Animates a reward widget out, to the left or right
function UnlockableRewardsContainer:_AnimateOut(reward_widget, from_right, on_done)
	local info_label_x, info_label_y = self.info_label:GetPos()
	self.rewards_container:RunUpdater(Updater.Parallel{
		Updater.Ease(function(v) reward_widget:SetMultColorAlpha(v) end, reward_widget:GetMultColorAlpha(), 0, 0.2, easing.outQuad),
		Updater.Ease(function(v) reward_widget:SetPos(v, reward_widget.center_y) end, reward_widget.center_x, reward_widget.center_x + (from_right and -80 or 80), 0.2, easing.outQuad),
		Updater.Ease(function(v) self.info_label:SetMultColorAlpha(v) end, self.info_label:GetMultColorAlpha(), 0, 0.2, easing.outQuad),
		Updater.Ease(function(v) self.info_label:SetPos(v, info_label_y) end, info_label_x, info_label_x+ (from_right and -15 or 15), 0.2, easing.outQuad),
		Updater.Series{
			Updater.Wait(0.4),
			Updater.Do(function()
				if on_done then on_done() end
			end)
		}
	})
	return self
end

function UnlockableRewardsContainer:OnClickPrev()
	local can_go_backward = self.current_idx ~= 1

	if can_go_backward then
		local new_idx = self.current_idx - 1
		if new_idx < 1 then new_idx = #self.rewards_container.children end
		local moving_right = false
		self:AnimateToIdx(new_idx, moving_right)
	end
	return self
end

function UnlockableRewardsContainer:OnClickNext()
	local can_go_forward = self.current_idx ~= #self.navigation_dots_container.children

	if can_go_forward then
		local new_idx = self.current_idx + 1
		if new_idx > #self.rewards_container.children then
			new_idx = 1
		end
		local moving_right = true
		self:AnimateToIdx(new_idx, moving_right)
	end
	return self
end

function UnlockableRewardsContainer:ShowNav()
	local nav_now_visible = #self.rewards_container.children > 1
	if self.nav_was_visible == false and nav_now_visible then
		self.nav_buttons:SetShown(true)
			:SetMultColorAlpha(0)
			:AlphaTo(1, 0.3, easing.outQuad)
			:IgnoreInput(false)
		self.navigation_dots_container:SetShown(true)
			:AlphaTo(1, 0.3, easing.outQuad)
			:IgnoreInput(false)
		self.nav_was_visible = true
	end
	return self
end

function UnlockableRewardsContainer:OnInputModeChanged(old_device_type, new_device_type)
	self:_RefreshShownButtons()
end

function UnlockableRewardsContainer:Layout()
	self.button_prev:LayoutBounds("left", "center", self.hitbox):Offset(-20, 0)
	self.button_next:LayoutBounds("right", "center", self.hitbox):Offset(20, 0)
	self.hotkey_prev:LayoutBounds("left", "center", self.hitbox)
	self.hotkey_next:LayoutBounds("right", "center", self.hitbox)
	self.navigation_dots_container:LayoutChildrenInRow(-15)
		:LayoutBounds("center", "bottom", self.hitbox)
	for k, v in ipairs(self.rewards_container.children) do
		v:LayoutBounds("center", "center", self.hitbox)
	end
	return self
end

UnlockableRewardsContainer.CONTROL_MAP =
{
	{
		control = Controls.Digital.MENU_TAB_PREV,
		fn = function(self)
		print("UnlockableRewardsContainer.CONTROL_MAP Controls.Digital.MENU_TAB_PREV")
			self:OnClickPrev()
			return true
		end,
	},
	{
		control = Controls.Digital.MENU_TAB_NEXT,
		fn = function(self)
		print("UnlockableRewardsContainer.CONTROL_MAP Controls.Digital.MENU_TAB_NEXT")
			self:OnClickNext()
			return true
		end,
	},
}

return UnlockableRewardsContainer
