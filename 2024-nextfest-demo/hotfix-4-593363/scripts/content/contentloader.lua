local loc = require "questral.util.loc"
local kassert = require "util.kassert"


local contentloader = {}

-- Load's text-based content. This function is run from lua.exe!
function contentloader.LoadAllTextContent(db)
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
	-- Do all string processing *before* adding to db so we don't need to do
	-- the same replacement twice and STRINGS.NAMES is special.
	contentloader._ProcessStrings(STRINGS, db:GetAllStrings())
	db:AddStringTable(STRINGS, "STRINGS")
end

function contentloader._ProcessStrings(...)
	local plural = STRING_METADATA.NAMES_PLURAL

	-- Allow names to contain a single level of indirection (boss_heart = "{name.konjur} Hearts")
	loc.ReplaceNames(STRINGS.NAMES, STRINGS.NAMES, {}, {})

	for id,str in pairs(STRINGS.NAMES) do
		-- Names are displayed without subfmt so no { for variable names. No
		-- more {name.blah} expansion because it was handled above and
		-- shouldn't need more than one level of expansion. If we do, probably
		-- too granular so let's not add to our startup time.
		kassert.assert_fmt(not str:find("{", nil, true), "NAMES cannot contain {variable} names or other NAMES that contain {name} references: %s = '%s'", id, str)
	end

	-- Allow singlular forms in the plural
	loc.ReplaceNames(plural, STRINGS.NAMES, {}, {})

	local plurality = loc.BuildPlurality(STRINGS.NAMES, plural)
	local n = select('#', ...)
	assert(n > 0, "Must pass string tables to process.")
	for i=1,n do
		local val = select(i, ...)
		loc.ReplaceNames(val, STRINGS.NAMES, plural, plurality)
	end
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
