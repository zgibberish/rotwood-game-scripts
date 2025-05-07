local fmodtable = require "defs.sound.fmodtable"
require "class"


-- A manager for global audio params. Expected to live on TheWorld and not
-- generic.
local AudioParams = Class(function(self, inst)
	self.inst = inst

	self._onplayerenterexit = function(source, player) self:UpdatePlayerCount() end
	self.inst:ListenForEvent("playerentered", self._onplayerenterexit)
	self.inst:ListenForEvent("playerexited", self._onplayerenterexit)

	self:SetDefaultState()
end)

function AudioParams:SetDefaultState()
	-- Global parameters do not reset when the sim restarts (we transition
	-- rooms), so we must set good initial values for them to gracefully
	-- recover from room transitions and errors.
	--~ TheAudio:SetGlobalParameter(fmodtable.GlobalParameter.critHitCounter, 0)

	self:UpdatePlayerCount()
end

function AudioParams:UpdatePlayerCount()
	TheAudio:SetGlobalParameter(fmodtable.GlobalParameter.numLocalPlayers, TheNet:GetNrLocalPlayers())
	TheAudio:SetGlobalParameter(fmodtable.GlobalParameter.numPlayers, #AllPlayers)
end

return AudioParams
