local powerutil = require "util.powerutil"

local assets =
{
	-- Asset("ANIM", "anim/blarmadillo.zip"),
	-- Asset("ANIM", "anim/blarmadillo_dirt.zip"),
}

local prefabs =
{
	--jambell entity sizes
	"hits_electric_med",
	"hits_electric_ground",
	"electric_orb_pre",
	"electric_orb_idle",
	"electric_orb_pst",
}

local function fn(prefabname)
	local inst = CreateEntity()
	inst:SetPrefabName(prefabname)

	inst.OnSetSpawnInstigator = function(inst_orb, instigator)
		if (instigator) then
			local pow = instigator.components.powermanager:GetPowerByName("charge_orb_on_dodge")
			inst_orb.chargepulses = pow.persistdata:GetVar("pulses")
			inst_orb.chargestacks = pow.persistdata:GetVar("stacks")
			inst_orb.spawn_charge_applied_fx = function(inst_target)
				local suffix = GetEntitySizeSuffix(inst_target)
				powerutil.SpawnFxOnEntity("hits_electric"..suffix, inst_target, { ischild = true} )
			end
		end
	end

	inst.entity:AddTransform()
	inst.entity:AddAnimState()
	inst.entity:AddSoundEmitter()
	inst.entity:AddHitBox()


	inst.AnimState:SetBank("fx_hit_electric")
	inst.AnimState:SetBuild("fx_hit_electric")
	inst.AnimState:SetBloom(0.5)

	MakeItemDropPhysics(inst, 1)

	inst:AddComponent("hitstopper")

	inst:AddComponent("hitbox")
	inst.components.hitbox:SetHitGroup(HitGroup.NONE)
	inst.components.hitbox:SetHitFlags(HitGroup.CREATURES)

	inst:AddComponent("combat")
	inst.components.combat:AddTargetTags(TargetTagGroups.Enemies)

	inst:SetStateGraph("sg_orb_charge")

	return inst
end

return Prefab("orb_charge", fn, assets, prefabs, nil, NetworkType_None)
