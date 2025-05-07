local Screen = require("widgets/screen")
local Image = require("widgets/image")

local PopupDialog = Class(Screen, function(self, id, controller, blocksScreen)
	local widgetId = id ~= nil and id or "PopupDialog"
	Screen._ctor(self, widgetId)
	self:SetAudioCategory(Screen.AudioCategory.s.Popup)

	self.controller = controller
	self.blocksScreen = blocksScreen == nil and true or blocksScreen
	-- TODO(dbriscoe): blocksScreen should proably set is_overlay

	-- Background fade out everything
	if self.blocksScreen then
		self.bg = self:AddChild(Image("images/global/square.tex"))
			:SetScale(100)
			:SetMultColor(0, 0, 0, 0.5)
	end
end)

function PopupDialog:OnBecomeActive()
	PopupDialog._base.OnBecomeActive(self)
end

return PopupDialog
