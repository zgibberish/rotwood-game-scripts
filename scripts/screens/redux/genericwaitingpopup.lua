local ConfirmDialog = require "screens.dialogs.confirmdialog"

local GenericWaitingPopup = Class(ConfirmDialog, function(self, text)
	ConfirmDialog._ctor(self, nil, nil, true, text)
	self:SetText(" ")
	self:HideButtons()
	self:HideArrow()
	self:CenterText()
	self:SetMinWidth(600)
	self.time = 0
	self.progress = 0
end)

function GenericWaitingPopup:OnUpdate( dt )
	self.time = self.time + dt
	if self.time > 0.75 then
	    self.progress = self.progress + 1
	    if self.progress > 5 then
	        self.progress = 1
	    end

	    local text = string.rep(".", self.progress)
        self:SetText(text)
	    self.time = 0
	end
end

return GenericWaitingPopup
