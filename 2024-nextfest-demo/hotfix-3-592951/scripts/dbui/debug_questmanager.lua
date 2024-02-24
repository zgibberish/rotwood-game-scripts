local DebugNodes = require "dbui.debug_nodes"
local DebugSettings = require "debug.inspectors.debugsettings"
local Enum = require "util.enum"
local Npc = require "components.npc"
local NpcAutogenData = require "prefabs.npc_autogen_data"
local Quest = require "questral.quest"
local contentutil = require "questral.util.contentutil"
local iterator = require "util.iterator"
local lume = require "util.lume"
local playerutil = require "util.playerutil"
local rotwoodquestutil = require "questral.game.rotwoodquestutil"


-------------------------------------------------------------------------------------
-- Debug panel for the manager of quests.

local SORT = Enum{ "BY_ID", "BY_TYPE", "BY_STATUS" } -- always stored by id instead of string.
local DebugQuestManager = Class(DebugNodes.DebugNode, function(self, ...) self:init(...) end)

DebugQuestManager.PANEL_WIDTH = 650
DebugQuestManager.PANEL_HEIGHT = 1000



local function GetPlayerFromPanel(panel)
	local current_node = panel:GetNode()
	local player = nil
	if current_node and current_node._GetPlayer then
		player = current_node:_GetPlayer()
	end
	return player or ConsoleCommandPlayer()
end

-- Common menu shared by all quest system debug.
DebugQuestManager.QUEST_MENU = {
	name = "Quest",
	bindings = {
		-- Global
		{
			name = "View CastManager",
			fn = function(params)
				params.panel:PushNode(DebugNodes.DebugCastManager())
			end,
		},

		-- Per player
		{ separator = true, },
		{
			name = "View QuestCentral",
			fn = function(params)
				local player = GetPlayerFromPanel(params.panel)
				local new_node = DebugNodes.DebugTable(player.components.questcentral, "QuestCentral")
				params.panel:PushNode(new_node)
			end,
		},
		{
			name = "View QuipMatcher",
			fn = function(params)
				local player = GetPlayerFromPanel(params.panel)
				local matcher = player.components.questcentral.quipmatcher
				params.panel:PushDebugValue(matcher)
			end,
		},
		{
			name = "View QuestManager",
			fn = function(params)
				local player = GetPlayerFromPanel(params.panel)
				local qman = player.components.questcentral:GetQuestManager()
				local new_node = params.panel:CreateDebugNode(qman)
				params.panel:PushNode(new_node)
			end,
		},
	},
}
DebugQuestManager.MENU_BINDINGS = {
	DebugQuestManager.QUEST_MENU,
}


local DBG = d_view

function DebugQuestManager:init(questmanager)
	DebugNodes.DebugNode._ctor(self, "Debug Quest Manager")
	questmanager = questmanager or rotwoodquestutil.Debug_GetQuestManager()
	if questmanager then
		self:_AssignQuestManager(questmanager)
	end
	self.opts = DebugSettings("DebugQuestManager.opts")
		:Option("spawn_filter_str", "")
		:Option("spawn_filter_unique", false)
end

-------
-- Quest Menu API
function DebugQuestManager:_GetPlayer()
	local questcentral = self.questmanager:GetQC()
	local player = questcentral:GetPlayer()
	return player
end
-- /end API

function DebugQuestManager:_ClearQuestManager()
	if not self.questmanager then
		return
	end
	self:_ClearTalker()
	self.quest_spawn = nil
	self.failed_quest_spawn = nil
	self.questmanager = nil
end

function DebugQuestManager:_AssignQuestManager(questmanager)
	assert(self.questmanager == nil, "Test changing questmanager works. May need to deregister some stuff?")
	assert(questmanager)
	self.questmanager = questmanager
	self.spawn_quests = {}
	self.all_quest_defs = contentutil.GetContentDB():GetFiltered(Quest, function(v)
		return v ~= Quest
	end)
	self.spawn_quest_params = { debug = true }

	self.on_remove_npc_talker = function()
		local player = self:_GetPlayer()
		self.npc_talker.components.conversation:Debug_ForceEndConvo(player)
		self.npc_talker = nil
		self.talk_err_msg = nil
		if self.talk_quest then
			self.talk_quest:Debug_Cancel()
			self.talk_quest = nil
		end
	end
end

function DebugQuestManager.CanBeOpened()
	-- Don't require QuestManager because since it's on players, it won't exist
	-- when we try to re-open sticky windows. Instead, we're restart with the
	-- default debug player's QuestManager.
	return TheWorld ~= nil
end

function DebugQuestManager:OnActivate( panel )
	if self.questmanager then
		self:LoadQuestSettings( panel.dbg )
	end
	TheInput:SetEditMode(self, true) -- ConvoTester spawns npcs
end

function DebugQuestManager:OnDeactivate(panel)
	self:_ClearTalker()
	TheInput:SetEditMode(self, false)
end

function DebugQuestManager:RenderPanel( ui, panel )
	if not self.questmanager then
		ui:Text("Can't find QuestManager.")
		local questmanager = rotwoodquestutil.Debug_GetQuestManager()
		if questmanager then
			self:_AssignQuestManager(questmanager)
			self:OnActivate(panel)
		end
		return
	end

	local player = self:_GetPlayer()
	ui:Value("Owning Player", player)
	ui:SameLineWithSpace()
	local next_player = playerutil.GetNextPlayer(player, true)
	if ui:Button(ui.icon.playback_step_fwd, ui.icon.width, nil, next_player == nil) then
		self:_ClearQuestManager()
		local questcentral = next_player.components.questcentral
		self:_AssignQuestManager(questcentral:GetQuestManager())
	end

	ui:Separator()

	if ui:CollapsingHeader("Convo Tester") then
		ui:Indent()
		ui:PushID("Convo Tester")
		self:_RenderConvoTester(ui, panel)
		ui:Unindent()
		ui:PopID()
	end

	if ui:CollapsingHeader("Spawn") then

		self:RenderSpawnQuest(ui, panel)

		-- Save last quest selected, use on load.
		local changed1 = self.opts:SaveIfChanged("spawn_filter_str", ui:InputText("Filter", self.opts.spawn_filter_str or ""))
		local changed2 = self.opts:Toggle(ui, "Exclude Active", "spawn_filter_unique")
		if changed1 or changed2 then
			self:RefreshSpawnList()
		end

		ui:Columns( 2, "quests" )

		if ui:Selectable( "Type", false ) then
			self.spawn_sort_order = SORT.id.BY_TYPE
		end
		ui:NextColumn()
		if ui:Selectable( "ID", false ) then
			self.spawn_sort_order = SORT.id.BY_ID
		end
		ui:NextColumn()

		ui:Separator()

		self:RefreshSortOrder( self.spawn_quests, self.spawn_sort_order )
		for i, qdef in ipairs( self.spawn_quests ) do

			ui:TextColored( WEBCOLORS.ORCHID, qdef:GetType() or "???" )
			ui:NextColumn()

			local id = qdef:GetContentID()
			if ui:Selectable( id, self.spawn_quest_id == id ) then
				self:SelectQuest(id)
			end

			ui:NextColumn()
		end
		ui:Columns( 1, "reset" )
		ui:Separator()
		ui:TextColored( WEBCOLORS.DARKTURQUOISE, string.format( "%d quests shown", #self.spawn_quests ))
	end

	local active_quests = shallowcopy(self.questmanager:GetQuests())
	--~ local current_sector = dbg:GetDebugEnv().scenario and dbg:GetDebugEnv().scenario:GetSector()
	if ui:CollapsingHeader(string.format("Active Quests (%d)###Active Quests", #active_quests), ui.TreeNodeFlags.DefaultOpen) then
		ui:Columns( 3 )

		if ui:Selectable( "Quest###ACTIVEQUESTID", false ) then
			self.active_sort_order = SORT.id.BY_ID
		end
		ui:NextColumn()

		if ui:Selectable( "Type###ACTIVEQUESTTYPE", false ) then
			self.active_sort_order = SORT.id.BY_TYPE
		end
		ui:NextColumn()

		ui:Text( "Cast In World" )
		ui:SetTooltipIfHovered("Cast that are spawned in the current world.")
		ui:NextColumn()

		ui:Separator()

		self:RefreshSortOrder( active_quests, self.active_sort_order )
		for _, quest in ipairs(active_quests) do
			local function InQuestConvo(actor)
				return (actor
					and actor.inst
					and actor.inst.components.conversation
					and actor.inst.components.conversation:IsInQuestConvo(quest))
			end
			local local_cast = lume.filter(quest.cast_members, "inst", true)

			panel:AppendTable( ui, quest, quest:Debug_GetDebugName() )
			if lume.match(local_cast, InQuestConvo) then
				ui:SameLineWithSpace()
				ui:Text(ui.icon.convo)
			end

			ui:NextColumn()
			ui:Text(quest:GetType())
			ui:NextColumn()

			-- I don't think these are useful enough to show one on each line.
			ui:TextColored(WEBCOLORS.LIMEGREEN,
				table.concat(lume(local_cast)
						:keys()
						:sort()
						:result(), ", "))
			ui:NextColumn()
		end
		ui:Columns( 1 )
	end

	if ui:CollapsingHeader("Old Quests", ui.TreeNodeFlags.DefaultOpen) then
		local old_quests = shallowcopy( self.questmanager.old_quests )

		ui:Columns( 3 )
		ui:SetColumnWidth(0, ui:GetWindowSize()*.5)
		ui:SetColumnWidth(1, ui:GetWindowSize()*.25)
		ui:SetColumnWidth(2, ui:GetWindowSize()*.25)

		if ui:Selectable( "Quest###OLDQUESTID", false ) then
			self.old_sort_order = SORT.id.BY_ID
		end
		ui:NextColumn()

		if ui:Selectable( "Type###OLDQUESTTYPE", false ) then
			self.old_sort_order = SORT.id.BY_TYPE
		end
		ui:NextColumn()
		if ui:Selectable( "Type###OLDQUESTSTATUS", false ) then
			self.old_sort_order = SORT.id.BY_STATUS
		end
		ui:NextColumn()

		ui:Separator()

		self:RefreshSortOrder( old_quests, self.old_sort_order )
		for _, quest in ipairs(old_quests) do
			panel:AppendTable( ui, quest, quest:GetContentID() )
			ui:NextColumn()
			ui:Text(quest:GetType())
			ui:NextColumn()
			ui:TextColored( Quest.GetStatusColour(quest:GetStatus()), quest:GetStatus() )
			ui:NextColumn()
		end
		ui:Columns( 1 )
	end

	self:AddFilteredAll(ui, panel, self.questmanager)
end

local function SortQuest( q1, q2, sort_order )
	if sort_order == SORT.id.BY_ID then
		return q1:GetContentID() < q2:GetContentID()
	elseif sort_order == SORT.id.BY_TYPE then
		local at, bt = q1:GetType(), q2:GetType()
		if at == bt then
			return q1:GetContentID() < q2:GetContentID()
		else
			return at > bt
		end
	elseif sort_order == SORT.id.BY_STATUS then
		local at, bt = q1:GetStatus(), q2:GetStatus()
		if at == bt then
			return q1:GetContentID() < q2:GetContentID()
		else
			return at < bt
		end
	end

	return tostring(q1) < tostring(q2)
end

function DebugQuestManager:RefreshSortOrder( t, sort_order )
	table.sort( t, function( q1, q2 ) return SortQuest( q1, q2, sort_order or SORT.id.BY_TYPE ) end )
end

function DebugQuestManager:RefreshSpawnList()
	local filter_txt = self.opts.spawn_filter_str
	local require_unique = self.opts.spawn_filter_unique
	table.clear( self.spawn_quests )
	for _, qdef in ipairs( self.all_quest_defs ) do
		local id = qdef:GetContentID()
		local name_match = filter_txt == nil or id:upper():find(filter_txt:upper(), 1, true)
		local unique_match = not require_unique or not self.questmanager:FindQuestByID(id)
		if name_match
			and unique_match
		then
			table.insert( self.spawn_quests, qdef )
		end
	end

	self:RefreshSortOrder( self.spawn_quests, self.spawn_sort_order )

	if #self.spawn_quests == 1 then
		self:SelectQuest(self.spawn_quests[1]:GetContentID())
	end
end

function DebugQuestManager:SelectQuest(id)
	assert(id ~= "Quest", "Must select a quest subclass and not Quest itself.")
	self.spawn_quest_id = id
end

function DebugQuestManager:LoadQuestSettings( dbg )
	self:RefreshSpawnList()
end

function DebugQuestManager:RenderSpawnQuest( ui, panel )
	local qdef = self.spawn_quest_id and contentutil.GetContentDB():Get(Quest, self.spawn_quest_id)
	if not qdef then
		return
	end

	if self.quest_spawn then
		ui:Spacing()
		ui:TextColored( WEBCOLORS.LIMEGREEN, "Spawned:" )
		ui:SameLine( nil, 10 )
		panel:AppendTable( ui, self.quest_spawn )

	elseif self.failed_quest_spawn then
		ui:Spacing()
		ui:TextColored( WEBCOLORS.CRIMSON, "Failed spawn: " )
		ui:SameLine( nil, 10 )
		panel:AppendTable( ui, self.failed_quest_spawn )
	end

	ui:Separator()

	--~ local env = dbg:GetDebugEnv()

	local qrank_min, qrank_max = qdef:GetRankRange()
	local current_rank = math.clamp( self.spawn_quest_params.qrank or qrank_min, qrank_min, qrank_max )

	ui:PushStyleColor( ui.Col.Button, WEBCOLORS.FORESTGREEN )
	if ui:Button( "Spawn Quest" ) then
		local ok, quest, failed_quest = xpcall(
			self.questmanager.SpawnQuest, generic_error,
			self.questmanager,
			-- self.questmanager:SpawnQuest(
			self.spawn_quest_id, current_rank, self.spawn_quest_params, self.spawn_quest_assignments
			-- )
			)
		if not ok then
			DBG{ quest }
		else
			self.quest_spawn, self.failed_quest_spawn = quest, failed_quest

			if self.failed_quest_spawn then
				DBG(self.failed_quest_spawn)
			else
				self.quest_spawn:MarkAsDebug()
			end
		end
	end

	ui:PopStyleColor()

	ui:SameLine( nil, 20 )
	--~ if qdef:GetIcon() then
	--~	 ui:Image( qdef:GetIcon(), 24, 24 )
	--~	 ui:SameLine( nil, 10 )
	--~ end
	panel:AppendTable( ui, qdef, "Inspect Class: ".. qdef:GetContentID() )

	ui:Columns( 2 )
	for cast_id, cast_def in pairs( qdef.def.cast ) do
		ui:PushID( cast_id )
		if cast_def:IsRequiredAssignment() then
			ui:Text( cast_id .. " (required)" )
		else
			ui:Text( cast_id )
		end

		ui:NextColumn()

		local cast = self.spawn_quest_assignments and self.spawn_quest_assignments[ cast_id ]
		local txt = string.format( "%s##CAST_%s", tostring(cast), cast_id )
		if ui:Button( txt ) then
			ui:OpenPopup( "CAST_MENU" )
		end
		--~ if ui:BeginPopup( "CAST_MENU" ) then
		--~	 for k, v in pairs( env ) do
		--~		 if type(v) == "table" and not strict.is_strict( v ) and Class.isInstance( v, require "sim/Entity" ) then
		--~			 -- TODO: filters???
		--~			 if ui:MenuItem( string.format( "%s - %s", tostring(k), tostring(v) )) then
		--~				 self.spawn_quest_assignments = self.spawn_quest_assignments or {}
		--~				 self.spawn_quest_assignments[ cast_id ] = v
		--~			 end
		--~		 end
		--~	 end
		--~	 ui:EndPopup()
		--~ end
		ui:NextColumn()
		ui:PopID()
	end

	ui:TextColored( WEBCOLORS.GOLD, "Rank" )
	ui:NextColumn()

	local qrank = ui:_SliderInt( "Rank", current_rank, qrank_min, qrank_max )
	if qrank and qrank ~= current_rank then
		self.spawn_quest_params.qrank = qrank
	end
	ui:NextColumn()

	ui:Columns( 1 )
end

function DebugQuestManager:_SpawnTalker(prefab)
	local player = self:_GetPlayer()
	if player then
		local npc_node = self.questmanager:GetQC():GetNpcCastForPrefab(prefab)
		if npc_node and npc_node.inst then
			self.npc_talker = npc_node.inst
		else
			self.npc_talker = DebugSpawn(prefab)
		end
		assert(self.npc_talker, prefab)
		TheDebugSource:ListenForEvent("onremove", self.on_remove_npc_talker, self.npc_talker)
		-- Move close to player for sensible convo setup.
		local pos = player:GetPosition() + Vector3.unit_x * 3
		self.npc_talker.Transform:SetPosition(pos:unpack())
		-- Don't allow normal conversations
		self.npc_talker.components.interactable.force_disable = true
		return self.npc_talker
	end
end

function DebugQuestManager:_ClearTalker()
	if self.npc_talker then
		self.npc_talker:Remove()
	end
end


function DebugQuestManager:_Button_IfMatches(ui, label, filter)
	local matches = not filter or label:lower():find(filter:lower())
	return matches and ui:Button(label)
end

function DebugQuestManager:_RenderConvoTester(ui, panel)
	if self.npc_talker then
		if self.questmanager.used_cheats_to_compromise_quest_state then
			ui:Text("Please Ctrl-R when done. You must not save quest state after convo testing.")
		end
		if ui:Button(ui.icon.arrow_left .." NPC List") then
			self.npc_talker:Remove()
			return
		end
		ui:SetTooltipIfHovered("Remove ".. self.npc_talker.prefab .." and go back to list of npcs.")
		ui:SameLineWithSpace()
		ui:Value("Talking To", self.npc_talker.prefab )
		if self.talk_err_msg then
			ui:TextWrapped(self.talk_err_msg)
		end
		local npc_node = TheDungeon.progression.components.castmanager:GetNpcNode(self.npc_talker)
		local quests = contentutil.GetContentDB():GetFiltered(Quest, function(quest_class)
			-- Spawn an unattached throwaway quest.
			local q = quest_class()
			return lume.any(q.def.convo_hooks)
				and q:MatchesCastFilters("giver", npc_node)
		end)
		for _,quest_class in ipairs(quests) do
			if ui:CollapsingHeader(quest_class._classname) then
				local t = quest_class:Debug_MakeConvoPicker(ui, self.colorscheme)
				if t then
					local cast_assignments = {
						giver = npc_node,
					}
					if not quest_class.is_instance(self.talk_quest) then
						if self.talk_quest then
							self.npc_talker.components.conversation:Debug_ForceEndConvo(GetDebugPlayer())
							self.talk_quest:Debug_Cancel()
						end
						local must_reuse = not quest_class:CanBeDuplicated()
						self.talk_quest = must_reuse and self.questmanager:FindQuestByID(quest_class._classname)
						if not self.talk_quest then
							self.talk_quest = self.questmanager:SpawnQuest(quest_class._classname, nil, nil, cast_assignments)
						end
						self.talk_quest:MarkAsDebug()
						-- We may modify quests or spawn new ones from doing
						-- these convos. Mark QuestManager as unsaveable so we
						-- don't persist our hacked state.
						self.questmanager.used_cheats_to_compromise_quest_state = true
					end

					local ok, err = pcall(function()
						self.npc_talker.components.conversation:Debug_ForceStartConvo(GetDebugPlayer(), t.state, self.talk_quest)
					end)
					self.talk_err_msg = err
				end
			end
		end
	else
		self.talker_filter = ui:_FilterBar(self.talker_filter, nil, "Filter NPCs...")
		if ui:CollapsingHeader("NPC Name", ui.TreeNodeFlags.DefaultOpen) then
			ui:Indent() do
				for prefab,params in iterator.sorted_pairs(NpcAutogenData) do
					local name = STRINGS.NAMES[prefab] or "unnamed"
					local label = ("%s (%s)"):format(name, prefab)
					if self:_Button_IfMatches(ui, label, self.talker_filter) then
						self:_SpawnTalker(prefab)
					end
				end
			end ui:Unindent()
		end
		if ui:CollapsingHeader("Villager Role") then
			ui:Indent() do
				for _,role in ipairs(Npc.Role:Ordered()) do
					if role ~= Npc.Role.s.visitor
						and self:_Button_IfMatches(ui, role, self.talker_filter)
					then
						local _, prefab = lume.match(NpcAutogenData, function(v)
							return v.role == role
						end)
						self:_SpawnTalker(prefab)
					end
				end
			end ui:Unindent()
		end
	end
end

DebugNodes.DebugQuestManager = DebugQuestManager
return DebugQuestManager
