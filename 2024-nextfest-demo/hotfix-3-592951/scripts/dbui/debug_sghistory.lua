local EntitySGFrameData = require "dbui.debug_historyframedata"
local EntityTracker = require "dbui.entitytracker"


local USE_SG_FRAME_DATA_POOLS = true

local ValidateEmptyFrameData
if DEV_MODE then
	ValidateEmptyFrameData = function(frame)
		assert(frame:IsEmpty(), "Recycled EntitySGFrameData for DebugSGHistory is not empty.")
	end
end

local EntitySGFrameDataPool = Class(Pool, function(self)
	Pool._ctor(self, EntitySGFrameData, ValidateEmptyFrameData, ValidateEmptyFrameData)
end)

local sg_data_pool = EntitySGFrameDataPool()

local DebugSGHistory = Class( function(self, max_history)
	self.history = {}
	self.history_ticks = {}
	self.max_history = max_history or 500
	self.loaded = false
end)

function DebugSGHistory:Save(save_data_file)
	local save_data = {}
	if USE_SG_FRAME_DATA_POOLS then
		save_data.history = {}
		for tick,frame in pairs(self.history) do
			local saveframe = {}
			for entguid,entdata in pairs(frame) do
				saveframe[entguid] = deepcopy_stringifymeta(entdata:GetData())
			end
			save_data.history[tick] = saveframe
		end
	else
		save_data.history = deepcopy_stringifymeta(self.history)
	end
	save_data.history_ticks = deepcopy(self.history_ticks)
	save_data.max_history = self.max_history

	save_data_file:SetValue("sg", save_data)

	return save_data
end

function DebugSGHistory:Load(save_data_file)
	local save_data = save_data_file:GetValue("sg")
	self:Reset()
	if USE_SG_FRAME_DATA_POOLS then
		self.history = {}
		for tick,saveframe in pairs(save_data.history) do
			local frame = {}
			for entguid,entdata in pairs(saveframe) do
				local sg_data = sg_data_pool:Get()
				sg_data:ForceSetData(deepcopy(entdata))
				frame[entguid] = sg_data
			end
			self.history[tick] = frame
		end
	else
		self.history = deepcopy(save_data.history)
	end
	self.history_ticks = deepcopy(save_data.history_ticks)
	self.max_history = save_data.max_history
	self.loaded = true
end

function DebugSGHistory:IsRelevantEntity(inst)
	return inst.sg
end


function DebugSGHistory:RecordState(sim_tick)
	self:InitTracker()

	if self.history[sim_tick] ~= nil or self.loaded then
		--already recorded this frame
		return
	end

	local frame_data = {}

	for _, entity in pairs(self:GetTrackedEntities()) do
		if entity.sg then
			local sg_data
			if USE_SG_FRAME_DATA_POOLS then
				sg_data = sg_data_pool:Get()
				entity.sg:GetDebugTable(sg_data:GetData())
			else
				sg_data = entity.sg:GetDebugTable()
			end
			frame_data[entity.GUID] = sg_data
		end
	end

	table.insert(self.history_ticks, sim_tick)
	self.history[sim_tick] = frame_data

	--prune old history
	if #self.history_ticks > self.max_history then
		if USE_SG_FRAME_DATA_POOLS then
			local oldframe = self.history[self.history_ticks[1]]
			for _,entdata in pairs(oldframe) do
				entdata:Clear()
				sg_data_pool:Recycle(entdata)
			end
		end
		self.history[self.history_ticks[1]] = nil
		table.remove(self.history_ticks, 1)
	end

end

function DebugSGHistory:DebugRenderPanel(ui, node, sim_tick)

	ui:Text( string.format("ents tracked: %d", table.numkeys(self:GetTrackedEntities())) )
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


function DebugSGHistory:Reset()
	print("sghistory: Resetting input history")

	self:ShutdownTracker()

	if #self.history_ticks == 0 then
		return
	end

	self.history_ticks = {}
	if USE_SG_FRAME_DATA_POOLS then
		for _,framedata in pairs(self.history) do
			for _,entdata in pairs(framedata) do
				entdata:Clear()
				sg_data_pool:Recycle(entdata)
			end
		end
	end
	self.history = {}
	self.loaded = false
end

function DebugSGHistory:ResumeState()

	if self.loaded then
		--if we loaded from file, then to resume state we need to reset our history
		self:Reset()
	end
end

function DebugSGHistory:GetFrame(sim_tick, entity)
	if entity == nil then
		return
	end

	local frame_data = self.history[sim_tick]
	if frame_data == nil then
		return
	end

	if entity.components.replayproxy then
		local real_guid = entity.components.replayproxy:GetRealEntityGUID()
		return USE_SG_FRAME_DATA_POOLS
			and (frame_data[real_guid] and frame_data[real_guid]:GetData() or nil)
			or frame_data[real_guid]
	end

	return USE_SG_FRAME_DATA_POOLS
		and (frame_data[entity.GUID] and frame_data[entity.GUID]:GetData() or nil)
		or frame_data[entity.GUID]
end

function DebugSGHistory:GetMinTick()
	return self.history_ticks[1] or 0
end

function DebugSGHistory:GetMaxTick()
	return self.history_ticks[#self.history_ticks] or 0
end


DebugSGHistory:add_mixin(EntityTracker)
return DebugSGHistory
