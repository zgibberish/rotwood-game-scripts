local Enum = require "util.enum"
local krandom = require "util.krandom"
local lume = require "util.lume"
local monsterutil = require "util.monsterutil"
local SGCommon = require("stategraphs/sg_common")

local RootCommand <const> = Enum {
	"DoGridAttack",
	"DoLinesAttack",
	"DoSpinAttack",
	"DoCircleAttack",
	"DoCirclesAttack",
	"DoHorizontalLineAttack",
	"DoVerticalLineAttack",
	"SpawnGuardRoots",
	"DespawnGuardRoots",
	"DoTargettedAttackPre",
	"FinishTargettedAttack",
}

local RootCommandIdle <const> = 0

-- TODO: networking2022, make these visible via require so no duplication is needed
-- from sg_megatreemon.lua

local function OnFlailHitBoxTriggered(inst, data)
	SGCommon.Events.OnHitboxTriggered(inst, data, {
		hitstoplevel = HitStopLevel.HEAVY,
		set_dir_angle_to_target = true,
		damage_mod = 0,
		pushback = 1.5,
		combat_attack_fn = "DoKnockbackAttack",
		hit_fx = monsterutil.defaultAttackHitFX,
		hit_fx_offset_x = 0.5,
		keep_it_local = true,
	})
end

local function OnPokeRootHitBoxTriggered(inst, data)
	SGCommon.Events.OnHitboxTriggered(inst, data, {
		hitstoplevel = HitStopLevel.LIGHT,
		set_dir_angle_to_target = true,
		damage_mod = 0.5,
		pushback = 0.1,
		hitflags = Attack.HitFlags.GROUND,
		combat_attack_fn = "DoKnockbackAttack",
		hit_fx = monsterutil.defaultAttackHitFX,
		keep_it_local = true,
	})
end

local function OnAttackRootHitBoxTriggered(inst, data)
	SGCommon.Events.OnHitboxTriggered(inst, data, {
		attackdata_id = "root",
		hitstoplevel = HitStopLevel.HEAVY,
		set_dir_angle_to_target = true,
		pushback = 0.5,
		hitflags = Attack.HitFlags.GROUND,
		combat_attack_fn = "DoKnockdownAttack",
		hit_fx = monsterutil.defaultAttackHitFX,
		keep_it_local = true,
	})
end

local RootAttacker = Class(function(self, inst)
	self.inst = inst
	self.guard_roots = {}
	self.attack_roots = {}
	self.summoned_roots = {}
	self.root_wave_pause = 1

	-- data to be synced
	self.phase = 1
	self.attacks_to_do = 0
	self.command = RootCommandIdle
	-- DoLinesAttack, DoSpinAttack, DoCirclesAttack: rng seed (x)
	-- DoTargettedAttackPre: world pos (x,z)
	self.command_data = nil

	-- client-only data
	self.client_hitboxtrigger_fn = nil
end)

function RootAttacker:_ClientListenForHitboxTrigger(fn)
	if not self.inst:IsLocal() then
		if self.client_hitboxtrigger_fn then
			self:_ClientClearHitboxTrigger()
		end
		self.client_hitboxtrigger_fn = fn
		-- TheLog.ch.RootAttacker:printf("Client started listening for hitboxtriggered event")
		self.inst:ListenForEvent("hitboxtriggered", self.client_hitboxtrigger_fn)
	end
end

function RootAttacker:_ClientClearHitboxTrigger()
	if not self.inst:IsLocal() and self.client_hitboxtrigger_fn then
		-- TheLog.ch.RootAttacker:printf("Client stopped listening for hitboxtriggered event")
		self.inst:RemoveEventCallback("hitboxtriggered", self.client_hitboxtrigger_fn)
		self.client_hitboxtrigger_fn = nil
	end
end

local ROOT_WAVE_PAUSE_BY_PHASE = { 1, 0.8, 0.65, 0.5 }

function RootAttacker:CanUpdateSyncedData()
	return TheNet:IsHost()
end

-- command = value from RootCommand enum;
-- data = optional x,z data (okay to be nil)
function RootAttacker:SetSyncCommand(command, data)
	if self:CanUpdateSyncedData() then
		-- TODO: in rare cases, it's possible to stomp a queued command that hasn't been synced yet
		-- may want to detect this and deal with it.  Ideally, commands get confirmed sent or queued
		self.command = command
		self.command_data = data
		-- TheLog.ch.RootAttacker:printf("Sending Command = %s, Data = %s,%s",
		-- 	self.command > 0 and RootCommand:FromId(self.command) or "Idle",
		-- 	self.command_data and tostring(self.command_data.x) or "nil",
		-- 	self.command_data and tostring(self.command_data.z) or "nil")
	end
end

function RootAttacker:OnNetSerialize()
	local e = self.inst.entity
	e:SerializeUInt(self.phase - 1, 2) -- 1..4
	e:SerializeUInt(self.attacks_to_do, 4)
	e:SerializeUInt(self.command, 4)
	e:SerializeBoolean(self.command_data ~= nil)
	if self.command_data then
		if self.command == RootCommand.id.DoLinesAttack
			or self.command == RootCommand.id.DoSpinAttack
			or self.command == RootCommand.id.DoCirclesAttack then
			e:SerializeUInt(self.command_data.x and self.command_data.x or 0, 32) -- encode rng seed
		elseif self.command == RootCommand.id.DoTargettedAttackPre then
			e:SerializeDoubleAs16Bit(self.command_data.x and self.command_data.x or 0)
			e:SerializeDoubleAs16Bit(self.command_data.z and self.command_data.z or 0)
		else
			assert(false, "Unsupported root command data format for attack: " .. RootCommand:FromId(self.command))
		end
	end
end

function RootAttacker:OnNetDeserialize()
	local e = self.inst.entity
	local new_phase = e:DeserializeUInt(2) + 1
	local new_attacks_to_do = e:DeserializeUInt(4)
	local new_command = e:DeserializeUInt(4)
	local has_command_data = e:DeserializeBoolean()
	if has_command_data then
		self.command_data = self.command_data or {}
		if new_command == RootCommand.id.DoLinesAttack
			or new_command == RootCommand.id.DoSpinAttack
			or new_command == RootCommand.id.DoCirclesAttack then
			self.command_data.x = e:DeserializeUInt(32)
			self.command_data.z = nil
		elseif new_command == RootCommand.id.DoTargettedAttackPre then
			self.command_data.x = e:DeserializeDoubleAs16Bit()
			self.command_data.z = e:DeserializeDoubleAs16Bit()
		else
			assert(false, "Unsupported root command data format for attack: " .. RootCommand:FromId(new_command))
		end
	else
		self.command_data = nil
	end

	if self.phase ~= new_phase then
		self:SetPhase(new_phase)
	end
	if new_attacks_to_do ~= self.attacks_to_do then
		self:SetNumAttacks(new_attacks_to_do)
	end
	if new_command ~= self.command then
		if self.command ~= 0 then
			self:CancelAttack()
			self.command = 0
		end
		if new_command > 0 then
			RootAttacker[RootCommand:FromId(new_command)](self, self.command_data)
		end
		self.command = new_command

		-- TheLog.ch.RootAttacker:printf("Receiving Command = %s, Data = %s,%s",
		-- 	self.command > 0 and RootCommand:FromId(self.command) or "Idle",
		-- 	self.command_data and tostring(self.command_data.x) or "nil",
		-- 	self.command_data and tostring(self.command_data.z) or "nil")
	end
end

function RootAttacker:SetNumAttacks(num)
	self.attacks_to_do = num
end

function RootAttacker:SetPhase(phase)
	self.phase = phase
	self.root_wave_pause = ROOT_WAVE_PAUSE_BY_PHASE[phase]
end

function RootAttacker:WaitForSeconds(duration)
	assert(self.attack_thread:IsRunning())
	self.inst.components.cororun:WaitForSeconds(self.attack_thread, duration)
end

function RootAttacker:CancelAttack()
	if self.attack_thread ~= nil then
		self:ForceFinishAttack()
		self.attack_thread:Stop()
		self.attack_thread = nil
	end
end

function RootAttacker:WaitForRootsCleared()
	assert(self.attack_thread:IsRunning())
	while next(self.summoned_roots) do
		coroutine.yield()
	end
end

function RootAttacker:ForceFinishAttack()
	self:ResetTargettedAttack()
	self.attacks_to_do = 0
	self.inst:PushEvent("done_root_attacks")
	self.inst.components.combat:StartCooldown(3)
	self:SetSyncCommand(RootCommandIdle)
end

function RootAttacker:OnDoneAttack()
	self.attacks_to_do = self.attacks_to_do - 1

	if self.attacks_to_do <= 0 then
		self:WaitForRootsCleared()
		self.inst:PushEvent("done_root_attacks")
		self.inst.components.combat:StartCooldown(3)
		self:SetSyncCommand(RootCommandIdle)
	else
		self.inst:PushEvent("advance_root_attack")
	end
end

function RootAttacker:SpawnRootAt(x, z, event, data, skip_rot)
	-- Allow spawning at ground and not only walkable area (IsWalkableAtXZ) to
	-- avoid drawing the outline of world collision with roots. They might not
	-- hit you there, but there's no visual reason they can't spawn there.
	if TheWorld.Map:IsGroundAtXZ(x, z) then
		local root = SpawnPrefab("megatreemon_growth_root", self.inst)
		local offset_size = 0.6
		local horizontal_offset = math.random() * offset_size
		x = x + (-(offset_size / 2) + horizontal_offset)
		root.Transform:SetPosition(x, 0, z)
		if not skip_rot then
			root.Transform:SetRotation(math.random(360)) -- don't care about rotation for sync purposes
		end
		root:Setup(self.inst)
		root:PushEvent(event or "poke", data)
		self.summoned_roots[root] = root
		return root
	end
end

function RootAttacker:SpawnGuardRoots()
	if #self.guard_roots > 0 then
		self:DespawnGuardRoots()
	end

	self:SetSyncCommand(RootCommand.id.SpawnGuardRoots)

	local pos = Vector2(self.inst.Transform:GetWorldXZ())
	local rad = 3 -- self.inst.Physics:GetSize() -- with a smaller physics size for gameplay reasons this no longer works, so it is being hard coded
	local perimeter = 2 * math.pi * rad
	local resolution = math.floor(perimeter/3)
	local angle_between_roots = 360/resolution
	local positions = {}

	for angle = 0, 360, angle_between_roots do
		table.insert(positions, Vector2(math.sin(math.rad(angle)), math.cos(math.rad(angle))))
	end

	for _, attack_pos in ipairs(positions) do
		local offset = Vector2(attack_pos.x * (rad), attack_pos.y * (rad))
		local root_pos = offset + pos
		local root = self:SpawnRootAt(root_pos.x, root_pos.y, "guard")
		table.insert(self.guard_roots, root)
	end
	self:_ClientListenForHitboxTrigger(OnFlailHitBoxTriggered)
end

function RootAttacker:DespawnGuardRoots()
	for _, root in ipairs(self.guard_roots) do
		root:PushEvent("stop_guard")
	end
	lume.clear(self.guard_roots)
	self:SetSyncCommand(RootCommand.id.DespawnGuardRoots)
	self:_ClientClearHitboxTrigger()
end


function RootAttacker:DoTargettedAttackPre(data)
	if self:CanUpdateSyncedData() then
		assert(#self.attack_roots == 0, "Tried to do a root attack but one is already active!")
	elseif #self.attack_roots ~= 0 then
		self:CancelAttack() -- don't assert for remote clients (i.e. via join-in-progress)
		return
	end

	if self.attack_thread then
		self.attack_thread:Stop()
	end
	self.attack_thread = nil

	self.attack_thread = self.inst.components.cororun:StartCoroutine(RootAttacker._targetted_attack_pre_coro, self, data)
	self:SetSyncCommand(RootCommand.id.DoTargettedAttackPre, data)
	self:_ClientListenForHitboxTrigger(OnAttackRootHitBoxTriggered)
end

function RootAttacker:FinishTargettedAttack()
	if self:CanUpdateSyncedData() then
		assert(#self.attack_roots > 0, "Tried to finish a root attack, but you have no roots to do it with!")
	elseif #self.attack_roots == 0 then
		self:CancelAttack() -- don't assert for remote clients (i.e. via join-in-progress)
		return
	end

	if self.attack_thread then
		self.attack_thread:Stop()
	end
	self.attack_thread = nil

	self.attack_thread = self.inst.components.cororun:StartCoroutine(RootAttacker._finish_targetted_attack_coro, self)
	self:SetSyncCommand(RootCommand.id.FinishTargettedAttack)
end

-- function RootAttacker:DoSpiralAttack(data)
-- 	if self.attack_thread then
-- 		self.attack_thread:Stop()
-- 	end
-- 	self.attack_thread = nil

-- 	self.attack_thread = self.inst.components.cororun:StartCoroutine(RootAttacker._spiral_coro, self, data)
-- 	-- self:SetSyncCommand(RootCommand.id.DoSpiralAttack)
-- end

function RootAttacker:DoLinesAttack(data)
	if self.attack_thread then
		self.attack_thread:Stop()
	end
	self.attack_thread = nil

	data = data or { x = math.random(0, 2^32 - 1) }
	self.attack_thread = self.inst.components.cororun:StartCoroutine(RootAttacker._lines_coro, self, data)
	self:SetSyncCommand(RootCommand.id.DoLinesAttack, data)
	self:_ClientListenForHitboxTrigger(OnPokeRootHitBoxTriggered)
end

function RootAttacker:DoSpinAttack(data)
	if self.attack_thread then
		self.attack_thread:Stop()
	end
	self.attack_thread = nil

	data = data or { x = math.random(0, 2^32 - 1) }
	self.attack_thread = self.inst.components.cororun:StartCoroutine(RootAttacker._spin_coro, self, data)
	self:SetSyncCommand(RootCommand.id.DoSpinAttack, data)
	self:_ClientListenForHitboxTrigger(OnPokeRootHitBoxTriggered)
end

function RootAttacker:DoCircleAttack(_data)
	if self.attack_thread then
		self.attack_thread:Stop()
	end
	self.attack_thread = nil

	self.attack_thread = self.inst.components.cororun:StartCoroutine(RootAttacker._circle_coro, self, nil)
	self:SetSyncCommand(RootCommand.id.DoCircleAttack)
	self:_ClientListenForHitboxTrigger(OnPokeRootHitBoxTriggered)
end

function RootAttacker:DoHorizontalLineAttack(_data)
	if self.attack_thread then
		self.attack_thread:Stop()
	end
	self.attack_thread = nil

	self.attack_thread = self.inst.components.cororun:StartCoroutine(RootAttacker._h_line_coro, self, nil)
	self:SetSyncCommand(RootCommand.id.DoHorizontalLineAttack)
	self:_ClientListenForHitboxTrigger(OnPokeRootHitBoxTriggered)
end

function RootAttacker:DoVerticalLineAttack(_data)
	if self.attack_thread then
		self.attack_thread:Stop()
	end
	self.attack_thread = nil

	self.attack_thread = self.inst.components.cororun:StartCoroutine(RootAttacker._v_line_coro, self, nil)
	self:SetSyncCommand(RootCommand.id.DoVerticalLineAttack)
	self:_ClientListenForHitboxTrigger(OnPokeRootHitBoxTriggered)
end

function RootAttacker:DoCirclesAttack(data)
	if self.attack_thread then
		self.attack_thread:Stop()
	end
	self.attack_thread = nil

	data = data or { x = math.random(0, 2^32 - 1) }
	self.attack_thread = self.inst.components.cororun:StartCoroutine(RootAttacker._circles_attack, self, data)
	self:SetSyncCommand(RootCommand.id.DoCirclesAttack, data)
	self:_ClientListenForHitboxTrigger(OnPokeRootHitBoxTriggered)
end

function RootAttacker:DoGridAttack(_data)
	if self.attack_thread then
		self.attack_thread:Stop()
	end
	self.attack_thread = nil

	self.attack_thread = self.inst.components.cororun:StartCoroutine(RootAttacker._grid_coro, self, nil)
	self:SetSyncCommand(RootCommand.id.DoGridAttack)
	self:_ClientListenForHitboxTrigger(OnPokeRootHitBoxTriggered)
end

function RootAttacker:_circles_attack(data)
	coroutine.yield()

	local num_circles = {1, 1, 2, 3} -- don't do more than around 4

	local num = num_circles[self.phase]
	local min_dist_apart = 10
	local max_attempts = 20

	local x_max, y_max = TheWorld.Map:GetSize()

	x_max = math.ceil(x_max * 0.75)
	y_max = math.ceil(y_max * 0.75)

	local x_min = -x_max
	local y_min = -y_max

	local rng = krandom.CreateGenerator(data.x)
	local positions = { }
	for i = 1, num do
		local num_attempts = 1
		while #positions < i and num_attempts < max_attempts do
			local can_insert = i == 1
			local x = rng:Float(x_min, x_max)
			local y = rng:Float(y_min, y_max)
			-- TheLog.ch.RootAttacker:printf("Circle %d, Attempt %d - RNG value: %1.3f,%1.3f", i, num_attempts, x, y)
			if not can_insert then
				local too_close = false
				for _, pos in ipairs(positions) do
					if Dist2D(x, y, pos.x, pos.y) < min_dist_apart then
						too_close = true
						break
					end
				end
				can_insert = not too_close
			end

			if can_insert then
				table.insert(positions, { x = x, y = y })
			end

			num_attempts = num_attempts + 1
		end

		if #positions ~= i then
			break
		end
	end

	local num_steps = 10
	local dist_per_step = 2
	local units_per_root = 4

	local attack_offsets = {}
	for step = 1, num_steps do
		attack_offsets[step] = {}
		local rad = dist_per_step * step
		local perimeter = 2 * math.pi * rad
		local resolution = math.floor(perimeter/units_per_root)
		local angle_between_roots = 360/resolution

		for angle = 1, 360, angle_between_roots do
			table.insert(attack_offsets[step], Vector2(math.sin(math.rad(angle)), math.cos(math.rad(angle))))
		end
	end

	for step = 1, num_steps do
		local rad = dist_per_step * step
		local offsets = attack_offsets[step]
		for _, pos in ipairs(positions) do
			for _, coords in ipairs(offsets) do
				local offset = Vector2(coords.x * rad, coords.y * rad)
				local root_pos = offset + pos
				self:SpawnRootAt(root_pos.x, root_pos.y)
			end
		end
		self:WaitForSeconds(self.root_wave_pause)
	end

	self:OnDoneAttack()
end

function RootAttacker:_v_line_coro(data)
	coroutine.yield()

	local x_max, y_max = TheWorld.Map:GetSize()

	x_max = math.floor(x_max)
	y_max = math.floor(y_max)

	local x_min = -x_max
	local y_min = -y_max

	local dist_between_rows = 3
	local dist_between_roots = 3

	local num_loops = { 1, 1, 2, 3 }
	local loops = num_loops[self.phase]
	for loop = 1, loops do
		for attack_num = 1, 5 do
			for x = x_min, x_max, dist_between_rows do
				local x_odd = x%2 == 1

				if attack_num%2 == 1 then
					if x_odd then
						for y = y_min, y_max, dist_between_roots do
							self:SpawnRootAt(x, y)
						end
					end
				else
					if not x_odd then
						for y = y_min, y_max, dist_between_roots do
							self:SpawnRootAt(x, y)
						end
					end
				end

			end
			self:WaitForSeconds(self.root_wave_pause)
		end
	end

	self:OnDoneAttack()
end

function RootAttacker:_h_line_coro(data)
	coroutine.yield()

	local x_max, y_max = TheWorld.Map:GetSize()

	x_max = math.floor(x_max)
	y_max = math.floor(y_max)

	local x_min = -x_max
	local y_min = -y_max

	local dist_between_rows = 3
	local dist_between_roots = 3

	local num_loops = { 1, 1, 2, 3 }
	local loops = num_loops[self.phase]
	for loop = 1, loops do
		for attack_num = 1, 5 do
			for y = y_min, y_max, dist_between_rows do
				local y_odd = y%2 == 1

				if attack_num%2 == 1 then
					if y_odd then
						for x = x_min, x_max, dist_between_roots do
							self:SpawnRootAt(x, y)
						end
					end
				else
					if not y_odd then
						for x = x_min, x_max, dist_between_roots do
							self:SpawnRootAt(x, y)
						end
					end
				end

			end
			self:WaitForSeconds(self.root_wave_pause)
		end
	end

	self:OnDoneAttack()
end


function RootAttacker:_grid_coro(data)
	coroutine.yield()

	local x_max, y_max = TheWorld.Map:GetSize()

	x_max = math.floor(x_max)
	y_max = math.floor(y_max)

	local x_min = -x_max
	local y_min = -y_max

	local num_loops = { 1, 1, 2, 3 }
	local loops = num_loops[self.phase]
	for loop = 1, loops do
		for attack_num = 1, 5 do
			for x = x_min, x_max, 3 do
				local x_odd = x%2 == 1
				for y = y_min, y_max, 3 do
					local y_odd = y%2 == 1
					if attack_num%2 == 1 and ((x_odd and y_odd) or (not x_odd and not y_odd)) then
						self:SpawnRootAt(x, y)
					elseif attack_num%2 == 0 and ((x_odd and not y_odd) or (not x_odd and y_odd)) then
						self:SpawnRootAt(x, y)
					end
				end
			end 
			self:WaitForSeconds(self.root_wave_pause)
		end
	end

	self:OnDoneAttack()
end

function RootAttacker:_spiral_coro(data)
	coroutine.yield()

	local num_spiral_rotations = 10
	local rotation_done = 0
	local rotation_to_do = num_spiral_rotations * 360
	local dist_out_per_root = 0.15
	local units_per_root = 5
	local root_num = 1
	local pos = Vector2(self.inst.Transform:GetWorldXZ())
	local base_offset = 5

	local cw_positions = {}
	while rotation_done < rotation_to_do do
		local rad = (dist_out_per_root * root_num) + base_offset
		local perimeter = 2 * math.pi * rad
		local resolution = math.floor(perimeter/units_per_root)
		local angle_between_roots = 360/resolution
		local offset = Vector2(math.sin(math.rad(rotation_done)) * rad, math.cos(math.rad(rotation_done)) * rad)
		local attack_pos = offset + pos
		if TheWorld.Map:IsGroundAtXZ(attack_pos.x, attack_pos.y) then
			local idx = math.max(math.ceil(rotation_done / 360), 1)
			if not cw_positions[idx] then
				cw_positions[idx] = {}
			end
			table.insert(cw_positions[idx], attack_pos)
		end
		root_num = root_num + 1
		rotation_done = rotation_done + angle_between_roots
	end

	root_num = 1

	local ccw_positions = {}
	while rotation_done > 0 do
		local rad = (dist_out_per_root * root_num) + base_offset
		local perimeter = 2 * math.pi * rad
		local resolution = math.floor(perimeter/units_per_root)
		local angle_between_roots = 360/resolution
		local offset = Vector2(math.sin(math.rad(rotation_done)) * rad, math.cos(math.rad(rotation_done)) * rad)
		local attack_pos = offset + pos
		if TheWorld.Map:IsGroundAtXZ(attack_pos.x, attack_pos.y) then
			local idx = math.max(math.ceil(rotation_done / 360), 1)
			if not ccw_positions[idx] then
				ccw_positions[idx] = {}
			end
			table.insert(ccw_positions[idx], attack_pos)
		end
		root_num = root_num + 1
		rotation_done = rotation_done - angle_between_roots
	end

	local num = math.min(#cw_positions, #ccw_positions)

	for i = 1, num do
		for _, atk in ipairs(cw_positions[i]) do
			self:SpawnRootAt(atk.x, atk.y)
			self:WaitForSeconds(0.10)
		end

		for _, atk in ipairs(ccw_positions[i]) do
			self:SpawnRootAt(atk.x, atk.y)
			self:WaitForSeconds(0.10)
		end
	end

	self:OnDoneAttack()
end

function RootAttacker:_lines_coro(data)
	coroutine.yield()

	local num_roots = {7, 8, 9, 10}
	local steps_by_phase = {10, 15, 20, 25}

	local rng = krandom.CreateGenerator(data.x)
	local angle_between_lines = 360/num_roots[self.phase]
	local angle_offset = rng:Integer(1, math.floor(angle_between_lines/2))
	local pos = Vector2(self.inst.Transform:GetWorldXZ())
	local num_steps = steps_by_phase[self.phase]
	local dist_per_step = 2

	for step = 1, num_steps do
		for i = 1, 360, angle_between_lines do
			local angle = math.rad(i + angle_offset)
			local offset = Vector2(math.sin(angle) * dist_per_step * step, math.cos(angle) * dist_per_step * step)
			local attack_pos = offset + pos
			self:SpawnRootAt(attack_pos.x, attack_pos.y)
		end
	self:WaitForSeconds(0.33)
	end
	self:OnDoneAttack()
end

function RootAttacker:_spin_coro(data)
	coroutine.yield()

	local num_roots = {4, 5, 6, 7}

	local rng = krandom.CreateGenerator(data.x)
	local angle_between_lines = 360 / num_roots[self.phase]
	local start_angle_offset = rng:Integer(45, 135)

	-- takes X attacks for one line to meet the start of the line ahead of it
	-- a higher number means the roots will step more gradually
	local angle_offset_step = angle_between_lines / 5

	local pos = Vector2(self.inst.Transform:GetWorldXZ())
	local num_steps = 10 -- how many roots in each line
	local dist_per_step = 2.5 -- spacing between each root in each line
	assert(dist_per_step < 3, "When dist_per_step < 3, there is a safe zone in front of Megatreemon.")

	local num_loops = {1, 2, 2, 3}
	local loops = num_loops[self.phase]
	for loop = 1, loops do
		for spin = 0, angle_between_lines - angle_offset_step, angle_offset_step do
			for step = 1, num_steps do
				for i = 1, 360, angle_between_lines do
					local angle = math.rad(i + spin + start_angle_offset)
					local offset = Vector2(math.sin(angle) * dist_per_step * step, math.cos(angle) * dist_per_step * step)
					local attack_pos = offset + pos
					self:SpawnRootAt(attack_pos.x, attack_pos.y)
				end
			end
			self:WaitForSeconds(self.root_wave_pause)
		end
	end

	self:OnDoneAttack()
end

function RootAttacker:_circle_coro(data)
	coroutine.yield()

	-- after around 7 steps, the roots are too far away to be on the stage
	-- for the fight this attack is only used in stage 3
	local steps_by_phase = {7, 7, 13, 13}

	local pos = Vector2(self.inst.Transform:GetWorldXZ())
	local num_steps = steps_by_phase[self.phase]
	local dist_per_step = 4 -- how apart are circles
	local units_per_root = 4 -- how tightly packed are roots within circles

	local steps_per_flip = 7 -- how many steps before the direction changes
	local rad = 0
	local move_direction = 1 -- flips between 1 and -1 to change attack directions

	for step = 1, num_steps do
		rad = rad + (dist_per_step * move_direction)
		local perimeter = 2 * math.pi * rad
		local resolution = math.floor(perimeter/units_per_root)
		local angle_between_roots = 360/resolution
		local positions = {}

		for angle = 0, 360, angle_between_roots do
			table.insert(positions, Vector2(math.sin(math.rad(angle)), math.cos(math.rad(angle))))
		end

		for _, attack_pos in ipairs(positions) do
			local offset = Vector2(attack_pos.x * (rad), attack_pos.y * (rad))
			local root_pos = offset + pos
			self:SpawnRootAt(root_pos.x, root_pos.y)
		end

		if step%steps_per_flip == 0 then
			move_direction = move_direction * -1
		end

		self:WaitForSeconds(self.root_wave_pause)
	end

	self:OnDoneAttack()
end


function RootAttacker:_targetted_attack_pre_coro(data)
	coroutine.yield()

	-- spawn 3 roots in a triangle shape around these coordinates
	local positions = {}

	local rad = 1.5
	local angle_between_roots = 360/3
	for angle = 1, 360, angle_between_roots do
		table.insert(positions, Vector2(math.sin(math.rad(angle)) * rad, math.cos(math.rad(angle)) * rad))
	end

	local num_roots = math.min(#positions, 3)
	local pos = Vector2(data.x, data.z)

	-- top, right, left
	local anim_num = { 2, 3, 4 }

	for i = 1, num_roots do
		local offset = Vector2(positions[i].x, positions[i].y)
		local attack_pos = offset + pos
		local root = self:SpawnRootAt(attack_pos.x, attack_pos.y, "attack_pre", anim_num[i], true)
		table.insert(self.attack_roots, root)
		self:WaitForSeconds(0.11)
	end
end

-- hack: force fire targeted attack roots if for some reason brain / coro decides to do another attack/command
function RootAttacker:ResetTargettedAttack()
	if #self.attack_roots > 0 then
		TheLog.ch.RootAttacker:printf("Force clearing attack roots in ResetTargettedAttack")
		for _i, root in ipairs(self.attack_roots) do
			root:PushEvent("attack")
		end
		table.clear(self.attack_roots)
	end
end

function RootAttacker:_finish_targetted_attack_coro()
	coroutine.yield()

	for i, root in ipairs(self.attack_roots) do
		root:PushEvent("attack")
		self:WaitForSeconds(0.11)
	end
	table.clear(self.attack_roots)
end

function RootAttacker:DebugDrawEntity(ui, panel, colors)

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
			-- "DoSpiralAttack",
			"DoGridAttack",
			"DoLinesAttack",
			"DoSpinAttack",
			"DoCircleAttack",
			"DoCirclesAttack",
			"DoHorizontalLineAttack",
			"DoVerticalLineAttack",
			"SpawnGuardRoots",
			"DespawnGuardRoots",
			"DoTargettedAttackPre",
			"FinishTargettedAttack",
		}
		for _,fn_name in ipairs(fns) do
			if ui:Button(fn_name) then
				local fn = self[fn_name]
				fn(self, data)
			end
		end
	end
end

return RootAttacker
