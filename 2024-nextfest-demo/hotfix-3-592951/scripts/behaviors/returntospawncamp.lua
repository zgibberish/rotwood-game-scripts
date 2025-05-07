local Leash = require "behaviors.leash"
local FaceEntity = require "behaviors.faceentity"
local StandStill = require "behaviors.standstill"

local function GetSpawnXZ(inst)
	return inst.components.knownlocations:GetLocationXZ("spawnpt")
end

local function GetNearbyCreature(inst)
	local x, z = inst.Transform:GetWorldXZ()
	local ents = TheSim:FindEntitiesXZ(x, z, 8, nil, nil, { "mob", "boss" })
	for i = 1, #ents do
		local ent = ents[i]
		if ent ~= inst and not ent:IsDead() and ent:IsVisible() then
			return ent
		end
	end
end

-- Only use when creatures have a dedicated spawn point.
--
-- The small distance thresholds to our leash mean we need a unique spawn
-- position. Two creatures with the same spawnpt will endlessly try to walk
-- into each other to reach their point.
local ReturnToSpawnCamp = Class(SequenceNode, function(self, inst)
	SequenceNode._ctor(self, {
		Leash(inst, GetSpawnXZ, .25, .25, false),
		NotDecorator(
			FaceEntity(inst, GetNearbyCreature)),
		StandStill(inst),
	})

	self.name = "ReturnToSpawnCamp"
	self.inst = inst
end)

return ReturnToSpawnCamp
