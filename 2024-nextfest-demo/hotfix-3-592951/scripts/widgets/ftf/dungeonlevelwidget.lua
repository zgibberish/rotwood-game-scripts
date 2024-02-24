local Widget = require("widgets/widget")
local Text = require("widgets/text")
local Image = require("widgets/image")
local RadialProgress = require("widgets/radialprogress")
local UIAnim = require "widgets.uianim"
local fmodtable = require "defs.sound.fmodtable"
local soundutil = require "util.soundutil"
local audioid = require "defs.sound.audioid"
local easing = require "util.easing"
local MetaProgress = require("defs.metaprogression")

local xp_tick_sound_map = {fmodtable.Event.endOfRun_XP_tick_1P, fmodtable.Event.endOfRun_XP_tick_2P, fmodtable.Event.endOfRun_XP_tick_3P, fmodtable.Event.endOfRun_XP_tick_4P}

--   ┌─────────────────────────────────┐◄ only shows if self:ShowLargePresentation() is called
--   │ title_container                 │
--   └─────────────────────────────────┘
-- ┌─────────────────────────────────────┐◄ only shows if self:ShowLargePresentation() is called
-- │ top_container                       │
-- └─────────────────────────────────────┘
--              ┌───────────┐◄ badge_bg
--              │ badge     │  badge_radial
--              │           │  badge_overlay
--              │           │  badge_value
--              │           │
--              │           │
--              │           │
--              └───────────┘
--          ┌───────────────────┐◄ only shows if self:ShowLargePresentation() is called
--          │ bottom_decor      │
--          └───────────────────┘

local DungeonLevelWidget = Class(Widget, function(self, player)
	Widget._ctor(self, "DungeonLevelWidget")

	self.progress_color = HexToRGB(0xE0B8FFff)

	-- The badge itself
	self.badge = self:AddChild(Widget())
		:SetName("Badge")
	self.badge_bg = self.badge:AddChild(Image("images/ui_ftf_runsummary/DungeonLevelBg.tex"))
		:SetName("Badge bg")
	self.badge_radial = self.badge:AddChild(RadialProgress("images/ui_ftf_runsummary/DungeonLevelRadial.tex"))
		:SetName("Badge radial")
		:SetSize(100 * HACK_FOR_4K, 100 * HACK_FOR_4K)
		:SetMultColor(self.progress_color)
	self.badge_overlay = self.badge:AddChild(Image("images/ui_ftf_runsummary/DungeonLevelOverlay.tex"))
		:SetName("Badge overlay")
	self.badge_glow = self.badge:AddChild(Image("images/glow.tex"))
		:SetName("Glow")
		:SetSize(110 * HACK_FOR_4K, 110 * HACK_FOR_4K)
		:SetMultColor(self.progress_color)
		:SetMultColorAlpha(0)
		:SetHiddenBoundingBox(true)
	self.badge_value = self.badge:AddChild(Text(FONTFACE.DEFAULT, 52 * HACK_FOR_4K, "", self.progress_color))
		:SetName("Value")
	self.should_play_sound = true

	if player then self:SetPlayer(player) end
	self:Layout()
end)

function DungeonLevelWidget:SetPlayer(player)
	self.player = player
	self.player_id = self.player:GetHunterId()
	self.xp_tick_sound = xp_tick_sound_map[self.player_id]
	self.faction = player:IsLocal() and 1 or 2 -- sets faction parameter to 1 for local players, 2 for remote

	return self
end

-- Large presentation for UI panels
-- Includes the title container, top bar with progress value, and bottom decorations
function DungeonLevelWidget:ShowLargePresentation(decor_color, title_color, title_font_size, text_width)
	if self.title_container then return self end

	self.decor_color = decor_color or UICOLORS.DARK_TEXT_DARKER
	self.title_color = title_color or UICOLORS.DARK_TEXT_DARKER

	self.title_container = self:AddChild(Widget())
		:SetName("Title container")

	local title_size = title_font_size or 88
	self.title = self.title_container:AddChild(Text(FONTFACE.DEFAULT, title_size, "", self.title_color))
		:SetName("Title container")
		:SetAutoSize(text_width or 450)
		:OverrideLineHeight(title_size * 0.9)

	self.top_container = self:AddChild(Widget())
		:SetName("Top container")
	self.top_container_bg = self.top_container:AddChild(Image("images/ui_ftf_runsummary/DungeonLevelTopDecor.tex"))
		:SetName("Top container bg")
		:SetMultColor(self.decor_color)
	self.top_container_value = self.top_container:AddChild(Text(FONTFACE.DEFAULT, 21 * HACK_FOR_4K, "", self.progress_color))
		:SetName("Top container value")

	self.bottom_decor = self:AddChild(Image("images/ui_ftf_runsummary/DungeonLevelBottomDecor.tex"))
		:SetName("Bottom decor")
		:SetMultColor(self.decor_color)
		:SendToBack()

	self:Layout()
	return self
end

function DungeonLevelWidget:SetTitleFontSize(font_size)
	if not self.title_container then return self end
	local title_size = font_size or 88
	self.title:SetFontSize(font_size)
		:OverrideLineHeight(title_size * 0.9)
	self:Layout()
	return self
end

function DungeonLevelWidget:RefreshMetaProgress(biome_exploration)

	self.biome_exploration = biome_exploration
	self.meta_reward = self.biome_exploration.meta_reward
	self.meta_reward_def = MetaProgress.FindProgressByName(TheDungeon:GetDungeonMap().data.region_id)

	self.meta_level = self.biome_exploration.meta_level
	self.meta_exp = self.biome_exploration.meta_exp
	self.meta_exp_max = self.biome_exploration.meta_exp_max

	if self.biome_exploration.meta_reward_log and #self.biome_exploration.meta_reward_log > 0 then
		self.meta_reward_log = self.biome_exploration.meta_reward_log
		self.meta_level = self.meta_reward_log[1].start_level
		self.meta_exp = self.meta_reward_log[1].start_exp
		self.meta_exp_max = MetaProgress.GetEXPForLevel(self.meta_reward_def, self.meta_level)
	end

	-- Set progress
	self:SetProgress(self.meta_level, self.meta_exp, self.meta_exp_max)

	-- And the name of the current dungeon
	self:SetBiomeTitle(self.meta_reward_def.pretty.name)

	return self
end

function DungeonLevelWidget:SetBiomeTitle(name)
	if self.title_container then
		self.title:SetText(name)

		self:Layout()
	end
	return self
end

function DungeonLevelWidget:SetProgress(level, exp, exp_max)

	-- Set current level
	self:SetLevelText(level)

	-- Set progress bar
	self:SetProgressData(exp, exp_max)

	self:Layout()
	return self
end

function DungeonLevelWidget:GetMetaLevel()
	return self.meta_level
end

function DungeonLevelWidget:ShouldPlaySound(should_play_sound)
	-- this defaults to true in initial setup (works for end run screen)
	-- but we set it to false when it's called from the map sidebar because it never animates there
	-- and therefore shouldn't play sound
	self.should_play_sound = should_play_sound
end

-- Callback:
-- on_progress_fn(current_level, move_up, reward_earned, next_reward, sequence_done)
function DungeonLevelWidget:ShowMetaProgression(on_progress_fn)
	if not self.meta_reward_log then
		--sound
		--immediately stop SetProgressData looping sound if we're aborting here
		--if self.handle then
		--	TheFrontEnd:GetSound():KillSound(self.handle)
		--	self.handle = nil
		--end

		return nil
	end

	-- Let's loop through the levels gained, show the progress, and update the main screen
	local levels_gained = self.meta_reward_log
	local has_moved_up = false

	local presentation = {}
	for i, level_data in ipairs(levels_gained) do
		local level_num = level_data.start_level

		-- Show bar increasing
		local levels_left_to_animate = #levels_gained - i
		self:BarMovementPresentation(presentation, level_data, levels_left_to_animate)

		-- If we leveled up, notify the parent
		if level_data.did_level then
			self:LevelUpPresentation(presentation, level_data)
		end

		-- If the parent widget hasn't moved up, do it
		if not has_moved_up then
			table.insert(presentation, Updater.Wait(0.2))
			table.insert(presentation, Updater.Do(function() on_progress_fn(level_num, true, nil, nil, nil) end))
			table.insert(presentation, Updater.Wait(0.4))
			has_moved_up = true
		end

		-- Then show the reward
		if level_data.did_level then
			-- you get the reward on achieving the level
			-- ie: leveling from 0 -> 1 grants you the reward for level 1
			local current_reward = MetaProgress.GetRewardForLevel(self.meta_reward_def, level_num + 1)
			table.insert(presentation, Updater.Do(function() on_progress_fn(level_num, nil, current_reward, nil, nil) end))
			table.insert(presentation, Updater.Wait(1.6))
		end

		-- Show the upcoming reward
		if levels_left_to_animate == 0 then

			local next_level = level_num + 1

			local perfect_level = level_data.did_level

			if perfect_level then
				-- We actually did level up to the next level, but got 0 exp in the next level so there is no presentation to be done.
				-- Because of that, we need to fake it.
				next_level = level_num + 2
			end

			local next_reward = MetaProgress.GetRewardForLevel(self.meta_reward_def, next_level)
			if next_reward then
				table.insert(presentation, Updater.Wait(0.6))
				table.insert(presentation, Updater.Do(function()
					if perfect_level then
						self:SetProgressData(0, MetaProgress.GetEXPForLevel(self.meta_reward_def, next_level))
					end
					on_progress_fn(next_level, nil, nil, next_reward, nil)
				end))
				table.insert(presentation, Updater.Wait(0.8))
				table.insert(presentation, Updater.Do(function() on_progress_fn(next_level, nil, nil, nil, true) end))
			end
		end
	end

	self:RunUpdater(Updater.Series(presentation))
end

function DungeonLevelWidget:BarMovementPresentation(pres, data, remaining)

	local percent_delta = (data.end_exp - data.start_exp) / MetaProgress.GetEXPForLevel(self.meta_reward_def, data.start_level)

	local bar_time = (self.log_has_levelling and remaining == 0) and 3 or (1.5 * percent_delta)

	bar_time = math.max(bar_time, 0.75)

	local easefn = remaining == 0 and easing.outSine or easing.linear

	table.insert(pres, Updater.Parallel({
		Updater.Do(function()
			self:SetProgressData(data.start_exp, MetaProgress.GetEXPForLevel(self.meta_reward_def, data.start_level))
		end),

		Updater.Ease(function(v) self:SetProgressData(v, self.meta_exp_max) end, data.start_exp, data.end_exp, bar_time, easefn),
		Updater.Series({
			Updater.Wait(bar_time),
			--Updater.Do(function()
			--	if self.handle then
			--		TheFrontEnd:GetSound():KillSound(self.handle)
			--		self.handle = nil
			--	end
			--end),
		})
	}))

end

function DungeonLevelWidget:LevelUpPresentation(pres, data)
	table.insert(pres, Updater.Do(function()
		self.meta_level = data.start_level + 1
		self:SetLevelText(self.meta_level)
		self.badge_glow:RunUpdater(Updater.Ease(function(v) self.badge_glow:SetMultColorAlpha(v) end, 0.9, 0, 1.2, easing.inQuad))
		self.badge:RunUpdater(Updater.Ease(function(v) self.badge:SetScale(v) end, 1.1, 1, 0.4, easing.inQuad))
		self.meta_exp_max = MetaProgress.GetEXPForLevel(self.meta_reward_def, self.meta_level)
	end))
end

function DungeonLevelWidget:SetLevelText(level)
	self.badge_value:SetText(level)
	self:Layout()
end

function DungeonLevelWidget:SetProgressData(current, max)
	self.badge_radial:SetProgress(current/max)
	if self.title_container then
		self.top_container_value:SetText(string.format(STRINGS.UI.DUNGEONLEVELWIDGET.PROGRESS_VALUE, math.round(current, 0), max))
	end

	-- initialize var for setting pitch for musical stinger / baseline pitch of looping XP bar
	if not self.levels_gained_this_session then
		self.levels_gained_this_session = 1
	end

	local xp_parameter_for_sound = (current/max)

	-- start looping XP sound
	--if not self.handle then
	--	self.handle = self:PlaySpatialSound(fmodtable.Event.endOfRun_XP_tick_LP, { faction_player_id = self.player_id})	
	--else
	--	TheFrontEnd:GetSound():SetParameter(self.handle, "xp_percent", xp_parameter_for_sound)
	--	TheFrontEnd:GetSound():SetParameter(self.handle, "levels_gained", self.levels_gained_this_session)
	--end

	-- on level up. Could probably also do this in LevelUpPresentation()
	if xp_parameter_for_sound == 1 then
		if self.levels_gained_this_session == 1 then
			audioid.oneshot.stinger = self:PlaySpatialSound(fmodtable.Event.Mus_levelUp_Stinger, { faction = self.faction, faction_player_id = self.player_id })
		end

		self:PlaySpatialSound(fmodtable.Event.endOfRun_XP_levelUp, { faction = self.faction, levels_gained = self.levels_gained_this_session })
		self.levels_gained_this_session = self.levels_gained_this_session + 1

		-- stop looping sound when it's not animating
		--TheFrontEnd:GetSound():KillSound(self.handle)
		--self.handle = nil
	end

	-- plays the event associated with a given player banner's XP tick sound

	-- do not play the sound on initial draw, only when the meter actually animates
	if self.badge_radial.is_initial_draw == nil then
		self.badge_radial.is_initial_draw = false
	elseif self.badge_radial.is_initial_draw == false then
		self.badge_radial.is_initial_draw = true
	end
	
	if self.badge_radial.is_initial_draw and self.should_play_sound then
		self.handle = self:PlaySpatialSound(self.xp_tick_sound, { faction = self.faction, xp_percent = xp_parameter_for_sound, levels_gained = self.levels_gained_this_session })
	end
		
	return self
end

function DungeonLevelWidget:Layout()

	self.badge_value:LayoutBounds("center", "center", self.badge_bg)
		:Offset(0 * HACK_FOR_4K, 3 * HACK_FOR_4K)

	if self.title_container then

		self.top_container_value:LayoutBounds("center", "center", self.top_container_bg)
			:Offset(0 * HACK_FOR_4K, -3.5 * HACK_FOR_4K)
		self.top_container:LayoutBounds("center", "above", self.badge)
			:Offset(0 * HACK_FOR_4K, 1 * HACK_FOR_4K)

		self.title_container:LayoutBounds("center", "above", self.top_container)
			:Offset(0 * HACK_FOR_4K, 6 * HACK_FOR_4K)

		self.bottom_decor:LayoutBounds("center", "below", self.badge)
			:Offset(0 * HACK_FOR_4K, 40 * HACK_FOR_4K)
	end

	return self
end

return DungeonLevelWidget
