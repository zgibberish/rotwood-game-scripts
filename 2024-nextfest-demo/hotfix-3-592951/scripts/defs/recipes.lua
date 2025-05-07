local Constructable = require "defs.constructable"
local Consumable = require "defs.consumable"
local Equipment = require "defs.equipment"
local EquipmentGem = require("defs.equipmentgems")
local itemcatalog = require "defs.itemcatalog"
local itemforge = require "defs.itemforge"
local kassert = require "util.kassert"
local lume = require "util.lume"
local soundutil = require "util.soundutil"
local fmodtable = require "defs.sound.fmodtable"

require "class"

local function GetInventory(player)
	return player.components.inventoryhoard
end

local recipes = {
	ForSlot = {
		PRICE = {},
	},
}

for _, slot in pairs(itemcatalog.All.Slots) do
	recipes.ForSlot[slot] = {}
end

-- Uncountable means if you already have one, you can"t craft another because
-- they don"t stack or sort as separate items.
local uncountable_categories = lume.invert({
		-- Until we have a reason to have multiple of one equipment (degradation, leveling up, etc).
		Equipment,
	})

local Recipe = Class(function(self, category, slot, name, ...)
	local def
	if slot == "PRICE" then
		def = {
			name = name,
			is_price = true,
		}
	else
		def = category.Items[slot][name]
	end
	assert(def, ("Invalid item to build: %s.%s"):format(slot, name))
	self.def = def
	self.slot = slot
	self.is_uncountable = uncountable_categories[category]
	self.count = 1
	self.ingredients = {}
	for i, ing in ipairs({ ... }) do
		self:AddIngredient(ing)
	end
end)

function Recipe:AddUpgradeLevel(level, ingredients)
	-- Is this a recipe to upgrade a piece of equipment?
	self.upgrade_levels[level] = ingredients
end

function Recipe:SetCount(count)
	self.count = count
end

function Recipe:GetCount()
	return self.count
end

function Recipe:GetDef()
	return self.def
end

function Recipe:AddIngredient(ing)
	assert(not self.ingredients[ing.name], ("Duplicate ingredient '%s' in '%s.%s'."):format(ing.name, self.slot, ing.name))
	self.ingredients[ing.name] = ing.count
end

function Recipe:CanPlayerCraft(player)
	local hoard = GetInventory(player)
	if self.slot ~= "PRICE" and self.is_uncountable and hoard:HasInventoryItem(self.def) then
		return false, STRINGS.NPC_DIALOG.ALREADY_OWNED
	end
	for ing_name, needs in pairs(self.ingredients) do
		local mat = Consumable.Items.MATERIALS[ing_name]
		local count = hoard:GetStackableCount(mat)
		if count < needs then
			return false, STRINGS.NPC_DIALOG.RESOURCES_MISSING
		end
	end
	return true
end

function Recipe:CanPlayerCraft_Detailed(player)
	local req = {}
	local hoard = GetInventory(player)
	for ing_name, needs in pairs(self.ingredients) do
		local mat = Consumable.Items.MATERIALS[ing_name]
		local count = hoard:GetStackableCount(mat)
		table.insert(req, {
				name = ing_name,
				def = mat,
				needs = needs,
				count = count,
				has_enough = count >= needs,
			})
	end
	-- TODO(dbriscoe): Sort to put konjur first
	return req
end

function Recipe:GiveIngredientsToPlayer(player)
	local hoard = GetInventory(player)
	for ing_name, needs in pairs(self.ingredients) do
		local mat = Consumable.Items.MATERIALS[ing_name]
		hoard:AddStackable(mat, needs)
	end
end

function Recipe:TakeIngredientsFromPlayer(player)
	local hoard = GetInventory(player)
	for ing_name, needs in pairs(self.ingredients) do
		local mat = Consumable.Items.MATERIALS[ing_name]
		local success = hoard:RemoveStackable(mat, needs)
		--soundutil.PlayRemoveItemSound(player, mat.remove_sound, needs)
		kassert.assert_fmt(
			success,
			"Called %s:TakeIngredientsFromPlayer(), but player didn't have sufficient materials: needs %s %s",
			self.def.name,
			needs,
			ing_name
		)
	end
end

function Recipe:CraftItemForPlayer(player, skip_equip)
	assert(not self.is_price, "You cannot craft PRICE items. Use TakeIngredientsFromPlayer instead.")
	self:TakeIngredientsFromPlayer(player)

	local slot = self.slot

	if slot == "PRICE" then
		return
	end

	local hoard = GetInventory(player)
	local item = itemforge.CreateEquipment(slot, self.def)

	if slot == "GEMS" then
		-- TEMP FOR DEMO UNTIL PROPER GEM CRAFTING FLOW CAN BE ADDED
		item.exp = 0
	end

	if self.def.stackable then
		hoard:AddStackable(self.def, self:GetCount())
	else
		hoard:AddToInventory(slot, item)
		if not skip_equip then
			kassert.assert_fmt(
				itemcatalog.All.SlotDescriptor[self.slot] and itemcatalog.All.SlotDescriptor[self.slot].tags.equippable,
				"Trying to equip non equipment item. %s %s",
				self.slot,
				self.def.name
				)
			hoard:SetLoadoutItem(hoard.data.selectedLoadoutIndex, slot, item)
			hoard:EquipSavedEquipment()
		end
	end

	if slot == Consumable.Slots.MATERIALS or slot == Consumable.Slots.PLACEABLE_PROP then
	else
	end

	return item
end

function Recipe:CraftMaximumQuantityForPlayer(player, skip_equip)
	local count = 0
	while self:CanPlayerCraft(player) do
		self:CraftItemForPlayer(player, skip_equip)
		count = count + 1
	end
	return count
end

local function Ingredient(name, count)
	local mat = Consumable.Items.MATERIALS[name]
	assert(mat, ("Invalid material: %s"):format(name))
	kassert.typeof("number", count)
	return {
		name = name,
		count = count,
	}
end

function recipes.add(recipe)
	assert(recipe)
	local def = recipe.def
	assert(recipe.slot)
	assert(def.name)
	recipes.ForSlot[recipe.slot][def.name] = recipe
end


function recipes.FindRecipeForItem(item)
	local name = item.name or item
	for slot, allrecipes in pairs(recipes.ForSlot) do
		for recipename, recipe in pairs(allrecipes) do
			if name == recipename then
				return recipe
			end
		end
	end
end

function recipes.FindRecipeForItemDef(def)
	for slot, allrecipes in pairs(recipes.ForSlot) do
		for recipename, recipe in pairs(allrecipes) do
			if recipe:GetDef() == def then
				return recipe
			end
		end
	end
end

function recipes.FindUpgradeRecipeForItem(item)
	local name = string.format("%s_upgrade_%s", item:GetDef().name, item:GetUsageLevel())
	for recipename, recipe in pairs(recipes.ForSlot.PRICE) do
		if name == recipename then
			return recipe
		end
	end
end

function recipes.FindRecipesForSlots(slots)
	local recipe_list = {}

	for _, slot in ipairs(slots) do
		recipe_list[slot] = shallowcopy(recipes.ForSlot[slot])
	end

	return recipe_list
end

function recipes.FilterRecipesByCraftable(recipes, player)
	-- takes a list of recipes & a player, returns a list of recipes that that player can currently craft.
	recipes = lume.filter(recipes, function(recipe)
		-- TODO: remove the world and check individually for unlocks
		local is_unlocked = player.components.unlocktracker:IsRecipeUnlocked(recipe.def.name)
		return is_unlocked and recipe:CanPlayerCraft(player)
	end)

	return recipes
end

local RECIPE_COSTS = {}
RECIPE_COSTS.WEAPON = TUNING.CRAFTING.WEAPON
RECIPE_COSTS.HEAD = TUNING.CRAFTING.ARMOUR_MEDIUM --ARMOUR_SMALL
RECIPE_COSTS.BODY = TUNING.CRAFTING.ARMOUR_MEDIUM --ARMOUR_LARGE
RECIPE_COSTS.WAIST = TUNING.CRAFTING.ARMOUR_MEDIUM --ARMOUR_LARGE
RECIPE_COSTS.FOOD = TUNING.CRAFTING.FOOD
RECIPE_COSTS.TONICS = TUNING.CRAFTING.TONICS
RECIPE_COSTS.PRICE = TUNING.CRAFTING.ARMOUR_UPGRADE_PATH

local ILVL_COST_MULT = 0.1
local function GetScaledCost(cost, ilvl)
	return math.floor(cost + (cost * ((ilvl-1) * ILVL_COST_MULT)))
end

function AddRecipeForItem(slot, name, def, formula, is_upgrade)
	local recipe = Recipe(Equipment, slot, name)

	local ilvl = def.ilvl or 1
	formula = formula or RECIPE_COSTS[slot][def.rarity]
	local count = RECIPE_COSTS[slot].COUNT or 1

	if count > 1 then
		assert(def.stackable, string.format("Tried to make a recipe that gives multiple of a non-stackable item [%s]", def.name))
		recipe:SetCount(count)
	end

	-- t = type
	-- r = rarity
	-- a = amount
	-- tags = extra tags for the items to refine further

	for _, ing in ipairs(formula) do
		if ing.t == INGREDIENTS.s.CURRENCY then
			local takes_currency = true
			if def.crafting_data ~= nil and def.crafting_data.ignore_currency_cost then
				takes_currency = false
			end

			if takes_currency then
				local currency_items = Consumable.GetItemList(Consumable.Slots.MATERIALS, { "crafting_resource", "currency" })
				for _, item in ipairs(currency_items) do
					if item.rarity == ing.r then
						local amount = ing.a
						if ing.r == ITEM_RARITY.s.COMMON then
							amount = GetScaledCost(ing.a, ilvl)
						end
						recipe:AddIngredient( Ingredient( item.name, amount ) )
						break
					end
				end
			end
		elseif ing.t == INGREDIENTS.s.MONSTER then
			assert(def.crafting_data.monster_source ~= nil, string.format("Tried to generate a crafting recipe for [%s] but has no valid monster_source!", name))

			local total_amount = ing.a
			local amount_used = 0
			local amount_left = total_amount
			local num_sources = #def.crafting_data.monster_source
			local sources_remaining = num_sources

			for _, monster in ipairs(def.crafting_data.monster_source) do
				local added_item = false
				local monster_items = Consumable.GetItemList(Consumable.Slots.MATERIALS, { "drops_"..monster })
				for _, item in ipairs(monster_items) do
					if item.rarity == ing.r then
						local amount = math.floor(total_amount/num_sources)
						if sources_remaining == 1 then
							-- you"re the last one, use up the rest of the "amount"
							amount = amount_left
						end

						amount_left = amount_left - amount
						sources_remaining = sources_remaining - 1
						amount_used = amount_used + amount

						recipe:AddIngredient( Ingredient( item.name, amount ) )
						added_item = true
						break
					end
				end
				assert(added_item == true, string.format("Failed to find [%s] ingredient from source [%s] when making recipe [%s]!", ing.r, monster, name))
			end
			assert(total_amount == amount_used, string.format("Failed to use all ingredients when making recipe for [%s]! (%s/ %s used)", name, amount_used, total_amount))
		end
	end

	recipes.add(recipe)

	if not is_upgrade and RECIPE_COSTS[slot].UPGRADE_PATH then
		local formulas = TUNING.CRAFTING.ARMOUR_UPGRADE_PATH[def.rarity]
		if formulas then
			for i, formula in ipairs(formulas) do
				local new_name = string.format("%s_upgrade_%s", def.name, i)
				AddRecipeForItem("PRICE", new_name, def, formula, true)
			end
		end
	end
end

for slot, items in pairs(Equipment.Items) do
	for name, def in pairs(items) do
		if def.crafting_data then
			AddRecipeForItem(slot, name, def)
		end
	end
end

for slot, gems in pairs(EquipmentGem.Items) do
	for name, def in pairs(gems) do
		recipes.add(Recipe(EquipmentGem, "GEMS", name, Ingredient("konjur_soul_lesser", 2)))
	end
end

recipes.add(Recipe(Equipment, "POTIONS", "heal1",    	   Ingredient("konjur_soul_lesser", 1))) -- unlocked by default
recipes.add(Recipe(Equipment, "POTIONS", "duration_heal1", Ingredient("konjur_soul_lesser", 1), Ingredient("gourdo_hat", 2))) -- gourdo
recipes.add(Recipe(Equipment, "POTIONS", "quick_heal1",    Ingredient("konjur_soul_lesser", 1), Ingredient("mossquito_cap", 2))) -- mossquito

recipes.add(Recipe(Constructable, "BUILDINGS",   "armorer_1"))
recipes.add(Recipe(Constructable, "BUILDINGS",   "armorer"))

recipes.add(Recipe(Constructable, "BUILDINGS",   "forge_1"))
recipes.add(Recipe(Constructable, "BUILDINGS",   "forge"))

recipes.add(Recipe(Constructable, "BUILDINGS",   "scout_tent_1"))
recipes.add(Recipe(Constructable, "BUILDINGS",   "scout_tent",        Ingredient("konjur_soul_greater", 10)))

recipes.add(Recipe(Constructable, "BUILDINGS",   "chemist_1"))
recipes.add(Recipe(Constructable, "BUILDINGS",   "chemist"))

recipes.add(Recipe(Constructable, "BUILDINGS",   "apothecary"))

recipes.add(Recipe(Constructable, "BUILDINGS",   "kitchen_1"))
recipes.add(Recipe(Constructable, "BUILDINGS",   "kitchen"))

recipes.add(Recipe(Constructable, "BUILDINGS",   "refinery_1",        Ingredient("megatreemon_hand", 1)))
recipes.add(Recipe(Constructable, "BUILDINGS",   "refinery",          Ingredient("bandicoot_wing", 1)))

recipes.add(Recipe(Constructable, "BUILDINGS",   "marketroom_shop"))

function MakePlaceablePropRecipe( category, slot, name, ... )
	recipes.add(Recipe(category, slot, name, ...))
	recipes.add(Recipe(Consumable, "PLACEABLE_PROP", name, ...))
end

MakePlaceablePropRecipe(Constructable, "FURNISHINGS", "dummy_cabbageroll", Ingredient("konjur_soul_lesser", 1))
MakePlaceablePropRecipe(Constructable, "FURNISHINGS", "dummy_bandicoot",   Ingredient("konjur_soul_lesser", 1))
MakePlaceablePropRecipe(Constructable, "FURNISHINGS", "chair1",            Ingredient("cabbageroll_baby", 1))
MakePlaceablePropRecipe(Constructable, "FURNISHINGS", "chair2",            Ingredient("yammo_stem", 1))

--TODO: tune these
MakePlaceablePropRecipe(Constructable, "FURNISHINGS", "bench_megatreemon",     Ingredient("megatreemon_hand", 1))
MakePlaceablePropRecipe(Constructable, "FURNISHINGS", "bench_rotwood",   	  Ingredient("konjur_soul_lesser", 1))
MakePlaceablePropRecipe(Constructable, "FURNISHINGS", "hammock",   			  Ingredient("cabbageroll_skin", 1), Ingredient("treemon_arm", 1))
MakePlaceablePropRecipe(Constructable, "FURNISHINGS", "kitchen_barrel",   	  Ingredient("treemon_arm", 1), Ingredient("treemon_cone", 1))
MakePlaceablePropRecipe(Constructable, "FURNISHINGS", "kitchen_chair",   	  Ingredient("konjur_soul_lesser", 1))
MakePlaceablePropRecipe(Constructable, "FURNISHINGS", "outdoor_seating_stool", Ingredient("treemon_arm", 2), Ingredient("yammo_skin", 1))
MakePlaceablePropRecipe(Constructable, "FURNISHINGS", "outdoor_seating",   	  Ingredient("treemon_arm", 1))
MakePlaceablePropRecipe(Constructable, "FURNISHINGS", "character_customizer_vshack",    Ingredient("konjur_soul_lesser", 1))

MakePlaceablePropRecipe(Constructable, "DECOR", "flower_bush",     	Ingredient("konjur_soul_lesser", 1))
MakePlaceablePropRecipe(Constructable, "DECOR", "flower_violet",   	Ingredient("konjur_soul_lesser", 1))
MakePlaceablePropRecipe(Constructable, "DECOR", "flower_bluebell", 	Ingredient("konjur_soul_lesser", 1))
MakePlaceablePropRecipe(Constructable, "DECOR", "tree",     		Ingredient("konjur_soul_lesser", 1))
MakePlaceablePropRecipe(Constructable, "DECOR", "shrub",   			Ingredient("konjur_soul_lesser", 1))

--TODO: tune these
MakePlaceablePropRecipe(Constructable, "DECOR", "plushies_lrg",    Ingredient("konjur_soul_lesser", 1))
MakePlaceablePropRecipe(Constructable, "DECOR", "plushies_mid",    Ingredient("yammo_skin", 2))
MakePlaceablePropRecipe(Constructable, "DECOR", "plushies_sm",     Ingredient("cabbageroll_skin", 2))
MakePlaceablePropRecipe(Constructable, "DECOR", "plushies_stack",  Ingredient("yammo_skin", 1), Ingredient("gourdo_skin", 1), Ingredient("zucco_skin", 1))
MakePlaceablePropRecipe(Constructable, "DECOR", "basket",     	  Ingredient("konjur_soul_lesser", 1))

--TODO: tune these
MakePlaceablePropRecipe(Constructable, "DECOR", "bulletin_board", Ingredient("konjur_soul_lesser", 1))
MakePlaceablePropRecipe(Constructable, "DECOR", "bread_oven",     Ingredient("konjur_soul_lesser", 1))
MakePlaceablePropRecipe(Constructable, "DECOR", "dye1", 		  Ingredient("gourdo_hat", 1))
MakePlaceablePropRecipe(Constructable, "DECOR", "dye2", 		  Ingredient("blarmadillo_trunk", 1))
MakePlaceablePropRecipe(Constructable, "DECOR", "dye3", 		  Ingredient("beets_body", 2))
MakePlaceablePropRecipe(Constructable, "DECOR", "kitchen_sign",   Ingredient("treemon_cone", 2))
MakePlaceablePropRecipe(Constructable, "DECOR", "leather_rack",   Ingredient("yammo_skin", 1),Ingredient("zucco_skin", 1))
MakePlaceablePropRecipe(Constructable, "DECOR", "tanning_rack",   Ingredient("blarmadillo_hide", 1), Ingredient("treemon_arm", 1))
MakePlaceablePropRecipe(Constructable, "DECOR", "pergola", 	      Ingredient("konjur_soul_lesser", 1))
MakePlaceablePropRecipe(Constructable, "DECOR", "stone_lamp",     Ingredient("blarmadillo_trunk", 1))
MakePlaceablePropRecipe(Constructable, "DECOR", "street_lamp",    Ingredient("cabbageroll_baby", 1))
MakePlaceablePropRecipe(Constructable, "DECOR", "travel_pack",    Ingredient("konjur_soul_lesser", 1))
MakePlaceablePropRecipe(Constructable, "DECOR", "weapon_rack",    Ingredient("megatreemon_hand", 1))
MakePlaceablePropRecipe(Constructable, "DECOR", "well", 		  Ingredient("blarmadillo_hide", 2))
MakePlaceablePropRecipe(Constructable, "DECOR", "wooden_cart",    Ingredient("treemon_arm", 2), Ingredient("treemon_cone", 1))

-- PRICE recipes don"t produce real items, but are used as costs for something
-- outside our item system.
recipes.add(Recipe(nil, "PRICE", "potion_refill", Ingredient("konjur", 75)))

recipes.add(Recipe(nil, "PRICE", "town_pillar_upgrade_1", Ingredient("konjur_heart", 1)))
recipes.add(Recipe(nil, "PRICE", "town_pillar_upgrade_2", Ingredient("konjur_heart", 1)))

--HOGGINS' "BUSINESS VENTURES"
---pay hoggins for a tip on where your missing friends are
recipes.add(Recipe(nil, "PRICE", "hoggins_tip", Ingredient("konjur", 1)))
--buy a limited edition potion from hoggins
recipes.add(Recipe(nil, "PRICE", "limited_potion_refill", Ingredient("konjur", 85)))
--doc needs money for his ailing grandmother in the Brinks
recipes.add(Recipe(nil, "PRICE", "granny_donation", Ingredient("konjur", 10)))

local function MakeUnlockRecipe(name, category, cost)
	local recipe_name = ("%s_unlock_%s"):format(category, name)
	local recipe = Recipe(Equipment, "PRICE", recipe_name)
	local monster_items = Consumable.GetItemList(Consumable.Slots.MATERIALS, { "drops_"..name })
	monster_items = lume.sort(monster_items, Consumable.CompareDef_ByRarityAndName)
	monster_items = lume.reverse(monster_items)
	local item = monster_items[1]

	if item then
		recipe:AddIngredient( Ingredient( item.name, cost ) )
	end

	recipes.add(recipe)
end

local TEMP_ID_TO_COST =
{
	['yammo'] = 3,
	['floracrane'] = 3,
	['megatreemon'] = 4,
	['bandicoot'] = 4,
}

for _, id in pairs(Equipment.ArmourSets) do
	local cost = TEMP_ID_TO_COST[id] or 2
	MakeUnlockRecipe(id, "armour", cost)
end

return recipes
