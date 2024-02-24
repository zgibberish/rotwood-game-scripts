local DEFAULT_WATER_COLOR = HexToStr(0x9ac3e500)
local DEFAULT_WATER_HEIGHT = -1.2
local DEFAULT_WATER_BOB_SPEED = 1
local DEFAULT_WATER_BOB_AMPLITUDE = 0.2

local DEFAULT_WATER_WAVE_SPEED = 1
local DEFAULT_WATER_WAVE_HEIGHT = 0.2
local DEFAULT_WATER_WAVE_PERIOD = 1
local DEFAULT_WATER_WAVE_OUTLINE = 0.05

local DEFAULT_WATER_REFRACTION = 0.3
local DEFAULT_WATER_REFRACTION_SPEED = 2

WATER_PROPS = 1
WATER_MESH = 2

local WorldWater = Class(function(self, inst)
	self.inst = inst
	self.inst:StartUpdatingComponent(self)

	self.color = {HexToRGBFloats(StrToHex(DEFAULT_WATER_COLOR))}
	self.height = DEFAULT_WATER_HEIGHT
	self.refraction = DEFAULT_WATER_REFRACTION
	self.refractionSpeed = DEFAULT_WATER_REFRACTION_SPEED

	-- settings that can be different for props and edgemesh
	self.bobSpeed = {DEFAULT_WATER_BOB_SPEED, DEFAULT_WATER_BOB_SPEED}
	self.bobAmplitude = {DEFAULT_WATER_BOB_AMPLITUDE, DEFAULT_WATER_BOB_AMPLITUDE}

	self.waveHeight = {DEFAULT_WATER_WAVE_HEIGHT,DEFAULT_WATER_WAVE_HEIGHT}
	self.wavePeriod = {DEFAULT_WATER_WAVE_PERIOD, DEFAULT_WATER_WAVE_PERIOD}
	self.waveSpeed = {DEFAULT_WATER_WAVE_SPEED,DEFAULT_WATER_WAVE_SPEED}
	self.waveOutline = {DEFAULT_WATER_WAVE_OUTLINE, DEFAULT_WATER_WAVE_OUTLINE}

	-- this one will be calculated for props and edgemesh
	self.waterHeight = {self.height, self.height}

	self:UpdateAuxParams()
	self:Enable(false)
end)


function WorldWater:Enable(enable)
	if (enable) then
		self.inst:StartUpdatingComponent(self)
	else
		self.waterHeight = {-1024, -1024 }
		self.inst:StopUpdatingComponent(self)
		self:UpdateAuxParams()
	end
end

function WorldWater:SetHeight(h)
	self.height = h
end

function WorldWater:SetRefraction(v)
	self.refraction = v
	self:UpdateAuxParams()
end

function WorldWater:SetRefractionSpeed(v)
	self.refractionSpeed = v
print("self.refractionSpeed:",self.refractionSpeed)
	self:UpdateAuxParams()
end

function WorldWater:GetHeight(index)
	-- defaults to mesh water
	return self.waterHeight[index or 1]
end

function WorldWater:SetColor(r,g,b)
	self.color = {r,g,b}
	self:UpdateAuxParams()
end

function WorldWater:SetBobSpeed(speed, index)
	if index then
		self.bobSpeed[index] = speed
	else
		self.bobSpeed[1] = speed
		self.bobSpeed[2] = speed
	end
	self:UpdateAuxParams()
end

function WorldWater:SetBobAmplitude(amplitude, index)
	if index then
		self.bobAmplitude[index] = amplitude
	else
		self.bobAmplitude[1] = amplitude
		self.bobAmplitude[2] = amplitude
	end
	self:UpdateAuxParams()
end

function WorldWater:SetAdditiveBlending(enabled)
	self.additiveBlending = enabled or false
end

function WorldWater:SetRampTexture(ramp)
	TheSim:SetWaterEdgeRampTexture(ramp)
end

function WorldWater:UpdateAuxParams()
	TheSim:SetWaterParam(0, self.color[1])
	TheSim:SetWaterParam(1, self.color[2])
	TheSim:SetWaterParam(2, self.color[3])
	TheSim:SetWaterParam(3, self.additiveBlending and 1 or 0)

	TheSim:SetWaterParam(4, self.waterHeight[1])
	TheSim:SetWaterParam(5, self.waterHeight[2])
	-- unused
	TheSim:SetWaterParam(6, self.refraction)
	TheSim:SetWaterParam(7, self.refractionSpeed)

	-- prop 
	TheSim:SetWaterParam(8, self.waveHeight[1])
	TheSim:SetWaterParam(9, self.waveSpeed[1])
	TheSim:SetWaterParam(10, self.wavePeriod[1])
	TheSim:SetWaterParam(11, self.waveOutline[1])
                             
	-- cliff
	TheSim:SetWaterParam(12, self.waveHeight[2])
	TheSim:SetWaterParam(13, self.waveSpeed[2])
	TheSim:SetWaterParam(14, self.wavePeriod[2])
	TheSim:SetWaterParam(15, self.waveOutline[2])
end

function WorldWater:SetWaveHeight(val, index)
	if index then
		self.waveHeight[index] = val
	else
		self.waveHeight[1] = val
		self.waveHeight[2] = val
	end
	self:UpdateAuxParams()
end

function WorldWater:SetWaveSpeed(val, index)
	if index then
		self.waveSpeed[index] = val
	else
		self.waveSpeed[1] = val
		self.waveSpeed[2] = val
	end
	self:UpdateAuxParams()
end

function WorldWater:SetWavePeriod(val, index)
	if index then
		self.wavePeriod[index] = val
	else
		self.wavePeriod[1] = val
		self.wavePeriod[2] = val
	end
	self:UpdateAuxParams()
end

function WorldWater:SetWaveOutline(val, index)
	if index then
		self.waveOutline[index] = val
	else
		self.waveOutline[1] = val
		self.waveOutline[2] = val
	end
	self:UpdateAuxParams()
end

function WorldWater:OnUpdate()
	local t = TheSim:GetSimTime()
	for i=1,2 do
		local h = self.height + math.sin(t * self.bobSpeed[i]) * self.bobAmplitude[i]
		self.waterHeight[i] = h
	end
	self:UpdateAuxParams()
end

return WorldWater
