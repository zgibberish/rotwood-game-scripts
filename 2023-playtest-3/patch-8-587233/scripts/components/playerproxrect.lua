local DebugDraw = require "util.debugdraw"

local PlayerProxRect = Class(function(self, inst)
	self.inst = inst
	self.x1 = 0
	self.z1 = 0
	self.x2 = 0
	self.z2 = 0
	self.buffer = 1
	self.inrange = false
	self.updating = false
	self.onnearfn = nil
	self.onfarfn = nil
end)

function PlayerProxRect:SetRect(x1, z1, x2, z2)
	self.x1 = math.min(x1, x2)
	self.x2 = math.max(x1, x2)
	self.z1 = math.min(z1, z2)
	self.z2 = math.max(z1, z2)
	self:CheckUpdate()
	return self
end

function PlayerProxRect:SetBuffer(buffer)
	self.buffer = buffer
	return self
end

-- fn receives the PlayerProxRadial as inst argument. It can do
-- inst:GetClosestPlayer() or self:FindPlayersInRange() to
-- find relevant players.
function PlayerProxRect:SetOnNearFn(fn)
	self.onnearfn = fn
	self:CheckUpdate()
	return self
end

function PlayerProxRect:SetOnFarFn(fn)
	self.onfarfn = fn
	self:CheckUpdate()
	return self
end

-- consider this part of the "PlayerProx interface"
function PlayerProxRect:FindPlayersInRange()
	-- Not using playerutil.FindPlayersInRange so we find in a rect instead of
	-- circle.
	local x1, z1, x2, z2 = self:_GetWorldRect(self.inrange)
	local players = {}
	for _,candidate in ipairs(AllPlayers) do
		if self:_IsPlayerInRect(candidate, x1, z1, x2, z2) then
			table.insert(players, candidate)
		end
	end
	return players
end

function PlayerProxRect:IsXZInRange(x, z)
	return self:_IsXZInRect(x, z, self:_GetWorldRect(self.inrange))
end

function PlayerProxRect:CheckUpdate()
	local shouldupdate = self.x1 < self.x2 and self.z1 < self.z2 and (self.onnearfn ~= nil or self.onfarfn ~= nil)
	if self.updating ~= shouldupdate then
		self.updating = shouldupdate
		if shouldupdate then
			self.inst:StartUpdatingComponent(self)
		else
			self.inst:StopUpdatingComponent(self)
		end
	end
end

function PlayerProxRect:_IsAnyPlayerInRect(x1, z1, x2, z2)
	for _,candidate in ipairs(AllPlayers) do
		if self:_IsPlayerInRect(candidate, x1, z1, x2, z2) then
			return true
		end
	end
	return false
end

function PlayerProxRect:_IsPlayerInRect(player, x1, z1, x2, z2)
	if not player or not player:IsValid() or player:IsInLimbo() then
		return false
	end
	local x, z = player.Transform:GetWorldXZ()
	return self:_IsXZInRect(x, z, x1, z1, x2, z2)
end
function PlayerProxRect:_IsXZInRect(x, z, x1, z1, x2, z2)
	return (x1 < x and x < x2
		and z1 < z and z < z2)
end

function PlayerProxRect:_GetWorldRect(inrange)
	local x1, z1, x2, z2
	if inrange then
		x1, z1, x2, z2 = self.x1 - self.buffer, self.z1 - self.buffer, self.x2 + self.buffer, self.z2 + self.buffer
	else
		x1, z1, x2, z2 = self.x1, self.z1, self.x2, self.z2
	end
	local x, z = self.inst.Transform:GetWorldXZ()
	x1, z1 = x + x1, z + z1
	x2, z2 = x + x2, z + z2
	return x1, z1, x2, z2
end

function PlayerProxRect:OnUpdate()
	local has_player = self:_IsAnyPlayerInRect(self:_GetWorldRect(self.inrange))
	if self.inrange then
		if not has_player then
			self.inrange = false
			if self.onfarfn ~= nil then
				self.onfarfn(self.inst)
			end
		end
	else
		if has_player then
			self.inrange = true
			if self.onnearfn ~= nil then
				self.onnearfn(self.inst)
			end
		end
	end
end

--------------------------------------------------------------------------

function PlayerProxRect:SetDebugDrawEnabled(enable)
	self.debugdraw = not not enable
	if enable then
		self.inst:StartWallUpdatingComponent(self)
	else
		self.inst:StopWallUpdatingComponent(self)
	end
	return self
end

function PlayerProxRect:OnWallUpdate()
	local x1, z1, x2, z2 = self:_GetWorldRect(self.inrange)
	local c = self.updating and WEBCOLORS.WHITE or WEBCOLORS.RED
	DebugDraw.GroundRect(x1, z1, x2, z2, c)
end

function PlayerProxRect:DebugDrawEntity(ui, panel, colors)
	if ui:Button("Toggle debug draw") then
		self:SetDebugDrawEnabled(not self.debugdraw)
	end
	ui:SameLineWithSpace()
	ui:ColorButton("Updating", WEBCOLORS.WHITE)
	ui:SameLineWithSpace()
	ui:ColorButton("Inactive", WEBCOLORS.RED)
end

--------------------------------------------------------------------------

return PlayerProxRect
