require "util.sourcemodifiers"
local Equipment = require "defs.equipment"
local Weight = require "components/weight"
local lume = require "util.lume"
local kassert = require "util.kassert"

local PlayerRoller = Class(function(self, inst)
	self.inst = inst
	self.iframes = TUNING.PLAYER.ROLL.NORMAL.IFRAMES -- TODO: does this initialize to Normal even if you load up as Light? or does weightchanged event happen after this in order?

	self.base_roll_ticks = TUNING.PLAYER.ROLL.NORMAL.LENGTH_ANIMFRAMES
	self.base_roll_distance = TUNING.PLAYER.ROLL.NORMAL.DISTANCE

	self.current_iframes = nil

	self.iframe_add_modifiers = {}
	self.distance_mult_modifiers = {}
	self.ticks_mult_modifiers = {}

	self._onweightchanged = function(inst, data) self:OnWeightChanged(inst, data) end
	self.inst:ListenForEvent("weightchanged", self._onweightchanged)

	self._onloadoutchanged = function(inst) self:OnLoadoutChanged(inst) end
	self.inst:ListenForEvent("loadout_changed", self._onloadoutchanged)

end)

function PlayerRoller:GetIframes()
	return math.max(0, self.iframes + self:GetIframeAddModifiers())
end

function PlayerRoller:GetTotalDistance()
	return self:ApplyDistanceMultModifiers(self.base_roll_distance)
end

function PlayerRoller:GetTotalTicks()
	return self:ApplyTicksMultModifiers(self.base_roll_ticks)
end

-------------------------------------------------

-- iframes
function PlayerRoller:GetIframeAddModifiers()
	local total = 0
	for id, bonus in pairs(self.iframe_add_modifiers) do
		total = total + bonus
	end
	return total
end

function PlayerRoller:AddIframeModifier(source_id, bonus)
	kassert.typeof("string", source_id)
	self.iframe_add_modifiers[source_id] = bonus
end

function PlayerRoller:RemoveIframeModifier(source_id)
	kassert.typeof("string", source_id)
	self.iframe_add_modifiers[source_id] = nil
end

function PlayerRoller:GetIframeModifierBySource(source_id)
	kassert.typeof("string", source_id)
	return self.iframe_add_modifiers[source_id]
end

function PlayerRoller:StartIFrames()
	self.inst:StartUpdatingComponent(self)
	self.current_iframes = self:GetIframes() * ANIM_FRAMES

	self.inst.HitBox:SetInvincible(true)
end

function PlayerRoller:StopIframes()
	self.current_iframes = nil
	self.inst.HitBox:SetInvincible(false)
	self.inst:StopUpdatingComponent(self)
end


function PlayerRoller:OnUpdate()
	self.current_iframes = self.current_iframes - 1

	if self.current_iframes <= 0 then
		self:StopIframes()
	end
end

-- roll distance/speed

function PlayerRoller:AddDistanceMultModifier(source_id, mult)
	kassert.typeof("string", source_id)
	self.distance_mult_modifiers[source_id] = mult
end

function PlayerRoller:RemoveDistanceMultModifier(source_id)
	kassert.typeof("string", source_id)
	self.distance_mult_modifiers[source_id] = nil
end

function PlayerRoller:ApplyDistanceMultModifiers(num)
	local total = 1
	for id, mod in pairs(self.distance_mult_modifiers) do
		total = total + mod
	end
	return total * num
end

function PlayerRoller:AddTicksMultModifier(source_id, mult)
	kassert.typeof("string", source_id)
	self.ticks_mult_modifiers[source_id] = mult
end

function PlayerRoller:RemoveTicksMultModifier(source_id)
	kassert.typeof("string", source_id)
	self.ticks_mult_modifiers[source_id] = nil
end

function PlayerRoller:ApplyTicksMultModifiers(num)
	local total = 1
	for id, mod in pairs(self.ticks_mult_modifiers) do
		total = total + mod
	end
	return lume.round(total * num)
end

function PlayerRoller:ClearAllModifiers()
	self.iframe_add_modifiers = {}
	self.distance_mult_modifiers = {}
	self.ticks_mult_modifiers = {}
end

-------------------------------------------------

function PlayerRoller:OnWeightChanged(inst, data)
	-- Check to see if the new weight has any things that should change our roll properties

	local weight = data.class
	local weapon = self.inst.components.inventoryhoard:GetEquippedItem(Equipment.Slots.WEAPON)
	local type = weapon:GetDef().weapon_type
	self:_UpdateBaseDistance(type, weight)
	self:_UpdateTicks(type, weight)
	self:_UpdateIFrames(weight)
end

function PlayerRoller:OnLoadoutChanged()
	-- Check to see if the new weapon type we equipped should override anything about our roll

	local weight = self.inst.components.weight:GetStatus()
	local weapon = self.inst.components.inventoryhoard:GetEquippedItem(Equipment.Slots.WEAPON)
	local type = weapon:GetDef().weapon_type
	self:_UpdateBaseDistance(type, weight)
	self:_UpdateTicks(type, weight)
	self:_UpdateIFrames(weight)
end

function PlayerRoller:_UpdateBaseDistance(type, weight)
	weight = string.upper(weight) -- Tuning file is all caps

	-- Take the Weight Class's distance

	local distance = TUNING.PLAYER.ROLL[weight].DISTANCE

	-- If this Weapon Type has an override for this weight type, then use it instead.
	if TUNING.GEAR.WEAPONS[type].ROLL_DISTANCE_OVERRIDE and TUNING.GEAR.WEAPONS[type].ROLL_DISTANCE_OVERRIDE[weight] then
		distance = TUNING.GEAR.WEAPONS[type].ROLL_DISTANCE_OVERRIDE[weight]
	end
	self.base_roll_distance = distance
end

function PlayerRoller:_UpdateTicks(type, weight)
	weight = string.upper(weight) -- Tuning file is all caps

	-- Take the Weight Class's animframes
	local animframes = TUNING.PLAYER.ROLL[weight].LENGTH_ANIMFRAMES

	-- If this Weapon Type has an override for this weight type, then use it instead.
	if TUNING.GEAR.WEAPONS[type].ROLL_LENGTH_ANIMFRAMES_OVERRIDE and TUNING.GEAR.WEAPONS[type].ROLL_LENGTH_ANIMFRAMES_OVERRIDE[weight] then
		animframes = TUNING.GEAR.WEAPONS[type].ROLL_LENGTH_ANIMFRAMES_OVERRIDE[weight]
	end
	self.base_roll_ticks = animframes * ANIM_FRAMES
end

function PlayerRoller:_UpdateIFrames(weight)
	local frames
	if weight == Weight.Status.s.Light then
		frames = TUNING.PLAYER.ROLL.LIGHT.IFRAMES
	elseif weight == Weight.Status.s.Heavy then
		frames = TUNING.PLAYER.ROLL.HEAVY.IFRAMES
	else
		frames = TUNING.PLAYER.ROLL.NORMAL.IFRAMES
	end

	self.iframes = frames
end

function PlayerRoller:OnSave()
	local data = {}

	data.iframes = self.iframes

	if next(self.iframe_add_modifiers) then
		data.iframe_add_modifiers = deepcopy(self.iframe_add_modifiers)
	end

	if next(self.distance_mult_modifiers) then
		data.distance_mult_modifiers = deepcopy(self.distance_mult_modifiers)
	end

	return next(data) and data or nil
end

function PlayerRoller:OnLoad(data)
	if data.iframes ~= self.iframes then
		self.iframes = data.iframes
	end

	if data.iframe_add_modifiers then
		for id, mod in pairs(data.iframe_add_modifiers) do
			self:AddIframeModifier(id, mod)
		end
	end

	if data.distance_mult_modifiers then
		for id, mod in pairs(data.distance_mult_modifiers) do
			self:AddDistanceMultModifier(id, mod)
		end
	end
end

return PlayerRoller
