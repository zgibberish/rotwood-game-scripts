local loc = require "questral.util.loc"
--~ local AgentUtil = require "questral.agentutil"
local qconstants = require "questral.questralconstants"


local ConvoOption = Class(function(self, ...) self:init(...) end)
ConvoOption:add_mixin( require "questral.contentnode" )

-- Could specify dependencies here, but Rotwood uses icons very differently.
--~ ConvoOption:PreloadTextures{
--~     POSITIVE = "station_icons/stationicon_positive.tex",
--~     NEGATIVE = "station_icons/stationicon_negative.tex",
--~ }

ConvoOption:AddStrings{
    LACKS_MONEY = "{1.name} can't afford the full price -{2#money}",
    TT_REQ_FACTION_OPINION = "Requires {1} reputation of {2} (You have {3})",
    REQ_ITEM = "You don't have any {1}",

    SELLS_HEADER = "<b>Sells:</>",
    BUYS_HEADER = "<b>Buys:</>",
}

function ConvoOption:init(convoplayer, cxt, txt)
    -- cxt is a context created by the ConvoPlayer and is unrelated to cxt in
    -- quests.
    self.cxt = cxt
    self.convoplayer = convoplayer
    self.txt = txt
    self.fns = {}
    self.tooltips = {}
    self.open_fn_list = self.fns
    self.open_tooltips = self.tooltips
    local info = debug.getinfo(5, "Sl")
    self.id = info.short_src .. tostring( info.currentline )
end

function ConvoOption:SetID(id)
    dbassert(id)
    self.id = id
    return self
end

function ConvoOption:MakePositive()
    -- self:SetIcon(self:IMG"POSITIVE")
    return self
end

function ConvoOption:MakeOppo()
    self:SetRightText("<p img='images/ui_ftf_dialog/convo_quest.tex' color=0>")
    return self
end

function ConvoOption:SetSound(snd)
    self.sound = snd
    return self
end

function ConvoOption:MakeNegative()
    -- self:SetIcon(self:IMG"NEGATIVE")
    return self
end

function ConvoOption:MakeQuestion()
    return self:SetRightText("<p img='images/ui_ftf_dialog/convo_more.tex' color=0>")
end

function ConvoOption:MakeMap()
    return self:SetRightText("<p img='images/ui_ftf_dialog/convo_map.tex' color=0>")
end

function ConvoOption:MakeArmor()
    return self:SetRightText("<p img='images/ui_ftf_dialog/convo_armor.tex' color=0>")
end

function ConvoOption:MakeWeapon()
    return self:SetRightText("<p img='images/ui_ftf_dialog/convo_weapon.tex' color=0>")
end

function ConvoOption:MakeFood()
    return self:SetRightText("<p img='images/ui_ftf_dialog/convo_food.tex' color=0>")
end

function ConvoOption:MakePotion()
    return self:SetRightText("<p img='images/ui_ftf_dialog/convo_potions.tex' color=0>")
end

function ConvoOption:MakeItem()
    return self:SetRightText("<p img='images/ui_ftf_dialog/convo_item.tex' color=0>")
end

-- An action to perform when the option is picked. You can call this multiple
-- times and the actions are performed in order.
function ConvoOption:Fn(fn)
    assert( fn == nil or type(fn) == "function" )
    table.insert(self.open_fn_list, fn)
    return self
end

function ConvoOption:SetSubText(txt)
    self.sub_text = txt
    return self
end

function ConvoOption:SubText(id, ...)
    return self:SetSubText( id and self.convoplayer:GetString(id, ...))
end

function ConvoOption:Text(txt)
    self.txt = txt
    return self
end

function ConvoOption:ShowReward(rewards)

    self:AppendRawTooltip( rewards:GetString() )

    local inv = rewards:GetInventory()
    if inv then
        for i, item in ipairs( inv:GetItems() ) do
            self:AppendTooltipData( item )
        end
    end

    return self
end

function ConvoOption:SetAgentButton(agent)
    assert(not self.is_back, "Can't have back agent button.")
    self.agent_button_agent = agent
    return self
end

-- The current_selection is to auto-select that character, in case the player came back to this part of the convo
function ConvoOption:SetCharacterSelection(on_selection_change_fn, current_selection)
    self.character_selection_fn = on_selection_change_fn
    self.character_selection_current = current_selection
    return self
end

function ConvoOption:LearnLore( lore_id )
    local lore_entry = self:GetContentDB():TryGet( require "sim.loreentry", lore_id )
    if lore_entry == nil then
        LOGWARN( "Invalid lore_id in convo: %s", lore_id )
        return
    end

    self:AppendTooltip("TALK.LORE_TT", lore_entry:GetName())

    self:Fn(function(cx)
        cx:GrantLore( lore_id )
    end)
    return self
end

function ConvoOption:SpecialShop(sell_items, buy_items)
    self:SetRightText("<p img='images/ui_ftf_dialog/convo_item.tex' color=0>")

    if sell_items then
        local t = {self:LOC"SELLS_HEADER"}
        for k,v in ipairs(sell_items) do
            table.insert(t, loc.format("\t<i>{1}</>", v:GetName()))
        end
        self:AppendRawTooltip(table.concat(t, "\n"))
    end

    if buy_items then
    local t = {self:LOC"BUYS_HEADER"}
        for k,v in ipairs(buy_items) do
            table.insert(t, loc.format("\t<i>{1}</>", v:GetName()))
        end
        self:AppendRawTooltip(table.concat(t, "\n"))
    end

    self:Fn(function(cx)
        cx:DoSpecialShop(sell_items, buy_items)
    end)
end

function ConvoOption:LearnRandomLore( lore_category )
    self:AppendTooltip("TALK.RANDOM_LORE_TT" )

    self:Fn(function(cx)
        cx:GrantRandomLore( lore_category )
    end)
    return self
end

function ConvoOption:GiveReward(rewards)
    if self.convoplayer:GetHeader() ~= self.convoplayer:GetQuest() then
        self:ShowReward( rewards )
    end
    self:Fn(function(cx)
            rewards:Grant(cx.sim:GetPlayer())
            if rewards.boon then
                rewards.boon:SetAvailable( true )
                local state = rewards.boon:GetBoonConvo():GetDefaultState()
                cx:GoTo( state, nil, nil, rewards.boon )
            end
        end)
    return self
end

function ConvoOption:GivePlayerMoney(money)
    self:AppendTooltip( "TALK.GET_MONEY_TT", money )

    return self:Fn(function(convoplayer)
        convoplayer:GetPlayer():DeltaMoney( money )
    end)
end

function ConvoOption:GiveStatProgress( amt, category, params )
    if amt <= 0 then
        return self
    end

    local CmpCharacterStats = require "sim.components.agent.cmpcharacterstats"
    local cmp = self.convoplayer:GetPlayer():GetComponent( CmpCharacterStats )
    if cmp then
        self:AppendTooltip( "TALK.GET_STAT_PROGRESS_TT", amt, CmpCharacterStats:LOC( category ))

        return self:Fn(function(convoplayer)
            convoplayer:GrantStatProgress( amt, category, params )
        end)
    end
end

function ConvoOption:GiveItem(item)
    -- TODO: Not actually implemented yet, but I imagine this is how we could
    -- give the player weapons. Pass Equipment.Items.polearm_basic.

    -- reason must be a string key!
    local can_take, reason = item:CanPlayerTake(self.convoplayer:GetPlayer())

    if not can_take then
        self:Disable(reason)
    else
        self:AppendTooltip("TALK.GET_ITEM_TT", item)
        self:AppendTooltipData( item )
    end

    self:Fn(function(cx)
        item:GiveToPlayer(self.convoplayer:GetPlayer())
        cx:Talk("STRINGS.TALK.TALK_GAIN_ITEM", item)

        if item.BuildGetItemScreen then
            local screen = item:BuildGetItemScreen()
            if screen then
                TheFrontEnd:PushScreen( screen )
            end
        end
    end)

    return self
end

function ConvoOption:_DoSuccess(...)
    if self.on_success_fns then
        for k,v in ipairs(self.on_success_fns) do
            v(self.convoplayer, ...)
        end
    end
end

function ConvoOption:_DoFailure(...)
    if self.on_fail_fns then
        for k,v in ipairs(self.on_fail_fns) do
            v(self.convoplayer, ...)
        end
    end
end

function ConvoOption:OnSuccess(fn)
    assert(self.on_success_fns == nil)
    self.on_success_fns = {fn}
    self.open_fn_list = self.on_success_fns

    self.success_tooltips = {}
    self.open_tooltips = self.success_tooltips

    return self
end

function ConvoOption:OnFailure(fn)
    assert(self.on_fail_fns == nil)
    self.on_fail_fns = {fn}
    self.open_fn_list = self.on_fail_fns

    self.failure_tooltips = {}
    self.open_tooltips = self.failure_tooltips

    return self
end

function ConvoOption:DeliverItemInstance( item )
    error("Unimplemented")
    --~ assert( item )
    --~ local items = AgentUtil.CollectLocalItems( self.convoplayer:GetPlayer(), function( v ) return item._class.is_instance(v) and (v:GetRank() or 0) >= (item:GetRank() or 0) end )
    --~ self:AppendTooltip( "TALK.DELIVER_ITEM_TT", item:GetName(), 1, #items )

    --~ return self:Fn(function(convoplayer)
    --~     item:Detach()
    --~     local agent = self.convoplayer:GetAgent()
    --~     if agent then
    --~         agent:ReceiveQuestItem(item)
    --~     end

    --~ end )
end

function ConvoOption:DeliverItem( item_class, amount, rank )
    error("Unimplemented")
    --~ assert(Class.IsClass(item_class))

    --~ amount = amount or 1

    --~ local items = AgentUtil.CollectLocalItems( self.convoplayer:GetPlayer(), function( item ) return item_class.is_instance(item) and (rank == nil or item:GetRank() >= rank) end )
    --~ local current_amount = #items

    --~ if current_amount < amount then
    --~     self:Disable( "TALK.REQ_ITEM_TT", item_class:GetName( rank ), amount, current_amount )
    --~ else
    --~     self:AppendTooltip( "TALK.REQ_ITEM_TT", item_class:GetName( rank ), amount, current_amount )
    --~ end
    --~ return self:Fn(function(convoplayer)
    --~     for i, item in ipairs(items) do
    --~         amount = amount - 1
    --~         if amount < 0 then
    --~             break
    --~         end
    --~         item:Detach()
    --~     end
    --~ end )
end

function ConvoOption:ReqStat( category, rank )
    local player = self.convoplayer:GetPlayer()
    local CmpCharacterStats = require "sim.components.agent.cmpcharacterstats"
    local stats = player:GetComponent(CmpCharacterStats)
    local stat_rank = stats:GetProgress(category)
    if stat_rank < rank then
        self:Disable( "TALK.REQ_STATCHECK", CmpCharacterStats:LOC(category), rank, stat_rank )
    else
        self:SubText( loc.format( LOC "TALK.DELIVER_STATCHECK", CmpCharacterStats:LOC(category), rank))
    end
    return self
end

function ConvoOption:CompleteQuest()
    return self:Fn(function()
            self.cxt.quest:Complete()
        end)
end

-- Choosing this option will complete the input or current objective.
function ConvoOption:CompleteObjective(id)
    return self:Fn(function()
        self.convoplayer:CompleteQuestObjective(id)
    end)
end

function ConvoOption:MarkWithQuests(quests)
    assert(quests)
    if quests then
        for k,v in ipairs(quests) do
            self:MarkWithQuest(v)
        end
    end
    return self
end

function ConvoOption:MarkWithQuest(quest)
    self.quests = self.quests or {}
    table.insert_unique(self.quests, quest or self.cxt.quest)
    return self
end

function ConvoOption:GetQuestMarks()
    return self.quests
end

function ConvoOption:MarkAsNew()
    self.is_new = true
    return self
end

function ConvoOption:SetQuestNode(node)
    if node then
        local quest_marks = node:GetQC():GetQuestManager():CollectMarksForNode(node)
        if #quest_marks > 0 then
            for _, quest in ipairs(quest_marks) do
                self:MarkWithQuest(quest)
            end
        end
    end
    return self
end

function ConvoOption:GrantOpinionIf(condition, ...)
    if condition then
        self:GrantOpinion(...)
    end
    return self
end

function ConvoOption:GrantOpinion(opinion_id, who, params)
    local event
    if self.cxt.quest then
        event = self.cxt.quest:GetOpinionEvent(opinion_id)
    else
        local OpinionEvent = require "sim.opinionevent"
        event = OpinionEvent.GetEvent(opinion_id)
    end

    assert(event, "Opinion event does not exist: " .. tostring(opinion_id))
    who = who or self.convoplayer:GetAgent()

    local CmpRelationships = require "sim.components.agent.cmprelationships"
    local str = self.convoplayer:GetPlayer():GetComponent(CmpRelationships):GetChangeString( event:GetContentID(), who )
    if str then
        self:AppendRawTooltip( str )
    end

    return self:Fn(function()
        who:AddOpinion( event:GetContentID(), params )
    end)
end

function ConvoOption:ReqFactionOpinion( amt, faction )
    faction = faction or self.convoplayer:GetAgent():GetFaction()
    local reputation = faction:GetReputation()
    return self:_ReqConditionRaw(reputation >= amt, loc.format(self:LOC"TT_REQ_FACTION_OPINION", faction:GetName(), amt, reputation))
end

function ConvoOption:GrantFactionOpinion( delta, faction )
    faction = faction or self.convoplayer:GetAgent():GetFaction()

    self:AppendTooltip( "TALK.GET_FACTION_OPINION_TT", faction, delta )

    return self:Fn(function(cx)
        faction:DeltaPlayerOpinion( delta )
        cx:Talk( delta > 0 and "STRINGS.TALK.TALK_GAIN_FACTION_OPINION" or "STRINGS.TALK.TALK_LOSE_FACTION_OPINION", faction )
    end)
end

-- Number of times this option was picked during this conversation. If we
-- reload/quit and come back, it resets to 0 (it's not saved). Options defined
-- in helper functions need to use SetID().
function ConvoOption:GetPickCount()
    return self.convoplayer.picked_options[self.id] or 0
end
-- Has the user picked this option before during this session? Only valid when
-- called from within an Opt's Fn (where picked will be at least 1).
function ConvoOption:HasPreviouslyPickedOption()
    return self:GetPickCount() > 1
end

-- After user's picked this option, disable it when displayed again in the same
-- session.
function ConvoOption:JustOnce()
    self.show_once = true
    return self
end

function ConvoOption:IsEnabled()
    if self.show_once and self.convoplayer.picked_options[self.id] then
        return false
    end

    if self.disabled then
        return false
    end

    return true
end

function ConvoOption:Disable( reason_txt, ... )
    self.disabled = true
    if reason_txt then
        self:AppendTooltip( reason_txt, ... )
    end

    return self
end

function ConvoOption:AppendRawTooltip( txt )
    table.insert( self.open_tooltips, txt )
    return self
end

function ConvoOption:AppendTooltip( tt, ... )
    local txt = self.convoplayer:GetString(tt, ...)
    self:AppendRawTooltip( txt )
    return self
end

function ConvoOption:AppendTooltipData( t )
    table.insert( self.open_tooltips, t )
    return self
end

function ConvoOption:GetTooltips()
    return self.tooltips or table.empty
end

function ConvoOption:GetFailureTooltips()
    return self.failure_tooltips or table.empty
end

function ConvoOption:GetSuccessTooltips()
    return self.success_tooltips or table.empty
end

function ConvoOption:ReqCondition( condition, txt, ... )
    if self.open_fn_list == self.fns then
        if not condition then
            self:Disable( txt, ... )
        end
    end
    return self
end

function ConvoOption:_ReqConditionRaw( condition, txt )
    if self.open_fn_list == self.fns then
        if not condition then
            self:Disable()
            if txt then
                self:AppendRawTooltip(txt)
            end
        end
    end
    return self
end

function ConvoOption:TestCooldown( mem, time, tt )
    time = time or 1
    tt = tt or "TALK.TT_TOO_SOON"

    self:ReqCondition( not self.convoplayer:GetAgent():TestMemory(mem, time), tt)
    return self
end

function ConvoOption:AgentCooldown( mem, time, tt )
    self:TestCooldown( mem, time, tt )

    return self:Fn(function(cx)
            cx:GetAgent():Remember(mem)
        end)
end

function ConvoOption:Priority( priority )
    -- Higher priority options come first.
    self.priority = priority
    return self
end

function ConvoOption:GetPriority()
    return self.priority or 0
end

function ConvoOption:ReqMemory( token, time_since_test, txt, ... )
    local duration = self.convoplayer:GetAgent():GetTimeSinceMemory( token )
    if duration ~= nil then
        self:ReqCondition( duration >= time_since_test, txt, time_since_test - duration, ... )
    end
    return self
end


function ConvoOption:ReqFriendly()
    if self.open_fn_list ~= self.fns then
        return self
    end

    if not self.convoplayer:GetAgent():IsFriendly() and not self.convoplayer:IsGodMode() then
        self:Disable( "TALK.REQ_FRIENDLY_TT", self.convoplayer:GetAgent() )
    end
    return self
end

function ConvoOption:ReqUnfriendly()
    if self.open_fn_list ~= self.fns then
        return self
    end

    if not self.convoplayer:GetAgent():IsUnfriendly() and not self.convoplayer:IsGodMode() then
        self:Disable( "TALK.REQ_UNFRIENDLY_TT", self.convoplayer:GetAgent() )
    end
    return self
end

-- Not necessarily friendly, could be neutral.
function ConvoOption:ReqNotUnfriendly()
    if self.open_fn_list ~= self.fns then
        return self
    end

    if self.convoplayer:GetAgent():IsUnfriendly() and not self.convoplayer:IsGodMode() then
        self:Disable( "TALK.REQ_NOT_UNFRIENDLY_TT", self.convoplayer:GetAgent() )
    end
    return self
end

function ConvoOption:ReqScrap( amount )

    local scrap = self.convoplayer:GetPlayer():GetScrap()
    if self.open_fn_list == self.fns and scrap < amount then
        self:Disable( "TALK.REQ_SCRAP_TT", amount )
    elseif amount > 0 then
        self:AppendTooltip( "TALK.REQ_SCRAP_TT", amount )
    end
    return self
end

function ConvoOption:ReqMoney( amount )

    local money = self.convoplayer:GetPlayer():GetMoney()
    if self.open_fn_list == self.fns and money < amount then
         self:Disable( "TALK.REQ_MONEY_TT", amount )
    elseif money > 0 then
        self:AppendTooltip( "TALK.REQ_MONEY_TT", amount )
    end
    return self
end

function ConvoOption:ReqCapacity( capacity, tags )
    -- TODO: Not actually implemented yet.
    return self.convoplayer:GetPlayer():HasCapacity(capacity, tags)
end


function ConvoOption:BuyItem( item, price_override )
    error("Unimplemented")

--~     local price, details = AgentUtil.CalculateBuyItemFromAgentPrice(self.convoplayer:GetAgent(), item, self.convoplayer:GetPlayer(), price_override)

--~     if self.convoplayer:GetAgent() then
--~         local rate
--~         rate, details = self.convoplayer:GetPlayer():PreviewAccumulatedValue( qconstants.MODS.ITEM_BUY_RATE, 1, self.convoplayer:GetAgent(), price )
--~         price = math.round(price*rate)
--~     end

--~     self:ReqMoney( price )
--~     if details then
--~         for k,v in ipairs(details) do
--~             self:AppendRawTooltip(v)
--~         end
--~     end

--~     self:GiveItem( item )

--~     return self:Fn(function()
--~                 if self.convoplayer:GetAgent() then
--~                     self.convoplayer:GetAgent():DeltaMoney(price)
--~                 end
--~                 self.convoplayer:GetPlayer():DeltaMoney(-price)
--~             end)
end

function ConvoOption:SellItem( item_class, rank, ignore_money )
    error("Unimplemented")

--~     local items = AgentUtil.CollectLocalItems( self.convoplayer:GetPlayer(),
--~                                                 function( item )
--~                                                         return item_class.is_instance(item) and (rank == nil or item:GetRank() >= rank)
--~                                                 end )

--~     local price, details = AgentUtil.CalculateSellItemToAgentPrice(self.convoplayer:GetAgent(), items[1] or item_class, self.convoplayer:GetPlayer())
--~     local money = self.convoplayer:GetAgent():GetMoney()
--~     if not ignore_money then
--~         if money < price then
--~             table.insert(details, loc.format(self:LOC"LACKS_MONEY", self.convoplayer:GetAgent(), price - money))
--~             price = money
--~         end
--~     end


--~     self:_ReqConditionRaw(#items > 0, loc.format(self:LOC"REQ_ITEM", item_class:GetName()))

--~     self:GivePlayerMoney( price )
--~     if details then
--~         for k,v in ipairs(details) do
--~             self:AppendRawTooltip(v)
--~         end
--~     end

--~     if #items > 0 then
--~         self:DeliverItemInstance( items[1] )
--~     end

--~     return self:Fn(function()
--~                 if self.convoplayer:GetAgent() and not ignore_money then
--~                     self.convoplayer:GetAgent():DeltaMoney(-price)
--~                 end
--~             end)
end

function ConvoOption:DeltaTether(delta)
    if delta > 0 then
        self:AppendTooltip("TALK.GAIN_TETHER_TT", delta)
    else
        self:AppendTooltip("TALK.LOSE_TETHER_TT", delta)
    end
    return self:Fn(function()
        self.convoplayer:DeltaTether(delta)
    end)
end

--gets modified by opinion, etc.
function ConvoOption:GetPaidMoney( nominal_amount )

    local price, details = nominal_amount
    if self.convoplayer:GetAgent() then
        price, details = self.convoplayer:GetPlayer():PreviewAccumulatedValue( qconstants.MODS.GET_PAID_MONEY, nominal_amount, self.convoplayer:GetAgent(), nominal_amount )
    end

    price = math.round(price)

    self:AppendTooltip( "TALK.GET_MONEY_MODIFIED_TT", price, nominal_amount )

    if details then
        for k,v in ipairs(details) do
            self:AppendRawTooltip(v)
        end
    end

    return self:Fn(function()
                if self.convoplayer:GetAgent() then
                    self.convoplayer:GetAgent():DeltaMoney(-price)
                end
                self.convoplayer:GetPlayer():DeltaMoney(price)
            end)
end


--gets modified by opinion, etc.
function ConvoOption:PayMoney( nominal_amount )
    if nominal_amount <= 0 then
        return self
    end

    local price, details = nominal_amount
    if self.convoplayer:GetAgent() then
        price, details = self.convoplayer:GetPlayer():PreviewAccumulatedValue( qconstants.MODS.PAY_MONEY, nominal_amount, self.convoplayer:GetAgent(), nominal_amount )
    end

    price = math.round(price)

    if price ~= nominal_amount then
        self:AppendTooltip( "TALK.PAY_MONEY_MODIFIED_TT", price, nominal_amount )
    end

    if self.open_fn_list == self.fns then
        self:ReqMoney( price )
    end

    if details then
        for k,v in ipairs(details) do
            self:AppendRawTooltip(v)
        end
    end

    return self:Fn(function()
                if self.convoplayer:IsGodMode() then
                    return
                end
                if self.convoplayer:GetAgent() then
                    self.convoplayer:GetAgent():DeltaMoney(price)
                end
                self.convoplayer:GetPlayer():DeltaMoney(-price)
            end)
end

--delivers an unmodified amount
function ConvoOption:DeliverMoney( amount )
    if amount <= 0 then
        return self
    end

    self:ReqMoney( amount )

    return self:Fn(function()
                if self.convoplayer:IsGodMode() then
                    return
                end
                if self.convoplayer:GetAgent() then
                    self.convoplayer:GetAgent():DeltaMoney(amount)
                end
                self.convoplayer:GetPlayer():DeltaMoney(-amount)
            end)
end

function ConvoOption:SetPercentChance(p)
    self.percent_chance = p
    return self
end

function ConvoOption:GetPercentChance()
    return self.percent_chance
end

function ConvoOption:SetRightText( right_text )
    self.right_text = right_text
    return self
end

function ConvoOption:Icon( tex_id )
    -- self:SetIcon( self.convoplayer:GetCurrentConvo():IMG( tex_id ) or self:IMG( tex_id ))
    return self
end

function ConvoOption:RelationshipIcon()
    -- local OpinionWidget = require "ui.widgets.opinionwidget"
    -- self:SetIcon( OpinionWidget:GetRelationshipIcon( self.convoplayer:GetAgent():GetRelationship() ))
    return self
end

function ConvoOption:SetHidden( is_hidden )
    self.is_hidden = is_hidden
    return self
end

function ConvoOption:IsHidden()
    return self.is_hidden == true
end

function ConvoOption:DeliverIntel( amount )
    local intel = self.convoplayer:GetPlayer():GetIntel()

    if intel < amount then
        self:Disable( "TALK.REQ_INTEL_TT", amount )
    else
        self:AppendTooltip( "TALK.REQ_INTEL_TT", amount )
    end

    return self:Fn(function()
            self.convoplayer:GetAgent():DeltaIntel(amount)
            self.convoplayer:GetPlayer():DeltaIntel(-amount)
        end)
end

function ConvoOption:Back()
    assert(not self.is_lower, "Is already lower. Can't be both.")
    assert(not self.agent_button_agent, "Can't have back agent button.")
    self.is_back = true
    return self
end

function ConvoOption:Lower()
    assert(not self.is_back, "Is already back. Can't be both.")
    assert(not self.agent_button_agent, "Can't have back lower button.")
    self.is_lower = true
    return self
end

function ConvoOption:Talk(...)
    local args = {...}
    return self:Fn(function(cx)
        cx:Talk(table.unpack(args))
    end)
end

function ConvoOption:Quip( speaker, ... )
    local tags = {...}
    return self:Fn(function(cx)
        cx:Quip( speaker, tags )
    end)
end

--create wrappers for action calls
local fns = {"End", "Exit", "GoTo", "Close", "EndLoop", "Loop"}
for k,v in ipairs(fns) do
    ConvoOption[v] = function(self, ...)
        local args = {...}
        return self:Fn(function(convoplayer)
                        convoplayer[v](convoplayer, table.unpack(args))
                    end)
    end
end


return ConvoOption
