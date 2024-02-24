local combatutil = require "util.combatutil"
local spawnutil = require "util.spawnutil"
local SGPlayerCommon = require "stategraphs.sg_player_common"
local ParticleSystemHelper = require "util.particlesystemhelper"
local soundutil = require "util.soundutil"
local fmodtable = require "defs.sound.fmodtable"

local bullet_prefabs =
{
}

local function UpdateCheckAlive(inst)
	if TheWorld.Map:IsGroundAtXZ(inst.Transform:GetWorldXZ()) then
		inst.removecounter = 0
	elseif inst.removecounter < 1 then
		inst.removecounter = inst.removecounter + 1
	else
		inst:Hide()
		if inst:IsLocal() then
			inst:Remove()
		end
	end
end

local function SetYValue(inst)
	-- local pos = inst:GetPosition()
	-- inst.Transform:SetPosition(pos.x, pos.y + 1, pos.z)
end

local function UpdateProjectile(inst)
	if inst:GetDistanceSqToXZ(inst.birthplace.x, inst.birthplace.z) > inst.range * inst.range then
		local pfx_prefab = inst.focus and "cannon_shot_fizzle_out_focus" or "cannon_shot_fizzle_out"
		local pfx = ParticleSystemHelper.MakeOneShotAtPosition(inst:GetPosition(), pfx_prefab, 1, inst, { use_entity_facing = true, })
		local dir = inst.Transform:GetFacingRotation()
		if pfx ~= nil then
			pfx.Transform:SetRotation(dir)
		else
			dbassert(false, "player_cannon_projectile's pfx was nil for some reason! Did anything unusual just happen?")
		end

		--sound
		soundutil.PlayCodeSound(
			inst,
			fmodtable.Event.Cannon_shoot_projectile_travel_pop,
			{
				max_count = 1,
				fmodparams = {
					cannonShotType = inst.cannon_shot_type,
				},
			})
		inst:Hide()
		inst.updateprojectiletask:Cancel()
		inst.updateprojectiletask = nil
		inst:Remove()
	else
		inst.components.hitbox:PushBeam(-.1, .1, 1.75, HitPriority.PLAYER_PROJECTILE)
		if inst.meleehitboxticks > 0 then
			-- Push a bigger hitbox for the first few ticks so make point-black shooting more effective.
			inst.components.hitbox:PushBeam(-1.5, 1, .75, HitPriority.MOB_PROJECTILE)
			inst.components.hitbox:PushBeam(-2, -1.5, 1.25, HitPriority.MOB_PROJECTILE)

			inst.meleehitboxticks = inst.meleehitboxticks - 1
		end
	end
end

local function OnProjectileHitBoxTriggered(inst, data)
	local hitstoplevel = HitStopLevel.MINOR
	local hit = false

	local dir = inst.Transform:GetFacingRotation()
	for i = 1, #data.targets do
		local v = data.targets[i]
		if (v.owner or v) ~= inst.owner and not table.contains(inst.targetsattacked, v) then
			local attack = Attack(inst.owner, v)

			attack:SetDamageMod(inst.damage_mod)
			attack:SetDir(dir)
			attack:SetFocus(inst.focus)
			attack:SetHitstunAnimFrames(inst.hitstun_animframes)
			attack:SetPushback(inst.pushback)
			attack:SetHitFlags(Attack.HitFlags.PROJECTILE)
			attack:SetProjectile(inst)
			attack:SetID(inst.attacktype)
			attack:SetNameID(inst.attackID)

			if inst.source then
				attack:SetSource("projectile")
			end

			local connected = inst.owner.components.combat:DoBasicAttack(attack)

			if connected then
				if v.components.hitstopper ~= nil then
					v.components.hitstopper:PushHitStop(hitstoplevel)
				end

				local x_offset = 0
				local y_offset = 1

				inst.components.combat:SpawnHitFxForPlayerAttack(attack, inst.hitfx, v, inst, x_offset, y_offset, attack:GetDir(), hitstoplevel)
				SpawnHurtFx(inst, v, 0, dir, hitstoplevel)
				table.insert(inst.targetsattacked, v)
				hit = true
			end
		end
	end

	if hit and not inst:HasTag("pierce") then
		-- Stop the bullet and keep it planted for a moment so our eye gets a chance to process the connection
		if inst.sound_handle then
			soundutil.KillSound(inst, inst.sound_handle)
			inst.sound_handle = nil
		end
		inst.Physics:Stop()
		inst.AnimState:Pause()
		inst:DoTaskInAnimFrames(hitstoplevel * 2, function()
			if inst ~= nil and inst:IsValid() then
				inst:Hide()
				if inst:IsLocal() then
					inst:Remove()
				end
			end
		end)
	end
end

local function OnBulletCollided(inst, other)
	-- inst:Hide()
	-- inst:DoTaskInTicks(2, inst.Remove)
end

local function Setup(inst, owner, damage_mod, hitstun_animframes, pushback, speed, range, focus, attacktype, attackid, numberinbatch, maxinbatch)
	inst.owner = owner
	inst.damage_mod = damage_mod or 1
	inst.hitstun_animframes = hitstun_animframes or 1
	inst.pushback = pushback or 1
	inst.range = range
	inst.focus = focus
	inst.source = owner
	inst.birthplace = inst:GetPosition()
	inst.attacktype = attacktype
	inst.attackID = attackid
	inst.numberinbatch = numberinbatch
	inst.maxinbatch = maxinbatch
	inst.meleehitboxticks = 4

	if inst.attacktype == "light_attack" then
		inst.hitfx = "hits_player_cannon_shot"
	else
		inst.hitfx = "hits_player_cannon_shotgun"
	end

	inst.targetsattacked = {} -- a list of what enemies this projectile has already hit, in case of piercing bullets

	inst.Physics:SetMotorVel(speed or 20)
	inst.Physics:StartPassingThroughObjects()
	inst.updateprojectiletask = inst:DoPeriodicTicksTask(0, UpdateProjectile)
	inst:ListenForEvent("hitboxtriggered", OnProjectileHitBoxTriggered)
	-- inst.components.hitbox:PushBeam(-1.5, 0, 1, HitPriority.PLAYER_PROJECTILE)
	UpdateProjectile(inst)

	-- if focus then
	-- 	inst.AnimState:SetBloom( 0/255, 255/255, 255/255, 50/255)
	-- end

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

	SGPlayerCommon.Fns.AttachPowerFxToProjectile(inst, inst.power_fx_prefab, inst.owner, inst.attacktype)

	combatutil.StartProjectileAttack(inst)
end

local function bullet_fn()
	local inst = spawnutil.CreateProjectile(
	{
		physics_size = 0.5,
		hits_targets = true,
		hit_group = HitGroup.NONE,
		hit_flags = HitGroup.CREATURES,
		does_hitstop = true,
		twofaced = true,
		collision_callback = OnBulletCollided,
		fx_prefab = "projectile_cannon",
	})

	inst:AddComponent("hittracker")
	inst.removecounter = 0
	inst:DoPeriodicTask(1, UpdateCheckAlive)
	inst:DoPeriodicTicksTask(1, SetYValue)

	inst.power_fx_prefab = "projectile_cannon"

	inst.Setup = Setup
	inst.Physics:SetSnapToGround(false) -- So we can adjust the y value based on height when shot

	--sound
	local params = {}
	params.fmodevent = fmodtable.Event.Cannon_shoot_projectile_travel
	params.sound_max_count = 1
	inst.sound_handle = soundutil.PlaySoundData(inst, params)
	inst.cannon_shot_type = 0

	return inst
end

local function bullet_focus_fn()
	local inst = spawnutil.CreateProjectile(
	{
		physics_size = 0.5,
		hits_targets = true,
		hit_group = HitGroup.NONE,
		hit_flags = HitGroup.CREATURES,
		does_hitstop = true,
		twofaced = true,
		collision_callback = OnBulletCollided,
		fx_prefab = "projectile_cannon_focus",
	})

	inst:AddComponent("hittracker")
	inst.removecounter = 0
	inst:DoPeriodicTask(1, UpdateCheckAlive)
	inst:DoPeriodicTicksTask(1, SetYValue)

	inst.power_fx_prefab = "projectile_cannon"

	inst.Setup = Setup
	inst.Physics:SetSnapToGround(false) -- So we can adjust the y value based on height when shot

	--sound
	local params = {}
	params.fmodevent = fmodtable.Event.Cannon_shoot_projectile_travel
	params.sound_max_count = 1
	inst.sound_handle = soundutil.PlaySoundData(inst, params)
	if inst.sound_handle then
		soundutil.SetInstanceParameter(inst, inst.sound_handle, "isFocusAttack", 1)
	end
	inst.cannon_shot_type = 0

	return inst
end

local function shotgun_fn()
	local inst = spawnutil.CreateProjectile(
	{
		physics_size = 0.5,
		hits_targets = true,
		hit_group = HitGroup.NONE,
		hit_flags = HitGroup.CREATURES,
		does_hitstop = true,
		twofaced = true,
		collision_callback = OnBulletCollided,
		fx_prefab = "projectile_cannon_shotgun",
	})

	inst:AddComponent("hittracker")
	inst.removecounter = 0
	inst:DoPeriodicTask(1, UpdateCheckAlive)
	inst:DoPeriodicTicksTask(1, SetYValue)

	inst.power_fx_prefab = "projectile_cannon"

	inst.Setup = Setup
	inst.Physics:SetSnapToGround(false) -- So we can adjust the y value based on height when shot

	--sound
	local params = {}
	params.fmodevent = fmodtable.Event.Cannon_shoot_projectile_travel
	params.sound_max_count = 1
	inst.sound_handle = soundutil.PlaySoundData(inst, params)
	if inst.sound_handle then
		soundutil.SetInstanceParameter(inst, inst.sound_handle, "cannonShotType", 1)
	end
	inst.cannon_shot_type = 1

	return inst
end

local function shotgun_focus_fn()
	local inst = spawnutil.CreateProjectile(
	{
		physics_size = 0.5,
		hits_targets = true,
		hit_group = HitGroup.NONE,
		hit_flags = HitGroup.CREATURES,
		does_hitstop = true,
		twofaced = true,
		collision_callback = OnBulletCollided,
		fx_prefab = "projectile_cannon_shotgun_focus",
	})

	inst:AddComponent("hittracker")
	inst.removecounter = 0
	inst:DoPeriodicTask(1, UpdateCheckAlive)
	inst:DoPeriodicTicksTask(1, SetYValue)

	inst.power_fx_prefab = "projectile_cannon"

	inst.Setup = Setup
	inst.Physics:SetSnapToGround(false) -- So we can adjust the y value based on height when shot

	--sound
	local params = {}
	params.fmodevent = fmodtable.Event.Cannon_shoot_projectile_travel
	params.sound_max_count = 1
	inst.sound_handle = soundutil.PlaySoundData(inst, params)
	if inst.sound_handle then
		soundutil.SetInstanceParameter(inst, inst.sound_handle, "isFocusAttack", 1)
		soundutil.SetInstanceParameter(inst, inst.sound_handle, "cannonShotType", 1)
	end
	inst.cannon_shot_type = 1

	return inst
end

return 	Prefab("player_cannon_projectile", bullet_fn, nil, bullet_prefabs, nil, NetworkType_ClientAuth),
		Prefab("player_cannon_focus_projectile", bullet_focus_fn, nil, bullet_prefabs, nil, NetworkType_ClientAuth),
		Prefab("player_cannon_shotgun_projectile", shotgun_fn, nil, bullet_prefabs, nil, NetworkType_ClientAuth),
		Prefab("player_cannon_shotgun_focus_projectile", shotgun_focus_fn, nil, bullet_prefabs, nil, NetworkType_ClientAuth)
