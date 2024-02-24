local Image = require "widgets.image"
local Text = require "widgets.text"
local UIAnim = require "widgets.uianim"
local Widget = require "widgets.widget"
local easing = require "util.easing"
local lume = require "util.lume"
require "class"


------------------------------------------------------------------------------------------
--- A single dungeon room on the map
----
local MapRoom = Class(Widget, function(self)
	Widget._ctor(self, "MapRoom")

	self.iconSize = 50
	self.relevant_icon_alpha   = 1 -- Alpha for current choice rooms
	self.irrelevant_icon_alpha = 0.6 -- Dim past rooms

	self.icons = {}
	self.icons.bg = self:AddChild(UIAnim())
		:SetBank("dungeon_map_node_icons")
	self.icons.roomicon = self:AddChild(UIAnim())
		:SetBank("dungeon_map_node_icons")
		--~ :SetMultColor(UICOLORS.LIGHT_TEXT_DARK)

	-- Give it some visual so I can see it for debug.
	self:SetRoomIcons({
			roomtype = "powerupgrade",
		},
		1,
		false)
end)

function MapRoom.GetColor_NextConnector()
	return HexToRGB(0xFFFFFFFF)
end

function MapRoom.GetColor_FutureConnector()
	return HexToRGB(0xCC93CCCF)
end

function MapRoom:SetTheme_SignpostNext()
	self:SetAddColor(HexToRGB(0xEE93FFFF))
	self:SetMultColor(HexToRGB(0xEE93FFFF))
	self.icons.bg:Hide()
	self:SetScale(1.5)
	return self
end

function MapRoom:SetTheme_SignpostFuture()
	self:SetAddColor(HexToRGB(0xAE8EC2FF))
	self:SetMultColor(HexToRGB(0xAE8EC2FF))
	self.icons.bg:Hide()
	self:SetScale(1)
	return self
end

function MapRoom:SetRelevant(is_relevant)
	-- We don't set relevant because it looks bad on uianims (the circle gets
	-- little corner cuts from the inside icon). Our map is much simpler now,
	-- so it doesn't really need it.
	--~ self.icons.roomicon:SetMultColorAlpha(is_relevant and self.relevant_icon_alpha or self.irrelevant_icon_alpha)
	return self
end

function MapRoom:IsRevealed()
	return self.isRevealed or false
end

function MapRoom:TrySetIcon(icon_widget, icon_name, size, is_relevant)
	if not icon_name then
		return self
	end
	icon_widget
		:PlayAnimation(icon_name)
		:Show()
	return self
end

function MapRoom:SetRoomIcons(icons, size, is_relevant)
	if icons.roomtype then
		self:TrySetIcon(self.icons.roomicon, icons.roomtype,            size, is_relevant)
		self:TrySetIcon(self.icons.bg,       icons.roomtype .."_under", size, is_relevant)
		self:SetRelevant(is_relevant)
	else
		self:Hide()
	end
	return self
end

function MapRoom:ApplyActionTint()
	local t = 45/255
	self.icons.bg:SetAddColor(t, t, t, 1)
	return self
end

function MapRoom:GetConnectionEndpoint(start_pos)
	return self:GetPositionAsVec2()
end

function MapRoom:SetCurrentLocation(is_player_here)
	self.is_player_here = is_player_here
	local coro = self:AnimateCurrentLocation(is_player_here)
	if coro then
		self.room_highlight_vis_updater = self:RunUpdater(coro)
	end
	return self
end

local room_locator_scale = 1.3
function MapRoom:EnsureLocatorExists()
	if self.roomBrackets then
		return
	end
	-- Add bg glow to hint current location.
	self.roomBrackets = self:AddChild(Image("images/ui_ftf/gradient_circle3.tex"))
		:SetHiddenBoundingBox(true)
		:SetScale(room_locator_scale)
		:SetBlendMode(BlendMode.id.Additive)
		:SetMultColor(self.bracket_tint)
		:IgnoreParentMultColor(true)
		:IgnoreParentAddColor(true)

	-- Layer between bg (visually part of tiles) and icon ("above" tiles).
	self.icons.roomicon:SendToFront()

	-- Room icons are anims so they don't have consistent enough size. Hardcode.
	local DungeonHistoryMap = require "widgets.ftf.dungeonhistorymap"
	local size = Vector2(DungeonHistoryMap.tuning.room_icon_width)
	self.roomBrackets:SetSize(size:unpack())

	-- Animate them
	local speed = 0.75
	local amplitude = 17
	local w, h = self.roomBrackets:GetSize()
	self.roomBrackets:RunUpdater(
		Updater.Loop({
				Updater.Ease(function(v) self.roomBrackets:SetSize(w + v, h + v) end, amplitude, 0, speed, easing.inOutQuad),
				Updater.Ease(function(v) self.roomBrackets:SetSize(w + v, h + v) end, 0, amplitude, speed, easing.inOutQuad),
		}))

	-- Default invisible so we can prelaod them.
	self.roomBrackets:SetMultColorAlpha(0)
end

function MapRoom:AnimateCurrentLocation(is_player_here, anim_speed_factor)
	anim_speed_factor = anim_speed_factor or 1

	if self.roomBrackets then
		self.roomBrackets:StopUpdater(self.room_highlight_vis_updater)
	end

	local full_alpha = self.bracket_tint[4]
	if is_player_here then
		local max_scale = 1.1 * room_locator_scale
		local function fn(v)
			self.roomBrackets:SetMultColorAlpha(full_alpha * v)
			self.roomBrackets:SetScale(lume.lerp(0.8, max_scale, v))
		end
		local frames = 1 / SecondsToAnimFrames(1) * anim_speed_factor
		return Updater.Series{
			Updater.Do(function()
				self:EnsureLocatorExists()
				self.roomBrackets:SetMultColorAlpha(full_alpha)
			end),
			Updater.Ease(fn, 0, 1, 6 * frames, easing.outQuad),
			Updater.Wait(6 * frames), -- need to hold or it looks bad blending into throb
			Updater.Ease(function(v)
				self.roomBrackets:SetScale(v)
			end, max_scale, room_locator_scale, 6 * frames, easing.inQuad),
		}

	elseif self.roomBrackets then
		-- We remove brackets during travel and looks much better to fade them.
		return Updater.Ease(function(v) self.roomBrackets:SetMultColorAlpha(v) end, full_alpha, 0, 0.3 / anim_speed_factor, easing.inCubic)
	end
end

function MapRoom:ConfigureRoom(nav, biome_location, room, current_rid)
	self:SetName("Room ".. room.index)
	self.room = room

	local is_current = room.index == current_rid

	-- Icon describing the contents of the room.
	local is_connected_to_current = (is_current
		or room.backlinks[current_rid])

	local size = self.iconSize
	local roomtype = nav:get_roomtype(room)
	if roomtype == 'boss'
		or roomtype == 'hype'
	then
		size = size * 1.5
	end
	self:SetRoomIcons({
			roomtype = nav:GetArtNameForRoom(room),
		},
		size,
		is_connected_to_current)

	if room.used_room_action then
		self:ApplyActionTint()
	end

	-- Must set after icon so icon has a size.
	self:SetCurrentLocation(is_current)


	-- Add text to show debug info about the room.
	self.debug_label = self.debug_label or self:AddChild(Text(FONTFACE.DEFAULT, FONTSIZE.BUTTON))
		:SetGlyphColor(WEBCOLORS.GOLD)
		:Offset(55, 60)

	local content = room.index
	--~ content = lume.count(room.connect) - 1
	--~ content = room.depth
	--~ content = room.roomtype
	--~ content = serpent.line(nav:get_pos_for_room_id(room.index))
	self.debug_label:SetText(content)
		:Hide()

	return self
end

function MapRoom:SetLocatorColor(tint)
	self.bracket_tint = tint
end

return MapRoom
