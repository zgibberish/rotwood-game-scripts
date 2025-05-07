local Power = require("defs.powers.power")
local lume = require "util.lume"
local itemforge = require "defs.itemforge"
local Equipment = require "defs.equipment"
local Cosmetic = require "defs.cosmetics.cosmetics"
local Currency = require "defs.currency"
local VendingMachine = require "components.vendingmachine"
local PowerDescriptionButton = require "widgets.ftf.powerdescriptionbutton"
local FollowPower = require "widgets.ftf.followpower"
local Widget = require("widgets/widget")
local EquipmentComparisonScreen = require "screens.dungeon.equipmentcomparisonscreen"
local Consumable = require "defs.consumable"
local recipes = require "defs.recipes"
local UpgradeableItemWidget = require"widgets/ftf/upgradeableitemwidget"
local Text = require "widgets.text"
local SGPlayerCommon = require "stategraphs.sg_player_common"

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

items.glitz = nil

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
	return PowerDescriptionButton()
		:SetPower(MakePower(power), false, true)
		:SetUnclickable()
		:SetScale(FollowPower.SCALE)
end

local function MakePowerDetailsWidget(vendingmachine)
	local details = vendingmachine.components.vendingmachine:GetProductDetails()
	local power_id = details[1]
	return items.MakePowerDetailsWidgetFromPower(power_id)
end

items.legendary = {
	name = "",
	cost = 150,
	currency = Currency.id.Run,
	crowd_fundable = true,
	init_fn = function(vendingmachine)
		local powerdropmanager = TheWorld.components.powerdropmanager
		local power = powerdropmanager:GetPowerForMarket(Power.Types.RELIC, Power.Rarity.LEGENDARY, false)
		vendingmachine.power_type = Power.Types.RELIC
		vendingmachine.power = power
	end,
	details_fn = MakePowerDetailsWidget,
	purchased_fn = MakePowerItem,
}

items.fabled = {
	name = "",
	cost = 150,
	currency = Currency.id.Run,
	crowd_fundable = true,
	init_fn = function(vendingmachine)
		local powerdropmanager = TheWorld.components.powerdropmanager
		local power = powerdropmanager:GetPowerForMarket(Power.Types.FABLED_RELIC, Power.Rarity.LEGENDARY, false)
		vendingmachine.power_type = Power.Types.FABLED_RELIC
		vendingmachine.power = power
	end,
	details_fn = MakePowerDetailsWidget,
	purchased_fn = MakePowerItem,
}

items.epic = {
	name = "",
	cost = 100,
	currency = Currency.id.Run,
	crowd_fundable = true,
	init_fn = function(vendingmachine)
		local powerdropmanager = TheWorld.components.powerdropmanager
		local power = powerdropmanager:GetPowerForMarket(Power.Types.RELIC, Power.Rarity.EPIC, false)
		vendingmachine.power_type = Power.Types.RELIC
		vendingmachine.power = power
	end,
	details_fn = MakePowerDetailsWidget,
	purchased_fn = MakePowerItem,
}

items.common = {
	name = "",
	cost = 75,
	currency = Currency.id.Run,
	crowd_fundable = true,
	init_fn = function(vendingmachine)
		local powerdropmanager = TheWorld.components.powerdropmanager
		local power = powerdropmanager:GetPowerForMarket(Power.Types.RELIC, Power.Rarity.COMMON, false)
		vendingmachine.power_type = Power.Types.RELIC
		vendingmachine.power = power
	end,
	details_fn = MakePowerDetailsWidget,
	purchased_fn = MakePowerItem,
}

items.skill = {
	name = "",
	cost = 75,
	currency = Currency.id.Run,
	crowd_fundable = true,
	init_fn = function(vendingmachine)
		local powerdropmanager = TheWorld.components.powerdropmanager
		local power = powerdropmanager:GetPowerForMarket(Power.Types.SKILL, Power.Rarity.LEGENDARY, true)
		vendingmachine.power_type = Power.Types.SKILL
		vendingmachine.power = power
	end,
	details_fn = MakePowerDetailsWidget,
	purchased_fn = MakePowerItem,
}

items.random_power = nil
-- {
-- 	name = "",
-- currency = Currency.id.Run,
-- 	cost = 75, -- could be a bad roll if common, could be a great roll if Legendary.
	   -- TODO @jambell #vending true these power drops against each other
-- crowd_fundable = true,
-- 	init_fn = function(vendingmachine)
-- 		local powerdropmanager = TheWorld.components.powerdropmanager
-- 		local power = powerdropmanager:GetPowerForMarket(Power.Types.SKILL, Power.Rarity.LEGENDARY, true)

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
	self.details = self:AddChild(UpgradeableItemWidget(self.width, nil, self.item, recipe, false, false, true))
end)

function EquipmentPreview:SetPlayer(player)
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
			return false, "already own it"
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
				return false, string.format("Weapon type (%s) is locked", def.weapon_type)
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
	local slot, dye_def = DyeDef(dye_bottle)

	-- Can purchase only if you do not have it equipped.
	local equipped_item = player.components.inventoryhoard:GetEquippedItem(slot)
	local equipped = equipped_item and equipped_item.id == dye_def.armour_set
	if not equipped then
		return false, STRINGS.UI.VENDING_MACHINE.CANNOT_DYE
	end
	local dye_name = DyeName(dye_def)
	return not player.components.equipmentdyer:IsDyeEquipped(slot, dye_def.armour_set, dye_name), STRINGS.UI.VENDING_MACHINE.ALREADY_DYED
end

local DyeDetailsWidget = Class(Widget, function(self, dye_bottle)
	Widget._ctor(self, "Dye Bottle")
	self.dye_bottle = dye_bottle
	self.label = self:AddChild(MakeTextWidget(DyeLabel(dye_bottle)))
	self.warning = self:AddChild(MakeTextWidget("<Placeholder Dye Warning>"))
		:SetScale(0.75)
end)

function DyeDetailsWidget:SetPlayer(player)
	local can, reason =  CanPurchaseDye(self.dye_bottle, player) 
	if can then
		self.warning:Hide()
	else
		self.warning
			:SetText(reason)
			:LayoutBounds("center", "below", self.label)
			:Offset(0, 10)
			:Show()
	end
end

items.dye = {
	name = DyeLabel,
	currency = Currency.id.Cosmetic,
	cost = 1500,
	crowd_fundable = false,
	details_fn = function(dye_bottle) return DyeDetailsWidget(dye_bottle) end,
	can_purchase_fn = CanPurchaseDye,
	purchased_fn = function(dye_bottle, player)
		local slot, dye_def = DyeDef(dye_bottle)
		local dye_name = DyeName(dye_def)
		player.components.equipmentdyer:SetEquipmentDye(slot, dye_def.armour_set, dye_name) -- TODO @jambell make 'dye_name' just take an int instead		

		-- Delay the player emote by a few ticks to allow them to drop out of the "interacting" state first.
		SGPlayerCommon.Fns.CelebrateEquipment(player, 1)
	end,
}

return items
