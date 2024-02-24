local PICKUP_MESSAGE <const> = STRINGS.UI.ACTIONS.TAKE_POWERITEM
local INTERACTOR_KEY <const> = "SinglePickup"

local function SetOnGainFocusFn(self, on_gain_focus_fn)
	self.inst.components.interactable
		:SetOnGainInteractFocusFn(function(inst, player)
			local can, reasons
			if self.can_interact_fn then
				can, reasons = self.can_interact_fn(inst, player)
			else
				can = true
			end
			self.canpickup[player.Network:GetPlayerID()] = can
			local status = can and PICKUP_MESSAGE or reasons
			player.components.interactor:SetStatusText(INTERACTOR_KEY, status)
			if on_gain_focus_fn then
				on_gain_focus_fn(inst, player)
			end
		end)
	return self
end

local function SetOnLoseFocusFn(self, on_lose_focus_fn)
	self.inst.components.interactable
		:SetOnLoseInteractFocusFn(function(inst, player)
			player.components.interactor:SetStatusText(INTERACTOR_KEY, nil) 
			if on_lose_focus_fn then
				on_lose_focus_fn(inst, player)
			end
		end)
	return self
end

local function SetCanInteractFn(self, can_interact_fn)
	self.can_interact_fn = can_interact_fn
	return self
end

-- Entity that can be picked up by any player only, but it guarantees that only one player actually gets the item.
local SinglePickup = Class(function(self, inst)
	self.inst = inst
	self.pickedupbyplayer = nil
	self.assignedplayer = nil -- If this item is assigned to one player, only they will be able to grab it. Otherwise, 
	self.handledLocalPickup = false
	self.canpickup = {}

	self.inst:StartUpdatingComponent(self)

	self.inst.components.interactable
		:SetInteractConditionFn(function(_inst, _player) 
			return (not inst.components.warevisualizer or inst.components.warevisualizer:IsInitialized())
				and (inst.sg and not inst.sg:HasStateTag("busy"))
		end)
		:SetOnInteractFn(function(_inst, player) self:_OnPickedUp(player) end)
	SetOnGainFocusFn(self)
	SetOnLoseFocusFn(self)
end)

SinglePickup.PICKUP_MESSAGE = PICKUP_MESSAGE
SinglePickup.SetOnGainFocusFn = SetOnGainFocusFn
SinglePickup.SetOnLoseFocusFn = SetOnLoseFocusFn
SinglePickup.SetCanInteractFn = SetCanInteractFn

-- callback(inst, player) -> bool
-- Return true if the callback will correctly handle removal of inst from the game in a multiplayer setting. If not,
-- return false and SinglePickup will DelayedRemove it.
function SinglePickup:SetOnConsumedCallback(consumed_cb)
	self.consumed_cb = consumed_cb
	return self
end

function SinglePickup:OnNetSerialize()
	local e = self.inst.entity

	local playerID = -1	 -- invalid
	if self.pickedupbyplayer and self.pickedupbyplayer:IsValid() then
		playerID = self.pickedupbyplayer.Network:GetPlayerID()
	end
	e:SerializePlayerID(playerID)

	local assignedPlayerID = -1 -- invalid
	if self.assignedplayer and self.assignedplayer:IsValid() then
		assignedPlayerID = self.assignedplayer.Network:GetPlayerID()
	end
	e:SerializePlayerID(assignedPlayerID)
end

function SinglePickup:OnNetDeserialize()
	local e = self.inst.entity

	local playerID = e:DeserializePlayerID()
	if playerID then
		-- Find the player by playerID:
		local playerGUID = TheNet:FindGUIDForPlayerID(playerID)
		if playerGUID then
			self.pickedupbyplayer = Ents[playerGUID]
		end
	end

	local assignedPlayerID = e:DeserializePlayerID()
	if assignedPlayerID then
		local assignedPlayerGUID = TheNet:FindGUIDForPlayerID(assignedPlayerID)
		if assignedPlayerGUID and Ents[assignedPlayerGUID] then
			self:UpdateAssignedPlayer(Ents[assignedPlayerGUID])
		end
	end
end


function SinglePickup:UpdateAssignedPlayer(newplayer)
	if newplayer ~= self.assignedplayer then
--		print("SinglePickup: Updating Assigned Player")
		self.assignedplayer = newplayer
		if self.inst.components.playerhighlight then
			self.inst.components.playerhighlight:SetPlayer(self:GetAssignedPlayer())
		end
	end
end

function SinglePickup:CanPickUp(interacting_player)
	local playerid = interacting_player.Network:GetPlayerID()
	return self.canpickup[playerid]
end

-- Send a network event requesting a pickup.
function SinglePickup:_OnPickedUp(interacting_player)
	local playerid = interacting_player.Network:GetPlayerID()
	TheLog.ch.InteractSpam:printf("SinglePickup:_OnPickedUp interacting_player = %d", playerid)
	if not self:CanPickUp(interacting_player) then
		return
	end
	if self.inst.Network then
		TheNetEvent:RequestSinglePickup(self.inst.Network:GetEntityID(), playerid)
	end
end

-- Callback from TheNetEvent:RequestSinglePickup(), received by all but only processed by the host.
-- Set self.pickedupbyplayer if it is unset, and this value will be subsequently replicated.
-- That is, this function effectively arbitrates between multiple players attempting to pick up the same item by 
-- choosing the first player's request to be received, and discarding all subsequent requests.
function SinglePickup:OnNetPickup(player)
	TheLog.ch.InteractSpam:printf("SinglePickup:OnNetPickup...")
	TheLog.ch.InteractSpam:indent()
	if not TheNet:IsHost() then	
		TheLog.ch.InteractSpam:printf("...but not Host so ignore it.")
		TheLog.ch.InteractSpam:unindent()
		return
	end
	if not self.pickedupbyplayer then
		if self.assignedplayer and self.assignedplayer.Network:GetPlayerID() ~= player.Network:GetPlayerID() then
			TheLog.ch.InteractSpam:printf("...player %d wants to pick up but it is assigned to player %d", player.Network:GetPlayerID(), self.assignedplayerid)
		else
			TheLog.ch.InteractSpam:printf("...picked up by player = %d", player.Network:GetPlayerID())
			self.pickedupbyplayer = player
			-- The actual logic for pickup is done in the OnUpdate function
		end
	else
		TheLog.ch.InteractSpam:printf(
			"...player %d wants to pick up but it's already claimed by player %d", 
			player.Network:GetPlayerID(), 
			self.pickedupbyplayer.Network:GetPlayerID()
		)
	end	
	TheLog.ch.InteractSpam:unindent()
end

-- Set an Assigned Player: only this player is allowed to pick this item up.
function SinglePickup:AssignToPlayer(player)
	TheLog.ch.InteractSpam:printf("SinglePickup:AssignToPlayer player = %d", player.Network:GetPlayerID())
	self:UpdateAssignedPlayer(player)
end
function SinglePickup:GetAssignedPlayer()
	return self.assignedplayer
end

-- sync/refresh player drops in rotatingdrop
function SinglePickup:OnUpdate(_dt)
	if self.handledLocalPickup then
		return
	end

	if not self.pickedupbyplayer then
		return
	end

	TheLog.ch.InteractSpam:printf("SinglePickup:OnUpdate handling pickup by player %d", self.pickedupbyplayer.Network:GetPlayerID())
	TheLog.ch.InteractSpam:indent()

	self.handledLocalPickup = true	-- Make sure this only happens once

	-- Prevent interaction:
	self.inst.components.interactable:SetInteractCondition_Never()

	local cleaned_up = false
	if self.consumed_cb then
		TheLog.ch.InteractSpam:printf("consumed_cb")

		-- Though the consumed_cb will be invoked on all clients to allow the pickup to gracefully terminate,
		-- pickedupbyplayer will only be passed as the consuming_player on the client for which they are local.
		local consuming_player = TheNet:IsLocalPlayer(self.pickedupbyplayer.Network:GetPlayerID())
			and self.pickedupbyplayer

		cleaned_up = self.consumed_cb(self.inst, consuming_player)
	end

	-- The host is responsible for cleaning up the pickup.
	if not cleaned_up and TheNet:IsHost() then
		-- Delay removal so that the update function still runs on remote clients.
		self.inst:DelayedRemove()
	end

	TheLog.ch.InteractSpam:unindent()
end

return SinglePickup
