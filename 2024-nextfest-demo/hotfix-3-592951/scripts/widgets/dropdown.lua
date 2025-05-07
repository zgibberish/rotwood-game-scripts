local Image = require "widgets.image"
local Panel = require "widgets.panel"
local PanelButton = require "widgets.panelbutton"
local ScrollPanel = require "widgets.scrollpanel"
local Text = require "widgets.text"
local Widget = require "widgets.widget"
local easing = require "util.easing"
local fmodtable = require "defs.sound.fmodtable"

local DropDown = Class(Widget, function(self, width, height)
	Widget._ctor(self, "DropDown")

	-- Set up values
	self.hAlign = ANCHOR_LEFT								-- Where to align the row and list text
	self.width = width or 220 * HACK_FOR_4K								-- Width of the main widget row
	self.listWidthOffset = -2								-- How much thinner the list should be than the background texture
	self.listWidth = self.width - self.listWidthOffset		-- Width of the list
	self.listPosOffset = 0									-- X offset of the list vs the background
	self.height = height or 50 * HACK_FOR_4K								-- Height of the main widget row
	self.buttonMargin = 5									-- Spacing around the button image
	self.buttonMarginRight = 5								-- Spacing from the right edge
	self.buttonSize = self.height - self.buttonMargin * 2	-- Square dropdown button size
	self.listHeightMax = 200 * HACK_FOR_4K								-- How tall the list can get. Above this, it shows a scroll bar
	self.textSpacingLeft = 10 * HACK_FOR_4K								-- Space between the left edge and the text
	self.textWidth = self.width - self.buttonSize - self.buttonMargin - self.textSpacingLeft		-- How wide the text can be, for the main row and list items
	self.listOpen = false

	-- Main row that's always displayed
	self.background = self:AddChild(PanelButton("images/ui_ftf_options/toggle_bg.tex"))
		:SetNineSliceCoords(5, 8, 95, 92)
		:SetScaleOnFocus(false)
		:SetMultColor(UICOLORS.LIGHT_TEXT_DARKER)
		:SetOnClick(function() self:OnButtonClick() end)
	self.valueText = self:AddChild(Text(FONTFACE.DEFAULT, FONTSIZE.OPTIONS_ROW_TITLE, "", UICOLORS.WHITE))
		:LeftAlign()
		:SetMultColor(UICOLORS.BACKGROUND_DARK)
	self.button = self:AddChild(Image("images/ui_ftf_options/dropdown_down.tex"))
		:SetMultColor(UICOLORS.BACKGROUND_DARK)

	-- List of selectable options
	self.listContainer = self:AddChild(Widget("List Container"))
		:SendToBack()
		:SetShown(self.listOpen)
	self.listBackground = self.listContainer:AddChild(Panel("images/ui_ftf_options/toggle_bg.tex"))
		:SetNineSliceCoords(5, 8, 95, 92)
		:SetMultColor(HexToRGB(0xB28637FF))
	self.scroll = self.listContainer:AddChild(ScrollPanel())
		:SetScrollBarMargin(-29 * HACK_FOR_4K) -- Make the content display even below the scroll bar
		:SetVirtualMargin(5)
		:SetVirtualBottomMargin(0)
	self.scrollContents = self.scroll:AddScrollChild(Widget())

	-- DEBUG: Useful to preview the bounds of the scroll panel
	-- self.scrollContents:AddChild(Image("images/global/square.tex"))
	-- 	:SetMultColor(HexToRGB(0xff00ff30))
	-- 	:SetSize(5000, 5000)

	-- Apply default sizes
	self:SetSize(self.width, self.height)

	self.openlist_sound =    fmodtable.Event.ui_dropdown_expand
	self.closelist_sound =   fmodtable.Event.ui_dropdown_collapse
	self:SetControlDownSound(fmodtable.Event.ui_dropdown_click)

end)

function DropDown:SetNavFocusable(focusable)
	DropDown._base.SetNavFocusable(self, focusable)
	self.background:SetNavFocusable(focusable)
	return self
end

function DropDown:IsListOpen()
	return self.listOpen
end

function DropDown:OnButtonClick()
	if self.listOpen then
		self:CloseList()
	else
		self:OpenList()
	end
	return self
end

function DropDown:OpenList()
	-- Remove old widgets, if any
	self.scrollContents:RemoveAllChildren()

	-- Keep reference to the current value list item
	local currentListItem = nil

	-- Fill up list with things
	for k, v in ipairs(self.values) do
		-- Add buttons for every selectable dropdown value
		local listItemBg = self.scrollContents:AddChild(PanelButton("images/ui_ftf_options/toggle_bg.tex"))
			:SetNineSliceCoords(5, 8, 95, 92)
			:SetScaleOnFocus(false)
			:SetImageNormalColour(self.currentIndex == k and UICOLORS.FOCUS or UICOLORS.FOCUS_TRANSPARENT)
			:SetImageFocusColour(UICOLORS.FOCUS)
			:SetOnClick(function() self:OnValueClick(k, v) end)

		if self.currentIndex == k then
			currentListItem = listItemBg
		end

		local listItemText = listItemBg:AddChild(Text(FONTFACE.DEFAULT, FONTSIZE.OPTIONS_ROW_TITLE, "", UICOLORS.WHITE))
			:SetMultColor(UICOLORS.BACKGROUND_DARK)
			:SetAutoSize(self.textWidth)
			:SetText(v.name)

		if self.hAlign == ANCHOR_LEFT then
			listItemText:LeftAlign()
		else
			listItemText:RightAlign()
		end

		-- Get text size
		local textW, textH = listItemText:GetSize()

		listItemBg:SetSize(self.listWidth, textH + 4 * HACK_FOR_4K)
		listItemText:LayoutBounds(self.hAlign == ANCHOR_LEFT and "left" or "before", "center", listItemBg)
			:Offset(self.hAlign == ANCHOR_LEFT and self.textSpacingLeft or self.textWidth, 0)

	end
	self.scrollContents:LayoutChildrenInGrid(1, 0)
		:LayoutBounds("left", "top", -self.listWidth/2, 0)
		:Offset(7, 0)
	self.scroll:RefreshView()
	if currentListItem then
		local snap = true
		self.scroll:EnsureVisible(currentListItem, snap)
	end


	-- Open the list
	self.listOpen = true
	self.listContainer:SetHiddenBoundingBox(false)
		:SetMultColorAlpha(0)
		:Show()
		:SetPosition(self.listX, self.listY + 20 * HACK_FOR_4K)
		:MoveTo(self.listX, self.listY, 0.1, easing.inOutQuad)
		:AlphaTo(1, 0.1, easing.inOutQuad)

	
	TheFrontEnd:GetSound():PlaySound(self.openlist_sound)

	return self
end

function DropDown:CloseList()

	self.listOpen = false
	self.listContainer
		:SetHiddenBoundingBox(true) -- So parents don't take the size of the dropdown into account
		:MoveTo(self.listX, self.listY + 20 * HACK_FOR_4K, 0.2, easing.inOutQuad)
		:AlphaTo(0, 0.2, easing.inOutQuad, function()
			-- Animation done.
			self.listContainer:Hide()

			-- Remove all widgets from the list
			self.scrollContents:RemoveAllChildren()
		end)

	-- TODO For some reason, it needs this to report the correct size after hiding the container
	self:InvalidateBBox()

	TheFrontEnd:GetSound():PlaySound(self.closelist_sound)

	return self
end

function DropDown:OnValueClick(valueIndex, valueData)
	self:CloseList()
	self:_SetValue(valueIndex)
	return self
end

function DropDown:SetBackground(texture, minx, miny, maxx, maxy)
	self.background:SetTextures(texture)
	self.background:SetNineSliceCoords(minx, miny, maxx, maxy)
	return self
end

-- How thinner or wider should the list be than the background
-- And how much should it move to the left or right to stay aligned with the background texture
function DropDown:SetListWidthOffset(width_offset, pos_x_offset)
	self.listWidthOffset = width_offset or -2
	self.listPosOffset = pos_x_offset or 0
	return self
end

function DropDown:SetBackgroundColour(colour)
	self.background:SetMultColor(colour)
	return self
end

function DropDown:SetButtonColour(colour)
	self.button:SetMultColor(colour)
	return self
end

function DropDown:SetTextColour(colour)
	self.valueText:SetMultColor(colour)
	return self
end

function DropDown:DropdownTintTo(back, text, duration)
	self.background:TintTo(nil, back, duration or 0.2, easing.inOutQuad)
	self.valueText:TintTo(nil, text, duration or 0.2, easing.inOutQuad)
	self.button:TintTo(nil, text, duration or 0.2, easing.inOutQuad)
	return self
end

function DropDown:LeftAlign()
	self.hAlign = ANCHOR_LEFT
	self.valueText:LeftAlign()
	self:LayoutValue()
	return self
end

function DropDown:RightAlign()
	self.hAlign = ANCHOR_RIGHT
	self.valueText:RightAlign()
	self:LayoutValue()
	return self
end

function DropDown:SetButtonMargin(margin)
	self.buttonMargin = margin
	return self
end

function DropDown:SetButtonMarginRight(margin_right)
	self.buttonMarginRight = margin_right
	return self
end

function DropDown:SetSize(width, height)
	self.width = width or 220 * HACK_FOR_4K
	self.height = height or 50 * HACK_FOR_4K

	-- Resize main row
	self.background:SetSize(self.width, self.height)
	self.button:SetSize(self.height - self.buttonMargin*2, self.height - self.buttonMargin*2)
		:LayoutBounds("right", "center", self.background)
		:Offset(-self.buttonMarginRight, 0)
	self:LayoutValue()

	-- Resize list
	self.listWidth = self.width + self.listWidthOffset
	self.listBackground:SetSize(self.listWidth, self.listHeightMax)
	self.scroll:SetSize(self.listWidth - 15 * HACK_FOR_4K, self.listHeightMax)
		:LayoutBounds("left", "top", self.listBackground)
	self.listContainer:LayoutBounds("center", "below", self.background)
		:Offset(self.listPosOffset, 5)

	-- Save the list position for animation purposes
	self.listX, self.listY = self.listContainer:GetPosition()

	return self
end

function DropDown:LayoutValue()
	self.valueText
		:LayoutBounds(self.hAlign == ANCHOR_LEFT and "left" or "before", "center", self.background)
		:Offset(self.hAlign == ANCHOR_LEFT and self.textSpacingLeft or self.textWidth, 0)
	return self
end

function DropDown:SetValues(values)
	self.values = values or {}
	return self
end

function DropDown:_SetValue(index)
	self.currentIndex = index
	local valueData = self.values[self.currentIndex]

	if valueData and valueData.name then
		self.valueText:SetText(valueData.name)
		self:LayoutValue()
	end

	if self.onValueChangeFn then
		self.onValueChangeFn(valueData.data, self.currentIndex, valueData)
	end
	return self
end

function DropDown:SetOnValueChangeFn(onValueChangeFn)
	self.onValueChangeFn = onValueChangeFn
	return self
end

return DropDown
