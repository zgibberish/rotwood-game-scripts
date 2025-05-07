--[[

easy todos:
- make spike state catchable

to try:
- [melee1, melee2, throw, melee3] NOT [melee1, melee2, throw, melee1]
	- track which melee we're in during a combo, and allow throws to break up the chain

- commonize states/eventhandlers as much as possible for this and _projectile

- make targetpos of rebound state dependent on y value of ball on hit
- complexprojectile makes ball go below 0, and then pops back up in "landing state"
- make start of spiked state be between ball + attacker
- bicycle kick adds to gravity so easier to hit things

]]

local SGCommon = require "stategraphs.sg_common"
local SGPlayerCommon = require "stategraphs.sg_player_common"
local fmodtable = require "defs.sound.fmodtable"
local soundutil = require "util.soundutil"
local combatutil = require "util.combatutil"
local Weight = require "components.weight"

-- jambell: a bit misleading PRESENTLY, these just determine combo states -- not initial presses. Fix to (probably) come.
local MELEE_BUTTON = "lightattack"
local THROW_BUTTON = "heavyattack"

local ATTACKS =
{
-- NW: Moved to player_shotput_projectile
--	THROW =
--	{
--		DMG_NORM = 1.33,
--		DMG_FOCUS = 2,
--		HITSTUN = 3,
--		PB_NORM = 0,
--		PB_FOCUS = 0,
--		HS_NORM = HitStopLevel.MEDIUM,
--		HS_FOCUS = HitStopLevel.HEAVY,
--	},
	PUNCH1 =
	{
		DMG_NORM = 0.53,
		HITSTUN = 10,
		PB_NORM = 1.5,
		HS_NORM = HitStopLevel.MEDIUM,
	},
	PUNCH2 =
	{
		DMG_NORM = 0.67,
		HITSTUN = 16,
		PB_NORM = 1.5,
		HS_NORM = HitStopLevel.HEAVY,
	},
	PUNCH3 =
	{
		DMG_NORM = 0.75,
		HITSTUN = 20,
		PB_NORM = 1,
		HS_NORM = HitStopLevel.HEAVY,
		KNOCKDOWN = true,
	},
	TACKLE =
	{
		DMG_NORM = 0.67,
		HITSTUN = 10,
		PB_NORM = 3.5,
		HS_NORM = HitStopLevel.HEAVY,
	},
	FADING_KICK =
	{
		DMG_NORM = 0.7,
		HITSTUN = 1,
		PB_NORM = 3,
		HS_NORM = HitStopLevel.HEAVY,
	},
}


local PRE_CATCH_FOCUS_BUFFER_ANIMFRAMES = 5  -- if we pressed the button slightly before catching, for how many frames beforehand should a focus be valid?
local POST_CATCH_FOCUS_BUFFER_ANIMFRAMES = 5 -- after catching, how many TICKS must we throw the ball to have that throw be a focus hit?

local TACKLE_HIT_THROW_CANCEL_DELAY = 4 	-- after hitting with a tackle, how many frames should we have to wait before a THROW-cancel is executed?
local TACKLE_HIT_DODGE_CANCEL_DELAY = 8 	-- after hitting with a tackle, how many frames should we have to wait before a DODGE-cancel is executed?

local FADING_KICK_HIT_THROW_CANCEL_DELAY = 14 	-- after hitting with a BICYCLE, how many frames should we have to wait before a THROW-cancel is executed?
local FADING_KICK_HIT_DODGE_CANCEL_DELAY = 15 	-- after hitting with a BICYCLE, how many frames should we have to wait before a DODGE-cancel is executed?

local PUNCH_HIT_THROW_CANCEL_DELAY = 0 	-- after hitting with a punch, how many frames should we have to wait before a THROW-cancel is executed?
local PUNCH_HIT_DODGE_CANCEL_DELAY = 4 	-- after hitting with a punch, how many frames should we have to wait before a DODGE-cancel is executed?
local PUNCH3_HIT_THROW_CANCEL_DELAY = 4 -- after hitting with a punch3, how many frames should we have to wait before a THROW-cancel is executed?

local NOAMMO_TO_THROW_WINDOW_ANIMFRAMES = 14 		-- if, during the 'noammo' state, we catch the ball. How many frames into noammo should we still allow a throw?

local TACKLE_HEIGHT_THRESHOLD = 1.5
local FADING_TACKLE_HEIGHT_THRESHOLD = 4
local PUNCH1_HEIGHT_THRESHOLD = 2
local PUNCH2_HEIGHT_THRESHOLD_LOW = 2.5
local PUNCH2_HEIGHT_THRESHOLD_HIGH = 3.5
local PUNCH3_HEIGHT_THRESHOLD = 2.5

local WEAPON_PREFIX = "shotput"

local EnableVerboseLogging = false

local function PrintActiveProjectiles(inst)
	if EnableVerboseLogging then
		print("inst:" .. inst.prefab)

		print("active_projectiles:")
		dumptable(inst.sg.mem.active_projectiles)

		print(debugstack())
	end
end

local function CreateProjectile(inst)
	local projectile = SpawnPrefab("player_shotput_projectile", inst)


	projectile.sg.mem.facing = inst.Transform:GetFacing()

	local pos = inst:GetPosition()
	if projectile.sg.mem.facing == FACING_RIGHT then
		projectile.Transform:SetPosition(pos.x + 2, pos.y, pos.z)
	else
		projectile.Transform:SetPosition(pos.x - 2, pos.y, pos.z)
	end
	projectile.focusthrow = inst.sg.statemem.focusthrow
	inst.sg.mem.attack_type = "heavy_attack" -- this matches hardcode in player_shotput_projectile Setup function

	projectile:Setup(inst)

	return projectile
end


-- Visual helper functions
local function UpdateAmmoSymbols(inst)
	-- Visualization of player's ammo on their character
	if inst.sg.mem.ammo == inst.sg.mem.ammo_max then
		inst.AnimState:ShowSymbol("feature01")
		inst.AnimState:ShowSymbol("shadow_untex")

		inst.AnimState:ShowSymbol("weapon_back01")
		inst.AnimState:ShowLayer("ARMED")
		inst.AnimState:HideLayer("UNARMED")
		inst.AnimState:ShowLayer("ATTACH")
	elseif inst.sg.mem.ammo > 0 then
		inst.AnimState:ShowSymbol("feature01")
		inst.AnimState:ShowSymbol("shadow_untex")
		
		inst.AnimState:ShowSymbol("weapon_back01")
		inst.AnimState:ShowLayer("ARMED")
		inst.AnimState:HideLayer("UNARMED")
		inst.AnimState:HideLayer("ATTACH")
	else
		inst.AnimState:HideSymbol("feature01")
		inst.AnimState:HideSymbol("shadow_untex")

		inst.AnimState:HideSymbol("weapon_back01")
		inst.AnimState:HideLayer("ARMED")
		inst.AnimState:ShowLayer("UNARMED")
		inst.AnimState:HideLayer("ATTACH")
	end
end

local function ResetAnimSymbols(inst)
	inst.AnimState:ShowSymbol("weapon_back01")
	-- not sure what else needs to be re-enabled
end

local function StartFocusParticles(inst)
	-- The ball itself has a particlesystem on it playing particles, but when it gets caught the ball gets put into limbo
	-- This attaches to the weapon in the player build for a few frames to smooth that transition.
	if inst.sg.mem.focustrail == nil then
		local pfx = SpawnPrefab("shotput_focus_trail", inst)
		pfx.entity:AddFollower()
		pfx.entity:SetParent(inst.entity)
		pfx.Follower:FollowSymbol(inst.GUID, "weapon_back01")
		inst.sg.mem.focustrail = pfx

		inst.sg.mem.focustrail:ListenForEvent("particles_stopcomplete", function()
			inst.sg.mem.focustrail:Remove()
			inst.sg.mem.focustrail = nil
		end)
	end
end

local function StopFocusParticles(inst)
	if inst.sg.mem.focustrail ~= nil then
		inst.sg.mem.focustrail.components.particlesystem:StopAndNotify()
	end
end

local function GetThrowAnim(inst)
	-- We have two normal throw anims and two focus throw anims
	-- Every time we throw, we should alternate between 1-2-1-2-1-2, regardless of whether it's focus or normal.
	-- This function gets the appropriate throw anim, # and focus/normal!
	local anim
	local idx = inst.sg.mem.throw_anim_idx
	if inst.sg.statemem.focusthrow then
		anim = inst.sg.mem.throw_focus_anims[idx]
	else
		anim = inst.sg.mem.throw_anims[idx]
	end

	inst.sg.mem.throw_anim_idx = inst.sg.mem.throw_anim_idx + 1
	if inst.sg.mem.throw_anim_idx > #inst.sg.mem.throw_anims then
		inst.sg.mem.throw_anim_idx = 1
	end

	return anim
end

local motorvel_to_xoffset =
{
	{ 0, 0 },
	{ 7.5, 1 },
	{ 12, 1.5 },
	{ 20, 2.5 },
}
local function PlayCatchFX(inst, ball)
	local pos = inst:GetPosition()

	-- TODO(jambell): this catch offset is messed up for catching ball while moving, because at the time this is evaluated, motorvel still thinks we're moving.
	--				  currently working on adding "can keep moving while catching", which will change this
	-- 			      works in other cases, going to check this in for now and revisit once we assess "can keep moving while catching"
	local x_offset = inst.Physics:GetMotorVel() > 0 and PiecewiseFn(inst.Physics:GetMotorVel(), motorvel_to_xoffset) or 0 -- if moving, offset it by 1 unit
	x_offset = x_offset * (inst.Transform:GetFacing() == FACING_LEFT and -1 or 1) -- if facing left, flip the offset
	local fx = SpawnPrefab("fx_pickup_center")
	fx.Transform:SetPosition(pos.x + x_offset, pos.y, pos.z)
end
-------------------------------------------------
-- Event Handlers

local function OnThrow(inst, projectile)
	if inst.sg.mem.ammo <= 0 then
		return
	end
	inst:PushEvent("projectile_launched", { projectile })
	inst.sg.mem.ammo = inst.sg.mem.ammo - 1
	UpdateAmmoSymbols(inst)
	StopFocusParticles(inst)

	inst.sg.mem.active_projectiles[projectile] = true

	PrintActiveProjectiles(inst)
end

local function OnCatch(inst, projectile)
	combatutil.EndProjectileAttack(projectile)

	projectile:SetPermanentFlags(PFLAG_JOURNALED_REMOVAL)
	projectile:Remove()

	inst.sg.mem.ammo = math.min(inst.sg.mem.ammo + 1, inst.sg.mem.ammo_max)
	UpdateAmmoSymbols(inst)
	PlayCatchFX(inst, projectile)

	inst.sg.mem.lastcatchtime = GetTick()

	inst.sg.mem.active_projectiles[projectile] = nil
	PrintActiveProjectiles(inst)

	if not inst.sg:HasStateTag("busy") then
		inst.sg:GoToState("catch")
	else
		--sound
		local params = {}
		params.fmodevent = fmodtable.Event.Shotput_roll_pickup
		local handle = soundutil.PlaySoundData(inst, params)
		soundutil.SetInstanceParameter(inst, handle, "shotputAmmo", inst.sg.mem.ammo)
	end
end

local function SwitchToFocusMidthrow(inst, projectile)
	-- Executed when we catch the ball in the middle of a throw. If we're early, within the first few frames, pop us into a focus throw instead.
	-- Gives player some leeway when throwing a ball, so if they press Throw a little early, there is a buffer to turn it into a focus.
	if inst.sg:GetAnimFramesInState() <= PRE_CATCH_FOCUS_BUFFER_ANIMFRAMES then
		inst.sg.statemem.focusthrow = true
		inst.sg.statemem.translating = true

		SGPlayerCommon.Fns.DetachSwipeFx(inst) -- In case we've already attached a swipe fx

		-- Get how many anim frames into the anim we are, and when we switch to the Focus anim, jump to that frame.
		local currentframe = inst.AnimState:GetCurrentAnimationFrame()
		local anim = GetThrowAnim(inst)
		inst.AnimState:PlayAnimation(anim)
		inst.AnimState:SetFrame(currentframe)

		StartFocusParticles(inst)
	end
end

local function OnPickup(inst, projectile)
	projectile:SetPermanentFlags(PFLAG_JOURNALED_REMOVAL)
	projectile:Remove()

	inst.sg.mem.ammo = math.min(inst.sg.mem.ammo + 1, inst.sg.mem.ammo_max)
	UpdateAmmoSymbols(inst)
	PlayCatchFX(inst, projectile)

	inst.sg.mem.active_projectiles[projectile] = nil
	PrintActiveProjectiles(inst)

	if not inst.sg:HasStateTag("busy") then
		local params = {}
		params.fmodevent = fmodtable.Event.Shotput_pickup
		params.sound_max_count = 1
		local handle = soundutil.PlaySoundData(inst, params)
		soundutil.SetInstanceParameter(inst, handle, "shotputAmmo", inst.sg.mem.ammo)
		inst.sg:GoToState("pickup_shotput")
	else
		local params = {}
		params.fmodevent = fmodtable.Event.Shotput_roll_pickup
		params.sound_max_count = 1
		local handle = soundutil.PlaySoundData(inst, params)
		soundutil.SetInstanceParameter(inst, handle, "shotputAmmo", inst.sg.mem.ammo)
	end
end

local function CheckForBallHit(inst, target, height_threshold)
	-- When melee attacking, this function checks to see whether or not the melee attack connected with a ball.
	-- Checks whether the ball is hittable or not, then checks to see if the y height of the ball is in a range that can be hit by that specific attack.
	if not target.sg:HasStateTag("hittable") then
		return
	end
	local ball_y = target:GetPosition().y
	local my_minx, my_miny, my_minz, my_maxx, my_maxy, my_maxz = inst.entity:GetWorldAABB()
	local threshold = my_maxy + height_threshold -- height_threshold above the player's highest point. height_threshold is set per attack.

	if not (ball_y <= threshold) then
		-- The ball is too high.
		return false
	else
		local params = {}
		params.fmodevent = fmodtable.Event.Hit_ball
		params.sound_max_count = 1
		soundutil.PlaySoundData(inst, params)

		target.sg:AddStateTag("tackled")
		return true
	end
end

local function TryPlayTackleSound(inst, victim)
	if not victim:HasTag("shotput") then
		local params = {}
		params.fmodevent = fmodtable.Event.Hit_tackle
		params.sound_max_count = 1
		soundutil.PlaySoundData(inst, params)
	end
end

local function OnTackleHitBoxTriggered(inst, data)
	local attackdata = ATTACKS[inst.sg.statemem.attackid]
	local hitstoplevel = attackdata.HS_NORM or HitStopLevel.HEAVY

	local hit = false

	local dir = inst.Transform:GetFacingRotation()
	for i = 1, #data.targets do
		local v = data.targets[i]
		local shouldhit = true
		if inst.sg.statemem.tackletargets[v] then
			-- We've already hit this target. RepeatTargetDelay isn't reliable in this case because we want to keep evaluating if we've hit a ball, but not re-hit an enemy if we've hit them
			shouldhit = false
		end

		local hitfx = "hits_player_unarmed"

		if v:HasTag("shotput") then
			if not inst.sg.statemem.hitball then -- If they haven't already hit a ball with this attack
				local ballhit = CheckForBallHit(inst, v, TACKLE_HEIGHT_THRESHOLD)
				if ballhit then
					hitstoplevel = 0
					inst.sg.statemem.hitball = true
					hitfx = "hits_player_unarmed_ball"

					-- The y-positions that the ball will be restrained to when it starts its 'spiked' trajectory
					inst.sg.statemem.minheight = 0.5
					inst.sg.statemem.maxheight = 1
				else
					shouldhit = false
				end
			else
				shouldhit = false
			end
		end

		if shouldhit then
			local focushit = inst.sg.statemem.focushit

			local attack = Attack(inst, v)
			attack:SetDamageMod(attackdata.DMG_NORM)
			attack:SetDir(dir)
			attack:SetHitstunAnimFrames(attackdata.HITSTUN)
			attack:SetPushback(attackdata.PB_NORM)
			attack:SetFocus(focushit)
			attack:SetID(inst.sg.mem.attack_type)

			inst.components.combat:DoBasicAttack(attack)

			hitstoplevel = SGCommon.Fns.ApplyHitstop(attack, hitstoplevel)

			local hitfx_x_offset = 2.75
			local hitfx_y_offset = 1.5

			inst.components.combat:SpawnHitFxForPlayerAttack(attack, hitfx, v, inst, hitfx_x_offset, hitfx_y_offset, dir, hitstoplevel)

			TryPlayTackleSound(inst, v)

			-- TODO(dbriscoe): Why do we only spawn if target didn't block? We unconditionally spawn in hammer. Maybe we should move this to SpawnHitFxForPlayerAttack
			if v.sg ~= nil and v.sg:HasStateTag("block") then
			else
				SpawnHurtFx(inst, v, hitfx_x_offset, dir, hitstoplevel)
			end

			inst.sg.statemem.tackletargets[v] = true
			hit = true
		end
	end

	if hit then
		inst.Physics:Stop()

		-- Activate immediate THROW cancel
		inst.components.playercontroller:OverrideControlQueueTicks(THROW_BUTTON, TACKLE_HIT_THROW_CANCEL_DELAY * ANIM_FRAMES)
		inst:DoTaskInAnimFrames(TACKLE_HIT_THROW_CANCEL_DELAY, function(inst)
			-- DESIGN: Allow throw-cancelling if we hit anything, but not immediately.
			if inst.sg:HasStateTag("busy") then -- In case we've gone into a different state
				inst.sg.statemem.heavycombostate = "default_heavy_attack"
				SGPlayerCommon.Fns.TryQueuedAction(inst, THROW_BUTTON)
			end
			inst.components.playercontroller:OverrideControlQueueTicks(THROW_BUTTON, nil)
		end)

		-- Activate immediate PUNCH cancel
		if inst.sg.statemem.lighthitcombostate then
			local delay = inst.sg.statemem.lighthitcombodelayframes

			inst.components.playercontroller:OverrideControlQueueTicks(MELEE_BUTTON, delay * ANIM_FRAMES)
			inst:DoTaskInAnimFrames(delay, function(inst)
				-- DESIGN: Allow throw-cancelling if we hit anything, but not immediately.
				if inst.sg:HasStateTag("busy") and inst.sg.statemem.lighthitcombostate then -- In case we've gone into a different state
					inst.sg.statemem.lightcombostate = inst.sg.statemem.lighthitcombostate
					SGPlayerCommon.Fns.TryQueuedAction(inst, MELEE_BUTTON)
				end
				inst.components.playercontroller:OverrideControlQueueTicks(MELEE_BUTTON, nil)
			end)
		end

		inst.sg.statemem.speedmult = 0.15 -- We've hit, so slow down the player's movement.
		inst.sg.statemem.hitting = false
	end
end

local function OnFadingTackleHitBoxTriggered(inst, data)
	--JAMBELL: lots of boilerplate here while prototyping, clean this up
	local attackdata = ATTACKS[inst.sg.statemem.attackid]
	local hitstoplevel = attackdata.HS_NORM or HitStopLevel.HEAVY

	local hit = false

	local dir = inst.Transform:GetFacingRotation()
	for i = 1, #data.targets do
		local v = data.targets[i]
		local shouldhit = true
		if inst.sg.statemem.tackletargets[v] then
			-- We've already hit this target. RepeatTargetDelay isn't reliable in this case because we want to keep evaluating if we've hit a ball, but not re-hit an enemy if we've hit them
			shouldhit = false
		end

		local hitfx = "hits_player_unarmed"

		if v:HasTag("shotput") then
			if not inst.sg.statemem.hitball then -- If they haven't already hit a ball with this attack
				local ballhit = CheckForBallHit(inst, v, FADING_TACKLE_HEIGHT_THRESHOLD)
				if ballhit then
					hitstoplevel = hitstoplevel * 0.25
					inst.sg.statemem.hitball = true
					hitfx = "hits_player_unarmed_ball"

					-- The y-positions that the ball will be restrained to when it starts its 'spiked' trajectory
					inst.sg.statemem.minheight = 0.5
					inst.sg.statemem.maxheight = FADING_TACKLE_HEIGHT_THRESHOLD
				else
					shouldhit = false
				end
			else
				shouldhit = false
			end
		end

		if shouldhit then
			local focushit = inst.sg.statemem.focushit

			local attack = Attack(inst, v)
			attack:SetDamageMod(attackdata.DMG_NORM)
			attack:SetDir(dir)
			attack:SetHitstunAnimFrames(attackdata.HITSTUN)
			attack:SetPushback(attackdata.PB_NORM)
			attack:SetFocus(focushit)
			attack:SetID(inst.sg.mem.attack_type)

			inst.components.combat:DoBasicAttack(attack)

			hitstoplevel = SGCommon.Fns.ApplyHitstop(attack, hitstoplevel)

			local hitfx_x_offset = 2.5

			local minheight = inst.sg.statemem.minheight or 1.5
			local maxheight = inst.sg.statemem.maxheight or 2

			local hitfx_y_offset = math.max(minheight, v:GetPosition().y)
			hitfx_y_offset = math.min(maxheight, hitfx_y_offset)

			inst.components.combat:SpawnHitFxForPlayerAttack(attack, hitfx, v, inst, hitfx_x_offset, hitfx_y_offset, dir, hitstoplevel)

			TryPlayTackleSound(inst, v)

			-- TODO(dbriscoe): Why do we only spawn if target didn't block? We unconditionally spawn in hammer. Maybe we should move this to SpawnHitFxForPlayerAttack
			if v.sg ~= nil and v.sg:HasStateTag("block") then
			else
				SpawnHurtFx(inst, v, hitfx_x_offset, dir, hitstoplevel)
			end

			inst.sg.statemem.tackletargets[v] = true
			hit = true
		end
	end

	if hit then
		inst.sg.statemem.hit = true
		inst.components.playercontroller:OverrideControlQueueTicks(THROW_BUTTON, FADING_KICK_HIT_THROW_CANCEL_DELAY * ANIM_FRAMES)
		inst:DoTaskInAnimFrames(FADING_KICK_HIT_THROW_CANCEL_DELAY, function(inst)
			-- -- DESIGN: Allow dodge-cancelling if we hit anything, but not immediately.
			-- if inst.sg:HasStateTag("busy") then -- In case we've gone into a different state
			-- 	inst.sg.statemem.heavycombostate = "default_heavy_attack"
			-- 	SGPlayerCommon.Fns.TryQueuedAction(inst, THROW_BUTTON)
			-- end
			inst.components.playercontroller:OverrideControlQueueTicks(THROW_BUTTON, nil)
		end)

		inst.components.playercontroller:OverrideControlQueueTicks("dodge", FADING_KICK_HIT_DODGE_CANCEL_DELAY * ANIM_FRAMES)
		inst:DoTaskInAnimFrames(FADING_KICK_HIT_DODGE_CANCEL_DELAY, function(inst)
			-- DESIGN: Allow dodge-cancelling if we hit anything, but not immediately.
			if inst.sg:HasStateTag("busy") then -- In case we've gone into a different state
				SGPlayerCommon.Fns.SetCanDodge(inst)
				SGPlayerCommon.Fns.TryQueuedAction(inst, "dodge")
			end
			inst.components.playercontroller:OverrideControlQueueTicks("dodge", nil)
		end)
		inst.sg.statemem.hitting = false
	end
end

local function OnPunchHitBoxTriggered(inst, data)
	local attackdata = ATTACKS[inst.sg.statemem.attackid]
	local hitstoplevel = attackdata.HS_NORM or HitStopLevel.HEAVY

	local hit = false

	local dir = inst.Transform:GetFacingRotation()
	for i = 1, #data.targets do
		local v = data.targets[i]
		local shouldhit = true
		if inst.sg.statemem.tackletargets[v] then
			-- We've already hit this target. RepeatTargetDelay isn't reliable in this case because we want to keep evaluating if we've hit a ball, but not re-hit an enemy if we've hit them
			shouldhit = false
			return
		end

		local hitfx = "hits_player_unarmed"

		if v:HasTag("shotput") then
			if not inst.sg.statemem.hitball then -- If they haven't already hit a ball with this attack
				local ballhit = CheckForBallHit(inst, v, inst.sg.statemem.ballhit_height_threshold)
				if ballhit then
					hitstoplevel = 0
					inst.sg.statemem.hitball = true
					hitfx = "hits_player_unarmed_ball"
				else
					shouldhit = false
				end
			else
				shouldhit = false
			end
		end

		if shouldhit then
			local focushit = inst.sg.statemem.focushit
			local pushback = attackdata.PB_NORM

			local attack = Attack(inst, v)
			attack:SetDamageMod(attackdata.DMG_NORM)
			attack:SetDir(dir)
			attack:SetHitstunAnimFrames(attackdata.HITSTUN)
			attack:SetPushback(attackdata.PB_NORM)
			attack:SetFocus(focushit)
			attack:SetID(inst.sg.mem.attack_type)

			if attackdata.KNOCKDOWN then
				inst.components.combat:DoKnockdownAttack(attack)
			elseif attackdata.KNOCKBACK then
				inst.components.combat:DoKnockbackAttack(attack)
			else
				inst.components.combat:DoBasicAttack(attack)
			end

			hitstoplevel = SGCommon.Fns.ApplyHitstop(attack, hitstoplevel)

			local hitfx_x_offset = 2
			local hitfx_y_offset = 1.5

			inst.components.combat:SpawnHitFxForPlayerAttack(attack, hitfx, v, inst, hitfx_x_offset, hitfx_y_offset, dir, hitstoplevel)

			if attackdata.KNOCKDOWN == true then
				local params = {}
				params.fmodevent = fmodtable.Event.Hit_headbutt
				params.sound_max_count = 1
				soundutil.PlaySoundData(inst, params)
			else TryPlayTackleSound(inst, v)
			end
		
			-- TODO(dbriscoe): Why do we only spawn if target didn't block? We unconditionally spawn in hammer. Maybe we should move this to SpawnHitFxForPlayerAttack
			if v.sg ~= nil and v.sg:HasStateTag("block") then
			else
				SpawnHurtFx(inst, v, hitfx_x_offset, dir, hitstoplevel)
			end

			inst.sg.statemem.tackletargets[v] = true
			hit = true
		end
	end

	if hit then
		-- Activate immediate DODGE cancel
		inst.components.playercontroller:OverrideControlQueueTicks("dodge", PUNCH_HIT_DODGE_CANCEL_DELAY * ANIM_FRAMES)
		inst:DoTaskInAnimFrames(PUNCH_HIT_DODGE_CANCEL_DELAY, function(inst)
			-- DESIGN: Allow dodge-cancelling if we hit anything, but not immediately.
			if inst.sg:HasStateTag("busy") then -- In case we've gone into a different state
				SGPlayerCommon.Fns.SetCanDodge(inst)
				SGPlayerCommon.Fns.TryQueuedAction(inst, "dodge")
			end
			inst.components.playercontroller:OverrideControlQueueTicks("dodge", nil)
		end)

		-- Activate immediate THROW cancel
		inst.components.playercontroller:OverrideControlQueueTicks(THROW_BUTTON, PUNCH3_HIT_THROW_CANCEL_DELAY * ANIM_FRAMES)
		inst:DoTaskInAnimFrames(PUNCH3_HIT_THROW_CANCEL_DELAY, function(inst)
			-- DESIGN: Allow throw-cancelling if we hit anything, but not immediately.
			if inst.sg:HasStateTag("busy") then -- In case we've gone into a different state
				inst.sg.statemem.heavycombostate = "default_heavy_attack"
				SGPlayerCommon.Fns.TryQueuedAction(inst, THROW_BUTTON)
			end
			inst.components.playercontroller:OverrideControlQueueTicks(THROW_BUTTON, nil)
		end)

		-- Activate immediate PUNCH cancel
		if inst.sg.statemem.lighthitcombostate then
			local delay = inst.sg.statemem.lighthitcombodelayframes

			inst.components.playercontroller:OverrideControlQueueTicks(MELEE_BUTTON, delay * ANIM_FRAMES)
			inst:DoTaskInAnimFrames(delay, function(inst)
				-- DESIGN: Allow throw-cancelling if we hit anything, but not immediately.
				if inst.sg:HasStateTag("busy") and inst.sg.statemem.lighthitcombostate then -- In case we've gone into a different state
					inst.sg.statemem.lightcombostate = inst.sg.statemem.lighthitcombostate
					SGPlayerCommon.Fns.TryQueuedAction(inst, MELEE_BUTTON)
				end
				inst.components.playercontroller:OverrideControlQueueTicks(MELEE_BUTTON, nil)
			end)
		end

		-- Activate immediate SKILL cancel
		inst.components.playercontroller:OverrideControlQueueTicks(THROW_BUTTON, PUNCH_HIT_THROW_CANCEL_DELAY * ANIM_FRAMES)
		inst:DoTaskInAnimFrames(PUNCH_HIT_THROW_CANCEL_DELAY, function(inst)
			-- DESIGN: Allow skill-cancelling if we hit anything, but not immediately.
			if inst.sg:HasStateTag("busy") then -- In case we've gone into a different state
				SGPlayerCommon.Fns.SetCanSkill(inst)
				SGPlayerCommon.Fns.TryQueuedAction(inst, "skill")
			end
			inst.components.playercontroller:OverrideControlQueueTicks(THROW_BUTTON, nil)
		end)
	end
end

-------------------------------------------------
-- Gameplay functions
local function IsFocusThrow(inst)
	if inst.sg.mem.lastcatchtime ~= nil then
		if GetTick() - inst.sg.mem.lastcatchtime <= (POST_CATCH_FOCUS_BUFFER_ANIMFRAMES * 2) then -- TUNING value is expressed in animframes, so convert to ticks to compare to GetTick()
			return true
		end
	end
	return false
end

local function MakeThrownProjectile(inst)
	OnThrow(inst, CreateProjectile(inst))
end

local function RemoveProjectiles(sg)
	if sg.mem.active_projectiles then
		for proj, _ in pairs(sg.mem.active_projectiles) do
			proj:TakeControl()
			proj:SetPermanentFlags(PFLAG_JOURNALED_REMOVAL)
			proj:Remove()
		end
		table.clear(sg.mem.active_projectiles)
	end
end

-------------------------------------------------

local events = {
	EventHandler("shotput_caught", OnCatch),
	EventHandler("shotput_pickuped", OnPickup),
}
SGPlayerCommon.Events.AddAllBasicEvents(events)

local roll_states =
{
	[Weight.Status.s.Light] = "roll_light",
	[Weight.Status.s.Normal] = "roll_pre",
	[Weight.Status.s.Heavy] = "roll_heavy",
}

local states =
{
	State({
		name = "init",
		onenter = function(inst)
			inst.sg.mem.ammo_max = TUNING.GEAR.WEAPONS.SHOTPUT.AMMO
			inst.sg.mem.ammo = TUNING.GEAR.WEAPONS.SHOTPUT.AMMO
			inst.sg.mem.throw_anims = { "shotput_atk1", "shotput_atk1_b" }
			inst.sg.mem.throw_focus_anims = { "shotput_focus_atk1", "shotput_focus_atk2" }
			assert(#inst.sg.mem.throw_anims == #inst.sg.mem.throw_focus_anims)
			inst.sg.mem.throw_anim_idx = 1

			inst.sg.mem.active_projectiles = {}
			PrintActiveProjectiles(inst)

			UpdateAmmoSymbols(inst)

			local _on_loadout_change_imminent = function()
				-- Immediately recall all active shotput objects:
				PrintActiveProjectiles(inst)

				RemoveProjectiles(inst.sg)

				-- Also reset the internal state of the shotput weapon:
				inst.sg.mem.ammo_max = TUNING.GEAR.WEAPONS.SHOTPUT.AMMO
				inst.sg.mem.ammo = TUNING.GEAR.WEAPONS.SHOTPUT.AMMO
				inst.sg.mem.throw_anims = { "shotput_atk1", "shotput_atk1_b" }
				inst.sg.mem.throw_focus_anims = { "shotput_focus_atk1", "shotput_focus_atk2" }
				assert(#inst.sg.mem.throw_anims == #inst.sg.mem.throw_focus_anims)
				inst.sg.mem.throw_anim_idx = 1

			end

			inst:ListenForEvent("loadout_change_imminent", _on_loadout_change_imminent)	-- This gets fired BEFORE the loadout actually changes (which resets inst.sg.mem), so that the inst.sg.mem.active_projectiles is still valid. 

			inst.sg:GoToState("idle")
		end,
	}),

	State({
		name = "default_light_attack",
		onenter = function(inst)
			inst.sg:GoToState("punch")
		end,
	}),

	State({
		name = "default_heavy_attack",
		onenter = function(inst)
			if inst.sg.mem.ammo > 0 then
				inst.sg:GoToState("throw")
			else
				inst.sg:GoToState("noammo", THROW_BUTTON)
			end
		end,
	}),

	State({
		name = "default_dodge",
		onenter = function(inst)
			local weight = inst.components.weight:GetStatus()
			inst.sg:GoToState(roll_states[weight])
		end,
	}),

	-- ATTACKS
	State({
		name = "throw",
		tags = { "attack", "busy", "heavy_attack" },

		onenter = function(inst, overridefocus)
			inst.Physics:Stop()
			if overridefocus ~= nil then
				inst.sg.statemem.focusthrow = overridefocus
			else
				inst.sg.statemem.focusthrow = IsFocusThrow(inst)
			end

			if inst.sg.statemem.focusthrow then
				StartFocusParticles(inst)
			end

			local anim = GetThrowAnim(inst)
			inst.AnimState:PlayAnimation(anim)

			inst:PushEvent("attack_state_start")
		end,

		timeline =
		{
			-- NORMAL THROW VERSION
			FrameEvent(6, function(inst)
				if not inst.sg.statemem.focusthrow then
					MakeThrownProjectile(inst)
					SGPlayerCommon.Fns.SetCanDodge(inst)
				end
			end),


			-- FOCUS THROW VERSION
			-- Specific movement unique to the focus throw state
			--PHYSICS
			-- Code Generated by PivotTrack.jsfl
			FrameEvent(6, function(inst) if inst.sg.statemem.focusthrow then inst.Physics:MoveRelFacing(58/150) end end),
			-- FrameEvent(8, function(inst) if inst.sg.statemem.focusthrow then inst.Physics:MoveRelFacing(29/150) end end), 
			-- FrameEvent(10, function(inst) if inst.sg.statemem.focusthrow then inst.Physics:MoveRelFacing(30/150) end end),
			-- End Generated Code

			-- Switching to physics movement mid-air
			FrameEvent(8, function(inst) if inst.sg.statemem.focusthrow then SGCommon.Fns.SetMotorVelScaled(inst, 1.5) end end),
			FrameEvent(14, function(inst) if inst.sg.statemem.focusthrow then inst.Physics:Stop() end end),

			FrameEvent(6, function(inst)
				if inst.sg.statemem.focusthrow then
					inst.sg:AddStateTag("airborne")
					MakeThrownProjectile(inst)
				end
			end),

			FrameEvent(14, function(inst)
				if inst.sg.statemem.focusthrow then
					inst.sg:RemoveStateTag("airborne")
					SGPlayerCommon.Fns.SetCanDodge(inst)
				end
			end),

			-- CANCELS
			FrameEvent(0, function(inst) inst.sg.statemem.lightcombostate = "default_light_attack" end),
			FrameEvent(5, function(inst) inst.sg.statemem.lightcombostate = nil end),

			-- SOUNDS
			FrameEvent(1, function(inst)
				local params = {}
				params.fmodevent = fmodtable.Event.Shotput_whoosh_light
				params.sound_max_count = 1
				local handle = soundutil.PlaySoundData(inst, params)
				soundutil.SetInstanceParameter(inst, handle, "isFocusAttack", inst.sg.statemem.focusthrow and 1 or 0)
				soundutil.SetInstanceParameter(inst, handle, "shotputAmmo", inst.sg.mem.ammo)
			end),
		},

		events =
		{
			EventHandler("animover", function(inst)
				inst.sg:GoToState("idle")
			end),

			EventHandler("shotput_caught", function(inst, projectile)
				OnCatch(inst, projectile)
				-- Catching the shotput while in startup frames, we pressed the button a little early -- provide a buffer
				SwitchToFocusMidthrow(inst, projectile)
			end),
		},
	}),

	State({
		name = "reverse_throw",
		tags = { "busy", "heavy_attack" },

		onenter = function(inst)
			inst:FlipFacingAndRotation()
			inst.sg:GoToState("default_heavy_attack")
		end,
	}),

	State({
		name = "reverse_throw_from_rolling_pst",
		tags = { "busy", "heavy_attack" },

		onenter = function(inst)
			if inst.sg.mem.ammo > 0 then
				inst:FlipFacingAndRotation()
				inst.sg:GoToState("throw_from_rolling_pst", true)
			else
				inst.sg:GoToState("roll_pst") -- TODO @jambell #weight figure out what to do with these
			end
		end,
	}),
	State({
		name = "throw_from_rolling_pst",
		tags = { "busy", "heavy_attack" },

		onenter = function(inst, flip)
			if inst.sg.mem.ammo > 0 then
				inst.sg.statemem.focusthrow = IsFocusThrow(inst)

				if inst.sg.statemem.focusthrow then
					StartFocusParticles(inst)
				end

				local anim = GetThrowAnim(inst)
				inst.AnimState:PlayAnimation(anim)

				local velocity = .3
				local runspeed = inst.components.locomotor:GetBaseRunSpeed()
				if flip then
					runspeed = runspeed * -1
					velocity = .2
				end
				SGCommon.Fns.SetMotorVelScaled(inst, velocity * runspeed)
			else
				inst.sg:GoToState("roll_pst") -- TODO @jambell #weight figure out what to do with these
			end
		end,

		timeline =
		{
			-- FOCUS THROW VERSION
			FrameEvent(5, function(inst)
				if inst.sg.statemem.focusthrow then
					inst.sg:AddStateTag("airborne")
				end
			end),
			FrameEvent(12, function(inst)
				if inst.sg.statemem.focusthrow then
					inst.sg:RemoveStateTag("airborne")
					inst.Physics:Stop()
				end
			end),

			-- NORMAL VERSION
			FrameEvent(6 , function(inst)
				if not inst.sg.statemem.focusthrow then
					inst.Physics:Stop()
				end
			end),

			FrameEvent(6, function(inst)
				MakeThrownProjectile(inst)
			end),

			FrameEvent(6 , SGPlayerCommon.Fns.SetCanDodge),

			FrameEvent(1, function(inst)
				local params = {}
				params.fmodevent = fmodtable.Event.Shotput_whoosh_light
				params.sound_max_count = 1
				local handle = soundutil.PlaySoundData(inst, params)
				soundutil.SetInstanceParameter(inst, handle, "isFocusAttack", inst.sg.statemem.focusthrow and 1 or 0)
				soundutil.SetInstanceParameter(inst, handle, "shotputAmmo", inst.sg.mem.ammo)
			end),
		},

		events =
		{
			EventHandler("animover", function(inst)
				inst.sg:GoToState("idle")
			end),

			EventHandler("shotput_caught", function(inst, projectile)
				OnCatch(inst, projectile)

				-- Catching the shotput while in startup frames, we pressed the button a little early -- provide a buffer
				SwitchToFocusMidthrow(inst, projectile)
			end),
		},
	}),


	State({
		name = "reverse_throw_from_rolling_loop",
		tags = { "busy", "heavy_attack" },

		onenter = function(inst)
			if inst.sg.mem.ammo > 0 then
				inst:FlipFacingAndRotation()
				inst.sg:GoToState("throw_from_rolling_loop", true)
			else
				inst.sg:GoToState("roll_pst") -- TODO @jambell #weight figure out what to do with these
			end
		end,
	}),
	State({
		name = "throw_from_rolling_loop",
		tags = { "busy", "heavy_attack" },

		onenter = function(inst, flip)
			if inst.sg.mem.ammo > 0 then
				inst.sg.statemem.focusthrow = IsFocusThrow(inst)
				inst.sg.statemem.flip = flip
				if inst.sg.statemem.focusthrow then
					StartFocusParticles(inst)
				end

				local anim = GetThrowAnim(inst)
				inst.AnimState:PlayAnimation(anim)

				local runspeed = inst.components.locomotor:GetBaseRunSpeed()
				local mult = 1
				local motorvel = inst.Physics:GetMotorVel()
				if flip then
					runspeed = runspeed * -1
					mult = .8 -- Move slightly less when turning backwards
				end
				SGCommon.Fns.SetMotorVelScaled(inst, mult * runspeed)
			else
				inst.sg:GoToState("roll_pst") -- TODO @jambell #weight figure out what to do with these
			end
		end,

		timeline =
		{
			-- FOCUS THROW VERSION
			FrameEvent(5, function(inst)
				if inst.sg.statemem.focusthrow then
					--SGCommon.Fns.SetMotorVelScaled(inst, 9 * inst.sg.statemem.locomotorspeedmult)
					inst.sg:AddStateTag("airborne")
				end
			end),
			FrameEvent(12, function(inst)
				if inst.sg.statemem.focusthrow then
					inst.sg:RemoveStateTag("airborne")
					inst.Physics:Stop()
				end
			end),

			-- NORMAL VERSION
			FrameEvent(6 , function(inst)
				if not inst.sg.statemem.focusthrow then
					inst.Physics:Stop()
				end
			end),

			FrameEvent(6, function(inst)
				MakeThrownProjectile(inst)
			end),

			FrameEvent(6 , SGPlayerCommon.Fns.SetCanDodge),

			FrameEvent(1, function(inst)
				local params = {}
				params.fmodevent = fmodtable.Event.Shotput_whoosh_light
				params.sound_max_count = 1
				local handle = soundutil.PlaySoundData(inst, params)
				soundutil.SetInstanceParameter(inst, handle, "isFocusAttack", inst.sg.statemem.focusthrow and 1 or 0)
				soundutil.SetInstanceParameter(inst, handle, "shotputAmmo", inst.sg.mem.ammo)
			end),
		},

		events =
		{
			EventHandler("animover", function(inst)
				inst.sg:GoToState("idle")
			end),

			EventHandler("shotput_caught", function(inst, projectile)
				OnCatch(inst, projectile)

				-- Catching the shotput while in startup frames, we pressed the button a little early -- provide a buffer
				SwitchToFocusMidthrow(inst, projectile)
			end),
		},
	}),

	State({
		name = "punch",
		tags = { "attack", "busy", "shotput_catch_forbidden", "light_attack" }, --shotput_catch_forbidden removed after active frames

		onenter = function(inst, overridefocus)
			inst.Physics:Stop()
			inst.AnimState:PlayAnimation("shotput_H_atk")
			inst:PushEvent("attack_state_start")
			inst.sg.statemem.tackletargets = {}

			inst.sg.statemem.lighthitcombostate = "punch2"
			inst.sg.statemem.lighthitcombodelayframes = 4
		end,

		timeline =
		{
			--sounds
			FrameEvent(1, function(inst)
				local params = {}
				params.soundevent = "Shotput_punch_whoosh_1"
				params.sound_max_count = 1
				inst.sound_handle = soundutil.PlaySoundData(inst, params)
			end),
			--

			--physics
			-- Code Generated by PivotTrack.jsfl
			FrameEvent(2, function(inst) inst.Physics:MoveRelFacing(24/150) end),
			FrameEvent(4, function(inst) inst.Physics:MoveRelFacing(50/150) end),
			-- End Generated Code

			--

			--Attack
			FrameEvent(4, function(inst)
				combatutil.StartMeleeAttack(inst)

				inst.components.hitbox:StartRepeatTargetDelayTicks(1) -- Set quite low so that we still evaluate if the ball should be hit each tick
				inst.sg.statemem.attackid = "PUNCH1"
				inst.sg.statemem.ballhit_height_threshold = PUNCH1_HEIGHT_THRESHOLD

				-- The y-positions that the ball will be restrained to when it starts its 'spiked' trajectory
				inst.sg.statemem.minheight = 0.5
				inst.sg.statemem.maxheight = 1.25

				inst.components.hitbox:PushBeam(0, 2.7, 2, HitPriority.PLAYER_DEFAULT)
				inst.components.hitbox:PushBeam(2.7, 3, 1.5, HitPriority.PLAYER_DEFAULT)
			end),
			FrameEvent(5, function(inst)
				inst.components.hitbox:PushBeam(0, 2.7, 1.5, HitPriority.PLAYER_DEFAULT)
				inst.components.hitbox:PushBeam(-0.5, 1.25, 1.25, HitPriority.PLAYER_DEFAULT)
			end),
			FrameEvent(6, function(inst)
				inst.components.hitbox:PushBeam(0, 1, 1.5, HitPriority.PLAYER_DEFAULT)
				inst.components.hitbox:PushBeam(-0.5, 1.25, 1.25, HitPriority.PLAYER_DEFAULT)
			end),
			FrameEvent(7, function(inst)
				inst.components.hitbox:PushBeam(0, 1, 1.5, HitPriority.PLAYER_DEFAULT)
				inst.components.hitbox:PushBeam(-0.5, 1.25, 1.25, HitPriority.PLAYER_DEFAULT)
				combatutil.EndMeleeAttack(inst)
				inst.sg:RemoveStateTag("shotput_catch_forbidden")
			end),
			--

			--cancels
			FrameEvent(0, function(inst) inst.sg.statemem.heavycombostate = "default_heavy_attack" end),
			FrameEvent(4, function(inst) inst.sg.statemem.heavycombostate = nil end),
			FrameEvent(10, function(inst)
				inst.sg.statemem.lightcombostate = "punch2"
				SGPlayerCommon.Fns.TryQueuedAction(inst, MELEE_BUTTON)
			end),
			FrameEvent(12, SGPlayerCommon.Fns.SetCanDodge),
			FrameEvent(12, SGPlayerCommon.Fns.SetCanSkill),
			FrameEvent(12, function(inst)
				inst.sg.statemem.heavycombostate = "default_heavy_attack"
				SGPlayerCommon.Fns.TryQueuedAction(inst, THROW_BUTTON)
			end),
			FrameEvent(12, function(inst)
				inst.sg.statemem.lightcombostate = "default_light_attack"
				SGPlayerCommon.Fns.TryQueuedAction(inst, MELEE_BUTTON)
			end),
			--
		},

		events =
		{
			EventHandler("animover", function(inst)
				inst.sg:GoToState("idle")
			end),

			EventHandler("hitboxtriggered", OnPunchHitBoxTriggered),

			EventHandler("shotput_caught", function(inst, projectile)
				OnCatch(inst, projectile)
			end),
		},

		onexit = function(inst)
			inst.components.hitbox:StopRepeatTargetDelay()
		end,
	}),

	State({
		name = "punch2",
		tags = { "attack", "busy", "shotput_catch_forbidden", "light_attack" }, --shotput_catch_forbidden removed after active frames

		onenter = function(inst, overridefocus)
			inst.AnimState:PlayAnimation("shotput_H_atk2")
			inst:PushEvent("attack_state_start")
			inst.sg.statemem.tackletargets = {}
			local frames = inst.AnimState:GetCurrentAnimationNumFrames()
			inst.components.playercontroller:OverrideControlQueueTicks("heavyattack", frames * ANIM_FRAMES)

			inst.sg.statemem.lighthitcombostate = "punch3"
			inst.sg.statemem.lighthitcombodelayframes = 10
		end,

		timeline =
		{
			--sounds
			FrameEvent(4, function(inst)
				local params = {}
				params.fmodevent = fmodtable.Event.Shotput_punch_whoosh_2
				params.sound_max_count = 1
				soundutil.PlaySoundData(inst, params)
			end),

			--physics
			FrameEvent(6, function(inst) SGCommon.Fns.SetMotorVelScaled(inst, 7.5) end),
			FrameEvent(12, function(inst) inst.Physics:Stop() end),
			-- Code Generated by PivotTrack.jsfl
			--FrameEvent(6, function(inst) inst.Physics:MoveRelFacing(72/150) end),
			--FrameEvent(9, function(inst) inst.Physics:MoveRelFacing(68/150) end),
			--FrameEvent(12, function(inst) inst.Physics:MoveRelFacing(56/150) end),
			FrameEvent(14, function(inst) inst.Physics:MoveRelFacing(50/150) end),
			-- End Generated Code
			--

			--Attack
			FrameEvent(4, function(inst)
				combatutil.StartMeleeAttack(inst)

				inst.components.hitbox:StartRepeatTargetDelayTicks(1) -- Set quite low so that we still evaluate if the ball should be hit each tick
				inst.sg.statemem.attackid = "PUNCH2"
				inst.sg.statemem.ballhit_height_threshold = PUNCH2_HEIGHT_THRESHOLD_LOW

				-- The y-positions that the ball will be restrained to when it starts its 'spiked' trajectory
				inst.sg.statemem.minheight = 0.5
				inst.sg.statemem.maxheight = 2.5

				inst.components.hitbox:PushBeam(0, 2.7, 2, HitPriority.PLAYER_DEFAULT)
				inst.components.hitbox:PushBeam(2.7, 3, 1.5, HitPriority.PLAYER_DEFAULT)
			end),
			FrameEvent(5, function(inst)
				inst.components.hitbox:PushBeam(0, 2.7, 2, HitPriority.PLAYER_DEFAULT)
				inst.components.hitbox:PushBeam(2.7, 3, 1.5, HitPriority.PLAYER_DEFAULT)
			end),
			FrameEvent(6, function(inst)
				inst.components.hitbox:PushBeam(-1.25, 1.25, 1.25, HitPriority.PLAYER_DEFAULT)
				inst.sg:AddStateTag("airborne")
			end),
			FrameEvent(7, function(inst)
				inst.sg.statemem.ballhit_height_threshold = PUNCH2_HEIGHT_THRESHOLD_HIGH
				inst.sg.statemem.maxheight = PUNCH2_HEIGHT_THRESHOLD_HIGH
				inst.components.hitbox:PushBeam(-1.25, 1.25, 1.25, HitPriority.PLAYER_DEFAULT)
			end),
			FrameEvent(8, function(inst)
				inst.components.hitbox:PushBeam(-1.25, 1.25, 1.25, HitPriority.PLAYER_DEFAULT)
				combatutil.EndMeleeAttack(inst)
				inst.sg:RemoveStateTag("shotput_catch_forbidden")
			end),
			FrameEvent(12, function(inst)
				inst.sg:RemoveStateTag("airborne")
			end),
			--

			--cancels
			FrameEvent(0, function(inst) inst.sg.statemem.heavycombostate = "default_heavy_attack" end),
			FrameEvent(4, function(inst) inst.sg.statemem.heavycombostate = nil end),
			FrameEvent(16, function(inst)
				inst.sg.statemem.lightcombostate = "punch3"
				SGPlayerCommon.Fns.TryQueuedAction(inst, MELEE_BUTTON)
			end),
			FrameEvent(16, SGPlayerCommon.Fns.SetCanDodge),
			FrameEvent(16, SGPlayerCommon.Fns.SetCanSkill),
			FrameEvent(17, function(inst)
				inst.sg.statemem.lightcombostate = "default_light_attack"
				SGPlayerCommon.Fns.TryQueuedAction(inst, MELEE_BUTTON)
			end),
			--
		},

		events =
		{
			EventHandler("animover", function(inst)
				inst.sg:GoToState("idle")
			end),

			EventHandler("hitboxtriggered", OnPunchHitBoxTriggered),

			EventHandler("shotput_caught", function(inst, projectile)
				OnCatch(inst, projectile)
			end),
		},

		onexit = function(inst)
			inst.components.hitbox:StopRepeatTargetDelay()
			inst.Physics:Stop()
			inst.components.playercontroller:OverrideControlQueueTicks("heavyattack", nil)
		end,
	}),

	State({
		name = "punch3",
		tags = { "attack", "busy", "shotput_catch_forbidden", "light_attack" }, --shotput_catch_forbidden removed after active frames

		onenter = function(inst, overridefocus)
			inst.AnimState:PlayAnimation("shotput_H_atk3")
			inst:PushEvent("attack_state_start")
			inst.sg.statemem.tackletargets = {}
		end,

		timeline =
		{
			-- Sounds
			FrameEvent(1, function(inst)
				local params = {}
				params.fmodevent = fmodtable.Event.Shotput_punch_whoosh_3
				params.sound_max_count = 1
				soundutil.PlaySoundData(inst, params)
			end),

			-- Physics
			-- Code Generated by PivotTrack.jsfl
			FrameEvent(2, function(inst) inst.Physics:MoveRelFacing(44/150) end),
			FrameEvent(5, function(inst) inst.Physics:MoveRelFacing(34/150) end),
			FrameEvent(8, function(inst) inst.Physics:MoveRelFacing(36/150) end),
			FrameEvent(9, function(inst) inst.Physics:MoveRelFacing(24/150) end),
			FrameEvent(12, function(inst) inst.Physics:MoveRelFacing(62/150) end),
			-- End Generated Code

			-- Tags
			FrameEvent(5, function(inst) inst.sg:AddStateTag("airborne") end),
			FrameEvent(9, function(inst) inst.sg:RemoveStateTag("airborne") end),

			--Attack
			FrameEvent(7, function(inst)
				combatutil.StartMeleeAttack(inst)

				inst.components.hitbox:StartRepeatTargetDelayTicks(1) -- Set quite low so that we still evaluate if the ball should be hit each tick
				inst.sg.statemem.attackid = "PUNCH3"

				inst.sg.statemem.ballhit_height_threshold = PUNCH3_HEIGHT_THRESHOLD

				-- The y-positions that the ball will be restrained to when it starts its 'spiked' trajectory
				inst.sg.statemem.minheight = 0.5
				inst.sg.statemem.maxheight = PUNCH3_HEIGHT_THRESHOLD

				inst.components.hitbox:PushBeam(-2, -0.25, 0.25, HitPriority.PLAYER_DEFAULT)
			end),
			FrameEvent(8, function(inst)
				inst.components.hitbox:PushBeam(-2, -0.25, 0.25, HitPriority.PLAYER_DEFAULT)
				inst.components.hitbox:PushBeam(0, 1, 2, HitPriority.PLAYER_DEFAULT)
			end),
			FrameEvent(9, function(inst)
				inst.components.hitbox:PushBeam(-2, -0.25, 0.25, HitPriority.PLAYER_DEFAULT)
				inst.components.hitbox:PushBeam(0, 2, 1.5, HitPriority.PLAYER_DEFAULT)
				inst.components.hitbox:PushBeam(2, 2.5, 1.25, HitPriority.PLAYER_DEFAULT)
			end),
			-- FrameEvent(9, function(inst) inst.components.hitbox:PushBeam(0, 2, 1.5, HitPriority.PLAYER_DEFAULT) end),
			FrameEvent(10, function(inst) inst.components.hitbox:PushBeam(0, 2, 1.5, HitPriority.PLAYER_DEFAULT) end),
			FrameEvent(11, function(inst) inst.components.hitbox:PushBeam(0, 2, 1.5, HitPriority.PLAYER_DEFAULT) end),
			FrameEvent(12, function(inst) inst.components.hitbox:PushBeam(0, 2, 1.5, HitPriority.PLAYER_DEFAULT) end),
			FrameEvent(13, function(inst) inst.components.hitbox:PushBeam(0, 2, 1.5, HitPriority.PLAYER_DEFAULT) end),
			FrameEvent(14, function(inst)
				inst.components.hitbox:PushBeam(0, 2, 1.5, HitPriority.PLAYER_DEFAULT)
				combatutil.EndMeleeAttack(inst)
				inst.sg:RemoveStateTag("shotput_catch_forbidden")
			end),
			--

			-- Cancels
			FrameEvent(18, SGPlayerCommon.Fns.SetCanSkill),
			FrameEvent(18, SGPlayerCommon.Fns.SetCanDodge),
			FrameEvent(21, function(inst)
				inst.sg.statemem.heavycombostate = "default_heavy_attack"
				SGPlayerCommon.Fns.TryQueuedAction(inst, MELEE_BUTTON)
			end),
			--
		},

		events =
		{
			EventHandler("animover", function(inst)
				inst.sg:GoToState("idle")
			end),

			EventHandler("hitboxtriggered", OnPunchHitBoxTriggered),

			EventHandler("shotput_caught", function(inst, projectile)
				OnCatch(inst, projectile)
			end),
		},

		onexit = function(inst)
			inst.components.hitbox:StopRepeatTargetDelay()
		end,
	}),

	-- State({
	-- 	name = "heavy_attack_throw",
	-- 	tags = { "busy" },

	-- 	onenter = function(inst, overridefocus)
	-- 		inst.AnimState:PlayAnimation("shotput_atk2")
	-- 		if overridefocus ~= nil then
	-- 			inst.sg.statemem.focusthrow = overridefocus
	-- 		else
	-- 			inst.sg.statemem.focusthrow = IsFocusThrow(inst)
	-- 		end

		-- if inst.sg.statemem.focusthrow then
		-- 	StartFocusParticles(inst)
		-- end
	-- 		inst:PushEvent("attack_state_start")
	-- 	end,

	-- 	timeline =
	-- 	{
	-- 		FrameEvent(1, function(inst) inst.SoundEmitter:PlaySoundWithParams(THROW_HEAVY_SOUND, { isFocusAttack = inst.sg.statemem.focusthrow and 1 or 0, shotputAmmo = inst.sg.mem.ammo }, nil, 1) end),
	-- 		FrameEvent(15, function(inst)
	--			local params = {}
	--			params.fmodevent = fmodtable.Event.Shotput_whoosh_light
	--			params.sound_max_count = 1
	--			local handle = soundutil.PlaySoundData(inst, params)
	-- soundutil.SetInstanceParameter(inst, handle, "isFocusAttack", inst.sg.statemem.focusthrow and 1 or 0)
	-- soundutil.SetInstanceParameter(inst, handle, "shotputAmmo", inst.sg.mem.ammo)
	--		end),

	-- 		FrameEvent(21, function(inst)
	-- 			MakeHeavyAttackProjectile(inst)

	-- 		end),
	-- 	},

	-- 	events =
	-- 	{
	-- 		EventHandler("animover", function(inst)
	-- 			inst.sg:GoToState("idle")
	-- 		end),

	-- 		EventHandler("shotput_caught", function(inst, projectile)
	-- 			OnCatch(inst, projectile)

	-- 			-- Catching the shotput while in startup frames, we pressed the button a little early -- provide a buffer
	-- 			SwitchToFocusMidthrow(inst, projectile)
	-- 		end),
	-- 	},

	-- 	onexit = function(inst)
	-- 	end,
	-- }),

	State({
		name = "rolling_tackle_early",
		tags = { "attack", "busy", "light_attack" },

		onenter = function(inst, speedmult)
			inst.sg:GoToState("rolling_tackle", 0.75)
		end,
	}),

	State({
		name = "rolling_tackle_late",
		tags = { "attack", "busy", "light_attack" },

		onenter = function(inst, speedmult)
			inst.sg:GoToState("rolling_tackle", 0.75)
		end,
	}),

	State({
		name = "rolling_tackle",
		tags = { "attack", "busy", "shotput_catch_forbidden", "light_attack" }, --shotput_catch_forbidden removed after active frames

		onenter = function(inst, speedmult)
			inst:PushEvent("attack_state_start")
			inst.AnimState:PlayAnimation("shotput_tackle")

			inst.sg.statemem.speedmult = speedmult or 1
			SGPlayerCommon.Fns.SetRollPhysicsSize(inst)
			inst.sg.statemem.hitboxsize = inst.HitBox:GetSize()
			inst.HitBox:SetNonPhysicsRect(1.5)
			inst.sg.statemem.tackletargets = {}

			SGCommon.Fns.StartJumpingOverHoles(inst)

			inst.sg.statemem.lighthitcombostate = "punch"
			inst.sg.statemem.lighthitcombodelayframes = 0
		end,

		onupdate = function(inst)
			if inst.sg.statemem.hittingbody then
				-- A very thin hitbox not intended to hit enemies, but place a hitbox over the player's body. Should still allow players to tackle *past* adjacent enemies, but catch a ball landing on them.
				inst.components.hitbox:PushBeam(-1.5, 1, 0.05, HitPriority.PLAYER_DEFAULT)
			end

			if inst.sg.statemem.hittingshoulder then
				-- The main attacking hitbox of the attack
				inst.components.hitbox:PushBeam(1.75, 2.25, 1.25, HitPriority.PLAYER_DEFAULT)
			end
		end,

		timeline =
		{
			--PHYSICS
			-- leaving the ground again
			FrameEvent(0, function(inst) SGCommon.Fns.SetMotorVelScaled(inst, 16 * inst.sg.statemem.speedmult) end),
			FrameEvent(8, function(inst) SGCommon.Fns.SetMotorVelScaled(inst, 12 * inst.sg.statemem.speedmult) end),
			FrameEvent(10, function(inst) SGCommon.Fns.SetMotorVelScaled(inst, 4 * inst.sg.statemem.speedmult) end),
			FrameEvent(12, function(inst) SGCommon.Fns.SetMotorVelScaled(inst, 2 * inst.sg.statemem.speedmult) end),
			FrameEvent(13, function(inst) inst.Physics:Stop() end),

			--ATTACK
			FrameEvent(0, function(inst)
				--TODO(jambell): try adding a head hitbox that extends past the attack hitbox
				inst.sg:AddStateTag("airborne")
				combatutil.StartMeleeAttack(inst)

				inst.sg.statemem.attackid = "TACKLE"

				inst.sg.statemem.focushit = false
				inst.components.hitbox:StartRepeatTargetDelayTicks(1) -- Set quite low so that we still evaluate if the ball should be hit every tick

				inst.sg.statemem.hittingbody = true
				inst.sg.statemem.hittingshoulder = false

			end),
			FrameEvent(2, function(inst)
				inst.sg.statemem.hittingbody = true
				inst.sg.statemem.hittingshoulder = true
			end),
			FrameEvent(9, function(inst)
				inst.sg:RemoveStateTag("airborne")
				SGCommon.Fns.StopJumpingOverHoles(inst)
			end),
			FrameEvent(11, function(inst)
				inst.sg.statemem.hittingbody = false
				inst.sg.statemem.hittingshoulder = false
				combatutil.EndMeleeAttack(inst)
				inst.sg:RemoveStateTag("shotput_catch_forbidden")
			end),

			--CANCELS
			FrameEvent(14, SGPlayerCommon.Fns.SetCanDodge),
			FrameEvent(14, SGPlayerCommon.Fns.SetCanAttackOrAbility),
			FrameEvent(15, SGPlayerCommon.Fns.RemoveBusyState),
		},

		onexit = function(inst)
			inst.Physics:Stop()
			inst.HitBox:SetNonPhysicsRect(inst.sg.statemem.hitboxsize)
			SGPlayerCommon.Fns.UndoRollPhysicsSize(inst)
			inst.components.hitbox:StopRepeatTargetDelay()
			SGCommon.Fns.StopJumpingOverHoles(inst)
		end,

		events =
		{
			EventHandler("hitboxtriggered", OnTackleHitBoxTriggered),
			EventHandler("animover", function(inst)
				inst.sg:GoToState("idle")
			end),
		},
	}),

	State({
		name = "fading_kick",
		tags = { "attack", "busy", "light_attack" },

		onenter = function(inst, speedmult)
			inst.sg:GoToState("fading_kick", 0.8)
		end,
	}),

	State({
		name = "fading_kick_late",
		tags = { "attack", "busy", "light_attack" },

		onenter = function(inst, speedmult)
			inst.sg:GoToState("fading_kick", 0.8)
		end,
	}),

	State({
		name = "fading_kick",
		tags = { "attack", "busy", "airborne", "shotput_catch_forbidden", "light_attack" }, --shotput_catch_forbidden removed after active frames

		onenter = function(inst, speedmult)
			inst:PushEvent("attack_state_start")
			inst.AnimState:PlayAnimation("shotput_roll_fade_H_atk")

			inst.sg.statemem.speedmult = speedmult or 1
			SGPlayerCommon.Fns.SetRollPhysicsSize(inst)
			inst.sg.statemem.hitboxsize = inst.HitBox:GetSize()
			inst.HitBox:SetNonPhysicsRect(1.5)
			inst:FlipFacingAndRotation()
			inst.sg.statemem.tackletargets = {}

			SGCommon.Fns.StartJumpingOverHoles(inst)
		end,

		-- onupdate = function(inst)
		-- 	if inst.sg.statemem.hitting then
		-- 		inst.components.hitbox:PushBeam(-1.75, 3, 1.25, HitPriority.PLAYER_DEFAULT)
		-- 	end
		-- end,

		timeline =
		{
			-- sounds
			FrameEvent(1, function(inst)
				local params = {}
				params.fmodevent = fmodtable.Event.Shotput_kick_whoosh
				params.sound_max_count = 1
				soundutil.PlaySoundData(inst, params)
			end),
			--

			--PHYSICS
			-- touch ground
			FrameEvent(0, function(inst) SGCommon.Fns.SetMotorVelScaled(inst, -7 * inst.sg.statemem.speedmult) end),
			--slowdown
			FrameEvent(13, function(inst) SGCommon.Fns.SetMotorVelScaled(inst, -3 * inst.sg.statemem.speedmult) end),
			FrameEvent(15, function(inst) SGCommon.Fns.SetMotorVelScaled(inst, -2 * inst.sg.statemem.speedmult) end),
			--land
			FrameEvent(16, function(inst) inst.Physics:Stop() end),

			--ATTACK
			FrameEvent(2, function(inst)
				combatutil.StartMeleeAttack(inst)

				inst.sg.statemem.attackid = "FADING_KICK"

				inst.sg.statemem.focushit = false
				inst.components.hitbox:StartRepeatTargetDelayTicks(1) -- Set quite low so that we still evaluate if the ball should be hit each tick

				inst.components.hitbox:PushBeam(-2, -1.5, .25, HitPriority.PLAYER_DEFAULT)
				inst.components.hitbox:PushBeam(-2, -3, 1, HitPriority.PLAYER_DEFAULT)
			end),

			FrameEvent(3, function(inst)
				inst.components.hitbox:PushBeam(-2, -1.5, .25, HitPriority.PLAYER_DEFAULT)
				inst.components.hitbox:PushBeam(-2, -3, 1, HitPriority.PLAYER_DEFAULT)

			end),


			FrameEvent(4, function(inst)
				inst.components.hitbox:PushBeam(-1.5, 1.5, .25, HitPriority.PLAYER_DEFAULT)
				inst.sg.statemem.angledown = true -- At the top of the attack arc, force the ball to gravity downwards immediately
			end),

			FrameEvent(5, function(inst)
				inst.components.hitbox:PushBeam(0, 2, 1.25, HitPriority.PLAYER_DEFAULT)
				inst.components.hitbox:PushBeam(2, 3, 1.75, HitPriority.PLAYER_DEFAULT)
			end),

			FrameEvent(6, function(inst)
				inst.components.hitbox:PushBeam(0, 2, 1.25, HitPriority.PLAYER_DEFAULT)
				inst.components.hitbox:PushBeam(2, 3, 1.75, HitPriority.PLAYER_DEFAULT)
			end),
			FrameEvent(7, function(inst)
				inst.components.hitbox:PushBeam(0, 2, 1.25, HitPriority.PLAYER_DEFAULT)
			end),
			FrameEvent(8, function(inst)
				inst.components.hitbox:PushBeam(0, 2, 1.25, HitPriority.PLAYER_DEFAULT)
				combatutil.EndMeleeAttack(inst)
				inst.sg:RemoveStateTag("shotput_catch_forbidden")
			end),
			-- FrameEvent(9, function(inst)
			-- 	inst.components.hitbox:PushBeam(0, 2, 1.25, HitPriority.PLAYER_DEFAULT)
			-- end),

			FrameEvent(15, function(inst)
				inst.sg:RemoveStateTag("airborne")
				inst.HitBox:SetNonPhysicsRect(inst.sg.statemem.hitboxsize)
				SGCommon.Fns.StopJumpingOverHoles(inst)
			end),

			--CANCELS
			FrameEvent(15, function(inst)
				if inst.sg.statemem.hit then
					inst.sg.statemem.heavycombostate = "default_heavy_attack"
					SGPlayerCommon.Fns.TryQueuedAction(inst, THROW_BUTTON)
				end
			end),
			FrameEvent(19, function(inst)
				SGPlayerCommon.Fns.SetCanDodge(inst)
				--SGPlayerCommon.Fns.TryQueuedAction(inst, "dodge")
			end),
			FrameEvent(19, SGPlayerCommon.Fns.SetCanAttackOrAbility),
			FrameEvent(29, SGPlayerCommon.Fns.RemoveBusyState),
		},

		onexit = function(inst)
			inst.Physics:Stop()
			inst.HitBox:SetNonPhysicsRect(inst.sg.statemem.hitboxsize)
			SGPlayerCommon.Fns.UndoRollPhysicsSize(inst)
			inst.components.hitbox:StopRepeatTargetDelay()
		end,

		events =
		{
			EventHandler("hitboxtriggered", OnFadingTackleHitBoxTriggered),
			EventHandler("animover", function(inst)
				inst.sg:GoToState("idle")
			end),
		},
	}),

	State({
		name = "noammo",
		tags = { "busy" },

		onenter = function(inst)
			inst.AnimState:PlayAnimation("shotput_empty")
		end,

		timeline =
		{
			--CANCELS
			FrameEvent(7, SGPlayerCommon.Fns.SetCanDodge),
			FrameEvent(10, SGPlayerCommon.Fns.RemoveBusyState),
		},

		events =
		{
			EventHandler("animover", function(inst)
				inst.sg:GoToState("idle")
			end),

			EventHandler("shotput_caught", function(inst, projectile)
				OnCatch(inst, projectile)

				-- Catching the shotput while in startup frames, we pressed the button a little early -- provide a buffer
				local framesinstate = inst.sg:GetAnimFramesInState()
				if framesinstate <= NOAMMO_TO_THROW_WINDOW_ANIMFRAMES then
					if framesinstate <= PRE_CATCH_FOCUS_BUFFER_ANIMFRAMES then
						inst.sg.statemem.focusthrow = true
						StartFocusParticles(inst)
					else
						inst.sg.statemem.focusthrow = false
					end

					inst.sg:GoToState("throw", inst.sg.statemem.focusthrow)
				end
			end),
		},
	}),

	-- BALL INTERACTIONS
	State({
		name = "catch",
		tags = { "busy" },

		onenter = function(inst)
			-- See whether we're moving or not, so we can keep the player moving + play the appropriate anim
			local moving = false
			local controller_dir = inst.components.playercontroller:GetAnalogDir()
			if controller_dir ~= nil then
				inst.components.locomotor:TurnToDirection(controller_dir)
				SGCommon.Fns.SetMotorVelScaled(inst, inst.components.locomotor:GetBaseRunSpeed())
				moving = true
			end

			-- Find the right anim + play it
			local anim
			if inst.sg.mem.ammo > 1 then
				anim = moving and "shotput_armed_moving_catch" or "shotput_armed_catch"
			else
				anim = moving and "shotput_moving_catch" or "shotput_catch"
			end
			inst.AnimState:PlayAnimation(anim)
			StartFocusParticles(inst)
			local params = {}
			params.fmodevent = fmodtable.Event.Shotput_catch
			params.sound_max_count = 1
			local handle = soundutil.PlaySoundData(inst, params)
			if inst.sg.mem.ammo then
				soundutil.SetInstanceParameter(inst, handle, "shotputAmmo", inst.sg.mem.ammo)
			end

			SGPlayerCommon.Fns.SetCanAttackOrAbility(inst)
		end,

		onupdate = function(inst)
			local controller_dir = inst.components.playercontroller:GetAnalogDir()
			if controller_dir then
				inst.components.locomotor:TurnToDirection(controller_dir)
			else
				inst.Physics:Stop()
			end
		end,

		timeline =
		{
			FrameEvent(2, SGPlayerCommon.Fns.SetCanDodge),
			FrameEvent(6, SGPlayerCommon.Fns.RemoveBusyState),
			FrameEvent(POST_CATCH_FOCUS_BUFFER_ANIMFRAMES, StopFocusParticles)
		},

		onexit = function(inst)
			StopFocusParticles(inst)
		end,

		events =
		{
			EventHandler("animover", function(inst)
				inst.sg:GoToState("idle")
			end),
		},
	}),

	State({
		name = "pickup_shotput",
		tags = { "busy" },

		onenter = function(inst)
			-- Find the right anim + play it
			local anim = inst.sg.mem.ammo > 1 and "shotput_armed_quick_pickup" or "shotput_quick_pickup"
			inst.AnimState:PlayAnimation(anim)

			-- See whether we're already moving or not, so we can keep the player moving
			local controller_dir = inst.components.playercontroller:GetAnalogDir()
			if controller_dir ~= nil then
				inst.components.locomotor:TurnToDirection(controller_dir)
				SGCommon.Fns.SetMotorVelScaled(inst, inst.components.locomotor:GetBaseRunSpeed())
			end

			SGPlayerCommon.Fns.SetCanAttackOrAbility(inst)
		end,

		onupdate = function(inst)
			local controller_dir = inst.components.playercontroller:GetAnalogDir()
			if controller_dir then
				inst.components.locomotor:TurnToDirection(controller_dir)
			else
				inst.Physics:Stop()
			end
		end,


		timeline =
		{
			FrameEvent(2, SGPlayerCommon.Fns.SetCanDodge),
			FrameEvent(4, SGPlayerCommon.Fns.RemoveBusyState),
		},

		events =
		{
			EventHandler("animover", function(inst)
				inst.sg:GoToState("idle")
			end),
		},
	}),
}

SGPlayerCommon.States.AddAllBasicStates(states)
SGPlayerCommon.States.AddRollStates(states)

-- TODO: add this as a SGPlayerCommon helper function after moving the other weapons over, too.
-- TODO: should roll_pre have combo states too, to allow 1-or-2 frame immediate cancels? I think yes?
for i,state in ipairs(states) do
	if state.name == "roll_pre" then
		local id = #state.timeline
		state.timeline[id + 1] = FrameEvent(0, function(inst)
			inst.sg.statemem.heavycombostate = "throw_from_rolling_loop"
			inst.sg.statemem.reverseheavystate = "reverse_throw_from_rolling_loop"

			inst.sg.statemem.lightcombostate = "rolling_tackle_early"
			inst.sg.statemem.reverseheavystate = "fading_kick"
		end)
		state.timeline[id + 1].idx = id + 1

		table.sort(state.timeline, function(a,b) return a.frame < b.frame end)
	end

	if state.name == "roll_loop" then
		local id = #state.timeline
		state.timeline[id + 1] = FrameEvent(0, function(inst)
			inst.sg.statemem.heavycombostate = "throw_from_rolling_loop"
			inst.sg.statemem.reverseheavystate = "reverse_throw_from_rolling_loop"

			inst.sg.statemem.lightcombostate = "rolling_tackle_early"
			inst.sg.statemem.reverselightstate = "fading_kick"
		end)

		state.timeline[id + 2] = FrameEvent(4, function(inst)
			inst.sg.statemem.lightcombostate = "rolling_tackle"
			inst.sg.statemem.reverselightstate = "fading_kick"
		end)
		state.timeline[id + 2].idx = id + 2

		table.sort(state.timeline, function(a,b) return a.frame < b.frame end)
	end

	if state.name == "roll_pst" then
		local id = #state.timeline
		state.timeline[id + 1] = FrameEvent(0, function(inst)
			inst.sg.statemem.heavycombostate = "throw_from_rolling_pst"
			inst.sg.statemem.reverseheavystate = "reverse_throw_from_rolling_pst"

			inst.sg.statemem.lightcombostate = "rolling_tackle_late"
			inst.sg.statemem.reverselightstate = "fading_kick_late"
		end)
		state.timeline[id + 1].idx = id + 1

		state.timeline[id + 2] = FrameEvent(10, function(inst)
			inst.sg.statemem.lightcombostate = "default_light_attack"
		end)
		state.timeline[id + 2].idx = id + 2

		table.sort(state.timeline, function(a,b) return a.frame < b.frame end)
	end


	-- LIGHT ROLL
	if state.name == "roll_light" then
		local id = #state.timeline
		state.timeline[id + 1] = FrameEvent(0, function(inst)
			inst.sg.statemem.heavycombostate = "throw_from_rolling_loop"
			inst.sg.statemem.reverseheavystate = "reverse_throw_from_rolling_loop"

			inst.sg.statemem.lightcombostate = "rolling_tackle_early"
			inst.sg.statemem.reverselightstate = "fading_kick"
			SGPlayerCommon.Fns.TryQueuedLightOrHeavy(inst)
		end)
		state.timeline[id + 1].idx = id + 1

		state.timeline[id + 2] = FrameEvent(2, function(inst)
			inst.sg.statemem.heavycombostate = "throw_from_rolling_loop"
			inst.sg.statemem.reverseheavystate = "reverse_throw_from_rolling_loop"

			inst.sg.statemem.lightcombostate = "rolling_tackle"
			inst.sg.statemem.reverselightstate = "fading_kick"
		end)
		state.timeline[id + 1].idx = id + 2

		table.sort(state.timeline, function(a,b) return a.frame < b.frame end)
	end

	if state.name == "roll_light_pst" then
		local id = #state.timeline
		state.timeline[id + 1] = FrameEvent(0, function(inst)
			inst.sg.statemem.heavycombostate = "throw_from_rolling_loop"
			inst.sg.statemem.reverseheavystate = "reverse_throw_from_rolling_loop"

			inst.sg.statemem.lightcombostate = "rolling_tackle"
			inst.sg.statemem.reverselightstate = "fading_kick"
		end)
		state.timeline[id + 1].idx = id + 1

		state.timeline[id + 2] = FrameEvent(2, function(inst)
			inst.sg.statemem.lightcombostate = "rolling_tackle_late"
			inst.sg.statemem.reverselightstate = "fading_kick_late"
		end)
		state.timeline[id + 2].idx = id + 2

		table.sort(state.timeline, function(a,b) return a.frame < b.frame end)
	end

	-- HEAVY ROLL
	if state.name == "roll_heavy" then
		local id = #state.timeline
		state.timeline[id + 1] = FrameEvent(3, function(inst)
			inst.sg.statemem.heavycombostate = "default_heavy_attack"
			inst.sg.statemem.reverseheavystate = "reverse_throw"

			inst.sg.statemem.lightcombostate = "rolling_tackle_late"
			inst.sg.statemem.reverselightstate = "fading_kick_late"
			-- DO NOT TRY to actually execute these states. This just lets the attack get queued up for the next state.
		end)
		state.timeline[id + 1].idx = id + 1

		table.sort(state.timeline, function(a,b) return a.frame < b.frame end)
	end

	if state.name == "roll_heavy_pst" then
		local id = #state.timeline
		state.timeline[id + 1] = FrameEvent(4, function(inst)
			-- First, try any queued attacks we've tried to do in the previous state.
			if inst.sg.statemem.queued_lightcombodata then
				inst.sg.statemem.lightcombostate = inst.sg.statemem.queued_lightcombodata.state
 				if SGPlayerCommon.Fns.DoAction(inst, inst.sg.statemem.queued_lightcombodata.data) then
 					inst.components.playercontroller:FlushControlQueue()
 				else
 					inst.sg.statemem.queued_lightcombodata = nil
 				end
			elseif inst.sg.statemem.queued_heavycombodata then
				inst.sg.statemem.heavycombostate = inst.sg.statemem.queued_heavycombodata.state
 				if SGPlayerCommon.Fns.DoAction(inst, inst.sg.statemem.queued_heavycombodata.data) then
 					inst.components.playercontroller:FlushControlQueue()
 				else
 					inst.sg.statemem.queued_heavycombodata = nil
 				end
 			else
				-- If we didn't queue anything before, go to these instead:
				inst.sg.statemem.heavycombostate = "default_heavy_attack"
				inst.sg.statemem.reverseheavystate = "reverse_throw"

				inst.sg.statemem.lightcombostate = "rolling_tackle_late"
				inst.sg.statemem.reverselightstate = "fading_kick_late"
				SGPlayerCommon.Fns.TryQueuedLightOrHeavy(inst)
			end
		end)
		state.timeline[id + 1].idx = id + 1

		table.sort(state.timeline, function(a,b) return a.frame < b.frame end)
	end
end

local fns =
{
	OnRemoveFromEntity = function(sg)	-- This is a catch-all for when this sg is removed from the entity. 
		ResetAnimSymbols(sg.inst)

		RemoveProjectiles(sg)
	end,
}

return StateGraph("sg_player_"..WEAPON_PREFIX, states, events, "init", fns)
