local SceneElement = require "proc_gen.scene_element"
local ParticleSystem = require "components.particlesystem"
local PropProcGen = require "proc_gen.prop_proc_gen"

local FLAGS = PropProcGen.Tag:AlphaSorted()
setmetatable(FLAGS, nil)

local SceneParticleSystem = Class(SceneElement, function(self, particle_system)
	SceneElement._ctor(self)
	self.particle_system = particle_system
	self.layer_override = nil
	self.flags = {}
end)

SceneParticleSystem.CLIPBOARD_CONTEXT = "++SceneParticleSystem.CLIPBOARD_CONTEXT"


function SceneParticleSystem.FromRawTable(raw_table)
	local particle_system = SceneParticleSystem()
	for k, v in pairs(raw_table) do
		particle_system[k] = v
	end
	return particle_system
end

function SceneParticleSystem:GetDecorType()
	return DecorType.s.ParticleSystem
end

function SceneParticleSystem:GetLabel()
	return self._base.GetLabel(self) or self.particle_system
end

function SceneParticleSystem:Ui(ui, id, prop_browser)
	ui:Text("Particle System: "..self.particle_system)
	ui:SameLineWithSpace()
	if ui:Button(ui.icon.search..id) then
		prop_browser:Open(ui, PrefabBrowserContext.id.ParticleSystem)
	end
	ui:SetTooltipIfHovered("Choose different particle system")

	self._base.Ui(self, ui, id)

	ParticleSystem.LayerOverrideUi(ui, id.."LayerOverride", self)
	ui:FlagRadioButtons("Flags"..id, FLAGS, self.flags)
end

return SceneParticleSystem
