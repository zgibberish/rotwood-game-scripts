local EffectEvents = require "effectevents"
local SGCommon = require "stategraphs.sg_common"
local monsterutil = require "util.monsterutil"

local ELITE_NUMSHOTS = 3

local function OnBiteHitboxTriggered(inst, data)
	local elite = inst:HasTag("elite")
	local hitstop = elite and HitStopLevel.HEAVY or HitStopLevel.MEDIUM
	local hitstun = elite and 10 or 2

	SGCommon.Events.OnHitboxTriggered(inst, data, {
		attackdata_id = "bite_r",
		hitstoplevel = hitstop,
		pushback = 1,
		hitstun_anim_frames = hitstun,
		hitflags = Attack.HitFlags.AIR,
		combat_attack_fn = "DoKnockbackAttack",
		hit_fx = monsterutil.defaultAttackHitFX,
		hit_fx_offset_x = 0.5,
	})
end

local function OnSpikeHitboxTriggered(inst, data)
	SGCommon.Events.OnHitboxTriggered(inst, data, {
		attackdata_id = "spike",
		hitstoplevel = HitStopLevel.MEDIUM,
		pushback = 1.5,
		hitstun_anim_frames = 10,
		hitflags = Attack.HitFlags.AIR_HIGH,
		combat_attack_fn = "DoKnockbackAttack",
		hit_fx = monsterutil.defaultAttackHitFX,
		hit_fx_offset_x = 0.5,
	})
end

local function OnDeath(inst, data)
	--Spawn death fx
	EffectEvents.MakeEventFXDeath(inst, nil, "death_sporemon")
	inst.components.lootdropper:DropLoot()
end

local events =
{
}
monsterutil.AddStationaryMonsterCommonEvents(events, { ondeath_fn = OnDeath, })

local states =
{
	State({
		name = "bite_r",
		tags = { "attack", "busy" },

		onenter = function(inst, target)
			inst.AnimState:PlayAnimation("atk_r_bite")
		end,

		timeline =
		{
            FrameEvent(2, function(inst)
                inst.components.hitbox:StartRepeatTargetDelay()
                inst.components.hitbox:PushBeam(-0.3, 2, 2.2, HitPriority.MOB_DEFAULT)
            end),
			FrameEvent(3, function(inst)
                inst.components.hitbox:PushBeam(0, 3, 2.2, HitPriority.MOB_DEFAULT)
            end),
			FrameEvent(4, function(inst)
                inst.components.hitbox:PushBeam(0.5, 3.6, 2.2, HitPriority.MOB_DEFAULT)
            end),
			FrameEvent(5, function(inst)
                inst.components.hitbox:PushBeam(0.5, 3.6, 2.2, HitPriority.MOB_DEFAULT)
            end),
		},

		events =
		{
			EventHandler("hitboxtriggered", OnBiteHitboxTriggered),
			EventHandler("animover", function(inst)
				inst.sg:GoToState("idle")
			end),
		},

		onexit = function(inst)
            inst.components.attacktracker:CompleteActiveAttack()
			inst.components.hitbox:StopRepeatTargetDelay()
		end,
	}),

    State({
		name = "bite_l",
		tags = { "attack", "busy" },

		onenter = function(inst, target)
			inst.AnimState:PlayAnimation("atk_l_bite")
		end,

		timeline =
		{
            FrameEvent(2, function(inst)
                inst.components.hitbox:StartRepeatTargetDelay()
                inst.components.hitbox:PushBeam(-2, 0.3, 2.2, HitPriority.MOB_DEFAULT)
            end),
			FrameEvent(3, function(inst)
                inst.components.hitbox:PushBeam(-3, 0, 2.2, HitPriority.MOB_DEFAULT)
            end),
			FrameEvent(4, function(inst)
                inst.components.hitbox:PushBeam(-3.6, -0.5, 2.2, HitPriority.MOB_DEFAULT)
            end),
			FrameEvent(5, function(inst)
                inst.components.hitbox:PushBeam(-3.6, -0.5, 2.2, HitPriority.MOB_DEFAULT)
            end),
		},

		events =
		{
			EventHandler("hitboxtriggered", OnBiteHitboxTriggered),
			EventHandler("animover", function(inst)
				inst.sg:GoToState("idle")
			end),
		},

		onexit = function(inst)
            inst.components.attacktracker:CompleteActiveAttack()
			inst.components.hitbox:StopRepeatTargetDelay()
		end,
	}),

    State({
		name = "spore",
		tags = { "attack", "busy" },

		onenter = function(inst, target)
			inst.AnimState:PlayAnimation("shoot")
			if (target) then
				inst.sg.mem.target = target
			end
			if (not inst.sg.mem.shotcount) then
				inst.sg.mem.shotcount = 1
			end
		end,

		timeline =
		{
            FrameEvent(9, function(inst)
				-- If target doesn't exist anymore, don't shoot anything
				if not inst.sg.mem.target then
					return
				end

				-- Target multiple players each volley as elite
				local current_target = inst.sg.mem.target
				if (inst:HasTag("elite")) then
					local new_target = AllPlayers[inst.sg.mem.shotcount]
					if (new_target and (not new_target.components.health:IsDead() and not new_target.components.health:IsRevivable())) then
						current_target = new_target
					end
				end

				-- get and set targets pos
				local pos = Vector2(inst.Transform:GetWorldXZ())
				local target_world = Vector2(current_target.Transform:GetWorldXZ())
				local target_pos = Vector3(target_world.x, 0, target_world.y)

				--Select projectile to shoot
				local projectile_name
				local initial_state
				if (inst.sg.mem.projectile_type == 2) then
					projectile_name = "sporemon_projectile_confuse"
					initial_state = "thrown_confuse"
				elseif(inst.sg.mem.projectile_type == 3) then
					projectile_name = "sporemon_projectile_juggernaut"
					initial_state = "thrown_juggernaut"
				else
					projectile_name = "sporemon_projectile_dmg"
					initial_state = "thrown_dmg"
				end

				--Throw Bomb
				local bomb = SpawnPrefab(projectile_name, inst)
				bomb:Setup(inst)
				bomb.Transform:SetPosition(pos.x, 4, pos.y)
				bomb.sg:GoToState(initial_state, target_pos)

				-- Enable this if we want multiple projectiles flying for elites
				--if (inst:HasTag("elite")) then
				--	local bomb2 = SpawnPrefab("sporemon_projectile_dmg", inst)
				--	bomb2:Setup(inst)
				--	bomb2.Transform:SetPosition(pos.x, 4, pos.y)
				--	bomb2.sg:GoToState("thrown_dmg", target_pos)
				--end
			end),
			FrameEvent(20, function(inst)
				if (inst:HasTag("elite")) then
					if (inst.sg.mem.shotcount < ELITE_NUMSHOTS) then
						inst.sg:GoToState("spore")
						inst.sg.mem.shotcount = inst.sg.mem.shotcount + 1
					end
				end
			end),
		},

		events =
		{
			EventHandler("animover", function(inst)
				inst.sg:GoToState("idle")
				inst.sg.mem.shotcount = 1
			end),
		},

		onexit = function(inst)
            inst.components.attacktracker:CompleteActiveAttack()
		end,
	}),

	State({
		name = "spike",
		tags = { "attack", "busy" },

		onenter = function(inst, target)
			inst.AnimState:PlayAnimation("atk_spike")
		end,

		timeline =
		{
            FrameEvent(2, function(inst)
                inst.components.hitbox:StartRepeatTargetDelay()
                inst.components.hitbox:PushCircle(0, 0, 3.5, HitPriority.MOB_DEFAULT)
            end),
			FrameEvent(3, function(inst)
                inst.components.hitbox:PushCircle(0, 0, 3.5, HitPriority.MOB_DEFAULT)
            end),
		},

		events =
		{
			EventHandler("hitboxtriggered", OnSpikeHitboxTriggered),
			EventHandler("animover", function(inst)
				inst.sg:GoToState("idle")
			end),
		},

		onexit = function(inst)
            inst.components.attacktracker:CompleteActiveAttack()
			inst.components.hitbox:StopRepeatTargetDelay()
		end,
	}),
}

SGCommon.States.AddAttackPre(states, "bite_r")
SGCommon.States.AddAttackPre(states, "bite_l")
SGCommon.States.AddAttackPre(states, "spike")
SGCommon.States.AddAttackPre(states, "spore",
{
	onenter_fn = function(inst)
		local rand_chance = math.random()
		if (rand_chance > 0.85) then
			inst.sg.mem.projectile_type = 2 -- Confuse spore
			EffectEvents.MakeEventSpawnLocalEntity(inst, "sporemon_symbol_confuse", "idle")
		elseif(rand_chance > 0.7) then
			inst.sg.mem.projectile_type = 3 -- Juggernaut spore
			EffectEvents.MakeEventSpawnLocalEntity(inst, "sporemon_symbol_juggernaut", "idle")
		else
			inst.sg.mem.projectile_type = 1 -- Damage spore
			EffectEvents.MakeEventSpawnLocalEntity(inst, "sporemon_symbol_damage", "idle")
		end
	end
})
SGCommon.States.AddAttackHold(states, "bite_r")
SGCommon.States.AddAttackHold(states, "bite_l")
SGCommon.States.AddAttackHold(states, "spike")
SGCommon.States.AddAttackHold(states, "spore")
SGCommon.States.AddHitStates(states)
SGCommon.States.AddIdleStates(states)
SGCommon.States.AddLeftRightHitStates(states)

SGCommon.States.AddMonsterDeathStates(states)

SGRegistry:AddData("sg_sporemon", states)

return StateGraph("sg_sporemon", states, events, "idle")
