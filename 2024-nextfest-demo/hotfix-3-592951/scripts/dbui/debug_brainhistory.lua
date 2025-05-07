local EntityTracker = require "dbui.entitytracker"
require "constants"


local DebugBrainHistory = Class( function(self, max_history)
	self.history = {}
	self.history_ticks = {}
	self.max_history = max_history or 500
	self.loaded = false
end )

local status_color = {
	["RUNNING"] = WEBCOLORS.YELLOW,
	["READY"] = WEBCOLORS.LIGHTSLATEGRAY,
	["SUCCESS"] = WEBCOLORS.PALEGREEN,
	["FAILED"] = WEBCOLORS.RED,
}

function DebugBrainHistory:Save(save_data_file)
	local save_data = {}
	save_data.history = deepcopy(self.history)
	save_data.history_ticks = deepcopy(self.history_ticks)
	save_data.max_history = self.max_history

	save_data_file:SetValue("brain", save_data)

	return save_data
end

function DebugBrainHistory:Load(save_data_file)
	local save_data = save_data_file:GetValue("brain")
	self:Reset()
	self.history = deepcopy(save_data.history)
	self.history_ticks = deepcopy(save_data.history_ticks)
	self.max_history = save_data.max_history
	self.loaded = true
end

function DebugBrainHistory:IsRelevantEntity(inst)
	return inst.brain
end


function DebugBrainHistory:RecordState(sim_tick)
	self:InitTracker()

	if self.history[sim_tick] ~= nil or self.loaded then
		--already recorded this frame
		return
	end

	local frame_data = {}

	for _, entity in pairs(self:GetTrackedEntities()) do
		if entity.brain and entity.brain.brain then
			frame_data[entity.GUID] = self:RecordStateInternal( entity.brain.brain.root )
		end
	end

	table.insert(self.history_ticks, sim_tick)
	self.history[sim_tick] = frame_data

	--prune old history
	if #self.history_ticks > self.max_history then
		self.history[self.history_ticks[1]] = nil
		table.remove(self.history_ticks, 1)
	end

end

function DebugBrainHistory:Reset()
	print("brainhistory: Resetting input history")

	self:ShutdownTracker()

	if #self.history_ticks == 0 then
		return
	end

	self.history_ticks = {}
	self.history = {}
	self.loaded = false
end

function DebugBrainHistory:ResumeState()

	if self.loaded then
		--if we loaded from file, then to resume state we need to reset our history
		self:Reset()
	end
end

function DebugBrainHistory:GetFrame(sim_tick, entity)
	if entity == nil then
		return
	end

	local frame_data = self.history[sim_tick]
	if frame_data == nil then
		return
	end

	if entity.components.replayproxy then
		return frame_data[entity.components.replayproxy:GetRealEntityGUID()]
	end

	return frame_data[entity.GUID]
end


function DebugBrainHistory:RecordStateInternal( node )
	local data = {
		name = node.name,
		id = node.id,
		sleepticks = node:GetTreeSleepTicks() or 0,
		lastresult = node.lastresult
	}

	if node.children ~= nil then
		for k, child in pairs(node.children) do
			data.children = data.children or {}
			table.insert(data.children, self:RecordStateInternal(child))
		end
	end

	return data
end

function DebugBrainHistory:GetMinTick()
	return self.history_ticks[1] or 0
end

function DebugBrainHistory:GetMaxTick()
	return self.history_ticks[#self.history_ticks] or 0
end

function DebugBrainHistory:DisplayData( ui, node, data )

	ui:PushStyleColor(ui.Col.Text, status_color[data.lastresult])
	local node_str = string.format("%s (%d)###%d", data.name, data.sleepticks, data.id)

	local tree_node = false
	if data.lastresult == BNState.RUNNING or self.expand_all then
		tree_node = ui:TreeNode( node_str, ui.TreeNodeFlags.DefaultOpen )
	else
		tree_node = ui:TreeNode( node_str )
	end

	if tree_node then
		if data.children ~= nil then
			for k, child in pairs(data.children) do
				self:DisplayData( ui, node, child )
			end
		end
		ui:TreePop()
	end

	ui:PopStyleColor(1)
end


DebugBrainHistory:add_mixin(EntityTracker)
return DebugBrainHistory
