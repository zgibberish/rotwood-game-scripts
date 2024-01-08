require("util/sourcemodifiers")

local Shield = Class(function(self, inst)
	self.inst = inst
	self.current = 0
	self.max = 0

	self._onhealthchanged = function(_, data)
		self:UpdateShield(data)
	end

	self._onexitroom = function(target, data)
		self:ClearShield()
	end

	self.inst:ListenForEvent("healthchanged", self._onhealthchanged)
	self.inst:ListenForEvent("exit_room", self._onexitroom, TheDungeon)
end)

function Shield:UpdateShield(data)
	if self:GetCurrent() > self:GetMax() then
		self:SetInternal(self:GetMax())
	end
end

function Shield:GetPercentOfHealth()
	-- what percent of your total health is shield
	return self:GetCurrent() / self.inst.components.health:GetMax()
end

function Shield:GetCurrent()
	return self.current
end

function Shield:SetCurrent(val, silent)
	self:SetInternal(val, silent)
end

function Shield:SetMax(val)
	self.max = val
end

function Shield:GetMax()
	return self.max
end

function Shield:AbsorbDamage(damage, attack)
	if self:GetCurrent() >= damage then
		self:DoDelta(-damage, false, attack)
		return 0
	else
		self:DoDelta(-self:GetCurrent(), false, attack)
		return damage - self:GetCurrent()
	end
end

function Shield:DoDelta(delta, silent, attack)
	self:SetInternal(self:GetCurrent() + delta, silent, attack)
end

function Shield:SetInternal(val, silent, attack)
	local old = self:GetCurrent()
	self.current = math.clamp(val, 0, self:GetMax())
	self.inst:PushEvent("shieldchanged", {
		old = old,
		new = self:GetCurrent(),
		max = self:GetMax(),
		max_health = self.inst.components.health:GetMax(),
		silent = silent,
		attack = attack,
	})
	if val <= 0 and old > 0 then
		self.inst:PushEvent("shieldremoved", { attack = attack })
	end
end

function Shield:ClearShield()
	if not self.inst:HasTag("keep_shield_between_rooms") then
		self:SetInternal(0, true, nil)
	end
end

function Shield:OnSave()
	if self.current > 0 then
		return { current = self.current }
	end
end

function Shield:OnLoad(data)
	if data.current then
		self:SetInternal(data.current, true)
	end
end

return Shield
