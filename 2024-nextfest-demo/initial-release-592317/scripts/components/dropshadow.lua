local DropShadow = Class(function(self, inst)
	self.inst = inst

	local drop_shadow = CreateEntity()
	drop_shadow.prefabname = "drop_shadow"
    drop_shadow.entity:AddTransform()
    drop_shadow.entity:AddAnimState()
	drop_shadow.AnimState:SetBank("fx_shadow")
	drop_shadow.AnimState:SetBuild("fx_shadow")
	drop_shadow.AnimState:PlayAnimation("idle", true)
    drop_shadow.AnimState:SetOrientation(ANIM_ORIENTATION.OnGround)
    drop_shadow.AnimState:SetLayer(LAYER_BACKGROUND)
    drop_shadow.AnimState:SetClipAtWorldEdge(false) -- this set true causes the shadow to flicker when travelling across the ground for some reason
    drop_shadow.AnimState:SetSortOrder(2)
    drop_shadow.AnimState:SetBrightness(0)
    drop_shadow.entity:SetParent(self.inst.entity) -- being a child, it gets removed with parent
    self.inst:StartUpdatingComponent(self)

    self.drop_shadow = drop_shadow
end)

function DropShadow:SetBank(...)
    self:GetDropShadow().AnimState:SetBank(...)
end

function DropShadow:SetBuild(...)
    self:GetDropShadow().AnimState:SetBuild(...)
end

function DropShadow:PlayAnimation(...)
    self:GetDropShadow().AnimState:PlayAnimation(...)
end

function DropShadow:SetMultColor(...)
    self:GetDropShadow().AnimState:SetMultColor(...)
end

function DropShadow:SetBloom(...)
    self:GetDropShadow().AnimState:SetBloom(...)
end

function DropShadow:SetBrightness(...)
    self:GetDropShadow().AnimState:SetBrightness(...)
end

function DropShadow:GetDropShadow()
    return self.drop_shadow
end

function DropShadow:OnUpdate(dt)
    -- ensure shadow is grounded no matter where the parents position is
    local parent_x, parent_y, parent_z = self.inst.Transform:GetWorldPosition()
    self.drop_shadow.Transform:SetWorldPosition(parent_x, 0, parent_z)
    --self.drop_shadow.Transform:SetPosition(0, -parent_y, 0) -- sets local position when shadow is parented
end

return DropShadow