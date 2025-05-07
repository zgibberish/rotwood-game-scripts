local SGCommon = require "stategraphs.sg_common"

-- Maintains offset hitbox state
-- Used for mobs with additional hurtboxes (i.e. floracrane head, tail)
local OffsetHitboxes = Class(function(self, inst)
	self.inst = inst
	self.hitboxes = {}
	self.hitboxes_ordered = {}
end)

function OffsetHitboxes:OnNetSerialize()
	local e = self.inst.entity
	local num_hitboxes = #self.hitboxes_ordered
	e:SerializeUInt(num_hitboxes, 2)
	if num_hitboxes > 0 then
		for _i, name in ipairs(self.hitboxes_ordered) do
			local is_enabled = self.hitboxes[name].HitBox:IsEnabled()
			e:SerializeBoolean(is_enabled)
			if is_enabled then
				e:SerializeDoubleAs16Bit(self.hitboxes[name].dist or 0)
			end
		end
	end
end

function OffsetHitboxes:OnNetDeserialize()
	local e = self.inst.entity
	local hitbox_count = e:DeserializeUInt(2)
	for i = 1,hitbox_count do
		local enabled = e:DeserializeBoolean()
		local dist = nil
		if enabled then
			dist = e:DeserializeDoubleAs16Bit()
		end
		-- sometimes data comes in early? and offset hitboxes don't yet exist
		if self.hitboxes_ordered[i] then
			local hitbox = self.hitboxes[self.hitboxes_ordered[i]]
			hitbox.HitBox:SetEnabled(enabled)
			if dist then
				SGCommon.Fns.MoveChildToDist(hitbox, dist)
			end
		end
	end
end

function OffsetHitboxes:OnEntityBecameLocal()
	-- always reset hitboxes when taking control of an entity; let sg reenable them as needed
	for _name,hitbox in pairs(self.hitboxes) do
		hitbox.HitBox:SetEnabled(false)
	end
end

function OffsetHitboxes:OnEntityBecameRemote()
	for _name,hitbox in pairs(self.hitboxes) do
		hitbox.HitBox:SetEnabled(false)
	end
end

function OffsetHitboxes:_InitHitBox(hitbox, size)
	-- see if the need to support inheriting hitgroup / flags from the parent is needed
	hitbox.HitBox:SetHitGroup(HitGroup.MOB)
	hitbox.HitBox:SetHitFlags(HitGroup.CHARACTERS)
	hitbox.HitBox:SetNonPhysicsRect(size)
	hitbox.HitBox:SetEnabled(false)
end

function OffsetHitboxes:_CreateOffsetHitBox(name, size)
	local inst = CreateEntity(name)

	inst.entity:AddTransform()
	inst.entity:AddHitBox()

	inst:AddTag("CLASSIFIED")
	inst.persists = false

	self:_InitHitBox(inst, size)
	return inst
end

function OffsetHitboxes:GetAll()
	return self.hitboxes
end

function OffsetHitboxes:Get(name)
	return self.hitboxes[name]
end

function OffsetHitboxes:Has(name)
	return self.hitboxes[name] ~= nil
end

function OffsetHitboxes:Add(size, name_override)
	size = size or self.inst.Physics:GetSize()

	local name = name_override or "offsethitbox"

	if not self.hitboxes[name] then
		local child_hitbox = self:_CreateOffsetHitBox(name, size)
		child_hitbox.entity:SetParent(self.inst.entity)

		table.insert(self.hitboxes_ordered, name)
		self.hitboxes[name] = child_hitbox
	else
		-- reinitialize an existing hitbox
		self:_InitHitBox(self.hitboxes[name], size)
	end
end

-- Try disabling hitboxes instead of removing them to maintain serialization indexing
-- function OffsetHitboxes:Remove(name)
-- 	if self.hitboxes[name] then
-- 		self.hitboxes[name]:Remove()
-- 		self.hitboxes[name] = nil
-- 		local i = table.arrayfind(self.hitboxes_ordered, name)
-- 		if i then
-- 			table.remove(self.hitboxes_ordered, i)
-- 		end
-- 	end
-- end

function OffsetHitboxes:SetEnabled(name, is_enabled)
	if self.hitboxes[name] then
		self.hitboxes[name].HitBox:SetEnabled(is_enabled)
	end
end

function OffsetHitboxes:Move(name, dist)
	if self.hitboxes[name] then
		self.hitboxes[name].dist = dist
		SGCommon.Fns.MoveChildToDist(self.hitboxes[name], dist)
	end
end

return OffsetHitboxes
