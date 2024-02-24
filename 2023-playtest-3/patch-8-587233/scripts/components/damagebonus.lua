local lume = require "util.lume"

local DamageBonus = Class(function(self, inst)
	self.inst = inst
end)

function DamageBonus:ModifyHeal(heal)
	local powers = self.inst.components.powermanager:GetAllPowersInAcquiredOrder()
	local is_healing = heal:GetAttacker() == self.inst
	local is_being_healed = heal:GetTarget() == self.inst
	assert(is_healing or is_being_healed)

	local start_heal = heal:GetHeal()

	local outputs = {
		heal_delta = 0,
		heal_to_healer = 0,
	}

	if is_healing then
		for _, pow in pairs(powers) do
			if not heal:SkipPowerHealModifiers() and pow.def.heal_mod_fn then
				local used = pow.def.heal_mod_fn(pow, heal, outputs)
				if used then
					self.inst:PushEvent("used_power", pow.def)
				end
			end
		end
	end

	-- These two are split out to potentially leave room for "when you heal yourself, do X" and "when you are healed, do Y"
	-- Right now they are the same thing, but Bryce intended for this to be a feature so I'm leaving this here to imply/remind the intent.
 	if is_being_healed then
		for _, pow in pairs(powers) do
			if not heal:SkipPowerHealModifiers() and pow.def.heal_mod_fn then
				local used = pow.def.heal_mod_fn(pow, heal, outputs)
				if used then
					self.inst:PushEvent("used_power", pow.def)
				end
			end
		end
	end

	assert(start_heal == heal:GetHeal(), "Modify functions shouldn't change heal. Modify heal_delta instead.")
	if outputs.heal_to_healer > 0 and heal:GetTarget().components.combat then
		local power_heal = Attack(heal:GetTarget(), heal:GetAttacker())
		power_heal:SetHeal(outputs.heal_to_healer)
		power_heal:SetSkipPowerHealModifiers(true)
		heal:GetTarget().components.combat:ApplyHeal(power_heal)
	end

	heal:SetHeal(lume.clamp(start_heal + outputs.heal_delta, 0, math.huge))
	--~ if outputs.damage_delta ~= 0 then print(("[DamageBonus] attacker '%s' did %0.1f more damage to '%s'."):format(attacker, outputs.damage_delta, victim)) end
end

function DamageBonus:ModifyAttackAsAttacker(attack)
	-- Runs only on the attacker's local machine, whether that attacker is a Player or a Mob.
	if attack:GetAttacker() ~= self.inst then
		return
	end

	local powers = self.inst.components.powermanager:GetAllPowersInAcquiredOrder()
	local start_damage = attack:GetDamage()

	local outputs = {
		damage_delta = 0,
	}

	for _, pow in pairs(powers) do
		local used = false

		if not attack:SkipPowerDamageModifiers() and pow.def.damage_mod_fn then
			used = pow.def.damage_mod_fn(pow, attack, outputs)
		end

		if used then
			self.inst:PushEvent("used_power", pow.def)
		end
	end

	assert(attack:GetDamage() == start_damage, "Modify functions shouldn't change damage. Modify damage_delta instead.")

	attack:SetDamage(lume.clamp(start_damage + outputs.damage_delta, 0, math.huge))
	--~ if outputs.damage_delta ~= 0 then print(("[DamageBonus] attacker '%s' did %0.1f more damage to '%s'."):format(attacker, outputs.damage_delta, victim)) end
end

function DamageBonus:ModifyAttackAsDefender(attack)
	-- Runs on the defender's local machine, whether that defender is a Player or a Mob.
	-- Also runs, after the attack has been transmitted, on the attacker's side ONLY to determine if the attack will deal >0 damage, for hitstreak purposes.
	-- But that second case does not actually affect the attack which the defender receives.
	if attack:GetTarget() ~= self.inst then
		return
	end

	local powers = self.inst.components.powermanager:GetAllPowersInAcquiredOrder()

	local start_damage = attack:GetDamage()

	local outputs = {
		damage_delta = 0,
	}

	for _, pow in pairs(powers) do
		local used = false

		if not attack:SkipPowerDefendModifiers() and pow.def.defend_mod_fn and (self.inst.components.health:IsAlive() or pow.def.works_on_nonalive) then
			used = pow.def.defend_mod_fn(pow, attack, outputs) or used
		end

		if used then
			self.inst:PushEvent("used_power", pow.def)
		end
	end

	assert(attack:GetDamage() == start_damage, "Modify functions shouldn't change damage. Modify damage_delta instead.")

	attack:SetDamage(lume.clamp(start_damage + outputs.damage_delta, 0, math.huge))

	--~ if outputs.damage_delta ~= 0 then print(("[DamageBonus] attacker '%s' did %0.1f more damage to '%s'."):format(attacker, outputs.damage_delta, victim)) end
end

return DamageBonus
