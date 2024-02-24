local EffectEvents = require "effectevents"
local prop_destructible = require "prefabs.customscript.prop_destructible"

local assets =
{
    Asset("ANIM", "anim/destructible_bandiforest_ceiling.zip"),
}

local prefabs =
{
	"fx_bandicoot_groundring_solid",
	"fx_ground_target_red",
	"mothball",
}

local function fn(prefabname, tuning)
	local inst = CreateEntity()
	inst:SetPrefabName(prefabname)

    inst.entity:AddTransform()
	inst.entity:AddAnimState()
	inst.entity:AddSoundEmitter()

	local r, g, b = HexToRGBFloats(StrToHex("EA914DFF"))
	local intensity = 0.2
	inst.AnimState:SetLayerBloom("bloom_untex", r, g, b, intensity)
	inst.AnimState:SetLayerBloom("bloom_scatter", r, g, b, intensity)

	inst.AnimState:SetShadowEnabled(false)
	inst.AnimState:SetRimEnabled(true)
	inst.AnimState:SetRimSize(3)
	inst.AnimState:SetRimSteps(3)

	-- Randomly flip the anim to make the stalactites on the ground look more varied.
	--[[if math.random() < 0.5 then
		inst.AnimState:SetScale(-1, 1)
	end]]

	inst.Transform:SetTwoFaced()

	inst.AnimState:SetBank("destructible_bandiforest_ceiling")
	inst.AnimState:SetBuild("destructible_bandiforest_ceiling")

	inst.entity:AddHitBox()

	inst:AddComponent("hitbox")
	inst.components.hitbox:SetHitGroup(HitGroup.NEUTRAL)
	inst.components.hitbox:SetHitFlags(HitGroup.CHARACTERS | HitGroup.CREATURES)

	inst.HitBox:SetNonPhysicsRect(1.4)
	inst.HitBox:SetHitGroup(HitGroup.NEUTRAL)

	inst:AddComponent("hitstopper")

	inst:AddComponent("combat")
	inst.components.combat:SetBaseDamage(inst, tuning.BASE_DAMAGE)
	inst.components.combat:SetHasKnockback(false)
	inst.components.combat:SetHasKnockdown(false)

	inst:AddComponent("fallingobject")

	inst:AddComponent("health")
	inst.components.health:SetMax(tuning.HEALTH, true)
	inst.components.health:SetHealable(false)

	MakeObstaclePhysics(inst, 1.5)

	inst:SetStateGraph("levelprops/sg_swamp_stalactite")

	-- Set up hit FX
	inst.SpawnHitRubble = prop_destructible.default.SpawnHitRubble
	inst.fx_types = tuning.fx

	inst:AddTag("prop") -- Classify this as a prop for prop-related interactions.

	return inst
end

local function stalactite_fn(prefabname)
	local tuning = TUNING.TRAPS["swamp_stalactite"]
	local inst = fn(prefabname, tuning)
	inst.HitBox:SetEnabled(false)

	inst.Physics:SetSnapToGround(false)

	inst.OnSetSpawnInstigator = function(inst, instigator)
		inst.owner = instigator and instigator.owner or nil
	end

	inst:AddTag("hidingspot")
	inst.sg:GoToState("fall_pre")

	return inst
end

local function stalactite_network_fn()
	-- For networking, spawn local versions of this on each networked machine.
	local tuning = TUNING.TRAPS["swamp_stalactite"]
	local inst = fn("swamp_stalactite", tuning)
	inst.HitBox:SetEnabled(false)

	inst.OnSetSpawnInstigator = function(_inst, instigator)
		inst.owner = instigator ~= nil and instigator.components.combat and instigator or nil
	end

	-- Delay until the next update so that everything is initialized.
	inst:DoTaskInTime(0, function()
		inst.sg:GoToState("local_init", "swamp_stalactite")
	end)

	return inst
end

local function stalagmite_fn(prefabname)
	local tuning = TUNING.TRAPS["swamp_stalagmite"]
	local inst = fn(prefabname, tuning)

	inst:AddTag("hidingspot")

	return inst
end

local function peekaboom_fn(prefabname)
	local tuning = TUNING.TRAPS["swamp_stalactite"]
	local inst = fn(prefabname, tuning)
	inst.HitBox:SetEnabled(false)

	inst.components.hitbox:SetHitFlags(HitGroup.MOB | HitGroup.CHARACTERS)
	inst.sg:GoToState("peekaboom_impact")

	return inst
end

local function peekaboom_network_fn()
	-- For networking, spawn local versions of this on each networked machine.
	local tuning = TUNING.TRAPS["swamp_stalactite"]
	local inst = fn("swamp_stalactite", tuning)
	inst.HitBox:SetEnabled(false)

	-- Delay until the next update so that everything is initialized.
	inst:DoTaskInTime(0, function()
		inst.sg:GoToState("local_init", "swamp_stalactite_peekaboom")
	end)

	return inst
end

return Prefab("swamp_stalactite", stalactite_fn, assets, prefabs, nil, NetworkType_Minimal), -- stalactites come from the ceiling
	Prefab("swamp_stalactite_network", stalactite_network_fn, assets, prefabs, nil, NetworkType_SharedHostSpawn),
	Prefab("swamp_stalagmite", stalagmite_fn, assets, prefabs, nil, NetworkType_HostAuth), -- stalagmites are on the ground
	Prefab("swamp_stalactite_peekaboom", peekaboom_fn, assets, prefabs, nil, NetworkType_HostAuth),
	Prefab("swamp_stalactite_peekaboom_network", peekaboom_network_fn, assets, prefabs, nil, NetworkType_SharedHostSpawn)
