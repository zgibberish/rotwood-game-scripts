local Cosmetic = require("defs.cosmetics.cosmetic")

Cosmetic.BodyPartGroups = {}

Cosmetic.BodySymbols = {}
Cosmetic.BodySymbolRemaps = {}
Cosmetic.BodySymbolFilters = {}

Cosmetic.BodyParts = {}

local function AddBodyPartGroup(bodypart, symbols)
	assert(Cosmetic.BodyPartGroups[bodypart] == nil)
	Cosmetic.BodyPartGroups[bodypart] = bodypart
	Cosmetic.BodySymbols[bodypart] = symbols
	Cosmetic.BodyParts[bodypart] = {}
end

local function RemapSymbol(symbol, newsymbol)
	Cosmetic.BodySymbolRemaps[symbol] = newsymbol
end

local function AddSymbolFilter(symbol, tag)
	Cosmetic.BodySymbolFilters[symbol] = tag
end

function Cosmetic.GetBodyPartList(bodypart, tags)
	if tags and not next(tags) then
		tags = nil
	end

	local ret = {}
	local items = Cosmetic.BodyParts[bodypart]
	if items ~= nil then
		for name, def in pairs(items) do
			if Cosmetic.MatchesTags(def.filtertags, tags) then
				ret[#ret + 1] = def
			end
		end
	end
	table.sort(ret, Cosmetic.SortByItemName)
	return ret
end

-- Passing nil for filtertags or symboltags will match as if we supported every tag.
-- TODO(dbriscoe): POSTVS Pass tags as named keys in a tags table to avoid errors.
function Cosmetic.AddBodyPart(name, data)
	local cosmetic_data = data.cosmetic_data

	if cosmetic_data.colorgroup == "NONE" then
		cosmetic_data.colorgroup = nil
	end

	assert(cosmetic_data.build or not cosmetic_data.colorgroup, "What's the point of a colorgroup without a build?")

	local def = Cosmetic.AddCosmetic(name, data)

	def.bodypart_group = cosmetic_data.bodypart_group
	def.build = cosmetic_data.build
	def.colorgroup = cosmetic_data.colorgroup
	def.species = cosmetic_data.bodypart_species

	local filtertags = {}
	table.insert(filtertags, cosmetic_data.bodypart_species)

	def.filtertags = Cosmetic.AddTagsToDict(def.filtertags, filtertags)
	def.symboltags = Cosmetic.MakeTagsDict(cosmetic_data.symboltags)
	def.uitags = Cosmetic.MakeTagsDict(cosmetic_data.uitags) or {} -- always have ui tags

	Cosmetic.BodyParts[def.bodypart_group][name] = def
end

function Cosmetic.GetSpeciesBodyParts(bodypart, species)
	local selected_bodyparts = {}
	local bodyparts = Cosmetic.BodyParts[bodypart]

	for name, def in pairs(bodyparts) do
		if def.filtertags and def.filtertags[species] then
			table.insert(selected_bodyparts, def)
		end
	end

	return selected_bodyparts
end

function Cosmetic.CollectBodyPartAssets(assets)
	local dupe = {}
	for bodypart, items in pairs(Cosmetic.BodyParts) do
		for name, def in pairs(items) do
			if def.build ~= nil and not dupe[def.build] then
				dupe[def.build] = true
				assets[#assets + 1] = Asset("ANIM", "anim/"..def.build..".zip")
			end
		end
	end
end

-- Symbols can only be assigned to a single part.
AddBodyPartGroup("HEAD", { "head01" })

AddBodyPartGroup("HAIR", { "hair01"})
AddBodyPartGroup("HAIR_BACK", { "hair_back01", "hair_tail01" })
AddBodyPartGroup("HAIR_FRONT", { "hair_front01"})

AddBodyPartGroup("BROW", { "brow_lft01", "brow_rgt01" })
AddBodyPartGroup("EYES", { "eye_lft", "eye_rgt", "pupil01" })
AddBodyPartGroup("MOUTH", { "mouth01", "mouth_inner01" })
AddBodyPartGroup("NOSE", { "nose01", "snout_nose01_long", "snout_nose01_flat" })
AddBodyPartGroup("EARS", { "ear_lft01", "ear_lft01_inner", "ear_rgt01", "ear_rgt01_inner", "ear_k9_lft01", "ear_k9_lft01_inner", "ear_k9_rgt01", "ear_k9_rgt01_inner", "earring_lft01", "earring_rgt01" })
AddBodyPartGroup("ORNAMENT", { "ornament01", "horn_lft01", "horn_rgt01", "head01_markings" })
AddBodyPartGroup("TORSO", { "base_torso" })
AddBodyPartGroup("SHIRT", { "undershirt01" })
AddBodyPartGroup("UNDIES", { "base_pelvis" })
AddBodyPartGroup("ARMS", { "base_shoulder", "base_arm_parts", "base_hand", "base_arm_markings" })
AddBodyPartGroup("LEGS", { "base_leg_parts", "base_foot" })
AddBodyPartGroup("OTHER", { "tail01" }) -- species specific stuff here (tail for example)
AddBodyPartGroup("SMEAR", { "smear_generic01" })
AddBodyPartGroup("SMEAR_WEAPON", { "smear_weapon_generic01" })

--Remap symbols that have different names in build files.
RemapSymbol("snout_nose01_long", "snout_nose01")
RemapSymbol("snout_nose01_flat", "snout_nose01")

--Show these symbols only when their symbol tag exists.
AddSymbolFilter("snout_nose01_long", "longsnout")
AddSymbolFilter("snout_nose01_flat", "flatsnout")

return Cosmetic