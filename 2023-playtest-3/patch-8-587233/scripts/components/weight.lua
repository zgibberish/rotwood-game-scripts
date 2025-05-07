local kassert = require "util.kassert"
require "util.sourcemodifiers"
local Enum = require "util.enum"

-- local WeightNrBits <const> = 20	-- max 1<<20 = 1048576
-- local WeightStatusBits <const> = 3 -- expect Weight.Status ids to be [1,3]
-- local WeightMaxValue <const> = (1 << WeightNrBits) - 1

local Weight = nil -- Forward declaration for Weight.Rating enum
Weight = Class(function(self, inst)
	self.inst = inst
	self.weight_add_modifiers = AddSourceModifiers(inst)
	self.current = 0
	self.status = Weight.Status.s.Normal

	-- Tuning values
	self.min = -4
	self.light_threshold = -2
	self.heavy_threshold = 2
	self.max = 4

	-- Every entity is, by default, 0. This represents an abstraction of their weight.
	-- From -4 to -2 is Light
	-- from -1 to 1 is Normal
	-- from 2 to 4 is Heavy

	self._new_run_fn = function()
		self:CalculateAndSetWeight()
	end

	self._loadout_changed_fn = function()
		self:ResetAndUpdateEquipmentWeight()
		self:CalculateAndSetWeight()
	end

	self.inst:ListenForEvent("start_new_run", self._new_run_fn)
	self.inst:ListenForEvent("loadout_changed", self._loadout_changed_fn)
	self.inst:ListenForEvent("end_current_run", self._new_run_fn)
end)

Weight.Status = Enum { "Light", "Normal", "Heavy" } -- These weights are relative to this entity's default state. Every entity weighs "0" by default, and gets relatively Lighter or Heavier

Weight.EquipmentWeight = Enum { "Light", "Normal", "Heavy", "None" } -- None = no armor

Weight.EquipmentWeight_to_WeightMod =
{
	[Weight.EquipmentWeight.s.Light] = -1,
	[Weight.EquipmentWeight.s.Normal] = 0,
	[Weight.EquipmentWeight.s.Heavy] = 1,
	[Weight.EquipmentWeight.s.None] = -1,
}

function Weight.GetWeightStringForValue(value)
	if value == -1 then
		return STRINGS.UI.INVENTORYSCREEN.WEIGHT_LIGHT
	elseif value == 0 then
		return STRINGS.UI.INVENTORYSCREEN.WEIGHT_NORMAL
	elseif value == 1 then
		return STRINGS.UI.INVENTORYSCREEN.WEIGHT_HEAVY
	else
		dbassert("Trying to get Weight String for a weight value that we don't support.", value)
	end
end

function Weight:GetMin()
	return self.min
end
function Weight:GetMax()
	return self.max
end

function Weight:GetCurrent()
	return self.current
end

function Weight:GetStatus()
	return self.debugstatus or self.status
end

function Weight:SetDebugStatus(status)
	self.debugstatus = status
	self.inst:PushEvent("weightchanged",
		{
			old = nil,
			new = self:GetCurrent(),
			class = self:GetStatus()
		})
end
function Weight:ClearDebugStatus(status)
	self.debugstatus = nil
	self.inst:PushEvent("weightchanged",
		{
			old = nil,
			new = self:GetCurrent(),
			class = self:GetStatus()
		})
end

function Weight:IsLight()
	return self:GetStatus() == Weight.Status.s.Light
end
function Weight:IsNormal()
	return self:GetStatus() == Weight.Status.s.Normal
end
function Weight:IsHeavy()
	return self:GetStatus() == Weight.Status.s.Heavy
end

function Weight:GetTotalWeightAddModifiers()
	return self.weight_add_modifiers:Get()
end

function Weight:AddWeightAddModifier(source_id, bonus, silent)
	self.weight_add_modifiers:SetModifier(source_id, bonus)
	if not silent then
		self:CalculateAndSetWeight()
	end
end

function Weight:RemoveWeightAddModifier(source_id, silent)
	self.weight_add_modifiers:RemoveModifier(source_id)
	if not silent then
		self:CalculateAndSetWeight()
	end
end

function Weight:GetWeightAddModifierBySource(source_id)
	return self.weight_add_modifiers[source_id]
end

function Weight:UpdateStatus()
	local current = self.current
	local status = Weight.Status.s.Normal

	if current >= self.heavy_threshold then
		status = Weight.Status.s.Heavy
	elseif current <= self.light_threshold then
		status = Weight.Status.s.Light
	end

	self.status = status
end

function Weight:ResetAndUpdateEquipmentWeight()
	self:RemoveWeightAddModifier("equipment_weapon", true)
	self:RemoveWeightAddModifier("equipment_head", true)
	self:RemoveWeightAddModifier("equipment_body", true)
	self:RemoveWeightAddModifier("equipment_waist", true)

	local inventoryhoard = self.inst.components.inventoryhoard
	local weapon = inventoryhoard:GetEquippedItem("WEAPON")
	local head = inventoryhoard:GetEquippedItem("HEAD")
	local body = inventoryhoard:GetEquippedItem("BODY")
	local waist = inventoryhoard:GetEquippedItem("WAIST")

	-- TODO @jambell #weight make this less prototypey
	local empty_slot_mod = Weight.EquipmentWeight_to_WeightMod[Weight.EquipmentWeight.s.None]

	local weapon_mod = weapon and Weight.EquipmentWeight_to_WeightMod[weapon:GetDef().weight] or empty_slot_mod
	self:AddWeightAddModifier("equipment_weapon", weapon_mod, true)
	
	local head_mod = head and Weight.EquipmentWeight_to_WeightMod[head:GetDef().weight] or empty_slot_mod
	self:AddWeightAddModifier("equipment_head", head_mod, true)

	local body_mod = body and Weight.EquipmentWeight_to_WeightMod[body:GetDef().weight] or empty_slot_mod
	self:AddWeightAddModifier("equipment_body", body_mod, true)

	local waist_mod = waist and Weight.EquipmentWeight_to_WeightMod[waist:GetDef().weight] or empty_slot_mod
	self:AddWeightAddModifier("equipment_waist", waist_mod, true)

	self:CalculateAndSetWeight()
end

function Weight:CalculateAndSetWeight()
	if not self.inst:IsLocal() then
		return
	end

	local old = self:GetCurrent()
	local new = 0

	new = new + self:GetTotalWeightAddModifiers()

	new = math.clamp(new, self:GetMin(), self:GetMax())

	if new ~= old then
		self.current = new
		self:UpdateStatus()
		self.inst:PushEvent("weightchanged",
		{
			old = old,
			new = self:GetCurrent(),
			class = self:GetStatus()
		})
	end
end

function Weight:OnSave()
	local data = {}

	data.max = self:GetMax()
	data.current = self:GetCurrent()

	-- if next(self.weight_add_modifiers) then
	-- 	data.weight_add_modifiers = deepcopy(self.weight_add_modifiers)
	-- end

	-- if next(self.weight_mult_modifiers) then
	-- 	data.weight_mult_modifiers = deepcopy(self.weight_mult_modifiers)
	-- end

	return next(data) and data or nil
end

function Weight:OnLoad(data)

	if data.max ~= self:GetMax() then
		self:SetMax(data.max)
	end

	-- if data.weight_add_modifiers then
	-- 	for id, mod in pairs(data.weight_add_modifiers) do
	-- 		self:AddWeightAddModifier(id, mod)
	-- 	end
	-- end

	-- if data.weight_mult_modifiers then
	-- 	for id, mod in pairs(data.weight_mult_modifiers) do
	-- 		self:AddWeightMultModifier(id, mod)
	-- 	end
	-- end

	if data.current ~= self:GetCurrent() then
		self:CalculateAndSetWeight()
	end
end

function Weight:OnNetSerialize()
	-- local e = self.inst.entity

	-- local status_id = Weight.Status.id[self.status] -- Serialize the enum id, not the string
	-- e:SerializeUInt(status_id, 2)

	-- if e:IsTransferable() then
	-- 	local current = self:GetCurrent()
	-- 	current = current + self.min -- Move the integer out of negative values and min=0
	-- 	e:SerializeUInt(current, 4)
	-- end

	-- local count = self.weight_add_modifiers:GetModifierCount()
	-- e:SerializeUInt(count, 4) -- TODO: add max?

	-- local add_mods = self.weight_add_modifiers:GetModifiers()
	-- for source,mod in pairs(add_mods) do
	-- 	e:SerializeString(source)
	-- 	e:SerializeUInt(mod, 4)
	-- end
	--		check how many modifiers we have
	--			serialize each
end

function Weight:OnNetDeserialize()
	-- local e = self.inst.entity

	-- local status_id = e:DeserializeUInt(2)
	-- self.status = Weight.Status:FromId(status_id)

	-- if e:IsTransferable() then
	-- 	local current = e:DeserializeUInt(4)
	-- 	self.current = current - self.min -- Move the integer back into negative values, instead of min=0
	-- end
end

function Weight:GetDebugString()
	-- return tostring(self:GetCurrent()).."/"..tostring(self:GetMax()) .. " " .. Weight.Status:FromId(self.status)
end

function Weight:DebugDrawEntity(ui, panel, colors)
	ui:Text("Current Weight: " .. self.current)
	ui:Text("Current Status: " .. self.status)
end


return Weight
