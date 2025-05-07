local SaveData = require "savedata.savedata"

local PlayerSave = Class(SaveData, function(self, idx)
	local name = string.format("character_slot_%s", idx)
	SaveData._ctor(self, name)
end)

function PlayerSave:Save(player, cb)
	if player ~= nil then
		local data = player:GetPersistData()
		self:SetValue("player", data)
	end

	PlayerSave._base.Save(self, cb)
end

return PlayerSave
