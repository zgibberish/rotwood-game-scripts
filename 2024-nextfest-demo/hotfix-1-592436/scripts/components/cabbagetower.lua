local monsterutil = require "util.monsterutil"

local CabbageTower = Class(function(self, inst)
	self.inst = inst
	self.tower = nil -- the "master" roll, nil if it is the master or single
	self.attacks = nil
	self.num = 1 -- the "mode" for this roll (single, double, triple)

	self.rolls = {} -- empty if single, otherwise rolls that are part of the tower

	self.starting_health_percentage = 1.0
	--[[
		this is a percentage of starting_health_percentage.
		IE: (assuming health_split_percentage is 0.50)
		- If a cabbage tower started with 100% health, the cabbage tower will split when it reaches below 50% health.
		- If a cabbage tower starts with 50% health, the cabbage tower will split when it reaches below 25% health
	--]]
	self.health_split_percentage = 0.40

	-- TODO: hack, softlock temp fix
	self.inst:StartUpdatingComponent(self)
end)

function CabbageTower:OnRemoveEntity()
	while #self.rolls > 0 do
		TheLog.ch.CabbageTower:printf("OnRemoveEntity: Removing extra rolls from tower")
		-- this entity is getting removed for whatever reason,
		-- so also remove the children
		local roll = self:RemoveTopRoll()
		if roll and roll:IsValid() then
			roll:Remove()
		end
	end
end

local startingHealthPercentageParams =
{
	12, -- nrBits
	0, -- minValue
	1, -- maxValue
}

function CabbageTower:OnNetSerialize()
	local e = self.inst.entity

	-- don't bother serializing if it is invalid
	local isValid = self.inst:IsValid() and not self.inst:IsInDelayedRemove()
	e:SerializeBoolean(isValid)
	if not isValid then
		return
	end

	local count = 0
	for _i,roll in ipairs(self.rolls) do
		if roll:IsValid() then
			count = count + 1
		end
	end

	e:SerializeUInt(count, 2)

	for _i,roll in ipairs(self.rolls) do
		if roll:IsValid() then
			e:SerializeEntityID(roll.Network:GetEntityID())
		end
	end

	e:SerializeDouble(self.starting_health_percentage, table.unpack(startingHealthPercentageParams))
end

function CabbageTower:OnNetDeserialize()
	local e = self.inst.entity

	local isValid = e:DeserializeBoolean()
	if not isValid then
		return
	end

	local roll_count = e:DeserializeUInt(2)
	local old_roll_count = #self.rolls
	if old_roll_count ~= roll_count then
		if VerboseNetworkLogging then
			TheLog.ch.CabbageTower:printf("%s EntityID %d Roll Count differs: old=%d new=%d",
				self.inst, self.inst.Network:GetEntityID(), old_roll_count, roll_count)
		end
		for i=1,old_roll_count do
			local roll = self:RemoveTopRoll()
			if roll then
				roll.components.cabbagetower:SetSingle(self.inst.components.cabbagerollstracker.cancombine)
			end
		end
		self:SetSingle(self.inst.components.cabbagerollstracker.cancombine)

		for i=1,roll_count do
			local roll_guid = TheNet:FindGUIDForEntityID(e:DeserializeEntityID())
			local roll = Ents[roll_guid]
			if i == 1 then
				self:SetDouble(roll)
			elseif i == 2 then
				self:SetTriple(roll)
			else
				assert(false)
			end
		end
	else
		for _i=1,roll_count do
			local roll_entid = e:DeserializeEntityID()
			local roll_guid = TheNet:FindGUIDForEntityID(roll_entid)
			local roll = Ents[roll_guid]
			if not table.arrayfind(self.rolls, roll) then
				TheLog.ch.CabbageTower:printf("Warning: %s EntityID %d master roll missing reference to %s",
					self.inst, self.inst.Network:GetEntityID(), roll)
			end
			-- assert(table.arrayfind(self.rolls, roll) ~= nil)
		end
	end

	self:ValidateTower(false)

	self.starting_health_percentage = e:DeserializeDouble(table.unpack(startingHealthPercentageParams))
end

function CabbageTower:OnUpdate(dt)
	if self.num == 1 then
		self:_ValidateSingle()
	end
end

-- TODO: hack, softlock temp fix
function CabbageTower:_ValidateSingle()
	assert(self.num == 1)

	local bank <const> = "cabbageroll_single_bank"
	if self.inst.AnimState:GetBank() ~= bank then
		TheLog.ch.CabbageTower:printf("ValidateSingle: Setting correct bank to %s", bank)
		self.inst.AnimState:SetBank(bank)
	end

	if self.inst:IsLocal() then
		if self.num == 1 and self.inst:HasTag("nokill") then
			TheLog.ch.CabbageTower:printf("ValidateSingle: Removing nokill tag")
			self.inst:RemoveTag("nokill")
		end
		if not self.inst.AnimState:GetCurrentAnimationName() and self.inst.sg then
			-- i.e. due to missing animation, go back to idle, since we don't know how the sg state is structured
			-- most reports show it's the bite anim
			TheLog.ch.CabbageTower:printf("ValidateSingle: No anim playing for sg state %s: Going to idle",
				self.inst.sg:GetCurrentState())
			self.inst.sg:GoToState("idle")
		end
	end
end

function CabbageTower:OnEntityBecameLocal()
	self:ValidateTower(true)
end

local temp = {}
function CabbageTower:ValidateTower(shouldTakeControl)
	-- validate and optionally take control of hat rolls
	for _i,roll in ipairs(self.rolls) do
		if not roll:IsValid() then
			TheLog.ch.CabbageTower:printf("ValidateTower %s EntityID %d - Removing invalid roll %s",
					self.inst, self.inst.Network:GetEntityID(), roll)
			table.insert(temp, roll)
		elseif shouldTakeControl then
			if VerboseNetworkLogging then
				TheLog.ch.CabbageTower:printf("ValidateTower %s EntityID %d - Taking control of roll %s EntityID %d",
					self.inst, self.inst.Network:GetEntityID(), roll, roll.Network:GetEntityID())
			end
			roll:TakeControl()
		end
	end

	-- remove invalid rolls
	for _i,roll in ipairs(temp) do
		table.removearrayvalue(self.rolls, roll)
	end
	table.clear(temp)

	-- reset self in case of changes
	if self.num ~= #self.rolls + 1 then
		TheLog.ch.CabbageTower:printf("ValidateTower %s EntityID %d - Num rolls (%d) mismatched with roll count (%d)",
			self.inst, self.inst.Network:GetEntityID(), self.num, #self.rolls + 1)
		if #self.rolls == 0 then
			self:SetSingle()
		elseif #self.rolls == 1 then
			self:SetDouble()
		elseif #self.rolls == 2 then
			self:SetTriple()
		end
	else
		if self.num == 1 then
			self:_ValidateSingle()
		end
	end

	-- reset rolls that are not assigned for whatever reason
	-- run even for remotes in case state gets messed up; it will get stomped by
	-- deserialization anyways
	for _i,roll in ipairs(self.rolls) do
		local tower = roll.components.cabbagetower
		if not tower:GetTower() then
			TheLog.ch.CabbageTower:printf("ValidateTower %s EntityID %d - Roll %s not assigned to master and will be added", 
			self.inst, self.inst.Network:GetEntityID(), roll)
			self:AddToTower(roll)
		elseif tower:GetTower() ~= self.inst then
			TheLog.ch.CabbageTower:printf("ValidateTower %s EntityID %d - Roll %s assigned to another master (%s) and will be removed", self.inst, roll, tower:GetTower())
			table.insert(temp, roll)
		end
	end

	for _i,roll in ipairs(temp) do
		table.removearrayvalue(temp, roll)
		roll:RemoveFromTower(self.inst)
	end
	table.clear(temp)
end

function CabbageTower:AddToTower(roll)
	local tower = roll.components.cabbagetower
	if not tower:GetTower() then
		roll.components.cabbagetower:SetTower(self.inst)
		if not table.arrayfind(self.rolls, roll) then
			table.insert(self.rolls, roll)
		end
		roll.Transform:SetPosition(0, 0, 0)
		roll.entity:SetParent(self.inst.entity)
		roll.components.powermanager:ResetData()
		roll:RemoveFromScene()
	end
end

function CabbageTower:RemoveFromTower(master)
	if self:GetTower() == master then
		local position = master:GetPosition()
		self.inst.entity:SetParent(nil)
		self:SetTower(nil)
		self.inst.components.powermanager:CopyPowersFrom(master)
		self.inst.Physics:Teleport(position:unpack())
		if self.inst:IsNetworked() then
			self.inst.Network:FlushAllHistory()
		end
		self.inst:ReturnToScene()
	end
end

function CabbageTower:RemoveTopRoll()
	local roll = table.remove(self.rolls)
	if not roll or roll and not roll:IsValid() then
		return
	end

	roll.components.cabbagetower:RemoveFromTower(self.inst)
	return roll
end

function CabbageTower:SetTower(tower)
	self.tower = tower
end

function CabbageTower:GetTower()
	return self.tower
end

function CabbageTower:SetStartingHealthPercentage(percentage)
	self.starting_health_percentage = percentage
end

function CabbageTower:GetHealthSplitPercentage()
	return self.starting_health_percentage * self.health_split_percentage
end

function CabbageTower:RefreshCombatCooldowns()
	for id, data in pairs(self.inst.components.attacktracker.attack_data) do
		if data.timer_id then
			local initial_cooldown_mod = self.inst.components.attacktracker.initial_cooldown_mod or 1
			self.inst.components.timer:StartTimer(data.timer_id, (data.initialCooldown or data.cooldown) * initial_cooldown_mod, true)
		end
	end
	self.inst.components.timer:StartTimer("combine_cd", 8, true)
end

function CabbageTower:SetSingle(prevent_combine)
	self.inst.components.cabbagerollstracker:Unregister()
	self.num = 1
	self.inst.components.cabbagerollstracker:Register(self.num)
	self.inst.components.cabbagerollstracker:SetCanCombine(not prevent_combine)

	self.inst:RemoveTag("nokill")

	-- art
	self.inst.AnimState:SetBank("cabbageroll_single_bank")
	self.inst.AnimState:PlayAnimation("idle", true)
	self.inst.AnimState:SetFrame(math.random(self.inst.AnimState:GetCurrentAnimationNumFrames()) - 1)
	if self.inst:IsNetworked() then
		self.inst.Network:FlushAllHistory()
	end

	-- stategraph
	self.inst.Physics:Stop()
	self.inst.Physics:SetSize(.9)
	self.inst:SetStateGraph(nil)
	self.inst:SetEmbellisherPrefab(self.inst:HasTag("elite") and "cabbageroll_elite" or "cabbageroll")
	self.inst:SetStateGraph("sg_cabbageroll")
	
	local modifiers = TUNING:GetEnemyModifiers(self.inst.prefab)

	-- health
	self.inst.components.health:SetMax((self.inst.tuning.health * self.num) * (modifiers.HealthMult + modifiers.BasicHealthMult), true)

	-- combat attacks
	self.inst.components.attacktracker:ResetData()
	self.inst.components.attacktracker:AddAttacks(self.attacks[self.num])
	self:RefreshCombatCooldowns()

	self.inst.components.combat:SetHasKnockdownHits(true)

	if self.inst.components.offsethitboxes and self.inst.components.offsethitboxes:Has("offsethitbox") then
		self.inst.components.offsethitboxes:SetEnabled("offsethitbox", false)
	end
end

function CabbageTower:SetDouble(roll)
	if roll then
		self:AddToTower(roll)
	end

	self.inst.components.cabbagerollstracker:Unregister()
	self.num = 2
	self.inst.components.cabbagerollstracker:Register(self.num)
	self.inst.components.cabbagerollstracker:SetCanCombine(true)

	self.inst:AddTag("nokill")

	-- art
	self.inst.AnimState:SetBank("cabbagerolls_double_bank")
	self.inst.AnimState:PlayAnimation("idle", true)
	self.inst.AnimState:SetFrame(math.random(self.inst.AnimState:GetCurrentAnimationNumFrames()) - 1)

	-- stategraph
	self.inst.Physics:Stop()
	self.inst.Physics:SetSize(.9)
	self.inst:SetStateGraph(nil)
	self.inst:SetEmbellisherPrefab(self.inst:HasTag("elite") and "cabbagerolls2_elite" or "cabbagerolls2")
	self.inst:SetStateGraph("sg_cabbagerolls2")

	local modifiers = TUNING:GetEnemyModifiers(self.inst.prefab)

	-- health
	self.inst.components.health:SetMax((self.inst.tuning.health * self.num) * (modifiers.HealthMult + modifiers.BasicHealthMult), true)

	-- combat attacks
	self.inst.components.attacktracker:ResetData()
	self.inst.components.attacktracker:AddAttacks(self.attacks[self.num])
	self:RefreshCombatCooldowns()

	self.inst.components.combat:SetHasKnockdownHits(false)

	monsterutil.AddOffsetHitbox(self.inst, 1.4)
end

function CabbageTower:SetTriple(roll)
	if roll then
		self:AddToTower(roll)
	end

	self.inst.components.cabbagerollstracker:Unregister()
	self.num = 3
	self.inst.components.cabbagerollstracker:Register(self.num)
	self.inst.components.cabbagerollstracker:SetCanCombine(true)

	self.inst:AddTag("nokill")

	-- art
	self.inst.AnimState:SetBank("cabbagerolls_bank")
	self.inst.AnimState:PlayAnimation("idle", true)
	self.inst.AnimState:SetFrame(math.random(self.inst.AnimState:GetCurrentAnimationNumFrames()) - 1)

	-- stategraph
	self.inst.Physics:Stop()
	self.inst.Physics:SetSize(.9)
	self.inst:SetStateGraph(nil)
	self.inst:SetEmbellisherPrefab(self.inst:HasTag("elite") and "cabbagerolls_elite" or "cabbagerolls")
	self.inst:SetStateGraph("sg_cabbagerolls")

	local modifiers = TUNING:GetEnemyModifiers(self.inst.prefab)

	-- health
	self.inst.components.health:SetMax((self.inst.tuning.health * self.num) * (modifiers.HealthMult + modifiers.BasicHealthMult), true)

	-- combat attacks
	self.inst.components.attacktracker:ResetData()
	self.inst.components.attacktracker:AddAttacks(self.attacks[self.num])
	self:RefreshCombatCooldowns()

	self.inst.components.combat:SetHasKnockdownHits(false)

	monsterutil.AddOffsetHitbox(self.inst, 1.4)
end

function CabbageTower:DebugDrawEntity(ui, panel, colors)
	local fns = {
		"SetSingle",
		"SetDouble",
		"SetTriple",
	}
	for _,fn_name in ipairs(fns) do
		if ui:Button(fn_name) then
			local fn = self[fn_name]
			fn(self)
		end
	end
end

return CabbageTower
