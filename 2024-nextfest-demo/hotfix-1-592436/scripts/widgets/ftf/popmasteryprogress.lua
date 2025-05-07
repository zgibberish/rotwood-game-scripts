local Widget = require "widgets.widget"
local Text = require "widgets.text"
local Image = require "widgets.image"
local PopPrompt = require "widgets.ftf.popprompt"

local easing = require "util.easing"

local PopMasteryProgress = Class(PopPrompt, function(self, target, button)
	Widget._ctor(self, "PopMasteryProgress")

	self.icon = self:AddChild(Image())
		:SetMultColor(UICOLORS.GOLD_FOCUS)
		:SetSize(128, 128)

	self.text_root = self:AddChild(Widget())

	self.number = self.text_root:AddChild(Text(FONTFACE.BUTTON, 75, "", UICOLORS.GOLD_FOCUS))
		:SetShadowColor(UICOLORS.BLACK)
		:SetShadowOffset(1, -1)
		:SetOutlineColor(UICOLORS.BLACK)
		:EnableShadow()
		:EnableOutline()

	self.desc = self.text_root:AddChild(Text(FONTFACE.BUTTON, 50, "", UICOLORS.WHITE))
		:SetShadowColor(UICOLORS.BLACK)
		:SetShadowOffset(1, -1)
		:SetOutlineColor(UICOLORS.BLACK)
		:EnableShadow()
		:EnableOutline()
		:LeftAlign()
end)

local function _get_main_string(mst)
	local main_str = ("%s %s/%s"):format(mst:GetDef().pretty.name, mst:GetProgress(), mst:GetMaxProgress())

	if mst:IsNew() then
		main_str = ("%s Activated!"):format(mst:GetDef().pretty.name)
	end

	if mst:IsComplete() then
		main_str = ("%s Complete!"):format(mst:GetDef().pretty.name)
	end

	return main_str
end

function PopMasteryProgress:Init(data)
	if data.color then
		self.number:SetGlyphColor(data.color)
	end

	if data.outline_color then
		self.number:SetOutlineColor(data.outline_color)
	end

	if data.size then
		self.number:SetFontSize(data.size)
		self.desc:SetFontSize(math.floor(data.size * 0.66))
	end

	local main_str = _get_main_string(data.mastery)
	local desc_str = data.mastery:GetDef().pretty.desc

	self.number:SetText(main_str)

	local w, h = self.number:GetSize()

	self.icon:SetTexture(data.mastery.def.icon):LayoutBounds("before", "top", self.number)
	self.desc:SetText(desc_str):SetAutoSize(w):LayoutBounds("left", "below", self.number)

	self:Start(data)
end

function PopMasteryProgress:Refresh(data)
	local main_str = _get_main_string(data.mastery)
	local desc_str = data.mastery:GetDef().pretty.desc

	self.number:SetText(main_str)
	local w, h = self.number:GetSize()
	self.icon:SetTexture(data.mastery.def.icon):LayoutBounds("before", "top", self.number)
	self.desc:SetText(desc_str):SetAutoSize(w):LayoutBounds("left", "below", self.number)

	self:Extend(data)
end

return PopMasteryProgress