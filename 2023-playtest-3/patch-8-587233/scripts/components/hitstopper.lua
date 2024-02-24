local HitStopper = Class(function(self, inst)
	self.inst = inst
	self.children = {}
	self.parent = nil
	self.hitstopmultiplier = 1

	self._onremovechild = function(child) self.children[child] = nil end
end)

function HitStopper:OnRemoveEntity()
	self:SetParentInternal(nil)

	for k in pairs(self.children) do
		self:DetachChild(k)
	end
end

function HitStopper:OnRemoveFromEntity()
	self:OnRemoveEntity()
end

function HitStopper:AttachChild(child)
	if self.children[child] == nil then
		self.children[child] = true

		if child.components.hitstopper ~= nil then
			child.components.hitstopper:SetParentInternal(self.inst)
		else
			self.inst:ListenForEvent("onremove", self._onremovechild, child)
		end
	end
end

function HitStopper:DetachChild(child)
	if self.children[child] ~= nil then
		self.children[child] = nil

		if child.components.hitstopper ~= nil then
			child.components.hitstopper:SetParentInternal(nil)
		else
			self.inst:RemoveEventCallback("onremove", self._onremovechild, child)
		end
	end
end

function HitStopper:SetParentInternal(parent)
	local old = self.parent
	if parent ~= old then
		if old ~= nil then
			self.parent = nil
			old.components.hitstopper:DetachChild(self.inst)
		end
		if parent ~= nil then
			self.parent = parent
			parent.components.hitstopper:AttachChild(self.inst)
		end
	end
end

-- expressed in anim frames
function HitStopper:PushHitStop(frames)
	if self.parent ~= nil then
		self.parent.components.hitstopper:PushHitStop(frames)
	else
		self:PushHitStopInternal(frames)
	end
end

function HitStopper:PushHitStopInternal(frames)
	frames = frames * self.hitstopmultiplier
	HitStopManager:PushHitStop(self.inst, frames)

	for k in pairs(self.children) do
		if k.components.hitstopper ~= nil then
			k.components.hitstopper:PushHitStopInternal(frames)
		else
			HitStopManager:PushHitStop(k, frames)
		end
	end
end

function HitStopper:GetHitStopMultiplier(mult)
	return self.hitstopmultiplier
end
function HitStopper:SetHitStopMultiplier(mult)
	self.hitstopmultiplier = mult
end

return HitStopper
