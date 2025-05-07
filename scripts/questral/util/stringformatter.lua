local loc = require "questral.util.loc"
local ExpressionParser = require "questral.util.expressionparser"
require "util.kstring"


----------------------------------------------------------------------------
--this handles context and variable lookup for localization substitution

local StringFormatter = Class(function(self, ...) self:init(...) end)

-- gln@6cff7c6ee15585c22c89ab80c5296cff72193b51 added nested lookup tables to
-- the array part of self.lookups:
-- "Add lookup indirects to StringFormatter so it can access the raw ConvoPlayer scratch table"
--
-- Presumably it's not another table to reduce garbage, but if anything breaks
-- in here we should split it up.
local function insert_unique( t, val )
    for k, v in pairs(t) do
        if v == val then
            return
        end
    end
    table.insert( t, val )
    return true
end


function StringFormatter:init()
    self.lookups = {}
end

function StringFormatter:Clear()
    table.clear( self.lookups )
end

function StringFormatter:SetSpeaker(agent)
    self.speaker = agent
    self:AddLookup( "speaker", agent )
    self:AddLookup( "agent", agent )
    return self
end

function StringFormatter:AddLookup( k, v )
    assert(type(k) ~= "number" ) -- Array part of lookups contains nested lookup tables..
    self.lookups[ k ] = v
end

-- Merges all elements of 't' into the lookup table, without holding reference to 't'.
function StringFormatter:AddLookups( t )
    for k, v in pairs( t ) do
        self.lookups[ k ] = v -- Array part of lookups contains nested lookup tables..
    end
end

-- Holds a reference to 't', using it as an additional lookup table.
function StringFormatter:AddLookupTable( t )
    insert_unique( self.lookups, t ) -- Array part of lookups is an array.
end

-- Return any assigned lookup value for key 'k' in the lookup table(s).
function StringFormatter:Lookup( k )
    local lookup = self.lookups[ k ]
    if type(lookup) == "function" then
        return lookup( k )
    elseif lookup ~= nil then
        return lookup
    end

    for i,lt in ipairs(self.lookups) do
        if lt[k] ~= nil then
            return lt[k]
        end
    end
end

local function SubstituteFormatter( self, text, rest )
    if rest and string.find(rest, "^%s*%?") then
        local tag_dict = {}
        if self.speaker then
            self.speaker:FillOutQuipTags(tag_dict)
        end

        local val = ExpressionParser.Evaluate(text, function(id)
            return self:Lookup( id ) or tag_dict[id] ~= nil
        end)

        return val == true
    end

    return self:Lookup( text )
end


function StringFormatter:FormatString(txt, ...)

    local params = {...}

    local function Formatter( word, operator, rest )
        local locobj = SubstituteFormatter( self, word, operator )

        if not locobj then
            local num = tonumber(word)
            if num and params[num] then
                locobj = params[num]
            end
        end

        if locobj ~= nil then
            if type( locobj ) == "table" and locobj.LocMacro then
                if operator == "." then
                    local tokens = rest:split_pattern("[?|]")
                    local res = locobj:LocMacro(table.unpack(tokens))
                    return res
                else
                    return locobj:LocMacro()
                end
            end

            table.insert(params, locobj)
            return loc.format( string.format("{%d%s%s}", #params, operator, rest), table.unpack(params))
        end
    end

    return loc.custom_format( txt, Formatter )
end

-- Format a run's duration (seconds) to a displayable string
function StringFormatter.FormatRunDuration(seconds, show_hours)
    local seconds_per_hour = 3600
    local seconds_per_minute = 60

    local hours = show_hours and math.floor(seconds / seconds_per_hour) or 0
    local remaining_seconds = seconds - hours*seconds_per_hour
    local minutes = math.floor(remaining_seconds / seconds_per_minute)
    remaining_seconds = remaining_seconds - minutes*seconds_per_minute

    if hours > 1 then
        return string.format("%.0f HR %.0f MIN %.0f SEC", hours, minutes, remaining_seconds)
    elseif hours > 0 then
        return string.format("1 HR %.0f MIN %.0f SEC", minutes, remaining_seconds)
    else
        return string.format("%.0f MIN %.0f SEC", minutes, remaining_seconds)
    end
end

return StringFormatter
