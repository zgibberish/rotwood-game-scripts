local Utils = require "math.modules.utils"

local properties = {
	hue = {
		name = "Hue",
		format = "%+dº",
		max = 180
	},
	saturation = {
		name = "Saturation",
		format = "%+d%%",
		max = 100,
	},
	brightness = {
		name = "Brightness",
		format = "%+d%%",
		max = 100,
	},
}

local order = {
	"hue",
	"saturation",
	"brightness"
}

local Hsb = Class(function(self)
	for k, _ in pairs(properties) do
		self[k] = 0
	end
end)

Hsb.CLIPBOARD_CONTEXT = "++Hsb.CLIPBOARD_CONTEXT"

function Hsb.FromRawTable(raw_table)
	local hsb = Hsb()
	for k, _ in pairs(properties) do
		hsb[k] = raw_table[k] or 0
	end
	return hsb
end

function Hsb:GetLabel()
	return "h:"..self.hue.." s:"..self.saturation.." b:"..self.brightness
end

-- Return a new Hsb if we get pasted; nil otherwise.
function Hsb:Ui(ui, id)
	local open = ui:TreeNode("HSB Color Shift"..id)
	id = id.."hsb"

	ui:SameLineWithSpace()
	ui:Text(self:GetLabel())

	if not open then
		return
	end

	local pasted = ui:CopyPasteButtons(Hsb.CLIPBOARD_CONTEXT, id, self)
	if pasted then
		local pasted_hsb = Hsb.FromRawTable(pasted)
		ui:TreePop()
		return pasted_hsb
	end
	ui:SameLineWithSpace()

	local reset = ui:Button(ui.icon.undo..id)
	ui:SetTooltipIfHovered("Reset HSB Color Shift")
	if reset then
		for k, _ in pairs(properties) do
			self[k] = 0
		end
	end

	for _, k in ipairs(order) do
		local v = properties[k]
		local changed, val = ui:SliderInt(v.name..id, self[k] or 0, -v.max, v.max, v.format)
		if changed then
			self[k] = val
		end
	end

	ui:TreePop()
end

-- Make a temporary Hsb so we can use the common Ui without trying to restructure the
-- prop data.
function Hsb.RawUi(ui, id, params)
	local hsb = Hsb.FromRawTable(params)
	local current = deepcopy(hsb)
	local pasted = hsb:Ui(ui, id)
	if pasted then
		hsb = pasted
	end
	if not deepcompare(current, hsb) then
		for k, _ in pairs(properties) do
			params[k] = hsb[k]
		end
		return true
	end
	return false
end

local function Set(entity, hue, saturation, brightness)
	hue = hue or 0
	-- Note: hue-clamping happens in native code.
	entity.AnimState:SetHue(hue / (properties.hue.max * 2))

	saturation = saturation or 0
	saturation = math.clamp(saturation, -properties.saturation.max, properties.saturation.max)
	entity.AnimState:SetSaturation((saturation + properties.saturation.max) / properties.saturation.max)
	
	brightness = brightness or 0
	brightness = math.clamp(brightness, -properties.brightness.max, properties.brightness.max)
	entity.AnimState:SetBrightness((brightness + properties.brightness.max) / properties.brightness.max)
end

function Hsb:Set(entity)
	if not entity.AnimState then
		return false
	end
	Set(entity, self.hue, self.saturation, self.brightness)
	return true
end

function Hsb:Shift(entity)
	if not entity.AnimState then
		return false
	end

	-- Convert native hsb values into ranges that are amenable to arithmetic.

	-- Map a hue value from [0, 1] units of 2PI radians to [-180, 180] degrees
	local hue = entity.AnimState:GetHue()
	if hue >= 0.5 then
		hue = hue - 1.0
	end
	hue = hue * properties.hue.max

	-- Map saturation and brightness from [0, 2] to [-100, 100].
	local saturation = (entity.AnimState:GetSaturation() - 1.0) * properties.saturation.max
	local brightness = (entity.AnimState:GetBrightness() - 1.0) * properties.brightness.max	

	-- Add to effect the shifts, then assign back to native.
	Set(entity, hue + self.hue, saturation + self.saturation, brightness + self.brightness)

	return true
end

return Hsb
