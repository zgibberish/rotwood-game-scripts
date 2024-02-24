local LANGUAGE = require "languages.langs"
local kassert = require "util.kassert"
require "constants"


local localizations = {
	--~ [LANGUAGE.FRENCH]         = { strings = "fr.po",      code = "fr",      scale = 1.0,  in_steam_menu   = false, in_console_menu = true,  shrink_to_fit_word = true },
	--~ [LANGUAGE.SPANISH]        = { strings = "es.po",      code = "es",      scale = 1.0,  in_steam_menu   = false, in_console_menu = true,  shrink_to_fit_word = true },
	--~ [LANGUAGE.SPANISH_LA]     = { strings = "es_419.po",  code = "es-419",  scale = 1.0,  in_steam_menu   = false, in_console_menu = false, shrink_to_fit_word = true },
	--~ [LANGUAGE.GERMAN]         = { strings = "de.po",      code = "de",      scale = 1.0,  in_steam_menu   = false, in_console_menu = true,  shrink_to_fit_word = true },
	--~ [LANGUAGE.ITALIAN]        = { strings = "it.po",      code = "it",      scale = 1.0,  in_steam_menu   = false, in_console_menu = true,  shrink_to_fit_word = true },
	--~ [LANGUAGE.PORTUGUESE_BR]  = { strings = "pt_br.po",   code = "pt-BR",   scale = 1.0,  in_steam_menu   = false, in_console_menu = true,  shrink_to_fit_word = true },
	--~ [LANGUAGE.POLISH]         = { strings = "pl.po",      code = "pl",      scale = 1.0,  in_steam_menu   = false, in_console_menu = true,  shrink_to_fit_word = true },
	--~ [LANGUAGE.RUSSIAN]        = { strings = "ru.po",      code = "ru",      scale = 0.8,  in_steam_menu   = false, in_console_menu = true,  shrink_to_fit_word = true },  -- Russian strings are very long (often the longest), and the characters in the font are big. Bad combination.
	--~ [LANGUAGE.KOREAN]         = { strings = "ko.po",      code = "ko",      scale = 0.85, in_steam_menu   = false, in_console_menu = true,  shrink_to_fit_word = false },
	[LANGUAGE.CHINESE_S]      = { strings = "zh_cn.po",   code = "zh-CN",   scale = 1,    in_steam_menu   = true,  in_console_menu = true,  shrink_to_fit_word = false },
	--~ [LANGUAGE.CHINESE_S_RAIL] = { strings = "zh_rail.po", code = "zh-rail", scale = 1,    in_steam_menu   = false, in_console_menu = false, shrink_to_fit_word = false },
	--~ [LANGUAGE.JAPANESE]       = { strings = "ja.po",      code = "ja",      scale = 0.85, in_console_menu = true},
	--~ [LANGUAGE.CHINESE_T]      = { strings = "zh_hant.po", code = "zh-Hant", scale = 0.85, in_console_menu = true},
}
--~ localizations[LANGUAGE.PORTUGUESE] = localizations[LANGUAGE.PORTUGUESE_BR]
--~ localizations[LANGUAGE.SPANISH_LA] = localizations[LANGUAGE.SPANISH]
for id,t in pairs(localizations) do
	t.id = id
end

local LOC_ROOT_DIR = "localizations/" -- in root data dir: Rotwood/data/localizations/
local EULA_FILENAME = "eula_english.txt"
if Platform.IsXB1() then
	-- TODO(l10n): Why did DST use a different LOC_ROOT_DIR on consoles?
	-- LOC_ROOT_DIR = "data/scripts/languages/"
	EULA_FILENAME = "eula_english_x.txt"
else
	EULA_FILENAME = "eula_english_p.txt"
end
local PO_DIR = LOC_ROOT_DIR

local LOCALE = { CurrentLocale = nil }

-- Find locale object by iso language code (eg, "zh-CN").
-- TODO(dbriscoe): Have a locale for english instead of returning two values.
function LOCALE.GetLocaleByCode(lang_code)
    if lang_code == nil or lang_code == "en" then
        return nil, true
    end

    for _, loc in pairs(localizations) do
        if lang_code == loc.code then
            return loc, true
        end
    end
	-- If we failed to find an exact match, ignore country codes and look again.
	lang_code = lang_code:sub(1,2)
    for _, loc in pairs(localizations) do
        if lang_code == loc.code:sub(1,2) then
            return loc, true
        end
    end
end

function LOCALE.SetCurrentLocale(locale)
	assert(not locale or kassert.typeof("table", locale))
	LOCALE.CurrentLocale = locale
end

function LOCALE.GetLanguages()
    local lang_options = {}
    table.insert(lang_options, LANGUAGE.ENGLISH)
    for _, loc in pairs(localizations) do
        if Platform.IsConsole() then
            if loc.in_console_menu then
                table.insert(lang_options, loc.id)
            end
        elseif Platform.IsSteam() then
            if loc.in_steam_menu then
                table.insert(lang_options, loc.id)
            end
        end
    end
    return lang_options
end

function LOCALE.GetLocale(lang_id)
    if lang_id == nil then
        return LOCALE.CurrentLocale
    end
	kassert.typeof("string", lang_id) -- Use the LANGUAGE table from constants.

    local locale = nil
    for _, loc in pairs(localizations) do
        if lang_id == loc.id then
            locale = loc
        end
    end
    return locale
end

function LOCALE.GetLocaleCode(lang_id)
	local locale = LOCALE.GetLocale(lang_id)
	if locale then
		return locale.code
	else
		return "en"
	end
end

function LOCALE.GetLanguage()
    if LOCALE.CurrentLocale then
        return LOCALE.CurrentLocale.id
    else
        return LANGUAGE.ENGLISH
    end
end

function LOCALE.IsLocalized()
	return nil ~= LOCALE.CurrentLocale
end

function LOCALE.GetStringFile(lang_id)
	local locale = LOCALE.GetLocale(lang_id)
	local file = nil
	if nil ~= locale then
		file = PO_DIR .. locale.strings
	end
	
	return file
end

function LOCALE.GetEulaFilename()
    local eula_file = LOC_ROOT_DIR .. EULA_FILENAME
    return eula_file
end

function LOCALE.DetectLanguage()
	local last_detected_code = TheGameSettings:Get("language.last_detected")
	local platform_lang_code = TheSim:GetPreferredLanguage()
	if last_detected_code == platform_lang_code then
		-- Already detected this language. Do nothing since user may have
		-- selected a different one.
		return
	end
	local platform_locale, has_locale = LOCALE.GetLocaleByCode(platform_lang_code)
	if has_locale and platform_locale ~= LOCALE.CurrentLocale then
		local locale_id = platform_locale and platform_locale.id or LANGUAGE.ENGLISH
		TheLog.ch.Loc:printf("Detected platform locale [%s] to use from platform language [%s].", locale_id, platform_lang_code)
		-- Only set last_detected on successful language change so if we add
		-- new languages, we'll still detect the new suggestion.
		TheGameSettings:Set("language.last_detected", platform_lang_code)
		TheGameSettings:Set("language.selected", locale_id) -- calls SwapLanguage.
	end
end

function LOCALE.SwapLanguage(lang_id)
    -- TODO(l10n): Doesn't reliably set english from another language -- even
    -- called before anything touches strings.
    TheLog.ch.Loc:printf("SwapLanguage: Changing from locale [%s] to [%s].", LOCALE.GetLanguage(), lang_id)
    local locale =  LOCALE.GetLocale(lang_id)
    LOCALE.SetCurrentLocale(locale)
    if nil ~= locale then
        LanguageTranslator:LoadPOFile(PO_DIR .. locale.strings, locale.code)    
    end
    TranslateStringTable( STRINGS )
end

function LOCALE.GetTextScale()
    if nil == LOCALE.CurrentLocale then
        return 1.0
    else
        return LOCALE.CurrentLocale.scale
    end
end

function LOCALE.RefreshServerLocale()
	print("You probably shouldn't be calling this on clients...")
end

function LOCALE.GetShouldTextFit()
	if LOCALE.CurrentLocale then
		return LOCALE.CurrentLocale.shrink_to_fit_word
	else
		return true
	end
end

function LOCALE.GetNamesImageSuffix()
    if LOCALE.CurrentLocale then
        if LOCALE.CurrentLocale.id == LANGUAGE.CHINESE_S or LOCALE.CurrentLocale.id == LANGUAGE.CHINESE_S_RAIL then
            return "_cn"
        end
	end
    return ""
end

return LOCALE
