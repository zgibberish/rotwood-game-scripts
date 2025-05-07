local Clickable = require "widgets.clickable"
local Image = require "widgets.image"
local ImageButton = require "widgets.imagebutton"
local TextButton = require "widgets.textbutton"
local Text = require "widgets.text"
local Widget = require "widgets/widget"
local easing = require "util.easing"
require "class"
require "util"

local TabGroup = Class(Widget, function(self)
	Widget._ctor(self, "TabGroup")
	self.tabs = {}
	self:SetTheme_DarkOnLight()
end)

function TabGroup:OnRemoved()
	TheInput:UnregisterForDeviceChanges(self._ondevicechange_fn)
end


function TabGroup:SetTheme_DarkOnLight()
	self.colors = {
		normal = UICOLORS.DARK_TEXT,
		focus = UICOLORS.FOCUS,
		disabled = UICOLORS.DISABLED,
		selected = UICOLORS.BLACK,
	}
	return self
end

function TabGroup:SetTheme_LightTransparentOnDark()
	local normal = deepcopy(UICOLORS.LIGHT_TEXT_DARK)
	normal[4] = normal[4] * 0.5
	self.colors = {
		normal = normal,
		focus = UICOLORS.LIGHT_TEXT_DARK,
		disabled = UICOLORS.DISABLED,
		selected = UICOLORS.LIGHT_TEXT_SELECTED,
	}
	return self
end

function TabGroup:SetFontSize(font_size)
	assert(#self.tabs == 0, "SetFontSize before adding tabs.")
	self.font_size = font_size
	return self
end

function TabGroup:SetTabSize(w,h)
	for _,tab in ipairs(self.tabs) do
		tab:SetSize(w,h)
	end
	return self
end

function TabGroup:SetTabOnClick(onclickfn)

	-- Save callback function
	self.on_click_fn = function(tab)
		if self.current then
			self.current:Unselect()
		end
		self.current = tab
		self.current:Select()
		onclickfn(tab)
	end

	-- If there are tabs already, set the callback on them
	for _,tab in ipairs(self.tabs) do
		tab:SetOnClick(function() self.on_click_fn(tab) end)
	end
	return self
end

function TabGroup:SelectTab(index, trigger_click)
	for i ,tab in ipairs(self.tabs) do
		if i == index then
			if self.current then
				self.current:Unselect()
			end
			self.current = tab
			self.current:Select()
			if trigger_click then
				onclickfn(tab)
			end
		end
	end
end

function TabGroup:SetNavFocusable(can_focus_with_nav)
	for _,tab in ipairs(self.tabs) do
		tab:SetNavFocusable(can_focus_with_nav)
	end
	return self
end


function TabGroup:GetNumTabs()
	return #self.tabs
end

function TabGroup:GetCurrentIdx()
	for i,v in ipairs(self.tabs) do
		if self.current == v then
			return i
		end
	end
end

function TabGroup:NextTab(delta)
	delta = delta or 1
	local idx = self:GetCurrentIdx()
	local slot = circular_index(self.tabs, idx + delta)
	slot:Click()
end

function TabGroup:OpenTabAtIndex(idx)
	local tab = self.tabs[idx]
	if tab then
		tab:Click()
		return tab
	end
end

function TabGroup:AddCycleIcons(icon_size, icon_margin, icon_color)
	assert(not self._ondevicechange_fn, "Don't call AddCycleIcons more than once.")
	assert(#self.tabs > 0, "AddCycleIcons after adding all your tabs.")

	self._ondevicechange_fn = function(old_device_type, device_type)
		self:RefreshHotkeyIcon()
	end
	TheInput:RegisterForDeviceChanges(self._ondevicechange_fn)

	icon_size = icon_size or 50
	icon_margin = icon_margin or 20
	icon_color = icon_color or self.colors.normal

	self.prev_icon = self:AddChild(Image())
		:SetSize(icon_size, icon_size)
		:SetMultColor(icon_color)
		:SetHiddenBoundingBox(true)
		:LayoutBounds("before", "center", self.tabs[1])
		:Offset(-icon_margin, 0)
	self.next_icon = self:AddChild(Image())
		:SetSize(icon_size, icon_size)
		:SetMultColor(icon_color)
		:SetHiddenBoundingBox(true)
		:LayoutBounds("after", "center", self.tabs[#self.tabs])
		:Offset(icon_margin, 0)
	self:RefreshHotkeyIcon()
	self.prev_icon:SendToBack() -- so it's first in children if we do LayoutChildrenInGrid.
	return self
end

function TabGroup:SetIsSubTab(is_subtab)
	self.is_subtab = is_subtab
	return self
end

function TabGroup:RefreshHotkeyIcon()
	if TheFrontEnd:IsRelativeNavigation() then
		local prev_control = Controls.Digital.MENU_TAB_PREV
		local next_control = Controls.Digital.MENU_TAB_NEXT

		if self.is_subtab then
			prev_control = Controls.Digital.MENU_SUB_TAB_PREV
			next_control = Controls.Digital.MENU_SUB_TAB_NEXT
		end

		-- Fall back to last input device so TabGroup works in main menu or
		-- screens not tied to a single player.
		local owner = self:GetOwningPlayer()
		local input_source = owner and owner.playercontroller or TheInput

		self.prev_icon:SetTexture(input_source:GetTexForControl(prev_control))
			:Show()
		self.next_icon:SetTexture(input_source:GetTexForControl(next_control))
			:Show()
	else
		-- TODO(dbriscoe): For now, hide the icons when using mouse because
		-- they don't match the size of gamepad and are a bit ugly.
		self.prev_icon:Hide()
		self.next_icon:Hide()
	end
end


function TabGroup:_HookupTab(tab)
	table.insert(self.tabs, tab)
	if not self.current then
		self.current = tab
	end
	if self.on_click_fn then tab:SetOnClick(function() self.on_click_fn(tab) end) end
	return tab
end

-- A tab with an icon and tooltip.
-- TODO(dbriscoe): Rename to AddIconTab
function TabGroup:AddTab(icon)
	local tab = self:AddChild(ImageButton(icon))
		:SetImageNormalColour(self.colors.normal)
		:SetImageFocusColour(self.colors.focus)
		:SetImageDisabledColour(self.colors.disabled)
		:SetImageSelectedColour(self.colors.selected)

	return self:_HookupTab(tab)
end

-- A tab with a square icon and text label.
function TabGroup:AddIconTextTab(icon, text)
	assert(icon)
	assert(text)
	local tab = self:AddChild(Clickable())
	tab.icon = tab:AddChild(Image(icon))
		:SetMultColor(WEBCOLORS.WHITE)

	tab.text = tab:AddChild(Text(FONTFACE.DEFAULT, self.font_size or 20))
		:SetGlyphColor(WEBCOLORS.WHITE)
		:SetText(text)
		:LeftAlign()
	tab.text.offset = 8

	function tab:RelayoutTab()
		self.text
			:LayoutBounds("after", "center", self.icon)
			:Offset(self.text.offset, 0)
		return self
	end
	function tab:SetSize(x, y)
		self.icon:SetSize(y, y)
		if x then
			-- Force the text to fill up remaining space. Useful for vertical
			-- alignment, but not so great for horizontal tabs.
			local w = x - y - self.text.offset
			self.text:SetSize(w, y)
		end
		return self:RelayoutTab()
	end

	tab:RelayoutTab()

	self:_ApplyFancyTint(tab)
	return self:_HookupTab(tab)
end

-- A tab with just text.
function TabGroup:AddTextTab(label, font_size)
	font_size = font_size or self.font_size
	local tab = self:AddChild(TextButton())
		-- All colors are white because we tint the text for prettier fades.
		:SetTextColour(WEBCOLORS.WHITE)
		:SetTextFocusColour(WEBCOLORS.WHITE)
		:SetTextDisabledColour(WEBCOLORS.WHITE)
		:SetTextSelectedColour(WEBCOLORS.WHITE)
		:SetTextSize(font_size or 20)
		:SetText(label)
	self:_HookupTab(tab)
	return self:_ApplyFancyTint(tab)
end

function TabGroup:_ApplyFancyTint(tab)
	tab:SetOnGainFocus(function()
		tab:TintTo(nil, self.colors.focus, 0.05, easing.inQuad)
	end)
	tab:SetOnLoseFocus(function()
		tab:TintTo(nil, tab:IsSelected() and self.colors.selected or self.colors.normal, 0.3, easing.outQuad)
	end)
	tab:SetOnDown(function()
		tab:TintTo(nil, self.colors.selected, 0.05, easing.inQuad)
	end)
	tab:SetOnUp(function()
		tab:TintTo(nil, tab:IsSelected() and self.colors.selected or self.colors.normal, 0.3, easing.outQuad)
	end)
	tab:SetOnSelect(function()
		tab:TintTo(nil, self.colors.selected, 0.05, easing.inQuad)
	end)
	tab:SetOnUnSelect(function()
		tab:TintTo(nil, self.colors.normal, 0.3, easing.outQuad)
	end)

	-- Snap to initial color
	tab:TintTo(nil, self.colors.normal, 0, easing.outQuad)

	return tab
end

function TabGroup:RemoveAllTabs()
	self:RemoveAllChildren()
	TheInput:UnregisterForDeviceChanges(self._ondevicechange_fn)
	self._ondevicechange_fn = nil
	self.tabs = {}
	self.current = nil
	return self
end

-- TODO(dbriscoe): POSTVS We should have some way of preventing tab cycling
-- during screen animations. IgnoreInput, Disable, etc.
--~ function TabGroup:OnEnable()
--~ 	for _,tab in ipairs(self.tabs) do
--~ 		tab:Enable()
--~ 	end
--~ end

--~ function TabGroup:OnDisable()
--~ 	for _,tab in ipairs(self.tabs) do
--~ 		tab:Disable()
--~ 	end
--~ end

return TabGroup
