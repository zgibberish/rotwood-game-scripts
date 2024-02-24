require "constants"
local lume = require "util.lume"
local playerutil = require "util.playerutil"

local DEFAULT_TUNING = {
	distance_from_centre = 1.5,
	singular_transition_ticks = 4 * SECONDS,
	deg_per_tick = 0.44,
	scales = { 1.24, 1.18, 1.1, 1, }
}
local TAU = 2 * math.pi

local RotatingDrop = Class(function(self, inst)
	self.inst = inst
	self.tuning = DEFAULT_TUNING
	self.child_drops = {}
	inst.core_drop = inst

	inst:ListenForEvent("selfdestruct_hint", function()
		for _, drop in pairs(self.child_drops) do
			drop:PushEvent("selfdestruct_hint")
		end
	end)
	inst:ListenForEvent("selfdestruct_abort", function()
		for _, drop in pairs(self.child_drops) do
			drop:PushEvent("selfdestruct_abort")
		end
	end)
	inst:ListenForEvent("on_fully_consumed", function()
		for _, drop in pairs(self.child_drops) do
			if drop.components.powerdrop then
				drop.components.powerdrop:OnFullyConsumed()
			end
			if drop.components.souldrop then
				drop.components.souldrop:OnFullyConsumed()
			end
		end
	end)
end)

function RotatingDrop:OnRemoveEntity()
	self:ClearDrops()
end

function RotatingDrop:SetTuning(tuning)
	self.tuning = tuning
end

function RotatingDrop:_PositionDrops()
	local count = self:GetDropCount()
	if count > 0 then
		local delta = TAU / count
		local i = 0
		for player, drop in pairs(self.child_drops) do
			i = i + 1
			local angle = delta * (i - 1)
			local offset = Vector2.unit_x:rotate(angle) * self.tuning.distance_from_centre
			drop.components.glue:FollowTarget(self.inst, offset)
		end
	end
end

function RotatingDrop:_ScaleDrops()
	local count = self:GetDropCount()
	if count > 0 then
		local s = self.tuning.scales[count]
		for player, drop in pairs(self.child_drops) do
			drop.AnimState:SetScale(s, s)
		end
	end
end

function RotatingDrop:SetOnDropSpawnFn(fn)
	self.on_drop_spawned_fn = fn
end

function RotatingDrop:ClearDrops()
	for player, drop in pairs(self.child_drops) do
		if drop:IsValid() and drop:IsLocal() then
			drop:Remove()
		end
		self.child_drops[player] = nil
	end
	if self.rotate_task then
		self.rotate_task:Cancel()
		self.rotate_task = nil
	end
	if self.monitor_task then
		self.monitor_task:Cancel()
		self.monitor_task = nil
	end
end

function RotatingDrop:GetDropCount()
	return table.count(self.child_drops)
end

function RotatingDrop:SetAnyInteract(bool)
	self.any_interact = true
end

function RotatingDrop:PlayerHasDrop(player)
	return self.any_interact or self.child_drops[player] ~= nil
end

-- Returns a table of players --> drop for all players that are NOT in remainingPlayers 
function RotatingDrop:GetPickedUpDrops(remainingPlayerIDs)
	-- Figure out if there are any drops that are not for players that are in the remainingPlayers table:
	local result = {}
	for player, drop in pairs(self.child_drops) do
		local playerID = player.Network:GetPlayerID()
		if not remainingPlayerIDs or not playerID or not table.contains(remainingPlayerIDs, playerID) then
			result[player] = drop
		end
	end
		
	return result
end

-- takes a table of drop prefabs, keyed by the player they will belong to.
-- local drops =
-- {
-- 	[p1] = "cool_drop",
-- 	[p2] = "cooler_drop",
-- 	[p3] = "cool_drop",
-- 	[p4] = "best_drop",
-- }
function RotatingDrop:SpawnDrops(drops)
	self:ClearDrops()

	for player, prefab in pairs(drops) do
		local drop = SpawnPrefab(prefab, self.inst)
		if drop then
			drop:AddComponent("glue")
			if not drop.components.cineactor then
				drop:AddComponent("cineactor")
			end
			if not drop:IsNetworked() then
				drop.components.cineactor:ForwardRolesTo(self.inst) -- If the drop entities aren't networked, make the root object trigger the cinematic and receive camera focus.
			end
			drop.core_drop = self.inst

			-- The core is invisible, so it must steal interaction clicks from drops
			self.inst.components.interactable:StealInteractionClicksFrom(drop)

			self.child_drops[player] = drop

			if self.on_drop_spawned_fn then
				self.on_drop_spawned_fn(player, drop)
			end

			if self.inst.components.powerdrop and self.inst.components.powerdrop:IsRelicDrop() then
				-- Only spawn one crystal
				-- TODO #powerdrop differentiate power crystals for different player counts
				break
			end
		end
	end

	local count = self:GetDropCount()
	self:_ScaleDrops()
	if count > 1 then
		self:_PositionDrops()
		local a = 0
		self.rotate_task = self.inst:DoPeriodicTicksTask(1, function(inst_)
			a = a + self.tuning.deg_per_tick
			self.inst.Transform:SetRotation(a)
		end)
	elseif count == 1 then
		local player, drop = next(self.child_drops)
		drop.components.glue:FollowTarget(self.inst)
	else
		TheLog.ch.RotatingDrop:printf("Warning: No drops spawned!")
	end
end

-- needs to be able to consume a specific drop prefab
function RotatingDrop:ConsumeDrop(player)
	local count = self:GetDropCount()
	if count == 0 then
		return
	end

	local child = self.child_drops[player]
	assert(child ~= nil, "Calling ConsumeDrop but all drops are consumed.")
	child.sg:GoToState("despawn")
	child:PushEvent("consume_drop", player)
	self.child_drops[player] = nil

	local only_one_left = self:GetDropCount() == 1

	if only_one_left then
		player, child = next(self.child_drops)
		local t = 0
		self.singular_task = self.inst:DoPeriodicTicksTask(1, function(inst_)
			t = t + 1
			local p = lume.clamp(t / self.tuning.singular_transition_ticks, 0, 1)
			local d = self.tuning.distance_from_centre * (1-p)
			if child and child:IsValid() and child:IsLocal() then
				child.Transform:SetPosition(d,0,0)
			end
			if p >= 1 then
				self.rotate_task:Cancel()
				self.singular_task:Cancel()
				self.rotate_task = nil
				self.singular_task = nil
			end
		end)
	end
end

function RotatingDrop:ConsumeAllDrops()
	if self:GetDropCount() == 0 then
		return
	elseif self.consuming then
		return
	end

	self.consuming = true
	local i = 0
	for player, drop in pairs(self.child_drops) do
		i = i + 1
		local delayi = i - 1 -- So the first one pops immediately, and the rest are sequential
		self.inst:DoTaskInAnimFrames(delayi * 15, function()
			if drop and drop.sg then
				drop.sg:GoToState("despawn")
			end
		end)
	end
end

function RotatingDrop:SetBuildDropsFn(fn)
	self.build_drops_fn = fn
end

function RotatingDrop:BuildDrops()
	return self.build_drops_fn(self.inst)
end

local MonitorInterval <const> = 0.2
local MonitorTimeout <const> = 10.0

function RotatingDrop:PrepareToShowDrops()
	if self.monitor_task then
		return
	end

	TheLog.ch.RotatingDrop:printf("Monitoring player count to spawn drops...")
	self.monitor_timeout = MonitorTimeout
	self.monitor_task = self.inst:DoPeriodicTask(MonitorInterval, function(_inst)
		local playerCount = #TheNet:GetPlayerList()
		if self.monitor_timeout <= 0.0 or
			playerutil.CountActivePlayers() >= math.min(playerCount, TheNet:GetNrPlayersOnRoomChange()) then
			TheLog.ch.RotatingDrop:printf("Monitoring player count to spawn drops... complete.")
			if self:GetDropCount() == 0 then
				local drops = self:BuildDrops()
				self:SpawnDrops(drops)
			end

			local i = 0
			for _player, drop in pairs(self.child_drops) do
				drop.sg:GoToState("spawn_pre")
				local additional_delay = i * TUNING.POWERS.DROP_SPAWN_SEQUENCE_DELAY_FRAMES_PLAIN
				drop.sg:SetTimeoutTicks((drop.sg.timeoutticks or 0.0) + additional_delay)
				i = i + 1
			end

			if self.monitor_task then
				self.monitor_task:Cancel()
				self.monitor_task = nil
			end
		else
			self.monitor_timeout = self.monitor_timeout - MonitorInterval

			-- TODO: Add a busy indicator if this is taking a while
			-- No player feedback otherwise for ready, but slow-loading players in starting room

			if self.monitor_timeout <= 0.0 then
				TheLog.ch.RotatingDrop:printf("Warning: Timed out monitoring player count (%d) to match players on room change (%d)",
					playerutil.CountActivePlayers(), TheNet:GetNrPlayersOnRoomChange())
			end
		end
	end)
end

function RotatingDrop:DebugDrawEntity(ui, panel, colors)
	local count = self:GetDropCount()
	for owner, drop in pairs(self.child_drops) do
		ui:Text(string.format("%s, %s", owner, drop))
	end

	local changed, newval = ui:SliderFloat("Distance from Centre", self.tuning.distance_from_centre, 0.1, 10)
	if changed then
		self.tuning.distance_from_centre = newval
		self:_PositionDrops()
	end
	self.tuning.deg_per_tick = ui:_SliderFloat("Rotation deg/tick", self.tuning.deg_per_tick, 0.1, 10)
	local s = self.tuning.scales[count]
	if s then
		changed, s = ui:SliderFloat("Scale", s, 0.1, 5)
		if changed then
			self.tuning.scales[count] = s
			self:_ScaleDrops()
		end
	end

	if ui:Button("ConsumeDrop") then
		self:ConsumeDrop()
	end
	if ui:Button("ConsumeAllDrops") then
		self:ConsumeAllDrops()
	end
	if ui:Button("PrepareToShowDrops") then
		local powerdrop = self.inst.core_drop.components.souldrop ~= nil and self.inst.core_drop.components.souldrop or self.inst.core_drop.components.powerdrop
		powerdrop:PrepareToShowGem({
  					appear_delay_ticks = TUNING.POWERS.DROP_SPAWN_INITIAL_DELAY_FRAMES,
  				})
		self:PrepareToShowDrops()
	end
end

return RotatingDrop
