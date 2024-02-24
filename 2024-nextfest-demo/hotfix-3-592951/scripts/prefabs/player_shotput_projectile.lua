local spawnutil = require "util.spawnutil"
local Equipment = require("defs.equipment")
require "hitstopmanager" -- for HitStopLevel, if only it didn't define globals!


local prefabs =
{
}
local assets =
{
	Asset("ANIM", "anim/fx_player_projectile_shotput.zip"),
}

local ATTACKS =
{
	THROW =
	{
		DMG_NORM = 1.33,
		DMG_FOCUS = 2,
		HITSTUN = 3,
		PB_NORM = 0,
		HS_NORM = HitStopLevel.MEDIUM,
	},
}

local function HandleSetup(inst, owner)
	inst.owner = owner
	inst.source = owner
	inst.attacktype = "heavy_attack" -- always starts this way

	inst.sg:GoToState("thrown")

	local weapon_def = owner.components.inventory:GetEquippedWeaponDef()
	inst.build = weapon_def.build

	inst.AnimState:SetBuild(inst.build)
end

local function Setup(inst, owner)
	if inst:ShouldSendNetEvents() then
		TheSim:HandleEntitySetup(inst.GUID, owner.GUID)
	else
		HandleSetup(inst, owner)
	end
end

local function fn(prefabname)
	local inst = spawnutil.CreateComplexProjectile(
	{
		name = prefabname,
		hits_targets = true,
		hit_group = HitGroup.NEUTRAL,
		hit_flags = HitGroup.ALL,
		bank = "fx_player_projectile_shotput",
		build = "fx_player_projectile_shotput",
		stategraph = "sg_player_shotput_projectile",
		no_healthcomponent = true,
	})

	-- The shotput object has physics when it's on the floor, so it needs physics.
	MakeProjectilePhysics(inst, 1)

	inst.AnimState:SetShadowEnabled(true)

	inst.AnimState:SetScale(1, 1)
	inst.AnimState:SetOrientation(ANIM_ORIENTATION.BillBoard)

	inst:AddComponent("hittracker")
	inst:AddComponent("hitstopper")
	inst:AddComponent("foleysounder")
	inst:AddComponent("ghosttrail")
	inst:AddComponent("shotputeffects")

	inst.serializeHistory = true	-- Tell it to precisely sync animations

	-- Entity lifetime function configuration
	inst.Setup = Setup
	inst.HandleSetup = HandleSetup

	inst.Physics:SetSnapToGround(false)

	inst:AddTag("shotput")
	inst:AddTag("nokill")


	local attack = ATTACKS.THROW
	inst.damage_mod = attack.DMG_NORM or 1
	inst.focus_damage_mod = attack.DMG_FOCUS or 2
	inst.hitstun_animframes = attack.HITSTUN or 1
	inst.hitstoplevel = attack.HS_NORM or HitStopLevel.MEDIUM
	inst.pushback = attack.PB_NORM or 1

	return inst
end

return Prefab("player_shotput_projectile", fn, assets, prefabs, nil, NetworkType_SharedAnySpawn)
