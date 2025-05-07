local DungeonSave = require "savedata.dungeonsave"
local PlayerSave = require "savedata.playersave"
local ProgressSave = require "savedata.progresssave"
local SaveData = require "savedata.savedata"

local NUM_CHARACTER_SLOTS = 4

local SaveSystem = Class(function(self)
	-- Save cheat data that will persist between rooms (to force specific rooms
	-- or powers). Erased on startup, to prevent locally broken behaviour.
	self.cheats = SaveData("cheats")

	-- Permanent data we never delete (even when player resets their save) to
	-- help distinguish smurf players in feedback. Put data in here you want to
	-- track with feedback, but don't use it in logic.
	self.permanent = SaveData("permanent")

	self.character_slots = {}
	for i = 0, NUM_CHARACTER_SLOTS - 1 do
		self.character_slots[i] = PlayerSave(i)
	end

	-- Information about all players that persists between launches (unlike
	-- active_players). Per-player data should go in character_slots.
	self.about_players = SaveData("about_players")

	-- saves what (local) players are currently active?
	-- how do remote players work/ save? We probably don't want to save these locally.
	self.active_players = SaveData("active_players")


	self.friends = SaveData("friends") -- unknown how (or if) this will be used, am not going to touch it for now

	-- world progress, not player progress
	self.progress = ProgressSave("progress")

	-- use a save predicate -- currently, only hosts should save towns
	self.town = DungeonSave("town", "town", function()
		local isHost = TheNet:IsHost() -- can return true for legacy purposes when "offline"
		local isInGame = TheNet:IsInGame() -- need to test if not in a game session (i.e. if the host disconnects before the client)
		TheLog.ch.SaveLoad:printf("    Checking - is host: %s, in game: %s", isHost, isInGame)
		return isHost and isInGame
	end)

	self.dungeon = DungeonSave("dungeon_temp", "dungeon")
end)

function SaveSystem:ErasePlayerSave(idx)

end

function SaveSystem:IsSlotActive(slot)
	local local_players = TheNet:GetLocalPlayerList()
	for _, id in pairs(local_players) do
		-- because playerID starts at 0 instead of 1, they must be tostring'd or the tables behave strangely.
		if self.active_players:GetValue(tostring(id)) == slot then
			return true
		end
	end
	return false
end

function SaveSystem:IsPlayerActive(id)
	-- because playerID starts at 0 instead of 1, they must be tostring'd or the tables behave strangely.
	return self.active_players:GetValue(tostring(id)) ~= nil
end

function SaveSystem:OnLocalPlayerLeave(id)
	-- because playerID starts at 0 instead of 1, they must be tostring'd or the tables behave strangely.
	self.active_players:SetValue(tostring(id), nil)
	self.active_players:Save()
end

function SaveSystem:LoadCharacterAsPlayerID(slot, id)
	-- because playerID starts at 0 instead of 1, they must be tostring'd or the tables behave strangely.
	self.active_players:SetValue(tostring(id), slot)
	self.active_players:Save()

	local local_players = TheNet:GetLocalPlayerList()
	-- If there is only one local player (or the local player list doesn't
	-- exist yet), that player must be the "main" local player.
	if not local_players or #local_players == 1 then
		TheSaveSystem.about_players:SetValue("last_selected_slot", slot)
	end

	return self.character_slots[slot]
end

function SaveSystem:SaveCharacterForPlayerID(playerID, cb)
	-- called when character screen is exited
	local player = GetPlayerEntityFromPlayerID(playerID)
	-- because playerID starts at 0 instead of 1, they must be tostring'd or the tables behave strangely.
	local slot = self:GetCharacterForPlayerID(playerID)

	-- if not slot then --[[error here]] end
	self:GetSaveForCharacterSlot(slot):Save(player, cb)
end

function SaveSystem:GetCharacterForPlayerID(playerID)
	-- because playerID starts at 0 instead of 1, they must be tostring'd or the tables behave strangely.
	local slot = self.active_players:GetValue(tostring(playerID))
	return slot
end

function SaveSystem:GetSaveForCharacterSlot(slot)
	return self.character_slots[slot]
end

function SaveSystem:GetSaveForPlayerEntity(player)
	local playerID = player.Network:GetPlayerID()
	local slot = self:GetCharacterForPlayerID(playerID)
	return self:GetSaveForCharacterSlot(slot)
end

function SaveSystem:SaveAll(cb)
	local _cb = MultiCallback()

	self:SaveAllExcludingRoom(_cb:AddInstance())
	self:SaveCurrentRoom(_cb:AddInstance())

	_cb:WhenAllComplete(cb)
end

function SaveSystem:SaveAllExcludingRoom(cb)
	local _cb = MultiCallback()

	self.active_players:Save(_cb:AddInstance())
	self.about_players:Save(_cb:AddInstance())

	local local_players = TheNet:GetLocalPlayerList()
	if local_players then
		for _, playerID in pairs(local_players) do
			local player = GetPlayerEntityFromPlayerID(playerID)

			if player then
				-- because playerID starts at 0 instead of 1, they must be tostring'd or the tables behave strangely.
				local slot = self:GetCharacterForPlayerID(playerID)

				if slot then
					-- if not slot then --[[error here]] end
					self:GetSaveForCharacterSlot(slot):Save(player, _cb:AddInstance())
				end
			end
		end
	end

	self.cheats:Save(_cb:AddInstance())
	self.permanent:Save(_cb:AddInstance())
	self.friends:Save(_cb:AddInstance())
	self.progress:Save(_cb:AddInstance())
	self.town:Save(_cb:AddInstance())
	self.dungeon:Save(_cb:AddInstance())

	_cb:WhenAllComplete(cb)
end

function SaveSystem:SaveCurrentRoom(cb)
	local worldmap = TheDungeon and TheDungeon:GetDungeonMap()
	if worldmap then
		local room_id = worldmap:GetCurrentRoomId()
		if TheDungeon:IsInTown() then
			self.town:SaveCurrentRoom(room_id, cb)
		else
			self.dungeon:SaveCurrentRoom(room_id, cb)
		end
	elseif cb ~= nil then
		cb(false)
	end
end

function SaveSystem:LoadAll(cb)
	local _cb = MultiCallback()

	if RUN_GLOBAL_INIT then
		-- active players is only supposed to persist for a single play session, and should be erased on startup
		self.active_players:Erase(_cb:AddInstance())

		-- Erase cheats on first startup to prevent mysterious behaviour
		-- between runs. You can change them in your localexec.
		self.cheats:Erase(_cb:AddInstance())
	else
		-- We frequently delete cheats, so we don't care if they fail to load.
		self.cheats:Load_ResetOnFailure(_cb:AddInstance())
	end

	self.active_players:Load(_cb:AddInstance())
	self.about_players:Load(_cb:AddInstance())

	for i, save in pairs(self.character_slots) do
		save:Load(_cb:AddInstance())
	end

	self.permanent:Load(_cb:AddInstance())
	self.friends:Load(_cb:AddInstance())
	self.progress:Load(_cb:AddInstance())
	self.town:Load(_cb:AddInstance())
	self.dungeon:Load(_cb:AddInstance())

	_cb:WhenAllComplete(cb)
end

function SaveSystem:EraseAll(cb)
	local _cb = MultiCallback()

	self.active_players:Erase(_cb:AddInstance())
	self.about_players:Erase(_cb:AddInstance())

	for _, save in pairs(self.character_slots) do
		save:Erase(_cb:AddInstance())
	end

	self.cheats:Erase(_cb:AddInstance())
	-- NO! Never erase permanent. self.permanent:Erase()
	self.friends:Erase(_cb:AddInstance())
	self.progress:Erase(_cb:AddInstance())
	self.town:Erase(_cb:AddInstance())
	self.dungeon:Erase(_cb:AddInstance())

	_cb:WhenAllComplete(cb)
end

return SaveSystem
