-- A metadata component so save files contain build version information.
local Meta = Class(function(self, inst)
	self.inst = inst
	self:SetToCurrentBuild()
end)

function Meta:SetToCurrentBuild()
	self.build_version = APP_VERSION
	self.build_date = APP_BUILD_DATE
	self.build_time = APP_BUILD_TIME
end

function Meta:OnSave()
	self:SetToCurrentBuild()
	return
	{
		build_version = self.build_version,
		build_date = self.build_date,
		build_time = self.build_time,
	}
end

function Meta:OnLoad(data)
	self.build_version = data.build_version or self.build_version
	self.build_date = data.build_date or self.build_date
	self.build_time = data.build_time or self.build_time
end

return Meta
