local InstanceLog = require "util.instancelog"
local krandom = require "util.krandom"
local sort = require "util.sort"
require "util.kstring"

local ANIM, IMG, LOC = require("questral.util.contentutil").anim_img_loc()

-------------------------------------------------------------------------------

local MAX_RECENT_QUIPS = 10 -- How many recent quips in recent_lookups for debugging.

-------------------------------------------------------------------------------
-- A system for looking up randomized quips by a set of criterion tags.


local QuipMatcher = Class(function(self, ...) self:init(...) end)

function QuipMatcher:init(sim)
    self.sim = sim
    self.stats = {}
    self.recent_lookups = {}
end

function QuipMatcher:_EvaluateScore( match_tags, quip )
    if quip.notags:hasAny(match_tags) then
        self:Logf("  Matched notags. quip '%s'.", quip)
        return nil
    end

    --need to have the first tag
    if not quip:HasPrimaryTag(match_tags[1]) then
        self:Logf("  Missing primary tag. quip '%s'.", quip)
        return nil
    end

    -- Require all tags in the quip to be in match_tags. match_tags is like the
    -- game state and the quip must match the current state. It's okay if some
    -- tags in the game state are missing from the quip.
    if not quip.tags:subsetOf(match_tags) then
        self:Logf("  Quip has tags missing from match tags. quip '%s'.", quip)
        return nil
    end

    local score = 1
    --score the matching tags
    for tag in quip.tags:Iter() do
        local points = quip:GetScore(tag)
        score = score + points
        self:Logf("    %i points for tag '%s'.", points, tag)
    end
    self:Logf("  Score %i for quip '%s'.", score, quip)

    return score
end

function QuipMatcher:_GenerateMatches( match_tags, formatter )
    -- TODO(quest): Collect relevant ContentNodes and pass to QuipMatcher so
    -- quips are automatically scoped to the relevant content (similar to how
    -- we FillOutQuipTags). Still fallback to ContentDB's quips for global quip
    -- content. This setup is more intuitive since when calling AddQuip on a
    -- quest, convo, or agent you'd assume those quips are only relevant when
    -- that entity is involved.
    --
    -- For now, we use the primary tag for the speaker because Quips aren't
    -- attached to the speaker node. ContentNode:GetQuips is never called: we
    -- only use ContentDB:GetQuips.

    local content = self.sim:GetContentDB()
    for i, tag in ipairs( match_tags ) do
        match_tags[i] = tag:lower()
    end

    self:Logf("Searching with %i tags:", #match_tags)
    self:LogTable("match_tags", match_tags)

    local matches
    local primary_tag = match_tags[1]
    local quips = primary_tag and content:GetQuips( primary_tag )
    if quips then
        self:Logf("  Found %i quips from primary tag '%s'.", #quips, primary_tag)
        for _, quip in ipairs( quips ) do
            local score = self:_EvaluateScore( match_tags, quip )
            if score and score > 0 then
                if matches == nil then
                    matches = {}
                end
                for _, v in ipairs(quip.dialog) do
                    table.insert( matches, { score, v, quip.emote } )
                end
            end
        end
    else
        self:Logf("  Returned nothing from primary tag '%s'.", primary_tag)
    end

    if matches == nil then
        if self.debug_empty_matches then
            table.insert( self.recent_lookups, 1, { table.empty, shallowcopy(match_tags), content })
        end
        self:Logf("  No matches.")
        return
    end


    -- Shuffle and then stable sort to randomize order of equivalent scores.
    krandom.Shuffle(matches)
    sort.stable_sort(matches,
        function(a,b)
            local stats_a = (self.stats[a[2]] or 0)
            local stats_b = (self.stats[b[2]] or 0)
            local score_a = a[1]
            local score_b = b[1]

            if score_a == score_b then
                return stats_a < stats_b
            else
                return score_b < score_a
            end
        end)

    table.insert( self.recent_lookups, 1, { matches and shallowcopy(matches) or table.empty, shallowcopy(match_tags), content })
    while #self.recent_lookups > MAX_RECENT_QUIPS do
        table.remove( self.recent_lookups )
    end

    local match = matches[1]
    if match then
        local score, string_id, emote = match[1], match[2], match[3]
        self.stats[string_id] = (self.stats[string_id] or 0) + 1

        local txt = formatter and formatter:FormatString(LOC(string_id)) or LOC(string_id)
        if emote then
            txt = string.format("!%s\n%s", emote, txt )
        end
        self:Logf("  Quip text:[[%s]]", txt)
        self:Logf("")
        return txt
    end
end

function QuipMatcher:LookupQuip( match_tags, formatter )
    return self:_GenerateMatches( match_tags, formatter )
end

function QuipMatcher:RenderDebugPanel( ui, panel )
    if ui:Checkbox( "Track Empty Matches", self.debug_empty_matches == true ) then
        self.debug_empty_matches = not self.debug_empty_matches
    end
    ui:SameLine( nil, 20 )
    if ui:Button( "Clear Recents" ) then
        table.clear( self.recent_lookups )
    end

    local quip_tags = ui:_InputText( "Tags", self.debug_quip_tags, ui.InputTextFlags.EnterReturnsTrue )
    if quip_tags and quip_tags ~= self.debug_quip_tags then
        self.debug_quip_tags = quip_tags
        local tags = quip_tags:split_pattern(" ")
        if self:LookupQuip( tags ) == nil then
            table.insert( self.recent_lookups, { table.empty, tags } )
        end
    end
    ui:Separator()

    if #self.recent_lookups == 0 then
        ui:Text( "No recent quips" )
    else
        for i, v in ipairs( self.recent_lookups ) do
            local matches, tags, content = v[1], v[2], v[3]
            -- TODO(dbriscoe): Is this unique? It used kstring.raw before, but index should be enough.
            tags = string.format("%s (%d matches)##%i", table.concat( tags, " " ), #matches, i)
            if ui:TreeNode( tags ) then
                local content_key, content_id
                if content and content.GetContentID then
                    content_key, content_id = content:GetContentKey(), content:GetContentID()
                else
                    content_key, content_id = "ContentDB", ""
                end
                panel:AppendTable( ui, content, string.format( "%s.%s", tostring(content_key), tostring(content_id) ))
                for j, match in ipairs( matches ) do
                    ui:Text( string.format( "%d) (Score: %d) %s", j, match[1], LOC(match[2]) ))
                end
                ui:TreePop()
            end
            ui:SetTooltipIfHovered(tags)
        end
    end
end

function QuipMatcher:RenderDebugUI(ui, panel)
    if ui:Button("Inspect QuestCentral") then
        panel:PushDebugValue(self.sim)
    end
    ui:SameLineWithSpace()
    if ui:Button("Inspect ContentDB") then
        panel:PushDebugValue(self.sim:GetContentDB())
    end

    self:RenderDebugPanel(ui, panel)

    ui:Spacing()
    self:DebugDraw_Log(ui, panel, panel:GetNode().colorscheme)
end



-- InstanceLog lets us use self:Logf for logs that show in DebugEntity.
QuipMatcher:add_mixin(InstanceLog)
return QuipMatcher
