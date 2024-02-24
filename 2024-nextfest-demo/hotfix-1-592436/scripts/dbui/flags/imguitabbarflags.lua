-- Generated by tools/imgui_upgrader/build_enums.lua

local ImGuiTabBarFlags_None                         = 0
local ImGuiTabBarFlags_Reorderable                  = 1   -- 1 << 0
local ImGuiTabBarFlags_AutoSelectNewTabs            = 2   -- 1 << 1
local ImGuiTabBarFlags_TabListPopupButton           = 4   -- 1 << 2
local ImGuiTabBarFlags_NoCloseWithMiddleMouseButton = 8   -- 1 << 3
local ImGuiTabBarFlags_NoTabListScrollingButtons    = 16  -- 1 << 4
local ImGuiTabBarFlags_NoTooltip                    = 32  -- 1 << 5
local ImGuiTabBarFlags_FittingPolicyResizeDown      = 64  -- 1 << 6
local ImGuiTabBarFlags_FittingPolicyScroll          = 128 -- 1 << 7

imgui.TabBarFlags = {
	None                         = ImGuiTabBarFlags_None,
	Reorderable                  = ImGuiTabBarFlags_Reorderable,                  -- Allow manually dragging tabs to re-order them + New tabs are appended at the end of list
	AutoSelectNewTabs            = ImGuiTabBarFlags_AutoSelectNewTabs,            -- Automatically select new tabs when they appear
	TabListPopupButton           = ImGuiTabBarFlags_TabListPopupButton,           -- Disable buttons to open the tab list popup
	NoCloseWithMiddleMouseButton = ImGuiTabBarFlags_NoCloseWithMiddleMouseButton, -- Disable behavior of closing tabs (that are submitted with p_open != NULL) with middle mouse button. You can still repro this behavior on user's side with if (IsItemHovered() && IsMouseClicked(2)) *p_open = false.
	NoTabListScrollingButtons    = ImGuiTabBarFlags_NoTabListScrollingButtons,    -- Disable scrolling buttons (apply when fitting policy is ImGuiTabBarFlags_FittingPolicyScroll)
	NoTooltip                    = ImGuiTabBarFlags_NoTooltip,                    -- Disable tooltips when hovering a tab
	FittingPolicyResizeDown      = ImGuiTabBarFlags_FittingPolicyResizeDown,      -- Resize tabs when they don't fit
	FittingPolicyScroll          = ImGuiTabBarFlags_FittingPolicyScroll,          -- Add scroll buttons when tabs don't fit
}
