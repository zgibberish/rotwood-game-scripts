local SGCommon = require "stategraphs.sg_common"
local SGPlayerCommon = require "stategraphs.sg_player_common"
local fmodtable = require "defs.sound.fmodtable"

local BLOCK_BUTTON = "dodge"

local ATTACK_DAMAGE_MOD =
{
	ATTACK1 = 1,
	ATTACK2 = 1,
	ATTACK3A = 1,
	ATTACK3B = 1,
	ATTACK3B_ALT = 1,
}

local ATTACK_PUSHBACK =
{
	ATTACK1 = 1.5,
	ATTACK2 = 1,
	ATTACK3A = 1,
	ATTACK3B = 1,
	ATTACK3B_ALT = 1,
}

local ATTACK_HITSTUN =
{
	ATTACK1 = 20,
	ATTACK2 = 18,
	ATTACK3A = 15,
	ATTACK3B = 20,
	ATTACK3B_ALT = 15,
}

local ATTACK_HITSTOP =
{
	ATTACK1 = HitStopLevel.MAJOR,
	ATTACK2 = HitStopLevel.MAJOR,
	ATTACK3A = HitStopLevel.MAJOR,
	ATTACK3B = HitStopLevel.MAJOR,
	ATTACK3B_ALT = HitStopLevel.MAJOR,
}

local function OnHitBoxTriggered(inst, data)
	local hitfx_x_offset = inst.sg.statemem.hitfx_x_offset
	local hitfx_y_offset = 0 --TODO
	local hitstoplevel = inst.sg.statemem.hitstoplevel or HitStopLevel.MEDIUM

	local dir = inst.Transform:GetFacingRotation()
	for i = 1, #data.targets do
		local v = data.targets[i]

		local kill = not v:IsDead()

		local attack = Attack(inst, v)
		attack:SetDamageMod(inst.sg.statemem.damage)
		attack:SetDir(dir)
		attack:SetHitstunAnimFrames(inst.sg.statemem.hitstun)
		attack:SetPushback(inst.sg.statemem.pushback)

		if inst.sg.statemem.counterhit then
			inst.components.combat:DoKnockdownAttack(attack)
		else
			inst.components.combat:DoBasicAttack(attack)
		end
		kill = kill and v:IsDead()

		hitstoplevel = SGCommon.Fns.ApplyHitstop(attack, hitstoplevel, { allow_multiple_on_attacker = true })

		-- TODO: Should use inst.components.combat:SpawnHitFxForPlayerAttack
		inst.components.combat:SpawnHitFxForPlayerAttack(attack, "hits_player_pierce", v, inst, hitfx_x_offset, hitfx_y_offset, dir, hitstoplevel)
		SpawnHurtFx(inst, v, 3.8, dir, hitstoplevel)
	end
end

local events = {}

SGPlayerCommon.Events.AddAllBasicEvents(events)

local states =
{
	State({
		name = "default_light_attack",
		onenter = function(inst) inst.sg:GoToState("attack1_pre") end,
	}),

	State({
		name = "default_heavy_attack",
		onenter = function(inst) end,--inst.sg:GoToState("block_pre") end,
	}),

	State({
		name = "default_dodge",
		onenter = function(inst) inst.sg:GoToState("block_pre") end,
	}),

	State({
		name = "attack1_pre",
		tags = { "attack", "busy" },

		onenter = function(inst)
			inst.AnimState:PlayAnimation("cleaver_atk1_pre")
			inst.Physics:SetMotorVel(2.8)
		end,

		timeline =
		{
			--sounds
			FrameEvent(3, PlayFootstep),
			FrameEvent(8, PlayFootstep),


			FrameEvent(11, function(inst) inst.Physics:Stop() end),
			FrameEvent(14, function(inst) inst.Physics:SetMotorVel(2.93) end),
		},

		events =
		{
			EventHandler("animover", function(inst)
				inst.sg:GoToState("attack1")
			end),
		},

		onexit = function(inst) inst.Physics:Stop() end,
	}),

	State({
		name = "attack1",
		tags = { "attack", "busy" },

		onenter = function(inst)
			inst.AnimState:PlayAnimation("cleaver_atk1")
			inst.Physics:SetMotorVel(1.8)

			inst.sg.statemem.damage = ATTACK_DAMAGE_MOD.ATTACK1
			inst.sg.statemem.pushback = ATTACK_PUSHBACK.ATTACK1
			inst.sg.statemem.hitstop = ATTACK_HITSTOP.ATTACK1
			inst.sg.statemem.hitstun = ATTACK_HITSTUN.ATTACK1
			inst.components.playercontroller:OverrideControlQueueTicks(BLOCK_BUTTON, 18 * ANIM_FRAMES)
		end,

		timeline =
		{
			--sounds
			FrameEvent(7, PlayFootstep),


			-- PHYSICS:
			FrameEvent(3, function(inst) inst.Physics:SetMotorVel(5) end),
			FrameEvent(4, function(inst) inst.Physics:SetMotorVel(5.5) end),
			FrameEvent(4, function(inst) inst.Physics:SetMotorVel(6) end),
			FrameEvent(7, function(inst) inst.Physics:SetMotorVel(3) end),
			FrameEvent(8, function(inst) inst.Physics:SetMotorVel(2) end),
			FrameEvent(9, function(inst) inst.Physics:SetMotorVel(1) end),
			FrameEvent(10, function(inst) inst.Physics:SetMotorVel(.5) end),
			FrameEvent(11, function(inst) inst.Physics:Stop() end),

			-- HITBOXES:
			FrameEvent(4, function(inst)
				inst.sg.statemem.hitfx_x_offset = 3.8
				inst.components.hitbox:StartRepeatTargetDelay()
				inst.components.hitbox:PushOffsetBeam(-2.5, 2.5, 2, 3, HitPriority.MOB_DEFAULT)
			end),
			FrameEvent(5, function(inst)
				inst.sg.statemem.damage = ATTACK_DAMAGE_MOD.ATTACK1
				inst.components.hitbox:PushBeam(1, 5.4, 2.5, HitPriority.PLAYER_DEFAULT)
			end),
			FrameEvent(6, function(inst)
				inst.components.hitbox:PushBeam(1, 5.4, 2.5, HitPriority.PLAYER_DEFAULT)
			end),
			FrameEvent(7, function(inst)
				inst.components.hitbox:PushOffsetBeam(-2.5, 2.5, -1.75, -2.75, HitPriority.MOB_DEFAULT)
			end),


			-- FrameEvent(9, SGPlayerCommon.Fns.SetCanDodge),

			FrameEvent(12, function(inst)
				inst.sg.statemem.lightcombostate = "attack2"
				SGPlayerCommon.Fns.TryQueuedAction(inst, "lightattack")
			end),
		},

		events =
		{
			EventHandler("hitboxtriggered", OnHitBoxTriggered),
			EventHandler("animover", function(inst)
				inst.sg:GoToState("attack1_pst")
			end),
		},

		onexit = function(inst)
			inst.Physics:Stop()
			inst.components.hitbox:StopRepeatTargetDelay()
		end,
	}),

	State({
		name = "attack1_pst",
		tags = { "busy" },

		onenter = function(inst)
			inst.AnimState:PlayAnimation("cleaver_atk1_pst")
		end,

		timeline =
		{
			FrameEvent(3, function(inst)
				inst.sg.statemem.candodge = true
				if inst.components.playercontroller:IsControlHeld(BLOCK_BUTTON) or inst.components.playercontroller:GetQueuedControl(BLOCK_BUTTON) then
					inst.sg:GoToState("block_pre4")
				end
			end),
			FrameEvent(15, SGPlayerCommon.Fns.RemoveBusyState),
		},

		events =
		{
			EventHandler("animover", function(inst)
				inst.sg:GoToState("idle")
			end),

			EventHandler("controlevent", function(inst, data)
				if data.control == BLOCK_BUTTON and inst.sg.statemem.candodge then
					inst.sg:GoToState("block_pre4")
				end
			end),
		},
	}),

	State({
		name = "attack2",
		tags = { "attack", "busy", "norotatecombo" },

		onenter = function(inst)
			inst.AnimState:PlayAnimation("cleaver_atk2")
			inst.Physics:SetMotorVel(2.6)
			inst.sg.statemem.damage = ATTACK_DAMAGE_MOD.ATTACK2
			inst.sg.statemem.pushback = ATTACK_PUSHBACK.ATTACK2
			inst.sg.statemem.hitstop = ATTACK_HITSTOP.ATTACK2
			inst.sg.statemem.hitstun = ATTACK_HITSTUN.ATTACK2
			inst.components.playercontroller:OverrideControlQueueTicks(BLOCK_BUTTON, 18 * ANIM_FRAMES)
		end,

		timeline =
		{
			--sounds

			--physics
			FrameEvent(3, function(inst) inst.Physics:SetMotorVel(2.2) end),
			FrameEvent(6, function(inst) inst.Physics:SetMotorVel(1.8) end),
			FrameEvent(9, function(inst) inst.Physics:SetMotorVel(1.4) end),
			FrameEvent(12, function(inst) inst.Physics:SetMotorVel(8) end),
			FrameEvent(14, function(inst) inst.Physics:SetMotorVel(4) end),
			FrameEvent(15, function(inst) inst.Physics:SetMotorVel(2) end),
			FrameEvent(16, function(inst) inst.Physics:SetMotorVel(1) end),
			FrameEvent(17, function(inst) inst.Physics:SetMotorVel(.5) end),
			FrameEvent(18, function(inst) inst.Physics:Stop() end),

			--hitboxes
			FrameEvent(14, function(inst)
				inst.sg.statemem.hitfx_x_offset = 3.2
				inst.components.hitbox:StartRepeatTargetDelay()
				inst.components.hitbox:PushBeam(0, 4.5, 1.75, HitPriority.PLAYER_DEFAULT)
				inst.components.hitbox:PushBeam(3, 4.75, 2.5, HitPriority.PLAYER_DEFAULT)
			end),
			FrameEvent(15, function(inst)
				inst.components.hitbox:PushBeam(0, 4.5, 1.75, HitPriority.PLAYER_DEFAULT)
				inst.components.hitbox:PushBeam(3, 4.75, 2.5, HitPriority.PLAYER_DEFAULT)
			end),

			-- chaining
			FrameEvent(21, function(inst)
				-- SGPlayerCommon.Fns.SetCanDodge(inst)
				inst.sg.statemem.lightcombostate = "attack3_pre"
				SGPlayerCommon.Fns.TryQueuedAction(inst, "lightattack")
			end),
		},

		events =
		{
			EventHandler("hitboxtriggered", OnHitBoxTriggered),
			EventHandler("animover", function(inst)
				inst.sg:GoToState("attack2_pst")
			end),
		},

		onexit = function(inst)
			inst.Physics:Stop()
			inst.components.hitbox:StopRepeatTargetDelay()
		end,
	}),

	State({
		name = "attack2_pst",
		tags = { "busy" },

		onenter = function(inst)
			inst.AnimState:PlayAnimation("cleaver_atk2_pst")
		end,

		timeline =
		{
			FrameEvent(10, function(inst) inst.Physics:MoveRelFacing(-34 / 150) end),
			FrameEvent(25, SGPlayerCommon.Fns.SetCanDodge),
			FrameEvent(26, SGPlayerCommon.Fns.RemoveBusyState),
		},

		events =
		{
			EventHandler("animover", function(inst)
				inst.sg:GoToState("idle")
			end),
		},
	}),

	State({
		name = "attack3_pre",
		tags = { "attack", "busy", "norotatecombo" },

		onenter = function(inst)
			inst.AnimState:PlayAnimation("cleaver_atk3_pre")
			inst.sg.statemem.damage = ATTACK_DAMAGE_MOD.ATTACK3A
			inst.sg.statemem.pushback = ATTACK_PUSHBACK.ATTACK3A
			inst.sg.statemem.hitstop = ATTACK_HITSTOP.ATTACK3A
			inst.sg.statemem.hitstun = ATTACK_HITSTUN.ATTACK3A
		end,

		timeline =
		{
			-- HITBOXES:
			FrameEvent(16, function(inst)
				inst.sg.statemem.hitfx_x_offset = 3.8
				inst.components.hitbox:StartRepeatTargetDelay()
				inst.components.hitbox:PushOffsetBeam(-3.5, 0.5, 1, -2, HitPriority.MOB_DEFAULT)
			end),
			FrameEvent(17, function(inst)
				inst.components.hitbox:PushOffsetBeam(-2.5, 2.5, 2, -3, HitPriority.MOB_DEFAULT)
			end),
		},
		events =
		{
			EventHandler("controlevent", function(inst, data)
				if data.control == "lightattack" then
					inst.sg.statemem.lightcombostate = "attack3a"
					inst.sg.statemem.queuedaction = data
				end
			end),
			EventHandler("animover", function(inst)
				local data = inst.components.playercontroller:GetQueuedControl("lightattack")
				if data ~= nil then
					inst.sg.statemem.lightcombostate = "attack3a"
					if SGPlayerCommon.Fns.DoAction(inst, data) then
						return
					end
				end

				inst.sg:GoToState("attack3b_quick")
			end),
		},
		onexit = function(inst)
			inst.components.hitbox:StopRepeatTargetDelay()
		end,
	}),

	State({
		name = "attack3a",
		tags = { "attack", "busy", "norotatecombo" },

		onenter = function(inst)
			inst.AnimState:PlayAnimation("cleaver_atk3a")
			inst.Physics:SetMotorVel(4)
			inst.sg.statemem.damage = ATTACK_DAMAGE_MOD.ATTACK3A
			inst.sg.statemem.pushback = ATTACK_PUSHBACK.ATTACK3A
			inst.sg.statemem.hitstop = ATTACK_HITSTOP.ATTACK3A
			inst.sg.statemem.hitstun = ATTACK_HITSTUN.ATTACK3A
			inst.sg.statemem.hitfx_x_offset = 4.1
			inst.components.hitbox:StartRepeatTargetDelay()
		end,

		timeline =
		{
			--physics
			FrameEvent(3, function(inst) inst.Physics:SetMotorVel(2) end),
			FrameEvent(6, function(inst) inst.Physics:SetMotorVel(1) end),
			FrameEvent(8, function(inst) inst.Physics:SetMotorVel(0.75) end),
			FrameEvent(11, function(inst) inst.Physics:SetMotorVel(.5) end),
			FrameEvent(14, function(inst) inst.Physics:SetMotorVel(2.4) end),

			--hitboxes
			FrameEvent(0, function(inst)
				inst.components.hitbox:PushBeam(0, 5.4, 1.5, HitPriority.PLAYER_DEFAULT)
			end),
			FrameEvent(1, function(inst)
				inst.components.hitbox:PushBeam(0, 5.4, 1.5, HitPriority.PLAYER_DEFAULT)
			end),
			FrameEvent(2, function(inst)
				inst.components.hitbox:PushBeam(0, 5.4, 1.5, HitPriority.PLAYER_DEFAULT)
			end),
			FrameEvent(3, function(inst)
				inst.components.hitbox:PushBeam(0, 5.4, 1.5, HitPriority.PLAYER_DEFAULT)
				inst.components.hitbox:PushOffsetBeam(3, 5.5, 2, 3, HitPriority.MOB_DEFAULT)
			end),
			FrameEvent(4, function(inst)
				inst.components.hitbox:PushBeam(0, 5.4, 1.5, HitPriority.PLAYER_DEFAULT)
				inst.components.hitbox:PushOffsetBeam(2, 4.5, 2, 3, HitPriority.MOB_DEFAULT)
			end),
			FrameEvent(5, function(inst)
				inst.components.hitbox:PushOffsetBeam(0, 2.5, 2, 3, HitPriority.MOB_DEFAULT)
			end),
			FrameEvent(6, function(inst)
				inst.components.hitbox:PushOffsetBeam(-1, 1.5, 2, 3, HitPriority.MOB_DEFAULT)
			end),
			FrameEvent(7, function(inst)
				inst.components.hitbox:PushOffsetBeam(-2, 0.5, 2, 3, HitPriority.MOB_DEFAULT)
			end),
			FrameEvent(8, function(inst)
				inst.components.hitbox:PushOffsetBeam(-4.5, 0, 2, 3, HitPriority.MOB_DEFAULT)
			end),
			FrameEvent(9, function(inst)
				inst.components.hitbox:PushBeam(-3, 0, 1.5, HitPriority.PLAYER_DEFAULT)
				inst.components.hitbox:PushOffsetBeam(-4.5, 0, 2, 3, HitPriority.MOB_DEFAULT)
			end),
			FrameEvent(10, function(inst)
				inst.components.hitbox:PushBeam(-3, 0, 1.5, HitPriority.PLAYER_DEFAULT)
			end),
--PushOffsetBeam(x-left, x-right, height, y-offset)
		},

		events =
		{
			EventHandler("hitboxtriggered", OnHitBoxTriggered),
			EventHandler("animover", function(inst)
				local data = inst.components.playercontroller:GetQueuedControl("lightattack")
				if data ~= nil then
					inst.sg.statemem.lightcombostate = "attack3b_alt"
					if SGPlayerCommon.Fns.DoAction(inst, data) then
						return
					end
				end

				inst.sg:GoToState("attack3b")
			end),
		},

		onexit = function(inst)
			inst.Physics:Stop()
			inst.components.hitbox:StopRepeatTargetDelay()
		end,
	}),

	State({
		name = "attack3b_quick",

		onenter = function(inst)
			inst.Physics:MoveRelFacing(83 / 150)
			inst.sg:GoToState("attack3b")
		end,
	}),

	State({
		name = "attack3b",
		tags = { "attack", "busy" },

		onenter = function(inst)
			inst.AnimState:PlayAnimation("cleaver_atk3b")
			inst.Physics:SetMotorVel(4)
			inst.sg.statemem.damage = ATTACK_DAMAGE_MOD.ATTACK3B
			inst.sg.statemem.pushback = ATTACK_PUSHBACK.ATTACK3B
			inst.sg.statemem.hitstop = ATTACK_HITSTOP.ATTACK3B
			inst.sg.statemem.hitstun = ATTACK_HITSTUN.ATTACK3B
			inst.sg.statemem.hitfx_x_offset = 3.4
			inst.sg.statemem.counterhit = true
			inst.components.hitbox:StartRepeatTargetDelay()
			inst.components.hitbox:PushBeam(0, 5.4, 1.5, HitPriority.PLAYER_DEFAULT)
		end,

		timeline =
		{

			-- physics
			FrameEvent(2, function(inst) inst.Physics:SetMotorVel(3) end),
			FrameEvent(4, function(inst) inst.Physics:SetMotorVel(2) end),
			FrameEvent(5, function(inst) inst.Physics:SetMotorVel(1) end),
			FrameEvent(6, function(inst) inst.Physics:SetMotorVel(.5) end),
			FrameEvent(7, function(inst) inst.Physics:Stop() end),
			FrameEvent(13, function(inst) inst.Physics:SetMotorVel(-1) end),
			FrameEvent(14, function(inst) inst.Physics:SetMotorVel(-.5) end),
			FrameEvent(15, function(inst) inst.Physics:Stop() end),
			FrameEvent(36, function(inst)
				inst.sg.statemem.lightcombostate = "attack3b_to_1"
				SGPlayerCommon.Fns.TryQueuedAction(inst, "lightattack")
			end),

			--hitboxes
			FrameEvent(1, function(inst)
				inst.components.hitbox:PushBeam(0, 5.4, 1.5, HitPriority.PLAYER_DEFAULT)
			end),

			FrameEvent(13, function(inst)
				inst.components.hitbox:PushBeam(-2, 0, 2.5, HitPriority.PLAYER_DEFAULT)
				inst.components.hitbox:PushBeam(-5.4, 0, 1.5, HitPriority.PLAYER_DEFAULT)
			end),
			FrameEvent(14, function(inst)
				inst.components.hitbox:PushBeam(-5.4, 0, 1.5, HitPriority.PLAYER_DEFAULT)
				inst.components.hitbox:PushBeam(-5.75, -4, 2.5, HitPriority.PLAYER_DEFAULT)
			end),
		},

		events =
		{
			EventHandler("hitboxtriggered", OnHitBoxTriggered),
			EventHandler("animover", function(inst)
				inst.sg:GoToState("attack3_pst")
			end),
		},

		onexit = function(inst)
			inst.Physics:Stop()
			inst.components.hitbox:StopRepeatTargetDelay()
		end,
	}),

	State({
		name = "attack3b_alt",
		tags = { "attack", "busy" },

		onenter = function(inst)
			inst.AnimState:PlayAnimation("cleaver_atk3b_alt")
			inst.Physics:SetMotorVel(4)
			inst.sg.statemem.damage = ATTACK_DAMAGE_MOD.ATTACK3B_ALT
			inst.sg.statemem.pushback = ATTACK_PUSHBACK.ATTACK3B_ALT
			inst.sg.statemem.hitstop = ATTACK_HITSTOP.ATTACK3B_ALT
			inst.sg.statemem.hitstun = ATTACK_HITSTUN.ATTACK3B_ALT
			inst.sg.statemem.hitfx_x_offset = 4.3
			inst.components.hitbox:StartRepeatTargetDelay()
		end,

		timeline =
		{
			--physics
			FrameEvent(1, function(inst)
				inst.Physics:SetMotorVel(3.5)
			end),
			FrameEvent(2, function(inst)
				inst.Physics:SetMotorVel(3)
			end),
			FrameEvent(3, function(inst)
				inst.Physics:SetMotorVel(2.5)
				inst.sg.statemem.hitfx_x_offset = 4
			end),
			FrameEvent(4, function(inst) inst.Physics:SetMotorVel(2) end),
			FrameEvent(5, function(inst) inst.Physics:SetMotorVel(1) end),
			FrameEvent(6, function(inst) inst.Physics:SetMotorVel(.5) end),
			FrameEvent(7, function(inst) inst.Physics:Stop() end),
			FrameEvent(11, function(inst) inst.Physics:SetMotorVel(-1) end),
			FrameEvent(12, function(inst) inst.Physics:SetMotorVel(-.5) end),
			FrameEvent(13, function(inst) inst.Physics:Stop() end),

			--hitboxes
			FrameEvent(0, function(inst)
				inst.components.hitbox:PushBeam(0, 5.4, 1.5, HitPriority.PLAYER_DEFAULT)
			end),
			FrameEvent(1, function(inst)
				inst.components.hitbox:PushBeam(0, 5.4, 1.5, HitPriority.PLAYER_DEFAULT)
			end),
			FrameEvent(2, function(inst)
				inst.components.hitbox:PushBeam(0, 5.4, 1.5, HitPriority.PLAYER_DEFAULT)
			end),
			FrameEvent(3, function(inst)
				inst.components.hitbox:PushBeam(0, 5.4, 1.5, HitPriority.PLAYER_DEFAULT)
				inst.components.hitbox:PushOffsetBeam(3, 5.5, 2, 3, HitPriority.MOB_DEFAULT)
			end),
			FrameEvent(4, function(inst)
				inst.components.hitbox:PushBeam(0, 5.4, 1.5, HitPriority.PLAYER_DEFAULT)
				inst.components.hitbox:PushOffsetBeam(2, 4.5, 2, 3, HitPriority.MOB_DEFAULT)
			end),
			FrameEvent(5, function(inst)
				inst.components.hitbox:PushOffsetBeam(0, 2.5, 2, 3, HitPriority.MOB_DEFAULT)
			end),
			FrameEvent(6, function(inst)
				inst.components.hitbox:PushOffsetBeam(-1, 1.5, 2, 3, HitPriority.MOB_DEFAULT)
			end),
			FrameEvent(7, function(inst)
				inst.components.hitbox:PushOffsetBeam(-2, 0.5, 2, 3, HitPriority.MOB_DEFAULT)
			end),
			FrameEvent(8, function(inst)
				inst.components.hitbox:PushOffsetBeam(-4.5, 0, 2, 3, HitPriority.MOB_DEFAULT)
			end),
			FrameEvent(9, function(inst)
				inst.components.hitbox:PushBeam(-3, 0, 1.5, HitPriority.PLAYER_DEFAULT)
				inst.components.hitbox:PushOffsetBeam(-4.5, 0, 2, 3, HitPriority.MOB_DEFAULT)
			end),
			FrameEvent(10, function(inst)
				inst.components.hitbox:PushBeam(-3, 0, 1.5, HitPriority.PLAYER_DEFAULT)
			end),
			FrameEvent(11, function(inst)
				inst.components.hitbox:PushBeam(-5.5, 0, 1.5, HitPriority.PLAYER_DEFAULT)
			end),

			--cancels
			FrameEvent(33, function(inst)
				inst.sg.statemem.lightcombostate = "attack3b_to_1"
				SGPlayerCommon.Fns.TryQueuedAction(inst, "lightattack")
			end),
		},

		events =
		{
			EventHandler("hitboxtriggered", OnHitBoxTriggered),
			EventHandler("animover", function(inst)
				inst.sg:GoToState("attack3_pst")
			end),
		},

		onexit = function(inst)
			inst.Physics:Stop()
			inst.components.hitbox:StopRepeatTargetDelay()
		end,
	}),

	State({
		name = "attack3b_to_1",

		onenter = function(inst)
			inst.Physics:MoveRelFacing(53 / 150)
			inst.sg:GoToState("attack1")
		end,
	}),

	State({
		name = "attack3_pst",
		tags = { "busy" },

		onenter = function(inst)
			inst.AnimState:PlayAnimation("cleaver_atk3_pst")
		end,

		timeline =
		{
			FrameEvent(11, function(inst)
				inst.sg.statemem.candodge = true
				if inst.components.playercontroller:IsControlHeld(BLOCK_BUTTON) or inst.components.playercontroller:GetQueuedControl(BLOCK_BUTTON) then
					inst.sg:GoToState("block_pre4")
				end
			end),
		},

		events =
		{
			EventHandler("animover", function(inst)
				inst.sg:GoToState("idle")
			end),

			EventHandler("controlevent", function(inst, data)
				if data.control == BLOCK_BUTTON and inst.sg.statemem.candodge then
					inst.sg:GoToState("block_pre4")
				end
			end),
		},
	}),

	State({
		name = "block_pre",
		tags = { "busy" },

		onenter = function(inst)
			inst.AnimState:SetDeltaTimeMultiplier(1.75)
			inst.AnimState:PlayAnimation("cleaver_idle_block_pre")
			inst.AnimState:PushAnimation("cleaver_idle_block_pre2")
			inst.AnimState:PushAnimation("cleaver_idle_block_pre3")
			inst.sg.statemem.unblock = not inst.components.playercontroller:IsControlHeld(BLOCK_BUTTON)
			inst.components.playercontroller:OverrideControlQueueTicks(BLOCK_BUTTON, nil)
		end,

		events =
		{
			EventHandler("controlupevent", function(inst, data)
				if data.control == BLOCK_BUTTON then
					inst.sg.statemem.unblock = true
				end
			end),
			EventHandler("animqueueover", function(inst)
				inst.sg:GoToState("block_pre4", inst.sg.statemem.unblock)
			end),
		},

		onexit = function(inst) inst.AnimState:SetDeltaTimeMultiplier(1) end,
	}),

	State({
		name = "block_pre4",
		tags = { "busy" },

		onenter = function(inst, unblock)
			inst.AnimState:PlayAnimation("cleaver_idle_block_pre4")
			inst.sg.statemem.unblock = unblock
		end,

		timeline =
		{
			FrameEvent(8, function(inst)
				inst.sg:AddStateTag("block")
				inst.Physics:MoveRelFacing(65 / 150)
				inst.Physics:SetSize(330 / 300)
			end),
			FrameEvent(9, function(inst)
				inst.sg:AddStateTag("caninterrupt")
			end),
		},

		events =
		{
			EventHandler("controlupevent", function(inst, data)
				if data.control == BLOCK_BUTTON then
					inst.sg.statemem.unblock = true
				end
			end),
			EventHandler("animover", function(inst)
				inst.sg.statemem.blocking = true
				if not inst.components.playercontroller:IsControlHeld(BLOCK_BUTTON) or inst.sg.statemem.unblock then
					inst.sg:GoToState("block_pst")
				else
					inst.sg:GoToState("block_loop")
				end
			end),
		},

		onexit = function(inst)
			if not inst.sg.statemem.blocking then
				inst.Physics:SetSize(1)
			end
		end,
	}),

	State({
		name = "block_loop",
		tags = { "block", "busy", "caninterrupt" },

		onenter = function(inst)
			if not inst.components.playercontroller:IsControlHeld(BLOCK_BUTTON) then
				inst.sg.statemem.blocking = true
				inst.sg:GoToState("block_pst")
			else
				inst.AnimState:PlayAnimation("cleaver_block_loop", true)
			end
		end,

		events =
		{
			EventHandler("controlupevent", function(inst, data)
				if data.control == BLOCK_BUTTON then
					inst.sg.statemem.blocking = true
					inst.sg:GoToState("block_pst")
				end
			end),

			EventHandler("animover", function(inst)
				if not inst.components.playercontroller:IsControlHeld(BLOCK_BUTTON) then
					inst.sg.statemem.blocking = true
					inst.sg:GoToState("block_pst")
				end
			end),
		},

		onexit = function(inst)
			if not inst.sg.statemem.blocking then
				inst.Physics:SetSize(1)
			end
		end,
	}),

	State({
		name = "block_hit_front",
		tags = { "hit", "block", "busy" },

		onenter = function(inst, unblock)
			inst.AnimState:PlayAnimation("cleaver_block_hit")
			inst.Physics:SetSize(330 / 300)
			inst.sg.statemem.unblock = unblock
		end,

		timeline =
		{
			FrameEvent(6, function(inst)
				if inst.sg.statemem.unblock then
					inst.sg.statemem.blocking = true
					inst.sg:GoToState("block_pst")
				else
					inst.sg:AddStateTag("caninterrupt")
				end
			end),
		},

		events =
		{
			EventHandler("controlupevent", function(inst, data)
				if data.control == BLOCK_BUTTON then
					if inst.sg:HasStateTag("caninterrupt") then
						inst.sg.statemem.blocking = true
						inst.sg:GoToState("block_pst")
					else
						inst.sg.statemem.unblock = true
					end
				end
			end),
			EventHandler("animover", function(inst)
				inst.sg.statemem.blocking = true
				inst.sg:GoToState("block_loop")
			end),
		},

		onexit = function(inst)
			if not inst.sg.statemem.blocking then
				inst.Physics:SetSize(1)
			end
		end,
	}),

	State({
		name = "block_hit_back",
		onenter = function(inst) inst.sg:GoToState("hit") end,
		onexit = function(inst) inst.Physics:SetSize(1) end,
	}),

	State({
		name = "block_knockback",
		onenter = function(inst, speedmult) inst.sg:GoToState("knockback", speedmult) end,
		onexit = function(inst) inst.Physics:SetSize(1) end,
	}),

	State({
		name = "block_pst",
		tags = { "unblock", "block", "busy" },

		onenter = function(inst)
			inst.AnimState:SetDeltaTimeMultiplier(1.3)
			inst.AnimState:PlayAnimation("cleaver_block_pst")
			-- inst.Physics:SetSize(330 / 300)
		end,

		timeline =
		{
			FrameEvent(8, function(inst)
				inst.AnimState:SetDeltaTimeMultiplier(1)
			end),
			FrameEvent(9, function(inst)
				inst.sg:RemoveStateTag("block")
				inst.Physics:MoveRelFacing(-65 / 150)
			end),

			-- CANCELS
			FrameEvent(20, SGPlayerCommon.Fns.SetCanDodge),
			FrameEvent(23, SGPlayerCommon.Fns.RemoveBusyState),
		},

		events =
		{
			EventHandler("animover", function(inst)
				inst.sg:GoToState("idle")
			end),
		},

		onexit = function(inst)
			if not inst.sg.statemem.blocking then
				inst.Physics:SetSize(1)
			end
			inst.AnimState:SetDeltaTimeMultiplier(1)
		end,
	}),
}

-- SGPlayerCommon.States.AddAllBasicStates(states)
SGPlayerCommon.States.AddIdleStateGeneric(states)
-- SGPlayerCommon.States.AddSheathedStates(states)
SGPlayerCommon.States.AddRunStatesGeneric(states)
-- SGPlayerCommon.States.AddTurnStates(states)
SGPlayerCommon.States.AddHitState(states)
SGPlayerCommon.States.AddKnockbackState(states)
SGPlayerCommon.States.AddKnockdownStates(states)
SGPlayerCommon.States.AddDeafenStates(states)
SGPlayerCommon.States.AddDeathStates(states)
SGPlayerCommon.States.AddPotionStates(states)
SGPlayerCommon.States.AddFoodStates(states)
SGPlayerCommon.States.AddTalkState(states)
SGPlayerCommon.States.AddPickupState(states)
SGPlayerCommon.States.AddPowerupInteractStates(states)
SGPlayerCommon.States.AddDisabledInputState(states)

return StateGraph("sg_player_cleaver", states, events, "idle")
