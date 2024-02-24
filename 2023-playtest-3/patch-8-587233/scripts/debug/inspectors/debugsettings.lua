local lume = require "util.lume"
require "class"


-- Simplify settings for our editors.
--
-- For game settings see settings.lua. Unlike Settings, DebugSettings are
-- intended to be edited with an imgui inspector and be a simple wrapper around
-- member variables.
local DebugSettings = Class(function(self, group_key)
	assert(group_key, "Expected something like 'embellisher.edit_options'")
	self.group_key = group_key
	self._storage = self:_GetSettings()
end)

-- Profile is a jungle, so keep all DebugSettings in a single table and each
-- individual one in its own subtable.
local ROOT_SETTINGS = "DebugSettings"
function DebugSettings:_GetSettings()
	local root_store = Profile:GetValue(ROOT_SETTINGS) or {}
	local store = root_store[self.group_key] or {}
	root_store[self.group_key] = store
	return store
end

function DebugSettings:_SetSettings()
	assert(self._storage, "Forgot to init.")
	-- Re-fetch from profile in case another editor was changing things.
	local root_store = Profile:GetValue(ROOT_SETTINGS) or {}
	root_store[self.group_key] = self._storage
	Profile:SetValue(ROOT_SETTINGS, root_store) -- mark dirty
end

function DebugSettings:Option(option_name, default)
	self[option_name] = self._storage[option_name]
	if default ~= nil and type(self[option_name]) ~= type(default) then
		-- Nil or type changed.
		self[option_name] = default
	end
	return self
end

function DebugSettings:Toggle(ui, key_pretty, key)
	if ui:Checkbox(key_pretty, self[key]) then
		self:Set(key, not self[key])
		self:Save()
		return true
	end
end

function DebugSettings:Enum(ui, key_pretty, key, options)
	table.sort(options)
	local idx = lume.find(options, self[key]) or 1
	local changed, newidx = ui:Combo(key_pretty, idx, options)
	if changed then
		self:Set(key, options[newidx])
		self:Save()
		return true
	end
end

function DebugSettings:Set(key, value)
	-- We store data on ourself and _storage to allow users to directly index
	-- us and have a clear table of data to store, without messing with
	-- __index.
	self[key] = value
	self._storage[key] = value
	self:_SetSettings()
	return self
end

-- Convenient way to assign to the idiomatic result of an imgui call by placing the imgui
-- call as the second parameter. E.g.:
-- self:SetIfChanged("roomtype", ui:Combo("##RoomType", self.roomtype, ROOM_TYPES))
function DebugSettings:SetIfChanged(key, changed, new_value)
	if changed then
		self:Set(key, new_value)
	end
end

function DebugSettings:SaveIfChanged(key, changed, new_value)
	if changed then
		self:Set(key, new_value)
		self:Save()
	end
end

function DebugSettings:Save()
	Profile:Save()
end

return DebugSettings
