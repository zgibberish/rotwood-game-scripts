local Agent = require "questral.agent"
local biomes = require "defs.biomes"
local kstring = require "util.kstring"


local RotwoodLocation = Class(Agent, function(self, biome_location)
    if biome_location then
        self:SetLocation(biome_location)
    end
end)

function RotwoodLocation:__tostring()
    return string.format("RotwoodLocation[%s %s]", self.id, kstring.raw(self))
end

function RotwoodLocation:SetLocation(biome_location)
    assert(biome_location)
    self.id = biome_location.id
    self.prefab = self.id
    return self
end

function RotwoodLocation:GetBiomeLocation()
    return biomes.locations[self.id]
end

-- TODO(dbriscoe): Along with Agent.GetName, rename -> GetPrettyName.
function RotwoodLocation:GetName()
    -- Ignore base implementation!
    return self:GetBiomeLocation().pretty.name
end

return RotwoodLocation

