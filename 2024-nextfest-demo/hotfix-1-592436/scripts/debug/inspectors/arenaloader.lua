local DebugSettings = require "debug.inspectors.debugsettings"
local SpecialEventRoom = require "defs.specialeventrooms"
local lume = require "util.lume"
local mapgen = require "defs.mapgen"
local scenegenutil = require "prefabs.scenegenutil"

local ROOM_TYPES = mapgen.roomtypes.RoomType:AlphaSorted()

local default = {
	levelname = "",
	location = "",
	entrance = 1,
	roomtype = "empty",
	reward = 1,
	difficulty = 1,
	mystery = next(SpecialEventRoom.Events),
	desired_progress = 0
}

local ROOM_TYPE_PATTERNS = {
	_hype_ = {"hype"},
	_small_ = {"food", "potion", "powerupgrade", "wanderer"},
	_boss_ = {"boss"},
	_start_ = {"entrance"}
}

local ArenaLoader = Class(DebugSettings, function(self, context)
	DebugSettings._ctor(self, context)
	lume(default):enumerate(function(k, v)
		self:Option(k, v)
	end)
	local worldmap = TheDungeon and TheDungeon:GetDungeonMap()
	if worldmap and worldmap.nav then
		self:Set("desired_progress", worldmap.nav:GetProgressThroughDungeon())
	end
end)

ArenaLoader.default = default

function ArenaLoader:GetRoomType()
	return self.roomtype
end

function ArenaLoader:CanStartArena()
	if not TheWorld then
		return false, "TheWorld is nil"
	end

	-- Check that the current levelname is compatible with the selected room type. This should not fail as we are only
	-- presenting valid options in the ui.
	for pattern, room_types in pairs(ROOM_TYPE_PATTERNS) do
		if lume(room_types):find(self:GetRoomType()):result()
			and not string.match(self.levelname, pattern)
		then
			return false, "Can't start arena ["..self.levelname.."] as room type ["..self:GetRoomType().."]; needs to match ["..pattern.."]"
		end
	end

	return true, ""
end

local function GetBossRoomDepth(depth_max)
	return depth_max + 1
end

local function GetHypeRoomDepth(depth_max)
	return depth_max
end

local function GetEntranceRoomDepth(depth_max)
	return 0
end
function ArenaLoader:StartArena(force_reload)
	if not self:CanStartArena() then
		return false
	end
	if self.roomtype == "ranger" then
		d_minigame(self.mystery, self.levelname, force_reload)
	elseif self.roomtype == "wanderer" then
		d_wanderer(self.mystery, self.levelname, force_reload)
	else
		-- 'Depth' is how many rooms deep into the dungeon we are.
		local room_depth
		if self.roomtype == "boss" then
			room_depth = GetBossRoomDepth
		elseif self.roomtype == "hype" then
			room_depth = GetHypeRoomDepth
		elseif self.roomtype == "entrance" then
			room_depth = GetEntranceRoomDepth
		else
			room_depth = function(depth_max)
				local entrance_depth = GetEntranceRoomDepth(depth_max)
				local hype_depth = GetHypeRoomDepth(depth_max)

				-- Compute depth in [entrance_depth, hype_depth]
				local depth = math.round(lume.lerp(entrance_depth, hype_depth, self.desired_progress))

				-- Our desired standard room range is a subset of progress range.
				return lume.clamp(depth, entrance_depth + 1, hype_depth - 1)

				-- Note that the resulting room depth is not necessarily precisely correlated to desired_progress due
				-- to the rounding and clamping. However, once the room reloads, we will re-align desired_progress to
				-- accurately reflect our dungeon depth.
			end
		end

		TheDungeon:GetDungeonMap():Debug_StartArena(self.levelname,
			{
				--~ last_entrance = self.entrances[self.test_options.entrance],
				location = self.location,
				difficulty = self.difficulty,
				roomtype = self.roomtype,
				reward = mapgen.Reward:FromId(self.reward),
				is_terminal = false, -- terminal suppresses resource rooms
				depth_fn = room_depth,
			})
	end
	return true
end

-- Return the room types that can be tested with the current level.
-- Determine valid room types by looking for patterns in levelname that map to room type sets.
function ArenaLoader:GetValidRoomTypes()
	local valid_room_types = deepcopy(ROOM_TYPES)
	for pattern, room_types in pairs(ROOM_TYPE_PATTERNS) do
		if string.match(self.levelname, pattern) then
			valid_room_types = room_types
			break
		else
			for _, room_type in ipairs(room_types) do
				local i = lume(valid_room_types):find(room_type):result()
				table.remove(valid_room_types, i)
			end
		end
	end
	return valid_room_types
end

function ArenaLoader:Ui(ui, id, suppress_location)
	local hype = self:GetRoomType() == "hype"
	local boss = self:GetRoomType() == "boss"
	local entrance = self:GetRoomType() == "entrance"

	local implicit_dungeon_progress
	if hype or boss then
		implicit_dungeon_progress = 1
	elseif entrance then
		implicit_dungeon_progress = 0
	end
	if implicit_dungeon_progress then
		ui:PushDisabledStyle()
	end
	local changed, new_desired_progress = ui:SliderFloat(
		"Dungeon Progress",
		implicit_dungeon_progress or self.desired_progress,
		0.0,
		1.0
	)
	self:SaveIfChanged("desired_progress", changed, new_desired_progress)
	if implicit_dungeon_progress then
		ui:PopDisabledStyle()
	end

	if not suppress_location then
		ui:PushItemWidth(150)
		local locations = scenegenutil.GetAllLocations()
		if #locations == 0 then
			ui:Text("No Locations are using world " .. self.levelname)
			self.location = nil
			self:Save()
		else
			if not lume(locations):find(self.location):result() then
				self.location = locations[1]
				self:Save()
			end
			self:SaveIfChanged("location", ui:ComboAsString("##Location", self.location, locations))
		end
		ui:PopItemWidth()
		ui:SameLineWithSpace()
	end

	ui:PushItemWidth(100)

	local same_line = false

	local valid_room_types = self:GetValidRoomTypes()
	if not lume(valid_room_types):find(self.roomtype):result() then
		self:Set("roomtype", valid_room_types[1])
	end
	if #valid_room_types > 1 then
		self:SaveIfChanged("roomtype", ui:ComboAsString("##RoomType", self.roomtype, valid_room_types))
		same_line = true
	end

	local is_ranger = self:GetRoomType() == "ranger"
	local is_wanderer = self:GetRoomType() == "wanderer"
	hype = self:GetRoomType() == "hype"
	boss = self:GetRoomType() == "boss"
	if is_ranger or is_wanderer then
		local target_category = is_ranger and SpecialEventRoom.Types.MINIGAME or SpecialEventRoom.Types.CONVERSATION
		local names = lume(SpecialEventRoom.Events)
			:filter(function(v)
				return v.category == target_category
			end, true)
			:keys()
			:sort()
			:result()
		if same_line then
			ui:SameLineWithSpace()
		end
		ui:SetNextItemWidth(200)
		self:SaveIfChanged("mystery", ui:ComboAsString("##Mystery", self.mystery, names))
		same_line = true
	elseif not (hype or boss or entrance) then
		if same_line then
			ui:SameLineWithSpace()
		end
		self:SaveIfChanged("reward", ui:Combo("##Reward", self.reward, mapgen.Reward:Ordered()))
		same_line = true

		if same_line then
			ui:SameLineWithSpace()
		end
		self:SaveIfChanged("difficulty", ui:Combo("##Difficulty", self.difficulty, mapgen.Difficulty:Ordered()))
		same_line = true
	end

	ui:PopItemWidth()
end

return ArenaLoader
