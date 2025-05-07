local Enum = require "util.enum"
local kstring = require "util.kstring"
local loc = require "questral.util.loc"
require "class"


---------------------------------------------------------------------------
--

local function overridePlurality( str )
    print( "Translator.overridePlurality:", str )
    if str == nil then
        loc.convertPluralityOverride = nil
        return
    end

    str = str:gsub("nplurals=(%d*);", function(n)
        n = tonumber(n)
        if n then
            print( "LOC: Overriding max plurality to ", n )
            loc.setMaxPlurality( n )
        end
        return ""
    end)

    --let's make it lua compatible
    str = str
        :gsub("\\n", "")
        :gsub("&&", "and")
        :gsub("%?", "and")
        :gsub("!=", "~=")
        :gsub(":", "or")
        :gsub("||", "or")
        :gsub(";", "")
        :gsub("plural=", "return ")
    if str then
        str = string.format( "return function( n ) %s end", str )
        local fn, err = load(str, "plurality", nil, loc.getEnv() )
        if not fn then
            print( "Failed to create plurality function:", str, tostring(err) )

        else
            print( "LOC: Plurality function:", str, type(fn) )
            loc.convertPluralityOverride = fn()
            -- for i = 1, 10 do
            --  print( i, loc.format( "{1} maps to index {1*one|two|three|four}", i ))
            -- end
        end
    end
end


local function isempty(s)
    return s == nil or s == ""
end

local function ConvertEscapeCharactersToRaw(str)
    local newstr = string.gsub(str, "\\n", "\n")
    newstr = string.gsub(newstr, "\\t", "\t")
    newstr = string.gsub(newstr, "\\r", "\r")
    newstr = string.gsub(newstr, "\\\"", "\"")

    return newstr
end

local function ParsePOHeader( str )
    local lines = str:split_pattern("\n")
    for i, line in ipairs( lines ) do
        local key, value = line:match( "^([^:]+)[:](.+)$")
        key = key and kstring.trim(key) or ""
        value = value and kstring.trim(value) or ""
        if #key > 0 and #value > 0 then
            print( "PO Header data:", key, value )
            if key == "Plural-Forms" then
                overridePlurality( value )
            end
        end
    end
end

---------------------------------------------------------------------------
--

local Translator = Class(function(self, ...) self:init(...) end)

function Translator.LoadPOFile( filepath )
    filepath = resolvefilepath(filepath)
    print( "questral Translator:LoadPOFile - loading file: "..filepath )
    local file = io.open(resolvefilepath(filepath))
    if not file then
        print( "Translator:LoadPOFile - Language file not found:", filepath )
        return nil
    end
    local text = file:read("*all")
    file:close()

    local strings = {}
    local current_id = false
    local current_str = ""
    local current_msgid = ""

    -- Need to track which msg field we are collating (multiline) strings for.
    local MODE = Enum{ "MSGCTXT", "MSGID", "MSGSTR" }
    local current_mode, temp_str = nil, ""

    local function AddCurrentString()
        temp_str = ConvertEscapeCharactersToRaw( temp_str )

        if current_mode == MODE.s.MSGCTXT then
            -- Assign to current string ID.
            current_id = temp_str
        elseif current_mode == MODE.s.MSGID then
            -- Assign to the current source (english) string.
            current_msgid = temp_str
        elseif current_mode == MODE.s.MSGSTR then
            -- Assign to the current translated string
            current_str = temp_str
        end

        if current_id then
            -- Stash the current string if we have one.

            --[[if isempty( current_str ) and not isempty( current_msgid ) then
                -- If a string is left empty, use the english string instead!
                print("\tEmpty string for id: ", current_id)
                -- Don't mangle the string if this is CONVO dialog, cause that messes up the Speaker notation.
                if not current_id:find("^CONVO[.]") then
                    current_str = UNTRANSLATED_PREFIX .. current_msgid
                end
            end--]]
            assert( not isempty( current_id ))

            if not isempty( current_str ) then
                if strings[ current_id ] then
                    LOGWARN( "Duplicate string id: %s\n%s", current_id, strings[ current_id ] )
                end
                strings[ current_id ] = current_str
            end

        elseif isempty( current_msgid ) then
            -- Interpret this stuff as the PO header.
            ParsePOHeader( current_str )
        end
    end
    for line in text:gmatch("([^\n]*)\n?") do

        --Skip lines until find an id using new format
        local sidx, eidx, c1, c2 = string.find(line, "^msgctxt(%s*)\"(.*)\"")
        if sidx then
            AddCurrentString()
            current_mode, temp_str = MODE.s.MSGCTXT, c2

            current_id = false
            current_str = ""
            current_msgid = ""
        end

        if not sidx then
            sidx, eidx, c1, c2 = string.find(line, "^msgid(%s*)\"(.*)\"")
            if sidx then
                AddCurrentString()
                current_mode, temp_str = MODE.s.MSGID, c2
            end
        end

        if not sidx then
            sidx, eidx, c1, c2 = string.find(line, "^msgstr(%s*)\"(.*)\"")
            if sidx then
                AddCurrentString()
                current_mode, temp_str = MODE.s.MSGSTR, c2
            end
        end

        if not sidx then
            -- Gather up multiline strings into temp_str.
            sidx, eidx, c1, c2 = string.find(line, "^(%s*)\"(.*)\"")
            if not isempty( c2 ) then
                assert( current_mode ~= nil ) -- Should only be accumulating multiline strings for a specific msg field.
                temp_str = temp_str .. c2
            end
        end
    end

    AddCurrentString()

    print( string.format("Translator:LoadPOFile( '%s' ) -- %d strings", filepath, table.count( strings ) ))
    return strings
end

-- Processes a map of string (loc path) -> loc string
-- eg. tbl_lookup[ "UI.FORM.BUTTON" ] = "Okay"
-- Escapes new lines, validates, and sorts the string list for writing to a PO file.
local function AggregateEntries( tbl_lookup, lookup_msgstr )
    local entries = {}
    for path, msgid  in pairs(tbl_lookup) do
        local msg_type = type(msgid)
        assert(msg_type == 'string', loc.format("ERROR! {1} is {2} but should be a string", path, msg_type))
        local str = string.gsub(msgid, "\n", "\\n")
        str = string.gsub(str, "\r", "\\r")
        str = string.gsub(str, "\"", "\\\"")

        local lines = {}
        -- #: indicates a reference comment (the string table path)
        table.insert( lines, "#: "..path)
        -- Use the string table path as the unique context as well.
        table.insert( lines, [[msgctxt "]]..path..[["]])
        table.insert( lines, [[msgid "]]..str..[["]])
        if lookup_msgstr then
            local msgstr = LOC( path )
            msgstr = msgstr:gsub( "\n", "\\n\"\n\"" )
            table.insert( lines, string.format( [[msgstr "%s"]], msgstr ))
        else
            table.insert( lines, [[msgstr ""]])
        end

        table.insert( entries, table.concat( lines, "\n" ))
    end

    -- Sort resultant entries.  Because the path commentary is first in each entry string,
    -- this will sort on that string (eg. STRINGS.UI.BLAH)
    table.sort( entries )
    return entries
end

local function FlattenStringTables(t, res, str)
    for k,v in pairs(t) do
        if type(v) == "table" then
            FlattenStringTables(v, res, str and str.."."..k or k)
        elseif type(v) == "string" then
            res[ str and (str .. "." .. k) or k] = v
        end
    end

    return res
end

local function generateFile( filename, strings, lookup_msgstr )
    print( "Exporting to data/"..filename )

    local file = io.open(filename, "w")
    -- Write UTF8 Byte Order Mark
    file:write('\239\187\191')

    local allEntries = AggregateEntries( strings, lookup_msgstr )
    for i, entry in ipairs( allEntries ) do
        file:write( entry )
        file:write( "\n\n" )
    end
    print( string.format("\t%d aggregated strings.", #allEntries ))

    file:close()
end

-- Generates a .pot file (PO template), which contains only core Game strings.
function Translator.generatePOT( db, lookup_msgstr, filter_fn )
    print("############################################")
    print("Growing unified PO/T files from strings table....")

    local strings = FlattenStringTables( db:GetAllStrings(), {} )
    --local strings = HarvestStrings( nil, filter_fn )
    generateFile("../translations/all_strings.pot", strings, lookup_msgstr )
    print( "\tDone!" )
end

local function DoLoadPoFile( po_filename )
    print("Loading po file " .. po_filename);
    local ok, result = pcall( Translator.LoadPOFile, po_filename )
    if ok then
        return result
    else
        print("FAILED TO LOAD:", po_filename, result)
    end
end

function Translator.overridePlurality( fn_str )
    overridePlurality( fn_str )
end


function Translator.LoadPoFiles( po_filename )
    local strings

    if po_filename then
        if type(po_filename) == "table" then    -- load multiple po files
            for k, v in pairs(po_filename) do
                -- MERGE.
                local postrings = DoLoadPoFile(v)
                if postrings then
                    if strings == nil then
                        strings = postrings
                    else
                        for k2,v2 in pairs(postrings) do
                            -- assert_warning(strings[k] == nil, "Merging duplicate into table")
                            strings[k2] = v2
                        end
                    end
                end
            end
        else
            strings = DoLoadPoFile(po_filename)
        end
    end

    return strings or table.empty
end


-- strings is a table of [stringid -> loc string] (compatible with the return from LoadPOFile)
-- returns a table of ranges consisting of all codepoints used by the string table.
function Translator.getCodepoints( strings )

    local ranges = {} -- Array of inclusive ranges, eg. { { 1, 3 }, { 4, 4 }, { 64, 92 }}
    local function Accumulate( n )
        local left, right
        for i, range in ipairs( ranges ) do
            if range[1] - n <= 1 and range[1] - n >= 1 then
                right = i
            elseif n - range[2] <= 1 and n - range[2] >= 1 then
                left = i
            elseif range[1] <= n and range[2] >= n then
                return -- already in a range
            end
        end

        if left and right then
            ranges[ left ][2] = ranges[ right ][2]
            table.remove( ranges, right )
        elseif left then
            ranges[ left ][2] = n
        elseif right then
            ranges[ right ][1] = n
        else
            table.insert( ranges, { n, n } )
        end
    end

    for k, s in pairs( strings ) do
        local t = { utf8.codepoint( s, 1, #s ) }
        for i, n in ipairs( t ) do
            Accumulate( n )
        end
    end

    table.sort( ranges, function( a, b ) return a[1] < b[1] end )
    return ranges
end

local function name_split( s, declensions )
    local case_idx = 1
    local t
    local function CaptureName( name )
        if name and #name > 0 and declensions[ case_idx ] then
            local declension = declensions[ case_idx ]
            if t == nil then
                t = {}
            end
            t[ declension ] = name
        end
        case_idx = case_idx + 1
    end

    local lpeg = require "lpeg"
    local sep = lpeg.P( "|" )
    local b1 = lpeg.P{ "{" * ((1 - lpeg.S"{}") + lpeg.V(1))^0 * "}" }
    --local name = lpeg.C((b1 + (1 - sep))^0)
    local name = (b1 + (1 - sep))^0 / CaptureName
    local p = lpeg.P(name * sep)^0 * lpeg.P(name)
    lpeg.match(p, s)

    return t
end

-- loc_name is a localized name containing declension forms for each case in language_info.name_declensions.
-- eg. if name_declensions is defined as { "nominative", "dative", "genetive" }, then a loc_name should be of the form
-- Bob|Boba|Boboo, where Bob is the nominative form, Boba is the dative form, and Boboo is the genetive form.
function Translator.parseNameDeclensions( db, language_info, loc_name )
    assert( loc_name )
    if language_info.name_declensions then
        local name_declensions = name_split( loc_name, language_info.name_declensions )
        local primary_name = name_declensions[ language_info.name_declensions[1] ]
        return primary_name or loc_name, name_declensions
    end

    return loc_name
end

return Translator

