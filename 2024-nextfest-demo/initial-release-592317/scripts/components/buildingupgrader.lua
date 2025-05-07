local recipes = require "defs.recipes"
local Constructable = require "defs.constructable"

local BuildingUpgrader = Class(function(self, inst)
	self.inst = inst
	self.npc = nil
end)

function BuildingUpgrader:SetUpgrade(key, id)
	self.upgrade_home_key = key
	self.upgrade_placer_id = id
end

function BuildingUpgrader:StartUpgrading(player, cb)
	assert(self.upgrade_placer_id)
	local recipe = self:GetUpgradeRecipe()
	assert(recipe, self.upgrade_home_key)

	self.inst.components.snaptogrid:DisableCells()
	self.inst:RemoveFromScene()

	--==================================================================================
	-- TODO: reenable this
	--recipe:TakeIngredientsFromPlayer(player)
	
	local building = SpawnPrefab(self.upgrade_home_key)
	local x, z = self.inst.Transform:GetWorldXZ()
	if building.components.snaptogrid ~= nil then
		building.components.snaptogrid:SetNearestGridPos(x, 0, z)
	else
		building.Transform:SetPosition(x, 0, z)
	end

	--Reposition player to continue interacting with npc
	local x0, z0 = building.Transform:GetWorldXZ()
	local player_x, player_z = building.components.npchome:GetSpawnXZ()
	if player_x < x0 or (player_x == x0 and player.Transform:GetFacing() == FACING_LEFT) then
		player_x = x0 + player.Physics:GetSize()
	else
		player_x = x0 - player.Physics:GetSize()
	end

	player.Transform:SetPosition(player_x, 0, player_z)

	for name, npc in pairs(self.inst.components.npchome:GetNpcs()) do
		building.components.npchome:AddNpc(npc)
		npc.components.npc:SetDesiredHomeData(self.upgrade_home_key, self.upgrade_placer_id)
		npc:Face(player)
		player:Face(npc)
	end

	player.components.unlocktracker:UnlockRecipe(self.upgrade_home_key)

	self.inst:Remove()
	-- TODO: suspend the dialogue and then reenable this
	-- if cb then
	-- 	cb(true)
	-- end
	--==========================================================================
end

function BuildingUpgrader:GetUpgradeRecipe()
	assert(self.upgrade_home_key)
	local recipe = recipes.ForSlot[Constructable.Slots.BUILDINGS][self.upgrade_home_key]
	return recipe
end

return BuildingUpgrader
