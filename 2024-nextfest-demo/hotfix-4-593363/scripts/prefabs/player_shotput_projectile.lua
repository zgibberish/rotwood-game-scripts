local spawnutil = require "util.spawnutil"

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

local function OnRemoveEntity(inst)
	if inst._onentityspawned then
		TheLog.ch.Shotput:printf("%s never resolved owner EntityID")
		inst:RemoveEventCallback("entity_spawned", inst._onentityspawned, TheGlobalInstance)
		inst._onentityspawned = nil
	end
end

local function SetOwner(inst, owner)
	inst.owner = owner
	inst.source = owner

	local weapon_def = owner.components.inventory:GetEquippedWeaponDef()
	inst.build = weapon_def.build

	inst.components.playerhighlight:SetPlayer(inst.owner, true) -- start hidden

	inst.AnimState:SetBuild(inst.build)
end

local TESTMODE = false
local TESTMODE_DELAY = 5

-- owner may no longer exist, or not be instantiated yet in some cases (i.e. join-in-progress)
-- params is normally empty but if the owner is nil, it is an unresolved GUID that is a pending spawn
-- in that case, params.ownerEntityID will be present
local function HandleSetup(inst, owner, params)
	inst.attacktype = "heavy_attack" -- always starts this way
	inst.sg:GoToState("thrown")

	if TESTMODE and owner and not owner:IsLocal() then
		TheLog.ch.Shotput:printf("Test: Delayed setup of owner %s by %d frames...", owner, TESTMODE_DELAY)
		local xowner = owner
		TheGlobalInstance:DoTaskInTicks(TESTMODE_DELAY, function(_inst)
			TheLog.ch.Shotput:printf("Test: owner = %s", xowner)
			TheGlobalInstance:PushEvent("entity_spawned", xowner)
		end)
		params = { ownerEntityID = owner.Network:GetEntityID() }
		owner = nil
	end

	if not owner then
		-- register this entity to listen for owner spawn, then unregister afterwards
		assert(params and params.ownerEntityID and not inst._onentityspawned)
		TheLog.ch.Shotput:printf("%s needs to resolve owner EntityID %d", inst, params.ownerEntityID)
		inst._onentityspawned = function(_inst, xowner)
			if xowner:IsNetworked() and xowner.Network:GetEntityID() == params.ownerEntityID then
				TheLog.ch.Shotput:printf("%s resolving owner %s EntityID %d", inst, xowner, params.ownerEntityID)
				SetOwner(inst, xowner)
				inst:RemoveEventCallback("entity_spawned", inst._onentityspawned, TheGlobalInstance)
				inst._onentityspawned = nil
			end
		end
		inst:ListenForEvent("entity_spawned", inst._onentityspawned, TheGlobalInstance)
		return
	end

	SetOwner(inst, owner)
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
	inst:AddComponent("playerhighlight")

	inst.serializeHistory = true	-- Tell it to precisely sync animations

	-- Entity lifetime function configuration
	inst.Setup = Setup
	inst.HandleSetup = HandleSetup
	inst.OnRemoveEntity = OnRemoveEntity

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
