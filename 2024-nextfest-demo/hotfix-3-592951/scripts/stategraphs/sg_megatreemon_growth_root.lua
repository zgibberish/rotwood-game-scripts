local POKE_HITBOX_SIZE = 0.66
local ATTACK_HITBOX_SIZE = 1.25
local GUARD_HITBOX_SIZE = 1.33

local ATTACK_HITBOX_DATA =
-- There are 3 different roots using the same hitbox size. They should be offset to better represent the actual attack.
{
	{ }, -- Anims start at 2, not 1
	{ x = 0, z = 0, radius = 0.75 }, -- Root 2
	{ x = -0.75, z = 0.75, radius = 1.25 }, -- Root 3
	{ x = 0.5, z = 0.75, radius = 1.25 }, -- Root 4
}

local audioid = require "defs.sound.audioid"
local fmodtable = require "defs.sound.fmodtable"
local soundutil = require "util.soundutil"

local function IsAPlayerInTheTrap(inst, radius)
	local is_player_in_trap
	local is_local_player_in_trap
	for k, player in pairs(AllPlayers) do
		if player:IsAlive() then
			local dist = inst:GetDistanceSqTo(player) / 10
			if dist <= radius then
				is_player_in_trap = true
				if player:IsLocal() then
					is_local_player_in_trap = true
				end
			end
		end
	end
	return is_player_in_trap, is_local_player_in_trap
end

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

	inst:ListenForEvent("animover", function(xinst) xinst:DelayedRemove() end)

	return inst
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
		name = "idle",
	}),

	State({
		name = "attack_pre",
		tags = { "busy" },
		onenter = function(inst, num)
			inst.sg.statemem.anim_num = type(num) == "number" and num or 2
			local pre_anim = string.format("root_attack%s_pre", inst.sg.statemem.anim_num)
			local hold_anim = string.format("root_attack%s_hold", inst.sg.statemem.anim_num)
			inst.AnimState:PlayAnimation(pre_anim)
			inst.AnimState:PushAnimation(hold_anim)

			local _, is_local_player_in_trap = IsAPlayerInTheTrap(inst, ATTACK_HITBOX_DATA[inst.sg.statemem.anim_num].radius)
			if is_local_player_in_trap then
				--sound
				local params = {}
				params.fmodevent = fmodtable.Event.megatreemon_root_spike_attack_warning
				inst.sg.statemem.warning_sound = soundutil.PlaySoundData(inst, params)
				soundutil.SetLocalInstanceParameter(inst, inst.sg.statemem.warning_sound, "isLocalPlayerInTrap", 1)
			end
		end,

		onupdate = function(inst)
			if inst.sg.statemem.warning_sound then
				local _, is_local_player_in_trap = IsAPlayerInTheTrap(inst, ATTACK_HITBOX_DATA[inst.sg.statemem.anim_num].radius)
				soundutil.SetLocalInstanceParameter(inst, inst.sg.statemem.warning_sound, "isLocalPlayerInTrap", is_local_player_in_trap and 1 or 0)
			end
		end,

		events =
		{
			EventHandler("attack", function(inst) inst.sg:GoToState("attack", inst.sg.statemem.anim_num) end),
		}
	}),

	State({
		name = "attack",
		tags = { "busy" },
		onenter = function(inst, num)
			inst.sg.statemem.anim_num = type(num) == "number" and num or 2
			local attack_anim = string.format("root_attack%s", inst.sg.statemem.anim_num)
			inst.AnimState:PlayAnimation(attack_anim)
		end,

		timeline =
		{
			FrameEvent(6, function(inst)
				-- create left offset
				local fx = CreateRootDebris()
				inst.components.hitstopper:AttachChild(fx)
				fx.Transform:SetRotation(inst.Transform:GetFacingRotation())
				local theta = math.rad(fx.Transform:GetFacingRotation())
				local x, z = inst.Transform:GetWorldXZ()
				local dist = -110/150
				fx.Transform:SetPosition(x + dist * math.cos(theta), 0, z - dist * math.sin(theta))
				inst.sg.statemem.fx = fx
				inst.sg.statemem.hitboxdata = ATTACK_HITBOX_DATA[inst.sg.statemem.anim_num]
			end),
			FrameEvent(6, function(inst)
				if inst.owner then
					inst.owner.components.hitbox:PushOffsetCircleFromChild(inst.sg.statemem.hitboxdata.x, 0, inst.sg.statemem.hitboxdata.radius, inst.sg.statemem.hitboxdata.z, inst, HitPriority.MOB_DEFAULT)
				end
			end),
			FrameEvent(7, function(inst)
				if inst.owner then
					inst.owner.components.hitbox:PushOffsetCircleFromChild(inst.sg.statemem.hitboxdata.x, 0, inst.sg.statemem.hitboxdata.radius, inst.sg.statemem.hitboxdata.z, inst, HitPriority.MOB_DEFAULT)
				end
			end),
			FrameEvent(8, function(inst)
				if inst.owner then
					inst.owner.components.hitbox:PushOffsetCircleFromChild(inst.sg.statemem.hitboxdata.x, 0, inst.sg.statemem.hitboxdata.radius, inst.sg.statemem.hitboxdata.z, inst, HitPriority.MOB_DEFAULT)
				end
			end),
			FrameEvent(21, function(inst)
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
			EventHandler("animover", function(inst) inst:DelayedRemove() end),
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
			if inst.owner then
				inst.owner.components.hitbox:PushOffsetCircleFromChild(0, 0, GUARD_HITBOX_SIZE, 0, inst, HitPriority.MOB_DEFAULT)
			end
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
			EventHandler("animover", function(inst) inst:DelayedRemove() end),
		},
	}),

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

			FrameEvent(3, function(inst)
				TheAudio:SetPersistentSoundParameter(audioid.persistent.boss_music, "Music_Megatreemon_RootTrigger", 1)
			end),

			FrameEvent(4, function(inst)
				if inst.owner then
					inst.owner.components.hitbox:PushOffsetCircleFromChild(0, 0, inst.sg.statemem.hit_rad, 0, inst, HitPriority.MOB_DEFAULT)
				end
			end),

			FrameEvent(5, function(inst)
				if inst.owner then
					inst.owner.components.hitbox:PushOffsetCircleFromChild(0, 0, inst.sg.statemem.hit_rad, 0, inst, HitPriority.MOB_DEFAULT)
				end
			end),

			--TEMP until animated version in -- get out quicker
			FrameEvent(9, function(inst)
				if inst.owner then
					local phase = inst.owner.boss_coro.phase
					if phase > 2 then
						inst.AnimState:SetDeltaTimeMultiplier(2) --TEMP until animated version in -- get out quicker
					end
				end
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
			EventHandler("animover", function(inst) inst:DelayedRemove() end),
		},
	}),

	State({
		name = "cancel",
		onenter = function(inst)
			inst.AnimState:PlayAnimation("rootsmack_pst")
		end,
		events =
		{
			EventHandler("animover", function(inst) inst:DelayedRemove() end),
		},
	}),
}

return StateGraph("sg_megatreemon_growth_root", states, events, "idle")
