local ConfirmDialog = require "screens.dialogs.confirmdialog"
local ControlsWidget = require "widgets.ftf.controlswidget"
local DungeonHistoryMap = require "widgets.ftf.dungeonhistorymap"
local DungeonLayoutMap = require "widgets.ftf.dungeonlayoutmap"
local EditableEditor = require "debug.inspectors.editableeditor"
local Enum = require "util.enum"
local Image = require "widgets.image"
local OptionsScreen = require "screens.optionsscreen"
local ManageMPScreen = require "screens.manage_mp_screen"
local PlayersScreen = require "screens.playersscreen"
local Panel = require "widgets.panel"
local RoomLoader = require "roomloader"
local Screen = require "widgets.screen"
local Text = require "widgets.text"
local Widget = require "widgets.widget"
local easing = require "util.easing"
local fmodtable = require "defs.sound.fmodtable"
local lume = require "util.lume"
local templates = require "widgets.ftf.templates"


local PauseScreen = Class(Screen, function(self, player)
	Screen._ctor(self, "PauseScreen")
	self:SetAudioEnterOverride(fmodtable.Event.ui_pauseScreen_enter)
		:SetAudioExitOverride(fmodtable.Event.ui_pauseScreen_exit)
		:SetAudioCategory(Screen.AudioCategory.s.Fullscreen)

	self.active = true
	SetGameplayPause(true, "PauseScreen")

	-- Get location data
	self.inTown = TheWorld:HasTag("town")
	self.worldmap = TheDungeon:GetDungeonMap()

	-- Add background
	self.bg = self:AddChild(templates.BackgroundImage("images/ui_ftf_pausescreen/background_gradient.tex"))

	if TheNet:IsGameTypeLocal() then
		self.bg.full_alpha = 1
	else
		-- Cannot pause in a non-local network game, so don't tint background
		-- so hard.
		self.bg.full_alpha = 0.4
	end

	-- Back button
	self.closeButton = self:AddChild(templates.BackButton())
		:SetPrimary()
		:SetOnClick(function() self:Unpause() end)
		:LayoutBounds("left", "bottom", self.bg)
		:Offset(30, 20)

	-- Manage Multiplayer button
	self.manageMPButton = self:AddChild(templates.Button(STRINGS.UI.PAUSEMENU.MANAGE_MP_BUTTON))
		:SetFlipped()
		:SetOnClick(function() self:OnClickManageMP() end)
		:LayoutBounds("after", "center", self.closeButton)
		:Offset(20, 0)



	if EditableEditor.HasUnsavedChanges() then
		self.debugSaveButton = self:AddChild(templates.Button("<p img='images/icons_ftf/inventory_wrap.tex' color=0> Save editor changes"))
			:SetDebug()
			:SetSize(BUTTON_W * 1.2, BUTTON_H)
			:SetOnClick(function()
				TheWorld.components.propmanager:SaveAllProps()
				self:Unpause()
			end)
			:LayoutBounds("right", "above", self.closeButton)
			:Offset(0, -10)
	end

	-- Options button
	self.optionsButton = self:AddChild(templates.Button(STRINGS.UI.PAUSEMENU.OPTIONS_BUTTON))
		:SetSecondary()
		:SetOnClick(function() self:OnClickOptions() end)
		:LayoutBounds("right", "bottom", self.bg)
		:Offset(-30, 20)

	-- TODO: Align with map?
	self.controls = self:AddChild(ControlsWidget(player))
		:LayoutBounds("right", "above", self.optionsButton)
		:Offset(-10, 140)

	self.quit_button = self:AddChild(templates.Button(STRINGS.UI.PAUSEMENU.SAVEQUIT_BUTTON))
		:SetSecondary()
		:SetFlipped()
		:SetOnClick(function() self:OnClickQuit() end)
		:LayoutBounds("before", "center", self.optionsButton)
		:Offset(-20, 0)
	if not self.inTown then
		self.quit_button:SetText(STRINGS.UI.PAUSEMENU.ABANDON_BUTTON)
		local can_abandon = TheDungeon.progression.components.runmanager:CanAbandonRun()
		if not can_abandon then
			self.quit_button:SetEnabled(false)
				:SetToolTip(STRINGS.UI.PAUSEMENU.NO_ABANDON_QUEST)
		end
	end

	self.imStuckButton = self:AddChild(templates.Button(STRINGS.UI.PAUSEMENU.IMSTUCK_BUTTON))
		:SetSecondary()
		:SetOnClick(function() self:OnClickImStuck() end)
		:LayoutBounds("before", "center", self.quit_button)
		:Offset(-20, 0)
		:SetPublicFacingDebug()

	if not TheNet:IsHost() then
		self.imStuckButton:SetEnabled(false)
			:SetToolTip(STRINGS.UI.PAUSEMENU.IMSTUCK.NON_HOST)
	end

	local joincode = TheNet:GetJoinCode()
	if joincode ~= "" then
		self.online_joincode_button = self:AddChild(templates.Button(STRINGS.UI.ONLINESCREEN.JOINCODE_LABEL:subfmt({ joincode = joincode })))
			:SetToolTip(STRINGS.UI.ONLINESCREEN.JOINCODE_LABEL_TOOLTIP)
			:SetUncolored()
			:SetFlipped()
			:SetTextSize(FONTSIZE.OVERLAY_TEXT)
			:OverrideLineHeight(FONTSIZE.OVERLAY_TEXT * 0.8)
			:SetOnClick(function() self:OnClickOnlineJoinCode() end)
			:LayoutBounds("left", "top", self.bg)
			:Offset(20,-20)
	end

	-- Map widget
	self.map = self:AddChild(DungeonHistoryMap(self.worldmap.nav))
		:SetOnMapChangedFn(function() self:OnMapChanged() end)
	if TheWorld:HasTag("town") then
		-- TODO(dbriscoe): What does town map look like?
		self.map:Hide()
	else
		self.map:DrawFullMap()
	end
	self.map:LayoutBounds("left", "above", self.closeButton)
		:Offset(0, 80)


	self.layout_btn = self.map.buttons:AddChild(templates.Button("Show Dungeon Layout"))
		:SetDebug()
		:SetOnClick(function()
			self.controls:Hide() -- more space for layout
			self.map:Hide()
			self.dungeon_layout = self:AddChild(DungeonLayoutMap(self.worldmap.nav))
				:Debug_SetupEditor(self)
				:SetOnMapChangedFn(function() self:OnMapChanged() end)
				:DrawFullMap()
			self:OnMapChanged()
		end)

	self.map.buttons:LayoutChildrenInGrid(1, 10)
	self.map.buttons:Reparent(self)
		:SetScale(0.6, 0.6)
		:LayoutBounds("right", "top", self.bg)
		:Offset(-30, -30)

	self:OnMapChanged()

	self.mapLegend = self:AddChild(self:AssembleMapLegend())
		:LayoutBounds("right", "top", self.bg)
		:Offset(-20, -20)
		-- TODO(dbriscoe): Are we going to completely remove the legend?
		:Hide()

	self.default_focus = self.closeButton
	self:SetOwningPlayer(player)
end)

function PauseScreen:SetOwningPlayer(player)
	PauseScreen._base.SetOwningPlayer(self, player)
	self.controls:SetOwningPlayer(player)
end

function PauseScreen:OnMapChanged()
	-- Layout map again
	local pad = 300
	if self.dungeon_layout then
		local scale_to_fit = true
		self.dungeon_layout:LayoutMap(self.bg, RES_X - pad, RES_Y - pad, scale_to_fit)
			:LayoutBounds("left", "center", self.bg)
			:Offset(pad, 0)
	end

	return self
end

function PauseScreen:AssembleMapLegend()
	local legendContainer = Widget("Map Legend")

	local legendTitle = legendContainer:AddChild(Text(FONTFACE.DEFAULT, FONTSIZE.PAUSE_SCREEN_LEGEND_TITLE))
		:SetGlyphColor(UICOLORS.LIGHT_TEXT)
		:SetHAlign(ANCHOR_LEFT)
		:SetText(STRINGS.UI.PAUSEMENU.MAP_LEGEND_TITLE)

	local legendMarkersContainer = legendContainer:AddChild(Widget())

	local keys
	if self.inTown then
		keys = {
		}
	else
		-- Dungeon map legend
		keys = {
			-- Specific ordered list of keys to display in a grid with 3
			-- columns. We don't show everything so we can enforce order and
			-- prevent info overload.
			"location", "BLANK",        "BLANK",
			"coin",     "potion",       "BLANK",
			"plain",    "powerupgrade", "miniboss",
			"fabled",   "mystery",      "hype",
		}
	end

	local desc = TheDungeon:GetDungeonMap().nav:GetArtDescriptions()
	desc.location = "location"
	local animated = {
		location = true,
	}
	local legend = lume.map(keys, function(key)
		if key == "BLANK" then
			return {}
		end
		local art_name = desc[key]
		local str = STRINGS.UI.PAUSEMENU.MAP_LEGEND[key]
		if not str then
			TheLog.ch.FrontEnd:printf("Missing string for map element '%s'.", key)
		end
		return {
			key = key,
			text = str,
			animate = animated[key],
			icon = ("images/ui_ftf_pausescreen/ic_%s.tex"):format(art_name),
		}
	end)

	for _, v in ipairs(legend) do

		-- Add label container
		local row = legendMarkersContainer:AddChild(Widget())

		-- Add icon
		if v.animate then
			-- Animated icon
			local icon = row:AddChild(Panel(v.icon))
				:SetNineSliceCoords(60, 60, 68, 68)
				:SetNineSliceBorderScale(0.5)
				:SetScale(0.5)
				:SetMultColor(UICOLORS.LIGHT_TEXT_DARK)
				:SetSize(FONTSIZE.PAUSE_SCREEN_LEGEND_TEXT, FONTSIZE.PAUSE_SCREEN_LEGEND_TEXT)

			local speed = 0.8
			local amplitude = 3
			local w, h = icon:GetSize()
			icon:RunUpdater(
				Updater.Loop({
						Updater.Ease(function(v) icon:SetSize(w + v, h + v) end, amplitude, 0, speed * 0.3, easing.inOutQuad),
						Updater.Ease(function(v) icon:SetSize(w + v, h + v) end, 0, amplitude, speed, easing.inOutQuad),
						Updater.Wait(speed * 0.5),
					})
				)
		elseif v.icon then
			-- Plain icon
			local icon = row:AddChild(Image(v.icon))
				:SetMultColor(UICOLORS.LIGHT_TEXT_DARK)
				:SetSize(FONTSIZE.PAUSE_SCREEN_LEGEND_TEXT, FONTSIZE.PAUSE_SCREEN_LEGEND_TEXT)
		end
		-- else: empty slot


		-- Add text
		local text = row:AddChild(Text(FONTFACE.DEFAULT, FONTSIZE.PAUSE_SCREEN_LEGEND_TEXT))
			:SetGlyphColor(UICOLORS.LIGHT_TEXT_DARK)
			:SetHAlign(ANCHOR_LEFT)
			:SetText(v.text)
			:LayoutBounds("after", nil)
			:Offset(10, 0)

	end

	-- Layout
	legendMarkersContainer:LayoutChildrenInAutoSizeGrid(3, 30, 10)
	legendTitle:LayoutBounds("left", "above", legendMarkersContainer)
		:Offset(-5, 10)

	return legendContainer
end

-- Only really specific special cases should call this (player join, feedback).
function PauseScreen:ForceUnpauseTime()
	TheLog.ch.FrontEnd:printf("Called PauseScreen:ForceUnpauseTime")
	return self:_UnpauseTime()
end

function PauseScreen:_UnpauseTime()
	self.active = false
	SetGameplayPause(false, "PauseScreen")
end

function PauseScreen:Unpause()
	TheFrontEnd:PopScreen(self)
end

function PauseScreen:OnClose()
	PauseScreen._base.OnClose(self)

	-- TODO: someone, force player to travel if leaving screen and debug travel was used
	-- if self.map:Debug_TravelUsed() or self.dungeon_layout:Debug_TravelUsed() then
	-- end
	self:_UnpauseTime()
	TheDungeon.HUD:Show()
	TheWorld:PushEvent("continuefrompause")
end

--[[
function PauseScreen:goafk()
	self:Unpause()

	local player = self:GetOwningPlayer()
	if player and player.components.combat and player.components.combat:IsInDanger() then
		--it's too dangerous to afk
		player.components.talker:Say(GetString(player, "ANNOUNCE_NODANGERAFK"))
		return
	end
end
]]

function PauseScreen:OnClickReturnToTown()
	-- Allow load tasks can update.
	self:_UnpauseTime()

	if EditableEditor.HasUnsavedChanges() then
		self:OnClickDebugSave()
	else
		TheDungeon.progression.components.runmanager:Abandon()
	end
	return self
end

function PauseScreen:OnClickOptions()
	TheFrontEnd:PushScreen(OptionsScreen())
	TheDungeon.HUD:Show()
	--Ensure last_focus is the options button since mouse can
	--unfocus this button during the screen change, resulting
	--in controllers having no focus when toggled on from the
	--options screen
	self.last_focus = self.optionsButton
	return self
end

function PauseScreen:OnClickImStuck()
	TheLog.ch.FrontEnd:printf("'I'm Stuck' clicked")

	local confirm_popup
	confirm_popup = ConfirmDialog(nil, nil, true)
		:SetTitle(STRINGS.UI.PAUSEMENU.IMSTUCK.TITLE)
		:SetText(STRINGS.UI.PAUSEMENU.IMSTUCK.BODY)
		:HideArrow()
		:SetYesButton(STRINGS.UI.PAUSEMENU.IMSTUCK.SEND_FEEDBACK, function()
			TheNet:HostRequestFeedbackForAllClients()
			-- Unpause to remove PauseScreen and hide confirm so it's not in
			-- the screenshot. Feedback messes with pause state regardless, so
			-- we won't stay properly paused.
			self:Unpause()
			confirm_popup:Hide()
			self.inst:DoTaskInTicks(2, function()
				confirm_popup:Show()
			end)
			-- hide the feedback button so it's clear that they should now reset.
			confirm_popup:HideYesButton()
		end)
		:SetNoButton(STRINGS.UI.PAUSEMENU.IMSTUCK.RESTART_ROOM, c_reset)
		:SetCancelButton(STRINGS.UI.PAUSEMENU.IMSTUCK.CANCEL, function()
			TheFrontEnd:PopScreen(confirm_popup)
		end)
		:CenterButtons()
	TheFrontEnd:PushScreen(confirm_popup)

	self.last_focus = self.imStuckButton
	return self
end

function PauseScreen:OnClickManageMP()
	TheFrontEnd:PushScreen(PlayersScreen())
	self.last_focus = self.manageMPButton
	return self
end


function PauseScreen:OnClickDebugSave()
	local town = "home_forest"
	local popup = ConfirmDialog()
		:SetTitle("Unsaved editor changes!")
		:SetText("You have unsaved changes to this level. Some props were modified.")
		:HideArrow()
		:SetYesButton("Save", function()
			TheWorld.components.propmanager:SaveAllProps()
			RoomLoader.LoadTownLevel(town)
			TheFrontEnd:PopScreen()
		end)
		:SetNoButton("Discard", function()
			RoomLoader.LoadTownLevel(town)
			TheFrontEnd:PopScreen()
		end)
		:SetCancelButton(STRINGS.UI.BUTTONS.CANCEL, function()
			TheFrontEnd:PopScreen()
		end)
	TheFrontEnd:PushScreen(popup)
	return self
end


function PauseScreen:OnClickQuit()
	self.active = false

	local function actualquit()
		self.parent:Disable()
		RestartToMainMenu("save")
	end

	local function doquit()
		-- You can listen to quit_to_menu to write to TheSaveSystem and we'll
		-- save it all before we quit.
		TheWorld:PushEvent("quit_to_menu")
		c_save(actualquit)
	end


	local dialog = nil

	local Actions = Enum{
		"Yes_Abandon",
		"No_QuitToMenu",
		"Cancel",
	}

	if TheNet:IsHost() and not TheNet:IsGameTypeLocal() then
		dialog = ConfirmDialog(nil, self.quit_button, true,
			STRINGS.UI.PAUSEMENU.HOSTQUITTITLE,
			STRINGS.UI.PAUSEMENU.HOSTQUITSUBTITLE)
		dialog:SetYesTooltip(STRINGS.UI.PAUSEMENU.HOSTRETURNTOTOWN_TOOLTIP)
		dialog:SetNoTooltip(STRINGS.UI.PAUSEMENU.HOSTQUIT_TOOLTIP)
	else
		-- Only if there are actually multiple players.
		local subtitle = #AllPlayers > 1 and STRINGS.UI.PAUSEMENU.CLIENTQUITBODY_MP or nil
		if TheWorld:HasTag("town") then
			dialog = ConfirmDialog(nil, self.quit_button, true,
				STRINGS.UI.PAUSEMENU.CLIENTQUITTITLE_TOWN,
				subtitle,
				STRINGS.UI.PAUSEMENU.CLIENTQUITSUBTITLE_TOWN)
		else
			dialog = ConfirmDialog(nil, self.quit_button, true,
				STRINGS.UI.PAUSEMENU.CLIENTQUITTITLE_DUNGEON,
				subtitle,
				STRINGS.UI.PAUSEMENU.CLIENTQUITSUBTITLE_DUNGEON)
		end
	end

	dialog
		:SetWideButtons()

	if TheWorld:HasTag("town") then
		dialog
			:SetYesButtonText(STRINGS.UI.PAUSEMENU.QUIT_BUTTON)
			:SetNoButton(STRINGS.UI.PAUSEMENU.CANCEL_QUIT)
			:SetCallbackActionLabels(Actions.s.No_QuitToMenu, Actions.s.Cancel)
	else
		dialog
			:SetText(STRINGS.UI.PAUSEMENU.CLIENTQUITSUBTITLE_DUNGEON)
			:SetYesButtonText(STRINGS.UI.PAUSEMENU.RETURN_TO_TOWN_BUTTON)
			:SetNoButton(STRINGS.UI.PAUSEMENU.QUIT_BUTTON)
			-- :SetCancelButtonText(STRINGS.UI.PAUSEMENU.CANCEL_QUIT)
			:SetCloseButton(function() dialog:Close() end)
			:SetCallbackActionLabels(Actions.s.Yes_Abandon, Actions.s.No_QuitToMenu, Actions.s.Cancel)

		if not TheNet:IsHost() then
			dialog.yesButton:SetEnabled(false)
				:SetToolTip(STRINGS.UI.PAUSEMENU.NO_ABANDON_CLIENT)
		end
	end

	-- Set the dialog's callback
	dialog:SetOnDoneFn(
		function(_, action)
			assert(Actions:Contains(action))
			if action == Actions.s.Yes_Abandon then
				self:OnClickReturnToTown()
			elseif action == Actions.s.No_QuitToMenu then
				TheLog.ch.Audio:print("***///***pausescreen.lua: Stopping all music.")
				TheWorld.components.ambientaudio:StopAllMusic()
				TheWorld.components.ambientaudio:StopAmbient()
				--TheFrontEnd:GetSound():PlaySound(fmodtable.Event.ui_input_up_confirm_save)
				doquit()
			else
				TheFrontEnd:PopScreen(dialog)
			end
		end)

	-- Show the popup
	TheFrontEnd:PushScreen(dialog)

	-- And animate it in!
	dialog:AnimateIn()
end

function PauseScreen:OnClickOnlineJoinCode()
	local success = TheNet:CopyJoinCodeToClipboard()
	if success then
		if self.online_joincode_button and not self.online_joincode_copied then
			self.online_joincode_button:Disable()
			local offx, offy = self.online_joincode_button:GetSize()
			self.online_joincode_copied = self:AddChild(Text(FONTFACE.BODYTEXT, FONTSIZE.OVERLAY_TEXT))
				:SetText(STRINGS.UI.PAUSEMENU.JOINCODE_COPIED)
				:LayoutBounds("center", "below", self.online_joincode_button)

			local fadeStatus = Updater.Series({
				Updater.Wait(2.0),
				Updater.Ease(function(v) self.online_joincode_copied:SetMultColorAlpha(v) end, 1, 0, 0.5, easing.inOutQuad),
				Updater.Do(function()
					self.online_joincode_copied:Remove()
					self.online_joincode_copied = nil
					self.online_joincode_button:Enable()
				end)
			})

			self:RunUpdater(fadeStatus)
		end
	end
end

PauseScreen.CONTROL_MAP =
{
	{
		control = Controls.Digital.SHOW_PLAYERS_LIST,
		fn = function(self)
			TheFrontEnd:PushScreen(PlayersScreen())
			return true
		end,
	},
}

function PauseScreen:OnControl(controls, down)
	if PauseScreen._base.OnControl(self,controls, down) then
		return true
	elseif not down and (controls:Has(Controls.Digital.PAUSE, Controls.Digital.CANCEL)) then
		self:Unpause()
		return true
	end
end

function PauseScreen:OnUpdate(dt)
	if self.active then
		SetGameplayPause(true, "PauseScreen")
	end
end

function PauseScreen:OnBecomeActive()
	PauseScreen._base.OnBecomeActive(self)

	-- Hide the topfade, it'll obscure the pause menu if paused during fade. Fade-out will re-enable it
	TheFrontEnd:HideTopFade()

	-- User may have been in options to rebind.
	self.controls:RefreshIcons()

	if not self.animatedIn then
		self:AnimateIn()
		self.animatedIn = true
	end
end

function PauseScreen:AnimateIn()

	-- Hide elements
	self.bg:SetMultColorAlpha(0)
	self.map:SetMultColorAlpha(0)
	self.mapLegend:SetMultColorAlpha(0)


	-- Get default positions
	local bgX, bgY = self.bg:GetPosition()
	local mapX, mapY = self.map:GetPosition()
	local mapLegendX, mapLegendY = self.mapLegend:GetPosition()

	local function AnimateButtonFromLeft_Sequence(btn)
		local btn_x, btn_y = btn:GetPosition()
		btn:SetMultColorAlpha(0)
		return {
			Updater.Wait(0.4),
			Updater.Parallel({
					Updater.Ease(function(v) btn:SetMultColorAlpha(v) end, 0, 1, 0.1, easing.inOutQuad),
					Updater.Ease(function(v) btn:SetPosition(v, btn_y) end, btn_x - 40, btn_x, 0.2, easing.inOutQuad),
				})
		}
	end


	-- Start animating
	local animateSequence = Updater.Parallel({

		Updater.Do(function()
			TheDungeon.HUD:Hide()
		end),

		-- Animate map background
		Updater.Series({
			-- Updater.Wait(0.15),
			Updater.Parallel({
				Updater.Ease(function(v) self.bg:SetMultColorAlpha(v) end, 0, self.bg.full_alpha, 0.5, easing.outQuad),
				Updater.Ease(function(v) self.bg:SetScale(v) end, 1.1, 1, 0.3, easing.outQuad),
				Updater.Ease(function(v) self.bg:SetPosition(bgX, v) end, bgY + 10, bgY, 0.3, easing.outQuad),
			}),
		}),

		-- And the map
		Updater.Series({
			Updater.Wait(0.1),
			Updater.Parallel({
				Updater.Ease(function(v) self.map:SetMultColorAlpha(v) end, 0, 1, 0.1, easing.outQuad),
				Updater.Ease(function(v) self.map:SetPosition(mapX, v) end, mapY + 10, mapY, 0.4, easing.outQuad),
			}),
		}),

		-- And the legend
		Updater.Series({
			Updater.Wait(0.4),
			Updater.Parallel({
				Updater.Ease(function(v) self.mapLegend:SetMultColorAlpha(v) end, 0, 1, 0.1, easing.outQuad),
				Updater.Ease(function(v) self.mapLegend:SetPosition(v, mapLegendY) end, mapLegendX + 40, mapLegendX, 0.3, easing.outQuad),
			}),
		}),

		Updater.Series(AnimateButtonFromLeft_Sequence(self.closeButton)),
		Updater.Series(AnimateButtonFromLeft_Sequence(self.manageMPButton)),

	})

	-- Animate the other buttons too

	local function AnimateButtonFromRight(btn)
		btn:SetMultColorAlpha(0)
		local btn_x, btn_y = btn:GetPosition()
		animateSequence:Add(Updater.Series({
					Updater.Wait(0.4),
					Updater.Parallel({
							Updater.Ease(function(v) btn:SetMultColorAlpha(v) end, 0, 1, 0.1, easing.inOutQuad),
							Updater.Ease(function(v) btn:SetPosition(v, btn_y) end, btn_x + 40, btn_x, 0.2, easing.inOutQuad),
						}),
			}))
	end

	AnimateButtonFromRight(self.optionsButton)
	AnimateButtonFromRight(self.quit_button)
	AnimateButtonFromRight(self.imStuckButton)

	self:RunUpdater(animateSequence)
end

return PauseScreen
