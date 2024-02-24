local DebugNodes = require "dbui.debug_nodes"
local Power = require "defs.powers"
local iterator = require "util.iterator"
local lume = require "util.lume"
local missinglist = require "util.missinglist"

-- Require things known use missinglist to ensure they all get processed.
require "defs.constructable"
require "defs.consumable"
require "defs.equipment"
require "defs.powers.power"


local DebugMissingAssets = Class(DebugNodes.DebugNode, function(self)
	DebugNodes.DebugNode._ctor(self, "Debug Missing Assets")

	self.filter = nil
end)

DebugMissingAssets.PANEL_WIDTH = 800
DebugMissingAssets.PANEL_HEIGHT = 1000


function DebugMissingAssets:RenderPanel( ui, panel )
	local missing = missinglist.GetAllMissing()

	local copy_visible = ui:Button(ui.icon.copy .." Visible")
	if ui:IsItemHovered() then
		ui:SetTooltip("Copy displayed lines.")
	end

	ui:SameLineWithSpace()
	if ui:Button(ui.icon.copy .." All") then
		ui:SetClipboardText(table.inspect(missing))
	end
	if ui:IsItemHovered() then
		ui:SetTooltip("Copy all lines.")
	end

	self.filter = ui:_FilterBar(self.filter, "Filter", "Only show items containing...")

	local displayed = {}
	for key,cat in iterator.sorted_pairs(missing) do
		local label = "%s (%d)"
		if ui:CollapsingHeader(label:format(key, lume.count(cat))) then
			for _,item in ipairs(cat) do
				if not self.filter or item.msg:find(self.filter) then
					-- Don't bother with the name.
					-- ui:Value(item.name, item.msg)
					ui:Text(item.msg)
					table.insert(displayed, item.msg)
				end
			end
		end
	end

	if ui:CollapsingHeader("Missing Power Strings") then
		ui:TextWrapped([[
Each variable in equipment powers needs a string. There are three ways for them to get names:
1. Name the variable the same as a STRINGS.NAMES.powerdesc string and it's automatically hooked up. (Preferred method!)
2. If we want a different variable name but to re-use one of those strings, add it to the map in GetStandardPowerDescVarPrettyName in itemforge.lua.
3. If we want a completely custom one, add it to a variables table in strings_items.lua.
]])
		ui:Separator()
		local missing_strings = self:_GetMissingPowerStrings()
		if next(missing_strings) then
			for _,item in ipairs(missing_strings) do
				if not self.filter or item.msg:find(self.filter) then
					ui:Text(item.msg)
					table.insert(displayed, item.msg)
				end
			end
		else
			ui:Text("Got 'em all!")
		end
	end

	if copy_visible then
		ui:SetClipboardText(table.concat(displayed, "\n"))
	end
end

function DebugMissingAssets:_GetMissingPowerStrings()
	local item = deepcopy(GetDebugPlayer().components.powermanager:CreatePower(Power.Items.EQUIPMENT.equipment_basic_head))
	local missing = {}
	local powers = Power.Items.EQUIPMENT
	for name,def in iterator.sorted_pairs(powers) do
		if def.pretty then
			item.id = name -- force change the id so we don't need to create a power for every item.
			for rarity,t in pairs(def.tuning) do
				for var in iterator.sorted_pairs(t) do
					local label = item:GetPrettyVar(var)
					if not label then
						table.insert(missing, {
								msg = string.format("%s: variable %s", name, var)
							})
					end
				end
			end
		else
			table.insert(missing, {
					msg = string.format("%s: All strings missing", name)
				})
		end
	end
	return missing
end

DebugNodes.DebugMissingAssets = DebugMissingAssets

return DebugMissingAssets
