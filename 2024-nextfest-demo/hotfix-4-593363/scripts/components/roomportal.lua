local FollowLabel = require "widgets.ftf.followlabel"


local RoomPortal = Class(function(self, inst)
	self.inst = inst
	self.cardinal = nil
	self.traveling = false
	self.unlock_time = 0

	TheWorld:PushEvent("register_roomportal", inst)

	self.inst:ListenForEvent("room_locked", function() self:OnRoomLocked(inst) end, TheWorld)
	self.inst:ListenForEvent("room_unlocked", function() self:OnRoomUnlocked(inst) end, TheWorld)
end)

function RoomPortal:OnRemoveFromEntity()
	TheWorld:PushEvent("unregister_roomportal", self.inst)
	self.inst:RemoveEventCallback("room_unlocked", self._onroomunlocked, TheWorld)
end

function RoomPortal:OnRemoveEntity()
	self:OnRemoveFromEntity()
end

function RoomPortal:SetCardinal(cardinal)
	self.cardinal = cardinal
end

function RoomPortal:GetCardinal()
	return self.cardinal
end

function RoomPortal:_RevealMap()
	if TheDungeon.HUD and TheDungeon.HUD.dungeon_hud then
		TheDungeon.HUD.dungeon_hud:ShowExitSignposts()
	end
end

function RoomPortal:OnSave()
	return
	{
		cardinal = self.cardinal,
	}
end

function RoomPortal:OnLoad(data)
	self.cardinal = data.cardinal or self.cardinal
end


function RoomPortal:OnRoomLocked()
	self.inst:StopUpdatingComponent(self)
	self:HideWaitingForAllPlayers()
end

function RoomPortal:OnRoomUnlocked()
	self.unlock_time = TheWorld:GetTimeAlive()
	self:_RevealMap()
	self.inst:StartUpdatingComponent(self)
end

function RoomPortal:DisplayWaitingForAllPlayers()
	if not self.waitingForAllPlayersLabel then
		if TheDungeon.HUD then
			self.waitingForAllPlayersLabel = TheDungeon.HUD:AddWorldWidget(FollowLabel())
				:SetText(STRINGS.UI.HUD.WAITING_FOR_ALL_PLAYERS)
				:SetTarget(self.inst)
			self.waitingForAllPlayersLabel:GetLabelWidget()
				:EnableShadow()
				:EnableOutline()
		end
	end
end

function RoomPortal:UpdateWaitingForAllPlayers(current, total)
	if self.waitingForAllPlayersLabel then
		local str = string.format(STRINGS.UI.HUD.WAITING_FOR_ALL_PLAYERS, current, total)
		self.waitingForAllPlayersLabel:SetText(str)
		self.inst:PushEvent("start_heli")
	end
end


function RoomPortal:HideWaitingForAllPlayers()
	if self.waitingForAllPlayersLabel then 
		self.waitingForAllPlayersLabel:Remove()
		self.waitingForAllPlayersLabel = nil
	end
end

function RoomPortal:OnUpdate(dt)

	-- Only do this logic for roomportals other than the entrance
	local worldmap = TheDungeon:GetDungeonMap()
	local active = worldmap:GetCardinalDirectionForEntrance() ~= self.cardinal and	-- This isn't the entrance
			worldmap:GetDestinationForCardinalDirection(self.cardinal)	-- There is a room on the other side
					
	if active then
		local has_just_entered_or_unlocked_room = (TheWorld:GetTimeAlive() - self.unlock_time) < 0.5
		if has_just_entered_or_unlocked_room then
			-- Require user to leave and return to edge to trigger navigation.
			return
		end


		-- Determine how many players are inside this roomportal that are ready to travel (not busy)
		local players = self.inst.components.playerproxrect:FindPlayersInRange()
		local nrReadyPlayers = 0
		for _,player in ipairs(players) do
			if player:IsAlive() then	-- We need players to be alive to switch rooms
				nrReadyPlayers = nrReadyPlayers + 1
			end
		end
	
		if not TheNet:IsHost() and not self.traveling then
			local direction = TheNet:GetRoomChangeImminent()
			if direction and direction == self.cardinal then 
				self.traveling = true
				print("Host told us room change is imminent in the " .. self.cardinal .. " direction!")

				local room = worldmap:GetDestinationForCardinalDirection(self.cardinal)
				if room then
					-- TODO: Update label one last time so we see 4/4 for at least a frame.
					TheWorld.components.dungeontravel:ReadyToTravel(self.cardinal)						
				end
			end
		end

		if not self.traveling then

			nrReadyPlayers = 0
			for _,player in ipairs(players) do
				if player:IsAlive() and not player.components.playerbusyindicator:IsBusy() then
					nrReadyPlayers = nrReadyPlayers + 1
				end
			end


			-- If the roomportal is not actively traveling to the next room, check if it should:
			if nrReadyPlayers > 0 and nrReadyPlayers == #AllPlayers and TheNet:IsHost() then	-- TODO: Fix this once spectating goes in
				local room = worldmap:GetDestinationForCardinalDirection(self.cardinal)
				assert( room )
				TheNet:HostSetRoomChangeImminent(self.cardinal)

				-- TODO: Update label one last time so we see 4/4 for at least a frame.
				TheWorld.components.dungeontravel:ReadyToTravel(self.cardinal)
				self.traveling = true
			end

		else
			-- The roomportal is busy traveling to the next room. If there are players that are no longer ready, abort the travel:

			-- Only allow backing out in LOCAL games. If we allow this on 
			if TheNet:IsGameTypeLocal() then	
				if nrReadyPlayers < #AllPlayers then	-- TODO: Fix this once spectating goes in
					TheWorld.components.dungeontravel:AbandonTravel()						
					self.traveling = false
				end
			end
		end


		-- Update the Waiting For All Players prompt:
		if nrReadyPlayers > 0 and not self.traveling then
			self:DisplayWaitingForAllPlayers()
			self:UpdateWaitingForAllPlayers(nrReadyPlayers, #AllPlayers)
		else
			self:HideWaitingForAllPlayers()
		end
	else
		self:HideWaitingForAllPlayers()
	end
end

return RoomPortal
