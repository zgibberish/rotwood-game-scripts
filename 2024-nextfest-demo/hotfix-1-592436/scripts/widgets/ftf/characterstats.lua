local Widget = require("widgets/widget")
local DisplayStat = require("widgets/ftf/displaystat")

------------------------------------------------------------------------------------------
--- Displays player character stats
----
local CharacterStats = Class(Widget, function(self, width, columns, column_spacing)
	Widget._ctor(self, "CharacterStats")

	self.width = width
	self.columns = columns or 2
	self.column_spacing = column_spacing or 20 * HACK_FOR_4K
	self.stat_width = (self.width - (self.columns-1)*self.column_spacing)/self.columns

	self.statsContainer = self:AddChild(Widget())
end)

function CharacterStats:SetPlayer(player, statsData)
	self.player = player

	-- Remove old stats
	self.statsContainer:RemoveAllChildren()

	-- Add new ones
	local index = 1
	local count = table.numkeys(statsData)
	local is_last_row = false
	for id, data in pairs(statsData) do

		-- We want the underline to show on all stats except the ones in the last row
		is_last_row = math.ceil(index/self.columns) == math.ceil(count/self.columns)

		-- Display stat widget
		self.statsContainer:AddChild(DisplayStat(self.stat_width))
			:SetLightBackgroundColors()
			:ShouldShowToolTip(true)
			:ShowUnderline(not is_last_row, 4, UICOLORS.LIGHT_TEXT)
			:SetStat(data)

		index = index + 1
	end

	-- Layout
	self.statsContainer:LayoutChildrenInGrid(self.columns, {h = self.column_spacing, v = 10 * HACK_FOR_4K})
end

return CharacterStats
