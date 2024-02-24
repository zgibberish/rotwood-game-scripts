local Widget = require("widgets/widget")
local Text = require("widgets/text")
local PlayerWeaponWidget = require("widgets/ftf/playerweaponwidget")


--- Displays a single player character's username
-- Check PlayerStatusWidget to see this with a health bar, actions bar and buffs container
local PlayerUsernameWidget =  Class(Widget, function(self, owner, colour)
	Widget._ctor(self, "PlayerUsernameWidget")

	self.weapon_widget = self:AddChild(PlayerWeaponWidget(self.owner))
	self.name_text = self:AddChild(Text(FONTFACE.DEFAULT, 18, nil, UICOLORS.LIGHT_TEXT_TITLE))
		:EnableShadow()
		:SetShadowColor(UICOLORS.BLACK)
		:SetShadowOffset(1, -1)
		:EnableOutline()
		:SetOutlineColor(UICOLORS.BLACK)

	if owner then
		self:SetOwner(owner, colour)
	end
end)

-- When you want to layout something relative to this, it shouldn't be empty.
function PlayerUsernameWidget:FillWithPlaceholder()
	self.name_text:SetText("PLACEHOLDER")
	self.weapon_widget:FillWithPlaceholder()
	self:_Layout()
	return self
end

function PlayerUsernameWidget:HideOutline()
	self.name_text
		:EnableShadow(false)
		:EnableOutline(false)
	return self
end

function PlayerUsernameWidget:SetOwner(owner, colour)
	self.owner = owner
	colour = owner and owner.uicolor or colour
	self.weapon_widget:SetOwner(self.owner)
	self:RefreshName()
	self.inst:ListenForEvent("username_changed", function(_, data) self:RefreshName() end, self.owner)
	return self
end

function PlayerUsernameWidget:RefreshName()
	local username = self.owner:GetCustomUserName()
	local colour = self.owner and self.owner.uicolor
	self.name_text:SetText(username)
		:SetGlyphColor(colour and colour or UICOLORS.LIGHT_TEXT_TITLE)

	-- Uncomment in local 4p to test multiple name lengths.
	--~ if username:find("2") then
	--~ 	self.name_text:SetText(username..username)
	--~ end
	--~ if username:find("3") then
	--~ 	self.name_text:SetText(username:sub(1,5))
	--~ end

	self:_Layout()
end

function PlayerUsernameWidget:SetFontSize(size)
	self.name_text:SetFontSize(size)
	self.weapon_widget:SetSize(size)
	self:_Layout()
	return self
end

function PlayerUsernameWidget:_Layout()
	self.weapon_widget:LayoutBounds("before", "center", self.name_text)
		:Offset(-5, 0)
end

return PlayerUsernameWidget
