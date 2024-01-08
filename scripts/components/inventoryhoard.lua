local Consumable = require "defs.consumable"
local Equipment = require "defs.equipment"
local EquipmentGem = require "defs.equipmentgems"
local itemforge = require "defs.itemforge"
local iterator = require "util.iterator"
local kassert = require "util.kassert"
local lume = require "util.lume"
local recipes = require "defs.recipes"
local Strict = require "util.strict"
require "util"
require "components.vendingmachine" -- for RequiredBitCount

local NUM_LOADOUTS = 5

local function create_default_data()
	local data =
	{
		-- unsorted lists of inventory items
		inventory = {
			-- Dict mapping slots to lists containing item instances:
			-- WEAPON = { { id = 'cleaver_basic' }, ... },
			-- HEAD   = { { id = 'bandicoot' }, ... },
		},

		loadouts = {
			-- List of dicts mapping slots to indexes in above inventory table:
			-- { WEAPON = 1, ... },
			-- { WEAPON = 2, ... },
		},
		selectedLoadoutIndex = 1,

		lastViewedInventorySlot = Equipment.Slots.WEAPON,

		maxPotionSlots = 5,

		acquire_index = 0,
	}

	for _,slot in pairs(Equipment.Slots) do
		data.inventory[slot] = {}
	end

	for _,slot in pairs(Consumable.Slots) do
		assert(not data.inventory[slot], "Equipment already provided slot ".. slot)
		data.inventory[slot] = {}
	end

	for _,slot in pairs(EquipmentGem.Slots) do
		assert(not data.inventory[slot], "Inventory Hoard already has slot ".. slot)
		data.inventory[slot] = {}
	end

	for i = 1, NUM_LOADOUTS do
		table.insert(data.loadouts, {})
	end
	return data
end

-- Total collection of everything the player's amassed -- not just what they're
-- wearing.
local InventoryHoard = Class(function(self, inst)
	self.inst = inst
	self.data = create_default_data()

	self._new_run_fn = function() self:_CrystallizeKonjur() end
	self.inst:ListenForEvent("start_new_run", self._new_run_fn)
	self._onget_loot = function(source, data) self:AddStackable(data.item, data.count) end
	self.inst:ListenForEvent("get_loot", self._onget_loot)
end)

local MaterialTypeNrBits = 3
local MaterialCountNrBits = 12

function InventoryHoard:OnNetSerialize()
	local e = self.inst.entity
	local slot_items = self.data.inventory[Consumable.Slots.MATERIALS] -- only care about specific slots
	local net_count = slot_items and lume.count(slot_items, function(x) return x:HasTag("netserialize") end) or 0
	e:SerializeUInt(net_count, MaterialTypeNrBits)

	if net_count > 0 then
		for _id,item in pairs(slot_items) do
			if item:HasTag("netserialize") then
				e:SerializeString(item.id)

				local count = item.count
				if count >= 1<<MaterialCountNrBits then
					TheLog.ch.Inventory:printf_once("too-many-items", "Trying to save too many items in inventoryhoard: Item=%s, nr=%d", item.id, count)
					count = (1<<MaterialCountNrBits)-1
				end

				e:SerializeUInt(count, MaterialCountNrBits)
			end
		end
	end

	self:SerializeEquipmentSlot(Equipment.Slots.BODY)
	self:SerializeEquipmentSlot(Equipment.Slots.HEAD)
	self:SerializeEquipmentSlot(Equipment.Slots.WAIST)
	self:SerializeEquipmentSlot(Equipment.Slots.WEAPON)
end

local EQUIPMENT_ITEM_COUNT_BIT_COUNT = RequiredBitCount(100)
local ILVL_BIT_COUNT = RequiredBitCount(11)

function InventoryHoard:SerializeEquipmentSlot(slot)
	local items = self.data.inventory[slot]
	local item_count = items and lume.count(items) or 0
	self.inst.entity:SerializeUInt(item_count, EQUIPMENT_ITEM_COUNT_BIT_COUNT)
	if item_count ~= 0 then
		lume(items):each(function(item)
			self.inst.entity:SerializeString(item.id)
			self.inst.entity:SerializeUInt(item.ilvl, ILVL_BIT_COUNT)
		end)
	end
end

function InventoryHoard:OnNetDeserialize()
	local e = self.inst.entity
	local slot_items = self.data.inventory[Consumable.Slots.MATERIALS]
	local net_count = e:DeserializeUInt(MaterialTypeNrBits)
	
	for _i=1,net_count do
		local id = e:DeserializeString()
		local count = e:DeserializeUInt(MaterialCountNrBits)

		local itemdef = slot_items[id] and slot_items[id]:GetDef() or Consumable.FindItem(id)
		local old_count = slot_items[id] and slot_items[id].count or 0
		dbassert(itemdef.tags["netserialize"])
		if old_count ~= count then
			self:AddStackable(itemdef, count - old_count)
		end
	end

	self:DeserializeEquipmentSlot(Equipment.Slots.BODY)
	self:DeserializeEquipmentSlot(Equipment.Slots.HEAD)
	self:DeserializeEquipmentSlot(Equipment.Slots.WAIST)
	self:DeserializeEquipmentSlot(Equipment.Slots.WEAPON)
end

function InventoryHoard:DeserializeEquipmentSlot(slot)
	local item_count = self.inst.entity:DeserializeUInt(EQUIPMENT_ITEM_COUNT_BIT_COUNT)
	local items = {}
	for i = 1, item_count do
		-- Build a lightweight proxy view of the remote equipment.
		local id = self.inst.entity:DeserializeString()
		local ilvl = self.inst.entity:DeserializeUInt(ILVL_BIT_COUNT)
		local item_proxy = {
			id = id,
			ilvl = ilvl, -- needed for Tuning:GetWeaponModifiers()
			slot = slot, -- needed for GetDef()
		}
		-- Add the ItemInstance meta-table so GetDef() works.
		itemforge.ConvertToRuntimeItem(item_proxy)
		table.insert(items, item_proxy)
	end
	self.data.inventory[slot] = items
end

function InventoryHoard:OnSave()
	local data = deepcopy(self.data)

	for slot_name, slot_items in pairs(data.inventory) do

		for _, item in ipairs(slot_items) do
			if item.gem_slots then
				for _, gem_slot in ipairs(item.gem_slots) do
					if gem_slot.gem then
						itemforge.ConvertToSaveableItem(gem_slot.gem)
					end
				end
			end
		end

		itemforge.ConvertToListOfSaveableItems(slot_items)
	end


	return data
end

function InventoryHoard:OnLoad(data)
	if data ~= nil then

		------------------
		-- Add slots that have been added after this save data was created.
		for _,slot in pairs(Equipment.Slots) do
			if not data.inventory[slot] then
				data.inventory[slot] = {}
			end
		end

		for _,slot in pairs(Consumable.Slots) do
			if not data.inventory[slot] then
				data.inventory[slot] = {}
			end
		end
		------------------

		kassert.typeof('table', data.inventory.WEAPON)
		for slot_name, slot_items in pairs(data.inventory) do
			itemforge.ConvertToListOfRuntimeItems(slot_items)

			for _, item in ipairs(slot_items) do
				if item.gem_slots then
					for _, gem_slot in ipairs(item.gem_slots) do
						if gem_slot.gem then
							itemforge.ConvertToRuntimeItem(gem_slot.gem)
						end
					end
				end
			end
		end

		self.data = data

		if DEV_MODE then
			self:RefreshItemStats()
		end
	end
end

function InventoryHoard:GetLastViewedSlot()
	if self.data.lastViewedInventorySlot == nil then
		self.data.lastViewedInventorySlot = Equipment.Slots.WEAPON
	end

	return self.data.lastViewedInventorySlot
end

function InventoryHoard:SetLastViewedSlot(slot)
	self.data.lastViewedInventorySlot = slot
end


function InventoryHoard:RefreshItemStats()
	for slot, items in pairs(self.data.inventory) do
		for i, item in ipairs(items) do
			if item.stats then
				item:RefreshItemStats()
			end
		end
	end
end

function InventoryHoard:OnPostLoadWorld(data)
	-- Clobber the inventory's loadout with ours.
	self:EquipSavedEquipment()
	if TheWorld:HasTag('town') then
		-- When you return to town, your konjur crystallizes into konjur.
		self:_CrystallizeKonjur()
	end
	-- Don't set this for join-in-progress spectators; the animstate should be blank
	-- TODO: networking2022, find a way to purge AnimState so it simply shows nothing
	if not self.inst:IsSpectating() then
		-- Our inventory is now fully loaded with the correct weapon, so force us
		-- to return to idle to ensure we're in the right sg.
		self.inst.sg:GoToState("idle")
	end
end

function InventoryHoard:_CrystallizeKonjur()
	local konjur = self:GetStackableCount(Consumable.Items.MATERIALS.konjur)
	if konjur > 0 then
		-- local recipe = recipes.ForSlot.MATERIALS.glitz
		-- recipe:CraftMaximumQuantityForPlayer(self.inst)
		-- Ensure there's none left.
		self:RemoveStackable(Consumable.Items.MATERIALS.konjur, konjur)
	end
end

function InventoryHoard:ResetData()
	self.data = create_default_data()
	self:GiveDefaultEquipment()
	self.data.selectedLoadoutIndex = 1
end

function InventoryHoard:EquipSavedEquipment()
	self:SwitchToLoadout(self.data.selectedLoadoutIndex)
end

function InventoryHoard:GetNumLoadouts()
	return #self.data.loadouts
end

function InventoryHoard:SwitchToLoadout(loadout_index)
	self.inst:PushEvent("loadout_change_imminent", loadout_index)	-- Fire an event BEFORE changing the loadout and resetting the stategraph to allow stategraphs to clean up after themselves.
	self.data.selectedLoadoutIndex = loadout_index
	self:OnLoadoutChanged()
end

function InventoryHoard:OnLoadoutChanged()
	local loadout = self:_GetLoadoutTable(self.data.selectedLoadoutIndex)
	for slot, _ in pairs(loadout) do
		local item = self:GetLoadoutItem(self.data.selectedLoadoutIndex, slot)
		local name = item and item:GetDef().name or nil
		self.inst.components.inventory:Equip(slot, name)
	end

	local modifier_name = "equipment_stats"

	local stats = self:ComputeStats()
	self.inst.components.health:SetBaseMaxHealth(stats.HP, true)
	self.inst.components.combat:SetBaseDamage(modifier_name, stats.DMG)
	self.inst.components.combat:SetCritChanceModifier(modifier_name, stats.CRIT)
	self.inst.components.combat:SetCritDamageMult(modifier_name, stats.CRIT_MULT)
	self.inst.components.combat:SetFocusDamageMult(modifier_name, stats.FOCUS_MULT)
	self.inst.components.locomotor:AddSpeedMult(modifier_name, stats.SPEED)
	self.inst.components.lucky:AddLuckMod(modifier_name, stats.LUCK)
	self.inst.components.combat:SetDungeonTierDamageReductionMult(modifier_name, stats.ARMOUR)
	self.inst.components.damagebonus.cached_stats = stats

	self.inst:PushEvent("loadout_changed", self.data.selectedLoadoutIndex)
end

function InventoryHoard:_GetLoadoutTable(loadout_index)
	assert(0 < loadout_index and loadout_index <= #self.data.loadouts)
	return self.data.loadouts[loadout_index]
end

function InventoryHoard:GetLoadoutItem(loadout_index, slot)
	kassert.typeof("string", slot)
	local loadout = self:_GetLoadoutTable(loadout_index)
	local index = loadout[slot]
	local category = self.data.inventory[slot]
	assert(category, "Bad slot: ".. slot)
	return category[index]
end

-- We don't store loadouts as lists of items, so offer this convenience to get
-- a view of a loadout.
function InventoryHoard:GetLoadout_Readonly(loadout_index)
	local loadout = self:_GetLoadoutTable(loadout_index)
	local copy = {}
	for slot,index in pairs(loadout) do
		copy[slot] = self.data.inventory[slot][index]
	end
	return copy
end

function InventoryHoard:SetLoadoutItem(loadout_index, slot, item_instance)
	kassert.typeof('string', slot)
	local inv = self.data.inventory[slot]
	local loadout = self:_GetLoadoutTable(loadout_index)
	if item_instance then
		kassert.typeof('table', item_instance)
		local index = lume.find(inv, item_instance)
		assert(index, "Setting loadout item that isn't in our hoard.")
		loadout[slot] = index
	else
		-- unequip
		assert(not Equipment.SlotDescriptor[slot].tags.required)
		loadout[slot] = -1
	end
end

-- This is NOT network-synced
function InventoryHoard:GetEquippedItem(slot)
	return self:GetLoadoutItem(self.data.selectedLoadoutIndex, slot)
end

function InventoryHoard:GetEquippedLoadout()
	return self:_GetLoadoutTable(self.data.selectedLoadoutIndex)
end

function InventoryHoard:NextLoadout(delta)
	delta = delta or 1
	self.data.selectedLoadoutIndex = circular_index_number(NUM_LOADOUTS, self.data.selectedLoadoutIndex + delta)
	self:SwitchToLoadout(self.data.selectedLoadoutIndex)
end

local slots_for_stats = lume.clone(Equipment.Slots)
lume.remove(slots_for_stats, Equipment.Slots.POTIONS)
lume.remove(slots_for_stats, Equipment.Slots.TONICS)
lume.remove(slots_for_stats, Equipment.Slots.FOOD)

-- Default stats for a player character, modifiable by equipment.
local DEFAULT_PLAYER_EQUIPMENT_STATS = lume.clone(EQUIPMENT_MODIFIER_DEFAULTS)
DEFAULT_PLAYER_EQUIPMENT_STATS.HP = TUNING.PLAYER_HEALTH
DEFAULT_PLAYER_EQUIPMENT_STATS.CRIT_MULT = TUNING.GEAR.WEAPONS.BASE_CRIT_DAMAGE_MULT
DEFAULT_PLAYER_EQUIPMENT_STATS.FOCUS_MULT = TUNING.GEAR.WEAPONS.BASE_FOCUS_DAMAGE_MULT
Strict.strictify(DEFAULT_PLAYER_EQUIPMENT_STATS)

-- Begin with DEFAULT_PLAYER_EQUIPMENT_STATS, then add stats from all equipped slots.
function InventoryHoard:ComputeStats()
	local item_stat_tables = lume(slots_for_stats)
		:map(function(slot)	return self:GetLoadoutItem(self.data.selectedLoadoutIndex, slot) end)
		:filter(function(item) return item ~= nil end)
		:map(function(item) return item:GetStats() end)
		:result()
		
	-- When we use itemforge to MakeWeaponStats() or MakeArmourStats(), we convert from PlayerModifiers
	-- to an untyped table with keys compatible for merging with equipment_modifiers.
	return ResolveModifiers(
		EQUIPMENT_MODIFIER_NAMES,
		DEFAULT_PLAYER_EQUIPMENT_STATS,
		table.unpack(item_stat_tables) -- unpack must be the final argument
	)
end

function InventoryHoard:GiveDefaultEquipment()
	self:_GiveEquipmentWithTags({ "starting_equipment" })
end

function InventoryHoard:Debug_GiveAllEquipment()
	for _, slot in pairs(Equipment.Slots) do
		lume.clear(self.data.inventory[slot])
	end
	self:_GiveEquipmentWithTags()
end

function InventoryHoard:Debug_GiveRelevantMaterials()
	local num_per_material = 10
	local tags = nil -- {"drops_resources"}
	local items = Consumable.GetItemList(Consumable.Slots.MATERIALS, tags)
	for _,mat in pairs(items) do
		if not mat.tags["hide"] then
			self:AddStackable(mat, num_per_material)
		end
	end
end

function InventoryHoard:Debug_GiveRelevantEquipment()
	for _, slot in pairs(Equipment.Slots) do
		lume.clear(self.data.inventory[slot])
	end
	for i, item in ipairs(itemforge.CreateAllEquipmentWithTags()) do
		if not item:GetDef().tags["hide"] then
			if item:GetDef().stackable then
				self:AddStackable(item:GetDef(), 5)
			else
				self:AddToInventory(item.slot, item)
			end
		end
	end

	-- Clobber all loadouts and populate with these default items.
	for loadout_index, loadout in ipairs(self.data.loadouts) do
		for _,slot in pairs(Equipment.GetOrderedSlots()) do
			self:SetLoadoutItem(loadout_index, slot, self.data.inventory[slot][1])
		end
	end
	-- Apply new equipment.
	self:SwitchToLoadout(1)
end

function InventoryHoard:Debug_GiveProps()
	local num_per_material = 1
	local tags = nil -- {"drops_resources"}
	local items = Consumable.GetItemList(Consumable.Slots.PLACEABLE_PROP, tags)
	for _,mat in pairs(items) do
		self:AddStackable(mat, num_per_material)
	end
end

function InventoryHoard:Debug_GiveKeyItems()
	local items = Consumable.GetItemList(Consumable.Slots.KEY_ITEMS)
	for _, def in pairs(items) do
		local item = itemforge.CreateKeyItem( def)
		self:AddToInventory(item.slot, item)
	end
end

function InventoryHoard:Debug_GiveMaterials()
	local num_per_material = 10
	local tags = nil -- {"drops_resources"}
	local items = Consumable.GetItemList(Consumable.Slots.MATERIALS, tags)
	for _,mat in pairs(items) do
		self:AddStackable(mat, num_per_material)
	end
end

function InventoryHoard:Debug_GiveGems()
	local tags = nil
	local items = EquipmentGem.GetItemList(EquipmentGem.Slots.GEMS, tags)
	for _, def in pairs(items) do
		local item = itemforge.CreateEquipment(def.slot, def)
		item.exp = 0
		self:AddToInventory(item.slot, item)
	end
end

function InventoryHoard:_GiveEquipmentWithTags(tags)
	for i, item in ipairs(itemforge.CreateAllEquipmentWithTags(tags)) do
		self:AddToInventory(item.slot, item)
	end

	-- Clobber all loadouts and populate with these default items.
	for loadout_index, loadout in ipairs(self.data.loadouts) do
		for _,slot in pairs(Equipment.GetOrderedSlots()) do
			self:SetLoadoutItem(loadout_index, slot, self.data.inventory[slot][1])
		end
	end
	-- Apply new equipment.
	self:SwitchToLoadout(1)
end

function InventoryHoard:AddToInventory(group, item_instance)
	kassert.typeof('table', item_instance)
	assert(item_instance.GetDef, "AddToInventory takes an ItemInstance")
	local t = self.data.inventory[group]
	kassert.typeof('table', t)
	table.insert(t, item_instance)
	self.inst:PushEvent("inventory_changed", {item = item_instance})
end


-- Returns the removed item.
function InventoryHoard:RemoveFromInventory(item_to_remove)
	assert(item_to_remove.GetDef, "RemoveFromInventory takes an ItemInstance")
	local category = item_to_remove.slot
	local cat = self.data.inventory[category]
	for i, item in ipairs(cat) do
		if item == item_to_remove then
			local loadouts = {}
			for loadout_index,loadout in ipairs(self.data.loadouts) do
				local index = loadout[category]
				if index == i then
					loadout[category] = nil
				end
				table.insert(loadouts, self:GetLoadout_Readonly(loadout_index))
			end
			local removed = table.remove(cat, i)
			if removed then
				-- Loadout uses indexes and if we removed something, the
				-- indexes might be out of date.
				for loadout_index,loadout in ipairs(loadouts) do
					for slot,equipped in pairs(loadout) do
						self:SetLoadoutItem(loadout_index, slot, equipped)
					end
				end
			end
			return removed
		end
	end
end

function InventoryHoard:_ModifyStackableCount(itemdef, quantity)
	local slot = self.data.inventory[itemdef.slot]
	local item = slot[itemdef.name]
	if item == nil then
		item = itemforge.CreateStack(itemdef.slot, itemdef)
		slot[itemdef.name] = item
		item.acquire_order = self.data.acquire_index
		self.data.acquire_index = self.data.acquire_index + 1
	end
	local before = item.count
	item.count = item.count + quantity
	if item.count <= 0 then
		slot[itemdef.name] = nil
	end
	self.inst:PushEvent("inventory_stackable_changed", itemdef)

	if not self.inst.components.unlocktracker:IsConsumableUnlocked(itemdef.name) then
		self.inst.components.unlocktracker:UnlockConsumable(itemdef.name)
	end

	return before, item.count
end

function InventoryHoard:AddStackable(itemdef, quantity, suppress_konjur_event)
	assert(itemdef.name, "AddStackable takes an item definition from Consumable.Items")
	self:_ModifyStackableCount(itemdef, quantity)

	self.inst:PushEvent("add_stackable", {def = itemdef, quantity = quantity})

	if not suppress_konjur_event then
		if itemdef.name == "konjur" then
			self.inst:PushEvent("gain_konjur", quantity)
		end
	end
end

-- Returns true if we previously had any of the item.
function InventoryHoard:RemoveStackable(itemdef, quantity)
	assert(itemdef.name, "RemoveStackable takes an item definition from Consumable.Items")

	if quantity == 0 then return true end

	local before,after = self:_ModifyStackableCount(itemdef, -quantity)
	return before > 0
end

function InventoryHoard:GetStackableCount(itemdef)
	assert(itemdef.name, "GetStackableCount takes an item definition from Consumable.Items")
	local slot = self.data.inventory[itemdef.slot]
	local item = slot[itemdef.name]
	if item then
		return item.count
	end
	return 0
end

function InventoryHoard:GetStackableListInAcquiredOrder(slot)
	local list = lume.filter(self.data.inventory[slot]) -- dict to array
	table.sort(list, function(a,b)
		return a.acquire_order < b.acquire_order
	end)
	return list
end

-- The item instance matching the input item def, nil if there is no match.
function InventoryHoard:GetInventoryItem(itemdef)
	assert(itemdef.name, "GetInventoryItem takes an item definition from Equipment.Items or Consumable.Items")
	local slot = self.data.inventory[itemdef.slot]
	local item = lume.match(slot, function(item)
		return item:GetDef() == itemdef
	end)
	return item
end

-- Whether this inventory contains input item def.
function InventoryHoard:HasInventoryItem(itemdef)
	assert(itemdef.name, "HasInventoryItem takes an item definition from Equipment.Items or Consumable.Items")
	if self:GetStackableCount(itemdef) > 0 then
		return true
	end
	return self:GetInventoryItem(itemdef) ~= nil
end

-- Whether this inventory contains input item def.
function InventoryHoard:GetMaterialsWithTag(tag)
	local materials = {}
	for id, item in pairs(self.data.inventory["MATERIALS"]) do
		local def = Consumable.FindItem(id)
		if def and def.tags[tag] then
			table.insert(materials, item)
		end
	end
	return materials
end

function InventoryHoard:GetSlotItems(slot)
	return self.data.inventory[slot]
end

-- Returns all gems, including ones equipped in weapons
-- Sorted by level and exp
function InventoryHoard:GetAllGems()
	local gems = {}

	-- Get gems in inventory
	for k, gem in ipairs(self.data.inventory["GEMS"]) do
		gem.equipped_in = nil
		table.insert(gems, gem)
	end

	-- Go through weapons and get the gems in them too
	for k, weapon in ipairs(self.data.inventory["WEAPON"]) do
		if weapon.gem_slots then
			for i, gem_slot in ipairs(weapon.gem_slots) do
				if gem_slot.gem then
					gem_slot.gem.equipped_in = weapon.id
					table.insert(gems, gem_slot.gem)
				end
			end
		end
	end

	-- Sort gems by level and exp
	table.sort(gems, function(a, b)
		if a.ilvl == b.ilvl then
			if a.exp == b.exp then
				return a.id > b.id
			end
			return a.exp > b.exp
		end
		return a.ilvl > b.ilvl
	end)

	return gems
end

function InventoryHoard:Debug_EquipWeaponByName(name)
	local item = lume.match(self.data.inventory.WEAPON, function(item)
		return item:GetDef().name == name
	end)
	if item then
		self:SetLoadoutItem(self.data.selectedLoadoutIndex, Equipment.Slots.WEAPON, item)
		self:EquipSavedEquipment()
	else
		self:Debug_GiveItem(Equipment.Slots.WEAPON, name, 1, true)
	end
end

-- Perfect for using in debug tools that spawn a fake player.
function InventoryHoard:Debug_CopyWeaponFrom(player)
	local weapon = player.components.inventoryhoard:GetEquippedItem(Equipment.Slots.WEAPON)
	self:Debug_EquipWeaponByName(weapon.id)
end

function InventoryHoard:Debug_GiveItem(slot, name, count, should_equip)
	if Equipment.Slots[slot] then
		-- ignore count. we only allow one of each item.
		local def = Equipment.Items[slot][name]
		if not def then
			print("Couldn't find Equipment:", slot, name)
			return false
		end
		local item = itemforge.CreateEquipment(slot, def)
		assert(item)
		print("giving", self.inst, item.id)
		self:AddToInventory(item.slot, item)
		if should_equip then
			self:SetLoadoutItem(self.data.selectedLoadoutIndex, slot, item)
			self:EquipSavedEquipment()
		end
		return true

	elseif Consumable.Slots[slot] then
		-- ignore should_equip, you cannot equip consumables.
		local def = Consumable.Items[slot][name]
		if not def then
			print("Couldn't find consumable:", slot, name)
			return false
		end
		print("giving", self.inst, def.name)
		self:AddStackable(def, count or 1)
		return true
	elseif EquipmentGem.Slots[slot] then
		-- ignore should_equip, you cannot equip consumables.
		local def = EquipmentGem.Items[slot][name]
		if not def then
			print("Couldn't find gem:", slot, name)
			return false
		end
		local item = itemforge.CreateEquipment(slot, def)
		assert(item)
		self:AddToInventory(item.slot, item)
		return true
	end
	print("Unknown slot:", slot)
end

function InventoryHoard:GetDebugString()
	--~ if true then return table.inspect(self.data, { depth = 4, }) end
	local loadout = self:_GetLoadoutTable(self.data.selectedLoadoutIndex)
	local str = ""
	for slot,idx in iterator.sorted_pairs(loadout) do
		local item = self.data.inventory[slot][idx]
		if item then
			str = str .. ("\n\t%s: %s"):format(slot, item.id)
		end -- else this slot is naked
	end
	return str
end

function InventoryHoard:DebugDrawEntity(ui, panel, colors)
	local loadout = self:_GetLoadoutTable(self.data.selectedLoadoutIndex)
	ui:Columns(2)
	for slot,idx in iterator.sorted_pairs(loadout) do
		local item = self.data.inventory[slot][idx]
		local name = item and item.id or "<empty>"
		ui:Value(slot, name)
		ui:NextColumn()
		panel:AppendTable(ui, item, "item##".. name)
		ui:SameLineWithSpace()
		panel:AppendTable(ui, item and item:GetDef(), "def##".. name)
		ui:NextColumn()
	end
	ui:Columns(1)
end

function InventoryHoard:Debug_RemoveByName(slot, item_name)
	local item_def = Equipment.Items[slot][item_name]

	if item_def == nil then
		print ("COULD NOT FIND DEFINITION FOR ITEM ", item_name)
		return
	end

	self:RemoveFromInventory(self:GetInventoryItem(item_def))
end


--- Calculates the delta in a stat between the currently equipped item and a given item.
-- Result is how much improvement we get from switching to item.
-- Receives both item and slot because item may be nil (for naked).
 function InventoryHoard:DiffStatsAgainstEquipped(item, slot)
	-- print("DiffStatsAgainstEquipped:", slot)
	-- assert(slot)
	local selectedLoadoutIndex = self.data.selectedLoadoutIndex
	local equipped_item = self:GetLoadoutItem(selectedLoadoutIndex, slot)
	if item and equipped_item then
		-- diff is item - equipped_item so we see how much improvement we get from item.
		local delta, equipped_stats = item:DiffStats(equipped_item)
		return delta, equipped_stats
	elseif item then
		-- If we have no equipped item, we gain all the new item's stats.
		return item:DiffStats()
	elseif equipped_item then
		-- If we have no selected item, we lose all our equipped stats.
		local delta, equipped_stats = equipped_item:InverseStats()
		for stat,val in pairs(delta) do
			equipped_stats[stat] = equipped_stats[stat] + val
		end
		return delta, equipped_stats
	else
		return {}, {}
	end
end

return InventoryHoard
