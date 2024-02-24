local kassert = require "util.kassert"
require "util.sourcemodifiers"

local Enum = require "util.enum"

local HealthNrBits <const> = 20	-- max 1<<20 = 1048576
local HealthStatusBits <const> = 4 -- expect Health.Status ids to be [1,4]
local HealthMaxValue <const> = (1 << HealthNrBits) - 1

local Health = nil -- Forward declaration for Health.Status enum
Health = Class(function(self, inst)
	self.inst = inst
	self.max = 100
	self.low_health_fixed = 150
	self.health_add_modifiers = {}
	self.health_mult_modifiers = {}
	self.current = self:GetMax()
	self.healable = true
	self.status = Health.Status.id.ALIVE

	self.armour = 0
	self.max_armour = 0

	self._new_run_fn = function()
		if self.initial_health then
			TheLog.ch.Health:printf("Clearing initial health value for new run: %s", tostring(self.initial_health))
			self.initial_health = nil
		end
		self:HealAndClearAllModifiers()
	end

	self.inst:ListenForEvent("start_new_run", self._new_run_fn)
	self.inst:ListenForEvent("end_current_run", self._new_run_fn)

	self._on_max_health_changed_fn = function()
		if self.current > self:GetMax() then
			self:SetCurrent(self:GetMax(), true)
		end
	end

	self.inst:ListenForEvent("maxhealthchanged", self._on_max_health_changed_fn)

	self.inst:ListenForEvent("done_dying", self._on_done_dying)
end)

-- Used to determine the death state a player is in. Everything should check for these values instead of relying on HP = 0.
Health.Status = Enum{ "ALIVE", "DYING", "DEAD", "REVIVABLE" }

function Health:GetMissing()
	return self:GetMax() - self:GetCurrent()
end

function Health:GetCurrent()
	return self.current
end

function Health:GetReviveAmount()
	return self.current * TUNING.REVIVE_HEALTH_PERCENT
end

function Health:GetBaseMaxHealth()
	return self.max
end

function Health:SetBaseMaxHealth(max)
	self:SetMax(max, true)
	self.inst:PushEvent("basemaxhealthchanged", self:GetBaseMaxHealth())
end

function Health:GetMax()
	local max = self.max + self:GetHealthAddModifiers()
	max = self:ApplyHealthMultModifiers(max)
	return max
end

function Health:GetLowHealthThreshold()
	if self.low_health_pct then
		return self.low_health_pct * self:GetMax(), self.low_health_pct
	elseif self.low_health_fixed then
		return self.low_health_fixed, self.low_health_fixed / self:GetMax()
	else
		error("Why don't we have a low_health value?")
	end
end

-------------------------------------------------
-- Life Status Functions
function Health:IsAlive()
	return self.status == Health.Status.id.ALIVE
end

function Health:IsDying()
	return self.status == Health.Status.id.DYING
end

function Health:IsDead()
	--return self:GetCurrent() <= 0
	return self.status == Health.Status.id.DEAD
end

function Health:IsRevivable()
	return self.status == Health.Status.id.REVIVABLE
end
-------------------------------------------------

function Health:GetPercent()
	return self:GetCurrent() / self:GetMax()
end

function Health:IsLow()
	local low_health = self:GetLowHealthThreshold()
	return (low_health < self.max -- Ignore low health if invalid.
		and 0 < self.current
		and self.current <= low_health)
end

-- When you want a fixed amount to be considered low. Useful for enemies so the
-- player can estimate how much health remains.
function Health:SetLowHealthAmount(val)
	kassert.lesser(val, self.max)
	self.low_health_fixed = val
	self.low_health_pct = nil
end

-- When you want low to be proportional to max health (and affected by health
-- modifiers).
function Health:SetLowHealthPercent(val)
	kassert.lesser(val, 1)
	self.low_health_fixed = nil
	self.low_health_pct = val
end

function Health:IsHealable()
	return self.healable
end

function Health:SetHealable(bool)
	self.healable = bool
end

function Health:SetCurrent(val, silent)
	if self.inst:IsLocalOrMinimal() then	-- Don't apply health changes to networked entities, or healthbars will do weird things (reduce health, then jump back up on the next network update, then go down again when the network catches up with the attack)
		self:SetInternal(val, silent)
	end
end

function Health:SetPercent(pct, silent)
	if self.inst:IsLocalOrMinimal() then	-- Don't apply health changes to networked entities, or healthbars will do weird things (reduce health, then jump back up on the next network update, then go down again when the network catches up with the attack)
		self:SetInternal(self:GetMax() * pct, silent)
	end
end

function Health:SetMax(max, silent)
	local percent = self:GetPercent()
	max = math.max(1, max)
	self.max = max
	self:SetPercent(percent, silent)
	self.inst:PushEvent("maxhealthchanged", self:GetMax())
end

function Health:GetHealthAddModifiers()
	local total = 0
	for id, bonus in pairs(self.health_add_modifiers) do
		total = total + bonus
	end
	return total
end

function Health:AddHealthAddModifier(source_id, bonus)
	self.health_add_modifiers[source_id] = bonus
	self.inst:PushEvent("maxhealthchanged", self:GetMax())
	self.inst:PushEvent("healthchanged", {
		old = self:GetCurrent(),
		new = self:GetCurrent(),
		max = self:GetMax(),
	})
end

function Health:RemoveHealthAddModifier(source_id)
	self.health_add_modifiers[source_id] = nil
	self.inst:PushEvent("maxhealthchanged", self:GetMax())
	self.inst:PushEvent("healthchanged", {
		old = self:GetCurrent(),
		new = self:GetCurrent(),
		max = self:GetMax(),
	})
end

function Health:GetHealthAddModifierBySource(source_id)
	return self.health_add_modifiers[source_id]
end

function Health:AddHealthMultModifier(source_id, mult)
	self.health_mult_modifiers[source_id] = mult
	self.inst:PushEvent("maxhealthchanged", self:GetMax())
	self.inst:PushEvent("healthchanged", {
		old = self:GetCurrent(),
		new = self:GetCurrent(),
		max = self:GetMax(),
	})
end

function Health:RemoveHealthMultModifier(source_id)
	self.health_mult_modifiers[source_id] = nil
	self.inst:PushEvent("maxhealthchanged", self:GetMax())
	self.inst:PushEvent("healthchanged", {
		old = self:GetCurrent(),
		new = self:GetCurrent(),
		max = self:GetMax(),
	})
end

function Health:ApplyHealthMultModifiers(num)
	for id, mod in pairs(self.health_mult_modifiers) do
		num = num * mod
	end
	return math.floor(num)
end

function Health:HealAndClearAllModifiers()
	if self.inst:IsLocalOrMinimal() then	-- Don't apply health changes to networked entities, or healthbars will do weird things (reduce health, then jump back up on the next network update, then go down again when the network catches up with the attack)
		self.health_add_modifiers = {}
		self.health_mult_modifiers = {}
		if self:IsHealable() then
			self:SetInternal(self:GetMax(), true)
		end
	end
end

function Health:Kill(silent)
	if self.inst:IsLocal() then	-- Don't apply health changes to networked entities, or healthbars will do weird things (reduce health, then jump back up on the next network update, then go down again when the network catches up with the attack)
		-- don't want to accidentally kill things not meant to be killed
		if self.inst:HasTag("nokill") and self.inst:HasTag("mob") then
			TheLog.ch.Health:printf("nokill tag removed from entity GUID %d", self.inst.GUID)
			self.inst:RemoveTag("nokill")
		end
		self:SetInternal(0, silent)
	end
end

function Health:GetAttacked(attack)
	local damage = attack:GetDamage()
	if self.inst.components.shield then
		damage = self.inst.components.shield:AbsorbDamage(damage, attack)
	end
	self:DoDelta(-damage, false, attack)
end

function Health:DoDelta(delta, silent, attack)
	if self.inst:IsLocalOrMinimal() then	-- Don't apply health changes to networked entities, or healthbars will do weird things (reduce health, then jump back up on the next network update, then go down again when the network catches up with the attack)
		local old = self:GetCurrent()
		self:SetInternal(self:GetCurrent() + delta, silent, attack)
		local new = self:GetCurrent()
		return (new - old)
	else
		return 0
	end
end

function Health:SetInternal(val, silent, attack)
	local was_low, health_parameter_for_fmod = self:IsLow()
	local old = self:GetCurrent()
	if val <= 0 and old > 0 then
		if (self.inst.sg ~= nil and self.inst.sg:HasStateTag("nokill"))
			or self.inst:HasTag("nokill")
			or (attack ~= nil and attack:GetCannotKill())
			or (not self:IsDead() and not self.inst:IsLocal() and not self.inst:HasTag("player"))
		then
			val = math.min(1, old)
		end
	elseif attack and val > 0 and old <= 0 and not attack:IsHealForced() then -- Cannot heal if HP <= 0 & not a forced heal
		return
	end
	local hurt = not silent and val < old
	self.current = math.clamp(val, 0, self:GetMax())
	self.inst:PushEvent("healthchanged", {
		old = old,
		new = self:GetCurrent(),
		max = self:GetMax(),
		hurt = hurt,
		silent = silent,
		attack = attack,
	})
	if was_low ~= self:IsLow() then
		self.inst:PushEvent("lowhealthstatechanged", self:IsLow())
		-- would love to try to push current health as fraction of max across the gap into lowhealthindicator.lua from here
		-- for use as a parameter
	end

	-- Player's health just turned zero
	if val <= 0 and old > 0 and self.inst:IsLocal() then
		self.inst:PushEvent("healthdepleted")

		if self:ShouldBeDying() then
			self.status = Health.Status.id.DYING
			self.inst:PushEvent("dying", { attack = attack, })
		else
			self.status = Health.Status.id.ALIVE
			self.inst:PushEvent("avoided_dying", self.inst)
		end
	end
end

function Health:ShouldBeDying()
	-- Transition to dying status if everything here is true.

	-- Only process if our status is alive.
	if self.status ~= Health.Status.id.ALIVE then
		return false
	end

	-- Check powermanager for any powers that prevent entering the dying state.
	if self.inst.components.powermanager and not self.inst.components.powermanager:CanStartDying() then
		return false
	end

	return true
end

function Health:CanActuallyDie()
	-- Transition to dead status if everything here is true.

	-- Only process if our status is dying.
	if self.status ~= Health.Status.id.DYING then
		return false
	end

	-- Is our health currently somehow above zero?
	if self.current > 0 then
		return false
	end

	-- (Lucky revive is checked within the powermanager, as it's a power now)

	-- Check powermanager for any powers that prevent entering the dying state.
	if self.inst.components.powermanager and not self.inst.components.powermanager:CanActuallyDie() then
		return false
	end

	return true
end

-- Move this outside of health?
-- Only "public" for networking
function Health:UpdateDeathStats()
	if self.inst:HasTag("mob") or self.inst:HasTag("boss") then
		local local_players = TheNet:GetLocalPlayerList()
		local is_active_player_present = false

		-- all active players that are present get credit for this, not just the player who got the killing blow
		for _i, id in ipairs(local_players) do
			local player = GetPlayerEntityFromPlayerID(id)
			if player and not player:IsSpectating() then
				is_active_player_present = true
				local progresstracker = player.components.progresstracker
				if progresstracker then
					-- TheLog.ch.Health:printf("DeathStat: player %d slot %d increment kills %s", id, slot, self.inst.prefab)
					progresstracker:IncrementKillValue("kills")
					progresstracker:IncrementKillValue(self.inst.prefab)

					if self.inst:HasTag("boss") then
						progresstracker:IncrementKillValue("boss")
					end

					if self.inst:HasTag("elite") then
						progresstracker:IncrementKillValue("elite")
					end
				end
			-- else
				-- TheLog.ch.Health:printf("DeathStat: ignored player %d (spectating or invalid)", id)
			end
		end

		if is_active_player_present then
			TheWorld:PushEvent("player_kill", self.inst)
		end
	end
end

function Health:_on_done_dying()
	local hc = self.components.health
	if hc.inst:HasTag("player") and not hc:CanActuallyDie() then
		-- only allow players to actually revert back to alive while dying
		hc.status = Health.Status.id.ALIVE
		hc.inst:PushEvent("avoided_death", hc.inst)
	else
		-- Actually dead now.
		hc.status = Health.Status.id.DEAD

		if hc.inst.components.lootdropper then
			-- specifically not doing this with an event so it happens BEFORE all the other "death" event triggers.
			hc.inst.components.lootdropper:OnDeath()
			-- TODO: networking2022, fix how this is called
			hc.inst.components.lootdropper:OnDeathKonjur()
		end

		hc.inst:PushEvent("death", self)
		if hc.inst:IsNetworked() then
			TheNetEvent:DeathStat(hc.inst.GUID)
		else
			self:UpdateDeathStats()
		end
	end
end

function Health:SetRevivable()
	if not self.status == Health.Status.id.DEAD then
		return
	end
	self.status = Health.Status.id.REVIVABLE
	self.inst:PushEvent("revivable")
end

function Health:SetRevived(reviver)
	if not self.status == Health.Status.id.REVIVABLE then
		return
	end
	self.status = Health.Status.id.ALIVE
	self.inst:PushEvent("revived", reviver)
end

function Health:OnSave()
	local data = {}

	data.max = self:GetBaseMaxHealth()

	if self:GetCurrent() ~= self:GetMax() then
		data.current = self:GetCurrent()
	end

	if next(self.health_add_modifiers) then
		data.health_add_modifiers = deepcopy(self.health_add_modifiers)
	end

	if next(self.health_mult_modifiers) then
		data.health_mult_modifiers = deepcopy(self.health_mult_modifiers)
	end

	return next(data) and data or nil
end

function Health:OnLoad(data)

	if data.max ~= self:GetBaseMaxHealth() then
		self:SetBaseMaxHealth(data.max)
	end

	if data.health_add_modifiers then
		for id, mod in pairs(data.health_add_modifiers) do
			self:AddHealthAddModifier(id, mod)
		end
	end

	if data.health_mult_modifiers then
		for id, mod in pairs(data.health_mult_modifiers) do
			self:AddHealthMultModifier(id, mod)
		end
	end

	-- If we're in town, heal to full health.
	if TheWorld:HasTag("town") then
		data.current = data.max
	end

	-- Delay until OnPostLoadWorld to allow the ondying, ondeath sg event handlers to load fully before applying health.
	if data.current ~= nil then
		self.initial_health = data.current
	else
		self.initial_health = HealthMaxValue
	end
end

function Health:OnPostLoadWorld(_data)
	if self.initial_health then
		self:SetInternal(self.initial_health, true)
		self.initial_health = nil
	end
end

function Health:OnNetSerialize()
	local e = self.inst.entity

	-- TODO: networking2022, victorc - Safe to serialize like this for
	-- entities that don't change ownership (i.e. players, host auth stuff)
	-- and it would avoid needing to serialize modifiers.
	-- Not safe to do this for transferable entities since the modifiers to
	-- calculate GetMax() are currently not synced.
	e:SerializeUInt(self:GetMax(), HealthNrBits)
	e:SerializeUInt(self:GetCurrent(), HealthNrBits)
	assert(self.status >= 1 and self.status <= 4, "Health status value overflow")
	e:SerializeUInt(self.status - 1, HealthStatusBits)

	-- Self-cleanup catch-all to handle cases on mobs where there are discrepancies in health and status to prevent zombie entities.
	-- If there's a discrepency in these cases, remove the entity:
	--  - Status is set to not alive, but health is > 0
	--  - Status is set to alive, but health is <= 0
	if self.inst:HasTag("mob")
		and not self.inst:IsInDelayedRemove()
		and	(  (self.status ~= Health.Status.id.ALIVE and self.current > 0)
			or (self.status == Health.Status.id.ALIVE and self.current <= 0))
	then
		TheLog.ch.Health:printf("Warning! Health status discrepency. Removing entity! GUID %d, EntityID %d, Status: %s (%d), Health: %0.3f, Hitbox Enabled: %s, In Limbo: %s, Last State: %s, Current State: %s",
			self.inst.GUID,
			self.inst.Network:GetEntityID(),
			Health.Status:FromId(self.status, "<invalid>"), self.status,
			self.current,
			self.inst.HitBox:IsEnabled(),
			self.inst:IsInLimbo(),
			self.inst.sg.laststate and self.inst.sg.laststate.name, self.inst.sg:GetCurrentState())
		self.inst:DelayedRemove()
	end
end

function Health:OnNetDeserialize()
	local e = self.inst.entity

	local mx = e:DeserializeUInt(HealthNrBits)
	local cr = e:DeserializeUInt(HealthNrBits)

	if mx and self.max ~= mx then
		self:SetBaseMaxHealth(mx)
	end
	if cr and cr ~= self.current then
		self:SetInternal(cr, true)
	end

	local status = e:DeserializeUInt(HealthStatusBits) + 1
	assert(status >= 1 and status <= 4, "Health status value overflow")
	self.status = status
end

local SGCommon = require("stategraphs.sg_common")

function Health:OnEntityBecameLocal()
	-- If it is dead, the death flow already happened on a different machine. Remove it.
	if (self:IsDead() or self.inst:HasTag("no_state_transition")) and not self.inst:HasTag("no_remove_on_death") then
		self.inst:Remove()

	-- There are signs that we tried killing this entity previously but lost control.
	elseif SGCommon.Fns.HasSignsOfDying(self.inst) then
		TheLog.ch.Health:printf("Warning: %s EntityID %d has previous signs of death (zombie).  Removing entity...",
			self.inst,
			self.inst:IsNetworked() and self.inst.Network:GetEntityID() or -1)
		self.inst:Remove()

	-- We've received it already in the dying state which didn't complete for some reason. Set it to ALIVE and then make it do the flow again.
	elseif self:IsDying() then
		self.inst:PushEvent("dying")

	-- If it has no health, but hasn't gone through the death flow, we should make it go through the death flow.
	elseif self:IsAlive() and self.current <= 0 then
		self.status = Health.Status.id.DYING
		self.inst:PushEvent("dying")
	end
end

function Health:GetDebugString()
	return tostring(self:GetCurrent()).."/"..tostring(self:GetMax()) .. " Status[" .. Health.Status:FromId(self.status, "<invalid>") .."]"
end


function Health:DebugDrawEntity(ui, panel, colors)
	ui:Text("Max health: " .. self.max)
	ui:Text("Current health: " .. self.current)
	ui:Text("Status: " .. Health.Status:FromId(self.status))
end


return Health
