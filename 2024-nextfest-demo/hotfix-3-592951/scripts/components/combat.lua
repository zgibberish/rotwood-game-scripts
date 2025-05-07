local DebugDraw = require "util.debugdraw"
local lume = require "util.lume"
local SGCommon = require "stategraphs.sg_common"
local audioid = require "defs.sound.audioid"
local fmodtable = require "defs.sound.fmodtable"
local ParticleSystemHelper = require "util.particlesystemhelper"
local soundutil = require "util.soundutil"
local Enum = require "util.enum"
local Weight = require "components.weight"

require("util/sourcemodifiers")

local KNOCKBACK_FRONT_MULT = 1.2
local KNOCKBACK_VULNERABLE_MULT = 1.5
local DOWN_FRONT_MULT = 3
local DOWN_BACK_MULT = 2
local BLOCK_FRONT_MULT = 0
local BLOCK_BACK_MULT = .8

local PVPMODE_DISABLED = 0
local PVPMODE_HIT_REACTIONS_ONLY = 1
local PVPMODE_ENABLED = 2

TargetTagGroups =
{
	Players = { "player", "playerminion" },
	Enemies = { "mob", "boss", "dummy" },
	Neutral = { "prop", "neutral" },
}

local Combat = Class(function(self, inst)
	self.inst = inst
	self.hurtfx = nil
	self.hasknockback = false
	self.hasknockdown = false
	self.hasknockdownhits = false
	self.hasknockdownhitdir = false
	self.frontknockbackonly = false
	self.vulnerableknockdownonly = false
	self.knockdownduration = 3
	self.knockdownlengthmodifier = 1
	self.blockknockback = false
	self.hasblockdir = false
	self.target = nil
	self.retargetfn = nil
	self.keeptargetfn = nil
	self.lastattacker = nil
	self.updating_targettracking = false
	self.updating_hitstreaks = false
	self.task = nil
	self.cooldownstart = nil
	self.cooldownend = nil
	self.pvpmode = PVPMODE_HIT_REACTIONS_ONLY
	self.ignoredamage = false

	self.current_hitstun_pressure_frames = 0
	self.hitstun_pressure_frames = nil

	self.damagenumbers = {} -- handles of UI elements

	self.targettags = {} -- Set of target tags that this entity can choose to target for offensive purposes
	self.friendlytargettags = {} -- Target tags this entity can choose to target for friendly purposes

	self.hitstreak = 0 -- The amount of hits in a short succession
	self.hitstreakdecaytime = 0 -- The amount of time left before this hitstreak dies
	self.hitstreakattackids = {} -- A table of all the attack ids
	self.hitstreakdamagetotal = 0 -- The total amount of damage dealt within this hitstreak

	-- TODO @chrisp #meta - if SourceModifiers operated against tables rather than numbers, it might be easier to
	-- work/dev with
	-- e.g. self.modifiers.DamageReceivedMult would return the number, merged from all sources
	-- e.g. self.modifiers:AddSource(game_effect) would add a table of modifiers from the game_effect source
	-- CombatModifiers already enumerates the variants that sources could set
	self.damagereceivedmult = MultSourceModifiers(inst)
	self.damagedealtmult = MultSourceModifiers(inst)

	self.critdamagemult = AddSourceModifiers(inst)
	self.critchance = AddSourceModifiers(inst)

	self.focusdamagemult = AddSourceModifiers(inst)

	self.damagedealtbonus = AddSourceModifiers(inst)
	self.basedamage = AddSourceModifiers(inst)

	self.damagereduction = AddSourceModifiers(inst)
	self.dungeontierdamagemult = AddSourceModifiers(inst, 1)
	self.dungeontierdamagereductionmult = AddSourceModifiers(inst, 0)

	self.healfx = nil

	self._onremovetarget = function() self:SetTarget(nil) end

	self._onkill = function(inst, data) self:OnKill(data) end

	inst:ListenForEvent("death", self._onremovetarget)

	self.inst:ListenForEvent("kill", self._onkill)
end)

local function ClosestRetargetFn(inst)
	-- Runs periodically, typically every 2sec or so.

	local old_target = inst.components.combat:GetTarget()
	local new_target = old_target
	local keeptargetfn = inst.components.combat.keeptargetfn
	local vision = inst.tuning.vision

	local closest_target, dist_to_closest_target = inst:GetClosestEntityByTagInRange(vision.aggro_range, inst.components.combat:GetTargetTags(), true, true)

	if not keeptargetfn(inst, old_target) then

		-- By our default "keep target" rules, our old target is not valid anymore. Pick the closest target.
		new_target = closest_target

	elseif closest_target and closest_target ~= old_target then

		-- Our closest target is not the old target, consider switching.

		if dist_to_closest_target <= vision.too_near_switch_target then

			-- The new target is close enough for us to possibly switch to them.

			if old_target then
				if inst:GetDistanceSqTo(old_target) <= vision.retarget_range then
					-- The old target is still in range, keep targeting it.
					new_target = old_target
				else
					-- The old target is too far away, switch to the closer one.
					new_target = closest_target
				end
			else
				-- The old target is gone. Just take the new one.
				new_target = closest_target
			end
		end
	end

	return new_target
end

local function RandomRetargetFn(inst)
	-- Runs periodically, typically every 2sec or so.
	local vision = inst.tuning.vision
	local target = inst:GetRandomEntityByTagInRange(vision.aggro_range, inst.components.combat:GetTargetTags(), true, true)
	return target
end

local function ValidateTuning(vision)
	dbassert(vision.aggro_range)
	dbassert(vision.retarget_period)
	dbassert(vision.retarget_range)
	dbassert(vision.too_near_switch_target)
	dbassert(vision.too_far_retarget)
	return vision
end

local function KeepTargetFn(inst, target)
	-- Runs every tick.

	-- Dead, non-existent, or in limbo
	if not target or not target:IsValid() or target:IsInLimbo() or not target:IsAlive() then
		return false
	end

	-- Too far away
	local vision = inst.tuning.vision
	local is_near = inst:IsNear(target, vision.too_far_retarget)
	if not is_near then
		return false
	end

	-- Stategraph has "notarget" function
	if target.sg and target.sg:HasStateTag("notarget") then
		return false
	end

	return true
end

function Combat:SetDefaultTargettingForTuning()
	assert(self.inst.tuning)
	local vision = ValidateTuning(self.inst.tuning.vision)
	self:SetRetargetFn(ClosestRetargetFn, vision.retarget_period)
	self:SetKeepTargetFn(KeepTargetFn)
end

function Combat:SetRandomTargettingForTuning()
	assert(self.inst.tuning)
	local vision = ValidateTuning(self.inst.tuning.vision)
	self:SetRetargetFn(RandomRetargetFn, vision.retarget_period)
	self:SetKeepTargetFn(KeepTargetFn)
end

function Combat:OnRemoveFromEntity()
	self.inst:RemoveEventCallback("death", self._onremovetarget)
	if self.target ~= nil then
		self.inst:RemoveEventCallback("onremove", self._onremovetarget, self.target)
		self.inst:RemoveEventCallback("death", self._onremovetarget, self.target)
	end
	if self.task ~= nil then
		self.task:Cancel()
	end
end

function Combat:SetHurtFx(fx)
	self.hurtfx = fx
end

function Combat:GetHurtFx()
	return self.hurtfx
end

function Combat:SetHasKnockback(enable)
	self.hasknockback = enable
end

function Combat:SetHasKnockdown(enable)
	self.hasknockdown = enable
end

function Combat:SetHasKnockdownHits(enable)
	self.hasknockdownhits = enable
end

function Combat:SetHasKnockdownHitDir(enable)
	self.hasknockdownhitdir = enable
end

function Combat:SetFrontKnockbackOnly(enable)
	self.frontknockbackonly = enable
end

function Combat:SetVulnerableKnockdownOnly(enable)
	self.vulnerableknockdownonly = enable
end

function Combat:SetKnockdownDuration(duration)
	self.knockdownduration = duration
end

function Combat:SetKnockdownLengthModifier(modifier)
	self.knockdownlengthmodifier = modifier
end

function Combat:SetBlockKnockback(enable)
	self.blockknockback = enable
end

function Combat:SetHasBlockDir(enable)
	self.hasblockdir = enable
end

function Combat:SetHitStunPressureFrames(frames)
	self.hitstun_pressure_frames = frames
end

function Combat:GetHitStunPressureFrames()
	return self.hitstun_pressure_frames
end

function Combat:GetCurrentHitstunPressureFrames()
	return self.current_hitstun_pressure_frames
end

function Combat:AddToCurrentHitStunPressureFrames(frames)
	self.current_hitstun_pressure_frames = self.current_hitstun_pressure_frames + frames
end

function Combat:ResetCurrentHitStunPressureFrames()
	self.current_hitstun_pressure_frames = 0
end

function Combat:HitStunPressureFramesExceeded()
	if not self.hitstun_pressure_frames then
		return false
	end
	return self.current_hitstun_pressure_frames >= self.hitstun_pressure_frames
end

function Combat:SetDamageReceivedMult(source, mult)
	self.damagereceivedmult:SetModifier(source, mult)
end

function Combat:SetDamageDealtMult(source, mult)
	self.damagedealtmult:SetModifier(source, mult)
end

function Combat:GetTotalDamageDealtMult()
	return self.damagedealtmult:Get()
end

function Combat:RemoveDamageReceivedMult(source)
	self.damagereceivedmult:RemoveModifier(source)
end

function Combat:RemoveDamageDealtMult(source)
	self.damagedealtmult:RemoveModifier(source)
end

function Combat:RemoveAllDamageMult(source)
	self.damagereceivedmult:RemoveModifier(source)
	self.damagedealtmult:RemoveModifier(source)
end

function Combat:SetDamageDealtBonus(source, bonus)
	self.damagedealtbonus:SetModifier(source, bonus)
end

function Combat:SetBaseDamage(source, base)
	self.basedamage:SetModifier(source, base)
end

function Combat:SetDungeonTierDamageMult(source, mult)
	self.dungeontierdamagemult:SetModifier(source, mult)
end

function Combat:RemoveDungeonTierDamageMult(source)
	self.dungeontierdamagemult:RemoveModifier(source)
end

function Combat:SetDungeonTierDamageReductionMult(source, mult)
	self.dungeontierdamagereductionmult:SetModifier(source, mult)
end

function Combat:RemoveDungeonTierDamageReductionMult(source)
	self.dungeontierdamagereductionmult:RemoveModifier(source)
end

function Combat:GetBaseDamage()
	return self.basedamage:Get()
end

function Combat:SetDamageReduction(source, reduction)
	self.damagereduction:SetModifier(source, reduction)
end

function Combat:RemoveDamageReduction(source)
	self.damagereduction:RemoveModifier(source)
end

function Combat:SetCritDamageMult(source, mult)
	self.critdamagemult:SetModifier(source, mult)
end

function Combat:RemoveCritDamageModifier(source)
	self.critdamagemult:RemoveModifier(source)
end

function Combat:GetTotalCritDamageMult()
	return self.critdamagemult:Get()
end

function Combat:SetFocusDamageMult(source, mult)
	self.focusdamagemult:SetModifier(source, mult)
end

function Combat:RemoveFocusDamageModifier(source, mult)
	self.focusdamagemult:RemoveModifier(source)
end

function Combat:GetTotalFocusDamageMult(source, mult)
	return self.focusdamagemult:Get()
end

function Combat:SetCritChanceModifier(source, base)
	local old = self.critchance:Get()
	self.critchance:SetModifier(source, base)

	self.inst:PushEvent("crit_chance_changed", { new = self.critchance:Get(), old = old })
end

function Combat:RemoveCritChanceModifier(source)
	local old = self.critchance:Get()
	self.critchance:RemoveModifier(source)

	self.inst:PushEvent("crit_chance_changed", { new = self.critchance:Get(), old = old })
end

function Combat:GetTotalCritChance()
	return self.critchance:Get()
end

function Combat:GetTarget()
	return self.target
end

function Combat:SetTarget(target)
	local oldtarget = self.target
	if target ~= oldtarget then
		if oldtarget ~= nil then
			self.inst:RemoveEventCallback("onremove", self._onremovetarget, oldtarget)
			self.inst:RemoveEventCallback("death", self._onremovetarget, oldtarget)
		end
		if target ~= nil then
			self.inst:ListenForEvent("onremove", self._onremovetarget, target)
			self.inst:ListenForEvent("death", self._onremovetarget, target)
		end
		self.target = target
		self:TryKeepTargetTracking() -- gotta stop tracking if we cleared our target
		self.inst:PushEvent("combattargetchanged", { old = oldtarget, new = target })

		-- This is causing all enemies on consequent wave spawns to peel off current target or focus individual players when online, disabled so enemies use distance targetting instead
		--[[if target and self.inst.tuning and self.inst.tuning.vision and self.inst.tuning.vision.share_target_range then
			self:ShareTarget(target,
				self.inst.tuning.vision.share_target_range,
				self.inst.tuning.vision.share_target_tags,
				self.inst.tuning.vision.share_not_target_tags)
		end]]
	end
end

-- Target tags, for enemies
function Combat:AddTargetTags(tags)
	table.appendarrays(self.targettags, tags)
end

function Combat:GetTargetTags()
	assert(#self.targettags > 0, "Target tags not set on ["..self.inst.prefab.."]. Please set target tags on the Combat component.")
	return self.targettags
end

function Combat:ClearTargetTags()
	self.targettags = {}
end

function Combat:CanTargetEntity(ent)
	for k, tag in pairs(self:GetTargetTags()) do
		if ent:HasTag(tag) then
			return true
		end
	end
	return false
end

-- Friendly target tags, for allies
function Combat:AddFriendlyTargetTags(tags)
	table.appendarrays(self.friendlytargettags, tags)
end

function Combat:GetFriendlyTargetTags()
	assert(#self.friendlytargettags > 0, "Friendly target tags not set on ["..self.inst.prefab.."]. Please set friendly target tags on the Combat component.")
	return self.friendlytargettags
end

function Combat:ClearFriendlyTargetTags()
	self.friendlytargettags = {}
end

function Combat:CanFriendlyTargetEntity(ent)
	local cantarget = false
	for k, tag in pairs(self:GetFriendlyTargetTags()) do
		if ent:HasTag(tag) then
			cantarget = true
			break
		end
	end
	return cantarget
end

----

function Combat:SuggestTarget(target)
	if self.target == nil and self.inst:IsAlive() then
		if target ~= nil and target:IsAlive() and target:IsVisible() and self:CanTargetEntity(target) then
			self:SetTarget(target)
		end
	end
end

function Combat:ShareTarget(target, range, andtags, nottags, ortags)
	local x, z = self.inst.Transform:GetWorldXZ()
	local ents = TheSim:FindEntitiesXZ(x, z, range, andtags, nottags, ortags)
	for i = 1, #ents do
		local ent = ents[i]
		if ent ~= self.inst and ent:IsAlive() and ent:IsVisible() then
			if ent.components.combat ~= nil then
				ent.components.combat:SuggestTarget(target)
			end
		end
	end
end

local function TryRetarget(inst, self)
	if inst:IsAlive() and not inst:IsInLimbo() and not inst.sg:HasStateTag("attack") then
		local target = self.retargetfn(inst)
		if target ~= nil and target:IsValid() then
			self:SetTarget(target)
		end
	end
end

function Combat:ForceRetarget()
	self:SetTarget(nil)
	TryRetarget(self.inst, self)
end

function Combat:SetRetargetFn(fn, period)
	if self.task ~= nil then
		self.task:Cancel()
		self.task = nil
	end
	self.retargetfn = fn
	if fn ~= nil then
		self.task = self.inst:DoPeriodicTask(period, TryRetarget, math.random() * period, self)
	end
end

function Combat:SetKeepTargetFn(fn)
	self.keeptargetfn = fn
	self:TryKeepTargetTracking()
end

function Combat:TryKeepTargetTracking()
	local shouldupdate = self.target ~= nil and self.keeptargetfn ~= nil
	if shouldupdate ~= self.updating_targettracking then
		self.updating_targettracking = shouldupdate
		if shouldupdate then
			self.inst:StartUpdatingComponent(self)
		elseif not self.updating_hitstreaks then
			self.inst:StopUpdatingComponent(self)
		end
	end
end

function Combat:GetLastAttacker()
	return self.lastattacker
end

function Combat:ClearLastAttacker()
	self.lastattacker = nil
end

function Combat:OnKill(data)
	local attack = data.attack
	if attack:GetFocus() then
		self:DeltaHitStreakDecay(TUNING.PLAYER.HIT_STREAK.FOCUS_KILL_BONUS)
	else
		self:DeltaHitStreakDecay(TUNING.PLAYER.HIT_STREAK.KILL_BONUS)
	end
end


function Combat:OnUpdate(dt)
	if self.updating_hitstreaks then
		self:DeltaHitStreakDecay(-dt)
	end

	if self.updating_targettracking then
		dbassert(self.target, "How did our target become nil? Use SetTarget to change target.")
		if not self.keeptargetfn(self.inst, self.target) then
			self:SetTarget(nil)
		end
	end
end

function Combat:StartCooldown(duration)
	self.cooldownstart = GetTime()
	self.cooldownend = self.cooldownstart + duration
end

function Combat:StopCooldown()
	self.cooldownend = nil
end

function Combat:IsInCooldown()
	if self.cooldownend == nil then
		return false
	elseif self.cooldownend <= GetTime() then
		self.cooldownend = nil
		return false
	end
	return true
end

function Combat:GetCooldownRemaining()
	if self.cooldownend == nil then
		return 0
	end
	local t = GetTime()
	if self.cooldownend <= t then
		self.cooldownend = nil
		return 0
	end
	return self.cooldownend - t
end

function Combat:GetCooldownElapsed()
	if self.cooldownend == nil then
		return math.huge
	end
	local t = GetTime()
	if self.cooldownend <= t then
		self.cooldownend = nil
		return math.huge
	end
	return t - self.cooldownstart
end

function Combat:SupportsHitStreak()
	return self.inst:HasTag("player")
end

function Combat:SetHitStreakDecay(val, silent)
	self:DeltaHitStreakDecay( val - self.hitstreakdecaytime, silent )
end

function Combat:DeltaHitStreakDecay(delta, silent)
	if not self:SupportsHitStreak() then
		return
	end

	self.hitstreakdecaytime = math.clamp(self.hitstreakdecaytime + delta, 0, TUNING.PLAYER.HIT_STREAK.MAX_TIME)

	if self.hitstreakdecaytime <= 0 and not silent then
		self:KillHitStreak()
	end

	if delta > 0 or self.hitstreakdecaytime == 0 then
		TheNetEvent:HitStreakDecay(self.inst.GUID, self.hitstreakdecaytime)
	end
end

function Combat:SetHitStreak(val)
	self:DeltaHitStreak( val - self.hitstreak )
end

function Combat:DeltaHitStreak(delta)
	if not self:SupportsHitStreak() then
		return
	end

	if delta >= 1 then
		-- add the delta one at a time so events that rely on stuff like "every 10th hit do this" aren't skipped.
		for i = 1, delta do
			self.hitstreak = math.max(self.hitstreak + 1, 0)
			--TheLog.ch.Combat:print("delta hit streak")
			TheNetEvent:HitStreakUpdate(self.inst.GUID, self.hitstreak, self.hitstreakdamagetotal)
		end
	else
		self.hitstreak = math.max(self.hitstreak + delta, 0)
		--TheLog.ch.Combat:print("delta hit streak")
		TheNetEvent:HitStreakUpdate(self.inst.GUID, self.hitstreak, self.hitstreakdamagetotal)
	end
end

function Combat:AddHitStreak(attack)
	if not self:SupportsHitStreak() then
		return
	end

	self.hitstreakdamagetotal = self.hitstreakdamagetotal + attack:GetDamage()
	table.insert(self.hitstreakattackids, attack:GetNameID())
	self:DeltaHitStreak(1)

	-- If the hitstreak has decayed at all already, then set it to the max amount of decay
	if self.hitstreakdecaytime < TUNING.PLAYER.HIT_STREAK.BASE_DECAY then
		self:SetHitStreakDecay(TUNING.PLAYER.HIT_STREAK.BASE_DECAY)
	end

	if not self.updating_hitstreaks then
		self.updating_hitstreaks = true
		self.inst:StartUpdatingComponent(self)
	end
end

function Combat:KillHitStreak()
	if not self:SupportsHitStreak() then
		return
	end

	local current_streak = self.hitstreak
	if current_streak > 0 then

		self:SetHitStreak(0)
		self:SetHitStreakDecay(0, true)

		-- Push the event
		-- attack ids are pulled locally in network event handler
		TheNetEvent:HitStreakKilled(self.inst.GUID, current_streak, self.hitstreakdamagetotal) --, self.hitstreakattackids)

		-- Reset everything
		self.hitstreakdamagetotal = 0
		lume.clear(self.hitstreakattackids)

		-- Stop updating if we shouldn't be.
		self.updating_hitstreaks = false
		if not self.updating_targettracking then
			self.inst:StopUpdatingComponent(self)
		end
	end
end

function Combat:GetHitStreakDecay()
	return self.hitstreakdecaytime
end

function Combat:GetHitStreak()
	return self.hitstreak
end

function Combat:GetHitStreakAttackIDs()
	return self.hitstreakattackids
end

function Combat:CheckDamageChain(data, source)
	source = source or data.source
	return data.chain and table.contains(data.chain, source)
end

function Combat:AddToDamageChain(data, source)
	source = source or data.source
	if not data.chain then data.chain = {} end
	table.insert(data.chain, source)
end

-- Calculates the damage to apply to the target taking into account damage reduction & damage received multiplier.
-- (damage - damage reduction) * damage received multiplier
function Combat:CalculateProcessedDamage(attack)
	TheLog.ch.CombatSpam:printf("CalculateProcessedDamage")
	TheLog.ch.CombatSpam:indent()

	local damage = attack:GetDamage()

	if attack:GetIgnoresArmour() then
		TheLog.ch.CombatSpam:printf("attack ignores armour")
	else
		local previous_damage = damage

		local attacker = attack:GetAttacker().components.combat
		local dungeon_tier_damage_mult = attacker.dungeontierdamagemult:Get() - self.dungeontierdamagereductionmult:Get()
		TheLog.ch.CombatSpam:printf(
			"attacker.dungeontierdamagemult - defender.dungeontierdamagereductionmult = %.2f - %.2f = X %.2f",
			attacker.dungeontierdamagemult:Get(),
			self.dungeontierdamagereductionmult:Get(),
			dungeon_tier_damage_mult
		)
		damage = damage * dungeon_tier_damage_mult

		local damage_reduction = self.damagereduction:Get()
		TheLog.ch.CombatSpam:printf("damage_reduction %.2f", damage_reduction)
		-- Damage reduction will never reduce damage to less than 1.
		-- However, attacks that deal non-positive damage are NOT increased to 1.
		damage = damage <= 0
			and 0
			or math.max(damage - damage_reduction, 1)
		damage = damage * self.damagereceivedmult:Get()

		TheLog.ch.CombatSpam:printf("changed damage from %.2f to %.2f", previous_damage, damage)
	end

	TheLog.ch.CombatSpam:unindent()
	return lume.round(damage)
end

function Combat:TakeDamage(attack)
	TheLog.ch.CombatSpam:printf("TakeDamage")
	TheLog.ch.CombatSpam:indent()
	if self.godmode then
		local previous_damage = attack:GetDamage()
		attack:SetDamage(0)
		TheLog.ch.CombatSpam:printf("godmode reduced damage from %.2f to %.2f", previous_damage, attack:GetDamage())
	end

	local damage_bonus = self.inst.components.damagebonus
	if damage_bonus then
		local previous_damage = attack:GetDamage()
		damage_bonus:ModifyAttackAsDefender(attack)
		TheLog.ch.CombatSpam:printf("ModifyAttackAsDefender changed damage from %.2f to %.2f", previous_damage, attack:GetDamage())
	end

	local previous_damage = attack:GetDamage()
	local damage = self:CalculateProcessedDamage(attack)
	attack:SetDamage(damage)
	TheLog.ch.CombatSpam:printf("CalculateProcessedDamage changed damage from %.2f to %.2f", previous_damage, attack:GetDamage())

	local attacker = attack:GetAttacker()
	if attacker.components.dpstracker ~= nil then
		attacker.components.dpstracker:LogDamage(attack:GetDamage())
	end

	self:KillHitStreak()

	if self.inst.components.health then
		if attack:GetTarget():IsValid() and attack:ShowDamageNumber() then
			if TheDungeon.HUD then
				TheDungeon.HUD:MakeDamageNumber(attack)
			end
		end
		attacker:PushEvent("do_damage", attack)
		attack:GetTarget():PushEvent("take_damage", attack)

		self.inst.components.health:GetAttacked(attack)
	end

	self.lastattacker = attacker

	TheLog.ch.CombatSpam:unindent()
end

function Combat:GetHealed(heal)
	if self.inst.components.health and self.inst.components.health:IsHealable() then
		heal:SetHeal(lume.round(heal:GetHeal()))
		local amount = 0

		heal:GetAttacker():PushEvent("do_heal", heal)
		heal:GetTarget():PushEvent("take_heal", heal)
		amount = heal:GetTarget().components.health:DoDelta(heal:GetHeal(), false, heal)

		--For display purposes, re-configure the heal to only show the delta
		if amount > 0 then
			heal:SetHeal(lume.round(amount))

			if heal:GetTarget():IsValid() and heal:ShowDamageNumber() then
				TheDungeon.HUD:MakeDamageNumber(heal)
			end
			self:PlayHealFx(heal:GetTarget(), heal)
		end

		if self.inst.components.lucky and self.inst.components.lucky:DoLuckRoll() and not heal:SourceIsLuck() then
			--sound
			local params = {}
			params.fmodevent = fmodtable.Event.lucky
			params.sound_max_count = 1
			soundutil.PlaySoundData(self.inst, params)

			self.inst:DoTaskInTime(1, function()
				local lucky_heal = Attack(self.inst, self.inst)
				lucky_heal:SetHeal( math.ceil(amount * 0.33) )
				lucky_heal:SetSource("luck")
				self.inst.components.combat:ApplyHeal(lucky_heal)
				self.inst.components.hitstopper:PushHitStop(1)
			end)
		end
	end
end

local healamount_to_particleamount =
{
	-- heal amount, particle count multiplier
	{0,		0},
	{1,		0.1},
	{100, 	1.5},
	{500, 	2},
	{1000, 	3},
}

local healamount_to_particlescale =
{
	-- heal amount, particle count multiplier
	{0,		0},
	{1,		0.4},
	{10,	0.5},
	{50,	0.75},
	{100, 	1},
}

local healamount_to_x_spread =
{
	-- heal amount, particle count multiplier
	{100,	1},
	{1000, 	1.75},
}

--TRY: increase velocity in -X, X and Y
--TRY: tint player based on heal amount
--TRY: see if we can spawn this on a symbol
--TRY: velocity transference (take player X velocity and add half of that to the velo of the emitter)

function Combat:PlayHealFx(ent, heal)
	-- if self.healfx ~= nil then
	-- 	-- Optimize
	-- 	self.healfx.components.particlesystem:Stop()
	-- end

	local amount = PiecewiseFn(heal:GetHeal(), healamount_to_particleamount)
	local scale = PiecewiseFn(heal:GetHeal(), healamount_to_particlescale)

	local emitter_params =
	{
		{
			-- Leaves: 1
			amount_mult = amount,
			scale_mult = scale,
		},
		{
			-- Other: 2
			amount_mult = amount,
			scale_mult = scale,
		},
		{
			-- Blips: 3
			amount_mult = amount,
			scale_mult = scale,
		},
	}

	local location = self.inst:GetPosition()
	location.z = location.z - 1
	local fx = ParticleSystemHelper.MakeOneShotAtPosition(location, "healing_procedural", 0.1, ent, emitter_params)

	soundutil.PlaySoundWithParams(self.inst, fmodtable.Event.fx_heal_burst, { healAmount = scale })
end

function Combat:RollCritChance(attack)
	if attack:GetForceCriticalHit() then
		attack:SetCrit(true)
	else
		-- Actually roll for it
		if math.random() < attack:GetTotalCritChance() then
			attack:SetCrit(true)
		end

		if attack:GetAttacker() == attack:GetTarget() then
			attack:SetCrit(false)
		end
	end
end

function Combat:ApplyCritModifier(attack)
	attack:SetDamage(math.ceil(attack:GetDamage() * attack:GetTotalCritDamageMult()))
	attack:SetPushback(math.ceil(attack:GetPushback() * TUNING.CRIT_PUSHBACK_MULT))
end

function DoNetEventApplyDamage(attack, event)
	local target = attack:GetTarget()
	if not target then
		return
	end
	if not target.components.combat then
		return
	end

	local was_alive = not target:IsDead()
	target.components.combat:TakeDamage(attack)
	local death = was_alive and target:IsDead()
	local attacker = attack:GetAttacker()

	if event and target ~= attacker then
		local front = attacker.components.combat:CalculateFront(target, 135, 90)
		target:PushEvent(event, {
			attack = attack,
			death = death,
			front = front or nil,
		})
	end

	if death and target:IsLocal() then
		-- If this was a remote attacker killing a local network-entity, send a net message to the attacker
		if not attacker:IsLocal() and target:IsNetworked() then
			TheNetEvent:Kill(attacker.GUID, target.GUID, attack)
		else
			DoNetEventKill(attack);	-- Just send it straight through if this was a local attacker and a local target
		end
	end
end

function DoNetEventKill(attack)
	local attacker = attack:GetAttacker()
	if attacker:IsLocal() then
		local data = { attack = attack }
		-- Removed victim, as it can just be queried from attack:GetTarget()
		-- Removed focus = attack:GetFocus(), as it can just be queried from attack:GetFocus()

		attacker:PushEvent("kill", data)
	end
end

function SendAttackOverNetwork(attack, event)
	local attacker = attack:GetAttacker()
	local target = attack:GetTarget()

	if attacker:IsMinimal() then 
		-- Minimal entities can ONLY attack local entities. They don't take control of remote entities.
		-- This is to fix a bug where minimal traps would trigger on all machines, and then hurt enemies multiple times over the network. 
		if target:IsLocal() then
			DoNetEventApplyDamage(attack, event)
			SGCommon.Fns.ApplyHitConfirmEffects(attack)
		end
	else
		--print("attacker = " .. attacker.prefab)

		-- Aggressively try to take control of the target. This will only work if the target is remote AND has a "shared" networktype.
		-- If the take control action is successful, the target will be local from this point on.
		if attack:GetProjectile()
			and (attack:GetProjectileLauncher()
				and attack:GetProjectileLauncher():IsLocal()
				and attack:GetProjectileLauncher():HasTag("player"))
			and target:CanTakeControl(attack) then
			-- take control of targets hit with someone else's (shotput) projectile for improved responsiveness
			target:TakeControl()
		elseif attacker:IsLocal() and attacker:HasTag("player") and target:CanTakeControl(attack) then
			target:TakeControl()
		end

		-- Only send over the network if the attacker is local:
		if not attack._keep_it_local then
			--print("Applying damage from ".. attacker.prefab .." to " .. target.prefab)
			TheNetEvent:ApplyDamage(attacker.GUID, target.GUID, attack, event)
		else
			DoNetEventApplyDamage(attack, event)
		end
	end
end


function Combat:ApplyDamage(attack, event)
	local target = attack:GetTarget()
	local attacker = attack:GetAttacker()

	local attacker_bonus = attacker.components.damagebonus

	if attacker_bonus then
		attacker_bonus:ModifyAttackAsAttacker(attack)
	end

	self:RollCritChance(attack)

	if attack:GetCrit() then
		self:ApplyCritModifier(attack)
	end

	-- uncomment this if you want to see how attack chains accumulate
	-- TheLog.ch.Combat:printf("Dump Attack Chain pre-network")
	-- attack:DebugDumpAttackChain()
	SendAttackOverNetwork(attack, event)

	self:PostApplyDamage(attack)
end

function Combat:PostApplyDamage(attack)
	local target = attack:GetTarget()
	local attacker = attack:GetAttacker()

	-- Now that the attacker has modified its own attack and sent it so the Defender can run its half of the code,
	-- For hitstreaks, to determine whether or not we just did damage, run the Defender version of the code locally to base our decision on.

	-- NOTE: This will run the ENTIRE damage_mod_fn that exists on the target. If that damage_mod_fn does anything other than modify the attack, then that may proc multiple times because of this.
	-- For example, if Retaliation was done in damage_mod_fn, to spawn a new attack then that code would run multiple times.
	-- For example, Shield doesn't actually break the shield in damage_mod_fn, just detects that it has broken and sets up the break itself inside take_damage, with the modified Attack.
	local _dummy_attack = attack
	local defender_bonus = target.components.damagebonus
	if defender_bonus and target ~= attacker then
		defender_bonus:ModifyAttackAsDefender(_dummy_attack)
	end

	if _dummy_attack:GetDamage() > 0 then
		attacker.components.combat:AddHitStreak(_dummy_attack)
	end
end

function SendHealOverNetwork(heal)
	local target = heal:GetTarget()
	local attacker = heal:GetAttacker()

	-- Only send over the network if the attacker is local and the target is remote:
	if attacker:IsLocal() and not target:IsLocal() then
		TheNetEvent:ApplyHeal(attacker.GUID, target.GUID, heal)
	else
		if target and target.components.combat then
			target.components.combat:GetHealed(heal)
		end
	end
end

function Combat:ApplyHeal(heal)
	if not heal:GetHeal() or heal:GetHeal() <= 0 then return end

	local target = heal:GetTarget()
	local healer = heal:GetAttacker()

	local bonus = healer.components.damagebonus
	if bonus then
		bonus:ModifyHeal(heal)
	end

	bonus = target.components.damagebonus
	if bonus and target ~= healer then
		bonus:ModifyHeal(heal)
	end

	SendHealOverNetwork(heal)
end

function Combat:ApplyReviveDamage(damage)
	SendHealOverNetwork(damage)
end

-- returns true if this attack should be ignored
-- ideally this would read from a global var for PVP mode
function Combat:ApplyPVPModifiers(attack)
	local target = attack:GetTarget()
	local attacker = attack:GetAttacker()
	if target ~= attacker and target:HasTag("player") and attacker:HasTag("player") then
		if self.pvpmode == PVPMODE_DISABLED then
			return true
		elseif self.pvpmode == PVPMODE_HIT_REACTIONS_ONLY then
			attack:SetDamageMod(0)
			attack:SetDamage(0)
		end
	end

	return false
end

function Combat:DoPowerAttack(attack)
	if self:ApplyPVPModifiers(attack) then
		return
	end

	local target = attack:GetTarget()
	if target.components.hitflagmanager and not target.components.hitflagmanager:CanAttackHit(attack) then
		return false
	end

	self:ApplyDamage(attack, "attacked")

	-- Apply hitstop to targets if they die.
	if target:IsDying() then
		local hitstoplevel = HitStopLevel.KILL
		if target:HasTag("player") then
			hitstoplevel = HitStopLevel.PLAYERKILL
		elseif target:HasTag("miniboss") then
			hitstoplevel = HitStopLevel.MINIBOSSKILL
		elseif target:HasTag("boss") then
			hitstoplevel = HitStopLevel.BOSSKILL
		end
		SGCommon.Fns.ApplyHitstop(attack, hitstoplevel)
	end

	return true
end

function Combat:DoBasicAttack(attack)
	--target, attack_damage_mod, dir, hitstun, pushback, focus
	if self:ApplyPVPModifiers(attack) then
		return
	end

	local target = attack:GetTarget()
	if target.components.hitflagmanager and not target.components.hitflagmanager:CanAttackHit(attack) then
		return false
	end

	self:DoBasicAttackInternal(attack)

	return true
end

function Combat:CalculateFront(target, angle1, angle2)
	if self.inst:IsValid() and target:IsValid() then
		local dirtotarget = self.inst:GetAngleTo(target)
		local targetfacingdir = target.Transform:GetFacingRotation()
		local diff = DiffAngle(targetfacingdir, dirtotarget)
		return diff > angle1 or (diff > angle2 and targetfacingdir == self.inst.Transform:GetFacingRotation())
	else
		return true -- default to hitting from the front if the target isn't around
	end
end

function Combat:DoBasicAttackInternal(attack)
	-- target, damage_mod, dir, knocked, hitstun, pushback, focus
	local target = attack:GetTarget()

	local MODIFIER_SOURCE = "DoBasicAttackInternal"
	if target.sg ~= nil then
		if target.sg:HasStateTag("knockdown") then
			if target.components.combat ~= nil and target.components.combat.hasknockdownhits and target.components.combat.hasknockdownhitdir then
				local front = self:CalculateFront(target, 135, 90)
				self.damagedealtmult:SetModifier(MODIFIER_SOURCE, front and DOWN_FRONT_MULT or DOWN_BACK_MULT)
			end
		elseif target.sg:HasStateTag("block") then
			if target.components.combat ~= nil and target.components.combat.hasblockdir then
				local front = self:CalculateFront(target, 100, 50)
				self.damagedealtmult:SetModifier(MODIFIER_SOURCE, front and BLOCK_FRONT_MULT or BLOCK_BACK_MULT)
			else
				self.damagedealtmult:SetModifier(MODIFIER_SOURCE, BLOCK_FRONT_MULT)
			end
		else
			-- Front can be used here to determine which 'hit' anim the target should use
			local _front = self:CalculateFront(target, 100, 90)
		end
	end

	if not attack:GetDir() then
		attack:SetDir(self.inst:GetAngleTo(target))
	end

	attack:InitDamageAmount(self.damagedealtmult:Get())

	self:ApplyDamage(attack, "attacked")

	self.damagedealtmult:RemoveModifier(MODIFIER_SOURCE)
end

function Combat:DoLoudAttack(attack)
	-- target, attack_damage_mod, dir, speedmult, hitstun, focus
	local target = attack:GetTarget()
	if target.components.hitflagmanager and not target.components.hitflagmanager:CanAttackHit(attack) then
		return false
	end
	if target.sg ~= nil then
		if target.sg:HasStateTag("airborne") then
			attack:SetIsKnockdown(true)
		else
			attack:SetDamageMod(0)
		end
	end

	if self:ApplyPVPModifiers(attack) then
		return
	end

	self:DoKnockingAttackInternal(attack)

	return true
end

function Combat:DoKnockbackAttack(attack)
	if self:ApplyPVPModifiers(attack) then
		return
	end

	local target = attack:GetTarget()
	if target.components.hitflagmanager and not target.components.hitflagmanager:CanAttackHit(attack) then
		return false
	end

	--target, attack_damage_mod, dir, speedmult, hitstun, focus
	if target.sg ~= nil then
		--Knockback attacks result in knockdown in certain states
		if target.sg:HasStateTag("airborne") or target.sg:HasStateTag("knockdown") then
			if target.components.combat ~= nil then
				if target.sg:HasStateTag("knockback_becomes_hit") then
					-- If their state wants to turn this into a normal hit, then do so. For example, being hit while in the knockdown state.
					attack:SetIsKnockdown(false)
					attack:SetKnocked(false)
					self:DoBasicAttackInternal(attack)
					return
				else
					-- Otherwise, knockdown!
					attack:SetIsKnockdown(true)
				end
			end
		end
	end
	self:DoKnockingAttackInternal(attack)

	return true
end

function Combat:DoKnockdownAttack(attack)
	if self:ApplyPVPModifiers(attack) then
		return
	end

	local target = attack:GetTarget()
	if target.components.hitflagmanager and not target.components.hitflagmanager:CanAttackHit(attack) then
		return false
	end

	-- target, attack_damage_mod, dir, speedmult, hitstun, focus
	attack:SetIsKnockdown(true)
	self:DoKnockingAttackInternal(attack)

	return true
end

Combat.LoggingEnabled = false
function Combat:Log(...)
	if Combat.LoggingEnabled then
		printf(...)
	end
end

function Combat:DoKnockingAttackInternal(attack)
	-- target, attack_damage_mod, dir, speedmult, isknockdown, hitstun, focus
	local hasknockback = false
	local hasknockdown = false
	local hasknockdownhits = false
	local frontknockbackonly = false
	local vulnerableknockdownonly = false
	local blockknockback = false
	local hasblockdir = false
	local target = attack:GetTarget()
	local target_combat = target.components.combat

	if target_combat ~= nil then
		hasknockback = target_combat.hasknockback -- does your target have knockback states?
		hasknockdown = target_combat.hasknockdown -- does your target have knockdown states?
		hasknockdownhits = target_combat.hasknockdownhits -- does your target have hit states while in the knockdown state?
		frontknockbackonly = target_combat.frontknockbackonly -- can your target only be knocked back when hit from the front?
		vulnerableknockdownonly = target_combat.vulnerableknockdownonly -- can your target only be knocked down when in a state with the "vulnerable" tag?
		blockknockback = target_combat.blockknockback -- can your target block knockback attacks?
		hasblockdir = target_combat.hasblockdir -- does the direction your attack is coming from matter for the target's blocking attempts?
	end

	local blocking = false

	local DEBUGPRINT = false -- set to True to print out results of all these IF checks
	self:Log("DoKnockingAttackInternal")

	if not (hasknockback or (attack:IsKnockdown() and hasknockdown)) then
		-- if your target does not have knockback states OR if your attack is supposed to knockdown but your target does not have knockdown states
		-- do a "knocked" attack
		attack:SetKnocked(true)
		return self:DoBasicAttackInternal(attack)
	elseif target.sg ~= nil then
		if target.sg:HasStateTag("knockdown") then
			-- if your target is currently knocked down
			self:Log("target.sg:HasStateTag(\"knockdown\")")
			if hasknockdownhits then -- it is important to note that the player does NOT have knockdown hits
				-- and your target has hit states while in the knockdown state
				-- do a "knocked" attack
				self:Log("hasknockdownhits")

				attack:SetKnocked(true)
				return self:DoBasicAttackInternal(attack)
			end
		elseif target.sg:HasStateTag("block") then
			self:Log("target.sg:HasStateTag(\"block\")")

			-- if your target is currently blocking
			if not hasknockback or (blockknockback and not hasblockdir) then
				-- and your target does not have knockback states OR your target can block knockback attacks and can block attacks from all directions
				-- do a "knocked" attack
				self:Log("not hasknockback or (blockknockback and not hasblockdir)")
				attack:SetKnocked(true)
				return self:DoBasicAttackInternal(attack)
			end
			-- if you got past the last check, your target either does have knockback states, or they can block knockback attacks but the direction of the attack matters
			-- convert all knockdowns to just knockback when blocking
			attack:SetIsKnockdown(false)
			-- can your target block knockback attacks?
			blocking = blockknockback
		elseif target.sg:HasStateTag("dormant") then
			self:Log("target.sg:HasStateTag(\"dormant\")")

			attack:SetKnocked(true)
			return self:DoBasicAttackInternal(attack)
		end
	end

	local front, dirtotarget

	if frontknockbackonly or (blocking and hasblockdir) then
		self:Log("frontknockbackonly or (blocking and hasblockdir)")

		-- determine which direction you are attacking your target from if your target has logic that makes it matter.
		local targetfacingdir = target.Transform:GetFacingRotation()
		if attack:GetDir() == nil or DiffAngle(targetfacingdir, attack:GetDir()) > 120 then
			dirtotarget = self.inst:GetAngleTo(target)
			front = DiffAngle(targetfacingdir, dirtotarget) > 135
		end
	end

	if not attack:GetDir() then
		self:Log("no attack dir")

		attack:SetDir(dirtotarget or self.inst:GetAngleTo(target))
	end

	local event

	attack:SetKnocked(true)

	local attacked_data =
	{
		attack = attack,
		front = front,
		death = false,
	}

	local DamageDealtModifierSource = Enum {"Front", "Vulnerable", "Block"}
	if blocking and (front or not hasblockdir) then
		-- if your target is blocking and you're hitting them from the front or they can block from all directions
		self.damagedealtmult:SetModifier(MODIFIER_SOURCE, BLOCK_FRONT_MULT) -- reduce the damage
		event = "attacked"  -- send a normal "attacked" event
		attacked_data.front = front -- pass in if you're hitting from the front
	else
		local knocked = false
		if not frontknockbackonly then
			self:Log("not frontknockbackonly")
			-- if your target can be knocked back from all directions
			knocked = true -- set knocked to true
		elseif front then
			self:Log("front")
			-- or if your target can only be knocked back from the front & you're hitting them from the front
			knocked = true -- set knocked to true
			self.damagedealtmult:SetModifier(DamageDealtModifierSource.s.Front, KNOCKBACK_FRONT_MULT) -- increase damage
		end
		if knocked or attack:IsForceKnockdown() then
			self:Log("knocked or attack:IsForceKnockdown() [knocked: %s -- attack:IsForceKnockdown(): %s]", knocked, attack:IsForceKnockdown())

			-- if your target can be knocked back, and your attack is supposed to knock back
			if not hasknockdown or (target.components.weight and target.components.weight:IsHeavy()) then
				self:Log("not hasknockdown [%s] or weight:IsHeavy() [%s]", not hasknockdown, (target.components.weight and target.components.weight:IsHeavy()))
				-- if your target can't be knocked down, do not knock down (regardless of if your attack was going to knockdown or not)
				attack:SetIsKnockdown(false)
			elseif attack:IsForceKnockdown() then
				self:Log("attack:IsForceKnockdown()")
				attack:SetIsKnockdown(true)
			elseif attack:IsKnockdown() and vulnerableknockdownonly then
				self:Log("attack:IsKnockdown() and vulnerableknockdownonly")
				-- if your attack is supposed to knockdown, but your target can only be knocked down when they are in a "vulnerable" state
				if target.sg ~= nil and target.sg:HasStateTag("vulnerable") then
					self:Log("target.sg ~= nil and target.sg:HasStateTag(\"vulnerable\")")
					-- your target is vulnerable, increase the damage and maintain the knockdown = true
					self.damagedealtmult:SetModifier(DamageDealtModifierSource.s.Vulnerable, KNOCKBACK_VULNERABLE_MULT)
				else
					self:Log("not vulnerable, cancel knockdown")
					-- your target was not vulnerable, so do not knockdown
					attack:SetIsKnockdown(false)
				end
			elseif target.sg ~= nil and target.sg:HasStateTag("knockback_becomes_knockdown") then
				self:Log("target.sg:HasStateTag(\"knockback_becomes_knockdown\")")

				-- this is a KnockBACK hit, but is landing at a vulnerable time when any knockback hits should be turned into knockDOWN hits.
				-- feels like this should be in the "vulnerable" tag above, but 'isknockdown' is not always true
				attack:SetIsKnockdown(true)
			end

			-- At this point we have determined if we are a knockdown hit or not. Set up the final event.
			if attack:IsKnockdown() then
				self:Log("attack:IsKnockdown()")

				-- your attack is supposed to knock the target down, and your target can be knocked down, so do it.
				event = "knockdown"
				attack:SetKnockdownDuration(self:GetKnockdownDuration())
			elseif hasknockback then
				self:Log("hasknockback")

				-- your attack is supposed to knock the target back, and your target can be knocked back, so do it.
				event = "knockback"
			else
				self:Log("attacked")

				-- your attack is not supposed to knock down or knock back, so just do a normal attack.
				for source, _ in pairs(DamageDealtModifierSource:Ordered()) do
					self.damagedealtmult:RemoveModifier(source)
				end
				event = "attacked"
			end
		else
			self:Log("no knockback or knockdown, normal attack")

			-- your target could not be knocked back (or knocked down), so just do a normal attack
			event = "attacked"
		end

		if blocking and event == "attacked" then
			-- if your target is blocking & you're doing a normal attack
			local block_mult = hasblockdir
				-- the direction you're hitting your target from matters, and it's not from the front (since we checked for that already), so do the "back" block modifier
				and BLOCK_BACK_MULT
				-- your target is blocking and can block from all directions, so reduce damage with the front modifier
				or BLOCK_FRONT_MULT
			self.damagedealtmult:SetModifier(DamageDealtModifierSource.s.Block, block_mult)
		end
	end

	self:Log("event:", event)

	attack:InitDamageAmount(self.damagedealtmult:Get())
	self:ApplyDamage(attack, event) -- PushEvent("knockdown PushEvent("knockback PushEvent("attacked"
	for source, _ in pairs(DamageDealtModifierSource:Ordered()) do
		self.damagedealtmult:RemoveModifier(source)
	end
end

function Combat:GetKnockdownDuration()
	return self.knockdownduration + (math.random() * 0.33)
end

function Combat:GetKnockdownLengthModifier(modifier)
	return self.knockdownlengthmodifier
end

function Combat:SpawnHitFxForPlayerAttack(attack, base_fx, victim, source, hitfx_x_offset, hitfx_y_offset, dir, hitstoplevel, matchfacing)
	local fxtbl = {}
	if victim.sg ~= nil and victim.sg:HasStateTag("block") then
		fxtbl.block = SpawnHitFx("hits_player_block", source, victim, hitfx_x_offset, hitfx_y_offset, dir, hitstoplevel)
	else
		local fx = base_fx
		if attack:GetFocus() then
			fx = base_fx .."_focus"
		end

		-- TODO: get the attack's pushback value, and get the victim's resistance to pushback. modify X offset of the FX based on those two
		fxtbl.fx = SpawnHitFx(fx, source, victim, hitfx_x_offset, hitfx_y_offset, dir, hitstoplevel)
		--~ TheLog.ch.Combat:print("SpawnHitFxForPlayerAttack", fx)
		-- Crit is an extra layer on top of base fx.
		if attack:GetCrit() then
			fx = base_fx .."_crit"
			fxtbl.crit = SpawnHitFx(fx, source, victim, hitfx_x_offset, hitfx_y_offset, dir, hitstoplevel)
		end
		if victim.components.combat.damagereceivedmult:Get() < .5 then
			--sound
			local normalized_damage_received_mult = victim.components.combat.damagereceivedmult:Get() * 2 -- FMOD param is 0 to 1 but we don't want to always trigger these blocking sounds so
			local params = {}
			params.fmodevent = fmodtable.Event.Hit_reduced
			params.sound_max_count = 1
			local handle = soundutil.PlaySoundData(source, params)
			soundutil.SetInstanceParameter(source, handle, "damage_received_mult", normalized_damage_received_mult)
		end
	end
	return fxtbl
end

function Combat:DebugDrawEntity(ui, panel, colors)
	local target = self.inst.components.combat:GetTarget()
	ui:Text("Target:")
	ui:SameLineWithSpace()
	if ui:Button(tostring(target)) then
		panel:PushDebugValue( target )
	end
	ui:Value("cooldown", self.inst.components.combat:GetCooldownRemaining())

	if not self.inst.tuning then
		ui:Text("No tuning")
		return
	end

	local vision = self.inst.tuning.vision
	if vision then
		ui:TextColored(colors.header, "Vision radius")
		local x,z = self.inst.Transform:GetWorldXZ()

		local function tunable_range(name, color)
			if not vision[name] then
				ui:TextColored(UICOLORS.GREY, name .." not supported")
				return
			end
			ui:ColorButton(name, color)
			ui:SameLineWithSpace()
			vision[name] = ui:_SliderFloat(name.."##slider", vision[name], 0.5, 30)
			DebugDraw.GroundCircle(x, z, vision[name], color)
		end

		tunable_range("aggro_range", WEBCOLORS.GREEN)
		tunable_range("too_far_retarget", WEBCOLORS.RED)
		tunable_range("share_target_range", WEBCOLORS.MEDIUMPURPLE)
	end
end

function Combat:GetDebugString()
	return string.format("target=[%s], cooldown=%.2f", tostring(self.target), self:GetCooldownRemaining())
end


function Combat:AddDamageNumber(damagenumber)
	self.damagenumbers[damagenumber] = true
end
function Combat:RemoveDamageNumber(damagenumber)
	self.damagenumbers[damagenumber] = nil
end
function Combat:GetDamageNumbers()
	return self.damagenumbers
end
function Combat:GetDamageNumbersCount()
	local count = 0
	for k,v in pairs(self.damagenumbers) do
		count = count + 1
	end
	return count
end

return Combat
