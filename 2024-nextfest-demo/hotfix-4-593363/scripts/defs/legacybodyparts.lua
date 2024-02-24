local color = require "math.modules.color"
local kassert = require "util.kassert"
require "util.colorutil"

-- local HSB = color.HSBFromInts

local _parts = {}
local _symbols = {}
local _symbolremaps = {}
local _symbolfilters = {}
local _items = {}

local function AddPart(bodypart, symbols)
	assert(_parts[bodypart] == nil)
	_parts[bodypart] = bodypart
	_symbols[bodypart] = symbols
	_items[bodypart] = {}
end

local function RemapSymbol(symbol, newsymbol)
	_symbolremaps[symbol] = newsymbol
end

local function AddSymbolFilter(symbol, tag)
	_symbolfilters[symbol] = tag
end

--------------------------------------------------------------------------

local _colorgroups = {}
local _colorgroupbasehsbs = {}
local _symbolcoloroverrides = {}
local _colors = {}
local _colorid = 1

local function MakeTagsDict(taglist)
	if taglist ~= nil and #taglist > 0 then
		local tags = {}
		for i = 1, #taglist do
			tags[taglist[i]] = true
		end
		return tags
	end
end

-- True if no input tags, item has no tags, or item has all required tags.
local function MatchesTags(item_tags, required_tags)
	if item_tags and required_tags then
		for tag in pairs(required_tags) do
			if not item_tags[tag] then
				return false
			end
		end
	end
	-- If the item doesn't define tags, then it matches all tags.
	return true
end

local function AddColorGroup(colorgroup, basehsb)
	assert(basehsb.s > 0, "Didn't expect build files to have 0 saturation.")
	assert(basehsb.b > 0, "Didn't expect build files to have 0 brightness.")
	assert(_colorgroups[colorgroup] == nil)
	_colorgroups[colorgroup] = colorgroup
	_colorgroupbasehsbs[colorgroup] = basehsb
	_colors[colorgroup] = {}
end

local function AddColor(colorgroup, hsb, filtertags, colorname)
	local colors = _colors[colorgroup]
	local rgb = HSBToRGB(hsb)
	local hex = RGBToHex(rgb)
	local basehsb = _colorgroupbasehsbs[colorgroup]
	local hsbshift =
	{
		hsb[1] - basehsb[1],
		hsb[2] / basehsb[2],
		hsb[3] / basehsb[3],
	}
	hsbshift[1] = hsbshift[1] - math.floor(hsbshift[1])

	local def =
	{
		hex = hex,
		rgb = rgb,
		hsb = hsbshift,
		base_hsb = hsb,
		id = _colorid, --for sorting
		colorname = colorname,
		colorgroup = colorgroup,
	}

	def.filtertags = MakeTagsDict(filtertags)

	colors[_colorid] = def
	_colorid = _colorid + 1
end

local function OverrideSymbolColorGroup(symbol, colorgroup)
	_symbolcoloroverrides[symbol] = colorgroup
end

--------------------------------------------------------------------------

-- Passing nil for filtertags or symboltags will match as if we supported every tag.
-- TODO(dbriscoe): POSTVS Pass tags as named keys in a tags table to avoid errors.
local function AddItem(bodypart, name, build, colorgroup, filtertags, symboltags, uitags)
	local items = _items[bodypart]
	assert(items ~= nil and items[name] == nil)
	assert(build or not colorgroup, "What's the point of a colorgroup without a build?")

	local def =
	{
		name = name,
		build = build,
		colorgroup = colorgroup,
		bodypart = bodypart,
	}

	def.filtertags = MakeTagsDict(filtertags)
	def.symboltags = MakeTagsDict(symboltags)
	def.uitags = MakeTagsDict(uitags) or {} -- always have ui tags

	items[name] = def
end

local function CollectAssets(assets)
	local dupe = {}
	for bodypart, items in pairs(_items) do
		for name, def in pairs(items) do
			if def.build ~= nil and not dupe[def.build] then
				dupe[def.build] = true
				assets[#assets + 1] = Asset("ANIM", "anim/"..def.build..".zip")
			end
		end
	end
end

--------------------------------------------------------------------------

local function SortByColorId(a, b)
	return a.id < b.id
end

local function GetColorList(colorgroup, tags)
	kassert.typeof('string', colorgroup)
	assert(not tags or tags[1] == nil, "Expected tags to be a *dict*.")
	if tags and not next(tags) then
		tags = nil
	end
	local ret = {}
	local colors = _colors[colorgroup]
	assert(colors, colorgroup)
	if colors ~= nil then
		for hex, def in pairs(colors) do
			if MatchesTags(def.filtertags, tags) then
				ret[#ret + 1] = def
			end
		end
	end
	table.sort(ret, SortByColorId)
	return ret
end

local function SortByItemName(a, b)
	return a.name < b.name
end

local function GetItemList(bodypart, tags)
	if tags and not next(tags) then
		tags = nil
	end
	local ret = {}
	local items = _items[bodypart]
	if items ~= nil then
		for name, def in pairs(items) do
			if MatchesTags(def.filtertags, tags) then
				ret[#ret + 1] = def
			end
		end
	end
	table.sort(ret, SortByItemName)
	return ret
end

--------------------------------------------------------------------------

-- Symbols can only be assigned to a single part.
AddPart("HEAD", { "head01" })
AddPart("HAIR", { "hair01", "hair_front01", "hair_back01", "hair_tail01" })
AddPart("BROW", { "brow_lft01", "brow_rgt01" })
AddPart("EYES", { "eye_lft", "eye_rgt", "pupil01" })
AddPart("MOUTH", { "mouth01", "mouth_inner01" })
AddPart("NOSE", { "nose01", "snout_nose01_long", "snout_nose01_flat" })
AddPart("EARS", { "ear_lft01", "ear_lft01_inner", "ear_rgt01", "ear_rgt01_inner", "ear_k9_lft01", "ear_k9_lft01_inner", "ear_k9_rgt01", "ear_k9_rgt01_inner" })
AddPart("ORNAMENT", { "ornament01", "horn_lft01", "horn_rgt01", "head01_markings" })
AddPart("TORSO", { "base_torso" })
AddPart("SHIRT", { "undershirt01" })
AddPart("UNDIES", { "base_pelvis" })
AddPart("ARMS", { "base_shoulder", "base_arm_parts", "base_hand", "base_arm_markings" })
AddPart("LEGS", { "base_leg_parts", "base_foot" })
AddPart("OTHER", { "tail01" }) -- species specific stuff here (tail for example)
AddPart("SMEAR", { "smear_generic01" })
AddPart("SMEAR_WEAPON", { "smear_weapon_generic01" })

--Remap symbols that have different names in build files.
RemapSymbol("snout_nose01_long", "snout_nose01")
RemapSymbol("snout_nose01_flat", "snout_nose01")

--Show these symbols only when their symbol tag exists.
AddSymbolFilter("snout_nose01_long", "longsnout")
AddSymbolFilter("snout_nose01_flat", "flatsnout")

--------------------------------------------------------------------------

--Base HSB is the color used in the actual build files. (S&B cannot be 0)
AddColorGroup("SKIN_TONE", HSB(180, 40, 65))
AddColorGroup("HAIR_COLOR", HSB(10, 60, 90))
AddColorGroup("EYE_COLOR", HSB(180, 50, 100))
AddColorGroup("NOSE_COLOR", HSB(300, 35, 90))
AddColorGroup("MOUTH_COLOR", HSB(350, 50, 100))
AddColorGroup("ORNAMENT_COLOR", HSB(40, 60, 90))
AddColorGroup("SHIRT_COLOR", HSB(30, 20, 80))
AddColorGroup("UNDIES_COLOR", HSB(30, 20, 80))
AddColorGroup("SMEAR_SKIN_COLOR", HSB(180, 40, 65))
AddColorGroup("SMEAR_WEAPON_COLOR", HSB(180, 50, 100))

--Override symbols to a different color group than the rest of that body part.
OverrideSymbolColorGroup("base_arm_markings", _colorgroups.ORNAMENT_COLOR)
OverrideSymbolColorGroup("ear_lft01_inner", _colorgroups.NOSE_COLOR)
OverrideSymbolColorGroup("ear_rgt01_inner", _colorgroups.NOSE_COLOR)
OverrideSymbolColorGroup("ear_k9_lft01_inner", _colorgroups.NOSE_COLOR)
OverrideSymbolColorGroup("ear_k9_rgt01_inner", _colorgroups.NOSE_COLOR)
OverrideSymbolColorGroup("mouth01", _colorgroups.SKIN_TONE)
OverrideSymbolColorGroup("mouth_inner01", _colorgroups.MOUTH_COLOR)

--------------------------------------------------------------------------

--- OGRE SKIN COLOURS
AddColor(_colorgroups.SKIN_TONE, HSB(335, 57, 33), { "ogre" }, "maroon")
AddColor(_colorgroups.SKIN_TONE, HSB(0, 100, 39), { "ogre" }, "brick")
AddColor(_colorgroups.SKIN_TONE, HSB(14, 55, 77), { "ogre", "default_unlocked" }, "orange")
AddColor(_colorgroups.SKIN_TONE, HSB(96, 37, 86), { "ogre", "default_unlocked" }, "apple")
AddColor(_colorgroups.SKIN_TONE, HSB(136, 38, 46), { "ogre", "default_unlocked" }, "forest")
AddColor(_colorgroups.SKIN_TONE, HSB(138, 43, 66), { "ogre" }, "green")
AddColor(_colorgroups.SKIN_TONE, HSB(129, 19, 95), { "ogre" }, "mint")
AddColor(_colorgroups.SKIN_TONE, HSB(180, 25, 100), { "ogre" }, "lightblue")
AddColor(_colorgroups.SKIN_TONE, HSB(180, 40, 65), { "ogre", "default", "default_unlocked" }, "teal") -- DEFAULT
AddColor(_colorgroups.SKIN_TONE, HSB(212, 50, 55), { "ogre" }, "blue")
AddColor(_colorgroups.SKIN_TONE, HSB(230, 54, 40), { "ogre" }, "midnight")
AddColor(_colorgroups.SKIN_TONE, HSB(252, 40, 54), { "ogre" }, "purple")
AddColor(_colorgroups.SKIN_TONE, HSB(272, 33, 75), { "ogre", "default_unlocked" }, "lavender")
AddColor(_colorgroups.SKIN_TONE, HSB(315, 30, 100), { "ogre", "default_unlocked" }, "pink")
AddColor(_colorgroups.SKIN_TONE, HSB(334, 49, 70), { "ogre" }, "rose")
AddColor(_colorgroups.SKIN_TONE, HSB(63, 5, 110), { "ogre" }, "bone")
AddColor(_colorgroups.SKIN_TONE, HSB(345, 4, 73), { "ogre", "default_unlocked" }, "grey")
AddColor(_colorgroups.SKIN_TONE, HSB(264, 3, 45), { "ogre" }, "darkgrey")

--- CANINE SKIN COLOURS
AddColor(_colorgroups.SKIN_TONE, HSB(33, 58, 81), { "canine", "default", "default_unlocked" }, "masu1") -- (DEFAULT)
AddColor(_colorgroups.SKIN_TONE, HSB(4, 110, 39), { "canine", "default_unlocked" }, "darkred")
AddColor(_colorgroups.SKIN_TONE, HSB(9, 108, 50), { "canine", "default_unlocked" }, "scarlet")
AddColor(_colorgroups.SKIN_TONE, HSB(15, 95, 64), { "canine" }, "orange")
AddColor(_colorgroups.SKIN_TONE, HSB(20, 80, 98), { "canine" }, "tangerine")
AddColor(_colorgroups.SKIN_TONE, HSB(32, 58, 100), { "canine" }, "masu2")
AddColor(_colorgroups.SKIN_TONE, HSB(47, 37, 110), { "canine" }, "flax")
AddColor(_colorgroups.SKIN_TONE, HSB(56, 21, 110), { "canine" }, "ivory")
AddColor(_colorgroups.SKIN_TONE, HSB(26, 60, 60), { "canine" }, "tan")
AddColor(_colorgroups.SKIN_TONE, HSB(21, 70, 47), { "canine", "default_unlocked" }, "brown")
AddColor(_colorgroups.SKIN_TONE, HSB(355, 49, 48), { "canine" }, "mauve")
AddColor(_colorgroups.SKIN_TONE, HSB(355, 35, 60), { "canine" }, "terrarosa")
AddColor(_colorgroups.SKIN_TONE, HSB(160, 13, 110), { "canine", "default_unlocked" }, "arctic")
AddColor(_colorgroups.SKIN_TONE, HSB(162, 18, 80), { "canine" }, "powder")
AddColor(_colorgroups.SKIN_TONE, HSB(195, 41, 50), { "canine", "default_unlocked" }, "marine")
AddColor(_colorgroups.SKIN_TONE, HSB(240, 20, 32), { "canine" }, "midnight")
AddColor(_colorgroups.SKIN_TONE, HSB(226, 12, 57), { "canine" }, "grey")
AddColor(_colorgroups.SKIN_TONE, HSB(225, 10, 100), { "canine", "default_unlocked" }, "periwinkle")

--- MER SKIN COLOURS
AddColor(_colorgroups.SKIN_TONE, HSB(142, 33, 69), { "mer", "default", "default_unlocked" }, "fern") -- DEFAULT
AddColor(_colorgroups.SKIN_TONE, HSB(353, 80, 54), { "mer" }, "red")
AddColor(_colorgroups.SKIN_TONE, HSB(20, 67, 78), { "mer" }, "orange")
AddColor(_colorgroups.SKIN_TONE, HSB(33, 65, 85), { "mer", "default_unlocked" }, "gold")
AddColor(_colorgroups.SKIN_TONE, HSB(75, 34, 84), { "mer", "default_unlocked"}, "frog")
AddColor(_colorgroups.SKIN_TONE, HSB(91, 38, 60), { "mer", "default_unlocked" }, "sage")
AddColor(_colorgroups.SKIN_TONE, HSB(85, 40, 43), { "mer" }, "olive")
AddColor(_colorgroups.SKIN_TONE, HSB(162, 66, 39), { "mer" }, "forest")
AddColor(_colorgroups.SKIN_TONE, HSB(181, 60, 55), { "mer" }, "teal")
AddColor(_colorgroups.SKIN_TONE, HSB(169, 48, 72), { "mer" }, "turquoise")
AddColor(_colorgroups.SKIN_TONE, HSB(161, 31, 86), { "mer", "default_unlocked" }, "mint")
AddColor(_colorgroups.SKIN_TONE, HSB(186, 21, 90), { "mer" }, "lightblue")
AddColor(_colorgroups.SKIN_TONE, HSB(199, 45, 70), { "mer", "default_unlocked" }, "cornflower")
AddColor(_colorgroups.SKIN_TONE, HSB(229, 75, 50), { "mer" }, "deepblue ")
AddColor(_colorgroups.SKIN_TONE, HSB(244, 65, 35), { "mer", "default_unlocked" }, "indigo")
AddColor(_colorgroups.SKIN_TONE, HSB(283, 50, 73), { "mer", "default_unlocked" }, "lilac")
AddColor(_colorgroups.SKIN_TONE, HSB(306, 45, 82), { "mer", "default_unlocked" }, "bubblegum")
AddColor(_colorgroups.SKIN_TONE, HSB(0, 6, 27), { "mer" }, "black")

--- OGRE HAIR COLOURS
AddColor(_colorgroups.HAIR_COLOR, HSB(332, 62, 20), { "ogre" }, "blackcherry")
AddColor(_colorgroups.HAIR_COLOR, HSB(344, 80, 42), { "ogre", "default_unlocked" }, "burgundy")
AddColor(_colorgroups.HAIR_COLOR, HSB(355, 79, 64), { "ogre" }, "scarlet")
AddColor(_colorgroups.HAIR_COLOR, HSB(11, 65, 95), { "ogre" }, "ginger")
AddColor(_colorgroups.HAIR_COLOR, HSB(32, 52, 98), { "ogre", "default_unlocked" }, "strawberryblonde")
AddColor(_colorgroups.HAIR_COLOR, HSB(45, 35, 125), { "ogre", "default_unlocked" }, "flax")
AddColor(_colorgroups.HAIR_COLOR, HSB(45, 15, 150), { "ogre" }, "platinum")
AddColor(_colorgroups.HAIR_COLOR, HSB(100, 43, 76), { "ogre" }, "green")
AddColor(_colorgroups.HAIR_COLOR, HSB(129, 26, 31), { "ogre" }, "forest")
AddColor(_colorgroups.HAIR_COLOR, HSB(180, 25, 105), { "ogre" }, "skyblue")
AddColor(_colorgroups.HAIR_COLOR, HSB(212, 38, 100), { "ogre" }, "cornflowerblue")
AddColor(_colorgroups.HAIR_COLOR, HSB(244, 56, 24), { "ogre", "default_unlocked" }, "midnight")
AddColor(_colorgroups.HAIR_COLOR, HSB(250, 48, 62), { "ogre" }, "purple")
AddColor(_colorgroups.HAIR_COLOR, HSB(288, 40, 85), { "ogre", "default_unlocked" }, "lilac")
AddColor(_colorgroups.HAIR_COLOR, HSB(331, 58, 85), { "ogre" }, "pink")
AddColor(_colorgroups.HAIR_COLOR, HSB(11, 41, 94), { "ogre", "default_unlocked" }, "coral")
AddColor(_colorgroups.HAIR_COLOR, HSB(11, 37, 70), { "ogre", "default_unlocked" }, "brown")
AddColor(_colorgroups.HAIR_COLOR, HSB(9, 35, 33), { "ogre", "default_unlocked" }, "darkbrown")

--- CANINE HAIR COLOURS
AddColor(_colorgroups.HAIR_COLOR, HSB(4, 110, 39), { "canine" }, "darkred")
AddColor(_colorgroups.HAIR_COLOR, HSB(9, 108, 50), { "canine", "default_unlocked" }, "scarlet")
AddColor(_colorgroups.HAIR_COLOR, HSB(15, 95, 64), { "canine", "default_unlocked" }, "orange")
AddColor(_colorgroups.HAIR_COLOR, HSB(20, 80, 98), { "canine", "default_unlocked" }, "tangerine")
AddColor(_colorgroups.HAIR_COLOR, HSB(35, 65, 85), { "canine" }, "ochre")
AddColor(_colorgroups.HAIR_COLOR, HSB(32, 58, 100), { "canine", "default_unlocked" }, "masu2")
AddColor(_colorgroups.HAIR_COLOR, HSB(47, 37, 110), { "canine" }, "flax")
AddColor(_colorgroups.HAIR_COLOR, HSB(56, 21, 110), { "canine" }, "ivory")
AddColor(_colorgroups.HAIR_COLOR, HSB(33, 58, 81), { "canine" }, "masu1")
AddColor(_colorgroups.HAIR_COLOR, HSB(26, 60, 60), { "canine", "default_unlocked" }, "tan")
AddColor(_colorgroups.HAIR_COLOR, HSB(21, 70, 47), { "canine", "default_unlocked" }, "brown")
AddColor(_colorgroups.HAIR_COLOR, HSB(355, 49, 48), { "canine" }, "mauve")
AddColor(_colorgroups.HAIR_COLOR, HSB(355, 35, 60), { "canine" }, "terrarosa")
AddColor(_colorgroups.HAIR_COLOR, HSB(160, 13, 110), { "canine", "default_unlocked" }, "arctic")
AddColor(_colorgroups.HAIR_COLOR, HSB(162, 18, 80), { "canine" }, "powder")
AddColor(_colorgroups.HAIR_COLOR, HSB(195, 41, 50), { "canine", "default_unlocked" }, "marine")
AddColor(_colorgroups.HAIR_COLOR, HSB(240, 20, 32), { "canine", "default_unlocked" }, "midnight")
AddColor(_colorgroups.HAIR_COLOR, HSB(226, 12, 57), { "canine" }, "grey")
AddColor(_colorgroups.HAIR_COLOR, HSB(225, 10, 100), { "canine", "default_unlocked" }, "periwinkle")

--- MER HAIR COLOURS
AddColor(_colorgroups.HAIR_COLOR, HSB(340, 65, 53), { "mer", "default_unlocked" }, "alizarin")
AddColor(_colorgroups.HAIR_COLOR, HSB(340, 56, 74), { "mer" }, "raspberry")
AddColor(_colorgroups.HAIR_COLOR, HSB(1, 53, 94), { "mer", "default_unlocked" }, "raspberru")
AddColor(_colorgroups.HAIR_COLOR, HSB(3, 56, 79), { "mer" }, "redorange")
AddColor(_colorgroups.HAIR_COLOR, HSB(30, 63, 97), { "mer" }, "orange")
AddColor(_colorgroups.HAIR_COLOR, HSB(41, 51, 86), { "mer", "default_unlocked" }, "ochre")
AddColor(_colorgroups.HAIR_COLOR, HSB(49, 30, 139), { "mer", "default_unlocked" }, "blond")
AddColor(_colorgroups.HAIR_COLOR, HSB(76, 20, 128), { "mer" }, "teal")
AddColor(_colorgroups.HAIR_COLOR, HSB(92, 27, 105), { "mer" }, "apple")
AddColor(_colorgroups.HAIR_COLOR, HSB(181, 64, 34), { "mer", "default_unlocked" }, "viridian")
AddColor(_colorgroups.HAIR_COLOR, HSB(168, 45, 79), { "mer", "default_unlocked" }, "bluegreen")
AddColor(_colorgroups.HAIR_COLOR, HSB(194, 33, 103), { "mer" }, "babyblue")
AddColor(_colorgroups.HAIR_COLOR, HSB(225, 78, 40), { "mer", "default_unlocked" }, "ultramarine")
AddColor(_colorgroups.HAIR_COLOR, HSB(228, 44, 25), { "mer" }, "darkblue")
AddColor(_colorgroups.HAIR_COLOR, HSB(250, 53, 73), { "mer", "default_unlocked" }, "violet")
AddColor(_colorgroups.HAIR_COLOR, HSB(292, 57, 60), { "mer", "default_unlocked" }, "plum")
AddColor(_colorgroups.HAIR_COLOR, HSB(317, 18, 137), { "mer", "default_unlocked" }, "blush")
AddColor(_colorgroups.HAIR_COLOR, HSB(210, 1, 148), { "mer", "default_unlocked" }, "white")

AddColor(_colorgroups.EYE_COLOR, HSB(1, 50, 100), {"mer", "canine", "ogre", "default_unlocked"}, "red")
AddColor(_colorgroups.EYE_COLOR, HSB(35, 50, 95), {"mer", "canine", "ogre"}, "gold")
AddColor(_colorgroups.EYE_COLOR, HSB(48, 50, 100), {"mer", "canine", "ogre"}, "yellow")
AddColor(_colorgroups.EYE_COLOR, HSB(50, 15, 110), {"mer", "canine", "ogre"}, "paleyellow")
AddColor(_colorgroups.EYE_COLOR, HSB(79, 41, 100), {"mer", "canine", "ogre"}, "green")
AddColor(_colorgroups.EYE_COLOR, HSB(160, 35, 90), {"mer", "canine", "ogre", "default_unlocked"}, "turquoise")
AddColor(_colorgroups.EYE_COLOR, HSB(182, 45, 90), {"mer", "canine", "ogre"}, "blue")
AddColor(_colorgroups.EYE_COLOR, HSB(193, 20, 100), {"mer", "canine", "ogre", "default_unlocked"}, "paleblue")

AddColor(_colorgroups.NOSE_COLOR, HSB(329, 39, 95), {"mer", "canine", "ogre", "default_unlocked"})

AddColor(_colorgroups.MOUTH_COLOR, HSB(329, 39, 95), {"mer", "canine", "ogre", "default_unlocked"})

AddColor(_colorgroups.ORNAMENT_COLOR, HSB(40, 60, 90), {"mer", "canine", "ogre", "default_unlocked"})
AddColor(_colorgroups.ORNAMENT_COLOR, HSB(130, 60, 90), {"mer", "canine", "ogre", "default_unlocked"})
AddColor(_colorgroups.ORNAMENT_COLOR, HSB(220, 60, 90))
AddColor(_colorgroups.ORNAMENT_COLOR, HSB(310, 60, 90))

--- MER MARKING COLOURS
AddColor(_colorgroups.ORNAMENT_COLOR, HSB(345, 50, 89), { "mer"}, "red")
AddColor(_colorgroups.ORNAMENT_COLOR, HSB(17, 50, 100), { "mer", "default_unlocked"}, "orange")
AddColor(_colorgroups.ORNAMENT_COLOR, HSB(55, 34, 97), { "mer", "default_unlocked"}, "yellow")
AddColor(_colorgroups.ORNAMENT_COLOR, HSB(54, 17, 96), { "mer"}, "white")
AddColor(_colorgroups.ORNAMENT_COLOR, HSB(138, 27, 96), { "mer"}, "green")
AddColor(_colorgroups.ORNAMENT_COLOR, HSB(178, 32, 93), { "mer"}, "blue")
AddColor(_colorgroups.ORNAMENT_COLOR, HSB(290, 33, 100), { "mer", "default_unlocked"}, "pink")
AddColor(_colorgroups.ORNAMENT_COLOR, HSB(266, 31, 27), { "mer"}, "black")

AddColor(_colorgroups.SHIRT_COLOR, HSB(30, 20, 80))
AddColor(_colorgroups.SHIRT_COLOR, HSB(30, 3, 96), {"mer", "canine", "ogre", "default_unlocked"})
AddColor(_colorgroups.SHIRT_COLOR, HSB(30, 1, 50))
AddColor(_colorgroups.SHIRT_COLOR, HSB(30, 0, 20), {"mer", "canine", "ogre", "default_unlocked"})

AddColor(_colorgroups.UNDIES_COLOR, HSB(250, 35, 60), {"mer", "canine", "ogre", "default_unlocked"})
AddColor(_colorgroups.UNDIES_COLOR, HSB(10, 35, 60), {"mer", "canine", "ogre", "default_unlocked"})
AddColor(_colorgroups.UNDIES_COLOR, HSB(130, 35, 60), {"mer", "canine", "ogre", "default_unlocked"})
AddColor(_colorgroups.UNDIES_COLOR, HSB(30, 20, 80))
AddColor(_colorgroups.UNDIES_COLOR, HSB(30, 3, 96))
AddColor(_colorgroups.UNDIES_COLOR, HSB(30, 1, 50), {"mer", "canine", "ogre", "default_unlocked"})
AddColor(_colorgroups.UNDIES_COLOR, HSB(30, 0, 20))

--- SMEAR COLORS
AddColor(_colorgroups.SMEAR_SKIN_COLOR, HSB(180, 40, 65))
AddColor(_colorgroups.SMEAR_WEAPON_COLOR, HSB(180, 50, 100))

--------------------------------------------------------------------------

AddItem(_parts.HEAD, "ogre", "player_head_ogre", _colorgroups.SKIN_TONE, { "ogre" })
AddItem(_parts.HEAD, "canine", "player_head_canine", _colorgroups.SKIN_TONE, { "canine" })
AddItem(_parts.HEAD, "mer", "player_head_ogre", _colorgroups.SKIN_TONE, { "mer" })


AddItem(_parts.HAIR, "ogre_buzz_x", "player_hair_ogre_buzz_x", _colorgroups.HAIR_COLOR, { "ogre", "default_unlocked" })
AddItem(_parts.HAIR, "ogre_manbun", "player_hair_ogre_manbun", _colorgroups.HAIR_COLOR, { "ogre" })
AddItem(_parts.HAIR, "ogre_pointed_quiff", "player_hair_ogre_pointed_quiff", _colorgroups.HAIR_COLOR, { "ogre" })
AddItem(_parts.HAIR, "ogre_pigtail_braid", "player_hair_ogre_pigtail_braids", _colorgroups.HAIR_COLOR, { "ogre", "default_unlocked" })
AddItem(_parts.HAIR, "ogre_ponytail_wild", "player_hair_ogre_ponytail_wild", _colorgroups.HAIR_COLOR, { "ogre" })
AddItem(_parts.HAIR, "ogre_part", "player_hair_ogre_part", _colorgroups.HAIR_COLOR, { "ogre" })
AddItem(_parts.HAIR, "ogre_sideswept", "player_hair_ogre_sideswept", _colorgroups.HAIR_COLOR, { "ogre" })
AddItem(_parts.HAIR, "ogre_poofy", "player_hair_ogre_poofy", _colorgroups.HAIR_COLOR, { "ogre" })
AddItem(_parts.HAIR, "ogre_fohawk", "player_hair_ogre_fohawk", _colorgroups.HAIR_COLOR, { "ogre" })

AddItem(_parts.HAIR, "canine_widow", "player_hair_canine_widow", _colorgroups.SKIN_TONE, { "canine" })
AddItem(_parts.HAIR, "canine_tuxedo", "player_hair_canine_tuxedo", _colorgroups.SKIN_TONE, { "canine", "default_unlocked" })
AddItem(_parts.HAIR, "canine_scruffy", "player_hair_canine_scruffy", _colorgroups.SKIN_TONE, { "canine", "default_unlocked" })
AddItem(_parts.HAIR, "canine_shiba", "player_hair_canine_shiba", _colorgroups.SKIN_TONE, { "canine" })

AddItem(_parts.HAIR, "mer_mohawk_dorsal", "player_hair_mer_mohawk_dorsal", _colorgroups.HAIR_COLOR, { "mer" })
AddItem(_parts.HAIR, "mer_goldfish", "player_hair_mer_goldfish", _colorgroups.HAIR_COLOR, { "mer", "default_unlocked" })
AddItem(_parts.HAIR, "mer_anemone", "player_hair_mer_anemone", _colorgroups.HAIR_COLOR, { "mer", "default_unlocked" })
AddItem(_parts.HAIR, "mer_flipped_strands", "player_hair_mer_flipped_strands", _colorgroups.HAIR_COLOR, { "mer" })



AddItem(_parts.BROW, "bean", "player_brow_bean", _colorgroups.HAIR_COLOR, {"mer", "canine", "ogre", "default_unlocked"})
AddItem(_parts.BROW, "thin", "player_brow_thin", _colorgroups.HAIR_COLOR, {"mer", "canine", "ogre"})
AddItem(_parts.BROW, "oval", "player_brow_oval", _colorgroups.HAIR_COLOR, {"mer", "canine", "ogre"})
AddItem(_parts.BROW, "none", nil, nil, {"mer", "canine", "ogre", "default_unlocked"}, nil, { "blank" })

AddItem(_parts.BROW, "ogre_rectangle", "player_brow_rectangle", _colorgroups.HAIR_COLOR, { "ogre" })

AddItem(_parts.BROW, "mer_antennae", "player_brow_mer_antennae", _colorgroups.HAIR_COLOR, { "mer" })
AddItem(_parts.BROW, "mer_feather", "player_brow_mer_feather", _colorgroups.HAIR_COLOR, { "mer", "default_unlocked" })


AddItem(_parts.EYES, "ogre_almond", "player_eyes_ogre_almond", _colorgroups.EYE_COLOR, { "ogre", "default_unlocked" })
AddItem(_parts.EYES, "ogre_dark", "player_eyes_ogre_dark", _colorgroups.EYE_COLOR, { "ogre" })
AddItem(_parts.EYES, "ogre_sleepy", "player_eyes_ogre_sleepy", _colorgroups.EYE_COLOR, { "ogre" })
AddItem(_parts.EYES, "ogre_round", "player_eyes_ogre_round", _colorgroups.EYE_COLOR, { "ogre", "default_unlocked" })

AddItem(_parts.EYES, "canine_almond", "player_eyes_canine_almond", _colorgroups.EYE_COLOR, { "canine", "default_unlocked" })
AddItem(_parts.EYES, "canine_wolf", "player_eyes_canine_wolf", _colorgroups.EYE_COLOR, { "canine", "default_unlocked" })
AddItem(_parts.EYES, "canine_wing_tip", "player_eyes_canine_wing_tip", _colorgroups.EYE_COLOR, { "canine" })
AddItem(_parts.EYES, "canine_round", "player_eyes_canine_round", _colorgroups.EYE_COLOR, { "canine" })
AddItem(_parts.EYES, "canine_squint", "player_eyes_canine_squint", _colorgroups.EYE_COLOR, { "canine" })
AddItem(_parts.EYES, "canine_cheetah", "player_eyes_canine_cheetah", _colorgroups.EYE_COLOR, { "canine" })

AddItem(_parts.EYES, "mer_oval", "player_eyes_mer_oval", _colorgroups.EYE_COLOR, { "mer", "default_unlocked" })
AddItem(_parts.EYES, "mer_almond", "player_eyes_mer_almond", _colorgroups.EYE_COLOR, { "mer" })
AddItem(_parts.EYES, "mer_petal", "player_eyes_mer_petal", _colorgroups.EYE_COLOR, { "mer" })


AddItem(_parts.MOUTH, "ogre", "player_mouth_ogre", nil, { "ogre", "default_unlocked" })
AddItem(_parts.MOUTH, "ogre_underbite_fang", "player_mouth_ogre_underbite_fang", nil, { "ogre", "default_unlocked" })
AddItem(_parts.MOUTH, "ogre_dainty_lip", "player_mouth_ogre_dainty_lip", nil, { "ogre" })
AddItem(_parts.MOUTH, "ogre_apathetic", "player_mouth_ogre_apathetic", nil, { "ogre" })
AddItem(_parts.MOUTH, "ogre_w", "player_mouth_ogre_w", nil, { "ogre" })

AddItem(_parts.MOUTH, "canine_long_overbite", "player_mouth_canine_long_overbite", _colorgroups.SKIN_TONE, { "canine" }, { "longsnout" })
AddItem(_parts.MOUTH, "canine_long_handsome", "player_mouth_canine_long_handsome", _colorgroups.SKIN_TONE, { "canine" }, { "longsnout" })
AddItem(_parts.MOUTH, "canine_long_sabretooth", "player_mouth_canine_long_sabretooth", _colorgroups.SKIN_TONE, { "canine" }, { "longsnout" })
AddItem(_parts.MOUTH, "canine_long_cutesy", "player_mouth_canine_long_cutesy", _colorgroups.SKIN_TONE, { "canine", "default_unlocked" }, { "longsnout" })

AddItem(_parts.MOUTH, "canine_flat_underbite", "player_mouth_canine_flat_underbite", _colorgroups.SKIN_TONE, { "canine", "default_unlocked" }, { "flatsnout" })
AddItem(_parts.MOUTH, "canine_flat_cat", "player_mouth_canine_flat_cat", _colorgroups.SKIN_TONE, { "canine", "default_unlocked" }, { "flatsnout" })
AddItem(_parts.MOUTH, "canine_flat_teardrop", "player_mouth_canine_flat_teardrop", _colorgroups.SKIN_TONE, { "canine" }, { "flatsnout" })

AddItem(_parts.MOUTH, "mer_koi", "player_mouth_mer_koi", nil, { "mer", "default_unlocked" })
AddItem(_parts.MOUTH, "mer_fishlips", "player_mouth_mer_fishlips", nil, { "mer", "default_unlocked" })
AddItem(_parts.MOUTH, "mer_turtle", "player_mouth_mer_turtle", nil, { "mer" })


AddItem(_parts.NOSE, "ogre_round", "player_nose_ogre_round", _colorgroups.NOSE_COLOR, { "ogre" })
AddItem(_parts.NOSE, "ogre_bullring", "player_nose_ogre_bullring", _colorgroups.NOSE_COLOR, { "ogre" })
AddItem(_parts.NOSE, "ogre_button", "player_nose_ogre_button", _colorgroups.NOSE_COLOR, { "ogre", "default_unlocked" })
AddItem(_parts.NOSE, "ogre_gumdrop", "player_nose_ogre_gumdrop", _colorgroups.NOSE_COLOR, { "ogre", "default_unlocked" })
AddItem(_parts.NOSE, "ogre_slope", "player_nose_ogre_slope", _colorgroups.NOSE_COLOR, { "ogre" })
AddItem(_parts.NOSE, "ogre_triangle", "player_nose_ogre_triangle", _colorgroups.NOSE_COLOR, { "ogre" })

AddItem(_parts.NOSE, "canine_clover", "player_nose_canine_clover", _colorgroups.NOSE_COLOR, { "canine", "default_unlocked" })
AddItem(_parts.NOSE, "canine_wide", "player_nose_canine_wide", _colorgroups.NOSE_COLOR, { "canine" })
AddItem(_parts.NOSE, "canine_bulb", "player_nose_canine_bulb", _colorgroups.NOSE_COLOR, { "canine", "default_unlocked" })
AddItem(_parts.NOSE, "canine_flat_triangle", "player_nose_canine_triangle", _colorgroups.NOSE_COLOR, { "canine" })
AddItem(_parts.NOSE, "canine_flat_dainty", "player_nose_canine_dainty", _colorgroups.NOSE_COLOR, { "canine" })
AddItem(_parts.NOSE, "canine_long_heart", "player_nose_canine_heart", _colorgroups.NOSE_COLOR, { "canine" })

AddItem(_parts.NOSE, "mer_flat", "player_nose_mer_flat", _colorgroups.NOSE_COLOR, { "mer", "default_unlocked" })
AddItem(_parts.NOSE, "mer_slit", "player_nose_mer_slit", _colorgroups.NOSE_COLOR, { "mer" })
AddItem(_parts.NOSE, "mer_blowhole", "player_nose_mer_blowhole", _colorgroups.NOSE_COLOR, { "mer" })


AddItem(_parts.EARS, "ogre_pointy", "player_ears_ogre_pointy", _colorgroups.SKIN_TONE, { "ogre" })
AddItem(_parts.EARS, "ogre_bat", "player_ears_ogre_bat", _colorgroups.SKIN_TONE, { "ogre", "default_unlocked" })
AddItem(_parts.EARS, "ogre_round_notch", "player_ears_ogre_round_notch", _colorgroups.SKIN_TONE, { "ogre" })

AddItem(_parts.EARS, "canine_jackal", "player_ears_canine_jackal", _colorgroups.SKIN_TONE, { "canine", "default_unlocked" })
AddItem(_parts.EARS, "canine_spade", "player_ears_canine_spade", _colorgroups.SKIN_TONE, { "canine" })
AddItem(_parts.EARS, "canine_round", "player_ears_canine_round", _colorgroups.SKIN_TONE, { "canine" })
AddItem(_parts.EARS, "canine_floppy", "player_ears_canine_floppy", _colorgroups.SKIN_TONE, { "canine", "default_unlocked" })
AddItem(_parts.EARS, "canine_angelwings", "player_ears_canine_angelwings", _colorgroups.SKIN_TONE, { "canine" })
AddItem(_parts.EARS, "canine_bat", "player_ears_canine_bat", _colorgroups.SKIN_TONE, { "canine" })
AddItem(_parts.EARS, "canine_fox_flat", "player_ears_canine_fox_flat", _colorgroups.SKIN_TONE, { "canine" })
AddItem(_parts.EARS, "canine_foxbig", "player_ears_canine_foxbig", _colorgroups.SKIN_TONE, { "canine" })
AddItem(_parts.EARS, "canine_folded", "player_ears_canine_folded", _colorgroups.SKIN_TONE, { "canine" })
AddItem(_parts.EARS, "canine_german", "player_ears_canine_german", _colorgroups.SKIN_TONE, { "canine" })
AddItem(_parts.EARS, "canine_kitty", "player_ears_canine_kitty", _colorgroups.SKIN_TONE, { "canine" })

AddItem(_parts.EARS, "mer_swimmer", "player_ears_mer_swimmer", _colorgroups.SKIN_TONE, { "mer", "default_unlocked" })
AddItem(_parts.EARS, "mer_guppy", "player_ears_mer_guppy", _colorgroups.SKIN_TONE, { "mer" })
AddItem(_parts.EARS, "mer_wing", "player_ears_mer_wing", _colorgroups.SKIN_TONE, { "mer" })
AddItem(_parts.EARS, "mer_fin", "player_ears_mer_fin", _colorgroups.SKIN_TONE, { "mer", "default_unlocked" })


AddItem(_parts.ORNAMENT, "ogre_horns", "player_ornament_ogre_horns", _colorgroups.ORNAMENT_COLOR, { "ogre" })
AddItem(_parts.ORNAMENT, "ogre_horns_sawed_off", "player_ornament_ogre_horns_sawed_off", _colorgroups.ORNAMENT_COLOR, { "ogre" })
AddItem(_parts.ORNAMENT, "ogre_horns_bull", "player_ornament_ogre_horns_bull", _colorgroups.ORNAMENT_COLOR, { "ogre" })

AddItem(_parts.ORNAMENT, "canine_3rdeye", "player_ornament_canine_3rdeye", _colorgroups.ORNAMENT_COLOR, { "canine" })
AddItem(_parts.ORNAMENT, "canine_triangle", "player_ornament_canine_triangle", _colorgroups.ORNAMENT_COLOR, { "canine" })
--AddItem(_parts.ORNAMENT, "canine_brows", "player_ornament_canine_brows", _colorgroups.ORNAMENT_COLOR, { "canine" })
AddItem(_parts.ORNAMENT, "ogre_none", nil, nil, { "ogre", "default_unlocked" }, nil, { "blank" })
AddItem(_parts.ORNAMENT, "canine_none", nil, nil, { "canine", "default_unlocked" }, nil, { "blank" })
AddItem(_parts.ORNAMENT, "mer_none", nil, nil, { "mer", "default_unlocked" }, nil, { "blank" })

AddItem(_parts.ORNAMENT, "mer_markings", "player_ornament_mer_markings", _colorgroups.ORNAMENT_COLOR, { "mer" })
AddItem(_parts.ORNAMENT, "mer_waves", "player_ornament_mer_waves", _colorgroups.ORNAMENT_COLOR, { "mer", "default_unlocked" })
AddItem(_parts.ORNAMENT, "mer_freckles", "player_ornament_mer_freckles", _colorgroups.ORNAMENT_COLOR, { "mer" })


AddItem(_parts.TORSO, "torso_ogre", "player_torso_solid", _colorgroups.SKIN_TONE, { "ogre"})
AddItem(_parts.TORSO, "torso_canine", "player_torso_solid", _colorgroups.SKIN_TONE, { "canine"})
AddItem(_parts.TORSO, "torso_mer", "player_torso_mer", _colorgroups.SKIN_TONE, { "mer"} )

AddItem(_parts.SHIRT, "bust_tank", "player_shirt_bust_tank", _colorgroups.SHIRT_COLOR, {"mer", "canine", "ogre", "default_unlocked"})
AddItem(_parts.SHIRT, "flat_binder", "player_shirt_flat_binder", _colorgroups.SHIRT_COLOR, {"mer", "canine", "ogre", "default_unlocked"})
AddItem(_parts.SHIRT, "flat_none", nil, nil, {"mer", "canine", "ogre", "default_unlocked"}, nil, { "blank" })

AddItem(_parts.UNDIES, "plain", "player_undies_plain", _colorgroups.UNDIES_COLOR, {"mer", "canine", "ogre", "default_unlocked"})
AddItem(_parts.UNDIES, "wrap", "player_undies_wrap", _colorgroups.UNDIES_COLOR, {"mer", "canine", "ogre", "default_unlocked"})

AddItem(_parts.ARMS, "solid", "player_arms_solid", _colorgroups.SKIN_TONE, {"mer", "canine", "ogre", "default_unlocked"}, nil, { "blank" })

AddItem(_parts.ARMS, "twotone", "player_arms_twotone", _colorgroups.SKIN_TONE, { "canine", "default_unlocked" })
AddItem(_parts.ARMS, "canine_stripe", "player_arms_canine_stripe", _colorgroups.SKIN_TONE, { "canine"})

AddItem(_parts.ARMS, "mer_arm_markings", "player_arms_mer_markings", _colorgroups.SKIN_TONE, { "mer", "default_unlocked" })
AddItem(_parts.ARMS, "mer_arm_waves", "player_arms_mer_waves", _colorgroups.SKIN_TONE, { "mer", "default_unlocked" })
AddItem(_parts.ARMS, "mer_arm_jaguar", "player_arms_mer_jaguar", _colorgroups.SKIN_TONE, { "mer" })
AddItem(_parts.ARMS, "mer_arm_salamander", "player_arms_mer_salamander", _colorgroups.SKIN_TONE, { "mer" })

AddItem(_parts.LEGS, "solid", "player_legs_solid", _colorgroups.SKIN_TONE, {"mer", "canine", "ogre", "default_unlocked"})

AddItem(_parts.LEGS, "twotone", "player_legs_twotone", _colorgroups.SKIN_TONE, { "canine", "default_unlocked" })
AddItem(_parts.LEGS, "canine_stripe", "player_legs_canine_stripe", _colorgroups.SKIN_TONE, { "canine"})

AddItem(_parts.OTHER, "tail_canine_plush", "player_tail_canine_plush", _colorgroups.SKIN_TONE, { "canine", "default_unlocked" })
AddItem(_parts.OTHER, "tail_canine_lion", "player_tail_canine_lion", _colorgroups.SKIN_TONE, { "canine" })
AddItem(_parts.OTHER, "tail_canine_slim", "player_tail_canine_slim", _colorgroups.SKIN_TONE, { "canine" })

--added under skin tone color group to match some aspect of the character, but should be updated to match worn armor colors
AddItem(_parts.SMEAR, "smear", "fx_player_smear", _colorgroups.SKIN_TONE)
-- AddItem(_parts.SMEAR_WEAPON, "smear_weapon", "fx_player_weapon_smear", _colorgroups.SMEAR_WEAPON_COLOR)


--------------------------------------------------------------------------

local BodyParts = {
	Parts = _parts,
	Symbols = _symbols,
	SymbolRemaps = _symbolremaps,
	SymbolFilters = _symbolfilters,
	Items = _items,
	ColorGroups = _colorgroups,
	ColorGroupBaseHSBs = _colorgroupbasehsbs,
	SymbolColorOverrides = _symbolcoloroverrides,
	Colors = _colors,
	CollectAssets = CollectAssets,
	GetColorList = GetColorList,
	GetItemList = GetItemList,
}

local function test_validate_bodyparts()
	local tags_for_groups = {}
	for slot,items in pairs(BodyParts.Items) do
		for id,def in pairs(items) do
			if def.filtertags -- has tags
				and def.colorgroup -- can be colored
			then
				assert(def.colorgroup, id)
				local taglist = tags_for_groups[def.colorgroup] or {}
				tags_for_groups[def.colorgroup] = taglist
				for tag in pairs(def.filtertags) do
					taglist[tag] = true
				end
			end
		end
	end
	for colorgroup, taglist in pairs(tags_for_groups) do
		for tag in pairs(taglist) do
			local colors = GetColorList(colorgroup, {[tag] = true})
			kassert.assert_fmt(#colors > 0, "No colors in colorgroup '%s' for tag '%s'", colorgroup, tag)
		end
	end

	-- Symbols can only be assigned to a single part.
	local seen_symbols = {}
	for part,symbol_list in pairs(BodyParts.Symbols) do
		for _,symbol in ipairs(symbol_list) do
			kassert.assert_fmt(not seen_symbols[symbol], "Symbol '%s' used on multiple parts: %s and %s.", symbol, part, seen_symbols[symbol])
			seen_symbols[symbol] = part
		end
	end
	return true
end
if DEV_MODE then
	test_validate_bodyparts()
end

return BodyParts
