local Coro = require "util.coro"
local DialogParser = require "questral.util.dialogparser"
local StringFormatter = require "questral.util.stringformatter"
local fmodtable = require "defs.sound.fmodtable"
local kassert = require "util.kassert"
local loc = require "questral.util.loc"
local lume = require "util.lume"
local Agent = require "questral.agent"
--~ local AgentUtil = require "questral.agentutil"
--~ local qconstants = require "questral.questralconstants"
--~ local CmpRelationships = require "sim.components.agent.cmprelationships"
local ConvoOption = require "questral.convooption"

--~ local SystemMapScreen = require "ui.screens.systemmapscreen"

--------------------------------------------------------------------------------


-- In quests, 'cx' usually means ConvoPlayer (the convo context). Not using
-- player or cp because they convey other meanings (player character, copy).
local ConvoPlayer = Class(function(self, ...) self:init(...) end)
ConvoPlayer:add_mixin( require "questral.contentnode" )

local ANIM, IMG, LOC = require("questral.util.contentutil").anim_img_loc()

ConvoPlayer:AddStrings{
    TALKING_TO = "Talking to {1.ui}",
}

function ConvoPlayer:init(conversation)
    self.screen = conversation
    self.sim = nil
    --~ self.scenario = conversation:GetCurrentScenario()
    self.memory = {} -- user key-value pairs; unlike scratch, memory is accessible/persistent for the entire convo.
    self.picked_options = {}
end

function ConvoPlayer:IsPlaying()
    return self.convo_coro ~= nil
end

function ConvoPlayer:IsGodMode()
    -- The path to divinity is long and arduous.
    return self.screen:GetFE():GetGame():GetDebug():GetDebugEnv().god_mode
end

function ConvoPlayer:StartConvoCoro(state, quest, speaker, on_done)
    if self.convo_coro then
        if not self.convo_coro:IsDone() then
            TheLog.ch.Quest:print( "Aborting convo to play", quest, state )
            TheLog.ch.Quest:print( debug.traceback(self.convo_coro.c, "aborted coro stack:"))
        end
        self.convo_coro:Stop()
        self.convo_coro = nil
    end
    -- Our Coro autoruns the input function (unlike gln).
    self.convo_coro = Coro(ConvoPlayer._ConvoCoro, self, quest, state, speaker, on_done)
end


function ConvoPlayer:GetCurrentConvo()
    return #self.cxt_stack > 0 and self.cxt_stack[#self.cxt_stack].state:GetConvo()
end

function ConvoPlayer:GetState()
    return #self.cxt_stack > 0 and self.cxt_stack[#self.cxt_stack].state
end

function ConvoPlayer:GetQuest()
    return #self.cxt_stack > 0 and self.cxt_stack[#self.cxt_stack].quest
end

function ConvoPlayer:GetScratch()
    return #self.cxt_stack > 0 and self.cxt_stack[#self.cxt_stack].scratch
end

function ConvoPlayer:GetMemory()
    return self.memory
end

--~ function ConvoPlayer:GetScenario()
--~     return self.scenario
--~ end

function ConvoPlayer:_GetPlayedStrings()
    for k = #self.cxt_stack, 1, -1 do
        if self.cxt_stack[k].played_strings then
            return self.cxt_stack[k].played_strings
        end
    end
    return self.played_strings
end

function ConvoPlayer:_GetFormatter()
    local formatter = StringFormatter()
    if self.quest then
        self.quest:FillFormatter( formatter )
    end
    formatter:AddLookupTable(self:GetScratch())
    local is_agent = self.current_speaker and Agent.is_instance(self.current_speaker)
    formatter:SetSpeaker(is_agent and self.current_speaker) -- when is speaker not an agent?
    formatter:AddLookup( "player", self:GetPlayer() )
    formatter:AddLookup( "agent", self.primary_entity )
    return formatter
end

function ConvoPlayer:_PushContext(state, quest, scratch, played_strings, string_lookup)
    table.insert(self.cxt_stack, {state = state, quest = quest, scratch = scratch or {}, played_strings = played_strings, string_lookup = string_lookup })
end

function ConvoPlayer:_PopContext()
    table.remove(self.cxt_stack)
    self.quest = self:GetQuest()
end

function ConvoPlayer:_ConvoCoro(quest, state, speaker, on_done)
    self.convo_done = false
    self.cxt_stack = {}

    self:_PushContext(state, quest)

    self.played_strings = {}
    self.current_options = {}
    self.line_just_played = false
    self.wait_for_advance = false
    self.done = nil
    self.done_loop = nil

    if speaker then
        self:TalkTo(speaker)
        if Agent.is_instance(speaker) then
            self:SetCurrentSpeaker( speaker )
        end
    end
    self:GoTo(state:GetID())

    if self.screen:IsShowingMessage() then
        self:WaitForAdvance()
    end

    self.convo_coro = nil
    self.skipping = nil

    self.screen:ClearMessage()

    -- Set done state before callback so callback knows that we finished talking.
    self.convo_done = true
    if on_done then
        on_done( )
    end

    if TheWorld:HasTag("town") then
        -- If you're in the town, save world and quest state at the end of each convo.
        TheSaveSystem:SaveAll()
    end
end

function ConvoPlayer:IsConvoDone()
    return self.convo_done
end

-- Doesn't call on_done!
function ConvoPlayer:ClearConvo()
    self.convo_coro = nil
    self.convo_done = true
end

function ConvoPlayer:_InjectOption(state, quest, ...)
    assert( state.fn ~= nil or error( string.format( "Missing state fn: %s.%s", tostring(quest), state:GetID() )))

    self:_PushContext(state, quest)

    self.injection = true
    self.quest = self:GetQuest()
    state.fn(self, ...)
    self.quest = nil
    self.injection = false

    self:_PopContext()
end


function ConvoPlayer:HasBackOption()
    for k,v in ipairs(self.current_options) do
        if v.is_back then
            return true
        end
    end
end

function ConvoPlayer:PickQuantity(txt, min, max, default_val)
    error("Not implemented yet.")
    default_val = default_val or max
    local PickQuantityPopup = require "ui.screens.pickquantitypopup"
    return self:PresentCallbackScreen(PickQuantityPopup, txt, min, max, default_val)
end


function ConvoPlayer:GoTo(state, scratch, played_strings, ...)

    self.done = nil
    self.done_state = nil
    self:WaitForAdvance()

    if type(state) == "string" then
        local stateid = state
        state = self:GetCurrentConvo():GetState(stateid)
        if not state then
            LOGWARN("NOT A VALID CONVO STATE: %s", stateid )
            d_view( self )
            return
        end
    else
        assert(require("questral.convostate").is_instance(state), "not a convo state")
    end

    self:_PushContext(state, self:GetQuest(), scratch, played_strings)
    self:_RunFn(state.fn, nil, ...)
    self:_PopContext()

    self.screen:ClearMessage()
    if state.exit_fn then
        self:_RunFn(state.exit_fn)
    end

end

--primary entity is "agent:"
--current speaker is whoever is currently talking (for quip and loc reasons)
function ConvoPlayer:TalkTo( what )

    if type(what) == "string" then
        local quest = self:GetQuest()
        what = quest and quest:GetCastMember(what)
    end

    self.primary_entity = what
    if Agent.is_instance(what) then
        self:SetCurrentSpeaker( what )
    end

    return self
end

function ConvoPlayer:FlagAsUnimportantConvo()
    -- Signify to the player that they have nothing important to say. For now,
    -- we do this by prefixing it with ... to simulate no popup speech bubble.
    --
    -- Levels of convo importance:
    -- 1. important quest info - walkby line
    -- 2. low importance (view shop, etc) - walkby line
    -- 3. unimportant (just chitchat) - no walkby line
    self:Talk("STRINGS.TALK.TALK_UNIMPORTANT")
    return self
end

-- Shim
function ConvoPlayer:Dialog(id, ...)
    OBSOLETE("ConvoPlayer:Dialog", "ConvoPlayer:Talk")
    return self:Talk(id, ...)
end

function ConvoPlayer:Talk(id, ...)
    self:WaitForAdvance()
    assert(not self.injection, "No dialog allowed in hubs.")

    local txt, remember_id = self:GetString(id, ...)
    if remember_id then
        self:_GetPlayedStrings()[remember_id] = true
    end
    self:_PlayDialog(txt or loc.format( "MISSING STRING: {1}", id))
end

function ConvoPlayer:Quip( speaker, tags )
    self:WaitForAdvance()
    local original_speaker = self.current_speaker

    if type(speaker) == "string" then
        speaker = self.quest:GetCastMember(speaker)
    end

    assert( Agent.is_instance(speaker))
    assert( type(tags) == "table" )

    self:SetCurrentSpeaker( speaker )
    do
        local qscript = self:_LookupQuip( tags )
        if qscript then
            self:_PlayDialog( qscript )
        else
            TheLog.ch.Quest:print("WARNING: No quip found", self.current_speaker, table.inspect(tags))
            -- Otherwise we'll crash later because we're stuck waiting for dialogue that will never come.
            error(("Always provide a fallback quip with one or zero tags. Missing on speaker '%s'."):format(speaker))
        end
    end
    self:SetCurrentSpeaker( original_speaker ) -- Quips can never change the original speaker.
end

-- Retrieve a localized string from id. Quest content shouldn't call GetString.
function ConvoPlayer:GetString(id, ...)
    local lookup = self:_GetContext().string_lookup
    local full_id, txt

    if lookup and lookup:TryLOC( id ) then
        full_id = id
        txt = lookup:LOC( id )
    else
        full_id = self:GetState():GetFullStringID(id)

        -- See note at Quest:SkinString for the caveats of quest string skinning.
        txt = self.quest and self.quest:TryLOC( id )

        if txt == nil then
            txt = self:GetCurrentConvo():TryLOC( full_id )
        end
    end

    local remember_id

    if txt then
        id = full_id
        remember_id = self:GetCurrentConvo().id .. "." .. full_id
    end

    if not txt then
        txt = self:GetCurrentConvo():TryLOC(id)
        remember_id = self:GetCurrentConvo().id .. "." .. id
    end

    if not txt then
        txt = LOC(id)
        remember_id = id
    end

    if txt then
        local formatter = self:_GetFormatter()
        formatter:AddLookup("first_time", self:_GetPlayedStrings()[remember_id] == nil)
        txt = formatter:FormatString(loc.format( txt, ... ))
        return txt, remember_id
    end

    return loc.format("[STRING NOT FOUND: {1}]", id), id
end

-- Unused in Rotwood.
-- The parameter can be a quest or a string
function ConvoPlayer:SetHeader(id, ...)
    if type(id) == "string" then -- This is a string
        local txt = id and self:GetString(id, ...)
        self.current_header = txt
    elseif type(id) == "table" then -- This is a quest
        -- TODO: Why support header as two different types?
        self.current_header = id
    end
    return self
end

-- Unused in Rotwood.
-- I think a header is like a screen title.
function ConvoPlayer:GetHeader()
    return self.current_header
end

function ConvoPlayer:_GetQuestObjectiveId()
    local state = self:GetState()
    dbassert(state.convo.objective_id, [[Convo not created with an objective id. Can't use CompleteQuestObjective when you pass no arguments to AddHook. Do Q:OnAttract("objective_id").]])
    return state.convo.objective_id
end

-- Complete the current or input objective.
--   cx:CompleteQuestObjective() -- completes objective for this convo
--   cx:CompleteQuestObjective("talk_in_town") -- completes talk_in_town objective
function ConvoPlayer:CompleteQuestObjective(id)
    id = id or self:_GetQuestObjectiveId()
    if id then
        -- When called from quests, self.quest matches their quest so probably
        -- more likely correct instead of GetQuest?
        dbassert(self.quest, "Was this called from within quest content?")
        self.quest:Complete(id)
    end
end

-- Complete the current quest. You may want to complete relevant objectives
-- before calling this.
function ConvoPlayer:CompleteQuest()
    dbassert(self.quest, "Was this called from within quest content?")
    self.quest:Complete()
end

-- Add a player choice. (Call multiple times for multiple options.)
-- See ConvoOption for what can be chained onto the return value.
function ConvoPlayer:Opt(id, ...)
    local txt = id and self:GetString(id, ...)
    return self:_CreateOption(txt)
end

-- Add a player choice that changes after the player picks it. Allows you to
-- make responses aware that they've already been picked. Best used with
-- cx:Loop().
--
-- The name of the first string id (OPT_HELP in the example) *must* be unique
-- within the convo.
--
-- Example that shows OPT_HELP on first pick, then OPT_HELP_AGAIN, then
-- OPT_HELP_FORGOT, then OPT_HELP_AGAIN every time after that:
--   cx:OptThatChanges("OPT_HELP", "OPT_HELP_AGAIN", "OPT_HELP_FORGOT", "OPT_HELP_AGAIN")
--       :Fn(function(_, opt)
--           if opt:HasPreviouslyPickedOption() then
--               -- Say this before repeating the same dialogue.
--               cx:Talk("HELP_RESPONSE_AGAIN")
--           end
--           cx:Talk("HELP_RESPONSE")
--       end)
function ConvoPlayer:OptThatChanges(...)
    -- Use the first id for the convo id so all picks count towards the same
    -- tally. Ensures ConvoOption:GetPickCount works correctly too.
    local forced_id = select(1, ...)
    local pick_count = self.picked_options[forced_id] or 0
    local str_id
    for i=1,select('#', ...) do
        str_id = select(i, ...)
        -- Pick the first unused option from the arguments.
        if pick_count < i then
            break
        end
    end
    assert(str_id, "You must pass a string id argument. If you don't have multiple, use Opt().")
    local txt = self:GetString(str_id) -- can't pass ... so no special format here
    return self:_CreateOption(txt, forced_id)
end

-- Join branches of the conversation back together.
--
-- If you want the player to choose dialogue options without branching the
-- convo, you can join all Opt together with this additional function. Only
-- joins undisplayed options (at the same level), so it can't join Opt that are
-- displayed as two separate groups. You'll need to use a common function for
-- that.
--
-- Example:
--   cx:Talk("TALK_INTRODUCTION")
--   cx:Opt("OPT_POLITE")
--      :Talk("RESPOND_OPT_POLITE")
--   cx:Opt("OPT_RUDE")
--      :Fn(function(cx)
--          cx:Talk("RESPOND_OPT_RUDE")
--          cx:MoreStuffAfterTalk()
--      end)
--   cx:JoinAllOpt_Fn(function()
--       -- both options go here after their Talks/Fns complete.
--       cx:Talk("TALK_RAMBLE")
--   end)
function ConvoPlayer:JoinAllOpt_Fn(fn)
	for _,opt in ipairs(self.current_options) do
		opt:Fn(fn)
	end
	return self
end

-- Create an option from a localized string instead of a string id.
function ConvoPlayer:RawOpt(txt)
	return self:_CreateOption(txt)
end

function ConvoPlayer:_CreateOption(txt, forced_id)
    -- This helper function ensures equal stack depth so ids for any option
    -- point to the right place.

    -- force the prompt's target back to the primary NPC that you are speaking to.
    self.screen.prompt:SetTarget(self.screen.inst)

    local opt = ConvoOption(self, self.cxt_stack[#self.cxt_stack], txt)
    if forced_id then
        opt:SetID(forced_id)
    end
    table.insert( self.current_options, opt)
    return opt
end

--~ function ConvoPlayer:BoonOpt( boon )
--~     local opt = self:Opt()
--~             :Text( boon:GetName() )
--~             :AppendRawTooltip( boon:GetDesc())
--~             :SetIcon( boon:IMG "OPT_BOON_ICON" )
--~             :Priority( -1 )

--~     if boon:GetAvailableDuration() then
--~         opt:AppendRawTooltip( loc.format( boon:LOC "TT_AVAILABLE_DURATION", boon:GetAvailableDuration() ))
--~     end

--~     return opt
--~ end

-- Pose a question with a specific answer.
-- I *think* this should work.
function ConvoPlayer:Question(id)
    local question_id = (self:GetState() and self:GetState().id or "") .. "_" .. id
    return
        self:Opt("QUESTION_" .. id )
            :SetID(question_id)
            :JustOnce()
            :MakeQuestion()
            :Talk("ANSWER_" .. id)
end

-- Keep repeating the input convo fn until player picks an option with
-- AddEndLoop(). Imagine an RPG dialogue tree where you keep returning to the
-- initial options until the player picks "Time for Battle".
function ConvoPlayer:Loop(fn)
    assert(not self.injection, "Not allowed in hubs.")
    self.done_loop = false
    while not self.done and not self.done_loop do
        self:_RunFn(fn)
    end
    self.done_loop = nil
end

function ConvoPlayer:EndLoop()
    self.done_loop = true
end

function ConvoPlayer:_GetContext()
    return self.cxt_stack[#self.cxt_stack]
end

function ConvoPlayer:_RunFn(fn, cxt, ...)
    assert(not self.injection, "Not allowed in hubs.")

    local pushed
    if cxt and cxt ~= self:_GetContext() then
        self:_PushContext(cxt.state, cxt.quest, nil, nil, cxt.string_lookup)
        pushed = true
    end
    table.clear(self.current_options)
    -- self.current_header = nil
    self.quest = self:GetQuest()
    fn(self, ...)
    self.quest = nil

    if pushed then
        self:_PopContext()
    end

    if #self.current_options > 0 then
        self:WaitForChoice()
    else
        self:WaitForAdvance()
    end
end

function ConvoPlayer:GetNumOptions()
    return #self.current_options
end

-- Signify that the convo has ended. The input done_state can be retrieved from
-- ExitFn(cx) with cx:GetEndState() so you can have multiple branches with
-- different ends and a common Exit handler.
--
-- This function doesn't return until the previous line of text is cleared.
function ConvoPlayer:End( done_state )
    -- Showing a line doesn't wait, so we want to wait before triggering End
    -- behaviour. This lets you chain other actions to only fire after End.
    -- (Like completing a quest *after* the last line is cleared.)
    self:WaitForAdvance()

    self.done = true
    self.done_state = done_state
end

-- Rotwood doesn't currently use exit. Once a convo ends, you exit.
function ConvoPlayer:Exit()
    self:WaitForAdvance()
    self.done = true
    self.exit = true
end

function ConvoPlayer:GetEndState()
    return self.done_state
end

function ConvoPlayer:Advance()
    if not self.in_callback then
        assert(self.wait_for_advance, "Not waiting for advance.")
        self.convo_coro:Resume()
    end
end

function ConvoPlayer:OnPresDone()
    if self.waiting_for_presentation then
        assert(self.waiting_for_presentation, "Not waiting for presentation.")
        self.waiting_for_presentation = false
        self.convo_coro:Resume()
    end
end


function ConvoPlayer:Skip()
    if not self.in_callback then
        assert(self.wait_for_advance, "Not waiting for advance.")
        self.skipping = true
        self.convo_coro:Resume()
    end
end

function ConvoPlayer:IsWaitingForPresentation()
    return self.waiting_for_presentation
end

function ConvoPlayer:WaitForPresentation()
    self.waiting_for_presentation = true
    coroutine.yield()
end

function ConvoPlayer:IsWaitingForCallback()
    return self.in_callback or false
end

-- Pause the convo to show a screen. When screen closes, we'll return to convo.
function ConvoPlayer:PresentCallbackScreen(screen_ctor, ...)
    self:WaitForAdvance()
    self.skipping = false
    self.in_callback = true

    -- GLN allowed screen instances to be passed, but had few occurences and
    -- you could pass a function that creates the screen and does whatever
    -- special logic instead of being fancy here.
    local screen = screen_ctor(...)
    TheFrontEnd:PushScreen(screen)

    assert(screen.SetCloseCallback, "not a valid callback screen")
    -- Callback arguments will be returned from PresentCallbackScreen.
    screen:SetCloseCallback(function(...)
        self.in_callback = false
        self.screen:OnResumeFromCallback()
        self.convo_coro:Resume(...)
    end)

    return coroutine.yield()
end

-- Pause convo until action is complete. Use with care, because this can softlock!
function ConvoPlayer:PresentCallbackAction(action, ...)
    kassert.typeof("function", action)
    self:WaitForAdvance()
    self.skipping = false
    -- Set flag *before* starting callback so ui can change dismiss behaviour.
    self.in_callback = true

    -- Callback arguments will be returned from PresentCallbackAction.
    -- If action never calls its callback, game will be stuck!
    action(function(...)
        self.in_callback = false
        self.screen:OnResumeFromCallback()
        self.convo_coro:Resume(...)
    end)

    return coroutine.yield()
end

-- Tells the ConversationScreen to display a custom widget instead of the
-- convo buttons, and to return a callback from that widget
function ConvoPlayer:PresentCallbackInterface(widget, ...)
    error("Not yet supported")
    self:WaitForAdvance()
    self.skipping = false
    self.in_callback = true

    self.screen:PresentCallbackInterface(widget(...))
        :SetCallback(function(...)
            self.in_callback = false
            self.screen:OnResumeFromCallback() -- EndCallbackInterface in gln
            self.convo_coro:Resume(...)
        end)

    return coroutine.yield()
end

function ConvoPlayer:IsWaitingForAdvance()
    return self.wait_for_advance
end

function ConvoPlayer:WaitForAdvance()
    if not self.skipping then
        if self.line_just_played then
            self.screen:HideMenu()
            self.wait_for_advance = true
            coroutine.yield()
            self.wait_for_advance = false
            self.line_just_played = false
        end
    end
end

function ConvoPlayer:WaitForAnimOver(inst, statename)
    -- TODO(dbriscoe): For this to work, we need to allow player to leave the
    -- talk sg state (so they can play other animations) without clearing their
    -- interact target. Maybe it's a special case for talk?
    local onanimover
    onanimover = function(source)
        inst:RemoveEventCallback("animover", onanimover)
        self:OnPresDone()
    end
    inst:ListenForEvent("animover", onanimover)

    self:WaitForPresentation()
end

function ConvoPlayer:_LookupQuip( tags )
    local primary = tags[1]
    local tag_dict = lume.invert(tags)

    local matcher = self.sim:GetQuipMatcher()
    if self.current_speaker then
        self.current_speaker:FillOutQuipTags( tag_dict )
    end

    if self.quest then
        tag_dict[self.quest:GetQuipID()] = true
    end

    local state = self:GetState()
    tag_dict[state.convo:GetQuipID()] = true

    tag_dict[primary] = nil
    tags = lume.keys(tag_dict)
    table.insert(tags, 1, primary)

    -- Terrible quip 'identity' based on speaker and tags.
    local remember_id = tostring(self.current_speaker)..":"..table.concat( tags, "." )

    local formatter = self:_GetFormatter()
    formatter:AddLookup("first_time", self:_GetPlayedStrings()[remember_id] == nil)
    self:_GetPlayedStrings()[remember_id] = true

    return matcher:LookupQuip( tags, formatter )
end

-- Force wait after the next line to prevent options from displaying next to it
-- or otherwise skipping past it.
function ConvoPlayer:SetForceWaitAfterLine(force_wait_after_line)
    self.force_wait_after_line = force_wait_after_line
    return self
end

-- You always need to WaitForAdvance after this returns. That way functions
-- like PresentOptions can fire before waiting.
function ConvoPlayer:_PlayDialog(txt)
    --this gives us a nice, usable, translated list of instructions
    local state = self:GetState()

    self.screen:SetFlagAsTemp(state.convo.temp_convo)

    local dialog = DialogParser.ParseDialog(txt)
    for k, dialog_instruction in ipairs(dialog) do
        local last_instruction = k == #dialog
        local function WaitUnlessLastLine()
            if last_instruction and not self.force_wait_after_line then
                self.has_pending_line = true
            else
                self:WaitForAdvance()
            end
        end

        --speaker settings are only on our side. script can use emotes to cause presentations.
        if dialog_instruction.action == DialogParser.LINE_TYPE.s.SPEAKER then
            local cast

            if dialog_instruction.speaker == "agent" then
                cast = self.primary_entity
            elseif dialog_instruction.speaker == "player" then
                cast = self:GetPlayer()
            else
                local quest = self:GetQuest()
                cast = quest and quest:GetCastMember(dialog_instruction.speaker)
            end

            if cast == nil then
                LOGWARN( "No cast member found:" .. tostring(dialog_instruction.speaker))
            end
            self:SetCurrentSpeaker( cast )

        elseif dialog_instruction.action == DialogParser.LINE_TYPE.s.NARRATION then
            if not self.skipping or last_instruction then
                self.screen:PlayNarration(dialog_instruction.text)
                self.line_just_played = true
            end
            WaitUnlessLastLine()

        elseif dialog_instruction.action == DialogParser.LINE_TYPE.s.RECIPE then
            -- Recipe displays both a price list and a line of dialogue and wait for finish.
            if not self.skipping or last_instruction then
                local quest = self:GetQuest()
                local recipe = quest and quest:GetVar(dialog_instruction.recipe)
                kassert.assert_fmt(recipe, "Quest '%s' has no param named '%s'. Make sure you called self:SetParam(\"%s\", recipe) from Quest_Start or before calling Talk().", quest, dialog_instruction.recipe, dialog_instruction.recipe)
                self.screen:PlayRecipeMenu(self.current_speaker, dialog_instruction.text, recipe)
                self.line_just_played = true
            end
            WaitUnlessLastLine()

        elseif dialog_instruction.action == DialogParser.LINE_TYPE.s.TITLECARD then
            -- Title displays a title card, but no line
            if not self.skipping or last_instruction then
                if dialog_instruction.title == "CLEAR" then
                    TheDungeon.HUD:HideTitleCard()
                elseif dialog_instruction.title == "SPEAKER" then
                    TheDungeon.HUD:ShowTitleCard(self.current_speaker.inst.prefab)
                else
                    TheDungeon.HUD:ShowTitleCard(dialog_instruction.title)
                end
            end

        --present emotes non-blocking
        elseif dialog_instruction.action == DialogParser.LINE_TYPE.s.EMOTE then
            self.screen:PlayEmote(self.current_speaker, dialog_instruction.emote)

        elseif dialog_instruction.action == DialogParser.LINE_TYPE.s.SOUND_EVENT then
            local event = fmodtable.Event[dialog_instruction.eventkey]
            if not event then
                TheLog.ch.Audio:printf("Dialogue had invalid fmodtable key 'fmodtable.Event.%s':\n%s", dialog_instruction.eventkey, txt)
            end
            local function fn()
                TheFrontEnd:GetSound():PlaySound(event or "")
            end
            if (dialog_instruction.delay or 0) > 0 then
                self.screen.inst:DoTaskInTime(dialog_instruction.delay, fn)
            else
                fn()
            end

        --translate quips to speech and emotes
        elseif dialog_instruction.action == DialogParser.LINE_TYPE.s.QUIP then
            local tags = shallowcopy(dialog_instruction.tags)
            self:Quip( self.current_speaker, tags )
            -- Quip calls back into _PlayDialog.

        --do a single speech line, and wait for it to finish
        elseif dialog_instruction.action == DialogParser.LINE_TYPE.s.SPEECH then
            if not self.current_speaker then
                LOGWARN( "NO current speaker set for line: " .. (dialog_instruction.text or ""))
            end
            if not self.skipping or last_instruction then
                self.screen:PlayLine(self.current_speaker, dialog_instruction.text)
                self.line_just_played = true
            end

            -- local next_instruction = dialog[k + 1]
            -- local is_switching_to_player = next_instruction and next_instruction.action == DialogParser.LINE_TYPE.s.SPEAKER
                -- and next_instruction.speaker == "player"
            -- On Rotwood, we advance with player dialogue instead of advancing
            -- each individual line.
            -- if not is_switching_to_player then
            -- end
            WaitUnlessLastLine()
        end
    end
end

function ConvoPlayer:_PresentOptions()
	assert(self.current_speaker ~= self:GetPlayer(), "Player cannot speak and have choices at the same time because the bubble needs to be over the npc to make space for choices.")

    self.skipping = false
    self.line_just_played = false
    self.waiting_for_option = true
    local to_present = {}
    for i, opt in ipairs( self.current_options ) do
        if not opt:IsHidden() then
            table.insert( to_present, opt )
        end
    end
    table.clear( self.current_options )

    self.screen:PresentOptions(to_present, self.current_header)

    local picked_idx, fn = coroutine.yield()
    if picked_idx == nil and fn then
        -- PickFnOption: TODO why would we use this? gln doesn't use it yet.
        error("ConvoOption's id depends on its callstack, so this probably doesn't set that up. It also doesn't support picked_options.")
        local opt = ConvoOption(self, self.cxt_stack[#self.cxt_stack], "")
        opt:Fn(fn)
        return opt
    else
        -- PickOption: chose one of the presented options.
        assert(picked_idx, "PickOption failed to return a chosen option.")
        local picked = to_present[picked_idx]
        self.picked_options[picked.id] = (self.picked_options[picked.id] or 0) + 1
        self.waiting_for_option = false
        return picked
    end
end

function ConvoPlayer:_ExecuteOption(option)
    if option.fns then
        self:_RunFn(function()
            for k,v in ipairs(option.fns) do
                -- Pass the ConvoOption because it has some useful queries, but
                -- modifying it won't do anything so please don't.
                v(self, option)
            end
        end,
        option.cxt)
    end
end

function ConvoPlayer:WaitForChoice()
    assert(not self.injection, "Not allowed in hubs.")
    local option = self:_PresentOptions()
    if option then
        self:_ExecuteOption(option)
    end
end


-- For screen to indicate player's choice. Quest content should never call Pick
-- functions.
function ConvoPlayer:PickFnOption(fn)
    -- assert(self.waiting_for_option, "Not waiting for option!")
    self.convo_coro:Resume(nil, fn)
end
function ConvoPlayer:PickOption(option_idx)
    assert(self.waiting_for_option, "Not waiting for option!")
    self.convo_coro:Resume(option_idx)
end

-------------------------

function ConvoPlayer:GetAgent()
    if Agent.is_instance(self.primary_entity) then
        return self.primary_entity
    end
end

-- Change tracked speaker. Used when we display lines. Quest content shouldn't
-- call SetCurrentSpeaker. Let Talk() and other functions handle it.
function ConvoPlayer:SetCurrentSpeaker( agent )
    if not Agent.is_instance(agent) then
        if agent ~= nil then
            LOGWARN( "Non-agent %s trying to speak", agent )
        end
        self.current_speaker = nil
    else
        self.current_speaker = agent

        if agent:GetFaction() then
            local CmpFactionRelationships = require "sim.components.agent.cmpfactionrelationships"
            local faction_rels = self:GetPlayer():GetComponent(CmpFactionRelationships)
            faction_rels:MeetFaction(agent:GetFaction())
        end
    end
end

function ConvoPlayer:GetPrimaryEntity()
    return self.primary_entity
end

function ConvoPlayer:SetSim(sim)
    self.sim = sim
end
function ConvoPlayer:SetPlayer(player)
    self.convo_player = player
end
function ConvoPlayer:GetPlayer()
    assert(self.convo_player, "No player yet!")
    return self.convo_player
end

function ConvoPlayer:GetLocation()
    local player = self:GetPlayer()
    if player then
        return player:GetConvoLocation()
    end
end


-------------------------

-- TODO: What's this for?
function ConvoPlayer:SetBlocker(val)
    self.screen:SetBlocker(val)
end

function ConvoPlayer:Close()
    self.screen:Close(self.oncloseconvofn)
    return self
end


---------convo starting/stopping

--~ function ConvoPlayer:StartScenario( sector, x, y, fn )
--~     self:WaitForAdvance()
--~     self.screen:Close(function()
--~         local EntityUtil = require "sim.entityutil"
--~         local scenario = EntityUtil.StartScenario( sector, x and function( playerShip ) playerShip:SetLocalPos(x, y) end )
--~         if fn then
--~             fn( scenario )
--~         end
--~     end)
--~     self:End()
--~ end

function ConvoPlayer:InjectHubOptions()
    if self:GetAgent():IsOpenToIdleConversation() then
        local role_data = self:GetAgent():GetFactionRoleData()
        if role_data and role_data.smalltalk then
            self:_InjectOption( role_data.smalltalk:GetDefaultState() )
        end
        if role_data and role_data.convos then
            for i, convo in ipairs( role_data.convos) do
                self:_InjectOption( convo:GetDefaultState() )
            end
        end
    end

    local qm = self.sim:GetQuestManager()
    local hub_options = qm:GetHubOptions(self:GetAgent())
    for _, opt in ipairs(hub_options) do
        self:_InjectOption(opt.state, opt.quest)
    end
end

function ConvoPlayer:PushAgentHub()
    self:Loop(function()
        self.current_header = loc.format( self:LOC"TALKING_TO", self:GetAgent() )

        self:InjectHubOptions()
        if #self.current_options == 0 then
            self:EndLoop()
        else
            self:Opt("STRINGS.TALK.OPT_LEAVE"):Back():EndLoop():Fn(function() self.screen:StopTalking() end)
        end
    end)
end

-- TODO: Why would we use this? Maybe it only makes sense for a hub where you
-- pull up different faces to talk to?
function ConvoPlayer:StopTalking()
    self.screen:StopTalking()
    self.current_speaker = nil
end


local function FindOwner(obj)
    if obj then
        if obj.GetAgentOwner then
            local owner = obj:GetAgentOwner()
            if owner then
                return owner
            end
        end
        return FindOwner(obj:GetParent())
    end
end

function ConvoPlayer:PushVisit(object, convo, agent)
    convo = convo or object:GetConvo("VISIT")
    agent = agent or FindOwner(object)
    if agent and convo then
        local old_loc = self:GetPlayer():GetConvoLocation()
        self:GetPlayer():SetConvoLocation(object)
        self:GoTo(convo:GetDefaultState(), nil, nil, object)
        self:GetPlayer():SetConvoLocation(old_loc)
        self:StopTalking()
    end
end

function ConvoPlayer:PushHub( what )
    self:Loop(function()
        self.current_header = what:GetName()
        local qm = self.sim:GetQuestManager()
        local hub_options = qm:GetHubOptions( what )
        for _, opt in ipairs(hub_options) do
            self:_InjectOption(opt.state, opt.quest, what)
        end

        if not self:HasBackOption() then
            self:Opt("STRINGS.TALK.OPT_LEAVE"):Back():EndLoop():Fn(function() self.screen:StopTalking() end)
        end
    end)
end

function ConvoPlayer:PushConvo(convo, scratch, ...)
    self:GoTo(convo:GetDefaultState(), scratch, {}, ...)
end

function ConvoPlayer:TryPushQuestConvo(quest, convoname )
    local convo = quest:GetConvo(convoname)
    if convo then
        local state = convo:GetDefaultState()
        self:_PushContext(state, quest)
        self:_RunFn(state.fn)
        self:_PopContext()
        return true
    else
        return false
    end
end

function ConvoPlayer:PushAgentAttract(agent)
    local Quest = require "questral.quest"
    local Convo = require "questral.convo"
    local convo = self:GetContentDB():Get( Convo, "convo_default_attract")
    return self:TryPushHook( Quest.CONVO_HOOK.s.ATTRACT, agent, convo and convo:GetDefaultState() )
end

function ConvoPlayer:TryPushHook(hook, object, default_state)
    local state, quest, best_node = object:GetQC():GetQuestManager():EvaluateHook(hook, object)
    if state == nil then
        state = default_state
        best_node = object
    end

    if state then
        self:TalkTo( best_node )
        self:_PushContext(state, quest)
        self:_RunFn(state.fn)
        self:_PopContext()
        self.screen:ClearMessage()
        if state.exit_fn then
            self:_RunFn(state.exit_fn)
        end
        if not self.exit then
            self.done = nil
        end
        self:StopTalking()
        return true
    end
    return false
end

-- TODO: Why would we use this? Should probably use End() instead.
function ConvoPlayer:EndConvo()
    error("Not currently supported.")
    self.screen:EndConvo()
end

-----------------------------These should be moved out to utility classes.

-- Roll, and return success or failure: chance is a number in [0, 1.0]
function ConvoPlayer:MakeChallengeRoll( title, chance, modifiers )
    local roll
    if self.debug_roll ~= nil then
        local success = (self.debug_roll == true)
        self.debug_roll = nil
        print( "Debug Challenge Roll:", title, success )
        return success
    else
        -- NOTE: returns a pseudo-random float with uniform distribution in the range [0,1).
        roll = math.random()

        local did_roll = false
        local ChallengeRollPopup = require "ui.screens.challengerollpopup"
        local popup = ChallengeRollPopup( title, chance, modifiers, roll)

        popup:SetCallback( function( result )
            did_roll = result
            self.in_callback = false
            self.convo_coro:Resume()
        end)

        TheFrontEnd:PushScreen( popup )
        self.in_callback = true
        coroutine.yield()

        if did_roll then
            print( "Challenge Roll:", roll, " < ", chance )
            return roll < chance
        else
            return nil
        end
    end
end

function ConvoPlayer:GrantMoney(amt)
    self:Talk("STRINGS.TALK.TALK_GAIN_MONEY", amt)
    self:GetPlayer():DeltaMoney(amt)
    return self
end

function ConvoPlayer:GrantStatProgress( amt, category, params )
    local CmpCharacterStats = require "sim.components.agent.cmpcharacterstats"
    local cmp = self:GetPlayer():GetComponent( CmpCharacterStats )
    if cmp then
        cmp:GainProgress( nil, category, amt, params )
        self:Talk("STRINGS.TALK.TALK_GAIN_STAT_PROGRESS", amt, CmpCharacterStats:LOC(category))
    end
    return self
end

function ConvoPlayer:DeltaTether(amt)

    local change = self:GetPlayer():DeltaTether(amt)
    change = math.round(change)
    if change > 0 then
        self:Talk("STRINGS.TALK.TALK_GAIN_TETHER", change)
    elseif change < 0 then
        self:Talk("STRINGS.TALK.TALK_LOSE_TETHER", -change)
    end

    return self
end

function ConvoPlayer:GrantLore( lore_id )
    local CmpUnlocker = require "sim.components.agent.cmpunlocker"
    local unlocks = self:GetPlayer():GetComponent( CmpUnlocker )
    unlocks:LearnAboutLore( lore_id )
    return self
end

function ConvoPlayer:GrantRandomLore( lore_category )
    local CmpUnlocker = require "sim.components.agent.cmpunlocker"
    local unlocks = self:GetPlayer():GetComponent( CmpUnlocker )
    unlocks:LearnAboutRandomLore( lore_category )
    return self
end

function ConvoPlayer:AddBack()
    return self:Opt("STRINGS.TALK.OPT_BACK"):Back()
end

function ConvoPlayer:AddEnd(dlg)
    return self:Opt(dlg or "STRINGS.TALK.OPT_LEAVE"):Back():End()
end

function ConvoPlayer:AddEndLoop()
    return self:Opt("STRINGS.TALK.OPT_BACK"):EndLoop():Back()
end



local function AppendTableNamed(ui, panel, t, name)
    panel:AppendTable(ui, t, name)
    ui:SameLineWithSpace()
    ui:Text(t)
end
function ConvoPlayer:RenderDebugPanel( ui, panel )
    -- Not skipping to the thread inside because convo_coro contains the done state.
    AppendTableNamed(ui, panel, self.convo_coro, "convo_coro")
    if self.cxt_stack then
        AppendTableNamed(ui, panel, self:GetCurrentConvo(), "CurrentConvo")
        AppendTableNamed(ui, panel, self:GetState(), "State")
        AppendTableNamed(ui, panel, self:GetQuest(), "Quest")
        AppendTableNamed(ui, panel, self:GetScratch(), "Scratch")
    end
    AppendTableNamed(ui, panel, self.picked_options, "picked_options")

    ui:Value("IsWaitingForAdvance", self:IsWaitingForAdvance())
    if ui:IsItemHovered() and self:IsWaitingForAdvance() then
        ui:SetTooltip("Conversation is waiting for a button to be pressed (a player input choice).")
    end
    ui:Value("IsWaitingForCallback", self:IsWaitingForCallback())
    if ui:IsItemHovered() and self:IsWaitingForCallback() then
        ui:SetTooltipMultiline({
                "Conversation is waiting for a callback because of PresentCallbackScreen or PresentCallbackAction.",
                "PresentCallbackScreen will automatically return to conversation when the screen closes,",
                "but PresentCallbackAction *requires* you to call the passed cb. Otherwise the game will hang!",
            })
    end

    ui:Value("IsConvoDone", self:IsConvoDone())

    ui:Spacing()
    if ui:Checkbox( "Win Challenge", self.debug_roll == true ) then
        if self.debug_roll == true then
            self.debug_roll = nil
        else
            self.debug_roll = true
        end
    end
    ui:SameLine( nil, 30 )
    if ui:Checkbox( "Lose Challenge", self.debug_roll == false ) then
        if self.debug_roll == false then
            self.debug_roll = nil
        else
            self.debug_roll = false
        end
    end
    return true
end

return ConvoPlayer
