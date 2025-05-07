local DebugDraw = require "util.debugdraw"
local DebugNodes = require "dbui.debug_nodes"
local iterator = require "util.iterator"

local Cosmetic = require "defs.cosmetics.cosmetics"

local CosmeticLister = Class(DebugNodes.DebugNode, function(self)
	DebugNodes.DebugNode._ctor(self, "Cosmetic Lister")
	self:RefreshData()
end)

CosmeticLister.PANEL_WIDTH = 800
CosmeticLister.PANEL_HEIGHT = 1000

function CosmeticLister:GetCSV()
	local str_tbl = {}
	
	local temp_tbl = {}
	for _, v in ipairs(self.data.cols) do
		table.insert(temp_tbl, v.name)
	end

	table.insert( str_tbl, table.concat(temp_tbl, ", ") )

	for _, item in ipairs(self.data.values) do
		temp_tbl = {}
		for _, v in ipairs(self.data.cols) do
			table.insert(temp_tbl, item[v.key])
		end

		table.insert( str_tbl, table.concat(temp_tbl, ", ") )
	end

	return table.concat( str_tbl, "\n" )
end

function CosmeticLister:RefreshData()
	self.data = {}

	self.data.cols = {
		{ key = "bodypart_group", name = "Group" },
		{ key = "name", name = "Name" },
		{ key = "species", name = "Species" },
		{ key = "locked", name = "Locked" },
		{ key = "hidden", name = "Hidden" },
	}

	self.data.values = {}

	local body_items = Cosmetic.Items["PLAYER_BODYPART"]
	for key, item in pairs(body_items) do
		local item_v = {}

		for _, v in ipairs(self.data.cols) do
			item_v[v.key] = tostring(item[v.key])
		end
		table.insert(self.data.values, item_v)
	end
end

function CosmeticLister:RenderPanel( ui, panel )

	if ui:Button("Copy CSV to Clipboard") then
		ui:SetClipboardText(self:GetCSV())
	end

	ui:Columns(#self.data.cols)

	for _, v in ipairs(self.data.cols) do
		ui:Text(v.name)
		ui:NextColumn()
	end

	ui:Separator()

	for _, item in ipairs(self.data.values) do
		for _, v in ipairs(self.data.cols) do
			ui:Text(item[v.key])
			ui:NextColumn()
		end
	end

	ui:Columns()

	self:AddFilteredAll(ui, panel, Cosmetic)
end

DebugNodes.CosmeticLister = CosmeticLister

return CosmeticLister
