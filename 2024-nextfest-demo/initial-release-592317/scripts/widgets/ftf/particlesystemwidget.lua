local Widget = require "widgets/widget"

-- Widget wrapper for a particlesystem. Use particlesystem prefab to spawn in world.
local ParticleSystemWidget = Class(Widget, function(self)
	Widget._ctor(self, "ParticleWidget")

	self.particlesystem = self.inst:AddComponent("particlesystem")
end)

function ParticleSystemWidget:DebugDraw_AddSection(ui, panel)
	panel:AppendTable(ui, self.particlesystem, "Inspect particlesystem")
end

-- Avoid duplicating too much of the particlesystem api here. Init is fine, but
-- otherwise access it via the component itself.

function ParticleSystemWidget:LoadParticlesParams(name)
	self.particlesystem:LoadParams(name)
	return self
end

return ParticleSystemWidget
