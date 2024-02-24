local Widget = require("widgets/widget")
local Text = require("widgets/text")
local Image = require("widgets/image")
local itemforge = require "defs.itemforge"
local Power = require("defs.powers")
local lume = require("util/lume")
local EquipmentStatDisplay = require "defs.equipmentstatdisplay"

------------------------------------------------------------------------------------

local PowerVariableWidget = Class(Widget, function(self, width, text_size)
	Widget._ctor(self, "UpgradeableItem")

	self.text_size = text_size or 33
	self.width = width or 200

	self.label = self:AddChild(Text(FONTFACE.DEFAULT, self.text_size, "NAME", UICOLORS.DARK_TEXT))
		:LeftAlign()
	self.value = self:AddChild(Text(FONTFACE.DEFAULT, self.text_size, 1, UICOLORS.DARK_TEXT))
		:LeftAlign()
		:LayoutBounds("before", "center", self.label)
		:Offset(self.width, 0)
end)

function PowerVariableWidget:Refresh(power, var, compare_stacks)
	local name, old_val = power:GetPrettyVar(var)
	local str = ("%s"):format(old_val)

	if compare_stacks then
		local start_stacks = power.stacks
		power.stacks = compare_stacks
		local _, new_val = power:GetPrettyVar(var)
		power.stacks = start_stacks

		if new_val ~= old_val then
			str = ("%s  <#UPGRADE_DARK><p img='images/ui_ftf/arrow_right.tex' color=0 scale=0.4>  %s</>"):format(old_val, new_val)
		end
	end

	self.label:SetText(("%s %s"):format(STRINGS.UI.BULLET_POINT, name))
	self.value:SetText(str)
	self:_Layout()
end

-- Creates a widget with equal-width columns for each level in a row
function PowerVariableWidget:GenerateMultiLevelHeaderWidget(stat_levels, current_level)
	local column_width, column_height = 110, 40
	local divider = "  <p img='images/ui_ftf/arrow_right.tex' color=0 scale=0.4>" -- Suffixed at the end of columns
	local row = Widget("Multi-level header widget container")

	local text = ""
	for level, v in ipairs(stat_levels) do
		text = ""

		if level == current_level then
			text = text .. "<#GEM>"
		end

		text = text .. STRINGS.ITEMS.GEMS.ILVL_TO_NAME[level]

		if level == current_level then
			text = text .. "</>"
		end

		-- Add an arrow on every level except the last one
		if level < #stat_levels then
			text = text .. divider
		end

		row:AddChild(Text(FONTFACE.DEFAULT, self.text_size or FONTSIZE.SCREEN_TEXT, text, UICOLORS.DARK_TEXT))
			:RightAlign()
			:SetRegionSize(column_width, column_height)

	end

	row:LayoutChildrenInRow(0)

	return row
end

-- Creates a widget with equal-width columns for each level in a row
function PowerVariableWidget:GenerateMultiLevelStatWidget(stat_id, stat_levels, current_level)
	local column_width, column_height = 110, 40
	local divider = "  <p img='images/ui_ftf/arrow_right.tex' color=0 scale=0.4>" -- Suffixed at the end of columns
	local row = Widget()
		:SetName("Multi-level stat widget container")

	local text = ""
	for level, v in ipairs(stat_levels) do
		text = ""

		if level == current_level then
			text = text .. "<#GEM>"
		end

		local value = stat_levels[level]
		if EquipmentStatDisplay[stat_id] and EquipmentStatDisplay[stat_id].percent then
			value = value * 100
			value = lume.round(value, 0.1)

			if lume.round(value) == value then
				value = lume.round(value)
			end

			value = value.."%"
		end
		text = text .. value

		if level == current_level then
			text = text .. "</>"
		end

		-- Add an arrow on every level except the last one
		if level < #stat_levels then
			text = text .. divider
		end

		row:AddChild(Text(FONTFACE.DEFAULT, self.text_size or FONTSIZE.SCREEN_TEXT, text, UICOLORS.DARK_TEXT))
			:RightAlign()
			:SetRegionSize(column_width, column_height)

	end

	row:LayoutChildrenInRow(0)

	return row
end

function PowerVariableWidget:GenerateMultiLevelPowerWidget(stat_levels, current_level)

	local column_width, column_height = 110, 40
	local divider = "  <p img='images/ui_ftf/arrow_right.tex' color=0 scale=0.4>" -- Suffixed at the end of columns
	local row = Widget()
		:SetName("Multi-level stat widget container")

	local text = ""
	for level, v in ipairs(stat_levels) do
		text = ""

		if level == current_level then
			text = text .. "<#GEM>"
		end

		local value = stat_levels[level]
		text = text .. value

		if level == current_level then
			text = text .. "</>"
		end

		-- Add an arrow on every level except the last one
		if level < #stat_levels then
			text = text .. divider
		end

		row:AddChild(Text(FONTFACE.DEFAULT, self.text_size or FONTSIZE.SCREEN_TEXT, text, UICOLORS.DARK_TEXT))
			:RightAlign()
			:SetRegionSize(column_width, column_height)

	end

	row:LayoutChildrenInRow(0)

	return row
end

function PowerVariableWidget:SetGemStat(stat_id, stat_levels, current_level)
	self.label:SetText(STRINGS.UI.EQUIPMENT_STATS[string.upper(stat_id)].name)

	self.value:SetText("")
	if self.value_row then self.value_row:Remove() end
	self.value_row = self:AddChild(self:GenerateMultiLevelStatWidget(stat_id, stat_levels, current_level))

	self:_Layout()
	return self
end

function PowerVariableWidget:SetGemPower(power, stat_levels, gem)
	local rarity = power:GetRarity()
	local def = power:GetDef()

	local processed_stat_levels = {}
	for lvl,stacks in ipairs(stat_levels) do
		for name, val in pairs(def.tuning[rarity]) do
			local pretty = val:GetPrettyForStacks(stacks)
			table.insert(processed_stat_levels, pretty)
		end
	end

	local desc = STRINGS.ITEMS.GEMS[gem.id].stat_name

	self.label:SetText(desc) --)STRINGS.UI.EQUIPMENT_STATS[string.upper(stat_id)].name)

	self.value:SetText("")
	if self.value_row then self.value_row:Remove() end
	self.value_row = self:AddChild(self:GenerateMultiLevelPowerWidget(processed_stat_levels, gem.ilvl))

	self:_Layout()
	return self
end

function PowerVariableWidget:_Layout()
	self.value:LayoutBounds("before", "center", self.label)
		:Offset(self.width * 0.5, 0)
	if self.value_row then
		self.value_row:LayoutBounds("before", "center", self.label)
			:Offset(self.width * 0.5, 0)
	end
	return self
end

------------------------------------------------------------------------------------

local EquipmentDescriptionWidget = Class(Widget, function(self,width, text_size)
	Widget._ctor(self, "EquipmentDescriptionWidget")

	self.width = width
	self.powervariable_width_modifier = 1.3
	self.text_size = text_size or 35
	self.secondary_text_size = self.text_size - 6

	self.variable_widgets = {}

	self.power_desc = self:AddChild(Text(FONTFACE.DEFAULT, self.text_size, "Power Description", UICOLORS.DARK_TEXT))
		:SetAutoSize(width)
		:LeftAlign()

	self.variable_root = self:AddChild(Widget("Variable Root"))
end)

function EquipmentDescriptionWidget:SetItemDef(usagelvl, def, preview_upgrade)
	if not def.usage_data.power_on_equip then return self end

	local power_def = Power.FindPowerByName(def.usage_data.power_on_equip)
	local power = itemforge.CreatePower(power_def)
	local current_stacks = power_def.stacks_per_usage_level and power_def.stacks_per_usage_level[usagelvl]
	local next_stacks = power_def.stacks_per_usage_level and power_def.stacks_per_usage_level[usagelvl + 1]

	power.stacks = current_stacks

	self.power_desc:SetText(Power.GetDescForPower(power))

	local variables = lume.sort(lume.keys(power:GetTuning()))

	self.variable_root:RemoveAllChildren()

	for _, var in ipairs(variables) do
		self.variable_root:AddChild(PowerVariableWidget(self.width * self.powervariable_width_modifier, self.secondary_text_size))
			:Refresh(power, var, preview_upgrade and next_stacks or nil)
	end

	-- Layout
	self.variable_root:LayoutChildrenInAutoSizeGrid(1, 0, 5)
	self.variable_root:LayoutBounds("left", "below", self.power_desc)
		:Offset(0, -10)

	return self
end

function EquipmentDescriptionWidget:SetItem(item, preview_upgrade)
	self.item = item
	local usagelvl = item:GetUsageLevel()
	self.def = item:GetDef()

	if self.def.slot == "GEMS" then

		-- This is a gem!
		self.power_desc:SetText(self.def.pretty.slotted_desc) --changed so that the gem can have a longer description on the inventoryscreen but a straight-to-the-point desc on the gemscreen --Kris
		self.variable_root:RemoveAllChildren()

		local has_header = false
		if self.def.stat_mods then
			for stat_id, stat_levels in pairs(self.def.stat_mods) do
				if not has_header then
					has_header = true
					self.variable_root:AddChild(PowerVariableWidget:GenerateMultiLevelHeaderWidget(stat_levels, usagelvl))
				end

				self.variable_root:AddChild(PowerVariableWidget(self.width * self.powervariable_width_modifier, self.text_size))
					:SetGemStat(stat_id, stat_levels, usagelvl)
			end
		elseif self.def.usage_data and self.def.usage_data.power_on_equip then

			self.variable_root:RemoveAllChildren()

			local power_def = Power.FindPowerByName(self.def.usage_data.power_on_equip)
			local power = itemforge.CreatePower(power_def)

			self.variable_root:AddChild(PowerVariableWidget:GenerateMultiLevelHeaderWidget(power_def.stacks_per_usage_level, usagelvl))
			self.variable_root:AddChild(PowerVariableWidget(self.width * self.powervariable_width_modifier, self.text_size))
				:SetGemPower(power, self.def.usage_data.stacks, item)
		end

		if not self.variables_bg then
			self.variables_bg = self:AddChild(Image("images/ui_ftf_gems/gem_stats_bg.tex"))
				:SetHiddenBoundingBox(true)
				:SetMultColor(UICOLORS.BACKGROUND_LIGHT)
				:SetMultColorAlpha(0.1)
				:SendToBack()
		end

		-- Layout
		self.variable_root:LayoutChildrenInColumn(5, "right")
		local w, h = self.variable_root:GetSize()
		self.variables_bg:SetSize(w + 40, h + 20)
			:LayoutBounds("center", "center", self.variable_root)
		self.power_desc:LayoutBounds("left", "above", self.variable_root)
			:Offset(0, 20)

	elseif self.def.usage_data and self.def.usage_data.power_on_equip then
		self:SetItemDef(usagelvl, self.def, preview_upgrade)
	end

	return self
end

return EquipmentDescriptionWidget
