local DebugNodes = require "dbui.debug_nodes"
local DebugPickers = require "dbui.debug_pickers"
require "constants"

local DebugBrain = Class(DebugNodes.DebugNode, function(self, inst)
	DebugNodes.DebugNode._ctor(self, "Debug Brain")
	if not EntityScript.is_instance(inst) then
		-- Might have passed a brain.
		inst = inst.inst
	end
	self.inst = inst
	self.expand_all = false
	self:Reset()
end)

DebugBrain.PANEL_WIDTH = 600
DebugBrain.PANEL_HEIGHT = 600

local status_color = {
	["RUNNING"] = WEBCOLORS.YELLOW,
	["READY"] = WEBCOLORS.LIGHTSLATEGRAY,
	["SUCCESS"] = WEBCOLORS.PALEGREEN,
	["FAILED"] = WEBCOLORS.RED,
}

local CreateState = function( node )
	return
	{
		name = node.name,
		id = node.id,
		sleepticks = node:GetTreeSleepTicks() or 0,
		lastresult = node.lastresult,
	}
end

function DebugBrain:DisplayNode( ui, node )

	local data
	if self.history_index ~= self.last_recorded_timestamp and self.history[ self.history_index ] ~= nil then
		data = self.history[ self.history_index ][node.id]
	else
		data = CreateState(node)
	end

	ui:PushStyleColor(ui.Col.Text, status_color[data.lastresult])
	local node_str = string.format("%s (%d)###%d", data.name, data.sleepticks, data.id)

	local tree_node = false
	if data.lastresult == BNState.RUNNING or self.expand_all then
		tree_node = ui:TreeNode( node_str, ui.TreeNodeFlags.DefaultOpen )
	else
		tree_node = ui:TreeNode( node_str )
	end

	if tree_node then
		if node.children ~= nil then
			for k, child in pairs(node.children) do
				self:DisplayNode( ui, child )
			end
		end
		ui:TreePop()
	end

	ui:PopStyleColor(1)
end

function DebugBrain:Reset()
	self.last_recorded_timestamp = TheSim:GetTick()
	self.history_index = self.last_recorded_timestamp
	self.history = {}
end

function DebugBrain:RecordState( node, dict )
	dict[node.id] = CreateState(node)

	if node.children ~= nil then
		for k, child in pairs(node.children) do
			self:RecordState( child, dict )
		end
	end
end

function DebugBrain:SetIndex( new_index )
	self.history_index = new_index
	TheFrontEnd.debugMenu.history:GetAnimHistory():PlayState(self.history_index)
end

function DebugBrain:RenderPanel( ui, panel )

	if self.inst and not self.inst:IsValid() then
		self.inst = nil
	end

	self.name = self.inst and tostring( self.inst ) or "Debug Brain"

	local debug_entity = GetDebugEntity()

	ui:Text("Hover over an entity and press F1 to set Debug Entity")

	if debug_entity ~= self.inst then
		ui:Value("Debug Entity", debug_entity)
		self.inst = debug_entity
		self:Reset()
	end

	if not self.inst then
		ui:Text("No entity to debug")
		return
	end

	if not self.inst.brain then
		ui:Text("No brain to debug")
		return
	end

	if self.inst.brain and self.inst.brain.brain and ui:CollapsingHeader("Brain", ui.TreeNodeFlags.DefaultOpen) then
		local history_len = table.numkeys(self.history)

		-- ui:Text("last recorded timestamp: "..self.last_recorded_timestamp)
		-- ui:Text("history_index: "..self.history_index)

		local changed, history_index = ui:SliderInt("History", self.history_index, self.last_recorded_timestamp - history_len, self.last_recorded_timestamp)
		if changed then
			self:SetIndex(history_index)
		end

		ui:SameLineWithSpace()
		if ui:Button(TheSim:IsDebugPaused() and "Resume" or "Pause") then
			if TheSim:IsDebugPaused() then
				TheFrontEnd.debugMenu.history:ResumeState()
				self.history_index = self.last_recorded_timestamp
			end
			TheSim:ToggleDebugPause()
		end

		ui:SameLineWithSpace()

		if ui:Button(ui.icon.playback_step_back, ui.icon.width, nil, self.history_index <= self.last_recorded_timestamp - history_len) then
			self:SetIndex(self.history_index - 1)
		end

		ui:SameLineWithSpace()

		if ui:Button(ui.icon.playback_step_fwd, ui.icon.width, nil, self.history_index >= self.last_recorded_timestamp) then
			self:SetIndex(self.history_index + 1)
		end


		local is_brain_active = self.inst.brain.brain
		if ui:Checkbox("Expand All", self.expand_all) then
			self.expand_all = not self.expand_all
		end

		if ui:Checkbox("Enabled", is_brain_active) then
			local reason = "debug_entity"
			if is_brain_active then
				self.inst.brain:Pause(reason)
			else
				self.inst.brain:Resume(reason)
			end
		end

		self:DisplayNode( ui, self.inst.brain.brain.root )

		--record history
		if self.last_recorded_timestamp ~= TheSim:GetTick() and self.history_index == self.last_recorded_timestamp then
			self.last_recorded_timestamp = TheSim:GetTick()
			local dict = {}
			self:RecordState( self.inst.brain.brain.root, dict )
			self.history[ self.last_recorded_timestamp ] = dict

			if self.history_index == self.last_recorded_timestamp - 1 then
				self.history_index = self.last_recorded_timestamp
			end
		end

		--chop off the end of the history
		if history_len >= 1000 and self.history_index == self.last_recorded_timestamp then
			table.remove(self.history, 1)
		end
	end

end

DebugNodes.DebugBrain = DebugBrain

return DebugBrain
