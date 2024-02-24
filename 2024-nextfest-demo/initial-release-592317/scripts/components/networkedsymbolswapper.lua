local lume = require"util/lume"

local NetworkedSymbolSwapper = Class(function(self, inst)
	self.inst = inst

	self.symbol_slots = {}
	self.swaps = {}
end)

function NetworkedSymbolSwapper:SetSymbolSlots(slots)
	--[[
	local slots = {
		["EXAMPLE"] = { "symbol1", "symbol2" },
	}
	--]]
	self.symbol_slots = slots
	self.ordered_slots = lume.sort(lume.keys(self.symbol_slots))
end

function NetworkedSymbolSwapper:GetOrderedSlots()
	return self.ordered_slots
end

function NetworkedSymbolSwapper:OverrideSymbolSlot(slot, build)
	self.swaps[slot] = build
	for _, symbol in ipairs(self.symbol_slots[slot]) do
		self.inst.AnimState:OverrideSymbol(symbol, build, symbol)
	end
end

function NetworkedSymbolSwapper:OnNetSerialize()
	local e = self.inst.entity
	local slots = self:GetOrderedSlots()
	for _i,slot in ipairs(slots) do
		e:SerializeString(self.swaps[slot] or "")
	end
end

function NetworkedSymbolSwapper:OnNetDeserialize()
	local e = self.inst.entity
	local slots = self:GetOrderedSlots()
	for _i, slot in ipairs(slots) do
		local build_name = e:DeserializeString()
		if build_name ~= "" then
			self:OverrideSymbolSlot(slot, build_name)
		end
	end
end

return NetworkedSymbolSwapper