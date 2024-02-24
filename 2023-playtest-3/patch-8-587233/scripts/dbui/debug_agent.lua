--~ local CmpAgentHistory = require "sim.components.agent.cmpagenthistory"
--~ local Condition = require "sim.condition"
local Agent = require "questral.agent"
local DebugNodes = require "dbui.debug_nodes"
local DebugQuestManager = require "dbui.debug_questmanager"
local Quest = require "questral.quest"
local iterator = require "util.iterator"
local qconstants = require "questral.questralconstants"

-------------------------------------------------------------------

local DebugAgent = Class(DebugNodes.DebugNode, function(self, ...) self:init(...) end)

DebugAgent.REGISTERED_CLASS = Agent
DebugAgent.MENU_BINDINGS = {
	DebugQuestManager.QUEST_MENU,
}


local DBG = d_view

local function CreateQuestMenu( quest_type, role_property )
    return function( self, dbg, ui, agent )
        local db = dbg:GetDebugEnv().db
        local role_data = agent:GetFactionRoleData()
        if ui:MenuItem( "-None-" ) then
            while agent:GetQuestOfType( quest_type ) do
                agent:GetQuestOfType( quest_type ):Cancel()
            end

        else
            ui:Separator()

            for _, id, quest_class in iterator.sorted_pairs( db:GetAll( Quest )) do
                if quest_class:GetType() == quest_type then
                    local menu_txt = quest_class._classname
                    if Class.isInstance( agent:GetQuestOfType( quest_type ), quest_class ) then
                        ui:PushStyleColor( ui.Col.Text, WEBCOLORS.GREEN )
                    elseif role_data and role_data[ role_property ] and table.contains( role_data[ role_property ], quest_class._classname ) then
                        ui:PushStyleColor( ui.Col.Text, WEBCOLORS.WEBCOLORS.DARKTURQUOISE )
                    else
                        ui:PushStyleColor( ui.Col.Text, WEBCOLORS.WHITE )
                    end
                    if ui:MenuItem( menu_txt ) then
                        -- Cancel existing trial.
                        while agent:GetQuestOfType( quest_type ) do
                            agent:GetQuestOfType( quest_type ):Cancel()
                        end
                        local cast_assignments = { giver = agent }
                        local quest, err = dbg:GetDebugEnv().sim:GetQuestManager():SpawnQuest( id, agent:GetRank(), nil, cast_assignments )
                        DBG{ quest, err }
                    end
                    ui:PopStyleColor()
                end
            end
        end
    end
end

--~ DebugAgent.MENU_BINDINGS = table.arrayconcat( DebugNodes.DebugNode.MENU_BINDINGS,
--~ {
--~     {
--~         name = "Agent",
--~         {
--~             Text = "Talk To...",
--~             Enabled = function( self, dbg, agent )
--~                 return Class.isInstance( dbg:GetDebugEnv().screen, require "ui.screens.tacticalscreen" )
--~             end,
--~             Do = function( self, dbg, agent )
--~                 local convo_state, quest, speaker = dbg:GetDebugEnv().sim:GetQuestManager():EvaluateHook(Quest.CONVO_HOOK.ATTRACT, agent)
--~                 if convo_state == nil then
--~                     convo_state = dbg:GetDebugEnv().db:GetConvo("convo_default_attract"):GetDefaultState()
--~                 end
--~                 if convo_state then
--~                     local ScenarioConvoScreen = require "ui.screens.scenarioconvoscreen"
--~                     local screen = ScenarioConvoScreen( dbg:GetDebugEnv().game, convo_state, quest, agent )
--~                     dbg:GetDebugEnv().fe:InsertScreen( screen )
--~                 end
--~             end
--~         },
--~         {
--~             Text = "Assign Job",
--~             Visible = function( self, dbg, agent )
--~                 return not agent:IsPlayer()
--~             end,
--~             CustomMenu = CreateQuestMenu( Quest.QUEST_TYPE.JOB, "jobs" )
--~         },
--~         {
--~             Text = "Assign Trial",
--~             Visible = function( self, dbg, agent )
--~                 return not agent:IsPlayer()
--~             end,
--~             CustomMenu = CreateQuestMenu( Quest.QUEST_TYPE.TRIAL, "trials" )
--~         },
--~         {
--~             Text = "Assign Boon",
--~             Visible = function( self, dbg, agent )
--~                 return not agent:IsPlayer()
--~             end,
--~             CustomMenu = function( self, dbg, ui, agent )
--~                 local Boon = require "sim.boon"
--~                 local role_data = agent:GetFactionRoleData()
--~                 if ui:MenuItem( "-None-" ) then
--~                     local boon = agent:GetBoon()
--~                     if boon then
--~                         boon:Detach()
--~                     end
--~                 else
--~                     for i, boon_class in pairs( Class.getTerminalSubclasses( Boon )) do
--~                         local menu_txt = boon_class._classname
--~                         if Class.isInstance( agent:GetBoon(), boon_class ) then
--~                             ui:PushStyleColor( ui.Col.Text, HexToRGB(0x00FF00FF) )
--~                         elseif role_data and role_data.boons and table.contains( role_data.boons, boon_class._classname ) then
--~                             ui:PushStyleColor( ui.Col.Text, HexToRGB(0x00CCCCFF) )
--~                         else
--~                             ui:PushStyleColor( ui.Col.Text, HexToRGB(0xFFFFFFFF) )
--~                         end
--~                         if ui:MenuItem( menu_txt ) then
--~                             local boon = agent:GetBoon()
--~                             if boon then
--~                                 boon:Detach()
--~                             end
--~                             boon = boon_class()
--~                             agent:AttachChild( boon )
--~                         end
--~                         ui:PopStyleColor()
--~                     end
--~                 end
--~             end
--~         },
--~         {
--~             Text = function( self, dbg, agent )
--~                 return string.format( "%s Available", agent:GetBoon()._classname )
--~             end,
--~             Visible = function( self, dbg, agent )
--~                 return agent:GetBoon() ~= nil
--~             end,
--~             Checked = function( self, dbg, agent )
--~                 return agent:GetBoon() and agent:GetBoon():IsAvailable()
--~             end,
--~             Do = function( self, dbg, agent )
--~                 if agent:GetBoon() then
--~                     agent:GetBoon():SetAvailable( not agent:GetBoon():IsAvailable() )
--~                 end
--~             end,
--~         },
--~         {
--~             Text = "Relationship",
--~             Visible = function( self, dbg, agent )
--~                 return not agent:IsPlayer()
--~             end,
--~             CustomMenu = function( self, dbg, ui, agent )
--~                 local idx = table.find( qconstants.RELATIONSHIP_ARRAY, agent:GetRelationship() )
--~                 local new_idx = ui:Combo( "Relationship", idx, qconstants.RELATIONSHIP_ARRAY )
--~                 if idx ~= new_idx then
--~                     local cmp = agent:GetComponent( CmpAgentHistory ) or agent:AddComponent( CmpAgentHistory() )
--~                     cmp:SetRelationship( qconstants.RELATIONSHIP_ARRAY[ new_idx ] )
--~                 end
--~             end,
--~         },

--~         {
--~             Text = "Clear History",
--~             Visible = function( self, dbg, agent )
--~                 return agent:GetComponent( CmpAgentHistory ) ~= nil
--~             end,
--~             Do = function( self, dbg, agent )
--~                 local cmp = agent:GetComponent( CmpAgentHistory )
--~                 agent:RemoveComponent( cmp )
--~             end
--~         },
--~         {
--~             Text = function( self, dbg, agent )
--~                 return string.format( "Pan To %s...", tostring(agent))
--~             end,
--~             Visible = function( self, dbg, agent )
--~                 return agent.inst ~= nil
--~             end,
--~             Do = function( self, dbg, agent )
--~                 dbg:GetDebugEnv().pan_to( agent.inst )
--~             end,
--~         }
--~     }
--~ })

function DebugAgent:init( agent )
	DebugNodes.DebugNode._ctor(self, "Debug Agent")
    self.agent = agent
end

function DebugAgent:RenderPanel( ui, panel, dbg )
    ui:Value("Agent", tostring(self.agent:GetTitleName()) )

    if self.agent:IsKilled() then
        ui:SameLine( nil, 20 )
        ui:TextColored( WEBCOLORS.RED, "DEAD" )
    end

    if self.agent:GetFaction() then
        ui:SameLine( nil, 20 )
        panel:AppendTable( ui, self.agent:GetFaction() )
    end

    ui:Separator()

    --~ if not self.agent:IsPlayer() then
    --~     local idx = table.find( qconstants.RELATIONSHIP_ARRAY, self.agent:GetRelationship() )
    --~     local new_idx = ui:Combo( "Relationship", idx, qconstants.RELATIONSHIP_ARRAY )
    --~     if idx ~= new_idx then
    --~         local cmp = self.agent:GetComponent( CmpAgentHistory ) or self.agent:AddComponent( CmpAgentHistory() )
    --~         cmp:SetRelationship( qconstants.RELATIONSHIP_ARRAY[ new_idx ] )
    --~     end
    --~ end

    --~ local current_money = self.agent:GetMoney()
    --~ local money = ui:InputInt( "Money", current_money, nil, 100 )
    --~ money = money and math.max( 0, money )
    --~ if money and money ~= current_money then
    --~     self.agent:DeltaMoney( money - current_money )
    --~ end

    --~ local current_intel = math.floor( self.agent:GetIntel())
    --~ local intel = ui:InputInt( "Intel", current_intel, nil, 100 )
    --~ intel = intel and math.max( 0, intel )
    --~ if intel and intel ~= current_intel then
    --~     self.agent:DeltaIntel( intel - current_intel )
    --~ end

    if false and ui:BeginMenu( "Conditions..." ) then
        if ui:BeginMenu( "Add Condition..." ) then
            for i, class in ipairs( Class.getTerminalSubclasses( Condition )) do
                if not self.agent:HasCondition(class) then
                    if ui:Selectable( class._classname, nil, ui.DontClosePopups ) then
                        self.agent:AddCondition( class )
                    end
                end
            end
            ui:EndMenu()
        end

        ui:Separator()

        if #self.agent:GetConditions() > 0 then
            ui:Columns( 4 )
            ui:SetColumnWidth( 0, 50 )
            ui:SetColumnWidth( 1, 200 )
            ui:SetColumnWidth( 2, 200 )
            ui:SetColumnWidth( 3, 80 )
            for k,condition in ipairs( self.agent:GetConditions() ) do
                ui:Image( condition:GetIcon(), 24, 24 )
                ui:NextColumn()
                ui:Text(condition:GetName())
                ui:NextColumn()
                local stacks = ui:InputInt( "Stacks", condition:GetStacks())
                if stacks and stacks > 0 then
                    condition:SetStacks(stacks)
                end
                ui:NextColumn()
                if ui:Button("Remove###CONDITION".. k) then
                    self.agent:RemoveCondition(condition._class)
                end
                ui:NextColumn()
            end
            ui:Columns( 1 )
            ui:Dummy( 600 )
        end
        ui:EndMenu()
    end

    ui:Separator()

	if ui:Button("View Entity", nil, nil, self.agent.inst == nil) then
		panel:PushNode(DebugNodes.DebugEntity(self.agent.inst))
	end

	self:AddFilteredAll(ui, panel, self.agent)
end

DebugNodes.DebugAgent = DebugAgent
return DebugAgent
