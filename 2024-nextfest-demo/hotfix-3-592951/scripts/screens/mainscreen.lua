local Widget = require "widgets.widget"
local WishlistCTA = require "widgets.ftf.wishlistcta"
local Image = require "widgets.image"
local Text = require "widgets.text"
local MenuMultiplayerWidget = require "widgets.ftf.menumultiplayerwidget"
local MenuOnlineWidget = require "widgets.ftf.menuonlinewidget"
local DiscordCTA = require"widgets.ftf.discordcta"
local Screen = require "widgets.screen"
local ConfirmDialog = require "screens.dialogs.confirmdialog"
local OptionsScreen = require "screens.optionsscreen"
local RoomLoader = require "roomloader"
local templates = require "widgets.ftf.templates"
local audioid = require "defs.sound.audioid"
local fmodtable = require "defs.sound.fmodtable"
local easing = require "util.easing"

OFFLINE_DIALOG = nil

local IS_ONLINE_ENABLED = true
local IS_STEAM_ENABLED = true -- False if on other platforms without friends list

local bottom_pad = 60

local MainScreen = Class(Screen, function(self, profile)
	Screen._ctor(self, "MainScreen")
	self:SetAudioEnterOverride(nil)
		:SetAudioExitOverride(nil)
	self.profile = profile
	self:DoInit()
	self.default_focus = self.play_button
	assert(self.default_focus)
end)

-- ┌────────────────────────────────────────────────────────────────────────────────┐
-- │                                 (warning_stack)                                │ ◄ bg
-- │                                                                                │ ◄ overlay
-- │                            ┌───────────────────────┐                           │
-- │                            │ game_logo             │                           │
-- │                            │                       │                           │
-- │                            │                       │                           │
-- │                            │                       │                           │
-- │                            │                       │                           │
-- │                            └───────────────────────┘                           │
-- │                                                                                │
-- │                                                                                │
-- │                          ┌───────────────────────────┐                         │
-- │                          │ interactions_container    │                         │ ◄ interaction_play (Widget)
-- │                          │                           │                         │   (just the Play button)
-- │                          │                           │                         │ ◄ interaction_multiplayer (MenuMultiplayerWidget)
-- │                          │                           │                         │   (choice between solo and multiplayer)
-- │                          │                           │                         │ ◄ interaction_online (MenuOnlineWidget)
-- │                          │                           │                         │   (choice between joining or hosting a game)
-- │                          │                           │                         │
-- │ ┌──────────────┐         └───────────────────────────┘                         │
-- │ │ corner_btns  │                                                               │
-- │ └──────────────┘                                                               │
-- └────────────────────────────────────────────────────────────────────────────────┘

function MainScreen:DoInit()
	HideLoading()

	self:SetAnchors("center","center")

	TheSaveSystem.active_players:Erase() -- there are no active players when in the main menu, so wipe this data.

	TheGameSettings:GetGraphicsOptions():DisableStencil()
	TheGameSettings:GetGraphicsOptions():DisableLightMapComponent()

	-- Background art
	self.bg = self:AddChild(templates.TitleBackground())
		:SetName("Background")
	-- Background darkening
	self.overlay = self:AddChild(Image("images/global/square.tex"))
		:SetName("Background overlay")
		:SetSize(RES_X, RES_Y)
		:SetMultColor(UICOLORS.BACKGROUND_DARKEST)
		:SetMultColorAlpha(0)

	-- Add warning messages as children.
	self.warning_stack = self:AddChild(Widget("warning_stack"))
		:LayoutBounds("center", "top", self)
		:Offset(0, -50)

	----------------------------------------------------------------------
	-- Game version
	self.updatename = self:AddChild(Text(FONTFACE.DEFAULT, 42))
		:SetGlyphColor(UICOLORS.WHITE)
		:SetHAlign(ANCHOR_RIGHT)
	-- Unlocalized text that player's aren't intended to read.
	local rev_fmt = "REV. %s"
	if RELEASE_CHANNEL ~= "prod" then
		rev_fmt = RELEASE_CHANNEL:upper() .. " REV. %s"
	end
	local rev = string.format(rev_fmt, APP_VERSION)
	self.updatename:SetText(rev)
		:LayoutBounds("right", "top", self)
		:Offset(-bottom_pad, -bottom_pad)
	----------------------------------------------------------------------
	-- Mod warning
	if TheSim:IsGameDataModified() then
		self.modwarning = self.warning_stack:AddChild(Text(FONTFACE.DEFAULT, 62))
			:SetGlyphColor(UICOLORS.WHITE)
			:SetText(STRINGS.UI.MAINSCREEN.MODIFIED_DATA)
			:SetHAlign(ANCHOR_MIDDLE)
	end


	-- Flip to playtest logo here.
	self.game_logo = self:AddChild(Image("images/ui_ftf/logo_demo.tex"))
		:Offset(0, 398)
		:SetScale(1.4)
--	self.game_logo = self:AddChild(Image("images/ui_ftf/logo.tex"))
--		:Offset(0, 487.6)
--		:SetScale(1.4)

	self.game_logo:SetName("Game logo")
	self.game_logo_x, self.game_logo_start_y = self.game_logo:GetPos() -- On the Play interaction
	self.game_logo_end_y = self.game_logo_start_y + 100 -- On the other interactions

	if LOC.IsLocalized() then
		self.loc_disclaimer = self.warning_stack:AddChild(Text(FONTFACE.DEFAULT, FONTSIZE.SCREEN_TEXT))
			:SetText(STRINGS.UI.MAINSCREEN.TRANSLATION_WIP)
			:SetHAlign(ANCHOR_MIDDLE)
	end


	-- Bottom-left corner buttons
	self.left_corner_btns = self:AddChild(Widget())
		:SetName("Left corner buttons")
	self.exit_button = self.left_corner_btns:AddChild(templates.Button(STRINGS.UI.MAINSCREEN.QUIT))
		:SetKonjur()
		:SetFlipped()
		:ResizeToFit(90)
		:SetOnClick(function() self:Quit() end)
		:SetMultColorAlpha(0)
		:Hide()
		:SetControlUpSound(nil)
	self.options_button = self.left_corner_btns:AddChild(templates.Button(STRINGS.UI.PAUSEMENU.OPTIONS_BUTTON))
		:SetSecondary()
		:ResizeToFit(90)
		:SetOnClick(function() self:OnClickOptions() end)
		:SetMultColorAlpha(0)
		:Hide()
	self.multiplayer_back_button = self.left_corner_btns:AddChild(templates.Button(STRINGS.UI.MAINSCREEN.BACK))
		:SetSecondary()
		:ResizeToFit(90)
		:SetOnClick(function() self:OnClickMultiplayerBack() end)
		:SetMultColorAlpha(0)
		:Hide()
	self.online_back_button = self.left_corner_btns:AddChild(templates.Button(STRINGS.UI.MAINSCREEN.BACK))
		:SetSecondary()
		:ResizeToFit(90)
		:SetOnClick(function() self:OnClickOnlineBack() end)
		:SetMultColorAlpha(0)
		:Hide()

	self:LayoutLeftCornerButtons()

	-- Bottom-right corner buttons

	self.right_corner_btns = self:AddChild(Widget())
		:SetName("Right corner buttons")

	self.discord_cta = self.right_corner_btns:AddChild(DiscordCTA())
	self.wishlist_btn = self:AddChild(WishlistCTA()) -- DEMO!

	self:LayoutRightCornerButtons()

	----------------------------------------------------------------------
	----------------------------------------------------------------------
	-- Interactions container
	-- This holds the various interactive widgets this screen can display
	-- Positioning of the interaction widgets is done within the _AnimateInInteraction functions below
	self.interactions_container = self:AddChild(Widget())
		:SetName("Interactions container")
		:LayoutBounds("center", "center", self)
		:Offset(0, -200)

	-- The default interaction, when you first open the screen
	self.interaction_play = self.interactions_container:AddChild(Widget())
		:SetName("Interaction - Play")
		:Hide()

	-- Allows the player to choose between single or multiplayer
	self.interaction_multiplayer = self.interactions_container:AddChild(MenuMultiplayerWidget())
		:SetName("Interaction - Multiplayer")
		:SetOnSingleplayerFn(function(device_type, device_id) self:OnClickSinglePlayer(device_type, device_id) end)
		:SetOnMultiplayerFn(function() self:_AnimateInInteractionOnline() end)
		:Hide()

	-- Allows the player to choose between hosting or joining a game
	self.interaction_online = self.interactions_container:AddChild(MenuOnlineWidget())
		:SetName("Interaction - Online")
		:ShowSteamFriends(IS_STEAM_ENABLED)
		:Hide()
	----------------------------------------------------------------------
	----------------------------------------------------------------------

	self.play_button = self.interaction_play:AddChild(templates.Button(STRINGS.UI.MAINSCREEN.PLAY))
		:SetPrimary()
		:SetOnClick(function()
			self.play_button:Disable()
			self:OnPlayButton()
		end)
	local online_label = TheSim:GetOnlineEnabled() and STRINGS.UI.MAINSCREEN.ONLINE_PLAY_INFO or STRINGS.UI.MAINSCREEN.ONLINE_INACTIVE_INFO
	self.online_play_info_label = self.interaction_play:AddChild(Text(FONTFACE.DEFAULT, FONTSIZE.SCREEN_TEXT))
		:SetGlyphColor(UICOLORS.LIGHT_BACKGROUNDS_DARK)
		:SetHAlign(ANCHOR_MIDDLE)
		:SetAutoSize(900)
		:SetText(online_label)
		:LayoutBounds("center", "below", self.play_button)
		:Offset(0, -30)

	self.dbg_btn_root = self:AddChild(Widget())
	self.dbg_btn_root.uitest = self.dbg_btn_root:AddChild(templates.Button("<p img='images/icons_ftf/menu_search.tex' scale=1 color=0> UI Assets"))
		:SetDebug()
		:SetOnClick(function()
			local UITestScreen = require "screens/uitestscreen"
			TheFrontEnd:PushScreen(UITestScreen())
		end)
		:SetScale(.75)
		:SetNormalScale(.75)
		:SetFocusScale(.8)
	self.dbg_btn_root.widgettest = self.dbg_btn_root:AddChild(templates.Button("Widget Test"))
		:SetDebug()
		:SetOnClick(function()
			local WidgetTest = require "screens/featuretests/widgettest"
			TheFrontEnd:PushScreen(WidgetTest())
		end)
		:SetScale(.75)
		:SetNormalScale(.75)
		:SetFocusScale(.8)
	self.dbg_btn_root.texttest = self.dbg_btn_root:AddChild(templates.Button("Text Test"))
		:SetDebug()
		:SetOnClick(function()
			local TextTest = require "screens/featuretests/texttest"
			TheFrontEnd:PushScreen(TextTest())
		end)
		:SetScale(.75)
		:SetNormalScale(.75)
		:SetFocusScale(.8)
	self.dbg_btn_root.resetSave = self.dbg_btn_root:AddChild(templates.Button("Reset Save Data"))
		:SetDebug() -- User-facing version is in options.
		:SetToolTip("Production button to clear save data is in options.")
		:SetOnClick(function()
			print("Resetting character, world, everything save data...")
			TheSaveSystem.about_players:SetValue("last_selected_slot", nil)
			TheSaveSystem:EraseAll(function(success)
				if success then
					print("Reset complete.")
				else
					print("Reset failed.")
				end
				c_reset()
			end)
		end)
		:SetScale(.75)
		:SetNormalScale(.75)
		:SetFocusScale(.8)
	self.dbg_btn_root
		:LayoutChildrenInGrid(1,10)
		:LayoutBounds("right", "below", self.updatename)
		:Offset(0, -10)


	self.dbg_play_root = self:AddChild(Widget())

	local function SetInputID(device_type, device_id)
		local inputID = TheInput:ConvertToInputID(device_type, device_id)
		TheSaveSystem.cheats:SetValue("debug_inputID", inputID)
	end

	-- self.dbg_quickplay = self.dbg_play_root:AddChild(templates.Button("Quick Play"))
	-- 	:SetDebug()
	-- 	:SetOnClick(function(...)
	-- 		SetInputID(...)
	-- 		self.dbg_quickplay:Disable()
	-- 		self:OnPlayButton(true)
	-- 	end)
	-- 	:SetScale(.75)
	-- 	:SetNormalScale(.75)
	-- 	:SetFocusScale(.8)

	-- if not TheSaveSystem.about_players:GetValue("last_selected_slot") then
	-- 	self.dbg_quickplay:Disable()
	-- end

	self.dbg_startdailyrun = self.dbg_play_root:AddChild(templates.Button("Start Daily Run"))
		:SetDebug()
		:SetOnClick(function(...)
			SetInputID(...)
			d_startdailyrun()
		end)
		:SetScale(.75)
		:SetNormalScale(.75)
		:SetFocusScale(.8)
	self.dbg_startrun = self.dbg_play_root:AddChild(templates.Button("Start Run"))
		:SetDebug()
		:SetOnClick(function(...)
			SetInputID(...)
			d_startrun()
		end)
		:SetScale(.75)
		:SetNormalScale(.75)
		:SetFocusScale(.8)
	self.dbg_startboss = self.dbg_play_root:AddChild(templates.Button("Start Boss"))
		:SetDebug()
		:SetOnClick(function(...)
			SetInputID(...)
			d_startboss()
		end)
		:SetScale(.75)
		:SetNormalScale(.75)
		:SetFocusScale(.8)
	self.dbg_startempty = self.dbg_play_root:AddChild(templates.Button("Empty Room"))
		:SetDebug()
		:SetOnClick(function(...)
			SetInputID(...)
			d_loadempty()
		end)
		:SetScale(.75)
		:SetNormalScale(.75)
		:SetFocusScale(.8)
	self.dbg_starttraining = self.dbg_play_root:AddChild(templates.Button("Training Room"))
		:SetDebug()
		:SetOnClick(function(...)
			SetInputID(...)
			d_loadempty("test_training_room")
		end)
		:SetScale(.75)
		:SetNormalScale(.75)
		:SetFocusScale(.8)
	self.dbg_edittown = self.dbg_play_root:AddChild(templates.Button("Edit Town"))
		:SetDebug()
		:SetOnClick(function(...)
			SetInputID(...)
			d_loadroom(TOWN_LEVEL)
		end)
		:SetScale(.75)
		:SetNormalScale(.75)
		:SetFocusScale(.8)
	self.dbg_sloth = self.dbg_play_root:AddChild(templates.Button("Old Town"))
		:SetDebug()
		:SetOnClick(function(...)
			SetInputID(...)
			d_loadroom("home_old")
		end)
		:SetScale(.75)
		:SetNormalScale(.75)
		:SetFocusScale(.8)

	self.dbg_play_root
		:LayoutChildrenInGrid(1,10)
		:LayoutBounds("left", "top", self)
		:Offset(bottom_pad, -bottom_pad)

	local dbg_btns = table.appendarrays({}, self.dbg_btn_root:GetChildren(), self.dbg_play_root:GetChildren())
	for i,btn in ipairs(dbg_btns) do
		if i % 2 == 0 then
			btn:SetFlipped()
		end
	end

	self.warning_stack:LayoutChildrenInColumn(30)

	for _, value in pairs(audioid.persistent) do
		TheAudio:StopPersistentSound(value)
	end
	TheAudio:PlayPersistentSound(audioid.persistent.ui_music, fmodtable.Event.mus_TitleScreen_LP)

end

MainScreen.CONTROL_MAP =
{
	{
		control = Controls.Digital.CANCEL,
		fn = function(self)
			if self.online_back_button:IsShown() then
				self.online_back_button:Click()
			elseif self.multiplayer_back_button:IsShown() then
				self.multiplayer_back_button:Click()
			elseif self.exit_button:IsShown() then
				self.exit_button:Click()
			end
			return true
		end,
	}
}

function MainScreen:DoPickCharacter()
 -- player entity doesn't exist at this point, so we can't do this yet...
end

function MainScreen:LayoutLeftCornerButtons()
	self.left_corner_btns:LayoutChildrenInRow(20)
	self.left_corner_btns:LayoutBounds("left", "bottom", self)
		:Offset(bottom_pad, bottom_pad)
	return self
end

function MainScreen:LayoutRightCornerButtons()
	self.right_corner_btns:LayoutChildrenInRow(20)
	self.right_corner_btns:LayoutBounds("right", "bottom", self)
		:Offset(-bottom_pad, bottom_pad)
	-- Not part of right_corner_btns because it doesn't display at the same time as discord.
	self.wishlist_btn
		:LayoutBounds("right", "bottom", self)
		:Offset(-bottom_pad, bottom_pad)
end

function MainScreen:OnPlayButton()
	-- Online play is active. Show those options
	self:_AnimateInInteractionMultiplayer()
	TheFrontEnd:GetSound():PlaySound(fmodtable.Event.ui_overlay_enter)
	-- TheAudio:StartFMODSnapshot(fmodtable.Snapshot.Dim_TitleScreen_Music)
	self.wishlist_btn:AnimateOut()
end

function MainScreen:OnClickSinglePlayer(device_type, device_id)
	-- Start the network game:
	local inputID = TheInput:ConvertToInputID(device_type, device_id)
	TheNet:StartGame(inputID, "local")

	if TheInput:IsKeyDown(InputConstants.Keys.ALT) then
		RoomLoader.DevLoadLevel(TOWN_LEVEL)
	else
		RoomLoader.LoadTownLevel(TOWN_LEVEL)
	end
end

function MainScreen:OnClickOptions()
	TheFrontEnd:PushScreen(OptionsScreen())
	--Ensure last_focus is the options button since mouse can
	--unfocus this button during the screen change, resulting
	--in controllers having no focus when toggled on from the
	--options screen
	self.last_focus = self.options_button
	return self
end

function MainScreen:OnClickMultiplayerBack()
	self:_AnimateInInteractionPlay()
	return self
end

function MainScreen:OnClickOnlineBack()
	self:_AnimateInInteractionMultiplayer()
	return self
end

function MainScreen:Quit()
	local confirmation = nil

	confirmation = ConfirmDialog(nil, self.exit_button, true,
		STRINGS.UI.MAINSCREEN.ASKQUIT,
		STRINGS.UI.MAINSCREEN.ASKQUITSUBTITLE,
		STRINGS.UI.MAINSCREEN.ASKQUITDESC)
		:SetYesButtonText(STRINGS.UI.MAINSCREEN.YES)
		:SetNoButtonText(STRINGS.UI.MAINSCREEN.NO)
		:SetOnDoneFn(function(accepted)
			if accepted then
				RequestShutdown()
			else
				TheFrontEnd:PopScreen(confirmation)
			end
		end)
		:SetArrowXOffset(20) -- extra right shift looks more centred
		:SetAnchorOffset(380, 0)

	TheFrontEnd:PushScreen(confirmation)

	-- And animate it in!
	confirmation:AnimateIn()

end

function MainScreen:OnOpen()
	MainScreen._base.OnOpen(self)
	for _, value in pairs(audioid.persistent) do
		TheAudio:StopPersistentSound(value)
	end
	TheAudio:PlayPersistentSound(audioid.persistent.ui_music, fmodtable.Event.mus_TitleScreen_LP)

	-- Show first interaction
	self:_AnimateInInteractionPlay()

	self:FocusTest_ValidateSaveFiles()

	-- Display offline popup when data collection is disabled
	if RUN_GLOBAL_INIT then
		if not TheSim:GetOnlineEnabled() then
			local body = table.concat({
					STRINGS.UI.DATACOLLECTION.REQUIREMENT,
					STRINGS.UI.DATACOLLECTION.LOGIN.SEE_OPTIONS
				},
				"\n\n")
			local dialog = ConfirmDialog(nil, nil, true, STRINGS.UI.DATACOLLECTION.LOGIN.TITLE, nil, body)
			dialog
				:SetYesButton(STRINGS.UI.DATACOLLECTION.LOGIN.CONTINUE,
					function()
						dialog:Close()
						OFFLINE_DIALOG = nil
					end)
				:HideArrow() 
				:HideNoButton()
				:SetMinWidth(1000)
				:CenterButtons()
			TheFrontEnd:PushScreen(dialog)
			dialog:AnimateIn()
			OFFLINE_DIALOG = dialog
		end
	end
end

function MainScreen:FocusTest_ValidateSaveFiles()
	local version = TheSaveSystem.progress:GetValue("global_version")
	TheLog.ch.SaveLoad:printf("Loaded global_version %s and expected version %s.", version, TheSaveSystem.progress.GLOBAL_VERSION)
	-- Require exact match because there's no migration support here.
	if version ~= TheSaveSystem.progress.GLOBAL_VERSION then
		local confirmation = ConfirmDialog(nil, nil, true,
			STRINGS.UI.MAINSCREEN.INCOMPATIBLE_SAVE.ASK_ERASE.TITLE,
			nil,
			STRINGS.UI.MAINSCREEN.INCOMPATIBLE_SAVE.ASK_ERASE.BODY)

		confirmation:SetYesButtonText(STRINGS.UI.MAINSCREEN.INCOMPATIBLE_SAVE.ASK_ERASE.CONFIRM)
			:HideNoButton()
			:HideArrow()
			:CenterText()
			:CenterButtons()
			:SetWideButtons()
			:SetOnDoneFn(function()
				TheLog.ch.SaveLoad:print("Player selected wipe saves due to global_version mismatch.")
				TheSaveSystem:EraseAll(function()
					TheFrontEnd:PopScreen(confirmation)

					local ok_popup = ConfirmDialog(nil, nil, true,
						STRINGS.UI.MAINSCREEN.INCOMPATIBLE_SAVE.ERASE_COMPLETE.TITLE,
						nil,
						STRINGS.UI.MAINSCREEN.INCOMPATIBLE_SAVE.ERASE_COMPLETE.BODY)

					ok_popup:SetYesButtonText(STRINGS.UI.BUTTONS.OK)
						:HideNoButton()
						:HideArrow()
						:CenterText()
						:CenterButtons()
						:SetOnDoneFn(function()
							TheFrontEnd:PopScreen(ok_popup)
							-- Restart to ensure clean save data startup.
							RestartToMainMenu()
						end)
					TheFrontEnd:PushScreen(ok_popup)
				end)
		end)
		TheFrontEnd:PushScreen(confirmation)
	end
end

function MainScreen:OnBecomeActive()
	MainScreen._base.OnBecomeActive(self)
end

function MainScreen:_AnimateInInteractionPlay()

	-- Hide things that aren't visible
	self.overlay:AlphaTo(0, 0.3, easing.outQuad)
	self.play_button:SetMultColorAlpha(0):Enable()
	self.interaction_multiplayer:Hide()
	self.interaction_online:Hide()

	self.discord_cta:Hide()

	-- Prepare corner buttons for animation
	self.exit_button:SetMultColorAlpha(0):Show()
	self.options_button:SetMultColorAlpha(0):Show()
	self.multiplayer_back_button:Hide()
	self.online_back_button:Hide()
	self:LayoutLeftCornerButtons()
	local exit_button_x, exit_button_y = self.exit_button:GetPos()
	local options_button_x, options_button_y = self.options_button:GetPos()

	self.wishlist_btn:AnimateIn()

	-- Animate stuff in
	self:RunUpdater(Updater.Parallel{
		Updater.Do(function()
			self.interaction_play:Show()
				:LayoutBounds("center", "center", 0, self.interactions_container.y)
				:Offset(0, -200)

			-- Update default_focus
			self.default_focus = self.play_button
			-- Ensure it has focus when you back out of Play.
			self.default_focus:SetFocus()
			-- Unlike most screens, we likely appear before the user has
			-- touched the gamepad. So turn on brackets for all inputs if
			-- there's a gamepad connected (even if not in use).
			if TheInput:HasAnyConnectedGamepads() then
				self:EnableFocusBracketsForGamepadAndMouse()
			else
				self:EnableFocusBracketsForGamepad()
			end
		end),

		Updater.Ease(function(y) self.game_logo:SetPos(self.game_logo_x, y) end, self.game_logo.y, self.game_logo_start_y, 0.9, easing.outElasticUI),

		Updater.Ease(function(a) self.play_button:SetMultColorAlpha(a) end, 0, 1, 0.25, easing.outQuad),
		Updater.Ease(function(y) self.play_button:SetPos(0, y) end, -50, 0, 0.75, easing.outElasticUI),

		Updater.Series{
			Updater.Wait(0.25),
			Updater.Parallel{
				-- Close button
				Updater.Ease(function(a) self.exit_button:SetMultColorAlpha(a) end, 0, 1, 0.25, easing.outQuad),
				Updater.Ease(function(y) self.exit_button:SetPos(exit_button_x, y) end, exit_button_y-40, exit_button_y, 0.75, easing.outElasticUI),
			},
		},
		Updater.Series{
			Updater.Wait(0.35),
			Updater.Parallel{
				-- Options button
				Updater.Ease(function(a) self.options_button:SetMultColorAlpha(a) end, 0, 1, 0.25, easing.outQuad),
				Updater.Ease(function(y) self.options_button:SetPos(options_button_x, y) end, options_button_y-40, options_button_y, 0.75, easing.outElasticUI),
			}
		}

	})

	return self
end

function MainScreen:_AnimateInInteractionMultiplayer()

	-- Hide things that aren't visible
	self.discord_cta:Hide()
	self.interaction_play:Hide()
	self.interaction_multiplayer:Hide()
	self.interaction_online:Hide()

	-- Prepare corner buttons for animation
	self.exit_button:Hide()
	self.options_button:Hide()
	self.multiplayer_back_button:SetMultColorAlpha(0):Show()
	self.online_back_button:Hide()
	self:LayoutLeftCornerButtons()
	local multiplayer_back_button_x, multiplayer_back_button_y = self.multiplayer_back_button:GetPos()

	-- Check if there is network
	if IS_ONLINE_ENABLED and TheNet:IsLoggedOn() then
		self.interaction_multiplayer:SetOnline(true)
			:SetOnMultiplayerFn(function() self:_AnimateInInteractionOnline() end)
	else
		self.interaction_multiplayer:SetOnline(false)
			:SetOnMultiplayerFn(function() self.interaction_multiplayer:ShowOfflineError() end)
	end

	-- Animate stuff in
	self:RunUpdater(Updater.Parallel{
		Updater.Do(function()
			self.interaction_multiplayer:Show()
				:LayoutBounds("center", "center", 0, self.interactions_container.y)
				:AnimateIn()

			-- Update default_focus
			self.default_focus = self.interaction_multiplayer.default_focus
			self.default_focus:SetFocus()
			self:_UpdateSelectionBrackets(self.default_focus)
		end),

		Updater.Ease(function(y) self.game_logo:SetPos(self.game_logo_x, y) end, self.game_logo.y, self.game_logo_end_y, 0.9, easing.outElasticUI),

		Updater.Ease(function(a) self.overlay:SetMultColorAlpha(a) end, self.overlay:GetMultColorAlpha(), 0.85, 0.45, easing.outQuad),

		Updater.Series{
			Updater.Wait(0.25),
			Updater.Parallel{
				-- Back button
				Updater.Ease(function(a) self.multiplayer_back_button:SetMultColorAlpha(a) end, 0, 1, 0.25, easing.outQuad),
				Updater.Ease(function(y) self.multiplayer_back_button:SetPos(multiplayer_back_button_x, y) end, multiplayer_back_button_y-40, multiplayer_back_button_y, 0.75, easing.outElasticUI),
			},
		}

	})


	return self
end

function MainScreen:_AnimateInInteractionOnline()

	-- Hide things that aren't visible
	self.interaction_play:Hide()
	self.interaction_multiplayer:Hide()
	self.interaction_online:Hide()

	-- Prepare corner buttons for animation
	self.exit_button:Hide()
	self.options_button:Hide()
	self.multiplayer_back_button:Hide()
	self.online_back_button:SetMultColorAlpha(0):Show()
	self:LayoutLeftCornerButtons()
	local online_back_button_x, online_back_button_y = self.online_back_button:GetPos()

	-- Animate stuff in
	self:RunUpdater(Updater.Parallel{
		Updater.Do(function() self.interaction_online:Show()
			:LayoutBounds("center", "center", 0, self.interactions_container.y)
			:AnimateIn()

			-- Update default_focus
			self.default_focus = self.interaction_online.default_focus
			self.default_focus:SetFocus()
			self:_UpdateSelectionBrackets(self.default_focus)
		end),

		Updater.Ease(function(y) self.game_logo:SetPos(self.game_logo_x, y) end, self.game_logo.y, self.game_logo_end_y, 0.9, easing.outElasticUI),

		Updater.Ease(function(a) self.overlay:SetMultColorAlpha(a) end, self.overlay:GetMultColorAlpha(), 0.85, 0.45, easing.outQuad),

		Updater.Series{
			Updater.Wait(0.25),
			Updater.Parallel{
				-- Back button
				Updater.Ease(function(a) self.online_back_button:SetMultColorAlpha(a) end, 0, 1, 0.25, easing.outQuad),
				Updater.Ease(function(y) self.online_back_button:SetPos(online_back_button_x, y) end, online_back_button_y-40, online_back_button_y, 0.75, easing.outElasticUI),
				Updater.Do(function() self.discord_cta:AnimateIn() end),
			},
		}

	})

	return self
end

function MainScreen:OnUpdate(dt)
	if IS_ONLINE_ENABLED then
		self.online_play_info_label:Show()
			:SetText(TheNet:IsLoggedOn() and STRINGS.UI.MAINSCREEN.ONLINE_PLAY_INFO or STRINGS.UI.MAINSCREEN.ONLINE_INACTIVE_INFO)
	else
		self.online_play_info_label:Hide()
	end
end

return MainScreen
