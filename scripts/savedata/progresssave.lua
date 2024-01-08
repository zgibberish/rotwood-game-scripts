local SaveData = require "savedata.savedata"


local ProgressSave = Class(SaveData, function(self)
	SaveData._ctor(self, "progress")
	self:_InitVersion()
end)

function ProgressSave:_InitVersion()
	-- Incrementing this version will force players to delete saves regardless
	-- of other SaveData versions.
	self.GLOBAL_VERSION = 1 -- BE CAREFUL!
	if DEV_MODE then
		-- Liberally upgrade this value during dev. We should snap it back to
		-- the above GLOBAL_VERSION when we make a release.
		self.GLOBAL_VERSION = 1
	end
	self:SetValue("global_version", self.GLOBAL_VERSION)
end

function ProgressSave:Reset()
	ProgressSave._base.Reset(self)
	self:_InitVersion()
end

function ProgressSave:Save(cb)
	if TheDungeon then
		TheDungeon.progression:WriteProgression()
	end
	self:SetValue("global_version", self.GLOBAL_VERSION)
	ProgressSave._base.Save(self, cb)
end

return ProgressSave
