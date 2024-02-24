-- Curve editor to make custom curves instead of using ease.

local DebugNodes = require "dbui.debug_nodes"
local PrefabEditorBase = require "debug.inspectors.prefabeditorbase"
require "mathutil"


local _static = PrefabEditorBase.MakeStaticData("curve_autogen_data")

-- A generic curve editor for logic that doesn't have a real editor.
local CurveEditor = Class(PrefabEditorBase, function(self)
	PrefabEditorBase._ctor(self, _static)

	self.name = "Curve Editor"
	self.prefab_label = "Curve Preset"
	self.test_label = false

	self:LoadLastSelectedPrefab("curveeditor")
end)

CurveEditor.PANEL_WIDTH = 660
CurveEditor.PANEL_HEIGHT = 990

local default_curve = CreateCurve()

function CurveEditor:AddEditableOptions(ui, params)
	if not next(params) then
		for i,val in ipairs(default_curve) do
			params[i] = val
		end
	end

	-- I don't think min/max/duration are useful since it's more useful to
	-- define curves and evaluate them like easing/ease.
	--~ local changed, val = ui:SliderFloat("Min", params.min or 0, 0, 10)
	--~ if changed then
	--~ 	params.min = val
	--~ end

	--~ changed, val = ui:SliderFloat("Max", params.max or 1, 0, 10)
	--~ if changed then
	--~ 	params.max = val
	--~ end

	local changed = ui:CurveEditor("Curve", params)
	if changed then
		self:SetDirty()
	end
end

DebugNodes.CurveEditor = CurveEditor

return CurveEditor
