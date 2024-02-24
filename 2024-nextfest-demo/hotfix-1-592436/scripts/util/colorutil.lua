local color = require "math.modules.color"
local lume = require "util.lume"
HSB = color.HSBFromInts

require "mathutil"


-- Find HSB conversions and other functions in math/modules/color.lua

local colorutil = {}

local rgb_remap =
{
	r = 1, g = 2, b = 3, a = 4,
	R = 1, G = 2, B = 3, A = 4,
}

local rgb_mt =
{
	__index = function(t, k)
		return rawget(t, rgb_remap[k] or k)
	end,
	__newindex = function(t, k, v)
		rawset(t, rgb_remap[k] or k, v)
	end,
}

---------------------------------------------------------------------------------------
function FindClosestHue(hsb, colours)
	local best_pick = nil
	local best = 1000
	local target_hue = hsb[1]

	for name, colour in pairs(colours) do
		local delta = math.abs(colour[1] - target_hue)
		if delta < best then
			best = delta
			best_pick = name
		end
	end

	if best_pick then
		return colours[best_pick]
	end
end

function FindClosestColor_HSB(base, options)
	local deltas = {}
	local h1, s1, b1 = table.unpack(base)

	for name, color in pairs(options) do
		local h2, s2, b2 = table.unpack(color)
		local delta = ((h2-h1))^2 + ((s2-s1))^2 + ((b2-b1))^2
		table.insert(deltas, { name = name, delta = delta })
	end

	deltas = lume.sort(deltas, "delta")

	local best_pick = deltas[1].name

	if best_pick then
		return options[best_pick]
	end	
end

function FindClosestColor_RGB(base, options)
	local deltas = {}
	local r1, g1, b1 = table.unpack(base)

	for name, color in pairs(options) do
		local r2, g2, b2 = table.unpack(color)
		local delta = (r2-r1)^2 + (g2-g1)^2 + (b2-b1)^2
		table.insert(deltas, { name = name, delta = delta })
	end

	deltas = lume.sort(deltas, "delta")

	local best_pick = deltas[1].name

	if best_pick then
		return options[best_pick]
	end	
end

function RGB(r, g, b, a)
	return setmetatable({ r / 255, g / 255, b / 255, (a or 255) / 255 }, rgb_mt)
end

function RGBToInts(rgb)
	return math.floor(rgb[1] * 255 + .5),
		math.floor(rgb[2] * 255 + .5),
		math.floor(rgb[3] * 255 + .5),
		math.floor(rgb[4] * 255 + .5)
end

-- To create HSB(), use math.modules.color.HSBFromInts.

function RGBToHSB( rgb )
	return color.color_to_hsb_table(rgb)
end

function HSBToRGB(hsb)
	--These are floats, not integer h, s, b
	local h, s, b = table.unpack(hsb)
	if b <= 0 then
		return setmetatable({ 0, 0, 0, 1 }, rgb_mt)
	end
	b = math.min(1, b)
	if s <= 0 then
		return setmetatable({ b, b, b, 1 }, rgb_mt)
	end
	s = math.min(1, s)
	local desat = (1 - s) * b
	h = h - math.floor(h)
	if h == 0 then
		return setmetatable({ b, desat, desat, 1 }, rgb_mt)
	end
	h = h * 2 * math.pi
	local hcos = math.cos(h)
	local hsin1 = math.sin(h) / math.sqrt(3)
	local hcos1 = (1 - hcos) / 3
	local rgb =
	{
		hcos + hcos1,
		hcos1 + hsin1,
		hcos1 - hsin1,
	}
	local max = math.max(table.unpack(rgb))
	local min = math.min(table.unpack(rgb))
	local normalize = b * s / (max - min)
	for i = 1, 3 do
		rgb[i] = desat + (rgb[i] - min) * normalize
	end
	rgb[4] = 1
	return setmetatable(rgb, rgb_mt)
end

function RGBIntsToHex(r, g, b, a)
	return (math.clamp(r, 0, 255) << 24)
		|  (math.clamp(g, 0, 255) << 16)
		|  (math.clamp(b, 0, 255) << 8)
		|   math.clamp(a or 255, 0, 255)
end

function RGBFloatsToHex(r, g, b, a)
	return RGBIntsToHex(
		math.floor(r * 255 + .5),
		math.floor(g * 255 + .5),
		math.floor(b * 255 + .5),
		a ~= nil and math.floor(a * 255 + .5) or nil)
end

function RGBToHex(rgb)
	return RGBFloatsToHex(table.unpack(rgb))
end

--- Takes color int `hex` and returns 4 values, one for each color channel
-- (`r`, `g`, `b` and `a`). Returned values are between 0 and 255.
-- ```lua
-- HexToRGBInts(0xff0000ff)                 -- Returns 255, 0, 0, 255
-- HexToRGBInts(StrToHex("00ffffff"))       -- Returns 0, 255, 255, 255
-- ```
function HexToRGBInts(hex)
	return (hex & 0xFF000000) >> 24	--r
		, (hex & 0xFF0000) >> 16	--g
		, (hex & 0xFF00) >> 8		--b
		, hex & 0xFF				--a
end

--- Takes color int `hex` and returns 4 values, one for each color channel
-- (`r`, `g`, `b` and `a`). Returned values are between 0 and 1.
-- ```lua
-- HexToRGBFloats(0xff0000ff)                 -- Returns 1, 0, 0, 1
-- HexToRGBFloats(StrToHex("00ffffff"))       -- Returns 0, 1, 1, 1
-- ```
function HexToRGBFloats(hex)
	local r, g, b, a = HexToRGBInts(hex)
	return r / 255, g / 255, b / 255, a / 255
end

function HexToRGB(hex)
	return RGB(HexToRGBInts(hex))
end

function HexToRGBA(hex)
	local res = RGB(HexToRGBInts(hex))
	return RGB(HexToRGBInts(hex))
end

function HexToStr(hex)
	return string.format("%08X", hex)
end

function StrToHex(str)
	return tonumber("0x"..str)
end

-- Lerp a gradient from backgroundgradient.lua
function colorutil.GradientLerp(first, last, t)
	assert(t)
	local curve = deepcopy(first)
	for i,end_color in ipairs(last) do
		local start_color = curve[i]
		-- lerp r,g,b. the final component is time.
		for c=1,3 do
			start_color[c] = lume.lerp(start_color[c], end_color[c], t)
		end
	end
	return curve
end

return colorutil
