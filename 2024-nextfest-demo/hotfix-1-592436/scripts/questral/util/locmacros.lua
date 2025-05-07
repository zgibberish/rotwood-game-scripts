
----------------------------------------------------------------
-- Localization macros

return
{
    -- List things:
    -- "foo"
    -- "foo and bar"
    -- "foo, bar, and foobar"
    listing = function( t )
        if #t == 0 then
            return ""
        end

        local concat = t[1]
        for i = 2, #t - 1 do
            concat = concat .. ", " ..t[i]
        end
        if #t >= 3 then
            concat = concat .. ", " .. LOC"LOCMACROS.LIST_AND" .. " " .. t[#t]
        elseif #t >= 2 then
            concat = concat .. " " .. LOC"LOCMACROS.LIST_AND" .. " " .. t[#t]
        end
        return concat
    end,

    upper = function( s )
        local loc = require "questral.util.loc"
        return loc.toupper( s )
    end,

    lower = function( s )
        local loc = require "questral.util.loc"
        return loc.tolower( s )
    end,

    comma_listing = function( t )
        local concat = tostring(t[1])
        for i = 2, #t do
            concat = concat .. ", " .. tostring(t[i])
        end
        return concat
    end,

    bonus = function( n )
        if type(n) == "number" then
            if n > 0 then
                return string.format( "<#POSITIVE>%+d</>", n )
            elseif n < 0 then
                return string.format( "<#NEGATIVE>%+d</>", n )
            else
                return string.format( "%+d", n )
            end
        end
    end,

    number_postfix = function( n )
        if n == 0 then
            return "0th"
        elseif n == 1 then
            return "1st"
        elseif n == 2 then
            return "2nd"
        elseif n == 3 then
            return "3rd"
        else
            return string.format( "%sth", n )
        end
    end,

    concat_line = function( s )
        if s ~= nil then
            return "\n"..tostring(s)
        else
            return ""
        end
    end,

    a_an = function( str )
        if str then
            local loc = require "questral.util.loc"
            local c = loc.tolower( str:sub(1,1) )
            if c == "a" or c == "e" or c == "i" or c == "o" or c == "u" then
                return "an"
            else
                return "a"
            end
        else
            return "a"
        end
    end,

    -- Percentage, 0 places of precision.
    percent = function( num )
        local loc = require "questral.util.loc"
        local percent = (num or 0) * 100
        return loc.format( LOC "LOCMACROS.PERCENT", percent )
    end,

    -- Signed percent, 0 places of precision.
    spercent = function( num )
        local loc = require "questral.util.loc"
        local percent = (num or 0) * 100
        return loc.format( LOC "LOCMACROS.SPERCENT", percent )
    end,

    thousands = function( num )
        local s = string.format( "%d", math.floor( num ) )
        local pos = string.len( s ) % 3
        if pos == 0 then pos = 3 end
        return string.sub( s, 1, pos ) .. string.gsub( string.sub( s, pos+1 ), "(...)", LOC"LOCMACROS.THOUSANDS_SEPARATOR" .. "%1" )
    end,

    -- dt is in units of 'seconds'
    duration = function( dt )
        local loc = require "questral.util.loc"
        local past = dt < 0
        dt = math.abs( dt )
        local hours = math.floor( dt / 3600 )
        local minutes = math.floor( (dt - hours * 3600) / 60)
        local seconds = math.floor(dt - hours * 3600 - minutes * 60)
        if past then
            if hours > 0 then
                return loc.format( "{1} {1*hour|hours}, {2} {2*minute|minutes} ago", hours, minutes )
            elseif minutes > 0 then
                return loc.format( "{1} {1*minute|minutes}, {2} {2*second|seconds} ago", minutes, seconds )
            else
                return loc.format( "{1} {1*second|seconds} ago", seconds )
            end
        else
            if hours > 0 then
                if minutes > 0 then
                    return loc.format( "{1} {1*hour|hours}, {2} {2*minute|minutes}", hours, minutes )
                else
                    return loc.format( "{1} {1*hour|hours}", hours )
                end
            elseif minutes > 0 then
                return loc.format( "{1} {1*minute|minutes}, {2} {2*second|seconds}", minutes, seconds )
            else
                return loc.format( "{1} {1*second|seconds}", seconds )
            end
        end
    end,

    agent = function( agent )
        local Agent = require "questral.agent"
        if Agent.is_instance(agent) then
            -- The <!node_1> markup comes from gln where it's a way for the
            -- handler of the hover/text to map that tag to an actual object
            -- reference in game. This allows the game to give a tooltip for
            -- the actual object when you to hover or click that tagged piece
            -- of subtext.
            -- 
            -- This would be used in GL to reference NPCs who were instantiated
            -- in game with a unique activation id. Not currently used in
            -- rotwood.
            return string.format( "<!node_%d><#ACTOR_NAME>%s</></>", agent and agent:GetActivationID() or 0000, agent and agent:GetName() )
        end
        return tostring(agent)
    end,

    location = function( location )
        if require("sim.sector").is_instance(location) then
            return string.format( "<!node_%d><#LOCATION_NAME>%s</></>", location:GetActivationID(), location:GetName() )
        elseif location and location.GetName then
            return location:GetName()
        else
            return tostring(location)
        end
    end,

    timer_seconds = function( total_seconds )
        total_seconds = math.floor(total_seconds or 0)
        local minute_part = math.floor(total_seconds / 60)
        local second_part = total_seconds - minute_part * 60
        local loc = require "questral.util.loc"
        return loc.format("{1}:{2%02d}", minute_part, second_part)
    end,

    quest = function( quest )
        local Quest = require "questral.quest"
        if Quest.is_instance(quest) then
            return string.format( "<!node_%d><#QUEST_TITLE>%s</></>", quest and quest:GetActivationID() or 0000, quest and quest:GetTitle() )
        end
        return tostring(quest)
    end,


    item = function ( item )
        if item and item.GetName then
            return string.format( "<!todo>%s</>", item:GetName() )
        end
        return tostring(item)
    end,

    item_plural = function( item )
        if item and item.GetName then
            return string.format( "<!todo>%s</>", item:GetName( nil, 99 ) )
        end
        return tostring(item)
    end,

    items = function( items )
        local loc = require "questral.util.loc"
        local amts = {}
        for k,v in ipairs( items ) do
            local name = v:GetName() or tostring(v)
            amts[name] = (amts[name] or 0) + 1
        end
        local names = {}
        for i, name, amt in iterator.sorted_pairs(amts) do
            table.insert(names, loc.format("x{2} {1}", name, amt))
        end
        if #names == 0 then
            return LOC "LOCMACROS.NO_ITEMS"
        else
            return loc.format("{1#listing}", names)
        end
    end,

    ---------------------------------------------------------------------------------------------------
    -------------------------------------- ROTWOOD MACROS ---------------------------------------------

    material = function ( mat_name )
        local rotwoodquestutil = require "questral.game.rotwoodquestutil"
        local consumable = rotwoodquestutil.GetMaterial(mat_name)
        return ("<#EA7722>%s</>"):format(consumable.pretty.name)
    end,

    material_desc = function(mat_name)
        local rotwoodquestutil = require "questral.game.rotwoodquestutil"
        local consumable = rotwoodquestutil.GetMaterial(mat_name)
        return ("<#EA7722>%s</>"):format(consumable.pretty.desc)
    end,

    recipe = function(recipe_name)
        local recipes = require "defs.recipes"
        local Constructable = require "defs.constructable"

        local recipe = recipes.ForSlot[Constructable.Slots.FURNISHINGS][recipe_name]

        if recipe == nil then
            recipe = recipes.ForSlot[Constructable.Slots.DECOR][recipe_name]
        end

        return ("<#EA7722>%s</>"):format(recipe.def.pretty.name)
    end,

    recipe_desc = function(recipe_name)
        local recipes = require "defs.recipes"
        local Constructable = require "defs.constructable"

        local recipe = recipes.ForSlot[Constructable.Slots.FURNISHINGS][recipe_name]

        if recipe == nil then
            recipe = recipes.ForSlot[Constructable.Slots.DECOR][recipe_name]
        end

        return ("<#EA7722>%s</>"):format(recipe.def.pretty.desc)
    end,

    enemy = function(prefab_name)
        local str_name = STRINGS.NAMES[prefab_name]
        if str_name == nil then
            str_name = "MISSING STRING " .. tostring(prefab_name)
        end

        return ("<#EA7722>%s</>"):format(str_name)
    end,

}
