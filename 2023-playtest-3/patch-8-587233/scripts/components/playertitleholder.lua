
local PlayerTitleHolder = Class(function(self, inst)
    self.inst = inst
	self:SetDefaultTitle()
end)

function PlayerTitleHolder:GetTitleKey()
	return self.title_key
end

function PlayerTitleHolder:SetTitleKey(title_key)
	local Cosmetics = require "defs.cosmetics.cosmetics"
	self:SetTitle(Cosmetics.Items["PLAYER_TITLE"][title_key])
end

function PlayerTitleHolder:SetTitle(def)
	self.title_key = def.name
	self.string_key = def.title_key
	self.rarity = def.rarity -- It would be cool if the UI adapted to the rarity
	self.inst:PushEvent("title_changed")
end

function PlayerTitleHolder:ClearTitle()
	self.title_key = nil
	self.string_key = nil

	self.inst:PushEvent("title_changed")
end

function PlayerTitleHolder:GetPretty()
	if self.string_key == nil then
		self:SetDefaultTitle()
	end

	return STRINGS.COSMETICS.TITLES[self.string_key]
end

function PlayerTitleHolder:GetRarity()
	return self.rarity
end

function PlayerTitleHolder:OnSave()
	return { title_key = self.title_key }
end

function PlayerTitleHolder:OnLoad(data)
	if data and data.title_key then
		self:SetTitleKey(data.title_key)
	end
end

function PlayerTitleHolder:SetDefaultTitle()
	self:SetTitleKey("default_title")
end

function PlayerTitleHolder:OnNetSerialize()
	local e = self.inst.entity
	e:SerializeString(self.title_key)
end

function PlayerTitleHolder:OnNetDeserialize()
	local e = self.inst.entity
	local title_key = e:DeserializeString()

	if title_key ~= self.title_key then
		self:SetTitleKey(title_key)
	end
end

return PlayerTitleHolder
