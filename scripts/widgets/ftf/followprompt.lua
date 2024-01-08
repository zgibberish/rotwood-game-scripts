local Widget = require("widgets/widget")

local function OnUpdate(updater)
	updater:GetParent():OnUpdateFollower()
end

local FollowPrompt = Class(Widget, function(self, name)
	Widget._ctor(self, name)

	self:SetControlDownSound(nil)
	self:SetControlUpSound(nil)
	self:SetGainFocusSound(nil)

	self.target = nil
	self.screen_offset_x = 0
	self.screen_offset_y = 0
	self.world_offset = Vector3()

	--separate widget for update, since ImageButton already
	--has internal logic for starting/stopping update.
	self.updater = self:AddChild(Widget("FollowPrompt_Updater"))
	self.updater.OnUpdate = OnUpdate

	self._onremovefn = function() self:SetTarget(nil) end

end)

function FollowPrompt:SetTarget(target)
	if self.target ~= target then

		if self.target then
			self.inst:RemoveEventCallback("onremove", self._onremovefn, self.target)
		end

		self.target = target
		if target ~= nil then

			self.inst:ListenForEvent("onremove", self._onremovefn, target )

			self.updater:StartUpdating()
			self:OnUpdateFollower()
		else
			self.updater:StopUpdating()
		end
	end
	return self
end

function FollowPrompt:GetTarget()
	return self.target
end

function FollowPrompt:Offset(dx, dy)
	-- Since we SetPosition in update, Widget:Offset() doesn't work and we need
	-- this custom implementation.
	self.screen_offset_x = dx
	self.screen_offset_y = dy
	if self.target ~= nil then
		self:OnUpdateFollower()
	end
	return self
end

-- Offset in symbol space if using an anim symbol, worldspace otherwise. Useful
-- to position at the object's feet/head, etc. Use Offset() to position
-- relative to other widgets.
function FollowPrompt:SetOffsetFromTarget(offset)
	assert(Vector3.is_vec3(offset))
	self.world_offset = offset
	if self.target ~= nil then
		self:OnUpdateFollower()
	end
	return self
end

function FollowPrompt:SetSymbol(symbol)
	self.symbol = symbol
	return self
end

function FollowPrompt:OnUpdateFollower()
	local x, y, z
	if self.symbol and self.target.AnimState then
		x, y, z = self.target.AnimState:GetSymbolPosition(self.symbol, self.world_offset:unpack())
	else
		x, y, z = self.target.Transform:GetWorldPosition()
		x = x + self.world_offset.x
		y = y + self.world_offset.y
		z = z + self.world_offset.z
	end
	x, y = self:CalcLocalPositionFromWorldPoint(x, y, z)
	local depth_changed = self.z ~= z
	self:SetPosition(x + self.screen_offset_x, y + self.screen_offset_y, z)
	if depth_changed then
		TheDungeon.HUD:UpdateGameWorld()
	end
end


function FollowPrompt:DebugDraw_AddSection(ui, panel)
	FollowPrompt._base.DebugDraw_AddSection(self, ui, panel)

	ui:Spacing()
	ui:Text("FollowPrompt")
	ui:Indent() do
		ui:DragVec3f("OffsetFromTarget", self.world_offset, nil, -100, 100)
	end
	ui:Unindent()
end

return FollowPrompt
