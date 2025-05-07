local DebugEntity = require "dbui.debug_entity"
local DebugPickers = require "dbui.debug_pickers"
local Text = require "widgets.text"
local Widget = require "widgets.widget"


local UIAnim = Class(Widget, function(self)
	Widget._ctor(self, "UIAnim")
	self.inst.entity:AddAnimState()
	self.inst.AnimState:SetEffect(global_shaders.UI_ANIM)
end)

function UIAnim:GetAnimState()
	return self.inst.AnimState
end

function UIAnim:SetBank(bank)
	self.inst.AnimState:SetBank(bank)
	self.inst.AnimState:SetBuild(bank) -- usually the same
	self:InvalidateBBox()
	return self
end

function UIAnim:SetFacing(dir)
	self.inst.UITransform:SetFacing(dir)
	self:InvalidateBBox()
	return self
end

function UIAnim:PushAnimation(anim, should_loop)
	self:GetAnimState():PushAnimation(anim, should_loop)
	self:InvalidateBBox()
	return self
end

function UIAnim:PlayAnimation(anim, should_loop)
	self:GetAnimState():PlayAnimation(anim, should_loop)
	self:InvalidateBBox()
	return self
end

-- GetSymbolPosition_Vec2 appears to be accurate for child widgets.
function UIAnim:GetSymbolPosition_Vec2(symbol)
	local pos = Vector2(self:GetAnimState():GetSymbolPosition(symbol, 0,0,0))
	pos.y = -pos.y
	return pos
end

function UIAnim:CreateUpdater_AnimDone()
	return Updater.Until(function()
		local animstate = self:GetAnimState()
		return animstate:IsCurrentAnimDone()
	end)
end

function UIAnim:GetWorldBoundingBox()
	return self.inst.entity:GetUIWorldAABB()
end

-- Capture the current anim bounding box to get a consistent size that matches
-- what's currently visible.
--
-- Use something like this:
--   w = self:AddChild(UIAnim())
--         :PlayAnimation("idle")
--         :CaptureAnimBBox()
--         :LayoutBounds("left", "top", self.bg)
-- You'll be able to do future layouts with the same bounding box.
function UIAnim:CaptureCurrentAnimBBox()
	self.can_use_bbox = true
	self.captured_bbox = { self:GetBoundingBox() }
	assert(self.inst.AnimState:HasAnimation(), "Bounding box will be incorrect without active animation.")
	return self
end

-- Since anims move, their bounding box is inconsistent and changes every frame
-- and may be wildly different between animations. So you have to opt into
-- using them to avoid awkward results in layout.
--
-- Use something like this:
--   w = self:AddChild(UIAnim())
--         :PlayAnimation("blah")
--         :UseAnimBBox()
--         :LayoutBounds("center", "center", self.bg)
function UIAnim:UseAnimBBox()
	self.can_use_bbox = true
	assert(self.inst.AnimState:HasAnimation(), "Bounding box will be incorrect without active animation.")
	return self
end

function UIAnim:GetBoundingBox()
	if self.captured_bbox then
		return table.unpack(self.captured_bbox)
	end
	if not self.can_use_bbox then
		return 0, 0, 0, 0
	end
	-- Unlike Image, we have a world BB that we translate to local.
	local x1, y1, x2, y2 = self:GetWorldBoundingBox()
	x1, y1 = self:TransformFromWorld( x1, y1 )
	x2, y2 = self:TransformFromWorld( x2, y2 )
	local xmin = math.min( x1, x2 )
	local xmax = math.max( x1, x2 )
	local ymin = math.min( y1, y2 )
	local ymax = math.max( y1, y2 )

	return xmin, ymin, xmax, ymax
end

-- This UIAnim defines a mask for use with SetMasked. Only content within the
-- opaque area of the mask will be visible. See Widget:SetMasked.
function UIAnim:SetMask()
	self:SetStencilWrite(STENCIL_MODES.SET)
	return self
end

function UIAnim:SetMaskOnly()
	self.inst.AnimState:SetColorWrite(false)
	self.inst.AnimState:SetEffect(global_shaders.UI_ANIM_MASK)
	self:SetStencilWrite(STENCIL_MODES.SET)
	return self
end

function UIAnim:ApplyMultColor(r,g,b,a)
	self.inst.AnimState:SetMultColor(r,g,b,a)
	return self
end

function UIAnim:ApplyAddColor(r,g,b,a)
	self.inst.AnimState:SetAddColor(r,g,b,a)
	return self
end

function UIAnim:ApplyHue(hue)
	self.inst.AnimState:SetHue(hue)
	return self
end

function UIAnim:ApplyBrightness(brightness)
	self.inst.AnimState:SetBrightness(brightness)
	return self
end

function UIAnim:ApplySaturation(saturation)
	self.inst.AnimState:SetSaturation(saturation)
	return self
end

function UIAnim:DebugDraw_AddSection(ui, panel)
	UIAnim._base.DebugDraw_AddSection(self, ui, panel)

	ui:Spacing()
	ui:Text("UIAnim")
	ui:Indent() do
		local animstate = self:GetAnimState()
		if animstate then
			ui:Value("IsCurrentAnimDone", animstate:IsCurrentAnimDone())
			ui:Value("CurrentFacing", animstate:GetCurrentFacing())

			local add_color = { animstate:GetAddColor() }
			local c = DebugPickers.Colour(ui, "Additive", add_color)
			if c then
				self:ApplyAddColor(table.unpack(c))
			end

			local mult_color = { animstate:GetMultColor() }
			c = DebugPickers.Colour(ui, "Tint", mult_color)
			if c then
				self:ApplyMultColor(table.unpack(c))
			end

			ui:Value("CurrentAnimationTime", animstate:GetCurrentAnimationTime(), "%.3f")
			if ui:TreeNode("Might crash") then
				-- If the underlying animation is null, then
				-- GetCurrentAnimationLength will assert. Should be safe to
				-- expand if IsCurrentAnimDone == true, but that's not very helpful.
				ui:Value("CurrentAnimationLength", animstate:GetCurrentAnimationLength(), "%.3f")
				ui:TreePop()
			end

			local current_anim = DebugEntity.RenderAnimStateCurrentAnim(ui, animstate)
			if ui:Button("Restart Anim", nil, nil, not current_anim) then
				animstate:PlayAnimation(current_anim)
			end

			local clicked, symbol = DebugEntity.DrawAnimList(ui, animstate, "SymbolNames", {
					sort = true,
					play_on_click = false,
				})
			if clicked then
				self.dbg_symbol_marker = self.dbg_symbol_marker or self:AddChild(Text())
				local pos = self:GetSymbolPosition_Vec2(symbol)
				self.dbg_symbol_marker
					:SetText(symbol)
					:SetPosition(pos:unpack())
			end
			ui:SameLineWithSpace()
			if ui:Button("Remove symbol marker", nil, nil, self.dbg_symbol_marker == nil) then
				self.dbg_symbol_marker:Remove()
				self.dbg_symbol_marker = nil
			end

			DebugEntity.DrawAnimList(ui, animstate, "CurrentBankAnimNames")
		end
	end

	ui:Unindent()
end

function UIAnim:SetBrightnessMap(gradient_tex, intensity)
	if gradient_tex == nil then
		self:GetAnimState():ClearBrightnessMap()
	else
		local atlas, tex, checkatlas = GetAtlasTex(gradient_tex)
		assert(atlas ~= nil)
		assert(tex ~= nil)
		self:GetAnimState():SetBrightnessMap(atlas, tex, intensity)
	end
	return self
end

return UIAnim
