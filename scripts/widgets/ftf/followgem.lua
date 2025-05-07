local FollowPrompt = require("widgets/ftf/followprompt")
local GemXpBar = require("widgets/gemxpbar")
local Text = require("widgets/text")

-- Text that follows a world-space entity around.
local FollowGem = Class(FollowPrompt, function(self, power)
	FollowPrompt._ctor(self)

	self.scale = 1.25
	self.offset_x = 0
	self.offset_y = 500

	self.name_label = self:AddChild(Text(FONTFACE.DEFAULT, FONTSIZE.SCREEN_SUBTITLE, ""))
		:SetName("Text label")
		:SetGlyphColor(UICOLORS.WHITE)
		:Offset(0, 50)

	self.gem_level = self:AddChild(GemXpBar())
		:SetName("Gem level")
		-- :SetTextColor(HexToRGB(0x967D7155))
		:SetMaxWidth(300)

	self:SetScale(self.scale)
end)

function FollowGem:SetText(text)
	self.textLabel:SetText(text)
	self.icon:LayoutBounds("center", "above", self.textLabel)
		:Offset(0, 10)
	self.radial:LayoutBounds("center", "center", self.icon)
	return self
end

function FollowGem:SetProgress(zeroToOne)
	self.radial:SetProgress(zeroToOne)
	return self
end

function FollowGem:Init(data)
	-- data =
	-- 		target: what world object to be placed on
	--		scale: how big should this widget be
	-- 		offset_x: x offset lol
	--		offset_y: y offset lol

	self.gem_level:SetGem(data.gem)

	if data.offset_x then self.offset_x = data.offset_x end
	if data.offset_y then self.offset_y = data.offset_y end
	if data.scale then self.scale = data.scale end

	local def = data.gem:GetDef()
	self.name_label:SetText(def.pretty.name)

	self.target = data.target

	self:Offset(self.offset_x, self.offset_y)
	self:SetScale(self.scale)
	self:SetTarget(self.target)

end

return FollowGem
