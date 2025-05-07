-- Component that will destroy other entities occupying the same space as it.

local Vec2 = require "math.modules.vec2"
local Lume = require "util.lume"

-- Destroys all entities within range that contain any intolerant tag, on spawn.
-- Entities that contain any tolerant tags are retained, however.
local SoleOccupant = Class(function(self, entity, radius, intolerant_tags, tolerant_tags)
	self.entity = entity
	self.radius_sq = radius * radius
	self.intolerant_tags = intolerant_tags
	self.tolerant_tags = tolerant_tags
	entity:StartUpdatingComponent(self)
end)

local function GetWorldPosition(entity)
	local x, z = entity.Transform:GetWorldXZ()
	return Vec2(x, z)
end

function SoleOccupant:OnUpdate()
	local position = GetWorldPosition(self.entity)
	for _, entity in pairs(Ents) do
		if entity ~= self.entity 
			and entity.Transform 
			and Vec2.dist2(position, GetWorldPosition(entity)) < self.radius_sq
			and Lume(self.intolerant_tags):any(function(tag) return entity:HasTag(tag) end):result()
			and not Lume(self.tolerant_tags):any(function(tag) return entity:HasTag(tag) end):result()
		then
			entity:Remove()
		end
	end
	self.entity:StopUpdatingComponent(self)
end

return SoleOccupant
