local Cosmetic = require("defs.cosmetics.cosmetic")

Cosmetic.PlayerEmotes = {}
function Cosmetic.AddPlayerEmote(name, data)
    local cosmetic_data = data.cosmetic_data
	local def = Cosmetic.AddCosmetic(name, data)

	def.anim = cosmetic_data.anim
	def.name_key = string.upper(name)
	def.icon_path = "images/icons_emotes/" .. name .. ".tex" --cosmetic_data.icon_path
	
	local filtertags = {}
	if cosmetic_data.emote_species ~= "none" and cosmetic_data.emote_species ~= nil then
		def.species = cosmetic_data.emote_species
		table.insert(filtertags, cosmetic_data.emote_species)
	end

	def.filtertags = Cosmetic.AddTagsToDict(def.filtertags, filtertags)

	Cosmetic.PlayerEmotes[name] = def
end

return Cosmetic