-- Initialization function for this prefab. The actual prefab is auto-generated via tools.
-- NOTE: The name for this file must match the prefab's name!

local trap_weed_thorns = {
}

local function OnRoomComplete(inst)
	inst.sg.mem.is_room_clear = true
	inst.sg:GoToState("retract")
end

function trap_weed_thorns:CustomInit(inst)
	-- Since thorns have a hitbox, prevent them from being teleported
	inst:AddTag("no_teleport")

	inst.HitBox:SetHitGroup(HitGroup.NEUTRAL)
	inst.HitBox:SetHitFlags(HitGroup.PLAYER | HitGroup.NPC | HitGroup.HOSTILES)

	inst:ListenForEvent("room_complete", function() OnRoomComplete(inst) end, TheWorld)

	return inst
end

return trap_weed_thorns
