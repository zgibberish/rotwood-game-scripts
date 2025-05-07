local DebugNodes = require "dbui.debug_nodes"
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

	if copy_visible then
		ui:SetClipboardText(table.concat(displayed, "\n"))
	end
end

DebugNodes.DebugMissingAssets = DebugMissingAssets

return DebugMissingAssets
