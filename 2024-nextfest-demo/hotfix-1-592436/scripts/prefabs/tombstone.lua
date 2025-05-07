local easing = require "util.easing"

local assets =
{
	Asset("ANIM", "anim/tombstone.zip"),
}

local function SetCreature(inst, name)
	inst.creature = name
	inst.AnimState:OverrideSymbol("head_swap", "tombstone", "head_"..name)
end

local function Unfocus(inst)
	Sleep(3)
	local focus_tuning = deepcopyskipmeta(FocusPreset.BOSS)
	local imax = math.ceil(2 * SECONDS)
	for i = imax - 1, 1, -1 do
		focus_tuning.weight = easing.inOutQuad(i, 0, FocusPreset.BOSS.weight, imax)
		TheFocalPoint.components.focalpoint:StartFocusSource(inst, focus_tuning)
		Yield()
	end
	TheFocalPoint.components.focalpoint:StopFocusSource(inst)
end

local function ShowSpawnAnim(inst)
	TheFocalPoint.components.focalpoint:StartFocusSource(inst, FocusPreset.BOSS)
	inst.AnimState:PlayAnimation("popup")
	inst.AnimState:PushAnimation("idle", true)
	inst:StartThread(Unfocus)
end

local function OnSave(inst, data)
	data.creature = inst.creature
end

local function OnLoad(inst, data)
	if data.creature ~= nil then
		SetCreature(inst, data.creature)
	end
end

local function fn(prefabname)
	local inst = CreateEntity()
	inst:SetPrefabName(prefabname)

	inst.entity:AddTransform()
	inst.entity:AddAnimState()

	MakeObstaclePhysics(inst, 1)

	inst.AnimState:SetBank("tombstone")
	inst.AnimState:SetBuild("tombstone")
	inst.AnimState:PlayAnimation("idle", true)
	inst.AnimState:SetShadowEnabled(true)
	inst.AnimState:SetRimEnabled(true)
	inst.AnimState:SetRimSize(3)
	inst.AnimState:SetRimSteps(3)

	inst.SetCreature = SetCreature
	inst.ShowSpawnAnim = ShowSpawnAnim
	inst.OnSave = OnSave
	inst.OnLoad = OnLoad

	return inst
end

return Prefab("tombstone", fn, assets)
