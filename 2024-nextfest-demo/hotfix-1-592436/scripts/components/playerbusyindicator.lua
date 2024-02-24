local OptionsScreen = require "screens.optionsscreen"
local InventoryScreen = require "screens.town.inventoryscreen"


local PlayerBusyIndicator = Class(function(self, inst)
	self.inst = inst
	self.busy = false
	self.busyindicator = nil
--	self.temptimer = 0.0

	if self.inst:IsLocal() then
		self.inst:StartUpdatingComponent(self)
	end
end)

function PlayerBusyIndicator:IsBusy()
	return self.busy
end

function PlayerBusyIndicator:OnNetSerialize()
	local e = self.inst.entity

	e:SerializeBoolean(self.busy)
end

function PlayerBusyIndicator:OnNetDeserialize()
	local e = self.inst.entity
	
	self.busy = e:DeserializeBoolean()

	self:UpdateIndicator()	-- Only call this on deserialize (meaning: for remote players only)
end

function PlayerBusyIndicator:UpdateIndicator()
	if self.busy and not self.busyindicator then
		-- Spawn the busy indicator
        self.busyindicator = SpawnPrefab("questmarker")
        self.busyindicator.entity:SetParent(self.inst.entity)

		self.busyindicator.Follower:FollowSymbol(self.inst.GUID, "head01")
		self.busyindicator.Follower:SetOffset(0, -250, 0)

		self.busyindicator:SetBusy()
		self.busyindicator:SpawnMarker()
	elseif not self.busy and self.busyindicator then
		-- Remove the busy indicator
		self.busyindicator:DespawnMarker()
		-- self.busyindicator:Remove()
		self.busyindicator = nil
	end
end


function PlayerBusyIndicator:OnUpdate(dt)
	if self.inst.entity:IsLocal() then
		self.busy = false

		-- TODO
		-- Set up queries to determine if the player is busy. Reasons to be busy:
		--  Pause menu
		--  Inventory
		--  In conversation
		--  in any type of menu

		local hud = TheDungeon.HUD
		if hud ~= nil then
			local hudfocus, reason = hud:IsHudSinkingInput()
			if hudfocus then
				self.busy = true
			end
		end
	end
end



return PlayerBusyIndicator
