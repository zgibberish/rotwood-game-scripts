local Enum = require "util.enum"
local Grid = require "widgets.grid"
local Image = require "widgets.image"
local MapPathAutogenData = require "prefabs.mappath_autogen_data"
local MapRoom = require "widgets.ftf.maproom"
local Panel = require "widgets.panel"
local TallyMarks = require "widgets.ftf.tallymarks"
local Text = require "widgets.text"
local UIAnim = require "widgets.uianim"
local Widget = require "widgets.widget"
local easing = require "util.easing"
local kassert = require "util.kassert"
local krandom = require "util.krandom"
local lume = require "util.lume"
local templates = require "widgets.ftf.templates"
local fmodtable = require "defs.sound.fmodtable"
require "class"
require "vector2"


local FAST_FORWARD_DT_MULTIPLIER = 30

-- This map shows the rooms you've visited. Used on pause screen and travel
-- screen.

local DungeonHistoryMap = Class(Widget, function(self, ...) self:init(...) end)
	:SetGainFocusSound(nil)
	:SetHoverSound(nil)

local function noop() end

-- TODO(dungeonmap):
-- Option to show bounding boxes


local grid_unit = Vector2(72) -- size of one grid cell

local function TravelPath(connection_id)
	local path = UIAnim()
		:SetBank("dungeon_map_paths")
		:SetName(tostring(connection_id))
	return path
end

------------------------------------------------------------------------------------------
--- Map of the dungeon.
----

function DungeonHistoryMap.OffsetToAnimName(v)
	-- Anim name is in format x1y4
	local key_fmt = "x%dy%d"
	return key_fmt:format(
		math.abs(v.x),
		math.abs(v.y))
end

function DungeonHistoryMap.GetHorizontalDirection(path_data, idx)
	local dir = 1
	for i,step in ipairs(path_data.path) do
		if i >= idx then
			-- Our direction is based on previous steps and not our own.
			break
		end
		if step.is_turn then
			dir = dir * -1
		end
	end
	return dir
end

local function CreateOffsetDict(offsets)
	local t = {}
	for i,v in ipairs(offsets) do
		t[DungeonHistoryMap.OffsetToAnimName(v)] = v
	end
	return t
end


DungeonHistoryMap.BossPosition = Enum{
	"BottomRight",
	"TopRight",
}
DungeonHistoryMap.assets = {
	travel_offsets = CreateOffsetDict{
		-- These match the animations in dungeon_map_paths.fla
		Vector2(2, 4), -- x2y4
		Vector2(3, 1),
		Vector2(4, 0),
		Vector2(4, 1),
		Vector2(4, 2),
		Vector2(4, 3),
		Vector2(4, 4),
		Vector2(5, 4),
	},
	turn_offsets = CreateOffsetDict{
		-- These match the animations in dungeon_map_paths.fla
		-- (But anim names are absolute values.)
		Vector2(-3, 3),
		Vector2(-3, 5),
		Vector2(-3, 6),
		Vector2(-5, 3),
		Vector2(-5, 5),
		Vector2(-5, 6),
	},
}
DungeonHistoryMap.tuning = {
	bg_tile = {
		num_variations = 6,
	},
	path = {
		num_variations = {
			default = 3,
			-- Specify exceptions, if necessary:
			x4y0 = 3,
			x3y3_turn = 3,
		},
	},
	room_icon_width = 200,
	bg_tile_width = 760, -- hardcoded anim size because LayoutChildrenInGrid isn't working on anims
}

function DungeonHistoryMap:init(nav)
	Widget._ctor(self, "DungeonHistoryMap")
	kassert.typeof("table", nav)

	self.nav = nav
	self.onMapChangedFn = noop

	local biome_location = TheDungeon:GetDungeonMap():GetBiomeLocation()

	self.paper = self:AddChild(Widget("paper"))
		:SetGainFocusSound(nil)
		:SetHoverSound(nil)

	self.bg = self.paper:AddChild(Widget("bg"))
		:SetGainFocusSound(nil)
		:SetHoverSound(nil)
	self.bg.border = self.bg:AddChild(Image("images/bg_dungeonmap_paperborder/dungeonmap_paperborder.tex"))
		:SetMultColor(biome_location.map_colors.frame_tint)
		:SetAddColor(biome_location.map_colors.frame_add)
	self.bg.mask = self.bg:AddChild(Image("images/ui_dungeonmap/dungeonmap_mask.tex"))
		:SetMask()
		:SetScale(10) -- mask image is 10% of paperborder image

	local grid_count = Vector2(4, 2)
	local w = self.tuning.bg_tile_width
	self.bg.tile_root = self.bg:AddChild(Grid("tile_root"))
		:InitSize(grid_count.x, grid_count.y, w, w)
		:UseNaturalLayout()
		:SetMasked()
		:Offset(-1520, 0)
	local bankname = biome_location:GetDungeonMapBgTileBankName()
	for x=1,grid_count.x do
		for y=1,grid_count.y do
			self.bg.tile_root:AddItem(UIAnim(), x, y)
				:SetBank(bankname)
				:PlayAnimation(biome_location.id .. "1") -- arbitrary so there's something there
		end
	end
	--~ local test = self.bg.tile_root:GetChildren()[1]
	--~ d_view(test)

	self.bg.tile_root
		-- LayoutChildrenInGrid isn't properly laying out the children (even
		-- with CaptureCurrentAnimBBox), so I'm using Grid parent instead.
		--~ :LayoutChildrenInGrid(grid_count.x, 0)
		--~ :CenterChildren()
		:SendToBack()

	-- Just in case bg tiles don't load, add a fill texture.
	self.bg.fill = self.bg:AddChild(Image("images/square.tex"))
		:Offset(3.3, 10.1)
		:SetScale(47.2, 23.9)
		:SetMultColor(biome_location.map_colors.bg_tint)
		:SetAddColor(biome_location.map_colors.bg_add)
		:SendToBack()
	self.bg.fill.label = self.bg.fill:AddChild(Text(FONTFACE.DEFAULT, 200))
		:SetText("Missing background tile textures") -- unlocalized debug text.
		:SetGlyphColor(UICOLORS.DARK_TEXT_DARKER)
		:SetMultColorAlpha(0.117647)
	self.bg.fill.label:SetScale(Vector3.one:div(self.bg.fill.label:GetNestedScale()):unpack())

	self.bg.mask:SendToBack()

	self.node_root_position = self.paper:AddChild(Widget())
		:SetGainFocusSound(nil)
		:SetHoverSound(nil)
		:LayoutBounds("left", "bottom", self.bg)
		:Offset(243, 233) -- inside left bottom of border


	local function LabelBox()
		return templates.PaperLabelBox()
			:SetMultColor(biome_location.map_colors.frame_tint)
			:SetAddColor(biome_location.map_colors.frame_add)
	end
	self.title_root = self.paper:AddChild(LabelBox())
	self.title = self.title_root:AddChild(Text(FONTFACE.DEFAULT, FONTSIZE.DUNGEON_MAP_TITLE))
		:SetGlyphColor(UICOLORS.DARK_TEXT_DARKER)
		:SetHAlign(ANCHOR_MIDDLE)
		:SetText(biome_location.pretty.name_upper or biome_location.pretty.name)
		:LayoutBounds("center", "center", self.title_root)
	local deco_offset = 20
	local deco_color = UICOLORS.DARK_TEXT_DARKER
	local title_ornament = biome_location:GetRegion().title_ornament
	self.deco_left = self.title_root:AddChild(Image(title_ornament))
		:SetMultColor(deco_color)
		:LayoutBounds("before", "center", self.title)
		:Offset(-deco_offset, 0)
	self.deco_right = self.title_root:AddChild(Image(title_ornament))
		:SetMultColor(deco_color)
		:LayoutBounds("after", "center", self.title)
		:Offset(deco_offset, 0)
		:SetScale(-1, 1)

	local title_size = Vector2(
		self.title:GetSize() + self.deco_left:GetSize() * 3 + 130,
		122)
	self.title_root
		:SetSize(title_size:unpack())
		:LayoutBounds("center", "top", self.bg.border)
		:Offset(0, -29)

	self.tally_root = self.paper:AddChild(LabelBox())
		:SetName("TallyMarksRoot")
		:SetSize(700, 130) -- fit 20 marks
		:LayoutBounds("center", "bottom", self.bg.border)
		:Offset(0, 27)
	self.tally = self.tally_root:AddChild(TallyMarks())
		:SetMultColor(UICOLORS.DARK_TEXT_DARKER)
		:LayoutBounds("center", "center", self.tally_root)

	self.paper_width, self.paper_height = self.paper:GetSize()
	self.roll_scissored_width = self.paper_width -- fully scissored

	-- Show rolled paper anim over the contents
	self.paper_roll_root = self:AddChild(Widget("paper_roll_root"))
		:SetGainFocusSound(nil)
		:SetHoverSound(nil)
	self.paper_roll = self.paper_roll_root:AddChild(UIAnim())
		:SetName("Roll anim")
		:SetBank("dungeon_map_scroll")
		:PlayAnimation("idle")
		:SetMultColor(biome_location.map_colors.frame_tint)
		:SetAddColor(biome_location.map_colors.frame_add)

	self:_SetPaperRevealAmount(1)


	self.buttons = self:AddChild(Widget())
		:SetGainFocusSound(nil)
		:SetHoverSound(nil)
		:LayoutBounds("after", "top", self)
		:Offset(200, -220)

	self.debug_btn = self.buttons:AddChild(templates.Button("Dump World Info"))
		:SetDebug()
		:SetOnClick(function()
			d_dumpworldgen()
			self.roomid_btn.onclick()
			TheSim:OpenGameLogFolder()
		end)

	self.randomize_layout = self.buttons:AddChild(templates.Button("Re-roll layout"))
		:SetDebug()
		:SetOnClick(function()
			self:Debug_RandomizeVisuals()
		end)

	self.step_all = self.buttons:AddChild(templates.Button("Full Path - Random"))
		:SetDebug()
		:SetEnabled(TheNet:IsGameTypeLocal())
		:SetToolTip(not TheNet:IsGameTypeLocal() and "Only available in local games")
		:SetOnClick(function()
			self:Debug_ExpandFullPath()
		end)

	self.reveal_step = self.buttons:AddChild(templates.Button("Next Room"))
		:SetDebug()
		:SetEnabled(TheNet:IsHost())
		:SetToolTip(not TheNet:IsHost() and "Only available for hosts")
		:SetOnClick(function()
			local worldmap = TheDungeon:GetDungeonMap()
			local traveled = worldmap:Debug_StepDungeon(1, false)
			self._debug_travel_used = self._debug_travel_used or traveled
			self:_RebuildMapNodes()
			self.onMapChangedFn()
		end)

	self.buttons:LayoutChildrenInGrid(1, 10)

	if TheWorld:HasTag("town") then
		-- Buttons don't work in town since it doesn't have a mapgen biome.
		self.buttons:Hide()
	end
end

function DungeonHistoryMap:_SetPaperRevealAmount(amount_unrolled)
	local never_shown_width = 90 -- there's extra paper beyond the tiles
	local amount_rolled = 1 - amount_unrolled
	self.paper:SetScissor(
		-self.paper_width/2 - self.roll_scissored_width * amount_rolled,
		-self.paper_height/2,
		self.paper_width - never_shown_width,
		self.paper_height)
	self.paper_roll_root:LayoutBounds("after", "center", self.paper)
end

function DungeonHistoryMap:CreateAnimateInUpdater()
	local unroll_duration = 0.233

	self:_SetPaperRevealAmount(0)
	-- Don't be visible at all until we start animating in. Prevents flicker of visible map.
	self:Hide()

	return Updater.Series{
		Updater.Do(function()
			if not TheSaveSystem.cheats:GetValue("hide_travel_map") then
				self:Show()
			end
			self.paper_roll:PlayAnimation("land")
		end),
		self.paper_roll:CreateUpdater_AnimDone(),
		Updater.Wait(0.033),
		Updater.Do(function()
			self.paper_roll:PlayAnimation("rollright", true)
			TheFrontEnd:GetSound():PlaySound(fmodtable.Event.travelScreen_unroll)
			if self.travel_cardinal and self.travel_room_id then
				-- TheLog.ch.DungeonHistoryMap:printf("travel_cardinal = %s travel_room_id = %d", self.travel_cardinal, self.travel_room_id)
				local room = TheDungeon:GetDungeonMap():GetRoomData(self.travel_room_id)
				if not room then
					TheLog.ch.DungeonHistoryMap:printf("How did we pick an invalid direction? travel_cardinal[%s] to roomid[%s], current roomid[%s]",
						self.travel_cardinal, self.travel_room_id, TheDungeon:GetDungeonMap():GetCurrentRoomId())
				end

				if room and room.roomtype == "miniboss" or room.roomtype == "hype" then
					TheAudio:SetGlobalParameter(fmodtable.GlobalParameter.g_fadeOutMusicAndSendToReverb, 1)
					TheWorld:DoTaskInTime(1, function()
						TheLog.ch.Audio:print("***///***dungeonhistorymap.lua: Stopping all music because next clearing is miniboss or hype room.")
						TheWorld.components.ambientaudio:StopAllMusic()
					end)
				end
			end

		end),

		Updater.Parallel{
			-- Unroll and start playing stop *before* we finish so it plays
			-- during the transition from moving to stopped.
			Updater.Ease(function(v)
				self:_SetPaperRevealAmount(v)
			end, 0, 1, unroll_duration, easing.inOutQuad),
			Updater.Series{
				Updater.Wait(unroll_duration * 0.9),
				Updater.Do(function()
					self.paper_roll:PlayAnimation("stop")
						:PushAnimation("idle")
				end),
			},
		},
	}
end

function DungeonHistoryMap:Debug_RandomizeVisuals()
	self.nav.data.layout.ui_seed = self.nav.data.layout.ui_seed + 1
	self:_RebuildMapNodes()
	self.onMapChangedFn()
end

function DungeonHistoryMap:Debug_ExpandFullPath()
	local worldmap = TheDungeon:GetDungeonMap()
	local traveled = worldmap:Debug_StepDungeon(nil, true)
	self._debug_travel_used = self._debug_travel_used or traveled
	self:_RebuildMapNodes()
	self.onMapChangedFn()
end

function DungeonHistoryMap:DrawFullMap()
	-- prevent pause menu crash when debug jumping to boss battles
	if self.nav.data.is_cheat and self.nav.data.is_fresh_map then
		return self
	end

	self:_RebuildMapNodes()
	return self
end

function DungeonHistoryMap.BuildConnectionId(room_id_a, room_id_b)
	if room_id_a > room_id_b then
		room_id_a, room_id_b = room_id_b, room_id_a
	end
	assert(room_id_b < 10000, "Update connection builder to account for so many rooms.")
	local id = room_id_a * 10000 + room_id_b
	return id
end

local function _configure_map_node(nav, biome_location, node, room, current_rid)
	assert(node)
	node:SetLocatorColor(biome_location.map_colors.locator_tint)
	node:ConfigureRoom(nav, biome_location, room, current_rid)
end

function DungeonHistoryMap:SetOnMapChangedFn(fn)
	self.onMapChangedFn = fn
	return self
end

function DungeonHistoryMap:_RebuildMapNodes()
	if self.node_root then
		self.node_root:Remove()
	end
	self.node_root = self.node_root_position:AddChild(Widget())
		:SetGainFocusSound(nil)
		:SetHoverSound(nil)
	self.map_nodes = {}
	self.connectors = {} -- The lines connecting the rooms
	self.current_node = nil

	local current_rid = self.nav.data.current
	local final = self.nav:get_final_room()
	if final and final.index == current_rid then
		-- Don't show the boss room as a separate room from the hype room.
		current_rid = self.nav:get_hype_room_id()
	end

	for i=1,self:CalcRoomsForDungeon() do
		local node = self.node_root:AddChild(MapRoom())
		self.map_nodes[i] = node
	end

	for _, node in pairs(self.map_nodes) do
		node:Hide()
	end

	-- Configure and show the current rooms
	local biome_location = self.nav:GetBiomeLocation()
	local i = 0
	for rid,room in self.nav:IterateVisitedRooms(self.travel_cardinal) do
		i = i + 1
		local node = self.map_nodes[i]
		_configure_map_node(self.nav, biome_location, node, room, current_rid)
		node:Show()
		if rid == current_rid then
			self.current_node = node
		end
	end

	self.tally:SetToRoomsSeen(self.nav)

	self:_LayoutMap()

	-- Apply color tweaks after creating nodes so they apply recursively.

	-- Just this one is only the map background tiles
	self.bg.tile_root:SetMultColor(biome_location.map_colors.bg_tint)
	self.bg.tile_root:SetAddColor(biome_location.map_colors.bg_add)
	-- These two make up the frame around the map:
	--~ self.title_root:SetMultColor(biome_location.map_colors.bg_tint)
	--~ self.bg:SetMultColor(biome_location.map_colors.bg_tint)
	-- Tint the room icons and paths.
	self.node_root_position:SetMultColor(biome_location.map_colors.room_tint)
	self.node_root_position:SetAddColor(biome_location.map_colors.room_add)
end

function DungeonHistoryMap:EditDungeonPath(path_data, step_idx, editor_params)
	self.editor_forced_path = path_data
	self.editor_params = editor_params
	if self.editor_focused_connector then
		self.editor_focused_connector:StopPulse()
		self.editor_focused_connector = nil
	end
	if self.editor_focus_bg then
		self.editor_focus_bg:Remove()
		self.editor_focus_bg = nil
	end
	if path_data then
		self.editor_focus_step = step_idx
		self:Debug_ExpandFullPath()
	end
end

function DungeonHistoryMap:_FocusConnector(connector, offset)
	self.editor_focused_connector = connector
	self.editor_focused_connector:PulseAlpha(0.5, 1.0, 0.01)
	self.editor_focus_bg = self.node_root:AddChild(Panel("images/ui_ftf_pausescreen/map_selection.tex"))
		:Offset((self.editor_focused_connector:GetPositionAsVec2() + offset:scale(0.5)):unpack())
		:SetScale(2.554)
		:SetMultColorAlpha(0.25)
end

-- Includes entrance and hype, but not boss.
function DungeonHistoryMap:CalcRoomsForDungeon()
	return self.nav.data.max_depth + 1
end

function DungeonHistoryMap:_ChoosePath(rng)
	if self.editor_forced_path then
		return self.editor_forced_path
	end
	-- Path data length includes boss, but depth does not (since hype and boss are one room).
	local length = self:CalcRoomsForDungeon()
	local paths = lume.filter(MapPathAutogenData, function(path_data)
		return path_data.length == length
	end, true)
	if not next(paths) then
		TheLog.ch.WorldMap:printf("Warning: Failed to find path data for map with length %i.", length)
		paths = MapPathAutogenData
	end
	local path_name, path_data = rng:PickKeyValue(paths)
	TheLog.ch.WorldMapSpam:printf("Picked '%s' for length %i.", path_name, length)
	return path_data
end

function DungeonHistoryMap:_LayoutMap()
	local rng = krandom.CreateGenerator(self.nav.data.layout.ui_seed)

	-- Setup background tiles
	local biome_location = self.nav:GetBiomeLocation()
	local tiles = self.bg.tile_root:GetChildren()
	for _,w in ipairs(tiles) do
		w.anim_choice = rng:Integer(1, self.tuning.bg_tile.num_variations)
		w:PlayAnimation(biome_location.id .. w.anim_choice)
	end

	local path_data = self:_ChoosePath(rng)

	local boss_tile = tiles[#tiles] -- default BottomRight never appears in data.
	if path_data.boss_position == self.BossPosition.s.TopRight then
		boss_tile = tiles[#tiles - 1]
	end
	assert(boss_tile)
	local bossname = self.nav:GetDungeonBoss()
	boss_tile:PlayAnimation(bossname .."_boss".. boss_tile.anim_choice)

	local show_path_bounds = self.editor_params and self.editor_params.show_path_bounds

	local start_pos = Vector2(0, 0) -- position will be recalculated relative to boss later
	local pos = start_pos
	for i,path_step in ipairs(path_data.path) do
		local src = self.map_nodes[i]

		local ui_pos = pos:MultiplyComponents(grid_unit)
		src:SetPosition(ui_pos:unpack())

		local dest = self.map_nodes[i+1]
		if not dest then
			break
		end

		local anim = path_step.anim
		local offset = self.assets.travel_offsets[anim]
		if path_step.is_turn then
			offset = self.assets.turn_offsets[anim]
			anim = anim .. "_turn"
		end
		assert(offset, anim)
		offset = offset:clone()
		local sign = Vector2(DungeonHistoryMap.GetHorizontalDirection(path_data, i), path_step.sign or 1)
		offset = offset:MultiplyComponents(sign)

		if src.room and dest.room then
			local connector = self:_ConnectRoomIds(src.room.index, dest.room.index)
			if show_path_bounds then
				anim = anim .."_bounds"
				-- For now, the bounds aren't displaying so show debug widget instead.
				connector:SetShowDebugBoundingBox()
			else
				anim = anim .."_".. rng:Integer(1, self.tuning.path.num_variations[anim] or self.tuning.path.num_variations.default)
			end

			local s = Vector2(connector:GetScale()):MultiplyComponents(sign)
			connector:SetScale(s:unpack())
				:SetPosition(ui_pos:unpack())

			local pct = 0
			if dest.room.has_visited then
				pct = 1
			end
			connector:GetAnimState():SetPercent(anim, pct)
			connector:GetAnimState():Pause()
			if src.room.has_visited and not dest.room.has_visited then
				self.untravelled_path = {
					connector = connector,
					anim = anim,
					dest_node = dest,
				}
			end

			if self.editor_focus_step == i then
				self:_FocusConnector(connector, offset:MultiplyComponents(grid_unit))
			end
			src:Show()
			dest:Show()
		end

		pos = pos + offset
	end

	-- Shift the whole map to position the boss room on the boss tile.
	local nudge = (self.tuning.bg_tile_width - self.tuning.room_icon_width * 0.5) * 0.5
	local marker = boss_tile:AddChild(Widget("marker"))
		:SetGainFocusSound(nil)
		:SetHoverSound(nil)
		:Offset(nudge, nudge)
	marker:Reparent(self.node_root)

	local desired_pos = marker:GetPositionAsVec2()
	local hype_node = lume.last(self.map_nodes)
	local hype_pos = hype_node:GetPositionAsVec2()
	local delta = desired_pos - hype_pos
	self.node_root:Offset(delta:unpack())

	if self.editor_params
		and self.editor_params.ignore_boss_position
	then
		-- Easier to understand editing path changes without the above
		-- repositioning. Assume start is opposite corner from end.
		local y = 900
		if path_data.boss_position == self.BossPosition.s.TopRight then
			y = 100
		end
		self.node_root:SetPosition(0, y)
	end
end

function DungeonHistoryMap:_ConnectRoomIds(src_rid, dest_rid)
	local line_id = DungeonHistoryMap.BuildConnectionId(src_rid, dest_rid)
	--~ print("creating connection", src_rid, dest_rid)
	local line = self.connectors[line_id] or self.node_root:AddChild(TravelPath(line_id))
	self.connectors[line_id] = line
	line:SendToBack()
	return line
end

function DungeonHistoryMap:_AnimateCurrentPath()
	assert(self.untravelled_path, "We didn't find a current path!")
	self.untravelled_path.connector:GetAnimState():Resume()
	self.untravelled_path.connector:PlayAnimation(self.untravelled_path.anim)
	self.untravelled_path.connector:GetAnimState():SetDeltaTimeMultiplier(self:GetAnimMultiplier())
end

function DungeonHistoryMap:CreateTravelUpdater(cardinal, dest_room_id, total_duration, time_before_lock)
	self.travel_cardinal = cardinal
	self.travel_room_id = dest_room_id
	self:_RebuildMapNodes()

	self.current_node:EnsureLocatorExists()
	local dest_node = self.untravelled_path.dest_node
	dest_node:EnsureLocatorExists()
	dest_node:SetMultColorAlpha(0)

	local path_draw_duration = 2/3 -- from animation file
	local tally_duration = 1

	self.delay_remaining = 0.5 -- hold for visibility
	local function waiting_for_delay()
		self.delay_remaining = self.delay_remaining - GetTickTime() * self:GetAnimMultiplier()
		return self.delay_remaining > 0
	end
	return Updater.Series({
			Updater.While(waiting_for_delay),
			Updater.Do(function()
				self.tally:Increment()
				TheFrontEnd:GetSound():PlaySound(fmodtable.Event.travelScreen_tallyMark_down)
				self.delay_remaining = tally_duration
			end),
			Updater.While(waiting_for_delay),
			self.current_node:AnimateCurrentLocation(false, self:GetAnimMultiplier()),
			Updater.Do(function()
				self:_AnimateCurrentPath()

				-- sound setup
				local worldmap = TheDungeon:GetDungeonMap()
				self.dungeon_progress = worldmap.nav:GetProgressThroughDungeon()
				TheFrontEnd:GetSound():PlaySound(fmodtable.Event.travelScreen_walk)

				self.travel_LP = TheFrontEnd:GetSound():PlaySound_Autoname(fmodtable.Event.travelScreen_path_LP)
				TheFrontEnd:GetSound():SetParameter(self.travel_LP, "Music_Dungeon_Progress", self.dungeon_progress)
				self.delay_remaining = path_draw_duration
			end),
			Updater.While(waiting_for_delay),
			Updater.Do(function()
				TheFrontEnd:GetSound():KillSound(self.travel_LP)
				self.travel_LP = nil

				if self.travel_cardinal and self.travel_room_id then
					-- TheLog.ch.DungeonHistoryMap:printf("travel_cardinal = %s travel_room_id = %d", self.travel_cardinal, self.travel_room_id)
					local room = TheDungeon:GetDungeonMap():GetRoomData(self.travel_room_id)
					if not room then
						TheLog.ch.DungeonHistoryMap:printf("How did we pick an invalid direction? travel_cardinal[%s] to roomid[%s], current roomid[%s]",
							self.travel_cardinal, self.travel_room_id, TheDungeon:GetDungeonMap():GetCurrentRoomId())
					end

					if room and room.is_mystery and room.roomtype == "monster" then
						--sound for mystery room stinger
						TheFrontEnd:GetSound():PlaySound(fmodtable.Event.ui_sting_mysteryEncounter)
						TheWorld.components.ambientaudio:PlayMusicStinger(fmodtable.Event.Mus_mysteryEncounter_Stinger)
						TheLog.ch.Audio:print("***///***dungeonhistorymap.lua: Stopping all music because next clearing is mystery monster room.")
						TheWorld.components.ambientaudio:StopAllMusic()
					end
				end

				TheFrontEnd:GetSound():PlaySound(fmodtable.Event.travelScreen_destination_highlight)
				TheFrontEnd:GetSound():PlaySound(fmodtable.Event.travelScreen_walk_stop)
				if self.dungeon_progress == 1 then
					TheFrontEnd:GetSound():PlaySound(fmodtable.Event.travelScreen_destination_atBoss)
				end
			end),
			Updater.Parallel{
				-- Stamp down the room icon.
				Updater.Series{
					Updater.Ease(function(v) dest_node:SetScale(v) end, 2.6, 0.86, 0.2, easing.inQuad),
					Updater.Ease(function(v) dest_node:SetScale(v) end, 0.86, 1, 0.23, easing.outQuad),
				},
				Updater.Ease(function(v) dest_node:SetMultColorAlpha(v) end, 0, 1, 0.1 / self:GetAnimMultiplier(), easing.outQuint),
				dest_node:AnimateCurrentLocation(true, self:GetAnimMultiplier()),
			},
			Updater.Wait(0.5 / self:GetAnimMultiplier()),
			Updater.Do(function()
				TheLog.ch.DungeonHistoryMap:printf("Finished traveling")
			end),
	})
end

function DungeonHistoryMap:CreateTravelUpdater_Reverse(duration)
	-- TODO(dungeonmap): Remove
end

function DungeonHistoryMap:HideYouAreHere()
	for key,node in pairs(self.map_nodes) do
		node:SetCurrentLocation(false)
	end
end

function DungeonHistoryMap:GetAnimMultiplier()
	return self.travel_fast_forward and FAST_FORWARD_DT_MULTIPLIER or 1
end

function DungeonHistoryMap:FastForwardAnimations()
	self.travel_fast_forward = true
	if self.untravelled_path and self.untravelled_path.connector then
		self.untravelled_path.connector:GetAnimState():SetDeltaTimeMultiplier(FAST_FORWARD_DT_MULTIPLIER)
	end
	TheLog.ch.DungeonHistoryMap:printf("Fast forwarding ...")
end

-- TODO: force player to travel if this is used, because dungeon map state has irreversibly changed
function DungeonHistoryMap:Debug_TravelUsed()
	return self._debug_travel_used
end

function DungeonHistoryMap:DebugDraw_AddSection(ui, panel)
	DungeonHistoryMap._base.DebugDraw_AddSection(self, ui, panel)

	if not self.connectors then
		return
	end

	ui:Spacing()
	ui:Text("DungeonHistoryMap")

	ui:Indent() do
		if ui:Button("Test Scissor") then
			self:_SetPaperRevealAmount(0.75)
		end
		if ui:CollapsingHeader("_LayoutMap") then
			self.dbg_filter = ui:_InputText("Line ID Filter", self.dbg_filter or "")
			for line_id, node_connection in pairs(self.connectors) do
				if self.dbg_filter:len() == 0 or node_connection._widgetname:find(self.dbg_filter) then
					local start_node = node_connection.start_node
					local end_node = node_connection.end_node
					local start_pos = start_node:GetPositionAsVec2()
					local end_pos = end_node:GetPositionAsVec2()
					local angle = end_pos:AngleTo_Degrees(start_pos)
					ui:Text(node_connection._widgetname)
					ui:DragVec2f(start_node._widgetname, start_pos)
					ui:DragVec2f(end_node._widgetname, end_pos)
					ui:Value("AngleTo_Degrees ".. node_connection._widgetname, angle)
					ui:Value("AngleBetween_Degrees ".. node_connection._widgetname, end_pos:AngleBetween_Degrees(start_pos))
					ui:Spacing(20)
				end
			end
		end
	end
	ui:Unindent()
end

return DungeonHistoryMap
