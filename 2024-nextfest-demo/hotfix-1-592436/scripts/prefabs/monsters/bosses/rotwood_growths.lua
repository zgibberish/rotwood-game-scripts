local assets =
{
	Asset("ANIM", "anim/rotwood_growth.zip"),
}

local GROWTHS =
{
	["rotwood_growth_punch"] =
	{
		linked = true,
		prefabs = { "fx_rotwood_debris_punch" },
	},

	["rotwood_growth_root"] =
	{
		linked = true,
		small = true,
		prefabs = { "fx_rotwood_debris_wave" },
	},

	["rotwood_growth_sapling"] =
	{
		canownerhit = true,
		small = true,
		prefabs = { "fx_rotwood_debris_pullout" },
	},
}

local function SetupBasic(inst, owner, targets)
	inst.owner = owner

	--optional for target tracking across multiple spawns
	inst.targets = targets
end

local function SetupLinked(inst, owner, targets)
	SetupBasic(inst, owner, targets)

	owner.components.bloomer:AttachChild(inst)
	owner.components.colormultiplier:AttachChild(inst)
	owner.components.coloradder:AttachChild(inst)
	owner.components.hitstopper:AttachChild(inst)

	local function oninterrupted()
		inst.sg:PushEvent("interrupted")
	end
	inst:ListenForEvent("rotwood_growth_interrupted", oninterrupted, owner)
	inst:ListenForEvent("onremove", oninterrupted, owner)
end

local function MakeGrowth(name, params)
	local function fn(prefabname)
		local inst = CreateEntity()
		inst:SetPrefabName(prefabname)

		inst.entity:AddTransform()
		inst.entity:AddAnimState()
		inst.entity:AddHitBox()

		if params.small then
			MakeDynamicSmallObstaclePhysics(inst)
		else
			MakeDynamicObstaclePhysics(inst)
		end

		inst.HitBox:SetEnabled(false)

		inst.Transform:SetTwoFaced()

		inst.AnimState:SetBank("rotwood_growth")
		inst.AnimState:SetBuild("rotwood_growth")
		inst.AnimState:SetShadowEnabled(true)
		inst.AnimState:SetRimEnabled(true)
		inst.AnimState:SetRimSize(3)
		inst.AnimState:SetRimSteps(3)

		inst:AddComponent("bloomer")
		inst:AddComponent("colormultiplier")
		inst:AddComponent("coloradder")
		inst:AddComponent("hitstopper")

		inst:AddComponent("hitbox")
		inst.components.hitbox:SetHitGroup(HitGroup.BOSS)
		inst.components.hitbox:SetHitFlags(HitGroup.CHARACTERS)

		inst:AddComponent("combat")

		inst:SetStateGraph("sg_"..name)

		inst.persists = false

		inst.Setup = params.linked and SetupLinked or SetupBasic
		inst.canownerhit = params.canownerhit

		return inst
	end

	return Prefab(name, fn, assets, params.prefabs, nil, NetworkType_HostAuth)
end

local ret = {}
for name, params in pairs(GROWTHS) do
	ret[#ret + 1] = MakeGrowth(name, params)
end
return table.unpack(ret)
