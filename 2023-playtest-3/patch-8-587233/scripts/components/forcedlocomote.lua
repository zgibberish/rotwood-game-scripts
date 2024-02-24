local krandom = require "util.krandom"
local lume = require "util.lume"
require "class"

-- Force player to locomote when they enter a room so they look like they came
-- in running.
local ForcedLocomote = Class(function(self, inst)
	self.inst = inst

	self._onenter_room = function(source, data)
		if not data or not data.no_force_locomote then
			self:_EnterRoom()
		end
	end
	self.inst:ListenForEvent("enter_room", self._onenter_room)
end)

function ForcedLocomote:OnRemoveFromEntity()
	self.inst:RemoveEventCallback("enter_room", self._onenter_room)
end
function ForcedLocomote:OnRemoveEntity()
	self:OnRemoveFromEntity()
end

function ForcedLocomote:_EnterRoom()
	if TheDungeon:GetDungeonMap():IsCurrentRoomDungeonEntrance() then
		return
	else
		local players = TheNet:GetPlayersOnRoomChange()
		if not lume.find(players, self.inst) then
			return
		end
	end
	local entrance = TheDungeon:GetDungeonMap():GetCardinalDirectionForEntrance()
	self:LocomoteAwayFrom(entrance)
end

local cardinal_to_dir = {
	north = 90,
	south = -90,
	east = 180,
	west = 0,
}

local cardinal_to_min_delay = {
	-- Keep these times short to avoid blocking player control.
	north = 0.5,
	south = 0.5,
	east = 0.1,
	west = 0.1,
}

function ForcedLocomote:LocomoteAwayFrom(cardinal)
	if not cardinal then
		TheLog.ch.ForcedLocomote:printf("Warning: LocomoteAwayFrom called with no cardinal direction")
		return
	end

	local dir = cardinal_to_dir[cardinal]
	self.inst.components.playercontroller:ForceAnalogMoveDir(dir)

	-- Variance to make multiple players not quite line up.
	local delay = cardinal_to_min_delay[cardinal] + krandom.Float(0.3)
	self.inst:DoTaskInTime(delay, function(inst_)
		self:AbortMove()
	end)
end

function ForcedLocomote:AbortMove()
	if self.move_task then
		self.move_task:Cancel()
		self.move_task = nil
	end
	self.inst.components.playercontroller:ForceAnalogMoveDir(nil)
end

local function noop() end
function ForcedLocomote:LocomoteTo(point, timeout_ticks, threshold, facing_target_pos, complete_cb)
	if not self.inst:IsLocal() then
		return
	end
	assert(timeout_ticks, "Must specify a timeout to avoid getting locked into movement.")
	threshold = threshold or 10
	complete_cb = complete_cb or noop

	self:AbortMove()

	local ticks = 0
	self.move_task = self.inst:DoPeriodicTicksTask(1, function(inst_)
		ticks = ticks + 1
		local delta = self:_TickMoveTowards(point)
		if ticks > timeout_ticks or delta:len2() < threshold then
			self:AbortMove()
			if facing_target_pos then
				self.move_task = self.inst:DoPeriodicTicksTask(1, function()
					-- Should this use SGCommon.Fns.FaceActionTarget(self.inst, facing_target_pos, false, true)?
					self.inst:FacePoint(facing_target_pos)
					self:AbortMove()
					complete_cb(self.inst)
				end)
			else
				complete_cb(self.inst)
			end
		end
	end)
end

-- Follows target entity until you call AbortMove.
--
-- This is not very robust, but useful for testing multiplayer.
function ForcedLocomote:ChaseEntity(target, threshold)
	self:AbortMove()
	local function Loco(cb)
		self:LocomoteTo(target:GetPosition(), math.huge, threshold, nil, cb)
	end
	local loop
	loop = function()
		-- Delay before move to prevent stutter walk.
		self.move_task = self.inst:DoTaskInTime(0.5, function(inst_)
			Loco(loop)
		end)
	end
	loop()
end

function ForcedLocomote:_TickMoveTowards(point)
	local delta = point - self.inst:GetPosition()
	local dir = delta:to_xz():angle_to()
	dir = -math.deg(dir)
	self.inst.components.playercontroller:ForceAnalogMoveDir(dir)
	return delta
end

return ForcedLocomote
