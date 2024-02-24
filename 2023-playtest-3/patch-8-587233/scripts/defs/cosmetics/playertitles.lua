local Cosmetic = require("defs.cosmetics.cosmetic")

Cosmetic.PlayerTitles = {}
function Cosmetic.AddPlayerTitle(name, data)
    local cosmetic_data = data.cosmetic_data
	local def = Cosmetic.AddCosmetic(name, data)
	def.title_key = cosmetic_data.title_key
	
	Cosmetic.PlayerTitles[name] = def
end

return Cosmetic