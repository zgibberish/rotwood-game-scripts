-- This component does a few simple things:
--     When a new target enters the hitbox, apply a power to it.
--     When a target leaves the hitbox, remove the power to it.
--     While in the hitbox, do nothing.

local lume = require "util.lume"
local Power = require "defs.powers"

local AuraApplyer = Class(function(self, inst)
    self.inst = inst
    self.enabled = false

	self.rampup = false
	self.rampup_velocity = 0
	self.rampup_start_dist = 0
	self.enabled_time = nil

	self.rampdown = false
	self.rampdown_velocity = 0
	self.disabled_time = nil

    self.radius = 5
	self.beamhitbox_data = nil

    self.expectedtargets = {}
    self.seenthistick = {}
	self.ignoreauratargetcheck = nil

    self.power = nil
    self.powerstacks = nil

	self.hitflags = Attack.HitFlags.DEFAULT
    self.inst.components.hitbox:SetUtilityHitbox(false)

    self._onhitboxtriggeredfn = function(_inst, data) self:OnHitBoxTriggered(data) end
    self.inst:ListenForEvent("hitboxtriggered", self._onhitboxtriggeredfn)
end)

local nrTargetBits = 6

function AuraApplyer:OnNetSerialize()
	local e = self.inst.entity

	e:SerializeBoolean(self.enabled)
	e:SerializeDoubleAs16Bit(self.radius)

	e:SerializeBoolean(self.power ~= nil)
	if self.power then
		e:SerializeString(self.power)
	end

	-- Count the nr of valid targets:
	local num_targets = 0;
	for ent, _ in pairs(self.expectedtargets) do
		if ent and ent:IsValid() and ent.Network then
			num_targets = num_targets + 1
		end
	end

	assert(num_targets < (1 << nrTargetBits), "Too many targets for auraapplyer to serialize")
	e:SerializeUInt(num_targets, nrTargetBits)

	for ent, _ in pairs(self.expectedtargets) do
		if ent and ent:IsValid() and ent.Network then
			e:SerializeEntityID(ent.Network:GetEntityID())
		end
	end
end

function AuraApplyer:OnNetDeserialize()
	local e = self.inst.entity

	local enabled = e:DeserializeBoolean()
	if self.power and self.enabled ~= enabled then
		if enabled then
			self:Enable()
		else
			self:Disable()
		end

		self.enabled = enabled
	end

	self.radius = e:DeserializeDoubleAs16Bit()

	local has_power = e:DeserializeBoolean()
	if has_power then
		self.power = e:DeserializeString()
	end

	local nrTargets = e:DeserializeUInt(nrTargetBits)

	local old_targets = self.expectedtargets
	self.expectedtargets = {}

	for _i=1,nrTargets do
		local entGUID = TheNet:FindGUIDForEntityID(e:DeserializeEntityID())
		local ent = Ents[entGUID]
		if ent and ent:IsValid() then
			self:_ApplyEffect(ent)
			self.expectedtargets[ent] = true
		end
	end

	for ent in pairs(old_targets) do
		if not self.expectedtargets[ent] and ent:IsValid() then
			self:_RemoveEffect(ent)
		end
	end
end

function AuraApplyer:OnRemoveFromEntity()
	self:Disable()
end

function AuraApplyer:OnRemoveEntity()
	self:OnRemoveFromEntity()
end

function AuraApplyer:Enable()
	if not self.enabled then
		self.enabled = true
		self.inst.components.hitbox:SetUtilityHitbox(true)
		self.inst:StartUpdatingComponent(self)

		self.enabled_time = GetTime()
	end
end

function AuraApplyer:Disable()
	if self.enabled then
		if self.rampdown then
			-- If ramping down the aura effect area, we must set self.rampdown & call Disable() during the update loop.
			return
		else
			self.inst:StopUpdatingComponent(self)
			self.inst.components.hitbox:SetUtilityHitbox(false)
			self.enabled = false

			for target,_ in pairs(self.expectedtargets) do
				self:_RemoveEffect(target)
			end
			self.expectedtargets = {}
		end
	end
end

function AuraApplyer:OnHitBoxTriggered(data)
	if not self.enabled then return end -- If disabled, ignore hitboxtriggered events!

	for _, target in ipairs(data.targets) do -- Iterate through the targets that are present this tick
		-- Only apply if the hitflags are valid
		local targethitflags = target.components.hitflagmanager and target.components.hitflagmanager:GetHitFlags() or Attack.HitFlags.DEFAULT
		if self.hitflags & targethitflags ~= 0 then
			self.seenthistick[target] = true -- Mark them as seen this tick, so that we know they have not stepped out of the aura range. In OnUpdate, we'll compare this list to the targets that were there last tick, to know who "left" the range.
			if self.expectedtargets[target] == nil then
				-- This target is new, so let's add our power to it and add it to our list of known targets
				self:_ApplyEffect(target)
				self.expectedtargets[target] = true
			end
		end
	end
end

function AuraApplyer:SetEffect(power)
	self.power = power
end

function AuraApplyer:_ShouldApplyEffect(target)
	return target.components.powermanager and not target.components.powermanager:IsPowerIgnored(self.power)
end

function AuraApplyer:_CanApplyEffect(target)
	if not target or not target:IsValid() then
		TheLog.ch.AuraApplyer:printf("Cannot apply: No target")
		return false
	end

	local is_net_aligned =
		(self.inst:IsNetworked() and target:IsNetworked()) or
		(not self.inst:IsNetworked() and target:IsLocalOrMinimal())

	if not is_net_aligned then
		TheLog.ch.AuraApplyer:printf("Cannot apply: Not net aligned")
		return false
	end

	return true
end

function AuraApplyer:_ApplyEffect(target)
	if self:_CanApplyEffect(target) and self:_ShouldApplyEffect(target) then
		local def = Power.FindPowerByName(self.power)
		if not target.components.powermanager:HasPower(def) then
			local power = self.inst.components.powermanager:CreatePower(def)
			target.components.powermanager:AddPower(power, self.powerstacks)
		end

		if def.has_sources then
			local power = target.components.powermanager:GetPower(def)
			if power ~= nil then
				if power.mem.sources == nil then
					power.mem.sources = {}
				end
				power.mem.sources[self.inst.GUID] = self.inst
				target:PushEvent("aura_source_added", self.inst)
			end
		end

		return true
	end
	return false
end

function AuraApplyer:_RemoveEffect(target)
	if self:_CanApplyEffect(target) and target.components.powermanager ~= nil then
		local def = Power.FindPowerByName(self.power)
		if def and def.has_sources then
			local power = target.components.powermanager:GetPower(def)
			-- TODO: networking2022, not sure this is sufficient (revisit this)
			if power ~= nil and power.mem.sources and power.mem.sources[self.inst.GUID] then
				power.mem.sources[self.inst.GUID] = nil
				target:PushEvent("aura_source_removed", self.inst)
				if table.count(power.mem.sources) > 0 then
					return
				end
			end
		end

		-- No more sources, remove the power
		target.components.powermanager:RemovePowerByName(self.power, true)
	end
end

function AuraApplyer:SetRadius(radius)
	self.beamhitbox_data = nil
	self.radius = radius
end

function AuraApplyer:SetupBeamHitbox(startdist_or_data, enddist, thickness, zoffset)
	self.beamhitbox_data = {}
	if type(startdist_or_data) == "table" then
		for i, data in ipairs(startdist_or_data) do
			table.insert(self.beamhitbox_data, data)
		end
	else
		table.insert(self.beamhitbox_data, { startdist_or_data, enddist, thickness, zoffset })
	end
end

function AuraApplyer:SetHitFlags(flags)
	self.hitflags = flags
end

-- Must call this after an effect has been assigned
function AuraApplyer:EnableRampUp(enabled, rampup_start_dist)
	self.rampup = enabled

	if enabled then
		local def = Power.FindPowerByName(self.power)
		if def then
			local rarity = Power.GetBaseRarity(def)
			self.rampup_velocity = def.tuning[rarity].rampup_velocity or 0
			self.rampup_start_dist = rampup_start_dist or 0
		end
	end
end

function AuraApplyer:EnableRampDown(enabled)
	self.rampdown = enabled

	self.disabled_time = GetTime()

	local def = Power.FindPowerByName(self.power)
	if def then
		local rarity = Power.GetBaseRarity(def)
		self.rampdown_velocity = def.tuning[rarity].rampdown_velocity or 0
	end
end

function AuraApplyer:OnUpdate()
	if not self.power then
		return
	end

	if self.beamhitbox_data ~= nil then
		for i, data in ipairs(self.beamhitbox_data) do
			local startdist, enddist, thickness, zoffset = table.unpack(data)

			if self.rampup then
				local time_active = self.enabled_time and GetTime() - self.enabled_time or 0
				local rampup_distance = self.rampup_velocity * time_active
				if rampup_distance >= enddist then
					self.rampup = nil
				end
				enddist = math.min(enddist, self.rampup_velocity * time_active)
			end
			if self.rampdown then
				local time_active = self.disabled_time and GetTime() - self.disabled_time or 0
				local rampdown_distance = self.rampdown_velocity * time_active
				if rampdown_distance >= enddist then
					self.rampdown = nil
					self:Disable()
				end
				startdist = math.min(enddist, self.rampdown_velocity * time_active)
			end

			self.inst.components.hitbox:PushOffsetBeam(startdist, enddist, thickness, zoffset, HitPriority.MOB_DEFAULT)
		end
	else
		local radius = self.radius
		local current_radius = self.rampup_start_dist or 0
		if self.rampup then
			local time_active = self.enabled_time and GetTime() - self.enabled_time or 0
			radius = math.min(radius, current_radius + self.rampup_velocity * time_active)
		end

		self.inst.components.hitbox:PushCircle(0, 0, radius, HitPriority.MOB_DEFAULT)
	end

	-- Check the table for who we expect to see, based on who was here last tick
	if not self.ignoreauratargetcheck then
		for target,_ in pairs(self.expectedtargets) do
			if not self.seenthistick[target] then -- If the target we expect to see wasn't detected by the hitbox this frame, remove its power and stop expecting it.
				self:_RemoveEffect(target)
				self.expectedtargets[target] = nil
			end
		end

		lume.clear(self.seenthistick) -- Clear the list of targets we've seen, so we're starting fresh next tick
	else
		self.ignoreauratargetcheck = nil
	end
end

return AuraApplyer
