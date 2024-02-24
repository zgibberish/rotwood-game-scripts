local DataDumper = require "util.datadumper"

-- Base class for handling save data to external files
local SaveData = Class(function(self, filename, save_pred)
	assert(filename ~= nil and filename:len() > 0)
	self.filename = filename
	self.persistdata = {}
	self.dirty = true
	assert(save_pred == nil or type(save_pred) == "function")
	if save_pred then
		TheLog.ch.SaveLoad:printf("%s has a save predicate.", filename)
	end
	self.save_pred = save_pred
	assert(self.version == nil, "Call SaveData constructor first in your constructor!")
	self:SetVersion(1)
end)

-- Set the version for this specific savedata bundle.
-- TODO: We should provide a list of upgrade functions.
function SaveData:SetVersion(version)
	assert(version)
	-- Store both on our self and in our persist data to separate expected from
	-- loaded versions.
	self.version = version
	self:SetValue("version", version)
	return self
end

function SaveData:SetValue(name, value)
	--Currently not bothering with deepcompare
	if self.persistdata[name] ~= value then
		self.persistdata[name] = value
		self.dirty = true
	end
	return self
end

function SaveData:IncrementValue(name)
	local v = (self:GetValue(name) or 0) + 1
	self:SetValue(name, v)
	return v
end

function SaveData:GetValue(name)
	return self.persistdata[name]
end

function SaveData:CanSave()
	if self.save_pred then
		TheLog.ch.SaveLoad:printf("Calling save predicate for %s...", self.filename)
		return self.save_pred()
	end
	return true
end

function SaveData:Save(cb)
	if not self:CanSave() then
		TheLog.ch.SaveLoad:printf("[SaveData:Save] Skipping save: %s (predicate did not pass)", self.filename)
		if cb ~= nil then
			cb(true) --success = true
		end
		return
	end

	if self.dirty then
		self:SetVersion(self.version)
		TheLog.ch.SaveLoad:print("Saving: /"..self.filename.."...")
		local PRETTY_PRINT = DEV_MODE
		local data = DataDumper(self.persistdata, nil, not PRETTY_PRINT)
		TheSim:SetPersistentString(self.filename, data, ENCODE_SAVES, function(success)
			if success then
				TheLog.ch.SaveLoad:print("Successfully saved: /"..self.filename)
				self.dirty = false
			else
				TheLog.ch.SaveLoad:print("Failed to save: /"..self.filename)
				dbassert(false)
			end
			if cb ~= nil then
				cb(success)
			end
		end)
	else
		TheLog.ch.SaveLoad:print("Skipping save: /"..self.filename)
		if cb ~= nil then
			cb(true) --success = true
		end
	end
end

-- Only when you don't care about failures! Mostly just for debug.
function SaveData:Load_ResetOnFailure(cb)
	assert(cb, "Why bother if you don't have a callback?")
	self:Load(function(success)
		if not success then
			self:Reset()
		end
		cb(true)
	end)
end

function SaveData:Load(cb)
	TheLog.ch.SaveLoad:print("Loading: /"..self.filename.."...")
	TheSim:GetPersistentString(self.filename, function(success, data)
		if success and string.len(data) > 0 then
			success, data = RunInSandbox(data)
			if success and data ~= nil then
				if self.version ~= data.version then
					-- Can't assert or the game will fail to start completely
					-- and you can't even reset your save data. Since we aren't
					-- upgrading saves yet, just note that this is where we'd
					-- do it.
					TheLog.ch.SaveLoad:print("Here's where we'd run the upgrade functions passed to SetVersion.")
				end
				self.persistdata = data
				self.dirty = false
				TheLog.ch.SaveLoad:print("Successfully loaded: /"..self.filename)
				if cb ~= nil then
					cb(true) --success = true
				end
				return
			end
		end
		TheLog.ch.SaveLoad:print("Failed to load: /"..self.filename)
		if cb ~= nil then
			cb(false) --success = false
		end
	end)
end

function SaveData:Reset()
	if next(self.persistdata) ~= nil then
		self.persistdata = {}
		self.dirty = true
	end
end

function SaveData:Erase(cb)
	self:Reset()
	TheLog.ch.SaveLoad:print("Deleting: /"..self.filename.."...")
	TheSim:CheckPersistentStringExists(self.filename, function(exists)
		if exists then
			TheSim:ErasePersistentString(self.filename, function(success)
				if success then
					TheLog.ch.SaveLoad:print("Successfully deleted: /"..self.filename)
					self.dirty = true
				else
					TheLog.ch.SaveLoad:print("failed to delete: /"..self.filename)
					dbassert(false)
				end
				if cb ~= nil then
					cb(success)
				end
			end)
		else
			TheLog.ch.SaveLoad:print("File not found: /"..self.filename)
			dbassert(self.dirty)
			if cb ~= nil then
				cb(true)
			end
		end
	end)
end

return SaveData
