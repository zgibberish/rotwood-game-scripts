local SGCommon = require "stategraphs.sg_common"
local Weight = require "components.weight"

local PushForce = Class(function(self, inst)
	self.inst = inst
	self.push_force = AddSourceModifiers(inst, Vector3(0, 0, 0))
	self.push_force_modifier = MultSourceModifiers(inst)
end)

function PushForce:GetTotalPushForce()
	return self.push_force:Get()
end

function PushForce:GetTotalPushForceModifier()
	return self.push_force_modifier:Get()
end

-- Lower = more resistance against push forces.
local relativeweight_to_pushforce_multiplier =
{
	[Weight.Status.s.Light] = 2.0,
	[Weight.Status.s.Normal] = 1.0,
	[Weight.Status.s.Heavy] = 0.5,
}

-- Higher = less resistance against push forces.
local relativeweight_to_dodge_multiplier =
{
	[Weight.Status.s.Light] = 2.0, -- 1.3,
	[Weight.Status.s.Normal] = 1.0, --0.8,
	[Weight.Status.s.Heavy] = 0.5, --0.6,
}

function PushForce:GetTotalPushForceWithModifiers()
	-- Calculate the total push force, with weight & modifiers applied.

	-- Reduce force if rolling; replace weight modifier with dodge modifier.
	local dodge_mod = self.inst.components.weight and relativeweight_to_dodge_multiplier[self.inst.components.weight:GetStatus()] or 1
	local weight_mod = self.inst.sg:HasStateTag("dodge") and dodge_mod or (self.inst.components.weight and relativeweight_to_pushforce_multiplier[self.inst.components.weight:GetStatus()]) or 1

	local total_speed = self.push_force:Get() * self.push_force_modifier:Get() * weight_mod
	return total_speed
end

function PushForce:AddPushForce(name, source, force, is_override)
	if not source or not source:IsValid() then
		return
	end
	local id = is_override and name or name .. "_" .. source.Network:GetEntityID()
	self.push_force:SetModifier(id, force)
	self:UpdatePushForce()
end

function PushForce:RemovePushForce(name, source, is_override)
	local id = (not (source and source.Network) or is_override) and name or name .. "_" .. source.Network:GetEntityID()
	--[[local start_force = self.push_force:GetModifier(id)
	if not start_force then return end

	-- Push force is removed; lerp this force over time to zero.
	local fn = function(inst, progress)
		local force = Vector3.lerp(start_force, Vector3.zero, progress)
		if progress < 1 then
			self:AddPushForce(name, source, force, is_override)
		else
			self.push_force:RemoveModifier(id)
		end
	end
	self.inst:DoDurationTaskForTicks(4, fn)]]

	self.push_force:RemoveModifier(id)

	-- If still moving, need to set motor velocity after removing modifiers.
	self:UpdatePushForce()
end

function PushForce:AddPushForceModifier(source, modifier)
	self.push_force_modifier:SetModifier(source, modifier)
	self.inst:PushEvent("pushforce_modifier_changed")
end

function PushForce:RemovePushForceModifier(source)
	self.push_force_modifier:RemoveModifier(source)
	self.inst:PushEvent("pushforce_modifier_changed")
end

function PushForce:ClampMaxPushForce(push_force)
	local total_force_length = math.min(push_force:Length(), 119.99) -- Cap at 120, our game's speed limit (119.99 to account for rounding error causing velocity to be > 120)
	local total_force_direction = push_force:normalized()
	local final_force = total_force_direction * total_force_length
	return final_force
end

function PushForce:UpdatePushForce()
	-- If standing still, apply force
	local motor_vel = Vector3(self.inst.Physics:GetMotorVel())
	if Vector3.LengthSq(motor_vel) == 0 then
		local push_force = self:GetTotalPushForceWithModifiers()
		local final_force = self:ClampMaxPushForce(push_force)
		self.inst.Physics:SetVel(final_force:unpack())
	else
		-- TODO: find a better way to determine if the entity was moving with run or walk speed.
		local base_speed = (self.inst.sg and self.inst.sg.statemem.speed) or (self.inst.sg and self.inst.sg.statemem.velocity) or self.inst.components.locomotor:GetBaseRunSpeed() or self.inst.components.locomotor:GetBaseWalkSpeed()
		SGCommon.Fns.SetMotorVelScaled(self.inst, base_speed) -- Push force calculations are done in SetMotorVelScaled
	end
end

return PushForce
