local FollowPrompt = require("widgets/ftf/followprompt")
local Text = require("widgets/text")


-- Text that follows a world-space entity around.
local FollowLabel = Class(FollowPrompt, function(self, owning_player)
	FollowPrompt._ctor(self, owning_player)

	self.textLabel = self:AddChild(Text(FONTFACE.DEFAULT, FONTSIZE.SCREEN_SUBTITLE, ""))
		:SetName("Text label")
		:SetGlyphColor(UICOLORS.WHITE)
end)

function FollowLabel:SetText(text)
	self.textLabel:SetText(text)
	return self
end

function FollowLabel:GetLabelWidget()
	return self.textLabel
end

return FollowLabel
