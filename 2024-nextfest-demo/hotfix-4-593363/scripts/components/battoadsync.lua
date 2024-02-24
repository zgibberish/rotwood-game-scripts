local SERIALIZED_STOLEN_BITS <const> = 8 -- max 2^8 256 since the battoad takes 20% of a players currency, players would need more than 1200 currency to break this cap

local BattoadSync = Class(function(self, inst)
	self.inst = inst
    self.on_ground = true
    self.stolen_konjur = 0
	self.heal_pos = nil
end)

function BattoadSync:GetStolenKonjur()
	return self.stolen_konjur
end

function BattoadSync:SetStolenKonjur(amount)
	assert(amount >= 0)
	self.stolen_konjur = amount
end

-- can be nil
function BattoadSync:GetHealPos()
	return self.heal_pos
end

function BattoadSync:SetHealPos(new_position)
	self.heal_pos = new_position
end

function BattoadSync:OnNetSerialize()
	local e = self.inst.entity
	e:SerializeBoolean(self.on_ground)
    e:SerializeUInt(self.stolen_konjur, SERIALIZED_STOLEN_BITS)
	e:SerializeBoolean(self.heal_pos ~= nil)
	if self.heal_pos then
		e:SerializePosition(self.heal_pos)
	end
end

function BattoadSync:OnNetDeserialize()
	local e = self.inst.entity
	local was_on_ground = self.on_ground
	self.on_ground = e:DeserializeBoolean()
    self.stolen_konjur = e:DeserializeUInt(SERIALIZED_STOLEN_BITS)
	if e:DeserializeBoolean() then -- heal_pos
		self.heal_pos = e:DeserializePosition()
	end

	if (not self.on_ground and was_on_ground) then -- Runs on remote machines. Local machines are set via stategraph
		self.inst:SetLocoState(self.inst.LocoState.AIR)
	end
end

return BattoadSync
