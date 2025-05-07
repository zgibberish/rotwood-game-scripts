local kassert = require "util.kassert"


-- TODO, make this a nested table? Or meh?

-- TODO(dbriscoe): Allow settings to fallback on other settings. That would let
-- us have a local setting that overrides content from the cloud sync'd
-- settings.

-- A single value stored within Settings (see below).
local SingleSetting = Class(function(self, name)
	self.name = name
end)

function SingleSetting:SetDefault(defaultvalue, datatype)
	-- Don't use nil as a default. We lose the clarity of looking in a save
	-- file and knowing what setting we expect to see.
	assert(defaultvalue ~= nil, "Must have a non nil default to clearly distinguish from 'no data'.")
	self.defaultvalue = defaultvalue
	self.datatype = type(defaultvalue)
	assert(not self.enum or self.enum:Contains(defaultvalue), "Default must be a string value from the enum.")
	return self
end

function SingleSetting:SetApplyFunction(func)
	self.applyfunction = func
	return self
end

-- Process the value before returning it.
-- Combined with SetApplyFunction, you can store one type of data in settings
-- but expose something different outside of settings. Useful for data may be
-- reordered between executions.
function SingleSetting:SetProcessFunctions(get_fn, set_fn)
	assert(get_fn and set_fn, "Both are required.")
	self.processors = {
		get_fn = get_fn,
		set_fn = set_fn,
	}
	return self
end

local function noop() end

-- Make it obvious which settings are queried directly instead of using
-- ApplyFunction and prevent the todo print when they're hooked up.
function SingleSetting:SetQueriedInsteadOfApplied()
	self.applyfunction = noop
	return self
end

function SingleSetting:Get()
	local value = self:RawGet()
	if self.processors then
		value = self.processors.get_fn(value)
	end
	return value
end

function SingleSetting:_ValidateValue(value, action)
	assert(self.datatype, "Forgot to call SetDefault. All settings must have a default value.")
	kassert.assert_fmt(
		type(value) == self.datatype,
		"Wrong type %s for setting %s. Expected %s, got %s.",
		action,
		self.name,
		self.datatype,
		type(value))
end

function SingleSetting:RawGet()
--	if self.isLocalSetting then
--		return TheSim:GetSystemSetting(self.name)
--	else
		local value = self.value
		if value == nil then
			value = self:GetDefault()
		end
		self:_ValidateValue(value, "stored")
		return value
--	end
end

function SingleSetting:GetDefault()
	return self.defaultvalue
end

function SingleSetting:Set(value)
	if self.processors then
		value = self.processors.set_fn(value)
	end
	return self:RawSet(value)
end

function SingleSetting:RawSet(value)
--	if self.isLocalSetting then
--		TheSim:SetSystemSetting(self.name, value)
--	else
		if value ~= nil then
			self:_ValidateValue(value, "set")
		elseif value == nil then
			value = self:GetDefault()
		end
		self.value = value
		if self.applyfunction then
			self.applyfunction(self.value)
		else
			TheLog.ch.Settings:print("TODO: ApplyFunction for "..self.name)
		end
--	end
end

-- Use enums so we can store string values that are easy to understand when
-- looking at the settings file and aren't incorrect when reordering settings.
function SingleSetting:SetEnum(enum)
	self.enum = enum
	return self
end

function SingleSetting:GetEnum()
	kassert.assert_fmt(self.enum, "Setting %s doesn't have an enum. Call SetEnum during setup.", self.name)
	return self.enum
end

function SingleSetting:Apply()
	local val = self:Get()
	self:Set(val)
	return val
end

function SingleSetting:SetLocalToCurrentMachine()
	self.isLocalSetting = true
	return self
end

-----------------------------------------------------------------------------------------------------------------------------

local Settings = Class(function(self, savename)
	assert(savename, "Must provide name for save file.")
	self.registered_settings = {}
	self.settings = {}
	self.savename = savename

	self.systemsettings = CreateEntity("SystemSettingsInterface")
	self.systemsettings.entity:AddGraphicsOptions()
end)

function Settings:GetGraphicsOptions()
	return self.systemsettings.GraphicsOptions
end

function Settings:SetVersion(version)
	self.version = version
	return self
end

function Settings:RegisterSetting(name, defaultvalue, setvalue, issystemspecific)
	assert(not self.settings[name], "Setting "..name.." already registered")
	local cats = string.split(name,".")
	local datatype = type(defaultvalue)
	local setting = SingleSetting(name, defaultvalue)
	self.settings[name] = setting
	return setting
end

function Settings:Set(name, value)
	local setting = self.settings[name]
	assert(setting, "Setting "..name.." is not registered")
	setting:Set(value)
end

function Settings:Get(name)
	local setting = self.settings[name]
	assert(setting, "Setting "..name.." is not registered")
	return setting:Get()
end

function Settings:EnumForSetting(name)
	local setting = self.settings[name]
	assert(setting, "Setting "..name.." is not registered")
	return setting:GetEnum()
end

function Settings:Apply(name)
	local setting = self.settings[name]
	assert(setting, "Setting "..name.." is not registered")
	return setting:Apply()
end

function Settings:ResetToDefaults()
	for i,v in pairs(self.settings) do
		v:Set(v:GetDefault())
	end
end

function Settings:GetSaveName()
	return self.savename
end

function Settings:GetSaveData()
	local settings = {}
	for i,v in pairs(self.settings) do
		settings[i] = v:RawGet()
	end
	local data = {
		version = self.version,
		settings = settings,
	}
	return data
end

-- Does not write any changes to disk!
function Settings:SetSaveData(data)
	if data and data.version ~= self.version then
		TheLog.ch.Settings:printf(
			"Attempted to load out of date '%s' settings (version: current[%s], loaded[%s]). Reverting to defaults.",
			self.savename,
			self.version,
			data.version)
		data = nil
	end

	if not data or not data.settings then
		for i,v in pairs(self.settings) do
			v:Set(nil)
		end
		return false -- failure: nothing to load so set defaults
	else
		for i,v in pairs(data.settings) do
			local setting = self.settings[i]
			assert(setting, "Setting "..i.." does not exist")
			setting:RawSet(v)
		end
		return true
	end
end

-- Write save data to disk
function Settings:Save(callback)
	local data = self:GetSaveData()
	-- In the past, we've accidentally added tables when serializing to json.
	-- Catch any errors and dump our settings to make these issues easy to
	-- resolve. Error usually looks like:
	--   scripts/json.lua:472: bad argument #1 to 'gsub' (string expected, got table)
	local success, msg = pcall(function()
		local str = json.encode(data)
		TheSim:SetPersistentString(self:GetSaveName(), str, ENCODE_SAVES, callback)
	end)
	if not success then
		error(table.concat({
					"Failed to serialize settings to json. See log for details.",
					msg,
					"Settings data:\n",
					table.inspect(data, { depth = 5, process = table.inspect.processes.skip_mt, })
				},
			"\n"))
	end
	return data
end

function Settings:Load(callback)
	TheSim:GetPersistentString(self:GetSaveName(),
		function(load_success, str)
			local data = str and #str > 0 and TrackedAssert("Settings:Load",  json.decode, str) or nil
			local success = self:SetSaveData(data)
			for key,setting in pairs(self.settings) do
				-- Since SetSaveData uses raw (it gets data from save file),
				-- processors didn't run to adapt to current environment
				-- (missing devices, etc).
				if setting.processors then
					setting:Set(setting:Get())
				end
			end
			callback(success)
		end, false)
end

return Settings
