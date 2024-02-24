local Lume = require "util.lume"
local DungeonProgress = require "proc_gen.dungeon_progress"
local PropColorVariant = require "proc_gen.prop_color_variant"

local UnderlayPropGen = Class(function(self, prop)
	self.prop = prop
	self.color_variants = {}
	self.enabled = true
end)

function UnderlayPropGen.FromRawTable(raw_table)
	local prop_gen = UnderlayPropGen()
	for k, v in pairs(raw_table) do
		prop_gen[k] = v
	end
	prop_gen.color_variants = Lume(prop_gen.color_variants):map(function(variant)
		return PropColorVariant.FromRawTable(variant)
	end):result()
	return prop_gen
end

function UnderlayPropGen:GetLabel()
	return self.name or self.prop
end

function UnderlayPropGen:GetPropName()
	return self.prop
end

function UnderlayPropGen:GetDungeonProgressConstraints()
	return self.dungeon_progress_constraints
end

function UnderlayPropGen:Ui(ui, id, prop_browser, selected_color_variant)
	self.name = ui:_InputTextWithHint("Name"..id, self:GetLabel(), self.name)
	if self.name == "" then
		self.name = nil
	end

	ui:Text("Prop: "..self.prop)
	ui:SameLineWithSpace()
	if ui:Button(ui.icon.search..id) then
		prop_browser:Open(ui, PrefabBrowserContext.id.UnderlayProp)
	end
	ui:SetTooltipIfHovered("Choose different prop")

	selected_color_variant = PropColorVariant.ColorVariantsUi(self, ui, id.."ColorVariants", selected_color_variant)
	DungeonProgress.Ui(ui,id.."DungeonProgressConstraintsUi", self)
	return selected_color_variant
end

return UnderlayPropGen
