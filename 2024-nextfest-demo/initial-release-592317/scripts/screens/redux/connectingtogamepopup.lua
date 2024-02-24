local WaitingDialog = require "screens.dialogs.waitingdialog"

local ConnectingToGamePopup = Class(WaitingDialog, function(self)
	WaitingDialog._ctor(self)
	self:SetTitle(STRINGS.UI.NOTIFICATION.CONNECTING)
	self:SetName("ConnectingToGamePopup")
end)

function ConnectingToGamePopup:OnCancel()
    -- Ignore base implementation and do it all ourself.
    self:Disable()
    TheFrontEnd:PopScreen(self)
end

return ConnectingToGamePopup
