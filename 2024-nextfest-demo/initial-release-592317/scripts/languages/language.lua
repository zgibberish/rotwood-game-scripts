require "translator"


-- Debug: Enable longest to see if the text fits on screen.
local USE_LONGEST_LOCS = false
LanguageTranslator:UseLongestLocs(USE_LONGEST_LOCS)

if USE_LONGEST_LOCS then
	for _, id in pairs(LOC.GetLanguages()) do
		local file = LOC.GetStringFile(id)
		local code = LOC.GetLocaleCode(id)
		if file and code then
			LanguageTranslator:LoadPOFile(file, code)
		end
	end
else
	local currentLocale = LOC.GetLocale()
    if nil ~= currentLocale then
		local file = LOC.GetStringFile(currentLocale.id)
		if file then
			LanguageTranslator:LoadPOFile(file, currentLocale.code)    
		end
    end
end
