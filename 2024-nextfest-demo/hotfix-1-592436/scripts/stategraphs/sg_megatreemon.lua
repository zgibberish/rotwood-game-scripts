local SGCommon = require("stategraphs/sg_common")
local SGBossCommon = require "stategraphs.sg_boss_common"
local TargetRange = require "targetrange"
local audioid = require "defs.sound.audioid"
local krandom = require "util.krandom"
local monsterutil = require "util.monsterutil"
local fmodtable = require "defs.sound.fmodtable"
local soundutil = require "util.soundutil"

local function IsRightDir(dir)
	if dir ~= nil then
		if dir > -90 and dir < 90 then
			return true
		elseif dir < -90 or dir > 90 then
			return false
		end
	end
	return math.random() < .5
end

-- TODO: networking2022, make these visible via require so no duplication is needed
-- see rootattacker.lua

local function OnFlailHitBoxTriggered(inst, data)
	local damage_mod = 0
	SGCommon.Events.OnHitboxTriggered(inst, data, {
		hitstoplevel = HitStopLevel.HEAVY,
		set_dir_angle_to_target = true,
		damage_mod = damage_mod,
		pushback = 1.5,
		combat_attack_fn = "DoKnockbackAttack",
		hit_fx = monsterutil.defaultAttackHitFX,
		hit_fx_offset_x = 0.5,
		keep_it_local = true,
	})

	--sound for reduced damage
	local params = {}
	params.fmodevent = fmodtable.Event.Hit_reduced
	params.sound_max_count = 1
	local handle = soundutil.PlaySoundData(inst, params)
	soundutil.SetInstanceParameter(inst, handle, "damage_received_mult", damage_mod)
end

local function OnSwipeHitBoxTriggered(inst, data)
	SGCommon.Events.OnHitboxTriggered(inst, data, {
		attackdata_id = "swipe",
		hitstoplevel = HitStopLevel.HEAVY,
		set_dir_angle_to_target = true,
		combat_attack_fn = "DoKnockdownAttack",
		hit_fx = monsterutil.defaultAttackHitFX,
		hit_fx_offset_x = 0.5,
	})
end

local function OnPokeRootHitBoxTriggered(inst, data)
	SGCommon.Events.OnHitboxTriggered(inst, data, {
		hitstoplevel = HitStopLevel.LIGHT,
		set_dir_angle_to_target = true,
		damage_mod = 0.5,
		pushback = 0.1,
		hitflags = Attack.HitFlags.GROUND,
		combat_attack_fn = "DoKnockbackAttack",
		hit_fx = monsterutil.defaultAttackHitFX,
		keep_it_local = true,
	})
end

local function OnAttackRootHitBoxTriggered(inst, data)
	SGCommon.Events.OnHitboxTriggered(inst, data, {
		attackdata_id = "root",
		hitstoplevel = HitStopLevel.HEAVY,
		set_dir_angle_to_target = true,
		damage_mod = 0.75,
		pushback = 0.5,
		hitflags = Attack.HitFlags.GROUND,
		combat_attack_fn = "DoKnockdownAttack",
		hit_fx = monsterutil.defaultAttackHitFX,
		keep_it_local = true,
	})
end

local function OnDeath(inst)
	-- Cine will handle death anim and presentation.
	inst.components.rootattacker:CancelAttack()
	inst:PushEvent("treemon_growth_interrupted")
end

local events =
{
	EventHandler("taunt", function(inst) inst.sg:GoToState("taunt")	end),
	EventHandler("introduction", function(inst) inst.sg:GoToState("introduction") end),
	EventHandler("enter_defend", function(inst) inst.sg:GoToState("defend_tell") end),
	EventHandler("exit_defend", function(inst) inst.sg:GoToState("defend_pst") end),
	EventHandler("do_root_attacks", function(inst, attack_fn) inst.sg:GoToState("room_attack_pre", attack_fn) end),
	EventHandler("throw_bombs", function(inst, data)
		inst.components.rootattacker:CancelAttack()
		inst.sg.mem.times_to_throw = data.times
		inst.sg.mem.bomb_throw_direction = 1
		inst.sg:GoToState("bomb_throw", data.num)
	end),
}
monsterutil.AddBossCommonEvents(events,
{
	ondying_data =
	{
		ondying_fn = OnDeath,
	},
})

local states =
{
	State({
		name = "idle",
		tags = { "idle", "nointerrupt" },

		onenter = function(inst)
			inst.components.combat:SetRandomTargettingForTuning()
			if not inst.AnimState:IsCurrentAnimation("idle") then
				inst.AnimState:PlayAnimation("idle", true)
			end
			inst.sg.statemem.loops = math.min(3, math.random(5))
		end,

		events =
		{
			EventHandler("animover", function(inst)
				if inst.sg.statemem.loops > 1 then
					inst.sg.statemem.loops = inst.sg.statemem.loops - 1
				else
					inst.sg:GoToState("idle_blink")
				end
			end),
		},
	}),

	State({
		name = "idle_blink",
		tags = { "idle", "nointerrupt" },

		onenter = function(inst)
			inst.AnimState:PlayAnimation("idle_blink")
		end,

		events =
		{
			EventHandler("animover", function(inst)
				inst.sg:GoToState("idle")
			end),
		},
	}),

	State({
		name = "defend_tell",
		tags = { "busy", "nointerrupt" },

		onenter = function(inst)
			inst.AnimState:PlayAnimation("defend_tell")
		end,

		events =
		{
			EventHandler("animover", function(inst)
				inst.sg:GoToState("defend")
			end),
		},
	}),

	State({
		name = "defend",
		tags = { "busy", "nointerrupt" },
		onenter = function(inst)
			inst.components.hitbox:StartRepeatTargetDelayAnimFrames(20)
			inst.components.rootattacker:SpawnGuardRoots()
			inst.AnimState:PlayAnimation("defend_pre")
			inst.AnimState:PushAnimation("defend_loop", true)
		end,

		onupdate = function(inst)
			if inst.sg.statemem.hitting then
				inst.components.hitbox:PushCircle(0, 0, 3.33, HitPriority.MOB_DEFAULT)
			end
		end,

		timeline = {
			FrameEvent(27, function(inst)
				inst.sg:AddStateTag("block")
				inst.sg:AddStateTag("notarget")
				inst.components.powermanager:ResetData() -- Clear all powers, to remove any stacks of status effects
				inst.components.powermanager:SetCanReceivePowers(false)
				inst.sg.statemem.hitting = true
			end)
		},

		onexit = function(inst)
			inst.components.rootattacker:DespawnGuardRoots()
			inst.components.hitbox:StopRepeatTargetDelay()
			inst.components.powermanager:SetCanReceivePowers(true)
		end,

		events =
		{
			EventHandler("hitboxtriggered", OnFlailHitBoxTriggered),
		},
	}),

	State({
		name = "defend_pst",
		tags = { "busy", "nointerrupt", "block" },
		onenter = function(inst)
			inst.AnimState:PlayAnimation("defend_pst")
		end,

		events =
		{
			EventHandler("animover", function(inst)
				inst.sg:GoToState("idle")
			end),
		},
	}),

	State({
		name = "room_attack_pre",
		tags = { "busy", "nointerrupt" },

		onenter = function(inst, attack_fns)
			inst.AnimState:PlayAnimation("uproot_floor_pre")
			TheLog.ch.Boss:dumptable(attack_fns)
			inst.sg.mem.attack_fns = attack_fns
			inst.sg.mem.attack_num = 1
		end,

		events =
		{
			EventHandler("animover", function(inst)
				inst.sg:GoToState("room_attack_loop")
			end),
		},
	}),

	State({
		name = "room_attack_loop",
		tags = { "busy", "nointerrupt" },

		onenter = function(inst)
			inst.AnimState:PushAnimation("uproot_floor_loop", true)
			inst.components.hitbox:StartRepeatTargetDelayAnimFrames(20)
			inst.sg.mem.attack_num = math.min(#inst.sg.mem.attack_fns, inst.sg.mem.attack_num)
			inst.sg.mem.attack_fns[inst.sg.mem.attack_num](inst)
		end,

		onexit = function(inst)
			inst.components.hitbox:StopRepeatTargetDelay()
		end,

		events =
		{
			EventHandler("hitboxtriggered", OnPokeRootHitBoxTriggered),
			EventHandler("advance_root_attack", function(inst)
				inst.sg.mem.attack_num = inst.sg.mem.attack_num + 1
				inst.sg.mem.attack_num = math.min(#inst.sg.mem.attack_fns, inst.sg.mem.attack_num)
				inst.sg.mem.attack_fns[inst.sg.mem.attack_num](inst)
			end),
			EventHandler("done_root_attacks", function(inst)
				inst.sg:GoToState("room_attack_pst")
			end),
		},
	}),

	State({
		name = "room_attack_pst",
		tags = { "busy", "nointerrupt" },

		onenter = function(inst)
			inst.sg.mem.attack_fns = nil
			inst.sg.mem.attack_num = nil
			inst.AnimState:PlayAnimation("uproot_floor_pst")
		end,

		events =
		{
			EventHandler("animover", function(inst)
				inst.sg:GoToState("idle")
			end),
		},
	}),

	State({
		name = "bomb_throw",
		tags = { "busy", "nointerrupt" },

		default_data_for_tools = 1,

		onenter = function(inst, num)
			inst.sg:ExpectMem("bomb_throw_direction", 0)
			inst.sg:ExpectMem("times_to_throw", 1)
			inst.sg.statemem.right = inst.sg.mem.bomb_throw_direction > 0
			inst.sg.statemem.num = num
			inst.AnimState:PlayAnimation(inst.sg.statemem.right and "throw_l" or "throw_r")
		end,

		timeline =
		{
			FrameEvent(42, function(inst)
				-- throw bomb
				for i = 1, inst.sg.statemem.num do
					local bomb = SpawnPrefab("megatreemon_bomb_projectile", inst)
					local offset = inst.sg.statemem.right and Vector3(4.2, 4, 0) or Vector3(-4.2, 4, 0)
					local x, z = inst.Transform:GetWorldXZ()
					bomb.Transform:SetPosition(x + offset.x, offset.y, z + offset.z)

					local angle = inst.sg.statemem.right and 135 or -135
					local dist_mod = math.random(9, 20)
					local target_offset = krandom.Vec2_Unit(angle - 45, angle + 45) * dist_mod
					local target_pos = Vector3(x + target_offset.x, 0, z + target_offset.y)
					bomb:PushEvent("thrown", target_pos)
				end

				inst.sg.mem.times_to_throw = inst.sg.mem.times_to_throw - 1
				inst.sg.mem.bomb_throw_direction = inst.sg.mem.bomb_throw_direction * -1
			end),
		},

		events =
		{
			EventHandler("animover", function(inst)
				if inst.sg.mem.times_to_throw > 0 then
					inst.sg:GoToState("bomb_throw", inst.sg.statemem.num)
				else
					inst:PushEvent("bomb_throw_done")
					inst.sg:GoToState("idle")
				end
			end),
		},
	}),

	State({
		name = "swipe_pre",
		tags = {"busy", "nointerrupt"},

		onenter = function(inst, target)
			inst.components.attacktracker:StartActiveAttack("swipe")
			inst.sg.statemem.right = IsRightDir(inst:GetAngleTo(target))
			local direction = inst.sg.statemem.right and "l" or "r"
			inst.AnimState:PlayAnimation(string.format("swipe_%s_pre", direction))
		end,

		onexit = function(inst)
			inst.components.attacktracker:DoStartupFrames(inst.sg:GetAnimFramesInState())
		end,

		events =
		{
			EventHandler("animover", function(inst)
				inst.sg:GoToState("swipe_hold", inst.sg.statemem.right)
			end),
		},
	}),

	State({
		name = "swipe_hold",
		tags = {"busy", "nointerrupt"},

		onenter = function(inst, right)
			inst.sg.statemem.right = right
			local remaining_startup_frames = inst.components.attacktracker:GetRemainingStartupFrames()
			local direction = inst.sg.statemem.right and "l" or "r"
			inst.AnimState:PlayAnimation(string.format("swipe_%s_hold", direction))
			if remaining_startup_frames >= 0 then
				inst.sg:SetTimeoutAnimFrames(remaining_startup_frames)
			else
				inst.sg:GoToState("swipe", inst.sg.statemem.right)
			end
		end,

		ontimeout = function(inst)
			inst.sg:GoToState("swipe", inst.sg.statemem.right)
		end,

		onexit = function(inst)
			inst.components.attacktracker:DoStartupFrames(inst.sg:GetAnimFramesInState())
		end,
	}),

	State({
		name = "swipe",
		tags = {"attack", "busy", "nointerrupt"},

		onenter = function(inst, right)
			inst.sg.statemem.right = right
			local direction = inst.sg.statemem.right and "l" or "r"
			inst.AnimState:PlayAnimation(string.format("swipe_%s", direction))
		end,

		timeline =
		{
			FrameEvent(6, function(inst)
				inst.components.attacktracker:CompleteActiveAttack()
				inst.components.hitbox:StartRepeatTargetDelay()
				if inst.sg.statemem.right then
					inst.components.hitbox:PushOffsetBeam(5.5, 8.5, 4, 5, HitPriority.MOB_DEFAULT)
					inst.components.hitbox:PushOffsetBeam(4.5, 10.25, 1, 0, HitPriority.MOB_DEFAULT)
					inst.components.hitbox:PushOffsetBeam(5.5, 8.5, 0.5, -1.5, HitPriority.MOB_DEFAULT)
				else
					inst.components.hitbox:PushOffsetBeam(-8.5, -5.5, 4, 5, HitPriority.MOB_DEFAULT)
					inst.components.hitbox:PushOffsetBeam(-4.5, -10.25, 1, 0, HitPriority.MOB_DEFAULT)
					inst.components.hitbox:PushOffsetBeam(-8.5, -5.5, 0.5, -1.5, HitPriority.MOB_DEFAULT)
				end
			end),

			FrameEvent(7, function(inst)
				if inst.sg.statemem.right then
					inst.components.hitbox:PushOffsetBeam(-0.5, 5.5, 2, 3, HitPriority.MOB_DEFAULT)
					inst.components.hitbox:PushOffsetBeam(1.5, 4, 2.5, -1, HitPriority.MOB_DEFAULT)
					inst.components.hitbox:PushOffsetBeam(3, 5, 2, -0.5, HitPriority.MOB_DEFAULT)
				else
					inst.components.hitbox:PushOffsetBeam(-5.5, 0.5, 2, 3, HitPriority.MOB_DEFAULT)
					inst.components.hitbox:PushOffsetBeam(-4, -1.5, 2.5, -1, HitPriority.MOB_DEFAULT)
					inst.components.hitbox:PushOffsetBeam(-5, -3, 2, -0.5, HitPriority.MOB_DEFAULT)
				end
			end),

			FrameEvent(8, function(inst)
				if inst.sg.statemem.right then
					inst.components.hitbox:PushOffsetBeam(0, 3, 1.5, -2, HitPriority.MOB_DEFAULT)
				else
					inst.components.hitbox:PushOffsetBeam(-3, 0, 1.5, -2, HitPriority.MOB_DEFAULT)
				end
			end),

			FrameEvent(23, function(inst)
				inst.sg:AddStateTag("caninterrupt")
			end),
			FrameEvent(23, function(inst)
				inst.sg:RemoveStateTag("busy")
			end),
		},

		onexit = function(inst)
			inst.components.hitbox:StopRepeatTargetDelay()
			inst.components.attacktracker:CompleteActiveAttack()
		end,

		events =
		{
			EventHandler("hitboxtriggered", OnSwipeHitBoxTriggered),
			EventHandler("animover", function(inst)
				inst.sg:GoToState("idle")
			end),
		},
	}),

	State({
		name = "root_pre",
		tags = {"busy", "nointerrupt"},

		onenter = function(inst, target)
			inst.components.attacktracker:StartActiveAttack("root")
			local x, z = target.Transform:GetWorldXZ()
			inst.sg.statemem.tar_x = x
			inst.sg.statemem.tar_z = z
			inst.sg.statemem.right = IsRightDir(inst:GetAngleToXZ(x, z))
			local direction = inst.sg.statemem.right and "l" or "r"
			inst.AnimState:PlayAnimation(string.format("uproot_%s_pre", direction))
			inst.components.rootattacker:DoTargettedAttackPre({ x = x, z = z })
		end,

		events =
		{
			EventHandler("animover", function(inst)
				inst.sg:GoToState("root_hold", shallowcopy(inst.sg.statemem))
			end),
		},
	}),

	State({
		name = "root_hold",
		tags = { "busy", "nointerrupt" },

		onenter = function(inst, data)
			local direction = data.right and "l" or "r"
			inst.AnimState:PlayAnimation(string.format("uproot_%s_hold", direction), true)
			inst.sg.statemem = data

			local remaining_startup_frames = inst.components.attacktracker:GetRemainingStartupFrames()
			if remaining_startup_frames >= 0 then
				inst.sg:SetTimeoutAnimFrames(remaining_startup_frames)
			else
				inst.sg:GoToState("root", inst.sg.statemem.right)
			end
		end,

		ontimeout = function(inst)
			inst.sg:GoToState("root", shallowcopy(inst.sg.statemem))
		end,

		onexit = function(inst)
			inst.components.attacktracker:DoStartupFrames(inst.sg:GetAnimFramesInState())
		end,
	}),

	State({
		name = "root",
		tags = {"attack", "busy", "nointerrupt"},
		onenter = function(inst, data)
			inst.components.hitbox:StartRepeatTargetDelay()
			inst.components.rootattacker:FinishTargettedAttack()
			local direction = data.right and "l" or "r"
			inst.AnimState:PlayAnimation(string.format("uproot_%s", direction))
			inst.components.attacktracker:CompleteActiveAttack()
		end,

		onexit = function(inst)
			inst.components.hitbox:StopRepeatTargetDelay()
		end,

		events =
		{
			EventHandler("hitboxtriggered", OnAttackRootHitBoxTriggered),
			EventHandler("animover", function(inst)
				inst.sg:GoToState("idle")
			end),
		},
	}),

	State({
		name = "taunt",
		tags = { "busy", "nointerrupt" },

		onenter = function(inst, attack_fn)
			inst.AnimState:PlayAnimation("roar")
		end,

		onexit = function(inst)
			inst:PushEvent("taunt_over")
		end,

		events =
		{
			EventHandler("animover", function(inst)
				inst.sg:GoToState("idle")
			end),
		},
	}),


	State({
		name = "introduction",
		tags = { "busy", "nointerrupt" },

		onenter = function(inst, attack_fn)
			inst.AnimState:PlayAnimation("intro")

		end,

		onexit = function(inst)
			inst:PushEvent("taunt_over")
		end,

		events =
		{
			EventHandler("animover", function(inst)
				inst.sg:GoToState("idle")
			end),
		},
	}),
}

SGCommon.States.AddLeftRightHitStates(states)
SGCommon.States.AddMonsterDeathStates(states)
SGBossCommon.States.AddBossStates(states)

SGRegistry:AddData("sg_megatreemon", states)

return StateGraph("sg_megatreemon", states, events, "dormant_idle")
