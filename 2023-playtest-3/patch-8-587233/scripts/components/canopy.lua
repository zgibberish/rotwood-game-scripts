
local ROT_SPEED = 1 / 1.5		-- 1.5 seconds per rotation
local TRANS_SPEED = 1 / 2.0		-- 2.0 seconds per translation
local MAX_ROTATION = 20			-- max 20 degrees from base rotation
local MAX_TRANSLATION = 0.5		-- max 1 world unit from base position
local SCALE = 5				-- scale for the texture
local STRENGTH = 0.5
--local MIN_STRENGTH = 0.2		-- blend min strength - modulated with avg ambient
--local MAX_STRENGTH = 0.7		-- blend max strength - modulated with avg ambient

local Canopy = Class(function(self, inst)
	self.inst = inst
	self.startRotation = 0
	self.scale = 5

	self.rotRatio = 0
	self.transRatio = 0
	                                                                                
	self:SetRotSpeed(ROT_SPEED)                                                   
	self:SetTransSpeed(TRANS_SPEED)
	self:SetMaxRotation(MAX_ROTATION)
	self:SetMaxTranslation(MAX_TRANSLATION)

	self:SetStrength(STRENGTH)

	self.startRotation = math.random() * 360
	self.targetRotation = self.startRotation + math.random() * self.maxRotation

	self.startX = 0
	self.targetX = math.random() * self.maxTranslation
	self.startY = 0
	self.targetY = math.random() * self.maxTranslation
end)

function Canopy:SetStrength(strength)
	self.strength = strength
	self.inst.Light:SetCanopyStrength(self.strength)
end

function Canopy:SetMinStrength(strength)
	self.minstrength = strength
end

function Canopy:SetRotSpeed(speed)
	self.rotSpeed = speed
end

function Canopy:SetTransSpeed(speed)
	self.transSpeed = speed
end

function Canopy:SetMaxRotation(rotation)
	self.maxRotation = rotation
end

function Canopy:SetMaxTranslation(translation)
	self.maxTranslation = translation
end

function Canopy:UpdateRotRatio(dt, maxAngle, rotSpeed)
	self.rotRatio = self.rotRatio - dt * rotSpeed
	if (self.rotRatio < 0) then
		self.rotRatio = 1
		local delta = math.random() * maxAngle
		if (self.targetRotation > self.startRotation) then
			self.startRotation = self.targetRotation
			self.targetRotation = self.targetRotation - delta
		else
			self.startRotation = self.targetRotation
			self.targetRotation = self.targetRotation + delta
		end
	end
end

function Canopy:UpdateTransRatio(dt, maxTranslation, transSpeed)
	self.transRatio = self.transRatio - dt * transSpeed
	if (self.transRatio < 0) then
		self.transRatio = 1
		local delta = math.random() * maxTranslation
		if (self.targetX > self.startX) then
			self.startX = self.targetX
			self.targetX = -delta
		else
			self.startX = self.targetX
			self.targetX = delta
		end
		delta = math.random() * maxTranslation
		if (self.targetY > self.startY) then
			self.startY = self.targetY
			self.targetY = -delta
		else
			self.startY = self.targetY
			self.targetY = delta
		end
	end
end          

function Canopy:OnUpdate(dt)
	self:UpdateRotRatio(dt, self.maxRotation, self.rotSpeed);
	self:UpdateTransRatio(dt, self.maxTranslation, self.transSpeed);

	-- update trans and rot
	local transamount = (math.cos(self.transRatio * math.pi) + 1) / 2
	local dx = self.startX + transamount * (self.targetX - self.startX)
	local dy = self.startY + transamount * (self.targetY - self.startY)
	local rotamount = (math.cos(self.rotRatio * math.pi) + 1) / 2
	local destrot = self.startRotation + rotamount * (self.targetRotation - self.startRotation)

	self.inst.Light:SetRotation(destrot)
	self.inst.Light:SetAmbientDisplace(dx,dy)
end

Canopy.EditableName = "Canopy"

return Canopy
