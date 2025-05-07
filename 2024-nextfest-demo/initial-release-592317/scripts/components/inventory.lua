-- This is not the player's inventory! You're looking for inventoryhoard.lua

local Equipment = require("defs.equipment")

-- TEMP TABLE TO PROOF OF CONCEPT
local TEMP_SLOT_BUILD_ORDER =
{
	-- the later slots will stomp the earlier slots
	"LEGS",
	"WAIST",
	"ARMS",
	"BODY",
	"SHOULDERS",
	"HEAD",
	"POTIONS",
	"TONICS",
	"FOOD",
	"WEAPON",
}

local Inventory = Class(function(self, inst)
	self.inst = inst
	self.equips = {}
	self.tags = {}
end)

function Inventory:HasTag(tag)
	return self.tags[tag] == true
end

-- This is network-synced
-- Returns "hammer", "polearm", etc. see Equipment.WeaponTag
function Inventory:GetEquippedWeaponTag()
	for _,tag in ipairs(Equipment.WeaponTag:Ordered()) do
		if self:HasTag(tag) then
			-- Should only have one weapon tag applied at a time (wouldn't have
			-- both spear and hammer equipped), so return first found.
			return tag
		end
	end
	if self:HasTag("weaponprototype") then
		return "weaponprototype"
	end
end

-- This is network-synced
-- Generally prefer this over:
--     local weapon = player.components.inventoryhoard:GetEquippedItem(Equipment.Slots.WEAPON)
--     return weapon:GetDef().weapon_type
-- ... because it's unwieldy and inventoryhoard is not network-synced
-- Returns "HAMMER", "POLEARM", etc. -- see constants.lua WEAPON_TYPE
-- TODO: someone -- consider reconciling codebase with WeaponTag
function Inventory:GetEquippedWeaponType()
	local tag = self:GetEquippedWeaponTag()
	-- need to special case for weapon prototype dev workflow
	if tag == "weaponprototype" then
		return WEAPON_TYPES.PROTOTYPE
	elseif tag ~= nil then
		return string.upper(tag)
	end
end

-- This is network-synced
-- Generally prefer this over the unsynced version:
--     player.components.inventoryhoard:GetEquippedItem(Equipment.Slots.WEAPON):GetDef()
function Inventory:GetEquippedWeaponDef()
	return Equipment.Items.WEAPON[self:GetEquip(Equipment.Slots.WEAPON)]
end

function Inventory:GetArmourDef(slot)
	return Equipment.Items[slot][self:GetEquip(slot)]
end

function Inventory:GetEquip(slot)
	return self.equips[slot]
end

function Inventory:Equip(slot, name)
	if self.equips[slot] == name then
		return
	end

	local needs_rebuild = false
	local old_item = self.equips[slot]

	local items = Equipment.Items[slot]
	if items == nil then
		print("[Inventory] Invalid equip slot: "..slot)
		return
	end

	local new_def = items[name]
	local old_def = old_item and items[old_item]

	if old_def and old_def.hidden_symbols then
		self:ClearEquipSlotSymbols(slot, old_def)
	end

	if new_def == nil and name ~= nil then
		print("[Inventory] Invalid "..slot.." item: "..name)
		return
	end

	local tagschanged = false
	local rebuildtags = self.equips[slot] ~= nil

	if new_def ~= nil then
		if not rebuildtags and new_def.tags ~= nil then
			--Just add our new tags
			for tag in pairs(new_def.tags) do
				if not self.tags[tag] then
					self.tags[tag] = true
					tagschanged = true
				end
			end
		end

		self.equips[slot] = name
	else
		self.equips[slot] = nil
	end

	self:ClearAllEquipSlots()
	-- needs_rebuild = true

	if rebuildtags then
		local oldtags = self.tags
		self.tags = {}

		for xslot, xname in pairs(self.equips) do
			local tags = Equipment.Items[xslot][xname].tags
			if tags ~= nil then
				for tag in pairs(tags) do
					if not self.tags[tag] then
						self.tags[tag] = true
						if oldtags[tag] then
							oldtags[tag] = nil
						else
							tagschanged = true
						end
					end
				end
			end
		end

		tagschanged = tagschanged or next(oldtags) ~= nil
	end

	if tagschanged then
		self.inst:PushEvent("inventorytagschanged", { slot = slot })
	end

	self.inst:PushEvent("fxtypechanged")
	self.inst:PushEvent("inventorychanged")

	self:RebuildCharacterArmour()

	return tagschanged
end

function Inventory:RebuildCharacterArmour()
	-- loop through all the armour the player has equipped
	-- pick priorities somehow (set in armour defs? maybe one slot always stomps another? ie: a body with sleeves will always stomp gloves with sleeves)
	local flags = {}
	for i, slot in ipairs(TEMP_SLOT_BUILD_ORDER) do
		local equipped_item = self.equips[slot]
		local items = Equipment.Items[slot]
		local def = equipped_item and items[equipped_item]
		if def then

			local equipmentdyer = self.inst.components.equipmentdyer
			local active_dye = nil
			if equipmentdyer then
				active_dye = equipmentdyer:GetActiveDye(slot, def.name)
			end

			self:OverrideEquipSlotSymbols(slot, def, flags, active_dye)
		end
	end
end

function Inventory:Debug_ForceEquipVisuals(dye_def)
	for i, slot in ipairs(TEMP_SLOT_BUILD_ORDER) do
		self:Equip(slot, dye_def.armour_set)
	end
	
	local flags = {}
	for i, slot in ipairs(TEMP_SLOT_BUILD_ORDER) do
		local equipped_item = self.equips[slot]
		local items = Equipment.Items[slot]
		local def = equipped_item and items[equipped_item]
	
		if def then
			self:OverrideEquipSlotSymbols(slot, def, flags, dye_def)
		end
	end
end

function Inventory:OverrideEquipSlotSymbols(slot, def, flags, active_dye)
	--print(string.format("~~~~~OverrideEquipSlotSymbols %s~~~~~", slot))

	local build = def.build
	if active_dye then
		build = active_dye.build_override
	end


	if build == nil then
		-- victorc: this call won't work (needs to be passed a def)
		self:ClearEquipSlotSymbols(slot)
		return
	end

	if def.symbol_flags then
		for flag, bool in pairs(def.symbol_flags) do
			flags[flag] = bool
		end
	end

	local symbols = def.symbol_overrides or Equipment.Symbols[slot]
	if symbols ~= nil then
		for i, symbol in ipairs(symbols) do
			-- print(string.format("~Trying to override %s with %s from build %s~", symbol, symbol, build))
			self.inst.AnimState:OverrideSymbol(symbol, build, symbol)
		end
	end

	if def.conditional_symbols then
		-- we're going to be adding to this table so we need a fresh table
		-- print("~~DOING CONDITIONAL SYMBOLS~~")
		local conditional_symbols = def.conditional_symbols(flags)
		for target, symbol in pairs(conditional_symbols) do
			-- print("Adding Conditional Sybmol:", symbol)
			-- print(string.format("~~Trying to override %s with %s from build %s~~", target, symbol, build))
			self.inst.AnimState:OverrideSymbol(target, build, symbol)
		end
	end

	if def.hidden_symbols then
		for _, symbol in ipairs(def.hidden_symbols) do
			self.inst.AnimState:HideSymbol(symbol)
		end
	end
end

function Inventory:ClearAllEquipSlots()
	for slot, symbols in pairs(Equipment.Symbols) do
		for i, symbol in ipairs(symbols) do
			self.inst.AnimState:ClearOverrideSymbol(symbol)
		end
	end
end

function Inventory:ClearEquipSlotSymbols(slot, def)
	local symbols = def.symbol_overrides or Equipment.Symbols[slot]
	if symbols ~= nil then
		for i = 1, #symbols do
			self.inst.AnimState:ClearOverrideSymbol(symbols[i])
		end
	end

	if def.hidden_symbols then
		for _, symbol in ipairs(def.hidden_symbols) do
			self.inst.AnimState:ShowSymbol(symbol)
		end
	end
end

function Inventory:OnSave()
	if next(self.equips) ~= nil then
		local equips = {}
		for slot, name in pairs(self.equips) do
			equips[slot] = name
		end
		return { equips = equips }
	end
end

function Inventory:OnLoad(data)
	if data ~= nil then
		for slot in pairs(Equipment.Slots) do
			local name = data.equips ~= nil and data.equips[slot] or nil
			self:Equip(slot, name)
		end
	end
end

function Inventory:OnNetSerialize()
	local e = self.inst.entity
	local slots = Equipment.GetOrderedSlots()
	for _i,slot in ipairs(slots) do
		e:SerializeString(self.equips[slot] or "")
	end
end

function Inventory:OnNetDeserialize()
	local e = self.inst.entity
	local slots = Equipment.GetOrderedSlots()
	for _i, slot in ipairs(slots) do
		local equip_name = e:DeserializeString()
		self:Equip(slot, equip_name ~= "" and equip_name or nil)
	end
end


function Inventory:GetDebugString()
	local str = ""
	local delim = "\n\tTags - "
	for tag in pairs(self.tags) do
		str = str..string.format("%s%s", delim, tag)
		delim = ", "
	end
	for slot in pairs(Equipment.Slots) do
		str = str.."\n\t["..slot.."]"
		local name = self.equips[slot]
		if name ~= nil then
			str = str.." - "..name
		end
	end
	return str
end

return Inventory
