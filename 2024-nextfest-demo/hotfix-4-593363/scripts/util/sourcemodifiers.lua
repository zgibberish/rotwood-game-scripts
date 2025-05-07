-- A base value modified by 0 or more modifiers, which are combined via a specific operation (as defined by some derived
-- class). Modifiers can be added, removed, and mutated dynamically, which will result in the effective value being
-- updated appopriately.
SourceModifiers = Class(function(self, inst, baseval)
	self.inst = inst
	self.modifiers = {}
	self.baseval = baseval
	self.val = baseval

	self._onremovesource = function(source) self:RemoveModifier(source) end
end)

function SourceModifiers:Get()
	return self.val
end

function SourceModifiers:GetModifiers()
	return self.modifiers
end
function SourceModifiers:GetModifierCount()
	local count = 0
	for k,v in pairs(self.modifiers) do
		count = count + 1
	end
	return count
end

function SourceModifiers:NetSet(val)
	self.val = val
end

function SourceModifiers:SetModifier(source, val)
	if val == nil then
		self:RemoveModifier(source)
	elseif self.modifiers[source] ~= val then
		if self.modifiers[source] == nil and EntityScript.is_instance(source) then
			self.inst:ListenForEvent("onremove", self._onremovesource, source)
		end
		self.modifiers[source] = val
		self:Recalculate()
	end
end

function SourceModifiers:RemoveModifier(source)
	if not self.modifiers[source] then
		return
	end
	if EntityScript.is_instance(source) then
		self.inst:RemoveEventCallback("onremove", self._onremovesource, source)
	end
	self.modifiers[source] = nil
	self:Recalculate()
end

function SourceModifiers:GetModifier(source)
	return self.modifiers[source]
end

function SourceModifiers:Recalculate()
	-- Modifiers are not synced, only self.val is synced. So for remote entities, don't alter any of the modifiers
	if self.inst:IsLocalOrMinimal() then 
		self.val = self.baseval
		for _, v in pairs(self.modifiers) do
			self.val = self:Op(self.val, v)
		end
	end
end

--------------------------------------------------------------------------
-- SourceModifiers combined via addition.
-- TODO @chrisp #meta - this is a terrible class name because it reads like a function
AddSourceModifiers = Class(SourceModifiers, function(self, inst, baseval)
	SourceModifiers._ctor(self, inst, baseval or 0)
end)

function AddSourceModifiers:Op(a, b)
	return a + b
end

--------------------------------------------------------------------------
-- SourceModifiers combined via multiplication.
-- TODO @chrisp #meta - this is a terrible class name because it reads like a function
MultSourceModifiers = Class(SourceModifiers, function(self, inst, baseval)
	SourceModifiers._ctor(self, inst, baseval or 1)
end)

function MultSourceModifiers:Op(a, b)
	return a * b
end
