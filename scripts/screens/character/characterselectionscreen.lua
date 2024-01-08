local Widget = require "widgets.widget"
local Image = require "widgets.image"
local SelectablePuppet = require "widgets.ftf.selectablepuppet"
local Text = require "widgets.text"
local Screen = require "widgets.screen"
local templates = require "widgets.ftf.templates"
local ImageButton = require "widgets.imagebutton"
local ConfirmDialog = require "screens.dialogs.confirmdialog"

local audioid = require "defs.sound.audioid"
local fmodtable = require "defs.sound.fmodtable"

local krandom = require "util.krandom"
local easing = require "util.easing"

local MusicTrack = fmodtable.Event.mus_CharacterCreation_LP

-- Lets the player pick a character from their save slots (or start the creation of a new one)
local CharacterSelectionScreen = Class(Screen, function(self, owner, on_close_cb)
	Screen._ctor(self, "CharacterSelectionScreen")

	self:SetOwningPlayer(owner)
	self.owner = owner
	self.ownerPlayerID = owner.Network:GetPlayerID()
	self.on_close_cb = on_close_cb

	self.bg = self:AddChild(Image("images/bg_ChooseCharacterBg/ChooseCharacterBg.tex"))
		:SetName("Background")
		:SetSize(RES_X, RES_Y)
		:SetMultColor(0xFFFFFFff)
		:SetMultColorAlpha(1)

	self.panel_root = self:AddChild(Widget())
		:SetName("Panel root")

	-- A panel background
	self.panel_bg = self.panel_root:AddChild(Image("images/bg_CharacterSelectionBg/CharacterSelectionBg.tex"))
		:SetName("Panel background")
		:SetMultColorAlpha(0)
	self.panel_w, self.panel_h = self.panel_bg:GetSize()

	self.choose_character_contents = self.panel_root:AddChild(Widget())
		:SetName("Choose-character contents")
		:SetMultColorAlpha(0)
		:Hide()

	self.close_button = self.choose_character_contents:AddChild(ImageButton("images/ui_ftf/HeaderClose.tex"))
		:SetNavFocusable(false) -- rely on CONTROL_MAP
		:SetOnClick(function() self:OnClickClose() end)
		:SetSize(BUTTON_SQUARE_SIZE, BUTTON_SQUARE_SIZE)
		:LayoutBounds("right", "top", self.panel_bg)
		:Offset(-40, 30)

	self.character_slot_data = TheSaveSystem.character_slots

	self.choose_character_title = self.choose_character_contents:AddChild(Text(FONTFACE.DEFAULT, FONTSIZE.SCREEN_TITLE))
		:SetName("Choose-character title")
		:SetGlyphColor(UICOLORS.BACKGROUND_LIGHT)
		:SetText(STRINGS.CHARACTER_SELECTOR.TITLE_SELECT)

	self.choose_character_buttons = self.choose_character_contents:AddChild(Widget())
		:SetName("Choose-character buttons")

	self.info_label = self.choose_character_contents:AddChild(Text(FONTFACE.DEFAULT, FONTSIZE.SCREEN_TEXT*1.3))
		:SetText(STRINGS.CHARACTER_SELECTOR.INFO_LABEL)
		:SetGlyphColor(UICOLORS.LIGHT_TEXT_DARK)
		-- :SetAutoSize(500)

	self.buttons = self:AddChild(Widget("Buttons container"))
	-- And continue button
	self.continue_btn = self.buttons:AddChild(templates.Button(STRINGS.CHARACTER_SELECTOR.START_BUTTON))
		:SetPrimary()
		:SetNineSliceBorderScale(0.9)
		:SetSize(BUTTON_W, BUTTON_H*1.3)
		:SetOnClick(function() self:OnContinueClicked() end)
		:SetMultColorAlpha(0)
		:Hide()
		:SetControlUpSound(fmodtable.Event.ui_input_up_play)

	self.choose_character_contents.start_x, self.choose_character_contents.start_y = self.choose_character_contents:GetPos()

	TheAudio:PlayPersistentSound(audioid.persistent.ui_music, MusicTrack)

	self.default_focus = self.continue_btn

	self:Refresh()
end)

CharacterSelectionScreen.CONTROL_MAP =
{
	{
		control = Controls.Digital.CANCEL,
		fn = function(self)
			if TheFrontEnd:IsRelativeNavigation() then
				self:OnClickClose()
				return true
			end
		end,
	},
	{
		control = Controls.Digital.ATTACK_HEAVY,
		fn = function(self)

			-- This handler is just for gamepad. Mouse has altclick callbacks set on the buttons
			if not TheFrontEnd:IsRelativeNavigation() then return false end

			-- Get selected slot
			local focus = TheFrontEnd:GetFocusWidget()
			if focus and self.choose_character_buttons:IsAncestorOf(focus) then
				focus:AltClick()
			end
		end,
	},
}

-- What should happen when the player closes this screen without a selection?
function CharacterSelectionScreen:SetOnClickCloseFn(on_click_close_fn)
	self.on_click_close_fn = on_click_close_fn
	return self
end

function CharacterSelectionScreen:OnClickClose()
	if self.on_click_close_fn then
		self.on_click_close_fn()
	else
		TheFrontEnd:PopScreen(self)
	end
	return self
end

function CharacterSelectionScreen:OnInputModeChanged(old_device_type, new_device_type)
	self.continue_btn:SetShown(not TheFrontEnd:IsRelativeNavigation() and self.selected_slot)
	self.info_label:RefreshText()
end

function CharacterSelectionScreen:Refresh()
	self.character_slot_data = TheSaveSystem.character_slots

	self.choose_character_buttons:RemoveAllChildren()
	self.character_slot_puppets = {}

	local species = {"ogre", "mer", "canine"}

	local num_slots = table.count(self.character_slot_data)
	-- we want these to always be in the same order but the table isn't an indexed table so we have to do it manually
	for i = 1, num_slots do
		local slot = i - 1 -- character slot data is indexed starting at 0 to match playerIDs
		local save = self.character_slot_data[slot]

		local player_data = save:GetValue("player")
		local button = self.choose_character_buttons:AddChild(SelectablePuppet(self.label_font_size))
				:LayoutBounds("after")
				:Offset(300, 0)

		button:SetOnClickFn(function()
			self:OnCharacterClicked(button, slot)
		end)

		button:SetOnClickAltFn(function()
			self:OnClickCharacterDelete(button, slot, i)
		end)

		button:SetOnFocusChangedFn(function(has_focus)
			self:OnCharacterFocusChanged(has_focus, button, slot, i)
		end)

		if player_data then
			button.can_be_deleted = true
			button:SetPlayerData(player_data)
			button:UpdateName(string.format(STRINGS.CHARACTER_SELECTOR.SLOT, i))

			if TheSaveSystem:IsSlotActive(slot) then
				if TheSaveSystem:GetCharacterForPlayerID(self.ownerPlayerID) == slot then
					button:UpdateName(string.format(STRINGS.CHARACTER_SELECTOR.SLOT_YOUR_SLOT, i))
				else
					button:UpdateName(string.format(STRINGS.CHARACTER_SELECTOR.SLOT_IN_USE, i))
					-- slot is claimed, disable button
					button.puppet:SetSaturation(0)
					button:Disable()
				end
				button.can_be_deleted = false
			end
		else
			-- this slot has never been used, show a "create character" button instead
			button.can_be_deleted = false
			button:Randomize(species[i])
			button.puppet:SetMultColor(0, 0, 0)
			button.puppet:SetMultColorAlpha(1)
			button:UpdateName(STRINGS.CHARACTER_SELECTOR.NEW_CHARACTER)
		end

		self.character_slot_puppets[i] = button
	end


	self.info_label:LayoutBounds("center", "bottom", self.panel_bg)
		:Offset(0, 120)
	self.choose_character_buttons:LayoutBounds("center", "center", self.panel_bg)
	self.choose_character_title:LayoutBounds("center", "above", self.choose_character_buttons)
		:Offset(0, 180)
end

function CharacterSelectionScreen:OnBecomeActive()
	CharacterSelectionScreen._base.OnBecomeActive(self)

	if not self.animatedIn then
		self.continue_btn:SetFocus()

		self:AnimateIn()
		self.animatedIn = true
	end
end

function CharacterSelectionScreen:OnBecomeInactive()
	CharacterSelectionScreen._base.OnBecomeInactive(self)
	TheAudio:StopPersistentSound(audioid.persistent.ui_music)
end

function CharacterSelectionScreen:PlayEmote(button)
	local emotes = 
	{
		"emote_pump",
		"emote_wave",
		"emote_nod_short_stern",
		"emote_nod_cheerful",
		"emote_excited",
	}

	-- local species_emotes = 
	-- {
	-- 	["mer"] = "emote_amphibee_bubble_kiss",
	-- 	["canine"] = "emote_mammimal_howl",
	-- 	["ogre"] = "emote_ogre_charged_jump",
	-- }

	-- local species = button:GetSpecies()
	-- table.insert(emotes, species_emotes[species])

	button.puppet:PlayAnimSequence({krandom.PickFromArray(emotes), "idle"})
end

function CharacterSelectionScreen:OnCharacterClicked(button, slot)

	-- Unselect other puppets
	for k, btn in ipairs(self.choose_character_buttons.children) do
		btn:SetSelected(button == btn)
	end

	self:PlayEmote(button)

	self.selected_slot = slot

	if TheFrontEnd:IsRelativeNavigation() then
		-- On gamepad, trigger the game starting
		self:OnContinueClicked()
	else
		-- On mouse, show the Continue button
		self:_AnimateChooseButtonsIn()
	end
end

function CharacterSelectionScreen:OnClickCharacterDelete(button, slot, idx)
	if button.can_be_deleted == false then return self end

	local function delete_character()
		TheSaveSystem.character_slots[slot]:Erase(function()
			-- if this was your last selected slot, remove that data
			if Profile:GetLastSelectedCharacterSlot() == slot then
				Profile:SetLastSelectedCharacterSlot(nil)
			end

			-- refresh the screen
			self:Refresh()

			-- remove this popup
			TheFrontEnd:PopScreen()
		end)
	end

	local function cancel()
		TheFrontEnd:PopScreen() -- confirmation message box
	end

	local confirmation = ConfirmDialog(nil, nil, true,
			STRINGS.CHARACTER_SELECTOR.DELETE_TITLE,
			string.format(STRINGS.CHARACTER_SELECTOR.DELETE, idx),
			STRINGS.CHARACTER_SELECTOR.DELETE_SUBTITLE
		)
		:SetYesButton(STRINGS.CHARACTER_SELECTOR.DELETE_CONFIRM, delete_character)
		:SetNoButton(STRINGS.CHARACTER_SELECTOR.DELETE_CANCEL, cancel)
		:HideArrow()
		:SetMinWidth(600)
		:CenterText()
		:CenterButtons()
	TheFrontEnd:PushScreen(confirmation)
end

function CharacterSelectionScreen:OnCharacterFocusChanged(has_focus, button, slot, idx)

	if not TheFrontEnd:IsRelativeNavigation() then return self end

	
	-- Unselect other puppets
	for k, btn in ipairs(self.choose_character_buttons.children) do
		btn:SetSelected(button == btn)
		
		
	end
	if has_focus then
		self:PlayEmote(button)
	end
	self.selected_slot = slot
end

function CharacterSelectionScreen:CreateNewCharacter(new_character_data)
	local CharacterScreen = require("screens.character.characterscreen")
	TheFrontEnd:PushScreen(CharacterScreen(self:GetOwningPlayer(), self.on_close_cb, new_character_data))
end

function CharacterSelectionScreen:OnContinueClicked()
	if not self.selected_slot then
		assert(true, "Somehow this got clicked with no slot selected?")
	end
	-- local wait_for_save_popup = PopupDialogScreen("", STRINGS.UI.NOTIFICATION.LOADING)
	-- TheFrontEnd:PushScreen(wait_for_save_popup)

	-- assign playerID to the character slot
	local owner = self:GetOwningPlayer()

	local on_close = function()
		local character_save = TheSaveSystem:LoadCharacterAsPlayerID(self.selected_slot, self.ownerPlayerID)
		local player_data = character_save and character_save:GetValue("player")

		owner:PushEvent("character_slot_changed")
		TheFrontEnd:PopScreen(self)

		if player_data ~= nil then
			owner:SetPersistData(player_data)
			owner:PostLoadWorld(player_data)
			if self.on_close_cb then
				self.on_close_cb(self.owner)
			end
		else
			local new_character_data = self.character_slot_puppets[self.selected_slot+1].puppet.components.charactercreator:OnSave()
			self:CreateNewCharacter(new_character_data)
			-- TODO: Pop up character customization screen after this if the slot you just picked has no player data.
			-- Remove character customization step from intro quest flow
			-- Change game startup flow to not even try to enter the game until both of these steps are done.
		end
	end

	if TheSaveSystem:GetSaveForCharacterSlot(TheSaveSystem:GetCharacterForPlayerID(self.ownerPlayerID)) then
		TheSaveSystem:SaveCharacterForPlayerID(self.ownerPlayerID, on_close)
	else
		on_close()
	end
end

function CharacterSelectionScreen:AnimateIn()
	self.panel_root:RunUpdater(Updater.Parallel{
		Updater.Ease(function(v) self.bg:SetMultColorAlpha(v) end, self.bg:GetMultColorAlpha(), 1, 0.6, easing.outQuad),
		Updater.Series{
			Updater.Wait(0.3),
			Updater.Parallel{
				-- Animate in the background
				Updater.Ease(function(v) self.panel_bg:SetMultColorAlpha(v) end, 0, 1, 0.4, easing.outQuad),
				Updater.Ease(function(v) self.panel_bg:SetPos(nil, v) end, -40, 0, 0.6, easing.outElastic),
			}
		},

		Updater.Series{
			Updater.Wait(0.5),
			Updater.Do(function()
				-- Set what mode to display
				self:ShowCharacters()
			end)
		}
	})

	return self
end

function CharacterSelectionScreen:ShowCharacters()
	-- Always set text to ensure it uses most recent input method.
	self.continue_btn:SetText(STRINGS.CHARACTER_SELECTOR.START_BUTTON)
	self:_AnimatePanelIn(self.choose_character_contents)

	return self
end

function CharacterSelectionScreen:_AnimatePanelIn(panel, on_done)
	panel:SetMultColorAlpha(0)
		:Show()
		:AlphaTo(1, 0.05, easing.outQuad)
		:SetPos(panel.start_x, panel.start_y - 40)
		:MoveTo(panel.start_x, panel.start_y, 0.15, easing.outQuad, on_done)
end

-- Animates in the customize_btn and the continue_btn
function CharacterSelectionScreen:_AnimateChooseButtonsIn(on_done)
	if not self.choose_buttons_animated_in then
		-- Only do this the first time a character is selected
		self.choose_buttons_animated_in = true

		self.continue_btn:SetMultColorAlpha(0):Show()
			:RefreshText()
			:LayoutBounds("after", "center", self.customize_btn)
			:Offset(30, 0)
		self.buttons:LayoutBounds("center", "below", self.panel_bg)
			:Offset(0, -10)

		-- Get their positions
		self.continue_btn.start_x, self.continue_btn.start_y = self.continue_btn:GetPos()

		-- Fade out the buttons
		self.continue_btn:SetMultColorAlpha(0):Show()

		-- Animate each button in
		local timing = 0.4
		self:RunUpdater(
			Updater.Parallel({
				-- Animate in the start button first
				Updater.Ease(function(y) self.continue_btn:SetPos(self.continue_btn.start_x, y) end, self.continue_btn.start_y - 30, self.continue_btn.start_y, timing, easing.outElastic),
				Updater.Ease(function(a) self.continue_btn:SetMultColorAlpha(a) end, 0, 1, timing/2, easing.outQuad),

				-- Then the customization one after a beat
				Updater.Series({
					Updater.Wait(0.15),
					-- Invoke callback, if any
					Updater.Do(function()
						if on_done then on_done() end
					end)
				})
			})
		)
	end
end

return CharacterSelectionScreen
