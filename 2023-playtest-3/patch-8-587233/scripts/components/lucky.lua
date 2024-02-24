require("util/sourcemodifiers")

-- TODO: networking2022, this is accessed for more than local-only use.
-- For example, the host uses this for konjur reward luck rolls.
-- Some aspects of this need to be synced (at the very least, source modifiers),
-- or the calls need to be reauthored to be client-authoritative.
local Lucky = Class(function(self, inst)
	self.inst = inst

	-- Note that this method of initialization of base_luck implicitly makes this component only applicable for player entities.
	self.base_luck = TUNING.PLAYER_LUCK

	self.luckmod = AddSourceModifiers(inst)

end)

function Lucky:_GetRNG()
	if not self.rng then
		self.rng = CreatePlayerRNG(self.inst, 0x70C41F0F, "Lucky")
	end
	return self.rng
end

function Lucky:AddLuckMod(source, mod)
	self.luckmod:SetModifier(source, mod)
end

function Lucky:RemoveLuckMod(source, mod)
	self.luckmod:RemoveModifier(source)
end

function Lucky:GetTotalLuck()
	return self.base_luck + self.luckmod:Get()
end

function Lucky:DoLuckRoll()
	local is_lucky = self:_GetRNG():Boolean(self:GetTotalLuck())
	if is_lucky then
		self.inst:PushEvent("lucky")
	end
	return is_lucky
end

return Lucky
