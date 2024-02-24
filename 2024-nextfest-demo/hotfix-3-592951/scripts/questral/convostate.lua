local loc = require "questral.util.loc"
local Validator = require "questral.util.validator"

----------------------------------

local QUESTION_VALIDATOR = Validator()
    :Opt( "id", "string" )
    :Req( "tags", "table" )
    :Opt( "unlock_tags", "table" )
    :Req( "questions", "table" )
    :Opt( "end_fn", "function" )
    :Opt( "lore_id", "string" )
    :Opt( "start", "string" )
    :Opt( "out", "string" )
    :Opt( "stop", "string" )
    :Opt( "persistent", "boolean" )

----------------------------------

-- ConvoState is the type returned from Quest:OnAttract/OnConfront/OnHub.
local ConvoState = Class(function(self, ...) self:init(...) end)

function ConvoState:init(convo, id)
    self.convo = convo
    self.id = id
end

function ConvoState:ID( id )
    self.id = id
    return self
end

function ConvoState:GetConvo()
    return self.convo
end

function ConvoState:Textures(t)
    self.convo:PreloadTextures( t )
    return self
end

function ConvoState:FlagAsTemp()
    self.convo.temp_convo = true
    return self
end

function ConvoState:Strings(strs)
    assert(strs, "Expected some strings. Is there a typo?")
    self.convo:AddStrings( strs, self.id )
    return self
end

function ConvoState:RequiredWorldFlags(flags)
    self.convo.required_world_flags = flags
    return self
end

function ConvoState:ForbiddenWorldFlags(flags)
    self.convo.forbidden_world_flags = flags
    return self
end

function ConvoState:RequiredPlayerFlags(flags)
    self.convo.required_player_flags = flags
    return self
end

function ConvoState:ForbiddenPlayerFlags(flags)
    self.convo.forbidden_player_flags = flags
    return self
end

function ConvoState:SetChatCost(num)
    self.chat_cost = num
    return self
end

function ConvoState:GetChatCost()
    return self.chat_cost or DEFAULT_CHAT_COST
end

function ConvoState:Quips(quips)
    self.convo:AddQuips( quips )
    return self
end

function ConvoState:GetID()
    return self.id
end

function ConvoState:GetFullID()
    return self.convo.id .. "." .. self.id
end

function ConvoState:Fn(fn)
    assert(self.fn == nil, "Duplicate fn call!")
    self.fn = fn
    return self
end

function ConvoState:ExitFn(fn)
    assert(self.exit_fn == nil, "Duplicate fn call!")
    self.exit_fn = fn
    return self
end

function ConvoState:State(id)
    return self.convo:AddState(id)
end

function ConvoState:BuildQuestionState(data)
    data = QUESTION_VALIDATOR:Validate( data )
    local state = self.convo:AddState(data.id)

    state:Strings{
        TALK_START = data.start,
        TALK_OUT_OF_QUESTIONS = data.out,
        TALK_STOP_QUESTIONS = data.stop,
        OPT_STOP_QUESTIONS = "Enough questions!"
    }

    for id,v in pairs(data.questions) do
        local question, answer = v[1], v[2]
        state:Strings{
            ["QUESTION_"..id] = question,
            ["ANSWER_"..id] = answer,
        }
        if v[3] then
            for k,v in ipairs(v[3]) do
                if not data.questions[v] then
                    error("Invalid question token: " .. v)
                end
            end
        end
    end

    state:Fn(function(convo)
        convo:GetScratch().asked_question = false
        local open_questions = shallowcopy(data.tags)

        if data.start then
            convo:Talk("TALK.START")
        end

        local function FinishQuestions()
            if data.lore_id then
                convo:GrantLore( data.lore_id )
            end
            if data.end_fn then
                return data.end_fn(convo, open_questions)
            else
                return convo:EndLoop()
            end
        end

        convo:Loop(function()
            for k, id in ipairs(open_questions) do
                local qdata = data.questions[id]
                if qdata then
                    local q = convo:Question(id)
                    q:Fn(function()
                            convo:GetScratch().asked_question = true
                            table.removearrayvalue(open_questions, id)
                            local tokens = qdata[3]
                            if tokens then
                                for k, v in ipairs(tokens) do
                                    table.insert_unique(open_questions, v)
                                end
                            end
                        end)
                    q:Fn( qdata[4] )
                else
                    LOGWARN( "Missing question state: %s", id )
                end
            end

            if #open_questions == 0 then
                if data.out then
                    convo:Talk("TALK.OUT_OF_QUESTIONS")
                end
                return FinishQuestions()
            else
                local opt = convo:Opt("OPT_STOP_QUESTIONS")
                if data.stop then
                    opt:Talk("TALK.STOP_QUESTIONS")
                end
                opt:Fn( FinishQuestions ):Back()
            end

        end)
    end)
    return state
end

-- Retrieves the 'local' id for this convo
function ConvoState:GetFullStringID(id)
    return string.format( "%s.%s", self.id, id )
end

-- Returns the global locstring path
function ConvoState:GetLocPath(id)
    return self.convo:GetLocPath( self:GetFullStringID( id ))
end

function ConvoState:SetPriority(p)
    self.convo:SetPriority(p)
    return self
end

function ConvoState:Talk(...)
    local args = {...} -- need to pack for closure
    return self:Fn(function(cx)
        cx:Talk(table.unpack(args))
    end)
end

function ConvoState:TalkAndCompleteQuestObjective(...)
    local args = {...} -- need to pack for closure
    return self:Fn(function(cx)
        cx:Talk(table.unpack(args))
        cx:CompleteQuestObjective()
    end)
end


return ConvoState
