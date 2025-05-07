local SGCommon = require "stategraphs.sg_common"
local SGPlayerCommon = require "stategraphs.sg_player_common"
local fmodtable = require "defs.sound.fmodtable"
local lume = require "util.lume"
local combatutil = require "util.combatutil"
local soundutil = require "util.soundutil"
local Weight = require "components.weight"

local ATTACK_DAMAGE_MOD =
{
	LIGHT_ATTACK1 = 0.833, --5.0/6,
	LIGHT_ATTACK2 = 1.0,
	LIGHT_ATTACK3 = 1.083, --13.0/12,
	HEAVY_ATTACK = 1.66, --5.0/3,
	HEAVY_ATTACK_SOMERSAULT = 2.5,
	SPIN = 1.66, --5.0/3,
	REVERSE_ATTACK = 1.66, --5.0/3,
	REVERSE_ATTACK_TIER1 = 2.5,
	REVERSE_ATTACK_TIER2 = 2.91, --35.0/12,
	REVERSE_HEAVY_SPIN = { 1.41 , 1.66, 2.5 }, --{ 17.0/12, 5.0/3, 2.5 },

	--focus
	LIGHT_ATTACK1_FOCUS = 1,
	LIGHT_ATTACK2_FOCUS = 1.16, --7.0/6,
	LIGHT_ATTACK3_FOCUS = 1.25,
	HEAVY_ATTACK_FOCUS = 2.75,
	HEAVY_ATTACK_SOMERSAULT_FOCUS = 2.75, --25.0/6,
	SPIN_FOCUS = 2,
	REVERSE_ATTACK_FOCUS = 2.5,
	REVERSE_ATTACK_TIER1_FOCUS = 2.91, --35.0/12,
	REVERSE_ATTACK_TIER2_FOCUS = 4.58, --55.0/12,
	REVERSE_HEAVY_SPIN_FOCUS = { 2.5, 2.5, 5 }, --{ 1.66, 2.5, 4.58 },
}

-- expressed as anim frames
local ATTACK_HITSTUN =
{
	LIGHT_ATTACK1 = 6,
	LIGHT_ATTACK2 = 10,
	LIGHT_ATTACK3 = 12,
	HEAVY_ATTACK = 16,
	SPIN = 16,
	HEAVY_ATTACK_SOMERSAULT = 12,
	REVERSE_ATTACK = 4,
	REVERSE_ATTACK_TIER1 = 6,
	REVERSE_ATTACK_TIER2 = 8,
	REVERSE_HEAVY_SPIN = { 12, 16, 20 },
}

local ATTACK_PUSHBACK =
{
	-- % of default pushback
	LIGHT_ATTACK1 = .5,
	LIGHT_ATTACK2 = 1,
	LIGHT_ATTACK3 = 1.5,
	HEAVY_ATTACK = 1,
	SPIN = 2, --8
	REVERSE_ATTACK = 1,
	REVERSE_ATTACK_TIER1 = 1.5,
	REVERSE_ATTACK_TIER2 = 1.75,
	REVERSE_HEAVY_SPIN = { 1, 1.5, 3.5 } --apply increasing amounts of knockback per spin
}

local REVERSE_HEAVY_SPIN_HITSTOP = { HitStopLevel.MINOR, HitStopLevel.MEDIUM, HitStopLevel.MEDIUM } --apply increasing amounts of hitstop per spin, the last round will have Focus modifier applied to it, so it is already bigger

local FOCUS_TARGETS_THRESHOLD = 1 -- When more than this amount of targets are struck in one swing, every subsequent hit should be a focus
local FOCUS_HITSTOP_MULTIPLIER = 1.5
local FOCUS_HITSTUN_MULTIPLIER = 1.25

local REVERSE_HEAVY_TIER1_THRESHOLD = 8 * ANIM_FRAMES -- How many ticks have we held reverse heavy for? 3 different damage tiers based on how long you held.
local REVERSE_HEAVY_TIER2_THRESHOLD = 16 * ANIM_FRAMES

local HEAVY_SPIN_HITSTOP_MULTIPLIER = 2 -- victorc: 60Hz, review this as it may not have been intentional
local ALLOWABLE_HEAVY_SPIN_LOOPS = 2 -- technically this is 3 loops, because one of them is in the _pst state... probably could account for that in the state itself

local function OnHitBoxTriggered(inst, data)
	local damage_mod = inst.sg.statemem.damage_mod
	local hitstoplevel = inst.sg.statemem.hitstoplevel or HitStopLevel.MEDIUM
	local hitstun = inst.sg.statemem.hitstun
	local hitfx_x_offset = inst.sg.statemem.hitfx_x_offset or 1.5
	local dir
	if not inst.sg.statemem.centerhit then
		dir = inst.Transform:GetFacingRotation()
		if inst.sg.statemem.backhit then
			dir = dir + 180
		end
	end

	local focushit = false
	-- We have to check every target before we start iterating over them to do damage, so we know before we damage the first target whether we've got a focus
	for i = 1, #data.targets do
		local v = data.targets[i] -- TODO: add this target to a inst.sg.statemem.targetlist and only count v as another numtarget if we haven't hit them before? or, leave as is so hammer has a few ways to focus against single enemies
		if v.components.health then
			inst.sg.statemem.numtargets = inst.sg.statemem.numtargets + 1
		end
	end

	if inst.sg.statemem.numtargets > FOCUS_TARGETS_THRESHOLD or inst.sg.statemem.focushit then
		focushit = true
		damage_mod = inst.sg.statemem.focus_damage_mod
		hitstun = math.floor(hitstun * FOCUS_HITSTUN_MULTIPLIER)
		hitstoplevel = hitstoplevel * FOCUS_HITSTOP_MULTIPLIER
	end

	for i = 1, #data.targets do
		local v = data.targets[i]

		local attack = Attack(inst, v)
		attack:SetDamageMod(damage_mod)
		attack:SetDir(dir)
		attack:SetHitstunAnimFrames(hitstun)
		attack:SetFocus(focushit)
		attack:SetID(inst.sg.mem.attack_type)
		attack:SetNameID(inst.sg.statemem.attack_id)

		if inst.sg.statemem.knockdownhit then
			inst:ShakeCamera(CAMERASHAKE.FULL, .3, .02, .3)
			inst.components.combat:DoKnockdownAttack(attack)
		elseif inst.sg.statemem.knockbackhit then
			inst:ShakeCamera(CAMERASHAKE.VERTICAL, .3, .02, .3)
			inst.components.combat:DoKnockbackAttack(attack)
		else
			attack:SetPushback(inst.sg.statemem.pushback)
			inst.components.combat:DoBasicAttack(attack)
		end

		hitstoplevel = SGCommon.Fns.ApplyHitstop(attack, hitstoplevel)

		-- Because the hammer's swing arc is so big, we want to adjust the y_offset for this weapon to account for the size of the target
		local hitfx_y_offset = 1.75
		local target_size = lume.round(v.Physics:GetSize(), 0.1)
		if target_size < 1.4 then
			--SMALL
			hitfx_y_offset = hitfx_y_offset - 0.5
		elseif target_size >= 1.4 and target_size < 1.8 then
			--MEDIUM
			hitfx_y_offset = hitfx_y_offset
		else
			--LARGE
			hitfx_y_offset = hitfx_y_offset + 0.25
		end

		inst.components.combat:SpawnHitFxForPlayerAttack(attack, "hits_player_blunt", v, inst, hitfx_x_offset, hitfx_y_offset, dir, hitstoplevel)
		if hitstoplevel > HitStopLevel.MAJOR then -- plays an extra sound layer if we land a big hitstop impact
			local params = {}
			params.fmodevent = fmodtable.Event.Hit_blunt_heavy
			params.sound_max_count = 1
			soundutil.PlaySoundData(inst, params)
		end
		SpawnHurtFx(inst, v, hitfx_x_offset, dir, hitstoplevel)
	end
end

local events = {}

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
		name = "default_light_attack",
		onenter = function(inst) inst.sg:GoToState("light_attack1") end,
	}),

	State({
		name = "default_heavy_attack",
		onenter = function(inst) inst.sg:GoToState("heavy_attack_jump_pre") end,
	}),

	State({
		name = "default_dodge",
		onenter = function(inst)
			local weight = inst.components.weight:GetStatus()
			inst.sg:GoToState(roll_states[weight])
		end,
	}),

	State({
		name = "light_attack1",
		tags = { "attack", "busy", "light_attack" },

		onenter = function(inst)
			inst:PushEvent("attack_state_start")
			inst.AnimState:PlayAnimation("hammer_atk1")
			inst.sg.statemem.numtargets = 0
			inst.components.playercontroller:OverrideControlQueueTicks("dodge", 8 * ANIM_FRAMES)
			inst.sg.statemem.attack_id = "LIGHT_ATTACK_1"
		end,

		timeline =
		{
			--sounds
			FrameEvent(1, function(inst)
				local params = {}
				params.fmodevent = fmodtable.Event.Hammer_atk_1
				params.sound_max_count = 1
				soundutil.PlaySoundData(inst, params)
			end),
			--

			--physics
			FrameEvent(3, function(inst) SGCommon.Fns.SetMotorVelScaled(inst, 3) end),
			FrameEvent(4, function(inst) SGCommon.Fns.SetMotorVelScaled(inst, 1) end),
			FrameEvent(5, function(inst) SGCommon.Fns.SetMotorVelScaled(inst, .5) end),
			FrameEvent(6, function(inst) SGCommon.Fns.SetMotorVelScaled(inst, .25) end),
			FrameEvent(7, function(inst) inst.Physics:Stop() end),
			--

			FrameEvent(4, function(inst)
				combatutil.StartMeleeAttack(inst)

				inst.components.hitbox:StartRepeatTargetDelay()
				--SGPlayerCommon.Fns.AttachSwipeFx(inst, "fx_hammer_atk1")
				--SGPlayerCommon.Fns.AttachPowerSwipeFx(inst, "fx_hammer_atk1")
				inst.sg.statemem.damage_mod = ATTACK_DAMAGE_MOD.LIGHT_ATTACK1
				inst.sg.statemem.focus_damage_mod = ATTACK_DAMAGE_MOD.LIGHT_ATTACK1_FOCUS
				inst.sg.statemem.hitstun = ATTACK_HITSTUN.LIGHT_ATTACK1
				inst.sg.statemem.pushback = ATTACK_PUSHBACK.LIGHT_ATTACK1
				inst.components.hitbox:PushBeam(0, 2.7, 2.3, HitPriority.PLAYER_DEFAULT)
			end),


			FrameEvent(5, function(inst)
				inst.components.hitbox:PushBeam(-0.3, 0.5, 1.2, HitPriority.PLAYER_DEFAULT)

				combatutil.EndMeleeAttack(inst)
			end),

			-- CANCELS:
			-- dodge window before attack
			-- FrameEvent(0, SGPlayerCommon.Fns.SetCanDodge),
			-- FrameEvent(4, SGPlayerCommon.Fns.SetCannotDodge),

			-- 
			FrameEvent(8, SGPlayerCommon.Fns.SetCanDodge),
			FrameEvent(8, function(inst)
				inst.sg.statemem.lightcombostate = "light_attack2"
				SGPlayerCommon.Fns.TryQueuedAction(inst, "lightattack")

				inst.sg.statemem.heavycombostate = "default_heavy_attack"
				SGPlayerCommon.Fns.TryQueuedAction(inst, "heavyattack")
			end),
		},

		events =
		{
			EventHandler("hitboxtriggered", OnHitBoxTriggered),
			EventHandler("animover", function(inst)
				inst.sg:GoToState("light_attack1_pst")
			end),
		},

		onexit = function(inst)
			inst.Physics:Stop()
			SGPlayerCommon.Fns.DetachSwipeFx(inst)
			SGPlayerCommon.Fns.DetachPowerSwipeFx(inst)
			inst.components.hitbox:StopRepeatTargetDelay()
			inst.components.playercontroller:OverrideControlQueueTicks("dodge", nil)
		end,
	}),

	State({
		name = "light_attack1_pst",
		tags = { "light_attack" },

		onenter = function(inst)
			inst.AnimState:PlayAnimation("hammer_atk1_pst")
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
		name = "light_attack2",
		tags = { "attack", "busy", "light_attack" },

		onenter = function(inst)
			inst:PushEvent("attack_state_start")
			inst.AnimState:PlayAnimation("hammer_atk2")
			inst.sg.statemem.numtargets = 0
			inst.sg.statemem.heavycombostate = nil
			inst.Physics:Stop()
			inst.components.playercontroller:OverrideControlQueueTicks("dodge", 10 * ANIM_FRAMES)
			inst.sg.statemem.attack_id = "LIGHT_ATTACK_2"
		end,

		onupdate = function(inst)
			if inst.sg.statemem.speed ~= nil then
				inst.sg.statemem.speed = inst.sg.statemem.speed * .8
				SGCommon.Fns.SetMotorVelScaled(inst, inst.sg.statemem.speed)
			end
		end,

		timeline =
		{
			FrameEvent(0, function(inst) inst.sg.statemem.heavycombostate = nil end),
			--sounds
			FrameEvent(4, function(inst)
				local params = {}
				params.fmodevent = fmodtable.Event.Hammer_atk_2
				params.sound_max_count = 1
				soundutil.PlaySoundData(inst, params)
			end),
			--

			--physics
			FrameEvent(3, function(inst) inst.sg.statemem.speed = 10 end),
			--

			FrameEvent(4, function(inst)
				combatutil.StartMeleeAttack(inst)

				inst.sg:AddStateTag("airborne")
				--SGPlayerCommon.Fns.AttachSwipeFx(inst, "fx_hammer_atk2")
				--SGPlayerCommon.Fns.AttachPowerSwipeFx(inst, "fx_hammer_atk2")
				inst.sg.statemem.damage_mod = ATTACK_DAMAGE_MOD.LIGHT_ATTACK2
				inst.sg.statemem.focus_damage_mod = ATTACK_DAMAGE_MOD.LIGHT_ATTACK2_FOCUS
				inst.sg.statemem.hitstun = ATTACK_HITSTUN.LIGHT_ATTACK2
				inst.sg.statemem.pushback = ATTACK_PUSHBACK.LIGHT_ATTACK2
				inst.components.hitbox:PushBeam(0, 2.7, 2.5, HitPriority.PLAYER_DEFAULT)
			end),

			FrameEvent(5, function(inst)
				combatutil.EndMeleeAttack(inst)
			end),

			-- CANCELS
			-- FrameEvent(0, SGPlayerCommon.Fns.SetCanDodge),
			-- FrameEvent(4, SGPlayerCommon.Fns.SetCannotDodge),
			-- FrameEvent(10, SGPlayerCommon.Fns.SetCanDodge),

			FrameEvent(8, function(inst)
				inst.sg.statemem.heavycombostate = "heavy_attack_air_pre"
				SGPlayerCommon.Fns.TryQueuedAction(inst, "heavyattack")
			end),
			FrameEvent(10, function(inst)
				inst.sg.statemem.lightcombostate = "light_attack3_pre"
				SGPlayerCommon.Fns.TryQueuedAction(inst, "lightattack")
			end),
		},

		events =
		{
			EventHandler("hitboxtriggered", OnHitBoxTriggered),
			EventHandler("animover", function(inst)
				inst.sg:GoToState("light_attack2_pst")
			end),
		},

		onexit = function(inst)
			inst.Physics:Stop()
			SGPlayerCommon.Fns.DetachSwipeFx(inst)
			SGPlayerCommon.Fns.DetachPowerSwipeFx(inst)
			inst.components.playercontroller:OverrideControlQueueTicks("dodge", nil)
		end,
	}),

	State({
		name = "light_attack2_pst",
		tags = { "busy", "light_attack" },

		onenter = function(inst)
			inst.AnimState:PlayAnimation("hammer_atk2_pst")
			SGPlayerCommon.Fns.TryQueuedAction(inst, "dodge")
		end,

		timeline =
		{
			FrameEvent(0, SGPlayerCommon.Fns.SetCanDodge),
			FrameEvent(6, SGPlayerCommon.Fns.SetCanAttackOrAbility),
			FrameEvent(6, SGPlayerCommon.Fns.RemoveBusyState),
		},

		events =
		{
			EventHandler("animover", function(inst)
				inst.sg:GoToState("idle")
			end),
		},
	}),

	State({
		name = "light_attack3_pre",
		tags = { "attack", "busy", "airborne", "light_attack" },

		onenter = function(inst)
			inst:PushEvent("attack_state_start")
			inst.AnimState:PlayAnimation("hammer_atk3_pre")
		end,

		events =
		{
			EventHandler("animover", function(inst)
				inst.sg:GoToState("light_attack3", { speedmult = 1, cancombotolight2 = false })
			end),
		},
	}),

	State({
		name = "fade_to_light_attack3_pre",
		tags = { "attack", "busy", "airborne", "light_attack" },

		onenter = function(inst)
			inst.AnimState:PlayAnimation("hammer_fade_to_roll_atk3_pre")
			inst.AnimState:PushAnimation("hammer_roll_atk3_pre")
		end,

		timeline =
		{
			--physics
			FrameEvent(0, function(inst) SGCommon.Fns.SetMotorVelScaled(inst, 3) end),
			--Start of "hammer_roll_atk3_pre"
			FrameEvent(2, function(inst) SGCommon.Fns.SetMotorVelScaled(inst, 6) end),
			--
		},

		events =
		{
			EventHandler("animqueueover", function(inst)
				inst.sg.statemem.attacking = true
				inst.sg:GoToState("light_attack3", { speedmult = 1.1, cancombotolight2 = true })
			end),
		},

		onexit = function(inst)
			if not inst.sg.statemem.attacking then
				inst.Physics:Stop()
			end
		end,
	}),

	State({
		name = "rolling_light_attack3_pre",
		tags = { "attack", "busy", "airborne", "light_attack" },

		onenter = function(inst)
			inst:PushEvent("attack_state_start")
			inst.AnimState:PlayAnimation("hammer_roll_atk3_pre")
		end,

		timeline =
		{
			FrameEvent(0, function(inst) SGCommon.Fns.SetMotorVelScaled(inst, 7) end),
		},

		events =
		{
			EventHandler("animover", function(inst)
				inst.sg.statemem.attacking = true
				inst.sg:GoToState("light_attack3", { speedmult = 1.25, cancombotolight2 = true })
				if inst.sg:GetCurrentState() == "light_attack3" then
					inst.sg.statemem.hitstoplevel = HitStopLevel.MEDIUM
				end
			end),
		},

		onexit = function(inst)
			if not inst.sg.statemem.attacking then
				inst.Physics:Stop()
			end
		end,
	}),

	State({
		name = "light_attack3",
		tags = { "attack", "busy", "airborne", "light_attack" },

		onenter = function(inst, data) --data = speedmult, cancombotolight1
			inst.AnimState:PlayAnimation("hammer_atk3")
			inst.sg.statemem.speedmult = data.speedmult or 1
			inst.sg.statemem.cancombotolight2 = data.cancombotolight2
			inst.sg.statemem.numtargets = 0

			inst.components.playercontroller:OverrideControlQueueTicks("dodge", 9 * ANIM_FRAMES)

			inst.sg.statemem.attack_id = "LIGHT_ATTACK_3"
		end,

		timeline =
		{
			FrameEvent(2, function(inst)
				local params = {}
				params.fmodevent = fmodtable.Event.Hammer_atk_3
				params.sound_max_count = 1
				soundutil.PlaySoundData(inst, params)
			end),
			--

			--physics
			FrameEvent(0, function(inst) SGCommon.Fns.SetMotorVelScaled(inst, 8 * inst.sg.statemem.speedmult) end),
			FrameEvent(2, function(inst) SGCommon.Fns.SetMotorVelScaled(inst, 4 * inst.sg.statemem.speedmult) end),
			FrameEvent(3, function(inst) SGCommon.Fns.SetMotorVelScaled(inst, 1.6 * inst.sg.statemem.speedmult) end),
			FrameEvent(4, function(inst) SGCommon.Fns.SetMotorVelScaled(inst, .8 * inst.sg.statemem.speedmult) end),
			FrameEvent(5, function(inst) SGCommon.Fns.SetMotorVelScaled(inst, .4 * inst.sg.statemem.speedmult) end),
			FrameEvent(6, function(inst) SGCommon.Fns.SetMotorVelScaled(inst, .2 * inst.sg.statemem.speedmult) end),
			FrameEvent(7, function(inst) inst.Physics:Stop() end),
			--

			FrameEvent(2, function(inst)
				combatutil.StartMeleeAttack(inst)

				inst.sg:RemoveStateTag("airborne")
				--SGPlayerCommon.Fns.AttachSwipeFx(inst, "fx_hammer_atk3")
				--SGPlayerCommon.Fns.AttachPowerSwipeFx(inst, "fx_hammer_atk3")
				inst.sg.statemem.damage_mod = ATTACK_DAMAGE_MOD.LIGHT_ATTACK3
				inst.sg.statemem.focus_damage_mod = ATTACK_DAMAGE_MOD.LIGHT_ATTACK3_FOCUS
				inst.sg.statemem.hitstun = ATTACK_HITSTUN.LIGHT_ATTACK3
				inst.sg.statemem.pushback = ATTACK_PUSHBACK.LIGHT_ATTACK3
				inst.components.hitbox:StartRepeatTargetDelay()
				inst.components.hitbox:PushBeam(0, 3.2, 2.5, HitPriority.PLAYER_DEFAULT)
			end),

			FrameEvent(3, function(inst)
				inst.components.hitbox:PushBeam(-0.8, 0.5, 1.2, HitPriority.PLAYER_DEFAULT)

				combatutil.EndMeleeAttack(inst)
			end),
			FrameEvent(5, SGPlayerCommon.Fns.DetachSwipeFx),
			FrameEvent(5, SGPlayerCommon.Fns.DetachPowerSwipeFx),

			-- CANCELS
			FrameEvent(4, SGPlayerCommon.Fns.SetCanDodge),

			FrameEvent(8, function(inst)
				if inst.sg.statemem.cancombotolight2 then
					inst.sg.statemem.lightcombostate = "light_attack2"
					SGPlayerCommon.Fns.TryQueuedAction(inst, "lightattack")
				end
				inst.sg.statemem.heavycombostate = "heavy_overhead_slam_pre"
				SGPlayerCommon.Fns.TryQueuedAction(inst, "heavyattack")
			end),

		},

		events =
		{
			EventHandler("hitboxtriggered", OnHitBoxTriggered),
			EventHandler("animover", function(inst)
				inst.sg:GoToState("light_attack3_pst")
			end),
		},

		onexit = function(inst)
			inst.Physics:Stop()
			SGPlayerCommon.Fns.DetachSwipeFx(inst)
			SGPlayerCommon.Fns.DetachPowerSwipeFx(inst)
			inst.components.hitbox:StopRepeatTargetDelay()
			inst.components.playercontroller:OverrideControlQueueTicks("dodge", nil)
		end,
	}),


	State({
		name = "light_attack3_pst",
		tags = { "busy", "light_attack" },

		onenter = function(inst)
			inst.AnimState:PlayAnimation("hammer_atk1_pst")
			SGPlayerCommon.Fns.TryQueuedAction(inst, "dodge")
		end,

		timeline =
		{
			FrameEvent(0, function(inst)
				SGPlayerCommon.Fns.SetCanDodge(inst)
				inst.sg.statemem.heavycombostate = "heavy_overhead_slam_pre"
				SGPlayerCommon.Fns.TryQueuedAction(inst, "heavyattack")
			end),
			FrameEvent(3, SGPlayerCommon.Fns.RemoveBusyState),
		},

		events =
		{
			EventHandler("animover", function(inst)
				inst.sg:GoToState("idle")
			end),
		},
	}),

	State({
		name = "heavy_overhead_slam_pre",
		tags = { "attack", "busy", "heavy_attack" },

		onenter = function(inst, sliding)
			inst:PushEvent("attack_state_start")
			inst.AnimState:PlayAnimation("hammer_atk4_pre")
			inst.sg.statemem.speedmult = sliding and 1 or 0
			inst.sg.statemem.held = inst.components.playercontroller:IsControlHeld("heavyattack")
		end,

		timeline =
		{
			--physics
			FrameEvent(0, function(inst) SGCommon.Fns.SetMotorVelScaled(inst, -3 * inst.sg.statemem.speedmult) end),
			FrameEvent(2, function(inst) SGCommon.Fns.SetMotorVelScaled(inst, -2 * inst.sg.statemem.speedmult) end),
			FrameEvent(3, function(inst) SGCommon.Fns.SetMotorVelScaled(inst, -1.5 * inst.sg.statemem.speedmult) end),
			FrameEvent(4, function(inst) SGCommon.Fns.SetMotorVelScaled(inst, -1 * inst.sg.statemem.speedmult) end),
			FrameEvent(5, function(inst) SGCommon.Fns.SetMotorVelScaled(inst, -.5 * inst.sg.statemem.speedmult) end),
			FrameEvent(6, function(inst) inst.Physics:Stop() end),
			FrameEvent(6, function(inst) inst:SnapToFacingRotation() end),
			--


			FrameEvent(11, function(inst)
				--Must have been holding at least throughout this entire state
				if inst.sg.statemem.held then
					dbassert(inst.components.playercontroller:GetControlHeldTicks("heavyattack") >= inst.sg:GetTicksInState())
					--NOTE: Use GetTicksInState() to account for pausing (e.g. hit stops)
					inst.sg.statemem.holdframe = inst.sg:GetTicksInState()
				else
					inst.sg.statemem.attacking = true
					inst.sg:GoToState("heavy_overhead_slam")
				end
			end),

			FrameEvent(16, function(inst)
				SGCommon.Fns.FlickerSymbolBloom(inst, "weapon_back01", TUNING.FLICKERS.WEAPONS.HAMMER.CHARGE_COMPLETE.COLOR, TUNING.FLICKERS.WEAPONS.HAMMER.CHARGE_COMPLETE.FLICKERS, TUNING.FLICKERS.WEAPONS.HAMMER.CHARGE_COMPLETE.FADE, TUNING.FLICKERS.WEAPONS.HAMMER.CHARGE_COMPLETE.TWEENS)
			end),
			FrameEvent(20, function(inst)
				inst.AnimState:SetSymbolBloom("weapon_back01", TUNING.FLICKERS.WEAPONS.HAMMER.FOCUS_SWING.COLOR[1], TUNING.FLICKERS.WEAPONS.HAMMER.FOCUS_SWING.COLOR[2], TUNING.FLICKERS.WEAPONS.HAMMER.FOCUS_SWING.COLOR[3], TUNING.FLICKERS.WEAPONS.HAMMER.FOCUS_SWING.COLOR[4])
				inst.AnimState:SetSymbolBloom("weapon_back01", TUNING.FLICKERS.WEAPONS.HAMMER.FOCUS_SWING.COLOR[1], TUNING.FLICKERS.WEAPONS.HAMMER.FOCUS_SWING.COLOR[2], TUNING.FLICKERS.WEAPONS.HAMMER.FOCUS_SWING.COLOR[3], TUNING.FLICKERS.WEAPONS.HAMMER.FOCUS_SWING.COLOR[4])
			end),

			-- CANCELS
			FrameEvent(6, SGPlayerCommon.Fns.SetCanDodge),
		},

		events =
		{
			EventHandler("controlupevent", function(inst, data)
				if data.control == "heavyattack" then
					if inst.sg.statemem.holdframe ~= nil then
						inst.sg.statemem.attacking = true
						inst.sg:GoToState("heavy_overhead_slam", inst.sg:GetTicksInState())
					else
						inst.sg.statemem.held = false
					end
				end
			end),
			EventHandler("animover", function(inst)
				inst.sg.statemem.attacking = true
				inst.sg:GoToState("heavy_overhead_slam", inst.sg:GetTicksInState())
			end),
		},

		onexit = function(inst)
			if not inst.sg.statemem.attacking then
				inst.Physics:Stop()
			end
			inst.AnimState:SetSymbolBloom("weapon_back01", 0, 0, 0, 0)
		end,
	}),

	State({
		name = "heavy_overhead_slam",
		tags = { "attack", "busy", "nointerrupt", "heavy_attack" },

		onenter = function(inst, heldticks)
			inst.AnimState:PlayAnimation("hammer_atk4")
			inst.sg.statemem.speedmult = heldticks ~= nil and 1 + math.min(10, heldticks) * .025 or 1
			-- inst.components.combat:SetDamageReceivedMult("superarmor", .2)
			inst.sg.statemem.knockbackhit = true
			inst.sg.statemem.numtargets = 0
			inst.sg.statemem.heldticks = heldticks

			inst.components.playercontroller:OverrideControlQueueTicks("dodge", 12 * ANIM_FRAMES)

			inst.sg.statemem.attack_id = "HEAVY_SLAM"
		end,

		timeline =
		{
			--physics
			FrameEvent(0, function(inst) SGCommon.Fns.SetMotorVelScaled(inst, 3.5 * inst.sg.statemem.speedmult) end),
			FrameEvent(1, function(inst) SGCommon.Fns.SetMotorVelScaled(inst, 6 * inst.sg.statemem.speedmult) end),
			FrameEvent(4, function(inst) SGCommon.Fns.SetMotorVelScaled(inst, 2 * inst.sg.statemem.speedmult) end),
			FrameEvent(4, function(inst) inst.sg.statemem.speedmult = .5 + .5 * inst.sg.statemem.speedmult end),
			FrameEvent(5, function(inst) SGCommon.Fns.SetMotorVelScaled(inst, 1.5 * inst.sg.statemem.speedmult) end),
			FrameEvent(6, function(inst) SGCommon.Fns.SetMotorVelScaled(inst, 1 * inst.sg.statemem.speedmult) end),
			FrameEvent(7, function(inst) SGCommon.Fns.SetMotorVelScaled(inst, 0.5 * inst.sg.statemem.speedmult) end),
			FrameEvent(8, function(inst) SGCommon.Fns.SetMotorVelScaled(inst, .25 * inst.sg.statemem.speedmult) end),
			FrameEvent(9, function(inst) SGCommon.Fns.SetMotorVelScaled(inst, .125 * inst.sg.statemem.speedmult) end),
			FrameEvent(10, function(inst) inst.Physics:Stop() end),
			--

			--focus hit charge highlights
			FrameEvent(0, function(inst)
				if inst.sg.statemem.heldticks and inst.sg.statemem.heldticks >= REVERSE_HEAVY_TIER2_THRESHOLD then
					inst.AnimState:SetSymbolBloom("weapon_back01", TUNING.FLICKERS.WEAPONS.HAMMER.FOCUS_SWING.COLOR[1], TUNING.FLICKERS.WEAPONS.HAMMER.FOCUS_SWING.COLOR[2], TUNING.FLICKERS.WEAPONS.HAMMER.FOCUS_SWING.COLOR[3], TUNING.FLICKERS.WEAPONS.HAMMER.FOCUS_SWING.COLOR[4])
				end
			end),
			FrameEvent(5, function(inst)
				inst.AnimState:SetSymbolBloom("weapon_back01", 0, 0, 0, 0)
			end),
			--

			--FrameEvent(4, function(inst) SGPlayerCommon.Fns.AttachSwipeFx(inst, "fx_hammer_smash_air") end), --SLOTH/JAMBELL: replace with 'hammer_atk4' fx
			--FrameEvent(4, function(inst)
				--SGPlayerCommon.Fns.AttachPowerSwipeFx(inst, "fx_hammer_smash_air") --SLOTH/JAMBELL: replace with 'hammer_atk4' fx
			--end),
			FrameEvent(5, function(inst)
				combatutil.StartMeleeAttack(inst)

				inst.sg.statemem.hitboxmult = 1
				--SGPlayerCommon.Fns.AttachSwipeFx(inst, "fx_hammer_reverse_atk")
				if inst.sg.statemem.heldticks and inst.sg.statemem.heldticks >= REVERSE_HEAVY_TIER2_THRESHOLD then
					inst.sg.statemem.damage_mod = ATTACK_DAMAGE_MOD.REVERSE_ATTACK_TIER2
					inst.sg.statemem.focus_damage_mod = ATTACK_DAMAGE_MOD.REVERSE_ATTACK_TIER2_FOCUS
					inst.sg.statemem.hitstun = ATTACK_HITSTUN.REVERSE_ATTACK_TIER2
					inst.sg.statemem.pushback = ATTACK_PUSHBACK.REVERSE_ATTACK_TIER2
					inst.sg.statemem.hitboxmult = 1.2
					inst.sg.statemem.chargedtier = 2
					inst.sg.statemem.knockdownhit = true
					inst.sg.statemem.focushit = true
					inst.sg.statemem.additionalfx = "fx_hammer_overhead_swipe_full"
					local params = {}
					params.fmodevent = fmodtable.Event.Hammer_atk_overhead_focus_whoosh
					params.autostop = 1
					params.sound_max_count = 1
					soundutil.PlaySoundData(inst, params)
					
				elseif inst.sg.statemem.heldticks and inst.sg.statemem.heldticks >= REVERSE_HEAVY_TIER1_THRESHOLD	then
					inst.sg.statemem.damage_mod = ATTACK_DAMAGE_MOD.REVERSE_ATTACK_TIER1
					inst.sg.statemem.focus_damage_mod = ATTACK_DAMAGE_MOD.REVERSE_ATTACK_TIER1_FOCUS
					inst.sg.statemem.hitstun = ATTACK_HITSTUN.REVERSE_ATTACK_TIER1
					inst.sg.statemem.pushback = ATTACK_PUSHBACK.REVERSE_ATTACK_TIER1
					inst.sg.statemem.hitboxmult = 1.1
					inst.sg.statemem.chargedtier = 1
					inst.sg.statemem.knockbackhit = true
					inst.sg.statemem.additionalfx = "fx_hammer_overhead_swipe_mid"
				else
					inst.sg.statemem.damage_mod = ATTACK_DAMAGE_MOD.REVERSE_ATTACK
					inst.sg.statemem.focus_damage_mod = ATTACK_DAMAGE_MOD.REVERSE_ATTACK_FOCUS
					inst.sg.statemem.hitstun = ATTACK_HITSTUN.REVERSE_ATTACK
					inst.sg.statemem.pushback = ATTACK_PUSHBACK.REVERSE_ATTACK
					inst.sg.statemem.chargedtier = 0
				end

				inst.sg.statemem.hitstoplevel = HitStopLevel.MAJOR
				inst.components.hitbox:StartRepeatTargetDelay()
				inst.components.hitbox:PushBeam(0, 4.2 * inst.sg.statemem.hitboxmult, 2.5, HitPriority.PLAYER_DEFAULT)

				if inst.sg.statemem.additionalfx ~= nil then
					SGPlayerCommon.Fns.AttachExtraSwipeFx(inst, inst.sg.statemem.additionalfx)
				end
			end),
			FrameEvent(6, function(inst)
				inst.components.hitbox:PushBeam(0, 4.2 * inst.sg.statemem.hitboxmult, 2.5, HitPriority.PLAYER_DEFAULT)
				combatutil.EndMeleeAttack(inst)
			end),
			FrameEvent(7, function(inst)
				inst.AnimState:SetSymbolBloom("weapon_back01", 0, 0, 0, 0)
				inst.sg:RemoveStateTag("nointerrupt")
				SGPlayerCommon.Fns.DetachSwipeFx(inst)
				SGPlayerCommon.Fns.DetachPowerSwipeFx(inst)
				SGPlayerCommon.Fns.DetachExtraSwipeFx(inst)
				-- inst.components.combat:SetDamageReceivedMult("superarmor", nil)
			end),

			-- CANCELS
			FrameEvent(0, SGPlayerCommon.Fns.SetCanDodge),
			FrameEvent(4, SGPlayerCommon.Fns.SetCannotDodge),

			FrameEvent(13, function(inst)
				SGPlayerCommon.Fns.SetCanDodge(inst)
				SGPlayerCommon.Fns.SetCanAttackOrAbility(inst)
			end),

			-- FrameEvent(16, function(inst)
			-- 	if inst.sg.statemem.chargedtier == 1 then
			-- 		SGPlayerCommon.Fns.SetCanDodge(inst)
			-- 		SGPlayerCommon.Fns.SetCanAttackOrAbility(inst)
			-- 	end
			-- end),
			-- FrameEvent(19, function(inst)
			-- 	if inst.sg.statemem.chargedtier == 2 then
			-- 		SGPlayerCommon.Fns.SetCanDodge(inst)
			-- 		SGPlayerCommon.Fns.SetCanAttackOrAbility(inst)
			-- 	end
			-- end),
		},

		events =
		{
			EventHandler("hitboxtriggered", OnHitBoxTriggered),
			EventHandler("animover", function(inst)
				inst.sg:GoToState("heavy_overhead_slam_pst", inst.sg.statemem.chargedtier)
			end),
		},

		onexit = function(inst)
			inst.Physics:Stop()
			SGPlayerCommon.Fns.DetachSwipeFx(inst)
			SGPlayerCommon.Fns.DetachPowerSwipeFx(inst)
			inst.components.hitbox:StopRepeatTargetDelay()
			-- inst.components.combat:SetDamageReceivedMult("superarmor", nil)
			inst.AnimState:SetSymbolBloom("weapon_back01", 0, 0, 0, 0)
			inst.components.playercontroller:OverrideControlQueueTicks("dodge", nil)
		end,
	}),

	State({
		name = "heavy_overhead_slam_pst",
		tags = { "busy", "heavy_attack" },

		onenter = function(inst, chargedtier)
			inst.AnimState:PlayAnimation("hammer_smash_pst")
			inst.sg.statemem.chargedtier = chargedtier
		end,

		timeline =
		{
			FrameEvent(15, SGPlayerCommon.Fns.RemoveBusyState),
		},

		events =
		{
			EventHandler("animover", function(inst)
				inst.sg:GoToState("idle")
			end),
		},
	}),

	State({
		name = "heavy_attack_air_pre",
		tags = { "attack", "busy", "airborne", "airborne_high", "heavy_attack" },

		onenter = function(inst, speedmult)
			inst.AnimState:PlayAnimation("hammer_smash_air_pre")
			if speedmult ~= nil then
				--came from ground jump
				inst.sg.statemem.speedmult = speedmult
			else
				--came from air combo
				inst.sg.statemem.speedmult = 1
				inst.sg.statemem.canspinattack = true
			end
			SGCommon.Fns.StartJumpingOverHoles(inst)
			inst.components.playercontroller:OverrideControlQueueTicks("dodge", 22 * ANIM_FRAMES) -- Enough to last until we land in "heavy_attack_air"
		end,

		timeline =
		{
			--physics
			FrameEvent(0, function(inst) SGCommon.Fns.SetMotorVelScaled(inst, 3.5 * inst.sg.statemem.speedmult) end),
			FrameEvent(1, function(inst) SGCommon.Fns.SetMotorVelScaled(inst, 3 * inst.sg.statemem.speedmult) end),
			FrameEvent(2, function(inst) SGCommon.Fns.SetMotorVelScaled(inst, 2.5 * inst.sg.statemem.speedmult) end),
			FrameEvent(3, function(inst) SGCommon.Fns.SetMotorVelScaled(inst, 2 * inst.sg.statemem.speedmult) end),
			FrameEvent(4, function(inst) SGCommon.Fns.SetMotorVelScaled(inst, 2.5 * inst.sg.statemem.speedmult) end),
			--
		},

		events =
		{
			EventHandler("animover", function(inst)
				inst.sg.statemem.attacking = true

				if inst.sg.statemem.canspinattack then
					inst.sg.statemem.heavycombostate = "spinning_heavy_attack_air"
					if inst.components.playercontroller:IsControlHeld("heavyattack") then
						inst.sg:GoToState("spinning_heavy_attack_air")
						return
					elseif SGPlayerCommon.Fns.TryQueuedAction(inst, "heavyattack") then
						return
					end
				end

				inst.sg:GoToState("heavy_attack_air", { speedmult = inst.sg.statemem.speedmult, dodgerequested = inst.sg.statemem.dodgerequested })
			end),

			EventHandler("controlevent", function(inst, data)
				if data.control == "dodge" then
					inst.sg.statemem.dodgerequested = true
				end
			end),
		},

		onexit = function(inst)
			if not inst.sg.statemem.attacking then
				inst.Physics:Stop()
			end
			SGCommon.Fns.StopJumpingOverHoles(inst)
			inst.components.playercontroller:OverrideControlQueueTicks("dodge", nil) -- Enough to last until we land in "heavy_attack_air"
		end,
	}),

	State({
		name = "heavy_attack_air",
		tags = { "attack", "busy", "airborne", "airborne_high", "heavy_attack" },

		onenter = function(inst, data)
			inst.AnimState:PlayAnimation("hammer_smash_air")
			inst.sg.statemem.speedmult = data.speedmult or 1
			inst.sg.statemem.dodgerequested = data.dodgerequested or false
			inst.sg.statemem.numtargets = 0
			SGCommon.Fns.StartJumpingOverHoles(inst)
			inst.components.playercontroller:OverrideControlQueueTicks("dodge", 12 * ANIM_FRAMES)

			inst.sg.statemem.attack_id = "HEAVY_ATTACK"
		end,

		timeline =
		{
			--sounds
			FrameEvent(0, function(inst)
				local params = {}
				params.fmodevent = fmodtable.Event.Hammer_atk_overhead
				params.sound_max_count = 1
				soundutil.PlaySoundData(inst, params)
			end),
			FrameEvent(4, function(inst)
				local params = {}
				params.fmodevent = fmodtable.Event.Hammer_atk_overhead_impact
				params.sound_max_count = 1
				soundutil.PlaySoundData(inst, params)
			end),
			--

			--physics
			FrameEvent(0, function(inst) SGCommon.Fns.SetMotorVelScaled(inst, 5 + 3 * inst.sg.statemem.speedmult) end),
			FrameEvent(3, function(inst) SGCommon.Fns.SetMotorVelScaled(inst, 2) end),
			FrameEvent(4, function(inst) SGCommon.Fns.SetMotorVelScaled(inst, 1) end),
			FrameEvent(5, function(inst) inst.Physics:Stop() end),
			--

			FrameEvent(4, function(inst)
				combatutil.StartMeleeAttack(inst)

				inst.sg:RemoveStateTag("airborne") -- these actually happen on FrameEvent3, but to give the player a bit of leeway, I'm giving them an extra frame
				inst.sg:RemoveStateTag("airborne_high")
				SGCommon.Fns.StopJumpingOverHoles(inst)

				inst:ShakeCamera(CAMERASHAKE.VERTICAL, .3, .02, .15, inst, 10)
				inst.sg.statemem.damage_mod = ATTACK_DAMAGE_MOD.HEAVY_ATTACK
				inst.sg.statemem.focus_damage_mod = ATTACK_DAMAGE_MOD.HEAVY_ATTACK_FOCUS
				inst.sg.statemem.hitstun = ATTACK_HITSTUN.HEAVY_ATTACK
				inst.sg.statemem.pushback = ATTACK_PUSHBACK.HEAVY_ATTACK
				inst.sg.statemem.hitstoplevel = HitStopLevel.MEDIUM
				inst.sg.statemem.knockbackhit = true
				inst.components.hitbox:StartRepeatTargetDelay()
				inst.components.hitbox:PushBeam(1, 4.7, 3.0, HitPriority.PLAYER_DEFAULT)

			end),
			FrameEvent(5, function(inst)
				inst.components.hitbox:PushBeam(1, 4.7, 3.0, HitPriority.PLAYER_DEFAULT)

			end),
			FrameEvent(6, function(inst)
				SGPlayerCommon.Fns.DetachSwipeFx(inst)
				SGPlayerCommon.Fns.DetachPowerSwipeFx(inst)
				inst.components.hitbox:PushBeam(1, 4.7, 3.0, HitPriority.PLAYER_DEFAULT)
				combatutil.EndMeleeAttack(inst)
			end),


			-- CANCELS
			FrameEvent(9, function(inst)
				SGPlayerCommon.Fns.SetCanSkill(inst)
				SGPlayerCommon.Fns.SetCanDodge(inst)
			end),

			-- FrameEvent(15, function(inst)
			-- 	inst.sg.statemem.lightcombostate = "default_light_attack"
			-- 	SGPlayerCommon.Fns.TryQueuedAction(inst, "lightattack")
			-- end),
		},

		events =
		{
			EventHandler("hitboxtriggered", OnHitBoxTriggered),
			EventHandler("animover", function(inst)
				inst.sg:GoToState("heavy_attack_air_pst")
			end),
		},

		onexit = function(inst)
			inst.Physics:Stop()
			SGPlayerCommon.Fns.DetachSwipeFx(inst)
			SGPlayerCommon.Fns.DetachPowerSwipeFx(inst)
			inst.components.hitbox:StopRepeatTargetDelay()
			inst.components.playercontroller:OverrideControlQueueTicks("dodge", nil)
			inst.components.playercontroller:OverrideControlQueueTicks("lightattack", nil)
		end,
	}),

	State({
		name = "spinning_heavy_attack_air",
		tags = { "attack", "busy", "airborne", "airborne_high", "heavy_attack" },

		onenter = function(inst)
			inst.AnimState:PlayAnimation("hammer_smash_air_alt")
			inst.sg.statemem.numtargets = 0
			SGCommon.Fns.StartJumpingOverHoles(inst)
			inst.components.playercontroller:OverrideControlQueueTicks("dodge", 8 * ANIM_FRAMES)

			inst.sg.statemem.attack_id = "HEAVY_AIR_SPIN"
		end,

		timeline =
		{
			--sounds
			FrameEvent(3, function(inst)
				local params = {}
				params.fmodevent = fmodtable.Event.Hammer_atk_overhead_alt
				params.sound_max_count = 1
				soundutil.PlaySoundData(inst, params)
			end),
			FrameEvent(13, function(inst)
				local params = {}
				params.fmodevent = fmodtable.Event.Hammer_atk_air_focus_whoosh
				params.autostop = 1
				params.sound_max_count = 1
				soundutil.PlaySoundData(inst, params)
			end),
			FrameEvent(19, function(inst)
				local params = {}
				params.fmodevent = fmodtable.Event.Hammer_atk_overhead_impact
				params.sound_max_count = 1
				soundutil.PlaySoundData(inst, params)
			end),
			--

			--physics
			FrameEvent(0, function(inst) SGCommon.Fns.SetMotorVelScaled(inst, 4) end),
			FrameEvent(2, function(inst) SGCommon.Fns.SetMotorVelScaled(inst, 3.5) end),
			FrameEvent(3, function(inst) SGCommon.Fns.SetMotorVelScaled(inst, 3) end),
			FrameEvent(4, function(inst) SGCommon.Fns.SetMotorVelScaled(inst, 2.5) end),
			FrameEvent(5, function(inst) SGCommon.Fns.SetMotorVelScaled(inst, 2) end),
			FrameEvent(6, function(inst) SGCommon.Fns.SetMotorVelScaled(inst, 1.5) end),
			FrameEvent(7, function(inst) SGCommon.Fns.SetMotorVelScaled(inst, 2) end),
			--FrameEvent(13, function(inst) SGCommon.Fns.SetMotorVelScaled(inst, 8) end),
			FrameEvent(16, function(inst) SGCommon.Fns.SetMotorVelScaled(inst, 2) end),
			FrameEvent(18, function(inst) SGCommon.Fns.SetMotorVelScaled(inst, 1) end),
			FrameEvent(19, function(inst) inst.Physics:Stop() end),
			--

			--focus hit highlight
			FrameEvent(10, function(inst)
				SGCommon.Fns.FlickerSymbolBloom(inst, "weapon_back01", TUNING.FLICKERS.WEAPONS.HAMMER.CHARGE_COMPLETE.COLOR, TUNING.FLICKERS.WEAPONS.HAMMER.CHARGE_COMPLETE.FLICKERS, TUNING.FLICKERS.WEAPONS.HAMMER.CHARGE_COMPLETE.FADE, TUNING.FLICKERS.WEAPONS.HAMMER.CHARGE_COMPLETE.TWEENS)
			end),
			FrameEvent(14, function(inst)
				inst.AnimState:SetSymbolBloom("weapon_back01", TUNING.FLICKERS.WEAPONS.HAMMER.FOCUS_SWING.COLOR[1], TUNING.FLICKERS.WEAPONS.HAMMER.FOCUS_SWING.COLOR[2], TUNING.FLICKERS.WEAPONS.HAMMER.FOCUS_SWING.COLOR[3], TUNING.FLICKERS.WEAPONS.HAMMER.FOCUS_SWING.COLOR[4])
			end),
			FrameEvent(17, function(inst)
				inst.AnimState:SetSymbolBloom("weapon_back01", 0, 0, 0, 0)
			end),
			--

			FrameEvent(4, function(inst)
				combatutil.StartMeleeAttack(inst)

				inst.sg.statemem.damage_mod = ATTACK_DAMAGE_MOD.SPIN
				inst.sg.statemem.focus_damage_mod = ATTACK_DAMAGE_MOD.SPIN_FOCUS
				inst.sg.statemem.hitstun = ATTACK_HITSTUN.SPIN
				inst.sg.statemem.pushback = ATTACK_PUSHBACK.SPIN
				inst.sg.statemem.hitstoplevel = HitStopLevel.HEAVY
				inst.sg.statemem.hitfx_x_offset = 0
				inst.sg.statemem.centerhit = true
				inst.components.hitbox:StartRepeatTargetDelayAnimFrames(HitStopLevel.HEAVY + 4) -- we want to delay so the next frame's hitbox doesn't hurt, but we need to account for hitstop's frames if it connects
				inst.components.hitbox:PushBeam(-1.25, 2.9, 2.3, HitPriority.PLAYER_DEFAULT)
			end),
			FrameEvent(5, function(inst)
				inst.components.hitbox:PushBeam(1.25, -2.9, 2.3, HitPriority.PLAYER_DEFAULT)
				combatutil.EndMeleeAttack(inst)
			end),
			FrameEvent(17, function(inst)
				inst.sg:RemoveStateTag("airborne")
				inst.sg:RemoveStateTag("airborne_high")
				SGCommon.Fns.StopJumpingOverHoles(inst)
			end),
			FrameEvent(18, function(inst)
				combatutil.StartMeleeAttack(inst)

				inst:ShakeCamera(CAMERASHAKE.VERTICAL, .3, .02, .15, inst, 10)
				inst.sg.statemem.damage_mod = ATTACK_DAMAGE_MOD.HEAVY_ATTACK_SOMERSAULT
				inst.sg.statemem.focus_damage_mod = ATTACK_DAMAGE_MOD.HEAVY_ATTACK_SOMERSAULT_FOCUS
				inst.sg.statemem.hitstun = ATTACK_HITSTUN.HEAVY_ATTACK_SOMERSAULT
				inst.sg.statemem.hitstoplevel = HitStopLevel.MEDIUM
				inst.sg.statemem.focushit = true
				inst.sg.statemem.numtargets = 0
				inst.sg.statemem.hitfx_x_offset = nil
				inst.sg.statemem.centerhit = nil
				inst.sg.statemem.knockbackhit = true
				inst.components.hitbox:StartRepeatTargetDelay()
				inst.components.hitbox:PushBeam(-.5, 1, 2.5, HitPriority.PLAYER_DEFAULT)
				inst.components.hitbox:PushBeam(1, 5.2, 3.0, HitPriority.PLAYER_DEFAULT)
			end),
			FrameEvent(19, function(inst)
				inst.components.hitbox:PushBeam(-.5, 1, 2.5, HitPriority.PLAYER_DEFAULT)
				inst.components.hitbox:PushBeam(1, 5.2, 3.0, HitPriority.PLAYER_DEFAULT)
				combatutil.EndMeleeAttack(inst)
			end),
			FrameEvent(20, SGPlayerCommon.Fns.DetachSwipeFx),
			FrameEvent(20, SGPlayerCommon.Fns.DetachPowerSwipeFx),

			--CANCELS
			FrameEvent(25, SGPlayerCommon.Fns.SetCanDodge),
			FrameEvent(25, SGPlayerCommon.Fns.SetCanSkill),
		},

		events =
		{
			EventHandler("hitboxtriggered", OnHitBoxTriggered),
			EventHandler("animover", function(inst)
				inst.sg:GoToState("heavy_attack_air_pst")
			end),
		},

		onexit = function(inst)
			inst.Physics:Stop()
			SGPlayerCommon.Fns.DetachSwipeFx(inst, false, inst.sg.statemem.centerhit)
			SGPlayerCommon.Fns.DetachPowerSwipeFx(inst, false, inst.sg.statemem.centerhit)
			inst.components.hitbox:StopRepeatTargetDelay()
			inst.AnimState:SetSymbolBloom("weapon_back01", 0, 0, 0, 0)
			inst.components.playercontroller:OverrideControlQueueTicks("dodge", nil)
		end,
	}),

	State({
		name = "heavy_attack_air_pst",
		tags = { "busy", "heavy_attack" },

		onenter = function(inst)
			inst.AnimState:PlayAnimation("hammer_smash_pst")
		end,

		timeline =
		{
			FrameEvent(0, SGPlayerCommon.Fns.SetCanDodge),
			FrameEvent(0, SGPlayerCommon.Fns.SetCanSkill),
			FrameEvent(3, SGPlayerCommon.Fns.SetCanAttackOrAbility),
			FrameEvent(7, SGPlayerCommon.Fns.RemoveBusyState),
		},

		events =
		{
			EventHandler("animover", function(inst)
				inst.sg:GoToState("idle")
			end),
		},
	}),

	State({
		name = "rolling_heavy_attack_jump_far",
		onenter = function(inst) inst.sg:GoToState("heavy_attack_jump", 2.3) end,
	}),

	State({
		name = "rolling_heavy_attack_jump_med",
		onenter = function(inst) inst.sg:GoToState("heavy_attack_jump", 1.5) end,
	}),

	State({
		name = "fade_to_heavy_attack_jump",
		tags = { "attack", "busy", "airborne", "heavy_attack" },

		onenter = function(inst)
			inst:PushEvent("attack_state_start")
			inst.AnimState:PlayAnimation("hammer_fade_to_smash_jump")
		end,

		timeline =
		{
			--physics
			FrameEvent(0, function(inst) SGCommon.Fns.SetMotorVelScaled(inst, 3) end),
			--
		},

		events =
		{
			EventHandler("animover", function(inst)
				inst.sg.statemem.attacking = true
				inst.sg:GoToState("heavy_attack_jump", 1.4)
			end),
		},

		onexit = function(inst)
			if not inst.sg.statemem.attacking then
				inst.Physics:Stop()
			end
		end,
	}),

	State({
		name = "light3_to_heavy_attack_jump",
		tags = { "attack", "busy", "airborne", "heavy_attack" },

		onenter = function(inst)
			inst.AnimState:PlayAnimation("hammer_fade_to_smash_jump") --JAMBELL/MIKE: replace this with the L3 -> H transition anim
		end,

		timeline =
		{
			--physics
			FrameEvent(0, function(inst) SGCommon.Fns.SetMotorVelScaled(inst, 3) end),
			--
		},

		events =
		{
			EventHandler("animover", function(inst)
				inst.sg.statemem.attacking = true
				inst.sg:GoToState("heavy_attack_jump", 1.4)
			end),
		},

		onexit = function(inst)
			if not inst.sg.statemem.attacking then
				inst.Physics:Stop()
			end
		end,
	}),


	State({
		name = "heavy_attack_jump_pre",
		tags = { "attack", "busy", "heavy_attack" },

		onenter = function(inst)
			inst:PushEvent("attack_state_start")
			inst.AnimState:PlayAnimation("hammer_smash_jump_pre")
		end,

		timeline =
		{
			--physics
			FrameEvent(2, function(inst) SGCommon.Fns.SetMotorVelScaled(inst, 4.25) end),
			--

			FrameEvent(0, function(inst)
				SGPlayerCommon.Fns.SetCanDodge(inst)	
				inst.sg.statemem.lightcombostate = "default_light_attack"
			end),
		},

		events =
		{
			EventHandler("animover", function(inst)
				inst.sg.statemem.attacking = true
				inst.sg:GoToState("heavy_attack_jump")
			end),
		},

		onexit = function(inst)
			if not inst.sg.statemem.attacking then
				inst.Physics:Stop()
			end
		end,
	}),

	State({
		name = "heavy_attack_jump",
		tags = { "attack", "busy", "airborne", "heavy_attack" },

		onenter = function(inst, speedmult)
			inst.AnimState:PlayAnimation("hammer_smash_jump")
			inst.sg.statemem.speedmult = speedmult or 1
			SGCommon.Fns.StartJumpingOverHoles(inst)
		end,

		timeline =
		{

			--physics
			FrameEvent(0, function(inst) SGCommon.Fns.SetMotorVelScaled(inst, 4.25 * inst.sg.statemem.speedmult) end),
			FrameEvent(1, function(inst) SGCommon.Fns.SetMotorVelScaled(inst, 4 * inst.sg.statemem.speedmult) end),

			--
			FrameEvent(1, function(inst) inst.sg:AddStateTag("airborne_high") end),
		},

		events =
		{
			EventHandler("animover", function(inst)
				inst.sg.statemem.attacking = true
				inst.sg:GoToState("heavy_attack_air_pre", inst.sg.statemem.speedmult)
			end),
		},

		onexit = function(inst)
			if not inst.sg.statemem.attacking then
				inst.Physics:Stop()
			end
			SGCommon.Fns.StopJumpingOverHoles(inst)
		end,
	}),

	State({
		name = "reverse_heavy_attack_sliding",
		onenter = function(inst) inst.sg:GoToState("reverse_heavy_attack_pre", true) end,
	}),

	State({
		name = "reverse_heavy_attack_pre",
		tags = { "attack", "busy", "heavy_attack" },

		onenter = function(inst, sliding)
			inst:PushEvent("attack_state_start")
			inst.AnimState:PlayAnimation("hammer_roll_reverse_atk_pre")
			inst.sg.statemem.speedmult = sliding and 1 or 0
			inst.sg.statemem.held = inst.components.playercontroller:IsControlHeld("heavyattack")
		end,

		timeline =
		{
			--physics
			FrameEvent(0, function(inst) inst:FlipFacingAndRotation() end),
			FrameEvent(0, function(inst) SGCommon.Fns.SetMotorVelScaled(inst, -3 * inst.sg.statemem.speedmult) end),
			FrameEvent(2, function(inst) SGCommon.Fns.SetMotorVelScaled(inst, -2 * inst.sg.statemem.speedmult) end),
			FrameEvent(3, function(inst) SGCommon.Fns.SetMotorVelScaled(inst, -1.5 * inst.sg.statemem.speedmult) end),
			FrameEvent(4, function(inst) SGCommon.Fns.SetMotorVelScaled(inst, -1 * inst.sg.statemem.speedmult) end),
			FrameEvent(5, function(inst) SGCommon.Fns.SetMotorVelScaled(inst, -.5 * inst.sg.statemem.speedmult) end),
			FrameEvent(6, function(inst) inst.Physics:Stop() end),
			FrameEvent(6, function(inst) inst:SnapToFacingRotation() end),
			--

			-- FrameEvent(REVERSE_HEAVY_TIER1_THRESHOLD, function(inst)
			-- 	if inst.sg.statemem.held then
			-- 		inst.AnimState:SetSymbolBloom("weapon_back01", 1, 1, 1, 0.15)
			-- 		inst.sg.statemem.warningfx = SGCommon.Fns.SpawnAtDist(inst, "glint_hammer", 0)
			-- 		inst.sg.statemem.warningfx.AnimState:SetScale(1, 1)
			-- 	end
			-- end),
			-- FrameEvent(REVERSE_HEAVY_TIER2_THRESHOLD, function(inst)
			-- 	if inst.sg.statemem.held then
			-- 		--inst.AnimState:SetSymbolBloom("weapon_back01", 1, 1, 1, 0.50)
			-- 		inst.sg.statemem.warningfx.AnimState:SetScale(1, 1)
			-- 	end
			-- end),

			FrameEvent(10, SGPlayerCommon.Fns.SetCanDodge),

			FrameEvent(11, function(inst)
				--Must have been holding at least throughout this entire state
				if inst.sg.statemem.held then
					dbassert(inst.components.playercontroller:GetControlHeldTicks("heavyattack") >= inst.sg:GetTicksInState())
					--NOTE: Use GetTicksInState() to account for pausing (e.g. hit stops)
					inst.sg.statemem.holdframe = inst.sg:GetTicksInState()
				else
					inst.sg.statemem.attacking = true
					inst.sg:GoToState("reverse_heavy_attack")
				end
			end),

			FrameEvent(16, function(inst)
				SGCommon.Fns.FlickerSymbolBloom(inst, "weapon_back01", TUNING.FLICKERS.WEAPONS.HAMMER.CHARGE_COMPLETE.COLOR, TUNING.FLICKERS.WEAPONS.HAMMER.CHARGE_COMPLETE.FLICKERS, TUNING.FLICKERS.WEAPONS.HAMMER.CHARGE_COMPLETE.FADE, TUNING.FLICKERS.WEAPONS.HAMMER.CHARGE_COMPLETE.TWEENS)
			end),
			FrameEvent(20, function(inst)
				inst.AnimState:SetSymbolBloom("weapon_back01", TUNING.FLICKERS.WEAPONS.HAMMER.FOCUS_SWING.COLOR[1], TUNING.FLICKERS.WEAPONS.HAMMER.FOCUS_SWING.COLOR[2], TUNING.FLICKERS.WEAPONS.HAMMER.FOCUS_SWING.COLOR[3], TUNING.FLICKERS.WEAPONS.HAMMER.FOCUS_SWING.COLOR[4])
			end),
		},

		events =
		{
			EventHandler("controlupevent", function(inst, data)
				if data.control == "heavyattack" then
					if inst.sg.statemem.holdframe ~= nil then
						inst.sg.statemem.attacking = true
						inst.sg:GoToState("reverse_heavy_attack", inst.sg:GetTicksInState())
					else
						inst.sg.statemem.held = false
					end
				end
			end),
			EventHandler("animover", function(inst)
				inst.sg.statemem.attacking = true
				inst.sg:GoToState("reverse_heavy_attack", inst.sg:GetTicksInState())
			end),
		},

		onexit = function(inst)
			if not inst.sg.statemem.attacking then
				inst.Physics:Stop()
			end
		end,
	}),

	State({
		name = "reverse_heavy_attack",
		tags = { "attack", "busy", "nointerrupt", "heavy_attack" },

		onenter = function(inst, heldticks)
			inst.AnimState:PlayAnimation("hammer_roll_reverse_atk")
			inst.sg.statemem.speedmult = heldticks ~= nil and 1 + math.min(10, heldticks) * .025 or 1
			-- inst.components.combat:SetDamageReceivedMult("superarmor", .2)
			inst.sg.statemem.numtargets = 0
			inst.sg.statemem.heldticks = heldticks
		end,

		timeline =
		{
			--sounds
			FrameEvent(0, function(inst)
				local params = {}
				params.fmodevent = fmodtable.Event.Hammer_atk_reverse
				params.sound_max_count = 1
				soundutil.PlaySoundData(inst, params)
			end),
			--

			--physics
			FrameEvent(0, function(inst) SGCommon.Fns.SetMotorVelScaled(inst, 7 * inst.sg.statemem.speedmult) end),
			FrameEvent(1, function(inst) SGCommon.Fns.SetMotorVelScaled(inst, 12 * inst.sg.statemem.speedmult) end),
			FrameEvent(4, function(inst) SGCommon.Fns.SetMotorVelScaled(inst, 4 * inst.sg.statemem.speedmult) end),
			FrameEvent(4, function(inst) inst.sg.statemem.speedmult = .5 + .5 * inst.sg.statemem.speedmult end),
			FrameEvent(5, function(inst) SGCommon.Fns.SetMotorVelScaled(inst, 3 * inst.sg.statemem.speedmult) end),
			FrameEvent(6, function(inst) SGCommon.Fns.SetMotorVelScaled(inst, 2 * inst.sg.statemem.speedmult) end),
			FrameEvent(7, function(inst) SGCommon.Fns.SetMotorVelScaled(inst, 1 * inst.sg.statemem.speedmult) end),
			FrameEvent(8, function(inst) SGCommon.Fns.SetMotorVelScaled(inst, .5 * inst.sg.statemem.speedmult) end),
			FrameEvent(9, function(inst) SGCommon.Fns.SetMotorVelScaled(inst, .25 * inst.sg.statemem.speedmult) end),
			FrameEvent(10, function(inst) inst.Physics:Stop() end),
			--

			FrameEvent(4, function(inst)
				combatutil.StartMeleeAttack(inst)

				-- inst.components.playercontroller:OverrideControlQueueTicks("dodge", 12 * ANIM_FRAMES)

				inst.sg.statemem.hitboxmult = 1
				--SGPlayerCommon.Fns.AttachSwipeFx(inst, "fx_hammer_reverse_atk")
				--SGPlayerCommon.Fns.AttachPowerSwipeFx(inst, "fx_hammer_reverse_atk")
				if inst.sg.statemem.heldticks and inst.sg.statemem.heldticks >= REVERSE_HEAVY_TIER2_THRESHOLD then

					inst.sg.statemem.damage_mod = ATTACK_DAMAGE_MOD.REVERSE_ATTACK_TIER2
					inst.sg.statemem.focus_damage_mod = ATTACK_DAMAGE_MOD.REVERSE_ATTACK_TIER2_FOCUS
					inst.sg.statemem.hitstun = ATTACK_HITSTUN.REVERSE_ATTACK_TIER2
					inst.sg.statemem.pushback = ATTACK_PUSHBACK.REVERSE_ATTACK_TIER2
					inst.sg.statemem.hitboxmult = 1.2
					inst.sg.statemem.chargedtier = 2
					inst.sg.statemem.focushit = true
					inst.sg.statemem.additionalfx = "fx_hammer_charge_swipe_full"
					inst.sg.statemem.knockdownhit = true
					local params = {}
					params.fmodevent = fmodtable.Event.Hammer_atk_charge_focus_whoosh
					params.autostop = 1
					params.sound_max_count = 1
					soundutil.PlaySoundData(inst, params)
					inst.sg.statemem.attack_id = "GOLF_SWING_FULL"

				elseif inst.sg.statemem.heldticks and inst.sg.statemem.heldticks >= REVERSE_HEAVY_TIER1_THRESHOLD then

					inst.sg.statemem.damage_mod = ATTACK_DAMAGE_MOD.REVERSE_ATTACK_TIER1
					inst.sg.statemem.focus_damage_mod = ATTACK_DAMAGE_MOD.REVERSE_ATTACK_TIER1_FOCUS
					inst.sg.statemem.hitstun = ATTACK_HITSTUN.REVERSE_ATTACK_TIER1
					inst.sg.statemem.pushback = ATTACK_PUSHBACK.REVERSE_ATTACK_TIER1
					inst.sg.statemem.hitboxmult = 1.1
					inst.sg.statemem.chargedtier = 1
					inst.sg.statemem.additionalfx = "fx_hammer_charge_swipe_mid"
					inst.sg.statemem.knockdownhit = true
					inst.sg.statemem.attack_id = "GOLF_SWING_MID"

				else
					inst.sg.statemem.damage_mod = ATTACK_DAMAGE_MOD.REVERSE_ATTACK
					inst.sg.statemem.focus_damage_mod = ATTACK_DAMAGE_MOD.REVERSE_ATTACK_FOCUS
					inst.sg.statemem.hitstun = ATTACK_HITSTUN.REVERSE_ATTACK
					inst.sg.statemem.pushback = ATTACK_PUSHBACK.REVERSE_ATTACK
					inst.sg.statemem.chargedtier = 0
					inst.sg.statemem.knockbackhit = true
					inst.sg.statemem.attack_id = "GOLF_SWING_LIGHT"

				end

				if inst.sg.statemem.additionalfx ~= nil then
					SGPlayerCommon.Fns.AttachExtraSwipeFx(inst, inst.sg.statemem.additionalfx)
				end
				inst.AnimState:SetSymbolBloom("weapon_back01", 0, 0, 0, 0)
				inst.sg.statemem.hitstoplevel = HitStopLevel.MAJOR
				inst.components.hitbox:StartRepeatTargetDelay()
				inst.components.hitbox:PushBeam(0, 4.2 * inst.sg.statemem.hitboxmult, 2.5, HitPriority.PLAYER_DEFAULT)
			end),
			FrameEvent(5, function(inst)
				inst.components.hitbox:PushBeam(0, 4.2 * inst.sg.statemem.hitboxmult, 2.5, HitPriority.PLAYER_DEFAULT)
				combatutil.EndMeleeAttack(inst)
			end),
			FrameEvent(7, function(inst)
				inst.sg:RemoveStateTag("nointerrupt")
				SGPlayerCommon.Fns.DetachSwipeFx(inst)
				SGPlayerCommon.Fns.DetachPowerSwipeFx(inst)
				SGPlayerCommon.Fns.DetachExtraSwipeFx(inst)
				-- inst.components.combat:SetDamageReceivedMult("superarmor", nil)
			end),

			-- CANCELS
			FrameEvent(7, SGPlayerCommon.Fns.SetCanDodge)
		},

		events =
		{
			EventHandler("hitboxtriggered", OnHitBoxTriggered),
			EventHandler("animover", function(inst)
				inst.sg:GoToState("reverse_heavy_attack_pst", inst.sg.statemem.chargedtier)
			end),
		},

		onexit = function(inst)
			inst.Physics:Stop()
			SGPlayerCommon.Fns.DetachSwipeFx(inst)
			SGPlayerCommon.Fns.DetachPowerSwipeFx(inst)
			SGPlayerCommon.Fns.DetachExtraSwipeFx(inst)
			inst.components.hitbox:StopRepeatTargetDelay()
			-- inst.components.combat:SetDamageReceivedMult("superarmor", nil)
		end,
	}),

	State({
		name = "reverse_heavy_attack_pst",
		tags = { "busy", "heavy_attack" },

		onenter = function(inst, chargedtier)
			inst.AnimState:PlayAnimation("hammer_roll_reverse_atk_pst")
			inst.sg.statemem.chargedtier = chargedtier
			SGPlayerCommon.Fns.SetCanDodge(inst)
			SGPlayerCommon.Fns.SetCanAttackOrAbility(inst)

		end,

		timeline =
		{
			-- jambell: old cancel window, based on charge length
			-- FrameEvent(0, function(inst)
			-- 	if inst.sg.statemem.chargedtier == 0 then
			-- 		SGPlayerCommon.Fns.SetCanDodge(inst)
			-- 		SGPlayerCommon.Fns.SetCanAttackOrAbility(inst)
			-- 	end
			-- end),

			-- FrameEvent(7, function(inst)
			-- 	if inst.sg.statemem.chargedtier == 1 then
			-- 		SGPlayerCommon.Fns.SetCanDodge(inst)
			-- 		SGPlayerCommon.Fns.SetCanAttackOrAbility(inst)
			-- 	end
			-- end),
			-- FrameEvent(10, function(inst)
			-- 	if inst.sg.statemem.chargedtier == 2 then
			-- 		SGPlayerCommon.Fns.SetCanDodge(inst)
			-- 		SGPlayerCommon.Fns.SetCanAttackOrAbility(inst)
			-- 	end
			-- end),

			FrameEvent(16, SGPlayerCommon.Fns.RemoveBusyState)
		},

		events =
		{
			EventHandler("animover", function(inst)
				inst.sg:GoToState("idle")
			end),
		},
	}),

	State({
		name = "fading_light_attack_far",
		onenter = function(inst) inst.sg:GoToState("fading_light_attack", 2.5) end,
	}),

	State({
		name = "fading_light_attack_med",
		onenter = function(inst) inst.sg:GoToState("fading_light_attack", 1.5) end,
	}),

	State({
		name = "fading_light_attack",
		tags = { "attack", "busy", "light_attack" },

		onenter = function(inst, speedmult)
			inst:PushEvent("attack_state_start")
			inst.AnimState:PlayAnimation("hammer_roll_fade_atk")
			inst.sg.statemem.speedmult = speedmult or 1
			inst.sg.statemem.numtargets = 0
			inst.components.playercontroller:OverrideControlQueueTicks("heavyattack", 12 * ANIM_FRAMES)
			inst.sg.statemem.attack_id = "FADING_LIGHT"
		end,

		timeline =
		{
			--sounds
			FrameEvent(7, function(inst)
				local params = {}
				params.fmodevent = fmodtable.Event.Hammer_atk_fade
				params.sound_max_count = 1
				soundutil.PlaySoundData(inst, params)
			end),
			--

			--physics
			FrameEvent(0, function(inst) inst:FlipFacingAndRotation() end),
			FrameEvent(0, function(inst) SGCommon.Fns.SetMotorVelScaled(inst, -2 * inst.sg.statemem.speedmult) end),
			FrameEvent(8, function(inst) inst.sg.statemem.speedmult = math.min(2.5, inst.sg.statemem.speedmult + .5) end),
			FrameEvent(8, function(inst) SGCommon.Fns.SetMotorVelScaled(inst, -3.5 * inst.sg.statemem.speedmult) end),
			FrameEvent(9, function(inst) SGCommon.Fns.SetMotorVelScaled(inst, -2 * inst.sg.statemem.speedmult) end),
			FrameEvent(12, function(inst) SGCommon.Fns.SetMotorVelScaled(inst, -1 * inst.sg.statemem.speedmult) end),
			FrameEvent(14, function(inst) SGCommon.Fns.SetMotorVelScaled(inst, -.5 * inst.sg.statemem.speedmult) end),
			FrameEvent(15, function(inst) SGCommon.Fns.SetMotorVelScaled(inst, -.25 * inst.sg.statemem.speedmult) end),
			FrameEvent(16, function(inst) inst.Physics:Stop() end),
			--

			--hitboxes
			FrameEvent(7, function(inst)
				combatutil.StartMeleeAttack(inst)

				inst.components.hitbox:PushOffsetBeam(0, 3.5, 1.3, -2.3, HitPriority.PLAYER_DEFAULT)
				inst.components.hitbox:PushBeam(0, 4.5, 1, HitPriority.PLAYER_DEFAULT)
			end),
			FrameEvent(8, function(inst)
				--inst.components.hitbox:PushBeam(0, 3.9, 2.3, HitPriority.PLAYER_DEFAULT)
				inst.components.hitbox:PushOffsetBeam(0, 2, 3.5, 3, HitPriority.PLAYER_DEFAULT) end),
			FrameEvent(9, function(inst)
				inst.components.hitbox:PushOffsetBeam(-2, 0, 3.5, 3, HitPriority.PLAYER_DEFAULT) end),
			FrameEvent(10, function(inst)
				inst.components.hitbox:PushBeam(0, -3, 1.5, HitPriority.PLAYER_DEFAULT)

				combatutil.EndMeleeAttack(inst)
			end),
			--

			FrameEvent(4, function(inst)
				inst.sg:AddStateTag("airborne")
			end),
			FrameEvent(7, function(inst)
				--SGPlayerCommon.Fns.AttachSwipeFx(inst, "fx_hammer_fade_atk_front")
				--SGPlayerCommon.Fns.AttachPowerSwipeFx(inst, "fx_hammer_fade_atk_front")
				inst.sg.statemem.damage_mod = ATTACK_DAMAGE_MOD.LIGHT_ATTACK1
				inst.sg.statemem.focus_damage_mod = ATTACK_DAMAGE_MOD.LIGHT_ATTACK1_FOCUS
				inst.sg.statemem.hitstun = ATTACK_HITSTUN.LIGHT_ATTACK1
				inst.sg.statemem.pushback = ATTACK_PUSHBACK.LIGHT_ATTACK1
				inst.sg.statemem.hitstoplevel = HitStopLevel.MEDIUM
				inst.components.hitbox:StartRepeatTargetDelay()
			end),
			FrameEvent(9, function(inst)
				inst.sg:RemoveStateTag("airborne")
				SGPlayerCommon.Fns.DetachSwipeFx(inst)
				SGPlayerCommon.Fns.DetachPowerSwipeFx(inst)
				--SGPlayerCommon.Fns.AttachSwipeFx(inst, "fx_hammer_fade_atk_back")
				--jambell: power back fx?
				inst.sg.statemem.hitstoplevel = HitStopLevel.LIGHT
				inst.sg.statemem.hitfx_x_offset = -1
				inst.sg.statemem.backhit = true
			end),
			FrameEvent(11, SGPlayerCommon.Fns.DetachSwipeFx),
			FrameEvent(12, SGPlayerCommon.Fns.SetCanDodge),
			FrameEvent(12, function(inst)
				inst.sg.statemem.lightcombostate = "light_attack2" -- prototyping this... old cancel: "fade_to_light_attack3_pre"
				inst.sg.statemem.heavycombostate = "fading_heavy_spin_pre"
				inst.sg.statemem.norotateheavycombo = true
				SGPlayerCommon.Fns.TryQueuedAction(inst, "lightattack")
				SGPlayerCommon.Fns.TryQueuedAction(inst, "heavyattack")
			end),
			FrameEvent(15, SGPlayerCommon.Fns.SetCanSkill),
		},

		events =
		{
			EventHandler("hitboxtriggered", OnHitBoxTriggered),
			EventHandler("animover", function(inst)
				inst.sg:GoToState("fading_light_attack_pst")
			end),
		},

		onexit = function(inst)
			inst.Physics:Stop()
			SGPlayerCommon.Fns.DetachSwipeFx(inst)
			SGPlayerCommon.Fns.DetachPowerSwipeFx(inst)
			inst.components.hitbox:StopRepeatTargetDelay()
			inst.components.playercontroller:OverrideControlQueueTicks("heavyattack", nil)
		end,
	}),

	State({
		name = "fading_light_attack_pst",
		tags = { "light_attack" },

		onenter = function(inst)
			inst.Physics:Stop()
			inst.AnimState:PlayAnimation("hammer_roll_fade_atk_pst")
		end,

		timeline =
		{
			-- FrameEvent(0, SGPlayerCommon.Fns.SetCanDodge),
			-- FrameEvent(5, SGPlayerCommon.Fns.SetCanAttackOrAbility),
			-- FrameEvent(13, SGPlayerCommon.Fns.RemoveBusyState),
		},

		events =
		{
			EventHandler("animover", function(inst)
				inst.sg:GoToState("idle")
			end),
		},
	}),

	State({
		name = "fading_heavy_spin_pre",
		tags = { "attack", "busy", "nointerrupt", "heavy_attack" },

		onenter = function(inst, speedmult)
			inst:PushEvent("attack_state_start")
			inst.AnimState:PlayAnimation("hammer_big_atk1_pre_short")
			inst.sg.statemem.speedmult = speedmult or 1
			inst.sg.statemem.numtargets = 0
			inst.sg.mem.heavyspinloops = 0
			inst.sg.statemem.held = inst.components.playercontroller:IsControlHeld("heavyattack")

			inst.sg.statemem.damage_mod = ATTACK_DAMAGE_MOD.REVERSE_HEAVY_SPIN[inst.sg.mem.heavyspinloops+1]
			inst.sg.statemem.focus_damage_mod = ATTACK_DAMAGE_MOD.REVERSE_HEAVY_SPIN_FOCUS[inst.sg.mem.heavyspinloops+1]
			inst.sg.statemem.hitstun = ATTACK_HITSTUN.REVERSE_HEAVY_SPIN[inst.sg.mem.heavyspinloops+1]
			inst.sg.statemem.pushback = ATTACK_PUSHBACK.REVERSE_HEAVY_SPIN[inst.sg.mem.heavyspinloops+1]
			inst.sg.statemem.hitstoplevel = REVERSE_HEAVY_SPIN_HITSTOP[inst.sg.mem.heavyspinloops+1]
			inst.components.hitbox:StartRepeatTargetDelayAnimFrames(6 + inst.sg.statemem.hitstoplevel * HEAVY_SPIN_HITSTOP_MULTIPLIER)

			inst.sg.statemem.attack_id = "LARIAT"
		end,

		timeline =
		{
			FrameEvent(0, function(inst) SGCommon.Fns.SetMotorVelScaled(inst, -1.5 * inst.sg.statemem.speedmult) end),
			FrameEvent(2, function(inst) inst.Physics:Stop() end),

			--Hitboxes
			FrameEvent(9, function(inst)
				--inst.components.hitbox:PushBeam(0, -3, 1.5, HitPriority.PLAYER_DEFAULT)
				--inst.components.hitbox:PushBeam(0, -4.5, 1, HitPriority.PLAYER_DEFAULT)
				--inst.components.hitbox:PushOffsetBeam(1, -2.5, -1.5, -1.75, HitPriority.PLAYER_DEFAULT)
			end),
			FrameEvent(10, function(inst)
				--inst.components.hitbox:PushOffsetBeam(-2, 0, 1.5, -2.5, HitPriority.PLAYER_DEFAULT)
			end),
			FrameEvent(11, function(inst)
				combatutil.StartMeleeAttack(inst)
				inst.components.hitbox:PushOffsetBeam(-1.75, 1, 1.5, -2.5, HitPriority.PLAYER_DEFAULT)
			end),
		},

		events =
		{
			EventHandler("controlupevent", function(inst, data)
				if data.control == "heavyattack" then
					inst.sg.statemem.held = false
				end
			end),
			EventHandler("hitboxtriggered", OnHitBoxTriggered),

			EventHandler("animover", function(inst)
				if inst.sg.statemem.held then
					inst.sg:GoToState("fading_heavy_spin_loop")
				else
					inst.sg:GoToState("fading_heavy_spin_pst")
				end
			end),
		},

		onexit = function(inst)
			combatutil.EndMeleeAttack(inst)
			SGPlayerCommon.Fns.DetachSwipeFx(inst)
			SGPlayerCommon.Fns.DetachPowerSwipeFx(inst)
		end,
	}),

	State({
		name = "fading_heavy_spin_loop",
		tags = { "attack", "busy", "nointerrupt", "heavy_attack" },

		onenter = function(inst, speedmult)

			inst.sg:ExpectMem("heavyspinloops", 0)

			inst.AnimState:PlayAnimation("hammer_big_atk1_loop")
			inst.sg.statemem.speedmult = speedmult or 1
			inst.sg.statemem.numtargets = 0
			inst.sg.statemem.held = inst.components.playercontroller:IsControlHeld("heavyattack")

			inst.sg.statemem.attacking = true
			inst.sg.statemem.damage_mod = ATTACK_DAMAGE_MOD.REVERSE_HEAVY_SPIN[inst.sg.mem.heavyspinloops+1]
			inst.sg.statemem.focus_damage_mod = ATTACK_DAMAGE_MOD.REVERSE_HEAVY_SPIN_FOCUS[inst.sg.mem.heavyspinloops+1]
			inst.sg.statemem.hitstun = ATTACK_HITSTUN.REVERSE_HEAVY_SPIN[inst.sg.mem.heavyspinloops+1]
			inst.sg.statemem.pushback = ATTACK_PUSHBACK.REVERSE_HEAVY_SPIN[inst.sg.mem.heavyspinloops+1]
			inst.sg.statemem.hitstoplevel = REVERSE_HEAVY_SPIN_HITSTOP[inst.sg.mem.heavyspinloops+1]
			inst.components.hitbox:StartRepeatTargetDelayAnimFrames(6 + inst.sg.statemem.hitstoplevel * HEAVY_SPIN_HITSTOP_MULTIPLIER)
			if inst.sg.mem.heavyspinloops >= ALLOWABLE_HEAVY_SPIN_LOOPS then
				inst.sg.statemem.knockdownhit = true
			end

			inst.sg.statemem.startingrotation = inst.Transform:GetRotation()
			SGCommon.Fns.SetMotorVelScaled(inst, -3 * inst.sg.statemem.speedmult)

			inst.sg.statemem.attack_id = "LARIAT"
		end,

		-- onupdate = function(inst, speedmult)
		-- 	local movedirection = inst.components.playercontroller:IsEnabled() and inst.components.playercontroller:GetAnalogDir()
		-- 	if movedirection ~= nil then
		-- 		movedirection = movedirection - inst.sg.statemem.startingrotation
		-- 		movedirection = (movedirection + 180) % 360 - 180
		-- 		-- if inst.sg.statemem.movedirection == 90 or inst.sg.statemem.movedirection == -90 then
		-- 		inst.Transform:SetRotation(movedirection)
		-- 		-- else
		-- 		-- end
		-- 	end
		-- end,

		timeline =
		{


			-- physics
			FrameEvent(0, function (inst) 	SGCommon.Fns.SetMotorVelScaled(inst, -1.5 * inst.sg.statemem.speedmult) end),
			FrameEvent(6, function (inst) 	SGCommon.Fns.SetMotorVelScaled(inst, -0.5 * inst.sg.statemem.speedmult) end),
			--

			-- hitboxes
			-- flips left at 0
			-- flips right at 6
			FrameEvent(0, function (inst)
				combatutil.StartMeleeAttack(inst)
				inst.components.hitbox:PushBeam(0, 4.5, 1, HitPriority.PLAYER_DEFAULT)
				inst.components.hitbox:PushOffsetBeam(0, 3.5, 1.3, -2.3, HitPriority.PLAYER_DEFAULT)
				inst.sg.statemem.pushback = ATTACK_PUSHBACK.REVERSE_HEAVY_SPIN[inst.sg.mem.heavyspinloops+1]
			end),
			FrameEvent(1, function(inst)
				inst.components.hitbox:PushBeam(0, 4.5, 1, HitPriority.PLAYER_DEFAULT)
			end),
			FrameEvent(2, function(inst)
				inst.components.hitbox:PushBeam(0, 4.5, 1.75, HitPriority.PLAYER_DEFAULT)
				inst.components.hitbox:PushOffsetBeam(0, 4, 1.5, 1.75, HitPriority.PLAYER_DEFAULT)
			end),
			FrameEvent(3, function(inst)
				inst.components.hitbox:PushOffsetBeam(0, 2.5, 3.5, 4, HitPriority.PLAYER_DEFAULT)
				inst.components.hitbox:PushOffsetBeam(0, 4, 1.75, 1.75, HitPriority.PLAYER_DEFAULT)
			end),
			FrameEvent(4, function(inst)
				inst.components.hitbox:PushOffsetBeam(-1, 1, 3.5, 4, HitPriority.PLAYER_DEFAULT)
			end),
			FrameEvent(5, function(inst)
				inst.components.hitbox:PushOffsetBeam(-2, 0.5, 3.5, 4, HitPriority.PLAYER_DEFAULT)
				inst.components.hitbox:PushOffsetBeam(0, -3.5, 1.5, 1.75, HitPriority.PLAYER_DEFAULT)
			end),
			FrameEvent(6, function(inst)
				inst.components.hitbox:PushBeam(0, -4.5, 1.5, HitPriority.PLAYER_DEFAULT)
				inst.components.hitbox:PushOffsetBeam(0, -3.5, 1.5, 1.75, HitPriority.PLAYER_DEFAULT)
			end),
			FrameEvent(7, function(inst)
				inst.components.hitbox:PushBeam(0, -4.5, 1, HitPriority.PLAYER_DEFAULT)
			end),
			FrameEvent(8, function(inst)
				--inst.components.hitbox:PushBeam(0, -3, 1.5, HitPriority.PLAYER_DEFAULT)
				inst.components.hitbox:PushBeam(0, -4.5, 1, HitPriority.PLAYER_DEFAULT)
				inst.components.hitbox:PushOffsetBeam(0, -3.5, -1.5, -1.75, HitPriority.PLAYER_DEFAULT)
			end),
			FrameEvent(9, function(inst)
				inst.components.hitbox:PushOffsetBeam(-2, 0, 1.5, -2.5, HitPriority.PLAYER_DEFAULT)
			end),
			FrameEvent(10, function(inst)
				inst.components.hitbox:PushOffsetBeam(-1, 1, 1.5, -2.5, HitPriority.PLAYER_DEFAULT)
			end),
			FrameEvent(11, function(inst)
				inst.components.hitbox:PushOffsetBeam(0, 2, 1.5, -2, HitPriority.PLAYER_DEFAULT)
			end),
			FrameEvent(12, function(inst)
				inst.components.hitbox:PushBeam(0, 4.5, 1, HitPriority.PLAYER_DEFAULT)
				inst.components.hitbox:PushOffsetBeam(0, 3.5, -1.5, -1.75, HitPriority.PLAYER_DEFAULT)

				combatutil.EndMeleeAttack(inst)
			end),
			--

			-- CANCELS
			FrameEvent(0, SGPlayerCommon.Fns.SetCanDodge)
		},

		events =
		{
			EventHandler("hitboxtriggered", OnHitBoxTriggered),

			EventHandler("controlupevent", function(inst, data)
				if data.control == "heavyattack" then
					-- victorc: 60Hz, this may need to be reconciled to work in anim frames
					if inst.sg:GetTicksInState() % inst.AnimState:GetCurrentAnimationNumFrames() < 3 then
						inst.sg:GoToState("fading_heavy_spin_pst")
					else
						inst.sg.statemem.held = false
					end
				end
			end),
			EventHandler("animover", function(inst)
				inst.sg.mem.heavyspinloops = inst.sg.mem.heavyspinloops + 1
				inst.sg.statemem.pushback = ATTACK_PUSHBACK.REVERSE_HEAVY_SPIN[inst.sg.mem.heavyspinloops+1]
				if inst.sg.statemem.held and inst.sg.mem.heavyspinloops < ALLOWABLE_HEAVY_SPIN_LOOPS then
					inst.sg.statemem.attacking = true
					inst.sg:GoToState("fading_heavy_spin_loop")
				else
					inst.sg:GoToState("fading_heavy_spin_pst")
				end
			end),
		},

		onexit = function(inst)
			SGPlayerCommon.Fns.DetachSwipeFx(inst)
			SGPlayerCommon.Fns.DetachPowerSwipeFx(inst)
			inst:DoTaskInAnimFrames(3, function() -- Wait some anim frames til we're in the next state -- if we aren't still attacking (we're in the pst) then we must have been knocked out of the state... so only then, stop the target delay
				if not inst.sg.statemem.attacking then
					inst.components.hitbox:StopRepeatTargetDelay()
				end
			end)
		end,
	}),

	State({
		name = "fading_heavy_spin_pst",
		tags = { "attack", "busy", "nointerrupt", "heavy_attack" },

		default_data_for_tools = 1,

		onenter = function(inst, speedmult)
			local recovery_anim

			inst.sg:ExpectMem("heavyspinloops", 0)
			if inst.sg.mem.heavyspinloops == 0 then
				recovery_anim = "hammer_big_atk1_sheathe_pst"
				inst.sg.statemem.recovery_tier = 0
			elseif inst.sg.mem.heavyspinloops == ALLOWABLE_HEAVY_SPIN_LOOPS then
				recovery_anim = "hammer_big_atk1_sheathe3_pst"
				inst.sg.statemem.knockdownhit = true
				inst.sg.statemem.recovery_tier = 2
			else
				recovery_anim = "hammer_big_atk1_sheathe2_pst"
				inst.sg.statemem.recovery_tier = 1
			end

			inst.AnimState:PlayAnimation(recovery_anim)
			inst.sg.statemem.speedmult = speedmult or 1
			inst.sg.statemem.numtargets = 0

			inst.sg.statemem.attacking = true -- used to prevent the last state from stopping target delay
			inst.sg.statemem.damage_mod = ATTACK_DAMAGE_MOD.REVERSE_HEAVY_SPIN[inst.sg.mem.heavyspinloops+1]
			inst.sg.statemem.focus_damage_mod = ATTACK_DAMAGE_MOD.REVERSE_HEAVY_SPIN_FOCUS[inst.sg.mem.heavyspinloops+1]
			inst.sg.statemem.hitstun = ATTACK_HITSTUN.REVERSE_HEAVY_SPIN[inst.sg.mem.heavyspinloops+1]
			inst.sg.statemem.pushback = ATTACK_PUSHBACK.REVERSE_HEAVY_SPIN[inst.sg.mem.heavyspinloops+1]
			inst.sg.statemem.focushit = inst.sg.mem.heavyspinloops >= ALLOWABLE_HEAVY_SPIN_LOOPS and true
			inst.sg.statemem.hitstoplevel = REVERSE_HEAVY_SPIN_HITSTOP[inst.sg.mem.heavyspinloops+1]
			inst.components.hitbox:StartRepeatTargetDelayAnimFrames(6 + inst.sg.statemem.hitstoplevel * HEAVY_SPIN_HITSTOP_MULTIPLIER)

			SGCommon.Fns.SetMotorVelScaled(inst, -2 * inst.sg.statemem.speedmult)

			inst.sg.statemem.attack_id = "LARIAT"
		end,

		timeline =
		{
			-- physics
			FrameEvent(0, function (inst) 	SGCommon.Fns.SetMotorVelScaled(inst, -1.5 * inst.sg.statemem.speedmult) end),
			FrameEvent(6, function (inst) 	SGCommon.Fns.SetMotorVelScaled(inst, -0.5 * inst.sg.statemem.speedmult) end),
			-- FrameEvent(0, function(inst) SGCommon.Fns.SetMotorVelScaled(inst, -1.5 * inst.sg.statemem.speedmult) end),
			FrameEvent(11, function(inst) inst.Physics:Stop() end),
			--

			--focus hit charge fx
			FrameEvent(0, function(inst)
				if inst.sg.statemem.recovery_tier == 2 then
					inst.AnimState:SetSymbolBloom("weapon_back01", TUNING.FLICKERS.WEAPONS.HAMMER.FOCUS_SWING.COLOR[1], TUNING.FLICKERS.WEAPONS.HAMMER.FOCUS_SWING.COLOR[2], TUNING.FLICKERS.WEAPONS.HAMMER.FOCUS_SWING.COLOR[3], TUNING.FLICKERS.WEAPONS.HAMMER.FOCUS_SWING.COLOR[4])
				end
			end),
			FrameEvent(8, function(inst)
				inst.AnimState:SetSymbolBloom("weapon_back01", 0, 0, 0, 0)
			end),
			--

			-- hitboxes
			FrameEvent(0, function (inst)
				combatutil.StartMeleeAttack(inst)
				inst.components.hitbox:PushBeam(0, 4.5, 1, HitPriority.PLAYER_DEFAULT)
				--inst.components.hitbox:PushOffsetBeam(0, 3.5, 1.3, -2.3, HitPriority.PLAYER_DEFAULT)
				inst.sg.statemem.pushback = ATTACK_PUSHBACK.REVERSE_HEAVY_SPIN[inst.sg.mem.heavyspinloops+1]
			end),
			FrameEvent(1, function(inst)
				inst.components.hitbox:PushBeam(0, 4.5, 1, HitPriority.PLAYER_DEFAULT)
			end),
			FrameEvent(2, function(inst)
				inst.components.hitbox:PushBeam(0, 4.5, 1.75, HitPriority.PLAYER_DEFAULT)
				inst.components.hitbox:PushOffsetBeam(0, 4, 1.5, 1.75, HitPriority.PLAYER_DEFAULT)
			end),
			FrameEvent(3, function(inst)
				inst.components.hitbox:PushOffsetBeam(0, 2.5, 3.5, 4, HitPriority.PLAYER_DEFAULT)
				inst.components.hitbox:PushOffsetBeam(0, 4, 1.5, 1.75, HitPriority.PLAYER_DEFAULT)
			end),
			FrameEvent(4, function(inst)
				inst.components.hitbox:PushOffsetBeam(-1, 1.5, 3.5, 4, HitPriority.PLAYER_DEFAULT)
			end),
			FrameEvent(5, function(inst)
				inst.components.hitbox:PushOffsetBeam(-2, 0, 3.5, 4, HitPriority.PLAYER_DEFAULT)
				inst.components.hitbox:PushOffsetBeam(0, -3.5, 1.5, 1.75, HitPriority.PLAYER_DEFAULT)
			end),
			FrameEvent(6, function(inst)
				inst.components.hitbox:PushBeam(0, -4.5, 1.5, HitPriority.PLAYER_DEFAULT)
				inst.components.hitbox:PushOffsetBeam(0, -3.5, 1.75, 1.75, HitPriority.PLAYER_DEFAULT)
			end),
			FrameEvent(7, function(inst)
				inst.components.hitbox:PushBeam(0, -4.5, 1, HitPriority.PLAYER_DEFAULT)
			end),
			FrameEvent(8, function(inst)
				inst.components.hitbox:PushBeam(0, -3.5, 1, HitPriority.PLAYER_DEFAULT)
			end),
			FrameEvent(9, function(inst)
				inst.components.hitbox:PushBeam(0, -3.5, 1, HitPriority.PLAYER_DEFAULT)
				combatutil.EndMeleeAttack(inst)
			end),
			--

			FrameEvent(2, function(inst)
				SGPlayerCommon.Fns.DetachSwipeFx(inst)
				SGPlayerCommon.Fns.DetachPowerSwipeFx(inst)
			end),
			FrameEvent(8, function(inst)
				SGPlayerCommon.Fns.DetachSwipeFx(inst, true)
			end),
			FrameEvent(10, function(inst)
				inst.sg:RemoveStateTag("nointerrupt")
			end),


			-- DIFFERENT RECOVERY TIERS:
			-- Different recovery frames based on which anim we're playing
			-- 	Recovery tier 0
			FrameEvent(13, function(inst)
				if inst.sg.statemem.recovery_tier == 0 then
					SGPlayerCommon.Fns.SetCanDodge(inst)
				end
			end),
			FrameEvent(18, function(inst)
				if inst.sg.statemem.recovery_tier == 0 then
					SGPlayerCommon.Fns.SetCanSkill(inst)
				end
			end),
			FrameEvent(22, function(inst)
				if inst.sg.statemem.recovery_tier == 0 then
					SGPlayerCommon.Fns.RemoveBusyState(inst)
				end
			end),

			-- 	Recovery tier 1
			FrameEvent(18, function(inst)
				if inst.sg.statemem.recovery_tier == 1 then
					SGPlayerCommon.Fns.SetCanDodge(inst)
				end
			end),
			FrameEvent(23, function(inst)
				if inst.sg.statemem.recovery_tier == 1 then
					SGPlayerCommon.Fns.SetCanSkill(inst)
				end
			end),
			FrameEvent(33, function(inst)
				if inst.sg.statemem.recovery_tier == 1 then
					SGPlayerCommon.Fns.RemoveBusyState(inst)
				end
			end),

			-- 	Recovery tier 2
			FrameEvent(26, function(inst)
				if inst.sg.statemem.recovery_tier == 2 then
					SGPlayerCommon.Fns.SetCanDodge(inst)
					SGPlayerCommon.Fns.SetCanSkill(inst)
				end
			end),
			FrameEvent(38, function(inst)
				if inst.sg.statemem.recovery_tier == 2 then
					SGPlayerCommon.Fns.RemoveBusyState(inst)
				end
			end),
		},

		events =
		{
			EventHandler("hitboxtriggered", OnHitBoxTriggered),
			EventHandler("animover", function(inst)
				inst.sg:GoToState("idle")
			end),
		},

		onexit = function(inst)
			inst.Physics:Stop()
			SGPlayerCommon.Fns.DetachSwipeFx(inst)
			SGPlayerCommon.Fns.DetachPowerSwipeFx(inst)
			inst.components.hitbox:StopRepeatTargetDelay()
			inst.AnimState:SetSymbolBloom("weapon_back01", 0, 0, 0, 0)
		end,
	}),
}

SGPlayerCommon.States.AddAllBasicStates(states)
SGPlayerCommon.States.AddRollStates(states)

-- TODO: add this as a SGPlayerCommon helper function after moving the other weapons over, too.
-- TODO: should roll_pre have combo states too, to allow 1-or-2 frame immediate cancels? I think yes?
for i,state in ipairs(states) do
	if state.name == "roll_loop" then
		local id = #state.timeline
		state.timeline[id + 1] = FrameEvent(8, function(inst)
			inst.sg.statemem.lightcombostate = "rolling_light_attack3_pre"
			inst.sg.statemem.heavycombostate = "rolling_heavy_attack_jump_far"
			inst.sg.statemem.reverselightstate = "fading_light_attack_far"
			inst.sg.statemem.reverseheavystate = "reverse_heavy_attack_sliding"
			SGPlayerCommon.Fns.TryQueuedLightOrHeavy(inst)
		end)
		state.timeline[id + 1].idx = id + 1

		table.sort(state.timeline, function(a,b) return a.frame < b.frame end)
	end

	if state.name == "roll_pst" then
		local id = #state.timeline
		state.timeline[id + 1] = FrameEvent(0, function(inst)
			inst.sg.statemem.lightcombostate = "rolling_light_attack3_pre"
			inst.sg.statemem.heavycombostate = "rolling_heavy_attack_jump_med"
			inst.sg.statemem.reverselightstate = "fading_light_attack_med"
			inst.sg.statemem.reverseheavystate = "reverse_heavy_attack_sliding"
		end)
		state.timeline[id + 1].idx = id + 1

		state.timeline[id + 2] = FrameEvent(5, function(inst)
			inst.sg.statemem.reverseheavystate = "reverse_heavy_attack_pre" --non-sliding version
			inst.sg.statemem.reverselightstate = "fading_light_attack"
		end)
		state.timeline[id + 2].idx = id + 2

		state.timeline[id + 3] = FrameEvent(7, function(inst)
				inst.sg:RemoveStateTag("norotatecombo")
				inst.sg.statemem.lightcombostate = nil
				inst.sg.statemem.heavycombostate = nil
				inst.sg.statemem.reverselightstate = nil
				inst.sg.statemem.reverseheavystate = nil
		end)
		state.timeline[id + 3].idx = id + 3

		table.sort(state.timeline, function(a,b) return a.frame < b.frame end)
	end

	-- LIGHT ROLL
	if state.name == "roll_light" then
		local id = #state.timeline
		state.timeline[id + 1] = FrameEvent(4, function(inst)
			inst.sg.statemem.lightcombostate = "rolling_light_attack3_pre"
			inst.sg.statemem.heavycombostate = "rolling_heavy_attack_jump_far"
			inst.sg.statemem.reverselightstate = "fading_light_attack_far"
			inst.sg.statemem.reverseheavystate = "reverse_heavy_attack_sliding"
			SGPlayerCommon.Fns.TryQueuedLightOrHeavy(inst)
		end)
		state.timeline[id + 1].idx = id + 1

		table.sort(state.timeline, function(a,b) return a.frame < b.frame end)
	end

	if state.name == "roll_light_pst" then
		local id = #state.timeline
		state.timeline[id + 1] = FrameEvent(0, function(inst)
			inst.sg.statemem.lightcombostate = "rolling_light_attack3_pre"
			inst.sg.statemem.heavycombostate = "rolling_heavy_attack_jump_med"
			inst.sg.statemem.reverselightstate = "fading_light_attack_med"
			inst.sg.statemem.reverseheavystate = "reverse_heavy_attack_sliding"
		end)
		state.timeline[id + 1].idx = id + 1

		state.timeline[id + 2] = FrameEvent(1, function(inst)
			inst.sg.statemem.reverseheavystate = "reverse_heavy_attack_pre" --non-sliding version
			inst.sg.statemem.reverselightstate = "fading_light_attack"
		end)
		state.timeline[id + 2].idx = id + 2

		table.sort(state.timeline, function(a,b) return a.frame < b.frame end)
	end

	-- HEAVY ROLL
	if state.name == "roll_heavy" then
		local id = #state.timeline
		state.timeline[id + 1] = FrameEvent(0, function(inst)
			inst.sg.statemem.lightcombostate = "rolling_light_attack3_pre"
			inst.sg.statemem.heavycombostate = "rolling_heavy_attack_jump_far"
			inst.sg.statemem.reverselightstate = "fading_light_attack_far"
			inst.sg.statemem.reverseheavystate = "reverse_heavy_attack_sliding"
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
				inst.sg.statemem.lightcombostate = "rolling_light_attack3_pre"
				inst.sg.statemem.heavycombostate = "rolling_heavy_attack_jump_med"
				inst.sg.statemem.reverselightstate = "fading_light_attack_med"
				inst.sg.statemem.reverseheavystate = "reverse_heavy_attack_sliding"
				SGPlayerCommon.Fns.TryQueuedLightOrHeavy(inst)
			end
		end)
		state.timeline[id + 1].idx = id + 1

		state.timeline[id + 2] = FrameEvent(4, function(inst)
			inst.sg.statemem.reverseheavystate = "reverse_heavy_attack_pre" --non-sliding version
			inst.sg.statemem.reverselightstate = "fading_light_attack"
		end)
		state.timeline[id + 2].idx = id + 2

		table.sort(state.timeline, function(a,b) return a.frame < b.frame end)
	end
end

return StateGraph("sg_player_hammer", states, events, "idle")
