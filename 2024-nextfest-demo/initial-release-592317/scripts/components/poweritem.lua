-- TODO: networking2022, victorc - This appears to be a copy/paste/modify of powerdrop.lua
-- Reconcile this with powerdrop.lua once we've sorted out what is common/different
local kstring = require "util.kstring"
local Power = require 'defs.powers'
local FollowLabel = require "widgets.ftf.followlabel"
local Image = require "widgets/image"
local FollowPowerIcon = require "widgets.ftf.followpowericon"

local PowerItem = Class(function(self, inst)
	self.inst = inst
	self.power_type = nil
	self.power_category = nil
	self.powers = {}

	self.interact_radius = 2
	self.num_powers = 2 -- num_choices
	self.inst:AddComponent("roomlock")
	self.inst:AddTag("PowerItem")

	-- synchronized data
	-- configuration
	self.spawn_order = 1 --if there are multiple power drops being spawned at once, what is the sequence of their appearance?
	self.appear_delay = 0 --after the prefab has been spawned, how many ticks until it appears?
	-- state
	self.prepared_id = 0 -- prepare can be called multiple times, so use a unique id to represent each call
	self.allowinteraction = false
	self.picked = false

	self.partners = {} -- other drops that will be consumed when one is selected

	-- PowerItems now only spawn after the room is cleared, so we only need to
	-- block interaction when despawning.
	self.inst:ListenForEvent("despawn", function() self:PreventInteraction() end)
end)

function PowerItem:OnEntityBecameLocal()
	-- Power drops need to be registered with the host after the EntityID is assigned. OnEntityBecameLocal is a spot where it is guaranteed to have a valid EntityID
	if TheNet:IsHost() then
		if self.power_type == Power.Types.RELIC then
			TheNet:SpawnPowerItem(self.inst.Network:GetEntityID(), PowerItem_RELIC)
		elseif self.power_type == Power.Types.SKILL then
			TheNet:SpawnPowerItem(self.inst.Network:GetEntityID(), PowerItem_SKILL)
		elseif self.power_type == Power.Types.FABLED_RELIC then
			TheNet:SpawnPowerItem(self.inst.Network:GetEntityID(), PowerItem_POWERFABLED)
		else
			assert(false, "PowerItem: Unknown power type!")
		end
	end
end

function PowerItem:OnNetSerialize()
	local e = self.inst.entity
	e:SerializeUInt(self.spawn_order, 4)
	e:SerializeUInt(self.appear_delay, 8)
	e:SerializeUInt(self.prepared_id, 8)
	e:SerializeBoolean(self.picked)
	e:SerializeBoolean(self.allowinteraction)
end

function PowerItem:OnNetDeserialize()
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
	if old_allowinteraction ~= self.allowinteraction and self.allowinteraction then
		self:AllowInteraction()
	end
end

function PowerItem:SetPower(power_name)
	self.power_name = power_name

	local power_def = Power.FindPowerByName(self.power_name)
	local power = ThePlayer.components.powermanager:CreatePower(power_def) -- TODO @jambell #vending: wish TheWorld had a powermanager

	self.prototype_hovericon = FollowPowerIcon(power)
	TheDungeon.HUD:AddWorldWidget(self.prototype_hovericon)
	self.prototype_hovericon:SetTarget(self.inst)

end

function PowerItem:GetPower()
	return self.power_name
end

function PowerItem:SetPowerCategory(category)
	self.power_category = category
end

function PowerItem:SetOnPrepareToShowGem(fn)
	self.on_preparetoshowgem = fn
end

-- Configure everything about display here.
function PowerItem:PrepareToShowGem(cfg)
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

function PowerItem:PreventInteraction()
	self.inst.components.interactable:SetInteractCondition_Never()
end

function PowerItem:SetOwningPlayer(player)
	self.owning_player = player
end
function PowerItem:GetOwningPlayer()
	return self.owning_player
end

local function OnApproachInteraction(inst, player)
	local partner = inst.components.poweritem.exclusive_partner
	if partner then
		partner:PushEvent("selfdestruct_hint")
	end

	if not inst.popup then
		local popup_data =
		{
			target = inst,
			power_name = inst.components.poweritem.power_name,
			offset_x = 50,
			offset_y = 680,
		}
		inst.popup = TheDungeon.HUD:MakePowerPopup(popup_data)
			-- :Offset(0, 196 * HACK_FOR_4K)
	end
	-- self.inst:StartUpdatingComponent(self)
	inst.components.poweritem.prototype_hovericon:Hide()
end

local function OnDepartInteraction(inst, player)
	local partner = inst.components.poweritem.exclusive_partner
	if partner then
		partner:PushEvent("selfdestruct_abort")
	end

	if inst.popup then
		inst.popup:Remove()
		inst.popup = nil
	end
	inst.components.poweritem.prototype_hovericon:Show()
end

local function OnInteract(inst, player)
	inst.components.poweritem:_OnPickedUp(player)
end

local function CheckInteractableConditions(inst, player)
	local eligible = true
	local reason

	if inst.components.poweritem:GetOwningPlayer() and player ~= inst.components.poweritem:GetOwningPlayer() then
		eligible = false
		reason = "CANNOT_INTERACT_WRONG_PLAYER"
	else
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
	end

	if eligible then
		inst.components.poweritem:HideNotInteractableLabel()
	else
		inst.components.poweritem:ShowNotInteractableLabel(reason)
	end

	return eligible
end

function PowerItem:ShowNotInteractableLabel(reason)
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

function PowerItem:HideNotInteractableLabel()
	if self.not_interactable_label then
		self.not_interactable_label:Remove()
		self.not_interactable_label = nil
		self.inst:StopUpdatingComponent(self)
		self.inst.components.interactable:SetCanConditionBreakFocus(true)
	end
end

function PowerItem:AllowInteraction()
	-- This function may be called multiple times on the same PowerItem!
	self.allowinteraction = true

	self.inst.components.interactable
		:SetInteractConditionFn(CheckInteractableConditions)
end

function PowerItem:ConfigureInteraction()
	self.inst.components.interactable:SetRadius(self.interact_radius)
		:SetInteractCondition_Never() -- until AllowInteraction is called
		:SetInteractStateName("powerup_interact")
		:SetAbortStateName("powerup_abort")
		:SetOnInteractFn(OnInteract)

	local label = STRINGS.UI.ACTIONS.TAKE_POWERITEM
	self.inst.components.interactable:SetupForButtonPrompt(label, OnApproachInteraction, OnDepartInteraction)
end

function PowerItem:OnPowerPicked()
	self.picked = true
	self:OnFullyConsumed()
	self.inst:PushEvent("selected_power")
end

function PowerItem:OnPartnerConsumed()
	self.inst.components.interactable:SetInteractCondition_Never()
	self.inst:RemoveComponent("roomlock")

	self.inst:DoTaskInAnimFrames(2, function()
		self.inst:Hide()
	end)
end

function PowerItem:OnFullyConsumed()
	self.inst.components.interactable:SetInteractCondition_Never()
	self.inst:RemoveComponent("roomlock")

	-- if inst:IsLocal() then
	self.inst:DoTaskInAnimFrames(2, function()
		-- TODO(jambell): can't actually remove because interactable is unhappy, hide for prototype
		self.inst:Hide()
	end)
	-- end

	for _,item in ipairs(self.partners) do
		item.components.poweritem:OnPartnerConsumed()
	end
end

local function SetExclusiveWith_OneWay(cmp, ent)
	cmp.exclusive_partner = ent
end

function PowerItem:SetExclusiveWith(drop)
	SetExclusiveWith_OneWay(self, drop)
	SetExclusiveWith_OneWay(drop.components.poweritem, self.inst)
end

function PowerItem:AddPartner(poweritem)
	table.insert(self.partners, poweritem)
end

function PowerItem:_OnPickedUp(interacting_player)
	assert(self.power_name ~= nil, "Tried to pick up a power item without a Power set.")

	local partner = self.exclusive_partner
	if partner then
		partner.components.poweritem:OnFullyConsumed()
	end

	local power_def = Power.FindPowerByName(self.power_name)
	interacting_player.components.powermanager:AddPower(interacting_player.components.powermanager:CreatePower(power_def))

	interacting_player.sg:GoToState("powerup_accept")

	self.prototype_hovericon:Remove()

	self:OnFullyConsumed()
end

function PowerItem:OnUpdate(dt)
	-- Only starts updating if interaction is disallowed due to reasons like A Player Is Dead, or A Player Has The Menu Open
	-- Keep showing the label until a player leaves radius, and then remove the label and stop updating.

	if not self.inst:IsNearPlayer(self.interact_radius + 1, true) then
		self:HideNotInteractableLabel()
		self.inst:StopUpdatingComponent(self)
	end
end

return PowerItem
