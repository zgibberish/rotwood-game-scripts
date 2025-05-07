local SaveData = require "savedata.savedata"
local DataDumper = require "util.datadumper"

local DungeonSave = Class(SaveData, function(self, folder, file, save_pred)
	assert(folder ~= nil and file ~= nil and string.len(folder) > 0 and string.len(file) > 0)
	self.folder = folder
	self.file = file
	SaveData._ctor(self, self.folder.."/"..self.file, save_pred)
end)

function DungeonSave:ResolveRoomFolder()
	return self.folder.."/rooms"
end

function DungeonSave:ResolveRoomFilename(roomid)
	return string.format("%s/room%02d", self:ResolveRoomFolder(), roomid)
end

function DungeonSave:SaveCurrentRoom(roomid, cb)
	if not self:CanSave(self) then
		TheLog.ch.SaveLoad:printf("[DungeonSave:SaveCurrentRoom] Skipping save: %s (predicate did not pass)", self.file)
		if cb ~= nil then
			cb(true)
		end
		return
	end

	local savedata = {}

	for _, v in pairs(Ents) do
		if v.persists and v.prefab ~= nil and v.entity:GetParent() == nil and v:IsLocal() then	-- Only save local entities
			local record = v:GetSaveRecord()
			if savedata.ents == nil then
				savedata.ents = { [v.prefab] = { record } }
			else
				local t = savedata.ents[v.prefab]
				if t == nil then
					savedata.ents[v.prefab] = { record }
				else
					t[#t + 1] = record
				end
			end
		end
	end

	savedata.map =
	{
		prefab = TheWorld.prefab,
		scenegenprefab = TheSceneGen and TheSceneGen.prefab,
		data = TheWorld:GetPersistData(),
	}

	-- Save out the 'next' iterators of the encounter_deck. They are embedded in tables next to the lists
	-- that they index, so just save out the entire hierarchy rather than detangling now and retangling
	-- on load.
	local deck = TheDungeon:GetDungeonMap().encounter_deck
	savedata.room_type_encounter_sets = deck and deck.room_type_encounter_sets

	local PRETTY_PRINT = DEV_MODE
	local data = DataDumper(savedata, nil, not PRETTY_PRINT)
	local filename = self:ResolveRoomFilename(roomid)
	TheLog.ch.WorldGen:print("Saving room: /"..filename.."...")
	TheSim:SetPersistentString(filename, data, ENCODE_SAVES, function(success)
		if success then
			TheLog.ch.WorldGen:print("Successfully saved room: /"..filename)
		else
			TheLog.ch.WorldGen:print("Failed to save room: /"..filename)
			dbassert(false)
		end
		if cb ~= nil then
			cb(success)
		end
	end)
end

function DungeonSave:LoadRoom(roomid, cb)
	local filename = self:ResolveRoomFilename(roomid)
	TheLog.ch.WorldGen:print("Loading room: /"..filename.."...")
	TheSim:GetPersistentString(filename, function(success, data)
		if success and string.len(data) > 0 then
			success, data = RunInSandbox(data)
			if success and data ~= nil then
				TheLog.ch.WorldGen:print("Successfully loaded room: /"..filename)
				if cb ~= nil then
					cb(data)
				end
				return
			end
		end
		-- Not an error, we just haven't been here yet.
		TheLog.ch.WorldGen:print("No savedata, loading fresh room: /"..filename)
		if cb ~= nil then
			cb(nil)
		end
	end)
end

function DungeonSave:ClearAllRooms(cb)
	local folder = self:ResolveRoomFolder()
	TheLog.ch.WorldGen:print("Clearing rooms: /"..folder.."/*...")
	TheSim:EmptyPersistentDirectory(folder, function(success)
		if success then
			TheLog.ch.WorldGen:print("Successfully cleared rooms: /"..folder.."/*")
		else
			TheLog.ch.WorldGen:print("Failed to clear rooms: /"..folder.."/*")
			dbassert(false)
		end
		if cb ~= nil then
			cb(success)
		end
	end)
end

function DungeonSave:Erase(cb)
	local _cb = MultiCallback()

	DungeonSave._base.Erase(self, _cb:AddInstance())
	self:ClearAllRooms(_cb:AddInstance())

	_cb:WhenAllComplete(cb)
end

return DungeonSave
