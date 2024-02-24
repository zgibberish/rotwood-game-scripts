local DebugNodes = require "dbui.debug_nodes"
local DebugQuestManager = require "dbui.debug_questmanager"
local iterator = require "util.iterator"
local rotwoodquestutil = require "questral.game.rotwoodquestutil"

-------------------------------------------------------------------------------------
-- Debug panel for the cast of characters (npcs).

local DebugCastManager = Class(DebugNodes.DebugNode, function(self, ...) self:init(...) end)

DebugCastManager.PANEL_WIDTH = 650
DebugCastManager.PANEL_HEIGHT = 1000

DebugCastManager.MENU_BINDINGS = {
	DebugQuestManager.QUEST_MENU,
}


function DebugCastManager:init(castmanager)
	DebugNodes.DebugNode._ctor(self, "Debug Cast Manager")
	self.castmanager = castmanager or rotwoodquestutil.Debug_GetCastManager()
	assert(self.castmanager)
end

function DebugCastManager.CanBeOpened()
	return (TheWorld ~= nil	and rotwoodquestutil.Debug_GetCastManager())
end

function DebugCastManager:OnActivate( panel )
end

function DebugCastManager:OnDeactivate(panel)
end

local function CmpAsString(a, b)
	return tostring(a) < tostring(b)
end

local function RenderActorNodes(ui, panel, name, node_dict)
	if ui:CollapsingHeader(name, ui.TreeNodeFlags.DefaultOpen) then
		if ui:BeginTable(name.."##table", 2, ui.TableFlags.Resizable) then
			for key,val in iterator.sorted_pairs(node_dict, CmpAsString) do
				ui:TableNextRow()
				ui:TableNextColumn()
				panel:AppendTable(ui, val, key)
				ui:TableNextColumn()
				ui:Text(tostring(val))
			end
			ui:EndTable()
		end
	end
end

function DebugCastManager:RenderPanel( ui, panel )
	if ui:CollapsingHeader("Actors", ui.TreeNodeFlags.DefaultClosed) then
		ui:Indent()
		RenderActorNodes(ui, panel, "Locations", self.castmanager.locations)
		RenderActorNodes(ui, panel, "NPCs", self.castmanager.npcnodes)
		RenderActorNodes(ui, panel, "Enemies", self.castmanager.enemynodes)
		RenderActorNodes(ui, panel, "Players", self.castmanager.playernodes)
		RenderActorNodes(ui, panel, "Interactables", self.castmanager.interactablenodes)
		ui:Unindent()
	end

	if ui:CollapsingHeader("Players", ui.TreeNodeFlags.DefaultOpen) then
		ui:Indent()
		local local_players = TheNet:GetLocalPlayerList()
		for _, id in ipairs(local_players) do
			local player = GetPlayerEntityFromPlayerID(id)
			local qc = self.castmanager.questcentrals[player]
			if qc ~= nil then
				panel:AppendTable(ui, qc:GetQuestManager(), string.format("[%s] %s", id, player:GetCustomUserName()))
			end
		end
		ui:Unindent()
	end

	if ui:CollapsingHeader("Known Interactables", ui.TreeNodeFlags.DefaultClosed) then
		ui:Indent()
		for prefab, ent in pairs(self.castmanager.interactables) do
			panel:AppendTable(ui, ent, prefab)
		end
		ui:Unindent()
	end

	self:AddFilteredAll(ui, panel, self.castmanager)
end

DebugNodes.DebugCastManager = DebugCastManager

return DebugCastManager
