local Power = require "defs.powers"
local iterator = require "util.iterator"
local itemforge = require "defs.itemforge"
local kassert = require "util.kassert"
local lume = require "util.lume"
local Equipment = require "defs.equipment"
require "util"

local function create_default_data()
	local data =
	{
		powers = {
			-- a list of all the powers the player currently has
			-- slot = { ["power_name"] = power_def, ... },
		},

		acquire_index = 0,
		seen_powers = {
			-- a list of all the powers the player has seen so far this run
			-- powers that the player has not seen will not be in this table
			-- slot = { ["power_name"] = true, ... }
		},
	}

	for _, slot in pairs(Power.Slots) do
		assert(not data.powers[slot] and not data.seen_powers[slot], "The following slot already exists:"..slot)
		data.powers[slot] = {}
		data.seen_powers[slot] = {}
	end

	return data
end

local PowerManager = Class(function(self, inst)
	self.inst = inst
	self.data = create_default_data() -- power items (persistent data)
	self.powers = {} -- power list (transient data)
	self.power_drop_choices = 2
	self.event_triggers = {}
	self.remote_event_triggers = {}
	self.update_powers = {}
	self.ready_powers = {}
	self.attack_fx_mods = {}
	self.ignorepowers = {}

	self.can_receive_powers = true

	self.powers_from_equipment = {} -- list of powers we gained from equipment
	self.overridden_equipment_slots = {}	-- If we got a skill in a run, set that slot as overridden and don't add that skill power back. Can also use to disable armour powers?

    self._reset_data_fn =  function() self:ResetData() end
    self.inst:ListenForEvent("start_new_run", self._reset_data_fn)
    self.inst:ListenForEvent("character_slot_changed", self._reset_data_fn)

	self._onupdate_power = function(source, power_def) self:OnUpdatePower(power_def) end
	self.inst:ListenForEvent("update_power", self._onupdate_power)

	self._onloadoutchanged = function() self:OnLoadoutChanged() end
	self.inst:ListenForEvent("loadout_changed", self._onloadoutchanged)
	self.inst:ListenForEvent("equipment_upgrade", self._onloadoutchanged)
end)

function PowerManager:OnPostSpawn()
	-- Calling EnsureRequiredComponents in prefab constructor ensures all
	-- components exist in OnPostSpawn so they can hook up to each other.
	local forgot = self:EnsureRequiredComponents()
	if forgot then
		TheLog.ch.PowerManager:printf("Forgot EnsureRequiredComponents in prefab contructor for [%s]. Some components added after PostSpawn.", self.inst)
	end
end

function PowerManager:OnRemoveFromEntity()
	self.inst:RemoveEventCallback("character_slot_changed", self._reset_data_fn)
	self.inst:RemoveEventCallback("start_new_run", self._reset_data_fn)
	self.inst:RemoveEventCallback("update_power", self._onupdate_power)
	self.inst:RemoveEventCallback("loadout_changed", self._onloadoutchanged)
	self.inst:RemoveEventCallback("equipment_upgrade", self._onloadoutchanged)
end

function PowerManager:OnRemoveEntity()
	self:OnRemoveFromEntity()
end

function PowerManager:OnPostSetPlayerOwner()
	self:OnLoadoutChanged()

	if self.deferred_presentation_fns then
		for _i,fn in ipairs(self.deferred_presentation_fns) do
			fn()
		end
		table.clear(self.deferred_presentation_fns)
	end
end

function PowerManager:OnLoadoutChanged()
	local inv = self.inst.components.inventoryhoard
	local new_powers = {}

	for _,slot in pairs(Equipment.Slots) do
		new_powers[slot] = {} -- Can be multiple powers per slot -- for example, a Gem.
		local item = inv:GetEquippedItem(slot)
		if item then
			local usage_data = item:GetUsageData()
			if usage_data and usage_data.power_on_equip then
				local new_level = item:GetUsageLevel() or 1
				table.insert(new_powers[slot], { name = usage_data.power_on_equip , level = new_level })
			end

			if item.gem_slots then
				for _,slot_data in ipairs(item.gem_slots) do
					if slot_data.gem then
						local def = slot_data.gem:GetDef()
						if def.usage_data and def.usage_data.power_on_equip then
							local new_level = item:GetUsageLevel() or 1
							table.insert(new_powers[slot], { name = def.usage_data.power_on_equip , level = new_level })
						end
					end
				end
			end
		end
	end

	for _, slot in pairs(Equipment.Slots) do
		if self:IsEquipmentSlotOverridden(slot) then
			goto skip_slot
		end

		local current_data = self:GetEquipmentPowers(slot)
		local new_data = new_powers[slot]

		local has_changed = not deepcompare(new_data, current_data)

		if not has_changed then
			goto skip_slot
		end

		if current_data then
			self:RemoveEquipmentPowers(slot)
		end

		if #new_data > 0 then
			for _,power_data in ipairs(new_data) do
				self:AddEquipmentPower(slot, power_data)
			end
		end

		::skip_slot::
	end
end

function PowerManager:EnsureRequiredComponents()
	local added_components = false
	if not self.inst.SoundEmitter then
		self.inst.entity:AddSoundEmitter()
		added_components = true
	end

	local components = {
		"bloomer",
		"coloradder",
		"colormultiplier",
		"combat",
		"health",
		"hitstopper",
		"timer",
	}
	for _,c in ipairs(components) do
		if not self.inst.components[c] then
			self.inst:AddComponent(c)
			added_components = true
		end
	end

	-- Other components aren't required, so we must nil check them:
	-- * hitbox: hitboxes require explicit setup
	-- * inventoryhoard: some things shouldn't get items (dummies)
	-- * locomotor: some things can't move (trees)
	-- * potiondrinker: only players drink potions
	-- * scalable: we don't want giant things to get bigger

	return added_components
end

function PowerManager:AddSeenPower(name, slot)
	self.data.seen_powers[slot][name] = true
end

function PowerManager:OnSave()
	-- Don't copy this implementation! Usually we should build a new table for
	-- our save data.

	local power_data = deepcopy(self.data)
	for _,slot in pairs(power_data.powers) do
		itemforge.ConvertToListOfSaveableItems(slot)
	end

	local data =
	{
		powers_from_equipment = shallowcopy(self.powers_from_equipment),
		overridden_equipment_slots = shallowcopy(self.overridden_equipment_slots),
		power_data = power_data,
	}

	return data
end

function PowerManager:OnLoad(data)
	self.loading = true
	if data ~= nil then
		self.powers_from_equipment = shallowcopy(data.powers_from_equipment)
		self.overridden_equipment_slots = shallowcopy(data.overridden_equipment_slots)

		local power_data = deepcopy(data.power_data)
		for _,slot in pairs(power_data.powers) do
			itemforge.ConvertToListOfRuntimeItems(slot)
		end
		self.data = power_data
	end

	if TheWorld:HasTag('town') then
		self:ResetData()
	else
		-- Init all first so powers that depend on each other are fully init
		-- before firing events.
		local powers = {}
		for _, slot in pairs(self.data.powers) do
			for _, power in pairs(slot) do
				table.insert(powers, self:_InitPower(power))
			end
		end
		for _,pow in ipairs(powers) do
			self:_RegisterPower(pow)
		end
	end
	self:RefreshTags()
	self.loading = nil
end

function PowerManager:IsLoading()
	return self.loading
end

function PowerManager:_CountPowerItems()
	local count = 0
	for _, slot in pairs(self.data.powers) do
		for _, _power in pairs(slot) do
			count = count + 1
		end
	end
	return count
end

-- networking2022, victorc - Not sure this implementation is a good idea
-- since we don't want the logic to run on remote entities, but adding and
-- creating powers has a lot of side effects.
-- However, we need the power state to be at least synchronized for transferable entities.

local nrPowerBits = 6
local nrStackBits = 10 -- see Power.AddPower max_stacks default (999), though most places is 100
local nrSourceCountBits = 5 -- see usage in places like auraapplyer
local nrCounterBits = 10
local CounterMaxValue = (1 << nrCounterBits) - 1

function PowerManager:OnNetSerialize()
	local e = self.inst.entity
	local nrPowerItems = self:_CountPowerItems()
	e:SerializeUInt(nrPowerItems, nrPowerBits)

	for slot, slot_powers in pairs(self.data.powers) do
		for _id, persistdata in pairs(slot_powers) do
			e:SerializeString(slot)
			e:SerializeUInt(persistdata.acquire_order, nrPowerBits)
			e:SerializeString(persistdata.id)

			local is_valid_counter = persistdata.counter ~= nil and type(persistdata.counter) == "number"
			e:SerializeBoolean(is_valid_counter)
			if is_valid_counter then
				e:SerializeUInt(persistdata.counter and math.max(0, math.min(persistdata.counter, CounterMaxValue)), nrCounterBits)
			end

			if self.powers[persistdata.id].def.stackable then
				e:SerializeUInt(persistdata.stacks and persistdata.stacks or 0, nrStackBits)
			end

			if self.powers[persistdata.id].def.has_sources then
				local nr = 0
				-- Count the nr of networked sources
				if persistdata.sources then
					for _guid,inst in pairs(persistdata.sources) do
						if inst:IsNetworked() then
							nr = nr + 1
						end
					end
				end

				-- Write out the nr
				if nr >= (1 << nrSourceCountBits) then
					TheLog.ch.PowerManager:printf("Power source overflow: %s", persistdata.id)
					for _guid,inst in pairs(persistdata.sources) do
						if inst:IsNetworked() then
							TheLog.ch.PowerManager:printf("Source: %s GUID %d", inst.prefab, inst.GUID)
						end
					end
					assert(false, "Power source overflow!")
				end
				e:SerializeUInt(nr, nrSourceCountBits)

				-- Now iterate through again and write out the networked sources
				if nr > 0 then
					for _guid,inst in pairs(persistdata.sources) do
						if inst:IsNetworked() then
							e:SerializeEntityID(inst.Network:GetEntityID())
						end
					end
				end
			end

			-- what to do about the arbitrary data? counter, did_init, etc.

			-- Run custom serialize function:
			local powinst = self.powers[persistdata.id]
			if powinst.def.on_net_serialize_fn and powinst.def.on_net_deserialize_fn then -- If there's a serialize, there should be a deserialize!
				powinst.def.on_net_serialize_fn(powinst, e)
			end
		end
	end
end

function PowerManager:OnNetDeserialize()
	local e = self.inst.entity
	local nrPowerItems = e:DeserializeUInt(nrPowerBits)

	local deserializedPowers = {}
	for i = 1, nrPowerItems do
		local slot = e:DeserializeString()
		local acquire_order = e:DeserializeUInt(nrPowerBits)
		local id = e:DeserializeString()

		local is_valid_counter = e:DeserializeBoolean()
		local counter = nil
		if is_valid_counter then
			counter = e:DeserializeUInt(nrCounterBits)
		end

		if not self.data.powers[slot][id] then
			self:AddPower(self:CreatePower(Power.FindPowerBySlotAndName(slot, id)))
			assert(self.data.powers[slot][id] ~= nil)
		end

		self.data.powers[slot][id].acquire_order = acquire_order
		local old_counter = self.data.powers[slot][id].counter
		self.data.powers[slot][id].counter = counter
		if old_counter ~= counter then
			-- power isn't fully updated ... if needed, defer to end of loop iteration
			-- TheLog.ch.PowerManager:printf("%s Remote power counter changed: old=%s new=%s", self.inst, tostring(old_counter), tostring(counter))
			self.inst:PushEvent("update_power", self.powers[id].def)
		end

		local is_stackable = false
		local has_stacks = false
		if self.powers[id].def.stackable then
			local old = self.data.powers[slot][id].stacks
			local new = e:DeserializeUInt(nrStackBits)

			if old ~= new then
				-- It's changed -- run DeltaPowerStacks so everything that relies on that can be run, too.
				local delta = new - old

				-- if a stackable power's stacks hits 0 in DeltaPowerStacks, the power will be removed,
				-- so defer that until deserialization of this power is done.
				local prevent_auto_remove <const> = true
				self:DeltaPowerStacks(self.powers[id].def, delta, prevent_auto_remove)
			else
				-- Same value, just set the value directly
				self.data.powers[slot][id].stacks = new
			end

			is_stackable = true
			has_stacks = self.data.powers[slot][id].stacks > 0
		end

		if self.powers[id].def.has_sources then
			local source_count = e:DeserializeUInt(nrSourceCountBits)
			if source_count == 0 then
				if self.powers[id].sources then
					lume.clear(self.powers[id].sources)
				end
			else
				if not self.powers[id].sources then
					self.powers[id].sources = {}
				end
				for _i=1,source_count do
					local entID = e:DeserializeEntityID()
					local entGUID = TheNet:FindGUIDForEntityID(entID)
					if entGUID and Ents[entGUID] and Ents[entGUID]:IsValid() then
						self.powers[id].sources[entGUID] = Ents[entGUID]
					end
				end
			end
		end


		local powinst = self.powers[id]
		if powinst.def.on_net_serialize_fn and powinst.def.on_net_deserialize_fn then -- If there's a serialize, there should be a deserialize!
			powinst.def.on_net_deserialize_fn(powinst, e)
		end


		deserializedPowers[id] = true

		-- get power removed after deserialization
		if is_stackable and not has_stacks and not powinst.def.permanent then
			TheLog.ch.PowerManager:printf("Deferred removal of stackable power: %s", id)
			deserializedPowers[id] = nil
		end
	end

	-- TODO: networking2022, sometimes powers aren't removed on transfer
	-- for example, bulbug shield on a slowpoke that gets shield broken, then transferred will retain shield
	local forceRemove = true
	for name, power in pairs(self.powers) do
		if not deserializedPowers[name] then
			self:RemovePowerBySlotAndName(power.def.slot, name, forceRemove)
		end
	end
end

function PowerManager:ResetData()
	-- Loop over savedata to ensure we reset loaded state.
	for _, slot in pairs(self.data.powers) do
		for _, power in pairs(slot) do
			local power_def = power:GetDef()
			self:RemovePower(power_def, true)
		end
	end

	self.powers_from_equipment = {}
	self.overridden_equipment_slots = {}

	assert(not next(self.event_triggers), "Player Powers data is reset but self.event_triggers is not empty.")
	assert(not next(self.remote_event_triggers), "Player Powers data is reset but self.remote_event_triggers is not empty.")
	assert(not next(self.update_powers), "Player Powers data is reset but self.update_powers is not empty.")
	assert(not next(self.ready_powers), "Player Powers data is reset but self.ready_powers is not empty.")

	self.data = create_default_data()
end

function PowerManager:_InitPower(power)
	local pow = Power.PowerInstance(power)
	assert(self.powers[pow.def.name] == nil, string.format("Tried to add power %s to %s more than once!", pow.def.name, self.inst))
	self.powers[pow.def.name] = pow
	return pow
end

function PowerManager:_RegisterPower(pow)
	-- don't need powers to run logic for remote, non-transferable entities (i.e. remote players)
	local is_local_or_transferable = self.inst:IsLocal() or self.inst:IsTransferable()
	if not is_local_or_transferable then
		return
	end

	self:SetUpEventTriggers(pow)

	if pow.def.on_add_fn then
		pow.def.on_add_fn(pow, self.inst)
	end

	if pow.def.on_update_fn then
		self:AddUpdatePower(pow)
	end
end

function PowerManager:DeltaPowerStacks(power_def, delta, prevent_remove_on_empty)
	assert(power_def.stackable, "Tried to add stacks to a power that isn't stackable: "..power_def.name)
	if not IsWholeNumber(delta) then
		TheLog.ch.PowerManager:printf("Warning: DeltaPowerStacks %s, delta %1.3f is expected to be an integer value.", power_def.name, delta)
	end

	local pow = self:GetPower(power_def)

	if not pow then return end

	local old = self:GetPowerStacks(power_def)

	pow.persistdata.stacks = (pow.persistdata.stacks or 0) + delta
	pow.persistdata.stacks = math.clamp(pow.persistdata.stacks, 0, power_def.max_stacks)

	if pow.persistdata.stacks ~= old then
		local event
		if self.inst:IsLocal() then
			event = "power_stacks_changed"
			if power_def.on_stacks_changed_fn then
				power_def.on_stacks_changed_fn(pow, self.inst, delta)
			end
		else
			event = "power_stacks_changed_remote"
		end

		-- network2022: sending a remote-specific version of this event sometimes because some UI elements will need to listen to it on remote entities
		-- 				but sending "power_stacks_changed" on those entities may cause unexpected knock-ons for powers that are listening to the event on a remote entity

		self.inst:PushEvent(event, {
			pow = pow,
			power_def = power_def,
			power = pow.persistdata,
			old = old,
			new = pow.persistdata.stacks,
		})
	end

	if not prevent_remove_on_empty and pow.persistdata.stacks <= 0 then
		self:RemovePower(power_def)
	end
end

function PowerManager:SetCanReceivePowers(toggle)
	self.can_receive_powers = toggle
end

function PowerManager:CanReceivePowers()
	return self.can_receive_powers
end

function PowerManager:SetPowerStacks(power_def, value)
	local delta = value - self:GetPowerStacks(power_def)
	self:DeltaPowerStacks(power_def, delta)
end

function PowerManager:GetPowerStacks(power_def)
	local pow = self:GetPower(power_def)
	if not pow or not power_def.stackable then
		return 0
	end
	return pow.persistdata.stacks
end

function PowerManager:GetCurrentSkillPower()
	for id,power in pairs(self.powers) do
		if power.persistdata.slot == Power.Slots.SKILL then
			return power.persistdata, id
		end
	end
end

function PowerManager:GetCurrentSkillID()
	local power, id = self:GetCurrentSkillPower()
	return id
end

function PowerManager:CreatePower(def, rarity)
	return itemforge.CreatePower(def, rarity)
end

function PowerManager:Debug_CanAddPower(power, stacks)
	local power_def = power:GetDef()
	assert(power_def.name, "AddPower takes a power def from Power.Items")
	local slot = self.data.powers[power_def.slot]
	local equipped_power = slot[power_def.name]
	return not equipped_power or power_def.stackable
end

function PowerManager:_CompactPowerAcquireOrder()
	local sorted_powers = self:GetAllPowersInAcquiredOrder()
	for i,power in ipairs(sorted_powers) do
		-- TheLog.ch.PowerManager:printf("[%d] Power: %s", power.persistdata.acquire_order, power.def.name)
		power.persistdata.acquire_order = i - 1 -- zero-based
	end

	-- TheLog.ch.PowerManager:printf("PowerManager acquire order - after:")
	-- for _i, power in ipairs(sorted_powers) do
	-- 	TheLog.ch.PowerManager:printf("[%d] Power: %s", power.persistdata.acquire_order, power.def.name)
	-- end

	self.data.acquire_index = #sorted_powers
end

function PowerManager:_GetOldestAcquiredPower(slot_name)
	local oldest_acquired
	for _, pow in pairs(self.powers) do
		if pow.persistdata.slot == slot_name then
			if not oldest_acquired then
				oldest_acquired = pow
			else
				oldest_acquired = oldest_acquired.persistdata.acquire_order < pow.persistdata.acquire_order
					and oldest_acquired
					or pow
			end
		end
	end
	return oldest_acquired
end

function PowerManager:AddPower(power, stacks)
	if not self.can_receive_powers then
		return
	end

	local power_def = power:GetDef()

	if power_def.prerequisite_fn ~= nil and not power_def.prerequisite_fn(self.inst) then
		return
	end

	assert(power_def.name, "AddPower takes a power def from Power.Items")
	local slot = self.data.powers[power_def.slot]
	local equipped_power = slot[power_def.name]

	if Power.MaxCount[power_def.slot] then
		local num_powers = lume.count(slot)

		dbassert(power_def.slot == Power.Slots.SKILL or num_powers < Power.MaxCount[power_def.slot],
			string.format("%s power limit reached (%d) - Review Power.AddPowerFamily call",
				power_def.slot, Power.MaxCount[power_def.slot]))

		while num_powers >= Power.MaxCount[power_def.slot] do
			local excess_power = self:_GetOldestAcquiredPower(power_def.slot)

			TheLog.ch.PowerManager:printf("Warning: Removing %s to make room for new power (%s limit = %d)",
				excess_power.def.name, power_def.slot, Power.MaxCount[power_def.slot])

			self:RemovePower(excess_power.def, true)
			num_powers = num_powers - 1
		end
	end

	if equipped_power ~= nil then
		if power_def.stackable then
			self:DeltaPowerStacks(power_def, stacks or 1)
			return
		elseif power_def.reset_on_stack then
			-- Remove the existing effect, effectly resetting it.
			self:RemovePower(power_def, true)
		else
			-- Something has gone wrong! The player is not supposed to be able to get two of the same upgrade.
			TheLog.ch.PowerManager:printf("Attempted to add a non-stackable power more than once!: "..power_def.name.." on "..self.inst.prefab)
			return
		end
	end

	power.acquire_order = self.data.acquire_index
	self.data.acquire_index = self.data.acquire_index + 1
	if self.data.acquire_index >= (1 << nrPowerBits) then
		self:_CompactPowerAcquireOrder()
	end

	local pow = self:_InitPower(power)
	assert(pow)
	self:_RegisterPower(pow)

	slot[power_def.name] = pow.persistdata

	if power_def.stackable then
		pow.persistdata.stacks = 0
		self:DeltaPowerStacks(power_def, stacks or 1)
	end

	if #power_def.tags > 0 then
		self:RefreshTags()
	end

	self:RefreshPowerAttackFX()

	self.inst:PushEvent("add_power", pow)
end

function PowerManager:RemovePower(power_def, force)
	if power_def.permanent and not force then return end

	local slot = self.data.powers[power_def.slot]
	local pow = self.powers[power_def.name]

	if pow ~= nil then
		self:RemoveEventTriggers(pow)
		if power_def.on_remove_fn then
			power_def.on_remove_fn(pow, self.inst)
		end
		if self.update_powers[pow] then
			self.update_powers[pow] = nil
		end
		if self.ready_powers[pow] then
			self.ready_powers[pow] = nil
		end
		slot[power_def.name] = nil

		self.powers[power_def.name] = nil

		if #power_def.tags > 0 then
			for i, tag in ipairs(power_def.tags) do
				self.inst:RemoveTag(tag)
			end
			self:RefreshTags()
		end

		self.inst:PushEvent("remove_power", pow)
	end
end

function PowerManager:IsEquipmentSlotOverridden(slot)
	return self.overridden_equipment_slots[slot] ~= nil
end

function PowerManager:GetEquipmentPowers(slot)
	return self.powers_from_equipment[slot]
end

-- Equipment power functions:
function PowerManager:AddEquipmentPower(slot, data)
	-- printf("PowerManager:AddEquipmentPower(%s)", slot)
	if not self.powers_from_equipment[slot] then
		self.powers_from_equipment[slot] = {}
	end

	table.insert(self.powers_from_equipment[slot], data)

	local def = Power.FindPowerByName(data.name)

	local stacks

	if def.power_type == Power.Types.EQUIPMENT then
		stacks = def.stacks_per_usage_level[data.level]
	end

	self:AddPowerByName(data.name, stacks)
end

function PowerManager:RemoveEquipmentPowers(slot)
	-- printf("PowerManager:RemoveEquipmentPowers(%s)", slot)

	local powers = self:GetEquipmentPowers(slot)
	for _,power_data in ipairs(powers) do
		local current_power = self:GetPowerByName(power_data.name)
		if current_power and current_power.def.stackable then
			-- if stackable, remove # of stacks.
			local stacks = current_power.def.stacks_per_usage_level[power_data.level]
			self:DeltaPowerStacks(current_power.def, -stacks)
		else
			-- if not stackable, remove entire power
			self:RemovePowerByName(power_data.name)
		end
	end

	self.powers_from_equipment[slot] = nil
end

function PowerManager:AddEquipmentPowerOverride(slot, data)
	self:RemoveEquipmentPowers(slot)
	self:AddEquipmentPower(slot, data)
	self.overridden_equipment_slots[slot] = true
end

function PowerManager:RemoveEquipmentPowerOverride(slot)
	self.overridden_equipment_slots[slot] = nil
	self:RemoveEquipmentPowers(slot)
end

function PowerManager:AddPowerByName(name, stacks)
	local def = Power.FindPowerByName(name)
	local power = self.inst.components.powermanager:CreatePower(def)
	self:AddPower(power, stacks)
end

function PowerManager:RemovePowerByName(name, force)
	local def = Power.FindPowerByName(name)
	self:RemovePower(def, force)
end

function PowerManager:RemovePowerBySlotAndName(slot, name, force)
	local def = Power.FindPowerBySlotAndName(slot, name)
	self:RemovePower(def, force)
end

function PowerManager:SetUpEventTriggers(pow)
	if next(pow.def.event_triggers) then
		if self.event_triggers[pow.def.name] ~= nil then
			assert(nil, "Tried to set up event triggers for a power that already has them!")
		end
		self.event_triggers[pow.def.name] = {}
		local triggers = self.event_triggers[pow.def.name]
		for event, fn in pairs(pow.def.event_triggers) do
			local listener_fn = function(inst, ...) return fn(pow, inst, ...) end
			triggers[event] = listener_fn
			self.inst:ListenForEvent(event, listener_fn)
		end
	end

	if next(pow.def.remote_event_triggers) then
		if self.remote_event_triggers[pow.def.name] ~= nil then
			assert(nil, "Tried to set up remote event triggers for a power that already has them!")
		end

		self.remote_event_triggers[pow.def.name] = {}
		local triggers = self.remote_event_triggers[pow.def.name]
		for event, data in pairs(pow.def.remote_event_triggers) do
			local source = data.source()
			local listener_fn = function(source, ...) data.fn(pow, self.inst, source, ...) end
			triggers[event] = { fn = listener_fn, source = source }
			self.inst:ListenForEvent(event, listener_fn, source)
			-- printf("Set Up Event Trigger: %s on %s", event, source)
		end
	end
end

function PowerManager:RemoveEventTriggers(pow)
	if next(pow.def.event_triggers) then
		local triggers = self.event_triggers[pow.def.name]
		if triggers then
			for event, fn in pairs(triggers) do
				self.inst:RemoveEventCallback(event, fn)
			end
		end
		self.event_triggers[pow.def.name] = nil
	end

	if next(pow.def.remote_event_triggers) then
		local triggers = self.remote_event_triggers[pow.def.name]
		if triggers then
			for event, data in pairs(triggers) do
				self.inst:RemoveEventCallback(event, data.fn, data.source)
			end
		end
		self.remote_event_triggers[pow.def.name] = nil
	end
end

function PowerManager:AddUpdatePower(pow)
	self.update_powers[pow] = pow.def
	self.inst:StartUpdatingComponent(self)
end

function PowerManager:OnUpdate(dt)
	if not next(self.update_powers) then
		self.inst:StopUpdatingComponent(self)
		return
	end

	if self.inst:IsLocal() then
		for pow, power_def in pairs(self.update_powers) do
			power_def.on_update_fn(pow, self.inst, dt)
		end
	end
end

function PowerManager:RefreshTags()
	for _, slot in pairs(self.data.powers) do
		for _, power in pairs(slot) do
			local power_def = power:GetDef()
			if #power_def.tags > 0 then
				for i, tag in ipairs(power_def.tags) do
					self.inst:AddTag(tag)
				end
			end
		end
	end
end

function PowerManager:RefreshPowerAttackFX()
	for _, slot in pairs(self.data.powers) do
		for _, power in pairs(slot) do
			local power_def = power:GetDef()
			if power_def.attack_fx_mods ~= nil then
				for attack, mod in pairs(power_def.attack_fx_mods) do
					self:SetPowerAttackFX(attack, mod)
				end
			end
		end
	end
end

function PowerManager:SetPowerAttackFX(attack_type, fx_type)
	dbassert(not self.attack_fx_mods[attack_type] or self.attack_fx_mods[attack_type] == fx_type)
	self.attack_fx_mods[attack_type] = fx_type
end

function PowerManager:GetPowerAttackFX(attack_type)
	return self.attack_fx_mods[attack_type]
end

function PowerManager:UpgradePower(power_def)
	if not self.inst:IsLocal() then
		return
	end

	local pow = self:GetPower(power_def)
	if not pow then
		TheLog.ch.PowerManager:printf("Warning: UpgradePower attempted to upgrade a non-existent power")
		return
	end

	local next_rarity = Power.GetNextRarity(pow.persistdata)

	if not next_rarity then return end

	if power_def.on_remove_fn then
		power_def.on_remove_fn(pow, self.inst, true)
	end

	pow.persistdata:SetRarity(next_rarity)

	if power_def.on_add_fn then
		power_def.on_add_fn(pow, self.inst, true)
	end

	self.inst:PushEvent("update_power", power_def)
	self.inst:PushEvent("power_upgraded", pow)
end

---------------------------------------------------------------------

function PowerManager:CopyPowersFrom(target)
	if target.components.powermanager then

		for name, pow in pairs(target.components.powermanager.powers) do
			local def = pow.persistdata:GetDef() -- Power.FindPowerByName(name)
			local new_power = self:CreatePower(def, pow.persistdata:GetRarity())
			self:AddPower(new_power, pow.persistdata.stacks or nil)
		end

		-- local power_data = target.components.powermanager:OnSave()
		-- self:OnLoad(power_data)
	end
end

function PowerManager:GetAllPowersInAcquiredOrder()
	local all_powers = {}
	for _, pow in pairs(self.powers) do
		table.insert(all_powers, pow)
	end

	table.sort(all_powers, function(a,b)
		return a.persistdata.acquire_order < b.persistdata.acquire_order
	end)
	return all_powers
end

function PowerManager:GetAllRelicPowersInAcquiredOrder()
	local all_powers = {}
	for _, pow in pairs(self.powers) do
		if pow.def.power_type == Power.Types.RELIC or pow.def.power_type == Power.Types.FABLED_RELIC then
			table.insert(all_powers, pow)
		end
	end

	table.sort(all_powers, function(a,b)
		return a.persistdata.acquire_order < b.persistdata.acquire_order
	end)
	return all_powers
end

function PowerManager:GetPowersInAcquiredOrder(slot)
	kassert.typeof('string', slot)
	local list = lume.values(lume.map(self.data.powers[slot], function(v)
		return self.powers[v:GetDef().name]
	end))
	table.sort(list, function(a,b)
		return a.persistdata.acquire_order < b.persistdata.acquire_order
	end)
	return list
end

function PowerManager:GetUpgradeablePowers()
	local all_powers = self:GetAllPowersInAcquiredOrder()
	local upgradeable_powers = {}
	for _, pow in ipairs(all_powers) do
		if self:CanUpgradePower(pow.def) then
			table.insert(upgradeable_powers, pow)
		end
	end

	return upgradeable_powers
end

function PowerManager:GetPowerByName(power)
	if self.powers[power] ~= nil then
		return self.powers[power]
	else
		return nil
	end
end

function PowerManager:GetPowersOfCategory(category)
	local all_powers = self:GetAllPowersInAcquiredOrder()
	local powers_of_category = {}
	for _, pow in ipairs(all_powers) do
		if pow.def.power_category == category then
			table.insert(powers_of_category, pow)
		end
	end

	return powers_of_category
end

function PowerManager:StripUnselectablePowers(list)
	local cleanlist = list
	for id, pow in ipairs(cleanlist) do
		if not pow.def.selectable then
			table.remove(cleanlist, id)
		end
	end
	return cleanlist
end

function PowerManager:HasPower(power_def)
	return self.data.powers[power_def.slot][power_def.name] ~= nil
end

function PowerManager:GetPower(power_def)
	return self.powers[power_def.name]
end

function PowerManager:HasSeenPower(power_def)
	return self.data.seen_powers[power_def.slot][power_def.name] ~= nil
end

function PowerManager:CanUpgradePower(power_def)
	if not power_def.upgradeable then return false end
	local pow = self:GetPower(power_def)
	local next_rarity = pow ~= nil and Power.GetNextRarity(pow.persistdata)
	return next_rarity ~= nil
end

function PowerManager:OnUpdatePower(power_def)
	if power_def.is_ready_fn then
		local pow = self:GetPower(power_def)
		if power_def.is_ready_fn(self.inst, pow) then
			self.ready_powers[pow] = true
			self.inst:PushEvent("power_ready_on")
		else
			self.ready_powers[pow] = nil
			if not next(self.ready_powers) then
				self.inst:PushEvent("power_ready_off")
			end
		end
	end
end

function PowerManager:IsPowerIgnored(power)
	return self.ignorepowers[power] ~= nil
end

function PowerManager:IgnorePower(power)
	self.ignorepowers[power] = true
end

function PowerManager:RemoveIgnorePower(power)
	self.ignorepowers[power] = nil
end

function PowerManager:_AreAllEventCallbacksTrue(callback)
	for _, def in pairs(self.event_triggers) do
		if def[callback] then
			if not def[callback](self.inst) then
				return false
			end
		end
	end
	return true
end
function PowerManager:CanStartDying()
	return self:_AreAllEventCallbacksTrue("canstartdying")
end

function PowerManager:CanActuallyDie()
	return self:_AreAllEventCallbacksTrue("canactuallydie")
end

-- queue up presentation elements that may want to be added during loading
-- but defer to post init
function PowerManager:QueuePresentation(fn)
	self.deferred_presentation_fns = self.deferred_presentation_fns or {}
	table.insert(self.deferred_presentation_fns, fn)
end

function PowerManager:Debug_GetPowerListing()
	return table.inspect(self.data.powers, { depth = 3, process = table.inspect.processes.skip_mt, })
end

function PowerManager:Debug_GiveAllPowers()
	for _,slot in pairs(Power.Items) do
		for name,power_def in pairs(slot) do
			if not self:HasPower(power_def) then
				self:AddPower(self:CreatePower(power_def))
			end
		end
	end
end

local dbg = {}

function PowerManager:DebugDrawEntity(ui, panel, colors)
	if ui:CollapsingHeader("Equipment Powers", ui.TreeNodeFlags.DefaultClosed) then
		ui:Indent()
		local SLOT_ORDER =
		{
			"WEAPON",
			"HEAD",
			"BODY",
			"WAIST"
		}
		for _, slot in ipairs(SLOT_ORDER) do
			local data = self.powers_from_equipment[slot]
			local overridden = self.overridden_equipment_slots[slot] ~= nil
			local str = string.format("%s : %s x %s [%s]", slot, data and data.name or "NONE", data and data.level or 0, overridden)
			ui:BulletText(str)
		end
		ui:Unindent()
	end
	-- panel:AppendTable(ui, self.powers_from_equipment, "powers_from_equipment")
	-- panel:AppendTable(ui, self.overridden_equipment_slots, "overridden_equipment_slots")

	if ui:CollapsingHeader("Give Power", ui.TreeNodeFlags.DefaultOpen) then
		ui:Indent() do
			local name_to_pretty = Power.GetQualifiedNamesToPrettyString()
			local pretty_to_name = lume.invert(name_to_pretty)
			local powers = lume.values(name_to_pretty)
			table.sort(powers)
			dbg.power = ui:_ComboAsString("Power##GivePowerName", dbg.power or powers[1], powers)
			dbg.stack = ui:_SliderInt("##GivePowerStack", dbg.stack or 1, 1, 10, "%d stacks")
			dbg.rarity = ui:_ComboAsString("Rarity##GivePower", dbg.rarity, Power.Rarities:Ordered())
			if ui:Button("Give Power##button") then
				local pwr = pretty_to_name[dbg.power]
				assert(pwr, dbg.power)
				c_power(pwr, dbg.rarity, dbg.stack, self.inst)
			end
		end ui:Unindent()
	end

	if ui:Button("Copy Power Data") then
		ui:SetClipboardText(self:Debug_GetPowerListing())
	end
	-- Use data.powers so it's ordered by slots.
	for slot,powerlist in iterator.sorted_pairs(self.data.powers) do
		local label = ("%s (%d)###%s"):format(slot, lume.count(powerlist), slot)
		if ui:CollapsingHeader(label) then
			ui:Indent()
			for power_name,power in iterator.sorted_pairs(powerlist) do
				panel:AppendTable(ui, self:GetPower(power:GetDef()), power_name)
			end
			ui:Unindent()
		end
	end
end

return PowerManager
