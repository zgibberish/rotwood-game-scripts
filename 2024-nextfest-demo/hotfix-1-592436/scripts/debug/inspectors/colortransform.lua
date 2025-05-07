local Cosmetic = require "defs.cosmetics.cosmetics"
local DebugNodes = require "dbui.debug_nodes"
local DebugPickers = require "dbui.debug_pickers"
local color = require "math.modules.color"
local lume = require "util.lume"
require "consolecommands"
require "constants"
require "util.colorutil"

local HSB = color.HSBFromInts


local BASECOLOR = {
	PLAYER = HSB(180, 37, 64),
	-- I think this actually depends on each build's individual settings. Not sure
	-- how to discover that.
	NONE = HSB(0, 100, 100),
}

local ColorTransform = Class(DebugNodes.DebugNode, function(self, inst)
	DebugNodes.DebugNode._ctor(self, "Color Inspector")

	self.inst = inst
    self.autoselect = inst == nil
    self.component_filter = ""
end)

ColorTransform.PANEL_WIDTH = 600
ColorTransform.PANEL_HEIGHT = 600

function ColorTransform:StoreHsb(h, s, b)
	self.H = math.floor(h * 360 + .5)
	self.S = math.floor(s * 100 + .5)
	self.B = math.floor(b * 100 + .5)
end

function ColorTransform:RenderPanel( ui, panel )
	local ent = c_sel()
	ui:Text("Selection (F1):");ui:SameLine();ui:TextColored(BGCOLORS.YELLOW, tostring(ent))
	ui:Dummy(0,10)

	if ent == nil then
		return
	end

	if not ent.AnimState then
		ui:Text("Selection can't colortransform")
		return
	end

	if not self.basecolor then
		if ent.components.charactercreator then
			self.basecolor = "PLAYER"
		else
			self.basecolor = "NONE"
		end
		local basecolor = BASECOLOR[self.basecolor]
		self:StoreHsb(basecolor.h, basecolor.s, basecolor.b)
	end


	ui:Text("Base color:")
	ui:SameLineWithSpace()
	local keys = lume.sort(lume.keys(BASECOLOR))
	local idx = lume.find(keys, self.basecolor) or 1
	for i,k in ipairs(keys) do
		if ui:RadioButton(k, idx, i) then
			self.basecolor = k
		end
		ui:SameLineWithSpace()
	end
	ui:Dummy(0,0)
	local basecolor = BASECOLOR[self.basecolor]

	local changed = {}
	changed.h, self.H = ui:SliderInt("Hue", self.H, 0, 360)
	changed.s, self.S = ui:SliderInt("Saturation", self.S, 0, 400)
	changed.b, self.B = ui:SliderInt("Brightness", self.B, 0, 200)
	ui:Dummy(0,10)

	ui:Spacing()
	-- This picker looks a bit confusing, but we allow super saturated colors
	-- so we need hdr (unclamped) hsv floats.
	local edit_mode = ui.ColorEditFlags.PickerHueWheel
			| ui.ColorEditFlags.DisplayHSV
			| ui.ColorEditFlags.InputHSV
			| ui.ColorEditFlags.Float
			| ui.ColorEditFlags.HDR
	local h, s, b
	changed.c, h, s, b = ui:ColorEdit3("Color Picker", self.H / 360, self.S / 100, self.B / 100, edit_mode)
	if changed.c then
		self:StoreHsb(h, s, b)
	end

	ui:Spacing()
	ui:Dummy(10,0) ui:SameLine() ui:Text(string.format("HSB(%i, %i, %i)", self.H, self.S, self.B))
	ui:Dummy(0,10)

	if lume.any(changed) then
		local hsb = HSB(self.H, self.S, self.B)
		hsb[1] = hsb[1] - basecolor[1]
		hsb[2] = hsb[2] / basecolor[2]
		hsb[3] = hsb[3] / basecolor[3]

		if ent == GetDebugPlayer() then
			ent.components.charactercreator:SetSymbolColorShift(Cosmetic.ColorGroups.SKIN_TONE, table.unpack(hsb))
		else
			ent.AnimState:SetHue(hsb[1])
			ent.AnimState:SetSaturation(hsb[2])
			ent.AnimState:SetBrightness(hsb[3])
		end
	end
	ui:Dummy(10,0) ui:SameLine()
    if ui:Button("Copy to clipboard") then
		ui:SetClipboardText(string.format("HSB(%i, %i, %i)\n", self.H, self.S, self.B))
	end

	ui:Spacing()
	ui:Separator()
	ui:Spacing()
	ui:Text("Raw Colors")
	ColorTransform.DrawColorPickers(ui, ent)
end

function ColorTransform.DrawColorPickers(ui, ent)
	assert(ent.AnimState)
	local c = DebugPickers.Colour(ui, "MultColor", { ent.AnimState:GetMultColor() })
	if c then
		ent.AnimState:SetMultColor(table.unpack(c))
	end
	c = DebugPickers.Colour(ui, "AddColor", { ent.AnimState:GetAddColor() })
	if c then
		ent.AnimState:SetAddColor(table.unpack(c))
	end
	local rgb = color.from_hsb(
		ent.AnimState:GetHue(),
		ent.AnimState:GetSaturation(),
		ent.AnimState:GetBrightness())
	local changed, r,g,b,a = ui:ColorEdit4("ShiftColor",
		rgb[1], rgb[2], rgb[3], rgb[4],
		ui.ColorEditFlags.DisplayHSV | ui.ColorEditFlags.PickerHueWheel)
	if changed then
		rgb = color(r,g,b,a)
		local hsb = rgb:color_to_hsb_table()
		if ent == GetDebugPlayer() then
			ent.components.charactercreator:SetSymbolColorShift(Cosmetic.ColorGroups.SKIN_TONE, table.unpack(hsb))
		else
			ent.AnimState:SetHue(hsb[1])
			ent.AnimState:SetSaturation(hsb[2])
			ent.AnimState:SetBrightness(hsb[3])
		end
	end
end

DebugNodes.ColorTransform = ColorTransform

return ColorTransform
