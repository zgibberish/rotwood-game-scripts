local SGCommon = require "stategraphs.sg_common"

local POKE_HITBOX_SIZE = 1.5
local ATTACK_HITBOX_SIZE = .75
local GUARD_HITBOX_SIZE = 1.33

local audioid = require "defs.sound.audioid"
local fmodtable = require "defs.sound.fmodtable"

local function CreateRootDebris()
	local inst = CreateEntity()

	inst.entity:AddTransform()
	inst.entity:AddAnimState()

	inst:AddTag("FX")
	inst:AddTag("NOCLICK")
	inst.persists = false

	inst.Transform:SetTwoFaced()

	inst.AnimState:SetBank("treemon_bank")
	inst.AnimState:SetBuild("treemon_build")
	inst.AnimState:PlayAnimation("debris")
	inst.AnimState:SetShadowEnabled(true)

	inst:ListenForEvent("animover", inst.Remove)

	return inst
end

local ATTACKS =
{
	-- Attack damage is tuned the same as reverse heavy attack
	POKE =
	{
		DAMAGE = 1,
		HITSTUN = 2,
		PUSHBACK = 1,
		HITSTOP = HitStopLevel.MEDIUM,
		RADIUS = 3,
		FOCUS = false,
		COMBAT_FN = "DoKnockbackAttack",
	},
}
local function OnHitboxTriggered(inst, data)
	-- dumptable(targets)
	-- return

	local attack = ATTACKS.POKE

	local numtargets = 0
	-- We have to check every target before we start iterating over them to do damage, so we know before we damage the first target whether we've got a focus
	for i = 1, #data.targets do
		local v = data.targets[i] -- TODO: add this target to a inst.sg.statemem.targetlist and only count v as another numtarget if we haven't hit them before? or, leave as is so hammer has a few ways to focus against single enemies
		if v.components.health then
			numtargets = numtargets + 1
		end
	end

	SGCommon.Events.OnHitboxTriggered(inst, data, {
		attackdata_id = "sg_megatreemon_growth_root_player_poke",
		damage_mod = attack.DAMAGE,
		hitstoplevel = attack.HITSTOP,
		pushback = attack.PUSHBACK,
		hitflags = Attack.HitFlags.GROUND,
		combat_attack_fn = attack.COMBAT_FN,
		disable_self_hitstop = true,
		hit_fx = "hits_player_pierce",
		hit_fx_offset_x = 0,
		hit_fx_offset_y = 0.5,
		set_dir_angle_to_target = true,
	})
end

local events =
{
	EventHandler("interrupted", function(inst) inst.sg:GoToState("cancel") end),
	EventHandler("poke", function(inst) inst.sg:GoToState("poke_pre") end),
	EventHandler("guard", function(inst) inst.sg:GoToState("guard_pre") end),
	EventHandler("stop_guard", function(inst) inst.sg:GoToState("guard_pst") end),
	EventHandler("attack_pre", function(inst, data) inst.sg:GoToState("attack_pre", data) end),
}

local states =
{
	State({
		name = "poke_pre",
		onenter = function(inst)
			inst.AnimState:PlayAnimation("root_spike_pre")
			inst.AnimState:PushAnimation("root_spike_hold", true)
			inst.sg:SetTimeoutAnimFrames(20)
		end,

		ontimeout = function(inst)
			inst.sg:GoToState("poke")
		end,
	}),

	State({
		name = "poke",

		onenter = function(inst)
			inst.AnimState:PlayAnimation("root_spike")
			inst.sg.statemem.hit_rad = POKE_HITBOX_SIZE
		end,

		timeline =
		{
			FrameEvent(2, function(inst)
				local fx = CreateRootDebris()
				inst.components.hitstopper:AttachChild(fx)
				fx.Transform:SetPosition(inst.Transform:GetWorldPosition())
				fx.Transform:SetRotation(inst.Transform:GetFacingRotation())
				inst.sg.statemem.fx = fx
			end),

			FrameEvent(4, function(inst)
				inst.components.hitbox:StartRepeatTargetDelay()
				inst.components.hitbox:PushOffsetCircleFromChild(0, 0, inst.sg.statemem.hit_rad, 0, inst, HitPriority.MOB_DEFAULT)
			end),

			FrameEvent(5, function(inst)
				inst.components.hitbox:PushOffsetCircleFromChild(0, 0, inst.sg.statemem.hit_rad, 0, inst, HitPriority.MOB_DEFAULT)
			end),

			FrameEvent(18, function(inst)
				inst.components.hitstopper:DetachChild(inst.sg.statemem.fx)
				inst.sg.statemem.fx = nil
			end),
		},

		onexit = function(inst)
			if inst.sg.statemem.fx ~= nil then
				inst.components.hitstopper:DetachChild(inst.sg.statemem.fx)
			end
		end,

		events =
		{
			EventHandler("hitboxtriggered", OnHitboxTriggered),

			EventHandler("animover", function(inst)
				if inst:IsLocal() then
					inst:Remove()
				end
			end),
		},
	}),

	State({
		name = "guard_pre",
		tags = { "busy" },
		onenter = function(inst)
			inst.AnimState:PlayAnimation("root_defend_pre")
		end,

		timeline =
		{
			FrameEvent(18, function(inst)
				-- create left offset
				local fx = CreateRootDebris()
				inst.components.hitstopper:AttachChild(fx)
				fx.Transform:SetRotation(inst.Transform:GetFacingRotation())
				local theta = math.rad(fx.Transform:GetFacingRotation())
				local x, z = inst.Transform:GetWorldXZ()
				local dist = -110/150
				fx.Transform:SetPosition(x + dist * math.cos(theta), 0, z - dist * math.sin(theta))
				inst.sg.statemem.fx = fx
			end),
			-- FrameEvent(21, function(inst)
			-- 	if inst.owner then
			-- 		inst.owner.components.hitbox:PushOffsetCircleFromChild(0, 0, GUARD_HITBOX_SIZE, 0, inst, HitPriority.MOB_DEFAULT)
			-- 	end
			-- end),
			FrameEvent(30, function(inst)
				if inst.sg.statemem.fx ~= nil then
					inst.components.hitstopper:DetachChild(inst.sg.statemem.fx)
				end
			end),
		},

		onexit = function(inst)
			if inst.sg.statemem.fx ~= nil then
				inst.components.hitstopper:DetachChild(inst.sg.statemem.fx)
			end
		end,

		events =
		{
			EventHandler("animover", function(inst) inst.sg:GoToState("guard_loop") end),
		},
	}),

	State({
		name = "guard_loop",
		tags = { "busy", "attack" },
		onenter = function(inst)
			inst.AnimState:PlayAnimation("root_defend_loop", true)
			inst.AnimState:SetFrame(math.random(5))
		end,

		onupdate = function(inst)
			inst.components.hitbox:PushOffsetCircleFromChild(0, 0, GUARD_HITBOX_SIZE, 0, inst, HitPriority.MOB_DEFAULT)
		end,
	}),

	State({
		name = "guard_pst",
		tags = { "busy" },
		onenter = function(inst)
			inst.AnimState:PlayAnimation("root_defend_pst", true)
		end,

		events =
		{
			EventHandler("animover", function(inst)
				if inst:IsLocal() then
					inst:Remove()
				end
			end),
		},
	}),
}

return StateGraph("sg_megatreemon_growth_root_player", states, events, "poke_pre")
