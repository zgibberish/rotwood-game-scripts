local STRENGTH = 0.5
local SCALE = 5
local ROT_SPEED = 1 / 1.5		-- 1.5 seconds per rotation
local TRANS_SPEED = 1 / 2.0		-- 2.0 seconds per translation
local MAX_ROTATION = 20			-- max 20 degrees from base rotation
local MAX_TRANSLATION = 0.5		-- max 1 world unit from base position

local LightSpot = Class(function(self, inst)
	self.inst = inst
	self.startRotation = 0
	self.scale = 5
	self.intensity = 1

	self.rotRatio = 0
	self.transRatio = 0
	
	self.shimmerTime = 0
	self.shimmer_speed = 1
	self.shimmer_strength = 0.3
	                                                                                
	self:SetRotSpeed(ROT_SPEED)                                                   
	self:SetTransSpeed(TRANS_SPEED)
	self:SetMaxRotation(MAX_ROTATION)
	self:SetMaxTranslation(MAX_TRANSLATION)

	self:SetStrength(STRENGTH)

	self.targetRotation = self.startRotation + math.random() * self.maxRotation

	self.startX = 0
	self.targetX = math.random() * self.maxTranslation
	self.startY = 0
	self.targetY = math.random() * self.maxTranslation
end)

function LightSpot:SetStrength(strength)
	self.strength = strength
	self.inst.Light:SetCanopyStrength(self.strength)
end

function LightSpot:SetMinStrength(strength)
	self.minstrength = strength
end

function LightSpot:SetRotSpeed(speed)
	self.rotSpeed = speed
end

function LightSpot:SetTransSpeed(speed)
	self.transSpeed = speed
end

function LightSpot:SetMaxRotation(rotation)
	self.maxRotation = rotation
	self.targetRotation = self.startRotation + math.random() * self.maxRotation
end

function LightSpot:SetMaxTranslation(translation)
	self.maxTranslation = translation
end

function LightSpot:UpdateRotRatio(dt, maxAngle, rotSpeed)
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

function LightSpot:UpdateTransRatio(dt, maxTranslation, transSpeed)
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

function LightSpot:OnUpdate(dt)
	if self.animate then
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
	if self.shimmer then
		self.shimmerTime = self.shimmerTime + dt * self.shimmer_speed
		local amp = math.sin(self.shimmerTime)
		local res = self.intensity + amp * self.shimmer_strength
		self.inst.Light:SetIntensity(res)
	end
end

function LightSpot:UpdateUpdateStatus()
	if self.animate or self.shimmer then
		self.inst:StartUpdatingComponent(self)
	else
		self.inst:StopUpdatingComponent(self)
	end
end

function LightSpot:SetAnimate(enable)
	self.animate = enable
	self:UpdateUpdateStatus()
end

function LightSpot:SetShimmer(enable)
	self.shimmer = enable
	self:UpdateUpdateStatus()
end

function LightSpot:SetRotation(rotation)
	self.startRotation = rotation
	self.inst.Light:SetRotation(rotation)
end

function LightSpot:SetIntensity(intensity)
	self.intensity = intensity
	self.inst.Light:SetIntensity(intensity)
end

function LightSpot:SetShimmerSpeed(shimmer_speed)
	self.shimmer_speed = shimmer_speed
end

function LightSpot:SetShimmerStrength(shimmer_strength)
	self.shimmer_strength = shimmer_strength
end

LightSpot.EditableName = "LightSpot"

return LightSpot
