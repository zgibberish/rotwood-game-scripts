local easing = require("util.easing")

local PropHighlight = Class(function(self, inst)
	self.inst = inst
	self.curvalue = 1
	self.intensity = .25
	self.period = 1

	if self.inst.Light ~= nil then
		if self.inst.Light:GetIsShadow() then
			self.backupShadowStrengh = self.inst.Light:GetCanopyStrength()
		else
			self.backupLightColor = {self.inst.Light:GetColor()}
		end
	end

	inst:StartUpdatingComponent(self)
	self:OnUpdate(0)
end)

function PropHighlight:OnUpdate(dt)
	self.curvalue = self.curvalue + dt * self.period * 2
	while self.curvalue > 1 do
		self.curvalue = self.curvalue - 2
	end
	local c = easing.inOutQuad(math.abs(self.curvalue), 0, self.intensity, 1)
	self:ApplyColor(c, c, c, 0)
end

function PropHighlight:ApplyColor(r, g, b, a)
	if self.inst.Light ~= nil then
		if self.inst.Light:GetIsShadow() then
			self.inst.Light:SetCanopyStrength(r)
		else
			self.inst.Light:SetColor(r,g,b)
		end
	else
		if self.inst.AnimState ~= nil then
			self.inst.AnimState:SetHighlightColor(r, g, b, a)
		end

		local children = self.inst.highlightchildren
		if children ~= nil then
			for i = 1, #children do
				local child = children[i]
				if child.AnimState ~= nil then
					child.AnimState:SetHighlightColor(r, g, b, a)
				end
			end
		end
	end
end

function PropHighlight:OnRemoveFromEntity()
	if self.backupLightColor then
		self.inst.Light:SetColor(table.unpack(self.backupLightColor))
	elseif self.backupShadowStrengh then
		self.inst.Light:SetCanopyStrength(self.backupShadowStrengh)
	else
		if self.inst.AnimState ~= nil then
			self.inst.AnimState:SetHighlightColor()
		end

		local children = self.inst.highlightchildren
		if children ~= nil then
			for i = 1, #children do
				local child = children[i]
				if child.AnimState ~= nil then
					child.AnimState:SetHighlightColor()
				end
			end
		end
	end
end

return PropHighlight
