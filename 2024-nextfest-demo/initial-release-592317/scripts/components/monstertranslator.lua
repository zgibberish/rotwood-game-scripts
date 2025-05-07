local lume = require "util.lume"

-- These strings are defined here to translate into monster language from English.
-- Once we can access English strings from any language and want to see translated monster language in-game,
-- we should place these strings in STRINGS and reference them there.
local monster_strings =
{
	thatcher =
	{
		THATCHER_INTRO_1 = "[TEMP] Hello! Let's be friends!",
		THATCHER_INTRO_2 = "[TEMP] Have you heard of a game called Rotwood? It's the best game ever!",
		THATCHER_INTRO_3 = "[TEMP] No you haven't? Then prepare to DIE!",

		THATCHER_DEATH_1 = "[TEMP] Aaaah! This is it for me...",
		THATCHER_DEATH_2 = "[TEMP] Please make my body parts into some fine armour!",
		THATCHER_DEATH_3 = "[TEMP] Oh, and remember to buy Rotwood and tell your friends!",
	},
}

local MonsterTranslator = Class(function(self, inst)
	self.inst = inst
    self.display_string = nil
end)

function MonsterTranslator:OnNetSerialize()
	local e = self.inst.entity
	local has_display_string = self.display_string ~= nil
	e:SerializeBoolean(has_display_string)
	if has_display_string then
		e:SerializeString(self.display_string)
	end
end

function MonsterTranslator:OnNetDeserialize()
	local e = self.inst.entity
	local has_display_string = e:DeserializeBoolean()
	if has_display_string then
    	local updated_string = e:DeserializeString()
		-- TODO: add code to show/update/hide serialized string if it changed compared to the local version.

		self.display_string = updated_string
	end
end

function MonsterTranslator:GetMonsterStringsList()
	return monster_strings
end

local alphabet = { 'a', 'b', 'c', 'd', 'e', 'f', 'g', 'h', 'i', 'j', 'k', 'l', 'm', 'n', 'o', 'p', 'q', 'r', 's', 't', 'u', 'v', 'w', 'x', 'y', 'z' }
local monster_translators =
{
	-- TODO: iterate on the translation function to make things sound more... bug-like?
	thatcher = function(str)
		local vowel_replacements =
		{
			a = "'stee",
			e = "'ielk", -- Thatcher's favourite word ;)
			i = "'knahs",
			o = "'aro",
			u = "'truw",
		}

		-- Generate consonant shift table
		local CONSONANT_SHIFT <const> = 5
		local consonant_shifts = {}
		for i, chr in ipairs(alphabet) do
			if not vowel_replacements[chr] then
				consonant_shifts[chr] = CONSONANT_SHIFT
			end
		end

		-- Iterate through each letter in the string, replacing vowels & shifting consonants
		local translated_string = ""

		-- Strip out the [TEMP] on temp text strings
		local _, start = string.find(str, "TEMP", 1, true)
		start = start + 1 or 1

		for i = start, #str do
			local chr = string.sub(str, i, i)
			local lookup_char = string.lower(chr)

			if vowel_replacements[lookup_char] then
				translated_string = translated_string .. vowel_replacements[lookup_char]
			elseif consonant_shifts[lookup_char] then
				local isUpperCase = chr == string.upper(chr)

				local letter_idx = lume.find(alphabet, lookup_char)
				local new_letter = alphabet[(letter_idx + consonant_shifts[lookup_char]) % 26]
				if isUpperCase then
					new_letter = string.upper(new_letter)
				end
				translated_string = translated_string .. new_letter
			elseif str.match(chr, "[ !.?]") then
				translated_string = translated_string .. chr
			else
				-- Ignore the character
			end
		end

		return translated_string
	end,
}

-- Returns a string in monster language.
function MonsterTranslator:GetTranslatedMonsterString(id, string_id)
	local monster_string = self:GetMonsterString(id, string_id)

	if not monster_translators[id] then
		TheLog.ch.MonsterTranslator:printf("Monster id %s does not have a translation function!", id)
		return ""
	end

	monster_string = monster_translators[id](monster_string)

	return monster_string
end

-- Returns a string in the localized language.
function MonsterTranslator:GetMonsterString(id, string_id)
	-- TODO: Implement properly once monster strings are stored in STRINGS. For now return the English string defined in monster_strings.
	if not monster_strings[id] then
		TheLog.ch.MonsterTranslator:printf("Monster id %s does not have any strings!", id)
		return ""
	elseif not monster_strings[id][string_id] then
		TheLog.ch.MonsterTranslator:printf("Monster string id %s does not exist!", string_id)
		return ""
	end

	return monster_strings[id][string_id]
end

return MonsterTranslator