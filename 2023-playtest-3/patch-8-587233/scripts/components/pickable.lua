local Consumable = require "defs.consumable"

-- A world item that can be picked up by the player.
-- If it doesn't go in the inventory, then use interactable directly instead.
local Pickable = Class(function(self, inst)
	self.inst = inst
	self.item = nil
	self.onpickedfn = nil

	local interactable = self.inst.components.interactable
	assert(interactable, "Pickable requires interactable.")
	interactable:SetOnInteractFn(function(pick_ent, player)
		self:_OnPickedUpBy(player)
	end)
end)

function Pickable:SetPickedItem(item)
	self.item = item
	return self
end

function Pickable:SetOnPickedFn(fn)
	self.onpickedfn = fn
	return self
end

function Pickable:_OnPickedUpBy(player)
	if self.item ~= nil and player.components.inventoryhoard ~= nil then
		local item = Consumable.FindItem(self.item)
		player.components.inventoryhoard:AddStackable(item, 1)
	end
	if self.onpickedfn ~= nil then
		self.onpickedfn(self.inst, player)
	end
end

return Pickable
