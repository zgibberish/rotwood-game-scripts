local Button = require "widgets.button"
local Image = require "widgets.image"
local Panel = require "widgets.panel"
local easing = require "util.easing"
local fmodtable = require "defs.sound.fmodtable"

local PanelButton = Class(Button, function(self, normal, focus, disabled, down, selected, scale, offset)
    Button._ctor(self, "PanelButton")

    self.scaleFocus = 1.05
    self.scaleNormal = scale or 1
    
    self.scaleOnFocus = true
    self.move_on_click = true

    self.image = self:AddChild(Panel())
    self.image:MoveToBack()

    self:SetTextures( normal, focus, disabled, down, selected, offset )
end)

function PanelButton.FromAtlasTex(atlas, normal, focus, disabled, down, selected, scale, offset)
	local atlas_no_suffix = atlas:gsub('%.xml', '')
	normal   = ("%s/%s"):format(atlas_no_suffix, normal)
	focus    = ("%s/%s"):format(atlas_no_suffix, focus)
	disabled = ("%s/%s"):format(atlas_no_suffix, disabled)
	down     = ("%s/%s"):format(atlas_no_suffix, down)
	selected = ("%s/%s"):format(atlas_no_suffix, selected)
	return PanelButton(normal, focus, disabled, down, selected, scale, offset)
end

function PanelButton:DebugDraw_AddSection(ui, panel)
    PanelButton._base.DebugDraw_AddSection(self, ui, panel)

    ui:Spacing()
    ui:Text("PanelButton")
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

function PanelButton:ForceImageSize(x, y)
	self.image:SetSize(x, y)
	return self
end

function PanelButton:SetSize(x, y)
	self.image:SetSize(x, y)
	return self
end

function PanelButton:GetImageWidget()
	return self.image
end

function PanelButton:SetTextures(normal, focus, disabled, down, selected, image_offset)
	local default_textures = false

	if not normal then
		normal = normal or "images/ui_ftf/button_red.tex"
		focus = focus or "images/ui_ftf/button_yellow.tex"
		disabled = disabled or "images/ui_ftf/button_grey.tex"
		down = down or "images/ui_ftf/button_grey.tex"
		selected = selected or "images/ui_ftf/button_orange.tex"
		default_textures = true
	end
	assert(not normal:find('%.xml$'), "PanelButton no longer supports an atlas with names. Try PanelButton.FromAtlasTex() instead.")

	self.image_normal = normal
	self.image_focus = focus or self.image_normal
	self.image_disabled = disabled or self.image_normal
	self.image_down = down or self.image_focus
	self.image_selected = selected or self.image_focus
	self.has_image_down = down ~= nil

	local scale = 1
	local offset = {0, 0}
	if not default_textures then
		scale = 1
		offset = {0, 0}
	end
	offset = image_offset or offset
	self.image_scale = scale
	self.image_offset = offset
	self.image:SetPosition(self.image_offset[1], self.image_offset[2])
	self.image:SetScale(self.scaleNormal)

	self:_RefreshImageState()
	return self
end

function PanelButton:_RefreshImageState()
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

-- in pixels from top left
function PanelButton:SetNineSliceCoords(minx, miny, maxx, maxy)
	self.image:SetNineSliceCoords(minx, miny, maxx, maxy)
	return self
end

function PanelButton:SetNineSliceBorderScale(scale)
	self.image:SetNineSliceBorderScale(scale)
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
function PanelButton:UseFocusOverlay(focus_selected_texture)
	if not self.hover_overlay then
		self.hover_overlay = self.image:AddChild(Image())
	end
	self.hover_overlay:SetTexture(focus_selected_texture)
	self.hover_overlay:Hide()
	self:_RefreshImageState()
	return self
end

function PanelButton:OnGainFocus()
	PanelButton._base.OnGainFocus(self)

	if self.hover_overlay then
		self.hover_overlay:Show()
	end

	if self:IsEnabled() then
		self.image:SetTexture(self.image_focus)
	end

	if self.scaleOnFocus then
		self.image:ScaleTo(nil, self.scaleFocus, 0.1, easing.inOutQuad)
	end

	if self.selected and self.imageselectedcolour then
		self.image:SetMultColor(self.imageselectedcolour[1], self.imageselectedcolour[2], self.imageselectedcolour[3], self.imageselectedcolour[4])
	end

	if self.imagefocuscolour then
		self.image:SetMultColor(table.unpack(self.imagefocuscolour))
	end

	if self.gainfocus_sound then
		TheFrontEnd:GetSound():PlaySound(self.gainfocus_sound)
	end
end

function PanelButton:OnLoseFocus()
	PanelButton._base.OnLoseFocus(self)

	if self.hover_overlay then
		self.hover_overlay:Hide()
	end

	if self:IsEnabled() then
		self.image:SetTexture(self.image_normal)
	end

	if self.scaleOnFocus then
		self.image:ScaleTo(nil, self.scaleNormal, 0.2, easing.inOutQuad)
	end

	if self.imagenormalcolour then
		self.image:SetMultColor(self.imagenormalcolour[1], self.imagenormalcolour[2], self.imagenormalcolour[3], self.imagenormalcolour[4])
	end

	if self.selected and self.imageselectedcolour then
		self.image:SetMultColor(self.imageselectedcolour[1], self.imageselectedcolour[2], self.imageselectedcolour[3], self.imageselectedcolour[4])
	end
end

function PanelButton:HandleControlDown(controls)
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
end

function PanelButton:HandleControlUp(controls)
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
			if self.onclick then
				self.onclick()
			end
			self:StopUpdating()
		end
		return true
	end
end

function PanelButton:OnEnable()
	PanelButton._base.OnEnable(self)
	if self.focus then
		self:GainFocus()
	else
		self:LoseFocus()
	end
end

function PanelButton:OnDisable()
	PanelButton._base.OnDisable(self)
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
function PanelButton:OnSelect()
	PanelButton._base.OnSelect(self)

	self.image:SetTexture(self.image_selected)
	if self.imageselectedcolour then
		self.image:SetMultColor(table.unpack(self.imageselectedcolour))
	end
end

-- This is roughly equivalent to OnEnable--it's what happens when canceling the Selected state. An unselected button will behave normally.
function PanelButton:OnUnselect()
	PanelButton._base.OnUnselect(self)
	if self:IsEnabled() then
		self:OnEnable()
	else
		self:OnDisable()
	end
end

function PanelButton:GetSize()
	return self.image:GetSize()
end

function PanelButton:SetScaleOnFocus(scale)
	self.scaleOnFocus = scale
	return self
end

function PanelButton:SetFocusScale(scale)
	self.scaleFocus = scale or 1.2

	if self.focus and self.scaleOnFocus and not self.selected then
		self.image:ScaleTo(nil, self.scaleFocus, 0.1, easing.inOutQuad)
	end
	return self
end

function PanelButton:SetNormalScale(scale)
	self.scaleNormal = scale or 1

	if not self.focus and self.scaleOnFocus then
		self.image:ScaleTo(nil, self.scaleNormal, 0.2, easing.inOutQuad)
	end
	return self
end

function PanelButton:SetImageNormalColour(r,g,b,a)
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

function PanelButton:SetImageFocusColour(r,g,b,a)
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

function PanelButton:SetImageDisabledColour(r,g,b,a)
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

function PanelButton:SetImageSelectedColour(r,g,b,a)
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

return PanelButton
