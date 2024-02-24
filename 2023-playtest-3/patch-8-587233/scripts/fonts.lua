
local defaultfont = "blockhead"

FONTFACE = {
	DEFAULT = defaultfont,
	TITLE = defaultfont,
	BUTTON = defaultfont,
	NUMBERS = defaultfont,
	CHAT = defaultfont, -- users talking to each other
	HEADER = defaultfont,
	BODYTEXT = defaultfont,
	CODE = "inconsolata",
}
-- See constants.lua for FONTSIZE table.

require "translator"

local font_posfix = ""

-- TODO(dbriscoe): We should use Localization to load fonts instead of
-- this since it allows easier custom fonts per language.
if LanguageTranslator then	-- This gets called from the build pipeline too
    local lang = LanguageTranslator.defaultlang

    -- Some languages need their own font
    local specialFontLangs = {"jp"}

    for i,v in pairs(specialFontLangs) do
        if v == lang then
            font_posfix = "__"..lang
        end
    end
end

-- These extra glyph fonts are only used as fallbacks.
local fallback_font = "fallback_font"
local DEFAULT_FALLBACK_TABLE = {
	fallback_font,
}


FONTS = {
	{ filename = "fonts/inconsolata_sdf"..font_posfix..".zip", alias = FONTFACE.CODE },
	{ filename = "fonts/blockhead_sdf"..font_posfix..".zip", alias = FONTFACE.DEFAULT, fallback = DEFAULT_FALLBACK_TABLE, sdfthreshold = 0.4, sdfboldthreshold = 0.1 },
	{ filename = "fonts/fallback_full_packed_sdf"..font_posfix..".zip", alias = fallback_font},
}
