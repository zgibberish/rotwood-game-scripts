local lume = require("util.lume")

local UseTracker = Class(function(self, inst)
	self.inst = inst
	self.tracked_uses = {} -- k:id (string), v:integer
	self.tracked_uses_change_event = {} -- k:id (string), v:event (string)
end)

local MaxTrackedUsesNrBits = 4
local UsesNrBits = 2

function UseTracker:OnNetSerialize()
	local e = self.inst.entity

	e:SerializeUInt(lume.count(self.tracked_uses), MaxTrackedUsesNrBits)
	for id,uses in pairs(self.tracked_uses) do
		e:SerializeString(id)
		e:SerializeUInt(uses, UsesNrBits)
	end
end

function UseTracker:OnNetDeserialize()
	local e = self.inst.entity

	local tracked_uses = e:DeserializeUInt(MaxTrackedUsesNrBits)
	-- lume.clear(self.tracked_uses)
	for _i=1,tracked_uses do
		local id = e:DeserializeString()
		local uses = e:DeserializeUInt(UsesNrBits)
		local changed = not self.tracked_uses[id] or self.tracked_uses[id] ~= uses

		self.tracked_uses[id] = uses
		if changed then
			self:PushChangedEvent(id)
		end
	end
end

function UseTracker:PushChangedEvent(id)
	if self.tracked_uses_change_event[id] then
		self.inst:PushEvent(self.tracked_uses_change_event[id])
	end
end

function UseTracker:AddTrackedUse(id, change_event)
	if not self.tracked_uses[id] then
		self.tracked_uses[id] = 0
	end
	if not self.tracked_uses_change_event[id] then
		self.tracked_uses_change_event[id] = change_event
	end
end

function UseTracker:Use(id, num)
	num = num or 1
	if not self.tracked_uses[id] then
		return
	end

	self.tracked_uses[id] = self.tracked_uses[id] + num
	self:PushChangedEvent(id)
end

function UseTracker:ResetUses(id)
	if not self.tracked_uses[id] then
		return
	end

	local changed = self.tracked_uses[id] ~= 0
	self.tracked_uses[id] = 0
	if changed then
		self:PushChangedEvent(id)
	end
end

function UseTracker:GetNumUses(id)
	return self.tracked_uses[id] or 0
end

function UseTracker:OnSave()
	if next(self.tracked_uses) == nil then
		return
	end
	local tracked_uses = {}
	for id, num in pairs(self.tracked_uses) do
		tracked_uses[id] = num
	end
	return { tracked_uses = tracked_uses }
end

function UseTracker:OnLoad(data)
	if data.tracked_uses ~= nil then
		for id, num in pairs(data.tracked_uses) do
			self.tracked_uses[id] = num
		end
	end
end

return UseTracker
