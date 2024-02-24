local HeartDropper = Class(function(self, inst)
	self.inst = inst
end)

function HeartDropper:GetSoulPrefab()
	return "soul_drop_konjur_soul_greater"
end

function HeartDropper:GetHeartPrefab()
	return string.format("soul_drops_boss_%s", self.inst.prefab)
end

function HeartDropper:EligibleForHeart(player)
	return true
end

function HeartDropper:DropHeart()
	-- TODO: networking2022, this needs to be reviewed
	-- evaluate the players who are present, pick what to drop based on
	local drops = {}
	local players = TheNet:GetPlayersOnRoomChange()
	for _, player in ipairs(players) do
		if self:EligibleForHeart(player) then
			drops[player] = self:GetHeartPrefab()
		else
			drops[player] = self:GetSoulPrefab()
		end
	end

	for player, prefab in pairs(drops) do
		-- spawn the drops that each player is eligible for
	end
end

return HeartDropper
