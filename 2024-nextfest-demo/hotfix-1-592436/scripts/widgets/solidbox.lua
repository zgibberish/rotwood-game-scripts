local Widget = require "widgets/widget"
local Image = require "widgets/image"

--local assets = {
--	square = engine.asset.Texture("images/square.tex")
--}

local SolidBox = Class(Widget, function(self, w, h, r, g, b, a)	
	Widget._ctor(self, "SolidBox")
	--self:SetBlocksMouse(true)
	self.image = self:AddChild(Image("images/global/square.tex"))
	self.image:SetSize(w,h)

	self.w, self.h = w or 1, h or 1
	
	--self.image.model:SetBlendMode(a and a < 0 and BLEND_MODE.BLENDED or BLEND_MODE.DISABLED)
	if r then
		self.image:SetMultColor(r,g,b,a)
	end
end)

function SolidBox:GetBoundingBox()
	return -self.w/2, -self.h/2, self.w/2, self.h/2
end

function SolidBox:SizeToWidgets( padding, ... )
    local xmin, ymin, xmax, ymax = self.parent:CalculateBoundingBox( ... )
    if ymax > ymin then
        self:SetSize( (xmax - xmin) + padding, (ymax - ymin) + padding )
        self:SetPos( (xmin + xmax)/2, (ymin + ymax)/2 )
    end
end

function SolidBox:SetBloom(b)
	self.image:SetBloom(b)
	return self
end

function SolidBox:GetSize()
	return self.w, self.h
end

function SolidBox:SetColour(r,g,b,a)
	if type(r) == "table" then
		r,g,b,a = r[1],r[2],r[3],r[4]
	else
		-- number
		if not g then
			-- hex value
			r,g,b,a = HexToRGBFloats(r)
		else
			-- they're fine as is
		end
	end
	--self.image.model:SetBlendMode(a and a < 0 and BLEND_MODE.BLENDED or BLEND_MODE.DISABLED)
	self.image:SetMultColor(r,g,b,a)
	return self
end

function SolidBox:SetSize(w,h)
	if self.w ~= w or self.h ~= h then
		local imw, imh = self.image:GetSize()
		self.w = w or self.w or 1
		self.h = h or self.h or 1
		self.image:SetScale(self.w/imw, self.h/imh)
	end
	return self
end

function SolidBox:ExpandSize( w, h )
	w = math.max( w or 0, self.w )
	h = math.max( h or 0, self.h )
	self:SetSize( w, h )
end

return SolidBox