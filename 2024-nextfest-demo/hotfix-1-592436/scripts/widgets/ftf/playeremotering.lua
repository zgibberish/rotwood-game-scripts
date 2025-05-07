local Clickable = require("widgets/clickable")
local Cosmetics = require "defs.cosmetics.cosmetics"
local HotkeyImage = require "widgets.hotkeyimage"
local Image = require "widgets/image"
local Widget = require("widgets/widget")
local easing = require("util/easing")
local fmodtable = require "defs.sound.fmodtable"


--------------------------------------------------------------------------------------------------

local RING_STATES =
{
	["HIDDEN"] = "HIDDEN",								-- currently hidden
	["WAITING_FOR_FADE_IN"] = "WAITING_FOR_FADE_IN",	-- waiting to show the ring or tigger the last emote
	["FADE_IN"] = "FADE_IN",							-- fading into the world
	["IDLE"] = "IDLE",									-- visible, but not doing anything right now
	["FADE_OUT"] = "FADE_OUT",							-- fading out of the world
}

local SOUND_EVENTS =
{
	["OPEN_DEFAULT"] = nil,
	["OPEN_POWERS"] = nil,
	["CLOSE"] = nil,
	["FOCUS"] = nil,
}

local SLOT_IDX_TO_GAMEPAD_HOTKEY =
{
	[1] = Controls.Digital.ATTACK_HEAVY,
	[3] = Controls.Digital.SKILL,
	[5] = Controls.Digital.DODGE,
	[7] = Controls.Digital.ATTACK_LIGHT
}

local CONTROLLER_SHORTCUT_MAP =
{
	["Controls.Digital.ATTACK_LIGHT"] = 7,
	["Controls.Digital.ATTACK_HEAVY"] = 1,
	["Controls.Digital.SKILL"] = 3,
	["Controls.Digital.DODGE"] = 5,
}

local ANIMATE_IN_DURATION = 0.1
local ANIMATE_OUT_DURATION = 0.1

--------------------------------------------------------------------------------------------------
-- A single emote-ring button

local PlayerEmoteQuadrant = Class(Clickable, function(self, slot_index)
	Widget._ctor(self, "PlayerEmoteQuadrant")

	self.emote_id = nil
	self.is_active = true -- If it should be shown and usable. False if not showing diagonals
	self.angle = 0
	self.rad_angle = 0
	self.slot_index = slot_index or 1 -- 1 is top, the rest continue clockwise
	self.size = 200
	self.icon_size = self.size*0.7

	-- Setup colors
	self.bg_normal = UICOLORS.LIGHT_BACKGROUNDS_LIGHT
	self.bg_focus = HexToRGB(0xFFB229ff)
	self.edge_normal = HexToRGB(0xF4E1CEff)
	self.edge_focus = HexToRGB(0xFFCB27ff)
	self.icon_normal = UICOLORS.LIGHT_TEXT_DARK
	self.icon_focus = UICOLORS.BACKGROUND_MID

	-- Contains the widgets that are rotated with the slot angle
	self.rotated_widgets = self:AddChild(Widget())
		:SetName("Rotated widgets")

	-- Widgets which move when selected
	self.moving_widgets = self.rotated_widgets:AddChild(Widget())
		:SetName("Moving widgets")

	self.bg = self.moving_widgets:AddChild(Image("images/ui_ftf_hud/emote_ring_button.tex"))
		:SetName("Background")
		:SetMultColor(self.bg_normal)
		:SetSize(self.size, self.size)

	self.edge = self.moving_widgets:AddChild(Image("images/ui_ftf_hud/emote_ring_edge.tex"))
		:SetName("Edge")
		:SetMultColor(self.edge_normal)
		:SetSize(self.size, self.size)

	self.icon = self.moving_widgets:AddChild(Image("images/ui_ftf_hud/circle.tex"))
		:SetName("Icon")
		:SetMultColor(self.icon_normal)
		:SetSize(self.icon_size, self.icon_size)
		:SetPosition(0, self.size*0.055)

	self:SetSelected(false, true) -- Set unselected, skipping animation
end)

function PlayerEmoteQuadrant:SetWidgetRotation(angle)
	self.angle = angle or 0
	self.rotated_widgets:SetRotation(self.angle)
	if self.hotkey_container then self.hotkey_container:SetRotation(-self.angle) end
	self.icon:SetRotation(-self.angle)
	return self
end

function PlayerEmoteQuadrant:SetSlotRadAngle(angle)
	self.rad_angle = angle
	return self
end

function PlayerEmoteQuadrant:GetSlotRadAngle()
	return self.rad_angle
end

function PlayerEmoteQuadrant:SetEmote(emote_id)
	self.emote_id = emote_id
	if self.emote_id then
		self.icon:Show()
			:SetTexture(Cosmetics.PlayerEmotes[self.emote_id].icon_path)
	else
		self.icon:Hide()
	end
	return self
end

function PlayerEmoteQuadrant:GetEmoteId()
	return self.emote_id
end

function PlayerEmoteQuadrant:SetHotkeyControl(control)
	if not self.hotkey_container then
		local hotkey_size = 56
		local hotkey_padding = 6

		self.hotkey_container = self.moving_widgets:AddChild(Widget())
			:SetName("Hotkey container")
			:SetPosition(0, -self.size*0.4)
			:SetRotation(-self.angle)
		self.hotkey_bg = self.hotkey_container:AddChild(Image("images/ui_ftf_hud/circle.tex"))
			:SetName("Hotkey background")
			:SetSize(hotkey_size, hotkey_size)
			:SetMultColor(self.edge_normal)
		self.hotkey_icon = self.hotkey_container:AddChild(HotkeyImage(control))
			:SetSize(hotkey_size - hotkey_padding*2, hotkey_size - hotkey_padding*2)
			:SetMultColor(UICOLORS.BACKGROUND_MID)
	end

	return self
end

function PlayerEmoteQuadrant:SetHotkeyShown(show_hotkey)
	if self.hotkey_container then
		self.hotkey_container:SetShown(show_hotkey)
	end
	return self
end

function PlayerEmoteQuadrant:SetActive(is_active)
	self.is_active = is_active
	return self
end

function PlayerEmoteQuadrant:IsActive()
	return self.is_active
end

function PlayerEmoteQuadrant:SetSelected(is_selected, skip_animation)
	if self.is_selected == is_selected then
		return self
	end
	self.is_selected = is_selected

	if skip_animation then
		self.bg:SetMultColor(self.is_selected and self.bg_focus or self.bg_normal)
		self.edge:SetMultColor(self.is_selected and self.edge_focus or self.edge_normal)
		if self.hotkey_bg then self.hotkey_bg:SetMultColor(self.is_selected and self.edge_focus or self.edge_normal) end
		self.icon:SetMultColor(self.is_selected and self.icon_focus or self.icon_normal)
		self.moving_widgets:SetPosition(0, self.is_selected and 20 or 0)
	else
		if self.is_selected then
			self:PlaySpatialSound(fmodtable.Event.emoteRing_hover)
			self.bg:TintTo(nil, self.bg_focus, 0.1, easing.outQuad)
			self.edge:TintTo(nil, self.edge_focus, 0.1, easing.outQuad)
			if self.hotkey_bg then self.hotkey_bg:TintTo(nil, self.edge_focus, 0.1, easing.outQuad) end
			self.icon:TintTo(nil, self.icon_focus, 0.1, easing.outQuad)
			self.moving_widgets:MoveTo(0, 20, 0.95, easing.outElasticUI)
		else
			self.bg:TintTo(nil, self.bg_normal, 0.3, easing.outQuad)
			self.edge:TintTo(nil, self.edge_normal, 0.3, easing.outQuad)
			if self.hotkey_bg then self.hotkey_bg:TintTo(nil, self.edge_normal, 0.3, easing.outQuad) end
			self.icon:TintTo(nil, self.icon_normal, 0.3, easing.outQuad)
			self.moving_widgets:MoveTo(0, 0, 1.2, easing.outElasticUI)
		end
	end
	return self
end

function PlayerEmoteQuadrant:IsSelected()
	return self.is_selected
end

function PlayerEmoteQuadrant:PrepareAnimation()
	self:SetMultColorAlpha(0)
	self.moving_widgets:SetPosition(0, -20)
	return self
end

function PlayerEmoteQuadrant:AnimateIn(on_done)
	if not self.is_active then
		return self
	end

	self:AlphaTo(1, ANIMATE_IN_DURATION, easing.outQuad, on_done)
	self.moving_widgets:MoveTo(0, 0, 0.95, easing.outElasticUI)
	return self
end

function PlayerEmoteQuadrant:AnimateOut(on_done)
	if not self.is_active then
		self:SetMultColorAlpha(0)
		return self
	end

	self:AlphaTo(0, ANIMATE_OUT_DURATION, easing.outQuad, on_done)
	return self
end

--------------------------------------------------------------------------------------------------
-- The emote-ring displaying the various available emote buttons

local PlayerEmoteRing = Class(Widget, function(self, owner)
	Widget._ctor(self, "PlayerEmoteRing")

	dbassert(owner)
	self:SetOwningPlayer(owner)

	self.active = false 					-- If true, then playercontroller will feed inputs to this instead
	self.show_diagonals = true				-- If true, it displays 8 emotes, instead of the cardinal 4
	self.slots_count = self.show_diagonals and 8 or 4
	self.slot_position_radius = 230			-- How far from the centre each slot is
	self.slots_position_y_offset = 80		-- How much to offset the circle from y=0
	self.emote_slots = {
		-- index: widget,
		-- index: widget,
		-- ...
	}
	self.mouse_radius_min = 130				-- How far from the centre the mouse has to be for hover
	self.mouse_radius_max = 580				-- If the mouse is this far from the centre, there's no hover
	self.last_played_emote_slot_idx = nil 	-- The last played emote. So we can repeat it later
	self.hotkeys_shown = true 				-- Slots show gamepad hotkeys by default

	-- If the player presses the emote-key and then releases it before this time
	-- is up, the last emote will be triggered. Otherwise the ring will fade in
	self.time_before_fade_in = 0.11
	self.delay_until_fade_in = 0

	-- Container for the emote slots
	self.slots_container = self:AddChild(Widget())
		:SetName("Slots container")
		:SetPos(0, self.slots_position_y_offset)

	-- Add emote slots
	for k = 1, 8 do
		-- Add a slot widget
		self:_AddEmoteSlot(k)

		-- Check if it's a diagonal
		if k%2 ~= 0 then
			-- Cardinal slot
			self.emote_slots[k]:SetHotkeyControl(SLOT_IDX_TO_GAMEPAD_HOTKEY[k])
		end
	end

	self:SetRingState(RING_STATES.HIDDEN)

	self._onremovetarget = function() self:SetOwner(nil) end
	self:Hide()
	self:SetOwner(owner)
end)

-- If diagonal slots are meant to be active or not
function PlayerEmoteRing:SetDiagonalsActive(diagonals_active)
	self.show_diagonals = diagonals_active
	self.slots_count = self.show_diagonals and 8 or 4

	for k, v in ipairs(self.slots_container.children) do
		if k%2 == 0 then
			v:SetActive(self.show_diagonals)
		end
	end

	return self
end

function PlayerEmoteRing:IsRingShowing()
	return self.bar_state == RING_STATES.WAITING_FOR_FADE_IN
	or self.bar_state == RING_STATES.FADE_IN
	or self.bar_state == RING_STATES.IDLE
end

function PlayerEmoteRing:SetRingState(new_state)
	self.bar_state = new_state
end

function PlayerEmoteRing:SetOwner(owner)
	self:SetOwningPlayer(owner)

	-- TODO(ui): Rely on GetOwningPlayer instead of tracking our own owner.
	if owner ~= self.owner then
		if self.owner ~= nil then
			self.inst:RemoveEventCallback("onremove", self._onremovetarget, self.owner)
		end
		
		self.owner = owner

		if self.owner ~= nil then
			self.inst:ListenForEvent("onremove", self._onremovetarget, self.owner)
		end
	end

	-- TODO: Check if this player has access to diagonals
	self:SetDiagonalsActive(self.show_diagonals)

	-- Update player emotes
	self:RefreshEmotes()

	self:StartUpdating()
end

function PlayerEmoteRing:RefreshEmotes()
	for slot_index, slot in ipairs(self.slots_container.children) do
		if self.owner then 
			slot:SetEmote(self.owner.components.playeremoter:GetEmote(slot_index))
		else
			slot:SetEmote(nil)
		end
	end
end

function PlayerEmoteRing:OnInputModeChanged(old_device_type, new_device_type)
	-- If the input mode changed, close this
	self:CloseImmediately()
end

function PlayerEmoteRing:OnEmoteKey(toggle_mode)

	-- Check whether the emote-key is being held down or not
	toggle_mode = (toggle_mode == "down")

	if toggle_mode then -- The button is being held down -------------------------------

		self:SetRingState(RING_STATES.WAITING_FOR_FADE_IN)
		self.delay_until_fade_in = self.time_before_fade_in
		self:StartUpdating() -- Start counting until we know whether to show the ring or trigger the last emote

		-- Update player emotes
		self:RefreshEmotes()

	else -- The button isn't down ------------------------------------------------------

		if self.bar_state == RING_STATES.WAITING_FOR_FADE_IN then
			-- The player release the emote-key before the ring faded in.

			-- Show the last emote, if any
			if self.last_played_emote_slot_idx and self.owner then
				self.owner.components.playeremoter:DoEmote(self.last_played_emote_slot_idx)
			end

			-- And close the ring
			self:SetRingState(RING_STATES.HIDDEN)

		elseif self.bar_state == RING_STATES.IDLE
		or self.bar_state == RING_STATES.FADE_IN
		then
			-- The ring is being shown
			-- If there's a selected slot, try to show that emote
			local selected_index = self:GetSelectedSlotIndex()
			if selected_index then
				local slot = self:GetSlot(selected_index)
				local slot_is_active = slot:IsActive()
				if slot_is_active then

					-- Play this emote
					if self.owner then 
						self.owner.components.playeremoter:DoEmote(selected_index)
						self:PlaySpatialSound(fmodtable.Event.emoteRing_select)
					end
					-- Save it for next time too
					self.last_played_emote_slot_idx = selected_index
					-- Close the ring without animating
					self:CloseImmediately()

				else

					-- This slot isn't active (maybe a diagonal when diagonals aren't enabled)
					-- Or it doesn't have an emote set to it
					-- Fade it out
					self:FadeOut()

				end
			else
				-- Fade it out
				self:FadeOut()
			end
		else
			self:CloseImmediately()
		end
	end
end

function PlayerEmoteRing:CloseImmediately()
	self:SetRingState(RING_STATES.HIDDEN)
	self:Hide()
	self.active = false
	for k, v in ipairs(self.slots_container.children) do
		v:PrepareAnimation()
	end
	self:StopUpdating()
end

function PlayerEmoteRing:FadeIn()
	self:PlaySpatialSound(fmodtable.Event.emoteRing_show)
	self:SetRingState(RING_STATES.FADE_IN)
	self:Show()
	for k, v in ipairs(self.slots_container.children) do
		v:PrepareAnimation()
			:SetSelected(false, true) -- Unselect slot, skipping animation
			:AnimateIn()
	end
	self:SetRingState(RING_STATES.IDLE)
	self:StartUpdating()
end

function PlayerEmoteRing:FadeOut()
	self:SetRingState(RING_STATES.FADE_OUT)
	for k, v in ipairs(self.slots_container.children) do
		if k == #self.slots_container.children then
			v:AnimateOut(function() self:Hide() end)
		else
			v:AnimateOut()
		end
	end
	self:SetRingState(RING_STATES.HIDDEN)
	self.active = false
	self:StopUpdating()
end

function PlayerEmoteRing:DoEmoteShortcut(control)
	local slot_index = CONTROLLER_SHORTCUT_MAP[control.key]
	self:PlaySpatialSound(fmodtable.Event.emoteRing_select)
	-- Play this emote
	if self.owner then 
		self.owner.components.playeremoter:DoEmote(slot_index)
	end
	-- Save it for next time too
	self.last_played_emote_slot_idx = slot_index
	-- Close the ring without animating
	self:CloseImmediately()
end

-- Positions the ring around the respective player character
function PlayerEmoteRing:UpdatePosition()
	if self.owner then
		local x, y = self:CalcLocalPositionFromEntity(self.owner)
		self:SetPosition(x, y + self.slots_position_y_offset)
	end
end

function PlayerEmoteRing:UpdateFocus()

	-- Only check for focus when the ring is visible
	if self.bar_state ~= RING_STATES.IDLE then
		return
	end

	if self.owner then 
		-- Get player's input device
		local input_id = TheNet:FindInputIDForGUID(self.owner.GUID)
		local device_type, device_id = TheInput:ConvertFromInputID(input_id)

		-- Handle them accordingly
		local angle, radius
		if device_type == "keyboard" then

			-- Show focus based on the mouse angle around the ring
			local mx, my = TheInput:GetVirtualMousePos()
			local wx, wy = self:GetPosition()
			wy = wy + self.slots_position_y_offset
			local dx = mx - wx
			local dy = my - wy -- self.slots_position_y_offset
			angle = math.deg(ReduceAngleRad(-math.atan(dy, dx)))
			angle = (angle + 360) % 360
			radius = math.sqrt(dx * dx + dy * dy)

			if radius < self.mouse_radius_min
			or radius > self.mouse_radius_max then
				angle = nil
			end

			self:SetGamepadHotkeysShown(false)

		elseif device_type == "gamepad" then

			-- Show focus based on the gamepad stick angle
			local playercontroller = self.owner.components.playercontroller
			radius, angle = playercontroller:GetRadialMenuDir() -- Angle is nil if the right-stick was idle
			if angle then
				angle = (angle + 360) % 360
			end

			self:SetGamepadHotkeysShown(true)

		end

		-- Find which slot matches the angle
		local closest_slot_index = -1
		if angle then

			local smallest_difference = 360
			for k, slot in ipairs(self.slots_container.children) do
				if slot:IsActive() then

					-- Calculate angle difference
					local diff = DiffAngle(angle, slot:GetSlotRadAngle())

					-- If it's closer than the last closest, save it
					if diff < smallest_difference then
						smallest_difference = diff
						closest_slot_index = k
					end

				end
			end
		end

		self:SelectSlot(closest_slot_index) -- if none, it unselects all slots

		-- If the player flicked the gamepad stick to a slot, trigger that emote
		if device_type == "gamepad" and closest_slot_index > 0 then

			local slot = self:GetSlot(closest_slot_index)
			local slot_is_active = slot:IsActive()
			if slot_is_active then
				-- Play this emote
				self.owner.components.playeremoter:DoEmote(closest_slot_index)
				-- Save it for next time too
				self.last_played_emote_slot_idx = closest_slot_index
			end
			self:CloseImmediately()
		end
	end
end

function PlayerEmoteRing:SetGamepadHotkeysShown(show_hotkeys)
	if self.hotkeys_shown ~= show_hotkeys then
		self.hotkeys_shown = show_hotkeys

		-- Update slots
		for k, slot in ipairs(self.slots_container.children) do
			slot:SetHotkeyShown(self.hotkeys_shown)
		end
	end
	return self
end

-- Sets the given slot to selected state, and all the others to non-selected
-- slot_index = -1 unselects all
function PlayerEmoteRing:SelectSlot(slot_index, skip_animation)

	for idx, slot in ipairs(self.slots_container.children) do
		slot:SetSelected(idx == slot_index, skip_animation)
	end

	return self
end

function PlayerEmoteRing:GetSelectedSlotIndex()
	for idx, slot in ipairs(self.slots_container.children) do
		if slot:IsSelected() then
			return idx
		end
	end
	return nil
end

function PlayerEmoteRing:GetSlot(slot_index)
	return self.slots_container.children[slot_index]
end

function PlayerEmoteRing:OnUpdate(dt)

	-- We're waiting to see if the player is holding the emote-key long enough to
	-- trigger the ring fading in, or if they'll release it and trigger the last emote
	if self.bar_state == RING_STATES.WAITING_FOR_FADE_IN then

		-- Decrease delay
		self.delay_until_fade_in = self.delay_until_fade_in - dt

		if self.delay_until_fade_in < 0 then
			-- The player held the button down. Animate the ring in
			self:FadeIn()
			self.active = true
		end
	end

	self:UpdateFocus()
	self:UpdatePosition()
end

function PlayerEmoteRing:_AddEmoteSlot(index)

	-- Calculate this slot's position and angle
	local angle = (index-1) * 45

    -- The angle that we'll use to compare to mouse or gamepad input angles
    local rad_angle = (angle - 90 + 360) % 360

	local x = math.sin(angle * DEGREES) * self.slot_position_radius
	local y = math.cos(angle * DEGREES) * self.slot_position_radius

	local w = self.slots_container:AddChild(PlayerEmoteQuadrant(index))
		:PrepareAnimation() -- Fades out the slot before an animation is triggered
		:SetPosition(x, y)
		:SetWidgetRotation(angle) -- Apparent rotation angle of the widget
		:SetSlotRadAngle(rad_angle)

	self.emote_slots[index] = w

end

return PlayerEmoteRing
