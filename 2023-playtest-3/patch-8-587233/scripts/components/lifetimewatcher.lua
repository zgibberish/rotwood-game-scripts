local Equipment = require "defs.equipment"
local itemforge = require "defs.itemforge"

local LifetimeWatcher = Class(function(self, inst)
	self.inst = inst
	self.items = {}

	self.inst:ListenForEvent("day_passed", function(source, data)
		self:OnDayPassed()
	end, TheWorld)

	self.inst:ListenForEvent("inventory_stackable_changed", function(source, data)
		if data.item then
			local def = data.item:GetDef()
			if def.tags["food"] and not def.tags["spoiled_food"] then
				data.item:ActivateLifetime()
			end
		end
	end)
end)

function LifetimeWatcher:OnDayPassed()
	local inventoryhoard = self.inst.components.inventoryhoard
	local slot = "FOOD"

	local items = inventoryhoard:GetSlotItems(slot)
	for k,v in pairs(items) do
		if not v:GetDef().tags["spoiled_food"] then
			v:DecreaseLifetime()
			if v:GetLifetime() <= 0 then
				inventoryhoard:RemoveFromInventory(v)
				local def = Equipment.Items[slot]["spoiled_food"]
				local item = itemforge.CreateEquipment(slot, def)
				inventoryhoard:AddToInventory(item.slot, item)
			end
		end
	end
end

return LifetimeWatcher
