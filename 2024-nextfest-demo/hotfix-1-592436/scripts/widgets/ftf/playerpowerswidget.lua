local Widget = require("widgets/widget")
local Image = require("widgets/image")
local PowerWidget = require("widgets/ftf/powerwidget")
local SkillWidget = require("widgets/ftf/skillwidget")
local FoodWidget = require("widgets/ftf/foodwidget")
local lume = require "util.lume"
local fmodtable = require "defs.sound.fmodtable"

local Power = require("defs.powers.power")

local MAX_POWERS_PER_ROW = 7

local PlayerPowersWidget = Class(Widget, function(self, owner)
	Widget._ctor(self, "PlayerPowersWidget")
	self:SetHoverSound(fmodtable.Event.hover)

	self.owner = owner

	self.power_size = 65 * HACK_FOR_4K
	self.static_slots = self:AddChild(Widget("Static Slots"))

	self.skill_root = self.static_slots:AddChild(Widget("Skill Root"))
	self.skill_bg = self.skill_root:AddChild(Image("images/ui_ftf_powers/common_skill.tex"))
		:SetMultColor(0,0,0,1)
		:SetSize(self.power_size, self.power_size)
	self.skill_widget = {}

	self.food_root = self.static_slots:AddChild(Widget("Food Root"))
	self.food_bg = self.food_root:AddChild(Image("images/ui_ftf_powers/food_empty.tex"))
		:SetSize(self.power_size, self.power_size)
	self.food_widget = {}

	self.powers_root = self:AddChild(Widget("Powers Root"))
	self.power_rows_idx = {}
	self.power_widgets = {}
	self.power_idxs = {}

	self:AddPowerRow()
	self:AddPowerRow()

	self.skill_root:LayoutBounds("left", "below", self.food_root)
		:Offset(- self.power_size/2, 5 * HACK_FOR_4K)

	self.inst:ListenForEvent("add_power", function(owner_, pow)
		assert(owner_ == self.owner)
		if pow.def.power_type == Power.Types.SKILL then
			if not self.skill_widget[pow.def.name] then
				self:SetSkill(pow.persistdata, true)
			end
		elseif pow.def.power_type == Power.Types.FOOD then
			if not self.food_widget[pow.def.name] then
				self:SetFood(pow.persistdata, true)
			end
		else
			if not self.power_widgets[pow.def.name] then
				self:AddPower(pow.persistdata, true)
			end
		end
	end, owner)

	self.inst:ListenForEvent("remove_power", function(owner_, pow)
		assert(owner_ == self.owner)
		if pow.def.power_type == Power.Types.SKILL then
			self:RemoveSkill()
		elseif pow.def.power_type == Power.Types.FOOD then
			self:RemoveFood()
		else
			if self.power_widgets[pow.def.name] then
				self.power_widgets[pow.def.name]:Remove()
				self.power_widgets[pow.def.name] = nil
				local idx = lume.find(self.power_idxs, pow.def.name)
				table.remove(self.power_idxs, idx)
				self:_LayoutPowers()
			end
		end
	end, owner)

	for _,pow in ipairs(owner.components.powermanager:GetAllPowersInAcquiredOrder()) do
		if pow.def.power_type == Power.Types.SKILL then
			self:SetSkill(pow.persistdata)
		elseif pow.def.power_type == Power.Types.FOOD then
			self:SetFood(pow.persistdata)
		else
			self:AddPower(pow.persistdata)
		end
	end
end)

function PlayerPowersWidget:RefreshPowers()
	for _,pow in ipairs(self.owner.components.powermanager:GetAllPowersInAcquiredOrder()) do
		if pow.def.power_type == Power.Types.SKILL then
			self:SetSkill(pow.persistdata)
		elseif pow.def.power_type == Power.Types.FOOD then
			self:SetFood(pow.persistdata)
		else
			self:AddPower(pow.persistdata)
		end
	end
end

local LAYOUT_LOGIC

function PlayerPowersWidget:_LayoutPowers()
	for _, power_name in ipairs(self.power_idxs) do
		local widget = self.power_widgets[power_name]
		if widget and not widget.parent then
			-- which row is best for this power?
			local best_row_num = MAX_POWERS_PER_ROW
			local best_row = nil

			for num_row, row_widget in ipairs(self.power_rows_idx) do
				local num_powers = #row_widget.children

				if num_powers < best_row_num then
					best_row_num = num_powers
					best_row = row_widget
				end
			end

			if not best_row then
				best_row = self:AddPowerRow()
			end
			best_row:AddChild(widget)
		end
	end

	LAYOUT_LOGIC[self.layout_mode or "TOP_LEFT"](self)

	self.owner:PushEvent("refresh_hud")
end

function PlayerPowersWidget:SetSkill(skill, fresh)
	local def = skill:GetDef()
	local w = self.skill_root:AddChild(SkillWidget(self.power_size, self.owner, skill))
	self.skill_widget[def.name] = w
	self:_LayoutPowers()
	if fresh then
		self.skill_root:SendToFront()
		w:AnimateFocusGrab(2.3)
	end
end

function PlayerPowersWidget:RemoveSkill()
	local name, skillwidget = next(self.skill_widget)
	if name and skillwidget then
		skillwidget:Remove()
		self.skill_widget[name] = nil
	end
end

function PlayerPowersWidget:SetFood(food, fresh)
	local def = food:GetDef()
	local w = self.food_root:AddChild(FoodWidget(self.power_size, self.owner, food))
	self.food_widget[def.name] = w
	self:_LayoutPowers()
	if fresh then
		self.food_root:SendToFront()
		w:AnimateFocusGrab(2.3)
	end
end

function PlayerPowersWidget:RemoveFood()
	local name, foodwidget = next(self.food_widget)
	if name and foodwidget then
		foodwidget:Remove()
		self.food_widget[name] = nil
	end
end

function PlayerPowersWidget:AddPower(power, fresh)
	local def = power:GetDef()
	
	if not self.power_widgets[def.name] then
		if not def.show_in_ui then return end
		local w = PowerWidget(self.power_size, self.owner, power)
		self.power_widgets[def.name] = w
		table.insert(self.power_idxs, def.name)
		self:_LayoutPowers()
		if fresh then
			w:AnimateFocusGrab(2.3)
		end
	end
end

function PlayerPowersWidget:AddPowerRow()
	local num_rows = #self.power_rows_idx + 1
	local row_root = self.powers_root:AddChild(Widget(string.format("Power Row %s", num_rows)))
	table.insert(self.power_rows_idx, row_root)
	return row_root
end

function PlayerPowersWidget:TOP_LEFT(mode)
	self.layout_mode = mode
	self:_LayoutPowers()
end

function PlayerPowersWidget:TOP_RIGHT(mode)
	self.layout_mode = mode
	self:_LayoutPowers()
end

function PlayerPowersWidget:BOTTOM_LEFT(mode)
	self.layout_mode = mode
	self:_LayoutPowers()
end

function PlayerPowersWidget:BOTTOM_RIGHT(mode)
	self.layout_mode = mode
	self:_LayoutPowers()
end

local reg_to_layout = {
	left = "after",
	right = "before",
	below = "top",
	above = "bottom",
}

function PlayerPowersWidget:_PositionPowers(hreg, vreg)
	local hsign = hreg == "left" and 1 or -1
	local vsign = vreg == "below" and 1 or -1
	for i, row in ipairs(self.power_rows_idx) do
		for num, child in ipairs(row.children) do
			child:SetPos((self.power_size + 5) * hsign * num, 0)
		end
	end

	local half_width = self.power_size/2
	for i = 2, #self.power_rows_idx do
		local w = self.power_rows_idx[i]
		w:LayoutBounds(hreg, vreg, self.power_rows_idx[i-1])
			:Offset(((i%2 == 0) and -1 or 1) * hsign * half_width, 5 * vsign)
	end

	self.skill_root:LayoutBounds(hreg, "below", self.food_root)
		:Offset(-hsign * vsign * half_width, 10)

	local hbound = reg_to_layout[hreg]
	local vbound = reg_to_layout[vreg]
	local pad = 20
	self.powers_root:LayoutBounds(hbound, vbound, self.static_root)
		:Offset((half_width - pad) * -hsign, -pad * vsign)
end

LAYOUT_LOGIC =
{
	TOP_LEFT = function(self)
		self:_PositionPowers("left", "below")
	end,

	BOTTOM_LEFT = function(self)
		self:_PositionPowers("left", "above")
	end,

	TOP_RIGHT = function(self)
		self:_PositionPowers("right", "below")
	end,

	BOTTOM_RIGHT = function(self)
		self:_PositionPowers("right", "above")

	end,
}

return PlayerPowersWidget
