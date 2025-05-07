local Widget = require("widgets/widget")
local Text = require("widgets/text")


--- Displays a single player character's username
-- Check PlayerStatusWidget to see this with a health bar, actions bar and buffs container
local PlayerTitleWidget =  Class(Widget, function(self, owner, size)
	Widget._ctor(self, "PlayerTitleWidget")

	size = size or 18

	self.spool_rate = 35

	self.title_text = self:AddChild(Text(FONTFACE.DEFAULT, size, nil, UICOLORS.LIGHT_TEXT_TITLE))
		:EnableShadow()
		:SetShadowColor(UICOLORS.BLACK)
		:SetShadowOffset(1, -1)
		:EnableOutline()
		:SetOutlineColor(UICOLORS.BLACK)

	if owner then 
		self:SetOwner(owner) 
	end
end)

function PlayerTitleWidget:HideOutline()
	self.title_text
		:EnableShadow(false)
		:EnableOutline(false)
	return self
end

-- When you want to layout something relative to this, it shouldn't be empty.
function PlayerTitleWidget:FillWithPlaceholder()
	self.title_text:SetText("PLACEHOLDER")
	return self
end

function PlayerTitleWidget:SetOwner(owner)
	if self.owner ~= nil then
		self.inst:RemoveEventCallback("title_changed", self._ontitlechanged, self.owner)
	end

	self._ontitlechanged = function()
		self:Refresh() 
	end
	self.inst:ListenForEvent("title_changed", self._ontitlechanged, self.owner)
	
	self.owner = owner
	self:Refresh()
	return self
end

function PlayerTitleWidget:Refresh()
	if self.owner == nil then
		self:Hide()
		return
	end

	local title_str = self.owner.components.playertitleholder:GetPretty()
	if title_str == nil then
		self:Hide()
	else
		self.title_text:SetText(title_str)
			:Spool(self.spool_rate)
		self:Show()
	end
end

-- Used for title preview in characterscreen.lua
function PlayerTitleWidget:ForceTitleText(txt)
	self.title_text:SetText(txt)
		:Spool(self.spool_rate)
end

function PlayerTitleWidget:SetFontSize(size)
	self.title_text:SetFontSize(size)
	return self
end

function PlayerTitleWidget:SetColor(color)
	self.title_text:SetGlyphColor(color)
	return self
end

return PlayerTitleWidget
