--
-- Generate strings.pot file.
--
-- Uses msgctxt set to the "path" in the table structure which is guaranteed unique
-- versus the string values (msgid) which are not.
--

-- Run with ../../updateprefabs.bat
package.path = package.path .. ";../tools/scripts/?.lua;./scripts/?.lua"

POT_GENERATION = true -- many files import strings, so before any require statements!
require "nativeshims"

local GameContent = require "gamecontent"
local Translator = require "questral.util.translator"


-- *** INSTRUCTIONS ***
-- To generate strings for the main game:
-- 1. Run updateprefabs.bat from root
--		* (It runs something like "%KLEI_ROOT%\tools\lua54\bin\lua.exe createstringspo.lua")

TheGameContent = GameContent()
TheGameContent:Load()
Translator.generatePOT(TheGameContent:GetContentDB())
