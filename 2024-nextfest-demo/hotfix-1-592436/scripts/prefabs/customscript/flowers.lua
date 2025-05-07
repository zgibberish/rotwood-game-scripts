---------------------------------------------------------------------------------------
--Custom script for auto-generated prop prefabs
---------------------------------------------------------------------------------------

local function CollectPrefabs(prefabs, args)
	prefabs[#prefabs + 1] = "interact_pointer"
end

local function OnRoomLocked(inst)
	inst.components.interactable:SetInteractCondition_Never()
end

local function OnRoomUnlocked(inst)
	inst.components.interactable
		:SetRadius(1)
		:SetupTargetIndicator("interact_pointer")
		:SetInteractStateName("pickup")
		:SetInteractCondition_Always()
end

local function MakePickable(item)
	return function(inst, args)
		-- inst:AddComponent("interactable")
		-- 	:SetInteractCondition_Never()
		-- inst:AddComponent("pickable")
		-- inst.components.pickable:SetPickedItem(item)
		-- inst.components.pickable:SetOnPickedFn(inst.Remove)

		-- inst:ListenForEvent("room_locked", function() OnRoomLocked(inst) end, TheWorld)
		-- inst:ListenForEvent("room_unlocked", function() OnRoomUnlocked(inst) end, TheWorld)
		-- if not TheWorld.components.roomlockable:IsLocked() then
		-- 	OnRoomUnlocked(inst)
		-- end
	end
end

return
{
	flower_bush =
	{
		CollectPrefabs = CollectPrefabs,
		CustomInit = MakePickable("flower_bush"),
	},

	flower_violet =
	{
		CollectPrefabs = CollectPrefabs,
		CustomInit = MakePickable("flower_violet"),
	},
}
