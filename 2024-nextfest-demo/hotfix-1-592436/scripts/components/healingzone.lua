local SGCommon = require "stategraphs.sg_common"

local HealingZone = Class(function(self, inst)
    self.inst = inst
    self.enabled = false
    self.timer_id = "healing_zone_tick"
    self.heal_period = 5
    self.heal_amount = 100
    self.heal_radius = 6

    self.show_projectile = false

    self._ontimerdonefn = function(inst, data) self:OnTimerDone(data) end
    self.inst:ListenForEvent("timerdone", self._ontimerdonefn)

    self._onhitboxtriggeredfn = function(inst, data) self:OnHealHitBoxTriggered(data) end
    self.inst:ListenForEvent("hitboxtriggered", self._onhitboxtriggeredfn)
end)

-- Banded data for scaling the FX based on distance, broken up into two FX to retain visual integrity
local smalldata =
{
	-- distance, scale
	{0, 	0.5},
	{1.8, 	0.9},
	{3.2, 	1.15},
	{5.7, 	1.3},
	{9.2, 	1.6},
	{13.2, 	1.8},
	{15, 	1.9},
}
local largedata =
{
	-- distance, scale
	{15, 	1},
	{16, 	1.15},
	{19.5, 	1.27},
	{22, 	1.37},
	{25, 	1.5},
	{30, 	1.525},
	{35, 	1.575},
	{40, 	1.625},
	{45, 	1.65},
	{100, 	1.70}, --just a guess!
}

function HealingZone:OnHealHitBoxTriggered(data)
	for i = 1, #data.targets do
		local target = data.targets[i]
		if self.inst.components.combat:CanFriendlyTargetEntity(target) then
			if self.show_projectile then
				FakeBeamFX(self.inst, target, "fx_gourdo_seed_heal_beam", smalldata, largedata)
				self:DoHeal(target)
			else
				self:DoHeal(target)
			end
		end
	end
end

function HealingZone:OnTimerDone(data)
	if data.name == self.timer_id then
		self.inst:PushEvent("zone_heal", self.heal_radius)
		-- self:StopHealing()
		if self.enabled then
			self:StartHealing()
		end
	end
end

function HealingZone:DoHeal(target)
	SGCommon.Fns.DoPotionColorSequence(target, function(target)
		local heal = Attack(self.inst, target)
		local heal_adjusted = target == self.inst and 9999 or self.heal_amount
		heal:SetHeal(heal_adjusted)
		target.components.combat:ApplyHeal(heal)
	end)
end

function HealingZone:Enable()
	if not self.enabled then
		self.enabled = true
		self:StartHealing()
	end
end

function HealingZone:Disable()
	if self.enabled then
		self:StopHealing()
		self.enabled = false
	end
end

function HealingZone:StartHealing()
	self.inst.components.timer:StartTimer(self.timer_id, self.heal_period, true)
end

function HealingZone:StopHealing()
	self.inst.components.timer:StopTimer(self.timer_id)
end

return HealingZone