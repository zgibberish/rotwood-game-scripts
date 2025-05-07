local ContentDB = require "questral.contentdb"
local Localization = require "questral.localization"
require "class"


local GameContent = Class(function(self)
end)

function GameContent:Load()
	self.content_db = ContentDB()
	local contentloader = self:GetContentLoader()
	contentloader.LoadAll(self.content_db)
	-- Don't SetLanguage, it's called externally.
	return self
end

function GameContent:GetContentLoader()
	return require "content.contentloader"
end

function GameContent:GetContentDB()
	return self.content_db
end

function GameContent:GetLocalization()
	return self.localization
end


local function GetDefaultLanguage(self)
	-- if no language is provided, figure out a default from the system

	-- I don't think this locale detection is worthwhile. Instead, we'll only
	-- rely on the platform language.
	--~ local userlocalename = TheSim:GetUserLocaleName()
	--~ if userlocalename ~= "" then
	--~ 	for _, localization in pairs(self.content_db:GetAll( Localization )) do
	--~ 		if localization:SupportsLocale(userlocalename) then
	--~ 			return localization.id
	--~ 		end
	--~ 	end
	--~ end

	return TheSim:GetPreferredLanguage()
end

function GameContent:SetLanguage(language_id)
	local settings_language = TheGameSettings:Get("language.selected")
	assert(settings_language, "Failed to get default language.")

	if language_id == nil or self.content_db:TryGet(Localization, language_id) == nil then
		language_id = settings_language
	end

	self.localization = self.content_db:Get(Localization, language_id)
	assert(self.localization, "Missing default localization?")

	self.localization:ApplyStage1_DataOnly( self.content_db )

	TranslateStringTable( STRINGS )

	print( "GameContent:InitLanguage", language_id)
end

-- Call this immediately after SetLanguage when calling from a menu!
function GameContent:LoadLanguageDisplayElements()
	assert(self.localization, "Call Load or SetLanguage first.")
	-- We can't load this on boot until graphics are initialized.
	self.localization:ApplyStage2_DisplayElements(self.content_db)
end


return GameContent
