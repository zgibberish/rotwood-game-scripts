local ValueStacker = require "components.valuestacker"
local color = require "math.modules.color"
require "util.colorutil"

local HSB = color.HSBFromInts


local function ApplyHsbToInst(inst, hsb)
	if inst.AnimState ~= nil then
		inst.AnimState:SetHue(hsb.h)
		inst.AnimState:SetSaturation(hsb.s)
		inst.AnimState:SetBrightness(hsb.b)
	end
end
local nil_hsb = HSB(0, 100, 100)


local ColorShifter = Class(ValueStacker, function(self, inst)
	ValueStacker._ctor(self, inst)

	self._scratch_hsb = HSB(1, 1, 1)
end)

function ColorShifter:PushColor(source, hsb)
	if hsb.h == 0 and hsb.s == 1 and hsb.b == 1 then
		self:_PopStack(source)
		return
	end
	self:_PushStack(source, hsb)
end

function ColorShifter:_Pack(hsb)
	-- We expect an hsb table to PushColor.
	return hsb
end

function ColorShifter:_CopyArgs(t, hsb)
	local changed = false
	for k,v in pairs(hsb) do
		changed = changed or t[k] ~= v
		t[k] = v
	end
	return changed
end

function ColorShifter:PopColor(source)
	self:_PopStack(source)
end

function ColorShifter:_ApplyDefaultState(inst)
	ApplyHsbToInst(inst, nil_hsb)
end

function ColorShifter:_GetSelfComponent(inst)
	return inst.components.colorshifter
end

function ColorShifter:_ApplyStack()
	local hsb = self:CalculateColorInternal()
	self:ApplyColorInternal(hsb)
end

local function MergeHsb(w, v)
	-- Add hue to shift further in each direction (it loops).
	w.h = w.h + v.h
	w.s = w.s * v.s
	w.b = w.b * v.b
	return w
end

function ColorShifter:CalculateColorInternal()
	local work = self._scratch_hsb
	work.h, work.s, work.b = 0, 1, 1

	-- TODO(dbriscoe): Does this valuestack make sense for hsb?
	for _, v in pairs(self.valuestack) do
		MergeHsb(work, v)
	end

	for k in pairs(self.children) do
		if k.components.colorshifter ~= nil then
			local child_hsb = k.components.colorshifter:CalculateColorInternal()
			MergeHsb(work, child_hsb)
		end
	end

	return work
end

function ColorShifter:ApplyColorInternal(hsb)
	ApplyHsbToInst(self.inst, hsb)

	for k in pairs(self.children) do
		if k.components.colorshifter ~= nil then
			k.components.colorshifter:ApplyColorInternal(hsb)
		else
			ApplyHsbToInst(k, hsb)
		end
	end
end

local shared_data = {}
function ColorShifter:PushVarianceShift(source, options)
	-- Each prefab has its own index in its options.
	local index = shared_data[self.inst.prefab] or 0
	index = index + 1
	shared_data[self.inst.prefab] = index

	local hsb = circular_index(options, index)
	self:PushColor(source, hsb)
end


local debug_hsb = color(WEBCOLORS.RED):color_to_hsb_table()
function ColorShifter:DebugDrawEntity(ui, panel, colors)
	local flags = (ui.ColorEditFlags.InputHSV | ui.ColorEditFlags.DisplayHSV)
	local hsb = self:CalculateColorInternal()
	ui:ColorEdit3("Current Applied Color", hsb.h, hsb.s, hsb.b, flags)

	ui:TextColored(colors.header, "Push color onto stack")
	hsb = debug_hsb
	hsb[1], hsb[2], hsb[3] = ui:_ColorEdit3("Color", hsb.h, hsb.s, hsb.b, flags)
	if ui:Button("Push Shift Color") then
		self:PushColor("DebugDrawEntity", hsb)
	end
	ui:SameLineWithSpace()
	if ui:Button("Remove Color") then
		self:PopColor("DebugDrawEntity")
	end
end

return ColorShifter
