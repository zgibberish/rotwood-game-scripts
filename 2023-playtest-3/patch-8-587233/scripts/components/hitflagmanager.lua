local HitFlagManager = Class(function(self, inst)
	self.inst = inst
	self.hit_flags = Attack.HitFlags.ALL

	inst:ListenForEvent("add_state_tag", function(_, tag) self:OnAddStateTag(tag) end)
	inst:ListenForEvent("remove_state_tag", function(_, tag) self:OnRemoveStateTag(tag) end)
end)

local HITFLAGMANAGER_STATES = MakeEnum{
	"PRONE", -- +ground, -air, -air_high, -projectile
	"AIR", -- -ground, +air, +air_high, +projectile
	"AIR_HIGH", -- -ground, -air, +air_high, -projectile
	"PROJECTILE_IMMUNE", -- +ground, +air_high, +air, -projectile
}

local TAG_TO_STATE =
{
	["prone"] = HITFLAGMANAGER_STATES.PRONE,

	["airborne"] = HITFLAGMANAGER_STATES.AIR,
	["flying"] = HITFLAGMANAGER_STATES.AIR,

	["airborne_high"] = HITFLAGMANAGER_STATES.AIR_HIGH,
	["flying_high"] = HITFLAGMANAGER_STATES.AIR_HIGH,

	["projectile_immune"] = HITFLAGMANAGER_STATES.PROJECTILE_IMMUNE,
}

local STATE_TO_FUNCTION =
{
	[HITFLAGMANAGER_STATES.PRONE] = function(self, remove)
		if remove then
			self:AddHitFlag(Attack.HitFlags.AIR)
			self:AddHitFlag(Attack.HitFlags.AIR_HIGH)
			self:AddHitFlag(Attack.HitFlags.PROJECTILE)
		else
			self:RemoveHitFlag(Attack.HitFlags.AIR)
			self:RemoveHitFlag(Attack.HitFlags.AIR_HIGH)
			self:RemoveHitFlag(Attack.HitFlags.PROJECTILE)
		end
	end,

	[HITFLAGMANAGER_STATES.AIR] = function(self, remove)
		if remove then
			self:AddHitFlag(Attack.HitFlags.GROUND)
		else
			self:RemoveHitFlag(Attack.HitFlags.GROUND)
		end
	end,

	[HITFLAGMANAGER_STATES.AIR_HIGH] = function(self, remove)
		if remove then
			self:AddHitFlag(Attack.HitFlags.GROUND)
			self:AddHitFlag(Attack.HitFlags.AIR)
			self:AddHitFlag(Attack.HitFlags.PROJECTILE)
		else
			self:RemoveHitFlag(Attack.HitFlags.GROUND)
			self:RemoveHitFlag(Attack.HitFlags.AIR)
			self:RemoveHitFlag(Attack.HitFlags.PROJECTILE)
		end
	end,

	[HITFLAGMANAGER_STATES.PROJECTILE_IMMUNE] = function(self, remove)
		if remove then
			self:AddHitFlag(Attack.HitFlags.PROJECTILE)
		else
			self:RemoveHitFlag(Attack.HitFlags.PROJECTILE)
		end
	end,
}

function HitFlagManager:OnAddStateTag(tag)
	local state = TAG_TO_STATE[tag]
	if state then
		STATE_TO_FUNCTION[state](self)
	end
end

function HitFlagManager:OnRemoveStateTag(tag)
	local state = TAG_TO_STATE[tag]
	if state then
		STATE_TO_FUNCTION[state](self, true)
	end
end

function HitFlagManager:AddHitFlag(flag)
	self.hit_flags = self.hit_flags | flag
end

function HitFlagManager:RemoveHitFlag(flag)
	self.hit_flags = self.hit_flags & ~flag
end

function HitFlagManager:GetHitFlags()
	return self.hit_flags
end

function HitFlagManager:CanAttackHit(attack)
	return attack:GetHitFlags() & self:GetHitFlags() ~= 0
end

function HitFlagManager:OnNetSerialize()
	local e = self.inst.entity

	e:SerializeUInt(self.hit_flags, 8);
end

function HitFlagManager:OnNetDeserialize()
	local e = self.inst.entity

	local hf = e:DeserializeUInt(8);
	if hf then
		self.hit_flags =  hf
	end
end


return HitFlagManager
