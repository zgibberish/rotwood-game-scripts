local SGCommon = require "stategraphs.sg_common"
local easing = require("util.easing")
local soundutil = require "util.soundutil"
local fmodtable = require "defs.sound.fmodtable"
local combatutil = require "util.combatutil"

local HIT_REBOUND_DISTANCE = 8 -- When a Light Attack-Thrown ball hits, how far does it bounce back?
							   -- Tuning notes: the shorter this is, the more dangerous it is to catch a rebound

local LOB_DISTANCE = 14 -- When a ball is manually lobbed, how far should it travel?
local OUT_OF_BOUNDS_REBOUND_DISTANCE = 8 -- When a ball goes out of bounds, how far does it bounce back into bounds?

local THROWN_VELOCITY = 23 -- Thrown normally
local THROWN_VELOCITY_FOCUS = 28 -- Thrown with focus timing
local SPIKED_VELOCITY = 31 -- Attacked by anything, while at rest
local SPIKED_ANGLED_VELOCITY = 37 -- Attacked by anything, while moving
local SUMMONED_VELOCITY = 31 -- Recalled with the "summon" skill

local RECALLED_MAX_DIST_X = 10
local RECALLED_MAX_DIST_Z = 8

local HEAVY_AUTOAIM_RANGE = 14 -- Within how much range from our natural target position (based on LOB_DISTANCE) should we select a target and nudge our X value towards them?

local GHOST_DATA_THROWN  = 	{ starting_alpha = 0.2, ticks_between_ghosts = 2, max_count = 5 }
local GHOST_DATA_REBOUND = 	{ starting_alpha = 0.1, ticks_between_ghosts = 2, max_count = 5 }
local GHOST_DATA_SPIKED  = 	{ starting_alpha = 0.25, ticks_between_ghosts = 2, max_count = 7 }  -- TODO(jambell): increase T_B_G when moving through anim 3-2-1-
local GHOST_DATA_DEBUG  = 	{ starting_alpha = 1, ticks_between_ghosts = 1, max_count = 15, permanent = true }

local FOCUS_FLASH_DATA_SPIKED  = { color = { 0/255, 160/255, 160/255 }, frames = 2 }
local FOCUS_FLASH_DATA_THROWN  = { color = { 0/255, 100/255, 100/255 }, frames = 1 }

local SPIKED_ANGLEDOWN_HEIGHT_THRESHOLD = 3.5 -- Under what height should an "angled down" spiked hit turn into a normal hit



local function MatchAnimToFacing(inst)
	if inst.sg.mem.facing == FACING_LEFT then
		inst.AnimState:SetScale(-1, 1)
	else
		inst.AnimState:SetScale(1, 1)
	end
	inst.components.ghosttrail:SetFacing(inst.sg.mem.facing)
end

-------------------------------------------------
-- GAMEPLAY FUNCTIONS

local function DoAttack(inst, target, focus)
	-- TheLog.ch.Shotput:printf("DoAttack %s EntityID %d: owner = %s EntityID %d, target = %s EntityID %d",
	-- 	inst, inst.Network:GetEntityID(),
	-- 	inst.owner, inst.owner.Network:GetEntityID(),
	-- 	target, target.Network and target.Network:GetEntityID() or 0)

	local hitstoplevel = inst.hitstoplevel or HitStopLevel.HEAVY
	local attack = Attack(inst.owner, target)
	local dir = 0

	--TODO(jambell): think about scenario: ball is lobbed over top of enemy, lands on their right side. It was travelling --> but the knockback should be <--
	local vx, vy, vz = inst.Physics:GetVel()
	if vx >= 0 then
		dir = 0
	else
		dir = 180
	end

	--TODO: KNOCKBACK? KNOCKDOWN?

	attack:SetDamageMod(focus and inst.focus_damage_mod or inst.damage_mod)
	attack:SetFocus(focus)
	attack:SetDir(dir)
	attack:SetHitstunAnimFrames(inst.hitstun_animframes)
	attack:SetPushback(focus and 1 or inst.pushback)
	attack:SetID(inst.attacktype)
	attack:SetProjectile(inst, inst.projectilelauncher)

	if inst.source then
		attack:SetSource("projectile")
	end

	local pos = inst:GetPosition()
	if inst.sg.statemem.angledown then
		inst.owner.components.combat:DoKnockdownAttack(attack)
	elseif focus then
		inst.owner.components.combat:DoKnockbackAttack(attack)
	else
		inst.owner.components.combat:DoBasicAttack(attack)
	end

	local fxspawned = inst.owner.components.combat:SpawnHitFxForPlayerAttack(attack, "hits_player_jamball", target, inst, 0, pos.y, dir, hitstoplevel)
	if inst.sg.mem.facing == FACING_LEFT then
		for id,fx in pairs(fxspawned) do
			fx.AnimState:SetScale(-1, 1)
		end
	end
	SGCommon.Fns.ApplyHitstop(attack, hitstoplevel, { projectile = inst })

	SpawnHurtFx(inst, target, 0, dir, hitstoplevel)
end

local ticksinstate_to_distancemult =
{
	{ -1, 	1 }, -- hit from above, don't mult
	{ 0, 	0.75 },
	{ 15, 	1 },
	{ 25, 	1 },
	{ 40, 	0.2 },
	{ 50, 	0 },
}

local function FindReboundTarget(inst, ticksinstate, outofbounds)
	local x, y, z = inst.Transform:GetWorldPosition()

	local dist = outofbounds and OUT_OF_BOUNDS_REBOUND_DISTANCE or HIT_REBOUND_DISTANCE

    -- (LATER IN THE THROW, BOUNCE LESS FAR)
    -- TODO(jambell): disabling this for now until I can get more work put into design+making it feel good. leaving bones here for later.
	-- local dist_multiplier = PiecewiseFn(ticksinstate, ticksinstate_to_distancemult)
	-- local spiked_multiplier = inst.sg.statemem.spiked and 1.2 or 1
	-- print(ticksinstate, dist_multiplier, spiked_multiplier)

	if outofbounds then
		if inst.sg.mem.facing == FACING_LEFT then
			inst.sg.mem.facing = FACING_RIGHT
		else
			inst.sg.mem.facing = FACING_LEFT
		end
	end

	local land_offset = math.max((dist) - inst.sg.mem.enemieshit, 3) --math.max()ing this to 2 makes it permanently bounce in place eventually
	land_offset = land_offset * (inst.sg.mem.facing == FACING_RIGHT and -1 or 1)

	if not TheWorld.Map:IsWalkableAtXZ(x + land_offset, z) then
		local cx, cz, _distsq = TheWorld.Map:FindClosestXZOnWalkableBoundaryToXZ(x + land_offset, z)
		TheLog.ch.Shotput:printf("FindReboundTarget falling back to closest XZ for (%1.2f, %1.2f) = (%1.2f, %1.2f)",
			x, z, cx, cz)

		return Vector3(cx, 0, cz)
	end

	return Vector3(x + land_offset, 0, z)
end

local function FindLobTarget(inst)
	local x, z = inst.owner.Transform:GetWorldXZ()
	local land_offset = LOB_DISTANCE
	local ownerfacing = inst.owner ~= nil and inst.owner.Transform:GetFacing() or FACING_RIGHT
	land_offset = land_offset * (ownerfacing == FACING_LEFT and -1 or 1)

	local target_x = x + land_offset

	local closest, sqdist = GetClosestEntityToXZByTag(x + land_offset, z, HEAVY_AUTOAIM_RANGE, inst.owner.components.combat:GetTargetTags(), true)

	if closest ~= nil then
		-- Predict where they will be based on their velocity
		local ent_x = closest:GetPosition().x
		local predicted_x = ent_x
		local vx, vy, vz = closest.Physics:GetVel()

		if inst.owner:GetDistanceSqToXZ(predicted_x + vx, z) < LOB_DISTANCE then
			predicted_x = closest:GetPosition().x + vx
		end

		-- And pick a middleish point between where the ball was going to land, and where we predict they'll be
		target_x = easing.linear(0.6, target_x, predicted_x - target_x, 1)
	end

	return Vector3(target_x, 0, z)
end

local function ApplyThrowGravity(inst, pos, ticks)
	local gravity = (inst.sg.statemem.gravity or -0.0001) * (ticks * ticks) -- Default gravity, or let it be overridden
	pos.y = pos.y + gravity
	inst.Transform:SetHeight(pos.y)
end

local ticks_to_height_thrown =
{
	-- Make a height arc as the player throws the projectile
	-- First number is tick #, second number is height at that tick
	{ 0, 1.0 },
	{ 4, 1.125 },
	{ 8, 1.15 },
	{ 15, 1.15 },
	{ 16, 1.125 },
	{ 17, 1.1 },
	{ 18, 1.065 },
	{ 19, 1.0 },
	{ 20, 0.95 },
	{ 24, 0.8 },
	{ 28, 0.7 },
	{ 30, 0.6 },
	{ 32, 0.5 },
	{ 34, 0.4 },
	{ 36, 0.3 },
	{ 38, 0.2 },
	{ 40, 0.1 },
}

local ticks_to_angledownheight_thrown =
{
	-- Make a height arc as the player throws the projectile
	-- First number is tick #, second number is height at that tick
	{ 0, 1 },
	{ 10, -1 },
	{ 20, -3 },
	{ 30, -5 },
	{ 40, -7 },
}

-- Whenever a ball is travelling horizontally, update its y-position per tick
local function UpdateHorizontalYPosition(inst)
	local ticks = inst.sg:GetTicksInState()
	local pos = inst:GetPosition()
	if inst.sg.statemem.gravitying then -- Gravitying begins naturally after the ball loops twice in the "squished" anim
		ApplyThrowGravity(inst, pos, ticks)
	else
		-- Gravity hasn't kicked in yet, so use the designed arcs.
		local datatable = inst.sg.statemem.angledown and ticks_to_angledownheight_thrown or ticks_to_height_thrown
		pos.y = inst.sg.statemem.starting_y + PiecewiseFn(ticks, datatable)

		inst.Transform:SetHeight(pos.y)
	end
end

-- Check if a thrown ball has exited playable space. If so, send it to the bounce state and return true.
local function CheckOutOfBounds(inst)

	local pos = inst:GetPosition()
	if not inst:IsInLimbo() and not TheWorld.Map:IsWalkableAtXZ(pos.x, pos.z) then
		local params = {}
		params.fmodevent = fmodtable.Event.Shotput_bounce
		params.sound_max_count = 1
		soundutil.PlaySoundData(inst, params)
		if inst.sg.mem.facing == FACING_LEFT then
			inst.sg.mem.facing = FACING_RIGHT
		else
			inst.sg.mem.facing = FACING_LEFT
		end

		inst.sg:GoToState("rebound", FindReboundTarget(inst, -1, true))
		return true
	else
		return false
	end
end
-------------------------------------------------
-- COMPLEX PROJECTILE STUFF

local function ComplexProjectileHitFn(inst)
	if not inst:IsInLimbo() then 
		inst.Physics:Stop()
		inst.components.shotputeffects:RemoveLandingMarker()
		if inst.sg.statemem.hit then -- if it hit something while rebounding
			if inst.sg.statemem.flipfacing then
				if inst.sg.mem.facing == FACING_LEFT then
					inst.sg.mem.facing = FACING_RIGHT
				elseif inst.sg.mem.facing == FACING_RIGHT then
					inst.sg.mem.facing = FACING_LEFT
				end
			end
			inst.sg:GoToState("hit", { reboundtarget = FindReboundTarget(inst, -1), vertical = true })
		else
			local x,z = inst.Transform:GetWorldXZ()
			if TheWorld.Map:IsWalkableAtXZ(x, z) then
				if inst.sg.mem.canland then
					inst.sg:GoToState("landing", { vertical = true })
				end
			else
				local params = {}
				params.fmodevent = fmodtable.Event.Shotput_bounce
				params.sound_max_count = 1
				soundutil.PlaySoundData(inst, params)
				inst.sg:GoToState("rebound", FindReboundTarget(inst, -1, true))
			end
		end
	end
end

local rangesq_to_gravity =
{
	{ 0, -300 },
	{ 10, -300 },
	{ 15, -200 },
	{ 25, -100 },
	{ 50, -80 },
	{ 100, -80 }
}

local rangesq_to_speedmult =
{
	{ 0, 	0.5 },
	{ 10, 	0.5 },
	{ 15, 	1 },
	{ 25, 	2 },
	{ 50, 	2 },
	{ 100, 	2 }
}

local function SetupComplexProjectile(inst, targetpos)
	targetpos.x = targetpos.x + (math.random(-1, 1)*.25) -- slightly randomize the position so the balls don't fall in the exact same location. Not meant to be far enough to be gameplay-affecting, just presentation-affecting

	local x, y, z = inst.Transform:GetWorldPosition()
    local dx = targetpos.x - x
    local dz = targetpos.z - z
    local rangesq = dx * dx + dz * dz
    local maxrange = 20
    local speed = easing.linear(rangesq, 20, 3, maxrange * maxrange)

    -- TODO(jambell): disabling this for now until I can get more work put into design+making it feel good. leaving bones here for later.
    -- print("rangesq:", rangesq)
    -- local gravity = PiecewiseFn(rangesq, rangesq_to_gravity)
    -- local speedmult = PiecewiseFn(rangesq, rangesq_to_speedmult)

    --TODO(jambell): perhaps modify bounce HEIGHT based on inst.sg.mem.enemieshit
    inst.components.complexprojectile:SetHorizontalSpeed(speed * 2)
    inst.components.complexprojectile:SetGravity(-80)
    inst.components.complexprojectile:Launch(targetpos)
	inst.components.complexprojectile.onhitfn = ComplexProjectileHitFn

	inst.components.hitbox:SetUtilityHitbox(true)
	inst.components.shotputeffects:CreateLandingMarker(targetpos)

	inst.sg:AddStateTag("catchable")
	inst.sg.mem.canland = true
end

local function ComplexProjectileHitFnCancel(inst)
	inst.Physics:Stop()
	inst.components.shotputeffects:RemoveLandingMarker()
end

-------------------------------------------------
-- EVENT HANDLERS

local function OnThrownHitBoxTriggered(inst, data)
	local hit = false

	if inst.sg.mem.enemieshit == nil then
		inst.sg.mem.enemieshit = -0
	end

	for i = 1, #data.targets do
		local v = data.targets[i]
		if inst.owner.components.combat:CanTargetEntity(v) then
			if inst.sg.statemem.spiked then
				local bally = inst:GetPosition().y
				local v_minx, v_miny, v_minz, v_maxx, v_maxy, v_maxz = v.entity:GetWorldAABB()
				if bally >= v_maxy + 1 then
					return
				end
			end
			hit = true
			inst.sg.mem.enemieshit = inst.sg.mem.enemieshit + 1
			DoAttack(inst, v, inst.focusthrow)
		end
	end

	if hit then
		inst.Physics:Stop()
		inst.sg:GoToState("hit", { reboundtarget = FindReboundTarget(inst, inst.sg:GetTicksInState()), vertical = false , spiked = inst.sg.statemem.spiked })
	end
end

local function OnReboundHitBoxTriggered(inst, data)
	--TODO(jambell): favour either a hit OR a catch, probably a catch
	if inst.sg.mem.enemieshit == nil then
		inst.sg.mem.enemieshit = 0
	end
	for i = 1, #data.targets do
		local v = data.targets[i]
		local bally = inst:GetPosition().y
		local v_minx, v_miny, v_minz, v_maxx, v_maxy, v_maxz = v.entity:GetWorldAABB()

		-- Only accept a collision if the ball has actually reached the entity's height
		if bally <= math.max(0.5, v_maxy - 1) then -- NOTE: v_maxy - x => change 'x' to adjust how much below their boundingbox height the ball must go to register a hit.
													 -- The lower this is, the longer it takes to register a hit and also makes player hitting the ball out of the air easier. Slows pace of weapon down a bit.
													 -- Use a minimum of 0.5 because some creatures are very small, and in some animations their bounding boxes may shrink smaller than the normal threshold can hit
			if v:HasTag("shotput") then
				inst:PushEvent("hit_a_shotput")
				v:PushEvent("hit_by_shotput")
				break
			elseif inst.owner.components.combat:CanTargetEntity(v) then
				DoAttack(inst, v, inst.sg.statemem.focushit or inst.focusthrow)
				inst.sg.statemem.hit = v
				inst.sg.mem.enemieshit = inst.sg.mem.enemieshit + 1
			end
		end
	end

	if inst.sg.statemem.hit ~= nil then
		inst.components.complexprojectile:Hit()
	end
end

local function OnRecalledHitBoxTriggered(inst, data)
	if inst.sg.mem.enemieshit == nil then
		inst.sg.mem.enemieshit = 0
	end
	for i = 1, #data.targets do
		local v = data.targets[i]
		local bally = inst:GetPosition().y
		local v_minx, v_miny, v_minz, v_maxx, v_maxy, v_maxz = v.entity:GetWorldAABB()
		-- Only accept a collision if the ball has actually reached the entity's height
		if bally <= v_maxy - 1 then -- NOTE: v_maxy - x => change 'x' to adjust how much below their boundingbox height the ball must go to register a hit.
									-- The lower this is, the longer it takes to register a hit and also makes player hitting the ball out of the air easier. Slows pace of weapon down a bit.
			if v:HasTag("shotput") then
				inst:PushEvent("hit_a_shotput")
				v:PushEvent("hit_by_shotput")
				break
			elseif inst.owner.components.combat:CanTargetEntity(v) then
				DoAttack(inst, v, inst.sg.statemem.focushit or inst.focusthrow)
				inst.sg.statemem.hit = v
				inst.sg.mem.enemieshit = inst.sg.mem.enemieshit + 1
			end
		else
			-- print("not bally <= v_maxy - 1")
			-- print("bally:", bally, "v_maxy - 1:", v_maxy - 1)
		end
	end

	if inst.sg.statemem.hit ~= nil then
		inst.sg.statemem.flipfacing = true
		inst.components.complexprojectile:Hit()
	end
end

local function OnAttacked(inst, attackdata)
	if inst.sg:HasStateTag("hittable") then
		combatutil.EndProjectileAttack(inst)
		local bally = inst:GetPosition().y
		local attack = attackdata.attack
		local attacker = attackdata.attack:GetAttacker()
		if not attacker:IsValid() then
			return
		end
		local attacker_minx, attacker_miny, attacker_minz, attacker_maxx, attacker_maxy, attacker_maxz = attacker.entity:GetWorldAABB()
		local attacker_thresholdy

		if attacker:HasTag("player") then --TODO(jambell): check for "shotputter" tag instead
			attacker_thresholdy = bally + 1 -- always pass the next check -- the shotput stategraph handles this
			if attack:IsLightAttack() then
				inst.attacktype = "light_attack"
			elseif attack:IsHeavyAttack() then
				inst.attacktype = "heavy_attack"
			else
				-- TODO: ask jambell what this is supposed to be for non-light, non-heavy attacks
				-- TheLog.ch.Shotput:printf("Setting attacktype to %s", attack:GetID())
				inst.attacktype = attack:GetID()
			end
			attacker:PushEvent("projectile_launched", { inst })
			inst.projectilelauncher = attacker -- for projectilelauncher attack property
		else
			attacker_thresholdy = attacker_maxy + 3 --(attacker_miny + attacker_maxy) * .75
			inst.projectilelauncher = nil -- for projectilelauncher attack property
		end

		-- Only accept a collision if the ball has actually reached the entity's height
		if bally <= attacker_thresholdy then
			inst.Physics:Stop()
			inst.sg:RemoveStateTag("catchable")
			inst.sg.mem.canland = false

			if attacker.sg ~= nil then
				attackdata.minheight = attacker.sg.statemem.minheight
				attackdata.maxheight = attacker.sg.statemem.maxheight
			end

			inst.sg.mem.facing = attackdata.attack:GetDir() == 0 and FACING_RIGHT or FACING_LEFT
			inst.sg:GoToState("spiked", attackdata)
		end
	end
end

-------------------------------------------------

local events =
{
}

local states =
{
	State({
		name = "limbo",
		tags = { },
	}),

	State({
		name = "thrown",
		tags = { },

		onenter = function(inst)
			inst.AnimState:PlayAnimation("air_fast", true)
			inst.sg.mem.enemieshit = 0
			combatutil.StartProjectileAttack(inst)

			MatchAnimToFacing(inst)

			inst.Physics:StartPassingThroughObjects()
			inst.sg.statemem.starting_y = 1
			inst.Transform:SetHeight(inst.sg.statemem.starting_y)

			if inst.focusthrow then
				inst.components.shotputeffects:StartFocusParticles()
				SGCommon.Fns.BlinkAndFadeColor(inst, FOCUS_FLASH_DATA_THROWN.color, FOCUS_FLASH_DATA_THROWN.frames)

				inst.sg.statemem.velocity = THROWN_VELOCITY_FOCUS * (inst.sg.mem.facing == FACING_LEFT and -1 or 1)
				inst.components.ghosttrail:Activate(GHOST_DATA_THROWN)
			else
				inst.sg.statemem.velocity = THROWN_VELOCITY * (inst.sg.mem.facing == FACING_LEFT and -1 or 1)
			end
		end,

		onupdate = function(inst)
			UpdateHorizontalYPosition(inst)

			local pos = inst:GetPosition()
			-- Check if we've landed
			if pos.y <= 1 then
				inst.sg:GoToState("landing", { vertical = false, spiked = false })
			end

			local oob = CheckOutOfBounds(inst)
			if not oob then
				if inst.sg:GetAnimFramesInState() > 10 then
					local facingmult = inst.sg.mem.facing == FACING_LEFT and -1 or 1
					inst.components.hitbox:PushBeam(.75 * facingmult, -.25 * facingmult, 1.5, HitPriority.MOB_DEFAULT)
				else
					inst.components.hitbox:PushBeam(-.25, .25, 1.5, HitPriority.MOB_DEFAULT)
				end
			end
		end,

		onexit = function(inst)
			inst.components.ghosttrail:Deactivate()
			inst.Physics:StopPassingThroughObjects()
			inst.position_last_frame = nil
		end,

		timeline =
		{
			FrameEvent(0, function(inst) inst.Physics:SetMotorVel(inst.sg.statemem.velocity) end),
			FrameEvent(0, function(inst)
				local params = {}
				params.fmodevent = fmodtable.Event.Shotput_thrown
				params.sound_max_count = 1
				params.stopatexitstate = true
				soundutil.PlaySoundData(inst, params)
			end),
			FrameEvent(8, function(inst) inst.sg.statemem.gravitying = true end),
			FrameEvent(20, function(inst)
				if inst.sg.statemem.forceland then
					inst.sg:GoToState("landing", { vertical = false })
				end
			end),
		},

		events =
		{
			EventHandler("hitboxtriggered", OnThrownHitBoxTriggered),
		},
	}),

	State({
		name = "spiked",
		tags = { },

		onenter = function(inst, attackdata)
			-- First, see if this should be flying downward at an angle.
			-- This happens when the player hits it with the bicycle kick attack at a certain height.
			local pos = inst:GetPosition()
			local attack = attackdata.attack
			local attacker
			if attack ~= nil then
				attacker = attack:GetAttacker()
				if attacker ~= nil and attacker.sg ~= nil then
					if attacker.sg.statemem.angledown and pos.y > SPIKED_ANGLEDOWN_HEIGHT_THRESHOLD then
						inst.sg.statemem.angledown = true
						inst.sg.statemem.gravity = -0.0002 -- when spiked + gravity kicks in, reach the ground sooner
					end
				end
			end

			--sound
			local params = {}
			params.fmodevent = fmodtable.Event.Shotput_spiked
			params.sound_max_count = 1
			params.stopatexitstate = true
			inst.sg.mem.spike_sound = soundutil.PlaySoundData(inst, params)
			
			-- Play the right animation, based on whether we're angled or not.
			inst.AnimState:PlayAnimation(inst.sg.statemem.angledown and "air_spiked_angled_3" or "air_spiked_3", true)
			MatchAnimToFacing(inst)

			combatutil.StartProjectileAttack(inst)

			inst.sg.statemem.spikedanimloopcounter = 4 -- play '3' anim twice
			inst.sg.statemem.spiked = true
			inst.sg.statemem.forceland = false

			inst.components.complexprojectile.onhitfn = ComplexProjectileHitFnCancel
			inst.components.complexprojectile:Hit()

			inst.sg.statemem.minheight = attackdata.minheight or 1
			inst.sg.statemem.maxheight = attackdata.maxheight or 2

			-- Set up spikedust particle emitter
			inst.components.shotputeffects:CreateSpikeDust()

			local dir
			if attack ~= nil then
				dir = attack:GetDir()
				if dir == nil then
					-- The attack doesn't have a Dir set (for example, a bomb), so use the relative angle between the two things
					local x,z = inst.Transform:GetWorldXZ()
					dir = attacker:GetAngleToXZ(x, z)
				end
			else
				dir = inst:GetAngleTo(inst.owner)
				if math.abs(dir) >= 90 then
					dir = 180
				else
					dir = 0
				end
			end
			if dir >= 180 then
				inst.sg.mem.facing = FACING_LEFT
			else
				inst.sg.mem.facing = FACING_RIGHT
			end

			inst.Physics:StartPassingThroughObjects()
			inst.sg.statemem.velocity = (inst.sg.statemem.angledown and SPIKED_ANGLED_VELOCITY or SPIKED_VELOCITY) * (inst.sg.mem.facing == FACING_LEFT and -1 or 1)
			inst.Physics:SetMotorVel(inst.sg.statemem.velocity)

			inst.sg.mem.enemieshit = 0

			if inst.focusthrow then
				inst.components.shotputeffects:StartFocusParticles()
				SGCommon.Fns.BlinkAndFadeColor(inst, FOCUS_FLASH_DATA_SPIKED.color, FOCUS_FLASH_DATA_SPIKED.frames)

				-- only play the whooshy sound if it's a focus punch
				local name = "Hit_ball_tail"
				local params = {}
				params.soundevent = "Hit_ball_tail"
				params.sound_max_count = 1
				soundutil.PlaySoundData(inst, params, name, inst)

				inst.components.ghosttrail:Activate(GHOST_DATA_SPIKED)
			end

			-- Shotput melee attacks have restricted ranges within which we can start the spiked state. If those exist, snap the ball to those positions.
			local start_y = math.max(inst.sg.statemem.minheight or 1.5, pos.y)
			start_y = math.min(inst.sg.statemem.maxheight, start_y)
			inst.sg.statemem.starting_y = start_y
		end,

		onupdate = function(inst)
			UpdateHorizontalYPosition(inst)

			local pos = inst:GetPosition()
			-- Check if we've landed
			if pos.y <= 1 then
				inst.sg:GoToState("landing", { vertical = false, spiked = true })
			end

			local oob = CheckOutOfBounds(inst)
			if not oob then
				if inst.sg.mem.facing == FACING_LEFT then
					inst.components.hitbox:PushBeam(-.25, 0.25, 1.5, HitPriority.MOB_DEFAULT) -- TODO(jambell): start smaller, to prevent hitting adjacent enemies
				else
					inst.components.hitbox:PushBeam(-.25, .25, 1.5, HitPriority.MOB_DEFAULT)
				end
			end

			if inst.sg:GetAnimFramesInState() >= 7 then
				-- If we're past the apex of the rebound, then turn on the hitbox + update the landing marker
				inst.sg:AddStateTag("hittable")
				inst.sg:AddStateTag("catchable")
			end
		end,

		onexit = function(inst)
			inst.components.ghosttrail:Deactivate()
			inst.Physics:StopPassingThroughObjects()
			inst.position_last_frame = nil
			inst.components.shotputeffects:StopSpikeDust()
		end,

		timeline =
		{

			FrameEvent(20, function(inst)
				if inst.sg.statemem.forceland then
					inst.sg:GoToState("landing", { vertical = false, spiked = true })
				end
			end),
		},

		events =
		{
			EventHandler("attacked", function(inst, attackdata) OnAttacked(inst, attackdata) end),
			EventHandler("hitboxtriggered", OnThrownHitBoxTriggered),
			EventHandler("animover", function(inst)
				if inst.sg.statemem.spikedanimloopcounter <= 2 then
					inst.sg.statemem.gravitying = true
				end

				inst.sg.statemem.spikedanimloopcounter = math.max(1, inst.sg.statemem.spikedanimloopcounter - 1)
				inst.sg.statemem.spikedanimloopcounter = math.min(3, inst.sg.statemem.spikedanimloopcounter)

				inst.AnimState:PlayAnimation((inst.sg.statemem.angledown and "air_spiked_angled_" or "air_spiked_")..inst.sg.statemem.spikedanimloopcounter, true)
			end),
		},
	}),

	State({
		name = "rebound",
		tags = {  },

		onenter = function(inst, targetpos)
			inst.AnimState:PlayAnimation("air", true)

			--sound
			local params = {}
			params.fmodevent = fmodtable.Event.Shotput_rebound
			params.sound_max_count = 1
			params.stopatexitstate = true
			soundutil.PlaySoundData(inst, params)

			inst.Physics:SetEnabled(false)
			inst.HitBox:SetNonPhysicsRect(1.25) -- Make the ball's hurtbox bigger so that it's easier to hit

			if inst.focusthrow then
				--TODO(jambell): make move faster... somehow... complexprojectile is v confusing to me ahahah. changing horizontalspeed makes it fly so high
			end

			inst.focusthrow = true -- Focus Hit: any rebound hit is a focus hit
			inst.components.ghosttrail:Activate(GHOST_DATA_REBOUND)

			inst.components.shotputeffects:StartFocusParticles()

			SetupComplexProjectile(inst, targetpos)

			combatutil.StartProjectileAttack(inst)

		end,

		onupdate = function(inst)
			if inst.sg:GetAnimFramesInState() >= 15 then
				-- If we're past the apex of the rebound, then turn on the hitbox + update the landing marker
				inst.sg:AddStateTag("hittable")
				inst.components.hitbox:PushCircle(0, 0, 2, HitPriority.MOB_DEFAULT)
			end
		end,

		onexit = function(inst)
			inst.components.ghosttrail:Deactivate()

			inst.components.hitbox:SetUtilityHitbox(false)
			inst.HitBox:UsePhysicsShape()
			inst.Physics:SetEnabled(true)
			inst.position_last_frame = nil
		end,

		events =
		{
			EventHandler("hitboxtriggered", OnReboundHitBoxTriggered),
			EventHandler("attacked", function(inst, attackdata) OnAttacked(inst, attackdata) end),
		},
	}),

	State({
		name = "recalled_pre",
		tags = { "hittable" },

		onenter = function(inst, data)
			inst.AnimState:PlayAnimation("return_pre")
			inst.sg.statemem.recaller = data ~= nil and data.recaller or inst
			inst.sg.statemem.horizontal = data ~= nil and data.horizontal or false
		end,

		timeline =
		{
			FrameEvent(6, function(inst)
				SGCommon.Fns.PlayGroundImpact(inst, { impact_type = GroundImpactFXTypes.id.ParticleSystem, impact_size = GroundImpactFXSizes.id.Small })
			end),
		},

		events =
		{
			EventHandler("animover", function(inst) inst.sg:GoToState(inst.sg.statemem.horizontal and "spiked" or "recalled", inst.sg.statemem.recaller) end),
		},
	}),

	State({
		name = "recalled",
		tags = { "hittable" },

		onenter = function(inst, recaller)
			inst.AnimState:PlayAnimation("air", true)
			inst.Physics:SetEnabled(false)
			inst.HitBox:SetNonPhysicsRect(1.25) -- Make the ball's hurtbox bigger so that it's easier to hit

			local direction = inst:GetAngleTo(recaller)
			if math.abs(direction) > 90 then
				inst.sg.mem.facing = FACING_LEFT
			else
				inst.sg.mem.facing = FACING_RIGHT
			end

			local recaller_pos = recaller:GetPosition()
			local ball_pos = inst:GetPosition()

			inst.Transform:SetHeight(ball_pos.y + 1)

			local target_x
			local x_distance = math.abs(recaller_pos.x - ball_pos.x)
			if x_distance < RECALLED_MAX_DIST_X then
				target_x = inst.sg.mem.facing == FACING_LEFT and ball_pos.x - x_distance or ball_pos.x + x_distance
			else
				target_x = inst.sg.mem.facing == FACING_LEFT and ball_pos.x - RECALLED_MAX_DIST_X or ball_pos.x + RECALLED_MAX_DIST_X
			end

			local target_z
			local z_distance = math.abs(recaller_pos.z - ball_pos.z)
			local above = ball_pos.z < recaller_pos.z
			if z_distance < RECALLED_MAX_DIST_Z then
				target_z = above and ball_pos.z + z_distance or ball_pos.z - z_distance
			else
				target_z = above and ball_pos.z + RECALLED_MAX_DIST_Z or ball_pos.z - RECALLED_MAX_DIST_Z
			end

			-- Find where I should land
			local targetpos = Vector3(target_x, 0, target_z)

			SetupComplexProjectile(inst, targetpos)

			combatutil.StartProjectileAttack(inst)
		end,

		onupdate = function(inst)
			if inst.sg:GetAnimFramesInState() >= 10 then
				-- If we're within 6 units from the ground, on the back end of the arc, be able to hit!
				inst.components.hitbox:PushCircle(0, 0, 2, HitPriority.MOB_DEFAULT)
			end
		end,

		onexit = function(inst)
			inst.components.hitbox:SetUtilityHitbox(false)
			inst.Physics:SetEnabled(true)
			inst.HitBox:UsePhysicsShape()
		end,

		events =
		{
			EventHandler("hitboxtriggered", OnRecalledHitBoxTriggered),
			EventHandler("attacked", function(inst, attackdata) OnAttacked(inst, attackdata) end),
		},
	}),

	-- Alternate 'recall' state, where the ball flies horizontally like a throw instead of upward like a rebound.
	State({
		name = "summoned",
		tags = { },

		onenter = function(inst, summoner)
			local direction = inst:GetAngleTo(summoner)
			if math.abs(direction) > 90 then
				inst.sg.mem.facing = FACING_LEFT
			else
				inst.sg.mem.facing = FACING_RIGHT
			end

			inst.AnimState:PlayAnimation("air_fast", true)
			inst.sg.mem.enemieshit = 0
			inst.sg:AddStateTag("catchable")
			combatutil.StartProjectileAttack(inst)

			MatchAnimToFacing(inst)

			-- Physics
			inst.Physics:StartPassingThroughObjects()
			inst.sg.statemem.starting_y = 0.25
			inst.Transform:SetHeight(inst.sg.statemem.starting_y)

			SGCommon.Fns.BlinkAndFadeColor(inst, FOCUS_FLASH_DATA_THROWN.color, FOCUS_FLASH_DATA_THROWN.frames)


			inst.sg.statemem.velocity = SUMMONED_VELOCITY * (inst.sg.mem.facing == FACING_LEFT and -1 or 1)
		end,

		onupdate = function(inst)
			UpdateHorizontalYPosition(inst)

			local oob = CheckOutOfBounds(inst)
			if not oob then
				if inst.sg:GetAnimFramesInState() > 0 then
					local facingmult = inst.sg.mem.facing == FACING_LEFT and -1 or 1
					inst.components.hitbox:PushBeam(.75 * facingmult, -.25 * facingmult, 1.5, HitPriority.MOB_DEFAULT)
				else
					inst.components.hitbox:PushBeam(-.25, .25, 1.5, HitPriority.MOB_DEFAULT)
				end
			end
		end,

		onexit = function(inst)
			inst.Physics:StopPassingThroughObjects()
		end,

		timeline =
		{
			FrameEvent(0, function(inst) inst.Physics:SetMotorVel(inst.sg.statemem.velocity) end),
			FrameEvent(20, function(inst) inst.sg:GoToState("landing", { vertical = false }) end),
		},

		events =
		{
			EventHandler("hitboxtriggered", OnRecalledHitBoxTriggered),
		},
	}),

	State({
		name = "lobbed",
		tags = { "hittable" },

		onenter = function(inst)
			inst.AnimState:PlayAnimation("air", true)

			inst.sg.mem.enemieshit = 0
			inst.sg.mem.canland = true

			--sound
			local params = {}
			params.fmodevent = fmodtable.Event.Shotput_lobbed
			params.sound_max_count = 1
			params.stopatexitstate = true
			soundutil.PlaySoundData(inst, params)

			inst.Physics:SetEnabled(false)
			local targetpos = FindLobTarget(inst)
			SetupComplexProjectile(inst, targetpos)

			if inst.focusthrow then
				inst.components.shotputeffects:StartFocusParticles()
			end

			inst.sg:AddStateTag("catchable")

			combatutil.StartProjectileAttack(inst)

		end,

		onupdate = function(inst)
			if inst.sg:GetAnimFramesInState() > 10 then
				-- If we're within 6 units from the ground, on the back end of the arc, be able to hit!
				inst.components.hitbox:PushCircle(0, 0, 2, HitPriority.MOB_DEFAULT)
			end
		end,

		onexit = function(inst)
			inst.components.hitbox:SetUtilityHitbox(false)
			inst.Physics:SetEnabled(true)
		end,

		events =
		{
			EventHandler("hitboxtriggered", OnReboundHitBoxTriggered),
		},
	}),

	State({
		name = "landing",
		tags = { "hittable", "recallable" },

		onenter = function(inst, data)
			inst.sg.statemem.vertical = data.vertical
			inst.sg.statemem.spiked = data.spiked
			local anim = "land_horizontal"
			if data.vertical then
				anim = "land_vertical"
			end
			inst.AnimState:PlayAnimation(anim)


			inst.components.ghosttrail:Deactivate()
			inst.focusthrow = false
			inst.components.shotputeffects:StopFocusParticles()

			if inst.sg.statemem.vertical then
				inst.Physics:Stop()
			end

			inst.Transform:SetHeight(0)

			inst.components.hitbox:SetUtilityHitbox(true)
		end,

		onupdate = function(inst)
			if not inst.sg.statemem.vertical then
				local facingmult = inst.sg.mem.facing == FACING_LEFT and -1 or 1
				inst.components.hitbox:PushBeam(.75 * facingmult, -.25 * facingmult, 1.5, HitPriority.MOB_DEFAULT)
			end

			CheckOutOfBounds(inst)
		end,

		onexit = function(inst)
			inst.components.hitbox:SetUtilityHitbox(false)
		end,

		timeline =
		{
			FrameEvent(0, function(inst)
				SGCommon.Fns.PlayGroundImpact(inst, { impact_type = GroundImpactFXTypes.id.ParticleSystem, impact_size = GroundImpactFXSizes.id.Small })
				if not inst.sg.statemem.vertical then
					local speed = inst.sg.statemem.spiked and 10 or 4
					speed = speed * (inst.sg.mem.facing == FACING_RIGHT and 1 or -1)

					local random_addition = math.random(-1,1) -- a little bit of extra speed to offset two balls that were going to otherwise land at the exact same spot
					inst.Physics:SetMotorVel(speed + random_addition)
				end
			end),
			FrameEvent(0, function(inst)
				local foleysounder = inst.components.foleysounder
				local tile_param_index = foleysounder:GetSurfaceAsParameter()
				local params = {}
				params.fmodevent = fmodtable.Event.Shotput_land
				params.sound_max_count = 1
				local handle = soundutil.PlaySoundData(inst, params)
				inst.SoundEmitter:SetParameter(handle, "tile_surface", tile_param_index)
				if inst.sg.mem.spike_sound then
					soundutil.KillSound(inst, inst.sg.mem.spike_sound)
					inst.sg.mem.spike_sound = nil
				end

			end),
			FrameEvent(8, function(inst)
				if not inst.sg.statemem.vertical then
					if inst.sg.statemem.spiked then
						inst.sg:GoToState("landing", { vertical = false, spiked = false })
					end
					inst.Physics:SetMotorVel(2 * (inst.sg.mem.facing == FACING_RIGHT and 1 or -1))
				end
			end),
			FrameEvent(10, function(inst)
				if not inst.sg.statemem.vertical then
					inst.Physics:Stop()
				end
			end),
		},

		events =
		{
			EventHandler("animover", function(inst)
				if inst.sg.statemem.spiked then
				else
					inst.sg:GoToState("grounded")
				end
			end),
			EventHandler("attacked", function(inst, attackdata) OnAttacked(inst, attackdata) end),
			EventHandler("hitboxtriggered", OnThrownHitBoxTriggered),
		},
	}),

	State({
		name = "grounded",
		tags = { "hittable", "recallable" },

		onenter = function(inst)
			combatutil.EndProjectileAttack(inst)
			inst.AnimState:PlayAnimation("ground", true)
			inst.components.hitbox:SetUtilityHitbox(true)
			inst.focusthrow = false
			if inst.Physics then -- on construction physics doesn't yet exist
				inst.Physics:SetEnabled(true)
			end
			inst.Transform:SetHeight(0)
		end,

		onexit = function(inst)
			inst.components.hitbox:SetUtilityHitbox(false)
		end,

		events =
		{
			EventHandler("attacked", function(inst, attackdata) OnAttacked(inst, attackdata) end)
		},
	}),

	State({
		name = "hit",
		tags = { },

		onenter = function(inst, data)
			local vertical = data.vertical
			local anim = vertical and "hit_vertical" or "hit"
			inst.AnimState:PlayAnimation(data.spiked and "hit_spiked" or anim)

			if inst.sg.mem.facing == FACING_LEFT then
				inst.sg.mem.facing = 2.0 -- wtf? why does setting this to FACING_RIGHT make it 2 instead of 2.0?
			else
				inst.sg.mem.facing = 0.0 -- wtf? why does setting this to FACING_LEFT make it 0 instead of 0.0?
			end

			MatchAnimToFacing(inst)

			combatutil.EndProjectileAttack(inst)
			inst.sg.statemem.reboundtarget = data.reboundtarget
			inst.Physics:SetEnabled(false)
		end,

		events =
		{
			EventHandler("animover", function(inst)
				if not inst:IsInLimbo() then 
					inst.sg:GoToState("rebound", inst.sg.statemem.reboundtarget)
				end
			end),
		},
	}),
}

local fns =
{
	CanTakeControl = function(sg)
		return not sg.inst:HasTag("no_state_transition")
	end,

	OnResumeFromRemote = function(sg)
		sg:GoToState("grounded") -- Just default to the grounded state, as normally the reason for the takeover will set it to a different state anyway
	end,
}

SGRegistry:AddData("sg_player_shotput_projectile", states)

return StateGraph("sg_player_shotput_projectile", states, events, "grounded", fns)
