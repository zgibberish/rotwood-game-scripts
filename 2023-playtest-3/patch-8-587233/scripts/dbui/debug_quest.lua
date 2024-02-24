local DebugNodes = require "dbui.debug_nodes"
local DebugQuestManager = require "dbui.debug_questmanager"
local DialogParser = require "questral.util.dialogparser"
local Quest = require "questral.quest"
local contentutil = require "questral.util.contentutil"
local iterator = require "util.iterator"
local lume = require "util.lume"
local rotwoodquestutil = require "questral.game.rotwoodquestutil"


-------------------------------------------------------------------------------------
-- Debug panel for a single quest.

local DebugQuest = Class(DebugNodes.DebugNode, function(self, ...) self:init(...) end)


DebugQuest.MENU_BINDINGS = {
	DebugQuestManager.QUEST_MENU,
}


function DebugQuest:init(quest)
	DebugNodes.DebugNode._ctor(self, "Debug Quest")
	if quest then
		self:InspectQuest(quest)
	end
	-- else, must call InspectQuest.
end

-------
-- Quest Menu API
function DebugQuest:_GetPlayer()
	if not self.quest:is_class() then
		return self.quest:GetQuestManager():GetQC():GetPlayer()
	end
end
-- /end API

function DebugQuest:InspectQuest(quest)
	if type(quest) == "string" then
		local qm = rotwoodquestutil.Debug_GetQuestManager()
		local candidate = qm:FindQuestByID(quest)
		if candidate then
			quest = candidate
		else
			quest = contentutil.GetContentDB():Get(Quest, quest)
		end
	end
	-- For some reason this validation doesn't pass quest classes.
	-- assert(Class.IsClassOrInstance(quest)
	-- 	and (quest:is_a(Quest)
	-- 	or Quest.is_instance(quest)), "Unknown quest.")
	self.quest = quest
end

function DebugQuest:RenderPanel( ui, panel )
	assert(self.quest, "Pass a quest to ctor or call InspectQuest.")
	panel:AppendTable( ui, self.quest.def, "Def" )

	if not self.quest:is_class() then
		self:_RenderQuestInstance(ui, panel)
	end

	self:AddFilteredAll(ui, panel, self.quest)
end

function DebugQuest:_RenderQuestInstance(ui, panel)
	ui:Value("Owning Player", self:_GetPlayer())

	ui:Text( string.format( "%s (Rank %d)", self.quest:GetContentID(), self.quest:GetRank()) )

	if self.quest:GetTimeLeft() then
		ui:Text( string.format( "Time Left: %d cycles", self.quest:GetTimeLeft() ))
	end

	ui:TextColored( Quest.GetStatusColour(self.quest:GetStatus()), self.quest:GetStatus() )

	if self.quest:IsActive() then
		ui:SameLine(0, 10)
		if ui:Button("Cancel") then
			self.quest:Cancel()
		end
		ui:SameLine(0, 10)
		if ui:Button("Complete") then
			self.quest:Complete()
		end
		ui:SameLine(0, 10)
		if ui:Button("Fail") then
			self.quest:Fail()
		end
	end

	local function InQuestConvo(actor, objective_id)
		return (actor
			and actor.inst
			and actor.inst.components.conversation
			and actor.inst.components.conversation:IsInQuestConvo(self.quest, objective_id))
	end

	if ui:CollapsingHeader("Cast") then
		ui:Columns( 2 )

		-- ui:SetColumnOffset( 1, 100 )

		for id, cast_def in iterator.sorted_pairs(self.quest.def.cast) do
			local cast = self.quest:GetCastMember( id )

			panel:AppendTable( ui, cast_def, id )
			if InQuestConvo(cast) then
				ui:SameLineWithSpace()
				ui:Text(ui.icon.convo)
			end
			ui:NextColumn()

			if cast == nil then
				ui:TextColored( WEBCOLORS.LIGHTSTEELBLUE, "uncast" )
			else
				panel:AppendTable( ui, cast )
			end
			ui:NextColumn()
		end
		ui:Columns( 1 )
	end

	if next(self.quest.param) ~= nil and ui:CollapsingHeader("Params") then
		panel:AppendKeyValues( ui, self.quest.param )
	end

	local objectives = self.quest.def.objective
	if next(objectives) ~= nil and ui:CollapsingHeader("Objectives", ui.TreeNodeFlags.DefaultOpen) then

		local cast_in_convo = lume.match(self.quest.cast_members, InQuestConvo)

		ui:Columns( 2 )
		-- ui:SetColumnOffset( 1, 100 )

		for id, objective_def in iterator.sorted_pairs( objectives ) do
			local state = self.quest:GetObjectiveState(id)

			ui:PushStyleColor( ui.Col.Text, Quest.GetStatusColour(state))
			panel:AppendTable( ui, objective_def, id )
			ui:PopStyleColor()

			if InQuestConvo(cast_in_convo, id) then
				ui:SameLineWithSpace()
				ui:Text(ui.icon.convo)
			end

			ui:NextColumn()

			local changed, new_debug_status = ui:ComboAsString("##state_"..id, state, QUEST_OBJECTIVE_STATE:Ordered())
			if changed then
				self.quest:SetObjectiveState(id, new_debug_status)
			end
			ui:NextColumn()
		end
		ui:Columns( 1 )
	end

	local triggers = self.quest._class.def.scenario_triggers
	if #triggers > 0 and ui:CollapsingHeader("Scenario Triggers") then
		ui:Columns( 2 )

		for k,v in ipairs(triggers) do
			local id = v.id
			local state = self.quest.scenario_state and self.quest.scenario_state.trigger_states[id]
				if state then
					panel:AppendTable( ui, state, id )
				else
					ui:Text(id)
				end
			ui:NextColumn()
			local count = state and state.count or 0
			ui:Text(count)
			ui:NextColumn()
		end

		ui:Columns( 1 )

	end


	if #self.quest.log > 0 and ui:CollapsingHeader("Log", ui.TreeNodeFlags.DefaultOpen) then
		ui:Text(table.concat(self.quest.log, "\n"))
	end

	if ui:CollapsingHeader("Quest Writing Reference") then
		ui:TextWrapped(DialogParser.help_text)
	end

	if self.quest.RenderDebugPanel then
		if ui:CollapsingHeader("Custom") then
			self.quest:RenderDebugPanel( ui, panel )
		end
	end
end


DebugNodes.DebugQuest = DebugQuest
return DebugQuest
