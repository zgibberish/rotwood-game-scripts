local Cosmetic = require("defs.cosmetics.cosmetic")

require ("defs.cosmetics.colors")
require ("defs.cosmetics.bodyparts")
require ("defs.cosmetics.playeremotes")
require ("defs.cosmetics.armordyes")
require ("defs.cosmetics.playertitles")

local cosmetic_defs = require ("prefabs/cosmetic_autogen_data")
for k,v in pairs(cosmetic_defs) do
    if not v.deprecated then
        if v.group == "PLAYER_COLOR" then
            Cosmetic.AddColor(k, v)
        elseif v.group == "PLAYER_BODYPART" then
            Cosmetic.AddBodyPart(k, v)
        elseif v.group == "PLAYER_EMOTE" then
            Cosmetic.AddPlayerEmote(k, v)
        elseif v.group == "EQUIPMENT_DYE" then
            Cosmetic.AddEquipmentDye(k, v)
        elseif v.group == "PLAYER_TITLE" then
            Cosmetic.AddPlayerTitle(k, v)
        else
            Cosmetic.AddCosmetic(k, v)
        end
    end
end

return Cosmetic