local InstanceLog = require "util.instancelog"
local lume = require "util.lume"

local AttackTracker = Class(function(self, inst)
	self.inst = inst
	self.active_attack = nil
	self.attack_data = {}

	self:UpdateModifiers() -- Do this now, but also allow it being triggered manually later because tags are added after this component gets initialized.

	self.force_attack = nil
	self.last_attack_priority = nil
	self.remaining_best_priority_attacks = {}

	self._on_attack_interrupted_fn = function()
		if self.active_attack then
			self:OnAttackInterrupted()
		end
	end
end)

function AttackTracker:AddAttack(attack_id, data)
	local new_attack =
	{
		id = attack_id,
		timer_id = nil,
		damage_mod = data.damage_mod or 1,
		startup_frames = data.startup_frames and data.startup_frames or 0,
		startup_frames_remaining = data.startup_frames and data.startup_frames or 0,
		cooldown = data.cooldown or 0,
		is_hitstun_pressure_attack = data.is_hitstun_pressure_attack or false,
		pre_anim = data.pre_anim,
		hold_anim = data.hold_anim,
		has_hold = data.hold_anim ~= nil,
		loop_hold_anim = data.loop_hold_anim or false,
		attack_state_override = data.attack_state_override or nil,
		min_startup_frames = data.min_startup_frames and data.min_startup_frames or 0,
		-- TODO(dbriscoe): Is it valid to have no start_conditions_fn? We'll never start this attack.
		start_conditions_fn = data.start_conditions_fn or nil,
		priority = data.priority or 0, -- higher priority goes first
		--max_interrupts = data.max_interrupts or math.huge,
		--num_interrupts = 0,
		targetrange = data.targetrange
			and (data.targetrange.centered
				and data.targetrange.base + SteppedRandomRangeCentered(data.targetrange.steps, data.targetrange.scale)
				or data.targetrange.base + SteppedRandomRange(data.targetrange.steps, data.targetrange.scale))
			or nil,
		max_attacks_per_target = data.max_attacks_per_target or 0,
		retry_cooldown = data.retry_cooldown_range
			and (data.retry_cooldown_range.centered
				and data.retry_cooldown_range.base + SteppedRandomRangeCentered(data.retry_cooldown_range.steps, data.retry_cooldown_range.scale)
				or data.retry_cooldown_range.base + SteppedRandomRange(data.retry_cooldown_range.steps, data.retry_cooldown_range.scale))
			or 0,
		type = data.type or "",
	}

	if self.inst.components.timer and (data.initialCooldown or data.cooldown) then
		new_attack.timer_id = attack_id.."_cd"
		local initialCooldown = data.initialCooldown or data.cooldown
		initialCooldown = initialCooldown * self.initial_cooldown_mod

		self.inst.components.timer:StartPausedTimer(new_attack.timer_id, data.initialCooldown or data.cooldown)
	end

	self.attack_data[attack_id] = new_attack
end

function AttackTracker:OnAttackInterrupted()
	if self.force_attack then
		return
	end

	--[[self.active_attack.num_interrupts = self.active_attack.num_interrupts + 1

	if self.active_attack.num_interrupts >= self.active_attack.max_interrupts then
		self:CancelActiveAttack()
	else]]
		-- If the attack was interrupted too much, set the state to force its next attack, i.e make it uninterruptable.
		local remaining_startup_frames = self:GetRemainingStartupFrames()
		if remaining_startup_frames <= 0 then
			self.force_attack = true
			self.active_attack.startup_frames_remaining = self.active_attack.startup_frames -- Also need to reset startup frames
		end
	--end
end

function AttackTracker:AddAttacks(attacks)
	for id, data in pairs(attacks) do
		self:AddAttack(id, data)
	end
end

function AttackTracker:StartActiveAttack(attack_id)
	if self.active_attack then
		if self:IsAttackActive(attack_id) then
			return
		else
			print(string.format("ERROR: Tried to start new attack (%s) when an activeAttack is already set (%s)!", attack_id, self.active_attack.id))
		end
	end

	if self.attack_data[attack_id] then
		self.active_attack = self.attack_data[attack_id]
		self.active_attack.startup_frames_remaining = self.active_attack.startup_frames
		--self.active_attack.num_interrupts = 0
		self.inst:ListenForEvent("attack_interrupted", self._on_attack_interrupted_fn)
		self:Logf("Start: '%s'", attack_id)
	else
		print(string.format("ERROR: Tried to start an attack that has no data! (%s)", attack_id))
	end
end

function AttackTracker:CancelActiveAttack()
	self:Logf("Cancel: '%s'", self.active_attack and self.active_attack.id)
	self.inst:RemoveEventCallback("attack_interrupted", self._on_attack_interrupted_fn)
	self.active_attack = nil
	self.force_attack = nil
end

function AttackTracker:CompleteActiveAttack()
	self:Logf("Complete: '%s'", self.active_attack and self.active_attack.id)
	--print(string.format("Completed attack %s", self.active_attack.id))
	-- once you successfully do the attack we don't need to track this attack anymore
	self.inst:PushEvent("completeactiveattack")

	-- Apply minimum_cooldown_mod to minimum_cooldown just-in-time (as opposed to at construction time) to permit state 
	-- graph code to set minimum_cooldown dynamically as it sees fit.
	local minimum_cooldown = self.minimum_cooldown * self.minimum_cooldown_mod
	self.inst.components.combat:StartCooldown(minimum_cooldown * self.cooldown_mod)

	if self.inst.components.timer and self.active_attack then
		self.inst.components.timer:StartTimer(self.active_attack.timer_id, self.active_attack.cooldown * self.cooldown_mod, true)
	end
	self.inst:RemoveEventCallback("attack_interrupted", self._on_attack_interrupted_fn)
	self.active_attack = nil
	self.force_attack = nil

	self.inst.components.combat:ResetCurrentHitStunPressureFrames()
end

function AttackTracker:DoStartupFrames(frames)
	if not self.active_attack then return print(string.format("ERROR: Tried to add startup frames when no attack is active!")) end
	--print(string.format("%s: Do Start-up Frames (%f/%f)", self.active_attack.id, frames, self.active_attack.startup_frames_remaining))
	self.active_attack.startup_frames_remaining = math.ceil((self.active_attack.startup_frames_remaining - frames) * self.startup_frames_mod)
end

function AttackTracker:PickAttackFromValidAttacks(valid_attacks)
	local next_attack = nil

	local best_priority = -math.huge
	local best_priority_attacks = {}
	for i, atk_data in ipairs(valid_attacks) do
		if atk_data.priority > best_priority then
			next_attack = atk_data.id
			best_priority = atk_data.priority
			best_priority_attacks = {}
		end

		-- Valid attacks with equal best priority get added to a list of attacks which we randomly choose from afterwards.
		if atk_data.priority == best_priority
				and (self.last_attack_priority == nil or self.last_attack_priority == best_priority)
				and (lume.count(self.remaining_best_priority_attacks) <= 0 or self.remaining_best_priority_attacks[atk_data.id]) then
			table.insert(best_priority_attacks, atk_data)
		end
	end

	-- Choose an attack from the list of available same-priority attacks.
	if #best_priority_attacks > 0 then
		local random_idx = math.random(1, #best_priority_attacks)
		next_attack = best_priority_attacks[random_idx].id
		table.remove(best_priority_attacks, random_idx)
	end

	return next_attack, best_priority, best_priority_attacks
end

function AttackTracker:PickNextAttack(data, trange)
	if self.active_attack then
		return self.active_attack.id
	end
	local valid_attacks = {}
	local next_attack = nil
	local best_priority = -math.huge
	local best_remaining_attacks = {}
	local retry_cooldown = 0

	for id, atk_data in pairs(self.attack_data) do
		if not self:IsAttackOnCooldown(id) then
			if atk_data.start_conditions_fn then
				local can_attack, use_retry_cooldown = atk_data.start_conditions_fn(self.inst, atk_data, trange)
				if can_attack then
					table.insert(valid_attacks, atk_data)
				elseif use_retry_cooldown then
					retry_cooldown = math.max(retry_cooldown, atk_data.retry_cooldown)
				end
				self:Logf("[%s] start_conditions_fn: can_attack=%s, retry_cooldown=%s", id, can_attack, retry_cooldown)
			end
		end
	end

	next_attack, best_priority, best_remaining_attacks = self:PickAttackFromValidAttacks(valid_attacks)

	if #best_remaining_attacks > 0 then
		if self.remaining_best_priority_attacks[next_attack] then
			self.remaining_best_priority_attacks[next_attack] = nil
		end
	end

	if next_attack == nil and retry_cooldown and retry_cooldown > 0 then
		self:Logf("PickNextAttack: cooldown '%s'", retry_cooldown)
		return next_attack, retry_cooldown
	end

	-- There are remaining attacks of the selected best priority; select from those instead the next time.
	if not self.last_attack_priority or self.last_attack_priority == best_priority then
		for _, atk_data in ipairs(best_remaining_attacks) do
			self.remaining_best_priority_attacks[atk_data.id] = true
		end
	end

	self.last_attack_priority = next_attack ~= nil and best_priority or self.last_attack_priority

	self:Logf("PickNextAttack: attack '%s'", next_attack)
	return next_attack
end

function AttackTracker:PickHitStunPressureAttack(data, trange)
	if self.active_attack then
		return self.active_attack.id
	end
	local valid_attacks = {}
	local next_attack = nil
	local retry_cooldown = 0

	-- Look for hitstun pressure attacks only.
	for id, atk_data in pairs(self.attack_data) do
		if atk_data.is_hitstun_pressure_attack then
			table.insert(valid_attacks, atk_data)
		end
	end

	next_attack = self:PickAttackFromValidAttacks(valid_attacks)

	self:Logf("PickHitStunPressureAttack: attack '%s'", next_attack)
	return next_attack
end

--- Helper Functions

function AttackTracker:GetStateNameForAttack(attack_id)
	local state_name = attack_id.."_pre"
	if self:IsAttackActive(attack_id) and self.active_attack.has_hold and not self.force_attack then
		state_name = attack_id.."_hold"
	end
	return state_name
end

function AttackTracker:SetRemainingStartupFrames(frames)
	-- This is used for networking purposes, taking control of a mob mid-attack. Don't cap this at min_startup_frames, because that may artificially extend the length of the 'hold'
	if not self.active_attack then return end
	self.active_attack.startup_frames_remaining = frames
end

function AttackTracker:GetRemainingStartupFrames()
	if not self.active_attack then return 0 end
	return math.max(self.active_attack.startup_frames_remaining, self.active_attack.min_startup_frames)
end

function AttackTracker:GetAttackCooldown()
	if not self.active_attack then return 0 end
	return self.active_attack.cooldown
end

function AttackTracker:SetMinimumCooldown(value)
	self.minimum_cooldown = value
end

function AttackTracker:GetAttackData(attack_id)
	return self.attack_data[attack_id]
end

function AttackTracker:IsAttackActive(attack_id)
	return self.active_attack ~= nil and self.active_attack.id == attack_id
end

function AttackTracker:IsAttackOnCooldown(attack_id)
	local data = self:GetAttackData(attack_id)
	if data.timer_id then
		return self.inst.components.timer:HasTimer(data.timer_id)
	end
	return false
end

function AttackTracker:GetActiveAttack()
	return self.active_attack
end

function AttackTracker:ModifyAttackCooldowns(multiplier)
	for id, atk_data in pairs(self.attack_data) do
		if atk_data.cooldown ~= nil then
			atk_data.cooldown = atk_data.cooldown * multiplier
		end
	end
end

function AttackTracker:ModifyAllAttackTimers(multiplier)
	local timer = self.inst.components.timer
	if timer ~= nil then
		for id, atk_data in pairs(self.attack_data) do
			if timer:HasTimer(atk_data.timer_id) then
				local timeleft = timer:GetTimeRemaining(atk_data.timer_id)
				timer:SetTimeRemaining(atk_data.timer_id, timeleft * multiplier)
			end
		end
	end
end

function AttackTracker:UpdateModifiers()
	local modifiers = TUNING:GetEnemyModifiers(self.inst.prefab)
	if self.inst:HasTag("elite") then
		self.cooldown_mod = modifiers.EliteCooldownMult
		self.minimum_cooldown_mod = modifiers.EliteCooldownMinMult
	elseif self.inst:HasTag("boss") then
		self.cooldown_mod = modifiers.BossCooldownMult
		self.minimum_cooldown_mod = modifiers.BossCooldownMinMult
	else
		self.cooldown_mod = modifiers.CooldownMult
		self.minimum_cooldown_mod = modifiers.CooldownMinMult
	end
	self.minimum_cooldown = TUNING.DEFAULT_MINIMUM_COOLDOWN

	self.initial_cooldown_mod = TUNING.DEFAULT_MINIMUM_COOLDOWN
	if self.inst:HasTag("elite") then
		self.initial_cooldown_mod = modifiers.EliteInitialCooldownMult 
	elseif self.inst:HasTag("boss") then
		self.initial_cooldown_mod = modifiers.BossInitialCooldownMult
	else
		self.initial_cooldown_mod = modifiers.InitialCooldownMult
	end

	if self.inst:HasTag("elite") then
		self.startup_frames_mod = modifiers.EliteStartupFramesMult
	elseif self.inst:HasTag("boss") then
		self.startup_frames_mod = modifiers.BossStartupFramesMult
	else
		self.startup_frames_mod = modifiers.StartupFramesMult
	end
end

function AttackTracker:IsForcedAttack()
	return self.force_attack ~= nil
end

function AttackTracker:ResetData()
	self:CancelActiveAttack()
	self.attack_data = {}
end


function AttackTracker:DebugDrawEntity(ui, panel, colors)
	-- See InstanceLog for usage of self:Logf.
	self:DebugDraw_Log(ui, panel, colors)
end

-- InstanceLog lets us use self:Logf for logs that show in DebugEntity.
AttackTracker:add_mixin(InstanceLog)
return AttackTracker
