local DebugNodes = require "dbui.debug_nodes"
local EditorBase = require("debug/inspectors/editorbase")
local Equipment = require "defs.equipment"
local SaveAlert = require ("debug/inspectors/savealert")
local lume = require "util.lume"
local recipes = require "defs.recipes"

local primary_columns = {
	"name",
	"icon",
	"tags",
	"build",
	"text",
	"stats",
	"max_level",
}
local heading_dict = lume.invert(primary_columns)

local ItemEditor = Class( EditorBase, function(self, inst)

    self.name = "Item Editor"

	local data =
	{
		file = nil,
		data = nil,
		originaldata = nil,

		dirty = false,
	}

	EditorBase._ctor(self, data)

	self.selectedItemCategoryIndex = 1
	self.minColumnWidth = 80

	self.saveAlert = SaveAlert()

	self:OnCategoryChanged(1)
end)

ItemEditor.PANEL_WIDTH = 1280
ItemEditor.PANEL_HEIGHT = 800

-- Disabled since the item editor doesn't save changes anymore
--[[function ItemEditor:SetDirty()
	self.static.dirty = true
end]]

function ItemEditor:OnCategoryChanged(newSelectedIndex)
	self.selectedItemCategoryIndex = newSelectedIndex
	self.tableColumnWidths = nil
end

function ItemEditor:GetSelectedSlot()
	return Equipment.GetOrderedSlots()[self.selectedItemCategoryIndex]
end

function ItemEditor:GetSelectedCategoryContent()
	local slot = Equipment.GetOrderedSlots()[self.selectedItemCategoryIndex]
	return Equipment.Items[slot]
end


local function draw_item(panel, ui, t, item, column)
	if column == "icon" then
		ui:Text(t)
		local atlas, icon = GetAtlasTex(t)
		ui:AtlasImage(atlas, icon, 100, 100)
	elseif column == "tags" then
		local s = ""
		for key,val in pairs(t or {}) do
			s = ("%s%s, "):format(s, key)
		end
		ui:Text(s)
	elseif type(t) == "boolean" then
		ui:Checkbox("##" .. column, t)
	elseif type(t) == "table" then
		panel:AppendTable(ui, t, column)
		local s = ""
		for key,val in pairs(t) do
			s = ("%s%s: %s\n"):format(s, key, val)
		end
		ui:Text(s)
	else
		ui:Text(t)
	end
end

function ItemEditor:RenderPanel( ui, panel )

	local newSelectedIndex = ui:_Combo("Item Category", self.selectedItemCategoryIndex, Equipment.GetOrderedSlots())
	if newSelectedIndex ~= self.selectedItemCategoryIndex then
		self:OnCategoryChanged(newSelectedIndex)
	end

	local sorted_items = {}
	for _, itemdef in pairs(self:GetSelectedCategoryContent()) do
		table.insert(sorted_items, itemdef)
	end
	table.sort(sorted_items, function(a, b) return a.name < b.name end)

	-- Add any missing columns to the end
	local columns = lume.clone(primary_columns)
	for key,val in pairs(sorted_items[1]) do
		if not heading_dict[key] then
			table.insert(columns, key)
		end
	end

	if not self.tableColumnWidths then
		self.tableColumnWidths = {}
		local total = 0
		for _, column in ipairs(columns) do
			local heading_width = ui:CalcTextSize(column .. "____")
			local content_width = ui:CalcTextSize(tostring(sorted_items[1][column]) .. "____")
			local column_width = math.max(self.minColumnWidth, heading_width, content_width)
			table.insert(self.tableColumnWidths, column_width)
			total = total + column_width
		end
		self.total_width = total
	end

	ui:Separator()
    ui:Text("Equipment")

	-- Set width so we scroll horizontally.
	local win_width = ui:GetWindowSize() - 40 -- don't use full window width or we'll always have scrollbar
	local width = math.max(self.total_width, win_width)
	ui:SetNextWindowContentSize(width, 0)

	ui:BeginChild("#itemTable", 0, 0, true, ui.WindowFlags.HorizontalScrollbar | ui.WindowFlags.AlwaysAutoResize)

	-- Simpler read-only version.
	--~ panel:AppendTabularKeyValues(ui, columns, sorted_items, draw_item)

	-- Writeable version. You can't save these values -- edit Equipment.lua for
	-- that. We don't want to build items in a big table because it makes it
	-- harder to fixup old data (especially from mods).
    self:RenderItemTable(ui, panel, columns, sorted_items)

	ui:EndChild()

	-- Save alert when switching categories
	if self.saveAlert:IsActive() then
		self.saveAlert:Render(ui)
	end
end

function ItemEditor:RenderItemTable(ui, panel, column_headers, data)
    ui:Columns( #column_headers + 1, "itemTableColumns", true )

    for i, headerName in ipairs(column_headers) do
        ui:TextColored({0.33, 0.8, 0.73, 1.0}, tostring(headerName))
        ui:NextColumn()
    end
	ui:TextColored({0.33, 0.8, 0.73, 1.0}, "Recipe")
	ui:NextColumn()
    ui:Separator()
    for name, itemdef in pairs(data) do
		local i = name

		for _, column in pairs(column_headers) do
			local uid = "##" .. column .. "," .. i
			local columnWidth = 100
			local item_attribute = itemdef[column]

			ui:PushItemWidth(-1)

			if column == "stats" then
				ui:PushItemWidth(100)
				-- for stat,val in pairs(itemdef.stats) do
				-- 	local modified, new_value = ui:DragInt(stat .. uid, val)
				-- 	if modified then
				-- 		itemdef.stats[stat] = new_value
				-- 		--self:SetDirty()
				-- 	end
				-- end
				columnWidth = 200
				ui:PopItemWidth()

			elseif column == "tags" then
				for tag in pairs(itemdef.tags or {}) do
					ui:Text(tag)
				end

			elseif column == "icon" then
				local wasModified, newValue = ui:InputText(uid, itemdef.icon)
				if wasModified then
					self:SetItemValue(itemdef, 'icon', newValue)
				end

				local atlas, icon = GetAtlasTex(itemdef.icon)
				ui:AtlasImage(atlas, icon, 100, 100)

				columnWidth = nil

			elseif column == "name" then
				-- The id field is read-only
				ui:Text( item_attribute )
				columnWidth = 170

			elseif type(item_attribute) == "string" then
				local wasModified, newValue = ui:InputText(uid, item_attribute)
				if wasModified then
					itemdef[column] = newValue
					--self:SetDirty()
				end
				columnWidth = 100

			elseif type(item_attribute) == "number" then
				local wasModified, newValue = ui:InputText(uid, item_attribute, imgui.InputTextFlags.CharsDecimal)
				if wasModified then
					itemdef[column] = newValue
					--self:SetDirty()
				end
				columnWidth = nil

			elseif type(item_attribute) == "boolean" then
				local wasModified, newValue = ui:Checkbox(uid, item_attribute)
				if wasModified then
					itemdef[column] = newValue
					--self:SetDirty()
				end

			elseif type(item_attribute) == "table" then
				panel:AppendTable(ui, item_attribute, "Inspect")
				if type(next(item_attribute)) == "string" then
					local s = ""
					for key,val in pairs(item_attribute) do
						s = ("%s%s: %s\n"):format(s, key, val)
					end
					ui:Text(s)
					columnWidth = ui:CalcTextSize(s)
				end

			else
				ui:Text( "" )
			end

			-- Nil columnWidth means use autosize to attribute
			columnWidth = columnWidth or math.max(ui:CalcTextSize(column), ui:CalcTextSize(item_attribute)) + 25 -- Add extra because some characters get clipped
			self.tableColumnWidths[column] = math.max(self.tableColumnWidths[column] or 0, columnWidth)
			ui:SetColumnWidth(-1, self.tableColumnWidths[column])

			ui:PopItemWidth()

            ui:NextColumn()
        end


		local item_recipe = recipes.ForSlot[self:GetSelectedSlot()][itemdef.name]
		ui:PushItemWidth(100)
		if item_recipe then
			for ing_name,needs in pairs(item_recipe.ingredients) do
				local wasModified, newValue = ui:DragInt(ing_name .."##quantity"..itemdef.name, needs, 0.1, 0, 100)
				if wasModified then
					item_recipe.ingredients[ing_name] = newValue
					--self:SetDirty()
				end
			end
		else
			ui:TextColored(WEBCOLORS.LIGHTGRAY, string.format("No recipe for %s %s", itemdef.name, self:GetSelectedSlot()))
		end
		ui:PopItemWidth()
		ui:SetColumnWidth(-1, 400)
		ui:NextColumn()

		ui:Separator()
    end

    ui:Columns(1)
end

DebugNodes.ItemEditor = ItemEditor

return ItemEditor
