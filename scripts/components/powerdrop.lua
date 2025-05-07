local kstring = require "util.kstring"
local Power = require 'defs.powers'
local FollowLabel = require "widgets.ftf.followlabel"

local PowerDrop = Class(function(self, inst)
	self.inst = inst
	self.power_type = nil
	self.power_category = nil
	self.powers = {}

	self.interact_radius = 2
	self.num_powers = 2 -- num_choices
	self.inst:AddComponent("roomlock")
	self.inst:AddTag("powerdrop")

	-- synchronized data
	-- configuration
	self.spawn_order = 1 --if there are multiple power drops being spawned at once, what is the sequence of their appearance?
	self.appear_delay = 0 --after the prefab has been spawned, how many ticks until it appears?
	-- state
	self.prepared_id = 0 -- prepare can be called multiple times, so use a unique id to represent each call
	self.allowinteraction = false
	self.picked = false

end)

function PowerDrop:OnEntityBecameLocal()
	-- Power drops need to be registered with the host after the EntityID is assigned. OnEntityBecameLocal is a spot where it is guaranteed to have a valid EntityID
	if TheNet:IsHost() then
		if self.power_type == Power.Types.RELIC then
			TheNet:SpawnPowerDrop(self.inst.Network:GetEntityID(), POWERDROP_RELIC)
		elseif self.power_type == Power.Types.SKILL then
			TheNet:SpawnPowerDrop(self.inst.Network:GetEntityID(), POWERDROP_SKILL)
		elseif self.power_type == Power.Types.FABLED_RELIC then
			TheNet:SpawnPowerDrop(self.inst.Network:GetEntityID(), POWERDROP_POWERFABLED)
		else
			assert(false, "PowerDrop: Unknown power type!")
		end
	end
end

function PowerDrop:OnNetSerialize()
	local e = self.inst.entity
	e:SerializeUInt(self.spawn_order, 4)
	e:SerializeUInt(self.appear_delay, 8)
	e:SerializeUInt(self.prepared_id, 8)
	e:SerializeBoolean(self.picked)
	e:SerializeBoolean(self.allowinteraction)
end

function PowerDrop:OnNetDeserialize()
	local e = self.inst.entity
	self.spawn_order = e:DeserializeUInt(4)
	self.appear_delay = e:DeserializeUInt(8)
	local old_prepared_id = self.prepared_id
	self.prepared_id = e:DeserializeUInt(8)
	local old_picked = self.picked
	self.picked = e:DeserializeBoolean()
	local old_allowinteraction = self.allowinteraction
	self.allowinteraction = e:DeserializeBoolean()

	if old_prepared_id ~= self.prepared_id then
		self:PrepareToShowGem()
	end
	if old_picked ~= self.picked and self.picked then
		self:OnPowerPicked()
	end
	if old_allowinteraction ~= self.allowinteraction then
		if self.allowinteraction then
			TheLog.ch.PowerDrop:printf("NetDeserialize: AllowInteraction")
			self:AllowInteraction()
		else
			TheLog.ch.PowerDrop:printf("NetDeserialize: PreventInteraction")
			self:PreventInteraction()
		end
	end
end

function PowerDrop:_ClearExclusivePartner()
	local partner = self.exclusive_partner
	if partner then
		-- Remove self from partner so they don't activate us.
		self.exclusive_partner = nil
		partner.components.powerdrop:_ClearExclusivePartner()
	end
end
function PowerDrop:OnRemoveFromEntity()
	self:_ClearExclusivePartner()
end
PowerDrop.OnRemoveEntity = PowerDrop.OnRemoveFromEntity

function PowerDrop:SetPowerType(type)
	self.power_type = type
end

function PowerDrop:GetPowerType()
	return self.power_type
end

function PowerDrop:SetPowerCategory(category)
	self.power_category = category
end

function PowerDrop:SetOnPrepareToShowGem(fn)
	self.on_preparetoshowgem = fn
end

-- Configure everything about display here.
function PowerDrop:PrepareToShowGem(cfg)
	if cfg then
		if not TheNet:IsHost() then
			return
		end
		self.appear_delay = assert(cfg.appear_delay_ticks)
		self.spawn_order = cfg.spawn_order or 1
		self.prepared_id = self.prepared_id + 1
	end
	self.on_preparetoshowgem(self.inst)
end

function PowerDrop:GetAppearDelay()
	return self.appear_delay
end

function PowerDrop:GetSpawnOrder()
	return self.spawn_order
end

function PowerDrop:PreventInteraction()
	self.inst.components.interactable:SetInteractCondition_Never()
	self.inst.components.interactable:SetCanConditionBreakFocus(true)
	self.allowinteraction = false
end

local function OnApproachInteraction(inst, player)
	local partner = inst.components.powerdrop.exclusive_partner
	if partner then
		partner:PushEvent("selfdestruct_hint")
	end
end

local function OnDepartInteraction(inst, player)
	local partner = inst.components.powerdrop.exclusive_partner
	if partner then
		partner:PushEvent("selfdestruct_abort")
	end
end

local function OnInteract(inst, player)
	inst.components.powerdrop:_OnPickedUp(player)
end

local function CheckInteractableConditions(inst, player)
	local eligible = true
	local reason
	for _,player in ipairs(AllPlayers) do
		if not player:IsAlive() then
			eligible = false
			reason = "CANNOT_INTERACT_DEAD"
			break
		elseif player.components.playerbusyindicator:IsBusy() then
			eligible = false
			reason = "CANNOT_INTERACT_BUSY"
			break
		end
	end

	if eligible then
		inst.components.powerdrop:HideNotInteractableLabel()
	else
		inst.components.powerdrop:ShowNotInteractableLabel(reason)
	end

	return eligible
end

-- TODO: should we show the not interactable label with interactable's
-- GainInteractFocus and block the interact? So it still gains focus, but
-- cannot be interacted with. Could cause issues with dead players near
-- powerdrops.
function PowerDrop:ShowNotInteractableLabel(reason)
	if not self.not_interactable_label then
		if TheDungeon.HUD then
			self.not_interactable_label = TheDungeon.HUD:AddWorldWidget(FollowLabel())
				:SetText(STRINGS.UI.HUD[reason])
				:SetTarget(self.inst)
			self.inst:StartUpdatingComponent(self)
		end

		self.inst.components.interactable:SetCanConditionBreakFocus(false)
	end
end

function PowerDrop:HideNotInteractableLabel()
	if self.not_interactable_label then
		self.not_interactable_label:Remove()
		self.not_interactable_label = nil
		self.inst:StopUpdatingComponent(self)
		self.inst.components.interactable:SetCanConditionBreakFocus(true)
	end
end

function PowerDrop:AllowInteraction()
	-- This function may be called multiple times on the same powerdrop!
	self.allowinteraction = true

	self.inst.components.interactable
		:SetInteractConditionFn(CheckInteractableConditions)
	self.inst.components.interactable:SetCanConditionBreakFocus(false)
end

function PowerDrop:ConfigureInteraction()
	self.inst.components.interactable:SetRadius(self.interact_radius)
		:SetInteractCondition_Never() -- until AllowInteraction is called
		:SetInteractStateName("powerup_interact")
		:SetAbortStateName("powerup_abort")
		:SetOnInteractFn(OnInteract)

	local t = {}
	t.category = STRINGS.POWERS.POWER_CATEGORY[self.power_category]
	local label
	if self.power_type == Power.Types.RELIC then
		label = kstring.subfmt(STRINGS.UI.POWERSELECTIONSCREEN.POWER_PROMPT_RELIC)
	elseif self.power_type == Power.Types.SKILL then
		label = kstring.subfmt(STRINGS.UI.POWERSELECTIONSCREEN.POWER_PROMPT_SKILL)
	else
		label = kstring.subfmt(STRINGS.UI.POWERSELECTIONSCREEN.POWER_PROMPT_FABLED_RELIC, t)
	end
	self.inst.components.interactable:SetupForButtonPrompt(label, OnApproachInteraction, OnDepartInteraction)
end

function PowerDrop:OnPowerPicked()
	self.picked = true
	self:OnFullyConsumed()
	self.inst:PushEvent("selected_power")
end

function PowerDrop:OnFullyConsumed()
	self:_ClearExclusivePartner()
	self:PreventInteraction() -- this gets called on the host and will be synced
	self.inst:PushEvent("on_fully_consumed")

	-- only do post-player reactions if it was actually picked
	-- fabled relics despawn through this route but are not necessarily picked

	if self.picked then
		local num_players = TheNet:GetNrPlayersOnRoomChange()
		local delay = (num_players - 1) * 15;

		self.inst:DoTaskInAnimFrames(delay, function(inst)
			self.inst:PushEvent("despawn")
		end)
	else
		self.inst:PushEvent("despawn")
	end
	self.inst:RemoveComponent("roomlock")
end

function SetExclusiveWith_OneWay(cmp, ent)
	cmp.exclusive_partner = ent
end

function PowerDrop:SetExclusiveWith(drop)
	SetExclusiveWith_OneWay(self, drop)
	SetExclusiveWith_OneWay(drop.components.powerdrop, self.inst)
end

function PowerDrop:_OnPickedUp(interacting_player)
	assert(self.power_type ~= nil, "Tried to pick up a power drop without a power type set.")

	self:PreventInteraction() -- this only gets called by the interacting client and is not guaranteed to be synced

	local partner = self.exclusive_partner
	if partner then
		partner.components.powerdrop:OnFullyConsumed()
	end

	local screen_open_delay_frames = 0 -- How many anim frames to delay opening the screen -- for Fabled Relic, delay a bit so we see the non-chosen one breaking.
	if self.power_type == Power.Types.FABLED_RELIC and self.exclusive_partner then
		screen_open_delay_frames = 23
	end

	self.inst:DoTaskInAnimFrames(screen_open_delay_frames, function() -- If fabled power, delay the screen slightly so we see the other power breaking.
		if self.inst:IsValid() then
			local playerid = interacting_player.Network:GetPlayerID()
			TheNet:ActivatePowerDrop(self.inst.Network:GetEntityID(), playerid)
		else
			TheLog.ch.PowerDrop:printf("Delayed interaction with invalid powerdrop %s", self.inst)
		end
	end)
end

function PowerDrop:OnUpdate(dt)
	-- Only starts updating if interaction is disallowed due to reasons like A Player Is Dead, or A Player Has The Menu Open
	-- Keep showing the label until a player leaves radius, and then remove the label and stop updating.

	if not self.inst:IsNearPlayer(self.interact_radius + 1, true) then
		self:HideNotInteractableLabel()
		self.inst:StopUpdatingComponent(self)
	end
end

function PowerDrop:GetDebugString()
	return string.format(
		"Allow Interaction[%s] Picked[%s]",
		self.allowinteraction or "false",
		self.picked or "false")
end

return PowerDrop
