-- Component used to serialize an attack angle. Used with entities that need to store its attack angle over the network, e.g. Windmon.
local AttackAngle = Class(function(self, inst)
	self.inst = inst
	self.attack_angle = 0
end)

local ANGLE_BITS <const> = 9 -- 1-degree precision (0-360)

function AttackAngle:OnNetSerialize()
	local e = self.inst.entity
	e:SerializeUInt(self.attack_angle, ANGLE_BITS);
end

function AttackAngle:OnNetDeserialize()
	local e = self.inst.entity
	self.attack_angle = e:DeserializeUInt(ANGLE_BITS);
end

function AttackAngle:GetAttackAngle()
	return self.attack_angle
end

-- Direction corresponding to the attack angle *away* from the attacker.
function AttackAngle:GetAttackDirection()
	return Vector3.unit_x:rotate_around_y(-math.rad(self.attack_angle))
end

function AttackAngle:SetAttackAngle(angle)
	-- Normalize angle to [0, 360]
	local normalized_angle = SimplifyAngle(angle)
	self.attack_angle = normalized_angle
end

return AttackAngle
