local Power = require("defs.powers.power")
local lume = require "util.lume"
local itemforge = require "defs.itemforge"
local Equipment = require "defs.equipment"
local Cosmetic = require "defs.cosmetics.cosmetics"
local Currency = require "defs.currency"
local VendingMachine = require "components.vendingmachine"
local PowerDescriptionButton = require "widgets.ftf.powerdescriptionbutton"
local WorldPowerDescription = require "widgets.ftf.worldpowerdescription"
local FollowPower = require "widgets.ftf.followpower"
local Widget = require("widgets/widget")
local EquipmentComparisonScreen = require "screens.dungeon.equipmentcomparisonscreen"
local Consumable = require "defs.consumable"
local recipes = require "defs.recipes"
local UpgradeableItemWidget = require"widgets/ftf/upgradeableitemwidget"
local Text = require "widgets.text"
local SGPlayerCommon = require "stategraphs.sg_player_common"
local ConfirmDialog = require "screens.dialogs.confirmdialog"

local items = {}

-- ██████╗░██╗░░░██╗███╗░░██╗ ██╗████████╗███████╗███╗░░░███╗░██████╗
-- ██╔══██╗██║░░░██║████╗░██║ ██║╚══██╔══╝██╔════╝████╗░████║██╔════╝
-- ██████╔╝██║░░░██║██╔██╗██║ ██║░░░██║░░░█████╗░░██╔████╔██║╚█████╗░
-- ██╔══██╗██║░░░██║██║╚████║ ██║░░░██║░░░██╔══╝░░██║╚██╔╝██║░╚═══██╗
-- ██║░░██║╚██████╔╝██║░╚███║ ██║░░░██║░░░███████╗██║░╚═╝░██║██████╔╝
-- ╚═╝░░╚═╝░╚═════╝░╚═╝░░╚══╝ ╚═╝░░░╚═╝░░░╚══════╝╚═╝░░░░░╚═╝╚═════╝░

-- Run Items

items.potion = {
	name = STRINGS.UI.VENDING_MACHINE.SHOP_INVENTORY.potion, --Potion Refill
	cost = 50,
	currency = Currency.id.Run,
	crowd_fundable = true,
	details_fn = function() return VendingMachine.MakeTextWidget(STRINGS.UI.VENDING_MACHINE.SHOP_INVENTORY.potion) end,
	purchased_fn = function(vendingmachine)
		local potion = SpawnPrefab("potion_refill_single", vendingmachine)
		local product_details = vendingmachine.components.vendingmachine:GetProductDetails()
		potion:PushEvent("initialized_ware", {
			ware_name = vendingmachine.components.vendingmachine.ware_id,
			power = product_details[1],
			power_type = product_details[2]
		})
		return potion
	end,
}

items.upgrade = {
	name = STRINGS.UI.VENDING_MACHINE.SHOP_INVENTORY.upgrade, --Power Upgrade
	cost = 100,
	currency = Currency.id.Run,
	crowd_fundable = true,
	details_fn = function() return VendingMachine.MakeTextWidget(STRINGS.UI.VENDING_MACHINE.SHOP_INVENTORY.upgrade) end,
	purchased_fn = function(vendingmachine)
		return SpawnPrefab("relic_upgrade_single")
	end,
}

items.shield = {
	name = STRINGS.NAMES.concept_shield, --Shield
	cost = 25,
	currency = Currency.id.Run,
	crowd_fundable = true,
	summary_fn = function() return VendingMachine.MakeTextWidget(STRINGS.NAMES.concept_shield) end,
	purchased_fn = function(vendingmachine)
		return SpawnPrefab("shield_refill_single")
	end,
}

-- TODO @chrisp #vending - need glitz ware defintion
-- this manifests as a missing VendingMachine
items.glitz = nil

-- TODO @chrisp #vending - need loot ware defintion
-- this manifests as a missing VendingMachine
items.loot = nil

items.corestone = {
	name = STRINGS.NAMES.konjur_soul_lesser, --Corestone
	cost = 200,
	currency = Currency.id.Run,
	crowd_fundable = true,
	details_fn = function() return VendingMachine.MakeTextWidget(STRINGS.NAMES.konjur_soul_lesser) end,
	purchased_fn = function(vendingmachine)
		return SpawnPrefab("corestone_pickup_single", vendingmachine)
	end,
}

-- ██████╗░░█████╗░░██╗░░░░░░░██╗███████╗██████╗░ ██╗████████╗███████╗███╗░░░███╗░██████╗
-- ██╔══██╗██╔══██╗░██║░░██╗░░██║██╔════╝██╔══██╗ ██║╚══██╔══╝██╔════╝████╗░████║██╔════╝
-- ██████╔╝██║░░██║░╚██╗████╗██╔╝█████╗░░██████╔╝ ██║░░░██║░░░█████╗░░██╔████╔██║╚█████╗░
-- ██╔═══╝░██║░░██║░░████╔═████║░██╔══╝░░██╔══██╗ ██║░░░██║░░░██╔══╝░░██║╚██╔╝██║░╚═══██╗
-- ██║░░░░░╚█████╔╝░░╚██╔╝░╚██╔╝░███████╗██║░░██║ ██║░░░██║░░░███████╗██║░╚═╝░██║██████╔╝
-- ╚═╝░░░░░░╚════╝░░░░╚═╝░░░╚═╝░░╚══════╝╚═╝░░╚═╝ ╚═╝░░░╚═╝░░░╚══════╝╚═╝░░░░░╚═╝╚═════╝░

-- Power Items

local function MakePowerItem(vendingmachine)
	local poweritem = SpawnPrefab("power_pickup_single", vendingmachine)
	local product_details = vendingmachine.components.vendingmachine:GetProductDetails()
	poweritem:PushEvent("initialized_ware", {
		ware_name = vendingmachine.components.vendingmachine.ware_id,
		power = product_details[1],
		power_type = product_details[2]
	})

	return poweritem
end

local function MakePower(power_name)
	local power_def = lume(Power.GetAllPowers()):match(function(power) return power.name == power_name end):result()
	local power = itemforge.CreatePower(power_def)
	return power
end

function items.MakePowerDetailsWidgetFromPower(power)
	return WorldPowerDescription()
		:SetPower(MakePower(power), false, true)
		:SetScale(FollowPower.SCALE)
end

local function MakePowerDetailsWidget(vendingmachine)
	local details = vendingmachine.components.vendingmachine:GetProductDetails()
	local power_id = details[1]
	return items.MakePowerDetailsWidgetFromPower(power_id)
end

local function InitializePowerWare(vendingmachine, rng, power_type, rarity, include_lower_rarities)
	local powerdropmanager = TheWorld.components.powerdropmanager
	local power = powerdropmanager:GetPowerForMarket(power_type, rarity, include_lower_rarities, rng)
	if not power then
		return false
	end
	vendingmachine.power_type = power_type
	vendingmachine.power = power
	return true
end

items.legendary = {
	name = "",
	cost = 150,
	currency = Currency.id.Run,
	crowd_fundable = true,
	init_fn = function(vendingmachine, rng)
		return InitializePowerWare(
			vendingmachine, 
			rng, 
			Power.Types.RELIC, 
			Power.Rarity.LEGENDARY, 
			false
		)
	end,
	details_fn = MakePowerDetailsWidget,
	purchased_fn = MakePowerItem,
}

items.fabled = {
	name = "",
	cost = 150,
	currency = Currency.id.Run,
	crowd_fundable = true,
	init_fn = function(vendingmachine, rng)
		return InitializePowerWare(
			vendingmachine, 
			rng, 
			Power.Types.FABLED_RELIC, 
			Power.Rarity.LEGENDARY, 
			false
		)
	end,
	details_fn = MakePowerDetailsWidget,
	purchased_fn = MakePowerItem,
}

items.epic = {
	name = "",
	cost = 100,
	currency = Currency.id.Run,
	crowd_fundable = true,
	init_fn = function(vendingmachine, rng)
		return InitializePowerWare(
			vendingmachine, 
			rng, 
			Power.Types.RELIC, 
			Power.Rarity.EPIC, 
			false
		)
	end,
	details_fn = MakePowerDetailsWidget,
	purchased_fn = MakePowerItem,
}

items.common = {
	name = "",
	cost = 75,
	currency = Currency.id.Run,
	crowd_fundable = true,
	init_fn = function(vendingmachine, rng)
		return InitializePowerWare(
			vendingmachine, 
			rng, 
			Power.Types.RELIC, 
			Power.Rarity.COMMON, 
			false
		)
	end,
	details_fn = MakePowerDetailsWidget,
	purchased_fn = MakePowerItem,
}

items.skill = {
	name = "",
	cost = 75,
	currency = Currency.id.Run,
	crowd_fundable = true,
	init_fn = function(vendingmachine, rng)
		return InitializePowerWare(
			vendingmachine, 
			rng, 
			Power.Types.SKILL, 
			Power.Rarity.LEGENDARY, 
			true
		)
	end,
	details_fn = MakePowerDetailsWidget,
	purchased_fn = MakePowerItem,
}

-- TODO @chrisp #random_power - dead code?
items.random_power = nil
-- {
-- 	name = "",
-- currency = Currency.id.Run,
-- 	cost = 75, -- could be a bad roll if common, could be a great roll if Legendary.
	   -- TODO @jambell #vending true these power drops against each other
-- crowd_fundable = true,
-- 	init_fn = function(vendingmachine, rng)
-- 		local powerdropmanager = TheWorld.components.powerdropmanager
-- 		local power = powerdropmanager:GetPowerForMarket(Power.Types.SKILL, Power.Rarity.LEGENDARY, true, rng)

-- 		vendingmachine.power = power
-- 	end,
-- 	summary_fn = MakePowerPreviewWidget,
-- 	purchased_fn = MakePowerItem,
-- }

-- ███╗░░░███╗███████╗████████╗░█████╗░ ██╗████████╗███████╗███╗░░░███╗░██████╗
-- ████╗░████║██╔════╝╚══██╔══╝██╔══██╗ ██║╚══██╔══╝██╔════╝████╗░████║██╔════╝
-- ██╔████╔██║█████╗░░░░░██║░░░███████║ ██║░░░██║░░░█████╗░░██╔████╔██║╚█████╗░
-- ██║╚██╔╝██║██╔══╝░░░░░██║░░░██╔══██║ ██║░░░██║░░░██╔══╝░░██║╚██╔╝██║░╚═══██╗
-- ██║░╚═╝░██║███████╗░░░██║░░░██║░░██║ ██║░░░██║░░░███████╗██║░╚═╝░██║██████╔╝
-- ╚═╝░░░░░╚═╝╚══════╝░░░╚═╝░░░╚═╝░░╚═╝ ╚═╝░░░╚═╝░░░╚══════╝╚═╝░░░░░╚═╝╚═════╝░

-- Meta Items

-- NOTE @chrisp #vending - copy-pasta from equipmentcomparisonscreen.lua
local EquipmentPreview = Class(Widget, function(self, itemDef)
	Widget._ctor(self, "EquipmentPreview")

	self.width = 800 * HACK_FOR_4K
	self.height = 280 * HACK_FOR_4K

	self.itemDef = itemDef
	self.item = itemforge.CreateEquipment(self.itemDef.slot, self.itemDef)
	
	local recipe = recipes.FindRecipeForItemDef(self.itemDef)

	-- TODO @chrisp #interact - this is probably not an appropriate details widget as it contains player-specifics
	self.details = self:AddChild(UpgradeableItemWidget(self.width, nil, self.item, recipe, false, false, true))
end)

function EquipmentPreview:OnGainInteractFocus(player)
	self.details:SetPlayer(player)
end

local function MakeEquipmentDetailsWidget(ilvl, def)
	return EquipmentPreview(def)
end

local EQUIPMENT_COSTS <const> = {
	[Equipment.Slots.HEAD] = 1, -- TODO: try 2
	[Equipment.Slots.BODY] = 2, -- TODO: try 3
	[Equipment.Slots.WAIST] = 1, -- TODO: try 2
	[Equipment.Slots.WEAPON] = 3,
}

local WEAPON_LOCKED_MESSAGE <const> = {
	[WEAPON_TYPES.HAMMER] = STRINGS.UI.VENDING_MACHINE.WEAPON_LOCKED.HAMMER,
	[WEAPON_TYPES.POLEARM] = STRINGS.UI.VENDING_MACHINE.WEAPON_LOCKED.POLEARM,
	[WEAPON_TYPES.GREATSWORD] = STRINGS.UI.VENDING_MACHINE.WEAPON_LOCKED.GREATSWORD,
	[WEAPON_TYPES.CANNON] = STRINGS.UI.VENDING_MACHINE.WEAPON_LOCKED.CANNON,
	[WEAPON_TYPES.SHOTPUT] = STRINGS.UI.VENDING_MACHINE.WEAPON_LOCKED.SHOTPUT,
	[WEAPON_TYPES.PROTOTYPE] = STRINGS.UI.VENDING_MACHINE.WEAPON_LOCKED.PROTOTYPE,
}

items.equipment = {
	name = function(mannequin_inst)
		local details = mannequin_inst.components.vendingmachine:GetProductDetails()
		local def = Equipment.Items[details[1]][details[2]]
		return def.pretty.name
	end,
	currency = Currency.id.Meta,
	crowd_fundable = false,
	cost = function(mannequin_inst)
		local details = mannequin_inst.components.vendingmachine:GetProductDetails()
		local slot = details[1]
		return EQUIPMENT_COSTS[slot]
	end,
	details_fn = function(mannequin_inst)
		local details = mannequin_inst.components.vendingmachine:GetProductDetails()
		local def = Equipment.Items[details[1]][details[2]]
		return MakeEquipmentDetailsWidget(itemforge.GetILvl(def), def)
	end,
	can_purchase_fn = function(mannequin_inst, player)
		-- Can purchase only if we do not already own it.
		local details = mannequin_inst.components.vendingmachine:GetProductDetails()
		local def = Equipment.Items[details[1]][details[2]]
		if player.components.inventoryhoard:HasInventoryItem(def) then
			return false, STRINGS.UI.VENDING_MACHINE.ALREADY_PURCHASED
		end

		if def.slot == "WEAPON" then
			local unlock_tracker = player.components.unlocktracker
			-- TODO @chrisp #deadcode - armour locked check in vending machine
			-- Armours are not subject to locking/unlocking, it appears...
			-- local category = def.slot == "WEAPON"
			-- 	and UNLOCKABLE_CATEGORIES.s.WEAPON_TYPE
			-- 	or UNLOCKABLE_CATEGORIES.s.ARMOUR
			-- local id = def.slot == "WEAPON"
			-- 	and def.weapon_type
			-- 	or def.armour_type
			if not unlock_tracker:IsWeaponTypeUnlocked(def.weapon_type) then
				return false, string.format(WEAPON_LOCKED_MESSAGE[def.weapon_type])
			end
		end
		
		return true
	end,
	purchased_fn = function(mannequin_inst, player)
		local details = mannequin_inst.components.vendingmachine:GetProductDetails()
		local slot = details[1]
		local ware = details[2]
		local def = Equipment.Items[details[1]][details[2]]

		local cost = EQUIPMENT_COSTS[slot]
		player.components.inventoryhoard:AddStackable(Consumable.Items.MATERIALS.konjur_soul_lesser, cost) -- HACK: Add the currency back -- we don't actually want to spend this cost yet.

		local screen = EquipmentComparisonScreen(player, def, Consumable.Items.MATERIALS.konjur_soul_lesser, cost)
		TheFrontEnd:PushScreen(screen)
	end,
}

-- The string by which an equipmentdyer identifies the dye.
local function DyeName(dye_def)
	local armor_family = dye_def.armour_set
	local dye_number = dye_def.dye_number
	local dye_string = armor_family.."_dye_"..dye_number
	return dye_string
end

-- The string to display to the user that identifies the dye.
local function DyeLabel(dye_bottle)
	local details = dye_bottle.components.vendingmachine:GetProductDetails()
	local slot = details[1]
	local dye_id = details[2]
	local dye_def = Cosmetic.FindDyeByNameAndSlot(dye_id, slot)
	local armour_def = Equipment.Items[dye_def.armour_slot][dye_def.armour_set]
	return string.format(STRINGS.UI.VENDING_MACHINE.DYE_LABEL, armour_def.pretty.name, dye_def.dye_number)
end

local function MakeTextWidget(text)
	return Text(FONTFACE.DEFAULT, FONTSIZE.DAMAGENUM_PLAYER, "", UICOLORS.INFO)
		:SetShadowColor(UICOLORS.BLACK)
		:SetShadowOffset(1, -1)
		:SetOutlineColor(UICOLORS.BLACK)
		:EnableShadow()
		:EnableOutline()
		:SetText(text)
end

local function DyeDef(dye_bottle)
	local details = dye_bottle.components.vendingmachine:GetProductDetails()
	local slot = details[1]
	local dye_id = details[2]
	local dye_def = Cosmetic.FindDyeByNameAndSlot(dye_id, slot)
	return slot, dye_def
end

local function CanPurchaseDye(dye_bottle, player)
	local can = true
	local reasons
	local Check = function(condition, reason)
		if not condition then
			return
		end
		can = false
		if reasons then
			reasons = reasons.."\n"..reason
		else
			reasons = reason
		end
	end

	local armour_slot, dye_def = DyeDef(dye_bottle)
	local dye_name = DyeName(dye_def)
	local owned_slot_armours = player.components.inventoryhoard:GetSlotItems(armour_slot)
	local owned = lume(owned_slot_armours):any(function(owned_slot_armour) 
		return owned_slot_armour.id == dye_def.armour_set 
	end):result()
	Check(not owned, STRINGS.UI.VENDING_MACHINE.ARMOUR_UNOWNED)
	Check(
		player.components.unlocktracker:IsCosmeticPurchased(armour_slot, dye_name), 
		STRINGS.UI.VENDING_MACHINE.ALREADY_PURCHASED
	)
	return can, reasons
end

local DyeDetailsWidget = Class(Widget, function(self, dye_bottle)
	Widget._ctor(self, "Dye Bottle")
	self.dye_bottle = dye_bottle
	self.label = self:AddChild(MakeTextWidget(DyeLabel(dye_bottle)))
end)

function DyeDetailsWidget:OnGainInteractFocus(player)
	local slot, def = DyeDef(self.dye_bottle)
	player.components.unlocktracker:UnlockCosmetic(slot, DyeName(def))
end

-- A popup dialog that asks the user if they want to apply the newly purchased dye and does so if they say yes.
local function ApplyDyeDialog(dye_bottle, player)
	local dialog = ConfirmDialog(nil, nil, false, DyeLabel(dye_bottle), nil, STRINGS.UI.DYE_PURCHASE_POPUP.TEXT)
	dialog
		:SetYesButton(STRINGS.UI.DYE_PURCHASE_POPUP.YES_OPTION, function()
			local armour_slot, dye_def = DyeDef(dye_bottle)
			local dye_name = DyeName(dye_def)
			player.components.equipmentdyer:SetEquipmentDye(armour_slot, dye_def.armour_set, dye_name) -- TODO @jambell make 'dye_name' just take an int instead		
			SGPlayerCommon.Fns.CelebrateEquipment(player, 1)			
			dialog:Close()
		end)
		:SetNoButton(STRINGS.UI.DYE_PURCHASE_POPUP.NO_OPTION, function() dialog:Close() end)
		:HideArrow() -- An arrow can show under the dialog pointing at the clicked element
		:SetMinWidth(600)
		:CenterText() -- Aligns left otherwise
		:CenterButtons() -- They align left otherwise
		:Offset(0, -530)
	TheFrontEnd:PushScreen(dialog)
	dialog:AnimateIn()
end

items.dye = {
	name = DyeLabel,
	currency = Currency.id.Cosmetic,
	cost = 1500,
	crowd_fundable = false,
	details_fn = function(dye_bottle) return DyeDetailsWidget(dye_bottle) end,
	can_purchase_fn = CanPurchaseDye,
	purchased_fn = function(dye_bottle, player)
		local armour_slot, dye_def = DyeDef(dye_bottle)
		local dye_name = DyeName(dye_def)
		player.components.unlocktracker:PurchaseCosmetic(armour_slot, dye_name)

		-- Give player option of immediately applying the dye if they are wearing the armour
		local equipped_armour = player.components.inventoryhoard:GetEquippedItem(armour_slot)
		local equipped = equipped_armour and equipped_armour.id == dye_def.armour_set
		if equipped then
			ApplyDyeDialog(dye_bottle, player)
		end
	end,
}

items.healing_fountain = {
	name = STRINGS.UI.VENDING_MACHINE.HEALING_FOUNTAIN,
	crowd_fundable = true,
	currency = Currency.id.Health,
	price_tag_visibility_by_proximity = true,
	cost = function(healing_fountain)
		local HEALTH_PER_PLAYER <const> = 250
		return HEALTH_PER_PLAYER * TheNet:GetNrPlayersOnRoomChange()
	end,
}

return items
