local lume = require "util.lume"

local PlayerSpawner = Class(function(self, inst)
	self.inst = inst
	self.portals = {}
	self.playerspawners = {}

	self.spawn_tasks = {
		delay = {},
		input = {},
	}

	self._oninputs_disabled = function(player) self:OnPlayerInputsDisabled(player) end
	self._oninputs_enabled = function(player) self:OnPlayerInputsEnabled(player) end

	inst:ListenForEvent("register_townportal", function(_, portal) self:RegisterPortal(portal) end)
	inst:ListenForEvent("unregister_townportal", function(_, portal) self:RegisterPortal(portal) end)

	inst:ListenForEvent("register_roomportal", function(_, portal) self:RegisterPortal(portal) end)
	inst:ListenForEvent("unregister_roomportal", function(_, portal) self:UnregisterPortal(portal) end)

	inst:ListenForEvent("register_playerspawner", function(_, spawner) self:RegisterPlayerSpawner(spawner) end)
	inst:ListenForEvent("unregister_playerspawner", function(_, spawner) self:UnregisterPlayerSpawner(spawner) end)
end)

function PlayerSpawner:RegisterPortal(portal)
	if self.portals[portal] == nil then
		self.portals[portal] = function(portal) self:UnregisterPortal(portal) end
		self.inst:ListenForEvent("onremove", self.portals[portal], portal)
	end
end

function PlayerSpawner:UnregisterPortal(portal)
	if self.portals[portal] ~= nil then
		self.inst:RemoveEventCallback("onremove", self.portals[portal], portal)
		self.portals[portal] = nil
	end
end

function PlayerSpawner:RegisterPlayerSpawner(spawner)
	if not spawner then return end

	table.insert(self.playerspawners, spawner)
	self.inst:ListenForEvent("onremove", function()
		self:UnregisterPlayerSpawner(spawner)
	end)
end

function PlayerSpawner:UnregisterPlayerSpawner(spawner)
	if not spawner then return end
	local index = lume.find(self.playerspawners, spawner)
	if index then
		self.inst:RemoveEventCallback("onremove", function()
			self:UnregisterPlayerSpawner(spawner)
		end)
		table.remove(self.playerspawners, index)
	end
end

function PlayerSpawner:GetEntrancePortal(player)
	if TheWorld:HasTag("town") then
		local id = TheDungeon.progression.components.runmanager:GetTownSpawnerID()

		if player.components.charactercreator:IsNew() then
			id = "new_player"
		end

		if id ~= nil then
			for portal in pairs(self.portals) do
				if portal.components.townportal and portal.components.townportal:GetID() == id then
					return portal
				end
			end
		end
	else
		local cardinal = TheDungeon:GetDungeonMap():GetCardinalDirectionForEntrance()
		if cardinal ~= nil then
			for portal in pairs(self.portals) do
				if portal.components.roomportal and portal.components.roomportal:GetCardinal() == cardinal then
					return portal
				end
			end
		end
	end

end

function PlayerSpawner:_QueueGameplayEvent(player)
	self.spawn_tasks.delay[player] = self.inst:DoTaskInTime(0.2, function(inst_)
		if player:IsValid() then
			player:PushEvent("start_gameplay")
			self.inst:RemoveEventCallback("inputs_disabled", self._oninputs_disabled, player)
		end
		self.spawn_tasks.delay[player] = nil
	end)
end

-- Use offsets to position player as far into the entrance as possible so other
-- players can be positioned more into the room.
local cardinal_data = {
	north = {
		rot = 90,
		offset = Vector3.unit_z,
	},
	east = {
		rot = 180,
		offset = Vector3.unit_x,
	},
	south = {
		rot = -90,
		offset = Vector3.unit_z,
	},
	west = {
		rot = 0,
		offset = -Vector3.unit_x,
	},
}

local function StaggerPlayerPosition(player, pos, cardinal)
	local signfn = function(x)
		return (x % 2 == 0) and 1 or -1
	end
	local SCALE = 1.5
	local playerid = player.Network:GetPlayerID() + 1
	local offset = signfn(playerid) * SCALE * math.ceil(playerid / 2)
	if cardinal == "west" or cardinal == "east" then
		pos.z = pos.z + offset
	else -- if cardinal == "south" or cardinal == "north" then
		pos.x = pos.x + offset
	end
end

-- After spawn, a sequence of events are sent.
--
-- To the world (see player_side):
-- * playerentered
--		* after adding a player entity. (One frame after construction.)
-- * playeractivated
--		* after player has owner and all other necessary bits. (After SetOwner.)
--
-- And then to the player:
-- * enter_room or enter_town
--		* use to setup anything visual
-- * playeractivated
--		* use to setup anything visual that's not dependent on dungeon/town.
-- * start_gameplay
--		* use to trigger timers
function PlayerSpawner:SpawnAtEntrance(player)
	assert(player:CanSpawnIntoWorld())
	local dungeon_map = TheDungeon:GetDungeonMap()
	if dungeon_map ~= nil then
		if TheWorld:HasTag("town") then
			self:_EnterTown(player)
		else
			self:_EnterDungeonRoom(player, dungeon_map)
		end
		-- We don't know if we can fire start_gameplay yet because a
		-- cinematic (or tutorial popup or something else blocking input)
		-- might start.
		self:_QueueGameplayEvent(player)
		self.inst:ListenForEvent("inputs_disabled", self._oninputs_disabled, player)
	end
end

function PlayerSpawner:_EnterTown(player)
	if TheSaveSystem.cheats:GetValue("town_spawn_pos") then
		local pos = TheSaveSystem.cheats:GetValue("town_spawn_pos")
		player.Physics:Teleport(pos[1], 0, pos[2])
	else
		local portal = self:GetEntrancePortal(player)
		if portal then
			local pos = portal:GetPosition()
			if TheNet:GetNrPlayersOnRoomChange() > 1 then
				StaggerPlayerPosition(player, pos, nil)
			end

			player.Physics:Teleport(pos:unpack())
		else
			TheLog.ch.WorldMap:print("Didn't find entrance for player spawn. Using room centre:", portal)
		end
	end
	player:PushEvent("enter_town")
end

function PlayerSpawner:_EnterDungeonRoom(player, dungeon_map)
	local enter_room_data = nil
	local pos = nil
	local rot = nil
	local cardinal = nil

	local player_spawner = self.playerspawners and self.playerspawners[1] or nil
	if player_spawner then
		-- Spawn via spawnpoint placed on the map
		local spawn_pos = player_spawner:GetPosition() or Vector3.zero

		pos = Vector3(spawn_pos.x or 0, spawn_pos.y or 0, spawn_pos.z or 0)
		enter_room_data = { no_force_locomote = true }
	else
		-- Spawn via the entrance portal on the map
		local portal = self:GetEntrancePortal()
		cardinal = dungeon_map:GetCardinalDirectionForEntrance()
		if cardinal ~= nil and portal ~= nil then
			local data = cardinal_data[cardinal]
			assert(data, cardinal)

			pos = portal:GetPosition() + data.offset
			rot = data.rot
		else
			-- Spawn at room center
			TheLog.ch.WorldMap:print("Didn't find entrance for player spawn. Using room centre:", cardinal, portal)

			pos = Vector3.zero:clone()
		end
	end
	assert(pos) -- the only required result from above

	-- Now, apply the above results.

	if TheNet:GetNrPlayersOnRoomChange() > 1 then
		StaggerPlayerPosition(player, pos, cardinal)
	end

	player.Physics:Teleport(pos:unpack())
	if rot then
		player.Transform:SetRotation(rot)
	end

	player:PushEvent("enter_room", enter_room_data)
end

function PlayerSpawner:OnPlayerInputsDisabled(player)
	local task = self.spawn_tasks.delay[player]
	self.spawn_tasks.delay[player] = nil
	if not task then
		-- Must be later on in the fight long after init.
		return
	end
	task:Cancel()
	self.spawn_tasks.input[player] = true
	self.inst:ListenForEvent("inputs_enabled", self._oninputs_enabled, player)
end

function PlayerSpawner:OnPlayerInputsEnabled(player)
	local task = self.spawn_tasks.input[player]
	self.spawn_tasks.input[player] = nil
	if not task then
		return
	end
	self:_QueueGameplayEvent(player)
end

return PlayerSpawner
