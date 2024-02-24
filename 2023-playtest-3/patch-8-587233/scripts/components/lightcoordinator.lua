require "class"

local LightCoordinator = Class(function(self, inst)
	self.inst = inst
	self.lights = {}
end)

function LightCoordinator:SetDefaultAmbient(r, g, b)
	dbassert(b)
	self.default_ambient = { r, g, b }
	TheSim:SetAmbientColor(r, g, b)
end

function LightCoordinator:RegisterLight(ent)
	self.lights[ent] = ent
end

function LightCoordinator:UnregisterLight(ent)
	self.lights[ent] = nil
end

-- This doesn't affect lights with Shimmer enabled. I assume they fluctuate
-- their intensity.
function LightCoordinator:SetIntensity(v)
	local light_v = v * v
	for ent in pairs(self.lights) do
		ent.Light:SetIntensity(light_v)
	end
	-- Don't have an intensity for ambient, so just set each component.
	TheSim:SetAmbientColor(v, v, v)
end

function LightCoordinator:ResetColor()
	self:SetIntensity(1)
	if self.default_ambient then
		TheSim:SetAmbientColor(table.unpack(self.default_ambient))
	end
end

function LightCoordinator:RenderIntensityUI(ui, params)
	params.world_intensity = ui:_SliderFloat("World Intensity", params.world_intensity or 0.5, 0, 1)
	ui:Text("Intensity doesn't affect lights with Shimmer enabled.")
	local is_editing = ui:IsItemActive()

	if ui:Checkbox("Preview", self.preview_light) then
		self.preview_light = not self.preview_light
		if not self.preview_light then
			self:ResetColor()
		end
	end
	if self.preview_light then
		self:SetIntensity(params.world_intensity)
	end

	return self.preview_light and is_editing
end
return LightCoordinator
