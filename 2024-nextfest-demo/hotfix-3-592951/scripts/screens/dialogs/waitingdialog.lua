local ConfirmDialog = require "screens.dialogs.confirmdialog"

local seconds_between_dots = 0.75
local max_dots = 5

---
-- Shows a dialog with waiting text and some expanding dots. With the right
-- text (see STRINGS.UI.NOTIFICATION), this is our SavingDialog or
-- LoadingDialog.
--
-- Call SetTitle to change the big text.
-- Call SetWaitingText to put text before dots.
--
local WaitingDialog = Class(ConfirmDialog, function(self)
	ConfirmDialog._ctor(self, nil, nil, true)
	self:HideButtons()
	self:HideArrow()
	self:CenterText()
	self:SetMinWidth(600)
	self.time = seconds_between_dots -- force immediate update for correct layout
	self.dots = 0
	self:SetWaitingText("") -- default to just showing dots
end)

function WaitingDialog:SetWaitingText(text)
	self.waiting_str = text
	self.dialogText:SetText(text)
	self:_LayoutDialog()
	return self
end

function WaitingDialog:OnUpdate(dt)
	self.time = self.time + dt
	if self.time > seconds_between_dots then
	    self.dots = self.dots + 1
	    if self.dots >= max_dots then
	        self.dots = 1
	    end

	    local text = self.waiting_str .. string.rep(".", self.dots)
        self:SetText(text)
	    self.time = 0
	end
end

return WaitingDialog
