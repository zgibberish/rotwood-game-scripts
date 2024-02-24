local DebugInputHistory = Class( function(self, max_history)
	self.history = {}
	self.history_ticks = {}
	self.max_history = max_history or 500
	self.loaded = false
end)

function DebugInputHistory:Save(save_data_file)
	local save_data = {}
	save_data.history = deepcopy(self.history)
	save_data.history_ticks = deepcopy(self.history_ticks)
	save_data.max_history = self.max_history

	save_data_file:SetValue("input", save_data)

	return save_data
end

function DebugInputHistory:Load(save_data_file)
	local save_data = save_data_file:GetValue("input")
	self:Reset()
	self.history = deepcopy(save_data.history)
	self.history_ticks = deepcopy(save_data.history_ticks)
	self.max_history = save_data.max_history
	self.loaded = true
end


function DebugInputHistory:RecordState(sim_tick)

	if self.history[sim_tick] ~= nil or self.loaded then
		--already recorded this frame
		return
	end

	local player_data = {}

	for id, player in pairs(AllPlayers) do

		local controller = player.components.playercontroller
		if controller.deferredcontrols ~= nil then

			local frame_data = {
				sim_tick = TheSim:GetTick(),
				controls = {}
			}

			frame_data.controls["Analog Dir"] = controller:GetAnalogDir() or "Neutral"

			for i = 1, #controller.deferredcontrols, 2 do
				local controls = controller.deferredcontrols[i]
				local down = controller.deferredcontrols[i + 1]

				if not controls then
					break
				end

				for k, v in pairs(Controls.Digital) do
					if controls:Has(v) then
						frame_data.controls[v.key] = down
					end
				end
				for k, v in pairs(Controls.Analog) do
					if controls:Has(v) then
						frame_data.controls[v.key] = down
					end
				end
			end

			player_data[id] = frame_data
		end
	end


	table.insert(self.history_ticks, sim_tick)
	self.history[sim_tick] = player_data

	--prune old history
	if #self.history_ticks > self.max_history then
		self.history[self.history_ticks[1]] = nil
		table.remove(self.history_ticks, 1)
	end

end

function DebugInputHistory:DebugRenderPanel(ui, node, sim_tick)

	ui:Text( string.format("history size: %d", table.numkeys(self.history)) )
	ui:Text( string.format("history_ticks size: %d", #self.history_ticks) )
	ui:Text( string.format("history_ticks[1]: %s", #self.history_ticks == 0 and "nil" or tostring(self.history_ticks[1])) )
	ui:Text( string.format("history_ticks[#history_ticks]: %s", #self.history_ticks == 0 and "nil" or tostring(self.history_ticks[#self.history_ticks])) )

	if ui:CollapsingHeader("Frame Data") then
		local frame = self:GetFrame(sim_tick)
		if frame then
			for k, data in ipairs(frame) do
				node:AppendKeyValues(ui, data)
			end
		end
	end

end


function DebugInputHistory:Reset()
	print("inputhistory: Resetting input history")

	if #self.history_ticks == 0 then
		return
	end

	self.history_ticks = {}
	self.history = {}
	self.loaded = false
end

function DebugInputHistory:ResumeState()

	if self.loaded then
		--if we loaded from file, then to resume state we need to reset our history
		self:Reset()
	end
end

function DebugInputHistory:GetFrame(sim_tick)
	return self.history[sim_tick]
end

function DebugInputHistory:GetMinTick()
	return self.history_ticks[1] or 0
end

function DebugInputHistory:GetMaxTick()
	return self.history_ticks[#self.history_ticks] or 0
end


return DebugInputHistory
