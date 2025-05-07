local SceneElement = require "proc_gen.scene_element"

local SceneSpace = Class(SceneElement, function(self)
	SceneElement._ctor(self)
end)

SceneSpace.CLIPBOARD_CONTEXT = "++SceneSpace.CLIPBOARD_CONTEXT"

function SceneSpace.FromRawTable(raw_table)
	local spacer = SceneSpace()
	for k, v in pairs(raw_table) do
		spacer[k] = v
	end
	return spacer
end

function SceneSpace:GetDecorType()
	return DecorType.s.Spacer
end

function SceneSpace:GetLabel()
	return self._base.GetLabel(self) or ("Space "..self:GetPersistentRadius())
end

return SceneSpace
