local FollowPrompt = require("widgets/ftf/followprompt")
local templates = require "widgets.ftf.templates"

local FollowButton = Class(FollowPrompt, function(self, owning_player)
	FollowPrompt._ctor(self, owning_player)

	-- TODO: only allow player to click the button so mouse player can't
	-- trigger gamepad player's interact.

	self.imageButton = self:AddChild(templates.Button(""))

	self:SetFocus()
end)

function FollowButton:SetText(text)
	self.imageButton:SetText(text)
	return self
end

function FollowButton:SetTextAndResizeToFit(text, horizontal_padding, vertical_padding)
	self.imageButton:SetTextAndResizeToFit(text, horizontal_padding, vertical_padding)
	return self
end

function FollowButton:SetOnClick(fn)
	self.imageButton:SetOnClick(fn)
	return self
end

function FollowButton:Click()
	self.imageButton:Click()
end

return FollowButton
