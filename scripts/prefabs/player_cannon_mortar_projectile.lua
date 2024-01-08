local combatutil = require "util.combatutil"
local spawnutil = require "util.spawnutil"
local monsterutil = require "util.monsterutil"
local SGPlayerCommon = require "stategraphs.sg_player_common"

local mortar_prefabs =
{
	"projectile_cannon_mortar",
	-- GroupPrefab("bombs_traps"),
}

local function Setup(inst, owner, damage_mod, hitstun_animframes, hitboxradius, pushback, focus, attacktype, numberinbatch, maxinbatch)
	inst.owner = owner
	inst.damage_mod = damage_mod or 1
	inst.hitstun_animframes = hitstun_animframes or 1
	inst.hitboxradius = hitboxradius
	inst.pushback = pushback or 1
	inst.focus = focus
	inst.source = owner
	inst.birthplace = inst:GetPosition()
	inst.attacktype = attacktype
	inst.numberinbatch = numberinbatch
	inst.maxinbatch = maxinbatch

	local _on_heavy_attack = function(source, data)
		owner:PushEvent("heavy_attack", data)
	end

	local _on_light_attack = function(source, data)
		owner:PushEvent("light_attack", data)
	end

	local _on_remove = function(source)
		if inst.numberinbatch == inst.maxinbatch then
			combatutil.EndProjectileAttack(inst)
		end
		owner:RemoveEventCallback("heavy_attack", _on_heavy_attack, inst)
		owner:RemoveEventCallback("light_attack", _on_heavy_attack, inst)
		owner:RemoveEventCallback("onremove", _on_heavy_attack, inst)
	end

	owner:ListenForEvent("heavy_attack", _on_heavy_attack, inst)
	owner:ListenForEvent("light_attack", _on_light_attack, inst)
	owner:ListenForEvent("onremove", _on_remove, inst)

	SGPlayerCommon.Fns.AttachPowerFxToProjectile(inst, "projectile_cannon_mortar", inst.owner, inst.attacktype)

	combatutil.StartProjectileAttack(inst)
end

local function mortar_fn(prefabname)
	local inst = spawnutil.CreateComplexProjectile(
	{
		name = prefabname,
		start_anim = "idle_cone",
		build = "fx_player_projectile_cannon",
		bank = "fx_player_projectile_cannon",
		stategraph = "sg_player_cannon_mortar_projectile",
	})

	inst.components.complexprojectile:SetHorizontalSpeed(30)
	inst.components.complexprojectile:SetGravity(-1)

	inst.entity:AddHitBox()
	inst:AddComponent("hitbox")
	inst.components.hitbox:SetHitGroup(HitGroup.NEUTRAL)
	inst.components.hitbox:SetHitFlags(HitGroup.CHARACTERS | HitGroup.CREATURES)

	inst:AddComponent("hittracker")
	inst:AddComponent("combat")

	inst.Setup = Setup

	return inst
end

return Prefab("player_cannon_mortar_projectile", mortar_fn, nil, mortar_prefabs, nil, NetworkType_SharedAnySpawn)
