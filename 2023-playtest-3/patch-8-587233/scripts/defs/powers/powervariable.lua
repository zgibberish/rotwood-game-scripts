local Enum = require "util.enum"

PowerVariable = Class(function(self, value)
	self.value = value
	self.variable_type = PowerVariable.Types.s.FLAT
end)

PowerVariable.Types = Enum{
	"PERCENTAGE",
	"FLAT",
}

function PowerVariable:GetValue(pow)
	if self:GetType() == PowerVariable.Types.s.PERCENTAGE then
		return self.value * 0.01
	else
		return self.value
	end
end

function PowerVariable:GetPretty(pow)
	local val = self:GetValue(pow)

	if self:GetType() == PowerVariable.Types.s.PERCENTAGE then
		val = string.format("%+.0f%%", val * 100)
	else
		-- Whether int or float, we display without decimals.
		val = string.format("%+.0f", val)
	end

	return val
end

function PowerVariable:GetType()
	return self.variable_type
end

function PowerVariable:SetPercentage()
	self.variable_type = PowerVariable.Types.s.PERCENTAGE
	return self
end

function PowerVariable:SetFlat()
	self.variable_type = PowerVariable.Types.s.FLAT
	return self
end

StackingVariable = Class(PowerVariable, function(self, per_stack, value)
	value = value or 0
	PowerVariable._ctor(self, value)
	self.per_stack = per_stack
end)

function StackingVariable:GetValue(pow)
	local val = self.value

	if pow and pow.stacks then
		val = val + (self.per_stack * pow.stacks)
	end

	if self:GetType() == PowerVariable.Types.s.PERCENTAGE then
		val = val * 0.01
	end

	return val
end

function StackingVariable:GetPrettyForStacks(stacks)
	local val = stacks

	val = self.per_stack * stacks

	if self:GetType() == PowerVariable.Types.s.PERCENTAGE then
		val = string.format("%+.0f%%", val)
	else
		-- Whether int or float, we display without decimals.
		val = string.format("%+.0f", val)
	end

	return val
end