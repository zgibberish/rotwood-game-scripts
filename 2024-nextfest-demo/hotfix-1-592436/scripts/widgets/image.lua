local Widget = require "widgets/widget"
local UIHelpers = require "ui/uihelpers"

-- Accepts arguments two ways:
--   1) tex as a combined atlas+tex string: images/ui/white.tex
--	  default_tex as a fallback texture within the same atlas
--   2) tex as atlas, and default_tex as the tex: images/ui.xml, white.tex
local Image = Class(Widget, function(self, tex, default_tex)
	Widget._ctor(self, "Image")

	self.inst.entity:AddImageWidget()

	-- Don't modify values within these color tables!
	self.tint = WEBCOLORS.WHITE
	self.addcolor = WEBCOLORS.TRANSPARENT_BLACK

	if tex then
		self:SetTexture(tex, default_tex)
	end
end)

function Image:__tostring()
	return string.format("%s - %s:%s", self._widgetname, self.atlas or "", self.texture or "")
end

function Image:DebugDraw_AddSection(ui, panel)
	Image._base.DebugDraw_AddSection(self, ui, panel)
	local DebugPickers = require "dbui.debug_pickers"

	ui:Spacing()
	ui:Text("Image")
	ui:Indent() do
		-- Clearly show the bounds of blank and other hard-to-see
		-- images. (Great for debugging buttons.)
		local show_region = self.region_preview ~= nil
		local changed, show = ui:Checkbox("white out image region", show_region)
		if changed then
			if show then
				self.region_preview = self:AddChild(Image("images/white.tex"))
				self.region_preview:SetSize(self:GetSize())
			else
				self.region_preview:Kill()
				self.region_preview = nil
			end
		end

		-- SetTexture doesn't gracefully fail on bad input, so don't allow editing
		-- (we'd call SetTexture for every keystroke).
		local function image_from_atlastexture(label, atlastexture)
			ui:SetNextTreeNodeOpen(true, ui.Cond.Appearing)
			if ui:TreeNode(label ..": ".. tostring(atlastexture)) then
				if atlastexture then
					local parts = atlastexture:split()
					if #parts == 2 then
						ui:AtlasImage(parts[1], parts[2], self:GetSize())
					end
				end
				ui:TreePop()
			end
		end
		-- Building a string to parse it is ugly, but not uglier than handling two
		-- input types. Must pass empty text for nil so AtlasImage isn't called on
		-- invalid data!
		image_from_atlastexture("atlas:texture", string.format("%s:%s", self.atlas or "", self.texture or ""))
		image_from_atlastexture("mouse over texture", self.mouseovertex)
		image_from_atlastexture("disabled texture", self.disabledtex)


		local c = DebugPickers.Colour(ui, "additive", self.addcolor)
		if c then
			self:ApplyAddColor(c)
		end

		c = DebugPickers.Colour(ui, "tint", self.tint)
		if c then
			self:ApplyMultColor(c)
		end

		local w, h = self:GetSize()
		if w and h then
			changed, w, h = ui:DragFloat3("size", w, h, 0, 1, 1, 1000)
			if changed then
				self:SetSize(w, h)
				if self.region_preview then
					self.region_preview:SetSize(self:GetSize())
				end
			end
		end -- else texture is probably nil

		ui:SetNextTreeNodeOpen(true, ui.Cond.Appearing)
		if ui:TreeNode("SetBlendMode") then
			local current_blend = self.blend_mode or 0
			if ui:Selectable("Disabled", 0 == current_blend) then
				self:SetBlendMode(0)
			end
			for _,mode in ipairs(BlendMode:Ordered()) do
				local mode_id = BlendMode.id[mode]
				if ui:Selectable(mode, mode_id == current_blend) then
					self:SetBlendMode(mode_id)
				end
			end
			ui:TreePop()
		end
	end
	ui:Unindent()
end

function Image:SetAlphaRange(min, max)
	self.inst.ImageWidget:SetAlphaRange(min, max)
	return self
end

-- NOTE: the default_tex parameter lets you set a fallback if the input texture
-- isn't found, but it will produce a bunch of warnings in the log.
function Image:SetTexture(tex, default_tex)
	local atlas, checkatlas
	atlas,tex,checkatlas = GetAtlasTex(tex, default_tex)

	assert(atlas ~= nil)
	assert(tex ~= nil)

	self.atlas = (checkatlas and type(atlas) == "string" and resolvefilepath(atlas)) or atlas
	self.texture = tex
	--print(atlas, tex)
	self.inst.ImageWidget:SetTexture(0, self.atlas, self.texture, default_tex)

	-- changing the texture may have changed our metrics
	self.inst.UITransform:UpdateTransform()

	-- Update our width and height

	if atlas and tex then
		local w, h = self.inst.ImageWidget:GetSize()
		self.w, self.h = w, h
	end

	-- did we have a set size? if so re-apply it
	if self.size_x then
		local sx, sy = self.size_x, self.size_y
		self:SetSize(sx, sy, true)
	end
	return self
end

function Image:SetMouseOverTexture(atlas, tex)
	self.atlas = type(atlas) == "string" and resolvefilepath(atlas) or atlas
	self.mouseovertex = tex
	return self
end

function Image:SetDisabledTexture(atlas, tex)
	self.atlas = type(atlas) == "string" and resolvefilepath(atlas) or atlas
	self.disabledtex = tex
	return self
end

--function Image:SetSize(w,h)
--	if type(w) == "number" then
--		self.inst.ImageWidget:SetSize(w,h)
--	else
--		self.inst.ImageWidget:SetSize(w[1],w[2])
--	end
--end

function Image:GetSize()
	local w, h = self.inst.ImageWidget:GetSize()
	return w, h
end

function Image:ScaleToSize(w, h)
	local w0, h0 = self.inst.ImageWidget:GetSize()
	local scalex = w / w0
	local scaley = h / h0
	self:SetScale(scalex, scaley, 1)
	return self
end

function Image:SetFadeAlpha(a, skipChildren)
	if not self.can_fade_alpha then return end

	self.inst.ImageWidget:SetMultColor(self.tint[1], self.tint[2], self.tint[3], self.tint[4] * a)
	Widget.SetFadeAlpha(self, a, skipChildren)
	return self
end

function Image:SetVRegPoint(anchor)
	self.inst.ImageWidget:SetVAnchor(anchor)
	return self
end

function Image:SetHRegPoint(anchor)
	self.inst.ImageWidget:SetHAnchor(anchor)
	return self
end

function Image:OnMouseOver()
	--print("Image:OnMouseOver", self)
	if self.enabled and self.mouseovertex then
		self.inst.ImageWidget:SetTexture(self.atlas, self.mouseovertex)
	end
	Widget.OnMouseOver(self)
end

function Image:OnMouseOut()
	--print("Image:OnMouseOut", self)
	if self.enabled and self.mouseovertex then
		self.inst.ImageWidget:SetTexture(self.atlas, self.texture)
	end
	Widget.OnMouseOut(self)
end

function Image:OnEnable()
	if self.mouse_over_self then
		self:OnMouseOver()
	else
		self.inst.ImageWidget:SetTexture(self.atlas, self.texture)
	end
end

function Image:OnDisable()
	self.inst.ImageWidget:SetTexture(self.atlas, self.disabledtex)
end

function Image:SetEffect(filename)
	self.inst.ImageWidget:SetEffect(filename)

	if filename == "shaders/ui_cc.ksh" then
		--hack for faked ambient lighting influence (common_postinit, quagmire.lua)
		--might need to get the colour from the gamemode???
		--If we're going to use the ui_cc shader again, we'll have to have a more sane implementation for setting the ambient lighting influence
		self.inst.ImageWidget:SetEffectParams(0.784, 0.784, 0.784, 1)
	end
	return self
end

function Image:SetEffectParams(param1, param2, param3, param4)
	self.inst.ImageWidget:SetEffectParams(param1, param2, param3, param4)
	return self
end

function Image:EnableEffectParams(enabled)
	self.inst.ImageWidget:EnableEffectParams(enabled)
	return self
end

function Image:SetUVScale(xScale, yScale)
	self.inst.ImageWidget:SetUVScale(xScale, yScale)
	return self
end

-- Pass a mode id: SetBlendMode(BlendMode.id.Additive)
function Image:SetBlendMode(mode)
	self.blend_mode = mode
	self.inst.ImageWidget:SetBlendMode(mode)
	return self
end

------------------------------------------------- GL ---------------------------------------------------------

function Image:GetBoundingBox()
	local w, h = self:GetSize()
	if not w or not h then
		return 0, 0, 0, 0
	end
	return -w / 2, -h / 2, w / 2, h / 2
end

function Image:SetSize(dw, dh, forceUpdate)
	if self.size_x ~= dw or self.size_y ~= dh or forceUpdate then
		self.size_x = dw or self.w or 1
		self.size_y = dh or self.h or 1
		self.inst.ImageWidget:SetSize(self.size_x, self.size_y)
		self:InvalidateBBox()
	end
	return self
end

function Image:SetWidth_PreserveAspect(new_width, force_update)
	local w, h = self:GetSize()
	local new_height = h / w * new_width
	return self:SetSize(new_width, new_height, force_update)
end

function Image:GetSize()
	return self.size_x or self.w, self.size_y or self.h
end

function Image:ResetSize()
	if self.texture then
		self:SetSize(self.inst.ImageWidget:GetSize())
	end
	return self
end

-- Prefer Widget:SetMultColor since it blends with its parent's mult color.
function Image:ApplyMultColor(r, g, b, a)
	self.tint = type(r) == "number" and { r, g, b, a } or r
	self.inst.ImageWidget:SetMultColor(table.unpack(self.tint))
	return self
end

-- Prefer Widget:SetAddColor since it blends with its parent's mult color.
function Image:ApplyAddColor(r, g, b, a)
	self.addcolor = type(r) == "number" and { r, g, b, a } or r
	self.inst.ImageWidget:SetAddColor(table.unpack(self.addcolor))
	return self
end

function Image:ApplyHue(hue)
	self.inst.ImageWidget:SetHue(hue)
	return self
end

function Image:ApplySaturation(saturation)
	self.inst.ImageWidget:SetSaturation(saturation)
	return self
end

function Image:ApplyBrightness(brightness)
	self.inst.ImageWidget:SetBrightness(brightness)
	return self
end

-- This Image defines a mask for use with SetMasked. Only content within the
-- opaque area of the mask will be visible. See Widget:SetMasked.
function Image:SetMask()
	self.parent:SetStencilContext()
	self.inst.ImageWidget:SetColorWrite(false)
	self.inst.ImageWidget:SetEffect(global_shaders.UI_MASK)
	self:SetStencilWrite(STENCIL_MODES.SET)
	return self
end

function Image:SetMaskClear()
	self.inst.ImageWidget:SetColorWrite(false)
	self.inst.ImageWidget:SetEffect(global_shaders.UI_MASK)
	self:SetStencilWrite(STENCIL_MODES.CLEAR)
	return self
end

function Image:SetBlendMask(mask_atlas, mask_tex)
	self.inst.ImageWidget:SetEffect(global_shaders.UI_ALPHA_MASK)
	self.inst.ImageWidget:SetTexture(1, mask_atlas, mask_tex)
	self:SetBlendParams(0, 1, 0, 1)
	self.inst.ImageWidget:SetEffectParams(0, 1, 1, 0)
	return self
end

-- This only works in tandem with SetBlendMask
function Image:SetBlendParams(min, max, mult, add)
	self.inst.ImageWidget:SetEffectParams(min, max, mult, add)
end

function Image:SetBrightnessMap(gradient_tex, intensity)
	UIHelpers.SetBrightnessMapNative(self.inst.ImageWidget, gradient_tex, intensity)
	return self
end

return Image
