-- Generated by tools/imgui_upgrader/build_enums.lua

local ImGuiTableRowFlags_None    = 0
local ImGuiTableRowFlags_Headers = 1 -- 1 << 0

imgui.TableRowFlags = {
	None    = ImGuiTableRowFlags_None,
	Headers = ImGuiTableRowFlags_Headers, -- Identify header row (set default background color + width of its contents accounted differently for auto column width)
}