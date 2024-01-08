local SimContent = require "questral.simcontent"
local TagSet = require "questral.util.tagset"
local kassert = require "util.kassert"
local kstring = require "util.kstring"
local loc = require "questral.util.loc"


local Quip = Class(function(self, ...) self:init(...) end)
Quip._classname = "Quip"

function Quip.CreateGlobalQuipContent()
    -- Simple wrapper. The only use case I can currently think of is quips.
    return SimContent.CreateContent()
end

function Quip.AssertValidTag(tag)
    return kassert.assert_fmt(not tag:find("%s"), "Tags cannot contain whitespace so we can parse them: '%s'", tag)
        and kassert.assert_fmt(tag:is_lower(), "Tags must be lower case to reduce typo bugs: '%s'", tag)
end

-- A quip will only match a request if:
-- 1. It has the same primary tag.
-- 2. *All* of its tags appear in requested tags. But requested tags (analogous
--    to current game state) may contain more tags than the quip.
-- Use many tags to narrowly define when it can play and few to allow it in
-- many scenarios.
--
-- If there are multiple quip matches, then the highest scoring will play.
function Quip:init(primary_tag, ...)
    dbassert(primary_tag and Quip.AssertValidTag(primary_tag), "Every quip must have a primary tag.")
    self.primary_tag = primary_tag
    self.tags = TagSet()
    self.notags = TagSet()
    self.dialog = table.empty
    self.scores = {}
    for i=1,select('#', ...) do
        local v = select(i, ...)
        dbassert(Quip.AssertValidTag(v))
        self:Tag(v)
    end
end

function Quip:__tostring()
    if self.tags:IsEmpty() and self.notags:IsEmpty() then
        return loc.format("Quip: {1}", self.primary_tag)
    elseif self.tags:IsEmpty() then
        return loc.format("Quip: {1}: !{3}", self.primary_tag, tostring(self.notags))
    elseif self.notags:IsEmpty() then
        return loc.format("Quip: {1}: {2}", self.primary_tag, tostring(self.tags))
    else
        return loc.format("Quip: {1}: {2} !{3}", self.primary_tag, tostring(self.tags), tostring(self.notags))
    end
end

function Quip:HasPrimaryTag(tag)
    return self.primary_tag == tag
end

function Quip:HasTag(tag)
    return self.primary_tag == tag or self.tags:has(tag)
end

function Quip:GetScore(tag)
    return self.scores[tag] or 1
end

-- Quip is only selected if it matches all of the requested tags. You can set
-- its score higher for certain tags to prefer choosing it when mulitple quips
-- match.
function Quip:Tag(tag, score)
    if type(tag) == "string" then
        dbassert(Quip.AssertValidTag(tag))
        self.tags:Add(tag)
        if score then
            self.scores[tag] = score
        end

    elseif type(tag) == "table" then
        for _, inner_tag in ipairs(tag) do
            dbassert(Quip.AssertValidTag(inner_tag))
            self.tags:Add(inner_tag)
            if score then
                self.scores[inner_tag] = score
            end
        end
    end
    return self
end

function Quip:Not(tag)
    if type(tag) == "string" then
        dbassert(Quip.AssertValidTag(tag))
        self.notags:Add(tag)

    elseif type(tag) == "table" then
        for _, inner_tag in ipairs(tag) do
            dbassert(Quip.AssertValidTag(inner_tag))
            self.notags:Add(inner_tag)
        end
    end
    return self
end

function Quip:Emote(emote)
    assert(self.emote == nil, "already specified an emote!")
    self.emote = emote
    return self
end

-- When we select this quip, we'll randomly pick one of these strings. These
-- could be mini conversations or (I think) single lines.
function Quip:PossibleStrings(lines)
    assert(lines[1], "Give a list of strings instead of giving them names. (Do PossibleStrings{[[Hi]], [[Hello]]}. Don't do PossibleStrings{TALK_BLAH = [[Hi]]}.)")
    self.dialog = {}
    for i, line in ipairs( lines ) do
        line = kstring.trim(line)
        if #line > 0 then
            table.insert( self.dialog, line )
        end
    end
    return self
end

return Quip
