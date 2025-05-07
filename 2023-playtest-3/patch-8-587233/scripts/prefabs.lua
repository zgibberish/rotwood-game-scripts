-- A definition of a spawnable object.
--
-- name: the name used to spawn the prefab.
-- fn: a function that constructs the prefab and returns the entity.
-- assets: a list of Asset instances that this prefab uses.
-- deps: a list of prefabs that this prefab might spawn.
-- force_path_search: ??
--
-- deps lets us selectively load only what's necessary instead of all possible
-- assets. Also, we know at build time which assets are actually used, so we
-- can prune unused prefabs from game builds or other processing.

NetworkTypeFlags_Enabled = 1		-- Networking enabled/disabled
NetworkTypeFlags_SpawnHostOnly = 2	-- Spawning on Host only or any client
NetworkTypeFlags_Transferable = 4	-- Ownership transferable or not.

-- NOTE: This flag does not exist in c++. It is an extra flag that is easier to pass into a prefab constructor like this. 
-- It basically means NetworkTypeFlags_SpawnHostOnly + calling SetMinimalNetworking on the network component after it is spawned.
NetworkTypeFlags_Minimal = 8		-- A Minimal entity means nothing is synced except the transform component. It DOES however, react to networked events.

NetworkType_None = 0																		-- Not synced over the network (local only)
NetworkType_HostAuth = NetworkTypeFlags_Enabled + NetworkTypeFlags_SpawnHostOnly			-- Entities spawned by the host, and auth stays on the host
NetworkType_ClientAuth = NetworkTypeFlags_Enabled											-- Entities spawned by any client, and auth stays on that client
NetworkType_SharedHostSpawn = NetworkTypeFlags_Enabled + NetworkTypeFlags_SpawnHostOnly + NetworkTypeFlags_Transferable	-- Transferable auth, but spawned on the host
NetworkType_SharedAnySpawn = NetworkTypeFlags_Enabled + NetworkTypeFlags_Transferable		-- Transferable auth, but spawned on any client
NetworkType_Minimal = NetworkTypeFlags_Enabled + NetworkTypeFlags_SpawnHostOnly	+ NetworkTypeFlags_Minimal	-- Entities spawned by the host, and auth stays on the host. Minimal syncing of data
NetworkType_ClientMinimal = NetworkTypeFlags_Enabled + NetworkTypeFlags_Minimal				-- Entities spawned by any client that are also minimal, auth stays on the client

Prefab = Class(function(self, name, fn, assets, deps, force_path_search, network_type)
	self.name = name
	self.fn = fn
	self.assets = assets or table.empty
	self.deps = deps or table.empty
	self.force_path_search = force_path_search or false
	self.network_type = network_type or NetworkType_None
end)

function Prefab:__tostring()
	return "Prefab "..self.name
end

function Prefab:CanBeSpawned()
	-- If it is the host, all can be spawned.
	-- If it is a client, only certain types can be spawned.
	return TheNet:IsHost() or
		self.network_type == NetworkType_None or
		self.network_type == NetworkType_ClientAuth or
		self.network_type == NetworkType_SharedAnySpawn or
		self.network_type == NetworkType_ClientMinimal
end

-- A definition of resources used in prefabs (textures, anims, etc).
Asset = Class(function(self, type, file, param1, param2, param3)
	self.type = type
	self.file = file
	self.param1 = param1
	self.param2 = param2
	self.param3 = param3
end)

-- Wrapper to make accessing groups consistent and clear.
GroupPrefab = function(name)
	return "GRP_".. name
end

