local Widget = require "widgets/widget"
local Text = require "widgets/text"

-------------------------------------------------------------------------------------------------------

local OnlineStatus = Class(Widget, function(self, show_borrowed_info )
    Widget._ctor(self, "OnlineStatus")

	self.show_borrowed_info = show_borrowed_info
	
    self.fixed_root = self:AddChild(Widget("root"))
    self.fixed_root:SetAnchors("center","center")
    self.fixed_root:SetScaleMode(SCALEMODE_PROPORTIONAL)

    self.text = self.fixed_root:AddChild(Text(FONTFACE.DEFAULT, 20))
    self.text:SetPosition(378, 345)
    self.text:SetHAlign(ANCHOR_RIGHT)
    self.text:SetRegionSize(300,40)

    self.debug_connections = self.fixed_root:AddChild(Text(FONTFACE.DEFAULT, 20, nil, UICOLORS.GREY))
    self.debug_connections:SetPosition(90, 345)

    self:StartUpdating()
end)

function OnlineStatus:OnUpdate()
	if self.show_borrowed_info and TheSim:IsBorrowed() then
		self.text:SetString(STRINGS.UI.MAINSCREEN.FAMILY_SHARED)
        self.text:SetGlyphColour(80/255, 143/255, 244/255, 255/255)
        self.text:Show()
    end
    
    -- If you're offline I guess it doesn't matter that you're borrowed?
    if TheFrontEnd:GetIsOfflineMode() or not TheNet:IsLoggedOn() then
        self.text:SetString(STRINGS.UI.MAINSCREEN.OFFLINE)
        self.text:SetGlyphColour(242/255, 99/255, 99/255, 255/255)
        self.text:Show()
    end

    if DEV_MODE then
        self.debug_connections:SetString(string.format("%s %s",
                TheNet:IsOnlineMode() and "Connected" or "Offline",
                TheNet:IsHost() and "as Host" or ""
            ))
    end
end

return OnlineStatus
