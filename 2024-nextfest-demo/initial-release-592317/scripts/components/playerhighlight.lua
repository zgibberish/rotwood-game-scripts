local PlayerHighlight = Class(function(self, inst)
	self.inst = inst

	self.highlight = nil
	self.aim = nil
	self.player = nil

	self.active = false

	self.last_angle = 0

	self._onremovetarget = function(inst)
		if self.aim then
			self.aim:DelayedRemove()
		end
		if self.highlight then
			self.highlight:DelayedRemove()
		end
	end
end)

function PlayerHighlight:SetPlayer(player)
	-- Note: This won't necessarily be attached to the player. This could be an item that is assigned to the player.
	--if self.player ~= player then 
		self.player = player

		self.inst:ListenForEvent("onremove", self._onremovetarget, player)

		if not self.active and player.GetHunterId then
			local playerID = player:GetHunterId() or 1

			if self.inst == player then

				-- For all players, have a coloured highlight under the player.
				local fx_pfb = "ground_indicator_p"..playerID
				local highlight = SpawnPrefab(fx_pfb, player)
				highlight.entity:SetParent(self.inst.entity)

				self.highlight = highlight

				-- For local players, have a direction indicator under the player, as well.
				if self.inst:IsLocal() then
					local aim_pfb = "aim_pointer_p"..playerID
					local aim = SpawnPrefab(aim_pfb, player)
					aim.AnimState:SetScale(-1, 1)

					self.aim = aim
					self.inst:StartUpdatingComponent(self)
				end
			else
				-- This is an object we're trying to highlight belongs to a player.
				local fx_pfb = "ground_indicator_ring_p"..playerID
				local highlight = SpawnPrefab(fx_pfb, player)
				highlight.entity:SetParent(self.inst.entity)

				self.highlight = highlight
			end

			self.active = true
		end
--	end
end

function PlayerHighlight:GetControlAngle()
	local angle
	if self.player.components.playercontroller:HasGamepad() then
		angle = self.player.components.playercontroller:GetAnalogDir()
	else
		angle = self.player.components.playercontroller:GetMouseActionDirection()
	end

	if angle then
		angle = math.floor(angle)

		-- Clamp the angle of the aim indicator to the actual effective angles that a player can attack
		local angle_snap = 0 --TUNING.player.attack_angle_clamp - 10 -- Give a bit less angle
		if math.abs(angle) < 90 then
			-- angle = 0
			angle = math.clamp(angle, -angle_snap, angle_snap)
		elseif math.abs(angle) > 90 then
			-- angle = 180
			if angle < 0 then
				angle = math.clamp(angle, -180, -180 + angle_snap)
			else
				angle = math.clamp(angle, 180 - angle_snap, 180)
			end
		end
	end
	return angle
end

function PlayerHighlight:OnUpdate(dt)
	if not self.active or not self.inst:IsLocal() then
		return
	end

	local angle
	-- If we're local, update the angle ourselves. Otherwise, use last_angle from OnNetSerialize.
	if self.player:IsLocal() then
		angle = self:GetControlAngle()
	else
		angle = self.last_angle
	end

	if self.player ~= nil and self.player:IsValid() then
		if angle then
			self.aim.Transform:SetRotation(angle)
			self.last_angle = angle
		end

		if self.player:IsSpectating() then
			self.aim:Hide()
		else
			self.aim:Show()
		end

		self.aim.Transform:SetPosition(self.player.Transform:GetWorldPosition())
	else
		self.aim:DelayedRemove()
		self.highlight:DelayedRemove()
	end
end

-- function PlayerHighlight:OnNetSerialize()
-- 	local e = self.inst.entity
-- 	local positive = self.last_angle ~= nil and self.last_angle >= 0
-- 	local abs_angle = math.abs(self.last_angle)
-- 	e:SerializeBoolean(positive)
-- 	e:SerializeUInt(abs_angle, 8)
-- end

-- function PlayerHighlight:OnNetDeserialize()
-- 	local e = self.inst.entity
-- 	local positive = e:DeserializeBoolean()
-- 	local abs_angle = e:DeserializeUInt(8)

-- 	if not positive then
-- 		abs_angle = abs_angle * -1
-- 	end

-- 	self.last_angle = abs_angle
-- end

return PlayerHighlight
