local Power = require "defs.powers.power"

local Enum = require "util.enum"
local lume = require "util.lume"

local GroakSync = nil -- Forward declaration for GroakSync.Status enum
GroakSync = Class(function(self, inst)
	self.inst = inst
	self.status = GroakSync and GroakSync.Status.id.NORMAL or nil
	self.chew_sequence_num = nil
end)

GroakSync.Status = Enum{ "NORMAL", "SUCKING", "JUST_SWALLOWED", "SWALLOWING", "SPIT_OUT" }

local nrChewSequenceNumBits <const> = 8
local nrStatusBits <const> = 3

function GroakSync:OnNetSerialize()
	local e = self.inst.entity

	e:SerializeUInt(self.status - 1, nrStatusBits)

	local chew_sequence_num_initialized = self.chew_sequence_num ~= nil
	e:SerializeBoolean(chew_sequence_num_initialized)
	if chew_sequence_num_initialized then
		e:SerializeUInt(self.chew_sequence_num, nrChewSequenceNumBits)
	end
end

function GroakSync:OnNetDeserialize()
	local e = self.inst.entity

	local status = e:DeserializeUInt(nrStatusBits) + 1
	self.status = status

	local swallowed_ents = self:FindSwallowedEntities()

	-- Process chewing
	local chew_sequence_num_initialized = e:DeserializeBoolean()
	if chew_sequence_num_initialized then
		local sequence_num = e:DeserializeUInt(nrChewSequenceNumBits)

		local diff = CompareNetworkSequenceNumber(self.chew_sequence_num, sequence_num, nrChewSequenceNumBits)
		-- Depending on the sequence number difference, chew that many times on local entities.
		for i = 1, diff do
			for _, ent in ipairs(swallowed_ents) do
				if ent:IsLocal() then
					ent:PushEvent("groak_chewed")
				end
			end
		end

		self.chew_sequence_num = sequence_num
	else
		self.chew_sequence_num = nil
	end

	-- Process spitting out
	if status == GroakSync.Status.id.SPIT_OUT then
		for _, ent in ipairs(swallowed_ents) do
			if ent:IsLocal() then
				ent:PushEvent("groak_spitout")
			end
		end
	end
end

function GroakSync:ResetData()
	self:SetStatusNormal()
	self.chew_sequence_num = nil
end

function GroakSync:GetSwallowPoint(swallow_point_offset)
	-- Check if within swallow range
	local pt = Vector3(table.unpack(swallow_point_offset))
	local facing = self.inst.Transform:GetFacing() == FACING_LEFT and -1 or 1
	local size = self.inst.Physics:GetSize() -- Need to account for swallower size when calculating distances & offsets.
	pt.x = pt.x * facing * size * 0.75 -- [TODO?] Adjust the multiplier to size so it works nicely at different scales.
	local swallow_pt = self.inst:GetPosition() + pt

	-- If the swallow point isn't on ground, we need to move it to be over ground
	local isPointOnGround = TheWorld.Map:IsGroundAtPoint(swallow_pt)
	if not isPointOnGround then
		swallow_pt = self.inst:GetPosition() -- (TODO?) Maybe have swallow_pt move towards the source until it's over ground. For now, set it to the source's position, since it should be guaranteed to be over ground.
	end

	return swallow_pt
end

function GroakSync:FindSwallowedEntities()
	local swallowed_ents = {}

	local def = Power.FindPowerByName("groak_suck")
	local swallow_pt = def.tuning[Power.Rarities.s.COMMON].swallow_point_offset

	local pos = self.inst:GetPosition()
	local facing = self.inst.Transform:GetFacing() == FACING_LEFT and -1 or 1
	local targets = TheSim:FindEntitiesXZ(pos.x + swallow_pt[1] * facing, pos.z + swallow_pt[3], 10) -- Search a rough area around the swallow distance to account for things not being inside the swallow distance.

	-- Detect if a remote entity within swallow range was swallowed & tell groak that it swallowed something.
	for _, target in ipairs(targets) do
		if target.components.powermanager then
			local swallowed_pwr = target.components.powermanager:GetPowerByName("groak_swallowed")
			if swallowed_pwr then
				-- (For swallowing remote clients) If swallowed its first target, tell itself that it has just swallowed something.
				if swallowed_pwr.mem.swallower == self.inst then
					table.insert(swallowed_ents, target)
				end
			end
		end
	end

	return swallowed_ents
end

function GroakSync:SwallowTarget(target, data)
	if not target or not target:IsValid() then return end

	target:TryToTakeControl()

	-- If swallowed its first target, tell itself that it has just swallowed something.
	if target:IsLocal() and self.inst:IsLocal() and not self:HasJustSwallowed() then
		self:SetStatusJustSwallowed()
		self.inst:PushEvent("has_just_swallowed")
	end

	-- Apply the 'swallowed' status effect onto the target. This will handle communication with the swallower.
	local powermanager = target.components.powermanager
	if powermanager ~= nil then
		local def = Power.FindPowerByName("groak_swallowed")
		if not powermanager:HasPower(def) then
			local power = self.inst.components.powermanager:CreatePower(def)
			if power ~= nil then
				power.source = data.swallower
			end
			powermanager:AddPower(power)
		end
	end
end

function GroakSync:SetStatusNormal()
	self.status = GroakSync.Status.id.NORMAL
end

function GroakSync:SetStatusSucking()
	self.status = GroakSync.Status.id.SUCKING
end

function GroakSync:IsSucking()
	return self.status == GroakSync.Status.id.SUCKING
end

function GroakSync:SetStatusJustSwallowed()
	self.status = GroakSync.Status.id.JUST_SWALLOWED
end

function GroakSync:HasJustSwallowed()
	return self.status == GroakSync.Status.id.JUST_SWALLOWED
end

function GroakSync:SetStatusSwallowing()
	self.status = GroakSync.Status.id.SWALLOWING
end

function GroakSync:IsSwallowing()
	return self.status == GroakSync.Status.id.SWALLOWING
end

function GroakSync:Chew()
	local swallowed_ents = self:FindSwallowedEntities()

	-- If just changed to chewing, tell all local swallowed entities to process chewing. Remote entities handled on deserialize.
	for _, ent in ipairs(swallowed_ents) do
		if ent:IsLocal() then
			ent:PushEvent("groak_chewed")
		end
	end

	self.chew_sequence_num = self.chew_sequence_num and self.chew_sequence_num + 1 % 2 ^ nrChewSequenceNumBits or 0
end

function GroakSync:SetStatusSpitOut(is_cinematic)
	local swallowed_ents = self:FindSwallowedEntities()

	-- If just spit out, tell all local swallowed entities to process being spit out. Remote entities handled on deserialize.
	if self.status ~= GroakSync.Status.id.SPIT_OUT then
		for _, ent in ipairs(swallowed_ents) do
			if ent:IsLocal() then
				ent:PushEvent("groak_spitout", is_cinematic)
			end
		end
	end

	self.status = GroakSync.Status.id.SPIT_OUT
end

function GroakSync:IsSpittingOut()
	return self.status == GroakSync.Status.id.SPIT_OUT
end

return GroakSync
