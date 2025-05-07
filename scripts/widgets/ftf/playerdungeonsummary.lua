local Widget = require("widgets/widget")
local Text = require("widgets/text")
local PlayerPuppet = require("widgets/playerpuppet")
local Image = require("widgets/image")
local ImageButton = require("widgets/imagebutton")
local LoadingIndicator = require("widgets/loadingindicator")
local UIAnim = require "widgets.uianim"
local DisplayStat = require("widgets/ftf/displaystat")
local SkillWidget = require("widgets/ftf/skillwidget")
local PowerWidget = require("widgets/ftf/powerwidget")
local DungeonLevelWidget = require("widgets/ftf/dungeonlevelwidget")
local InventorySlot = require "widgets.ftf.inventoryslot"
local ItemWidget = require("widgets/ftf/itemwidget")
local UnlockableRewardsContainer = require('widgets/ftf/unlockablerewardscontainer')
local UnlockableRewardWidget = require('widgets/ftf/unlockablerewardwidget')
local fmodtable = require "defs.sound.fmodtable"
local StringFormatter = require "questral.util.stringformatter"
local Equipment = require("defs.equipment")
local ItemCatalog = require("defs.itemcatalog")
local Consumable = require("defs.consumable")
local Power = require 'defs.powers'
local easing = require "util.easing"
local iterator = require "util.iterator"
local lume = require "util.lume"
local monster_pictures = require "gen.atlas.monster_pictures"
local PlayerTitleWidget = require("widgets/ftf/playertitlewidget")
local itemcatalog = require "defs.itemcatalog"
local itemforge = require "defs.itemforge"

local PlayerDungeonSummary = Class(Widget, function(self, player, reward_data)
	Widget._ctor(self, "PlayerDungeonSummary")

	-- Show rolled paper anim over the contents
	self.roll_anim = self:AddChild(UIAnim())
		:SetName("Roll anim")
		:SetScale(0.52 * HACK_FOR_4K)
		:SetBank("ui_scroll")
		:PlayAnimation("downidle")
	self.roll_anim_w, self.roll_anim_h = self.roll_anim:GetScaledSize()

	-- Player portrait
	self.puppet_container = self:AddChild(Widget())
		:SetName("Puppet container")
	self.puppet_bg = self.puppet_container:AddChild(Image("images/ui_ftf_runsummary/CharacterMask.tex"))
		:SetName("Puppet bg")
		:SetMultColor(UICOLORS.WHITE)
	self.puppet_mask = self.puppet_container:AddChild(Image("images/ui_ftf_runsummary/CharacterMask.tex"))
		:SetName("Puppet mask")
		:SetMultColor(UICOLORS.WHITE)
		:SetMask()
	self.puppet = self.puppet_container:AddChild(PlayerPuppet())
		:SetName("Puppet")
		:SetScale(0.35 * HACK_FOR_4K)
		:SetFacing(FACING_RIGHT)
		:SetMasked()
	self.puppet_overlay = self.puppet_container:AddChild(Image("images/ui_ftf_runsummary/CharacterBg.tex"))
		:SetName("Overlay")
		:SetMultColor(HexToRGB(0x3D3029ff))

	-- Player username
	self.username = self:AddChild(Text(FONTFACE.DEFAULT, 25 * HACK_FOR_4K, "", UICOLORS.LIGHT_TEXT_TITLE))
		:SetName("Username")
		:LeftAlign()

	self.player_title = self:AddChild(PlayerTitleWidget(nil, FONTSIZE.SCREEN_TEXT))
		--:LeftAlign()

	-- Networking: some data on this screen will be static, filled out once and never updated.
	-- Other clients will be sending data every tick, so that the data is always available.
	-- So that we don't have to rebuild the screen every time, let's build the static data once and never rebuild it.
	-- Then, we'll only update the other clients' cursor positions.
	self.static_data_configured = false

	------------------------------------------------------------------------------
	-- Contains the background and all panel contents.
	-- Gets scissored during in/out animation
	-- The roll anim is shown over this
	self.panel_contents = self:AddChild(Widget())
		:SetName("Panel contents")
		:SendToBack()
		:SetShowDebugBoundingBox(true)

	-- Background for the panel
	self.bg = self.panel_contents:AddChild(Image("images/ui_ftf_runsummary/PanelBg.tex"))
		:SetName("Background")

	-- Show player equipment
	self.equipment_container = self.panel_contents:AddChild(Widget())
		:SetName("Equipment container")
	local weapon_slot_size = 95 * HACK_FOR_4K
	local slot_size = 70 * HACK_FOR_4K

	local function slot_tooltip_fn(focus_widget, tooltip_widget)
		tooltip_widget:LayoutBounds("center", nil, self.bg)
			:LayoutBounds(nil, "below", self.slot_weapon)
			:Offset(0, -15 * HACK_FOR_4K)
	end

	self.slot_weapon = self.equipment_container:AddChild(InventorySlot(weapon_slot_size, ItemCatalog.All.SlotDescriptor[Equipment.Slots.WEAPON].icon))
		:SetName("Slot weapon")
		:SetBackground("images/ui_ftf_runsummary/WeaponSlot.tex", "images/ui_ftf_inventory/WeaponSlotOverlay.tex", "images/ui_ftf_runsummary/WeaponSlot.tex")
		:ApplyTheme_DungeonSummary()
		:SetToolTipLayoutFn(slot_tooltip_fn)
		:ShowToolTipOnFocus(true)
		:SetMoveOnClick(false)
		:SetControlDownSound(nil)
		:SetControlUpSound(nil)
		:SetGainFocusSound(nil)
	self.slot_potion = self.equipment_container:AddChild(InventorySlot(slot_size*1.1, ItemCatalog.All.SlotDescriptor[Equipment.Slots.POTIONS].icon))
		:SetName("Slot potion")
		:ApplyTheme_DungeonSummaryPotion()
		:SetToolTipLayoutFn(slot_tooltip_fn)
		:ShowToolTipOnFocus(true)
		:SetMoveOnClick(false)
		:SetControlDownSound(nil)
		:SetControlUpSound(nil)
		:SetGainFocusSound(nil)
	self.slot_tonic = self.equipment_container:AddChild(InventorySlot(slot_size*0.6, ItemCatalog.All.SlotDescriptor[Equipment.Slots.TONICS].icon))
		:SetName("Slot tonic")
		:ApplyTheme_DungeonSummaryTonic()
		:SetToolTipLayoutFn(slot_tooltip_fn)
		:ShowToolTipOnFocus(true)
		:SetMoveOnClick(false)
		:SetControlDownSound(nil)
		:SetControlUpSound(nil)
		:SetGainFocusSound(nil)
	self.slot_food = self.equipment_container:AddChild(InventorySlot(slot_size, ItemCatalog.All.SlotDescriptor[Equipment.Slots.FOOD].icon))
		:SetName("Slot food")
		:ApplyTheme_DungeonSummary()
		:SetToolTipLayoutFn(slot_tooltip_fn)
		:ShowToolTipOnFocus(true)
		:SetMoveOnClick(false)
		:SetControlDownSound(nil)
		:SetControlUpSound(nil)
		:SetGainFocusSound(nil)
	self.slot_skill = self.equipment_container:AddChild(SkillWidget(slot_size * 0.9, player))
		:SetName("Slot skill")
		:SetToolTipLayoutFn(slot_tooltip_fn)
		:ShowToolTipOnFocus(true)
		:SetNavFocusable(true)
		:SetControlDownSound(nil)
		:SetControlUpSound(nil)
		:SetGainFocusSound(nil)

	------------------------------------------------------------------------------
	-- Only one of these is shown at a given time:
	------------------------------------------------------------------------------
	-- Contains the summary widgets
	self.summary_contents = self.panel_contents:AddChild(Widget())
		:SetName("Summary contents")
		:Hide()
	-- Contains the rewards widgets
	self.rewards_contents = self.panel_contents:AddChild(Widget())
		:SetName("Rewards contents")
		:Hide()
	------------------------------------------------------------------------------

	-- Calculate sizes
	self.width, self.height = self.bg:GetScaledSize()

	-- Calculate content size for animation
	self.content_width, self.content_height = self.panel_contents:GetSize()

	-- How much of the panel will be scissored in the animation, starting from the bottom
	-- Basically everything except the equipment icons at the top
	self.roll_scissored_height = self.content_height - 40

	-- Show kills
	self.kills_container = self.summary_contents:AddChild(Widget())
		:SetName("Kills container")
	self.kills_bg = self.kills_container:AddChild(Image("images/ui_ftf_runsummary/KillCountBg.tex"))
		:SetName("Background")
	self.kills_count = self.kills_container:AddChild(Text(FONTFACE.DEFAULT, FONTSIZE.SCREEN_SUBTITLE, "", UICOLORS.LIGHT_TEXT_TITLE))
		:SetName("Count")
		:SetGlyphColor(HexToRGB(0xDEC9B3FF))
	self.kills_label = self.kills_container:AddChild(Text(FONTFACE.DEFAULT, 20 * HACK_FOR_4K, STRINGS.UI.DUNGEONSUMMARYSCREEN.TOTAL_KILLS, UICOLORS.LIGHT_TEXT_TITLE))
		:SetName("Label")
		:SetGlyphColor(HexToRGB(0xDEC9B3FF))

	-- Show stats
	self.stats_container = self.summary_contents:AddChild(Widget())
		:SetName("Stats container")
	self.stats_bg = self.stats_container:AddChild(Image("images/ui_ftf_runsummary/StatsBg.tex"))
		:SetName("Background")
	local stats_w = 190 * HACK_FOR_4K
	self.stats_column = self.stats_container:AddChild(Widget())
		:SetName("Stats column")
	self.stat_damage_done = self.stats_column:AddChild(DisplayStat(stats_w))
		:SetLightBackgroundColors()
		:ShowUnderline(true, 4, HexToRGB(0xBCA493FF))
	self.stat_damage_taken = self.stats_column:AddChild(DisplayStat(stats_w))
		:SetLightBackgroundColors()
		:ShowUnderline(true, 4, HexToRGB(0xBCA493FF))
	self.stat_damage_deaths = self.stats_column:AddChild(DisplayStat(stats_w))
		:SetLightBackgroundColors()

	-- Show run duration
	self.duration_container = self.summary_contents:AddChild(Widget())
		:SetName("Duration container")
	self.duration_hitbox = self.duration_container:AddChild(Image("images/square.tex"))
		:SetName("Hitbox")
		:SetSize(self.width, 100 * HACK_FOR_4K)
		:SetMultColor(HexToRGB(0xff00ff00))
	self.duration_text_container = self.duration_container:AddChild(Widget())
		:SetName("Duration container")
	self.duration_icon = self.duration_text_container:AddChild(Image("images/ui_ftf_runsummary/DurationIcon.tex"))
		:SetName("Icon")
		:SetScale(0.45 * HACK_FOR_4K)
		:SetMultColor(UICOLORS.LIGHT_TEXT_DARK)
	self.duration_label = self.duration_text_container:AddChild(Text(FONTFACE.DEFAULT, 20 * HACK_FOR_4K, STRINGS.UI.DUNGEONSUMMARYSCREEN.DURATION_TITLE, UICOLORS.LIGHT_TEXT_DARK))
		:SetName("Label")
	self.duration_value = self.duration_text_container:AddChild(Text(FONTFACE.DEFAULT, FONTSIZE.SCREEN_SUBTITLE, "", UICOLORS.LIGHT_TEXT_DARKER))
		:SetName("Value")

	-- Show map
	self.map_container = self.summary_contents:AddChild(Widget())
		:SetName("Map container")
	self.map_bg = self.map_container:AddChild(Image("images/ui_ftf_runsummary/MapForest.tex"))
		:SetName("Background")
	self.map_text_container = self.map_container:AddChild(Widget())
		:SetName("Duration container")
	self.map_value = self.map_text_container:AddChild(Text(FONTFACE.DEFAULT, 55 * HACK_FOR_4K, "", UICOLORS.LIGHT_TEXT_DARKER))
		:SetName("Value")
		:SetSDFThreshold(0.65)
	self.map_label = self.map_text_container:AddChild(Text(FONTFACE.DEFAULT, 20 * HACK_FOR_4K, STRINGS.UI.DUNGEONSUMMARYSCREEN.ROOMS_LABEL, UICOLORS.LIGHT_TEXT_DARK))
		:SetName("Label")
		:OverrideLineHeight(16 * HACK_FOR_4K)

	-- Show nemesis
	self.nemesis_container = self.summary_contents:AddChild(Widget())
		:SetName("Nemesis container")
	self.nemesis_bg = self.nemesis_container:AddChild(Image("images/ui_ftf_runsummary/BossMask.tex"))
		:SetName("Puppet bg")
		:SetMultColor(HexToRGB(0xCEB6A5ff))
		:SetMultColorAlpha(.4)
	self.nemesis_mask = self.nemesis_container:AddChild(Image("images/ui_ftf_runsummary/BossMask.tex"))
		:SetName("Puppet mask")
		:SetMask()
	local mask_w = self.nemesis_mask:GetScaledSize()
	self.nemesis = self.nemesis_container:AddChild(Image("images/global/transparent.tex"))
		:SetName("Nemesis")
		:SetScale(0.8)
		:SetMasked()
		:SetHiddenBoundingBox(true)
	self.nemesis_overlay = self.nemesis_container:AddChild(Image("images/ui_ftf_runsummary/BossOverlay.tex"))
		:SetName("Puppet mask")
	self.nemesis_label = self.nemesis_container:AddChild(Text(FONTFACE.DEFAULT, 20 * HACK_FOR_4K, STRINGS.UI.DUNGEONSUMMARYSCREEN.DAMAGED_BY, UICOLORS.LIGHT_TEXT_DARK))
		:SetName("Label")
		:SetAutoSize(mask_w - 30)
	self.nemesis_value = self.nemesis_container:AddChild(Text(FONTFACE.DEFAULT, FONTSIZE.SCREEN_SUBTITLE, "", UICOLORS.LIGHT_TEXT_DARKER))
		:SetName("Value")
		:OverrideLineHeight(FONTSIZE.SCREEN_SUBTITLE*0.8)
		:SetAutoSize(mask_w - 30)

	-- Show powers used
	self.powers_container = self.summary_contents:AddChild(Widget())
		:SetName("Powers container")

	-- Show level progression
	self.level_container = self.rewards_contents:AddChild(Widget())
		:SetName("level container")
	self.level_container_start_y = 180	-- Before the rewards show up
	self.level_container_end_y = 300	-- After the rewards pop in
	self.dungeon_level = self.level_container:AddChild(DungeonLevelWidget(player))
		:SetName("Dungeon level widget")
		:ShowLargePresentation(HexToRGB(0xA3897B77), UICOLORS.LIGHT_TEXT_DARKER)
		:SetTitleFontSize(30 * HACK_FOR_4K)
		:SetHiddenBoundingBox(true)
		:SetPos(0, self.level_container_start_y)

	-- Show level reward
	self.reward_container = self.rewards_contents:AddChild(UnlockableRewardsContainer(self.width - 140, player))
		:SetName("Reward container")
		:SetNavFocusable(true)
		:Hide()
		:SetControlDownSound(nil)
		:SetControlUpSound(nil)
		:SetGainFocusSound(nil)

	-- Show loot
	self.loot_container = self.rewards_contents:AddChild(Widget())
		:SetName("Loot container")
	self.loot_bg = self.loot_container:AddChild(Image("images/ui_ftf_runsummary/LootBg.tex"))
		:SetName("Background")
	self.loot_title = self.loot_container:AddChild(Text(FONTFACE.DEFAULT, FONTSIZE.ROOMBONUS_TEXT, STRINGS.UI.DUNGEONSUMMARYSCREEN.LOOT_TITLE, UICOLORS.LIGHT_TEXT_DARK))
		:SetName("Title")
	self.loot_empty = self.loot_container:AddChild(Text(FONTFACE.DEFAULT, FONTSIZE.ROOMBONUS_TEXT * 0.8, STRINGS.UI.DUNGEONSUMMARYSCREEN.LOOT_EMPTY, UICOLORS.LIGHT_TEXT_DARK))
		:SetName("Empty")
	self.loot_widgets = self.loot_container:AddChild(Widget())
		:SetName("Loot widgets")

	-- Show loading spinner
	self.loading_indicator = self:AddChild(LoadingIndicator())
		:SetName("Loading indicator")
		:SetText(STRINGS.UI.DUNGEONSUMMARYSCREEN.LOADING_TEXT)
		:SendToBack()

	self.current_page = nil

	self:SetPlayer(player, reward_data)
end)

function PlayerDungeonSummary:SetPlayer(player, reward_data)
	self.player = player
	self.player_colour = self.player.uicolor or HexToRGB(0x8CBF91ff)

	self.reward_data = reward_data

	self.username:SetText(player:GetCustomUserName())
	self.player_title:SetOwner(self.player)

	-- Update player color
	self.puppet_bg:SetMultColor(self.player_colour)
	self.puppet_overlay:SetMultColor(self.player_colour)
	self.username:SetGlyphColor(self.player_colour)

	self:Layout()
	return self
end

function PlayerDungeonSummary:ApplyDataToScreen(data)
	if not self.static_data_configured and data then
		TheLog.ch.RunSummary:print("Showing player ui data from player " .. self.player:GetCustomUserName())
		TheLog.ch.RunSummary:dumptable(data)

		self:RefreshEquipment(data)
		self:RefreshStats(data)
		self:RefreshBuild() -- PowerManager is already synced, other than 'mem' stuff -- so we don't need to send / receive this over the network.
		self:RefreshMetaProgress(data)
		self:RefreshLoot(data)
		self:Layout()

		self.static_data_configured = true
	end
end

function PlayerDungeonSummary:OnInputModeChanged(old_device_type, new_device_type)

end

function PlayerDungeonSummary:RefreshEquipment(display_data)
	-- Update weapon
	local catalog = itemcatalog.All.Items
	local weapon_def = catalog.WEAPON[display_data.equipment.equipped_weapon]
	local weapon

	if weapon_def then
		weapon = itemforge.CreateEquipment(weapon_def.slot, weapon_def)
	end

	self.slot_weapon:SetItem(weapon, self.player)

	-- Update potion
	local potion_def = catalog.POTIONS[display_data.equipment.equipped_potion]
	local potion
	if potion_def then
		potion = itemforge.CreateEquipment(potion_def.slot, potion_def)
	end
	self.slot_potion:SetItem(potion, self.player)

	-- Update tonic
	local tonic_def = catalog.TONICS[display_data.equipment.equipped_tonic]
	local tonic
	if tonic_def then
		tonic = itemforge.CreateEquipment(tonic_def.slot, tonic_def)
		self.slot_tonic:SetGainFocusSound(fmodtable.Event.hover)
	end
	self.slot_tonic:SetItem(tonic, self.player)

	-- Update food
	local food_def = catalog.FOOD[display_data.equipment.equipped_food]
	local food
	if food_def then
		food = itemforge.CreateEquipment(food_def.slot, food_def)
		self.slot_food:Show()
		self.slot_food:SetHoverSound(fmodtable.Event.hover)
		self.slot_food:SetGainFocusSound(fmodtable.Event.hover)
	else
		self.slot_food:Hide()
	end
	self.slot_food:SetItem(food, self.player)

	-- Update skill
	local skill = self.player.components.powermanager:GetCurrentSkillPower()
	if skill then
		self.slot_skill:SetSkill(skill)
		self.slot_skill:Show()
		self.slot_skill:SetHoverSound(fmodtable.Event.hover)
		self.slot_skill:SetGainFocusSound(fmodtable.Event.hover)
	else
		self.slot_skill:Hide()
	end

	return self
end

function PlayerDungeonSummary:RefreshPuppet()
	self.puppet:CloneCharacterWithEquipment(self.player)
	-- TODO: re-layout this puppet, seems to be too far down now?
	return self
end

function PlayerDungeonSummary:RefreshStats(display_data)
	if display_data.stats.total_kills then
		self.kills_count:SetText(display_data.stats.total_kills)
	end

	if display_data.stats.total_damage_done then
		self.stat_damage_done:SetValue(display_data.stats.total_damage_done, STRINGS.UI.DUNGEONSUMMARYSCREEN.DAMAGE_DONE)
	end

	if display_data.stats.total_damage_taken then
		self.stat_damage_taken:SetValue(display_data.stats.total_damage_taken, STRINGS.UI.DUNGEONSUMMARYSCREEN.DAMAGE_TAKEN)
	end

	-- Refresh nemesis
	local nemesis = display_data.stats.nemesis
	local texture = monster_pictures.tex[string.format("research_widget_%s", nemesis)]
	if display_data.stats.total_damage_taken == 0 then
		self.nemesis_label:SetText(STRINGS.UI.DUNGEONSUMMARYSCREEN.DAMAGED_BY_NONE)
		self.nemesis_value:SetText(STRINGS.UI.DUNGEONSUMMARYSCREEN.DAMAGED_VALUE_NONE)
	elseif nemesis and texture then
		self.nemesis:SetTexture(texture)
		self.nemesis_label:SetText(STRINGS.UI.DUNGEONSUMMARYSCREEN.DAMAGED_BY)
		self.nemesis_value:SetText(STRINGS.NAMES[nemesis] or nemesis)
	else -- Unassigned damage is attributed to environment
		self.nemesis:SetTexture(monster_pictures.tex["research_widget_environment"])
		self.nemesis_label:SetText(STRINGS.UI.DUNGEONSUMMARYSCREEN.DAMAGED_BY_EMPTY)
		self.nemesis_value:SetText(STRINGS.UI.DUNGEONSUMMARYSCREEN.DAMAGED_VALUE_EMPTY)
	end

	-- Refresh deaths
	if display_data.stats.total_deaths then
		self.stat_damage_deaths:SetValue(display_data.stats.total_deaths, STRINGS.UI.DUNGEONSUMMARYSCREEN.DEATHS)
	end

	-- Refresh duration
	if display_data.stats.duration_millis then
		self.duration_value:SetText(StringFormatter.FormatRunDuration(display_data.stats.duration_millis, display_data.stats.duration_show_hours))
	end

	-- Refresh map
	if display_data.stats.rooms_discovered then
		self.map_value:SetText(display_data.stats.rooms_discovered)
	end
end

function PlayerDungeonSummary:RefreshBuild()
	-- PowerManager is already synced, other than 'mem' stuff -- so we don't need to send / receive this over the network.
	local powers = self.player.components.powermanager:GetAllPowersInAcquiredOrder()

	for _, pow in ipairs(powers) do
		if pow.def.show_in_ui then
			if pow.def.power_type ~= Power.Types.SKILL then
				self.powers_container:AddChild(PowerWidget(self.width / 4.5, self.player, pow.persistdata))
					:SetNavFocusable(true)
					:ShowToolTipOnFocus(true)
					-- sound
					:SetControlDownSound(nil)
					:SetControlUpSound(nil)
					:SetGainFocusSound(fmodtable.Event.hover)
			end
			-- else: The skill is shown on the top bar, next to the equipment
		end
	end
end

function PlayerDungeonSummary:RefreshMetaProgress(display_data)
	if display_data.biome_exploration then

		-- Update progress display
		self.dungeon_level:RefreshMetaProgress(display_data.biome_exploration)

		-- Remove existing rewards
		self.reward_container:RemoveAllPowers()
	end
end

function PlayerDungeonSummary:RefreshLoot(display_data)

	-- Remove old loot
	self.loot_widgets:RemoveAllChildren()

	-- Add new stuffs
	if display_data.loot then
		for _, loot_data in ipairs(display_data.loot) do
			if loot_data.name ~= "konjur" then
				local def = Consumable.FindItem(loot_data.name)
				self.loot_widgets:AddChild(ItemWidget(def, loot_data.count, 60 * HACK_FOR_4K))
					:SetNavFocusable(true)
					:ShowToolTipOnFocus(true)
			end
		end
	end

	if display_data.bonus_loot then
		for _, loot_data in ipairs(display_data.bonus_loot) do
			local def = Consumable.FindItem(loot_data.name)
			self.loot_widgets:AddChild(ItemWidget(def, loot_data.count, 60 * HACK_FOR_4K))
				:SetNavFocusable(true)
				:ShowToolTipOnFocus(true)
				:SetBonus()
		end
	end

	return self
end

function PlayerDungeonSummary:_SetPaperRollAmount(amount_rolled)
	self.panel_contents:SetScissor(-self.content_width/2, -self.content_height/2 + self.roll_scissored_height*amount_rolled, self.content_width, self.content_height)
	self.roll_anim:LayoutBounds(nil, "below", self.panel_contents)
		:Offset(0, self.roll_anim_h/2)
end

function PlayerDungeonSummary:PrepareToAnimate()
	-- Snap to fully rolled position.
	self:_SetPaperRollAmount(1)
end

function PlayerDungeonSummary:AnimateInSummary()

	-- Show summary
	self.summary_contents:Hide()
	self.rewards_contents:Show()


	-- Animation duration
	local scissor_duration = 0.45

	self:RunUpdater(Updater.Series{
		-- Scissor up
		Updater.Parallel{
			Updater.Do(function()
				-- Roll up sound
				self:PlaySpatialSound(fmodtable.Event.endOfRun_rollUp)

				self.roll_anim:PlayAnimation("rollup")
					:PushAnimation("upidle", true)
			end),
			Updater.Ease(function(v)
				self:_SetPaperRollAmount(v)
			end, 0, 1, scissor_duration, easing.outQuad)
		},
		-- Scissor down
		Updater.Parallel{
			Updater.Do(function()
				-- Show summary
				self.summary_contents:Show()
				self.rewards_contents:Hide()

				-- Unroll sound
				self:PlaySpatialSound(fmodtable.Event.endOfRun_rollDown)

				-- Animate rolling
				self.roll_anim:PlayAnimation("rolldown")
					:PushAnimation("downidle", true)
			end),
			Updater.Ease(function(v)
				self:_SetPaperRollAmount(v)
			end, 1, 0, scissor_duration, easing.outQuad)
		}
	})
end

function PlayerDungeonSummary:AnimateInRewards()

	-- Show rewards
	self.summary_contents:Hide()
	self.rewards_contents:Show()

	-- Animation duration
	local scissor_duration = 0.45

	self:RunUpdater(Updater.Series{
		-- Scissor down
		Updater.Parallel{
			Updater.Do(function()

				-- Show rewards
				-- self.summary_contents:Hide()
				-- self.rewards_contents:Show()

				-- Unroll sound
				self:PlaySpatialSound(fmodtable.Event.endOfRun_rollDown)
					-- HACK, this needs to be done this way because some UI elements begin animating (and making sound)
					-- before they are shown on screen. The below snapshot suppresses them
					--TheAudio:StopFMODSnapshot(fmodtable.Snapshot.Mute_EndOfRun_Meters)

				-- Animate rolling
				self.roll_anim:PlayAnimation("rolldown")
					:PushAnimation("downidle", true)
			end),
			Updater.Ease(function(v)
				self:_SetPaperRollAmount(v)
			end, 1, 0, scissor_duration, easing.outQuad)
		},
		Updater.Do(function()
			-- Show progress
			self.dungeon_level:ShowMetaProgression(function(level_num, move_up, reward_earned, next_reward, sequence_done)
				-- Called first, to move the widget up
				if move_up then
					self.dungeon_level:MoveTo(nil, self.level_container_end_y, 0.45, easing.outQuad)
				end

				-- Called next, for each reward earned
				if reward_earned then
					self.reward_container:Show():AddRewardPower(reward_earned.def, reward_earned.slot, level_num, true)
					self:PlaySpatialSound(fmodtable.Event.ui_endOfRun_unlock_power)
				end

				-- Called to show the upcoming reward
				if next_reward then
					self.reward_container:Show():AddRewardPower(next_reward.def, next_reward.slot, level_num, false)
					self:PlaySpatialSound(fmodtable.Event.ui_endOfRun_unlock_power)
				end

				-- Called at the end, after everything else
				if sequence_done then
					self.reward_container:Show():ShowNav()
				end
			end)
		end),

	})
end

function PlayerDungeonSummary:AnimateOutDone()

	-- Show rewards
	self.loading_indicator:Hide()
	-- Animation duration
	local scissor_duration = 0.45

	self:RunUpdater(Updater.Series{
		-- Scissor up
		Updater.Parallel{
			Updater.Do(function()
				-- Roll up sound
				self:PlaySpatialSound(fmodtable.Event.endOfRun_rollUp)

				self.roll_anim:PlayAnimation("rollup")
					:PushAnimation("upidle", true)
			end),
			Updater.Ease(function(v)
				self:_SetPaperRollAmount(v)
			end, 0, 1, scissor_duration, easing.outQuad)
		},
	})
end

function PlayerDungeonSummary:Layout()

	-- Position puppet
	self.puppet:LayoutBounds("left", "bottom", self.puppet_container)
		:Offset(65 * HACK_FOR_4K, -15 * HACK_FOR_4K)
	self.puppet_container:LayoutBounds("left", "top", self.bg)
		:Offset(-30 * HACK_FOR_4K, 40 * HACK_FOR_4K)
		:SendToFront()

	-- And username
	self.username:LayoutBounds("after", nil, self.puppet_container)
		:LayoutBounds(nil, "above", self.bg)
		:Offset(0, 21 * HACK_FOR_4K)

	self.player_title:LayoutBounds("left", "below", self.username)

	-- Layout equipment slots
	self.slot_weapon:LayoutBounds("left", "top", self.bg)
		:Offset(88 * HACK_FOR_4K, 1)
	if self.slot_tonic:HasItem() then
		-- If there's a tonic, nudge the potion a bit to make room
		self.slot_potion:LayoutBounds("after", "center", self.slot_weapon)
			:Offset(-20, 5)
		self.slot_tonic:Show()
			:LayoutBounds("right", "bottom", self.slot_potion)
			:Offset(5, -10)
	else
		self.slot_potion:LayoutBounds("after", "center", self.slot_weapon)
			:Offset(0, 0)
		self.slot_tonic:Hide()
	end
	self.slot_skill:LayoutBounds("after", "center", self.slot_weapon)
		:Offset(150, -10)
	self.slot_food:LayoutBounds("after", "center", self.slot_weapon)
		:Offset(280, -10)

	-- Layout kills
	self.kills_container:LayoutBounds("left", "top", self.bg)
		:Offset(26.5 * HACK_FOR_4K, -92 * HACK_FOR_4K)
	self.kills_label:LayoutBounds("center", "bottom", self.kills_bg)
		:Offset(0, 6 * HACK_FOR_4K)
	self.kills_count:LayoutBounds("center", "above", self.kills_label)
		:Offset(0, -4 * HACK_FOR_4K)

	-- Layout stats
	self.stats_container:LayoutBounds("after", "center", self.kills_container)
		:Offset(4 * HACK_FOR_4K, 0)
	self.stats_column:LayoutChildrenInColumn(10 * HACK_FOR_4K, "left", 0, 0)
		:LayoutBounds("left", "center", self.stats_bg)
		:Offset(30 * HACK_FOR_4K, -5)

	-- Layout duration
	self.duration_container:LayoutBounds(nil, "below", self.kills_container)
	self.duration_label:LayoutBounds("after", "center", self.duration_icon)
		:Offset(2 * HACK_FOR_4K, 14 * HACK_FOR_4K)
	self.duration_value:LayoutBounds("left", "below", self.duration_label)
		:Offset(0, 4 * HACK_FOR_4K)
	self.duration_text_container:LayoutBounds("center", "center", self.duration_hitbox)
		:Offset(-4 * HACK_FOR_4K, 0)

	-- Layout map
	self.map_container:LayoutBounds("left", "below", self.duration_container)
		:Offset(30 * HACK_FOR_4K, 0)
	self.map_value:LayoutBounds("center", "above", self.map_label)
		:Offset(0, -4 * HACK_FOR_4K)
	self.map_text_container:LayoutBounds("center", "center", self.map_bg)
		:Offset(0, 2 * HACK_FOR_4K)

	-- Layout nemesis
	self.nemesis_container:LayoutBounds("after", "top", self.map_container)
		:Offset(14 * HACK_FOR_4K, 1.5)
	self.nemesis_label:LayoutBounds("center", "top", self.nemesis_overlay)
		:Offset(-4, -10 * HACK_FOR_4K)
	self.nemesis_value:LayoutBounds("center", "below", self.nemesis_label)
		:Offset(0, 4 * HACK_FOR_4K)
	self.nemesis:LayoutBounds("center", "below", self.nemesis_value)
		:Offset(0, 50)

	-- Layout powers grid
	self.powers_container:LayoutInDiagonal(4, 20, 10)
		:SetScale(Remap(#self.powers_container.children, 1, 11, 1.3, 0.85))
		:LayoutBounds("center", "center", self.bg)
		:Offset(0, -260 * HACK_FOR_4K)

	-- Layout reward
	self.reward_container:LayoutBounds("center", "center", self.bg)
		:Offset(0, -10)

	-- Layout loot
	self.loot_widgets:LayoutInDiagonal(6, 5 * HACK_FOR_4K, 5 * HACK_FOR_4K)
		:SetScale(Remap(#self.powers_container.children, 1, 11, 1.3, 0.85))
		:LayoutBounds("center", "center", self.loot_bg)
		:Offset(0, -5 * HACK_FOR_4K)
	-- If there's no loot, show the empty message instead
	local has_loot = self.loot_widgets:HasChildren()
	self.loot_empty:SetShown(not has_loot)
		:LayoutBounds("center", "center", self.loot_bg)
		:Offset(0, -5 * HACK_FOR_4K)
	self.loot_title:LayoutBounds("center", "above", has_loot and self.loot_widgets or self.loot_empty)
		:Offset(0, has_loot and 10 * HACK_FOR_4K or 0)
	self.loot_container:LayoutBounds("center", "bottom", self.bg)

	-- Position animated roll
	self.roll_anim:LayoutBounds(nil, "below", self.panel_contents)
		:Offset(-1 * HACK_FOR_4K, self.roll_anim_h/2)

	self.loading_indicator:SetScale(0.7)
		:LayoutBounds("center", "top", self.roll_anim)
		:Offset(0, -80)

	return self
end

return PlayerDungeonSummary
