local Image = require("widgets/image")
local Panel = require("widgets/panel")
local Text = require("widgets/text")
local Widget = require("widgets/widget")
local bossdef = require  "defs.monsters.bossdata"

------------------------------------------------------------------------------------------
--- Displays the main & mini bosses that will be fought in a given location
----

local LocationBossesWidget = Class(Widget, function(self, width, monsters)
	Widget._ctor(self, "LocationBossesWidget")
	self.width = width or 300 * HACK_FOR_4K

	self.monsterIconsRoot = self:AddChild(Widget("Monster Icons Root"))

	if monsters then
		self:SetMonsters(monsters)
	end

end)

function LocationBossesWidget:SetMonsters(monsters)
	-- Remove old ones
	self.monsterIconsRoot:RemoveAllChildren()

	-- Add minibosses
	local miniBossIconSize = 450
	if monsters.minibosses then
		for k, bossId in ipairs(monsters.minibosses) do
			-- Check if this boss has been seen
			local boss_unlocked = ThePlayer.components.unlocktracker:IsEnemyUnlocked(bossId)
			local icon = bossdef:GetBossIcon(bossId)
			local w = self.monsterIconsRoot:AddChild(Image(icon))
				:SetSize(miniBossIconSize, miniBossIconSize)
				:SetToolTip(STRINGS.NAMES[bossId])
				:SetToolTipLayoutFn(function(focus_widget, tooltip_widget)
					tooltip_widget:LayoutBounds("center", "bottom", focus_widget)
						:Offset(0, -20)
				end)

			if not boss_unlocked then
				w:SetMultColor(0,0,0)
					:SetToolTip(STRINGS.UI.MAPSCREEN.UNKNOWN_CREATURE)
			end
		end
	end

	-- Add bosses
	local bossIconSize = 550
	if monsters.bosses then
		for k, bossId in ipairs(monsters.bosses) do
			-- Check if this boss has been seen
			local boss_unlocked = ThePlayer.components.unlocktracker:IsEnemyUnlocked(bossId)
			local icon = bossdef:GetBossIcon(bossId)
			local w = self.monsterIconsRoot:AddChild(Image(icon))
				:SetSize(bossIconSize, bossIconSize)
				:SetToolTip(STRINGS.NAMES[bossId])
				:SetToolTipLayoutFn(function(focus_widget, tooltip_widget)
					tooltip_widget:LayoutBounds("center", "bottom", focus_widget)
						:Offset(0, -20)
				end)

			if not boss_unlocked then
				w:SetMultColor(0,0,0)
					:SetToolTip(STRINGS.UI.MAPSCREEN.UNKNOWN_CREATURE)
			end
		end
	end

	self:Layout()
	return self
end

function LocationBossesWidget:Layout()
	self.monsterIconsRoot:LayoutChildrenInRow(50, "bottom")
	return self
end

return LocationBossesWidget
