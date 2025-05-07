-- Listens for the "do_damage" event, and keeps a list of everything that it has taken damage to.
-- When "Finish Attack" is called, an event is pushed that contains all of that data.
local lume = require "util.lume"

local HitTracker = Class(function(self, inst)
	self.inst = inst
	self._on_do_damage = function(_, attack) self:OnDoDamage(attack) end
	self._on_state_changed = function() self:FinishAttack() end
	self.is_active = false
	self.is_auto_exit = false
end)

function HitTracker:OnDoDamage(attack)
	local target = attack:GetTarget()

	-- print("HitTracker:OnDoDamage")

	if attack:GetID() ~= self.attack_type then
		-- printf("Wrong ID (%s) for attack_type (%s)", attack:GetID(), self.attack_type)
		return
	end

	if target ~= nil and not lume.find(self.targets_hit, target) then
		table.insert(self.targets_hit, target)
	end
end

function HitTracker:GetTargetsHit()
	-- returns the targets that have been hit by the attack that is currently going on.
	return self.is_active and self.targets_hit or {}
end

function HitTracker:StartNewAttack(attack_type, attack_id, auto_exit, listen_override)
	if self.is_active then
		assert(true, "HitTracker cannot track two attacks at the same time!")
	end

	-- print("-----------------------")
	-- printf("HitTracker:StartNewAttack [%s] - %s", self.inst, attack_type)

	self.listen_override = listen_override or nil
	self.targets_hit = {}
	self.attack_type = attack_type
	self.attack_id = attack_id
	self.inst:ListenForEvent("do_damage", self._on_do_damage, self.listen_override)
	self.is_active = true

	if auto_exit then
		self.is_auto_exit = true
		self.inst:ListenForEvent("newstate", self._on_state_changed)
	end
end

function HitTracker:FinishAttack()
	if not self.is_active then
		assert(true, "HitTracker tried to finish an attack, but no attack was ever started!")
	end

	-- print("HitTracker:FinishAttack")

	self.inst:RemoveEventCallback("do_damage", self._on_do_damage, self.listen_override)
	self.inst:PushEvent(self.attack_type, { targets_hit = self.targets_hit, attack_id = self.attack_id } ) -- PushEvent("light_attack //// PushEvent("heavy_attack
	self.is_active = false

	if self.is_auto_exit then
		self.inst:RemoveEventCallback("newstate", self._on_state_changed)
		self.is_auto_exit = false
	end
end

return HitTracker