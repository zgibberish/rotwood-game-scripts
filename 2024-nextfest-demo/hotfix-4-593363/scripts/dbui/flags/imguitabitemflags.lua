-- Generated by tools/imgui_upgrader/build_enums.lua

local ImGuiTabItemFlags_None                         = 0
local ImGuiTabItemFlags_UnsavedDocument              = 1   -- 1 << 0
local ImGuiTabItemFlags_SetSelected                  = 2   -- 1 << 1
local ImGuiTabItemFlags_NoCloseWithMiddleMouseButton = 4   -- 1 << 2
local ImGuiTabItemFlags_NoPushId                     = 8   -- 1 << 3
local ImGuiTabItemFlags_NoTooltip                    = 16  -- 1 << 4
local ImGuiTabItemFlags_NoReorder                    = 32  -- 1 << 5
local ImGuiTabItemFlags_Leading                      = 64  -- 1 << 6
local ImGuiTabItemFlags_Trailing                     = 128 -- 1 << 7

imgui.TabItemFlags = {
	None                         = ImGuiTabItemFlags_None,
	UnsavedDocument              = ImGuiTabItemFlags_UnsavedDocument,              -- Display a dot next to the title + tab is selected when clicking the X + closure is not assumed (will wait for user to stop submitting the tab). Otherwise closure is assumed when pressing the X, so if you keep submitting the tab may reappear at end of tab bar.
	SetSelected                  = ImGuiTabItemFlags_SetSelected,                  -- Trigger flag to programmatically make the tab selected when calling BeginTabItem()
	NoCloseWithMiddleMouseButton = ImGuiTabItemFlags_NoCloseWithMiddleMouseButton, -- Disable behavior of closing tabs (that are submitted with p_open != NULL) with middle mouse button. You can still repro this behavior on user's side with if (IsItemHovered() && IsMouseClicked(2)) *p_open = false.
	NoPushId                     = ImGuiTabItemFlags_NoPushId,                     -- Don't call PushID(tab->ID)/PopID() on BeginTabItem()/EndTabItem()
	NoTooltip                    = ImGuiTabItemFlags_NoTooltip,                    -- Disable tooltip for the given tab
	NoReorder                    = ImGuiTabItemFlags_NoReorder,                    -- Disable reordering this tab or having another tab cross over this tab
	Leading                      = ImGuiTabItemFlags_Leading,                      -- Enforce the tab position to the left of the tab bar (after the tab list popup button)
	Trailing                     = ImGuiTabItemFlags_Trailing,                     -- Enforce the tab position to the right of the tab bar (before the scrolling buttons)
}