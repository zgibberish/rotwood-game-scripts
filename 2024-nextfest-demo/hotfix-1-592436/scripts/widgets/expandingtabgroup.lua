local Clickable = require "widgets.clickable"
local TabGroup = require "widgets.tabgroup"
local Image = require "widgets.image"
local Panel = require "widgets.panel"
local ImageButton = require "widgets.imagebutton"
local TextButton = require "widgets.textbutton"
local ActionAvailableIcon = require("widgets/ftf/actionavailableicon")
local Text = require "widgets.text"
local Widget = require "widgets/widget"
local easing = require "util.easing"
require "class"
require "util"

local ExpandingTabGroup = Class(TabGroup, function(self)
	TabGroup._ctor(self, "ExpandingTabGroup")
end)

-- A tab with a bg, icon and text label
-- When selected, the icon and text are shown
-- When not, just the icon shows
--
-- ┌──────────────────┐  ┌──────────┐  ┌──────────┐ ◄ bg alternates between tab_odd and tab_even
-- │ ┌──────┐         │  │ ┌──────┐ │  │ ┌──────┐ │
-- │ │      ├───────┐ │  │ │      │ │  │ │      │ │
-- │ │ icon │ label │ │  │ │ icon │ │  │ │ icon │ │
-- │ │      ├───────┘ │  │ │      │ │  │ │      │ │
-- │ └──────┘         │  │ └──────┘ │  │ └──────┘ │
-- └──────────────────┘  └──────────┘  └──────────┘
--      ▲ the selected tab is expanded
--
function ExpandingTabGroup:AddTab(icon, text)
	local tab = self:AddChild(Clickable())
	tab.tab_group = self

	tab.icon_max_height = 90
	tab.is_locked = false

	local is_even = #self.children % 2 ~= 0
	tab.bg = tab:AddChild(Panel(is_even and "images/ui_ftf_research/research_tab_even.tex" or "images/ui_ftf_research/research_tab_odd.tex"))
		:SetNineSliceCoords(15, 0, 202, 150)
		:SetName("Background")
	tab.content = tab:AddChild(Widget())
		:SetName("Content")
	tab.icon = tab.content:AddChild(Image(icon))
		:SetName("Icon")
		:SetMultColor(WEBCOLORS.WHITE)
	tab.text = tab.content:AddChild(Text(FONTFACE.DEFAULT, 80))
		:SetName("Text")
		:SetGlyphColor(WEBCOLORS.WHITE)
		:SetText(text)
		:LeftAlign()
	tab.action_available_icon = tab:AddChild(ActionAvailableIcon())
		:SetName("Action available icon")
		:SetHiddenBoundingBox(true)
		:SetScale(1.2)
		:Hide()
	tab.text.offset = 8

	function tab:ShowAvailableActionIcon(show_icon)
		self.action_available_icon:SetShown(show_icon)
		return self
	end

	-- Locked tabs don't show text
	function tab:SetLocked(is_locked)
		self.is_locked = is_locked
		self:RelayoutTab()
		return self
	end

	function tab:RelayoutTab()
		-- Make sure the icon doesn't pass the icon_max_height
		local ic_w, ic_h = self.icon:GetSize()
		if ic_h > self.icon_max_height then
			local ratio = self.icon_max_height/ic_h
			self.icon:SetScale(ratio)
		end

		self.text:LayoutBounds("after", "center", self.icon)
			:Offset(self.text.offset, 0)
			:SetShown(self:IsSelected() and self.is_locked == false)
		local w, h = self.content:GetSize()
		self.bg:SetSize(w + 40, h + 30)
			:LayoutBounds("center", "center", self.content)
		self.action_available_icon:LayoutBounds("right", "top", self.bg)
			:Offset(-15, 10)
		if self.tab_group.onTabSizeChange then self.tab_group.onTabSizeChange() end
		return self
	end

	tab:RelayoutTab()

	self:_ApplyFancyTint(tab)
	return self:_HookupTab(tab)
end

function ExpandingTabGroup:SetTheme_DarkOnLight()
	self._base.SetTheme_DarkOnLight(self)

	-- Add more colors
	self.colors.text_normal = UICOLORS.DARK_TEXT
	self.colors.text_focus = UICOLORS.BLACK
	self.colors.text_disabled = UICOLORS.BLACK
	self.colors.text_selected = UICOLORS.BLACK
	self.colors.bg_normal = UICOLORS.LIGHT_TEXT
	self.colors.bg_focus = UICOLORS.FOCUS
	self.colors.bg_disabled = UICOLORS.DISABLED
	self.colors.bg_selected = UICOLORS.DARK_TEXT

	return self
end

function ExpandingTabGroup:_ApplyFancyTint(tab)
	tab:SetOnGainFocus(function()
		tab.bg:TintTo(nil, self.colors.bg_focus, 0.05, easing.inQuad)
		tab.icon:TintTo(nil, self.colors.text_focus, 0.05, easing.inQuad)
		tab.text:TintTo(nil, self.colors.text_focus, 0.05, easing.inQuad)
	end)
	tab:SetOnLoseFocus(function()
		tab.bg:TintTo(nil, tab:IsSelected() and self.colors.bg_selected or self.colors.bg_normal, 0.3, easing.outQuad)
		tab.icon:TintTo(nil, tab:IsSelected() and self.colors.text_selected or self.colors.text_normal, 0.3, easing.outQuad)
		tab.text:TintTo(nil, tab:IsSelected() and self.colors.text_selected or self.colors.text_normal, 0.3, easing.outQuad)
	end)
	tab:SetOnDown(function()
		tab.bg:TintTo(nil, self.colors.bg_selected, 0.05, easing.inQuad)
		tab.icon:TintTo(nil, self.colors.text_selected, 0.05, easing.inQuad)
		tab.text:TintTo(nil, self.colors.text_selected, 0.05, easing.inQuad)
	end)
	tab:SetOnUp(function()
		-- No change is needed, since the OnSelect or OnUnSelect will be triggered and change the tints
	end)
	tab:SetOnSelect(function()
		tab:RelayoutTab()
		if tab.hover or tab.focus then
			tab.bg:TintTo(nil, self.colors.bg_focus, 0.05, easing.inQuad)
			tab.icon:TintTo(nil, self.colors.text_focus, 0.05, easing.inQuad)
			tab.text:TintTo(nil, self.colors.text_focus, 0.05, easing.inQuad)
		else
			tab.bg:TintTo(nil, tab:IsSelected() and self.colors.bg_selected or self.colors.bg_normal, 0.3, easing.outQuad)
			tab.icon:TintTo(nil, tab:IsSelected() and self.colors.text_selected or self.colors.text_normal, 0.3, easing.outQuad)
			tab.text:TintTo(nil, tab:IsSelected() and self.colors.text_selected or self.colors.text_normal, 0.3, easing.outQuad)
		end
	end)
	tab:SetOnUnSelect(function()
		tab:RelayoutTab()
		tab.bg:TintTo(nil, self.colors.bg_normal, 0.3, easing.outQuad)
		tab.icon:TintTo(nil, self.colors.text_normal, 0.3, easing.outQuad)
		tab.text:TintTo(nil, self.colors.text_normal, 0.3, easing.outQuad)
	end)

	-- Snap to initial color
	tab.bg:TintTo(nil, self.colors.bg_normal, 0, easing.outQuad)
	tab.icon:TintTo(nil, self.colors.text_normal, 0, easing.outQuad)
	tab.text:TintTo(nil, self.colors.text_normal, 0, easing.outQuad)

	return tab
end

function ExpandingTabGroup:SetOnTabSizeChange(fn)
	self.onTabSizeChange = fn
	return self
end

return ExpandingTabGroup
