local Translator = require "questral.util.translator"
local Validator = require "questral.util.validator"
local ContentNode = require "questral.contentnode"
local lume = require "util.lume"
----------------------------------------------------------------------

local Localization = Class(function(self, ...) self:init(...) end)
Localization:add_mixin(ContentNode)
Localization._classname = "Localization"
Localization:UseClassAsKey()
Localization.VALIDATOR = Validator()
    :Req("id", "string")
    :Req("name", "string") -- LocString
    :Req("default_languages", "table")
    :Opt("fonts", "table", table.empty )
    :Opt("plurality_fn", "string" ) -- Lua chunk in raw string
    :Opt("po_filenames", "table", table.empty )
    :Opt("incomplete", "boolean", false)

Localization.FONT_FACE_SCALE = {} --  Map of font -> number (scaling factor)
Localization.LINE_HEIGHT_SCALE = {} --  Map of font -> number (scaling factor), for tuning line height per font
Localization.EMPTY_LINE_HEIGHT_SCALE = {} -- Map of font -> number (scaling factor) for tuning line heights of empty (no-word) lines,
Localization.IMAGE_SCALE = {} --  Map of font -> number (scaling factor), for tuning embedded images

----------------------------------------------------------------------

function Localization:init(data)
    self:SetContentID(data.id)
    Localization.VALIDATOR:Validate(data)
    for k,v in pairs(data) do
        self[k] = v
    end

    self:AddString("NAME", self.name)
end

function Localization.GetFontScaling( font )
    local font_scale = Localization.FONT_FACE_SCALE[ font ] or 1
    local line_height_scale = Localization.LINE_HEIGHT_SCALE[ font ] or 1
    local image_scale = Localization.IMAGE_SCALE[ font ] or 1
    return font_scale, line_height_scale, Localization.EMPTY_LINE_HEIGHT_SCALE[ font ], image_scale
end

function Localization:ApplyFonts()
    lume.clear( Localization.FONT_FACE_SCALE )
    lume.clear( Localization.LINE_HEIGHT_SCALE )
    lume.clear( Localization.EMPTY_LINE_HEIGHT_SCALE )
    lume.clear( Localization.IMAGE_SCALE )

    if self.fonts then
        for alias, fontinfo in pairs( self.fonts ) do
            TheSim:LoadFont(
                fontinfo.font,
                alias,
                fontinfo.sdfthreshold,
                fontinfo.sdfboldthreshold,
                fontinfo.sdfshadowthreshold,
                -- fontinfo.kernAdvance, -- GLN: no kern in Rotwood
                fontinfo.supportsitalics
                )
            Localization.FONT_FACE_SCALE[alias] = fontinfo.scale
            Localization.LINE_HEIGHT_SCALE[alias] = fontinfo.line_height_scale
            Localization.EMPTY_LINE_HEIGHT_SCALE[alias] = fontinfo.empty_line_height_scale
            Localization.IMAGE_SCALE[alias] = fontinfo.image_scale
        end
    end
end

function Localization:LoadStrings()
    if self.po_filenames then
        self.strings = Translator.LoadPoFiles( self.po_filenames )
    else
        print( "No po files: defaulting to english string table.")
    end
end

-- Apply what's needed to have translated strings.
function Localization:ApplyStage1_DataOnly( db )

    self:LoadStrings()

    if self.plurality_fn then
        Translator.overridePlurality( self.plurality_fn )
    end

    --local locale_id = self.default_languages[1]
    --engine.inst:SetLocale( locale_id )

    db:setCurrentLocalization(self)
end

-- Apply graphical elements needed to display strings.
function Localization:ApplyStage2_DisplayElements(db)
    self:ApplyFonts()
end

function Localization:SupportsLocale(locale_id)
    return self.default_languages and table.arrayfind(self.default_languages, locale_id)
end

function Localization:GetString(id)
    return self.strings and self.strings[id]
end


--this might have to be different for non-english strings
function Localization.EstimateTalkingLengthForLine(txt)
    local _, words = string.gsub(txt, "%S+", "")

    if words <= 1 then
        return 1
    elseif words <= 4 then
        return 2
    elseif words <= 8 then
        return 3
    else
        return 4
    end
end

return Localization
