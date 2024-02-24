local Widget = require "widgets/widget"

local Video = Class(Widget, function(self)
	Widget._ctor(self, "Video")

	self.inst.entity:AddVideoWidget()
end)

function Video:__tostring()
	return string.format("%s - %s:%s", self._widgetname, self.atlas or "", self.texture or "")
end

function Video:SetSize(w, h)
	if type(w) == "number" then
		self.inst.VideoWidget:SetSize(w,h)
	else
		self.inst.VideoWidget:SetSize(w[1],w[2])
	end
	return self
end

function Video:GetSize()
	local w, h = self.inst.VideoWidget:GetSize()
	return w, h
end

function Video:ScaleToSize(w, h)
	local w0, h0 = self.inst.VideoWidget:GetSize()
	local scalex = w / w0
	local scaley = h / h0
	self:SetScale(scalex, scaley, 1)
	return self
end

function Video:ApplyMultColor(r,g,b,a)
	local multcolor = type(r) == "number" and { r, g, b, a } or r
print("video:Applymultcolor")
	self.inst.VideoWidget:SetMultColor(table.unpack(multcolor))
	return self
end

function Video:ApplyAddColor(r,g,b,a)
	local addcolor = type(r) == "number" and { r, g, b, a } or r
	self.inst.VideoWidget:SetAddColor(table.unpack(addcolor))
	return self
end

function Video:ApplyHue(hue)
	self.inst.VideoWidget:SetHue(hue)
	return self
end

function Video:ApplyBrightness(brightness)
	self.inst.VideoWidget:SetBrightness(brightness)
	return self
end

function Video:ApplySaturation(saturation)
	self.inst.VideoWidget:SetSaturation(saturation)
	return self
end

--[[
function Video:SetAlphaRange(min, max)
	self.inst.VideoWidget:SetAlphaRange(min, max)
end

function Video:SetFadeAlpha(a, skipChildren)
	if not self.can_fade_alpha then return end

    self.inst.VideoWidget:SetMultColor(self.tint[1], self.tint[2], self.tint[3], self.tint[4] * a)
    Widget.SetFadeAlpha( self, a, skipChildren )
end
function Video:SetUVScale(xScale, yScale)
	self.inst.VideoWidget:SetUVScale(xScale, yScale)
end
]]

function Video:SetVRegPoint(anchor)
	self.inst.VideoWidget:SetVAnchor(anchor)
	return self
end

function Video:SetHRegPoint(anchor)
	self.inst.VideoWidget:SetHAnchor(anchor)
	return self
end


function Video:Load(filename)
	self.inst.VideoWidget:Load(filename)
	return self
end

function Video:Play()
	self.inst.VideoWidget:Play()
	return self
end

function Video:IsDone()
	return self.inst.VideoWidget:IsDone()
end

function Video:Pause()
	self.inst.VideoWidget:Pause()
	return self
end

function Video:Stop()
	self.inst.VideoWidget:Stop()
	return self
end

return Video
