local Widget = require("widgets/widget")
local Image = require('widgets/image')
local Text = require('widgets/text')
local ProgressBar = require("widgets/ftf/progressbar")
local UnlockableRewardWidget = require('widgets/ftf/unlockablerewardwidget_temp')

local easing = require "util.easing"

local MetaProgressWidget = Class(Widget, function(self, owner)
	Widget._ctor(self, "MetaProgressWidget")

	self.owner = owner

	self.reward_widgets = {}
	self.level_reward_root = self:AddChild(Widget("Level Rewards"))

	self.bar = self:AddChild(ProgressBar())
	self.level_root = self.bar:AddChild(Widget("Level Indicator"))
	self.level_bg = self.level_root:AddChild(Image("images/ui_ftf/meta_level_bg.tex")):SetSize(50 * HACK_FOR_4K, 50 * HACK_FOR_4K)
	self.level_text = self.level_root:AddChild(Text(FONTFACE.DEFAULT, 50, 0, UICOLORS.LIGHT_TEXT_TITLE))

	self.level_reward_root:LayoutBounds("left", "below", self.bar):Offset(0, -15)

	self.rewards_per_row = 6
end)

function MetaProgressWidget:GetMetaProgress()
	return self.meta_progress
end

function MetaProgressWidget:NotDiscovered()
	self.level_reward_root:Hide()
	self:SetMultColor(0,0,0)
end

function MetaProgressWidget:SetMetaProgressData(meta_progress, log)
	self.meta_progress = meta_progress

	local level = meta_progress:GetLevel()
	local exp = meta_progress:GetEXP()
	local max_exp = self.meta_progress:GetEXPForLevel(level)

	if log and #log > 0 then
		self.log = log
		level = log[1].start_level
		exp = log[1].start_exp
		max_exp = self.meta_progress:GetEXPForLevel(level)
	end

	self:SetProgressData(level, exp, max_exp)
	self:LayoutRewardWidgets(level)
end

function MetaProgressWidget:LayoutRewardWidgets(level)
	if not self.meta_progress then
		return
	end

	self.level_reward_root:RemoveAllChildren()
	local rewards = self.meta_progress.def.rewards
	for i, reward in pairs(rewards) do
		local w = self:MakeRewardWidget(i, reward.def, 65)
		self.reward_widgets[i] = w
		self.level_reward_root:AddChild(w)

		if level + 1 < i then
			w:SetHidden(w)
		elseif level + 1 == i then
			w:SetUnHidden()
		end
	end

	self.level_reward_root:LayoutChildrenInGrid(self.rewards_per_row, 0)
	self.level_reward_root:LayoutBounds("left", "below", self.bar)
		:Offset(0, -5)
end

function MetaProgressWidget:MakeRewardWidget(level, def, size)
	return UnlockableRewardWidget(self.owner, self, level, def, size)
end

function MetaProgressWidget:SetLevelText(level)
	self.level_text:SetText(level)
	self.level_text:LayoutBounds("center", "center", self.level_bg)
end

function MetaProgressWidget:SetProgressData(level, current, max)
	self:SetLevelText(level)
	self.bar:SetMaxProgress(max)
	self.bar:SetProgressPercent(current/ max)
	return self
end

function MetaProgressWidget:ShowMetaProgression()
	if not self.log then
		return nil
	end
	self.log_has_levelling = #self.log > 1
	local presentation = {}
	for i, data in ipairs(self.log) do
		local num_left = #self.log - i
		self:BarMovementPresentation(presentation, data, num_left)
		if data.did_level then
			self:LevelUpPresentation(presentation, data)
		end
	end
	self:RunUpdater(Updater.Series(presentation))
end

function MetaProgressWidget:BarMovementPresentation(pres, data, remaining)
	local percent_delta = (data.end_exp - data.start_exp) / self.meta_progress:GetEXPForLevel(data.start_level)

	local bar_time = (self.log_has_levelling and remaining == 0) and 3 or (1.5 * percent_delta)

	bar_time = math.max(bar_time, 0.75)

	local easefn = remaining == 0 and easing.outSine or easing.linear

	table.insert(pres, Updater.Parallel({
		Updater.Do(function()
			self:SetProgressData(data.start_level, data.start_exp, self.meta_progress:GetEXPForLevel(data.start_level))
			self:ProgressTo(data.start_exp, data.end_exp, bar_time, easefn)
		end),
		Updater.Wait(bar_time)
	}))
end

function MetaProgressWidget:LevelUpPresentation(pres, data)
	table.insert(pres, Updater.Do(function()
		self:SetLevelText(data.start_level + 1)
	end))

	if self.reward_widgets[data.start_level + 1] then
		self.reward_widgets[data.start_level + 1]:SetUnlocked(pres)
	end

	table.insert(pres, Updater.Do(function()
		self:SetProgressData(data.start_level + 1, 0, self.meta_progress:GetEXPForLevel(data.start_level + 1))
	end))

	if self.reward_widgets[data.start_level + 2] then
		self.reward_widgets[data.start_level + 2]:SetUnHidden(pres)
	end
end

function MetaProgressWidget:PreviewExperienceGain(exp)
	local end_level, end_exp = self.meta_progress:PreviewExperienceGain(exp)
	self:SetProgressData(end_level, end_exp, self.meta_progress:GetEXPForLevel(end_level))
end

function MetaProgressWidget:AddLevelUpReward(pres, data)
	local w = self:MakeRewardWidget(data.reward.def)
	self.level_reward_root:AddChild(w)
	self.level_reward_root:LayoutChildrenInGrid(5, 5)

	w:SetMultColorAlpha(0)
	table.insert(pres, Updater.Parallel({
			Updater.Ease(function(v) w:SetMultColorAlpha(v) end, 0, 1, 0.1, easing.outQuad),
			Updater.Ease(function(v) w:SetScale(v) end, 2, 1, 0.08, easing.outQuad),
		}))
end

function MetaProgressWidget:SetBarSize( ... )
	self.bar:SetBarSize( ... )
	self.level_root:LayoutBounds("before", "center", self.bar)
		:Offset(40, 5)
	-- self.level_reward_root:LayoutBounds("left", "below", self.bar):Offset(33, -50)
	return self
end

function MetaProgressWidget:ProgressTo( ... )
	self.bar:ProgressTo( ... )
	return self
end

return MetaProgressWidget
