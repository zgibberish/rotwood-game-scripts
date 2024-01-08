

-- This component is kind of a side-component of the combat component. 
-- It is intended to sync only the important variables inside the combat component for players.
-- The reason it's a separate component is because we don't want this component overhead for every 
-- entity that is synced.
local CombatPlayerSync = Class(function(self, inst)
	self.inst = inst
end)


function CombatPlayerSync:OnNetSerialize()
	local e = self.inst.entity
	assert(e ~= nil, "entity can't be nil")

	local combat = self.inst.components.combat
	assert(combat ~= nil, "combat can't be nil")

	-- Only saving select sourcemodifiers:
	e:SerializeDoubleAs16Bit(combat.focusdamagemult:Get())
	e:SerializeDoubleAs16Bit(combat.critdamagemult:Get())
	e:SerializeDoubleAs16Bit(combat.damagedealtbonus:Get())
	e:SerializeDoubleAs16Bit(combat.basedamage:Get())

	-- Save locomotor's total speed mult for the powers that want this info (i.e. wrecking_ball)
	local loco = self.inst.components.locomotor
	assert(loco)
	e:SerializeDoubleAs16Bit(loco:GetTotalSpeedMult())
end

function CombatPlayerSync:OnNetDeserialize()
	local e = self.inst.entity
	assert(e ~= nil, "entity can't be nil")

	local combat = self.inst.components.combat
	assert(combat ~= nil, "combat can't be nil")

	local f = e:DeserializeDoubleAs16Bit()
	if f then
		combat.focusdamagemult:NetSet(f)
	end

	f = e:DeserializeDoubleAs16Bit()
	if f then
		combat.critdamagemult:NetSet(f)
	end

	f = e:DeserializeDoubleAs16Bit()
	if f then
		combat.damagedealtbonus:NetSet(f)
	end

	f = e:DeserializeDoubleAs16Bit()
	if f then
		combat.basedamage:NetSet(f)
	end

	local loco = self.inst.components.locomotor
	assert(loco)
	f = e:DeserializeDoubleAs16Bit()
	if f then
		loco:NetSetTotalSpeedMult(f)
	end
end

return CombatPlayerSync
