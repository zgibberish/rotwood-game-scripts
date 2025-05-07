local Cosmetic = require("defs.cosmetics.cosmetic")
local kassert = require "util.kassert"

Cosmetic.ColorGroups = {}
Cosmetic.ColorGroupBaseHSBs = {}
Cosmetic.SymbolColorOverrides = {}
Cosmetic.Colors = {}

local function OverrideSymbolColorGroup(symbol, colorgroup)
	Cosmetic.SymbolColorOverrides[symbol] = colorgroup
end

function AddColorGroup(colorgroup, basehsb)
	assert(basehsb.s > 0, "Didn't expect build files to have 0 saturation.")
	assert(basehsb.b > 0, "Didn't expect build files to have 0 brightness.")
	assert(Cosmetic.ColorGroups[colorgroup] == nil)
	Cosmetic.ColorGroups[colorgroup] = colorgroup
	Cosmetic.ColorGroupBaseHSBs[colorgroup] = basehsb
	Cosmetic.Colors[colorgroup] = {}
end

function Cosmetic.GetColorList(colorgroup, tags)
	kassert.typeof('string', colorgroup)
	assert(not tags or tags[1] == nil, "Expected tags to be a *dict*.")
	if tags and not next(tags) then
		tags = nil
	end
	local ret = {}
	local colors = Cosmetic.Colors[colorgroup]
	assert(colors, colorgroup)
	if colors ~= nil then
		for hex, def in pairs(colors) do

			if Cosmetic.MatchesTags(def.filtertags, tags) then
				ret[#ret + 1] = def
			end
		end
	end

	table.sort(ret, Cosmetic.SortByItemName)
	return ret
end

function Cosmetic.GetSpeciesColors(colorgroup, species)
	local selected_colors = {}
	local colors = Cosmetic.Colors[colorgroup]

	for name, def in pairs(colors) do
		if def.filtertags and def.filtertags[species] then
			table.insert(selected_colors, def)
		end
	end

	return selected_colors
end

function Cosmetic.AddColor(name, data)
    local cosmetic_data = data.cosmetic_data

    --local colors = _colors[colorgroup]
    local hsb = cosmetic_data.color -- HSB(cosmetic_data.color[1], cosmetic_data.color[2], cosmetic_data.color[3])
	local rgb = HSBToRGB(hsb)
	local hex = RGBToHex(rgb)
	local basehsb = Cosmetic.ColorGroupBaseHSBs[cosmetic_data.colorgroup]
	
    local hsbshift =
	{
		hsb[1] - basehsb[1],
		hsb[2] / basehsb[2],
		hsb[3] / basehsb[3],
	}
	hsbshift[1] = hsbshift[1] - math.floor(hsbshift[1])

    local def = Cosmetic.AddCosmetic(name, data)
	
    def.hex = hex
    def.rgb = rgb
    def.hsb = hsbshift
	def.base_hsb = hsb

	def.colorgroup = cosmetic_data.colorgroup

    local filtertags = {}

	if cosmetic_data.color_species ~= nil and cosmetic_data.color_species ~= "" then
		table.insert(filtertags, cosmetic_data.color_species)
	end

	if cosmetic_data.is_default_color then
        table.insert(filtertags, "default")
    end
	
	if #filtertags == 0 then
		filtertags = nil
	end

	def.filtertags = Cosmetic.AddTagsToDict(def.filtertags, filtertags)

	Cosmetic.Colors[def.colorgroup][name] = def
end

--Base HSB is the color used in the actual build files. (S&B cannot be 0)
AddColorGroup("SKIN_TONE", HSB(180, 40, 65))
AddColorGroup("HAIR_COLOR", HSB(10, 60, 90))
AddColorGroup("EYE_COLOR", HSB(180, 50, 100))
AddColorGroup("NOSE_COLOR", HSB(300, 35, 90))
AddColorGroup("EAR_COLOR", HSB(300, 35, 90))
AddColorGroup("MOUTH_COLOR", HSB(350, 50, 100))
AddColorGroup("ORNAMENT_COLOR", HSB(40, 60, 90))
AddColorGroup("SHIRT_COLOR", HSB(30, 20, 80))
AddColorGroup("UNDIES_COLOR", HSB(30, 20, 80))
AddColorGroup("SMEAR_SKIN_COLOR", HSB(180, 40, 65))
AddColorGroup("SMEAR_WEAPON_COLOR", HSB(180, 50, 100))
AddColorGroup("EARRING", HSB(180, 40, 65))

--Override symbols to a different color group than the rest of that body part.
OverrideSymbolColorGroup("base_arm_markings", Cosmetic.ColorGroups.ORNAMENT_COLOR)

OverrideSymbolColorGroup("ear_lft01", Cosmetic.ColorGroups.SKIN_TONE)
OverrideSymbolColorGroup("ear_rgt01", Cosmetic.ColorGroups.SKIN_TONE)
OverrideSymbolColorGroup("ear_k9_lft01", Cosmetic.ColorGroups.SKIN_TONE)
OverrideSymbolColorGroup("ear_k9_rgt01", Cosmetic.ColorGroups.SKIN_TONE)

OverrideSymbolColorGroup("earring_rgt01", 	   Cosmetic.ColorGroups.EARRING)
OverrideSymbolColorGroup("earring_lft01", 	   Cosmetic.ColorGroups.EARRING)
OverrideSymbolColorGroup("mouth01", Cosmetic.ColorGroups.SKIN_TONE)
OverrideSymbolColorGroup("mouth_inner01", Cosmetic.ColorGroups.MOUTH_COLOR)

return Cosmetic