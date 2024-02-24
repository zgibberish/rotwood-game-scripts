local DungeonLayoutMap = require "widgets.ftf.dungeonlayoutmap"
local Image = require "widgets.image"
local UIAnim = require "widgets.uianim"
local Widget = require "widgets.widget"
local color = require "math.modules.color"
local easing = require "util.easing"
require "class"


local cardinal_data = {
	east = {
		offset = { 260, 0, },
		map_rot = 0,
		bounds = { vert = "center", horiz = "after", },
	},
	west = {
		offset = { -260, 0, },
		map_rot = 180,
		bounds = { vert = "center", horiz = "before", },
	},
	north = {
		offset = { 100, 260, },
		map_rot = -60,
		bounds = { vert = "before", horiz = "center", },
	},
	south = {
		offset = { 100, -260, },
		map_rot = 60,
		bounds = { vert = "after", horiz = "center", },
	},
}


-- A tiny map overlay to show where each exit leads.
local DungeonSignposts = Class(Widget, function(self)
	Widget._ctor(self, "DungeonSignposts")

	local worldmap = TheDungeon:GetDungeonMap()
	self.nav = worldmap.nav

	self.map = self:AddChild(Widget("map"))
		:Offset(130, 0)
		:SetScale(0.8)

	self.bg = self.map:AddChild(Image("images/ui_ftf/gradient_circle.tex"))
		:SetMultColor(color():alpha(0.5))
		:SetScale(5.0)
		:Offset(-200, 0)

	self.directions = self.map:AddChild(Widget("directions"))

	self.current = self.map:AddChild(UIAnim())
		:SetBank("dungeon_map_node_icons")
		:PlayAnimation("player")
		:SetMultColor(HexToRGB(0xEA5DF3FF))
		:SetAddColor(HexToRGB(0xEA5DF3FF))
		:UseAnimBBox()

	local biome_location = self.nav:GetBiomeLocation()
	local current_room_id = self.nav.data.current
	for cardinal,data in pairs(cardinal_data) do
		local room = worldmap:GetDestinationForCardinalDirection(cardinal)
		if room then
			self:AddDirection(cardinal, biome_location, room, current_room_id)
		end
	end

	-- Disable this when debugging so you can select with widget debugger.
	self:SetClickable(false)
end)

function DungeonSignposts.CanShowSignposts()
	local worldmap = TheDungeon:GetDungeonMap()
	-- Skip widget in boss area.
	return not worldmap:IsInBossArea()
end

function DungeonSignposts:AddDirection(cardinal, biome_location, room, current_rid)
	local data = cardinal_data[cardinal]
	self.directions[cardinal] = self.directions:AddChild(DungeonLayoutMap(TheDungeon:GetDungeonMap().nav))
		:DrawMapAfterRoomId(room.index, data)
		:SetRotation(data.map_rot)
		:Offset(table.unpack(data.offset))
		-- LayoutBounds around self.current doesn't look any good.

	return self.directions[cardinal]
end

function DungeonSignposts:AnimateIn()
	self:SetMultColorAlpha(0)
	local pos = self:GetPositionAsVec2()
	local start_pos = pos - Vector2.unit_x * 250
	self:SetPosition(start_pos)
	self:RunUpdater(Updater.Series({
				-- Short wait to see most of gate animation before we slide in.
				Updater.Wait(0.8),
				Updater.Parallel({
						Updater.Ease(function(v) self:SetMultColorAlpha(v) end, 0, 1, 0.1, easing.outQuad),
						Updater.Ease(function(v) self:SetScale(v) end, 1.075, 1, 0.5, easing.outQuad),
						Updater.Ease(function(v) self:SetPosition(start_pos:lerp(pos, v)) end, 0, 1, 0.5, easing.outQuad),
					}),
		}))
	return self
end

return DungeonSignposts
