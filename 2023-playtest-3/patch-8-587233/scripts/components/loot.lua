local Consumable = require "defs.consumable"

local Loot = Class(function(self, inst)
	self.inst = inst
	self.onpickedupfn = nil

	self.owner = nil
	self.loot_id = nil
	self.count = 1

	self.loot_type = "item"

	self.count_thresholds = nil

	inst:AddTag("loot")
end)

function Loot:MakeLootLucky()
	self.lucky = true

	local lucky_trail = SpawnPrefab("item_airtrail_lucky")
--		lucky_trail.components.particlesystem:LoadParams(pfx)
	-- lucky_trail.entity:SetParent(inst.entity)
	lucky_trail.Transform:SetPosition(0,0,0)
	lucky_trail.entity:AddFollower()
	local symbol = self.loot_type == "curve" and "item_curve" or "item"
	lucky_trail.Follower:FollowSymbol(self.inst.GUID, symbol)
	self.inst.lucky_trail_particles = lucky_trail
end

function Loot:SetLootType(type)
	self.loot_type = type
	return self
end

function Loot:MakePickupable()
	self.inst:AddTag("loot_acquirable")
end

function Loot:SetLootID(id)
	self.loot_id = id
end

function Loot:GetLootID(id)
	return self.loot_id
end

function Loot:SetCountThresholds(tbl)
	self.count_thresholds = tbl
end

function Loot:SetCount(num)
	self.count = math.floor(num)
	-- do art adjustments

	if self.count_thresholds ~= nil then
		local best_idx = nil
		for i, threshold in ipairs(self.count_thresholds) do
			if threshold.count > num then
				best_idx = i - 1
				break
			end

			if not best_idx and i == #self.count_thresholds then
				best_idx = i
				break
			end
		end

		if best_idx and best_idx > 0 then
			self.inst:SetSymbolOverride(self.count_thresholds[best_idx].symbol)
		end
	end
end

function Loot:SetOnPickedUpFn(fn)
	self.onpickedupfn = fn
	return self
end

function Loot:AddWeightedItem(item, weight, count)
	self.list:AddItem(item, weight)
	self.counts[item] = count or 1
end

function Loot:GetItemName()
	return self.list:PickItem()
end

function Loot:GetOwner()
	return self.owner
end

function Loot:SetOwner(owner)
	self.owner = owner
end

function Loot:OnPickedUpBy(player)
	-- don't update remote players -- they will do it themselves
	if player:IsLocal() and self.loot_id ~= nil then
		local item = Consumable.FindItem(self.loot_id)
		if item ~= nil then
			player:PushEvent("get_loot", { item = item, count = self.count })
		else
			dbassert(item ~= nil, "Loot ["..tostring(self.inst).."] without pickup item.")
		end
		if self.onpickedupfn ~= nil then
			self.onpickedupfn(self.inst, player, item)
		end
	end
	self.inst:Remove()
end

return Loot
