require("util/sourcemodifiers")

local Scalable = Class(function(self, inst)
	self.inst = inst
	self.base_scale = 1
	self.base_size = 1
	self.hitbox_sizes = {}

	self.scale_modifiers = MultSourceModifiers(inst)

	self:SnapshotBaseSize()
end)

function Scalable:SnapshotBaseSize()
	if self.scale_modifiers:Get() ~= 1 then
		assert(false, string.format("tried to call Scalable:SnapshotBaseSize() on %s when scale modifiers have already been applied!", self.inst))
	end

	self.base_scale = self.inst.Transform:GetScale()
	self.base_size = self.inst.Physics:GetSize()

	if self.inst.hitboxes == nil then
		assert(false, string.format("tried to call Scalable:SnapshotBaseSize() on %s that has no hitboxes registered.", self.inst))
	end

	for name, inst in pairs(self.inst.hitboxes) do
		self.hitbox_sizes[name] = inst.HitBox:GetSize()
	end

	if self.inst.components.offsethitboxes then
		for name, inst in pairs(self.inst.components.offsethitboxes.hitboxes) do
			assert(not self.hitbox_sizes[name])
			self.hitbox_sizes[name] = inst.HitBox:GetSize()
		end
	end
end

function Scalable:AddScaleModifier(source, mod)
	self.scale_modifiers:SetModifier(source, mod)
	self:OnScaleChanged()
end

function Scalable:RemoveScaleModifier(source)
	self.scale_modifiers:RemoveModifier(source)
	self:OnScaleChanged()
end

function Scalable:GetTotalScaleModifier()
	return self.scale_modifiers:Get()
end

function Scalable:OnScaleChanged()
	local new_scale = self.base_scale * self.scale_modifiers:Get()
	new_scale = math.max(new_scale, 0.1)
	self.inst.Transform:SetScale(new_scale, new_scale, new_scale)

	local new_size = self.base_size * self.scale_modifiers:Get()
	new_size = math.max(new_size, 0.1)
	self.inst.Physics:SetSize(new_size)

	for name, base_size in pairs(self.hitbox_sizes) do
		local hitbox_size = base_size * self.scale_modifiers:Get()
		hitbox_size = math.max(hitbox_size, 0.1)

		local hitbox
		if self.inst.hitboxes[name] then
			hitbox = self.inst.hitboxes[name]
		elseif self.inst.components.offsethitboxes then
			hitbox = self.inst.components.offsethitboxes:Get(name)
		end

		if hitbox then
			hitbox.HitBox:SetNonPhysicsRect(hitbox_size)
		end
	end

	self.inst:PushEvent("scale_changed", new_scale)
end

function Scalable:DebugDrawEntity(ui, panel, colors)
	local key <const> = "DebugDrawEntity"
	if self.scale_modifiers:GetModifier(key) then
		if ui:Button("Remove Scale") then
			self:RemoveScaleModifier(key, 1.5)
		end
	else
		if ui:Button("Add Scale Bigger") then
			self:AddScaleModifier(key, 1.5)
		end
		if ui:Button("Add Scale Smaller") then
			self:AddScaleModifier(key, 0.5)
		end
	end
	local s = self.base_scale * self.scale_modifiers:Get()
	s = math.max(s, 0.1)
	ui:Value("Applied Scale", s)
end

return Scalable
