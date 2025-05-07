local GenericWaitingPopup = require "screens/redux/genericwaitingpopup"

local ConnectingToGamePopup = Class(GenericWaitingPopup, function(self)
    GenericWaitingPopup._ctor(self, STRINGS.UI.NOTIFICATION.CONNECTING)
	self:SetName("ConnectingToGamePopup")
end)

function ConnectingToGamePopup:OnCancel()
    -- Ignore base implementation and do it all ourself.
    self:Disable()
    TheFrontEnd:PopScreen(self)
end

return ConnectingToGamePopup
