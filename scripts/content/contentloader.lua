local loc = require "questral.util.loc"


local contentloader = {}

function contentloader.LoadAll(db)
	-- Load dynamic folder-based content with embedded strings. Unlike GLN, on
	-- Rotwood we don't load every lua file to improve startup time and
	-- amortize load costs. Only a small subset of our game has embedded
	-- strings.
	--
	--~ local _perf1 <close> = PROFILE_SECTION( "loader.LoadAll" )

	-- List all the content to load.
	db:LoadAllScript("scripts/content/quests")
	db:LoadAllScript("scripts/content/localizations")

	-- Replace name strings on load so writers can easily rename enemies but
	-- translators still have full control over how names are
	-- used/gendered/counted.
	-- TODO(dbriscoe): Only do this for English. Or if the loc has it enabled?
	-- Do all string processing *before* adding to db so we don't need to do
	-- the same replacement twice.
	local _, _, plural, plurality = contentloader.ProcessStrings()
	loc.ReplaceNames(db:GetAllStrings(), STRINGS.NAMES, plural, plurality)
	-- TODO(dbriscoe): Is this correct? Looks like it's loading strings, but
	-- still see MISSING TALK.OPT_LEAVE in tut_intro_scout.
	db:AddStringTable(STRINGS)
end

function contentloader.ProcessStrings()
	local plural = STRING_METADATA.NAMES_PLURAL

	-- Allow singlular forms in the plural
	loc.ReplaceNames(plural, STRINGS.NAMES, {})

	local plurality = loc.BuildPlurality(STRINGS.NAMES, plural)
	loc.ReplaceNames(STRINGS, STRINGS.NAMES, plural, plurality)
	-- We're done applying these strings, so strip them from the runtime. They
	-- should not get used from code.
	STRING_METADATA = nil
	return STRINGS, STRINGS.NAMES, plural, plurality
end

function contentloader.GetNewGameQuest()
	-- A single start quest that can spawn all the other necessary quests.
	return "main_start_rotwood"
end

return contentloader
