local Consumable = require 'defs.consumable'
local lume = require "util.lume"

local HeartDeposit = Class(function(self, inst)
	self.inst = inst
end)

function HeartDeposit:_GetHeartDef(heart)
	return Consumable.FindItem(heart.id)
end

function HeartDeposit:DepositHeartForPlayer(player, heart)
	player.components.heartmanager:ConsumeHeartAndUpgrade(self:_GetHeartDef(heart))
end

function HeartDeposit:GetHeartsForPlayer(player)
	-- return a list of hearts this player has
	local hearts = player.components.inventoryhoard:GetMaterialsWithTag("konjur_heart")
	hearts = lume.sort(hearts, function(a, b) return a.acquire_order < b.acquire_order end)
	return hearts
end

function HeartDeposit:GetBestHeartToDeposit(hearts)
	-- (TEMP) Just return the first heart in the list. 
	-- They are ordered in the order the player got them.
	return hearts[1] 
end

function HeartDeposit:IsAnyPlayerEligible(players)
	for _, player in ipairs(players) do
		local hearts = self:GetHeartsForPlayer(player)
		if hearts and #hearts > 0 and player:IsFlagUnlocked("pf_energy_pillar_unlocked") then
			return true
		end
	end
	return false
end

return HeartDeposit