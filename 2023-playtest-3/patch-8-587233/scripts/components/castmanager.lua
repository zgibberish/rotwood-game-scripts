-- Holds reference to the cast and other things that can be used in quests by the player.
-- Is on TheDungeon.progression

local GameNode = require "questral.gamenode"
local RotwoodActor = require "questral.game.rotwoodactor"
local RotwoodInteractable = require "questral.game.rotwoodinteractable"
local RotwoodLocation = require "questral.game.rotwoodlocation"
local biomes = require "defs.biomes"
local kstring = require "util.kstring"
local lume = require "util.lume"


local CastManager = Class(GameNode, function(self, inst)
	self.inst = inst

	self.npcs = {}
	self.npcnodes = {}
	self.playernodes = {}
	self.enemynodes = {}
	self.interactablenodes = {}
	self.locations = {}
	self.locations.current = RotwoodLocation()

	self.questcentrals = {}

	self.interactables = {}

	self._onregisternpc = function(source, data) self:_RegisterNpc(data) end
	self._onunregisternpc = function(source, data) self:_UnregisterNpc(data) end
	self._onregisterenemy = function(source, data) self:_RegisterEnemy(data) end
	self._onregisterinteractable = function(source, data)
		if not self.interactables[data.prefab] then
			self.interactables[data.prefab] = data
			self:_RegisterInteractable(data)
		end
	end
end)

-- Called from progression.
function CastManager:OnRegisterRoomCreated(world)
	self.inst:ListenForEvent("registernpc", self._onregisternpc, world)
	self.inst:ListenForEvent("unregisternpc", self._onunregisternpc, world)
	self.inst:ListenForEvent("spawnenemy", self._onregisterenemy, world)
	self.inst:ListenForEvent("registerinteractable", self._onregisterinteractable, world)
end

function CastManager:OnSave()
	return {
		known_npcs = lume.keys(self.npcnodes),
		known_enemies = lume.keys(self.enemynodes),
		known_locations = lume.keys(self.locations),
	}
end

function CastManager:OnLoad(data)
	if not next(data) then return end

	for _,prefab in ipairs(data.known_npcs) do
		self:_GetCastForPrefab(prefab, self.npcnodes)
	end
	for _,prefab in ipairs(data.known_enemies) do
		self:_GetCastForPrefab(prefab, self.enemynodes)
	end
	for _,biome_location_id in ipairs(data.known_locations) do
		self:_GetLocation(biome_location_id)
	end

	self:_ActivateSelf()
end

function CastManager:_ActivateSelf()
	if not self.activated then
		self.activated = true
		self.locations.current:SetLocation(TheDungeon:GetDungeonMap().nav:GetBiomeLocation())
		self:AttachChild(self.locations.current)
		self:_ActivateNode()
	end
end

function CastManager:OnPostSpawn()
	self:_ActivateSelf()
end

function CastManager:__tostring()
    return string.format( "CastManager[%s %s]", self.inst, kstring.raw(self) )
end

function CastManager:AttachPlayer(player)
	if not player:IsLocal() then return end

	local qc = player.components.questcentral
	self.questcentrals[player] = qc
	self:AttachChild(qc)
end

function CastManager:DetachPlayer(player)
	if not player:IsLocal() then return end

	local qc = player.components.questcentral
	self.questcentrals[player] = nil
	assert(not qc:IsActivated(), "QuestCentral should be inactive when it detaches the player.")
	local is_child = qc:GetParent() == self
	if is_child then -- might not have attached yet.
		self:DetachChild(qc)
	end
	-- else: player was never fully created (probably player canceled selection).
end

function CastManager:GetActivePlayers()
	return self.questcentrals
end

function CastManager:_GetCastForPrefab(prefab, node_dict)
	local node = node_dict[prefab]
	if not node then
		node = RotwoodActor()
			:SetWaitingForSpawn(prefab)

		-- Always attach to location so they can be found by FillCast.
		self.locations.current:AttachChild(node)

		node_dict[prefab] = node
	end
	return node
end

function CastManager:_RegisterNpc(data)
	local node = self:_GetCastForPrefab(data.npc.prefab, self.npcnodes)
	node:FillReservation(data.npc)
	node:SetNpcRole(data.role)
	self.npcnodes[data.npc.prefab] = node
	self.npcs[data.npc] = data.npc
end

-- Unregister means remove this npc from the game. We don't do this just
-- because they were removed from the scene.
function CastManager:_UnregisterNpc(data)
	self.npcnodes[data.npc.prefab] = nil
	self.npcs[data.npc] = nil
end

function CastManager:_RegisterEnemy(enemy)
	local mon = self.enemynodes[enemy.prefab]
	if mon and mon.is_reservation then
		mon:FillReservation(enemy)
		-- TODO(dbriscoe): What do we do if enemy dies?
	end

	TheWorld:PushEvent("player_seen", enemy)
	-- else ignore unreserved monsters, there will be many.
end

function CastManager:_RegisterInteractable(ent)
	local interactable = self.interactablenodes[ent.prefab]
	if interactable and interactable.is_reservation then
		interactable:FillReservation(ent)
	end
end

function CastManager:_GetInteractable(prefab)
	local node = self.interactablenodes[prefab]

	if not node then
		node = RotwoodInteractable()
			:SetWaitingForSpawn(prefab)

		-- Always attach to location so they can be found by FillCast.
		self.locations.current:AttachChild(node)

		self.interactablenodes[prefab] = node

		if self.interactables[prefab] then
			-- this interactable exists in this level already, fill the reservation
			self:_RegisterInteractable(self.interactables[prefab])
		end
	end
	return node
end

function CastManager:GetCurrentLocation()
	return self:_GetLocation(TheDungeon:GetDungeonMap().data.location_id)
end

function CastManager:_GetLocation(biome_location_id)
	local node = self.locations[biome_location_id]
	if not node then
		local biome_location = biomes.locations[biome_location_id]
		node = RotwoodLocation(biome_location)
		self.locations[biome_location_id] = node
		self:AttachChild(node)
	end
	return node
end

function CastManager:GetNpcNode(ent)
	return self.npcnodes[ent.prefab]
end

function CastManager:GetNpcNodeFromPrefabName(prefab)
	return self.npcnodes[prefab]
end

function CastManager:GetPlayerNode(player)
	local actor = self.playernodes[player]
	if not actor then
		actor = RotwoodActor(player)
		self.locations.current:AttachChild(actor)
		self.playernodes[player] = actor
	end
	return actor
end

function CastManager:GetLocationActor(location_id)
	return self:_GetLocation(location_id)
end

function CastManager:AllocateEnemy(prefab_name)
	-- TODO(dbriscoe): Consider handling enemies more generically so we don't
	-- need a new actor for each one (or keep around actors from old quests).
	local enemy = self:_GetCastForPrefab(prefab_name, self.enemynodes)
	enemy:SetHostile(true)
	return enemy
end

function CastManager:AllocateInteractable(prefab_name)
	-- TODO(dbriscoe): Consider handling interactables more generically so we don't
	-- need a new actor for each one (or keep around actors from old quests).
	local interactable = self:_GetInteractable(prefab_name)
	return interactable
end

function CastManager:GetEnemyNodes()
	return self.enemynodes
end

function CastManager:GetNPCNodes()
	return self.npcnodes
end

---------------------

return CastManager
