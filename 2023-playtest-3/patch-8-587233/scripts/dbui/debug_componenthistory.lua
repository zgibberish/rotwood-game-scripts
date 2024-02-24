local EntityTracker = require "dbui.entitytracker"


local DebugComponentHistory = Class( function(self, max_history)
	self.history = {}
	self.history_ticks = {}
	self.max_history = max_history or 500
	self.loaded = false
	self.save_token = "components"
	self.components_to_track = {
		"combat",
		"health"
	}
end)

--jcheng: you can use d_addcomponenttohistory to add a component to the history
function DebugComponentHistory:AddComponentToTrack(component_name)
	table.insert(self.components_to_track, component_name)
end

function DebugComponentHistory:Save(save_data_file)
	local save_data = {}
	save_data.history = deepcopy_stringifymeta(self.history)
	save_data.history_ticks = deepcopy(self.history_ticks)
	save_data.max_history = self.max_history

	save_data_file:SetValue(self.save_token, save_data)

	return save_data
end

function DebugComponentHistory:Load(save_data_file)
	local save_data = save_data_file:GetValue(self.save_token)
	self:Reset()
	self.history = deepcopy(save_data.history)
	self.history_ticks = deepcopy(save_data.history_ticks)
	self.max_history = save_data.max_history
	self.loaded = true
end

function DebugComponentHistory:IsRelevantEntity(inst)
	return inst.sg
end

function DebugComponentHistory:RecordState(sim_tick)
	self:InitTracker()

	if self.history[sim_tick] ~= nil or self.loaded then
		--already recorded this frame
		return
	end

	local frame_data = {}

	for _, entity in pairs(self:GetTrackedEntities()) do
		for k, v in ipairs(self.components_to_track) do
			if entity.components[v] then
				frame_data[entity.GUID] = frame_data[entity.GUID] or {}
				frame_data[entity.GUID][v] = shallowcopy(entity.components[v])
			end
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

function DebugComponentHistory:DebugRenderPanel(ui, node, sim_tick)

	ui:Text( string.format("history size: %d", table.numkeys(self.history)) )
	ui:Text( string.format("history_ticks size: %d", #self.history_ticks) )
	ui:Text( string.format("history_ticks[1]: %s", #self.history_ticks == 0 and "nil" or tostring(self.history_ticks[1])) )
	ui:Text( string.format("history_ticks[#history_ticks]: %s", #self.history_ticks == 0 and "nil" or tostring(self.history_ticks[#self.history_ticks])) )

	if ui:CollapsingHeader("Frame Data") then
		local frame = self:GetFrame(sim_tick, GetDebugEntity())
		if frame then
			node:AppendKeyValues(ui, frame)
		else
			ui:Text(string.format("No frame data for %d %s", sim_tick, tostring(GetDebugEntity())))
		end
	end

end


function DebugComponentHistory:Reset()
	print("Resetting input history")

	self:ShutdownTracker()

	if #self.history_ticks == 0 then
		return
	end

	self.history_ticks = {}
	self.history = {}
	self.loaded = false
end

function DebugComponentHistory:ResumeState()

	if self.loaded then
		--if we loaded from file, then to resume state we need to reset our history
		self:Reset()
	end
end

function DebugComponentHistory:GetFrame(sim_tick, entity)
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

function DebugComponentHistory:GetMinTick()
	return self.history_ticks[1] or 0
end

function DebugComponentHistory:GetMaxTick()
	return self.history_ticks[#self.history_ticks] or 0
end


DebugComponentHistory:add_mixin(EntityTracker)
return DebugComponentHistory
