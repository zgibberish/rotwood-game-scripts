
local Attack = Class(function(self, attacker, target)

-- WARNING: Adding/Removing fields will require C++ changes to sync this class over the network. Talk to the networking team!

	self.id = "default"  -- e.g. light_attack, heavy_attack
	self._name_id = nil  -- the id of the attack itself "bite", "lunge", etc
	self._attacker = nil
	self._target = nil
	self._damage_mod = 1
	self._damage = nil
	self._heal = nil
	self._healforced = nil
	self._hitstunframes = 1
	self._pushback = 1
	self._focus = false
	self._crit = false
	self._dir = nil
	self._isknockdown = false
	self._knockdownbecomesprojectile = false
	self._forceknockdown = false
	self._knockdown_duration = 0
	self._knocked = false
	self._sourceType = Attack.SourceType.ATTACKER
	self._chain = {}
	self._chain_count = 0
	self._ignore_armour = false
	self._ignore_shield = false
	self._skip_power_damage_modifiers = false
	self._skip_power_defend_modifiers = false
	self._skip_power_heal_modifiers = false
	self._is_high = false
	self._cannot_kill = false
	self._show_damage_number = true
	self._hit_flags = Attack.HitFlags.DEFAULT
	self._hitbox_data = nil

	-- only intended to be used for remote attacks
	self._hitstoplevel = HitStopLevel.NONE
	self._hitstop_allow_multiple_on_attacker = false
	self._hitstop_disable_enemy_on_enemy = false
	self._hitstop_disable_self_hitstop = false

	self._do_hit_reaction = true
	self._bypass_posthit_invincibility = false -- Disable the targets's post-hit invincibility frames, if any, if this is meant to be a rapidly-hitting attack.

	self._force_crit = false -- Ignore normal combat rolls, always crit.
	self._bonus_crit_chance = 0
	self._bonus_crit_damage_mult = 0

	self._projectile = nil -- used for attacks done by projectiles for power purposes.
	-- shotput can be launched off ground by other entities (players, mobs, etc.)
	-- NOT synced (only used in initial attack event tests) -- maybe it needs syncing?
	self._projectilelauncher = nil

	self._keep_it_local = false -- _keep_it_local is used for bullets that are spawned as a LOCAL entity on ALL machines. They should only damage local entities.
	self._is_remote_attack = false -- when true, this was an attack executed on behalf of a non-local attacker (i.e. shotput hit by a remote player)
	self._force_remote_hit_confirm = false -- when true, force confirm a hit when checking for attacks sent from a remote entity.

	self:SetAttacker(attacker)
	self:SetTarget(target)
end)

Attack.HitFlags =
{
	GROUND =			0x01,
	AIR =				0x02,
	AIR_HIGH = 			0x04,
	PROJECTILE = 		0x08,
	--
	ALL = 				0xFF,
}

Attack.HitFlags.DEFAULT = Attack.HitFlags.GROUND | Attack.HitFlags.AIR | Attack.HitFlags.AIR_HIGH
Attack.HitFlags.LOW_ATTACK = Attack.HitFlags.GROUND | Attack.HitFlags.AIR


Attack.SourceType =
{
	ATTACKER =			1,
	NOTATTACKER =		2,
	LUCK =				3,
}


--- Set Functions ---

function Attack:SetID(id)
	assert(type(id) == "string")
	self.id = id
	return self
end

function Attack:SetNameID(name_id)
	assert(type(name_id) == "string")
	self._name_id = name_id
	return self
end

function Attack:SetTarget(target)
	self._target = target
	assert(self._target.components.combat ~= nil, "You cannot attack something that does not have a combat component.")
	return self
end

function Attack:SetAttacker(attacker)
	if not attacker.Network then
		self._keep_it_local = true
	end

	if attacker.owner then
		self._attacker = attacker.owner
	else
		self._attacker = attacker
	end

	self:InitAttackChainData()
	assert(self._attacker.components.combat ~= nil, "You cannot attack without a combat component.")
	return self
end

function Attack:SetDamageMod(damage_mod)
	self._damage_mod = damage_mod or 1.0
	return self
end

function Attack:SetDamage(damage)
	self._damage = damage
	self:UpdateAttackChainData()
	return self
end

function Attack:SetHeal(heal)
	self._heal = heal
	return self
end

function Attack:SetHealForced(toggle)
	self._healforced = toggle
	return self
end

function Attack:SetForceCriticalHit(toggle)
	self._force_crit = toggle
end

function Attack:DeltaBonusCritChance(delta)
	self._bonus_crit_chance = self._bonus_crit_chance + delta
	return self
end

function Attack:DeltaBonusCritDamageMult(delta)
	self._bonus_crit_damage_mult = self._bonus_crit_damage_mult + delta
	return self
end

function Attack:SetHitstunAnimFrames(hitstun)
	self._hitstunframes = hitstun
	return self
end

function Attack:SetPushback(pushback)
	self._pushback = pushback
	return self
end

function Attack:SetCrit(crit)
	self._crit = crit
	return self
end

function Attack:SetFocus(focus)
	self._focus = focus
	self:UpdateAttackChainData()
	return self
end

function Attack:SetDir(dir)
	self._dir = dir
	return self
end

function Attack:SetIsKnockdown(isknockdown)
	self._isknockdown = isknockdown
	return self
end

function Attack:SetForceKnockdown(forceknockdown)
	self._forceknockdown = forceknockdown
	return self
end

function Attack:SetKnockdownDuration(duration)
	self._knockdown_duration = duration
	return self
end

function Attack:SetKnockdownBecomesProjectile(toggle)
	self._knockdownbecomesprojectile = toggle
end

function Attack:InitAttackChainData()
	assert(self._chain_count == 0)
	self._sourceType = Attack.SourceType.ATTACKER
	self:AddToChainData("attacker", self)
end

function Attack:UpdateAttackChainData()
	for _source, data in pairs(self._chain) do
		if data.index >= self._chain_count then
			data.damage = self._damage
			data.focus = self._focus
		end
	end
end

function Attack:SetSource(source)
	assert(self._chain_count > 0)
	assert(type(source) == "string")
	if source == "attacker" then
		self._sourceType = Attack.SourceType.ATTACKER
	elseif source == "luck" then
		self._sourceType = Attack.SourceType.LUCK
	else
		self._sourceType = Attack.SourceType.NOTATTACKER
	end

	self:AddToChainData(source, self)
	return self
end

function Attack:SetKnocked(knocked)
	self._knocked = knocked
	return self
end

function Attack:SetIgnoresShield(ignore_shield)
	self._ignore_shield = ignore_shield
	return self
end

function Attack:SetIgnoresArmour(ignore_armour)
	self._ignore_armour = ignore_armour
	return self
end

function Attack:SetSkipPowerDamageModifiers(skip)
	self._skip_power_damage_modifiers = skip
	return self
end

function Attack:SetSkipPowerDefendModifiers(skip)
	self._skip_power_defend_modifiers = skip
	return self
end

function Attack:SetSkipPowerHealModifiers(skip)
	self._skip_power_heal_modifiers = skip
	return self
end

function Attack:SetIsHigh(high)
	self._is_high = high
	return self
end

function Attack:SetCannotKill(cannot_kill)
	self._cannot_kill = cannot_kill
	return self
end

function Attack:SetProjectile(projectile, launcher)
	self._projectile = projectile
	self._projectilelauncher = launcher or self._attacker
	assert(self._projectilelauncher)
	if self._projectile.owner
		and self._projectile.owner:IsNetworked()
		and not self._projectile.owner:IsLocal()
		and self._projectilelauncher:IsLocal() then
		self._is_remote_attack = true
	end
	return self
end

function Attack:GetProjectileLauncher()
	return self._projectilelauncher
end

function Attack:IsRemoteAttack()
	return self._is_remote_attack
end

function Attack:SetHitFlags(flags)
	self._hit_flags = flags
end

-- This is forwarded data from hitbox.lua
-- data structure is defined as part of the "hitboxtriggered" event
function Attack:SetHitBoxData(hitbox_data)
	self._hitbox_data = hitbox_data
end

function Attack:SetHitFxData(hit_fx, offx, offy)
	self._hit_fx = hit_fx
	self._hit_fx_offset_x = offx
	self._hit_fx_offset_y = offy
end

function Attack:DisableHitReaction()
	self._do_hit_reaction = false
	return self
end

function Attack:BypassesPosthitInvincibility()
	return self._bypass_posthit_invincibility
end

function Attack:DisablePostHitInvincibility()
	self._bypass_posthit_invincibility = true
	return self
end

function Attack:DisableDamageNumber()
	self._show_damage_number = false
	return self
end

function Attack:SetOverrideDamage(damage)
	self._override_damage = damage
end

-- only intended to be used for remote attacks
function Attack:SetHitStopData(level, allow_multiple_on_attacker, disable_enemy_on_enemy, disable_self_hitstop)
	self._hitstoplevel = level
	self._hitstop_allow_multiple_on_attacker = allow_multiple_on_attacker
	self._hitstop_disable_enemy_on_enemy = disable_enemy_on_enemy
	self._hitstop_disable_self_hitstop = disable_self_hitstop
end

function Attack:SetForceRemoteHitConfirm(enabled)
	self._force_remote_hit_confirm = enabled
end

--- Get Functions ---

function Attack:GetID()
	return self.id
end

function Attack:GetNameID()
	return self._name_id
end

function Attack:GetTarget()
	return self._target
end

function Attack:GetAttacker()
	return self._attacker
end

function Attack:GetDamageMod()
	return self._damage_mod or 1.0
end

function Attack:GetDamage()
	return self._damage
end

function Attack:GetHeal()
	return self._heal
end

function Attack:IsHealForced()
	return self._healforced
end

function Attack:GetHitstunAnimFrames()
	return self._hitstunframes
end

function Attack:GetPushback()
	return self._pushback
end

function Attack:GetCrit()
	return self._crit
end

function Attack:GetBonusCritChance()
	return self._bonus_crit_chance
end

function Attack:GetForceCriticalHit()
	return self._force_crit
end

function Attack:GetBonusCritDamageMult()
	return self._bonus_crit_damage_mult
end

function Attack:GetFocus()
	return self._focus
end

function Attack:GetDir()
	return self._dir
end

function Attack:IsKnockdown()
	return self._isknockdown
end

function Attack:IsForceKnockdown()
	return self._forceknockdown
end

function Attack:GetKnockdownDuration()
	return self._knockdown_duration
end

function Attack:GetKnockdownBecomesProjectile()
	return self._knockdownbecomesprojectile
end

function Attack:SourceIsLuck()
	return self._sourceType == Attack.SourceType.LUCK
end

function Attack:SourceIsAttacker()
	return self._sourceType == Attack.SourceType.ATTACKER
end

function Attack:GetKnocked()
	return self._knocked
end

function Attack:GetIgnoresArmour()
	return self._ignore_armour
end

function Attack:GetIgnoresShield()
	return self._ignore_shield
end

function Attack:SkipPowerDamageModifiers()
	return self._skip_power_damage_modifiers
end

function Attack:SkipPowerDefendModifiers()
	return self._skip_power_defend_modifiers
end

function Attack:SkipPowerHealModifiers()
	return self._skip_power_heal_modifiers
end

function Attack:IsHigh()
	return self._is_high
end

function Attack:GetCannotKill()
	return self._cannot_kill
end

function Attack:GetProjectile()
	return self._projectile
end

function Attack:GetHitFlags()
	return self._hit_flags
end

function Attack:GetHitBoxData()
	return self._hitbox_data
end

function Attack:GetHitFxData()
	return self._hit_fx, self._hit_fx_offset_x, self._hit_fx_offset_y
end

function Attack:CanHit()
	local tar = self:GetTarget()
	if tar and tar.components.hitflagmanager then
		return tar.components.hitflagmanager:CanAttackHit(self)
	else
		return true
	end
end

function Attack:ShowDamageNumber()
	return self._show_damage_number
end

function Attack:DoHitReaction()
	return self._do_hit_reaction
end

function Attack:IsForceRemoteHitConfirm()
	return self._force_remote_hit_confirm
end

function Attack:GetMetrics_PlayerVictim()
	-- dbriscoe: I assume these are all relevant when the player is attacked?
	return {
		id = self:GetID(),
		attacker = self._attacker.prefab,
		damage = self._damage,
		damage_mod = self._damage_mod,
		isknockdown = self._isknockdown,
	}
end

-- only intended to be used for remote attacks
function Attack:GetHitStopData()
	return self._hitstoplevel,
		self._hitstop_allow_multiple_on_attacker,
		self._hitstop_disable_enemy_on_enemy,
		self._hitstop_disable_self_hitstop
end

--- Util Functions ---

local function MakeAttackChainData(index, damage, focus)
	return
	{
		index = index,
		damage = damage,
		focus = focus,
	}
end

function Attack:GetLastDamageSourceInChain()
	local highest_index = 0
	local chain_data = nil
	for _source,data in pairs(self._chain) do
		if data.damage ~= nil and data.index > highest_index then
			highest_index = data.index
			chain_data = data
		end
	end
	return chain_data
end

function Attack:CheckChain(source)
	assert(type(source) == "string")
	return self._chain[source]
end

function Attack:AddToChainData(source, attack)
	assert(type(source) == "string")
	local data = MakeAttackChainData(self._chain_count + 1, attack:GetDamage(), attack:GetFocus())
	self:_AddToChainDataInternal(source, data)
end

function Attack:_AddToChainDataInternal(source, data)
	assert(type(source) == "string")
	if not self._chain[source] then
		self._chain[source] = data
		self._chain_count = self._chain_count + 1
	else
		TheLog.ch.Attack:printf("Tried to add duplicate attack source: %s", source)
	end
end

function Attack:GetNumInChain()
	return self._chain_count
end

function Attack:CloneChainDataFromAttack(src_attack)
	-- completely stomp initialized chain when cloning
	self._chain = {}
	self._chain_count = 0
	for src_source, src_data in pairs(src_attack._chain) do
		local data = MakeAttackChainData(src_data.index, src_data.damage, src_data.focus)
		self:_AddToChainDataInternal(src_source, data)
	end
end

local debugID = 1
function Attack:DebugDumpAttackChain()
	for source, data in pairs(self._chain) do
		TheLog.ch.Attack:printf("Chain %d k: %s v: index=%d damage=%s focus=%s",
			debugID, source, data.index, tostring(data.damage), tostring(data.focus))
	end
	debugID = debugID + 1
end

-- ===========================================================================

function Attack:InitDamageAmount(damage_mult)
	damage_mult = damage_mult or 1
	local attacker = self:GetAttacker().components.combat
	local damage_bonus = attacker.damagedealtbonus:Get()
	local damage
	if self._override_damage ~= nil then
		damage = self._override_damage + damage_bonus
	else
		local base_damage = attacker.basedamage:Get()
		damage = (base_damage + damage_bonus) * self:GetDamageMod()
		if self:GetFocus() then
			local focus_damage_mult = attacker.focusdamagemult:Get()
			damage = damage * focus_damage_mult
		end
	end
	self:SetDamage(damage * damage_mult)
end

function Attack:IsHeavyAttack()
	return self:GetID() == "heavy_attack"
end

function Attack:IsLightAttack()
	return self:GetID() == "light_attack"
end

function Attack:IsPotionHeal()
	return self:GetID() == "potion_heal"
end

function Attack:GetTotalCritChance()
	return self:GetAttacker().components.combat.critchance:Get() + self:GetBonusCritChance()
end

function Attack:GetTotalCritDamageMult()
	return self:GetAttacker().components.combat.critdamagemult:Get() + self:GetBonusCritDamageMult()
end

return Attack
