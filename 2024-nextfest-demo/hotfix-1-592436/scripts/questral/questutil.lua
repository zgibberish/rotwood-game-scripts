local krandom = require "util.krandom"


local QuestUtil = {}

function QuestUtil.IsAgentValidForQuest(agent, quest)

    if agent:IsCastInQuest() then
        return false
    end

    return true
end

function QuestUtil.PickCastAgent(quest, agent_list, score_fn)
    local best = {}
    local best_score = nil
    for _, agent in ipairs(agent_list) do
        if QuestUtil.IsAgentValidForQuest(agent, quest) then
            local score
            if score_fn then
                score = score_fn(agent, quest)
            else
                score = 0
            end
            if score then
                if not best_score then
                    table.insert(best, agent)
                    best_score = score
                elseif best_score == score then
                    table.insert(best, agent)
                elseif score > best_score then
                    table.clear(best)
                    table.insert(best, agent)
                    best_score = score
                end
            end
        end
    end

    if #best > 0 then
        return krandom.PickFromArray(best)
    end
end


return QuestUtil