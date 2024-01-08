local easing = require("util/easing")
local SGCommon = require("stategraphs/sg_common")
local monsterutil = require "util.monsterutil"
local powers = require "defs.powers"
local EffectEvents = require "effectevents"

local PUSHBACK_DISTANCE = 0.25
local HITSTUN = 4 -- anim frames
local HIT_RADIUS = 2.8

local function OnHitBoxTriggered(inst, data)
	SGCommon.Events.OnHitboxTriggered(inst, data, {
		attackdata_id = "spore",
		hitstoplevel = HitStopLevel.LIGHT,
		set_dir_angle_to_target = true,
		pushback = PUSHBACK_DISTANCE,
		combat_attack_fn = "DoKnockbackAttack",
		hitflags = Attack.HitFlags.GROUND,
		hit_fx = monsterutil.defaultAttackHitFX,
		hit_fx_offset_x = -5,
	})
end

local function OnHitBoxConfuseTriggered(inst, data)
	SGCommon.Events.OnHitboxTriggered(inst, data, {
		hitstoplevel = HitStopLevel.HEAVIER,
		set_dir_angle_to_target = true,
		player_damage_mod = TUNING.TRAPS.DAMAGE_TO_PLAYER_MULTIPLIER,
		pushback = PUSHBACK_DISTANCE,
		hitstun_anim_frames = HITSTUN,
		disable_damage_number = true,
		disable_hit_reaction = false,
		disable_self_hitstop = true,
		combat_attack_fn = "DoKnockbackAttack",
		hit_fx = nil,
		hit_fx_offset_x = 0.5,
		hit_target_pre_fn = function(attacker, v)
			-- Normal traps that apply a Power
			local pm = v.components.powermanager
			if pm ~= nil then
				local def = powers.FindPowerByName("confused")
				-- If they already have the power, only try to add more if it's a stackable power
				if pm:HasPower(def) then
					if def.stackable then
						pm:DeltaPowerStacks(def, 1)
					end
				-- If they don't already have it, then add a new instance.
				else
					pm:AddPowerByName("confused", 1)
				end
			end
	end })
end

local function OnHitBoxJuggernautTriggered(inst, data)
	SGCommon.Events.OnHitboxTriggered(inst, data, {
		hitstoplevel = HitStopLevel.HEAVIER,
		set_dir_angle_to_target = true,
		player_damage_mod = TUNING.TRAPS.DAMAGE_TO_PLAYER_MULTIPLIER,
		pushback = PUSHBACK_DISTANCE,
		hitstun_anim_frames = HITSTUN,
		disable_damage_number = true,
		disable_hit_reaction = false,
		disable_self_hitstop = true,
		combat_attack_fn = "DoKnockbackAttack",
		hit_fx = nil,
		hit_fx_offset_x = 0.5,
		hit_target_pre_fn = function(attacker, v)
			-- Normal traps that apply a Power
			local pm = v.components.powermanager
			if pm ~= nil then
				local def = powers.FindPowerByName("juggernaut")
				-- If they already have the power, only try to add more if it's a stackable power
				if pm:HasPower(def) then
					if def.stackable then
						pm:DeltaPowerStacks(def, 25)
					end
				-- If they don't already have it, then add a new instance.
				else
					pm:AddPowerByName("juggernaut", 25)
				end
			end
	end })
end

local function SetupTrajectory(inst, targetpos)
	local offset_size = 4.0
	local x_offset = math.random() * offset_size
	local z_offset = math.random() * offset_size
	targetpos.x = targetpos.x + (-(offset_size / 2) + x_offset)
	targetpos.z = targetpos.z + (-(offset_size / 2) + z_offset)
	local x, y, z = inst.Transform:GetWorldPosition()
	local dx = targetpos.x - x
	local dz = targetpos.z - z
	local rangesq = dx * dx + dz * dz
	local maxrange = 20
	local speed = easing.linear(rangesq, 20, 10, maxrange * maxrange)
	inst.components.complexprojectile:SetHorizontalSpeed(speed)
	inst.components.complexprojectile:SetGravity(-40)
	inst.components.complexprojectile:Launch(targetpos)

	local circle = SpawnPrefab("ground_target", inst)
	circle.Transform:SetPosition(targetpos.x, 0, targetpos.z)
	circle.Transform:SetScale(1.6, 1.6, 1.6)
	inst.sg.statemem.landing_pos = circle
end

local states =
{
	State({
		name = "idle",
	}),

	--DAMAGE STATES
	State({
		name = "thrown_dmg",
		tags = { "airborne" },
		onenter = function(inst, targetpos)
			SetupTrajectory(inst, targetpos)

			inst.AnimState:PlayAnimation("damage_spin", true)
		    inst.components.complexprojectile.onhitfn = function()
				inst.sg:GoToState("land_dmg", targetpos)
			end

			inst.components.hitbox:StartRepeatTargetDelay()
		end,

		events =
		{
			EventHandler("hitboxtriggered", OnHitBoxTriggered),
		},

		onupdate = function(inst)
			local x, y, z = inst.Transform:GetWorldPosition()
			if y <= 1 then
				inst.components.hitbox:PushCircle(0, 0, HIT_RADIUS, HitPriority.MOB_DEFAULT)
			end
		end,

		onexit = function(inst)
			if inst.sg.statemem.landing_pos then
				inst.sg.statemem.landing_pos:Remove()
				inst.components.hitbox:StopRepeatTargetDelay()
			end
		end,
	}),

	State({
		name = "land_dmg",
		onenter = function(inst, pos)
			inst.AnimState:PlayAnimation("damage_break")
			EffectEvents.MakeEventSpawnLocalEntity(inst, "fx_spores_damage_all", "idle")
		end,

		events =
		{
			EventHandler("animover", function(inst)
				inst:Remove()
			end),
		},
	}),

	--CONFUSE STATES
	State({
		name = "thrown_confuse",
		tags = { "airborne" },
		onenter = function(inst, targetpos)
			SetupTrajectory(inst, targetpos)

			inst.AnimState:PlayAnimation("confuse_spin", true)
		    inst.components.complexprojectile.onhitfn = function()
				inst.sg:GoToState("land_confuse", targetpos)
			end

			inst.components.hitbox:StartRepeatTargetDelay()
		end,

		events =
		{
			EventHandler("hitboxtriggered", OnHitBoxConfuseTriggered),
		},

		onupdate = function(inst)
			local x, y, z = inst.Transform:GetWorldPosition()
			if y <= 1 then
				inst.components.hitbox:PushCircle(0, 0, HIT_RADIUS, HitPriority.MOB_DEFAULT)
			end
		end,

		onexit = function(inst)
			if inst.sg.statemem.landing_pos then
				inst.sg.statemem.landing_pos:Remove()
				inst.components.hitbox:StopRepeatTargetDelay()
			end
		end,
	}),

	State({
		name = "land_confuse",
		onenter = function(inst, pos)
			inst.AnimState:PlayAnimation("confuse_break")
			EffectEvents.MakeEventSpawnLocalEntity(inst, "fx_spores_confused_all", "idle")
		end,

		events =
		{
			EventHandler("animover", function(inst)
				inst:Remove()
			end),
		},
	}),

	--JUGGERNAUT STATES
	State({
		name = "thrown_juggernaut",
		tags = { "airborne" },
		onenter = function(inst, targetpos)
			SetupTrajectory(inst, targetpos)

			inst.AnimState:PlayAnimation("juggernaut_spin", true)
		    inst.components.complexprojectile.onhitfn = function()
				inst.sg:GoToState("land_juggernaut", targetpos)
			end

			inst.components.hitbox:StartRepeatTargetDelay()
		end,

		events =
		{
			EventHandler("hitboxtriggered", OnHitBoxJuggernautTriggered),
		},

		onupdate = function(inst)
			local x, y, z = inst.Transform:GetWorldPosition()
			if y <= 1 then
				inst.components.hitbox:PushCircle(0, 0, HIT_RADIUS, HitPriority.MOB_DEFAULT)
			end
		end,

		onexit = function(inst)
			if inst.sg.statemem.landing_pos then
				inst.sg.statemem.landing_pos:Remove()
				inst.components.hitbox:StopRepeatTargetDelay()
			end
		end,
	}),

	State({
		name = "land_juggernaut",
		onenter = function(inst, pos)
			inst.AnimState:PlayAnimation("juggernaut_break")
			EffectEvents.MakeEventSpawnLocalEntity(inst, "fx_spores_juggernaut_all", "idle")
		end,

		events =
		{
			EventHandler("animover", function(inst)
				inst:Remove()
			end),
		},
	}),
}

return StateGraph("sg_sporemon_projectile", states, nil, "idle")
