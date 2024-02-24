local Widget = require "widgets/widget"
local UIHelpers = require "ui/uihelpers"

local assets =
{
	panel_bg = {"images/9slice/roundbox.tex",30,30,70,70},
}


local Panel = Class( Widget, function(self, tex, dw, dh, innerpw, innerph)
	Widget._ctor(self, "Panel")

	self.model = self.inst.entity:AddNineSlice()

	self.model:SetEffect(global_shaders.UI)
	if innerpw and innerph then
		self.model:SetInteriorPercent(innerpw, innerph)
	end

	self:SetBlocksMouse(true)

	if tex then
		self:SetTexture(tex)
	else
		self:SetNineSlice(assets.panel_bg)
	end

	if dw and dh then
		self:SetInnerSize(dw, dh)
	end
end)


function Panel:SetEffect(effect)
	self.model:SetEffect(effect)
end

function Panel:__tostring()
	return string.format("Panel Widget (%2.2fx%2.2f)", self:GetSize())
end

function Panel:DebugDraw_AddSection(ui, panel)
	Panel._base.DebugDraw_AddSection(self, ui, panel)
	local DebugPickers = require "dbui.debug_pickers"

	ui:Spacing()
	ui:Text("Panel")
	ui:Indent() do

		-- We don't store atlas/texture or have any way to retrieve it, so don't do anything for now.
		--~ -- SetTexture doesn't gracefully fail on bad input, so don't allow editing
		--~ -- (we'd call SetTexture for every keystroke).
		--~ ui:SetNextTreeNodeOpen(true, ui.Cond.Appearing)
		--~ if ui:TreeNode(("texture: %s/%s"):format(self.atlas, self.texture)) then
		--~ 	if self.atlas then
		--~ 		ui:AtlasImage(self.atlas, self.texture, self:GetSize())
		--~ 	end
		--~ 	ui:TreePop()
		--~ end

		local colour = DebugPickers.Colour(ui, "mult color", self.tint or WEBCOLORS.WHITE)
		if colour then
			self:ApplyMultColor(colour)
		end

		colour = DebugPickers.Colour(ui, "add color", self.addcolor or {0,0,0,0})
		if colour then
			self:ApplyAddColor(colour)
		end

		local w,h = self:GetSize()
		if w and h then
			local changed
			changed, w,h = ui:DragFloat2("size", w,h, 1,1,1000)
			if changed then
				self:SetSize(w,h)
			end
		end -- else texture is probably nil

		local to_pop = ui:PushDisabledStyle()
		local tex_size = Vector2(self.model:GetTextureSize())
		ui:DragVec2f("texture size", tex_size:clone())
		ui:PopStyleColor(to_pop)

		ui:PushItemWidth((ui:GetContentRegionAvail() - 170)/2) do
			-- Probably best for whoever gave you the art to give you the coords.
			self.coords = self.coords or {
				min = tex_size * 0.33, -- defaults from NineSlice::ClearInternal()
				max = tex_size * 0.66,
			}
			local max_coord = math.max(tex_size:unpack())
			local changed = ui:DragVec2f("##NineSliceCoords.min", self.coords.min, nil, 0, max_coord)
			ui:SetTooltipIfHovered("minx, miny: in pixels from top left")
			ui:SameLine(nil, 5)
			changed = ui:DragVec2f("NineSliceCoords##NineSliceCoords.max", self.coords.max, nil, 0, max_coord) or changed
			ui:SetTooltipIfHovered("maxx, maxy: in pixels from top left")
			local from_edge = tex_size - self.coords.max
			local do_botright = ui:DragVec2f("Max Coords from bottom right", from_edge, nil, 0, max_coord)
			ui:SetTooltipIfHovered("maxx, maxy: in pixels from bottom right")
			if do_botright then
				changed = true
				self.coords.max = tex_size - from_edge
			end
			if changed then
				self:SetNineSliceCoords(self.coords.min.x, self.coords.min.y, self.coords.max.x, self.coords.max.y)
			end
		end ui:PopItemWidth()

		local changed
		changed, self.border_scale = ui:DragFloat("NineSliceBorderScale", self.border_scale or 1, nil, 0, 5)
		if changed then
			self:SetNineSliceBorderScale(self.border_scale)
		end

	end
	ui:Unindent()
end

function Panel:SetTexture(tex)
	local atlas, atlasregion = GetAtlasTex(tex)

	self.model:SetTexture(atlas, atlasregion)
	self:MarkTransformDirty()
	self:InvalidateBBox()

	return self
end

function Panel:FitChildren(padding)
	padding = padding or 0
	local xmin, ymin, xmax, ymax = math.huge, math.huge, -math.huge, -math.huge

	if self.children then
		for k,widget in pairs(self.children) do
			local x0, y0, x1, y1 = widget:GetBoundingBox()
			if y1 then
				x0, y0 = widget:TransformToParent( x0, y0 )
				x1, y1 = widget:TransformToParent( x1, y1 )
				xmin = math.min( x0, xmin )
				xmax = math.max( x1, xmax )
				ymin = math.min( y0, ymin )
				ymax = math.max( y1, ymax )
			end
		end
	end
	if ymax > ymin then
		self:SetInnerSize( (xmax - xmin) + padding, (ymax - ymin) + padding )
	end

	return self
end

function Panel:SetBloom(b)
	print("Not implemented: Panel:SetBloom")
	--	self.model:SetBloom(b)
	return self
end

function Panel:GetBoundingBox()
	return self.model:GetBoundingBox()
end

function Panel:SizeToWidgets( padding, ... )
	local xmin, ymin, xmax, ymax = self.parent:CalculateBoundingBox( ... )
	local hpad, vpad
	if type(padding) == "table" then
		hpad, vpad = padding[1], padding[2]
	else
		hpad, vpad = padding, padding
	end
	if ymax > ymin then
		self:SetSize( (xmax - xmin) + hpad, (ymax - ymin) + vpad )
		self:SetPos( (xmin + xmax)/2, (ymin + ymax)/2 )
	end
	return self
end

function Panel:ExpandToWidgets( padding, ... )
	local w, h = self.model:GetInnerSize()
	local xmin, ymin, xmax, ymax = self.parent:CalculateBoundingBox( ... )
	xmin = math.min( xmin, self.x - w/2 )
	xmax = math.max( xmax, self.x + w/2 )
	ymin = math.min( ymin, self.y - h/2 )
	ymax = math.max( ymax, self.y + h/2 )
	if ymax > ymin then
		self:SetInnerSize( (xmax - xmin) + padding, (ymax - ymin) + padding )
		self:SetPos( (xmin + xmax)/2, (ymin + ymax)/2 )
	end
	return self
end

function Panel:ExpandToPoint( x, y )
	local w, h = self.model:GetInnerSize()
	local xmin = math.min( x, self.x - w/2 )
	local xmax = math.max( x, self.x + w/2 )
	local ymin = math.min( y, self.y - h/2 )
	local ymax = math.max( y, self.y + h/2 )
	if ymax > ymin then
		self:SetInnerSize( (xmax - xmin), (ymax - ymin) )
		self:SetPos( (xmin + xmax)/2, (ymin + ymax)/2 )
	end
end

function Panel:SetInnerSize(dw,dh)
	self.model:SetInnerSize(dw, dh)
	self:InvalidateBBox()
	return self
end

function Panel:GetInnerSize()
	return self.model:GetInnerSize()
end

function Panel:SetInnerUVs(minx, miny, maxx, maxy)
	-- print("Panel:SetInnerUVs()", minx, miny, maxx, maxy)
	self.model:SetInnerUVS(minx, miny, maxx, maxy)
	return self
end

-- really these pretty much always have to be set together
function Panel:SetNineSlice(asset)
	local tex, minx, miny, maxx, maxy = table.unpack(asset)
	local atlas, atlasregion = GetAtlasTex(tex)
	self.model:SetTexture(atlas, atlasregion)
	self:SetNineSliceCoords(minx, miny, maxx, maxy)
	self:InvalidateBBox()
	return self
end


-- ▼ in pixels from top left
-- ┌───┬─────────────┬───┐
-- │   │             │   │
-- ├───┼─────────────┼───┤
-- │   minx,miny     │   │
-- │   │             │   │
-- │   │             │   │
-- │   │             │   │
-- │   │     maxx,maxy   │
-- ├───┼─────────────┼───┤
-- │   │             │   │
-- └───┴─────────────┴───┘
function Panel:SetNineSliceCoords(minx, miny, maxx, maxy)
--	local tx, ty = self.texture:GetSize()
	local tx, ty = self.model:GetTextureSize()
	-- print("SetNineSliceCoords()", minx, miny, maxx, maxy, tx, ty)
	local uvminx = minx/tx
	local uvminy = miny/ty
	local uvmaxx = maxx/tx
	local uvmaxy = maxy/ty
	self:SetInnerUVs(uvminx, uvminy, uvmaxx, uvmaxy)
	self:InvalidateBBox()
	return self
end

-- scale = 1 by default.
function Panel:SetNineSliceBorderScale(scale)
	self.model:SetBorderScale(scale)
	self:InvalidateBBox()
	return self
end

function Panel:SetMask()
	self.model:SetColorWrite(false)
	self.model:SetEffect(global_shaders.UI_MASK)
	self:SetStencilWrite(STENCIL_MODES.SET)
	return self
end

function Panel:SetInnerPercents(dw,dh)
	self.model:SetInteriorPercent(dw, dh)
	return self
end

function Panel:SetSize(w, h)
	local current_w, current_h = self:GetSize()

	w = w or current_w
	h = h or current_h

	self.model:SetSize(w, h)
	self:MarkTransformDirty()
	self:InvalidateBBox()

	return self
end

function Panel:Expand( dw, dh )
	local w, h = self:GetSize()
	self:SetSize( w + (dw or 0), h + (dh or 0) )
	return self
end

function Panel:GetSize()
	return self.model:GetOuterSize()
end

function Panel:GetBorderSize()
	return self.model:GetBorderSize()
end

-- Prefer Widget:SetMultColor since it blends with its parent's mult color.
function Panel:ApplyMultColor(r,g,b,a)
	self.tint = type(r) == "number" and { r, g, b, a } or r
	self.model:SetMultColor(table.unpack(self.tint))
	return self
end

-- Prefer Widget:SetAddColor since it blends with its parent's mult color.
function Panel:ApplyAddColor(r,g,b,a)
	self.addcolor = type(r) == "number" and { r, g, b, a } or r
	self.model:SetAddColor(table.unpack(self.addcolor))
	return self
end

function Panel:ApplyHue(hue)
	self.model:SetHue(hue)
	return self
end

function Panel:ApplyBrightness(brightness)
	self.model:SetBrightness(brightness)
	return self
end

function Panel:ApplySaturation(saturation)
	self.model:SetSaturation(saturation)
	return self
end

function Panel:SetBrightnessMap(gradient_tex, intensity)
	UIHelpers.SetBrightnessMapNative(self.model, gradient_tex, intensity)
	return self
end

return Panel
