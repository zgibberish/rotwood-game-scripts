-- Generated by tools/imgui_upgrader/build_enums.lua

local ImGuiSliderFlags_None            = 0
local ImGuiSliderFlags_AlwaysClamp     = 16  -- 1 << 4
local ImGuiSliderFlags_Logarithmic     = 32  -- 1 << 5
local ImGuiSliderFlags_NoRoundToFormat = 64  -- 1 << 6
local ImGuiSliderFlags_NoInput         = 128 -- 1 << 7

imgui.SliderFlags = {
	None            = ImGuiSliderFlags_None,
	AlwaysClamp     = ImGuiSliderFlags_AlwaysClamp,     -- Clamp value to min/max bounds when input manually with CTRL+Click. By default CTRL+Click allows going out of bounds.
	Logarithmic     = ImGuiSliderFlags_Logarithmic,     -- Make the widget logarithmic (linear otherwise). Consider using ImGuiSliderFlags_NoRoundToFormat with this if using a format-string with small amount of digits.
	NoRoundToFormat = ImGuiSliderFlags_NoRoundToFormat, -- Disable rounding underlying value to match precision of the display format string (e.g. %.3f values are rounded to those 3 digits)
	NoInput         = ImGuiSliderFlags_NoInput,         -- Disable CTRL+Click or Enter key allowing to input text directly into the widget
}