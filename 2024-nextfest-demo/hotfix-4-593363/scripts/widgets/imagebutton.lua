local Button = require "widgets.button"
local Image = require "widgets.image"
local easing = require "util.easing"


local ImageButton = Class(Button, function(self, normal, focus, disabled, down, selected, scale, offset)
	Button._ctor(self, "ImageButton")

	self.focus_scale = {1.2, 1.2, 1.2}
	self.normal_scale = {1, 1, 1}

	self.scale_on_focus = true
	self.move_on_click = true

	self.image = self:AddChild(Image())
	self.image:MoveToBack()

	self:SetTextures( normal, focus, disabled, down, selected, scale, offset )
end)


function ImageButton.FromAtlasTex(atlas, normal, focus, disabled, down, selected, scale, offset)
	local atlas_no_suffix = atlas:gsub('%.xml', '')
	normal   = ("%s/%s"):format(atlas_no_suffix, normal)
	focus    = ("%s/%s"):format(atlas_no_suffix, focus)
	disabled = ("%s/%s"):format(atlas_no_suffix, disabled)
	down     = ("%s/%s"):format(atlas_no_suffix, down)
	selected = ("%s/%s"):format(atlas_no_suffix, selected)
	return ImageButton(normal, focus, disabled, down, selected, scale, offset)
end

function ImageButton:DebugDraw_AddSection(ui, panel)
	ImageButton._base.DebugDraw_AddSection(self, ui, panel)

	ui:Spacing()
	ui:Text("ImageButton")
	ui:Indent() do
		local changed,r,g,b,a = ui:ColorEdit4("imagenormalcolour  ", table.unpack(self.imagenormalcolour   or {0,0,0,0}))
		if changed then
			self:SetImageNormalColour(r,g,b,a)
		end
		local changed,r,g,b,a = ui:ColorEdit4("imagefocuscolour   ", table.unpack(self.imagefocuscolour    or {0,0,0,0}))
		if changed then
			self:SetImageFocusColour(r,g,b,a)
		end
		local changed,r,g,b,a = ui:ColorEdit4("imagedisabledcolour", table.unpack(self.imagedisabledcolour or {0,0,0,0}))
		if changed then
			self:SetImageDisabledColour(r,g,b,a)
		end
		local changed,r,g,b,a = ui:ColorEdit4("imageselectedcolour", table.unpack(self.imageselectedcolour or {0,0,0,0}))
		if changed then
			self:SetImageSelectedColour(r,g,b,a)
		end
	end
	ui:Unindent()
end

function ImageButton:ForceImageSize(x, y)
	self.image:SetSize(x, y)
	return self
end

function ImageButton:SetSize(x, y)
	self.image:SetSize(x, y)
	return self
end

function ImageButton:SetTextures(normal, focus, disabled, down, selected, image_scale, image_offset)
	local default_textures = false

	if not normal then
		normal = normal or "images/ui_ftf/button_red.tex"
		focus = focus or "images/ui_ftf/button_yellow.tex"
		disabled = disabled or "images/ui_ftf/button_grey.tex"
		down = down or "images/ui_ftf/button_grey.tex"
		selected = selected or "images/ui_ftf/button_orange.tex"
		default_textures = true
	end
	assert(not normal:find('%.xml$'), "ImageButton no longer supports an atlas with names. Try ImageButton.FromAtlasTex() instead.")

	self.image_normal = normal
	self.image_focus = focus or self.image_normal
	self.image_disabled = disabled or self.image_normal
	self.image_down = down or self.image_focus
	self.image_selected = selected or self.image_focus
	self.has_image_down = down ~= nil

	local scale = {1, 1}
	local offset = {0, 0}
	if not default_textures then
		scale = {1, 1}
		offset = {0, 0}
	end
	scale = image_scale or self.normal_scale or scale
	offset = image_offset or offset
	self.image_scale = scale
	self.image_offset = offset
	self.image:SetPosition(self.image_offset[1], self.image_offset[2])
	self.image:SetScale(self.image_scale[1], self.image_scale[2] or self.image_scale[1])

	self:_RefreshImageState()
	return self
end

function ImageButton:_RefreshImageState()
	if self:IsSelected() then
		self:OnSelect()
	elseif self:IsEnabled() then
		if self.focus then
			self:GainFocus()
		else
			self:LoseFocus()
		end
	else
		self:OnDisable()
	end
	return self
end

-- Apply a focus overlay to all image states.
--
-- Instead (or in addition to) having a focus image state, add a focus overlay
-- that's drawn on top of our image state when focus. This overlay is drawn
-- even when button is selected or disabled. Prevents focus from disappearing
-- when passing over selected items (essential on gamepad).
--
-- Common bug: you probably want scale_on_focus = false or customize scaling.
function ImageButton:UseFocusOverlay(focus_selected_texture)
	if not self.hover_overlay then
		self.hover_overlay = self.image:AddChild(Image())
	end
	self.hover_overlay:SetTexture(focus_selected_texture)
	self.hover_overlay:Hide()
	self:_RefreshImageState()
	return self
end

function ImageButton:OnGainFocus()
	ImageButton._base.OnGainFocus(self)

	if self.hover_overlay then
		self.hover_overlay:Show()
	end

	if self:IsSelected() then return end

	if self:IsEnabled() then
		self.image:SetTexture(self.image_focus)
	end

	if self.image_focus == self.image_normal and self.scale_on_focus and self.focus_scale then
		self.image:ScaleTo(nil, self.focus_scale[1], 0.1, easing.outQuad)
	end

	if self.imagefocuscolour then
		self.image:SetMultColor(table.unpack(self.imagefocuscolour))
	end

	if self.selected and self.imageselectedcolour then
		self.image:SetMultColor(self.imageselectedcolour[1], self.imageselectedcolour[2], self.imageselectedcolour[3], self.imageselectedcolour[4])
	end

	if self.gainfocus_sound then
		TheFrontEnd:GetSound():PlaySound(self.gainfocus_sound)
	end
end

function ImageButton:OnLoseFocus()
	ImageButton._base.OnLoseFocus(self)

	if self.hover_overlay then
		self.hover_overlay:Hide()
	end

	if self:IsSelected() then return end

	if self:IsEnabled() then
		self.image:SetTexture(self.image_normal)
	end

	if self.image_focus == self.image_normal and self.scale_on_focus and self.normal_scale then
		self.image:ScaleTo(nil, self.normal_scale[1], 0.15, easing.outQuad)
	end

	if self.imagenormalcolour then
		self.image:SetMultColor(self.imagenormalcolour[1], self.imagenormalcolour[2], self.imagenormalcolour[3], self.imagenormalcolour[4])
	end

	if self.selected and self.imageselectedcolour then
		self.image:SetMultColor(self.imageselectedcolour[1], self.imageselectedcolour[2], self.imageselectedcolour[3], self.imageselectedcolour[4])
	end
end

function ImageButton:HandleControlDown(controls)
	if not self:IsEnabled() or not self.focus then return end

	if self:IsSelected() and not self.AllowOnControlWhenSelected then return false end

	if controls:Has(self.control) then
		if not self.down then
			if self.has_image_down then
				self.image:SetTexture(self.image_down)
			end

			if self.controldown_sound then
				TheFrontEnd:GetSound():PlaySound(self.controldown_sound)
			end

			self.o_pos = self:GetLocalPosition()
			if self.move_on_click then
				self:SetPosition(self.o_pos + self.clickoffset)
			end
			self.down = true
			if self.whiledown then
				self:StartUpdating()
			end
			if self.ondown then
				self.ondown()
			end
		end
		return true
	end

	if controls:Has(self.alt_control) then
		if not self.down then
			if self.has_image_down then
				self.image:SetTexture(self.image_down)
			end

			if self.controldown_sound then
				TheFrontEnd:GetSound():PlaySound(self.controldown_sound)
			end

			self.o_pos = self:GetLocalPosition()
			if self.move_on_click then
				self:SetPosition(self.o_pos + self.clickoffset)
			end
			self.down = true
			if self.whiledown then
				self:StartUpdating()
			end
			if self.ondown_alt then
				self.ondown_alt()
			end
		end
		return true
	end
end

function ImageButton:HandleControlUp(controls, device_type, trace, device_id)
	if not self:IsEnabled() or not self.focus then return end

	if self:IsSelected() and not self.AllowOnControlWhenSelected then return false end

	if controls:Has(self.control) then
		if self.down then
			if self.has_image_down then
				self.image:SetTexture(self.image_focus)
			end

			if self.controlup_sound then
				TheFrontEnd:GetSound():PlaySound(self.controlup_sound)
			end

			self.down = false
			self:ResetPreClickPosition()
			self:Click(device_type, device_id)
			self:StopUpdating()
		end
		return true
	end

	if controls:Has(self.alt_control) then
		if self.down then
			if self.has_image_down then
				self.image:SetTexture(self.image_focus)
			end

			if self.controlup_sound then
				TheFrontEnd:GetSound():PlaySound(self.controlup_sound)
			end

			self.down = false
			self:ResetPreClickPosition()
			self:ClickAlt(device_type, device_id)
			self:StopUpdating()
		end
		return true
	end

end

function ImageButton:OnEnable()
	ImageButton._base.OnEnable(self)
	if self.focus then
		self:GainFocus()
	else
		self:LoseFocus()
	end
end

function ImageButton:OnDisable()
	ImageButton._base.OnDisable(self)
	self.image:SetTexture(self.image_disabled)

	if self.imagedisabledcolour then
		self.image:SetMultColor(table.unpack(self.imagedisabledcolour))
	end
end

-- This is roughly equivalent to OnDisable.
-- Calling "Select" on a button makes it behave as if it were disabled (i.e. won't respond to being clicked), but will still be able
-- to be focused by the mouse or controller. The original use case for this was the page navigation buttons: when you click a button
-- to navigate to a page, you select that page and, because you're already on that page, the button for that page becomes unable to
-- be clicked. But because fully disabling the button creates weirdness when navigating with a controller (disabled widgets can't be
-- focused), we have this new state, Selected.
-- NB: For image buttons, you need to set the image_selected variable. Best practice is for this to be the same texture as disabled.
function ImageButton:OnSelect()
	ImageButton._base.OnSelect(self)

	self.image:SetTexture(self.image_selected)
	if self.imageselectedcolour then
		self.image:SetMultColor(table.unpack(self.imageselectedcolour))
	end
end

-- This is roughly equivalent to OnEnable--it's what happens when canceling the Selected state. An unselected button will behave normally.
function ImageButton:OnUnselect()
	ImageButton._base.OnUnselect(self)
	if self:IsEnabled() then
		self:OnEnable()
	else
		self:OnDisable()
	end
end

function ImageButton:GetImage()
	return self.image
end

function ImageButton:GetSize()
	return self.image:GetSize()
end

function ImageButton:SetScaleOnFocus(scale_on_focus)
	self.scale_on_focus = scale_on_focus
	return self
end

function ImageButton:SetMoveOnClick(move_on_click)
	self.move_on_click = move_on_click
	return self
end

function ImageButton:SetFocusScale(scaleX, scaleY, scaleZ)
	if type(scaleX) == "number" then
		self.focus_scale = {scaleX, scaleY or scaleX, scaleZ or 1}
	else
		self.focus_scale = {scaleX, scaleX, scaleX}
	end

	if self.focus and self.scale_on_focus and not self.selected then
		self.image:ScaleTo(nil, self.focus_scale[1], 0.1, easing.outQuad)
	end
	return self
end

function ImageButton:SetNormalScale(scaleX, scaleY, scaleZ)
	if type(scaleX) == "number" then
		self.normal_scale = {scaleX, scaleY or scaleX, scaleZ or 1}
	else
		self.normal_scale = {scaleX, scaleX, scaleX}
	end

	if not self.focus and self.scale_on_focus then
		self.image:ScaleTo(nil, self.normal_scale[1], 0.15, easing.outQuad)
	end
	return self
end

function ImageButton:SetImageNormalColour(r,g,b,a)
	if type(r) == "number" then
		self.imagenormalcolour = {r, g, b, a}
	else
		self.imagenormalcolour = r
	end

	if self:IsEnabled() and not self.focus and not self.selected then
		self.image:SetMultColor(self.imagenormalcolour[1], self.imagenormalcolour[2], self.imagenormalcolour[3], self.imagenormalcolour[4])
	end
	return self
end

function ImageButton:SetImageFocusColour(r,g,b,a)
	if type(r) == "number" then
		self.imagefocuscolour = {r,g,b,a}
	else
		self.imagefocuscolour = r
	end

	if self.focus and not self.selected then
		self.image:SetMultColor(table.unpack(self.imagefocuscolour))
	end
	return self
end

function ImageButton:SetImageDisabledColour(r,g,b,a)
	if type(r) == "number" then
		self.imagedisabledcolour = {r,g,b,a}
	else
		self.imagedisabledcolour = r
	end

	if not self:IsEnabled() then
		self.image:SetMultColor(table.unpack(self.imagedisabledcolour))
	end
	return self
end

function ImageButton:SetImageSelectedColour(r,g,b,a)
	if type(r) == "number" then
		self.imageselectedcolour = {r,g,b,a}
	else
		self.imageselectedcolour = r
	end

	if self.selected then
		self.image:SetMultColor(table.unpack(self.imageselectedcolour))
	end
	return self
end

return ImageButton
