-- Component for handling reviving a player. Mainly set up to act as an interface for sending revive data in multiplayer.
-- This component is set up to handle both the reviver and revivee.
-- (TODO: Make separate components for reviver & revivee!)
local Enum = require "util.enum"
local lume = require "util.lume"
local easing = require "util.easing"
local SGCommon = require "stategraphs.sg_common"

local Revive = nil -- Forward declaration for Health.Status enum
Revive = Class(function(self, inst)
    self.inst = inst

	self.revivetimer = nil -- UI widget to display revival progress; used by both reviver and revivee
	self.revivefx_interval = nil -- Value used to determine when to show reviving FX on the revivee

	-- In case someone disconnects while reviving:
	self._onremove = function()
		self:_RemoveTimerHUD()

		-- Reset the remaining reviver or revivee player's follow health bar preview
		if self.reviver then
			self.reviver:PushEvent("previewhealthchange_end")
		elseif self.revivee then
			self.revivee:PushEvent("previewhealthchange_end")
		end
	end
	self.inst:ListenForEvent("onremove", self._onremove )
end)

function Revive:OnPostSpawn()
	-- these modify interact component state
	-- put here to avoid constructor initialization order issues
	self:_ReviveeResetState()
	self:ReviveeResetState()
end

-- Used to determine if a revivee (revive target) is revivable, reviving, etc.
Revive.Status = Enum{ "NORMAL", "REVIVABLE", "REVIVING" }
local ReviveStatusNrBits = 2

function Revive:OnNetSerialize()
	local e = self.inst.entity

	e:SerializeBoolean(self.last_revive_attempt_success and true or false)
	if self.last_revive_attempt_success then
		e:SerializeEntityID(self.last_revivee.Network:GetEntityID())
	end

	local is_reviver = (self.revivee ~= nil and self.revivee:IsValid())
	local is_revivee = (self.revivee_status and self.revivee_status ~= Revive.Status.id.NORMAL or false)
	e:SerializeBoolean(is_reviver)
	e:SerializeBoolean(is_revivee)
	assert(not (is_reviver and is_revivee))

	if is_reviver then
		e:SerializeEntityID(self.revivee.Network:GetEntityID())
		e:SerializeDoubleAs16Bit(self.revive_time)
		e:SerializeDoubleAs16Bit(self.current_revive_time)
	elseif is_revivee then
		if self.reviver and self.reviver:IsValid() then
			e:SerializeBoolean(true)
			e:SerializeEntityID(self.reviver.Network:GetEntityID())
		else
			e:SerializeBoolean(false)
		end
		e:SerializeUInt(self.revivee_status, ReviveStatusNrBits)
	end
end

local function TryGetEntity(entity_id)
	local guid = TheNet:FindGUIDForEntityID(entity_id)
	if guid and guid ~= 0 and Ents[guid] and Ents[guid]:IsValid() then
		return Ents[guid]
	end
	return nil
end

function Revive:OnNetDeserialize()
	local e = self.inst.entity

	self.last_revive_attempt_success = e:DeserializeBoolean()
	if self.last_revive_attempt_success then
		local last_revivee_entity_id = e:DeserializeEntityID()
		self.last_revivee = TryGetEntity(last_revivee_entity_id)

		self:_ReviveeHandleLastReviveSuccess()
	else
		self:_ReviveeHandleReviveCancel()
		self.last_revivee = nil
	end

	local is_reviver = e:DeserializeBoolean()
	local is_revivee = e:DeserializeBoolean()
	assert(not (is_reviver and is_revivee))

	if is_reviver then
		local revivee_entity_id = e:DeserializeEntityID()
		self.revive_time = e:DeserializeDoubleAs16Bit()
		self.current_revive_time = e:DeserializeDoubleAs16Bit()

		local revivee_ent = TryGetEntity(revivee_entity_id)
		if revivee_ent then
			self.revivee = revivee_ent
			self:_ReviveeHandleReviveStart()
		else
			self:_ReviveeHandleReviveCancel()
			self.revivee = nil
		end
	elseif is_revivee then
		local has_reviver = e:DeserializeBoolean()
		if has_reviver then
			local reviver_entity_id = e:DeserializeEntityID()
			self.reviver = TryGetEntity(reviver_entity_id)
		else
			self.reviver = nil
		end
		local new_status = e:DeserializeUInt(ReviveStatusNrBits)

		self:_ReviveeSetStatus(new_status)
	else
		self:ReviveeResetState()
		self:_ReviveeResetState()
	end
end

function Revive:GetReviveTime()
	return self.revive_time
end

function Revive:GetCurrentReviveTime()
	return self.current_revive_time
end

function Revive:CanRevive()
	return self.reviver == nil and self.revivee_status and self.revivee_status == Revive.Status.id.REVIVABLE
end

function Revive:IsBeingRevived()
	return self.revivee_status and self.revivee_status == Revive.Status.id.REVIVING
end

function Revive:HasReviver()
	return self.reviver and self.reviver:IsValid()
end

function Revive:IsReviver(entity)
	return self.reviver and self.reviver == entity
end

--------------------------------------------------------------------------
-- Reviver functions
local REVIVE_TIME = TUNING.REVIVE_TIME

function Revive:_ReviverResetLastAttempt()
	self.last_revive_attempt_success = nil
	self.last_revivee = nil
end

function Revive:_ReviveeResetState(was_last_revive_successful)
	self.last_revive_attempt_success = was_last_revive_successful
	self.last_revivee = self.revivee
	if self.last_revive_attempt_success ~= nil then
		self.inst:DoTaskInTime(1, function(inst)
			inst.components.revive:_ReviverResetLastAttempt()
		end)
	end

	self.revivee = nil
	self.revive_time = nil
	self.current_revive_time = nil
end

function Revive:ReviverStartReviving(target)
	assert(self.inst:IsLocal())

	self.revivee = target
	self:_ReviverSetTimeRemaining(REVIVE_TIME)

	TheDungeon.HUD:HidePrompt(target)

	self:_ReviveeHandleReviveStart()
end

function Revive:ReviverIsInRange()
	local pos = self.inst:GetPosition()
	local targetpos = self.revivee:GetPosition()

	if not pos or not targetpos then
		return false
	end

	local distanceToTarget = pos:dist(targetpos)
	local interact_radius = self.revivee.components.interactable:GetRadius()
	return distanceToTarget <= interact_radius
end

function Revive:_ReviverCompleteReviving(last_revive_attempt_success)
	self:_ReviveeResetState(last_revive_attempt_success)
	self:_RemoveTimerHUD()
end

function Revive:ReviverFinishReviving()
	self.inst:PushEvent("revive", { revivee = self.last_revivee, health = self.inst.components.health:GetReviveAmount() }) -- TODO: move this somewhere I can get the revived health
	self:_ReviverCompleteReviving(true)
	self:_ReviveeHandleLastReviveSuccess()
end

function Revive:ReviverCancelReviving()
	self:_ReviveeHandleReviveCancel()
	self:_ReviverCompleteReviving(false)
end

function Revive:_ReviverSetTimeRemaining(time)
	self.revive_time = time
	self.current_revive_time = time
end

function Revive:ReviverUpdateTimeRemaining(time_spent_reviving)
	assert(self.revive_time and self.revive_time > 0)
	self.current_revive_time = math.max(0, self.revive_time - time_spent_reviving)
end
--------------------------------------------------------------------------
-- Revivee functions

function Revive:ReviveeResetState()
	self.reviver = nil
	self:_ReviveeSetStatus(Revive.Status.id.NORMAL)
end

function Revive:ReviveeSetRevivable()
	if self.inst:IsLocal() then
		self.reviver = nil
		self:_ReviveeSetStatus(Revive.Status.id.REVIVABLE)
	end
end

local function RevivableInteractConditionFn(inst, player)
	return inst ~= player
		and inst.components.revive:CanRevive()
		and inst.components.revive.revivee_status == Revive.Status.id.REVIVABLE
end

local function DoRevivingFX(inst)
	local rc = inst.components.revive
	if rc.reviver then
		local revive_time = rc.reviver.components.revive:GetReviveTime()
		local revive_time_remaining = rc.reviver.components.revive:GetCurrentReviveTime()

		if revive_time and revive_time_remaining then
			local blink_interval = easing.linear(revive_time_remaining, 2, 8, revive_time)
			SGCommon.Fns.BlinkAndFadeColor(inst, { 102/255, 204/255, 51/255, 0.5 }, blink_interval)

			rc.revivefx_interval = easing.linear(revive_time_remaining, 0, 1, revive_time)
			inst:DoTaskInTime(rc.revivefx_interval, DoRevivingFX)
		end
	end
end

function Revive:_ReviveeSetStatus(new_status)
	if self.revivee_status ~= new_status then
		if new_status == Revive.Status.id.REVIVABLE then
			self.inst.components.interactable:SetInteractConditionFn(RevivableInteractConditionFn)
			self:_RemoveTimerHUD()
		elseif new_status == Revive.Status.id.NORMAL then
			self.inst.components.interactable:SetInteractCondition_Never()
			self:_RemoveTimerHUD()
		elseif new_status == Revive.Status.id.REVIVING then
			if self.reviver then
				self:_StartTimerHUD()

				-- Setup for Reviving FX
				self.revivefx_interval = 1
				DoRevivingFX(self.inst)
			else
				self:_ReviveeSetStatus(Revive.Status.id.REVIVABLE)
				return -- to avoid stomping status in recursive call
			end
		end
		self.revivee_status = new_status
	end
end

-- Revivee conditional handling of reviver "events" (starting, canceling, succeeding)
-- Either directly called for local revivers or through network deserialization changes

function Revive:_ReviveeHandleReviveStart()
	-- reviver started reviving
	if self.revivee:IsLocal() and
		self.revivee.components.revive:CanRevive() and
		not self.revivee.components.revive:HasReviver() then
		self.revivee.components.revive:_ReviveeStartReviving(self.inst)
	end
end

function Revive:_ReviveeHandleLastReviveSuccess()
	-- reviver finished
	if self.last_revivee and
		self.last_revivee:IsLocal() and
		self.last_revivee.components.revive.revivee_status == Revive.Status.id.REVIVING and
		self.last_revivee.components.revive:HasReviver() and self.last_revivee.components.revive:IsReviver(self.inst) then
			self.last_revivee.components.revive:_ReviveeFinishReviving()
		end
end

function Revive:_ReviveeHandleReviveCancel()
	-- reviver stopped reviving for any reason
	if self.revivee and self.revivee:IsLocal() and
		self.revivee.components.revive:HasReviver() and self.revivee.components.revive:IsReviver(self.inst) then
		self.revivee.components.revive:_ReviveeCancelReviving()
	end
end

function Revive:_ReviveeStartReviving(reviver)
	assert(self.inst:IsLocal())
	self.reviver = reviver
	self:_ReviveeSetStatus(Revive.Status.id.REVIVING)
end

function Revive:_ReviveeFinishReviving()
	if self.revivee_status == Revive.Status.id.REVIVING then
		self.inst.components.health:SetRevived(self.reviver)
		self:ReviveeResetState()
		self.inst:StopUpdatingComponent(self)
	end
end

function Revive:_ReviveeCancelReviving()
	if self.revivee_status == Revive.Status.id.REVIVING then
		self:_ReviveeSetStatus(Revive.Status.id.REVIVABLE)
		self.reviver = nil
		self.inst:StopUpdatingComponent(self)
	end
end

-- Stategraph state change listener
-- Takes revivee out of reviving process when hit, etc.
function Revive:OnReviveeSGStateChanged(data)
	if not self.inst.sg:HasStateTag("revivable") then
		self:ReviveeResetState()
	elseif self.inst:IsLocal() and self.revivee_status ~= Revive.Status.id.REVIVING then
		-- Set to revivable only if we aren't currently being revived.
		self:ReviveeSetRevivable() -- TODO: victorc: not sure we want this
	end
end

--------------------------------------------------------------------------
-- Common Revive Timer/Presentation API

function Revive:_StartTimerHUD()
	if not self.revivetimer then
		self.revivetimer = TheDungeon.HUD:MakeReviveTimerText(self.inst, self.reviver)
			:SetOffsetFromTarget(Vector3.unit_y * 4.5)
	end
	self.inst:StartUpdatingComponent(self)
end

function Revive:_RemoveTimerHUD()
	if self.revivetimer then
		self.revivetimer:Remove()
		self.revivetimer = nil
	end
end


function Revive:OnUpdate(_dt)
	if self.revivetimer then
		if self.reviver and self.reviver:IsValid() then
			-- Get the revive time remaining from the reviver
			local revive_time_remaining = self.reviver.components.revive:GetCurrentReviveTime()
			if revive_time_remaining then
				if self.reviver:IsLocal() and self.revivetimer:GetText() == "" then
					self.revivetimer:SetText(STRINGS.UI.ACTIONS.REVIVING)
				end
				local elapsed_time = self.reviver.components.revive:GetReviveTime() - revive_time_remaining
				local change = self.reviver.components.revive:GetReviveTime()
				local duration = self.reviver.components.revive:GetReviveTime()
				self.revivetimer:SetProgress(easing.outQuad(elapsed_time, 0, change, duration)/change)

			end
		end
	else
		self.inst:StopUpdatingComponent(self)
	end
end

return Revive
