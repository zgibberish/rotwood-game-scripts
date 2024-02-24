


local SpikeBallAttacker = Class(function(self, inst)
	self.inst = inst
end)

function SpikeBallAttacker:SetUpSuperFlap()
	return 10
end

function SpikeBallAttacker:DoSuperFlap()
	local facing = self.inst.Transform:GetFacing() == FACING_LEFT and -1 or 1
	-- Spawn spikeballs
	local minx, minz, maxx, maxz = TheWorld.Map:GetWalkableBounds()

	local stage_height = maxz - minz
	local spike_line_interval = 1.5
	local line_size = math.ceil(stage_height/4)
	local pos = self.inst:GetPosition()
	local dist_per_ball = 2

	local z_pos_odd = minz + 0.5 --krandom.Float(minz + 0.5, maxz - 0.5)
	local z_pos_even = maxz - 0.5

	local num_lines_spawned = 0

	local num_spike_lines = 5

	local function _spawn_spike_line()
		local dist_offset = 1
		local z_pos = z_pos_odd
		if num_lines_spawned%2 == 0 then
			z_pos = z_pos_even
			dist_offset = -1
		end

		local s_pos = Vector3(pos.x + 5 * facing, pos.y, z_pos)

		for i = 0, line_size - 1 do
			local spikeball = SGCommon.Fns.SpawnAtDist(self.inst, "owlitzer_spikeball", 0)
			if spikeball then
				local target_pos = Vector3(s_pos.x, s_pos.y, s_pos.z + (i * dist_per_ball * dist_offset))
				spikeball.Transform:SetPosition(pos.x, pos.y + 1, pos.z) -- Set so the spikeball's y-position is set to be the same as Owlitzer's
				spikeball.sg:GoToState("thrown", target_pos)
			end
		end

		num_lines_spawned = num_lines_spawned + 1

		if num_lines_spawned < num_spike_lines then
			self.inst:DoTaskInTime(spike_line_interval, _spawn_spike_line)
		end
	end

	_spawn_spike_line()
end

function SpikeBallAttacker:DebugDrawEntity(ui, panel, colors)

	local phase_diff, new_phase = ui:SliderInt("Boss Phase", self.phase, 1, 4)
	if phase_diff then
		self.phase = new_phase
	end

	local line_diff, new_time = ui:SliderFloat("Line Attack Time", self.root_wave_pause, 0.1, 1)
	if line_diff then
		self.root_wave_pause = new_time
	end

	local debugplayer = GetDebugPlayer()
	if debugplayer then 
		local x, z = debugplayer.Transform:GetWorldXZ()
		local data =  { x = x, z = z } -- is this the right data?
		local fns = {
			-- "DoLinesAttack",
		}
		for _,fn_name in ipairs(fns) do
			if ui:Button(fn_name) then
				local fn = self[fn_name]
				fn(self, data)
			end
		end
	end
end

return SpikeBallAttacker
