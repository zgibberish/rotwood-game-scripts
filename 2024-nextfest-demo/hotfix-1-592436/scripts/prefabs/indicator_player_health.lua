local assets =
{
	Asset("ANIM", "anim/fx_low_health_sweat.zip"),
}

local prefabs = {
	"fx_low_health_sweat",
}

local function OnLowHealthChanged(inst, source, data)
	local should_show = source.components.health:IsLow()
	if should_show then
		-- Wait extra long so anim start after hit fx have settled.
		inst.sg:GoToState("wait", 2)
	else
		inst.sg:GoToState("hidden")
	end
end

local function WatchHealth(inst, target)
	dbassert(target)
	-- Main entity for the face sweat.
	inst.entity:SetParent(target.entity)
	inst.entity:AddFollower()
	inst.Follower:FollowSymbol(target.GUID, "hair_front01")
	inst.Follower:SetOffset(-90,23,0)
	inst.sg.mem.target = target

	inst._onhealthchanged = function(source, data) inst:OnLowHealthChanged(source, data) end
	inst:ListenForEvent("healthchanged", inst._onhealthchanged, target)
end
local function OnRemoveEntity(inst)
	inst:RemoveEventCallback("healthchanged", inst._onhealthchanged, inst.sg.mem.target)
end

local function fn(prefabname)
	local inst = CreateEntity()
	inst:SetPrefabName(prefabname)

	inst.entity:AddTransform()
	inst.entity:AddAnimState()

	inst.AnimState:SetBank("fx_low_health_sweat")
	inst.AnimState:SetBuild("fx_low_health_sweat")
	inst.Transform:SetTwoFaced()

	inst:SetStateGraph("sg_health_indicator")

	--~ inst.sg.mem.vfx_prefab = "fx_low_health_sweat"

	inst.WatchHealth = WatchHealth
	inst.OnLowHealthChanged = OnLowHealthChanged
	inst.OnRemoveEntity = OnRemoveEntity

	-- Tuning: Uncomment and edit the Offset in Follower section of the Entity
	-- Debugger. Use keypad minus to reduce player health.
	--~ d_viewinpanel(inst)

	return inst
end

return Prefab("indicator_player_health", fn, assets, prefabs)
