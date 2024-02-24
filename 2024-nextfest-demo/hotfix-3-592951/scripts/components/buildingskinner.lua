local SGCommon = require "stategraphs.sg_common"

local BuildingSkinner = Class(function(self, inst)
	self.inst = inst

	self.symbol_groups = {} -- All the symbols that can be skinned
	self.skin_sets = {} -- All the sets you can skin the symbols with
	
	self.skin_index = {} -- Stores which set is mapped to which symbol at any time. k = symbol, v = index in the skin_sets table
end)


-----------------------------------------------------------------------------
-----------------------------------------------------------------------------

function BuildingSkinner:SetSymbolSkin(group, set)
	for index, _set in ipairs(self.skin_sets) do
		if _set == set then
			self.skin_index[group] = index
		end
	end

	for _, symbol in ipairs(self.symbol_groups[group]) do
		SGCommon.Fns.OverrideSymbolOnAllLayers(self.inst, symbol, self.inst.AnimState:GetBuild(), symbol .."_".. set)
	end

end

function BuildingSkinner:ResetSymbolSkin(group)
	self.skin_index[group] = 0

	for _, symbol in ipairs(self.symbol_groups[group]) do
		SGCommon.Fns.ClearOverrideSymbolOnAllLayers(self.inst, symbol)
	end
end

function BuildingSkinner:NextSkinSymbol(group)
	self.skin_index[group] = (self.skin_index[group] + 1) % (#self.skin_sets + 1)

	if self.skin_index[group] == 0 then
		self:ResetSymbolSkin(group)
	else
		self:SetSymbolSkin(group, self.skin_sets[self.skin_index[group]])
	end
end

function BuildingSkinner:PreviousSkinSymbol(group)
	self.skin_index[group] = self.skin_index[group] - 1

	if self.skin_index[group] == -1 then
		self.skin_index[group] = #self.skin_sets
	end

	if self.skin_index[group] == 0 then
		self:ResetSymbolSkin(group)
	else
		self:SetSymbolSkin(group, self.skin_sets[self.skin_index[group]])
	end
end

-----------------------------------------------------------------------------
-----------------------------------------------------------------------------

-- Symbols are clustered together by groups
-- symbol_groups = { groupA = {"symbol1", "symbol2"}, groupB = {"symbol3"}, etc.. }
function BuildingSkinner:SetSkinSymbolGroups(symbol_groups)
	self.symbol_groups = symbol_groups
	for key, group in pairs(self.symbol_groups) do
		self.skin_index[key] = 0
	end
end

function BuildingSkinner:SetSkinSets(sets)
	self.skin_sets = sets
end

function BuildingSkinner:AddSkinSet(set)
	table.insert(self.skin_sets, set)
end

function BuildingSkinner:AddSkinSets(sets)
	for _, set in ipairs(sets) do
		self:AddSkinSet(set)
	end
end

function BuildingSkinner:GetSkinSetIndex(set)
	for index, _set in ipairs(self.skin_sets) do
		if _set == set then
			return index
		end
	end
end

function BuildingSkinner:GetCurrentSet(group)
	local index = self.skin_index[group]
	if index == 0 then
		return "default"
	end

	return self.skin_sets[index]
end

-----------------------------------------------------------------------------
-----------------------------------------------------------------------------

function BuildingSkinner:OnSave()
	return { skin_index = self.skin_index }
end

function BuildingSkinner:OnLoad(data)
	if data and data.skin_index then
		self.skin_index = data.skin_index
		for symbol, index in pairs(self.skin_index) do
			if index ~= 0 then
				self:SetSymbolSkin(symbol, self.skin_sets[index])
			end
		end
	end
end

return BuildingSkinner