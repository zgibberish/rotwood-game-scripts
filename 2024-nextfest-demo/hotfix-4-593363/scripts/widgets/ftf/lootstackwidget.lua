local Widget = require("widgets/widget")
local LootWidget = require("widgets/ftf/lootwidget")
local easing = require "util.easing"
local Enum = require"util.enum"
local lume = require"util.lume"

local LootStackWidget =  Class(Widget, function(self, owner)
	Widget._ctor(self, "LootStackWidget")
	self:SetScaleMode(SCALEMODE_PROPORTIONAL)
	self.owner = owner

	self.loot_root = self:AddChild(Widget("Loot Root"))

	self.layout_x = "after"
	self.layout_y = "center"
	self.panel_offset = 10

	self.loot_panels = {}
	self.to_animate_in = {}
	self.animating_panel = nil
	self.done_animating_in = {}

	self.fade_out_time = 5
	self.fade_out_timer = self.fade_out_time

	-- listen for owner getting items
	self._on_get_loot = function(player, data) self:GetLoot(data) end
	self.inst:ListenForEvent("get_loot", self._on_get_loot, self.owner)

	-- d_view(self)
end)

function LootStackWidget:GetPanel(loot_name)
	return self.loot_panels[loot_name]
end

function LootStackWidget:MakePanelForLoot(data)
	-- add a new panel if you need to
	local panel = self.loot_root:AddChild(LootWidget(self.owner, data))
		:Hide()
	self.loot_panels[data.item.name] = panel
	table.insert(self.to_animate_in, panel)
end

function LootStackWidget:GetLoot(data)
	if self:GetPanel(data.item.name) then
		self.fade_out_timer = self.fade_out_time
		self:GetPanel(data.item.name):DeltaCount(data.count)
	else
		if not self.is_updating then
			self.fade_out_timer = self.fade_out_time
			self:StartUpdating()
		end
		self:MakePanelForLoot(data)
	end
end

function LootStackWidget:OnUpdate(dt)
	if #self.to_animate_in > 0 then
		self.fade_out_timer = self.fade_out_time -- reset fade out
		if self.animating_panel == nil then
			self.animating_panel = self.to_animate_in[1]

			local prev_widget = #self.done_animating_in > 0 and self.done_animating_in[#self.done_animating_in] or nil

			self.animating_panel:LayoutBounds(self.layout_x, self.layout_y, prev_widget)
				:Offset(self.panel_offset, 0)

			self.animating_panel:AnimateIn(self.layout_x, prev_widget, function()
				-- remove this widget from self.to_animate_in
				lume.remove(self.to_animate_in, self.animating_panel)
				-- add this widget to self.done_animating_in
				table.insert(self.done_animating_in, self.animating_panel)
				self.animating_panel = nil
			end)
		end
	else
		self.fade_out_timer = self.fade_out_timer - dt

		if self.fade_out_timer <= 0 then
			self:FadeOut()
		end
	end
end

function LootStackWidget:FadeOut()
	self:StopUpdating()

	for _, widget in ipairs(self.done_animating_in) do
		widget:RunUpdater(
			Updater.Series{
				Updater.Ease(function(v) widget:SetMultColorAlpha(v) end, 1, 0, 1, easing.linear),
				Updater.Do(function()
					lume.remove(self.done_animating_in, widget)
					lume.remove(self.loot_panels, widget)
					widget:Remove()
				end),
		})
	end
end

function LootStackWidget:TOP_LEFT()
end

function LootStackWidget:TOP_RIGHT()
	self.layout_x = "before"
	self.panel_offset = -10
end

function LootStackWidget:BOTTOM_LEFT()
end

function LootStackWidget:BOTTOM_RIGHT()
	self.layout_x = "before"
	self.panel_offset = -10
end


return LootStackWidget