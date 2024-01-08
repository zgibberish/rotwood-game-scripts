-- Generated by tools/imgui_upgrader/build_enums.lua

local ImGuiMouseCursor_None       = -1
local ImGuiMouseCursor_Arrow      = 0
local ImGuiMouseCursor_TextInput  = 1
local ImGuiMouseCursor_ResizeAll  = 2
local ImGuiMouseCursor_ResizeNS   = 3
local ImGuiMouseCursor_ResizeEW   = 4
local ImGuiMouseCursor_ResizeNESW = 5
local ImGuiMouseCursor_ResizeNWSE = 6
local ImGuiMouseCursor_Hand       = 7
local ImGuiMouseCursor_NotAllowed = 8
local ImGuiMouseCursor_COUNT      = 9

imgui.MouseCursor = {
	None       = ImGuiMouseCursor_None,
	Arrow      = ImGuiMouseCursor_Arrow,
	TextInput  = ImGuiMouseCursor_TextInput,  -- When hovering over InputText, etc.
	ResizeAll  = ImGuiMouseCursor_ResizeAll,  -- (Unused by Dear ImGui functions)
	ResizeNS   = ImGuiMouseCursor_ResizeNS,   -- When hovering over a horizontal border
	ResizeEW   = ImGuiMouseCursor_ResizeEW,   -- When hovering over a vertical border or a column
	ResizeNESW = ImGuiMouseCursor_ResizeNESW, -- When hovering over the bottom-left corner of a window
	ResizeNWSE = ImGuiMouseCursor_ResizeNWSE, -- When hovering over the bottom-right corner of a window
	Hand       = ImGuiMouseCursor_Hand,       -- (Unused by Dear ImGui functions. Use for e.g. hyperlinks)
	NotAllowed = ImGuiMouseCursor_NotAllowed, -- When hovering something with disallowed interaction. Usually a crossed circle.
	COUNT      = ImGuiMouseCursor_COUNT,
}
