local Consumable = require "defs.consumable"
local lume = require"util/lume"

local CollaberativeCraft = Class(function(self, inst)
	self.inst = inst
	self.recipe = nil
	self.held_items = {}
end)

function CollaberativeCraft:SetActiveRecipe(recipe)
	self.recipe = recipe
end

function CollaberativeCraft:GetActiveRecipe()
	return self.recipe
end

function CollaberativeCraft:GetRequiredItems()
	local required_items = {}

	for name, count in pairs(self.recipe.ingredients) do
		required_items[name] = count
		if self.held_items[name] then
			required_items[name] = required_items[name] - self.held_items[name]
		end
	end

	required_items = lume.filter(required_items, function(count) return count > 0 end, true)

	return required_items
end

function CollaberativeCraft:GetPossibleContribution(player)
	local contribution = {}
	
	-- does this player have any of the items required to advance the craft?
	local required_items = self:GetRequiredItems()
	local inv = player.components.inventoryhoard
	for name, count in pairs(required_items) do
		local def = Consumable.FindItem(name)
		local has = inv:GetStackableCount(def)
		contribution[name] = { has = has, needs = count }
	end

	return contribution
end

function CollaberativeCraft:CanContribute(player)
	if not self:GetActiveRecipe() then return false end
	-- We want the button to always show up if there is a craft active, so always return true if active.
	return true

	--[[
	local contribution = self:GetPossibleContribution(player)
	local can_contribute = false
	for item, counts in pairs(contribution) do
		if counts.has >= counts.needs then
			can_contribute = true
			break
		end
	end
	return can_contribute
	--]]
end

function CollaberativeCraft:TryToContribute(player)
	local contribution = self:GetPossibleContribution(player)

	local did_contribute = false

	for item, count in pairs(contribution) do
		local to_add = math.min(count.has, count.needs)
		if to_add > 0 then
			self:Contribute(player, item, to_add)
			did_contribute = true
		end
	end

	return did_contribute
end

function CollaberativeCraft:Contribute(player, item, count)
	local inv = player.components.inventoryhoard

	local def = Consumable.FindItem(item)
	inv:RemoveStackable(def, count)

	if not self.held_items[item] then
		self.held_items[item] = 0
	end

	self.held_items[item] = self.held_items[item] + count

	local required_items = self:GetRequiredItems()

	if not next(required_items) then
		self:CompleteCraft()
	end
end

function CollaberativeCraft:CompleteCraft()
	self.inst:PushEvent("complete_craft", self)
	self:SetActiveRecipe(nil)
end

function CollaberativeCraft:OnSave()
	if not self:GetActiveRecipe() then return end
	local data = {}
	data.recipe = self.recipe.def.name
	data.held_items = shallowcopy(self.held_items)
	return data
end

function CollaberativeCraft:OnLoad(data)
	local recipes = require "defs.recipes"

	if data.recipe then
		self:SetActiveRecipe(recipes.FindRecipeForItem(data.recipe))
		self.held_items = shallowcopy(data.held_items)
	end
end

return CollaberativeCraft
