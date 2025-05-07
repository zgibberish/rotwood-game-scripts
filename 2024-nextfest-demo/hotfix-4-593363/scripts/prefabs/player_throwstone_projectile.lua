-- local SGCommon = require "stategraphs.sg_common"
local spawnutil = require "util.spawnutil"
local fmodtable = require "defs.sound.fmodtable"
local soundutil = require "util.soundutil"

local bullet_prefabs =
{
    "projectile_stone",
    "hits_projectile_stone",
}

local function _cancel_update_task(inst)
	if inst.updateprojectiletask then
		inst.updateprojectiletask:Cancel()
		inst.updateprojectiletask = nil
	end
end

local function OnHitBoxTriggered(inst, data)
	-- Roll crit chance manually, so we can know before applying damage whether or not it's going to be a crit.
	-- If we rolled a crit, then adjust the parameters of the attack to make it juicier.
	local crit_chance_bonus = 0.25
	local total_crit_chance = inst.owner and inst.owner.components.combat.critchance:Get() + crit_chance_bonus or crit_chance_bonus -- baseline crit chance for this attack is quite high
	local crit = math.random() < total_crit_chance -- recreating the roll from Combat:RollCritChance()

	local hitstun_anim_frames
	local pushback
	local hitstop

	if crit then
		hitstun_anim_frames = 10
		pushback = 6
		hitstop = HitStopLevel.HEAVY
	else
		hitstun_anim_frames = 3
		pushback = 1
		hitstop = HitStopLevel.MINOR
	end

	-- TODO: networking2022, review player projectiles like this and cannon
	-- and reconcile with OnProjectileHitboxTriggered.  These custom hitbox
	-- methods work better for player projectiles but are harder to maintain
	local hit = false
	local dir = inst.Transform:GetFacingRotation()
	for i = 1, #data.targets do
		local v = data.targets[i]
		if (v.owner or v) ~= inst.owner then
			assert(inst.owner)
			local attack = Attack(inst.owner, v)

			attack:SetDamageMod(inst.damage_mod)
			attack:SetOverrideDamage(9)
			attack:DeltaBonusCritDamageMult(9)
			attack:SetDir(dir)
			attack:SetFocus(inst.focus)
			attack:SetForceCriticalHit(crit)
			attack:SetHitstunAnimFrames(hitstun_anim_frames)
			attack:SetPushback(pushback)
			attack:SetHitFlags(Attack.HitFlags.PROJECTILE)
			attack:SetProjectile(inst)
			attack:SetID("throwstone")
			local multiple_hitstop <const> = false
			local disable_enemy_on_enemy_hitstop <const> = false
			local disable_self_hitstop <const> = true
			attack:SetHitStopData(hitstop, multiple_hitstop, disable_enemy_on_enemy_hitstop, disable_self_hitstop)

			if inst.source then
				attack:SetSource("throwstone")
			end

			local connected = inst.owner.components.combat:DoBasicAttack(attack)

			if connected then
				if v.components.hitstopper ~= nil then
					v.components.hitstopper:PushHitStop(hitstop)
				end

				local x_offset = 1
				local y_offset = 1.5

				inst.components.combat:SpawnHitFxForPlayerAttack(attack, "hits_projectile_stone", v, inst, x_offset, y_offset, attack:GetDir(), hitstop)
				SpawnHurtFx(inst, v, 0, dir, hitstop)
				hit = true
			end
		end
	end

	-- local hit = SGCommon.Events.OnProjectileHitboxTriggered(inst, data, {
	-- 	damage_mod = 1,
	-- 	hitstoplevel = hitstop,
	-- 	disable_self_hitstop = true,
	-- 	pushback = pushback,
	-- 	hitstun_anim_frames = hitstun_anim_frames,
	-- 	damage_override = 9,
	-- 	force_crit = crit,
	-- 	critdamage_mult = 9, -- multiplier to crit damage (default is damage_override*2)
	-- 	hitflags = Attack.HitFlags.PROJECTILE,
	-- 	source = "throwstone",
	-- 	combat_attack_fn = "DoBasicAttack",
	-- 	hit_fx = "hits_projectile_stone",
	-- 	hit_fx_offset_x = 1,
	-- 	hit_fx_offset_y = 1.5,
	-- })

	if hit then
		if crit then
			--[[ This doesnt play the sound every time, using sound emitter until we can determine why
			local params = {}
			params.fmodevent = fmodtable.Event.Crit_throwstone
			params.sound_max_count = 1
			soundutil.PlaySoundData(inst, params)--]]
			inst.SoundEmitter:PlaySound(fmodtable.Event.Crit_throwstone)
		end

		--kill travel sound
		if inst.sg.statemem.travel_sound_handle then
			soundutil.KillSound(inst, inst.sg.statemem.travel_sound_handle)
		end
		--kill throw sound
		if inst.owner and inst.owner.sg.statemem.throw_sound_handle then
			soundutil.KillSound(inst.owner, inst.owner.sg.statemem.throw_sound_handle)
		end

		-- Stop the ball and keep it planted for a moment so our eye gets a chance to process the connection
		_cancel_update_task(inst)
		inst.Physics:Stop()
		inst.AnimState:Pause()
		inst:DoTaskInAnimFrames(hitstop * 2, function()
			if inst ~= nil and inst:IsValid() then
				inst:Hide()
				if inst:IsLocal() then
					inst:Remove()
				end
			end
		end)
	end
end

local function UpdateProjectile(inst, is_first_frame)
	if is_first_frame then
		inst.components.hitbox:PushBeam(-2.5, 0, 1.75, HitPriority.PLAYER_PROJECTILE)
	else
		inst.components.hitbox:PushBeam(-0.5, -0.25, 1.5, HitPriority.PLAYER_PROJECTILE)

		if inst:GetDistanceSqToXZ(inst.birthplace.x, inst.birthplace.z) > inst.range * inst.range then
			inst:Hide()
			_cancel_update_task(inst)
			inst:Remove()
		end
	end
end

local function Setup(inst, owner)
	inst.owner = owner
	inst.Physics:StartPassingThroughObjects()
	local pos = inst:GetPosition()
	inst.Transform:SetPosition(pos.x, pos.y + 1.5, pos.z)
	inst.birthplace = inst:GetPosition()
	inst.range = 30
	inst.faction_hunter_id = inst.owner:GetHunterId()

	inst.updateprojectiletask = inst:DoPeriodicTicksTask(0, UpdateProjectile)
	inst:ListenForEvent("hitboxtriggered", OnHitBoxTriggered)
	UpdateProjectile(inst, true)
end

local function stone_fn(prefabname)
	local inst = spawnutil.CreateProjectile(
	{
		name = prefabname,
		physics_size = 0.5,
		hits_targets = true,
		hit_group = HitGroup.NONE,
		hit_flags = HitGroup.CREATURES,
		does_hitstop = true,
		twofaced = true,
		stategraph = "sg_player_throwstone_projectile",
		fx_prefab = "projectile_stone",
		motor_vel = 28,
	})

	inst.Setup = Setup --monsterutil.BasicProjectileSetup
	inst.Physics:SetSnapToGround(false)

	-- inst.components.projectilehitbox:PushBeam(-2.5, 0, 1.75, HitPriority.PLAYER_PROJECTILE, true)
	-- 								:PushBeam(-0.5, -0.25, 1.5, HitPriority.PLAYER_PROJECTILE)
	--								:SetTriggerFunction(OnHitBoxTriggered)

	return inst
end

return Prefab("player_throwstone_projectile", stone_fn, nil, bullet_prefabs, nil, NetworkType_ClientAuth)
