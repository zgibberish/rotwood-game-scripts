local SceneElement = require "proc_gen.scene_element"
local PropProcGen = require "proc_gen.prop_proc_gen"

local FLAGS = PropProcGen.Tag:AlphaSorted()
setmetatable(FLAGS, nil)

local SceneFx = Class(SceneElement, function(self, fx)
	SceneElement._ctor(self)
	self.fx = fx
end)

SceneFx.CLIPBOARD_CONTEXT = "++SceneFx.CLIPBOARD_CONTEXT"

function SceneFx.FromRawTable(raw_table)
	local particle_system = SceneFx()
	for k, v in pairs(raw_table) do
		particle_system[k] = v
	end
	return particle_system
end

function SceneFx:GetDecorType()
	return DecorType.s.Fx
end

function SceneFx:GetLabel()
	return self._base.GetLabel(self) or self.fx
end

function SceneFx:Ui(ui, id, prop_browser)
	ui:Text("Fx: "..self.fx)
	ui:SameLineWithSpace()
	if ui:Button(ui.icon.search..id) then
		prop_browser:Open(ui, PrefabBrowserContext.id.Fx)
	end
	ui:SetTooltipIfHovered("Choose different Fx")

	self._base.Ui(self, ui, id)
end

return SceneFx
