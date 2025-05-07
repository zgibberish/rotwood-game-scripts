local Enum = require "util.enum"
local Image = require("widgets/image")
local Text = require "widgets.text"
local Widget = require "widgets.widget"
local lume = require "util.lume"


local PresentationType = Enum{ "PERCENT_ABSOLUTE", "PERCENT_RELATIVE", "VALUE", }

local StatStackCategory = Class(Widget, function(self, name, icon)
	Widget._ctor(self, "StatStackCategory")

	self.icon = self:AddChild(Image(icon))
	self.label = self:AddChild(Text(FONTFACE.DEFAULT))
		:SetText(name)
		:SetFontSize(42)
		:SetGlyphColor(HexToRGB(0x967D71FF))
		:LayoutBounds("after", "center", self.icon)
		:Offset(16, -2)
end)

local StatStackReading = Class(Widget, function(self, statstable, getreading_fn, presentationType, layoutReference, layoutPosition)
	Widget._ctor(self, "StatStackReading")

	self.getreading_fn = getreading_fn
	self.presentationType = presentationType
	self.layoutReference = layoutReference
	self.layoutPosition = layoutPosition

	self.current = self:AddChild(Text(FONTFACE.DEFAULT))
		:SetFontSize(42)
		:SetGlyphColor(HexToRGB(0x967D71FF))
		:SetHAlign(ANCHOR_RIGHT)

	self:UpdateValue(statstable)

	-- if delta ~= nil then
	-- 	local color
	-- 	local prefix = ""
	-- 	if delta > 0 then
	-- 		prefix = "+"
	-- 		color = HexToRGB(0x6DBC80FF)
	-- 	else
	-- 		color = HexToRGB(0XFB6564FF)
	-- 	end
	-- 	self.delta = self:AddChild(Text(FONTFACE.DEFAULT))
	-- 		:SetText(prefix..delta)
	-- 		:SetFontSize(42)
	-- 		:SetGlyphColor(color)
	-- 		:LayoutBounds("after", "center", self.current)
	-- 		:Offset(8, -1)
	-- end
end)

function StatStackReading:UpdateStats(statstable)
	self:UpdateValue(statstable)
end

function StatStackReading:UpdateValue(statstable)
	local current = self.getreading_fn(statstable)
	if current ~= self.last_value then	-- Only update if it changed (This will repeatedly be called, because of networking)
		self.last_value = current

		local text = current
		local relative_pct = self.presentationType == PresentationType.s.PERCENT_RELATIVE
		if self.presentationType == PresentationType.s.PERCENT_ABSOLUTE
			or relative_pct
		then
			local val = current * 100
			val = lume.round(val, 0.1)

			if lume.round(val) == val then
				val = lume.round(val)
			end

			if relative_pct then
				-- Always show a +- sign to indicate that it's relative to the
				-- normal amount (an extra 50%) and not just a total (100% is
				-- no bonus).
				text = string.format("%+.0f%%", val) --TODO(jambell): make localizable
			else
				text = val.."%" --TODO(jambell): make localizable
			end
		end
		self.current:SetText(text)
	end
end

function StatStackReading:UpdateLayout()
	local layoutPosition = self.layoutPosition
	local y_offset = layoutPosition == "above" and -10 or 5
	self.current:LayoutBounds("right", layoutPosition, self.layoutReference)
		:SetScale(1, 0.5) -- Undo the scale of the whole art
		:Offset(0, y_offset)
		:SetHAlign(ANCHOR_RIGHT)
end


-- For networking, we might be displaying players that are remote, and therefore don't have all the stats
-- synced. Therefore, instead of reading the stats from a player, make this playerstatstack work using a table
-- with values that are extracted from a player. This table can then be synced easily.
local function GatherStats(player)
	assert(player)

	local result = {}

	local inventoryhoard = player.components.inventoryhoard
	local stats = inventoryhoard:ComputeStats()

	result.health = player.components.health:GetMax()
	result.armour = stats.ARMOUR
	result.luck = player.components.lucky:GetTotalLuck()
	result.movespeed = player.components.locomotor:GetTotalSpeedMult()
	result.weapondamage = stats.DMG
	result.focusdamage = player.components.combat:GetTotalFocusDamageMult()
	result.critchance = player.components.combat:GetTotalCritChance()
	result.critdamage = player.components.combat:GetTotalCritDamageMult()

	return result
end

local function GetHealth(statstable)
	return statstable and statstable.health or 1
end

local function GetArmour(statstable)
	return statstable and statstable.armour or 1
end

local function GetLuck(statstable)
	return statstable and statstable.luck or 1
end

local function GetMovespeed(statstable)
	return statstable and statstable.movespeed or 1
end

local function GetWeaponDamage(statstable)
	return statstable and statstable.weapondamage or 1
end

local function GetFocusDamage(statstable)
	return statstable and statstable.focusdamage or 1
end

local function GetCritChance(statstable)
	return statstable and statstable.critchance or 1
end

local function GetCritDamage(statstable)
	return statstable and statstable.critdamage or 1
end

local PlayerStatStack = Class(Widget, function(self)
	Widget._ctor(self, "PlayerStatStack")

	self.ornamentscale = 1

	self.readings = {} -- A table which holds all of the actual readings of stats. Iterate through this and update to update stats.

	self.x_distance_left = 5
	self.x_distance_right = 155

	self.y_right_offset = 1

	self.y_row_center = -3
	self.y_row_above = self.y_row_center + 33
	self.y_row_below = self.y_row_center - 33

	self.category_padding_from_divider = 8

	self.bgContainer = self:AddChild(Widget())

	-- LEFT SIDE
	self.bgLeft = self.bgContainer:AddChild(Image("images/ui_ftf_relic_selection/stats_bg_left.tex"))
		:SetScale(self.ornamentscale)

	self.statsLeft = self.bgLeft:AddChild(Widget())
	self.health = 				self.statsLeft:AddChild(StatStackCategory(STRINGS.UI.EQUIPMENT_STATS.HP.name, "images/ui_ftf_relic_selection/stats_health.tex" ))
	self.divider_left_one = 	self.statsLeft:AddChild(Image("images/ui_ftf_relic_selection/stats_divider.tex"))
		:SetScale(1, 2)
	self.health_data = 			self.divider_left_one:AddChild(StatStackReading(nil, GetHealth, PresentationType.s.VALUE, self.divider_left_one, "above"))
	self.health_data:UpdateLayout()
	table.insert(self.readings, self.health_data)

	self.armour = 				self.statsLeft:AddChild(StatStackCategory(STRINGS.UI.EQUIPMENT_STATS.ARMOUR.name, "images/ui_ftf_relic_selection/stats_armour.tex" ))
	self.armour_data = 			self.divider_left_one:AddChild(StatStackReading(nil, GetArmour, PresentationType.s.PERCENT_ABSOLUTE, self.divider_left_one, "below"))
																			--player, getreading_fn, presentationType, layoutReference, layoutPosition
	self.armour_data:UpdateLayout()
	table.insert(self.readings, self.armour_data)

	self.divider_left_two = 	self.statsLeft:AddChild(Image("images/ui_ftf_relic_selection/stats_divider.tex"))
		:SetScale(1, 2)
	self.luck = 				self.statsLeft:AddChild(StatStackCategory(STRINGS.UI.EQUIPMENT_STATS.LUCK.name, "images/ui_ftf_relic_selection/stats_luck.tex" ))
	self.luck_data = 			self.divider_left_two:AddChild(StatStackReading(nil, GetLuck, PresentationType.s.PERCENT_ABSOLUTE, self.divider_left_two, "below"))
	self.luck_data:UpdateLayout()
	table.insert(self.readings, self.luck_data)

	self.divider_left_three = 	self.statsLeft:AddChild(Image("images/ui_ftf_relic_selection/stats_divider.tex"))
		:SetScale(1, 2)
	self.movespeed = 			self.statsLeft:AddChild(StatStackCategory(STRINGS.UI.EQUIPMENT_STATS.SPEED.name, "images/ui_ftf_relic_selection/stats_movspeed.tex" ))
	self.movespeed_data =		self.divider_left_three:AddChild(StatStackReading(nil, GetMovespeed, PresentationType.s.PERCENT_ABSOLUTE, self.divider_left_three, "below"))
	self.movespeed_data:UpdateLayout()
	table.insert(self.readings, self.movespeed_data)

	self.statsLeft:LayoutChildrenInGrid(1, 7)
		:LayoutBounds("center", "center", self.bgLeft)


	--RIGHT SIDE
	self.bgRight = self.bgContainer:AddChild(Image("images/ui_ftf_relic_selection/stats_bg_right.tex"))
		:SetScale(self.ornamentscale, self.ornamentscale)
		:LayoutBounds("after", "center", self.bgLeft)
		:Offset(-2, -3)

	self.statsRight = self.bgRight:AddChild(Widget())
	self.weapondamage = 		self.statsRight:AddChild(StatStackCategory(STRINGS.UI.EQUIPMENT_STATS.DMG.name, "images/ui_ftf_relic_selection/stats_weapondamage.tex" ))
	self.divider_right_one = 	self.statsRight:AddChild(Image("images/ui_ftf_relic_selection/stats_divider.tex"))
		:SetScale(1, 2)
	self.weapondamage_data =	self.divider_right_one:AddChild(StatStackReading(nil, GetWeaponDamage, PresentationType.s.VALUE, self.divider_right_one, "above"))
	self.weapondamage_data:UpdateLayout()
	table.insert(self.readings, self.weapondamage_data)

	self.critchance = 			self.statsRight:AddChild(StatStackCategory(STRINGS.UI.EQUIPMENT_STATS.CRIT.name, "images/ui_ftf_relic_selection/stats_criticalchance.tex" ))
	self.critchance_data =		self.divider_right_one:AddChild(StatStackReading(nil, GetCritChance, PresentationType.s.PERCENT_ABSOLUTE, self.divider_right_one, "below"))
	self.critchance_data:UpdateLayout()
	table.insert(self.readings, self.critchance_data)

	self.divider_right_two = 	self.statsRight:AddChild(Image("images/ui_ftf_relic_selection/stats_divider.tex"))
		:SetScale(1, 2)
	self.critdamage = 			self.statsRight:AddChild(StatStackCategory(STRINGS.UI.EQUIPMENT_STATS.CRIT_MULT.name, "images/ui_ftf_relic_selection/stats_criticaldamage.tex" ))
	self.critdamage_data =		self.divider_right_two:AddChild(StatStackReading(nil, GetCritDamage, PresentationType.s.PERCENT_RELATIVE, self.divider_right_two, "below"))
	self.critdamage_data:UpdateLayout()
	table.insert(self.readings, self.critdamage_data)

	self.divider_right_three = 	self.statsRight:AddChild(Image("images/ui_ftf_relic_selection/stats_divider.tex"))
		:SetScale(1, 2)
	self.focusdamage = 			self.statsRight:AddChild(StatStackCategory(STRINGS.UI.EQUIPMENT_STATS.FOCUS_MULT.name, "images/ui_ftf_relic_selection/stats_focusdamage.tex" ))
	self.focusdamage_data =		self.divider_right_three:AddChild(StatStackReading(nil, GetFocusDamage, PresentationType.s.PERCENT_RELATIVE, self.divider_right_three, "below"))
	self.focusdamage_data:UpdateLayout()
	table.insert(self.readings, self.focusdamage_data)

	self.statsRight:LayoutChildrenInGrid(1, 7)
		:LayoutBounds("center", "center", self.bgRight)
		:Offset(-40, 0)

end)

function PlayerStatStack:UpdateStatsForPlayer(player)
	self:UpdateStatsWithStatsTable(GatherStats(player))
end


-- This is the function that should be called to make it player independent (network requirement)
function PlayerStatStack:UpdateStatsWithStatsTable(statstable)
	for i,reading in ipairs(self.readings) do
		reading:UpdateStats(statstable)
	end
end

return PlayerStatStack
