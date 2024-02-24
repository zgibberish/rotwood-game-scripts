local lume = require "util.lume"
local kassert = require "util.kassert"


-- Encapsulate a list of tags. All functions take either *lists* of tags or a
-- single tag and not TagSets.
local TagSet = Class(function(self, ...) self:init(...) end)

local function IsTagList(tags)
    return next(tags) == nil or tags[1] ~= nil
end

function TagSet:init(taglist)
    if taglist then
        dbassert(IsTagList(taglist), "Pass a list of tags or a single tag.")
        self:AddTag(taglist)
    end
end

function TagSet:Clone()
    local ts = TagSet()
    if self.tags then
        for tag in pairs(self.tags) do
            ts:AddTag(tag)
        end
    end
    return ts
end

local function iter(...)
    -- Omit the second value since it exposes our internal implementation.
    local tag = next(...)
    return tag
end
function TagSet:Iter()
    if not self.tags then
        return next, table.empty, nil
    end
    return iter, self.tags, nil
end

function TagSet:Add( tag )
    OBSOLETE("Add", "AddTag")
    if type(tag) == "string" then
        self:AddTag(tag)
    elseif type(tag) == "table" then
        dbassert(IsTagList(tag), "Pass a list of tags or a single tag.")
        for _,v in ipairs(tag) do
            self:AddTag(v)
        end
    end
end

function TagSet:FillDict( tag_dict )
    if self.tags then
        for tag in pairs(self.tags) do
            tag_dict[tag] = true
        end
    end
end

-- Avoid giving access to our internals like this, so we can adjust how we
-- store tags for efficiency.
-- function TagSet:GetAllTags()
--     return self.tags
-- end

function TagSet:AddTag( tag )

    if self.tags == nil then
        self.tags = {}
    end

    if type(tag) == "string" then
        self.tags[tag] = true
    elseif type(tag) == "table" then
        dbassert(IsTagList(tag), "Pass a list of tags or a single tag.")
        for _,v in ipairs(tag) do
            kassert.typeof("string", v)
            self.tags[v] = true
        end
    else
        assert(tag == nil, "malformed tag (needs to be table of strings or string)")
    end
end

function TagSet:RemoveTag( tag )
    self.tags[tag] = nil
end

function TagSet:has( tag )
    kassert.typeof("string", tag)
    if self.tags and tag then
        return self.tags[tag]
    end
end

-- Is self.tags a subset of 'tags': each entry in self.tags appears in 'tags'
function TagSet:subsetOf( tags )
    dbassert(IsTagList(tags), "Pass a list of tags.")
    if self.tags then
        for tag in pairs(self.tags) do
            if not lume.find(tags, tag) then
                return false
            end
        end
    end
    return true
end

-- self.tags has ALL of the tags within 'tags'
-- NOTE: if tags is empty or nil, then this always returns true!
function TagSet:hasAll( tags )
    if tags then
        dbassert(IsTagList(tags), "Pass a list of tags.")
        for _, tag in ipairs( tags ) do
            if not self:has(tag) then
                return false
            end
        end
    end
    return true
end

-- self.tags has AT LEAST ONE of the entries within 'tags'
-- NOTE: if tags is empty or nil, then this always returns false!
function TagSet:hasAny( tags )
    if self.tags and tags then
        dbassert(IsTagList(tags), "Pass a list of tags.")
        for _, tag in ipairs( tags ) do
            if self:has(tag) then
                return true
            end
        end
    end

    return false
end

-- self.tags has NONE of the entries within 'tags'
-- NOTE: if tags is empty or nil, then this always returns true!
function TagSet:hasNone( tags )
    return not self:hasAny(tags)
end

function TagSet:__tostring()
    if self:IsEmpty() then
        return "[]"
    else
        local taglist = lume.keys(self.tags)
        return string.format("[%s]", table.concat(taglist, ", "))
    end
end

function TagSet:IsEmpty()
    return self.tags == nil or next(self.tags) == nil
end
return TagSet
