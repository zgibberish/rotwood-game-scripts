local assets =
{
    Asset("ANIM", "anim/mouseover.zip"),
}

local function fn()
    local inst = CreateEntity()
    inst.persists = false

    inst.entity:AddTransform()
    inst.entity:AddAnimState()

    inst.AnimState:SetBank("mouseover")
    inst.AnimState:SetBuild("mouseover")
    inst.AnimState:SetMultColor(table.unpack(WEBCOLORS.RED))
    inst.AnimState:PlayAnimation("circle")
    inst.AnimState:SetOrientation(ANIM_ORIENTATION.OnGround)
    inst.AnimState:SetLayer(LAYER_BACKGROUND)
    inst.AnimState:SetSortOrder(2)

    -- Make draggable with alt-drag.
    inst:AddComponent("prop")

    if not inst.components.prop.edit_listeners then
        -- we don't persist so we can always be edited.
        inst.components.prop:ListenForEdits()
    end
    assert(inst.components.prop.edit_listeners)

    -- Spawn and add a task to move your object around:
    --   self.handle = SpawnPrefab("debug_draggable", inst)
    --   function self.handle.move_obj(inst)
    --       if inst.components.prop:IsDragging() then
    --       	self:CleanupDuringDrag()
    --       end
    --       if self.object_to_move then
    --           local x,z = inst.Transform:GetWorldXZ()
    --           self.object_to_move.Transform:SetPosition(x, 0, z)
    --       end
    --   end
    --   self.handle:DoPeriodicTask(0, self.handle.move_obj)

    return inst
end

return Prefab("debug_draggable", fn, assets)
