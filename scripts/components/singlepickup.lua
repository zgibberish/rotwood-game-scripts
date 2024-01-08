local BUTTON_LABEL <const> = STRINGS.UI.ACTIONS.TAKE_POWERITEM

-- Entity that can be picked up by any player only, but it guarantees that only one player actually gets the item.
local SinglePickup = Class(function(self, inst)
	self.inst = inst
	self.pickedupbyplayer = nil
	self.handledLocalPickup = false

	self.inst:StartUpdatingComponent(self)

	self.inst.components.interactable
		:SetupForButtonPrompt(BUTTON_LABEL, nil, nil, 3)
		:SetOnInteractFn(function(_, player) self:_OnPickedUp(player) end )
end)

SinglePickup.BUTTON_LABEL = BUTTON_LABEL

-- callback(inst, player) -> bool
-- Return true if the callback will correctly handle removal of inst from the game in a multiplayer setting. If not,
-- return false and SinglePickup will DelayedRemove it.
function SinglePickup:SetOnConsumedCallback(consumed_cb)
	self.consumed_cb = consumed_cb
end

function SinglePickup:OnNetSerialize()
	local e = self.inst.entity

	local playerID = -1	 -- invalid
	if self.pickedupbyplayer then 
		playerID = self.pickedupbyplayer.Network:GetPlayerID()
	end
	e:SerializePlayerID(playerID)
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
end

-- Send a network event requesting a pickup.
function SinglePickup:_OnPickedUp(interacting_player)
	local playerid = interacting_player.Network:GetPlayerID()
	TheLog.ch.InteractSpam:printf("SinglePickup:_OnPickedUp interacting_player = %d", playerid)
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
		TheLog.ch.InteractSpam:printf("...picked up by player = %d", player.Network:GetPlayerID())
		self.pickedupbyplayer = player
		-- The actual logic for pickup is done in the OnUpdate function
	else
		TheLog.ch.InteractSpam:printf(
			"...player %d wants to pick up but it's already claimed by player %d", 
			player.Network:GetPlayerID(), 
			self.pickedupbyplayer.Network:GetPlayerID()
		)
	end	
	TheLog.ch.InteractSpam:unindent()
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
