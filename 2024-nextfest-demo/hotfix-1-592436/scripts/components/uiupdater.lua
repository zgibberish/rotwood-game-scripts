
local UIUpdater = Class(function(self, inst)
	self.inst = inst
	self.running_updaters = {}
end)

function UIUpdater:RunUpdater(updater)
	table.insert(self.running_updaters, updater)
	self.inst:StartWallUpdatingComponent(self)
	return updater
end

function UIUpdater:StopUpdater( updater )
	if table.removearrayvalue(self.running_updaters, updater) ~= nil then
		updater:Stop()
	end
end

function UIUpdater:OnWallUpdate(dt)
	if not self.inst:IsValid() then
		self.inst:StopWallUpdatingComponent(self)
		return
	end

	if self.running_updaters and #self.running_updaters > 0 then
		local i = 1
		while i <= #self.running_updaters do
			local updater = self.running_updaters[i]

			updater:Update(dt)
			
			if updater:IsDone() then
				-- Updating could have affected the updaters list
				if self.running_updaters[i] == updater then
					self.inst:PushEvent("uiupdater_done", updater)
					table.remove( self.running_updaters, i )
				end
			else
				i = i + 1
			end
		end
	end

	if not self:ShouldUpdate() then
		self.inst:StopWallUpdatingComponent(self)
	end
end

function UIUpdater:ShouldUpdate()
	return self.running_updaters and #self.running_updaters > 0
end


function UIUpdater:PauseAll()
	for i, updater in ipairs(self.running_updaters) do
		updater:Pause()
	end	
end

function UIUpdater:ResumeAll()
	for i, updater in ipairs(self.running_updaters) do
		updater:Resume()
	end	
end

return UIUpdater
