local Widget = require "widgets/widget"
local Text = require "widgets/text"
local fmodtable = require "defs.sound.fmodtable"

-- Base class for imagebuttons and animbuttons.
local Button = Class(Widget, function(self)
	Widget._ctor(self, "Button")

	self:SetHoverCheck(true)
	self:SetNavFocusable()

	self.font = FONTFACE.DEFAULT
	self.fontdisabled = FONTFACE.DEFAULT

	self.textcolour = {0,0,0,1}
	self.textfocuscolour = {0,0,0,1}
	self.textdisabledcolour = {0,0,0,1}
	self.textselectedcolour = {0,0,0,1}

	self.text = self:AddChild(Text(self.font, FONTSIZE.BUTTON))
	self.text:SetVAlign(ANCHOR_MIDDLE)
	self:_UpdateTextColour(self.textcolour)
	self.text:Hide()

	self.clickoffset = Vector3(0,-3,0) * HACK_FOR_4K

	self.selected = false

	self.control = Controls.Digital.ACCEPT
	self.alt_control = Controls.Digital.CLICK_SECONDARY

	self.help_message = STRINGS.UI.HELP.SELECT

	self:SetGainFocusSound(fmodtable.Event.hover)
end)

function Button:DebugDraw_AddSection(ui, panel)
	Button._base.DebugDraw_AddSection(self, ui, panel)

	ui:Spacing()
	ui:Text("Button")
	ui:Indent()
	do
		ui:Value("IsSelected", self:IsSelected())
		ui:Value("IsEnabled", self:IsEnabled())

		local changed,r,g,b,a
		changed,r,g,b,a = ui:ColorEdit4("textcolour        ", table.unpack(self.textcolour))
		if changed then
			self:SetTextColour(r,g,b,a)
		end
		changed,r,g,b,a = ui:ColorEdit4("textfocuscolour   ", table.unpack(self.textfocuscolour))
		if changed then
			self:SetTextFocusColour(r,g,b,a)
		end
		changed,r,g,b,a = ui:ColorEdit4("textdisabledcolour", table.unpack(self.textdisabledcolour))
		if changed then
			self:SetTextDisabledColour(r,g,b,a)
		end
		changed,r,g,b,a = ui:ColorEdit4("textselectedcolour", table.unpack(self.textselectedcolour))
		if changed then
			self:SetTextSelectedColour(r,g,b,a)
		end
	end
	ui:Unindent()
end

function Button:SetControl(ctrl)
	if ctrl then
		self.control = ctrl
	end
	return self
end

function Button:OnControl(controls, down, device_type, trace, device_id)
	if Button._base.OnControl(self, controls, down, device_type, trace, device_id) then return true end

	if not self:IsEnabled() or not self.focus then return false end

	if self:IsSelected() and not self.AllowOnControlWhenSelected then return false end

	if controls:Has(self.control) then

		if down then
			if not self.down then
				if self.controldown_sound then
					TheFrontEnd:GetSound():PlaySound(self.controldown_sound)
				end
				self.o_pos = self:GetLocalPosition()
				self:SetPosition(self.o_pos + self.clickoffset)
				self.down = true
				if self.whiledown then
					self:StartUpdating()
				end
				if self.ondown then
					self.ondown()
				end
			end
		else
			if self.down then
				self.down = false
				if self.controlup_sound then
					TheFrontEnd:GetSound():PlaySound(self.controlup_sound)
				end

				self:ResetPreClickPosition()
				if self.onup then
					self.onup()
				end
				self:Click(device_type, device_id)
				self:StopUpdating()
			end
		end

		return true
	end

	if controls:Has(self.alt_control) then

		if down then
			if not self.down then
				if self.altcontroldown_sound then
					TheFrontEnd:GetSound():PlaySound(self.altcontroldown_sound)
				end

				self.o_pos = self:GetLocalPosition()
				self:SetPosition(self.o_pos + self.clickoffset)
				self.down = true
				if self.whiledown then
					self:StartUpdating()
				end
				if self.ondown_alt then
					self.ondown_alt()
				end
			end
		else
			if self.down then
				self.down = false
				if self.altcontrolup_sound then
					TheFrontEnd:GetSound():PlaySound(self.altcontrolup_sound)
				end

				self:ResetPreClickPosition()
				if self.onup_alt then
					self.onup_alt()
				end
				self:ClickAlt(device_type, device_id)
				self:StopUpdating()
			end
		end

		return true
	end

end

-- Will only run if the button is manually told to start updating: we don't want a bunch of unnecessarily updating widgets
function Button:OnUpdate(dt)
	if self.down then
		if self.whiledown then
			self.whiledown()
		end
	end
end

function Button:OnGainFocus()
	Button._base.OnGainFocus(self)

	if self:IsEnabled() and not self.selected and TheFrontEnd:GetFadeLevel() <= 0 then
		if self.text then self:_UpdateTextColour(self.textfocuscolour) end

		if self.gainfocus_sound then
			TheFrontEnd:GetSound():PlaySound(self.gainfocus_sound)
		end
	end
end

function Button:ResetPreClickPosition()
	if self.o_pos then
		self:SetPosition(self.o_pos)
		self.o_pos = nil
	end
	return self
end

function Button:OnLoseFocus()
	Button._base.OnLoseFocus(self)

	if self:IsEnabled() and not self.selected then
		self:_UpdateTextColour(self.textcolour)
	end
	self:ResetPreClickPosition()

	self.down = false

	if self.onup then
		self.onup()
	end
	if self.onlosefocus then
		self.onlosefocus(self:IsEnabled())
	end
end

function Button:OnEnable()
	if not self.focus and not self.selected then --Note(Peter):This causes the disabled font to remain on an enabled text button, if it has focus (EG: When you click on a button and the button is temporarily disabled). Why do we check the focus here?
		self:_UpdateTextColour(self.textcolour)
		self.text:SetFont(self.font)
	end
end

function Button:OnDisable()
	self:_UpdateTextColour(self.textdisabledcolour)
	self.text:SetFont(self.fontdisabled)
end

-- Calling "Select" on a button makes it behave as if it were disabled (i.e.
-- won't respond to being clicked), but will still be able to be focused by the
-- mouse or controller. The original use case for this was the page navigation
-- buttons: when you click a button to navigate to a page, you select that page
-- and, because you're already on that page, the button for that page becomes
-- unable to be clicked. But because fully disabling the button creates
-- weirdness when navigating with a controller (disabled widgets can't be
-- focused), we have this new state, Selected.
--
-- NB: For image buttons, you need to set the image_selected variable. Best
-- practice is for this to be the same texture as disabled.
function Button:Select()
	self.selected = true
	self:OnSelect()
	return self
end

-- This is roughly equivalent to calling Enable after calling Disable--it
-- cancels the Selected state. An unselected button will behave normally.
function Button:Unselect()
	self.selected = false
	self:OnUnselect()
	return self
end

-- This is roughly equivalent to OnDisable
function Button:OnSelect()
	self:_UpdateTextColour(self.textselectedcolour)
	if self.onselect then
		self.onselect()
	end
end

-- This is roughly equivalent to OnEnable
function Button:OnUnselect()
	if self:IsEnabled() then
		if self.focus then
			if self.text then
				self:_UpdateTextColour(self.textfocuscolour[1],self.textfocuscolour[2],self.textfocuscolour[3],self.textfocuscolour[4])
			end
		else
			self:LoseFocus()
		end
	else
		self:OnDisable()
	end
	if self.onunselect then
		self.onunselect()
	end
end

function Button:IsSelected()
	return self.selected
end

function Button:SetSelected(selected)
	if selected then self:Select() else self:Unselect() end
	return self
end


-- Highlight is for making a button look hovered or selected but doesn't change
-- the button's behaviour. Useful when you want a button to look selected when
-- you first click on it and then activate an action when you click on it
-- again. It doesn't change the button appearance on its own: you need to do
-- that in SetOnHighlight.
function Button:SetHighlighted(highlighted)
	if highlighted then
		self:Highlight()
	else
		self:Unhighlight()
	end
	return self
end

function Button:Highlight()
	self.highlighted = true
	self:OnHighlight()
	return self
end

function Button:Unhighlight()
	self.highlighted = false
	self:OnUnhighlight()
	return self
end

function Button:OnHighlight()
	assert(self.onhighlight, "You must implement highlight callbacks for highlight to have any effect.")
	self.onhighlight()
end

function Button:OnUnhighlight()
	assert(self.onhighlight, "You must implement highlight callbacks for highlight to have any effect.")
	self.onunhighlight()
end

function Button:IsHighlighted()
	return self.highlighted
end


--- Triggers a click if there is a callback
function Button:Click(device_type, device_id)
	if self.onclick then
		self.onclick(device_type, device_id)
	end
	return self
end

function Button:SetOnClickFn( fn )
	self.onclick = fn
	return self
end

-- shim
function Button:SetOnClick( fn )
	return self:SetOnClickFn(fn)
end

function Button:ClickAlt(device_type, device_id)
	if self.onclick_alt then
		self.onclick_alt(device_type, device_id)
	end
	return self
end

function Button:SetOnClickAltFn( fn )
	self.onclick_alt = fn
	return self
end

-- shim
function Button:SetOnClickAlt( fn )
	return self:SetOnClickAltFn(fn)
end

function Button:SetOnSelect( fn )
	self.onselect = fn
	return self
end

function Button:SetOnUnSelect( fn )
	self.onunselect = fn
	return self
end

function Button:SetOnHighlight(fn)
	self.onhighlight = fn
	return self
end

function Button:SetOnUnHighlight(fn)
	self.onunhighlight = fn
	return self
end

function Button:SetOnDown( fn )
	self.ondown = fn
	return self
end

function Button:SetOnUp( fn )
	self.onup = fn
	return self
end

function Button:SetWhileDown( fn )
	self.whiledown = fn
	return self
end

function Button:SetFont(font)
	self.font = font
	if self:IsEnabled() then
		self.text:SetFont(font)
		if self.text_shadow then
			self.text_shadow:SetFont(font)
		end
	end
	return self
end

function Button:SetDisabledFont(font)
	self.fontdisabled = font
	if not self:IsEnabled() then
		self.text:SetFont(font)
		if self.text_shadow then
			self.text_shadow:SetFont(font)
		end
	end
	return self
end

function Button:HasText()
	return self.text:IsShown()
end

function Button:_UpdateTextColour(r,g,b,a)
	self.text:SetGlyphColor(r,g,b,a)
	return self
end

function Button:SetTextColour(r,g,b,a)
	if type(r) == "number" then
		self.textcolour = {r,g,b,a}
	else
		self.textcolour = r
	end

	if self:IsEnabled() and not self.focus and not self.selected then
		self:_UpdateTextColour(self.textcolour)
	end
	return self
end

function Button:SetTextFocusColour(r,g,b,a)
	if type(r) == "number" then
		self.textfocuscolour = {r,g,b,a}
	else
		self.textfocuscolour = r
	end

	if self.focus and not self.selected then
		self:_UpdateTextColour(self.textfocuscolour)
	end
	return self
end

function Button:SetTextDisabledColour(r,g,b,a)
	if type(r) == "number" then
		self.textdisabledcolour = {r,g,b,a}
	else
		self.textdisabledcolour = r
	end

	if not self:IsEnabled() then
		self:_UpdateTextColour(self.textdisabledcolour)
	end
	return self
end

function Button:SetTextSelectedColour(r,g,b,a)
	if type(r) == "number" then
		self.textselectedcolour = {r,g,b,a}
	else
		self.textselectedcolour = r
	end

	if self.selected then
		self:_UpdateTextColour(self.textselectedcolour)
	end
	return self
end

function Button:SetTextSize(sz)
	self.size = sz
	self.text:SetFontSize(sz)
	if self.text_shadow then self.text_shadow:SetFontSize(sz) end
	return self
end

function Button:OverrideLineHeight(height)
	self.text:OverrideLineHeight(height)
	return self
end

function Button:GetText()
	return self.text:GetText()
end

function Button:SetText(msg, dropShadow, dropShadowOffset)
	if msg then
		self:SetName(msg and ("button:"..msg) or "button")
		self.text:SetText(msg)
		self.text:Show()
		if self:IsEnabled() then
			self:_UpdateTextColour(self.selected and self.textselectedcolour or (self.focus and self.textfocuscolour or self.textcolour))
		else
			self:_UpdateTextColour(self.textdisabledcolour)
		end

		if dropShadow then
			if self.text_shadow == nil then
				self.text_shadow = self:AddChild(Text(self.font, self.size or FONTSIZE.BUTTON))
				self.text_shadow:SetVAlign(ANCHOR_MIDDLE)
				self.text_shadow:SetGlyphColor(.1,.1,.1,1)
				local offset = dropShadowOffset or {-4, -4}
				self.text_shadow:SetPosition(offset[1], offset[2])
				self.text:MoveToFront()
			end
			self.text_shadow:SetText(msg)
		end
	else
		self.text:Hide()
		if self.text_shadow then self.text_shadow:Hide() end
	end
	return self
end

function Button:RefreshText()
	self.text:RefreshText()
	return self
end

function Button:SetHelpTextMessage(str)
	if str then
		self.help_message = str
	end
	return self
end

function Button:SetBrightnessMap(gradient_tex, intensity)
	if self.text then
		self.text:SetBrightnessMap(gradient_tex, intensity)
	end
	if self.image then
		-- ImageButton
		self.image:SetBrightnessMap(gradient_tex, intensity)
	end
	if self.background then
		--ActionButton
		self.background:SetBrightnessMap(gradient_tex, intensity)
	end
	return self
end

return Button
