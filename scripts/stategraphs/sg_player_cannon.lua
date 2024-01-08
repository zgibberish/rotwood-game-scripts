--[[
Ideas/Notes:
- think about whether the kickback can actually be described as a "Dodge" -- and proc "Dodge" powers??

short-term TODO:
- work on visualizing focus-clip mechanic
]]

local SGCommon = require "stategraphs.sg_common"
local SGPlayerCommon = require "stategraphs.sg_player_common"
local fmodtable = require "defs.sound.fmodtable"
local combatutil = require "util.combatutil"
local soundutil = require "util.soundutil"
local krandom = require "util.krandom"
local ParticleSystemHelper = require "util.particlesystemhelper"
local Weight = require "components/weight"

local ATTACKS =
{
	SINGLE =
	{
		DAMAGE = 0.75,
		DAMAGE_FOCUS = 1.5,
		HITSTUN = 3,
		HITSTUN_FOCUS = 5,
		PUSHBACK = 0,
		PUSHBACK_FOCUS = 0,
		SPEED = 18,
		SPEED_FOCUS = 20,
		RANGE = 20,
		RANGE_FOCUS = 20,
	},

	BLAST =
	{
		DAMAGE = 0.25, --PROPOSED TUNING: 0.25
		DAMAGE_FOCUS = 0.75, --PROPOSED TUNING: 0.5 or 0.75
		HITSTUN = 10,
		HITSTUN_FOCUS = 15,
		PUSHBACK = 0.75,
		PUSHBACK_FOCUS = 1,
		SPEED = 22,
		SPEED_FOCUS = 24,
		RANGE = 10,
		RANGE_FOCUS = 10,
	},

	QUICKRISE =
	{
		DAMAGE = 0.75,
		DAMAGE_FOCUS = 1.5,
		HITSTUN = 1,
		HITSTUN_FOCUS = 15,
		PUSHBACK = 1,
		PUSHBACK_FOCUS = 2,
		HITSTOP = HitStopLevel.MEDIUM, -- Some hitstop is already applied by the move itself, this is additional hitstop
		RADIUS = 3,
	},

	MORTAR =
	{
		DAMAGE = 2, -- 12 total for full 6-ammo shot
		DAMAGE_FOCUS = 3, -- 9 total for full 3-ammo shot
		HITSTUN = 10,
		HITSTUN_FOCUS = 15,
		PUSHBACK = 1,
		PUSHBACK_FOCUS = 2,
		HITSTOP = HitStopLevel.HEAVY,
		RADIUS = 2,
		RADIUS_FOCUS = 3,
	},

	SHOCKWAVE_WEAK =
	{
		DAMAGE = 2,
		DAMAGE_FOCUS = 3,
		HITSTUN = 8,
		HITSTUN_FOCUS = 10,
		PUSHBACK = 1,
		PUSHBACK_FOCUS = 1.5,
		HITSTOP = HitStopLevel.MEDIUM,
		RADIUS = 3,
		KNOCKDOWN = false,
		SELF_DAMAGE = 0,
		SELF_HIT_FX_X_OFFSET = 0.5,
		SELF_HIT_FX_Y_OFFSET = 2.5,
	},

	SHOCKWAVE_MEDIUM =
	{
		DAMAGE = 3,
		DAMAGE_FOCUS = 4,
		HITSTUN = 10,
		HITSTUN_FOCUS = 12,
		PUSHBACK = 1.5,
		PUSHBACK_FOCUS = 2,
		HITSTOP = HitStopLevel.MEDIUM,
		RADIUS = 3.5,
		KNOCKDOWN = false,
		SELF_DAMAGE = 0,
		SELF_HIT_FX_X_OFFSET = 0.5,
		SELF_HIT_FX_Y_OFFSET = 2.5,
	},

	SHOCKWAVE_STRONG =
	{
		-- This attack cannot be FOCUS. Only shots with remaining ammo 3,2,1 are focus. Leaving tuning in case something weird happens.
		DAMAGE = 5,
		SELF_DAMAGE = 30,
		DAMAGE_FOCUS = 6,
		HITSTUN = 15,
		HITSTUN_FOCUS = 15,
		PUSHBACK = 2,
		PUSHBACK_FOCUS = 3,
		HITSTOP = HitStopLevel.HEAVY,
		RADIUS = 5,
		KNOCKDOWN = true,
		KNOCKDOWN_RADIUS = 0.95, -- What percentage of "Radius" above should create a KNOCKDOWN, instead of just a knockback?
		SELF_HIT_FX_X_OFFSET = 0.5,
		SELF_HIT_FX_Y_OFFSET = 2.5,
	},

	BACKFIRE_WEAK =
	{
		DAMAGE = 0.5,
		DAMAGE_FOCUS = .75,
		HITSTUN = 4,
		HITSTUN_FOCUS = 4,
		PUSHBACK = 0.5,
		PUSHBACK_FOCUS = 1,
		HITSTOP = HitStopLevel.NONE,

		KNOCK = "KNOCKBACK",

		SELF_DAMAGE = 0,
		SELF_HIT_FX_X_OFFSET = -2,
		SELF_HIT_FX_Y_OFFSET = 1,
	},

	BACKFIRE_MEDIUM_EARLY =
	{
		-- This attack is for the first, initial blast of the backfire attack. The slower part towards the end is BACKFIRE_MEDIUM_LATE
		DAMAGE = 3,
		DAMAGE_FOCUS = 4,
		HITSTUN = 10,
		HITSTUN_FOCUS = 10,
		PUSHBACK = 2,
		PUSHBACK_FOCUS = 2,
		HITSTOP = HitStopLevel.NONE,

		KNOCK = "KNOCKDOWN",

		SELF_DAMAGE = 0,
		SELF_HIT_FX_X_OFFSET = -2,
		SELF_HIT_FX_Y_OFFSET = 1,
	},

	BACKFIRE_MEDIUM_LATE =
	{
		-- Just the slowdown of BACKFIRE_MEDIUM
		DAMAGE = 4,
		DAMAGE_FOCUS = 5,
		HITSTUN = 1,
		HITSTUN_FOCUS = 1,
		PUSHBACK = 0.5,
		PUSHBACK_FOCUS = 1,
		HITSTOP = HitStopLevel.NONE,

		KNOCK = "KNOCKBACK",

		SELF_DAMAGE = 0,
		SELF_HIT_FX_X_OFFSET = -2,
		SELF_HIT_FX_Y_OFFSET = 1,
	},

	BACKFIRE_STRONG_EARLY =
	{
		-- This attack is for the first, initial blast of the backfire attack. The body landing on the ground is "BACKFIRE_STRONG_LATE"
		-- This attack cannot be FOCUS. Only shots with remaining ammo 3,2,1 are focus. Leaving tuning in case something weird happens.
		DAMAGE = 4,
		DAMAGE_FOCUS = 5,
		HITSTUN = 10,
		HITSTUN_FOCUS = 10,
		PUSHBACK = 2,
		PUSHBACK_FOCUS = 2,
		HITSTOP = HitStopLevel.HEAVY,

		KNOCK = "KNOCKDOWN",

		SELF_DAMAGE = 0,
		SELF_HIT_FX_X_OFFSET = -2,
		SELF_HIT_FX_Y_OFFSET = 1,
	},

	BACKFIRE_STRONG_LATE =
	{
		-- This attack is for the player's body landing on the ground. Don't push back very much, and don't do much hitstun. If they are landing in danger, they should not have frame advantage.
		-- This attack cannot be FOCUS. Only shots with remaining ammo 3,2,1 are focus. Leaving tuning in case something weird happens.
		DAMAGE = 1,
		DAMAGE_FOCUS = 2,
		HITSTUN = 1,
		HITSTUN_FOCUS = 1,
		PUSHBACK = 0.5,
		PUSHBACK_FOCUS = 0.5,
		HITSTOP = HitStopLevel.LIGHT,

		KNOCK = "KNOCKBACK",

		SELF_DAMAGE = 30,
		SELF_HIT_FX_X_OFFSET = -2,
		SELF_HIT_FX_Y_OFFSET = 1,
	},
}

local WEIGHT_TO_DODGE_MULTIPLIER =
{
	[Weight.Status.s.Normal] = 1,
	[Weight.Status.s.Light] = 1.5,
	[Weight.Status.s.Heavy] = 0.3, -- Keeps Heavy player up close, very offensive. They can do multiple shotgun blasts against the same enemy.
}
local WEIGHT_TO_BACKFIRE_MULTIPLIER =
{
	-- This is such a strong movement that we should be more specific about it. Using the values above affect the move so severely.
	[Weight.Status.s.Normal] = 1,
	[Weight.Status.s.Light] = 1.25,
	[Weight.Status.s.Heavy] = 0.75,
}

-- MORTAR PARAMETERS:
local MORTAR_AIM_START_DISTANCE = 7 -- How far away from the player does the mortar aim indicator start?
local MORTAR_SHOOT_HITSTOP =
{
	WEAK = HitStopLevel.LIGHT,
	MEDIUM = HitStopLevel.MEDIUM,
	STRONG = HitStopLevel.MEDIUM,
}
local MORTAR_SHOOT_BLOWBACK = -- How much is the player blown back when doing a weak, medium, or strong mortar blast?
{
	WEAK = 0,
	MEDIUM = 4,
	STRONG = 10,
}

local MORTAR_AIM_RETICLE_SPEED = 0.1
local MORTAR_AIM_OFFSET =
{
	-- When shooting multiple projectiles in a mortar, what positioning should they have?
	{ x =  0,  z = 0  },
	{ x =  -2,  z = 0.5  },
	{ x =  2,  z = 0.5  },
	{ x =  -1,  z = -2  },
	{ x =  1,  z = -2  },
	{ x =  0,  z = 2  },
}

local MORTAR_SHOOT_TIMING =
{
	-- When firing a mortar, how many frames should a given bullet be delayed, so they don't shoot all at once??
	0,
	0,
	2,
	2,
	4,
	4,
}

-- We randomly scale each mortar's anim to create offsets/visual variation. What's the min/max?
local MORTAR_RANDOM_SCALE_MIN = 0.7
local MORTAR_RANDOM_SCALE_MAX = 1.0

-- We randomly scale the speed of each mortar's anim to rotate at different speeds. The animation speed is the rotation speed. What's the min/max?
local MORTAR_RANDOM_ROTATESPEED_MIN = 0.5
local MORTAR_RANDOM_ROTATESPEED_MAX = 1.5

-- Backfire Parameters:
local BACKFIRE_VELOCITY =
{
	WEAK = -28,
	MEDIUM = -34,
	STRONG = -34,
}

local FOCUS_SEQUENCE =
{
	-- Of a given clip, which shots are FOCUS shots and which are NORMAL shots?
	[1] = true,
	[2] = true,
	[3] = true,
	[4] = false,
	[5] = false,
	[6] = false,
}
local MORTAR_FOCUS_THRESHOLD = 3 -- Equal to and below this much ammo, a mortar becomes focus shots. Match the values in FOCUS_SEQUENCE for best clarity ^

local BLAST_RECOIL_FRAME_TO_SPEEDMULT =
{
	-- Doing it this way so that I can count how many frames we've been sliding across multiple possible states.
	-- These are SetMotorVel()s done in update of any state that is said to be "dodging"
	-- For example, if I BLAST backwards, and cancel into a SHOT or a PLANT -- maintain this tightly tuned velocity the whole way through.
	-- cannon_H_atk
	[1] = 1.75,
	[4] = 1,
	[8] = 1,
	-- cannon_H_land
	[9] = 0.5,
	[10] = 0.45,
	[11] = 0.4 ,
	[12] = 0.35,
	[13] = 0.3,
	[14] = 0.15,
	[15] = 0,
	[16] = 0,
}

-- AMMO MANAGEMENT
local function UpdateAmmoSymbols(inst)
	-- if inst.sg.mem.ammo > 0 then
	-- 	inst.AnimState:ShowSymbol("weapon_back01")
	-- 	inst.AnimState:ShowLayer("ARMED")
	-- 	inst.AnimState:HideLayer("UNARMED")
	-- else
	-- 	inst.AnimState:HideSymbol("weapon_back01")
	-- 	inst.AnimState:HideLayer("ARMED")
	-- 	inst.AnimState:ShowLayer("UNARMED")
	-- end
end

local function GetMaxAmmo(inst)
	return inst.sg.mem.ammo_max
end

local function GetMissingAmmo(inst)
	return inst.sg.mem.ammo_max - inst.sg.mem.ammo
end

local function GetRemainingAmmo(inst)
	return inst.sg.mem.ammo
end

local function UpdateAmmo(inst, amount)
	inst.sg.mem.ammo = math.max(inst.sg.mem.ammo - amount, 0)
	UpdateAmmoSymbols(inst)
end

local function OnReload(inst, amount)
	inst.sg.mem.ammo = math.min(inst.sg.mem.ammo + amount, inst.sg.mem.ammo_max)
	UpdateAmmoSymbols(inst)
end

local function GetWeightVelocityMult(inst)
	local weight = inst.components.weight:GetStatus()
	local weightmult = WEIGHT_TO_DODGE_MULTIPLIER[weight]

	return weightmult
end

local function GetBackfireWeightVelocityMult(inst)
	local weight = inst.components.weight:GetStatus()
	local weightmult = WEIGHT_TO_BACKFIRE_MULTIPLIER[weight]

	return weightmult
	end

local function PlayMortarSound(inst, cannonAmmo, cannonMortarStrength, isFocusAttack)
	soundutil.PlaySoundWithParams(inst, fmodtable.Event.Cannon_mortar_launch_fire_scatterer, { cannonAmmo = cannonAmmo, cannonMortarStrength = cannonMortarStrength, isFocusAttack = isFocusAttack })
end

local function PlayMortarTubeSound(inst, cannonMortarStrength, isFocusAttack)
	local params = {}
	params.fmodevent = fmodtable.Event.Cannon_mortar_launch_tube
	params.sound_max_count = 1
	local handle = soundutil.PlaySoundData(inst, params)
	soundutil.SetInstanceParameter(inst, handle, "cannonMortarStrength", cannonMortarStrength)
	soundutil.SetInstanceParameter(inst, handle, "isFocusAttack", isFocusAttack)
end

--

local function CreateMortarAimReticles(inst)
	if inst.sg.mem.aim_reticles ~= nil then
		for reticle,aim_data in pairs(inst.sg.mem.aim_reticles) do
			if reticle ~= nil and reticle:IsValid() then
				reticle:Remove()
			end
		end
	end
	inst.sg.mem.aim_reticles = {}

	-- Get some global information about inst's position and direction
	local x, z = inst.Transform:GetWorldXZ()
	local facingright = inst.Transform:GetFacing() == FACING_RIGHT
	local start_offset = facingright and MORTAR_AIM_START_DISTANCE or -MORTAR_AIM_START_DISTANCE

	-- Set up the root aim distance, so we're not relying on FX position and existence for calculating the distance
	inst.sg.mem.aim_root_x = x + start_offset
	inst.sg.mem.aim_root_z = z
	inst.sg.mem.aim_root_speed = facingright and MORTAR_AIM_RETICLE_SPEED or -MORTAR_AIM_RETICLE_SPEED

	-- For every bullet we are about to shoot, create an aim indicator
	local bullets = GetRemainingAmmo(inst)
	for i=1,bullets do
		local circle = SpawnPrefab("fx_ground_target_player", inst)
		circle.Transform:SetScale(0.75, 0.75, 0.75)

		local aim_offset = MORTAR_AIM_OFFSET[i]
		local offsetmult = facingright and -1 or 1

		local aim_data =
		{
			aim_x = x + start_offset + aim_offset.x * offsetmult,
			aim_z = z + aim_offset.z,
			aim_speed = facingright and MORTAR_AIM_RETICLE_SPEED or -MORTAR_AIM_RETICLE_SPEED,
		}
		inst.sg.mem.aim_reticles[circle] = aim_data

		circle.Transform:SetPosition(aim_data.aim_x, 0, aim_data.aim_z)
	end

	inst.sg.mem.update_aim = true

end

local function UpdateMortarAimReticles(inst)
	for circle,aim_data in pairs(inst.sg.mem.aim_reticles) do
		aim_data.aim_x = aim_data.aim_x + aim_data.aim_speed
		circle.Transform:SetPosition(aim_data.aim_x, 0, aim_data.aim_z)
	end
	inst.sg.mem.aim_root_x = inst.sg.mem.aim_root_x + inst.sg.mem.aim_root_speed
end

local function DestroyMortarAimReticles(inst)
	if inst ~= nil and inst.sg.mem.aim_reticles ~= nil then
		for reticle,aim_data in pairs(inst.sg.mem.aim_reticles) do
			if reticle ~= nil and reticle:IsValid() then
				reticle:Remove()
			end
		end
	end
end

local function ConfigureNewDodge(inst)
	--[[
		In order to actually start the dodge, make sure that:
			- state has DoDodgeMovement() in onupdate()
			- call StartNewDodge() on the frame you want the movement to begin
			- probably add a Kickback() function, like DoKickback or DoBlastKickback
	]]
	local weightmult = GetWeightVelocityMult(inst)
	local locomotorspeedmult = inst.components.locomotor.total_speed_mult * 0.75 --(TODO)jambell: use the common dodge func

	inst.sg.statemem.maxspeed = -TUNING.GEAR.WEAPONS.CANNON.ROLL_VELOCITY * locomotorspeedmult * weightmult
	inst.sg.statemem.framessliding = 0
end
local function StartNewDodge(inst)
	inst.sg.statemem.speed = inst.sg.statemem.maxspeed
end
local function CheckIfDodging(inst, data)
	if data ~= nil then
		inst.sg.statemem.maxspeed = data.maxspeed
		inst.sg.statemem.speed = data.speed
		inst.sg.statemem.framessliding = data.framessliding

		if inst.sg.statemem.framessliding ~= nil and inst.sg.statemem.framessliding <= TUNING.PLAYER.ROLL.NORMAL.IFRAMES then -- TODO #weight @jambell make work for different weights
			inst.HitBox:SetInvincible(true)
		end
	else
		-- jambell: Trying to fix a crash I can't repro... we didn't get data here, so just set maxspeed to 0.
		-- Elsewhere, if we received maxspeed = 0 then print some logging to help identify why
		inst.sg.statemem.maxspeed = 0
		inst.sg.statemem.speed = 0
		inst.Physics:Stop()
	end
end
local function DoDodgeMovement(inst)
	if not inst.sg.statemem.pausedodgemovement then
		if inst.sg.statemem.speed ~= nil and inst.sg.statemem.framessliding ~= nil then
			-- print("--------")
			-- print(inst.sg:GetCurrentState()..": "..inst.sg:GetTicksInState())
			-- print("inst.sg.statemem.speed", inst.sg.statemem.speed, "inst.sg.statemem.framessliding", inst.sg.statemem.framessliding)
			inst.sg.statemem.framessliding = inst.sg.statemem.framessliding + 0.5 -- a tick is 0.5 a 'frame'
			if BLAST_RECOIL_FRAME_TO_SPEEDMULT[inst.sg.statemem.framessliding] ~= nil then
				inst.sg.statemem.speed = inst.sg.statemem.maxspeed * BLAST_RECOIL_FRAME_TO_SPEEDMULT[inst.sg.statemem.framessliding]
			end

			inst.Physics:SetMotorVel(inst.sg.statemem.speed)
			if inst.sg.statemem.speed == 0 then
				inst.Physics:Stop()
				inst.sg.statemem.speed = nil
			end
		end

		-- JAMBELL: BUG... this keeps invincible for way longer because air-to-air cancel states set framessliding back down to 0.
		-- Either do that movement boost in a different way OR track iframes individually
		if inst.sg.statemem.framessliding ~= nil and inst.sg.statemem.framessliding > TUNING.PLAYER.ROLL.NORMAL.IFRAMES then -- TODO #weight @jambell make work for different weights
			inst.HitBox:SetInvincible(false)
		else
			-- print("Invincible this frame:", inst.sg.statemem.framessliding)
		end
	end
end

local function DoAirShootMovement(inst)
	if not inst.sg.statemem.pausedodgemovement then
		if inst.sg.statemem.maxspeed == 0 then
			-- HACK: hopefully temporary bandaid to fix a crash when 'transitiondata' became nil at some point.
			local laststatename = inst.sg.laststate ~= nil and inst.sg.laststate.name
			print("WARNING: [Cannon] DoAirShootMovement has received inst.sg.statemem.maxspeed of 0. Configuring new dodge.", inst.sg:GetTicksInState(), laststatename ~= nil and laststatename)
			ConfigureNewDodge(inst)
		end
		inst.sg.statemem.framessliding = 8
		inst.sg.statemem.speed = inst.sg.statemem.maxspeed * BLAST_RECOIL_FRAME_TO_SPEEDMULT[inst.sg.statemem.framessliding]
	end
end

-- KICKBACK FUNCTIONS:
-- Moving the player back, sharply, when an attack is executed.
local function DoShootKickback(inst)
	inst.Physics:MoveRelFacing(-25 / 150)
end

local function DoBlastKickback(inst)
	inst.Physics:MoveRelFacing(-125 / 150)
end

local function DoAirBlastKickback(inst)
	inst.Physics:MoveRelFacing(-250 / 150)
end

local function DoQuickRiseKickback(inst)
	inst.Physics:MoveRelFacing(-150 / 150)
end

local function DoMortarWeakKickback(inst)
	inst.Physics:MoveRelFacing(-25 / 150)
end

local function DoMortarMediumKickback(inst)
	inst.Physics:MoveRelFacing(-50 / 150)
end

local function DoMortarStrongKickback(inst)
	inst.Physics:MoveRelFacing(-150 / 150)
end

local function DoBackfireWeakKickback(inst)
	inst.Physics:MoveRelFacing(-75 / 150)
end

local function DoBackfireMediumKickback(inst)
	inst.Physics:MoveRelFacing(-150 / 150)
end

local function DoBackfireStrongKickback(inst)
	inst.Physics:MoveRelFacing(-250 / 150)
end
--

-- FUNCTIONS FOR DOING SHOTS
local function DoShoot(inst)
	-- First, initialize the attack
	local ATTACK =  ATTACKS.SINGLE

	local damagemod
	local hitstun
	local pushback
	local speed
	local range
	local projectileprefab

	-- If this is a focus attack, use FOCUS numbers. Otherwise, use default numbers.
	local focus = FOCUS_SEQUENCE[GetRemainingAmmo(inst)]
	if focus then
		damagemod = ATTACK.DAMAGE_FOCUS
		hitstun = ATTACK.HITSTUN_FOCUS
		pushback = ATTACK.PUSHBACK_FOCUS
		speed = ATTACK.SPEED_FOCUS
		range = ATTACK.RANGE_FOCUS
		projectileprefab = "player_cannon_focus_projectile"
	else
		damagemod = ATTACK.DAMAGE
		hitstun = ATTACK.HITSTUN
		pushback = ATTACK.PUSHBACK
		speed = ATTACK.SPEED
		range = ATTACK.RANGE
		projectileprefab = "player_cannon_projectile"
	end

	local params = {}
	params.fmodevent = fmodtable.Event.Cannon_shoot_light
	params.sound_max_count = 1
	local handle = soundutil.PlaySoundData(inst, params)
	soundutil.SetInstanceParameter(inst, handle, "isFocusAttack", focus and 1 or 0)
	soundutil.SetInstanceParameter(inst, handle, "cannonAmmo", GetRemainingAmmo(inst))

	-- kill travel sound
	if inst.sg.mem.bullet and inst.sg.mem.bullet.handle then
		soundutil.KillSound(inst.sg.mem.bullet, inst.sg.mem.bullet.handle)
		inst.sg.mem.bullet = nil
	end

	-- Create the bullet, set it up, and position it correctly based on which state we're in.
	-- Neutral shot will have one y value, while airborne shot will have a different y value.
	local bullet = SGCommon.Fns.SpawnAtDist(inst, projectileprefab, 2)
	inst.sg.mem.bullet = bullet
	bullet:Setup(inst, damagemod, hitstun, pushback, speed, range, focus, inst.sg.mem.attack_type, inst.sg.mem.attack_id, 1, 1)

	local bulletpos = bullet:GetPosition()
	local y_offset = inst.sg.statemem.projectile_y_offset ~= nil and inst.sg.statemem.projectile_y_offset or 1
	bullet.Transform:SetPosition(bulletpos.x, bulletpos.y + y_offset, bulletpos.z)

	-- Send an event for power purposes.
	inst:PushEvent("projectile_launched", { bullet })

	UpdateAmmo(inst, 1)
end

-- A blast shoots 5 bullets, and they should be delayed so they don't shoot in a boring pattern.
-- This pattern results in:
--[[
    o
o
  o
o
    o
]]
local delay_frames_per_blast_bullet =
{
	2,
	0,
	1,
	0,
	2,
}
-- Because the bullets come out at a different time, increase the range of the earlier shots so that they all die at the same time.
local extra_range_per_blast_bullet =
{
	0,
	1.25,
	1,
	1.25,
	0,
}

local function DoBlast(inst)
	-- First, initialize the attack
	inst:PushEvent("dodge")

	local ATTACK =  ATTACKS.BLAST

	local damagemod = ATTACK.DAMAGE
	local hitstun = ATTACK.HITSTUN
	local pushback = ATTACK.PUSHBACK
	local speed = ATTACK.SPEED
	local range = ATTACK.RANGE
	local projectileprefab = "player_cannon_shotgun_projectile"

	-- If this is a focus attack, use FOCUS numbers. Otherwise, use default numbers.
	-- local focus = FOCUS_SEQUENCE[GetRemainingAmmo(inst)] == "lightattack" and true or false
	local focus = FOCUS_SEQUENCE[GetRemainingAmmo(inst)]
	if focus then
		damagemod = ATTACK.DAMAGE_FOCUS
		hitstun = ATTACK.HITSTUN_FOCUS
		pushback = ATTACK.PUSHBACK_FOCUS
		speed = ATTACK.SPEED_FOCUS
		range = ATTACK.RANGE_FOCUS
		projectileprefab = "player_cannon_shotgun_focus_projectile"
	end

	-- Create 5 tiny bullets and spread them in a shotgun/spread pattern
	local numbullets = 5
	local bullets = {}
	for i=1,numbullets do
		local angle = -30 + (i * 10)
		local bullet = SGCommon.Fns.SpawnAtAngleDist(inst, projectileprefab, 2, angle)
		bullet:Hide()
		table.insert(bullets, bullet)

		inst:DoTaskInAnimFrames(delay_frames_per_blast_bullet[i], function()
			bullet:Show()
			bullet:Setup(inst, damagemod, hitstun, pushback, speed, range + extra_range_per_blast_bullet[i], focus, inst.sg.mem.attack_type, inst.sg.mem.attack_id, i, numbullets)

			local bulletpos = bullet:GetPosition()
			local y_offset = inst.sg.statemem.projectile_y_offset ~= nil and inst.sg.statemem.projectile_y_offset or 1.3
			bullet.Transform:SetPosition(bulletpos.x, bulletpos.y + y_offset, bulletpos.z)
		end)

	end

	inst:PushEvent("projectile_launched", bullets)
	UpdateAmmo(inst, 1)
end

local function DoMortar(inst, ammo)
	local facingright = inst.Transform:GetFacing() == FACING_RIGHT
	local num_bombs = ammo

	local ATTACK = ATTACKS.MORTAR

	local damagemod = ATTACK.DAMAGE
	local hitstun = ATTACK.HITSTUN
	local pushback = ATTACK.PUSHBACK
	local focus = ammo <= MORTAR_FOCUS_THRESHOLD
	local radius = ATTACK.RADIUS

	-- If this is a focus attack, use FOCUS numbers. Otherwise, use default numbers.
	if focus then
		damagemod = ATTACK.DAMAGE_FOCUS
		hitstun = ATTACK.HITSTUN_FOCUS
		pushback = ATTACK.PUSHBACK_FOCUS
		radius = ATTACK.RADIUS_FOCUS

	end

	-- Create 'num_bombs' mortars and arrange them in a star shape
	local bullets = {}
	for i = 1, num_bombs do
		local delay = MORTAR_SHOOT_TIMING[i]
		inst:DoTaskInAnimFrames(delay, function(inst)
			if inst ~= nil and inst:IsValid() then
				local bomb = SpawnPrefab("player_cannon_mortar_projectile", inst)

				-- Set the starting position of this mortar
				local offset = facingright and Vector3(1.5, 3, 0) or Vector3(-1.5, 3, 0) --inst.sg.statemem.right and Vector3(0, 0, 0) or Vector3(0, 0, 0)
				local x, z = inst.Transform:GetWorldXZ()
				bomb.Transform:SetPosition(x + offset.x, offset.y, z + offset.z)

				bomb:Setup(inst, damagemod, hitstun, radius, pushback, focus, "heavy_attack", inst.sg.mem.attack_id, i,
					num_bombs, num_bombs)
				-- Setup(inst, owner, damage_mod, hitstun_animframes, hitboxradius, pushback, focus, attacktype, numberinbatch, maxinbatch)

				-- Randomize the scale + rotation speed between a min/max for variance purposes
				local randomscale = krandom.Float(MORTAR_RANDOM_SCALE_MIN, MORTAR_RANDOM_SCALE_MAX)
				local randomrotationspeed = krandom.Float(MORTAR_RANDOM_ROTATESPEED_MIN, MORTAR_RANDOM_ROTATESPEED_MAX)
				bomb.AnimState:SetScale(randomscale, randomscale, randomscale)
				bomb.AnimState:SetDeltaTimeMultiplier(randomrotationspeed)

				-- Set up the target
				local aim_x = inst.sg.mem.aim_root_x or 1
				local aim_z = inst.sg.mem.aim_root_z or 1
				local aim_offset = MORTAR_AIM_OFFSET[i]
				local offsetmult = facingright and -1 or 1
				local target_pos = Vector3(aim_x + aim_offset.x * offsetmult, 0, aim_z + aim_offset.z)

				table.insert(bullets, bomb)
				bomb:PushEvent("thrown", target_pos)
			end
		end)
	end

	inst:PushEvent("projectile_launched", bullets)
end

local function OnQuickriseHitBoxTriggered(inst, data)
	local ATTACK_DATA = ATTACKS.QUICKRISE

	for i = 1, #data.targets do
		local v = data.targets[i]

		local focushit = FOCUS_SEQUENCE[GetRemainingAmmo(inst)]

		local hitstoplevel = focushit and ATTACK_DATA.HITSTOP_FOCUS or ATTACK_DATA.HITSTOP
		local damage_mod = focushit and ATTACK_DATA.DAMAGE_FOCUS or ATTACK_DATA.DAMAGE
		local pushback = focushit and ATTACK_DATA.PUSHBACK_FOCUS or ATTACK_DATA.PUSHBACK
		local hitstun = ATTACK_DATA.HITSTUN

		local dir = inst:GetAngleTo(v)

		local attack = Attack(inst, v)
		attack:SetDamageMod(damage_mod)
		attack:SetDir(dir)
		attack:SetHitstunAnimFrames(hitstun)
		attack:SetPushback(pushback)
		attack:SetFocus(focushit)
		attack:SetID(inst.sg.mem.attack_type)
		attack:SetNameID(inst.sg.mem.attack_id)

		local dist = inst:GetDistanceSqTo(v)
		dist = math.sqrt(dist)

		-- If really close to the center of the blast, do a knockdown. Otherwise, do a knockback.
		if dist <= ATTACK_DATA.RADIUS * 0.7 then
			inst.components.combat:DoKnockdownAttack(attack)
		else
			inst.components.combat:DoKnockbackAttack(attack)
		end

		hitstoplevel = SGCommon.Fns.ApplyHitstop(attack, hitstoplevel)

		local hitfx_x_offset = 0
		local hitfx_y_offset = 0

		inst.components.combat:SpawnHitFxForPlayerAttack(attack, "hits_player_cannon_shot", v, inst, hitfx_x_offset, hitfx_y_offset, dir, hitstoplevel)

		-- TODO(dbriscoe): Why do we only spawn if target didn't block? We unconditionally spawn in hammer. Maybe we should move this to SpawnHitFxForPlayerAttack
		if v.sg ~= nil and v.sg:HasStateTag("block") then
		else
			SpawnHurtFx(inst, v, hitfx_x_offset, dir, hitstoplevel)
		end
	end
end

local function OnShockwaveHitBoxTriggered(inst, data)
	assert(inst.sg.mem.attack_id == "SHOCKWAVE_WEAK" or inst.sg.mem.attack_id == "SHOCKWAVE_MEDIUM" or inst.sg.mem.attack_id == "SHOCKWAVE_STRONG", "Received wrong attack ID for shockwave attack.")
	local ATTACK_DATA = ATTACKS[inst.sg.mem.attack_id]

	for i = 1, #data.targets do
		local v = data.targets[i]

		local focushit = FOCUS_SEQUENCE[GetRemainingAmmo(inst)]

		local hitstoplevel = focushit and ATTACK_DATA.HITSTOP_FOCUS or ATTACK_DATA.HITSTOP
		local damage_mod = focushit and ATTACK_DATA.DAMAGE_FOCUS or ATTACK_DATA.DAMAGE
		local pushback = focushit and ATTACK_DATA.PUSHBACK_FOCUS or ATTACK_DATA.PUSHBACK
		local hitstun = ATTACK_DATA.HITSTUN

		local dir = inst:GetAngleTo(v)

		local attack = Attack(inst, v)
		attack:SetDamageMod(damage_mod)
		attack:SetDir(dir)
		attack:SetHitstunAnimFrames(hitstun)
		attack:SetPushback(pushback)
		attack:SetFocus(focushit)
		attack:SetID(inst.sg.mem.attack_type)
		attack:SetNameID(inst.sg.mem.attack_id)

		local dist = inst:GetDistanceSqTo(v)
		dist = math.sqrt(dist)

		-- If really close to the center of the blast, do a knockdown. Otherwise, do a knockback.
		if ATTACK_DATA.KNOCKDOWN and dist <= ATTACK_DATA.RADIUS * ATTACK_DATA.KNOCKDOWN_RADIUS then
			inst.components.combat:DoKnockdownAttack(attack)
		else
			inst.components.combat:DoKnockbackAttack(attack)
		end

		hitstoplevel = SGCommon.Fns.ApplyHitstop(attack, hitstoplevel)

		local hitfx_x_offset = 0
		local hitfx_y_offset = 0

		inst.components.combat:SpawnHitFxForPlayerAttack(attack, "hits_player_cannon_shot", v, inst, hitfx_x_offset, hitfx_y_offset, dir, hitstoplevel)

		-- TODO(dbriscoe): Why do we only spawn if target didn't block? We unconditionally spawn in hammer. Maybe we should move this to SpawnHitFxForPlayerAttack
		if v.sg ~= nil and v.sg:HasStateTag("block") then
		else
			SpawnHurtFx(inst, v, hitfx_x_offset, dir, hitstoplevel)
		end
	end
end

local function DoShockwaveSelfAttack(inst)
	if TheWorld:HasTag("town") then
		-- Don't self-damage in town
		return
	end

	assert(inst.sg.mem.attack_id == "SHOCKWAVE_WEAK" or inst.sg.mem.attack_id == "SHOCKWAVE_MEDIUM" or inst.sg.mem.attack_id == "SHOCKWAVE_STRONG", "Received wrong attack ID for shockwave attack.")
	local ATTACK_DATA = ATTACKS[inst.sg.mem.attack_id]

	if ATTACK_DATA.SELF_DAMAGE <= 0 then
		return
	end

	local focushit = FOCUS_SEQUENCE[GetRemainingAmmo(inst)]

	local hitstoplevel = focushit and ATTACK_DATA.HITSTOP_FOCUS or ATTACK_DATA.HITSTOP
	local pushback = focushit and ATTACK_DATA.PUSHBACK_FOCUS or ATTACK_DATA.PUSHBACK
	local hitstun = ATTACK_DATA.HITSTUN

	local dir = inst:GetAngleTo(inst)

	local attack = Attack(inst, inst)
	attack:SetOverrideDamage(ATTACK_DATA.SELF_DAMAGE)
	attack:SetHitstunAnimFrames(hitstun)
	attack:SetPushback(pushback)
	attack:SetFocus(focushit)
	attack:SetID(inst.sg.mem.attack_type)
	attack:SetNameID(inst.sg.mem.attack_id)

	inst.components.combat:DoBasicAttack(attack)
end

local function OnBackfireHitBoxTriggered(inst, data)
	-- This is for the first burst in the backfire strong, right after blasting.
	-- assert(inst.sg.mem.attack_id == "BACKFIRE_STRONG_EARLY" or inst.sg.mem.attack_id == "BACKFIRE_STRONG_LATE", "Received wrong attack ID for BACKFIRE attack. Maybe some timing issue?")
	local ATTACK_DATA = ATTACKS[inst.sg.mem.attack_id]

	if inst.sg.mem.backfire_sound then
		soundutil.KillSound(inst, inst.sg.mem.backfire_sound)
		inst.sg.mem.backfire_sound = nil
	end

	for i = 1, #data.targets do
		local v = data.targets[i]

		local focushit = FOCUS_SEQUENCE[GetRemainingAmmo(inst)]

		local hitstoplevel = focushit and ATTACK_DATA.HITSTOP_FOCUS or ATTACK_DATA.HITSTOP
		local damage_mod = focushit and ATTACK_DATA.DAMAGE_FOCUS or ATTACK_DATA.DAMAGE
		local pushback = focushit and ATTACK_DATA.PUSHBACK_FOCUS or ATTACK_DATA.PUSHBACK
		local hitstun = ATTACK_DATA.HITSTUN

		local dir = inst:GetAngleTo(v)

		local attack = Attack(inst, v)
		attack:SetDamageMod(damage_mod)
		attack:SetDir(dir)
		attack:SetHitstunAnimFrames(hitstun)
		attack:SetPushback(pushback)
		attack:SetFocus(focushit)
		attack:SetID(inst.sg.mem.attack_type)
		attack:SetNameID(inst.sg.mem.attack_id)

		if inst.sg.statemem.hitflags then
			attack:SetHitFlags(inst.sg.statemem.hitflags)
		end

		if ATTACK_DATA.KNOCK == "KNOCKDOWN" then
			inst.components.combat:DoKnockdownAttack(attack)
		elseif ATTACK_DATA.KNOCK == "KNOCKBACK" then
			inst.components.combat:DoKnockbackAttack(attack)
		else
			inst.components.combat:DoBasicAttack(attack)
		end

		hitstoplevel = SGCommon.Fns.ApplyHitstop(attack, hitstoplevel)

		local hitfx_x_offset = 0
		local hitfx_y_offset = 0

		inst.components.combat:SpawnHitFxForPlayerAttack(attack, "hits_player_cannon_shot", v, inst, hitfx_x_offset, hitfx_y_offset, dir, hitstoplevel)

		-- TODO(dbriscoe): Why do we only spawn if target didn't block? We unconditionally spawn in hammer. Maybe we should move this to SpawnHitFxForPlayerAttack
		if v.sg ~= nil and v.sg:HasStateTag("block") then
		else
			SpawnHurtFx(inst, v, hitfx_x_offset, dir, hitstoplevel)
		end
	end
end

local function DoBackfireSelfAttack(inst)
	if TheWorld:HasTag("town") then
		-- Don't self-damage in town
		return
	end

	assert(inst.sg.mem.attack_id == "BACKFIRE_STRONG_EARLY" or inst.sg.mem.attack_id == "BACKFIRE_STRONG_LATE", "Received wrong attack ID for BACKFIRE attack. Maybe some timing issue?")
	local ATTACK_DATA = ATTACKS[inst.sg.mem.attack_id]

	if ATTACK_DATA.SELF_DAMAGE <= 0 then
		return
	end

	local focushit = FOCUS_SEQUENCE[GetRemainingAmmo(inst)]

	local hitstoplevel = focushit and ATTACK_DATA.HITSTOP_FOCUS or ATTACK_DATA.HITSTOP
	local pushback = focushit and ATTACK_DATA.PUSHBACK_FOCUS or ATTACK_DATA.PUSHBACK
	local hitstun = ATTACK_DATA.HITSTUN

	local dir = inst:GetAngleTo(inst)

	local attack = Attack(inst, inst)
	attack:SetOverrideDamage(ATTACK_DATA.SELF_DAMAGE)
	attack:SetHitstunAnimFrames(hitstun)
	attack:SetPushback(pushback)
	attack:SetFocus(focushit)
	attack:SetID(inst.sg.mem.attack_type)
	attack:SetNameID(inst.sg.mem.attack_id)

	inst.components.combat:DoBasicAttack(attack)

	hitstoplevel = SGCommon.Fns.ApplyHitstop(attack, hitstoplevel)

	local hitfx_x_offset = ATTACK_DATA.SELF_HIT_FX_X_OFFSET
	local hitfx_y_offset = ATTACK_DATA.SELF_HIT_FX_Y_OFFSET

	inst.components.combat:SpawnHitFxForPlayerAttack(attack, "hits_player_cannon_shot", inst, inst, hitfx_x_offset, hitfx_y_offset, inst, hitstoplevel)

	-- TODO(dbriscoe): Why do we only spawn if target didn't block? We unconditionally spawn in hammer. Maybe we should move this to SpawnHitFxForPlayerAttack
	if inst.sg ~= nil and inst.sg:HasStateTag("block") then
	else
		SpawnHurtFx(inst, inst, hitfx_x_offset, dir, hitstoplevel)
	end
end

local function GetReloadState(inst)
	-- Reload
	local nextstate
	if inst.sg.statemem.perfectwindow then
		nextstate = "planted_reload_fast"
	elseif inst.sg.statemem.earlywindow then
		nextstate = "planted_reload_slow_early"
	else
		nextstate = "planted_reload_slow_late"
	end
	return nextstate
end

local function GetShockwavePreState(inst)
	-- Reload
	local nextstate
	if inst.sg.statemem.perfectwindow then
		nextstate = "shockwave_ammocheck"
	elseif inst.sg.statemem.earlywindow then
		nextstate = "shockwave_pre_early"
	end
	return nextstate
end

local function GetBackfirePreState(inst)
	-- Reload
	local nextstate
	if inst.sg.statemem.perfectwindow then
		nextstate = "backfire_ammocheck"
	elseif inst.sg.statemem.earlywindow and GetRemainingAmmo(inst) > 0 then
		-- This animation hops onto the cannon, which would then pop as we transition back to the "chk-chk!" no ammo state.
		-- So we must check at this point if we have enough ammo. If not, go right to ammo_check so we don't hop onto the cannon.
		nextstate = "backfire_pre_early"
	elseif GetRemainingAmmo(inst) <= 0 then
		nextstate = "backfire_pre_early_noammo"
	end
	return nextstate
end

local function GetMortarPreState(inst)
	-- Reload
	local nextstate
	if inst.sg.statemem.perfectwindow then
		nextstate = "mortar_ammocheck"
	elseif inst.sg.statemem.earlywindow then
		nextstate = "mortar_pre_early"
	end
	return nextstate
end

-- Default data for tools functions
local function BlastToStatesDataForTools(inst)
	return {
		maxspeed = -TUNING.GEAR.WEAPONS.CANNON.ROLL_VELOCITY,
		speed = 0,
		framessliding = 0,
	}
end

local function CheckForHeavyQuickRise(inst, data)
	if data.control == "heavyattack" and inst.sg.statemem.canheavydodgespecial then
		if GetRemainingAmmo(inst) > 0 then
			inst.sg:GoToState("cannon_quickrise")
		else
			inst.sg:GoToState("cannon_quickrise_noammo")
			return false
		end
		return true
	end

	return false
end

local events =
{
	EventHandler("cannon_reload", function(inst, amount)
		OnReload(inst, amount)
	end),
	EventHandler("controlevent", function(inst, data)
		CheckForHeavyQuickRise(inst, data)
	end),
}
SGPlayerCommon.Events.AddAllBasicEvents(events)

local states =
{
	State({
		name = "init",
		onenter = function(inst)
			inst.sg.mem.ammo_max = TUNING.GEAR.WEAPONS.CANNON.AMMO
			inst.sg.mem.ammo = TUNING.GEAR.WEAPONS.CANNON.AMMO

			inst.sg.mem.heavydodge = true -- For quickrising
			--UpdateAmmoSymbols(inst)
			inst.sg:GoToState("idle")
		end,
	}),

	State({
		name = "default_light_attack",
		onenter = function(inst, transitiondata)
			if GetRemainingAmmo(inst) > 0 then
				inst.sg:GoToState("shoot", transitiondata ~= nil and transitiondata or nil)
			else
				inst.sg:GoToState("shoot_noammo")
			end
		end,
	}),

	State({
		name = "default_heavy_attack",
		onenter = function(inst, transitiondata)
			if GetRemainingAmmo(inst) > 0 then
				inst.sg:GoToState("blast", transitiondata ~= nil and transitiondata or nil)
			else
				inst.sg:GoToState("shoot_noammo")
			end
		end,
	}),

	State({
		name = "default_dodge",
		onenter = function(inst) inst.sg:GoToState("cannon_plant_pre") end,
	}),

	State({
		name = "shoot",
		tags = { "busy", "light_attack" },

		default_data_for_tools = function(inst)
			return { attack_type = "light_attack" }
		end,

		onenter = function(inst, transitiondata)
			-- transitiondata =
			-- exists if we are canceling into this state from a blast-dodge
			-- {
			-- 	maxspeed = the overall speed of this blast backwards
			-- 	speed = the speed we are currently moving
			-- 	framessliding = how many frames we have already been sliding, so we can continue the same slide
			-- }
			inst.AnimState:PlayAnimation("cannon_atk1")
			inst.Network:FlushAllHistory()	-- Make sure this anim 'skips' the network buffered anim history

			inst.sg.mem.attack_id = "SHOOT"
			inst.sg.mem.attack_type = "light_attack"

			DoShoot(inst)
			-- CheckIfDodging(inst, transitiondata) -- If we canceled into this shot from another blast

			inst.sg.statemem.weightmult = GetWeightVelocityMult(inst)
			inst:PushEvent("attack_state_start")
		end,

		onupdate = function(inst)
			DoDodgeMovement(inst)
		end,

		timeline =
		{
			--physics
			FrameEvent(0, DoShootKickback),

			FrameEvent(1, function(inst) inst.Physics:SetMotorVel(-3 * inst.sg.statemem.weightmult) end),
			FrameEvent(3, function(inst) inst.Physics:SetMotorVel(-2 * inst.sg.statemem.weightmult) end),
			FrameEvent(4, function(inst) inst.Physics:SetMotorVel(-1 * inst.sg.statemem.weightmult) end),
			FrameEvent(5, function(inst) inst.Physics:SetMotorVel(0 * inst.sg.statemem.weightmult) end),

			FrameEvent(7, SGPlayerCommon.Fns.RemoveBusyState),
		},

		events =
		{
			EventHandler("animover", function(inst)
				inst.sg:GoToState("idle")
				inst.Physics:Stop()
			end),
		},
	}),

	State({
		name = "blast",
		tags = { "busy", "airborne", "heavy_attack", "dodge", "dodging_backwards" },

		onenter = function(inst)
			inst.AnimState:PlayAnimation("cannon_H_atk")
			inst:PushEvent("attack_state_start")

			inst.sg.mem.attack_id = "BLAST"
			inst.sg.mem.attack_type = "heavy_attack"

			DoBlast(inst)
			ConfigureNewDodge(inst)

			local focus = FOCUS_SEQUENCE[GetRemainingAmmo(inst)]
			local params = {}
			params.fmodevent = fmodtable.Event.Cannon_shoot_heavy
			params.sound_max_count = 1
			local handle = soundutil.PlaySoundData(inst, params)
			soundutil.SetInstanceParameter(inst, handle, "isFocusAttack", focus and 1 or 0)
			soundutil.SetInstanceParameter(inst, handle, "cannonHeavyShotType", 0)
			soundutil.SetInstanceParameter(inst, handle, "cannonAmmo", GetRemainingAmmo(inst))

			SGCommon.Fns.StartJumpingOverHoles(inst)
			SGPlayerCommon.Fns.SetRollPhysicsSize(inst)
			inst.HitBox:SetInvincible(true)
			--
		end,

		onupdate = function(inst)
			DoDodgeMovement(inst)
		end,

		timeline =
		{
			FrameEvent(1, function(inst)
				DoBlastKickback(inst) -- Start with a strong burst
				StartNewDodge(inst)
			end),

			--CANCELS
			FrameEvent(5, function(inst)
				inst.sg.statemem.canshoot = true
				SGPlayerCommon.Fns.DetachSwipeFx(inst)
				SGPlayerCommon.Fns.DetachPowerSwipeFx(inst)
			end),
			FrameEvent(7, function(inst)
				inst.sg.statemem.canplant = true
				if inst.sg.statemem.triedplantearly then
					local transitiondata = { maxspeed = inst.sg.statemem.maxspeed, speed = inst.sg.statemem.speed, framessliding = inst.sg.statemem.framessliding }
					inst.sg:GoToState("blast_TO_plant", transitiondata)
				end
			end),
		},

		onexit = function(inst)
			inst.HitBox:SetInvincible(false)
			SGPlayerCommon.Fns.UndoRollPhysicsSize(inst)
			SGCommon.Fns.StopJumpingOverHoles(inst)
		end,


		events =
		{
			EventHandler("controlevent", function(inst, data)
				local transitiondata = { maxspeed = inst.sg.statemem.maxspeed, speed = inst.sg.statemem.speed, framessliding = inst.sg.statemem.framessliding }
				if inst.sg.statemem.canshoot then
					if data.control == "heavyattack" then
						SGCommon.Fns.FaceActionTarget(inst, data, true, true)
						if GetRemainingAmmo(inst) > 0 then
							inst.sg:GoToState("blast_TO_airblast", transitiondata) -- JAN14 switch to double-dodge state
						else
							inst.sg:GoToState("blast_TO_noammo", transitiondata)
						end
					elseif data.control == "lightattack" then
						SGCommon.Fns.FaceActionTarget(inst, data, true, true)
						if GetRemainingAmmo(inst) > 0 then
							inst.sg:GoToState("blast_TO_airshoot", transitiondata)
						else
							inst.sg:GoToState("blast_TO_noammo", transitiondata)
						end
					end
				end

				if data.control == "dodge" then
					if inst.sg.statemem.canplant then
						inst.sg:GoToState("blast_TO_plant", transitiondata)
					else
						inst.sg.statemem.triedplantearly = true
					end
				end
			end),

			EventHandler("animover", function(inst)
				local transitiondata = { maxspeed = inst.sg.statemem.maxspeed, speed = inst.sg.statemem.speed, framessliding = inst.sg.statemem.framessliding }
				inst.sg:GoToState("blast_TO_land", transitiondata)
			end),
		},
	}),

	State({
		name = "blast_TO_noammo",
		tags = { "busy", "airborne" },

		onenter = function(inst, transitiondata)
			inst.AnimState:PlayAnimation("cannon_H_to_L_atk")
			-- "Dodge" stuff, using transitiondata
			CheckIfDodging(inst, transitiondata)

		end,

		onupdate = function(inst)
			DoDodgeMovement(inst)
		end,

		timeline =
		{
			FrameEvent(1, function(inst)
				--sound
				local params = {}
				params.fmodevent = fmodtable.Event.Cannon_noammo
				local handle = soundutil.PlaySoundData(inst, params)
			end),
		},

		onexit = function(inst)
			inst.HitBox:SetInvincible(false)
			SGPlayerCommon.Fns.UndoRollPhysicsSize(inst)
			SGCommon.Fns.StopJumpingOverHoles(inst)
		end,


		events =
		{
			EventHandler("animover", function(inst)
				local transitiondata = { maxspeed = inst.sg.statemem.maxspeed, speed = inst.sg.statemem.speed, framessliding = inst.sg.statemem.framessliding }
				inst.sg:GoToState("blast_TO_land", transitiondata)
			end),
		},
	}),

	State({
		name = "blast_TO_land",
		tags = { "busy" },

		default_data_for_tools = BlastToStatesDataForTools,

		onenter = function(inst, transitiondata)
			inst.AnimState:PlayAnimation("cannon_H_land")

			-- "Dodge" stuff, using transitiondata
			CheckIfDodging(inst, transitiondata)
			--

			inst.sg.statemem.canplant = true
			inst.sg.statemem.canslidingact = true
		end,

		onupdate = function(inst)
			DoDodgeMovement(inst)
		end,

		timeline =
		{
			--CANCELS
			FrameEvent(2, SGPlayerCommon.Fns.SetCanSkill),
		},

		onexit = function(inst)
			inst.HitBox:SetInvincible(false)
			inst.Physics:Stop()
		end,


		events =
		{
			EventHandler("controlevent", function(inst, data)
				local transitiondata = { maxspeed = inst.sg.statemem.maxspeed, speed = inst.sg.statemem.speed, framessliding = inst.sg.statemem.framessliding }
				if inst.sg.statemem.canslidingact then
					if data.control == "heavyattack" then
						inst.sg:GoToState("default_heavy_attack", transitiondata)
					elseif data.control == "lightattack" then
						inst.sg:GoToState("default_light_attack", transitiondata)
					end
				end

				if inst.sg.statemem.canplant then
					if data.control == "dodge" then
						inst.sg:GoToState("cannon_plant_pre", transitiondata) -- JAN14 switch to midair-plant state
					end
				end
			end),

			EventHandler("animover", function(inst)
				inst.sg:GoToState("idle")
			end),
		},
	}),

	State({
		name = "blast_TO_airshoot",
		tags = { "busy", "airborne", "light_attack" },

		default_data_for_tools = BlastToStatesDataForTools,

		onenter = function(inst, transitiondata)
			inst.AnimState:PlayAnimation("cannon_H_to_L_atk")
			inst.sg.mem.attack_id = "BLACK_TO_AIRSHOOT"
			inst.sg.mem.attack_type = "light_attack"
			inst:PushEvent("attack_state_start")
			inst.sg.statemem.projectile_y_offset = 1.7

			SGCommon.Fns.StartJumpingOverHoles(inst)

			-- Dodge stuff, using transitiondata
			CheckIfDodging(inst, transitiondata) -- If we were already dodging, continue that dodge's momentum.

			-- Mid-air shooting presentation
			if GetRemainingAmmo(inst) > 0 then
				local hitstop = HitStopLevel.LIGHT
				inst.components.hitstopper:PushHitStop(hitstop)
				inst.sg.statemem.pausedodgemovement = true -- Pause dodge movement momentarily to let the eye register the shot

				inst:DoTaskInAnimFrames(hitstop, function()
					if inst ~= nil and inst:IsValid() then
						if GetRemainingAmmo(inst) > 0 then
							inst.sg.statemem.pausedodgemovement = false
							DoShootKickback(inst)
							DoAirShootMovement(inst)
							inst.sg.statemem.framessliding = math.floor(inst.sg.statemem.framessliding / 2) -- Regain some momentum
							DoShoot(inst)
						end
					end
				end)
			else
				inst.sg.statemem.cantshoot = true
			end
		end,

		onupdate = function(inst)
			DoDodgeMovement(inst)
		end,

		timeline =
		{
			-- FX: Because this one state needs to be reused for both "ammo" and "noammo" versions, we will play the FX here.
			FrameEvent(1, function(inst)
				if GetRemainingAmmo(inst) + 1 > 0 then
					-- Normal shot
					-- No ammo version is below in the controlevent EventHandler
					local param =
					{
						duration=45.0,
						offx=0.5,
						offy=2.0,
						offz=0.0,
						particlefxname="cannon_shot",
						use_entity_facing=true
					}
					ParticleSystemHelper.MakeEventSpawnParticles(inst, param)
					SGPlayerCommon.Fns.AttachSwipeFx(inst, "fx_player_cannon_h_to_l_atk")
					SGPlayerCommon.Fns.AttachPowerSwipeFx(inst, "fx_player_cannon_h_to_l_atk")
				end
			end),

			FrameEvent(7, function(inst)
				SGPlayerCommon.Fns.DetachSwipeFx(inst)
				SGPlayerCommon.Fns.DetachPowerSwipeFx(inst)
			end),

			--CANCELS
			FrameEvent(7, function(inst)
				inst.sg.statemem.canshoot = true
				inst.sg.statemem.airplant = true
				if inst.sg.statemem.triedplantearly then
					local transitiondata = { maxspeed = inst.sg.statemem.maxspeed, speed = inst.sg.statemem.speed, framessliding = inst.sg.statemem.framessliding }
					inst.sg:GoToState("blast_TO_plant", transitiondata)
				end
			end),
			FrameEvent(8, function(inst)
				inst.sg.statemem.airplant = false
				inst.sg.statemem.groundplant = true
			end),
		},

		onexit = function(inst)
			inst.HitBox:SetInvincible(false)
			inst.Physics:Stop()
			SGCommon.Fns.StopJumpingOverHoles(inst)
		end,


		events =
		{
			EventHandler("controlevent", function(inst, data)
				if inst.sg.statemem.canshoot then
					local transitiondata = { maxspeed = inst.sg.statemem.maxspeed, speed = inst.sg.statemem.speed, framessliding = inst.sg.statemem.framessliding }
					if data.control == "heavyattack" and not inst.sg.statemem.cantshoot then
						SGCommon.Fns.FaceActionTarget(inst, data, true, true)
						if GetRemainingAmmo(inst) > 0 then
							inst.sg:GoToState("blast_TO_airblast", transitiondata)
						else
							inst.sg:GoToState("blast_TO_noammo", transitiondata)
						end
					elseif data.control == "lightattack" and not inst.sg.statemem.cantshoot then
						SGCommon.Fns.FaceActionTarget(inst, data, true, true)
						if GetRemainingAmmo(inst) > 0 then
							inst.sg:GoToState("blast_TO_airshoot", transitiondata)
						else
							inst.sg:GoToState("blast_TO_noammo", transitiondata)
						end
					end
				end

				if data.control == "dodge" then
					if inst.sg.statemem.airplant then
						local transitiondata = { maxspeed = inst.sg.statemem.maxspeed, speed = inst.sg.statemem.speed, framessliding = inst.sg.statemem.framessliding }
						inst.sg:GoToState("blast_TO_plant", transitiondata)
					elseif inst.sg.statemem.groundplant then
						local transitiondata = { maxspeed = inst.sg.statemem.maxspeed, speed = inst.sg.statemem.speed, framessliding = inst.sg.statemem.framessliding }
						inst.sg:GoToState("cannon_plant_pre", transitiondata)
					else
						inst.sg.statemem.triedplantearly = true
					end
				end
			end),

			EventHandler("animover", function(inst)
				local transitiondata = { maxspeed = inst.sg.statemem.maxspeed, speed = inst.sg.statemem.speed, framessliding = inst.sg.statemem.framessliding }
				inst.sg:GoToState("blast_TO_land", transitiondata)
			end),
		},
	}),

	State({
		name = "airshoot_TO_airshoot",
		tags = { "busy", "light_attack" },

		default_data_for_tools = BlastToStatesDataForTools,

		onenter = function(inst, transitiondata)
			inst.AnimState:PlayAnimation("cannon_H_to_L_atk")
			inst.sg.mem.attack_id = "AIRSHOOT_TO_AIRSHOOT"
			inst.sg.mem.attack_type = "light_attack"
			inst:PushEvent("attack_state_start")
			inst.sg.statemem.projectile_y_offset = 1.4

			SGCommon.Fns.StartJumpingOverHoles(inst)

			-- "Dodge" stuff:
			CheckIfDodging(inst, transitiondata)
			--

			-- Mid-air shooting presentation
			if GetRemainingAmmo(inst) > 0 then
				local hitstop = HitStopLevel.LIGHT
				inst.components.hitstopper:PushHitStop(hitstop)
				inst.sg.statemem.pausedodgemovement = true -- Pause dodge movement momentarily to let the eye register the shot

				inst:DoTaskInAnimFrames(hitstop, function()
					if inst ~= nil and inst:IsValid() then
						if GetRemainingAmmo(inst) > 0 then
							DoShootKickback(inst)
							inst.sg.statemem.framessliding = math.floor(inst.sg.statemem.framessliding / 2)
							inst.sg.statemem.pausedodgemovement = false
							DoShoot(inst)
						end
					end
				end)
			end
		end,

		onupdate = function(inst)
			DoDodgeMovement(inst)
		end,

		timeline =
		{
			--CANCELS
			-- FrameEvent(2, function(inst) inst.sg.statemem.canshoot = true end),
		},

		onexit = function(inst)
			inst.HitBox:SetInvincible(false)
			inst.Physics:Stop()
			SGCommon.Fns.StopJumpingOverHoles(inst)
		end,


		events =
		{
			EventHandler("controlevent", function(inst, data)
				-- if inst.sg.statemem.canslidingact then
				-- 	local transitiondata = { maxspeed = inst.sg.statemem.maxspeed, speed = inst.sg.statemem.speed, framessliding = inst.sg.statemem.framessliding }
				-- 	if data.control == "heavyattack" then
				-- 		inst.sg:GoToState("default_heavy_attack", transitiondata)
				-- 	elseif data.control == "lightattack" then
				-- 		inst.sg:GoToState("default_light_attack", transitiondata)
				-- 	elseif data.control == "dodge" then
				-- 		inst.sg:GoToState("cannon_plant_pre", transitiondata)
				-- 	end
				-- end
			end),

			EventHandler("animover", function(inst)
				inst.sg:GoToState("blast_TO_land")
			end),
		},
	}),

	State({
		name = "blast_TO_airblast",
		tags = { "busy", "airborne", "airborne_high", "heavy_attack", "dodge", "dodging_backwards" },

		onenter = function(inst, transitiondata)
			inst.AnimState:PlayAnimation("cannon_H_to_H_atk")
			inst.sg.mem.attack_id = "BLAST_TO_AIRBLAST"
			inst.sg.mem.attack_type = "heavy_attack"
			inst:PushEvent("attack_state_start")
			inst.sg.statemem.projectile_y_offset = 1.7

			SGCommon.Fns.StartJumpingOverHoles(inst)

			-- "Dodge" stuff:
			CheckIfDodging(inst, transitiondata) -- If we were already dodging, continue that dodge's momentum.
			--

			-- Mid-air shooting presentation
			if GetRemainingAmmo(inst) > 0 then
				local hitstop = HitStopLevel.MEDIUM
				inst.components.hitstopper:PushHitStop(hitstop)
				inst.sg.statemem.pausedodgemovement = true -- Pause dodge movement momentarily to let the eye register the shot
				inst:DoTaskInAnimFrames(hitstop, function()
					if inst ~= nil and inst:IsValid() then
						if GetRemainingAmmo(inst) > 0 then
							inst.Physics:StartPassingThroughObjects()

							inst.sg.statemem.pausedodgemovement = false
							ConfigureNewDodge(inst)
							StartNewDodge(inst)
							SGPlayerCommon.Fns.SetRollPhysicsSize(inst)

							inst.AnimState:SetFrame(1) -- Force us to jump to the post-"hitstop" freezeframe

							DoAirBlastKickback(inst)
							DoBlast(inst)

							local focus = FOCUS_SEQUENCE[GetRemainingAmmo(inst)]
							local params = {}
							params.fmodevent = fmodtable.Event.Cannon_shoot_blast
							params.sound_max_count = 1
							local handle = soundutil.PlaySoundData(inst, params)
							soundutil.SetInstanceParameter(inst, handle, "isFocusAttack", focus and 1 or 0)
							soundutil.SetInstanceParameter(inst, handle, "cannonHeavyShotType", 1)
							soundutil.SetInstanceParameter(inst, handle, "cannonAmmo", GetRemainingAmmo(inst))

						end
					end
				end)
			end
		end,

		onupdate = function(inst)
			DoDodgeMovement(inst)
		end,

		timeline =
		{
			-- Movement + state tags
			FrameEvent(13, function(inst)
				inst.sg:RemoveStateTag("airborne_high")

			end),

			FrameEvent(16, function(inst)
				inst.sg.statemem.speed = 0
				inst.sg:RemoveStateTag("airborne")
				inst.Physics:StopPassingThroughObjects()
				SGCommon.Fns.StopJumpingOverHoles(inst)
			end),

			--CANCELS
			FrameEvent(12, function(inst)
				inst.sg.statemem.airplant = true
				inst.sg.statemem.canquickrise = true
				if inst.sg.statemem.triedplantearly then
					local transitiondata = { maxspeed = inst.sg.statemem.maxspeed, speed = inst.sg.statemem.speed, framessliding = inst.sg.statemem.framessliding }
					inst.sg:GoToState("blast_TO_plant", transitiondata)
				end
			end),
			FrameEvent(15, function(inst)
				inst.sg.statemem.airplant = false
				inst.sg.statemem.groundplant = true
			end),
			FrameEvent(16, function(inst)
				inst.sg.statemem.canquickrise = false
				inst.sg.statemem.heavycombostate = nil
			end),
			FrameEvent(17, function(inst)
				inst.sg.statemem.heavycombostate = "default_heavy_attack"
				SGPlayerCommon.Fns.TryQueuedAction(inst, "heavyattack")
			end),
			FrameEvent(24, SGPlayerCommon.Fns.SetCanAttackOrAbility),
			FrameEvent(30, SGPlayerCommon.Fns.RemoveBusyState),
		},

		onexit = function(inst)
			inst.HitBox:SetInvincible(false)
			SGPlayerCommon.Fns.UndoRollPhysicsSize(inst)
			inst.Physics:StopPassingThroughObjects()
			inst.Physics:Stop()
			SGCommon.Fns.StopJumpingOverHoles(inst)
		end,


		events =
		{
			EventHandler("animover", function(inst)
				inst.sg:GoToState("idle")
			end),

			EventHandler("controlevent", function(inst, data)
				if data.control == "dodge" then
					local transitiondata = { maxspeed = inst.sg.statemem.maxspeed, speed = inst.sg.statemem.speed, framessliding = inst.sg.statemem.framessliding }
					if inst.sg.statemem.airplant then
						inst.sg:GoToState("blast_TO_plant", transitiondata)
					elseif inst.sg.statemem.groundplant then
						inst.sg:GoToState("cannon_plant_pre", transitiondata)
					else
						inst.sg.statemem.triedplantearly = true
					end
				elseif data.control == "heavyattack" then
					if inst.sg.statemem.canquickrise and GetRemainingAmmo(inst) > 0 then
						SGCommon.Fns.FaceActionTarget(inst, data, true, true)
						inst.sg:GoToState("cannon_quickrise")
					end
				end
			end),
		},
	}),

	State({
		name = "shoot_noammo",
		tags = { "busy" },

		onenter = function(inst)
			inst.AnimState:PlayAnimation("cannon_empty")

			local params = {}
			params.fmodevent = fmodtable.Event.Cannon_noammo
			params.sound_max_count = 1
			soundutil.PlaySoundData(inst, params)

			inst.Physics:Stop()
		end,

		timeline =
		{
		},

		events =
		{
			EventHandler("animover", function(inst)
				inst.sg:GoToState("idle")
			end),
		},
	}),

	State({
		name = "cannon_plant_pre",
		tags = { "busy" },

		onenter = function(inst, transitiondata)
			-- transitiondata =
			-- {
			-- 	maxspeed = the overall speed of this blast backwards
			-- 	speed = the speed we are currently moving
			-- 	framessliding = how many frames we have already been sliding, so we can continue the same slide
			-- }
			inst.AnimState:PlayAnimation("cannon_atk2_pre")
			inst.sg.statemem.perfectwindow = false
			inst.sg.statemem.earlywindow = true

			-- "Dodge" stuff:
			CheckIfDodging(inst, transitiondata)
		end,

		onupdate = function(inst)
			DoDodgeMovement(inst, true)
		end,

		timeline =
		{
			FrameEvent(5, function(inst)
				-- SGCommon.Fns.BlinkAndFadeColor(inst, {0.25, 0.25, 0.25}, 6) -- 2f eligibility here, 4f eligibility in the hold frame
				inst.sg.statemem.earlywindow = false
				inst.sg.statemem.perfectwindow = true
			end),
		},

		onexit = function(inst)
			inst.Physics:Stop()
		end,

		events =
		{
			EventHandler("controlevent", function(inst, data)
				local nextstate
				local transitiondata
				if data.control == "dodge" then
					nextstate = GetReloadState(inst)
				elseif data.control == "lightattack" then
					nextstate = GetShockwavePreState(inst)
					transitiondata = { perfect = true }
				elseif data.control == "skill" then
					nextstate = GetBackfirePreState(inst)
					transitiondata = { perfect = true }
				elseif data.control == "heavyattack" then
					-- Mortar
					nextstate = GetMortarPreState(inst)
					transitiondata = { perfect = true }
				end

				inst.sg.statemem.nextstate = nextstate
				inst.sg.statemem.transitiondata = transitiondata
			end),

			EventHandler("animover", function(inst)
				if inst.sg.statemem.nextstate then -- If they already clicked a button
					inst.sg:GoToState(inst.sg.statemem.nextstate, inst.sg.statemem.transitiondata)
				else
					inst.sg:GoToState("cannon_plant_hold")
				end
			end),
		},
	}),

	State({
		name = "blast_TO_plant",
		tags = { "busy", "airborne" },

		onenter = function(inst, transitiondata)
			-- transitiondata =
			-- {
			-- 	maxspeed = the overall speed of this blast backwards
			-- 	speed = the speed we are currently moving
			-- 	framessliding = how many frames we have already been sliding, so we can continue the same slide
			-- }
			inst.AnimState:PlayAnimation("cannon_H_to_plant")
			inst.sg.statemem.perfectwindow = false
			inst.sg.statemem.earlywindow = true

			-- "Dodge" stuff:
			CheckIfDodging(inst, transitiondata)
			--
		end,

		onupdate = function(inst)
			DoDodgeMovement(inst, true)
		end,

		timeline =
		{
			FrameEvent(6, function(inst)
				-- SGCommon.Fns.BlinkAndFadeColor(inst, {0.25, 0.25, 0.25}, 6) -- 2f eligibility here, 4f eligibility in the hold frame
				inst.sg.statemem.earlywindow = false
				inst.sg.statemem.perfectwindow = true
			end),

			FrameEvent(10, function(inst)
				inst.sg:RemoveStateTag("airborne")
			end),
		},

		onexit = function(inst)
			inst.Physics:Stop()
		end,

		events =
		{
			EventHandler("controlevent", function(inst, data)
				local nextstate
				local transitiondata
				if data.control == "dodge" then
					-- Reload
					nextstate = GetReloadState(inst)
				elseif data.control == "lightattack" then
					nextstate = GetShockwavePreState(inst)
					transitiondata = inst.sg.statemem.perfectwindow
				elseif data.control == "skill" then
					nextstate = GetBackfirePreState(inst)
					transitiondata = { perfect = true } -- This state is trying out a new animation requirement, needs different data
				elseif data.control == "heavyattack" then
					-- Mortar
					nextstate =	GetMortarPreState(inst)
					transitiondata = inst.sg.statemem.perfectwindow
				end

				inst.sg.statemem.nextstate = nextstate
				inst.sg.statemem.transitiondata = transitiondata
			end),

			EventHandler("animover", function(inst)
				if inst.sg.statemem.nextstate then -- If they already clicked a button
					inst.sg:GoToState(inst.sg.statemem.nextstate, inst.sg.statemem.transitiondata)
				else
					inst.sg:GoToState("cannon_plant_hold")
				end
			end),
		},
	}),

	State({
		name = "cannon_plant_hold",
		tags = { "busy" },

		onenter = function(inst)
			inst.AnimState:PlayAnimation("cannon_atk2_hold_loop", true)
			inst.sg.statemem.dodgecombostate = "planted_reload_fast"
			inst.sg.statemem.lightcombostate = "shockwave_ammocheck"
			inst.sg.statemem.heavycombostate = "mortar_ammocheck"
			inst.sg.statemem.skillcombostate = "backfire_ammocheck"
		end,

		timeline =
		{
			FrameEvent(2, function(inst)
				inst.sg.statemem.dodgecombostate = "planted_reload_slow_late"
				inst.sg.statemem.lightcombostate = "shockwave_pre_late"
				inst.sg.statemem.heavycombostate = "mortar_pre_late"
				if GetRemainingAmmo(inst) > 0 then
					inst.sg.statemem.skillcombostate = "backfire_pre_late"
				else
					inst.sg.statemem.skillcombostate = "backfire_pre_late_noammo" -- The pre_late anim has the player jumping on the cannon, which we don't want to show.
				end
				inst.sg.statemem.canwalkcancel = true
			end),

		},

		onupdate = function(inst)
			if inst.sg.statemem.canwalkcancel and inst.components.playercontroller:GetAnalogDir() ~= nil then
				inst.sg:GoToState("cannon_plant_pst")
			end
		end,

		events =
		{
			EventHandler("animover", function(inst, data)
				inst.sg:GoToState("cannon_plant_pst")
			end),
		},
	}),

	State({
		name = "cannon_plant_pst",
		tags = { "busy" },

		onenter = function(inst)
			inst.AnimState:PlayAnimation("cannon_atk2_pst", true)
			inst.sg.statemem.dodgecombostate = "planted_reload_slow_late"
		end,

		timeline =
		{
		},

		events =
		{
			EventHandler("animover", function(inst, data)
				inst.sg:GoToState("idle")
			end),
		},
	}),

	State({
		name = "mortar_ammocheck",
		tags = { "busy" },

		onenter = function(inst, perfect)
			local ammo = GetRemainingAmmo(inst)
			local max_ammo = GetMaxAmmo(inst)
			local percent = ammo / max_ammo

			local mortar_data = { perfect = perfect, ammo_percent = percent }
			if percent > 0 then
				inst.sg:GoToState("mortar_hold", mortar_data)
			else -- No ammo
				inst.sg:GoToState("mortar_noammo")
			end
		end,
	}),

	State({
		name = "mortar_noammo",
		tags = { "busy" },

		onenter = function(inst)
			inst.AnimState:PlayAnimation("cannon_atk2_pst")
		end,

		events =
		{
			EventHandler("animover", function(inst)
				inst.sg:GoToState("idle")
			end),
		},
	}),

	State({
		name = "mortar_hold",
		tags = { "busy", "heavy_attack" },

		onenter = function(inst, mortar_data)
			-- mortar_data
			--[[
				perfect: whether or not this was a perfectly timed attack. Focus hit if so!
				ammo_percent: how much ammo they have left, 0-1
			]]
			inst.AnimState:PlayAnimation("cannon_atk2_hold_loop", true)
			inst.sg.statemem.mortar_data = mortar_data or { perfect = false, ammo_percent = 1 }
			CreateMortarAimReticles(inst)
		end,

		timeline =
		{
		},

		onupdate = function(inst)
			if not inst.components.playercontroller:IsControlHeld("heavyattack") then
				inst.sg:GoToState("mortar_shoot", inst.sg.statemem.mortar_data)
			else
				UpdateMortarAimReticles(inst)
			end
		end,

		events =
		{
			EventHandler("controlupevent", function(inst, data)
				if data.control == "heavyattack" then
					inst.sg:GoToState("mortar_shoot", inst.sg.statemem.mortar_data)
				end
			end),
			EventHandler("controlevent", function(inst, data)
				if data.control == "dodge" or data.control == "lightattack" or data.control == "potion" or data.control == "skill" then
					inst.sg:GoToState("cannon_plant_pst")
				end
			end),
		},

		onexit = function(inst)
			inst:DoTaskInAnimFrames(9, DestroyMortarAimReticles) -- Delay some frames so there isn't a gap where no aim reticles exist
		end,
	}),

	State({
		name = "mortar_pre_early",
		tags = { "busy", "heavy_attack" },

		onenter = function(inst, mortar_data) --perfect -- whether or not this mortar shot was started with perfect timing -- aka, becomes a focus hit
			inst.AnimState:PlayAnimation("cannon_mortar_early")
		end,

		timeline =
		{
		},

		events =
		{
			EventHandler("animover", function(inst)
				inst.sg:GoToState("mortar_ammocheck", false)
			end)
		},
	}),

	State({
		name = "mortar_pre_late",
		tags = { "busy", "heavy_attack" },

		onenter = function(inst) --perfect -- whether or not this mortar shot was started with perfect timing -- aka, becomes a focus hit
			inst.AnimState:PlayAnimation("cannon_mortar_late")
		end,

		timeline =
		{
		},

		events =
		{
			EventHandler("animover", function(inst)
				inst.sg:GoToState("mortar_ammocheck", false)
			end)
		},
	}),

	State({
		name = "mortar_shoot",
		tags = { "busy", "heavy_attack" },

		onenter = function(inst, mortar_data)
			-- mortar_data
			--[[
				perfect: whether or not this was a perfectly timed attack. Focus hit if so!
				ammo_percent: how much ammo they have left, 0-1
			]]

			inst.Transform:SetRotation(inst.Transform:GetFacing() == FACING_LEFT and -180 or 0)

			local perfect = mortar_data and mortar_data.perfect or false
			local ammo = mortar_data and mortar_data.ammo_percent or 1
			local nextstate
			-- 6/6 ammo = strong
			-- 5/6 ammo = strong
			-- 4/6 ammo = medium
			-- 3/6 ammo = medium
			-- 2/6 ammo = weak
			-- 1/6 ammo = weak
			if ammo >= 0.8 then
				nextstate = "mortar_shoot_strong"
			elseif ammo >= 0.5 then
				nextstate = "mortar_shoot_medium"
			else
				nextstate = "mortar_shoot_weak"
			end

			inst.sg:GoToState(nextstate, perfect)
		end,

		timeline =
		{
		},

		events =
		{
		},
	}),

	State({
		name = "mortar_shoot_weak",
		tags = { "busy", "heavy_attack" },

		onenter = function(inst)
			inst:PushEvent("attack_state_start")

			inst.AnimState:PlayAnimation("cannon_atk2_shoot")
			inst.AnimState:PushAnimation("cannon_atk2_pst")

			inst.sg.mem.attack_id = "MORTAR_WEAK"
			inst.sg.mem.attack_type = "heavy_attack"

			inst.sg.statemem.weightmult = GetWeightVelocityMult(inst)
		end,

		timeline =
		{
			--sound
			FrameEvent(1, function(inst)
				inst.sg.mem.fmodammo = inst.sg.mem.ammo
				PlayMortarSound(inst, inst.sg.mem.fmodammo, 0, 1)
			end),
			FrameEvent(3, function(inst)
				if inst.sg.mem.fmodammo < 2 then
					PlayMortarTubeSound(inst, 0, 1)
				end

				DoMortar(inst, GetRemainingAmmo(inst))
				inst.sg.mem.ammo = GetRemainingAmmo(inst)
				UpdateAmmo(inst, GetRemainingAmmo(inst))
			end),

			FrameEvent(4, function(inst)
				if inst.sg.mem.fmodammo >= 2 then
					PlayMortarTubeSound(inst, 0, 1)
				end
			end),

			FrameEvent(0, function(inst)
				inst.components.hitstopper:PushHitStop(MORTAR_SHOOT_HITSTOP.WEAK)
			end),
			FrameEvent(1, function(inst)
				DoMortarWeakKickback(inst)
				inst.Physics:SetMotorVel(-MORTAR_SHOOT_BLOWBACK.WEAK * inst.sg.statemem.weightmult)
			end),
			FrameEvent(2, function(inst)
				inst.Physics:SetMotorVel(-MORTAR_SHOOT_BLOWBACK.WEAK * inst.sg.statemem.weightmult * 0.5)
			end),
			FrameEvent(4, function(inst)
				inst.Physics:Stop()
			end),
		},

		events =
		{
			EventHandler("animqueueover", function(inst, data)
				inst.sg:GoToState("idle")
			end),
		},

		onexit = function(inst)
		end,
	}),

	State({
		name = "mortar_shoot_medium",
		tags = { "busy", "heavy_attack" },

		onenter = function(inst)
			inst:PushEvent("attack_state_start")

			inst.AnimState:PlayAnimation("cannon_mortar_med_atk")
			inst.sg.mem.attack_id = "MORTAR_MEDIUM"
			inst.sg.mem.attack_type = "heavy_attack"
		end,

		timeline =
		{
			--sound
			FrameEvent(1, function(inst)
				inst.sg.mem.fmodammo = inst.sg.mem.ammo
				PlayMortarSound(inst, inst.sg.mem.fmodammo, 0, 1)
			end),
			FrameEvent(4, function(inst)
				PlayMortarTubeSound(inst, 0, inst.sg.mem.fmodammo <= 3 and 1 or 0)
			end),

			FrameEvent(1, function(inst)
				inst.components.hitstopper:PushHitStop(MORTAR_SHOOT_HITSTOP.MEDIUM)
				DoMortar(inst, GetRemainingAmmo(inst))
				inst.sg.mem.ammo = GetRemainingAmmo(inst)
				UpdateAmmo(inst, GetRemainingAmmo(inst))
			end),

			FrameEvent(3, function(inst)
				DoMortarMediumKickback(inst)
			end),

			FrameEvent(12, function(inst)
				inst.Physics:Stop()
			end),

			--CANCELS
			FrameEvent(23, SGPlayerCommon.Fns.RemoveBusyState),

		},

		events =
		{
			EventHandler("animqueueover", function(inst, data)
				inst.sg:GoToState("idle")
			end),
		},

		onexit = function(inst)
		end,
	}),

	State({
		name = "mortar_shoot_strong",
		tags = { "busy", "heavy_attack" },

		onenter = function(inst)
			inst:PushEvent("attack_state_start")
			inst.AnimState:PlayAnimation("cannon_mortar_heavy_atk")
			inst.sg.mem.attack_id = "MORTAR_STRONG"
			inst.sg.mem.attack_type = "heavy_attack"


			inst.sg.statemem.speed = MORTAR_SHOOT_BLOWBACK.STRONG * GetWeightVelocityMult(inst)
		end,

		timeline =
		{
			--sound
			FrameEvent(1, function(inst)
				inst.sg.mem.fmodammo = inst.sg.mem.ammo
				PlayMortarSound(inst, inst.sg.mem.fmodammo, 2, 0)
			end),

			FrameEvent(5, function(inst)
				PlayMortarTubeSound(inst, 2, 0)
			end),

			FrameEvent(3, function(inst)
				DoMortar(inst, GetRemainingAmmo(inst))
				UpdateAmmo(inst, GetRemainingAmmo(inst))
			end),
			FrameEvent(5, function(inst)
				inst.components.hitstopper:PushHitStop(MORTAR_SHOOT_HITSTOP.STRONG)
			end),
			FrameEvent(6, function(inst)
				DoMortarStrongKickback(inst)
			end),
			FrameEvent(9, function(inst)
				inst.Physics:SetMotorVel(-inst.sg.statemem.speed)
			end),
			FrameEvent(12, function(inst)
				inst.Physics:SetMotorVel(-inst.sg.statemem.speed * 0.5)
				inst.sg:AddStateTag("prone")
			end),
			FrameEvent(16, function(inst)
				inst.Physics:Stop()
			end),

			FrameEvent(55, function(inst)
				inst.sg:RemoveStateTag("prone")
			end),

			--CANCELS
			FrameEvent(65, SGPlayerCommon.Fns.SetCanAttackOrAbility),
			FrameEvent(68, SGPlayerCommon.Fns.RemoveBusyState),

		},

		events =
		{
			EventHandler("animqueueover", function(inst, data)
				inst.sg:GoToState("idle")
			end),
		},
	}),

	State({
		name = "shockwave_ammocheck",
		tags = { "busy" },

		onenter = function(inst, perfect)
			local ammo = GetRemainingAmmo(inst)
			local max_ammo = GetMaxAmmo(inst)
			local percent = ammo / max_ammo

			local shockwave_data = { perfect = perfect, ammo_percent = percent }
			if percent > 0 then
				inst.sg:GoToState("shockwave_hold", shockwave_data)
			else -- No ammo
				inst.sg:GoToState("shockwave_noammo")
			end
		end,
	}),

	State({
		name = "shockwave_noammo",
		tags = { "busy" },

		onenter = function(inst)
			inst.AnimState:PlayAnimation("cannon_atk2_pst")
		end,

		timeline = {
			FrameEvent(6, function(inst)
				--sound
				local params = {}
				params.fmodevent = fmodtable.Event.Cannon_noammo
				soundutil.PlaySoundData(inst, params)
			end),
		},

		events =
		{
			EventHandler("animover", function(inst)
				inst.sg:GoToState("idle")
			end),
		},
	}),

	State({
		name = "shockwave_hold",
		tags = { "busy", "light_attack" },

		onenter = function(inst, shockwave_data)
			-- shockwave_data
			--[[
				perfect: whether or not this was a perfectly timed attack. Focus hit if so!
				ammo_percent: how much ammo they have left, 0-1
			]]
			inst.AnimState:PlayAnimation("cannon_shockwave_hold_loop", false)
			inst.sg.statemem.shockwave_data = shockwave_data or { perfect = false, ammo_percent = 1 }

			--sound
			if not inst.sg.mem.shockwave_looping_sound then
				local params = {}
				params.max_count = 1;
				params.is_autostop = true;
				params.stopatexitstate = true;
				params.fmodevent = fmodtable.Event.Cannon_shockwave_hold_LP
				inst.sg.mem.shockwave_looping_sound = soundutil.PlaySoundData(inst, params)
			end

		end,

		timeline = {},

		onupdate = function(inst)
			if not inst.components.playercontroller:IsControlHeld("lightattack") then
								local params = {}
				params.fmodevent = fmodtable.Event.Cannon_shockwave_plug
				soundutil.PlaySoundData(inst, params)
				inst.sg:GoToState("shockwave_shoot", inst.sg.statemem.shockwave_data)
			end
		end,

		events =
		{
			EventHandler("controlupevent", function(inst, data)
				if data.control == "lightattack" then
				elseif data.control == "dodge" or data.control == "heavyattack" or data.control == "potion" or data.control == "skill" then
					inst.sg:GoToState("cannon_plant_pst")
				end
			end),
		},

		onexit = function(inst)
			if inst.sg.mem.shockwave_looping_sound then
				soundutil.KillSound(inst, inst.sg.mem.shockwave_looping_sound)
				inst.sg.mem.shockwave_looping_sound = nil
			end
		end,
	}),

	State({
		name = "shockwave_pre_early",
		tags = { "busy", "light_attack" },

		onenter = function(inst, shockwave_data) --perfect -- whether or not this mortar shot was started with perfect timing -- aka, becomes a focus hit
			inst.AnimState:PlayAnimation("cannon_shockwave_early")
		end,

		timeline =
		{
		},

		events =
		{
			EventHandler("animover", function(inst)
				inst.sg:GoToState("shockwave_ammocheck", false)
			end)
		},
	}),

	State({
		name = "shockwave_pre_late",
		tags = { "busy", "light_attack" },

		onenter = function(inst) --perfect -- whether or not this mortar shot was started with perfect timing -- aka, becomes a focus hit
			inst.AnimState:PlayAnimation("cannon_shockwave_late")
		end,

		timeline =
		{
		},

		events =
		{
			EventHandler("animover", function(inst)
				inst.sg:GoToState("shockwave_ammocheck", false)
			end)
		},
	}),

	State({
		name = "shockwave_shoot",
		tags = { "busy", "light_attack" },

		onenter = function(inst, shockwave_data)
			-- shockwave_data
			--[[
				perfect: whether or not this was a perfectly timed attack. Focus hit if so!
				ammo_percent: how much ammo they have left, 0-1
			]]

			inst.Transform:SetRotation(inst.Transform:GetFacing() == FACING_LEFT and -180 or 0)

			local perfect = shockwave_data and shockwave_data.perfect or false
			local ammo = shockwave_data and shockwave_data.ammo_percent or 1
			local nextstate
			-- 6/6 ammo = strong
			-- 5/6 ammo = strong
			-- 4/6 ammo = medium
			-- 3/6 ammo = medium
			-- 2/6 ammo = weak
			-- 1/6 ammo = weak
			if ammo >= 0.8 then
				nextstate = "shockwave_shoot_strong"
			elseif ammo >= 0.5 then
				nextstate = "shockwave_shoot_medium"
			else
				nextstate = "shockwave_shoot_weak"
			end

			inst.sg:GoToState(nextstate, perfect)
		end,

		timeline =
		{
		},

		events =
		{
		},
	}),

	State({
		name = "shockwave_shoot_weak",
		tags = { "busy", "light_attack" },

		onenter = function(inst)
			inst:PushEvent("attack_state_start")

			inst.AnimState:PlayAnimation("cannon_shockwave_shoot")
			inst.AnimState:PushAnimation("cannon_shockwave_pst")

			inst.sg.mem.attack_id = "SHOCKWAVE_WEAK"
			inst.sg.mem.attack_type = "light_attack"
		end,

		timeline =
		{
			FrameEvent(3, function(inst)
				combatutil.StartMeleeAttack(inst)
				inst.components.hitbox:PushCircle(0, 0, ATTACKS.SHOCKWAVE_WEAK.RADIUS, HitPriority.MOB_DEFAULT)

				DoShockwaveSelfAttack(inst)

				--sound
				local params = {}
				params.fmodevent = fmodtable.Event.Cannon_shockwave_shoot_weak
				soundutil.PlaySoundData(inst, params)

				UpdateAmmo(inst, GetRemainingAmmo(inst))
			end),

			FrameEvent(4, function(inst)
				combatutil.EndMeleeAttack(inst)
			end),

			--CANCELS
			FrameEvent(14, SGPlayerCommon.Fns.SetCanAttackOrAbility),
			FrameEvent(16, SGPlayerCommon.Fns.RemoveBusyState),
		},

		events =
		{
			EventHandler("animqueueover", function(inst, data)
				inst.sg:GoToState("idle")
			end),

			EventHandler("hitboxtriggered", OnShockwaveHitBoxTriggered),
		},

		onexit = function(inst)
		end,
	}),

	State({
		name = "shockwave_shoot_medium",
		tags = { "busy", "light_attack" },

		onenter = function(inst)
			inst:PushEvent("attack_state_start")

			inst.AnimState:PlayAnimation("cannon_shockwave_med_atk")
			inst.sg.mem.attack_id = "SHOCKWAVE_MEDIUM"
			inst.sg.mem.attack_type = "light_attack"
		end,

		timeline =
		{
			FrameEvent(3, function(inst)
				combatutil.StartMeleeAttack(inst)
				inst.components.hitbox:PushCircle(0, 0, ATTACKS.SHOCKWAVE_MEDIUM.RADIUS, HitPriority.MOB_DEFAULT)

				DoShockwaveSelfAttack(inst)

				--sound
				local params = {}
				params.fmodevent = fmodtable.Event.Cannon_shockwave_shoot_medium
				soundutil.PlaySoundData(inst, params)

				UpdateAmmo(inst, GetRemainingAmmo(inst))
			end),

			FrameEvent(4, function(inst)
				combatutil.EndMeleeAttack(inst)
			end),

			--CANCELS
			FrameEvent(24, SGPlayerCommon.Fns.SetCanAttackOrAbility),
			FrameEvent(26, SGPlayerCommon.Fns.RemoveBusyState),
		},

		events =
		{
			EventHandler("animqueueover", function(inst, data)
				inst.sg:GoToState("idle")
			end),

			EventHandler("hitboxtriggered", OnShockwaveHitBoxTriggered),
		},

		onexit = function(inst)
		end,
	}),

	State({
		name = "shockwave_shoot_strong",
		tags = { "busy", "light_attack" },

		onenter = function(inst)
			inst:PushEvent("attack_state_start")
			inst.AnimState:PlayAnimation("cannon_shockwave_heavy_atk")
			inst.sg.mem.attack_id = "SHOCKWAVE_STRONG"
			inst.sg.mem.attack_type = "light_attack"
		end,

		timeline =
		{
			FrameEvent(3, function(inst)
				combatutil.StartMeleeAttack(inst)
				inst.components.hitbox:PushCircle(0, 0, ATTACKS.SHOCKWAVE_STRONG.RADIUS, HitPriority.MOB_DEFAULT)

				--sound
				local params = {}
				params.fmodevent = fmodtable.Event.Cannon_shockwave_shoot_strong
				soundutil.PlaySoundData(inst, params)

				UpdateAmmo(inst, GetRemainingAmmo(inst))
			end),

			FrameEvent(4, function(inst)
				combatutil.EndMeleeAttack(inst)
			end),

			FrameEvent(34, function(inst) DoShockwaveSelfAttack(inst) end),

			--CANCELS
			FrameEvent(65, SGPlayerCommon.Fns.SetCanAttackOrAbility),
			FrameEvent(68, SGPlayerCommon.Fns.RemoveBusyState),
		},

		events =
		{
			EventHandler("animqueueover", function(inst, data)
				inst.sg:GoToState("idle")
			end),

			EventHandler("hitboxtriggered", OnShockwaveHitBoxTriggered),
		},
	}),


-- HERE

	State({
		name = "backfire_ammocheck",
		tags = { "busy" },

		onenter = function(inst, timing_data)
			local ammo = GetRemainingAmmo(inst)
			local max_ammo = GetMaxAmmo(inst)
			local percent = ammo / max_ammo

			local perfect = timing_data and timing_data.perfect or true -- If we received no timing data, we know it was perfect because we came right from the "skillcombostate" of cannon_plant_hold
			local backfire_data = { perfect = perfect, ammo_percent = percent }
			if percent > 0 then
				if timing_data and timing_data.poortiming then
					inst.sg:GoToState("backfire_hold_poortiming", backfire_data) -- This state has some different animation requirements.
				else
					inst.sg:GoToState("backfire_hold", backfire_data)
				end
			else -- No ammo
				inst.sg:GoToState("backfire_noammo") -- TODO #backfire need a no ammo?
			end
		end,
	}),

	State({
		name = "backfire_noammo",
		tags = { "busy" },

		onenter = function(inst)
			inst.AnimState:PlayAnimation("cannon_atk2_pst")
		end,
		
		timeline = {
			FrameEvent(2, function(inst)
				--sound
				local params = {}
				params.fmodevent = fmodtable.Event.Cannon_noammo
				soundutil.PlaySoundData(inst, params)
			end),
		},

		events =
		{
			EventHandler("animover", function(inst)
				inst.sg:GoToState("idle")
			end),
		},
	}),

	State({
		name = "backfire_hold",
		tags = { "busy", "light_attack" },

		onenter = function(inst, backfire_data)
			-- backfire_data
			--[[
				perfect: whether or not this was a perfectly timed attack. Focus hit if so!
				ammo_percent: how much ammo they have left, 0-1
			]]
			inst.AnimState:PlayAnimation("cannon_backfire_hold_pre", false)
			inst.AnimState:PushAnimation("cannon_backfire_hold_loop", false)

			--sound
			if not inst.sg.mem.backfire_looping_sound then
				local params = {}
				params.max_count = 1;
				params.is_autostop = true;
				params.stopatexitstate = true;
				params.fmodevent = fmodtable.Event.Cannon_backfire_hold_LP
				inst.sg.mem.backfire_looping_sound = soundutil.PlaySoundData(inst, params)
			end

			inst.sg.statemem.backfire_data = backfire_data or { perfect = false, ammo_percent = 1 }
		end,

		timeline =
		{
			-- TODO #backfire this should be about 3
			FrameEvent(6, function(inst) -- TODO #backfire adjust this once anim is smoothed out -- should let the first frame of the second pose through, then transition
				inst.sg.statemem.can_shoot = true -- If we release the button after this point, we can transition.

				if inst.sg.statemem.shoot_requested then
					-- However, if we've already released the button before this point -- go directly into the shoot.
					inst.sg:GoToState("backfire_shoot", inst.sg.statemem.backfire_data)
				end
			end),
		},

		onupdate = function(inst)
			if not inst.components.playercontroller:IsControlHeld("skill") then
				if inst.sg.statemem.can_shoot then
					inst.sg:GoToState("backfire_shoot", inst.sg.statemem.backfire_data)
				else
					inst.sg.statemem.shoot_requested = true
				end
			end
		end,

		events =
		{
			EventHandler("controlupevent", function(inst, data)
				if data.control == "skill" then
					if inst.sg.statemem.can_shoot then
						-- Don't allow going directly to this state -- force us to wait at least to the "can_shoot" flag is set.
						inst.sg:GoToState("backfire_shoot", inst.sg.statemem.backfire_data)
					else
						inst.sg.statemem.shoot_requested = true
					end
				elseif data.control == "dodge" or data.control == "heavyattack" or data.control == "potion" or data.control == "lightattack" then
					inst.sg:GoToState("cannon_plant_pst") -- TODO #backfire need a cancel out
				end
			end),
		},

		onexit = function(inst)
			--sound
			if inst.sg.mem.backfire_looping_sound then
				soundutil.KillSound(inst, inst.sg.mem.backfire_looping_sound)
				inst.sg.mem.backfire_looping_sound = nil
			end
		end,
	}),

	State({
		name = "backfire_hold_poortiming",
		tags = { "busy", "light_attack" },

		onenter = function(inst, backfire_data)
			-- backfire_data
			--[[
				perfect: whether or not this was a perfectly timed attack. Focus hit if so!
				ammo_percent: how much ammo they have left, 0-1
			]]
			inst.AnimState:PlayAnimation("cannon_backfire_hold_loop", false)
			inst.sg.statemem.backfire_data = backfire_data or { perfect = false, ammo_percent = 1 }

			--sound
			if not inst.sg.mem.backfire_looping_sound then
				local params = {}
				params.max_count = 1;
				params.is_autostop = true;
				params.stopatexitstate = true;
				params.fmodevent = fmodtable.Event.Cannon_backfire_hold_LP
				inst.sg.mem.backfire_looping_sound = soundutil.PlaySoundData(inst, params)
			end

		end,

		timeline =
		{
			FrameEvent(4, function(inst)
				inst.sg.statemem.can_shoot = true -- If we release the button after this point, we can transition.

				if inst.sg.statemem.shoot_requested then
					-- However, if we've already released the button before this point -- go directly into the shoot.
					inst.sg:GoToState("backfire_shoot", inst.sg.statemem.backfire_data)
				end
			end),
		},

		onupdate = function(inst)
			if not inst.components.playercontroller:IsControlHeld("skill") then
				if inst.sg.statemem.can_shoot then
					inst.sg:GoToState("backfire_shoot", inst.sg.statemem.backfire_data)
				else
					inst.sg.statemem.shoot_requested = true
				end
			end
		end,

		events =
		{
			EventHandler("controlupevent", function(inst, data)
				if data.control == "skill" then
					if inst.sg.statemem.can_shoot then
						-- Don't allow going directly to this state -- force us to wait at least to the "can_shoot" flag is set.
						inst.sg:GoToState("backfire_shoot", inst.sg.statemem.backfire_data)
					else
						inst.sg.statemem.shoot_requested = true
					end
				elseif data.control == "dodge" or data.control == "heavyattack" or data.control == "potion" or data.control == "lightattack" then
					inst.sg:GoToState("cannon_plant_pst") -- TODO #backfire need a cancel out
				end
			end),
		},

		onexit = function(inst)
			--sound
			if inst.sg.mem.backfire_looping_sound then
				soundutil.KillSound(inst, inst.sg.mem.backfire_looping_sound)
				inst.sg.mem.backfire_looping_sound = nil
			end
		end,
	}),

	State({
		name = "backfire_pre_early",
		tags = { "busy" },

		onenter = function(inst)
			inst.AnimState:PlayAnimation("cannon_backfire_early")
		end,

		timeline =
		{
		},

		events =
		{
			EventHandler("animover", function(inst)
				inst.sg:GoToState("backfire_ammocheck", { perfect = false, poortiming = true })
			end)
		},
	}),

	State({
		name = "backfire_pre_early_noammo",
		tags = { "busy" },

		onenter = function(inst)
			inst.AnimState:PlayAnimation("cannon_shockwave_early") -- Reuse anim, which doesn't have us hopping on the cannon.
		end,

		timeline =
		{
		},

		events =
		{
			EventHandler("animover", function(inst)
				inst.sg:GoToState("backfire_ammocheck", { perfect = false, poortiming = true })
			end)
		},
	}),


	State({
		name = "backfire_pre_late",
		tags = { "busy", "light_attack" },

		onenter = function(inst)
			inst.AnimState:PlayAnimation("cannon_backfire_late")
		end,

		timeline =
		{
		},

		events =
		{
			EventHandler("animover", function(inst)
				inst.sg:GoToState("backfire_ammocheck", { perfect = false, poortiming = true })
			end)
		},
	}),

	State({
		name = "backfire_pre_late_noammo",
		tags = { "busy", "light_attack" },

		onenter = function(inst)
			inst.AnimState:PlayAnimation("cannon_shockwave_late") -- Reuse anim, which doesn't have us hopping on the cannon.
		end,

		timeline =
		{
		},

		events =
		{
			EventHandler("animover", function(inst)
				inst.sg:GoToState("backfire_ammocheck", { perfect = false, poortiming = true })
			end)
		},
	}),

	State({
		name = "backfire_shoot",
		tags = { "busy", "light_attack" },

		onenter = function(inst, backfire_data)
			-- backfire_data
			--[[
				perfect: whether or not this was a perfectly timed attack. Focus hit if so!
				ammo_percent: how much ammo they have left, 0-1
			]]

			inst.Transform:SetRotation(inst.Transform:GetFacing() == FACING_LEFT and -180 or 0)

			--sound
			if inst.sg.mem.backfire_looping_sound then
				soundutil.KillSound(inst, inst.sg.mem.backfire_looping_sound)
				inst.sg.mem.backfire_looping_sound = nil
			end

			local perfect = backfire_data and backfire_data.perfect or false
			local ammo = backfire_data and backfire_data.ammo_percent or 1
			local nextstate
			-- 6/6 ammo = strong
			-- 5/6 ammo = strong
			-- 4/6 ammo = medium
			-- 3/6 ammo = medium
			-- 2/6 ammo = weak
			-- 1/6 ammo = weak
			if ammo >= 0.8 then
				nextstate = "backfire_shoot_strong"
			elseif ammo >= 0.5 then
				nextstate = "backfire_shoot_medium"
			else
				nextstate = "backfire_shoot_weak"
			end

			inst.sg:GoToState(nextstate, perfect)
		end,

		timeline =
		{
		},

		events =
		{
		},
	}),

	State({
		name = "backfire_shoot_weak",
		tags = { "busy", "nointerrupt" },

		onenter = function(inst)
			inst:PushEvent("attack_state_start")

			inst.AnimState:PlayAnimation("cannon_backfire_shoot")
			inst.AnimState:PushAnimation("cannon_backfire_pst")

			inst.sg.mem.attack_id = "BACKFIRE_WEAK"
			inst.sg.mem.attack_type = "skill"

			inst.sg.statemem.speed = BACKFIRE_VELOCITY.WEAK * GetBackfireWeightVelocityMult(inst)

			--sound
			if inst.sg.mem.backfire_looping_sound then
				soundutil.KillSound(inst, inst.sg.mem.backfire_looping_sound)
				inst.sg.mem.backfire_looping_sound = nil
			end
		end,

		timeline =
		{
			--PHYSICS
			-- FrameEvent(0, function(inst) inst.components.hitstopper:PushHitStop(HitStopLevel.LIGHT) end),
			FrameEvent(1, function(inst) DoBackfireWeakKickback(inst) end),
			FrameEvent(1, function(inst)
				--sound
				local params = {}
				params.fmodevent = fmodtable.Event.Cannon_backfire_shoot_weak
				inst.sg.mem.backfire_sound = soundutil.PlaySoundData(inst, params)
			end),
			FrameEvent(1, function(inst) inst.Physics:SetMotorVel(inst.sg.statemem.speed * 1) end),
			FrameEvent(1, function(inst) inst.Physics:StartPassingThroughObjects() end),

			FrameEvent(3, function(inst) inst.Physics:SetMotorVel(inst.sg.statemem.speed * 1.25) end),

			FrameEvent(6, function(inst) inst.Physics:SetMotorVel(inst.sg.statemem.speed * 0.75) end),
			FrameEvent(8, function(inst) inst.Physics:SetMotorVel(inst.sg.statemem.speed * 0.5) end),
			FrameEvent(10, function(inst) inst.Physics:SetMotorVel(inst.sg.statemem.speed * 0.25) end),
			FrameEvent(12, function(inst) inst.Physics:SetMotorVel(inst.sg.statemem.speed * 0.125) end),
			FrameEvent(12, function(inst) inst.Physics:StopPassingThroughObjects() end),
			FrameEvent(14, function(inst)
				inst.Physics:Stop()
			end),

			-- ATTACK DATA
			FrameEvent(1, function(inst)
				combatutil.StartMeleeAttack(inst)
				inst.sg.statemem.hitflags = Attack.HitFlags.LOW_ATTACK
				inst.components.hitbox:StartRepeatTargetDelay()
				inst.components.hitbox:PushBeam(4, 2, 2.5, HitPriority.PLAYER_DEFAULT) -- Thicker in front
				inst.components.hitbox:PushBeam(2, -3, 1, HitPriority.PLAYER_DEFAULT)  -- Thinner in back

				UpdateAmmo(inst, GetRemainingAmmo(inst))
			end),
			FrameEvent(2, function(inst) inst.components.hitbox:PushBeam(2, -1.75, 1, HitPriority.PLAYER_DEFAULT) end),
			FrameEvent(3, function(inst) inst.components.hitbox:PushBeam(2, -1.75, 1, HitPriority.PLAYER_DEFAULT) end),
			FrameEvent(4, function(inst) inst.components.hitbox:PushBeam(2, -1.75, 1, HitPriority.PLAYER_DEFAULT) end),
			FrameEvent(5, function(inst) inst.components.hitbox:PushBeam(2, -1.75, 1, HitPriority.PLAYER_DEFAULT) end),

			FrameEvent(6, function(inst) inst.components.hitbox:PushBeam(1.5, -1.75, 1, HitPriority.PLAYER_DEFAULT) end),
			FrameEvent(7, function(inst) inst.components.hitbox:PushBeam(1.5, -1.75, 1, HitPriority.PLAYER_DEFAULT) end),
			FrameEvent(8, function(inst) inst.components.hitbox:PushBeam(1.5, -1.75, 1, HitPriority.PLAYER_DEFAULT) end),
			FrameEvent(9, function(inst) inst.components.hitbox:PushBeam(1.5, -1.75, 1, HitPriority.PLAYER_DEFAULT) end),
			FrameEvent(10, function(inst) inst.components.hitbox:PushBeam(1.5, -1.75, 1, HitPriority.PLAYER_DEFAULT) end),
			FrameEvent(10, function(inst) inst.components.hitbox:PushBeam(1.5, -1.75, 1, HitPriority.PLAYER_DEFAULT) end),

			FrameEvent(10, function(inst)
				inst.components.hitbox:StopRepeatTargetDelay()
				combatutil.EndMeleeAttack(inst)
			end),

			-- --CANCELS
			FrameEvent(15, SGPlayerCommon.Fns.SetCanDodge),
			FrameEvent(18, SGPlayerCommon.Fns.RemoveBusyState),
		},

		onexit = function(inst)
			inst.Physics:StopPassingThroughObjects()
			inst.components.hitbox:StopRepeatTargetDelay()
			if inst.sg.mem.backfire_sound then
				soundutil.KillSound(inst, inst.sg.mem.backfire_sound)
				inst.sg.mem.backfire_sound = nil
			end
		end,

		events =
		{
			EventHandler("animqueueover", function(inst, data)
				inst.sg:GoToState("idle")
			end),

			EventHandler("hitboxtriggered", OnBackfireHitBoxTriggered),
		},
	}),

	State({
		name = "backfire_shoot_medium",
		tags = { "busy", "light_attack", "nointerrupt" },

		onenter = function(inst)
			inst:PushEvent("attack_state_start")

			inst.AnimState:PlayAnimation("cannon_backfire_med_atk")
			inst.sg.mem.attack_id = "BACKFIRE_MEDIUM_EARLY"
			inst.sg.mem.attack_type = "skill"

			inst.sg.statemem.speed = BACKFIRE_VELOCITY.MEDIUM * GetBackfireWeightVelocityMult(inst)

			--sound
			if inst.sg.mem.backfire_looping_sound then
				soundutil.KillSound(inst, inst.sg.mem.backfire_looping_sound)
				inst.sg.mem.backfire_looping_sound = nil
			end
		end,

		timeline =
		{
			--PHYSICS
			FrameEvent(1, function(inst) inst.components.hitstopper:PushHitStop(HitStopLevel.LIGHT) end),
			FrameEvent(2, function(inst) DoBackfireMediumKickback(inst) end),
			FrameEvent(2, function(inst)
				--sound
				local params = {}
				params.fmodevent = fmodtable.Event.Cannon_backfire_shoot_medium
				inst.sg.mem.backfire_sound = soundutil.PlaySoundData(inst, params)
			end),
			FrameEvent(2, function(inst) inst.Physics:StartPassingThroughObjects() end),
			FrameEvent(2, function(inst) inst.Physics:SetMotorVel(inst.sg.statemem.speed * 1) end),

			FrameEvent(4, function(inst) inst.Physics:SetMotorVel(inst.sg.statemem.speed * 1.15) end),

			FrameEvent(9, function(inst) inst.Physics:SetMotorVel(inst.sg.statemem.speed * 0.5) end),
			FrameEvent(13, function(inst) inst.Physics:SetMotorVel(inst.sg.statemem.speed * 0.25) end),
			FrameEvent(18, function(inst) inst.Physics:SetMotorVel(inst.sg.statemem.speed * 0.125) end),
			FrameEvent(18, function(inst) inst.Physics:StopPassingThroughObjects() end),
			FrameEvent(23, function(inst)
				inst.Physics:Stop()
			end),

			-- ATTACK DATA
			FrameEvent(2, function(inst)
				combatutil.StartMeleeAttack(inst)
				inst.sg.statemem.hitflags = Attack.HitFlags.LOW_ATTACK
				inst.components.hitbox:StartRepeatTargetDelay()
				inst.components.hitbox:PushBeam(4, 2, 2.5, HitPriority.PLAYER_DEFAULT) -- Thicker in front
				inst.components.hitbox:PushBeam(2, -3, 1, HitPriority.PLAYER_DEFAULT)  -- Thinner in back

				UpdateAmmo(inst, GetRemainingAmmo(inst))
			end),
			FrameEvent(3, function(inst) inst.components.hitbox:PushBeam(2, -3, 1, HitPriority.PLAYER_DEFAULT) end),
			FrameEvent(4, function(inst) inst.components.hitbox:PushBeam(2, -3, 1, HitPriority.PLAYER_DEFAULT) end),
			FrameEvent(5, function(inst) inst.components.hitbox:PushBeam(2, -3, 1, HitPriority.PLAYER_DEFAULT) end),
			FrameEvent(6, function(inst) inst.components.hitbox:PushBeam(2, -3, 1, HitPriority.PLAYER_DEFAULT) end),
			FrameEvent(7, function(inst) inst.components.hitbox:PushBeam(2, -3, 1, HitPriority.PLAYER_DEFAULT) end),
			FrameEvent(8, function(inst) inst.components.hitbox:PushBeam(2, -3, 1, HitPriority.PLAYER_DEFAULT) end),
			FrameEvent(9, function(inst) inst.components.hitbox:PushBeam(2, -3, 1, HitPriority.PLAYER_DEFAULT) end),
			FrameEvent(10, function(inst) inst.components.hitbox:PushBeam(2, -3, 1, HitPriority.PLAYER_DEFAULT) end),
			FrameEvent(11, function(inst) inst.components.hitbox:PushBeam(2, -3, 1, HitPriority.PLAYER_DEFAULT) end),
			FrameEvent(12, function(inst) inst.components.hitbox:PushBeam(2, -3, 1, HitPriority.PLAYER_DEFAULT) end),

			FrameEvent(13, function(inst) inst.sg.mem.attack_id = "BACKFIRE_MEDIUM_LATE" end),
			FrameEvent(13, function(inst) inst.components.hitbox:PushBeam(2, -2, 1, HitPriority.PLAYER_DEFAULT) end),
			FrameEvent(14, function(inst) inst.components.hitbox:PushBeam(2, -2, 1, HitPriority.PLAYER_DEFAULT) end),
			FrameEvent(15, function(inst) inst.components.hitbox:PushBeam(2, -2, 1, HitPriority.PLAYER_DEFAULT) end),
			FrameEvent(16, function(inst) inst.components.hitbox:PushBeam(2, -2, 1, HitPriority.PLAYER_DEFAULT) end),
			FrameEvent(17, function(inst) inst.components.hitbox:PushBeam(2, -2, 1, HitPriority.PLAYER_DEFAULT) end),
			FrameEvent(18, function(inst) inst.components.hitbox:PushBeam(2, -2, 1, HitPriority.PLAYER_DEFAULT) end),
			FrameEvent(18, function(inst)
				combatutil.EndMeleeAttack(inst)
			end),

			-- --CANCELS
			FrameEvent(17, function(inst)
				inst.components.playercontroller:AddGlobalControlQueueTicksModifier(7, "backfire_shoot_medium")
			end),
			FrameEvent(22, SGPlayerCommon.Fns.SetCanDodge),
			FrameEvent(24, SGPlayerCommon.Fns.SetCanAttackOrAbility),
			FrameEvent(28, SGPlayerCommon.Fns.RemoveBusyState),
		},

		events =
		{
			EventHandler("animqueueover", function(inst, data)
				inst.sg:GoToState("idle")
			end),

			EventHandler("hitboxtriggered", OnBackfireHitBoxTriggered),
		},

		onexit = function(inst)
			inst.components.playercontroller:RemoveGlobalControlQueueTicksModifier("backfire_shoot_medium")
			inst.components.hitbox:StopRepeatTargetDelay()
			inst.Physics:StopPassingThroughObjects()

			if inst.sg.mem.backfire_sound then
				soundutil.KillSound(inst, inst.sg.mem.backfire_sound)
				inst.sg.mem.backfire_sound = nil
			end
		end,
	}),

	State({
		name = "backfire_shoot_strong",
		tags = { "busy", "light_attack", "nointerrupt" },

		onenter = function(inst)
			inst:PushEvent("attack_state_start")
			inst.AnimState:PlayAnimation("cannon_backfire_heavy_atk")
			inst.sg.mem.attack_id = "BACKFIRE_STRONG_EARLY"
			inst.sg.mem.attack_type = "skill"

			inst.sg.statemem.speed = BACKFIRE_VELOCITY.STRONG * GetBackfireWeightVelocityMult(inst)
			inst.Physics:StartPassingThroughObjects()

			--sound
			if inst.sg.mem.backfire_looping_sound then
				soundutil.KillSound(inst, inst.sg.mem.backfire_looping_sound)
				inst.sg.mem.backfire_looping_sound = nil
			end
		end,

		timeline =
		{
			--PHYSICS
			FrameEvent(1, function(inst) inst.components.hitstopper:PushHitStop(HitStopLevel.MEDIUM) end),

			FrameEvent(2, function(inst) DoBackfireStrongKickback(inst) end),
			FrameEvent(2, function(inst)
				--sound
				local params = {}
				params.fmodevent = fmodtable.Event.Cannon_backfire_shoot_strong
				inst.sg.mem.backfire_sound = soundutil.PlaySoundData(inst, params)
			end),
			FrameEvent(2, function(inst) inst.Physics:SetMotorVel(inst.sg.statemem.speed) end),
			FrameEvent(2, function(inst) inst.Physics:StartPassingThroughObjects() end),

			FrameEvent(10, function(inst) inst.Physics:SetMotorVel(inst.sg.statemem.speed * 0.5) end),
			FrameEvent(18, function(inst) inst.Physics:SetMotorVel(inst.sg.statemem.speed * 0.125) end), -- Hit ground
			-- FrameEvent(18, function(inst) inst.components.hitstopper:PushHitStop(HitStopLevel.LIGHT) end), -- Hit ground
			FrameEvent(20, function(inst) inst.Physics:SetMotorVel(inst.sg.statemem.speed * 0.25) end), -- Bounce
			FrameEvent(23, function(inst) inst.Physics:SetMotorVel(inst.sg.statemem.speed * 0.125) end),
			FrameEvent(27, function(inst) inst.Physics:Stop() end),
			FrameEvent(27, function(inst) inst.Physics:StopPassingThroughObjects() end),

			-- HITBOX STUFF
			FrameEvent(2, function(inst) inst.sg:AddStateTag("airborne") end),
			FrameEvent(3, function(inst) inst.sg:AddStateTag("airborne_high") end),
			FrameEvent(4, function(inst) inst.HitBox:SetEnabled(false) end),
			FrameEvent(13, function(inst) inst.HitBox:SetEnabled(true) end),
			FrameEvent(15, function(inst) inst.sg:RemoveStateTag("airborne_high") end),
			FrameEvent(18, function(inst) inst.sg:RemoveStateTag("airborne") end),

			FrameEvent(2, function(inst)
				combatutil.StartMeleeAttack(inst)
				inst.components.hitbox:StartRepeatTargetDelay()
				inst.components.hitbox:PushBeam(4, 2, 2.5, HitPriority.PLAYER_DEFAULT) -- Thicker in front
				inst.components.hitbox:PushBeam(2, -3, 1, HitPriority.PLAYER_DEFAULT)  -- Thinner in back
				DoBackfireSelfAttack(inst)
				UpdateAmmo(inst, GetRemainingAmmo(inst))
			end),

			FrameEvent(3, function(inst)
				inst.components.hitbox:PushBeam(-2, 2, 1, HitPriority.PLAYER_DEFAULT)
				inst.sg.statemem.hitflags = Attack.HitFlags.AIR_HIGH
			end),

			FrameEvent(4, function(inst)
				inst.components.hitbox:PushBeam(-2, 2, 1, HitPriority.PLAYER_DEFAULT)
				combatutil.EndMeleeAttack(inst)
			end),
			FrameEvent(5, function(inst) inst.components.hitbox:StopRepeatTargetDelay() end),


			FrameEvent(14, function(inst)
				inst.sg.mem.attack_id = "BACKFIRE_STRONG_LATE"
				combatutil.StartMeleeAttack(inst)
				inst.components.hitbox:StartRepeatTargetDelay()
				inst.sg.statemem.hitflags = Attack.HitFlags.AIR_HIGH
				inst.components.hitbox:PushBeam(0, -2, 1, HitPriority.PLAYER_DEFAULT)
			end),
			FrameEvent(15, function(inst)
				inst.sg.statemem.hitflags = nil
				inst.components.hitbox:PushBeam(0, -2, 1, HitPriority.PLAYER_DEFAULT)
			end),

			FrameEvent(16, function(inst)
				inst.components.hitbox:PushBeam(0, -2, 1, HitPriority.PLAYER_DEFAULT)
			end),

			FrameEvent(17, function(inst)
				inst.components.hitbox:PushBeam(0, -2, 1, HitPriority.PLAYER_DEFAULT)
				combatutil.EndMeleeAttack(inst)
			end),

			FrameEvent(18, function(inst)
				inst.components.hitbox:PushBeam(0, -2, 1, HitPriority.PLAYER_DEFAULT)
				DoBackfireSelfAttack(inst)
				combatutil.EndMeleeAttack(inst)
			end),
			FrameEvent(19, function(inst) inst.components.hitbox:StopRepeatTargetDelay() end),

			-- --CANCELS
			FrameEvent(67, SGPlayerCommon.Fns.RemoveBusyState),
		},

		onexit = function(inst)
			inst.components.hitbox:StopRepeatTargetDelay()
			if inst.sg.mem.backfire_sound then
				soundutil.KillSound(inst, inst.sg.mem.backfire_sound)
				inst.sg.mem.backfire_sound = nil
			end
		end,

		events =
		{
			EventHandler("animqueueover", function(inst, data)
				inst.sg:GoToState("idle")
			end),

			EventHandler("hitboxtriggered", OnBackfireHitBoxTriggered),
		},
	}),

	State({
		name = "planted_reload_fast",
		tags = { "busy", "nointerrupt" },

		onenter = function(inst, attacktype)
			-- SGCommon.Fns.FlickerColor(inst, {.25, .25, .25}, 3, false, true)
			inst.AnimState:PlayAnimation("cannon_reload_fast")
			inst.sg.statemem.attacktype = attacktype

		end,

		timeline =
		{
			FrameEvent(13, function(inst)
				OnReload(inst, GetMissingAmmo(inst))
				inst.sg.statemem.lightcombostate = "default_light_attack"
				inst.sg.statemem.heavycombostate = "default_heavy_attack"

				SGPlayerCommon.Fns.SetCanDodge(inst)
			end),
		},

		onexit = function(inst)
		end,

		events =
		{
			EventHandler("animover", function(inst, data)
				inst.sg:GoToState("idle")
			end),
		},
	}),

	State({
		name = "planted_reload_slow_late",
		tags = { "busy", "nointerrupt" },

		onenter = function(inst, attacktype)
			inst.AnimState:PlayAnimation("cannon_reload_slow")
		end,

		timeline =
		{

			FrameEvent(19, function(inst) --TODO(jambell): retime with actual anim
				OnReload(inst, 3)
			end),

			FrameEvent(31, function(inst) --TODO(jambell): retime with actual anim
				OnReload(inst, 3)
			end),

			-- FrameEvent(31, function(inst) --TODO(jambell): retime with actual anim
			-- 	inst.sg.statemem.lightcombostate = "default_light_attack"
			-- 	inst.sg.statemem.heavycombostate = "default_heavy_attack"
			-- end),
		},

		events =
		{
			EventHandler("animover", function(inst, data)
				inst.sg:GoToState("idle")
			end),
		},
	}),

	State({
		name = "planted_reload_slow_early",
		tags = { "busy", "nointerrupt" },

		onenter = function(inst, attacktype)
			inst.AnimState:PlayAnimation("cannon_reload_early")
		end,

		timeline =
		{

			FrameEvent(32, function(inst) --TODO(jambell): retime with actual anim
				OnReload(inst, GetMissingAmmo(inst))
			end),

			-- FrameEvent(31, function(inst) --TODO(jambell): retime with actual anim
			-- 	inst.sg.statemem.lightcombostate = "default_light_attack"
			-- 	inst.sg.statemem.heavycombostate = "default_heavy_attack"
			-- end),
		},

		events =
		{
			EventHandler("animover", function(inst, data)
				inst.sg:GoToState("idle")
			end),
		},
	}),

	State({
		name = "planted_reload_big_pst",
		tags = { "busy" },

		onenter = function(inst, wasfast)
			inst.AnimState:PlayAnimation("cannon_reload_big_pst")
			inst.sg.statemem.wasfast = wasfast or false
		end,

		timeline =
		{
			FrameEvent(0, function(inst)
				if inst.sg.statemem.wasfast then
					SGPlayerCommon.Fns.RemoveBusyState(inst)
				end
			end)
		},

		events =
		{
			EventHandler("animover", function(inst, data)
				inst.sg:GoToState("idle")
			end),
		},
	}),

	State({
		name = "cannon_quickrise",
		tags = { "busy", "heavy_attack", "dodge", "dodging_backwards" },

		onenter = function(inst)
			inst.AnimState:PlayAnimation("cannon_getup_dodge")
			SGPlayerCommon.Fns.UnsetCanDodge(inst)

			SGPlayerCommon.Fns.SetRollPhysicsSize(inst)
			inst.HitBox:SetInvincible(true)
			SGCommon.Fns.StartJumpingOverHoles(inst)

			inst:PushEvent("dodge")
			inst:PushEvent("attack_state_start")
			inst.sg.mem.attack_id = "QUICK_RISE"
			inst.sg.mem.attack_type = "heavy_attack"

			-- TODO(jambell): commonize this
			local hitstop = TUNING.HITSTOP_PLAYER_QUICK_RISE_FRAMES
			inst.components.hitstopper:PushHitStop(hitstop)
			inst:DoTaskInAnimFrames(hitstop, function()
				if inst ~= nil and inst:IsValid() then
					if GetRemainingAmmo(inst) > 0 then
						inst.Physics:StartPassingThroughObjects()

						combatutil.StartMeleeAttack(inst)

						inst.components.hitbox:PushCircle(0, 0, ATTACKS.QUICKRISE.RADIUS, HitPriority.MOB_DEFAULT)

						UpdateAmmo(inst, 1)

						ConfigureNewDodge(inst)
						StartNewDodge(inst)
					end
				end
			end)
		end,

		onupdate = function(inst)
			DoDodgeMovement(inst, true)
		end,

		timeline =
		{
			FrameEvent(1, function(inst)
				combatutil.EndMeleeAttack(inst)
			end),
			FrameEvent(1, function(inst)
				local focus = FOCUS_SEQUENCE[GetRemainingAmmo(inst)]
				local params = {}
				params.fmodevent = fmodtable.Event.Cannon_shoot_quickrise
				params.sound_max_count = 1
				local handle = soundutil.PlaySoundData(inst, params)
				soundutil.SetInstanceParameter(inst, handle, "isFocusAttack", focus and 1 or 0)
				soundutil.SetInstanceParameter(inst, handle, "cannonHeavyShotType", 2)
				soundutil.SetInstanceParameter(inst, handle, "cannonAmmo", GetRemainingAmmo(inst))
			end),
			FrameEvent(3, function(inst)
				DoQuickRiseKickback(inst)
			end),

			--CANCELS
			FrameEvent(8, function(inst)
				inst.sg.statemem.airplant = true
				if inst.sg.statemem.triedplantearly then
					local transitiondata = { maxspeed = inst.sg.statemem.maxspeed, speed = inst.sg.statemem.speed, framessliding = inst.sg.statemem.framessliding }
					inst.sg:GoToState("blast_TO_plant", transitiondata)
				end
			end),
			FrameEvent(11, function(inst)
				inst.sg.statemem.airplant = false
				inst.sg.statemem.groundplant = true
				inst.Physics:StopPassingThroughObjects()
			end),
			FrameEvent(15, SGPlayerCommon.Fns.SetCanAttackOrAbility),
			FrameEvent(20, SGPlayerCommon.Fns.RemoveBusyState),
		},

		onexit = function(inst)
			inst.HitBox:SetInvincible(false)
			SGPlayerCommon.Fns.UndoRollPhysicsSize(inst)
			inst.Physics:StopPassingThroughObjects()
			inst.Physics:Stop()
			SGCommon.Fns.StopJumpingOverHoles(inst)
		end,


		events =
		{
			EventHandler("animover", function(inst)
				inst.sg:GoToState("idle")
			end),

			EventHandler("controlevent", function(inst, data)
				if data.control == "dodge" then
					local transitiondata = { maxspeed = inst.sg.statemem.maxspeed, speed = inst.sg.statemem.speed, framessliding = inst.sg.statemem.framessliding }
					if inst.sg.statemem.airplant then
						inst.sg:GoToState("blast_TO_plant", transitiondata)
					elseif inst.sg.statemem.groundplant then
						inst.sg:GoToState("cannon_plant_pre", transitiondata)
					else
						inst.sg.statemem.triedplantearly = true
					end
				end
			end),

			EventHandler("hitboxtriggered", OnQuickriseHitBoxTriggered),
		},
	}),

	State({
		name = "cannon_quickrise_noammo",
		tags = { "busy", "heavy_attack" },

		onenter = function(inst)
			inst.AnimState:PlayAnimation("cannon_getup_dodge")
		end,

		onupdate = function(inst)
		end,

		timeline =
		{
			FrameEvent(1, function(inst)
				--sound
				local params = {}
				params.fmodevent = fmodtable.Event.Cannon_noammo
				params.sound_max_count = 1
			end),
		},

		onexit = function(inst)
		end,


		events =
		{
			EventHandler("animover", function(inst)
				inst.sg:GoToState("idle")
			end),
		},
	}),
}

SGPlayerCommon.States.AddAllBasicStates(states)

return StateGraph("sg_player_cannon", states, events, "init")
