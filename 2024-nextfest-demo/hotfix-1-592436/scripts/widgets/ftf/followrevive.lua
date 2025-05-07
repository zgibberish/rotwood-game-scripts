local FollowPrompt = require("widgets/ftf/followprompt")
local Text = require("widgets/text")
local Image = require("widgets/image")
local RadialProgress = require("widgets/radialprogress")


-- Text that follows a world-space entity around.
local FollowRevive = Class(FollowPrompt, function(self, owning_player)
	FollowPrompt._ctor(self, owning_player)

	self.textLabel = self:AddChild(Text(FONTFACE.DEFAULT, FONTSIZE.SCREEN_SUBTITLE, ""))
		:SetName("Text label")
		:SetGlyphColor(UICOLORS.WHITE)

	local icon_size = 120
	self.icon = self:AddChild(Image("images/ui_ftf_hud/revive_icon.tex"))
		:SetName("Icon")
		:SetSize(icon_size, icon_size)
	self.radial = self:AddChild(RadialProgress("images/ui_ftf_hud/revive_icon_radial.tex"))
		:SetName("Radial")
		:SetSize(icon_size, icon_size)
end)

function FollowRevive:GetText()
	return self.textLabel:GetText()
end

function FollowRevive:SetText(text)
	self.textLabel:SetText(text)
	self.icon:LayoutBounds("center", "above", self.textLabel)
		:Offset(0, 10)
	self.radial:LayoutBounds("center", "center", self.icon)
	return self
end

function FollowRevive:SetProgress(zeroToOne)
	self.radial:SetProgress(zeroToOne)
	return self
end

function FollowRevive:GetLabelWidget()
	return self.textLabel
end

return FollowRevive
