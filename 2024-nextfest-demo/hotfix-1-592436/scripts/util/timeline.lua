local ease = require "util/ease"
local kassert = require "util/kassert"
local lume = require "util/lume"
local eventfuncs = require "eventfuncs"
require "class"


local SingleTimeline

-- Timeline for a set of events across multiple variables. Each timeline
-- contains a sequence of items and each item contains:
-- * start time,
-- * end time,
-- * and event data.
-- The event data is opaque, but could be a start/end pair or a curve. Each
-- timeline is a different key with its own set of data.
--
-- Input data is edited directly and we do not create our own backing store.
--
-- Timeline(int, {str,...}, {str={{int, int, {any}, ...}, ...})
--
-- Example:
--   Timeline(100,
--       {
--           'hue',
--           'brightness',
--       },
--       {
--           hue = {
--               { 0,  5,  {0,   1.0}, },
--               { 5,  9,  {1,   0.5}, },
--               { 16, 30, {0.5, 1.0}, },
--           },
--           brightness = {
--               { 20, 25, {1,   0.2}, },
--           },
--       },
--       {
--           hue = "Hue",
--           brightness = "Brightness",
--       })
--
local Timeline = Class(function(self, duration, keys, data, prettykeys)
	self._timelines = {}
	self._keys = keys
	self._editor_state = {
		duration = duration,
		row_colors = {},
	}
	if data then
		self:set_data(duration, keys, data, prettykeys)
	end
end)

function Timeline:has_data()
	if not self._dataset then
		return false
	end
	for element_key, items in pairs(self._dataset) do
		if items[1] then
			return true
		end
	end
end

local function ensure_complete_timeline_data(timelines, element_keys)
	for _,key in ipairs(element_keys) do
		timelines[key] = timelines[key] or {}
	end
end

local function strip_empty_timelines(timelines)
	for k, v in pairs(timelines) do
		if not next(v) then
			timelines[k] = nil
		end
	end
end

function Timeline:set_data(duration, keys, data, prettykeys)
	kassert.typeof("number", duration)
	kassert.typeof("table", keys)
	kassert.typeof("table", data)
	ensure_complete_timeline_data(data, keys)

	lume.clear(self._timelines)
	self._editor_state.duration = duration
	self._keys = keys
	if prettykeys then
		self._prettykeys = {}
		for i, key in ipairs(self._keys) do
			-- Make it the same order as keys to pass to TimelineEditor.
			table.insert(self._prettykeys, prettykeys[key])
		end
	end
	self._dataset = data
	for k, v in pairs(data) do
		self._timelines[k] = SingleTimeline(v)
	end
end

function Timeline:set_editor_frame(frame_number)
	kassert.typeof("number", frame_number)
	self._editor_state.current_frame = frame_number
end

function Timeline:get_current_frame()
	return self._editor_state.current_frame
end

function Timeline:set_row_color_fn(fn)
	self.row_color_fn = fn
end

function Timeline:get(key)
	return self._timelines[key]
end



-- Timeline for a single variable.
--
-- SingleTimeline({int, int, {any}, ...})
SingleTimeline = Class(function(self, data)
	self._data = data
end)

function SingleTimeline:has_data()
	return self._data and self._data[1] ~= nil
end


-- Find the index to place timecode. Also return the event at that time code if
-- it exists.
function SingleTimeline:find_index_for(timecode)
	local next_idx = 1
	for i, item in ipairs(self._data) do
		-- Each entry in _data is start+end timecode and an event:
		-- int, int, {any}
		local start_time = item[1]
		local end_time = item[2]
		if start_time <= timecode and timecode < end_time then
			return i, item
		end
		assert(timecode)
		assert(start_time)
		if timecode < start_time then
			return i
		end
		next_idx = i + 1
	end
	return next_idx
end

function SingleTimeline:_get_timecode_with_offset(timecode, offset)
	if not self:has_data() then
		return 0
	end
	local i = self:find_index_for(timecode)
	i = lume.clamp(i + offset, 1, #self._data)
	-- We're only interested in the start of the timecode.
	return self._data[i][1]
end

-- Convenience functions for editor.
function SingleTimeline:get_next_start_timecode(timecode)
	return self:_get_timecode_with_offset(timecode, 1)
end

function SingleTimeline:get_prev_start_timecode(timecode)
	return self:_get_timecode_with_offset(timecode, -1)
end

function SingleTimeline:get_last_end_timecode()
	local start_time = 0
	if self:has_data() then
		-- Use end time of last entry
		start_time = lume.last(self._data)[2]
	end
	return start_time
end
-- /Convenience functions

-- Add a new event. Modify event occurring at the start. Truncate the next event
-- if the new timeline would expand beyond the next event.
function SingleTimeline:add(start_time, end_time, event)
	assert(start_time < end_time, ("Start/end time were not sequential: %s %s"):format(start_time, end_time))
	local i, item = self:find_index_for(start_time)
	local j, next_item = self:find_index_for(end_time)
	if next_item then
		assert(j <= i + 1, "Adding a new time event that overlaps more than one item.")
		-- Adjust next time to avoid overlap with current.
		next_item[1] = end_time
	end
	if not item then
		assert(i and i > 0, "Even if item isn't found, we should always have an index.")
		item = {}
		table.insert(self._data, i, item)
	end
	item[1] = start_time
	item[2] = end_time
	item[3] = event
end

-- Remove any value that occurs at the input timecode.
function SingleTimeline:remove_at(timecode)
	local i, item = self:find_index_for(timecode)
	if item then
		table.remove(self._data, i)
	end
	return item ~= nil
end

-- Returns the progress and the event at that time code.
--
-- get_progress_for_time(number) -> float, {any}
function SingleTimeline:get_progress_for_time(timecode)
	if not self:has_data() then
		return 0
	end
	local i, current_item = self:find_index_for(timecode)
	current_item = self._data[i]
	if not current_item then
		-- use the end value for the previous item.
		current_item = self._data[i - 1]
		return 1, current_item[3]
	end
	if not current_item then
		error("How do we not have any items?")
		return 0
	end
	local start_time = current_item[1]
	local end_time = current_item[2]
	local period = end_time - start_time
	local progress
	if period == 0 then
		progress = 1
	else
		progress = (timecode - start_time) / period
	end
	progress = lume.clamp(progress, 0, 1)

	return progress, current_item[3]
end

-- If event data is a simple pair of numbers, we can interpolate between them.
--
-- get_value_for_time(number) -> float
function SingleTimeline:get_value_for_time(timecode)
	local progress, event = self:get_progress_for_time(timecode)
	kassert.typeof("table", event)
	kassert.typeof("number", progress, event[1], event[2])
	progress = ease.cubicinout(progress)

	assert(0 <= progress and progress <= 1, progress)
	return lume.lerp(event[1], event[2], progress)
end

local function is_invalid(item, i, j)
	local start_time = item[1]
	local end_time = item[2]
	return (not start_time
		or not end_time
		or end_time < 0
		or end_time < start_time)
end

local function GetPreviousSameRoleEvent(end_idx, data, role, sub_idx)
	local same_role_idx = nil
	for i = 1, end_idx - 1 do
		local prev_role = data[i][3].target_role
		local pre_sub_idx = data[i][3].sub_actor_idx

		if role == prev_role and (not pre_sub_idx or pre_sub_idx == sub_idx) then
			same_role_idx = i
		end
	end
	return same_role_idx -- No previous same role event.
end

function SingleTimeline:validate_data(duration)
	if not self:has_data() then
		return
	end
	-- end_time=-1 means deleted. Remove that and anything else weird.
	lume.removeall(self._data, is_invalid)
	for i, item in ipairs(self._data) do
		-- Clamp to [0, duration]
		local start_time = item[1]
		local end_time = item[2]
		local max_start = 0

		local no_overlap = true
		local always_can_overlap = false
		-- HACK: Allow overlaps for some eventfuncs.lua. Should move this can
		-- overlap query to a settable function to keep the overlap condition
		-- out of runtime data, but not be specific to eventfuncs.
		local eventdef = eventfuncs[item[3].eventtype]
		if eventdef then
			no_overlap = eventdef.no_overlap
			always_can_overlap = eventdef.always_can_overlap
		end

		local prev = self._data[i - 1]

		-- Timeline events with the same target should not overlap one another.
		if not always_can_overlap and not no_overlap then
			local prev_same_role_idx = GetPreviousSameRoleEvent(i, self._data, item[3].target_role, item[3].sub_actor_idx)
			if prev_same_role_idx then
				no_overlap = true
				prev = self._data[prev_same_role_idx]
			end
		end

		-- prevent overlap
		if prev and no_overlap then
			max_start = prev[2]
		end
		item[1] = math.max(start_time, max_start)
		if end_time > duration then
			item[2] = duration
		end
		-- All time values are ints in C++, so ensure no floats creep in.
		item[1] = math.floor(item[1])
		item[2] = math.floor(item[2])
	end
end



local function default_create_event_fn(owner, element_key, prev_event)
	local event = { 0, 1 }
	if prev_event then
		-- Copy previous end value
		event[1] = prev_event[2]
	end
	return 10, event
end

local function default_draw_event_fn(owner, ui, element_key, event, timecode_start, timecode_end)
	local key = element_key -- the element within the SingleTimeline.
	ui:Text(key)
	ui:Value("Start Frame", timecode_start)
	ui:Value("End Frame", timecode_end)
	local bounds = 1
	local modified
	modified, event.test = ui:SliderFloat("Test", event.test or 0, -bounds, bounds)
	ui:Text(table.inspect(event))
	return modified
end

-- If we don't have data, but have been initialized, setup enough
-- default content to have something saveable.
function Timeline:add_default_timeline(owner, create_event_fn)
	local key = self._keys[1]
	assert(key, "No keys!")
	local single = self:get(key)
	local duration, event = create_event_fn(owner, key, nil)
	single:add(0, duration, event)
end

-- Draw an imgui editor for the timeline.
--
-- create_event_fn creates the data passed into draw_event_fn.
--   create_event_fn(input owner, string) -> float, {any}
-- draw_event_fn returns true if modified.
--   draw_event_fn(input owner, userdata<imgui>, string, {any}) -> bool
function Timeline:RenderEditor(ui, owner, create_event_fn, draw_event_fn)
	if not draw_event_fn then
		-- These are a pair.
		create_event_fn = default_create_event_fn
		draw_event_fn = default_draw_event_fn
	end

	if not self:has_data() then
		if ui:Button("Add timeline") then
			self:add_default_timeline(owner, create_event_fn)
		end

		-- Abort! Don't try to draw if we have no data (TimelineEditor won't
		-- draw anything anyway).
		return
	end

	-- For simplicity, we only operate on tables with all their keys.
	ensure_complete_timeline_data(self._dataset, self._keys)

	local editor_data = {}
	lume.clear(self._editor_state.row_colors)
	for _, key in ipairs(self._keys) do
		-- Building up a table of pointers to our internal
		-- data, but in the format ui:TimelineEditor expects.
		table.insert(editor_data, self._dataset[key])
		if self.row_color_fn then
			for _,event in ipairs(self._dataset[key]) do
				local c = self.row_color_fn(key, event)
				assert(c)
				table.insert(self._editor_state.row_colors, c)
			end
		end
	end

	local timeline_modified, add_type = ui:TimelineEditor(
		self._prettykeys or self._keys,
		self._editor_state,
		editor_data)

	local any_changes = add_type or timeline_modified
	if add_type then
		local key = self._keys[add_type]
		local single = self:get(key)
		local start_time = single:get_last_end_timecode()
		local last_index = single:find_index_for(start_time - 0.01)
		local new_index = last_index
		if single:has_data() then
			-- find_index_for returns 1 if no data, so only increment when we have data.
			new_index = new_index + 1
		end
		local last_item = single._data[last_index]
		local last_event = last_item and last_item[3] or nil
		if start_time >= self._editor_state.duration then
			-- No space for new items, shrink previous one.
			last_item[2] = lume.lerp(last_item[1], last_item[2], 0.5)
			start_time = last_item[2]
		end
		local duration, event = create_event_fn(owner, key, last_event)
		single:add(start_time, start_time + duration, event)
		-- Select the new item
		self._editor_state.selected_type = add_type
		self._editor_state.selected_index = new_index
	end

	if self._editor_state.selected_type then
		local selected_key = self._keys[self._editor_state.selected_type]
		local items = self._dataset[selected_key]
		local selected_item = items[self._editor_state.selected_index]
		if selected_item then -- has data
			local start = selected_item[1]
			local stop = selected_item[2]
			local event = selected_item[3]
			local modified = draw_event_fn(owner, ui, selected_key, event, start, stop)
			any_changes = any_changes or modified
		end
	end

	if any_changes then
		for k, v in pairs(self._dataset) do
			self._timelines[k]:validate_data(self._editor_state.duration)
		end
	end

	-- Exclude empty timelines from savedata to avoid changing every cine when
	-- we add a new timeline.
	strip_empty_timelines(self._dataset)

	return any_changes, timeline_modified
end


local function test_SingleTimeline_add()
	local t = SingleTimeline({})
	assert(not t:has_data())
	t:add(10, 19, { 0.1, 0 })
	assert(t:has_data())
	kassert.equal(t._data[1][1], 10)
	kassert.equal(t:find_index_for(10), 1)

	kassert.equal(t:find_index_for(20), 2)
	t:add(20, 29, { 0.3, 0.1 })
	kassert.equal(t:find_index_for(20), 2)
	kassert.equal(t._data[2][1], 20)

	t:add(30, 39, { 0.5, 0.3 })
	t:add(40, 49, { 1.0, 0.5 })
	t:add(50, 51, { 0.0, 1.0 })

	for i = 1, 5 do
		kassert.equal(i, t:find_index_for(i * 10))
	end

	-- Modify 30,39 to be exactly adjacent with 40,49
	t:add(30, 40, { 1.0, 0.0 })

	kassert.equal(t._data[3][1], 30)
	kassert.equal(t._data[3][2], 40)
	kassert.equal(t._data[4][1], 40)
	kassert.equal(t._data[4][2], 49)

	-- Modify 30,39 to overlap with 40,49
	t:add(30, 45, { 1.0, 1.0 })

	kassert.equal(t._data[3][1], 30)
	kassert.equal(t._data[3][2], 45)
	kassert.equal(t._data[4][1], 45)
	kassert.equal(t._data[4][2], 49)
end

local function test_SingleTimeline_get_progress_for_time()
	local t = SingleTimeline({})
	assert(not t:has_data())

	t:add(30, 40, { 0.0, 1.0 })
	t:add(40, 45, { 1.0, 1.0 })

	assert(t:has_data())

	kassert.equal(t:get_progress_for_time(30), 0)
	kassert.equal(t:get_progress_for_time(35), 0.5)
	kassert.equal(t:get_value_for_time(35), ease.cubicinout(0.5))
	kassert.equal(t:get_value_for_time(32.5), ease.cubicinout(0.25))
	kassert.equal(t:get_value_for_time(30), 0)
	kassert.equal(t:get_value_for_time(40), 1)

	local prev = 0
	for i = 30, 40, 0.1 do
		local curr = t:get_progress_for_time(i)
		kassert.lesser_or_equal(prev, curr)
		prev = curr
	end
end

local function test_Timeline()
	local t = Timeline(10,
		{
			"h",
			"s",
			"b",
		},
		{
			h = {
				{ 0, 10, true },
			},
			s = {},
			b = {},
		})
	assert(t:has_data())
	t = Timeline()
	assert(not t:has_data())
	t:set_data(10,
		{
			"h",
			"s",
			"b",
		},
		{
			h = {},
			s = {},
			b = {},
		})
	assert(not t:has_data())

	t:get("h"):add(30, 40, { 0.0, 1.0 })
	assert(t:has_data())
	t:get("h"):add(40, 100, { 1.0, 1.0 })

	t:get("s"):add(0, 100, { 0.0, 1.0 })

	t:get("b"):add(0, 50, { 1.0, 1.0 })
	t:get("b"):add(50, 100, { 1.0, 1.0 })

	kassert.equal(t:get("h"):get_progress_for_time(30), 0)
	kassert.equal(t:get("s"):get_progress_for_time(30), 0.3)
	kassert.equal(t:get("b"):get_progress_for_time(30), 3 / 5)
end

return Timeline
