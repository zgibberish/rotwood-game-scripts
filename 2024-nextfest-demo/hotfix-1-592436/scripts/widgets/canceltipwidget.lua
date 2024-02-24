local Widget = require "widgets/widget"
local Text = require "widgets/text"

local CancelTipWidget = Class(Widget, function(self)
	Widget._ctor(self, "CancelTipWidget")
	self.initialized = false
	self.forceShowNextFrame = false
	self.is_enabled = false
    self:Hide()
	self:StartUpdating()
end)

function CancelTipWidget:SetEnabled(enabled)
    self.is_enabled = enabled
	if enabled then
		self.initialized = false
    	self:Show()
	else
		self:Hide()
		self.is_enabled = false
        self:Hide()
        self:StopUpdating()
	end
end

function CancelTipWidget:ShowNextFrame()
	self.forceShowNextFrame = true
end

function CancelTipWidget:KeepAlive( auto_increment )

	local just_initialized = false
	if self.initialized == false then
		local local_cancel_tip_widget = self:AddChild(Text(FONTFACE.DEFAULT, 33))
		local_cancel_tip_widget:SetPosition(0, -50)
		local_cancel_tip_widget:SetGlyphColor(1,1,1,0)
		local_cancel_tip_widget:SetHAlign(ANCHOR_LEFT)
		local_cancel_tip_widget:SetVAlign(ANCHOR_BOTTOM)
		local args = {
			input = TheInput:GetLabelForControl(Controls.Digital.CANCEL),
		}
		local_cancel_tip_widget:SetText(STRINGS.UI.NOTIFICATION.PRESS_TO_DISCONNECT:subfmt(args))

		self.cancel_tip_widget = local_cancel_tip_widget
		self.cached_fade_level = 0.0
		self.initialized = true
		
		just_initialized = true
	end
	
	if self.initialized then
	    if self.is_enabled then
		    if TheFrontEnd and auto_increment == false then
			    self.cached_fade_level = TheFrontEnd:GetFadeLevel()
		    else
			    self.cached_fade_level = 1.0
		    end
		    
		    self.cancel_tip_widget:SetGlyphColour(1,1,1,self.cached_fade_level*self.cached_fade_level)
		    
		    if 0.01 > self.cached_fade_level then
		        self.is_enabled = false
		        self:Hide()
		        self:StopUpdating()
		    end		    
		end	
	end
end

function CancelTipWidget:OnUpdate()
	self:KeepAlive(self.forceShowNextFrame)
	self.forceShowNextFrame = false
end

return CancelTipWidget
