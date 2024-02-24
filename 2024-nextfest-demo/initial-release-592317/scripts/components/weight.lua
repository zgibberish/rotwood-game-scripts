local kassert = require "util.kassert"
require "util.sourcemodifiers"
local Enum = require "util.enum"
local Lume = require "util.lume"

-- local WeightNrBits <const> = 20	-- max 1<<20 = 1048576
-- local WeightStatusBits <const> = 3 -- expect Weight.Status ids to be [1,3]
-- local WeightMaxValue <const> = (1 << WeightNrBits) - 1

local LIGHT_THRESHOLD = -2
local HEAVY_THRESHOLD =  2

local Weight = nil -- Forward declaration for Weight.Rating enum
Weight = Class(function(self, inst)
	self.inst = inst
	self.weight_add_modifiers = AddSourceModifiers(inst)
	self.current = 0
	self.status = Weight.Status.s.Normal

	-- Tuning values
	self.min = -4
	self.light_threshold = LIGHT_THRESHOLD
	self.heavy_threshold = HEAVY_THRESHOLD
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

function Weight.ComputeStatus(weight)
	if weight >= HEAVY_THRESHOLD then
		return Weight.Status.s.Heavy
	elseif weight <= LIGHT_THRESHOLD then
		return Weight.Status.s.Light
	else
		return Weight.Status.s.Normal
	end
end

function Weight:UpdateStatus()
	self.status = Weight.ComputeStatus(self.current)
	self.inst.components.foleysounder:UpdateWeight(self.status)
end

-- Return a dict-like table of EquipmentWeights indexed by Equipment.Slots.
function Weight:GetWeights()
	local weights = {}
	local Equipment = require "defs.equipment"
	local relevant_slots = { Equipment.Slots.WEAPON, Equipment.Slots.HEAD, Equipment.Slots.BODY, Equipment.Slots.WAIST }
	local hoard = self.inst.components.inventoryhoard
	for _,slot in ipairs(relevant_slots) do
		local item = hoard:GetEquippedItem(slot)
		weights[slot] = item
			 and item:GetDef().weight
			 or Weight.EquipmentWeight.s.None
	end
	return weights
end

function Weight.SumWeights(weights)
	return Lume(weights)
		:map(function(weight) return Weight.EquipmentWeight_to_WeightMod[weight] end)
		:reduce(function(current, weight) return current + weight end)
		:result()
end

function Weight:ResetAndUpdateEquipmentWeight()
	local status = self:GetStatus()

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

	if status ~= self:GetStatus() then
		self:OnStatusChangeByEquipment(status)
	end
end

function Weight:OnStatusChangeByEquipment(previous_status)
	local STRINGS = STRINGS.UI.WEIGHT_CHANGED_SCREEN
	local current_status = self:GetStatus()
	local CheckFirstTimeWeightClassSeen = function(persistent_has_seen, weight_class, label, description)
		if Profile:GetValue(persistent_has_seen, false) then
			return
		end
		if current_status ~= weight_class then
			return
		end
		local ConfirmDialog = require "screens.dialogs.confirmdialog"
		local screen = ConfirmDialog(
			nil, 
			nil, 
			false,
			STRINGS.TITLE,
			STRINGS.SUB_TITLE_FMT:subfmt({ weight_class = label, }),
			description
		)
		screen
			:SetYesButton(STRINGS.OK, function()
				Profile:SetValue(persistent_has_seen, true)
				Profile:Save()
				screen:Close() 
			end)
			:HideNoButton()
			:HideArrow() -- An arrow can show under the dialog pointing at the clicked element
			:SetMinWidth(600)
			:CenterText() -- Aligns left otherwise
			:CenterButtons() -- They align left otherwise
		TheFrontEnd:PushScreen(screen)
	end
	CheckFirstTimeWeightClassSeen(
		"seen_light_weight", 
		Weight.Status.s.Light, 
		STRINGS.LIGHT.BRIEF,
		STRINGS.LIGHT.VERBOSE
	)
	CheckFirstTimeWeightClassSeen(
		"seen_heavy_weight", 
		Weight.Status.s.Heavy, 
		STRINGS.HEAVY.BRIEF,
		STRINGS.HEAVY.VERBOSE
		)
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
