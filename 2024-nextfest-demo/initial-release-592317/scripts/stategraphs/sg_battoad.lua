local EffectEvents = require "effectevents"
local LootEvents = require "lootevents"
local SGCommon = require "stategraphs.sg_common"
local TargetRange = require "targetrange"
local Consumable = require "defs.consumable"
local combatutil = require "util.combatutil"
local playerutil = require "util.playerutil"
local monsterutil = require "util.monsterutil"

local function UpdateKonjurState(inst)
	if inst.components.battoadsync.stolen_konjur > 0 then
		inst.AnimState:ShowSymbol("cheeks")
		-- hide/ show fx here
	else
		inst.AnimState:HideSymbol("cheeks")
	end
end

local function StealKonjur(inst, target)
	if target.components.inventoryhoard then
		-- steal some konjur if the target has any
		local inv = target.components.inventoryhoard
		local konjur = inv:GetStackableCount(Consumable.Items.MATERIALS.konjur)
		if konjur > 0 then
			local steal_amount = math.ceil(konjur * 0.20)
			steal_amount = math.min(steal_amount, 250) --Cap stolen amount for networking purposes which is 255 in battoadsync.lua
			inv:RemoveStackable(Consumable.Items.MATERIALS.konjur, steal_amount)
			inst.components.battoadsync.stolen_konjur = steal_amount
			TheDungeon.HUD:MakePopText({ target = target, button = string.format(STRINGS.UI.INVENTORYSCREEN.KONJUR, -steal_amount), color = UICOLORS.KONJUR, size = 65, fade_time = 3.5 })

			inst:SetWalkSpeedFleeing() -- Set walkspeed to the faster version to make fleeing more effective
			inst:SetPhysicsSizeFleeing() -- Set physics size smaller so battoad doesn't get stuck on props while fleeing.
		end
	end
	UpdateKonjurState(inst)
end

local function ApplyLickStatus(inst, target)
	if inst.apply_on_lick and target ~= nil and target:IsValid() then
		local pm = target.components.powermanager
		if pm ~= nil then
			pm:AddPowerByName(inst.apply_on_lick)
		end
	end
end

local function ConsumeKonjur(inst)
	local healthmissing = inst.components.health:GetMissing()
	local heal = Attack(inst, inst)
	heal:SetHeal(healthmissing)
	inst.components.combat:ApplyHeal(heal)

	if inst.brain.brain then
		inst.brain.brain:OnHealed()
	end

	inst.sg.statemem.consumed = true -- So that we can gain juggernaut on a good animation frame, then go to "upperwings" state on animover

	inst:AddTag("nointerrupt")

	inst.components.battoadsync.stolen_konjur = 0
	UpdateKonjurState(inst)
end

local function DropKonjur(inst)
	if inst.components.battoadsync.stolen_konjur > 0 then
		local loot = { ["konjur"] = inst.components.battoadsync.stolen_konjur }
		LootEvents.SpawnLootFromMaterials(inst, loot)

		TheDungeon.HUD:MakePopText({ target = inst, button = string.format(STRINGS.UI.INVENTORYSCREEN.KONJUR, inst.components.battoadsync.stolen_konjur), color = UICOLORS.KONJUR, size = 35, fade_time = 3 })
		inst.components.battoadsync.stolen_konjur = 0

		local active_attack = inst.components.attacktracker:GetActiveAttack()
		if active_attack ~= nil and active_attack.id == "swallow" then
			inst.components.attacktracker:CancelActiveAttack()
		end
	end

	if inst.brain.brain then
		inst.brain.brain:OnHealed()
	end

	UpdateKonjurState(inst)
end

local function OnTongueHitBoxTriggered(inst, data)
	SGCommon.Events.OnHitboxTriggered(inst, data, {
		attackdata_id = "tongue",
		hitstoplevel = HitStopLevel.MEDIUM,
		hitflags = Attack.HitFlags.LOW_ATTACK,
		combat_attack_fn = "DoKnockbackAttack",
		hit_fx = monsterutil.defaultAttackHitFX,
		hit_fx_offset_x = 0.5,
		hit_target_pst_fn = function(_, target, _attack)
			inst.sg.statemem.next_state = "tongue_hit"
			StealKonjur(inst, target)
			ApplyLickStatus(inst, target)
		end
	})
end

local function OnUpperWingsHitBoxTriggered(inst, data)
	SGCommon.Events.OnHitboxTriggered(inst, data, {
		attackdata_id = "upperwings",
		hitstoplevel = HitStopLevel.MEDIUM,
		hitflags = Attack.HitFlags.LOW_ATTACK,
		combat_attack_fn = "DoKnockdownAttack",
		hit_fx = monsterutil.defaultAttackHitFX,
		hit_fx_offset_x = 0.5,
	})
end

local function OnSlashHitBoxTriggered(inst, data)
	SGCommon.Events.OnHitboxTriggered(inst, data, {
		attackdata_id = inst.sg.statemem.currentattack,
		hitstoplevel = HitStopLevel.MEDIUM,
		custom_attack_fn = function(_, attack)
			local hit = false

			if inst.sg.statemem.currentattack == "slash2" then
				hit = inst.components.combat:DoKnockdownAttack(attack)
			else
				attack:SetPushback(0.50)
				hit = inst.components.combat:DoKnockbackAttack(attack)
			end

			return hit
		end,
		hit_fx = monsterutil.defaultAttackHitFX,
		hit_fx_offset_x = 0.5,
	})
end

local function ChooseIdleBehavior(inst)
	if not inst.components.timer:HasTimer("idlebehavior_cd") then
		local threat = playerutil.GetRandomLivingPlayer()
		if not threat then
			inst.sg:GoToState("idle_behaviour")
			return true
		end
	end
	return false
end

local function OnDeath(inst, data)
	--Spawn death fx
	DropKonjur(inst)
	local offset = inst:IsAirborne() and { y = 3.5 } or nil
	EffectEvents.MakeEventFXDeath(inst, data.attack, "death_battoad", offset)

	inst.components.lootdropper:DropLoot()
end

local function OnLocomote(inst, data)
	local shouldturn
	if data ~= nil and data.dir ~= nil then
		local oldfacing = inst.Transform:GetFacing()
		if inst.sg:HasStateTag("turning") then
			inst.Transform:SetRotation(data.dir + 180)
		else
			inst.Transform:SetRotation(data.dir)
		end
		shouldturn = oldfacing ~= inst.Transform:GetFacing()
	end

	if inst.components.battoadsync.stolen_konjur > 0 then
		inst.sg:AddStateTag("nointerrupt")
	end

	if inst.sg:HasStateTag("busy") then
		return
	end

	if data ~= nil and data.move then
		if inst:IsAirborne() then
			if not inst.sg:HasStateTag("moving") or shouldturn then
				if shouldturn then
					if not inst.sg:HasStateTag("turning") then
						inst:FlipFacingAndRotation()
					end
					inst.sg:GoToState("turn_pre_fly_pre")
				else
					inst.sg:GoToState("fly_pre")
				end
			end
		else -- not airborne so you must be grounded
			if not inst.sg:HasStateTag("moving") or shouldturn then
				-- You can't turn mid-hop
				if shouldturn and not inst.sg:HasStateTag("airborne") then
					if not inst.sg:HasStateTag("turning") then
						inst:FlipFacingAndRotation()
					end
					inst.sg:GoToState("turn_ground_hop_pre")
				elseif not inst.sg:HasStateTag("moving") then
					inst.sg:GoToState("hop_pre")
				end
			end
		end
	elseif shouldturn then
		if inst:IsAirborne() then
			if not inst.sg:HasStateTag("turning") then
				inst:FlipFacingAndRotation()
			end
			inst.sg:GoToState("turn_air_pre")
		else -- not airborne so you must be grounded
			if not inst.sg:HasStateTag("turning") then
				inst:FlipFacingAndRotation()
			end
			inst.sg:GoToState("turn_ground_pre")
		end
	elseif inst.sg:HasStateTag("moving") then
		if inst:IsAirborne() then
			if inst.sg:HasStateTag("turning") then
				inst:FlipFacingAndRotation()
			end
			inst.sg:GoToState("fly_pst")
		else -- not airborne so you must be grounded
			if inst.sg:HasStateTag("turning") then
				inst:FlipFacingAndRotation()
			end
			if not inst.sg:HasStateTag("airborne") then
				inst.sg:GoToState("hop_pst")
			end
		end
	end
end

local function OnDoHeal(inst, targetpos)
	if not inst.sg:HasStateTag("busy") then
		SGCommon.Fns.TurnAndActOnLocation(inst, targetpos.x, targetpos.z, true, "swallow_pre")
	end
end

local events =
{
	EventHandler("doheal", OnDoHeal),
}
monsterutil.AddMonsterCommonEvents(events,
{
	ondeath_fn = OnDeath,
})
monsterutil.OverrideEventHandler(events, "locomote", OnLocomote) -- Override the default locomote event handler
monsterutil.AddOptionalMonsterEvents(events,
{
	idlebehavior_fn = ChooseIdleBehavior,
	spawn_battlefield = true,
})
SGCommon.Fns.AddCommonSwallowedEvents(events)

local states =
{
	----------------------
	-- Transition states to go from ground -> air or air -> ground

	State{
		name = "ground",
        tags = {"busy", "nointerrupt"},
        onenter = function(inst, data)
            inst.Physics:Stop()
            inst.sg.statemem.endstate = data.endstate
            local anim = "float_to_sit"
            inst.AnimState:PlayAnimation(data.animoverride or anim)
        end,

        events =
        {
            EventHandler("animover", function(inst)
                inst.sg:GoToState(inst.sg.statemem.endstate)
            end)
        },

        onexit = function(inst)
            inst:SetLocoState(inst.LocoState.GROUND)
        end,
	},

	State{
		name = "air",
        tags = {"busy", "nointerrupt"},
        onenter = function(inst, data)
			DropKonjur(inst)
            inst.Physics:Stop()
            inst.sg.statemem.endstate = data.endstate
            local anim = "sit_to_float"
            inst.AnimState:PlayAnimation(data.animoverride or anim)
        end,

        events =
        {
            EventHandler("animover", function(inst)
                inst.sg:GoToState(inst.sg.statemem.endstate)
            end)
        },

        onexit = function(inst)
            inst:SetLocoState(inst.LocoState.AIR)
        end,
	},

	----------------------
	-- Ground loco states

	State{
		name = "hop_pre",
		tags = { "moving" },

		onenter = function(inst)
			SGCommon.Fns.PlayAnimOnAllLayers(inst, "hop_pre")
		end,

		events =
		{
			EventHandler("animover", function(inst)
				inst.sg.statemem.moving = true
				inst.sg:GoToState("hop_loop")
			end),
		},

		onexit = function(inst)
			if not inst.sg.statemem.moving then
				inst.Physics:Stop()
			end
		end,
	},

	State{
		name = "hop_loop",
		tags = { "moving" },

		onenter = function(inst)
			if not inst.AnimState:IsCurrentAnimation("hop_loop") then
				SGCommon.Fns.PlayAnimOnAllLayers(inst, "hop_loop", true)
			end
		end,

        timeline =
        {
			FrameEvent(2, function(inst)
				SGCommon.Fns.SetMotorVelScaled(inst, inst.components.locomotor:GetWalkSpeed(), SGCommon.SGSpeedScale.TINY)
				inst.sg:AddStateTag("airborne")
				inst.sg:AddStateTag("busy")
			end),
			FrameEvent(15, function(inst)
				inst.sg:RemoveStateTag("airborne")
				inst.sg:RemoveStateTag("busy")
				inst.Physics:Stop()
			end),
        },

		events =
		{
			EventHandler("animover", function(inst)
				inst.sg.statemem.moving = true
				inst.sg:GoToState("hop_loop")
			end),
		},

		onexit = function(inst)
			if not inst.sg.statemem.moving then
				inst.Physics:Stop()
			end
		end,
	},

	State{
		name = "hop_pst",
		onenter = function(inst)
			SGCommon.Fns.PlayAnimOnAllLayers(inst, "hop_pst")
		end,

		events =
		{
			EventHandler("animover", function(inst)
				inst.sg:GoToState("idle")
			end),
		},
	},

	State{
		name = "turn_ground_hop_pre",
		tags = { "moving", "turning", "busy", "caninterrupt" },

		onenter = function(inst)
			SGCommon.Fns.PlayAnimOnAllLayers(inst, "turn_pre_sit_hop")
		end,

		events =
		{
			EventHandler("animover", function(inst)
				inst:FlipFacingAndRotation()
				inst.sg:GoToState("turn_ground_hop_pst")
			end),
		},

		onexit = function(inst)
			if not inst.sg.statemem.moving then
				inst.Physics:Stop()
			end
		end,
	},

	State{
		name = "turn_ground_hop_pst",
		tags = { "moving", "busy", "caninterrupt" },

		onenter = function(inst)
			SGCommon.Fns.PlayAnimOnAllLayers(inst, "turn_pst_sit_hop")
		end,

		events =
		{
			EventHandler("animover", function(inst)
				inst.sg.statemem.moving = true
				inst.sg:GoToState("hop_loop")
			end),
		},

		onexit = function(inst)
			if not inst.sg.statemem.moving then
				inst.Physics:Stop()
			end
		end,
	},

	----------------------
	-- Ground attack states

	State{
		name = "tongue",
		tags = { "attack", "busy" },

		onenter = function(inst, target)
			inst.AnimState:PlayAnimation("tongue")
			inst.sg.statemem.target = target
			inst.sg.statemem.next_state = "tongue_miss"
		end,

		timeline =
		{
			FrameEvent(3, function(inst)
				inst.components.hitbox:StartRepeatTargetDelay()
				inst.components.hitbox:PushBeam(0.5, 4.75, 1, HitPriority.MOB_DEFAULT)
			end),
			FrameEvent(4, function(inst)
				inst.components.hitbox:PushBeam(0.5, 4.75, 1, HitPriority.MOB_DEFAULT)
			end),
			FrameEvent(5, function(inst)
				inst.components.hitbox:PushBeam(0.5, 4.75, 1, HitPriority.MOB_DEFAULT)
			end),
			FrameEvent(6, function(inst)
				inst.components.hitbox:PushBeam(0.5, 4.75, 1, HitPriority.MOB_DEFAULT)
			end),
			FrameEvent(7, function(inst)
				inst.components.hitbox:PushBeam(0.5, 4.75, 1, HitPriority.MOB_DEFAULT)
			end),
			FrameEvent(8, function(inst)
				inst.components.hitbox:PushBeam(0.5, 4.75, 1, HitPriority.MOB_DEFAULT)
			end),
		},

		events =
		{
			EventHandler("hitboxtriggered", OnTongueHitBoxTriggered),
			EventHandler("animover", function(inst)
				inst.sg:GoToState(inst.sg.statemem.next_state, inst.sg.statemem.target)
			end),
		},

		onexit = function(inst)
			inst.components.attacktracker:CompleteActiveAttack()
			inst.components.hitbox:StopRepeatTargetDelay()
		end,
	},

	State{
		name = "tongue_hit",
		tags = { "attack", "busy" },

		onenter = function(inst, target)
			inst.AnimState:PlayAnimation("tongue_hit")
		end,

		events =
		{
			EventHandler("animover", function(inst)
				inst.sg:GoToState("idle")
			end),
		},
	},

	State{
		name = "tongue_miss",
		tags = { "attack", "busy" },

		onenter = function(inst, target)
			inst.AnimState:PlayAnimation("tongue_miss")
		end,

		events =
		{
			EventHandler("animover", function(inst)
				inst.sg:GoToState("idle")
			end),
		},
	},

	State{
		name = "swallow_to_upperwings",
		tags = { "attack", "busy", "block", "nointerrupt" },

		onenter = function(inst, target)
			inst.AnimState:PlayAnimation("upperwings2_pre")
			inst.sg.statemem.target = target
		end,

		timeline =
		{
		},

		events =
		{
			EventHandler("animover", function(inst)
				inst.sg:GoToState("upperwings_hold")
			end),
		},
	},

	State{
		name = "upperwings",
		tags = { "attack", "busy", "block", "nointerrupt" },

		onenter = function(inst, target)
			inst.AnimState:PlayAnimation("upperwings_to_float")
			inst.sg.statemem.target = target
		end,

		timeline =
		{
			FrameEvent(1, function(inst)
				inst.Physics:StartPassingThroughObjects()
				inst.sg:RemoveStateTag("block")
				inst.components.powermanager:AddPowerByName("juggernaut", 75)
			end),
			FrameEvent(2, function(inst)
				inst.components.hitbox:StartRepeatTargetDelay()
				inst.components.hitbox:PushCircle(0, 0, 3, HitPriority.MOB_DEFAULT)
			end),
			FrameEvent(3, function(inst)
				inst.components.hitbox:PushCircle(0, 0, 2.5, HitPriority.MOB_DEFAULT)
			end),
			FrameEvent(4, function(inst)
				inst.components.hitbox:PushCircle(0, 0, 2.5, HitPriority.MOB_DEFAULT)
			end),
			FrameEvent(6, function(inst)
				inst.sg:AddStateTag("airborne")
			end),
		},

		events =
		{
			EventHandler("hitboxtriggered", OnUpperWingsHitBoxTriggered),
			EventHandler("animover", function(inst)
				inst:SetLocoState(inst.LocoState.AIR)
				inst.sg:GoToState("idle")
			end),
		},

		onexit = function(inst)
			inst.components.attacktracker:CompleteActiveAttack()
			inst.components.hitbox:StopRepeatTargetDelay()
			inst.Physics:StopPassingThroughObjects()
		end,
	},

	State{
		name = "swallow",
		tags = { "attack", "busy", "nointerrupt" },
		-- Too late to knockdown -- don't allow interruption at this point.

		onenter = function(inst)
			inst.AnimState:PlayAnimation("swallow")
		end,

		timeline =
		{
			FrameEvent(33, function(inst)
				ConsumeKonjur(inst)
				inst.sg:GoToState("swallow_to_upperwings")
			end),

		},

		events =
		{
			EventHandler("animover", function(inst)
				inst.sg:GoToState("idle")
			end),
		},

		onexit = function(inst)
			inst.components.attacktracker:CompleteActiveAttack()
		end,
	},

	----------------------
	-- Air attack states

	State{
		name = "spit",
		tags = { "attack", "busy", "flying" },

		onenter = function(inst, target)
			inst.AnimState:PlayAnimation("spit")
			local target_pos = combatutil.GetWalkableOffsetPositionFromEnt(target, 1, 3)
			inst.sg.statemem.target_pos = target_pos
		end,

		timeline =
		{
			-- Code Generated by PivotTrack.jsfl
			FrameEvent(16, function(inst) inst.Physics:MoveRelFacing(29/150) end),
			FrameEvent(18, function(inst) inst.Physics:MoveRelFacing(22/150) end),
			FrameEvent(20, function(inst) inst.Physics:MoveRelFacing(16/150) end),
			FrameEvent(22, function(inst) inst.Physics:MoveRelFacing(10/150) end),
			FrameEvent(24, function(inst) inst.Physics:MoveRelFacing(3/150) end),
			FrameEvent(26, function(inst) inst.Physics:MoveRelFacing(-13/150) end),
			FrameEvent(28, function(inst) inst.Physics:MoveRelFacing(-26/150) end),
			FrameEvent(30, function(inst) inst.Physics:MoveRelFacing(-41/150) end),
			-- End Generated Code

			FrameEvent(18, function(inst)
				inst.components.attacktracker:CompleteActiveAttack()
				local projectile = SpawnPrefab("battoad_spit", inst)
				projectile:Setup(inst)
				local offset_x = 250/150

				if inst.Transform:GetFacing() == FACING_LEFT then
					offset_x = offset_x * -1
				end

				local offset = Vector3(offset_x, 310/150, 0)
				local x, z = inst.Transform:GetWorldXZ()
				projectile.Transform:SetPosition(x + offset.x, offset.y, z + offset.z)
				projectile:PushEvent("spit", inst.sg.statemem.target_pos)
			end),
			FrameEvent(30, function(inst)
				inst.sg:AddStateTag("caninterrupt")
			end),
			FrameEvent(35, function(inst)
				inst.sg:RemoveStateTag("busy")
			end),
		},

		events =
		{
			EventHandler("animover", function(inst)
				inst.sg:GoToState("idle")
			end),
		},

		onexit = function(inst)
			inst.components.attacktracker:CompleteActiveAttack()
		end,
	},

	State{
		name = "slash",
		tags = { "attack", "busy", "flying" },

		default_data_for_tools = function(inst)
			return nil
		end,

		onenter = function(inst, target)
			inst.AnimState:PlayAnimation("slash")
			inst.sg.statemem.target = target
			inst.sg.statemem.currentattack = "slash"
			SGCommon.Fns.SetMotorVelScaled(inst, 8)
		end,

		timeline =
		{
			FrameEvent(5, function(inst)
				inst.components.hitbox:StartRepeatTargetDelay()
				inst.components.hitbox:PushOffsetBeam(0.60, 3.00, 1.00, 1.20, HitPriority.MOB_DEFAULT)
				inst.components.hitbox:PushOffsetBeam(0.30, 2.60, 1.00, -0.50, HitPriority.MOB_DEFAULT)
			end),
			FrameEvent(6, function(inst)
				inst.components.hitbox:PushBeam(-0.3, 2, 1, HitPriority.MOB_DEFAULT)
			end),
			FrameEvent(7, function(inst)
				inst.components.hitbox:PushBeam(-0.5, 1, 1, HitPriority.MOB_DEFAULT)
			end),
			FrameEvent(8, function(inst)
				inst.Physics:Stop()
			end)
		},

		events =
		{
			EventHandler("hitboxtriggered", OnSlashHitBoxTriggered),
			EventHandler("animover", function(inst)
				SGCommon.Fns.FaceTarget(inst, inst.sg.statemem.target, true)
				inst.sg:GoToState("slash2_pre", inst.sg.statemem.target)
			end),
		},

		onexit = function(inst)
			inst.components.attacktracker:CompleteActiveAttack()
			inst.Physics:Stop()
			inst.components.hitbox:StopRepeatTargetDelay()
		end,
	},

	State{
		name = "slash_pst",
		tags = { "busy", "flying" },

		onenter = function(inst, target)
			inst.AnimState:PlayAnimation("slash_pst")
		end,

		events =
		{
			EventHandler("animover", function(inst)
				inst.sg:GoToState("idle")
			end),
		},
	},

	State{
		name = "slash2",
		tags = { "attack", "busy", "flying" },

		onenter = function(inst, target)
			inst.AnimState:PlayAnimation("slash2")
			inst.sg.statemem.target = target
			inst.sg.statemem.currentattack = "slash2"
			SGCommon.Fns.SetMotorVelScaled(inst, 10)
		end,

		timeline =
		{
			FrameEvent(4, function(inst)
				inst.components.hitbox:StartRepeatTargetDelay()
				inst.components.hitbox:PushBeam(-3 , 1, 1, HitPriority.MOB_DEFAULT)
			end),
			FrameEvent(5, function(inst)
				inst.components.hitbox:PushOffsetBeam(-1 , 2.8, 1, -1, HitPriority.MOB_DEFAULT)
			end),
			FrameEvent(6, function(inst)
				inst.components.hitbox:PushOffsetBeam(0 , 2.8, 1, -1, HitPriority.MOB_DEFAULT)
			end),
			FrameEvent(7, function(inst)
				inst.components.hitbox:PushBeam(1, 2.8, 1.5, HitPriority.MOB_DEFAULT)
			end),
			FrameEvent(10, function(inst) SGCommon.Fns.SetMotorVelScaled(inst, 5) end),
			FrameEvent(11, function(inst) SGCommon.Fns.SetMotorVelScaled(inst, 3) end),
			FrameEvent(12, function(inst) SGCommon.Fns.SetMotorVelScaled(inst, 1) end),
			FrameEvent(13, function(inst) inst.Physics:Stop() end),
			FrameEvent(14, function(inst) SGCommon.Fns.SetMotorVelScaled(inst, -1) end),
			FrameEvent(19, function(inst) inst.Physics:Stop() end),
		},

		events =
		{
			EventHandler("hitboxtriggered", OnSlashHitBoxTriggered),
			EventHandler("animover", function(inst)
				inst.sg:GoToState("idle")
			end),
		},

		onexit = function(inst)
			inst.components.attacktracker:CompleteActiveAttack()
			inst.Physics:Stop()
			inst.components.hitbox:StopRepeatTargetDelay()
		end,
	},
}

SGCommon.States.AddAttackPre(states, "tongue")
SGCommon.States.AddAttackHold(states, "tongue")

SGCommon.States.AddAttackPre(states, "upperwings",
{
	tags = { "attack", "busy", "nointerrupt", "block" }
})
SGCommon.States.AddAttackHold(states, "upperwings",
{
	tags = { "attack", "busy", "nointerrupt", "block" }
})

SGCommon.States.AddAttackPre(states, "swallow",
{
	addtags = { "nointerrupt" }
})
SGCommon.States.AddAttackHold(states, "swallow",
{
	addtags = { "nointerrupt" }
})

SGCommon.States.AddAttackPre(states, "spit",
{
	addtags = { "flying" },
})
SGCommon.States.AddAttackHold(states, "spit",
{
	addtags = { "flying" },
})

SGCommon.States.AddAttackPre(states, "slash",
{
	addtags = { "flying" },
})
SGCommon.States.AddAttackHold(states, "slash",
{
	addtags = { "flying" },
})

SGCommon.States.AddAttackPre(states, "slash2",
{
	addtags = { "flying" },
})
SGCommon.States.AddAttackHold(states, "slash2",
{
	addtags = { "flying" },
})

SGCommon.States.AddIdleStates(states,
{
	modifyanim = function(inst)
		local animname = "sit_"
		if inst:IsAirborne() then
			animname = "float_"
			inst.sg:AddStateTag("flying")
		end
		return animname
	end,
})

SGCommon.States.AddTurnStates(states,
{
	name_override = "turn_ground",
	modifyanim = function(inst)
		return "turn_sit"
	end
})

SGCommon.States.AddTurnStates(states,
{
	name_override = "turn_air",
	modifyanim = function(inst)
		return "turn_float"
	end
})

SGCommon.States.AddLocomoteStates(states, "fly",
{
	addtags = { "flying" },
	isRunState = true,
})

SGCommon.States.AddHitStates(states, nil,
{
	modifyanim = function(inst)
		local animname = "hit_sit"
		if inst:IsAirborne() then
			animname = "hit_float"
			inst.sg:AddStateTag("flying")
		end
		return animname
	end,
})

SGCommon.States.AddKnockbackStates(states,
{
	movement_frames = 11,
	modifyanim = function(inst)
		local animname = "flinch_sit"
		if inst:IsAirborne() then
			animname = "flinch_float"
			inst.sg:AddStateTag("flying")
		end
		return animname
	end,
})

SGCommon.States.AddKnockdownStates(states,
{
	onenter_hold_fn = function(inst)
		DropKonjur(inst)
	end,
	movement_frames = 14,
	modifyanim = function(inst)
		local animname = "knockdown_sit"
		if inst:IsAirborne() then
			animname = "knockdown_float"
		end
		return animname
	end,
})

SGCommon.States.AddSpawnBattlefieldStates(states,
{
	anim = "spawn",
	fadeduration = 0.33,
	fadedelay = 0,

	timeline =
	{
		FrameEvent(0, function(inst) inst:PushEvent("leave_spawner") end),

		FrameEvent(1, function(inst) SGCommon.Fns.SetMotorVelScaled(inst, 5) end),

		FrameEvent(14, function(inst)
			inst.sg:RemoveStateTag("airborne")
			inst.sg:AddStateTag("caninterrupt")
			inst.Physics:Stop()
		end),
	},

	onexit_fn = function(inst)
		inst.Physics:Stop()
	end,
})

SGCommon.States.AddKnockdownHitStates(states)

SGCommon.States.AddMonsterDeathStates(states)

SGRegistry:AddData("sg_battoad", states)

return StateGraph("sg_battoad", states, events, "idle")
