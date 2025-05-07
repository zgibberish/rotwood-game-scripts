local EntityAnimFrameData = require "dbui.debug_historyframedata"
local EntityTracker = require "dbui.entitytracker"


local ANIM_HISTORY_VERBOSE = false
-- set to true reduce memory usage velocity when debug history is active
-- has some overhead but the net result is about 60~85% reduction in memory
-- usage velocity once the history buffer is saturated
local USE_ANIM_FRAME_DATA_POOLS = true

local ANIMDATA = {
	-- Entity
	ENTITY_GUID 		= 1,
	VISIBLE 		= 2,
	-- Transform
	WORLD_X 		= 3,
	WORLD_Z 		= 4,
	LOCAL_X 		= 5,
	LOCAL_Y 		= 6,
	LOCAL_Z 		= 7,
	SCALE_X 		= 8,
	SCALE_Y 		= 9,
	SCALE_Z 		= 10,
	FACING_ROTATION 	= 11,
	-- AnimState
	BANK_NAME 		= 12,
	ANIM_NAME 		= 13,
	FRAME 			= 14,
	ORIENTATION 		= 15,
	ANIM_SCALE_X 		= 16,
	ANIM_SCALE_Y 		= 17,
}

-- ===========================================================================

local ValidateEmptyFrameData
if DEV_MODE then
	ValidateEmptyFrameData = function(frame)
		assert(frame:IsEmpty(), "Recycled EntityAnimFrameData for DebugAnimHistory is not empty.")
	end
end

local EntityAnimFrameDataPool = Class(Pool, function(self)
	Pool._ctor(self, EntityAnimFrameData, ValidateEmptyFrameData, ValidateEmptyFrameData)
end)

-- ===========================================================================

local entity_anim_data_pool = EntityAnimFrameDataPool()

local create_data = function(entity)
	if USE_ANIM_FRAME_DATA_POOLS then
		local anim_data = entity_anim_data_pool:Get()
		anim_data:AddData(entity.entity:GetAnimStateData())
		return anim_data
	else
		return {entity.entity:GetAnimStateData()}
	end
end

local destroy_data = function(entity_anim_data)
	if USE_ANIM_FRAME_DATA_POOLS then
		entity_anim_data:Clear()
		entity_anim_data_pool:Recycle(entity_anim_data)
	end
	-- intentionally nothing when not using pools
end

local DebugAnimHistory = Class( function(self, max_history)
	self.history = {}
	self.history_ticks = {}
	self.max_history = max_history or 500
	self.proxies = {}
	self.loaded = false
	self.debug_proxy_filter = ""
	self.debug_frame_filter = ""

	self._on_charactercreator_load = function(inst)
		local proxy_table = self.proxies[inst.GUID]
		proxy_table.charactercreator_data = inst.components.charactercreator:OnSave()
		proxy_table.entity.components.charactercreator:OnLoad(proxy_table.charactercreator_data)
	end
	self._on_inventorychanged = function(inst)
		local proxy_table = self.proxies[inst.GUID]
		if not proxy_table.entity.components.inventory then
			proxy_table.entity:AddComponent("inventory")
		end
		proxy_table.inventory_data = inst.components.inventory:OnSave()
		proxy_table.entity.components.inventory:OnLoad(proxy_table.inventory_data)
	end
end)

function DebugAnimHistory:IsRelevantEntity(entity)
	return entity.AnimState
		and entity.Transform
end

function DebugAnimHistory:OnTrackEntity(inst)
	self.inst:ListenForEvent("charactercreator_load", self._on_charactercreator_load, inst)
	self.inst:ListenForEvent("inventorychanged", self._on_inventorychanged, inst)

	self:SpawnProxy({
		prefab_name = inst.prefab,
		guid = inst.GUID,
		bank = inst.AnimState:GetCurrentBankName(),
		build = inst.AnimState:GetBuild(),
		layer = inst.AnimState:GetLayer(),
		charactercreator_data = inst.components.charactercreator and inst.components.charactercreator:OnSave() or nil,
		inventory_data = inst.components.inventory and inst.components.inventory:OnSave() or nil
	})
	if ANIM_HISTORY_VERBOSE then
		print( "[ANIMHISTORY] Entity spawned: ", tostring(inst))
	end
end

function DebugAnimHistory:OnForgetEntity(inst)
	if ANIM_HISTORY_VERBOSE then
		print( "[ANIMHISTORY] Entity despawned: ", tostring(inst))
	end

	local removed_proxy_table = self.proxies[inst.GUID]
	if not removed_proxy_table then
		return
	end

	removed_proxy_table.last_alive = TheSim:GetTick() - 1

	local oldest_tick = self:GetMinTick()

	TheSim:ProfilerPush("Remove Old Proxies")
	--remove old entities
	local to_remove = {}
	for entity_guid, proxy_table in pairs(self.proxies) do
		if proxy_table.last_alive and proxy_table.last_alive < oldest_tick then
			if ANIM_HISTORY_VERBOSE then
				print(string.format("[ANIMHISTORY] Removing proxy for: %d (last alive: %d | min_ticks: %d)", entity_guid, proxy_table.last_alive, oldest_tick))
			end
			table.insert(to_remove, entity_guid)
		end
	end

	for i, entity_guid in ipairs(to_remove) do
		self.proxies[entity_guid].entity:Remove()
		self.proxies[entity_guid] = nil
	end
	TheSim:ProfilerPop()
end

function DebugAnimHistory:Save(save_data_file)
	local save_data = {}
	if USE_ANIM_FRAME_DATA_POOLS then
		-- write out save data to be identical to non-pooled format
		save_data.history = {}
		for tick,frame in pairs(self.history) do
			local saveframe = {}
			for _,animdata in ipairs(frame) do
				table.insert(saveframe, deepcopy(animdata:GetData()))
			end
			save_data.history[tick] = saveframe
		end
	else
		save_data.history = deepcopy(self.history)
	end
	save_data.history_ticks = deepcopy(self.history_ticks)
	save_data.max_history = self.max_history
	save_data.proxies_to_spawn = {}
	for guid, proxy_data in pairs(self.proxies) do
		local proxy_entity = proxy_data.entity

		table.insert( save_data.proxies_to_spawn,
		{
			last_alive = proxy_data.last_alive,
			guid = guid,
			prefab_name = proxy_data.prefab_name,
			charactercreator_data = proxy_entity.components.charactercreator and proxy_entity.components.charactercreator:OnSave() or nil,
			inventory_data = proxy_entity.components.inventory and proxy_entity.components.inventory:OnSave() or nil,
			bank = proxy_entity.AnimState:GetCurrentBankName(),
			build = proxy_entity.AnimState:GetBuild(),
			layer = proxy_entity.AnimState:GetLayer(),
		})
	end

	save_data_file:SetValue("anim", save_data)

	return save_data
end

function DebugAnimHistory:Load(save_data_file)
	local save_data = save_data_file:GetValue("anim")

	self:Reset()
	if USE_ANIM_FRAME_DATA_POOLS then
		-- load data from non-pooled format
		self.history = {}
		for tick,saveframe in pairs(save_data.history) do
			local frame = {}
			for _,saveanimdata in ipairs(saveframe) do
				local animdata = entity_anim_data_pool:Get()
				animdata:AddData(table.unpack(saveanimdata))
				table.insert(frame, animdata)
			end
			self.history[tick] = frame
		end
	else
		self.history = deepcopy(save_data.history)
	end
	self.history_ticks = deepcopy(save_data.history_ticks)
	self.max_history = save_data.max_history

	local prefabs = {}
	for _, to_spawn in ipairs(save_data.proxies_to_spawn) do
		table.insert(prefabs, to_spawn.prefab_name)
	end

	TheSim:LoadPrefabs(prefabs)

	for _, to_spawn in ipairs(save_data.proxies_to_spawn) do
		self:SpawnProxy( to_spawn )
	end

	--verify
	if ANIM_HISTORY_VERBOSE then
		for _, frame in pairs(self.history) do
			for _, data in ipairs(frame) do
				if self.proxies[data.entity_guid] == nil then
					print("[ANIMHISTORY] can't find entity_guid: ", data.entity_guid)
				end
			end
		end
	end

	self.loaded = true
end

function DebugAnimHistory:SpawnProxy( to_spawn )

	if ANIM_HISTORY_VERBOSE then
		print( "[ANIMHISTORY] spawning proxy for: ", tostring(to_spawn.guid))
	end

	local proxy = SpawnPrefab("entityproxy", TheDebugSource)
		:MakeSurviveRoomTravel() -- we'll clean these up ourself

	if to_spawn.bank == nil then
		local inst = Ents[to_spawn.guid]
		print( string.format("[ANIMHISTORY] ERROR: No bank for entity: %d (%s)", tostring(to_spawn.guid), inst) )
	else
		proxy.AnimState:SetBank( to_spawn.bank )
	end

	proxy.AnimState:SetBuild( to_spawn.build )
	proxy.AnimState:SetLayer( to_spawn.layer )

	--assume everything is two faced (but they may not be??)
	proxy.Transform:SetTwoFaced()

	proxy:AddTag("entityproxy")

	proxy.components.replayproxy:SetRealEntityGUID(to_spawn.guid)
	proxy.components.replayproxy:SetRealEntityPrefabName(to_spawn.prefab_name)

	--if player, you need to equip the player
	if to_spawn.charactercreator_data then
		proxy:AddComponent("charactercreator")
		proxy.components.charactercreator:OnLoad( to_spawn.charactercreator_data )
	end

	if to_spawn.inventory_data or to_spawn.prefab_name == "player_side" then
		proxy:AddComponent("inventory")
		proxy.components.inventory:OnLoad( to_spawn.inventory_data )
	end

	self.proxies[to_spawn.guid] = {
		entity = proxy,
		last_alive = to_spawn.last_alive,
		prefab_name = to_spawn.prefab_name,
		charactercreator_data = to_spawn.charactercreator_data,
		inventory_data = to_spawn.inventory_data,
		bank = to_spawn.bank,
		build = to_spawn.build
	}
end

function DebugAnimHistory:Reset()
	if ANIM_HISTORY_VERBOSE then
		print("Resetting anim history")
	end

	-- This removes self.inst which unregisters our events.
	self:ShutdownTracker()

	if #self.history_ticks == 0 then
		return
	end

	--order matters here, set flag to false so that ResumeState doesn't re-call Reset
	self.loaded = false

	self:ResumeState()


	for k, proxy_table in pairs(self.proxies) do
		proxy_table.entity:Remove()
	end
	self.proxies = {}
	self.history_ticks = {}
	if USE_ANIM_FRAME_DATA_POOLS then
		for _,frame in pairs(self.history) do
			for _,animdata in ipairs(frame) do
				destroy_data(animdata)
			end
		end
	end
	self.history = {}
end



function DebugAnimHistory:PlayData(data)
	local proxy_entity

	local guid = data[ANIMDATA.ENTITY_GUID]
	if not self.loaded and Ents[guid] ~= nil then
		--if we're just playing back and not loaded, try to use the live entity as it has more info (e.g. bloom, etc)
		proxy_entity = Ents[guid]
		proxy_entity.Transform:SetPosition(data[ANIMDATA.LOCAL_X], data[ANIMDATA.LOCAL_Y], data[ANIMDATA.LOCAL_Z])
	else
		--otherwise, use the proxy entity
		proxy_entity = self.proxies[guid].entity
		proxy_entity.Transform:SetPosition(data[ANIMDATA.WORLD_X], 0, data[ANIMDATA.WORLD_Z])
	end

	if data.bank_name ~= proxy_entity.AnimState:GetCurrentBankName() then
		proxy_entity.AnimState:SetBank(data[ANIMDATA.BANK_NAME])
	end

	if data[ANIMDATA.ANIM_NAME] == nil then
		--no animation to play
		return
	end

	proxy_entity.AnimState:PlayAnimation(data[ANIMDATA.ANIM_NAME])
	proxy_entity.AnimState:SetFrame(data[ANIMDATA.FRAME])
	proxy_entity.AnimState:SetScale(data[ANIMDATA.ANIM_SCALE_X], data[ANIMDATA.ANIM_SCALE_Y])
	proxy_entity.AnimState:SetOrientation(data[ANIMDATA.ORIENTATION])
	proxy_entity.Transform:SetRotation(data[ANIMDATA.FACING_ROTATION])
	proxy_entity.Transform:SetScale(data[ANIMDATA.SCALE_X], data[ANIMDATA.SCALE_Y], data[ANIMDATA.SCALE_Z])

	if data[ANIMDATA.VISIBLE] then
		if not proxy_entity:IsVisible() then
			proxy_entity:Show()
		end
	else
		proxy_entity:Hide()
	end
end

function DebugAnimHistory:RecordState(sim_tick)

	self:InitTracker()

	if self.history[sim_tick] ~= nil or self.loaded then
		--already recorded this frame
		return
	end

	local frame = {}

	TheSim:ProfilerPush("RecordData")
	--record data for this frame
	for _, entity in pairs(self:GetTrackedEntities()) do
		--TheSim:ProfilerPush("RecordDataEntity")
		table.insert(frame, create_data(entity)) -- destroyed in RecordState "Prune History"
		--TheSim:ProfilerPop()
	end
	TheSim:ProfilerPop()

	table.insert(self.history_ticks, sim_tick)
	self.history[sim_tick] = frame

	TheSim:ProfilerPush("Prune History")
	--prune old history
	if #self.history_ticks > self.max_history then
		if USE_ANIM_FRAME_DATA_POOLS then
			local old_frame = self.history[self.history_ticks[1]]
			for _,anim_data in ipairs(old_frame) do
				destroy_data(anim_data) -- created in RecordState "RecordData"
			end
		end
		self.history[self.history_ticks[1]] = nil
		table.remove(self.history_ticks, 1)
	end
	TheSim:ProfilerPop()
end

function DebugAnimHistory:DebugRenderPanel(ui, node, sim_tick)

	ui:Text( string.format("ents_to_track size: %d", table.numkeys(self:GetTrackedEntities())) )
	ui:Text( string.format("history size: %d", table.numkeys(self.history)) )
	ui:Text( string.format("history_ticks size: %d", #self.history_ticks) )
	ui:Text( string.format("history_ticks[1]: %s", #self.history_ticks == 0 and "nil" or tostring(self.history_ticks[1])) )
	ui:Text( string.format("history_ticks[#history_ticks]: %s", #self.history_ticks == 0 and "nil" or tostring(self.history_ticks[#self.history_ticks])) )

	if ui:CollapsingHeader("Proxy Data") then
		local changed, new_val = ui:InputText("Filter###proxy_filter", self.debug_proxy_filter)
		if changed then
			self.debug_proxy_filter = new_val
		end

		ui:BeginChild("Proxy Data", 0, 250, true, ui.WindowFlags.HorizontalScrollbar)
		for guid, proxy_table in pairs(self.proxies) do
			local str = string.format("%d - %s", guid, proxy_table.prefab_name)
			local filter_passed = self.debug_proxy_filter == "" or str:match(self.debug_proxy_filter) ~= nil
			if filter_passed and ui:TreeNode( str ) then
				node:AppendKeyValues(ui, proxy_table)
				ui:TreePop()
			end
		end
		ui:EndChild()
	end

	if ui:CollapsingHeader("Frame Data") then
		local changed, new_val = ui:InputText("Filter###frame_filter", self.debug_frame_filter)
		if changed then
			self.debug_frame_filter = new_val
		end

		ui:BeginChild("Frame Data", 0, 250, true, ui.WindowFlags.HorizontalScrollbar)
		local frame = self:GetFrame(sim_tick)
		if frame then
			for _, data in ipairs(frame) do
				local guid = data[ANIMDATA.ENTITY_GUID]
				local proxy_entity = self.proxies[guid].entity
				local str = string.format("%s (proxy: %d)", proxy_entity.components.replayproxy:GetRealEntityPrefabName(), proxy_entity.GUID)
				local filter_passed = self.debug_frame_filter == "" or str:match(self.debug_frame_filter) ~= nil
				if filter_passed and ui:TreeNode(str) then
					node:AppendKeyValues(ui, data)
					ui:TreePop()
				end
			end
		end
		ui:EndChild()
	end

end

function DebugAnimHistory:GetFrame(sim_tick)
	local frame = self.history[sim_tick]
	if not frame then
		--find the closest frame
		for i = #self.history_ticks, 1, -1 do
			if self.history_ticks[i] <= sim_tick then
				frame = self.history[ self.history_ticks[i] ]
				break
			end
		end
	end

	return frame
end

function DebugAnimHistory:PlayState(sim_tick)
	local frame = self:GetFrame(sim_tick)
	if not frame then
		-- Not sure how this can happen, but I hit this case from DebugBrain.
		return
	end

	if not TheSim:IsDebugPaused() then
		TheSim:ToggleDebugPause()
	end

	--save data for all live entities, and hide them
	if self.live_entity_data == nil then
		self.live_entity_data = {}
		for k, real_entity in pairs(Ents) do
			if real_entity.AnimState and real_entity.Transform and not real_entity:HasTag("entityproxy") then
				table.insert(self.live_entity_data, create_data(real_entity)) -- destroyed in ResumeState
				real_entity.AnimState:SetScale(0, 0)
			end
		end
	end

	--hide all the proxy entities by default
	for _, proxy_table in pairs(self.proxies) do
		proxy_table.entity.AnimState:SetScale(0, 0)
	end

	--set values for all proxies and hide the current entities
	for _, animdata in ipairs(frame) do
		self:PlayData(USE_ANIM_FRAME_DATA_POOLS and animdata:GetData() or animdata)
	end
end

function DebugAnimHistory:ResumeState()

	if self.loaded then
		--if we loaded from file, then to resume state we need to reset our history
		self:Reset()
	end

	--reset all values and keep playing

	if self.live_entity_data then
		for _, animdata in ipairs(self.live_entity_data) do
			self:PlayData(USE_ANIM_FRAME_DATA_POOLS and animdata:GetData() or animdata)
			destroy_data(animdata) -- created in PlayState
		end
	end

	for _, proxy_table in pairs(self.proxies) do
		proxy_table.entity:Hide()
	end

	self.live_entity_data = nil
end

function DebugAnimHistory:GetMinTick()
	-- TODO: Should this fallback to TheSim:GetTick()? If no history, the
	-- oldest tick isn't the start of time.
	return self.history_ticks[1] or 0
end

function DebugAnimHistory:GetMaxTick()
	return self.history_ticks[#self.history_ticks] or 0
end


DebugAnimHistory:add_mixin(EntityTracker)
return DebugAnimHistory
