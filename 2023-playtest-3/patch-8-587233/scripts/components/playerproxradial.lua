local DebugDraw = require "util.debugdraw"
local playerutil = require "util.playerutil"


local PlayerProxRadial = Class(function(self, inst)
	self.inst = inst
	self.radius = 0
	self.buffer = 1
	self.inrange = false
	self.updating = false
	self.onnearfn = nil
	self.onfarfn = nil
end)

function PlayerProxRadial:SetRadius(range)
	self.radius = range
	self:CheckUpdate()
	return self
end

function PlayerProxRadial:SetBuffer(buffer)
	self.buffer = buffer
	return self
end

-- fn receives the PlayerProxRadial as inst argument. It can do
-- inst:GetClosestPlayer() or self:FindPlayersInRange() to
-- find relevant players.
function PlayerProxRadial:SetOnNearFn(fn)
	self.onnearfn = fn
	self:CheckUpdate()
	return self
end

function PlayerProxRadial:SetOnFarFn(fn)
	self.onfarfn = fn
	self:CheckUpdate()
	return self
end

-- consider this part of the "PlayerProx interface"
function PlayerProxRadial:FindPlayersInRange()
	local x, y, z = self.inst.Transform:GetWorldPosition()
	local players = playerutil.FindPlayersInRange(x, z, self.radius + self.buffer)
	return players
end

function PlayerProxRadial:IsXZInRange(x, z)
	local r = self.radius + self.buffer
	local delta = Vector3(x, 0, z) - self.inst:GetPosition()
	return delta:len2() < r * r
end

function PlayerProxRadial:CheckUpdate()
	local shouldupdate = self.radius > 0 and (self.onnearfn ~= nil or self.onfarfn ~= nil)
	if self.updating ~= shouldupdate then
		self.updating = shouldupdate
		if shouldupdate then
			self.inst:StartUpdatingComponent(self)
			if self.debugdraw then
				self.inst:StartWallUpdatingComponent(self)
			end
		else
			self.inst:StopUpdatingComponent(self)
			if self.debugdraw then
				self.inst:StopWallUpdatingComponent(self)
			end
		end
	end
end

function PlayerProxRadial:OnUpdate()
	if self.inrange then
		if not self.inst:IsNearPlayer(self.radius + self.buffer) then
			self.inrange = false
			if self.onfarfn ~= nil then
				self.onfarfn(self.inst)
			end
		end
	else
		if self.inst:IsNearPlayer(self.radius) then
			self.inrange = true
			if self.onnearfn ~= nil then
				self.onnearfn(self.inst)
			end
		end
	end
end

--------------------------------------------------------------------------

function PlayerProxRadial:SetDebugDrawEnabled(enable)
	self.debugdraw = not not enable
	if enable then
		self.inst:StartWallUpdatingComponent(self)
	else
		self.inst:StopWallUpdatingComponent(self)
	end
	return self
end

function PlayerProxRadial:OnWallUpdate()
	local x, z = self.inst.Transform:GetWorldXZ()
	local radius = self.inrange and self.radius + self.buffer or self.radius
	local c = self.updating and WEBCOLORS.WHITE or WEBCOLORS.RED
	DebugDraw.GroundCircle(x, z, radius, c)
end

function PlayerProxRadial:DebugDrawEntity(ui, panel, colors)
	if ui:Button("Toggle debug draw") then
		self:SetDebugDrawEnabled(not self.debugdraw)
	end
	ui:SameLineWithSpace()
	ui:ColorButton("Updating", WEBCOLORS.WHITE)
	ui:SameLineWithSpace()
	ui:ColorButton("Inactive", WEBCOLORS.RED)
end

--------------------------------------------------------------------------

return PlayerProxRadial
