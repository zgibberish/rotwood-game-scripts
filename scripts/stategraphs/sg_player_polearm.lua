local SGCommon = require "stategraphs.sg_common"
local SGPlayerCommon = require "stategraphs.sg_player_common"
local fmodtable = require "defs.sound.fmodtable"
local combatutil = require "util.combatutil"
local DebugDraw = require "util.debugdraw"
local soundutil = require "util.soundutil"
local Weight = require "components.weight"

local ATTACKS =
{
	LIGHT_ATTACK_1 =
	{
		DAMAGE = 1,
		DAMAGE_FOCUS = 1.5,
		HITSTUN = 8,
		PUSHBACK = 1,
		PUSHBACK_FOCUS = 0,
		HITSTOP = HitStopLevel.MINOR,
		HITSTOP_FOCUS = HitStopLevel.MINOR,
	},
	LIGHT_ATTACK_2 =
	{
		DAMAGE = 1.3,
		DAMAGE_FOCUS = 2.0,
		HITSTUN = 10,
		PUSHBACK = 1.2,
		PUSHBACK_FOCUS = 0,
		HITSTOP = HitStopLevel.MINOR,
		HITSTOP_FOCUS = HitStopLevel.MINOR,
	},
	LIGHT_ATTACK_3 =
	{
		DAMAGE = 1.5,
		DAMAGE_FOCUS = 2.5,
		HITSTUN = 12,
		PUSHBACK = 1.4,
		PUSHBACK_FOCUS = 0,
		HITSTOP = HitStopLevel.MINOR,
		HITSTOP_FOCUS = HitStopLevel.MINOR,
	},
	HEAVY_ATTACK =
	{
		DAMAGE = 2.5,
		DAMAGE_FOCUS = 6,
		HITSTUN = 10,
		PUSHBACK = 3,
		PUSHBACK_FOCUS = 1,
		HITSTOP = HitStopLevel.MINOR,
		HITSTOP_FOCUS = HitStopLevel.MEDIUM,
	},
	DRILL =
	{
		DAMAGE = 0.7,
		DAMAGE_FOCUS = 1.5,
		HITSTUN = 1,
		PUSHBACK = 1,
		PUSHBACK_FOCUS = 1,
		HITSTOP = HitStopLevel.MINOR,
		HITSTOP_FOCUS = HitStopLevel.MEDIUM,
	},
	REVERSE =
	{
		DAMAGE = 1,
		DAMAGE_FOCUS = 1.5,
		HITSTUN = 0,
		PUSHBACK = 1,
		PUSHBACK_FOCUS = 0,
		HITSTOP = HitStopLevel.MINOR,
		HITSTOP_FOCUS = HitStopLevel.MINOR,
	},


	-- Multithrust behaves differently & has its own hitbox function
	MULTITHRUST =
	{
		DAMAGE = 0.5,
		DAMAGE_FOCUS = 1,
		HITSTUN = 1,
		HITSTUN_KNOCKBACK = 10,
		PUSHBACK = 0.7,
		PUSHBACK_FOCUS = 0.1,
		HITSTOP = HitStopLevel.MEDIUM,
		HITSTOP_FOCUS = HitStopLevel.MEDIUM,
	},
}

local LIGHT_ATTACK_HEIGHT_MAX = 1.75
local LIGHT_ATTACK_HEIGHT_MIN = 1.3


local FOCUS_TESTPOINT_ENABLED = false -- jambell: I don't like how this behaves mostly. It nullifies a lot of visually true focus hits.
									  -- Because horizontal size of hitboxes is so inconsistent, it's hard to set a good value that works for all mobs.
									  -- Disabling this but leaving the code in case we change mind. But this favours fun.
local FOCUS_TESTPOINT_DISTANCE = 5.5

local function CheckIfFocusHit(inst, target)
	local focus = false

	if inst.sg.statemem.drillattack then

		inst.sg.statemem.drillcount = inst.sg.statemem.drillcount + 1

		local targets_hit = inst.components.hittracker:GetTargetsHit()
		if #targets_hit > 1 then
			focus = true
			inst.sg.statemem.knockbackhit = true
		elseif #targets_hit == 1 and inst.sg.statemem.drillcount == 4 then
			inst.sg.statemem.knockbackhit = true
		end

	elseif inst.sg.statemem.focushit then
		if FOCUS_TESTPOINT_ENABLED then
			local testpoint = inst:GetPosition()
			local x_offset = inst.Transform:GetFacing() == FACING_LEFT and -FOCUS_TESTPOINT_DISTANCE or FOCUS_TESTPOINT_DISTANCE --5.5 is the start of the focus hitbox... but physics sizes are quite drastically different, not always matching art size.
			testpoint.x = testpoint.x + x_offset

			local color = target.Physics:IsPointInBody(testpoint:unpack()) and WEBCOLORS.RED or WEBCOLORS.CYAN
			DebugDraw.GroundPoint(testpoint, nil, 1, color, 1, 3)

			if not target.Physics:IsPointInBody(testpoint:unpack()) then
				focus = true
			end
		else
			focus = true
		end
	end

	return focus
end

local function OnHitBoxTriggered(inst, data)
	local ATTACK_DATA = ATTACKS[inst.sg.statemem.attack_id]

	local dir = inst.Transform:GetFacingRotation()
	for i = 1, #data.targets do
		local v = data.targets[i]

		-- if inst.sg.statemem.drillattack then
		-- 	inst.sg.statemem.drillcount = inst.sg.statemem.drillcount + 1
		-- 	if inst.sg.statemem.drillcount > 4 then -- only possible when hitting multiple targets -- never focus against a single target.
		-- 		focushit = true
		-- 		damage_mod = ATTACK_DAMAGE_MOD.DRILL_FOCUS
		-- 		pushback = ATTACK_PUSHBACK.DRILL_FOCUS
		-- 		inst.sg.statemem.knockbackhit = true
		-- 	elseif inst.sg.statemem.drillcount == 4 then
		-- 		inst.sg.statemem.knockbackhit = true
		-- 	end
		-- end

		local focushit = CheckIfFocusHit(inst, v)

		local hitstoplevel = focushit and ATTACK_DATA.HITSTOP_FOCUS or ATTACK_DATA.HITSTOP
		local damage_mod = focushit and ATTACK_DATA.DAMAGE_FOCUS or ATTACK_DATA.DAMAGE
		local pushback = focushit and ATTACK_DATA.PUSHBACK_FOCUS or ATTACK_DATA.PUSHBACK
		local hitstun = ATTACK_DATA.HITSTUN

		local attack = Attack(inst, v)
		attack:SetDamageMod(damage_mod)
		attack:SetDir(dir)
		attack:SetHitstunAnimFrames(hitstun)
		attack:SetPushback(pushback)
		attack:SetFocus(focushit)
		attack:SetID(inst.sg.mem.attack_type)
		attack:SetNameID(inst.sg.statemem.attack_id)

		if inst.sg.statemem.knockbackhit and inst.sg.statemem.knockbackable then
			inst.components.combat:DoKnockbackAttack(attack)
		else
			inst.components.combat:DoBasicAttack(attack)
		end

		hitstoplevel = SGCommon.Fns.ApplyHitstop(attack, hitstoplevel)

		local hitfx_x_offset = 3.2
		local hitfx_y_offset = 1.5

		local distance = inst:GetDistanceSqTo(v)
		if distance >= 30 then
			hitfx_x_offset = hitfx_x_offset + 1.25
		elseif distance >= 25 then
			hitfx_x_offset = hitfx_x_offset + 0.75
		end
		inst.components.combat:SpawnHitFxForPlayerAttack(attack, "hits_player_pierce", v, inst, hitfx_x_offset, hitfx_y_offset, dir, hitstoplevel)

		-- TODO(dbriscoe): Why do we only spawn if target didn't block? We unconditionally spawn in hammer. Maybe we should move this to SpawnHitFxForPlayerAttack
		if v.sg ~= nil and v.sg:HasStateTag("block") then
		else
			SpawnHurtFx(inst, v, hitfx_x_offset, dir, hitstoplevel)
		end
	end
end

local function OnDistanceCheckHitboxTriggered(inst, data)
	inst.sg.statemem.enemynearby = true
end

local function OnMultithrustHitBoxTriggered(inst, data)
	local ATTACK_DATA = ATTACKS.MULTITHRUST

	local hitstoplevel = HitStopLevel.MEDIUM -- For the multithrust, we apply hitstop a little bit differently because of how many hits happen quickly. Usually we'd use SGCommon.Fns.ApplyHitstop()
	local playerhitstoplevel = hitstoplevel
	local shouldhitstop = false

	local dir = inst.Transform:GetFacingRotation()
	for i = 1, #data.targets do
		local v = data.targets[i]

		local hitsonthistarget = 0
		if inst.sg.statemem.targets and inst.sg.statemem.targets[v] then
			hitsonthistarget = inst.sg.statemem.targets[v]
		end
		local numhits = hitsonthistarget + 1
		inst.sg.statemem.targets[v] = numhits

		local kill = not v:IsDead() and not (v.sg and v.sg:HasStateTag("nokill"))
		local focushit = CheckIfFocusHit(inst, v)

		-- local hitstoplevel = focushit and ATTACK_DATA.HITSTOP_FOCUS or ATTACK_DATA.HITSTOP
		local damage_mod = focushit and ATTACK_DATA.DAMAGE_FOCUS or ATTACK_DATA.DAMAGE
		local pushback = focushit and ATTACK_DATA.PUSHBACK_FOCUS or ATTACK_DATA.PUSHBACK

		local attack = Attack(inst, v)
		attack:SetDamageMod(damage_mod)
		attack:SetFocus(focushit)
		attack:SetDir(dir)
		attack:SetID(inst.sg.mem.attack_type)
		attack:SetNameID(inst.sg.statemem.attack_id)

		if numhits < 7 then
			attack:SetPushback(pushback)
			attack:SetHitstunAnimFrames(ATTACK_DATA.HITSTUN)
			inst.components.combat:DoBasicAttack(attack)
		else
			-- jambell - tuning: pushback enough to be in range of Heavy
			attack:SetHitstunAnimFrames(ATTACK_DATA.HITSTUN_KNOCKBACK)
			inst.components.combat:DoKnockbackAttack(attack)
		end
		kill = kill and v:IsDead()

		local targethitstoplevel = hitstoplevel
		if kill then
			shouldhitstop = true
			local killstoplevel = v:HasTag("boss") and HitStopLevel.BOSSKILL or HitStopLevel.KILL
			targethitstoplevel = math.max(targethitstoplevel, killstoplevel)
			playerhitstoplevel = math.max(playerhitstoplevel, killstoplevel)
		end

		local fxhitstoplevel
		if numhits >= 7 then -- used to also include 'numhits =='
			shouldhitstop = true
			fxhitstoplevel = targethitstoplevel
			if v.components.hitstopper ~= nil then
				v.components.hitstopper:PushHitStop(targethitstoplevel)
			end

			SpawnHurtFx(inst, v, 3.2, dir, fxhitstoplevel)
		end

		local hitfx_x_offset = 3.2
		local hitfx_y_offset = 1.5
		inst.components.combat:SpawnHitFxForPlayerAttack(attack, "hits_player_pierce", v, inst, hitfx_x_offset, hitfx_y_offset, dir, fxhitstoplevel)
	end

	if shouldhitstop then
		inst.components.hitstopper:PushHitStop(playerhitstoplevel)
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
		onenter = function(inst) inst.sg:GoToState("light_attack1_pre") end,
	}),

	State({
		name = "default_heavy_attack",
		onenter = function(inst) inst.sg:GoToState("heavy_attack_pre") end,
	}),

	State({
		name = "default_dodge",
		onenter = function(inst)
			local weight = inst.components.weight:GetStatus()
			inst.sg:GoToState(roll_states[weight])
		end,
	}),

	State({
		name = "light_attack1_pre",
		tags = { "attack", "busy" },

		onenter = function(inst)
			inst:PushEvent("attack_state_start")
			inst.AnimState:PlayAnimation("polearm_atk_pre")
		end,

		timeline =
		{
			FrameEvent(0, function(inst) inst.sg.statemem.heavycombostate = "combo_heavy_attack_pre" end),
			-- FrameEvent(0, function(inst) inst.components.hitbox:PushBeam(0, 2.5, 1, HitPriority.PLAYER_DEFAULT) end),

			-- CANCELS
			FrameEvent(0, SGPlayerCommon.Fns.SetCanDodge),
		},

		events =
		{
			EventHandler("animover", function(inst)
				inst.sg:GoToState("light_attack1")
			end),
		},

		onexit = function(inst)
			inst.sg.statemem.enemynearby = false
		end,
	}),

	State({
		name = "light_attack1",
		tags = { "attack", "busy", "light_attack" },

		onenter = function(inst)
			inst.AnimState:PlayAnimation("polearm_atk")
			inst.sg.statemem.attack_id = "LIGHT_ATTACK_1"
			inst.components.playercontroller:OverrideControlQueueTicks("dodge", 10 * ANIM_FRAMES)
			inst.components.playercontroller:OverrideControlQueueTicks("heavyattack", 10 * ANIM_FRAMES)
			inst.components.playercontroller:OverrideControlQueueTicks("lightattack", 10 * ANIM_FRAMES)
		end,

		timeline =
		{
			--sounds
			FrameEvent(0, function(inst)
				local params = {}
				params.fmodevent = fmodtable.Event.Polearm_poke_1
				params.sound_max_count = 1
				soundutil.PlaySoundData(inst, params)
			end),

			FrameEvent(1, function(inst)
				SGCommon.Fns.SetMotorVelScaled(inst, 3) end),
			FrameEvent(2, function(inst)
				combatutil.StartMeleeAttack(inst)

				SGCommon.Fns.SetMotorVelScaled(inst, 1)
				inst.components.hitbox:StartRepeatTargetDelay()
				inst.sg.statemem.focushit = true
				inst.components.hitbox:PushBeam(5.5, 6, LIGHT_ATTACK_HEIGHT_MAX, HitPriority.PLAYER_DEFAULT)
			end),
			FrameEvent(3, function(inst)
				SGCommon.Fns.SetMotorVelScaled(inst, .5)
				inst.sg.statemem.focushit = false
				inst.components.hitbox:PushBeam(0, 5.8, LIGHT_ATTACK_HEIGHT_MAX, HitPriority.PLAYER_DEFAULT)
			end),
			FrameEvent(4, function(inst)
				SGCommon.Fns.SetMotorVelScaled(inst, .25)
				inst.components.hitbox:PushBeam(0, 5.8, LIGHT_ATTACK_HEIGHT_MAX, HitPriority.PLAYER_DEFAULT)
				combatutil.EndMeleeAttack(inst)
			end),
			FrameEvent(5, function(inst) inst.Physics:Stop() end),

			-- CANCELS
			-- FrameEvent(0, SGPlayerCommon.Fns.SetCanDodge),
			-- FrameEvent(2, SGPlayerCommon.Fns.SetCannotDodge),
			FrameEvent(7, SGPlayerCommon.Fns.SetCanDodge), -- ACTIVE FRAME + 3
			FrameEvent(10, function(inst)
				inst.sg.statemem.lightcombostate = "light_attack2"
				inst.sg.statemem.heavycombostate = "combo_heavy_attack_pre"
				SGPlayerCommon.Fns.TryQueuedLightOrHeavy(inst)

				SGPlayerCommon.Fns.SetCanSkill(inst)
			end),
		},

		events =
		{
			EventHandler("hitboxtriggered", OnHitBoxTriggered),
			EventHandler("animover", function(inst)
				inst.sg:GoToState("attack_pst")
			end),
		},

		onexit = function(inst)
			inst.Physics:Stop()
			SGPlayerCommon.Fns.DetachSwipeFx(inst)
			SGPlayerCommon.Fns.DetachPowerSwipeFx(inst)
			inst.components.hitbox:StopRepeatTargetDelay()
			inst.components.playercontroller:OverrideControlQueueTicks("dodge", nil)
			inst.components.playercontroller:OverrideControlQueueTicks("heavyattack", nil)
			inst.components.playercontroller:OverrideControlQueueTicks("lightattack", nil)
		end,
	}),

	State({
		name = "light_attack2",
		tags = { "attack", "busy", "light_attack" },

		onenter = function(inst)
			inst:PushEvent("attack_state_start")
			inst.AnimState:PlayAnimation("polearm_atk2")
			inst.sg.statemem.attack_id = "LIGHT_ATTACK_2"

			inst.components.playercontroller:OverrideControlQueueTicks("dodge", 10 * ANIM_FRAMES)
			inst.components.playercontroller:OverrideControlQueueTicks("lightattack", 10 * ANIM_FRAMES)
			inst.components.playercontroller:OverrideControlQueueTicks("heavyattack", 10 * ANIM_FRAMES)
		end,

		timeline =
		{
			--sounds
			FrameEvent(3, function(inst)
				local params = {}
				params.fmodevent = fmodtable.Event.Polearm_poke_2
				params.sound_max_count = 1
				soundutil.PlaySoundData(inst, params)
			end),

			FrameEvent(4, function(inst) SGCommon.Fns.SetMotorVelScaled(inst, 2) end),
			FrameEvent(5, function(inst)
				combatutil.StartMeleeAttack(inst)

				SGCommon.Fns.SetMotorVelScaled(inst, 1)
				inst.components.hitbox:StartRepeatTargetDelay()
				inst.sg.statemem.focushit = true
				inst.components.hitbox:PushBeam(5.5, 6, LIGHT_ATTACK_HEIGHT_MAX, HitPriority.PLAYER_DEFAULT)
			end),
			FrameEvent(6, function(inst)
				SGCommon.Fns.SetMotorVelScaled(inst, .5)
				inst.sg.statemem.focushit = false
				inst.components.hitbox:PushBeam(0, 5.8, LIGHT_ATTACK_HEIGHT_MAX, HitPriority.PLAYER_DEFAULT)
			end),
			FrameEvent(7, function(inst)
				SGCommon.Fns.SetMotorVelScaled(inst, .25)
				inst.components.hitbox:PushBeam(0, 5.8, LIGHT_ATTACK_HEIGHT_MAX, HitPriority.PLAYER_DEFAULT)

				combatutil.EndMeleeAttack(inst)
			end),
			FrameEvent(8, function(inst) inst.Physics:Stop() end),

			-- CANCELS
			-- FrameEvent(0, SGPlayerCommon.Fns.SetCanDodge),
			-- FrameEvent(5, SGPlayerCommon.Fns.SetCannotDodge),
			FrameEvent(10, SGPlayerCommon.Fns.SetCanDodge), -- ACTIVE FRAME + 3
			FrameEvent(10, SGPlayerCommon.Fns.SetCanSkill),
			FrameEvent(13, function(inst)
				inst.sg.statemem.lightcombostate = "light_attack3"
				inst.sg.statemem.heavycombostate = "combo_heavy_attack_pre"
				SGPlayerCommon.Fns.TryQueuedLightOrHeavy(inst)
			end),
		},

		events =
		{
			EventHandler("hitboxtriggered", OnHitBoxTriggered),
			EventHandler("animover", function(inst)
				inst.sg:GoToState("attack_pst")
			end),
		},

		onexit = function(inst)
			inst.Physics:Stop()
			inst.components.hitbox:StopRepeatTargetDelay()
			inst.components.playercontroller:OverrideControlQueueTicks("dodge", nil)
			inst.components.playercontroller:OverrideControlQueueTicks("lightattack", nil)
			inst.components.playercontroller:OverrideControlQueueTicks("heavyattack", nil)
		end,
	}),

	State({
		name = "light_attack3",
		tags = { "attack", "busy", "light_attack" },

		onenter = function(inst)
			inst:PushEvent("attack_state_start")
			inst.AnimState:PlayAnimation("polearm_atk3")
			inst.sg.statemem.attack_id = "LIGHT_ATTACK_3"

			inst.components.playercontroller:OverrideControlQueueTicks("heavyattack", 16 * ANIM_FRAMES)
			inst.components.playercontroller:OverrideControlQueueTicks("dodge", 16 * ANIM_FRAMES)
		end,

		timeline =
		{
			--sounds
			FrameEvent(6, function(inst)
				local params = {}
				params.fmodevent = fmodtable.Event.Polearm_poke_3
				params.sound_max_count = 1
				soundutil.PlaySoundData(inst, params)
			end),

			FrameEvent(7, function(inst) SGCommon.Fns.SetMotorVelScaled(inst, 10) end),
			FrameEvent(8, function(inst)
				combatutil.StartMeleeAttack(inst)

				SGCommon.Fns.SetMotorVelScaled(inst, 1)
				inst.components.hitbox:StartRepeatTargetDelay()
				inst.sg.statemem.focushit = true
				inst.components.hitbox:PushBeam(5.5, 6, LIGHT_ATTACK_HEIGHT_MAX, HitPriority.PLAYER_DEFAULT)
			end),
			FrameEvent(9, function(inst)
				SGCommon.Fns.SetMotorVelScaled(inst, .5)
				inst.sg.statemem.focushit = false
				inst.components.hitbox:PushBeam(0, 5.8, LIGHT_ATTACK_HEIGHT_MAX, HitPriority.PLAYER_DEFAULT)
			end),
			FrameEvent(10, function(inst)
				SGCommon.Fns.SetMotorVelScaled(inst, .25)
				inst.components.hitbox:PushBeam(0, 5.8, LIGHT_ATTACK_HEIGHT_MAX, HitPriority.PLAYER_DEFAULT)

				combatutil.EndMeleeAttack(inst)
			end),
			FrameEvent(11, function(inst) inst.Physics:Stop() end),

			-- CANCELS
			FrameEvent(0, function(inst)
			end),
			FrameEvent(8, function(inst)
			end),
			FrameEvent(16, function(inst)
				inst.sg.statemem.heavycombostate = "multithrust_attack"
				SGPlayerCommon.Fns.TryQueuedAction(inst, "heavyattack")
			end),

			-- CANCELS
			-- FrameEvent(0, SGPlayerCommon.Fns.SetCanDodge),
			-- FrameEvent(8, SGPlayerCommon.Fns.SetCannotDodge),
			FrameEvent(13, SGPlayerCommon.Fns.SetCanDodge), -- ACTIVE FRAME + 3
			FrameEvent(13, SGPlayerCommon.Fns.SetCanSkill),
		},

		events =
		{
			EventHandler("hitboxtriggered", OnHitBoxTriggered),
			EventHandler("animover", function(inst)
				inst.sg:GoToState("attack_pst")
			end),
		},

		onexit = function(inst)
			inst.Physics:Stop()
			SGPlayerCommon.Fns.DetachSwipeFx(inst)
			SGPlayerCommon.Fns.DetachPowerSwipeFx(inst)
			inst.components.hitbox:StopRepeatTargetDelay()
			inst.components.playercontroller:OverrideControlQueueTicks("dodge", nil)
			inst.components.playercontroller:OverrideControlQueueTicks("heavyattack", nil)
		end,
	}),

	State({
		name = "attack_pst",
		tags = { },

		onenter = function(inst)
			inst.AnimState:PlayAnimation("polearm_atk_pst")
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
		name = "heavy_attack_pre",
		tags = { "attack", "busy", "heavy_attack" },

		onenter = function(inst)
			inst:PushEvent("attack_state_start")
			inst.AnimState:PlayAnimation("polearm_heavy_atk_pre")
		end,

		timeline =
		{
			FrameEvent(0, function(inst)
				inst.sg.statemem.lightcombostate = "default_light_attack"
			end),

			-- CANCELS
			-- FrameEvent(0, SGPlayerCommon.Fns.SetCanDodge),
		},

		events =
		{
			EventHandler("animover", function(inst)
				inst.sg:GoToState("heavy_attack")
			end),
		},
	}),

	State({
		name = "combo_heavy_attack_pre",
		tags = { "attack", "busy", "heavy_attack" },

		onenter = function(inst)
			inst:PushEvent("attack_state_start")
			inst.AnimState:PlayAnimation("polearm_combo_heavy_atk_pre")
		end,

		timeline =
		{
			-- CANCELS
			-- FrameEvent(0, SGPlayerCommon.Fns.SetCanDodge),
		},

		events =
		{
			EventHandler("animover", function(inst)
				inst.sg:GoToState("heavy_attack")
			end),
		},
	}),

	State({
		name = "rolling_heavy_attack_back_pre",
		tags = { "attack", "busy", "heavy_attack" },

		onenter = function(inst)
			inst:PushEvent("attack_state_start")
			inst.AnimState:PlayAnimation("polearm_rev_heavy_atk_pre")
		end,

		events =
		{
			EventHandler("animover", function(inst)
				inst.sg:GoToState("heavy_attack")
			end),
		},
	}),


	State({
		name = "heavy_attack",
		tags = { "attack", "busy", "airborne", "heavy_attack" },

		onenter = function(inst, data)
			inst:PushEvent("attack_state_start")
			inst.AnimState:PlayAnimation(data and data.reverse and "polearm_rev_heavy_atk" or "polearm_heavy_atk")
			inst.sg.statemem.speedmult = data and data.speedmult or 1
			if inst.sg.statemem.speedmult < 0 then
				inst:FlipFacingAndRotation()
			end
			SGCommon.Fns.SetMotorVelScaled(inst, 7 * inst.sg.statemem.speedmult)
			inst.sg.statemem.attack_id = "HEAVY_ATTACK"
			SGCommon.Fns.StartJumpingOverHoles(inst)

			-- If the player clicks dodge or attack while in the air, open the queue up to allow a pre-press.
			inst.components.playercontroller:OverrideControlQueueTicks("dodge", 10 * ANIM_FRAMES)
			inst.components.playercontroller:OverrideControlQueueTicks("lightattack", 10 * ANIM_FRAMES)
		end,

		timeline =
		{
			--sounds
			FrameEvent(10, function(inst)
				local params = {}
				params.fmodevent = fmodtable.Event.Polearm_jump_atk
				params.sound_max_count = 1
				soundutil.PlaySoundData(inst, params)
			end),

			--physics
			FrameEvent(3, function(inst) SGCommon.Fns.SetMotorVelScaled(inst, 6 * inst.sg.statemem.speedmult) end),
			FrameEvent(4, function(inst) SGCommon.Fns.SetMotorVelScaled(inst, 5.5 * inst.sg.statemem.speedmult) end),
			FrameEvent(5, function(inst) SGCommon.Fns.SetMotorVelScaled(inst, 5 * inst.sg.statemem.speedmult) end),
			FrameEvent(6, function(inst) SGCommon.Fns.SetMotorVelScaled(inst, 4 * inst.sg.statemem.speedmult) end),
			FrameEvent(7, function(inst) SGCommon.Fns.SetMotorVelScaled(inst, 3 * inst.sg.statemem.speedmult) end),
			FrameEvent(8, function(inst) SGCommon.Fns.SetMotorVelScaled(inst, 5.5 * inst.sg.statemem.speedmult) end),
			FrameEvent(9, function(inst) SGCommon.Fns.SetMotorVelScaled(inst, 10 * inst.sg.statemem.speedmult) end),
			FrameEvent(10, function(inst) SGCommon.Fns.SetMotorVelScaled(inst, 6 * inst.sg.statemem.speedmult) end),
			FrameEvent(11, function(inst) SGCommon.Fns.SetMotorVelScaled(inst, 5 * inst.sg.statemem.speedmult) end),
			FrameEvent(12, function(inst) SGCommon.Fns.SetMotorVelScaled(inst, 4.5 * inst.sg.statemem.speedmult) end),
			FrameEvent(13, function(inst) SGCommon.Fns.SetMotorVelScaled(inst, 4 * inst.sg.statemem.speedmult) end),
			FrameEvent(14, function(inst) SGCommon.Fns.SetMotorVelScaled(inst, 3.5 * inst.sg.statemem.speedmult) end),
			FrameEvent(15, function(inst) SGCommon.Fns.SetMotorVelScaled(inst, 3 * inst.sg.statemem.speedmult) end),
			FrameEvent(16, function(inst) SGCommon.Fns.SetMotorVelScaled(inst, 2.5 * inst.sg.statemem.speedmult) end),
			FrameEvent(17, function(inst) SGCommon.Fns.SetMotorVelScaled(inst, 2 * inst.sg.statemem.speedmult) end),
			FrameEvent(18, function(inst) SGCommon.Fns.SetMotorVelScaled(inst, 2.5 * inst.sg.statemem.speedmult) end),
			FrameEvent(19, function(inst) SGCommon.Fns.SetMotorVelScaled(inst, 2 * inst.sg.statemem.speedmult) end),
			FrameEvent(20, function(inst) SGCommon.Fns.SetMotorVelScaled(inst, 0.5 * inst.sg.statemem.speedmult) end),
			--

			-- FrameEvent(10, function(inst) SGPlayerCommon.Fns.AttachSwipeFx(inst, "fx_polearm_heavy_atk") end),
			-- FrameEvent(10, function(inst) SGPlayerCommon.Fns.AttachPowerSwipeFx(inst, "fx_polearm_heavy_atk") end),


			FrameEvent(2, function(inst)
				SGCommon.Fns.SetMotorVelScaled(inst, 6.5 * inst.sg.statemem.speedmult)
				inst.sg:AddStateTag("airborne_high")
			end),

			FrameEvent(10, function(inst)
				combatutil.StartMeleeAttack(inst)

				inst.components.hitbox:StartRepeatTargetDelay()
				inst.sg.statemem.focushit = true
				inst.components.hitbox:PushBeam(5.7, 6.2, LIGHT_ATTACK_HEIGHT_MAX, HitPriority.PLAYER_DEFAULT)
			end),
			FrameEvent(11, function(inst)
				inst.sg.statemem.focushit = false
				inst.components.hitbox:PushBeam(0.5, 6.1, LIGHT_ATTACK_HEIGHT_MAX, HitPriority.PLAYER_DEFAULT)
			end),
			FrameEvent(12, function(inst)
				inst.components.hitbox:PushBeam(0.5, 6.1, LIGHT_ATTACK_HEIGHT_MAX, HitPriority.PLAYER_DEFAULT)

				combatutil.EndMeleeAttack(inst)
			end),

			FrameEvent(18, function(inst) inst.sg:RemoveStateTag("airborne_high") end),
			FrameEvent(20, function(inst)
				inst.sg:RemoveStateTag("airborne")
				SGCommon.Fns.StopJumpingOverHoles(inst)
			end),
			FrameEvent(21, function(inst) inst.Physics:Stop() end),
			FrameEvent(24, function(inst)
				inst.sg.statemem.lightcombostate = "light_attack3"
				SGPlayerCommon.Fns.TryQueuedAction(inst, "lightattack")
			end),

			-- Cancels
			FrameEvent(23, SGPlayerCommon.Fns.SetCanDodge),
			FrameEvent(23, SGPlayerCommon.Fns.SetCanSkill),
		},

		events =
		{
			EventHandler("hitboxtriggered", OnHitBoxTriggered),
			EventHandler("animover", function(inst)
				inst.sg:GoToState("attack_pst")
			end),
		},

		onexit = function(inst)
			inst.Physics:Stop()
			SGPlayerCommon.Fns.DetachSwipeFx(inst)
			SGPlayerCommon.Fns.DetachPowerSwipeFx(inst)
			inst.components.hitbox:StopRepeatTargetDelay()
			inst.components.playercontroller:OverrideControlQueueTicks("dodge", nil)
				inst.components.playercontroller:OverrideControlQueueTicks("lightattack", nil)
			SGCommon.Fns.StopJumpingOverHoles(inst)
		end,
	}),

	State({
		name = "multithrust_attack",
		tags = { "attack", "busy", "heavy_attack" },

		onenter = function(inst)
			inst:PushEvent("attack_state_start")
			inst.AnimState:PlayAnimation("polearm_multithrust_atk")
			inst.sg.statemem.multithrustfx = nil
			inst.sg.statemem.multithrustpowerfx = nil
			inst.sg.statemem.attack_id = "MULTITHRUST" -- unnecessary, but here for consistancy's sake
			inst.components.playercontroller:OverrideControlQueueTicks("dodge", 12 * ANIM_FRAMES)
		end,

		timeline =
		{
			--sounds
			FrameEvent(0, function(inst)
				local params = {}
				params.fmodevent = fmodtable.Event.Polearm_poke_4_spin
				params.sound_max_count = 1
				soundutil.PlaySoundData(inst, params)
			end),
			FrameEvent(14, function(inst)
				local params = {}
				params.fmodevent = fmodtable.Event.Polearm_poke_4_flurry
				params.sound_max_count = 1
				soundutil.PlaySoundData(inst, params)
			end),

			-- FrameEvent(0, function(inst) inst.sg.statemem.multithrustfx = SGPlayerCommon.Fns.AttachSwipeFx(inst, "fx_polearm_multithrust_atk") end),
			-- FrameEvent(0, function(inst) inst.sg.statemem.multithrustpowerfx = SGPlayerCommon.Fns.AttachPowerSwipeFx(inst, "fx_polearm_multithrust_atk") end),

			FrameEvent(11, function(inst) SGCommon.Fns.SetMotorVelScaled(inst, 3) end),
			FrameEvent(12, function(inst)
				combatutil.StartMeleeAttack(inst)

				SGCommon.Fns.SetMotorVelScaled(inst, 1)
				inst.sg.statemem.targets = {}
				inst.components.hitbox:StartRepeatTargetDelayAnimFrames(2)
				inst.sg.statemem.focushit = true
				inst.components.hitbox:PushBeam(5.8, 6.3, LIGHT_ATTACK_HEIGHT_MAX, HitPriority.PLAYER_DEFAULT)
			end),
			FrameEvent(13, function(inst)
				SGCommon.Fns.SetMotorVelScaled(inst, .5)
				inst.sg.statemem.focushit = false
				inst.components.hitbox:PushBeam(0, 6.2, LIGHT_ATTACK_HEIGHT_MAX, HitPriority.PLAYER_DEFAULT)
			end),

			FrameEvent(14, function(inst)
				SGCommon.Fns.SetMotorVelScaled(inst, .25)
				inst.sg.statemem.focushit = true
				inst.components.hitbox:PushBeam(5.8, 6.3, LIGHT_ATTACK_HEIGHT_MAX, HitPriority.PLAYER_DEFAULT)
			end),
			FrameEvent(15, function(inst)
				inst.sg.statemem.focushit = false
				inst.components.hitbox:PushBeam(0, 6.2, LIGHT_ATTACK_HEIGHT_MAX, HitPriority.PLAYER_DEFAULT)
			end),


			FrameEvent(16, function(inst)
				inst.sg.statemem.focushit = true
				inst.components.hitbox:PushBeam(5.8, 6.3, LIGHT_ATTACK_HEIGHT_MAX, HitPriority.PLAYER_DEFAULT)
			end),
			FrameEvent(17, function(inst)
				inst.sg.statemem.focushit = false
				inst.components.hitbox:PushBeam(0, 6.2, LIGHT_ATTACK_HEIGHT_MAX, HitPriority.PLAYER_DEFAULT)
			end),


			FrameEvent(18, function(inst)
				inst.sg.statemem.focushit = true
				inst.components.hitbox:PushBeam(5.8, 6.3, LIGHT_ATTACK_HEIGHT_MAX, HitPriority.PLAYER_DEFAULT)
			end),
			FrameEvent(19, function(inst)
				inst.sg.statemem.focushit = false
				inst.components.hitbox:PushBeam(0, 6.2, LIGHT_ATTACK_HEIGHT_MAX, HitPriority.PLAYER_DEFAULT)
			end),


			FrameEvent(20, function(inst)
				inst.sg.statemem.focushit = true
				inst.components.hitbox:PushBeam(5.8, 6.3, LIGHT_ATTACK_HEIGHT_MAX, HitPriority.PLAYER_DEFAULT)
			end),
			FrameEvent(21, function(inst)
				inst.sg.statemem.focushit = false
				inst.components.hitbox:PushBeam(0, 6.2, LIGHT_ATTACK_HEIGHT_MAX, HitPriority.PLAYER_DEFAULT)
			end),


			FrameEvent(22, function(inst)
				inst.sg.statemem.focushit = true
				inst.components.hitbox:PushBeam(5.8, 6.3, LIGHT_ATTACK_HEIGHT_MAX, HitPriority.PLAYER_DEFAULT)
			end),
			FrameEvent(23, function(inst)
				inst.sg.statemem.focushit = false
				inst.components.hitbox:PushBeam(0, 6.2, LIGHT_ATTACK_HEIGHT_MAX, HitPriority.PLAYER_DEFAULT)
			end),


			FrameEvent(24, function(inst)
				inst.sg.statemem.focushit = true
				inst.components.hitbox:StartRepeatTargetDelayAnimFrames(4) -- The final hit of the multithrust has longer hitstop, so increase the repeat hit delay so the final non-crit hit doesn't sneak through
				inst.components.hitbox:PushBeam(5.8, 6.3, LIGHT_ATTACK_HEIGHT_MAX, HitPriority.PLAYER_DEFAULT)
			end),
			FrameEvent(25, function(inst)
				inst.sg.statemem.focushit = false
				inst.components.hitbox:PushBeam(0, 6.2, LIGHT_ATTACK_HEIGHT_MAX, HitPriority.PLAYER_DEFAULT)

				combatutil.EndMeleeAttack(inst)

			end),


			FrameEvent(25, function(inst) SGCommon.Fns.SetMotorVelScaled(inst, .1) end),
			FrameEvent(26, function(inst) inst.Physics:Stop() end),

			-- Cancels
			-- FrameEvent(0, SGPlayerCommon.Fns.SetCanDodge),
			-- FrameEvent(12, SGPlayerCommon.Fns.SetCannotDodge),

			FrameEvent(34, SGPlayerCommon.Fns.SetCanSkill),
			FrameEvent(34, SGPlayerCommon.Fns.SetCanDodge),
		},

		events =
		{
			EventHandler("hitboxtriggered", OnMultithrustHitBoxTriggered),
			EventHandler("animover", function(inst)
				inst.sg:GoToState("attack_pst")
			end),
		},

		onexit = function(inst)
			inst.Physics:Stop()
			SGPlayerCommon.Fns.DetachSwipeFx(inst)
			SGPlayerCommon.Fns.DetachPowerSwipeFx(inst)
			inst.components.hitbox:StopRepeatTargetDelay()
			SGCommon.Fns.DestroyFx(inst, "multithrustfx")
			SGCommon.Fns.DestroyFx(inst, "multithrustpowerfx")
		end,
	}),

	State({
		name = "rolling_drill_attack_very_far",
		onenter = function(inst) inst.sg:GoToState("rolling_drill_attack", 1.5) end,
	}),

	State({
		name = "rolling_drill_attack_far",
		onenter = function(inst) inst.sg:GoToState("rolling_drill_attack", 1.25) end,
	}),

	State({
		name = "rolling_drill_attack_med",
		onenter = function(inst) inst.sg:GoToState("rolling_drill_attack", .8) end,
	}),

	State({
		name = "rolling_drill_attack_very_short",
		onenter = function(inst) inst.sg:GoToState("rolling_drill_attack", .25) end,
	}),

	State({
		name = "rolling_drill_attack",
		tags = { "attack", "busy", "airborne", "projectile_immune", "light_attack" },

		onenter = function(inst, speedmult)
			inst:PushEvent("attack_state_start")
			inst.AnimState:PlayAnimation("polearm_roll_atk")

			inst.sg.statemem.speedmult = speedmult or 1
			SGPlayerCommon.Fns.SetRollPhysicsSize(inst)
			SGCommon.Fns.SetMotorVelScaled(inst, 12 * inst.sg.statemem.speedmult)
			inst.sg.statemem.hitboxsize = inst.HitBox:GetSize()
			inst.HitBox:SetNonPhysicsRect(inst.sg.statemem.hitboxsize * 1.5)
			inst.sg.statemem.drillattack = true
			inst.sg.statemem.drillcount = 0
			inst.sg.statemem.drillfrontfx = nil
			inst.sg.statemem.drillbackfx = nil

			SGCommon.Fns.StartJumpingOverHoles(inst)

			inst.sg.statemem.attack_id = "DRILL"
		end,

		onupdate = function(inst)
			if inst.sg.statemem.hitting then
				inst.components.hitbox:PushBeam(0, 4, .85, HitPriority.PLAYER_DEFAULT)
				inst.components.hitbox:PushBeam(0, 4.5, .5, HitPriority.PLAYER_DEFAULT)
				inst.components.hitbox:PushBeam(0.5, 2, 1.5, HitPriority.PLAYER_DEFAULT)
			end
		end,

		timeline =
		{
			--sounds
			FrameEvent(0, function(inst)
				local params = {}
				params.fmodevent = fmodtable.Event.Polearm_spin_atk
				params.sound_max_count = 1
				soundutil.PlaySoundData(inst, params)
			end),

			--physics
			FrameEvent(14, function(inst) SGCommon.Fns.SetMotorVelScaled(inst, 6 * inst.sg.statemem.speedmult) end),
			FrameEvent(15, function(inst) SGCommon.Fns.SetMotorVelScaled(inst, 5 * inst.sg.statemem.speedmult) end),
			FrameEvent(15, function(inst) SGCommon.Fns.SetMotorVelScaled(inst, 5 * inst.sg.statemem.speedmult) end),
			FrameEvent(16, function(inst) SGCommon.Fns.SetMotorVelScaled(inst, 4 * inst.sg.statemem.speedmult) end),
			FrameEvent(17, function(inst) SGCommon.Fns.SetMotorVelScaled(inst, 3 * inst.sg.statemem.speedmult) end),
			FrameEvent(18, function(inst) SGCommon.Fns.SetMotorVelScaled(inst, 2 * inst.sg.statemem.speedmult) end),
			FrameEvent(19, function(inst) SGCommon.Fns.SetMotorVelScaled(inst, 1 * inst.sg.statemem.speedmult) end),
			FrameEvent(20, function(inst) inst.Physics:Stop() end),
			--

			-- FrameEvent(0, function(inst)
			-- 	inst.sg.statemem.drillfrontfx = SGPlayerCommon.Fns.AttachSwipeFx(inst, "fx_polearm_roll_atk")
			-- 	inst.sg.statemem.drillpowerfx = SGPlayerCommon.Fns.AttachPowerSwipeFx(inst, "fx_polearm_roll_atk")
			-- end),

			FrameEvent(2, function(inst)
				combatutil.StartMeleeAttack(inst)

				inst.sg.statemem.focushit = false
				inst.components.hitbox:StartRepeatTargetDelayAnimFrames(3) --decrease to allow for more hits per drill, increase for less hits for drill
				inst.sg.statemem.hitting = true
			end),
			FrameEvent(10, function(inst)
				inst.sg.statemem.knockbackable = true
			end),
			FrameEvent(12, function(inst)
				inst.sg.statemem.hitting = false
				combatutil.EndMeleeAttack(inst)
				inst.components.playercontroller:OverrideControlQueueTicks("dodge", 15 * ANIM_FRAMES)
			end),
			FrameEvent(14, function(inst)
				inst.sg:RemoveStateTag("airborne")
				SGCommon.Fns.StopJumpingOverHoles(inst)
			end),

			FrameEvent(18, function(inst)
				inst.sg.statemem.lightcombostate = "light_attack2"

				local data = inst.components.playercontroller:GetQueuedControl("lightattack")
				if data ~= nil then
					if SGPlayerCommon.Fns.IsForwardControl(inst, data) then
						SGPlayerCommon.Fns.DoAction(inst, data)
					end
				end
			end),

			FrameEvent(23, function(inst)
				-- Delay some time before setting hitbox size back down.
				-- Make this later to make this move worse, and make this earlier to make this move better.
				inst.HitBox:SetNonPhysicsRect(inst.sg.statemem.hitboxsize)
			end),

			-- Cancels
			FrameEvent(19, SGPlayerCommon.Fns.SetCanAttackOrAbility),
			FrameEvent(25, SGPlayerCommon.Fns.SetCanDodge),
		},

		events =
		{
			EventHandler("controlevent", function(inst, data)
				if data.control == "lightattack" then
					if inst.sg.statemem.lightcombostate ~= nil then
						if SGPlayerCommon.Fns.IsForwardControl(inst, data) then
							SGPlayerCommon.Fns.DoAction(inst, data)
						end
					end
				end
			end),
			EventHandler("hitboxtriggered", OnHitBoxTriggered),
			EventHandler("animover", function(inst)
				inst.sg.statemem.heavycombostate = "rolling_heavy_attack_med"

				local data = inst.components.playercontroller:GetQueuedControl("heavyattack")
				if data ~= nil then
					if SGPlayerCommon.Fns.IsForwardControl(inst, data) then
						if SGPlayerCommon.Fns.DoAction(inst, data) then
							return
						end
					end
				end

				inst.sg:GoToState("attack_pst")
			end),
		},

		onexit = function(inst)
			inst.Physics:Stop()
			inst.HitBox:SetNonPhysicsRect(inst.sg.statemem.hitboxsize)
			SGPlayerCommon.Fns.UndoRollPhysicsSize(inst)
			inst.components.hitbox:StopRepeatTargetDelay()
			inst.components.playercontroller:OverrideControlQueueTicks("dodge", nil)
			SGCommon.Fns.StopJumpingOverHoles(inst)

			SGPlayerCommon.Fns.DetachSwipeFx(inst)
			SGPlayerCommon.Fns.DetachSwipeFx(inst, true)
			SGPlayerCommon.Fns.DetachPowerSwipeFx(inst)
			SGCommon.Fns.DestroyFx(inst, "drillfrontfx")
			SGCommon.Fns.DestroyFx(inst, "drillpowerfx")
			SGCommon.Fns.DestroyFx(inst, "drillbackfx")
		end,
	}),

	State({
		name = "rolling_heavy_attack_very_far",
		onenter = function(inst) inst.sg:GoToState("heavy_attack", { speedmult = 1.55 }) end,
	}),

	State({
		name = "rolling_heavy_attack_far",
		onenter = function(inst) inst.sg:GoToState("heavy_attack", { speedmult = 1.2 }) end,
	}),

	State({
		name = "rolling_heavy_attack_med",
		onenter = function(inst) inst.sg:GoToState("heavy_attack", { speedmult = 1 }) end,
	}),

	State({
		name = "rolling_heavy_attack_very_short",
		onenter = function(inst) inst.sg:GoToState("heavy_attack", { speedmult = .25 }) end,
	}),

	State({
		name = "rolling_heavy_attack_back_far",
		onenter = function(inst)
			inst.sg:GoToState("heavy_attack", { speedmult = -1.0, reverse = true })
		end,
	}),

	State({
		name = "rolling_heavy_attack_back_very_far",
		onenter = function(inst)
			inst.sg:GoToState("heavy_attack", { speedmult = -1.4, reverse = true })
		end,
	}),

	State({
		name = "rolling_heavy_attack_back",
		onenter = function(inst)
			inst.sg:GoToState("heavy_attack", { speedmult = -0.85, reverse = true })
		end,
	}),

	State({
		name = "rolling_heavy_attack_back_med",
		onenter = function(inst)
			inst.sg:GoToState("heavy_attack", { speedmult = -0.7, reverse = true })
		end,
	}),

	State({
		name = "rolling_heavy_attack_back_short",
		onenter = function(inst)
			inst.sg:GoToState("heavy_attack", { speedmult = -0.5, reverse = true })
		end,
	}),

	State({
		name = "rolling_heavy_attack_back_very_short",
		onenter = function(inst)
			inst.sg:GoToState("heavy_attack", { speedmult = -0.35, reverse = true })
		end,
	}),


	-- these far -> very_short versions of this state are to approximate the same length of a roll regardless of when we cancelled into the fading L
	State({
		name = "fading_light_attack_far",
		onenter = function(inst)
			inst.sg:GoToState("fading_light_attack", .9)
		end,
	}),
	State({
		name = "fading_light_attack_med",
		onenter = function(inst) inst.sg:GoToState("fading_light_attack", .65) end,
	}),

	State({
		name = "fading_light_attack_short",
		onenter = function(inst) inst.sg:GoToState("fading_light_attack", .35) end,
	}),
	State({
		name = "fading_light_attack_very_short",
		onenter = function(inst) inst.sg:GoToState("fading_light_attack", .15) end,
	}),

	State({
		name = "fading_light_attack",
		tags = { "attack", "busy", "light_attack" },

		onenter = function(inst, speedmult)
			inst:PushEvent("attack_state_start")
			inst:FlipFacingAndRotation()
			inst.AnimState:PlayAnimation("polearm_roll_rev_atk")
			inst.sg.statemem.speedmult = speedmult or 1

			inst.sg.statemem.attack_id = "REVERSE"
		end,

		timeline =
		{
			--physics
			FrameEvent(0, function(inst) SGCommon.Fns.SetMotorVelScaled(inst, -9.5 * inst.sg.statemem.speedmult) end),
			FrameEvent(1, function(inst) SGCommon.Fns.SetMotorVelScaled(inst, -9 * inst.sg.statemem.speedmult) end),
			FrameEvent(2, function(inst) SGCommon.Fns.SetMotorVelScaled(inst, -8.5 * inst.sg.statemem.speedmult) end),
			FrameEvent(5, function(inst) SGCommon.Fns.SetMotorVelScaled(inst, -10.5 * inst.sg.statemem.speedmult) end),
			FrameEvent(7, function(inst) SGCommon.Fns.SetMotorVelScaled(inst, -3.5 * inst.sg.statemem.speedmult) end),
			FrameEvent(9, function(inst) SGCommon.Fns.SetMotorVelScaled(inst, -2.5 * inst.sg.statemem.speedmult) end),
			FrameEvent(11, function(inst) SGCommon.Fns.SetMotorVelScaled(inst, -1.5 * inst.sg.statemem.speedmult) end),
			FrameEvent(14, function(inst) inst.Physics:Stop() end),
			--

			FrameEvent(6, function(inst)
				combatutil.StartMeleeAttack(inst)

				inst.sg.statemem.focushit = true
				inst.components.hitbox:PushBeam(5.6, 6.1, LIGHT_ATTACK_HEIGHT_MAX, HitPriority.PLAYER_DEFAULT)
				inst.components.hitbox:StartRepeatTargetDelay()
			end),
			FrameEvent(7, function(inst)
				inst.sg.statemem.focushit = false

				inst.components.hitbox:PushBeam(0.5, 5.6, LIGHT_ATTACK_HEIGHT_MAX, HitPriority.PLAYER_DEFAULT)
			end),
			FrameEvent(8, function(inst)
				inst.components.hitbox:PushBeam(0.5, 5.6, LIGHT_ATTACK_HEIGHT_MAX, HitPriority.PLAYER_DEFAULT)

				combatutil.EndMeleeAttack(inst)
			end),

			FrameEvent(9, SGPlayerCommon.Fns.DetachSwipeFx),
			FrameEvent(9, SGPlayerCommon.Fns.DetachPowerSwipeFx),

			-- CANCELS
			FrameEvent(13, function(inst)
				inst.sg.statemem.lightcombostate = "light_attack2"
				inst.sg.statemem.heavycombostate = "combo_heavy_attack_pre"
				SGPlayerCommon.Fns.TryQueuedLightOrHeavy(inst)
			end),

			FrameEvent(14, SGPlayerCommon.Fns.SetCanDodge),
			FrameEvent(14, SGPlayerCommon.Fns.SetCanSkill),
		},

		events =
		{
			EventHandler("hitboxtriggered", OnHitBoxTriggered),
			EventHandler("animover", function(inst)
				inst.sg:GoToState("attack_pst")
			end),
		},

		onexit = function(inst)
			inst.Physics:Stop()
			SGPlayerCommon.Fns.DetachSwipeFx(inst)
			SGPlayerCommon.Fns.DetachPowerSwipeFx(inst)
			inst.components.hitbox:StopRepeatTargetDelay()
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
		state.timeline[id + 1] = FrameEvent(0, function(inst)
				inst.sg.statemem.lightcombostate = "rolling_drill_attack"
				inst.sg.statemem.heavycombostate = "rolling_heavy_attack_far"
				inst.sg.statemem.reverselightstate = "fading_light_attack_far"
				inst.sg.statemem.reverseheavystate = "rolling_heavy_attack_back_far"
			end)
		state.timeline[id + 1].idx = id + 1

		state.timeline[id + 2] = FrameEvent(2, function(inst)
				inst.sg.statemem.reverselightstate = "fading_light_attack_med"
				inst.sg.statemem.reverseheavystate = "rolling_heavy_attack_back_med"
			end)
		state.timeline[id + 2].idx = id + 2

		state.timeline[id + 3] = FrameEvent(9, function(inst)
				inst.sg.statemem.reverselightstate = "fading_light_attack_short"
				inst.sg.statemem.reverseheavystate = "rolling_heavy_attack_back_short"
			end)
		state.timeline[id + 3].idx = id + 3

		state.timeline[id + 4] = FrameEvent(10, function(inst)
				inst.sg.statemem.lightcombostate = "rolling_drill_attack_med"
				inst.sg.statemem.heavycombostate = "rolling_heavy_attack_med"
			end)
		state.timeline[id + 4].idx = id + 4

		table.sort(state.timeline, function(a,b) return a.frame < b.frame end)
	end

	if state.name == "roll_pst" then
		local id = #state.timeline
		state.timeline[id + 1] = FrameEvent(0, function(inst)
			inst.sg.statemem.lightcombostate = "rolling_drill_attack_med"
			inst.sg.statemem.heavycombostate = "rolling_heavy_attack_med"
			inst.sg.statemem.reverselightstate = "fading_light_attack_very_short"
			inst.sg.statemem.reverseheavystate = "rolling_heavy_attack_back_very_short"
			end)
		state.timeline[id + 1].idx = id + 1

		table.sort(state.timeline, function(a,b) return a.frame < b.frame end)
	end

	-- LIGHT ROLL
	if state.name == "roll_light" then
		local id = #state.timeline
		state.timeline[id + 1] = FrameEvent(0, function(inst)
				inst.sg.statemem.lightcombostate = "rolling_drill_attack_far"
				inst.sg.statemem.heavycombostate = "rolling_heavy_attack_med"
				inst.sg.statemem.reverselightstate = "fading_light_attack"
				inst.sg.statemem.reverseheavystate = "rolling_heavy_attack_back"
			end)
		state.timeline[id + 1].idx = id + 1

		state.timeline[id + 2] = FrameEvent(2, function(inst)
				inst.sg.statemem.lightcombostate = "rolling_drill_attack_very_far"
				inst.sg.statemem.heavycombostate = "rolling_heavy_attack_very_far"
				inst.sg.statemem.reverselightstate = "fading_light_attack_far"
				inst.sg.statemem.reverseheavystate = "rolling_heavy_attack_back_very_far"
			end)
		state.timeline[id + 2].idx = id + 2

		table.sort(state.timeline, function(a,b) return a.frame < b.frame end)
	end

	if state.name == "roll_light_pst" then
		local id = #state.timeline
		state.timeline[id + 1] = FrameEvent(0, function(inst)
			inst.sg.statemem.lightcombostate = "rolling_drill_attack_far"
			inst.sg.statemem.heavycombostate = "rolling_heavy_attack_very_far"
			inst.sg.statemem.reverselightstate = "fading_light_attack_far"
			inst.sg.statemem.reverseheavystate = "rolling_heavy_attack_back_very_far"
			end)
		state.timeline[id + 1].idx = id + 1

		state.timeline[id + 2] = FrameEvent(2, function(inst)
			inst.sg.statemem.lightcombostate = "rolling_drill_attack_med"
			inst.sg.statemem.heavycombostate = "rolling_heavy_attack_med"
			inst.sg.statemem.reverselightstate = "fading_light_attack_very_short"
			inst.sg.statemem.reverseheavystate = "rolling_heavy_attack_back_very_short"
			end)
		state.timeline[id + 2].idx = id + 2

		table.sort(state.timeline, function(a,b) return a.frame < b.frame end)
	end

	-- HEAVY ROLL
	if state.name == "roll_heavy" then
		local id = #state.timeline
		state.timeline[id + 1] = FrameEvent(2, function(inst)
			inst.sg.statemem.lightcombostate = "rolling_drill_attack_med"
			inst.sg.statemem.heavycombostate = "rolling_heavy_attack_med"
			inst.sg.statemem.reverselightstate = "fading_light_attack_very_short"
			inst.sg.statemem.reverseheavystate = "rolling_heavy_attack_back_very_short"
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
				inst.sg.statemem.lightcombostate = "rolling_drill_attack_med"
				inst.sg.statemem.heavycombostate = "rolling_heavy_attack_med"
				inst.sg.statemem.reverselightstate = "fading_light_attack_very_short"
				inst.sg.statemem.reverseheavystate = "rolling_heavy_attack_back_very_short"
				SGPlayerCommon.Fns.TryQueuedLightOrHeavy(inst)
			end
		end)
		state.timeline[id + 1].idx = id + 1

		state.timeline[id + 2] = FrameEvent(3, function(inst)
			inst.sg.statemem.reverseheavystate = "reverse_heavy_attack_pre" --non-sliding version
			inst.sg.statemem.reverselightstate = "fading_light_attack"
		end)
		state.timeline[id + 2].idx = id + 2

		table.sort(state.timeline, function(a,b) return a.frame < b.frame end)
	end
end

return StateGraph("sg_player_polearm", states, events, "idle")
