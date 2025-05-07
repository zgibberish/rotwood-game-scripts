local SERIALIZED_STOLEN_BITS <const> = 8 -- max 2^8 256 since the battoad takes 20% of a players currency, players would need more than 1200 currency to break this cap

local BattoadSync = Class(function(self, inst)
	self.inst = inst
    self.on_ground = true
    self.stolen_konjur = 0
end)

function BattoadSync:OnNetSerialize()
	local e = self.inst.entity
	e:SerializeBoolean(self.on_ground)
    e:SerializeUInt(self.stolen_konjur, SERIALIZED_STOLEN_BITS)
end

function BattoadSync:OnNetDeserialize()
	local e = self.inst.entity
	local was_on_ground = self.on_ground
	self.on_ground = e:DeserializeBoolean()
    self.stolen_konjur = e:DeserializeUInt(SERIALIZED_STOLEN_BITS)

	if (not self.on_ground and was_on_ground) then -- Runs on remote machines. Local machines are set via stategraph
		self.inst:SetLocoState(self.inst.LocoState.AIR)
	end
end

return BattoadSync