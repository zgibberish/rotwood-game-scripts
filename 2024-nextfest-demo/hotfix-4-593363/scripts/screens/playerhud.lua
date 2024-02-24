local BossHealthBar = require("widgets/ftf/bosshealthbar")
local CookingButton = require("widgets/ftf/cookingbutton")
local CookingButtonTrack = require("widgets/ftf/cookingbuttontrack")
local DamageNumber = require("widgets/ftf/damagenumber")
local DebugNodes = require "dbui.debug_nodes"
local DungeonHud = require "widgets.ftf.dungeonhud"
local FollowButton = require("widgets/ftf/followbutton")
local FollowLabel = require("widgets/ftf/followlabel")
local FollowRevive = require("widgets/ftf/followrevive")
local FollowPower = require("widgets/ftf/followpower")
local FollowGem = require("widgets/ftf/followgem")
local FullscreenEffect = require "widgets.fullscreeneffect"
local HitCounter = require "widgets/ftf/hitcounter"
local Image = require "widgets.image"
local NpcPrompt = require("widgets/ftf/npcprompt")
local PauseScreen = require("screens/redux/pausescreen")
local PlayerFollowHealthBar = require "widgets/ftf/playerfollowhealthbar"
local PlayerFollowStatus = require "widgets/ftf/playerfollowstatus"
local PlayerEmoteRing = require "widgets/ftf/playeremotering"
local LoadoutWidget = require "widgets/ftf/loadoutwidget"
local PlayerUnitFrames = require("widgets/ftf/playerunitframes")
local PlayersScreen = require "screens.playersscreen"
local PopText = require("widgets/ftf/poptext")
local PopGem = require("widgets/ftf/popgem")
local PopPower = require("widgets/ftf/poppower")
local PopPowerDisplay = require("widgets/ftf/poppowerdisplay")
local PopMasteryProgress = require("widgets/ftf/popmasteryprogress")
local RunSummaryScreen = require "screens.dungeon.runsummaryscreen"
local HuntAccoladesScreen = require "screens.dungeon.huntaccoladesscreen"
local Screen = require("widgets/screen")
local Text = require "widgets.text"
local TitleCard = require "screens.dungeon.titlecard"
local TownHud = require "widgets.ftf.townhud"
local TravelScreen = require "screens.dungeon.travelscreen"
local Widget = require "widgets.widget"
local easing = require "util.easing"
local lume = require "util.lume"
local templates = require "widgets.ftf.templates"
local playerutil = require "util.playerutil"
local ConfirmDialog = require "screens.dialogs.confirmdialog"
local Text = require "widgets/text"
local TextEdit = require "widgets/textedit"
local soundutil = require "util.soundutil"
local fmodtable = require "defs.sound.fmodtable"

local PlayerHud = Class(Screen, function(self)
	Screen._ctor(self, "HUD")
	self:SetAudioCategory(Screen.AudioCategory.s.None)

	-- Since these are screens, they have fullscreen bounds.
	-- under_root holds full-screen effects that are not to include the PlayerHud itself.
	self.under_root = self:AddChild(Screen("under_root"))

	-- game_world holds UI elements that are located in game world space, often attached to game entities to indicate
	-- status. E.g. damage numbers, ware prices, etc..
	self.game_world = self:AddChild(Screen("game_world"))
	self.game_world.OnUpdate = function(game_world)
		game_world:SortChildren(function(a, b)
			if a.z == b.z then
				-- Different sort order! Put the newest widget in front.
				return a.inst.GUID < b.inst.GUID
			end
			return a.z > b.z
		end)
		game_world:StopUpdating()
	end

	-- root is the main flat 2D UI presentation layer: status and interactable widgets
	self.root = self:AddChild(Screen("root"))

	-- over_root holds high-priority widgets that should not be obscured by the main Hud elements, like NPC dialog
	self.over_root = self:AddChild(Screen("over_root"))

	self.is_animated_in = true
	self.animated = {}

	self.effects = {
		hurt_explosion = self:AddFullScreenEffect(FullscreenEffect("images/fullscreeneffects/hitoverlay.tex",
				{
					fadein = 0.25,
					life = 0,
					fadeout = 0.75,
			})),
		death_stop = self:AddFullScreenEffect(FullscreenEffect("images/fullscreeneffects/hitoverlay.tex",
				{
					fadein = 0.25,
					life = 0,
					fadeout = 0.75,
			})),
		low_health = self:AddFullScreenEffect(FullscreenEffect("images/fullscreeneffects/halo.tex",
				{
					fadein = 0.9,
					life = 0.2,
					fadeout = 0.9,
				},
				{
					min_alpha = 0.45,
				})),
	}
	for _,effect in pairs(self.effects) do
		effect:SetAnchors("fill", "fill")
	end

	self.debug_btns = self:AddChild(Widget())
		:LayoutBounds("right", "top", self.root)
		:SetScale(0.66)
	self.debug_btns.toggle_btn = self:AddChild(templates.Button("[Debug Menu]"))
		:SetDebug()
		:SetOnClick(function() self.debug_btns:SetShown(not self.debug_btns.visible) end)
		:LayoutBounds("right", "top", self.debug_btns)
		:Offset(-10 * HACK_FOR_4K, -10 * HACK_FOR_4K)
	self:_AddGlobalDebugButtons()

	if TheDungeon:GetDungeonMap():IsDebugMap() then
		self.editicon = self:AddChild(Image("images/ui_ftf_ingame/edit_icon.tex"))
			:SetScale(.2, .2)
			:LayoutBounds("before", "top", self.debug_btns.toggle_btn)
			:Offset(-10 * HACK_FOR_4K, -6)
			:SetToolTip("World Editing Mode")
		self.editicon.inst:StartThread(function()
			while true do
				for i = 1, 20 do
					self.editicon:ApplyMultColor(1, 1, 1, (1 + i / 20) / 2)
					Yield()
				end
				for i = 19, 0, -1 do
					self.editicon:ApplyMultColor(1, 1, 1, (1 + i / 20) / 2)
					Yield()
				end
			end
		end)
	end

	local version_label = APP_VERSION == "-1" and "" or "REV. " .. APP_VERSION
	local build_label = ""
	if PLAYTEST_MODE then
		build_label = "[Demo]"
	end

	-- Show town or dungeon HUD
	if TheDungeon:IsInTown() then

		--jcheng: clear history when going back to town. This is really only here for NextFest until nosimreset is permanent
		TheDungeon.components.chathistory:Clear()

		self.townHud = self.root:AddChild(TownHud(self.debug_btns))
		self.location_hud = self.townHud
		table.insert(self.animated, self.townHud)

		self.TEMP_NO_CONTROLLER_SUPPORT_WIDGET = self.root:AddChild(Text(FONTFACE.DEFAULT, 50 * HACK_FOR_4K, "Use your mouse to place buildings for now! :)", UICOLORS.LIGHT_TEXT_TITLE))
			:LayoutBounds("center", "bottom", self.root)
			:Offset(0, 100 * HACK_FOR_4K)
			:Hide()

		self.inst:ListenForEvent("startplacing", function()
			self.TEMP_NO_CONTROLLER_SUPPORT_WIDGET:Show()
			if self.prompt then self.prompt:Hide() end
		end, TheWorld)
		self.inst:ListenForEvent("stopplacing", function()
			self.TEMP_NO_CONTROLLER_SUPPORT_WIDGET:Hide()
			if self.prompt then self.prompt:Show() end
		end, TheWorld)

		if PLAYTEST_MODE then
			self.feedback_text = self.root:AddChild(Text(FONTFACE.DEFAULT, 25 * HACK_FOR_4K, nil, UICOLORS.LIGHT_TEXT_TITLE))
				:SetMultColorAlpha(0.8)
				:RightAlign()
				:SetText(STRINGS.UI.HUD.ENCOURAGE_FEEDBACK)
				:SetAnchors("center", "bottom")
				:Offset(0, 20 * HACK_FOR_4K)
		end

		self.debug_text = self.root:AddChild(Text(FONTFACE.DEFAULT, 18 * HACK_FOR_4K, nil, UICOLORS.LIGHT_TEXT_TITLE))
			:SetMultColorAlpha(0.75)
			:SetText(string.upper(string.format("%s\n%s",
				version_label,
				build_label)))
	else
		self.dungeon_hud = self.root:AddChild(DungeonHud(self.debug_btns))
			:SetAnchors("left", "center")
			:LayoutBounds("left", "center", self.root)
		self.location_hud = self.dungeon_hud

		self.player_unit_frames = self.root:AddChild(PlayerUnitFrames())
		table.insert(self.animated, self.player_unit_frames)

		self.bosshealthbar = self.root:AddChild(BossHealthBar())
			:LayoutBounds("center", "top", self.root)
		table.insert(self.animated, self.bosshealthbar)
		self.prompt = nil

		local mapgen = require "defs.mapgen"
		local worldmap = TheDungeon:GetDungeonMap()
		local ascensionmanager = TheDungeon.progression.components.ascensionmanager
		local scene_gen = TheSceneGen and TheSceneGen.components.scenegen
		local room_difficulty = worldmap:GetDifficultyForCurrentRoom()
		local roomtype = worldmap.nav:get_roomtype(worldmap:Debug_GetCurrentRoom())
		local difficulty = mapgen.Difficulty:FromId(room_difficulty, "")
		local encounter
		if TheNet:IsHost() then
			encounter = worldmap:GetForcedEncounterForCurrentRoom() or tostring(TheWorld.components.spawncoordinator.encounter_idx or "?")
		else
			encounter = "Client " .. TheNet:GetClientID() -- only hosts run encounters
		end
		if not DEV_MODE then
			-- Limit to first letters to obscure debug info and prevent "died in
			-- easy room" sadness.
			difficulty = difficulty:sub(1,2)
			roomtype = roomtype:sub(1,4)
			-- Encounters might be "e01" or "e05_kanft_swamp" for normal or any
			-- string ("tutorial") for forced. Leave them alone to retain usefulness.
			-- encounter = encounter:sub(1,7)
		end
		local tier = scene_gen 
			and string.format("%1d", scene_gen:GetTier())
			or "*"
		self.debug_text = self.root:AddChild(Text(FONTFACE.DEFAULT, 18 * HACK_FOR_4K, nil, UICOLORS.LIGHT_TEXT_TITLE))
			:SetMultColorAlpha(0.5)
			:SetText(string.upper(string.format("%s (t%s - a%1d - %.0f%%) %s %s %s\n%s",
				version_label,
				tier,
				ascensionmanager:GetCurrentLevel(),
				worldmap.nav:GetProgressThroughDungeon() * 100,
				difficulty,
				roomtype,
				encounter,
				build_label)))

		if PLAYTEST_MODE then
			self.feedback_text = self.root:AddChild(Text(FONTFACE.DEFAULT, 25 * HACK_FOR_4K, nil, UICOLORS.LIGHT_TEXT_TITLE))
				:SetMultColorAlpha(0.66)
				:RightAlign()
				:SetText(STRINGS.UI.HUD.ENCOURAGE_FEEDBACK)
				:SetAnchors("center", "bottom")
				:Offset(0, 20 * HACK_FOR_4K)
		end

		if worldmap:IsDebugMap() then
			self:_AddDungeonDebugButtons()
		else
			self.debug_btns:Hide()
			self.debug_btns.toggle_btn:Hide()
		end

		self.victory_button = self.root:AddChild(templates.Button())
			:SetOnClick(function()
				self:DoVictoryFlow()
			end)
			:SetAnchors("center", "bottom")
			:Offset(0, 50 * HACK_FOR_4K)
			:Hide()

		self._ontravelpreview_start = function(source, cardinal) self:StartDungeonTravelPreview(cardinal) end
		self._ontravelpreview_stop = function(source) self:StopDungeonTravelPreview() end
		self.inst:ListenForEvent("travelpreview_start", self._ontravelpreview_start, TheWorld)
		self.inst:ListenForEvent("travelpreview_stop",  self._ontravelpreview_stop,  TheWorld)

	end

	--remove after NextFest
	TheDungeon.components.chathistory:Load()

	local TEXT_W = 1080
	local INPUT_H = 100
	self.chat_text_edit = self.root:AddChild( TextEdit(FONTFACE.DEFAULT, 44) )
		:SetSize(TEXT_W, INPUT_H)
		:SetEditing(false)
		:SetHAlign(ANCHOR_LEFT)
		:SetTextLengthLimit(99) -- See MaxChatLineLength in NetworkChatManager.cpp
		:SetForceEdit(true)
		:SetAnchors("center", "bottom")
		:Offset(0, 50)
		:SetString("")
		:Hide()

	self.chat_text_edit.OnTextEntered = function()
		TheNet:SendChatMessage( self.chat_text_edit:GetText() )
		TheFrontEnd:GetSound():PlaySound(fmodtable.Event.ui_chat_messageSent)
		self.chat_text_edit:Hide()
	end

	self.chat_text_edit.onlosefocus = function()
		self:RefreshChat()
		self.chat_text_edit:Hide()
	end

	self.chat_history_label = self.root:AddChild( Text(FONTFACE.DEFAULT, 60) )
		:SetAutoSize(TEXT_W)
		:SetHAlign(ANCHOR_LEFT)
		:SetShadowColor(WEBCOLORS.BLACK)
		:SetShadowOffset(1.5, -1.5)
		:EnableShadow()
		:EnableOutline()
		:SetRegistration("left","bottom")
		:SetAnchors("left", "bottom")
		:SetClickable(false)
	self:_LayoutChat()

	self.debug_text
		:SetAnchors("center", "top")
		:SetRegistration("center", "top")
		:Offset(0, -5)

	self.low_health_players = {}
	self._onlowhealthstate = function(player_source, is_low_health)
		self:OnLowHealthStateChanged(player_source, is_low_health)
	end

	self.pop_mastery_progress_widgets = {}
	self.active_mastery_popup = nil
	self.mastery_popup_queue = {}

	-- flips between - and + to control which side numbers go to
	self._damage_offset_mod = 1
	self._heal_offset_mod = 0.5

	self._onpromptremoved = function() self.prompt = nil end
	self._onprompttargetremoved = function(target) self:HidePrompt(target) end

	self._onplayerentered = function(source, player) self:_AttachPlayerToHud(player) end
	self.inst:ListenForEvent("player_fully_constructed", self._onplayerentered, TheDungeon)
	self._onplayerexited = function(source, player) self:_DetachPlayerFromHud(player) end
	self.inst:ListenForEvent("playerexited", self._onplayerexited, TheWorld)
	-- TODO(roomtravel): Listen to playerexited on TheDungeon.

	-- Uncomment these to hide the hud.
	--~ self:Hide()
	--~ self.Show = function() end
end)

function PlayerHud:ShowChatHistory()
	local history = TheDungeon.components.chathistory:GetHistory()

	local str = table.concat( history, "\n" )
	self.chat_history_label:SetText(str)

	self.chat_history_label:Show()
	self.chat_history_label:AlphaTo(1,0)
end

function PlayerHud:RefreshChat()
	local CHAT_SHOW_TIME = 7

	if TheWorld:IsSafeFromCombat() then
		CHAT_SHOW_TIME = CHAT_SHOW_TIME * 2
	end

	self:ShowChatHistory()

	--hide the chat after CHAT_SHOW_TIME seconds
	if self.chat_fade_timer then
		self.chat_fade_timer:Cancel()
	end
	self.chat_fade_timer = self.inst:DoTaskInTime(CHAT_SHOW_TIME, function()
		self.chat_history_label:AlphaTo(0, 0.25)
	end)
end

function PlayerHud:OnRemoveFromEntity()
	for _,player in ipairs(AllPlayers) do
		self.inst:RemoveEventCallback("lowhealthstatechanged", self._onlowhealthstate, player)
	end
	self.inst:RemoveEventCallback("travelpreview_start", self._ontravelpreview_start)
	self.inst:RemoveEventCallback("travelpreview_stop", self._ontravelpreview_stop)
	self.inst:RemoveEventCallback("playerexited", self._onplayerexited, TheWorld)
	self.inst:RemoveEventCallback("playerentered", self._onplayerentered, TheWorld)
end

function PlayerHud:OnRemoveEntity()
	self:OnRemoveFromEntity()
	-- We sometimes get errors on death because widgets in the player hud are
	-- no longer valid. Barf an error earlier to catch why.
	error("Why are we removing the player hud?")
end

--- Invoke this when a game world element changes depth. The game world elements need to be resorted so that they
--- render in the correct order.
function PlayerHud:UpdateGameWorld()
	-- Use the updater to do the sort with the hope that we will bundle multiple updates into a single sort.
	self.game_world:StartUpdating()
end

function PlayerHud:AddWorldWidget(widget)
	self.game_world:AddChild(widget)
	self:UpdateGameWorld()
	return widget
end

function PlayerHud:AddFullScreenEffect(widget)
	return self.under_root:AddChild(widget)
end

function PlayerHud:AddElement(widget)
	return self.root:AddChild(widget)
end

function PlayerHud:OverlayElement(widget)
	return self.over_root:AddChild(widget)
end

function PlayerHud:_AttachPlayerToHud(player)
	player.follow_ui         = self:OverlayElement(Widget("follow_ui"))
	player.follow_health_bar = player.follow_ui:AddChild(PlayerFollowHealthBar(player))
	player.follow_status     = player.follow_ui:AddChild(PlayerFollowStatus(player))
	player.emote_ring     	 = player.follow_ui:AddChild(PlayerEmoteRing(player))
	player.hitcounter        = player.follow_ui:AddChild(HitCounter(player))
	player.loadout_ui 		 = player.follow_ui:AddChild(LoadoutWidget(player))

	-- need to invalidate widget reference when it is removed by other means, such as TheFrontEnd:ClearScreens()
	self.inst:ListenForEvent("onremove", function()
		self:_ClearPlayerFollowReferences(player)
	end, player.follow_ui.inst)

	self.inst:ListenForEvent("lowhealthstatechanged", self._onlowhealthstate, player)
	-- We may have missed the event.
	self:OnLowHealthStateChanged(player, player.components.health:IsLow())
	self.location_hud:AttachPlayerToHud(player)
	self:_LayoutChat()
	return self
end

function PlayerHud:_ClearPlayerFollowReferences(player)
	player.follow_ui = nil
	-- Code is explicitly checking for these. Check for follow_ui instead.
	player.follow_health_bar = nil
	player.follow_status = nil
	player.emote_ring = nil
	player.hitcounter = nil
	player.loadout_ui = nil
end

function PlayerHud:_DetachPlayerFromHud(player)
	if not player.follow_health_bar then
		return
	end

	self.location_hud:DetachPlayerFromHud(player)

	if player.follow_ui then
		player.follow_ui:Remove()
	end
	self:_ClearPlayerFollowReferences(player)

	self:OnLowHealthStateChanged(player, false)
	self.inst:RemoveEventCallback("lowhealthstatechanged", self._onlowhealthstate, player)

	self:_LayoutChat()
end

function PlayerHud:_LayoutChat()
	local has_p3_hud = not TheDungeon:IsInTown() and lume.match(AllPlayers, function(p)
		return p:GetHunterId() == 3
	end)
	if has_p3_hud then
		self.chat_history_label
			:SetPosition(405, 430) -- above p3's hud
	else
		self.chat_history_label
			:SetPosition(405, 205)
	end
	-- Must set again to ensure future text changes have correct registration.
	self.chat_history_label:SetRegistration("left", "bottom")
end

function PlayerHud:OnLowHealthStateChanged(player, is_low_health)
	if not player:IsLocal() then
		return
	end

	-- Effect that applies to all local players.
	self.low_health_players[player] = is_low_health or nil -- nil to remove when not lowhealth
	local are_any_low = not not next(self.low_health_players)
	self.effects.low_health:SetLooping(are_any_low)

	-- Effect that applies to individual player.
	local lifetime_drinks = player.components.progresstracker:GetValue("total_potion_drinks") or 0
	if is_low_health and lifetime_drinks <= 3 and player.components.potiondrinker:CanDrinkPotion() then
		self:TutorialPopup(STRINGS.UI.TUTORIAL_POPUPS.DRINK_POTION, player)
	end
end

function PlayerHud:StartDungeonTravelPreview(cardinal)
	if self.travel then
		return
	end

	self.travel = TravelScreen(cardinal)
	TheFrontEnd:PushScreen(self.travel)
end

function PlayerHud:StopDungeonTravelPreview()
	if self.travel then
		assert(TheFrontEnd:GetActiveScreen() == self.travel, "Changed screens while travelling?")
		self.travel:TryCancelTravel(function()
			self.travel = nil
		end)
	end
end

function PlayerHud:IsPreviewingTravel()
	return self.travel ~= nil
end

local function dbg_start_level(roomtype)
	if TheWorld.components.propmanager:IsDirty() then
		local popup = ConfirmDialog()
			:SetTitle("Unsaved editor changes!")
			:SetText("You have unsaved changes to this level. Some props were modified.")
			:HideArrow()
			:HideYesButton()
			:HideNoButton()
			:CenterButtons()
			:SetCancelButton(STRINGS.UI.BUTTONS.CANCEL, function()
				TheFrontEnd:PopScreen()
			end)
		TheFrontEnd:PushScreen(popup)
		return
	end
	TheDungeon:GetDungeonMap():Debug_StartArena(TheWorld.prefab, {
			roomtype = roomtype,
		})
end

function PlayerHud:_AddGlobalDebugButtons()
	self.debug_btns:AddChild(templates.Button("Toggle Imgui"))
		:SetDebug()
		:SetOnClickFn(function()
			TheFrontEnd:ToggleImgui()
		end)
	self.debug_btns:AddChild(templates.Button("Prefab Spawner"))
		:SetDebug()
		:SetOnClickFn(function()
			DebugNodes.ShowDebugPanel(DebugNodes.DebugPrefabs, true)
		end)
end

function PlayerHud:_AddDungeonDebugButtons()
	-- Use EditableEditor for more options.
	local debug_rooms = {
		{
			label = "Play Empty",
			roomtype = 'empty',
		},
		{
			prefab_pattern = "_boss_",
			label = "Fight Boss",
			roomtype = 'boss',
		},
		{
			prefab_pattern = "_arena_",
			label = "Fight Monsters",
			roomtype = 'monster',
		},
		{
			prefab_pattern = "_mat_",
			label = "Play with Resources",
			roomtype = 'resource',
		},
		{
			prefab_pattern = "_small_",
			label = "Play with Chef",
			roomtype = 'food',
		},
		{
			prefab_pattern = "_small_",
			label = "Play with Potion",
			roomtype = 'potion',
		},
		{
			prefab_pattern = "_small_",
			label = "Play with Upgrader",
			roomtype = 'powerupgrade',
		},
	}
	for _,b in ipairs(debug_rooms) do
		if not b.prefab_pattern
			or TheWorld.prefab:match(b.prefab_pattern)
		then
			self.debug_btns:AddChild(templates.Button(b.label))
				:SetDebug()
				:SetOnClickFn(lume.fn(dbg_start_level, b.roomtype))
		end
	end

	self.debug_btns:LayoutChildrenInGrid(1, 6)
		:LayoutBounds("center", "below", self.debug_btns.toggle_btn)
		:Offset(0, -5)
		:Hide()
end

function PlayerHud:OnBecomeActive()
	PlayerHud._base.OnBecomeActive(self)
	if self.townHud then
		self.townHud:OnBecomeActive()
	end
end

function PlayerHud:IsAnimatedIn()
	return self.is_animated_in
end

function PlayerHud:AnimateIn()
	self.is_animated_in = true
	for _,w in ipairs(self.animated) do
		w:AnimateIn()
	end

	return self
end

function PlayerHud:AnimateOut()
	self.is_animated_in = nil
	for _,w in ipairs(self.animated) do
		w:AnimateOut()
	end
	
	return self
end

-- Probably only for debug.
function PlayerHud:CancelDefeatedFlow()
	if self.is_showing_defeat then
		self.is_showing_defeat = false
		TheFrontEnd:PopScreen()
	end
end

function PlayerHud:DoDefeatedFlow(run_data)
	if self.is_showing_defeat then
		return
	end
	-- Do not delay here! We need the screen to appear immediately to take
	-- control away from players so they can't travel/pause/etc. Instead,
	-- delays in RunSummaryScreen:AnimateIn()

	-- Pop off other screens (pause, console)
	TheFrontEnd:PopScreensAbove(self)

	self.is_showing_defeat = true

	local accolades_screen = HuntAccoladesScreen()

	accolades_screen:SetCloseCallback(function()
		local you_died_screen = RunSummaryScreen(run_data)
		TheFrontEnd:PushScreen(you_died_screen)
	end)

	TheFrontEnd:PushScreen(accolades_screen)
end

function PlayerHud:DoVictoryFlow()
	self.victory_button:Hide()
	-- Pop off other screens (pause, console)
	TheFrontEnd:PopScreensAbove(self)
	self.is_showing_defeat = true
	local victory_screen = RunSummaryScreen(self.run_data)
	TheFrontEnd:PushScreen(victory_screen)
end

function PlayerHud:ShowVictoryButton(run_data)
	-- Set text this late so it can grab the latest button glyph.
	self.victory_button:SetTextAndResizeToFit(STRINGS.UI.HUD.VICTORY.BUTTON)
		:Show()
		:ScalePulseSingle(1.2, 0.2, easing.cubicinout)
	self.run_data = run_data
end

function PlayerHud:ShowTitleCard(titlekey)
	if self.titlecard then
		TheLog.ch.FrontEnd:printf("Interrupted title card '%s' to show '%s'.", self.titlecard.titlekey, titlekey)
		self.titlecard:Remove()
	end
	self.titlecard = self:OverlayElement(TitleCard(titlekey))
		:LayoutBounds("right", "bottom", self.over_root)
		:Offset(0, 228 * HACK_FOR_4K)
		:AnimateIn()
end

function PlayerHud:HideTitleCard()
	if not self.titlecard then
		TheLog.ch.FrontEnd:print("Trying to hide title card but it doesn't exist.")
		return
	end
	self.titlecard:FadeAndRemove()
	self.titlecard = nil
end

-- Is the hud stealing input? False means player should be getting input.
function PlayerHud:IsHudSinkingInput()
	--We're checking that the active screen is NOT us, because HUD
	--is always active, and we're saying that it locks input focus
	--when anything else is active on top of it and consuming input.
	local active_screen, has_console = TheFrontEnd:GetInputSinkScreenUnderConsole()
	if active_screen ~= self then
		return true, "screen"
	elseif self.prompt ~= nil and self.prompt.IsModal ~= nil and self.prompt:IsModal() then
		return true, "prompt"
	elseif self.chat_text_edit and self.chat_text_edit:IsShown() then
		return true, "chat"
	elseif has_console then
		return true, "console"
	elseif TheInput:IsEditMode() then
		--Check if prop editor controls are being used
		if TheInput:IsKeyDown(InputConstants.Keys.ALT) then
			return true, "propedit"
		end
		local prop = TheInput:GetWorldEntityUnderMouse()
		if prop ~= nil and prop.components.prop ~= nil and prop.components.prop:IsDragging() then
			return true, "propedit"
		end
	end
	return false
end

function PlayerHud:MakeControllerSwitchPopup(playerID, device, device_id)

	local title = STRINGS.UI.PRESSED_START_IN_SINGLE_PLAYER.TITLE:subfmt({
			device_icon = TheInput:GetLabelForDevice(device, device_id),
		})
	local subtitle = STRINGS.UI.PRESSED_START_IN_SINGLE_PLAYER.SUBTITLE

	local ChangeInputDialog = require("screens/dialogs/changeinputdialog")
	local dialog = ChangeInputDialog(title, subtitle)

	-- so only this device (and, currently, mouse) can control this popup
	dialog:SetOwningDevice(device, device_id)

	dialog:SetOnAddPlayerClickFn(function()
		net_addplayer(TheInput:ConvertToInputID(device, device_id))
		dialog:OnClickClose()
	end)

	dialog:SetOnChangeInputClickFn(function()
		net_modifyplayer(playerID, TheInput:ConvertToInputID(device, device_id))
		dialog:OnClickClose()
	end)

	TheFrontEnd:PushScreen(dialog)
	return dialog
end

local function PushScreenIfNoExist(screen_class)
	local screen = TheFrontEnd:FindScreen(screen_class)
	if not screen then
		screen = screen_class()
		TheFrontEnd:PushScreen(screen)
	end
	return screen
end

function PlayerHud:ShowGamepadDisconnectedPopup(player)
	-- Open pause to pause the game. We could only do if pauseable, but the
	-- players screen blocks input and obscures gameplay anyway.
	local screen = PushScreenIfNoExist(PauseScreen)
	screen = PushScreenIfNoExist(PlayersScreen)
	TheFrontEnd:MoveScreenToFront(screen)
	return screen
end

function PlayerHud:OnControl(controls, down, device, trace, device_id)
	if self.travel
		or not TheWorld -- Ignore inputs during load.
	then
		return
	end

	if PlayerHud._base.OnControl(self, controls, down, device, trace, device_id) then
		return true
	elseif not self.shown then
		return false
	elseif not down then
		if controls:Has(Controls.Digital.NON_MODAL_CLICK) then
			if self.victory_button and self.victory_button:IsVisible() then
				self.victory_button:Click()
				return true
			end
		end

		if controls:Has(Controls.Digital.ACTIVATE_INPUT_DEVICE) then
			local inputID = TheInput:ConvertToInputID(device, device_id);
			local playerID = TheNet:FindPlayerIDForLocalInputID(inputID);

			if not playerID then -- there isn't a player assigned to this inputID
				local players = TheNet:GetLocalPlayerList() or table.empty
				if #players == 1 then
					playerID = players[1]

					-- See what P1 wants to do: start multiplayer or switch to that device?
					self:MakeControllerSwitchPopup(playerID, device, device_id)
				else
					-- If there are already multiple players, just add a new player
					net_addplayer(TheInput:ConvertToInputID(device, device_id))
				end
				return true
			end
		end

		local player = TheInput:GetDeviceOwner(device, device_id)

		if playerutil.IsAnyPlayerAlive() and controls:Has(Controls.Digital.PAUSE) then
			if player then
				local pausescreen = PauseScreen(player)
				TheFrontEnd:PushScreen(pausescreen)
				return true
			end
		end

		if controls:Has(Controls.Digital.TOGGLE_SAY) then
			if player then
				-- Player won't receive up events while screen is active.
				player.components.playercontroller:ClearControlQueue()
			end
			self:ShowChatHistory()

			self.chat_text_edit
				:Show()
				:SetString("")
				:SetEditing(true)
			return true
		end

		if TheDungeon:IsInTown() then
			if player and controls:Has(Controls.Digital.OPEN_INVENTORY) then
				self.townHud:OnInventoryButtonClicked(player)
				return true
			end
			if controls:Has(Controls.Digital.OPEN_CRAFTING) then
				if self.townHud then
					self.townHud:OnCraftButtonClicked()
					return true
				end
			end
		end
	end
	return false
end

function PlayerHud:IsCraftMenuOpen()
	return self.townHud and self.townHud:IsCraftMenuOpen()
end

function PlayerHud:OnFocusMove(dir, down)
	-- Ignore focus movement unless we have active widgets.
	if self.prompt and self.prompt.enabled and self.prompt.shown then

		-- The modal check makes it so this focusmove call only happens after the player
		-- entered the conversation. Not while walking around, so the speech balloon doesn't nudge
		if self.prompt.IsModal and self.prompt:IsModal() == false then
			return
		end

		self.prompt:OnFocusMove(dir, down)
	end
end

function PlayerHud:GetControlMap()
	if self.townHud then
		return self.townHud:GetControlMap()
	end
end

-- Button will not be triggerable by gamepad. Use
-- interactable:SetupForButtonPrompt() for player interactions.
function PlayerHud:ShowPrompt(target, player)
	if self.prompt ~= nil then
		self.prompt:Remove()
	end

	self.prompt = self:AddWorldWidget(FollowButton(player))
	self.prompt.inst:ListenForEvent("onremove", self._onpromptremoved)
	self.prompt.inst:ListenForEvent("onremove", self._onprompttargetremoved, target)
	return self.prompt:SetTarget(target)
end

function PlayerHud:ShowLabelPrompt(target, player)
	if self.prompt ~= nil then
		self.prompt:Remove()
	end

	self.prompt = self:AddWorldWidget(FollowLabel(player))
	self.prompt.inst:ListenForEvent("onremove", self._onpromptremoved)
	self.prompt.inst:ListenForEvent("onremove", self._onprompttargetremoved, target)
	return self.prompt:SetTarget(target)
end

function PlayerHud:ShowNpcPrompt(target, player)
	if self.prompt ~= nil then
		self.prompt:Remove()
	end

	self.prompt = self:AddWorldWidget(NpcPrompt(player, target))
	self.prompt.inst:ListenForEvent("onremove", self._onpromptremoved)
	self.prompt.inst:ListenForEvent("onremove", self._onprompttargetremoved, target)
	return self.prompt:SetTarget(target)
end

function PlayerHud:HidePrompt(target)
	if self.prompt ~= nil and self.prompt:GetTarget() == target then
		self.prompt:Remove()
		self.prompt = nil
	end
end

function PlayerHud:GetPromptTarget()
	return self.prompt ~= nil and self.prompt:GetTarget() or nil
end

local UseNetworkDamageNumbers = true

function PlayerHud:_ShouldShowDamageNumber(attack)
	local target = attack:GetTarget()
	if not target:IsValid() or
		not attack:ShowDamageNumber() or
		not target:IsAlive() and attack:GetHeal() == nil -- Do not show non-heal damagenumbers if they are dead.
		then
		return false
	end

	if TheNet:IsGameTypeLocal() then
		return true
	end
	-- TODO: gameplay option test

	-- TODO: networking2022, resolve "neutral" party damage numbers (i.e. a bomb damaging a destructible)
	local attacker = attack:GetAttacker()
	local target = attack:GetTarget()
	if UseNetworkDamageNumbers then
		if target:IsLocalOrMinimal() then
			return true
		end
	else
		if attacker:IsLocal() and attacker:HasTag("player") then
			return true
		elseif target:IsLocal() and target:HasTag("player") then
			return true
		elseif attacker:IsMinimal() or target:IsMinimal() then -- i.e. attacker: floor traps
			return true
		elseif target:HasTag("prop_destructible") then -- special case because these are non-transferable
			return true
		end
	end

	return false
end

function PlayerHud:MakeDamageNumber(attack)
	if UseNetworkDamageNumbers then
		self:MakeDamageNumberNet(attack)
	else
		self:MakeDamageNumberOld(attack)
	end
end

function PlayerHud:MakeDamageNumberNet(attack)
	if not self:_ShouldShowDamageNumber(attack) then
		return
	end

	local value = attack:GetDamage() or attack:GetHeal()
	local target = attack:GetTarget()
	local num_sources = attack:GetNumInChain()

	local active_numbers = 1
	local attacker = attack:GetAttacker()
	if attacker and attacker:IsLocalOrMinimal() then
		active_numbers = attacker.components.combat:GetDamageNumbersCount() + 1
	end
	local is_focus = attack:GetFocus()
	local is_crit = attack:GetCrit()
	local is_heal = attack:GetHeal() ~= nil
	local is_player = target:HasTag("player")
	local is_secondary_attack = not attack:SourceIsAttacker() and not attack:GetProjectile()
	local playerID = attacker.Network and attacker.Network:GetPlayerID() or nil

	local num_widget
	if target:IsLocal() and not target:IsMinimal() then -- don't propagate numbers for minimal entities
		local entGUID = TheNetEvent:DamageNumber(target.GUID, value, num_sources, active_numbers, is_focus, is_crit, is_heal, is_player, is_secondary_attack, playerID)
		local ent = Ents[entGUID]
		if ent then
			num_widget = ent.widget
		end
	else
		num_widget = self:HandleDamageNumber(target, value, num_sources, active_numbers, is_focus, is_crit, is_heal, is_player, is_secondary_attack, playerID)
	end

	if num_widget and attacker and attacker:IsLocalOrMinimal() then
		num_widget:SetAttacker(attacker)
		attacker.components.combat:AddDamageNumber(num_widget)
	end
end

function PlayerHud:HandleDamageNumber(target, value, num_sources, active_numbers, is_focus, is_crit, is_heal, is_player, is_secondary_attack, playerID)
	local offset_mod
	if is_heal then
		self._heal_offset_mod = self._heal_offset_mod * -1
		offset_mod = self._heal_offset_mod
	else
		self._damage_offset_mod = self._damage_offset_mod * -1
		offset_mod = self._damage_offset_mod
	end

	local num = self:AddWorldWidget(DamageNumber())

	num:InitNew(target, value, offset_mod, num_sources, active_numbers, is_focus, is_crit, is_heal, is_player, is_secondary_attack, playerID)
	return num
end

function PlayerHud:MakeDamageNumberOld(attack)
	if not self:_ShouldShowDamageNumber(attack) then
		return
	end

	local num = self:AddWorldWidget(DamageNumber())

	local dmg_data = {
		attack = attack,
		x_offset_mod = attack:GetHeal() and self._heal_offset_mod or self._damage_offset_mod
	}

	if attack:GetTarget():HasTag("player") then
		dmg_data.is_player = true
	end

	if attack:GetHeal() then
		self._heal_offset_mod = self._heal_offset_mod * -1
	else
		self._damage_offset_mod = self._damage_offset_mod * -1
	end

	num:InitOld(dmg_data)
end

function PlayerHud:StartCookingTrack(data)
	local track = self:OverlayElement(CookingButtonTrack(data))
	track:Init(data)
	return track
end

function PlayerHud:StopCookingTrack(track)
	track:StopTrack()
end

function PlayerHud:MakeCookingButton(data)
	local btn = self:OverlayElement(CookingButton())

	btn:Init(data)
end

function PlayerHud:MakePopText(data)
	local txt = self:OverlayElement(PopText())

	txt:Init(data)
end

function PlayerHud:MakePopPower(data)
	local pow = self:OverlayElement(PopPower())

	pow:Init(data)
end

function PlayerHud:MakePopPowerDisplay(data)
	local pow = self:OverlayElement(PopPowerDisplay())

	pow:Init(data)
end

function PlayerHud:MakePopGem(data)
	local gem = self:OverlayElement(PopGem())

	gem:Init(data)
end

-- Mastery Progress Widget Stuff --

function PlayerHud:MakePopMasteryProgress(data, mst)
	if self.pop_mastery_progress_widgets[mst] then

		if self.active_mastery_popup == self.pop_mastery_progress_widgets[mst] then
			self.pop_mastery_progress_widgets[mst]:Refresh(data)
		else
			-- update the data in the queue
			for _, queue_data in ipairs(self.mastery_popup_queue) do
				if queue_data.mst == mst then
					queue_data.data = data
				end
			end
		end
	else
		local progress = self:OverlayElement(PopMasteryProgress())
		self.pop_mastery_progress_widgets[mst] = progress
		self.inst:ListenForEvent("onremove", function() 
			self.pop_mastery_progress_widgets[mst] = nil
			self.active_mastery_popup = nil
			self:TryNextPopMasteryProgress()
		end, progress.inst)
		self:QueuePopMasteryProgress(progress, data, mst)
	end
end

function PlayerHud:QueuePopMasteryProgress(widget, data, mst)
	table.insert(self.mastery_popup_queue, { widget = widget, data = data, mst = mst })

	if not self.active_mastery_popup then
		self:TryNextPopMasteryProgress()
	end
end

function PlayerHud:TryNextPopMasteryProgress()
	if #self.mastery_popup_queue == 0 then return end

	local popup = self.mastery_popup_queue[1]
	self.active_mastery_popup = popup.widget
	popup.widget:Init(popup.data)
	table.remove(self.mastery_popup_queue, 1)
end

-- --

function PlayerHud:MakeReviveTimerText(reviver, dead_player)
	local txt = self:AddWorldWidget(FollowRevive(reviver))
	return txt:SetTarget(dead_player)
end

function PlayerHud:MakePowerPopup(data)
	local powerpopup = self:AddWorldWidget(FollowPower())
	powerpopup:Init(data)
	return powerpopup
end

function PlayerHud:MakeFollowGem(data)
	local gempopup = self:AddWorldWidget(FollowGem())
	gempopup:Init(data)

	return gempopup
end

function PlayerHud:TutorialPopup(string, target)
	local popup = self:MakePopText({ target = target, button = string, color = UICOLORS.WHITE, size = FONTSIZE.BUTTON, fade_time = 5, y_offset = 150 * HACK_FOR_4K })

	return popup
end

return PlayerHud
