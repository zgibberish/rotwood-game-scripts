local Widget = require("widgets/widget")
local LootWidget = require("widgets/ftf/lootwidget")
local easing = require "util.easing"

local PADDING = 10

local LootStackWidget =  Class(Widget, function(self, owner)
	Widget._ctor(self, "LootStackWidget")
	self:SetScaleMode(SCALEMODE_PROPORTIONAL)
	-- self:SetAnchors("right","top")
	self.owner = owner
	self.loot_root = self:AddChild(Widget("Loot Root"))
		:LayoutBounds("left", "center")

	self.layout_x = "left"
	self.layout_y = "below"

	self.loot_panels = {}
	self.loot_counts = {}

	-- listen for owner getting items
	self._on_get_loot = function(player, data) self:GetLoot(data) end
	self.inst:ListenForEvent("get_loot", self._on_get_loot, self.owner)
end)

function LootStackWidget:_LayoutLootWidgets()
	for i, data in pairs(self.loot_panels) do
		local padding = -PADDING
		if self.layout_y ~= "below" then
			padding = padding * -1
		end
		data.widget:LayoutBounds(self.layout_x, self.layout_y)
			:Offset(0, padding)
	end
end

function LootStackWidget:GetPanel(loot_name)
	for i, data in ipairs(self.loot_panels) do
		if data.name == loot_name then
			return data.widget
		end
	end
end

function LootStackWidget:GetLoot(data)
	-- update the count on a panel if you have one already
	self.loot_root:AlphaTo(1, 0, easing.linear)
	local panel = self:GetPanel(data.item.name)
	if not panel then
		-- add a new panel if you need to
		panel = self.loot_root:AddChild(LootWidget(self.owner, data.item, data.count))
		table.insert(self.loot_panels, { name = data.item.name, widget = panel })
		self.loot_counts[data.item.name] = data.count
		self:_LayoutLootWidgets()
		panel:AnimateIn(self.layout_x)
	else
		self.loot_counts[data.item.name] = self.loot_counts[data.item.name] + data.count
		panel:UpdateCount(self.loot_counts[data.item.name])
	end

	if self.fade_task then
		self.fade_task:Cancel()
	end

	self.fade_task = self.inst:DoTaskInTime(10, function()
		if self.loot_root ~= nil then
			self.loot_root:AlphaTo(0, 0.66, easing.linear, function()
				for i, lr_data in ipairs(self.loot_panels) do
					lr_data.widget:Remove()
				end
				self.loot_panels = {}
			end)

		end
	end)
end

function LootStackWidget:TOP_LEFT()
end


function LootStackWidget:TOP_RIGHT()
	self.layout_x = "right"
end

function LootStackWidget:BOTTOM_LEFT()
	self.layout_y = "above"
end

function LootStackWidget:BOTTOM_RIGHT()
	self.layout_x = "right"
	self.layout_y = "above"
end


return LootStackWidget