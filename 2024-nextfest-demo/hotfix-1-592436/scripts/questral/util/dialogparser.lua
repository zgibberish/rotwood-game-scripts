local Enum = require "util.enum"
require "util.kstring"


local DialogParser = Class(function(self, ...) self:init(...) end)

DialogParser.LINE_TYPE = Enum{
    "SPEECH",
    "SPEAKER",
    "NARRATION",
    "EMOTE",
    "QUIP",
    "RECIPE",
    "TITLECARD",
    "SOUND_EVENT",
}

--Kris-learn to use quips here
DialogParser.help_text = [[
* SPEECH looks like some text:
	Hey, listen!

* SPEAKER is a cast id and ends with a colon:
	agent:
    giver:

* NARRATION starts with *:
	* The second most intelligent creatures were, of course, Dolphins.

* EMOTE starts with !:
	!greet
    see defs/emotion.lua for options.

* QUIP starts with % with space-separated tags:
	%scout sigh

* RECIPE starts with [recipe:] and includes the recipe param and text to accompany the price list:
	[recipe:admission_recipe] You like? You buy?

* TITLECARD starts with [title:] and includes the key for STRINGS.TITLE_CARDS.
	[title:yammo]
  There are two special keys: SPEAKER and CLEAR.
	[title:SPEAKER] -- uses the speaker's prefab name as the key for STRINGS.TITLE_CARDS.
	[title:CLEAR] -- hides the title card. Use this every time!

* SOUND_EVENT is an fmod event:
	[sound:Event.blah] 0.5   -- Plays fmodtable.Event.blah after 0.5 seconds.
	[sound:Event.bleh]       -- Plays fmodtable.Event.bleh immediately after clearing the previous line.
]]

function DialogParser.ParseDialog(txt)
    local ret = {}
    local lines = txt:split_pattern("\n")
    for i, line in ipairs(lines) do
        line = line:trim()
        local speaker = string.match(line, "^([_%w]*):$")
        local narration = string.match(line, "^[*]%s*(.+)") -- shorthand for Narrator: that doesn't change current speaker
        local emote = string.match(line, "^!([^%s]+)")
        local quip = string.match(line, "^[%%](.+)")
        local recipe, recipe_line = string.match(line, "^%[recipe:(.+)%]%s*(.*)")
        local title, title_line = string.match(line, "^%[title:(.+)%]%s*(.*)")
        local sound, sound_line = string.match(line, "^%[sound:Event.(.+)%]%s*(.*)")
        if speaker then
            table.insert(ret, { action = DialogParser.LINE_TYPE.s.SPEAKER, speaker = speaker:lower() })
        elseif narration then
            table.insert(ret, {action = DialogParser.LINE_TYPE.s.NARRATION, text = narration })
        elseif emote then
            table.insert(ret, {action = DialogParser.LINE_TYPE.s.EMOTE, emote = emote })
        elseif quip then
            table.insert(ret, {action = DialogParser.LINE_TYPE.s.QUIP, tags = quip:split_pattern() })
        elseif recipe then
            table.insert(ret, {action = DialogParser.LINE_TYPE.s.RECIPE, recipe = recipe, text = recipe_line })
        elseif title then
            table.insert(ret, {action = DialogParser.LINE_TYPE.s.TITLECARD, title = title, text = title_line })
        elseif sound then
            table.insert(ret, {action = DialogParser.LINE_TYPE.s.SOUND_EVENT, eventkey = sound, delay = tonumber(sound_line) })
        elseif #line > 0 then
            table.insert(ret, {action = DialogParser.LINE_TYPE.s.SPEECH, text = line })
        end
    end

    return ret
end

return DialogParser
