local krandom = require "util.krandom"
local Power = require("defs.powers.power")
local lume = require "util.lume"
local itemforge = require "defs.itemforge"
local Equipment = require "defs.equipment"
local Cosmetic = require "defs.cosmetics.cosmetics"
local Strict = require "util.strict"
local vending_machine_wares = require"defs/vendingmachine_wares"
local VendingMachine = require "components.vendingmachine"

require "prefabs.customscript.waredispenser"

SHOP_TUNING =
{
	DUNGEON_MARKET =
	{
		 --bank choice: when the other types are not rolled, they get increased chance to roll next time. that % comes from this choice

		-- Guaranteed high value power
		HIGH_TIER_POWER = {
			CHANCES = -- starting drop chances
			{
				legendary = 50,
				fabled = 50, --bank
			},

			CHANCE_INCREASE = -- when these types are NOT rolled, how much more likely should seeing one of them become next roll? measured in %
			{
				legendary = 30,
				fabled = 0, --bank
			},
			BANK_CHOICE = "fabled",
		},

		-- A grab bag of various items from any category.
		-- Normal powers, run items, meta items, or rarely perhaps even another legendary power.
		GRAB_BAG = {
			CHANCES = -- starting drop chances
			{
				random_power = 5,
				skill = 7,
				common = 15,
				legendary = 3,
				fabled = 2,
				upgrade = 13,
				potion = 10,
				shield = 5,
				epic = 40, --bank
			},

			CHANCE_INCREASE = -- when these types are NOT rolled, how much more likely should seeing one of them become next roll? measured in %
			{
				random_power = 2,
				skill = 3,
				common = 5,
				legendary = 1,
				fabled = 1,
				upgrade = 5,
				potion = 5,
				shield = 3,
				epic = 0, --bank
			},
			BANK_CHOICE = "epic",
		},

		-- Guaranteed run item of some kind.
		RUN_ITEMS = {
			CHANCES = -- starting drop chances
			{
				-- First drop is always an Epic
				upgrade = 50,
				potion = 50, --bank
			},

			CHANCE_INCREASE = -- when these types are NOT rolled, how much more likely should seeing one of them become next roll? measured in %
			{
				upgrade = 25,
				potion = 0, --bank
			},
			BANK_CHOICE = "potion",
		},

		-- Guaranteed meta item of some kind.
		META = {
			CHANCES = -- starting drop chances
			{
				glitz = 25,
				loot = 25,
				corestone = 50, --bank
			},

			CHANCE_INCREASE = -- when these types are NOT rolled, how much more likely should seeing one of them become next roll? measured in %
			{
				glitz = 10,
				loot = 10,
				corestone = 0, --bank
			},
			BANK_CHOICE = "corestone",
		},
	},
}


local WARES_LIST =
{
	DUNGEON_MARKET =
	{
		"HIGH_TIER_POWER",
		"GRAB_BAG",
		"GRAB_BAG",
		"RUN_ITEMS",
		"META",
	},

	META_MARKET =
	{
		ARMOUR =
		{
			Equipment.Slots.HEAD,
			Equipment.Slots.BODY,
			Equipment.Slots.WAIST,
		},
		WEAPON = 1,
	},

	DYE_MARKET =
	{
		ARMOUR =
		{
			Equipment.Slots.HEAD,
			Equipment.Slots.BODY,
			Equipment.Slots.WAIST,
		},
	},
}

local ShopManager = Class(function(self, inst)
	self.inst = inst
	self.shop_data = {}
	self.initialized = false
	self.pending_ware_dispensers = {}
	self.markets = {}
	for _, market in ipairs(Market:Ordered()) do
		self.markets[market] = {}
	end
	Strict.strictify(self.markets)
end)

ShopManager.LoggingEnabled = false
function ShopManager:Log(...)
	if ShopManager.LoggingEnabled then
		TheLog.ch.ShopManager:printf(...)
	end
end

function ShopManager:LogShopData()
	if ShopManager.LoggingEnabled then
		dumptable(self.shop_data)
	end
end

function ShopManager:ResetAllWareChances()
	self:ResetAllDungeonWareChances()
end

function ShopManager:FillMarkets(rng)
	local rng = rng or krandom.CreateGenerator(TheDungeon:GetDungeonMap():GetCurrentRoomSeed())
	self.markets.Run = self:GenerateDungeonWares("DUNGEON_MARKET", rng)
	self.markets.Meta = self:GenerateMetaWares(TheSceneGen.components.scenegen.dungeon, rng)
	self.markets.Dye = self:GenerateDyeWares(TheSceneGen.components.scenegen.dungeon, rng)
	if ShopManager.LoggingEnabled then
		self:Log("--------------------------")
		self:Log("Markets")
		self:Log("--------------------------")
		dumptable(self.markets)
		self:Log("--------------------------")
	end
end

function ShopManager:SpawnWareDispenser(prop, transform, ware_args)
	local SPAWN_FUNCTIONS <const> = {
		[Market.s.Run] = ShopManager.SpawnVendingMachine,
		[Market.s.Meta] = ShopManager.SpawnMannequin,
		[Market.s.Dye] = ShopManager.SpawnDyeDispenser,
	}
	Strict.strictify(SPAWN_FUNCTIONS)
	local spawn_function = SPAWN_FUNCTIONS[ware_args.market]
	dbassert(spawn_function, "Unhandled Market variant: "..ware_args.market)
	spawn_function(self, prop, ware_args.index, transform:GetWorldPosition())
end

--------
--[[
  ____     _   _   _   _     ____  U _____ u U  ___ u  _   _          __  __      _       ____      _  __  U _____ u  _____   
 |  _"\ U |"|u| | | \ |"| U /"___|u\| ___"|/  \/"_ \/ | \ |"|       U|' \/ '|uU  /"\  uU |  _"\ u  |"|/ /  \| ___"|/ |_ " _|  
/| | | | \| |\| |<|  \| |>\| |  _ / |  _|"    | | | |<|  \| |>      \| |\/| |/ \/ _ \/  \| |_) |/  | ' /    |  _|"     | |    
U| |_| |\ | |_| |U| |\  |u | |_| |  | |___.-,_| |_| |U| |\  |u       | |  | |  / ___ \   |  _ <  U/| . \\u  | |___    /| |\   
 |____/ u<<\___/  |_| \_|   \____|  |_____|\_)-\___/  |_| \_|        |_|  |_| /_/   \_\  |_| \_\   |_|\_\   |_____|  u |_|U   
  |||_  (__) )(   ||   \\,-._)(|_   <<   >>     \\    ||   \\,-.    <<,-,,-.   \\    >>  //   \\_,-,>> \\,-.<<   >>  _// \\_  
 (__)_)     (__)  (_")  (_/(__)__) (__) (__)   (__)   (_")  (_/      (./  \.) (__)  (__)(__)  (__)\.)   (_/(__) (__)(__) (__)
]]


function ShopManager:GenerateDungeonWares(market, rng)
	self:Log("GenerateDungeonWares for [%s]", market)

	local wares = {}

	for i,category in ipairs(WARES_LIST[market]) do
		local ware_name = self:GetDungeonWareForCategory(market, category, rng)
		local ware_data = vending_machine_wares[ware_name]

		-- Resolve init_fns at generation time.
		local vending_machine_proxy = {}
		if ware_data and ware_data.init_fn then
			ware_data.init_fn(vending_machine_proxy)
		end

		table.insert(wares, {
			name = ware_name,
			power_type = vending_machine_proxy.power_type,
			power = vending_machine_proxy.power		
		})
	end

	return wares
end

local z_offset = -8
local debug_machines = {}

function ShopManager:_SpawnVendingMachine(prop, ware, x, y, z)
	local vending_machine = SpawnPrefab(prop)

	-- TODO @chrisp #vending - I think we should be able to get rid of this
	vending_machine.power = ware.power

	vending_machine.components.vendingmachine:Initialize(ware.name, ware.power, ware.power_type)
	vending_machine.Transform:SetPosition(x, y, z)
	return vending_machine
end

function ShopManager:DebugTestWares(rng)
	local wares = self:GenerateDungeonWares("DUNGEON_MARKET", rng)
	local x_offset = -10
	for i,ware in ipairs(wares) do
		local ware_data = vending_machine_wares[ware.name]
		if ware_data then
			-- TODO @chrisp #vending - this debug code has rotted as the code around it has developed
			local vending_machine = self:_SpawnVendingMachine(prop, ware, 0 + x_offset, 0, 0 + z_offset)
			x_offset = x_offset + 5
			table.insert(debug_machines, vending_machine)
		end
	end
	z_offset = z_offset + 10
end

function ShopManager:SpawnVendingMachine(prop, index, x, y, z)
	local ware = self.markets.Run[index] or "common"
	local ware_data = vending_machine_wares[ware.name]
	return ware_data and self:_SpawnVendingMachine(prop, ware, x, y, z)
end

function ShopManager:GetDungeonWareForCategory(market, category, rng)
	if not self.initialized then
		self:Log("Resetting shop data")
		self:ResetAllDungeonWareChances()
		self.initialized = true
	end

	local choices = self.shop_data[market][category].CHANCES
	local sorted_keys = lume.sort(lume.keys(choices), function(a,b) return choices[a] > choices[b] end)

	local total = self:SumPercents(category, choices)
	local roll = total - rng:Float(total)
	self:Log("ShopManager:GetDungeonWareForCategory %s, %s", total, roll)

	local last_choice
	local picked_choice

	local previous_percentage = 0

	for i, ware in ipairs(sorted_keys) do
		if picked_choice then break end
		local chance = choices[ware]
		local tweaked_percentage = chance + SHOP_TUNING.DUNGEON_MARKET[category].CHANCES[ware]
		self:Log("-Rolling for %s, (%s + %s = %s)", ware, chance, SHOP_TUNING.DUNGEON_MARKET[category].CHANCES[ware], tweaked_percentage)
		if roll <= (tweaked_percentage + previous_percentage) and not picked_choice then
			self:Log("--Picked Choice: %s", ware)
			picked_choice = ware
		end
		last_choice = ware
		previous_percentage = tweaked_percentage
	end

	if not picked_choice then
		picked_choice = last_choice
	end

	for choice, percent in pairs(choices) do
		if choice ~= picked_choice then
			-- increase the percents of everything that didn't drop
			self:IncreaseDungeonWareChance(market, category, choice)
		else
			-- reset the percents of what did drop
			self:ResetDungeonWareChance(market, category, choice)
		end
	end

	self:Log("Chosen Reward: %s", picked_choice)
	self:LogShopData()
	return picked_choice
end

-- Increase an individual choice's chances by taking some chance away from the bank choice for that category.
-- If the bank is already at 0, then do not increase any further.
function ShopManager:IncreaseDungeonWareChance(market, category, choice)
	local bankchoice = self.shop_data[market][category].BANK_CHOICE

	if choice ~= bankchoice then
		self:Log("ShopManager:IncreaseDungeonWareChance(%s, %s). Subtracting from [%s]", category, choice, bankchoice)

		local chance_adjustment = self.shop_data[market][category].CHANCE_INCREASE[choice]
		local bank_remaining = self.shop_data[market][category].CHANCES[bankchoice]
		if chance_adjustment > bank_remaining then
			-- If there's not enough left in the bank, don't take any further
			chance_adjustment = bank_remaining
		end

		if chance_adjustment > 0 then
			self.shop_data[market][category].CHANCES[choice] = self.shop_data[market][category].CHANCES[choice] + chance_adjustment
			self.shop_data[market][category].CHANCES[bankchoice] = self.shop_data[market][category].CHANCES[bankchoice] - chance_adjustment
			self:Log("- INCREASED: %s: %s (+%s)", choice, self.shop_data[market][category].CHANCES[choice], chance_adjustment)
			self:Log("- DECREASED: %s: %s (-%s)", bankchoice, self.shop_data[market][category].CHANCES[bankchoice], chance_adjustment)
		else
			self:Log("- No bank remaining. Not adjusting.")
		end
	end
end

-- Reset an individual choice's chances and put the value back into the bankchoice for that category.
function ShopManager:ResetDungeonWareChance(market, category, choice)
	local bankchoice = self.shop_data[market][category].BANK_CHOICE

	if choice ~= bankchoice then
		local amount_to_reset = self.shop_data[market][category].CHANCES[choice]
		self.shop_data[market][category].CHANCES[bankchoice] = self.shop_data[market][category].CHANCES[bankchoice] + amount_to_reset
		self.shop_data[market][category].CHANCES[choice] = 0
		self:Log("ShopManager:ResetDungeonWareChance(%s) [%s -> %s] [%s -> %s]", category, choice, self.shop_data[market][category].CHANCES[choice], bankchoice, self.shop_data[market][category].CHANCES[bankchoice])
	end
end

function ShopManager:ResetAllDungeonWareChances()
	self.shop_data = deepcopy(SHOP_TUNING) --TODO: place in tuning table
end

function ShopManager:SumPercents(category, choices)
	local total = 0
	self:Log("SumPercents", category)
	for choice, percentage in pairs(choices) do
		total = total + percentage
	end
	local msg = ("[ShopManager] [%s] Percents should sum to 100. They sum to [%s]"):format(category, total)
	dbassert(total == 100, msg)
	return total
end

function ShopManager:RollPower(type, rarity, include_lower_rarities)
	local powerdropmanager = TheWorld.components.powerdropmanager
	local options = Power.GetAllPowers()
	options = powerdropmanager:FilterByType(options, type)
	options = powerdropmanager:FilterByAllHas(options)
	options = powerdropmanager:FilterByDroppable(options)
	options = powerdropmanager:FilterByAnyEligible(options)
	options = powerdropmanager:FilterByPlayerCount(options)
	options = powerdropmanager:FilterByAnyUnlocked(options)

	local choice = powerdropmanager:GetRandomPowerOfRarity(options, rarity, include_lower_rarities)

	return choice
end

---------------------------------------------------------------------------------------------------
--[[
  __  __  U _____ u  _____      _           __  __      _       ____      _  __  U _____ u  _____   
U|' \/ '|u\| ___"|/ |_ " _| U  /"\  u     U|' \/ '|uU  /"\  uU |  _"\ u  |"|/ /  \| ___"|/ |_ " _|  
\| |\/| |/ |  _|"     | |    \/ _ \/      \| |\/| |/ \/ _ \/  \| |_) |/  | ' /    |  _|"     | |    
 | |  | |  | |___    /| |\   / ___ \       | |  | |  / ___ \   |  _ <  U/| . \\u  | |___    /| |\   
 |_|  |_|  |_____|  u |_|U  /_/   \_\      |_|  |_| /_/   \_\  |_| \_\   |_|\_\   |_____|  u |_|U   
<<,-,,-.   <<   >>  _// \\_  \\    >>     <<,-,,-.   \\    >>  //   \\_,-,>> \\,-.<<   >>  _// \\_  
 (./  \.) (__) (__)(__) (__)(__)  (__)     (./  \.) (__)  (__)(__)  (__)\.)   (_/(__) (__)(__) (__)
]]

local function CountUnlockedPlayers(weapon_type)
	return lume(TheNet:GetPlayersOnRoomChange())
		:filter(function(player)
			return player.components.unlocktracker:IsWeaponTypeUnlocked(weapon_type)
		end)
		:count()
		:result()
end

local function CountUnlockedButUnownedPlayers(weapon_def)
	return lume(TheNet:GetPlayersOnRoomChange())
		:filter(function(player)
			return player.components.unlocktracker:IsWeaponTypeUnlocked(weapon_def.weapon_type)
				and not player.components.inventoryhoard:HasInventoryItem(weapon_def)
		end)
		:count()
		:result()
end

local function CompareWeaponMetaWares(a, b)
	-- Order weapons as follows:
	-- 1) unlocked and unowned by all players
	-- 2) unlocked by all players and unowned by some player
	-- 3) unlocked and unowned by some player
	-- 4) locked by some player
	-- 5) locked by all players

	if a.unlocked_but_unowned_count == b.unlocked_but_unowned_count then		
		-- Most unlocked weapons move to the front.
		return a.unlock_count > b.unlock_count
	else
		-- Move the weapons that are unlocked but unowned to the front.
		return a.unlocked_but_unowned_count > b.unlocked_but_unowned_count
	end
end

function ShopManager:GenerateMetaWares(location, rng)
	-- ARMOUR
	local armor_slot_lists = lume(WARES_LIST.META_MARKET.ARMOUR)
		:map(function(category)
			return self:GetSlotItemsForLocation(category, location)
		end)
		:result()
	local armours = lume.concat(table.unpack(armor_slot_lists))
	rng:Shuffle(armours)

	-- WEAPON;
	local weapons = lume(self:GetSlotItemsForLocation(Equipment.Slots.WEAPON, location))
		:map(function(weapon_def)
			return {
				def = weapon_def,
				unlock_count = CountUnlockedPlayers(weapon_def.weapon_type),
				unlocked_but_unowned_count = CountUnlockedButUnownedPlayers(weapon_def),
			}
		end)
		:result()
	rng:Shuffle(weapons)
	weapons = lume.sort(weapons, CompareWeaponMetaWares)
	weapons = lume(weapons)
		:map(function(ware) return ware.def	end)
		:result()

	-- Remove items that all players own.
	local meta_wares = lume.concat(armours, weapons)
	meta_wares = self:_FilterItemsByAllOwned(meta_wares)
	return meta_wares
end

function ShopManager:GetSlotItemsForLocation(slot, location)
	local valid_defs = {}
	local defs = itemforge.GetItemDefsBySlot(slot)

	for i, def in ipairs(defs) do
		if def.crafting_data
			and def.crafting_data.craftable_location
			and table.contains(def.crafting_data.craftable_location, location)
		then
			table.insert(valid_defs, def)
		end
	end

	self:Log("-=-=-= Possible entries for [%s] in [%s] =-=-=-", slot, location)

	return valid_defs
end


local MANNEQUINS <const> = {
	[Equipment.Slots.HEAD] = { anim = "armor_head", ui_y_offset_delta = 0.25, },
	[Equipment.Slots.BODY] = { anim = "armor_upper", ui_y_offset_delta = 0.25, },
	[Equipment.Slots.WAIST] = { anim = "armor_lower", ui_y_offset_delta = 0.25, },	

	-- Each weapon type has a unique anim
	[WEAPON_TYPES.HAMMER] = { anim = "weapon_hammer", ui_y_offset_delta = 1, },
	[WEAPON_TYPES.POLEARM] = { anim = "weapon_polearm", ui_y_offset_delta = 2.5, },
	[WEAPON_TYPES.GREATSWORD] = { anim = "weapon_polearm", ui_y_offset_delta = 2.5, },
	[WEAPON_TYPES.CANNON] = { anim = "weapon_cannon", ui_y_offset_delta = 1, },
	[WEAPON_TYPES.SHOTPUT] = { anim = "weapon_shotput", ui_y_offset_delta = 0, },
}
Strict.strictify(MANNEQUINS)

function ShopManager:_SpawnMannequin(prop, slot, ware_name, x, y, z)
	local def = Equipment.Items[slot][ware_name]
	local mannequin = SpawnPrefab(prop, self.inst)

	mannequin.Transform:SetPosition(x, y, z)

	local mannequin_config

	if slot == "WEAPON" then
		-- Use the polearm weapon rack if this mannequin has no ware.
		local weapon_type = def and def.weapon_type or WEAPON_TYPES.POLEARM
		mannequin_config = MANNEQUINS[weapon_type]
	else
		mannequin_config = MANNEQUINS[slot]
	end

	local anim = mannequin_config.anim
	if def ~= nil then
		-- If there is an item on the mannequin, set it up to be interactable.
		mannequin.components.inventory:Equip(slot, ware_name)
		mannequin.components.vendingmachine:Initialize(
			"equipment", 
			slot, 
			ware_name, 
			VendingMachine.DEFAULT_UI_Y_OFFSET + mannequin_config.ui_y_offset_delta
		)
		anim = anim.."_on"
	else
		anim = anim.."_off"
	end

	mannequin.AnimState:PlayAnimation(anim)

	return mannequin
end

-- Array-like table of equipment slots, indexed by index (as specified in spawner_waredispensers).
local EQUIPMENT_SLOTS <const> = {
	Equipment.Slots.HEAD,
	Equipment.Slots.BODY,
	Equipment.Slots.WAIST,
	Equipment.Slots.WEAPON
}

function ShopManager:_SpawnMannequinFromWares(prop, wares, index, x, y, z)
	-- Choose the first ware that matches the slot for this index (the list of wares was shuffled on construction).
	local slot = EQUIPMENT_SLOTS[index]
	local ware_name
	for i, ware in ipairs(wares) do
		if ware.slot == slot then
			ware_name = wares[i].name
			table.remove(wares, i) -- Mutate self.markets.Meta to no longer include this ware.
			break
		end
	end

	-- If there are no wares to display for this slot, show an empty mannequin.
	return self:_SpawnMannequin(prop, slot, ware_name, x, y, z)
end

function ShopManager:PROTO_CreateMannequins(location, rng)
	local wares = self:GenerateMetaWares(location, rng)
	local x_offset = 0
	for i, slot in ipairs(EQUIPMENT_SLOTS) do
		self:_SpawnMannequinFromWares(wares,-10 + x_offset, 0, -10 + z_offset)
		x_offset = x_offset + 4
	end
	z_offset = z_offset + 10
end

function ShopManager:SpawnMannequin(prop, index, x, y, z)
	return self:_SpawnMannequinFromWares(prop, self.markets.Meta, index, x, y, z)
end

-- Remove all items that all present players own.
function ShopManager:_FilterItemsByAllOwned(items)
	local players = TheNet:GetPlayersOnRoomChange()
	local num_players = #players

	return lume.filter(items, function(def)
		local owners = 0
		for _, player in ipairs(players) do
			if player.components.inventoryhoard:HasInventoryItem(def) then
				owners = owners + 1
			end
		end
		-- print("item:", def.name, "owners", owners, "num_players", num_players, "returning", owners < num_players)
		return owners < num_players
	end)
end

function ShopManager:ResetAllMetaWareChances()
	-- self.shop_data = deepcopy(SHOP_TUNING) --TODO: place in tuning table
end

--[[
  ____   __   __U _____ u      __  __      _       ____      _  __  U _____ u  _____   
 |  _"\  \ \ / /\| ___"|/    U|' \/ '|uU  /"\  uU |  _"\ u  |"|/ /  \| ___"|/ |_ " _|  
/| | | |  \ V /  |  _|"      \| |\/| |/ \/ _ \/  \| |_) |/  | ' /    |  _|"     | |    
U| |_| |\U_|"|_u | |___       | |  | |  / ___ \   |  _ <  U/| . \\u  | |___    /| |\   
 |____/ u  |_|   |_____|      |_|  |_| /_/   \_\  |_| \_\   |_|\_\   |_____|  u |_|U   
  |||_ .-,//|(_  <<   >>     <<,-,,-.   \\    >>  //   \\_,-,>> \\,-.<<   >>  _// \\_  
 (__)_) \_) (__)(__) (__)     (./  \.) (__)  (__)(__)  (__)\.)   (_/(__) (__)(__) (__) 

Dye Market

]]

function ShopManager:GenerateDyeWares(location, rng)
	local wares = {}

	-- ARMOUR
	for i,category in ipairs(WARES_LIST.DYE_MARKET.ARMOUR) do

		local valid_ids = {}
		local valid_items = self:GetSlotItemsForLocation(category, location)
		for i,item in ipairs(valid_items) do
			table.insert(valid_ids, item.name)
		end

		wares[category] = {}
		local all_dyes = Cosmetic.EquipmentDyes[category]
		for id,dyes in pairs(all_dyes) do
			if table.contains(valid_ids, id) then
				for dye_id,dye_data in pairs(dyes) do
					table.insert(wares[category], dye_id)
				end
			end
		end

		-- TODO @jambell: filter that list of cosmetics by "ones everyone owns"
		-- TODO(jambell): sort by most un-owned, and weight towards that?
		-- TODO(jambell): care about rarity?

		wares[category] = rng:Shuffle(wares[category])
	end

	return wares
end

-- Array-like table of dye slots, indexed by index (as specified in spawner_waredispensers).
local DYE_SLOTS <const> = {
	Equipment.Slots.HEAD,
	Equipment.Slots.BODY,
	Equipment.Slots.WAIST
}

function ShopManager:_SpawnDyeDispenser(prop, slot, dye_id, x, y, z)
	-- If no dye_def is present, show no dispenser whatsoever.
	if not dye_id then
		return
	end

	local dye_def = Cosmetic.FindDyeByNameAndSlot(dye_id, slot)

	-- TODO @jambell lots of concatenation here which I don't love. Simplify dye system to be number based instead of string based

	local armor_family = dye_def.armour_set
	local dye_number = dye_def.dye_number

	local dyebottle = SpawnPrefab(prop, self.inst)

	local anim
	local symbol_slot

	local build = "armor_"..armor_family.."_dye_"..dye_number
	if slot == Equipment.Slots.HEAD then
		anim = "dye_bottle_helmet"
		symbol_slot = "HEAD"
	elseif slot == Equipment.Slots.BODY then
		anim = "dye_bottle_body"
		symbol_slot = "BODY"
	elseif slot == Equipment.Slots.WAIST then
		anim = "dye_bottle_waist"
		symbol_slot = "WAIST"
	end

	dyebottle.components.vendingmachine:Initialize("dye", slot, dye_id)

	dyebottle.components.networkedsymbolswapper:OverrideSymbolSlot(symbol_slot, build)
	-- dyebottle.AnimState:OverrideSymbol(symbol, build, symbol)
	dyebottle.AnimState:PlayAnimation(anim)

	dyebottle.Transform:SetPosition(x, y, z)

	return dyebottle
end

function ShopManager:_SpawnDyeDispenserFromWares(prop, wares, index, x, y, z)
	local slot = DYE_SLOTS[index]
	local wares = wares and wares[slot]
	local ware
	if wares then
		ware = wares[1]
		table.remove(wares, 1) -- Mutate self.markets.Dye to no longer include this ware.
	end

	-- If there are no wares to display for this slot, show some "empty slot" representation.
	return self:_SpawnDyeDispenser(prop, slot, ware, x, y, z)
end

function ShopManager:PROTO_CreateDyeBottles(location, rng)
	local wares = self:GenerateDyeWares(location, rng)
	local x_offset = -5
	for i = 1, #DYE_SLOTS do
		TheDungeon:GetDungeonMap().shopmanager:_SpawnDyeDispenserFromWares(wares, i, x_offset, 0, 0)
		x_offset = x_offset + 5
	end
end

function ShopManager:SpawnDyeDispenser(prop, index, x, y, z)
	if next(self.markets.Dye) then
		return self:_SpawnDyeDispenserFromWares(prop, self.markets.Dye, index, x, y, z)
	end
end


function ShopManager:SaveData()
	self:Log("Saving Data...")
	return {
		shop_data = deepcopy(self.shop_data),
		initialized = self.initialized,
		markets = deepcopyskipmeta(self.markets)
	}
end

function ShopManager:LoadData(data)
	self:Log("Loading Data...")
	self.shop_data = deepcopy(data.shop_data)
	self.initialized = data.initalized
	self.markets = data.markets
	Strict.strictify(self.markets)
end

return ShopManager

--[[

Shopkeeper:

Shows up in a room in the dungeon.
Has a few shops:

Shopkeeper 1 (Meta Shop)
	Armour Shop
		Roll 3 armour pieces

	Dye Shop
		Roll 5 dyes

	Weapon Shop
		Roll 1 weapon

Shopkeeper 2 (Dungeon Shop)
	Options
		Powers
			1 High Tier
				- legendary power
				- fabled power
			3 Middle Tier
				- epic power
				- common power
				- random power
				- skill power
				- corestone
				- loot
		Other
			1 High Tier
				- potion upgrade
				- power upgrade
				- heal

	Sell Power for Teffra



From Caley/Marcus:
Top-of-pyramid answers:
	one-time use dungeon-only weapons/armor that you can use for the dungeon
	armor oils
	unique quest items
	buy/remove curses
Bottom of pyramid answers:
	remove powers for teffra
	shop-only skills
	(unique?) monster loot

From Sloth:
magpie is a thief and keeps stealing from the town, the villagers ask if you've seen it and starts a quest. the magpie sells it back to you, but asks for random things that you have aquired in your run. like corestones/ teffra/ or mob drops
the magpie is a weapons courrier and can bring you a differnt weapons mid run in exchange for teffra
the magpie is a scout that can let you select the rooms after the next room
the magpie is a trickster that extorts you for items or he lures difficult enemies to your next fight
]]
