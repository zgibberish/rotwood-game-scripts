local spawnutil = require "util.spawnutil"

local room_loot_drops =
{
	"power_drop_player",
	"drop_konjur",
	"power_drop_skill",

	"soul_drop_lesser",
	"soul_drop_greater",
	"soul_drop_heart",	

	GroupPrefab("power_drops"),
}

local function fn(prefabname)
	local inst = CreateEntity()
	inst:SetPrefabName(prefabname)

	inst.entity:AddTransform()

	if TheDungeon:GetDungeonMap():IsDebugMap() then
		inst.entity:AddAnimState()
		inst.AnimState:SetBank("mouseover")
		inst.AnimState:SetBuild("mouseover")
		inst.AnimState:SetMultColor(table.unpack(UICOLORS.KONJUR_DARK))
		inst.AnimState:PlayAnimation("square")
		inst.AnimState:SetScale(1, 1)
		inst.AnimState:SetOrientation(ANIM_ORIENTATION.OnGround)
		inst.AnimState:SetLayer(LAYER_BACKGROUND)
		inst.AnimState:SetSortOrder(1)
		inst:AddTag("FX")
		inst:AddTag("NOCLICK")
		spawnutil.SetupPreviewPhantom(inst, "power_drop_generic_1p")
	end

	inst:AddTag("CLASSIFIED")
	--[[Non-networked entity]]

	inst:AddComponent("prop")
	inst:AddComponent("snaptogrid")
	inst.components.snaptogrid:SetDimensions(3, 3, -2)

	TheWorld.components.powerdropmanager:AddSpawner(inst)

	return inst
end

return Prefab("room_loot", fn, nil, room_loot_drops)
