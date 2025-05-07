local Widget = require "widgets/widget"
local UIHelpers = require "ui/uihelpers"

local RadialProgress = Class(Widget, function( self, tex )

    Widget._ctor(self, "RadialProgress")

    self.progress = 0

    self.model = self.inst.entity:AddRadialProgress()

    self:SetTexture(tex)

    self.blocks_mouse = true
end)

function RadialProgress:OnRemoved()
    self.texture = nil
end


function RadialProgress:__tostring()
    return string.format("RadialProgress Widget (%2.2fx%2.2f)", self:GetSize())
end

-- Prefer Widget:SetMultColor since it blends with its parent's mult color.
function RadialProgress:ApplyMultColor(r,g,b,a)
	self.tint = type(r) == "number" and { r, g, b, a } or r
	self.model:SetMultColor(table.unpack(self.tint))
	return self
end

-- Prefer Widget:SetAddColor since it blends with its parent's mult color.
function RadialProgress:ApplyAddColor(r,g,b,a)
	self.addcolor = type(r) == "number" and { r, g, b, a } or r
	self.model:SetAddColor(table.unpack(self.addcolor))
	return self
end

function RadialProgress:ApplyHue(hue)
	self.model:SetHue(hue)
	return self
end

function RadialProgress:ApplyBrightness(brightness)
	self.model:SetBrightness(brightness)
	return self
end

function RadialProgress:ApplySaturation(saturation)
	self.model:SetSaturation(saturation)
	return self
end

function RadialProgress:GetBoundingBox()
    return self.model:GetBoundingBox()
end

function RadialProgress:SetSize(dw,dh)
    self.model:SetSize(dw, dh)
    self:MarkTransformDirty()
    self:InvalidateBBox()
    return self
end

function RadialProgress:GetSize()
    return self.model:GetSize()
end

function RadialProgress:SetTexture(texture)
    local atlas, atlasregion = GetAtlasTex(texture)

    self.model:SetTexture(atlas, atlasregion)

    return self
end

function RadialProgress:SetProgress(zeroToOne)
    self.progress = zeroToOne
    self.model:SetProgress(zeroToOne)
    return self
end

function RadialProgress:GetProgress()
    return self.progress
end

function RadialProgress:SetMask()
    self.model:SetColorWrite(false)
    self.model:SetEffect(global_shaders.UI_MASK)
    self:SetStencilWrite(STENCIL_MODES.SET)
    return self
end

function RadialProgress:SetSize(w, h)
    local current_w, current_h = self:GetSize()

    if current_w ~= w or current_h ~= h then
        w = w or current_w
        h = h or current_h

        self.model:SetSize(w, h)
        self:MarkTransformDirty()
        self:InvalidateBBox()
    end

    return self
end

function RadialProgress:Expand( dw, dh )
    local w, h = self:GetSize()
    self:SetSize( w + (dw or 0), h + (dh or 0) )
    return self
end

function RadialProgress:GetSize()
    return self.model:GetSize()
end

function RadialProgress:SetBrightnessMap(gradient_tex, intensity)
	UIHelpers.SetBrightnessMapNative(self.model, gradient_tex, intensity)
	return self
end

function RadialProgress:__tostring()
    return "radial progress"
end

return RadialProgress
