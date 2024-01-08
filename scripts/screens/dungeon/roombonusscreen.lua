local ActionButton = require("widgets/actionbutton")
local Image = require("widgets/image")
local PlayerPuppet = require "widgets.playerpuppet"
local PlayerStatStack = require("widgets/ftf/playerstatstack")
local PlayerTitleWidget = require("widgets/ftf/playertitlewidget")
local PlayerUnitFrames = require("widgets/ftf/playerunitframes")
local PlayerUsernameWidget = require("widgets/ftf/playerusernamewidget")
local RoomBonusButton = require("widgets/ftf/roombonusbutton")
local RoomBonusKonjurRings = require("widgets/ftf/roombonuskonjurrings")
local Screen = require("widgets/screen")
local SkillIconWidget = require("widgets/skilliconwidget")
local TallyMarks = require "widgets.ftf.tallymarks"
local Text = require("widgets/text")
local Widget = require("widgets/widget")
local Power = require "defs.powers"
local fmodtable = require "defs.sound.fmodtable"
local soundutil = require "util.soundutil"
local Equipment = require "defs.equipment"
local Consumable = require("defs.consumable")
local easing = require "util.easing"
local kassert = require "util.kassert"
local krandom = require "util.krandom"
local lume = require "util.lume"


------------------------------------------------------------------------------------------
--- A title widget for the screen
----
local RoomBonusTitleWidget = Class(Widget, function(self)
	Widget._ctor(self, "RoomBonusTitleWidget")

	self.ornamentPadding = 6
	self.ornamentScale = 0.5
	self.ornamentLeft = self:AddChild(Image("images/ui_ftf_relic_selection/titleornament.tex"))
		:SetScale(self.ornamentScale)
	self.ornamentRight = self:AddChild(Image("images/ui_ftf_relic_selection/titleornament.tex"))
		:SetScale(-self.ornamentScale, self.ornamentScale)

	self.textContent = self:AddChild(Widget())
	self.title = self.textContent:AddChild(Text(FONTFACE.DEFAULT, FONTSIZE.ROOMBONUS_SCREEN_TITLE, "", HexToRGB(0x967D71FF)))

end)

function RoomBonusTitleWidget:SetTitle(title)
	self.title:SetText(title)

	local w, h = self.title:GetSize()
	w = math.max(w, 200) + 130
	h = h + 60


	self.ornamentLeft:LayoutBounds("before", nil, self.title)
		:Offset(-self.ornamentPadding, -2)
	self.ornamentRight:LayoutBounds("right", nil, self.title)
		:Offset(self.ornamentPadding, -2)
	return self
end
------------------------------------------------------------------------------------------

local SelectingPlayerWidget = Class(Widget, function(self)
	Widget._ctor(self, "SelectingPlayerWidget")

	local mask_sz = 400
	self.mask = self:AddChild(Image("images/white.tex"))
		:SetHiddenBoundingBox(true)
		:SetMask()
		:SetSize(mask_sz * 4, mask_sz)
		:Offset(0, mask_sz/2)
		:SetRotation(1.3) -- match tilt of dialog bg

	-- Parent for animating parts so mask doesn't move.
	self.rescalable = self:AddChild(Widget("rescalable"))

	local puppet_w = 360
	self.portrait = self.rescalable:AddChild(PlayerPuppet())
		:SetScale(.6)
		:SetFacing(FACING_RIGHT)
		:SetMasked()
		:Offset(-puppet_w/4, -97)

	-- Just for the bounding box so we can CenterChildren.
	self.puppet_size = self.portrait:AddChild(Image("images/white.tex"))
		:SetMultColorAlpha(0)
		:SetSize(puppet_w, 64)
		:Offset(-10, 0)

	-- Positioned when we set the player because it's relative to puppet.
	self.text_root = self.rescalable:AddChild(Widget())

	local main_font_size = FONTSIZE.ROOMBONUS_PLAYER
	self.playername = self.text_root:AddChild(PlayerUsernameWidget())
		:FillWithPlaceholder()
		:SetFontSize(main_font_size)

	-- TODO(UI): Make a PlayerNameTitle widget that contains both.
	self.title = self.text_root:AddChild(PlayerTitleWidget())
		:FillWithPlaceholder()
		:SetFontSize(main_font_size * 0.9)
		:LayoutBounds("left", "below", self.playername)
end)

function SelectingPlayerWidget:SetPlayer(player, islocal)
	if player == self.player then
		return
	end

	self.player = player
	self.portrait:CloneCharacterWithEquipment(player)
	self.playername:SetOwner(player)
	self.title:SetOwner(player)
		:LayoutBounds("left", "below", self.playername)

	self.text_root
		:LayoutBounds("after", "bottom", self.portrait)
		:Offset(0, 110)

	if islocal then
		player.components.playercontroller:TryPlayRumble_IdentifyPlayer()
		self:GrabAttention(3.5)
		--play an obnoxious sound that says "hey it's your turn!"
		--only do it when it's a remote game though
		if not TheNet:IsGameTypeLocal() then
			self:PlaySpatialSound(fmodtable.Event.ui_roomBonusScreen_playerTurnNotification, { faction_player_id = player:GetHunterId()})
		end

		--play a gentle sound that comes with moving through these screens
		TheFrontEnd:GetSound():PlaySoundWithParams(fmodtable.Event.ui_roomBonusScreen_panel_show, { faction_player_id = player:GetHunterId() })
		--TheFrontEnd:GetSound():PlaySoundWithParams(fmodtable.Event.ui_roomBonusScreen_playerNumberTone, { faction_player_id = player:GetHunterId() })
	end

	return self
end

function SelectingPlayerWidget:GrabAttention(duration)
	if self.is_animating then
		return
	end

	self.is_animating = true

	self.rescalable:ScaleTo(1, 1.4, duration * 0.05, easing.inOutQuad, function()
		self.rescalable:ScaleTo(1.4, 1, duration * 0.2, easing.inBack)
	end)

	local x, y = self.rescalable:GetPos()
	self.rescalable:MoveTo(x, y + 55, duration * 0.2, easing.inOutQuad, function()
		self.rescalable:MoveTo(x, y, duration * 0.8, easing.outElastic, function()
			self.is_animating = nil
		end)
	end)
end

------------------------------------------------------------------------------------------
--- Display the amulets the players can choose from for clearing a room.
local RoomBonusScreen = Class(Screen, function(self, power_type)
	Screen._ctor(self, "RoomBonusScreen")
	self:SetAudioCategory(Screen.AudioCategory.s.PartialOverlay)
	self:SetAudioEnterOverride(nil)
	self:SetAudioExitOverride(nil)

	local is_skill_drop <const> = power_type == Power.Types.SKILL

	-- hack - player status on screen
	if TheDungeon.HUD and TheDungeon.HUD.player_unit_frames then
		TheDungeon.HUD.player_unit_frames:Hide()
	end

	self.displayed_drops = nil
	self.displayed_current_skill = {}

	local total_konjur_on_skip = 0
	self.power_type = power_type
	if power_type == Power.Types.RELIC then
		self.gamemode = GAMEMODE_RELICSELECT
		total_konjur_on_skip = TUNING.KONJUR_ON_SKIP_POWER
	elseif power_type == Power.Types.SKILL then
		self.gamemode = GAMEMODE_SKILLSELECT
		total_konjur_on_skip = TUNING.KONJUR_ON_SKIP_SKILL
	elseif power_type == Power.Types.FABLED_RELIC then
		self.gamemode = GAMEMODE_POWERFABLEDSELECT
		total_konjur_on_skip = TUNING.KONJUR_ON_SKIP_POWER_FABLED
	else
		self.gamemode = nil
		kassert.assert_fmt(false, "Power_type unrecognized: %s", power_type)
	end

	TheWorld:UnlockFlag("wf_seen_room_bonus")

	print("roombonusscreen power type: " .. self.power_type)

	self.num_powers = 2 -- num_choices

	local allplayers = TheNet:GetSelectingPlayerIDs()
	--dumptable(allplayers)
	self.konjur_on_skip = total_konjur_on_skip
	self.playerchoices = {}

	local first_player
	for i,player_nid in ipairs(allplayers) do
		local player = self:_FindEntityForNetId(player_nid)
		if player and player:IsLocal() then
			first_player = first_player or player
			-- Force the player into the "interact" state:
			player:PushEvent("roombonusscreen_opened")
		end
	end
	self:SetOwningPlayer(first_player)


	self.lockoutselection = false

	self.bg = self:AddChild(Image("images/ui_ftf_roombonus/background_gradient.tex"))
		:SetAnchors("fill", "fill")
		:Hide()

	self.screenContainer = self:AddChild(Widget())

	self.panel = self.screenContainer:AddChild(Image("images/bg_selectpower/selectpower.tex"))
		:LayoutBounds("center", "center", self.bg)

	-- Screen Title
	self.title = self.screenContainer:AddChild(RoomBonusTitleWidget())
		:SetTitle(is_skill_drop and STRINGS.UI.ROOMBONUSSCREEN.TITLE_SKILL or STRINGS.UI.ROOMBONUSSCREEN.TITLE)
		:LayoutBounds("center", "top", self.bg)
		:Offset(17 * HACK_FOR_4K, -302 * HACK_FOR_4K)

	-- Contains the clickable powers
	self.buttonContainer = self.screenContainer:AddChild(Widget("Button Container"))

	-- hack - player status on screen
	self.player_unit_frames = self:AddChild(PlayerUnitFrames())

	-- Player's stats
	self.statStack = self.screenContainer:AddChild(PlayerStatStack()) -- doesn't matter who, we'll replace later.
		:LayoutBounds("center", "bottom", self.bg)
		:Offset(0, 470)

	-- separate root so we can centre on this position.
	self.selecting_player_root = self.screenContainer:AddChild(Widget("selecting_player_root"))
		:LayoutBounds("center", "top", self.panel)
		:Offset(0, -99)
	self.selectingPlayer = self.selecting_player_root:AddChild(SelectingPlayerWidget())

	-- Meant to display what room we're in, within the whole run.
	-- The design isn't finalized
	self.tally = self.screenContainer:AddChild(TallyMarks())
		:SetMultColor(UICOLORS.DARK_TEXT_DARKER)
		:SetToRoomsSeen(TheDungeon:GetDungeonMap().nav)
		:LayoutBounds("left", "bottom", self.panel)
		:Offset(117 * HACK_FOR_4K, 104 * HACK_FOR_4K)
		:SetShown(not is_skill_drop) -- not enough space for tallys and previous skill


	-- Display the player's konjur
	local current_player_nid, islocal = TheNet:GetCurrentSelectingPlayerID()
	local playerent = self:_FindEntityForNetId(current_player_nid)
	local konjur = 0
	if playerent then
		konjur = playerent.components.inventoryhoard:GetStackableCount(Consumable.Items.MATERIALS.konjur)
	end
	self.konjurRings = self.screenContainer:AddChild(RoomBonusKonjurRings(konjur))
		:Offset(1610, -454)
		:SetScissorInsetSides(-50, 24, 0, 133) -- Clip edges to keep within panel, but leave extra left space for skill.

	-- The buttons centered below the panel
	self.nav_buttons = self.screenContainer:AddChild(Widget())
	self.konjur_button = self.nav_buttons:AddChild(ActionButton())
		:SetNavFocusable(false)
		:SetKonjur()
		:SetSize(BUTTON_W*1.1, BUTTON_H)
		:SetScale(0.75)
		:SetNormalScale(0.75)
		:SetFocusScale(0.78)
		:SetText(is_skill_drop and STRINGS.UI.ROOMBONUSSCREEN.SKIP_BUTTON_SKILL or STRINGS.UI.ROOMBONUSSCREEN.SKIP_BUTTON_POWER)
		:SetRightText(string.format(STRINGS.UI.ROOMBONUSSCREEN.SKIP_BUTTON_KONJUR, self.konjur_on_skip))
		:SetOnClick(function() self:_OnClickSkip() end)
	self.continue_button = self.nav_buttons:AddChild(ActionButton())
		:SetNavFocusable(false)
		:SetPrimary()
		:SetSize(BUTTON_W*1, BUTTON_H)
		:SetText(is_skill_drop and STRINGS.UI.ROOMBONUSSCREEN.CONTINUE_BUTTON_SKILL or STRINGS.UI.ROOMBONUSSCREEN.CONTINUE_BUTTON_POWER)
		:SetOnClick(function() self:OnClickContinue() end)
		:SetToolTipLayoutFn(function(w, tooltip) tooltip:LayoutBounds("center", "below", w):Offset(0, 10) end)
		:Disable()
	self.continue_button.unselected_tooltip = is_skill_drop and STRINGS.UI.ROOMBONUSSCREEN.CONTINUE_BUTTON_SKILL_TT or STRINGS.UI.ROOMBONUSSCREEN.CONTINUE_BUTTON_POWER_TT
	self.continue_button:SetToolTip(self.continue_button.unselected_tooltip)

	-- A label explaining how to use skills
	-- Shown on the top right
	self.skill_info_root = self.screenContainer:AddChild(Widget("skillInfoPanel_root"))
		:Hide()
	self.skillInfoPanel = self.skill_info_root:AddChild(Image("images/ui_ftf_relic_selection/relic_skillinfo.tex"))
	self.skillInfoText = self.skill_info_root:AddChild(Text(FONTFACE.DEFAULT, 54))
		:SetText(STRINGS.UI.ROOMBONUSSCREEN.SKILL_TIP)
		:SetGlyphColor(HexToRGB(0xF4E1CEFF))
		:LayoutBounds("center", "center", self.skillInfoPanel)
		:Offset(-24, 6)
	self.skill_info_root:LayoutBounds("right", "top", self.panel)
		:Offset(-200, -35)
		:SetShown(is_skill_drop)


	-- Displays the skill you currently have, if any
	self.currentSkillContainer = self.screenContainer:AddChild(Widget())
		:SetName("Current skill container")
		:Hide()
	self.currentSkillIcon = self.currentSkillContainer:AddChild(SkillIconWidget())
		:SetName("Skill icon")
		:SetScale(0.5)
		:SetRotation(-20)
	self.currentSkillText = self.currentSkillContainer:AddChild(Widget())
		:SetName("Text container")
	self.currentSkillName = self.currentSkillText:AddChild(Text(FONTFACE.DEFAULT, FONTSIZE.SCREEN_SUBTITLE))
		:SetName("Skill name")
		:SetGlyphColor(UICOLORS.LIGHT_TEXT_DARKER)
		:LeftAlign()
		:SetAutoSize(800)
	self.currentSkillDesc = self.currentSkillText:AddChild(Text(FONTFACE.DEFAULT, FONTSIZE.SCREEN_TEXT))
		:SetName("Skill description")
		:SetGlyphColor(UICOLORS.LIGHT_TEXT_DARK)
		:LeftAlign()
		:SetAutoSize(800)
	self.currentSkillInfo = self.currentSkillText:AddChild(Text(FONTFACE.DEFAULT, FONTSIZE.SCREEN_TEXT))
		:SetName("Skill info")
		:SetGlyphColor(UICOLORS.LIGHT_TEXT_DARKER)
		:LeftAlign()
		:SetAutoSize(800)
		:SetText(STRINGS.UI.ROOMBONUSSCREEN.CURRENT_SKILL_INFO)


	local dropGUID = TheNet:GetActivePowerDropGUID();	-- Store which powerup spawned this screen, so the host can remove the powerup on exit
	if dropGUID then
		self.activePowerDrop = Ents[dropGUID]
		if self.activePowerDrop then
			print("Active PowerDrop: ".. self.activePowerDrop.prefab .. " (GUID:" .. dropGUID .. ")")
			print("Active PowerDrop Power Category: " .. self.activePowerDrop.components.powerdrop.power_category)
		end
	end


	self.screenContainer:Offset(0, 20 * HACK_FOR_4K) -- Now that the whole thing has been made, adjust it into final position here.

	self:_RefreshNavButtons()

	self:StartUpdating()
end)

-- Run like this:
--	d_screen_getpower(Power.Items.PLAYER.snowball_effect)
--	d_screen_getpower()
function RoomBonusScreen.DebugConstructScreen(cls, player, power_def)
	local power_type = Power.Types.RELIC
	if power_def then
		power_type = power_def.power_type
	end
	local self = RoomBonusScreen(power_type)
	self.exiting = true -- blocks forced update and quick quit behaviour
	self:StopUpdating()

	local player_net_id = player.Network:GetPlayerID()
	local islocal = true
	self:OnNewSelectingPlayer(player_net_id, islocal)
	if power_def then
		local left = self.drops[1]
		left.name = power_def.name
		left.slot = power_def.slot
		left.rarity = Power.GetBaseRarity(power_def)
	end

	local uidata = self:_GatherPlayerUIData(GetDebugPlayer())
	self:_ApplyDataToScreen(islocal, uidata)

	return self
end

RoomBonusScreen.CONTROL_MAP =
{
	{
		control = Controls.Digital.MENU_REJECT,
		fn = function(self)
			self:_OnClickSkip()
			return true
		end,
	}
}

function RoomBonusScreen:OnInputModeChanged(old_device_type, new_device_type)
	-- TODO: The callback is only relevant when our owning player's input mode
	-- changed. However, their GetLastInputDeviceType doesn't update in screens
	-- so we can't rely on it heavily. Just always refresh and handle it there.
	self:_RefreshNavButtons()
end

function RoomBonusScreen:_RefreshNavButtons()

	-- TODO: It would be better to check IsRelativeNavigation and refresh when
	-- the mouse moves, but the screen doesn't have a keyboad binding for skip
	-- (take konjur).
	if self:IsUsingGamepad() then
		self.continue_button:Hide()
	else
		self.continue_button
			:Show()
			:Enable()
			:SetToolTip(self.continue_button.unselected_tooltip)
	end

	-- TODO: Make this kind of refresh specific to the player in control.
	self.konjur_button:RefreshText()
	self.skillInfoText:RefreshText()

	self.continue_button:LayoutBounds("center", "below", self.panel)
		:Offset(0, 75)

	-- Position konjur button
	self.konjur_button:LayoutBounds("center", "below", self.konjurRings)
		:LayoutBounds(nil, "top", self.continue_button)
		:Offset(0, 10)

end

function RoomBonusScreen:_FindEntityForNetId(player_nid)
	local guid = TheNet:FindGUIDForPlayerID(player_nid)
	return guid and Ents[guid] or nil
end


function RoomBonusScreen:SetDefaultFocus()
	if not self.exiting then -- This fixes a crash if a remote player chooses last, and a local player is pressing direction buttons while the screen is closing. If it's closing, don't set any focus.
		-- Interface elements are too dynamic to rely on default_focus.
		if next(self.buttonContainer.children) then
			self.buttonContainer.children[1]:SetFocus()
			return
		end
	end
	self.buttonContainer:SetFocus()
end

function RoomBonusScreen:SetupBonuses(islocal, uidata)
	-- Remove old ones
	self.buttonContainer:RemoveAllChildren()
	self.buttonContainer:SetPosition(0,0)

	-- We may have tinted transparent in _ApplyFinalChoiceToButtons.
	self.konjur_button
		:TintTo(nil, WEBCOLORS.WHITE, 0.5, easing.outExpo)
	self.continue_button
		:TintTo(nil, WEBCOLORS.WHITE, 0.5, easing.outExpo)
	self.currentSkillContainer
		:TintTo(nil, WEBCOLORS.WHITE, 0.2, easing.outQuad)
	self.currentSkillIcon
		:TintTo(nil, WEBCOLORS.WHITE, 0.2, easing.outQuad)

	if uidata and uidata.drops then
		-- Create button widgets
		local num_buttons = lume.count(uidata.drops)
		for id, data in pairs(uidata.drops) do
			local pick = Power.FindPowerByName(data.name)
			local rarity = data.rarity
			local power = TheWorld.components.powerdropmanager:MakePower(pick, rarity)	-- Create the power based on the pick and rarity

			local button_idx = #self.buttonContainer.children + 1

			TheLog.ch.FrontEnd:printf("RoomBonusScreen:SetupBonuses id[%s] power[%s]", id, data.name) -- Ensure later errors have context
			local button = self.buttonContainer:AddChild(RoomBonusButton())
				:SetBonus(power, data.lucky, not data.block_selection)
				:LayoutBounds("center", "center")
				:Offset(655 * HACK_FOR_4K, 0) -- Distance between buttons
				:SetName("RoomBonusButton." .. id)
				:SetControlDownSound(fmodtable.Event.input_down_roomBonusButton)
				:SetControlUpSound(nil)
				:SetGainFocusSound(fmodtable.Event.hover_roomBonusButton)
				-- :AnimateFloating(krandom.Float(0.4, 0.5), krandom.Float(5, 10))
			button:SetOnClick(
				function()
					self:OnBonusClicked(id, power, data.lucky, button)
					if not self.currentSkillIcon.faded then
						self.currentSkillIcon:TintTo(WEBCOLORS.WHITE, UICOLORS.DISABLED, 0.2, easing.outQuad)
						self.currentSkillIcon.faded = true
					end
				end)
				:SetPowerToolTip(id, num_buttons, data.lucky)
				:SetToolTipLayoutFn(function(w, tooltip_widget)
					if num_buttons == 3 then
						-- Show the right tooltip before the widget and the others after
						tooltip_widget:LayoutBounds(button_idx == 3 and "before" or "after", "center", w)
							:Offset(button_idx == 3 and 60 or -60, 0)
					else -- 2 buttons
						-- Show left tooltip before the widget and the right one after the widget
						tooltip_widget:LayoutBounds(button_idx == 1 and "before" or "after", "center", w)
							:Offset(button_idx == 1 and 60 or -60, 0)
					end
				end)
		end

		-- Position buttons
		self.buttonContainer:SetScale(0.95)
			:LayoutBounds("center", "center", self.bg)
			:Offset(0, 90)

		if next(self.buttonContainer.children) then
			TheFrontEnd:HintFocusWidget(self.buttonContainer.children[1])
		end

		self:RunUpdater(self:MakeButtonAnimator())
	end

	-- Sink all input if this is a remote player (so that you can't control any of the ui of a remote player
	self.screenContainer:IgnoreInput(not islocal)

	return self
end

function RoomBonusScreen:_SetButtonPickState(selected_button)
	for _,button in ipairs(self.buttonContainer:GetChildren()) do
		if button ~= selected_button then
			button:SetNotPicked()
		end
	end
	if selected_button then
		selected_button:SetPicked()
	end
end

function RoomBonusScreen:OnBonusClicked(bonusId, power, islucky, bonusButton)
	if self.lockoutselection or self.is_animating then
		TheLog.ch.FrontEnd:print("OnBonusClicked but blocked.")
		return
	end

	self:_SetButtonPickState(bonusButton)

	self.selected_button = bonusButton
	self.continue_button:Enable()
		:SetToolTip(nil)

	-- If this is a controller, triggering a bonus shouldn't require confirming
	if TheFrontEnd:IsRelativeNavigation() then
		self:OnClickContinue()
	end
end

function RoomBonusScreen:_ApplyFinalChoiceToButtons(selected_button)
	for _,button in ipairs(self.buttonContainer:GetChildren()) do
		-- We've already set pick state, so disabling will keep selected power
		-- fully visible.
		button:Disable()
	end
	if selected_button == self.konjur_button then
		-- Fade back to full colour.
		self.currentSkillIcon:TintTo(nil, WEBCOLORS.WHITE, 0.2, easing.outQuad)
	else
		self.konjur_button
			:TintTo(nil, WEBCOLORS.TRANSPARENT_BLACK, 0.5, easing.outExpo)
		-- Tint the whole thing to fade the text too.
		self.currentSkillContainer:TintTo(nil, WEBCOLORS.TRANSPARENT_BLACK, 0.2, easing.outQuad)
	end
	self.continue_button
		:TintTo(nil, WEBCOLORS.TRANSPARENT_BLACK, 0.5, easing.outExpo)
end

function RoomBonusScreen:OnClickContinue()
	if not self.selected_button then
		-- The continue button is enabled if we entered the screen with
		-- gamepad, but if you use the mouse to click it we don't have a
		-- selection yet. Disable to push user to click a button.
		self.continue_button:Disable()
			:SetToolTip(self.continue_button.unselected_tooltip)
		return
	end

	-- Actually activates the player's current choice

	for k,v in ipairs(self.buttonContainer.children) do
		if v == self.selected_button then
			self.confirmed_choice = k -- This is sent with the UIdata for remote players, and is passed through self:UpdateConfirmedChoice() eventually to _ApplyFinalChoiceToButtons()
		end
	end

	self.continue_button:IgnoreInput(true)

	local power = self.selected_button:GetBonus()

	if self.power_type == Power.Types.SKILL then
		self:GetOwningPlayer().components.powermanager:AddEquipmentPowerOverride(Equipment.Slots.WEAPON, { name = power.id, stacks = 1 })
	else
		self:GetOwningPlayer().components.powermanager:AddPower(power) -- TODO: Add skip power Konjur here.
	end

	local current_player_nid, islocal = TheNet:GetCurrentSelectingPlayerID()
	if islocal then
		local playerent = self:_FindEntityForNetId(current_player_nid)
		if playerent then
			self.playerchoices[playerent] = true	-- Picked power
		end
	end

	self:OnPlayerCompleted(islocal)
end

-- Cancel/Skip is the "I want konjur instead" button.
function RoomBonusScreen:_OnClickSkip()
	if self.lockoutselection or self.is_animating then
		TheLog.ch.FrontEnd:print("_OnClickSkip but blocked.")
		return
	end

	self:_SetButtonPickState(nil)
	self:_ApplyFinalChoiceToButtons(self.konjur_button)

	local current_player_nid, islocal = TheNet:GetCurrentSelectingPlayerID()
	if islocal then
		local playerent = self:_FindEntityForNetId(current_player_nid)
		if playerent then
			self.playerchoices[playerent] = false	-- Picked konjur
		end
	end

	self:OnPlayerCompleted(islocal, true)
end

function RoomBonusScreen:OnPlayerCompleted(islocal, picked_konjur)

	self.lockoutselection = true

	-- Disable all buttons:
	for _k, button in ipairs(self.buttonContainer.children) do
		button:SetOnGainFocus(nil)
		button:SetOnLoseFocus(nil)
	end

	-- Signal to the host that we're done, so it can switch to the next player:

	-- Get the result so the host knows when to generate skip-konjur:
	local result = 0
	local current_player_nid, islocal = TheNet:GetCurrentSelectingPlayerID()

	local playerent = self:_FindEntityForNetId(current_player_nid)
	if playerent then
		if self.playerchoices[playerent] == false then 	-- Picked konjur
			result = 1
			local params = {}
			params.fmodevent = fmodtable.Event.input_up_roomBonusButton_pickedKonjur
			local picked_konjur_sound = soundutil.PlaySoundData(playerent, params)
			soundutil.HandleSetInstanceParameter(playerent, picked_konjur_sound, "faction", islocal and 1 or 2)
		else
			local params = {}
			params.fmodevent = fmodtable.Event.input_up_roomBonusButton_pickedPower
			local picked_konjur_sound = soundutil.PlaySoundData(playerent, params)
			soundutil.HandleSetInstanceParameter(playerent, picked_konjur_sound, "faction", islocal and 1 or 2)
		end
	end

	--TODO: someone - transition presentation
	self.inst:DoTaskInTime(0.75, function()
		TheNet:SetPlayerDone(self.active_player_nid, result)
	end)
end

function RoomBonusScreen:Exit()
	if not self.exiting then	-- self:StopUpdating() somehow doesn't stops OnUpdate from being called (?!)
		self.exiting = true
		self:StopUpdating();
		self.lockoutselection = true
		self:AlphaTo(0, 0.2, easing.outQuad, function()
			TheFrontEnd:PopScreen(self)
			-- hack - player status on screen
			if TheDungeon.HUD and TheDungeon.HUD.player_unit_frames then
				TheDungeon.HUD.player_unit_frames:Show()
			end


			-- Spawn the skip Konjur (on host only)
			if TheNet:IsHost() then
				local allplayers = TheNet:GetSelectingPlayerIDs()
				--dumptable(allplayers)

				for i,player_nid in ipairs(allplayers) do
					local result = TheNet:GetPlayerDoneResult(player_nid);
					print("Result is ".. result .." for player " .. player_nid)

					if result == 1 then	-- Picked konjur (see RoomBonusScreen:OnPlayerCompleted())
						local player = self:_FindEntityForNetId(player_nid)
						if player then
							print("Spawning ".. self.konjur_on_skip .." konjur for player " .. player_nid)
							TheWorld.components.konjurrewardmanager:SpawnSkipPowerKonjur(player, self.konjur_on_skip)
						end
					end
				end
			end


			-- Use AllPlayers here, because the network might have already reset the SelectingPlayers array
			local delayi = 0
			for i, player in ipairs(AllPlayers) do
				if player:IsLocal() then
					local picked = self.playerchoices[player]
					if picked ~= nil then	-- if the player picked something (konjur OR a power)
						self.inst:DoTaskInAnimFrames(delayi, function(inst)
							-- If it got a bonus, determine if it accepted a skill/relic or if it decided to get konjur instead
							-- TODO: someone -- only the interacting players goes into their animation
							-- the others are not set into their powerup_interact state due to how interactables work
							if picked == true then
								player:PushEvent("roombonusscreen_accept")
							else
								player:PushEvent("roombonusscreen_skip")
							end
						end)
						delayi = delayi + 15 -- So the first one pops immediately, and the rest are sequential
					else
						player:PushEvent("roombonusscreen_closed")
					end
				end
			end

			-- Remove the powerdrop:
			if self.activePowerDrop and self.activePowerDrop.components.powerdrop and TheNet:IsHost() then
				self.activePowerDrop.components.powerdrop:OnPowerPicked()
			end
		end)
	end
end



-- For networking, we might be displaying players that are remote, and therefore don't have all the stats
-- synced. Therefore, instead of reading the stats from a player, make this playerstatstack work using a table
-- with values that are extracted from a player. This table can then be synced easily.
function RoomBonusScreen:_GatherPlayerUIData(player)
	local playerUIData = {}

	if player then
		local inventoryhoard = player.components.inventoryhoard
		local stats = inventoryhoard:ComputeStats()

		playerUIData.health = player.components.health:GetMax()
		playerUIData.armour = stats.ARMOUR
		playerUIData.luck = player.components.lucky:GetTotalLuck()
		playerUIData.movespeed = player.components.locomotor:GetTotalSpeedMult()
		playerUIData.weapondamage = stats.DMG
		playerUIData.focusdamage = player.components.combat:GetTotalFocusDamageMult()
		playerUIData.critchance = player.components.combat:GetTotalCritChance()
		playerUIData.critdamage = player.components.combat:GetTotalCritDamageMult()

		local currentSkillID = player.components.powermanager:GetCurrentSkillID()
		if currentSkillID then
			playerUIData.currentskillID = currentSkillID
		end
	end

	-- copy the drops that this player has:
	playerUIData.drops = self.drops

	-- TODO: gather the state of buttons:
	-- Which buttons are active, and what each is displaying
	-- current focus element in the UI

	playerUIData.konjurButtonFocus = self.konjur_button:HasFocus()
	playerUIData.continueButtonFocus = self.continue_button:HasFocus()

	playerUIData.buttonFocus = {}	-- true/false state to see if button is pressed or not
	playerUIData.buttonPicked = {}	-- true/false state to see if button is picked
	for k,v in ipairs(self.buttonContainer.children) do
		local hasfocus = v:HasFocus()
		local ispicked = v:IsPicked()
		table.insert(playerUIData.buttonFocus, hasfocus)
		table.insert(playerUIData.buttonPicked, ispicked)
	end

	if self.confirmed_choice then
		playerUIData.confirmedChoice = self.confirmed_choice
	end

	return playerUIData
end




function RoomBonusScreen:UpdateSkipSection(uidata)

	if uidata then

		-- If we're selecting a skill, detect if skill info changed. If they did, change them.
		if self.power_type == Power.Types.SKILL then

			local uidata_skill = uidata.currentskillID
			-- Don't update the displayed skill until player changes too.
			-- This prevents the "current" skill from changing when the
			-- player selects a new skill.
			if self.displayed_current_skill.id ~= uidata_skill
				and self.displayed_current_skill.player ~= TheNet:GetCurrentSelectingPlayerID()
			then
				-- Contents changed, so re-generate the buttons:

				-- If we already have a skill, show the currentSkillIcon with its image, and change the Skip button to say "Keep [Skillname]"
				if uidata_skill ~= nil then

					local skill = Power.FindPowerByName(uidata_skill)
					local power = TheWorld.components.powerdropmanager:MakePower(skill)	-- Create the power based on the pick and rarity
					self:SetPlayerExistingSkill(power)

				-- If we don't already have a skill, hide the currentSkillIcon and make the Skip button say "Skip Skill"
				else
					self.currentSkillContainer:Hide()
				end

				self.displayed_current_skill.id = uidata_skill
				self.displayed_current_skill.player = TheNet:GetCurrentSelectingPlayerID()
			end

		-- Otherwise, if we're selecting a power, modify the Skip Button and the CurrentSkillIcon to reflect that screen's state.
		elseif self.power_type == Power.Types.RELIC or self.power_type == Power.Types.FABLED_RELIC then
			self.currentSkillContainer:Hide()
		end
	else
		-- hide the current skill icon until we get some uidata to show
		self.currentSkillContainer:Hide()
	end
end

-- Shows the skill the player already has, which will be replaced by a new one
function RoomBonusScreen:SetPlayerExistingSkill(skill)
	self.currentSkillIcon:SetSkill(skill)
	self.currentSkillName:SetText(skill:GetDef().pretty.name)
	self.currentSkillDesc:SetText(Power.GetDescForPower(skill))
		:LayoutBounds("left", "below", self.currentSkillName)
	self.currentSkillInfo:LayoutBounds("left", "below", self.currentSkillDesc)
		:Offset(0, -15)
	self.currentSkillText:LayoutBounds("after", "center", self.currentSkillIcon)
		:Offset(80, 0)
	self.currentSkillContainer:Show()
		:LayoutBounds("left", "bottom", self.panel)
		:Offset(120, 120)
end

function RoomBonusScreen:UpdateBonusButtons(islocal, uidata)

	if uidata then
		-- Detect if the bonus buttons changed.
		-- If they did change, update them
		--self:ShowBonuses(uidata)
		if not deepcompare(self.displayed_drops, uidata.drops) then
			-- contents changed, so re-generate the buttons:
			self:SetupBonuses(islocal, uidata)

			self.displayed_drops = deepcopy(uidata.drops)
		else
			if not islocal then
				-- We are watching a remote player affect the buttons:
				-- Update the state of the buttons:

				if uidata.konjurButtonFocus ~= self.konjur_button:HasFocus() then
					if uidata.konjurButtonFocus then
						self.konjur_button:GainFocus()
					else
						self.konjur_button:LoseFocus()
					end
				end

				if uidata.continueButtonFocus ~= self.continue_button:HasFocus() then
					if uidata.konjurButtonFocus then
						self.continue_button:GainFocus()
					else
						self.continue_button:LoseFocus()
					end
				end

				for k,v in ipairs(self.buttonContainer.children) do
					if uidata.buttonFocus[k] ~= v:HasFocus() then
						if uidata.buttonFocus[k] then
							v:GainFocus()
						else
							v:LoseFocus()
						end
					end

					if uidata.buttonPicked[k] and not v:IsPicked() then
						v:SetPicked()
					end
				end
			end
		end
	else
		-- clear out all buttons until we get uidata to display
		self.buttonContainer:RemoveAllChildren()
	end
end


local LOCAL_SATURATION = 1
local REMOTE_SATURATION = 0

function RoomBonusScreen:UpdateIsLocal(islocal)

	local sat
	if islocal then
		sat = LOCAL_SATURATION
	else
		sat = REMOTE_SATURATION
	end

	-- Panel and buttons
	self.panel:SetSaturation(sat)
	self.statStack:SetSaturation(sat)
	self.selectingPlayer:SetSaturation(sat)

	self.konjurRings:SetSaturation(sat)
	self.nav_buttons:SetSaturation(sat)

	if islocal then
		self.nav_buttons:Show()
		self.selectingPlayer.playername.weapon_widget:Show() -- TEMP HACK: Applying colour to the BG happens after this, so just hide it for this hack.
	else
		self.nav_buttons:Hide()
		self.selectingPlayer.playername.weapon_widget:Hide() -- TEMP HACK: Applying colour to the BG happens after this, so just hide it for this hack.
	end

	-- Room rewards
	for k,v in ipairs(self.buttonContainer.children) do
		v:SetSaturation(sat)
	end
end

function RoomBonusScreen:UpdateStats(uidata)
	if uidata then
		self.statStack:UpdateStatsWithStatsTable(uidata)
	else
		-- TODO: Clear the stats?
		--self.statStack
	end
end

function RoomBonusScreen:UpdateConfirmedChoice(uidata)
	if uidata then
		-- If we have a confirmed choice that we haven't triggered, then trigger it.
		if not self.displayed_choice and uidata.confirmedChoice then

			local selected_button = nil
			for k,v in ipairs(self.buttonContainer.children) do
				if k == uidata.confirmedChoice then
					selected_button = v
					break
				end
			end

			self:_ApplyFinalChoiceToButtons(selected_button)
			self.displayed_choice = true
		end
	end
end

function RoomBonusScreen:OnNewSelectingPlayer(newplayer, islocal)
	TheLog.ch.FrontEnd:print("OnNewSelectingPlayer ".. (newplayer and newplayer or "nil"));
	self.active_player_nid = newplayer
	self.playerchoice = nil
	self.drops = nil
	self.displayed_drops = nil
	self.lockoutselection = not islocal	-- for remote players we want to lock out selection

	local player = self:_FindEntityForNetId(self.active_player_nid)

	if player then
		self:SetOwningPlayer(player)

		self.continue_button:IgnoreInput(false)
		self:_RefreshNavButtons()

		self.displayed_choice = false
		self.confirmed_choice = nil
		self.selected_button = nil

		self.player_unit_frames:FocusUnitFrame(player, 0.2)

		self.selectingPlayer:SetPlayer(player, islocal)
			:SendToFront()
		-- Centre only on x axis
		self.selecting_player_root:CenterChildren()
		self.selectingPlayer:SetPosition(self.selectingPlayer.x, 0)

		if islocal then
			-- Find the bonuses that apply to this player:

			self.drops = {} -- A table that contains what powers the current player will be choosing from.

			-- For each player, get what powers they should see and add it to the total list of drops.
			local num_powers = player.components.powermanager.power_drop_choices or self.num_powers
			if self.power_type == Power.Types.RELIC then
				self.drops = TheWorld.components.powerdropmanager:GetNumRelics(player, num_powers)
			elseif self.power_type == Power.Types.SKILL then
				self.drops = TheWorld.components.powerdropmanager:GetNumSkills(player, num_powers)
			elseif self.power_type == Power.Types.FABLED_RELIC then

				-- Check the active powerDrop to see what category to pick from:
				if self.activePowerDrop then
					local power_category = self.activePowerDrop.components.powerdrop.power_category
					if power_category == Power.Categories.ALL then
						print("Active powerdrop = " .. self.activePowerDrop.prefab)
						kassert.assert_fmt(false, "ERROR: Fabled Powers can't be set to have Power.Categories.ALL")
					else
						self.drops = TheWorld.components.powerdropmanager:GetNumFabledRelics(player, power_category, num_powers)
					end
				end
			end

			-- If we found some drops, tell the powermanager that the player has Seen that power.
			if next(self.drops) then
				--dumptable(self.drops)
				for _, drop in ipairs(self.drops) do
					player.components.powermanager:AddSeenPower(drop.name, drop.slot)

					if player.components.powermanager:HasPower(drop) then
						drop.block_selection = true
					end
				end
			else
				self.drops = nil
				self:_OnClickSkip()	-- Award the player some Konjur
			end
		end
	end
end


function RoomBonusScreen:_ApplyDataToScreen(islocal, uidata)
	self:UpdateBonusButtons(islocal, uidata)	-- Only update this state for remote players

	self:UpdateIsLocal(islocal)

	self:UpdateSkipSection(uidata)

	self:UpdateStats(uidata)

	self:UpdateConfirmedChoice(uidata)
end


function RoomBonusScreen:OnUpdate(dt)
	if not TheNet:IsInGame() then
		return
	end
	if not self.exiting then
		local uidata
		local current_player_nid, islocal = TheNet:GetCurrentSelectingPlayerID()

		local player_changed = false

		-- If a new player was made active, call OnNewSelectingPlayer:
		if current_player_nid ~= self.active_player_nid then
			self:OnNewSelectingPlayer(current_player_nid, islocal)
			player_changed = true
		end


		-- If this is a remote player, get the UI data from the network.
		-- If it is a local player, gather the UI data from the player and UI state, and send it out to the network
		if islocal then
			uidata = self:_GatherPlayerUIData(self:_FindEntityForNetId(current_player_nid))
			--dumptable(uidata)
			TheNet:SetPlayerUIData(current_player_nid, uidata)	-- Set the ui data for the other (remote) players
		else
			-- Update the UI based on the remote player's UI data:
			uidata = TheNet:GetCurrentSelectingPlayerUIData()
		end

		self:_ApplyDataToScreen(islocal, uidata)

		-- If the game mode changes back to game, exit this screen
		local mode, modeseqnr = TheNet:GetCurrentGameMode()
		if mode ~= self.gamemode then	-- If the game mode was changed by the host, exit this screen immediately:
			self:Exit()
		end
	end
end

function RoomBonusScreen:OnBecomeActive()
	RoomBonusScreen._base.OnBecomeActive(self)
	self:AnimateIn()
end

function RoomBonusScreen:OnBecomeInactive()
	RoomBonusScreen._base.OnBecomeInactive(self)
end

function RoomBonusScreen:MakeButtonAnimator()
	-- Hide buttons
	for k, button in ipairs(self.buttonContainer.children) do
		button:PrepareAnimation()
	end

	-- Animate in buttons
	local buttonsUpdater = Updater.Parallel()

	-- Shuffle button order so they don't come in sequentially
	local buttons = krandom.ShuffleCopy(self.buttonContainer.children)

	for k, button in ipairs(buttons) do

		-- Fade out button
		button:SetMultColorAlpha(0)

		-- Get button position
		local buttonX, buttonY = button:GetPosition()

		-- Animate each button in
		buttonsUpdater:Add(Updater.Series({
			Updater.Wait(k * 0.1),
			Updater.Parallel({
				Updater.Ease(function(v) button:SetMultColorAlpha(v) end, 0, 1, 0.25, easing.outQuad),
				Updater.Ease(function(v) button:SetScale(v) end, 0.9, 1, 0.2, easing.outQuad),
				Updater.Ease(function(v) button:SetPosition(buttonX, v) end, buttonY - 90, buttonY, 0.2, easing.outQuad),
			})
		}))

		-- And add a delay before the next button starts animating in too
		buttonsUpdater:Add(Updater.Wait(0.02))
	end

	self.is_animating = true
	return Updater.Series({
		Updater.Wait(0.3),
		buttonsUpdater,
		Updater.Do(function()
			-- Once done animating buttons, the player should have stopped
			-- mashing and won't accidentally select a power.
			self.is_animating = false
		end),
	})
end

function RoomBonusScreen:AnimateIn()
	-- Hide elements
	self.bg:SetMultColorAlpha(0)
	self.title:SetMultColorAlpha(0)
	self.nav_buttons:SetMultColorAlpha(0)
	-- self.continue_button:SetMultColorAlpha(0)

	-- Get default positions
	local bgX, bgY = self.bg:GetPosition()
	local titleX, titleY = self.title:GetPosition()
	local navX, navY = self.nav_buttons:GetPosition()
	-- local continue_buttonX, continue_buttonY = self.continue_button:GetPosition()

	-- Start animating
	self:RunUpdater(Updater.Parallel({

		-- HACK(dbriscoe): Let hud show behind for now. Eventually, we
		-- might redo this screen to include the hud data. I think that's
		-- necessary to make the tooltips show up.
		--~ Updater.Do(function()
		--~ 	TheDungeon.HUD:Hide()
		--~ end),

		-- Animate background
		Updater.Series({
			-- Updater.Wait(0.15),
			Updater.Parallel({
				Updater.Ease(function(v) self.bg:SetMultColorAlpha(v) end, 0, 1, 0.5, easing.outQuad),
				Updater.Ease(function(v) self.bg:SetScale(v) end, 1.1, 1, 0.3, easing.outQuad),
				Updater.Ease(function(v) self.bg:SetPosition(bgX, v) end, bgY + 10, bgY, 0.3, easing.outQuad),
			}),
		}),

		-- Animate the title
		Updater.Series({
			Updater.Wait(0.2),
			Updater.Parallel({
				Updater.Ease(function(v) self.title:SetMultColorAlpha(v) end, 0, 1, 0.1, easing.inOutQuad),
				Updater.Ease(function(v) self.title:SetPosition(titleX, v) end, titleY + 40, titleY, 0.2, easing.inOutQuad),
			}),
		}),

		-- Animate the continue button
		Updater.Series({
			Updater.Wait(1),
			Updater.Parallel({
				Updater.Ease(function(v) self.nav_buttons:SetMultColorAlpha(v) end, 0, 1, 0.1, easing.inOutQuad),
				Updater.Ease(function(v) self.nav_buttons:SetPosition(v, navY) end, navX - 40, navX, 0.2, easing.inOutQuad),
			}),
		}),

	}))

	return self
end

return RoomBonusScreen
