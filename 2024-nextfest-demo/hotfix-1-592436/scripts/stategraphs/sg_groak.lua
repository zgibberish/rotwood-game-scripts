local EffectEvents = require "effectevents"
local SGCommon = require "stategraphs.sg_common"
local SGMinibossCommon = require "stategraphs.sg_miniboss_common"
local playerutil = require "util.playerutil"
local monsterutil = require "util.monsterutil"
local Power = require "defs.powers"
local TargetRange = require "targetrange"

local lume = require "util.lume"
--local DebugDraw = require "util.debugdraw"

local groundpound_data =
{
	attackdata_id = "groundpound",
	hitstoplevel = HitStopLevel.LIGHT,
	hitflags = Attack.HitFlags.GROUND,
	reduce_friendly_fire = true,
	set_dir_angle_to_target = true,
	pushback = 0.1,
	hitstun_anim_frames = 2,
	combat_attack_fn = "DoKnockdownAttack",
	hit_fx = monsterutil.defaultAttackHitFX,
	hit_fx_offset_x = 0.5,
}

local GROUNDPOUND_RADIUS = 5
local GROUNDPOUND_CLOSE_RADIUS = 4
local GROUNDPOUND_FINAL_RADIUS = 6
local GROUNDPOUND_PST_RECOVERY_TIME = 3
local GROUNDPOUND_FACE_AWAY_TIMEOUT_TICKS = 120
local GROUNDPOUND_FACE_AWAY_Z_RANGE = 10

local OFFSET_1 = -1.8
local OFFSET_2 = 1.8

local function GetTargetsByDistance(inst, targets)
	-- Sort out targets into distance from Groak and apply different hit data to them.
	local close_targets = {}
	local far_targets = {}
	for i, target in ipairs(targets) do
		if target.HitBox and not target.HitBox:IsInvincible() then -- [TODO] look into why invincible targets weren't removed in HitBoxQueue:PostUpdate()
			if inst:GetDistanceSqTo(target) <= GROUNDPOUND_CLOSE_RADIUS ^ 2 then
				table.insert(close_targets, target)
			else
				table.insert(far_targets, target)
			end
		end
	end

	return close_targets, far_targets
end

local function OnGroundPoundHitboxTriggered(inst, data)
	-- Sort out targets into distance from Groak and apply different hit data to them.
	local close_targets, far_targets = GetTargetsByDistance(inst, data.targets)
	local attack_data = inst.components.attacktracker:GetAttackData("groundpound")

	if far_targets ~= nil and #far_targets > 0 then
		SGCommon.Events.OnHitboxTriggered(inst, { targets = far_targets, hitbox = data.hitbox }, groundpound_data)
	end

	if close_targets ~= nil and #close_targets > 0 then
		SGCommon.Events.OnHitboxTriggered(inst, { targets = close_targets, hitbox = data.hitbox }, lume.overlaymaps(groundpound_data,
		{
			damage_mod = (attack_data and attack_data.damage_mod or 1) * 2,
			hitstoplevel = HitStopLevel.MEDIUM,
			pushback = 0.2,
		}))
	end
end

local function OnGroundPoundFinalHitboxTriggered(inst, data)

	-- Sort out targets into distance from Groak and apply different hit data to them.
	local close_targets, far_targets = GetTargetsByDistance(inst, data.targets)
	local attack_data = inst.components.attacktracker:GetAttackData("groundpound")

	if far_targets ~= nil and #far_targets > 0 then
		SGCommon.Events.OnHitboxTriggered(inst, { targets = far_targets, hitbox = data.hitbox }, lume.overlaymaps(groundpound_data,
		{
			damage_mod = (attack_data and attack_data.damage_mod or 1) * 3,
			hitstoplevel = HitStopLevel.MEDIUM,
			pushback = 1.5,
		}))
	end

	if close_targets ~= nil and #close_targets > 0 then
		SGCommon.Events.OnHitboxTriggered(inst, { targets = close_targets, hitbox = data.hitbox }, lume.overlaymaps(groundpound_data,
		{
			damage_mod = (attack_data and attack_data.damage_mod or 1) * 5,
			hitstoplevel = HitStopLevel.HEAVY,
			pushback = 2,
		}))
	end
end

local function OnGroundPoundEnterHitboxTriggered(inst, data)
	SGCommon.Events.OnHitboxTriggered(inst, data, {
		attackdata_id = "groundpound",
		damage_mod = 2,
		hitstoplevel = HitStopLevel.HEAVY,
		hitstun_anim_frames = 12,
		pushback = 1.5,
		hitflags = Attack.HitFlags.LOW_ATTACK,
		set_dir_angle_to_target = true,
		combat_attack_fn = "DoKnockdownAttack",
		hit_fx = monsterutil.defaultAttackHitFX,
		hit_fx_offset_x = 0.5,
		reduce_friendly_fire = true,
		disable_self_hitstop = true,
		disable_enemy_on_enemy_hitstop = true,
	})
end

local function OnBurrowHitboxTriggered(inst, data)
	SGCommon.Events.OnHitboxTriggered(inst, data, {
		attackdata_id = "burrow",
		hitstoplevel = HitStopLevel.LIGHT,
		pushback = 1.5,
		set_dir_angle_to_target = true,
		hitflags = Attack.HitFlags.LOW_ATTACK,
		combat_attack_fn = "DoKnockdownAttack",
		hit_fx = monsterutil.defaultAttackHitFX,
		hit_fx_offset_x = 0.5,
	})
end

local function CheckForRemoteSwallowedEnts(inst)
	local swallowed_ents = inst.components.groaksync:FindSwallowedEntities()

	-- Detect if a remote entity within swallow range was swallowed & tell groak that it swallowed something.
	for _, target in ipairs(swallowed_ents) do
		if not target:IsLocal() then
			if not inst.components.groaksync:HasJustSwallowed() then
				inst.components.groaksync:SetStatusJustSwallowed()
				inst:PushEvent("has_just_swallowed")
				break
			end
		end
	end
end

local function OnSwallowedTargetStart(inst, target)
	-- Delay to allow groak to swallow other entities
	inst:DoTaskInTime(0.5, function()
		inst.components.groaksync:SetStatusSwallowing()
		inst.components.auraapplyer:Disable()
		if not inst.sg:HasStateTag("spawn_swallowing") then
			inst.sg:GoToState("swallow_yes")
		end
	end)
end

local function OnSwallowInterrupted(inst)
	inst.components.groaksync:ResetData()
	inst.components.attacktracker:CancelActiveAttack()
	return true -- Set to allow for PushEvent fallthrough to occur & allow for default event handlers to be handled.
end

--[[local function ChooseBattleCry(inst, data)
	if data.target ~= nil and data.target:IsValid() then
		if not inst.components.timer:HasTimer("battlecry_cd") then
			if not inst:IsNear(data.target, 6) then
				SGCommon.Fns.TurnAndActOnTarget(inst, data.target, true, "battlecry")
				return true
			end
		end
	end
	return false
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
end]]

local function OnDeath(inst, data)
	--Spawn death fx
	EffectEvents.MakeEventFXDeath(inst, data.attack, "death_groak")
	inst.components.auraapplyer:Disable()
	inst.components.lootdropper:DropLoot()
end

local function _SwallowedCommonEvents()
	return {
		EventHandler("charmed", OnSwallowInterrupted),
		EventHandler("knockback", OnSwallowInterrupted),
		EventHandler("knockdown", OnSwallowInterrupted),
		EventHandler("dying", OnSwallowInterrupted),
		EventHandler("attacked", function(inst, data)
			-- If attacked by something Groak is swallowing, e.g. retaliation, interrupt the swallow.
			local attacker = data.attack:GetAttacker()
			if attacker then
				local pm = attacker.components.powermanager
				if pm then
					local def = pm:GetPowerByName("groak_swallowed")
					if def and def.mem.swallower == inst then
						OnSwallowInterrupted(inst)
						return true
					end
				end
			end
		end),
	}
end

local events =
{
	EventHandler("has_just_swallowed", OnSwallowedTargetStart),
}
monsterutil.AddMinibossCommonEvents(events,
{
	ondeath_fn = OnDeath,
})
monsterutil.AddOptionalMonsterEvents(events,
{
	spawn_perimeter = true,
})
SGCommon.Fns.AddCommonSwallowedEvents(events)

local function SpawnGroundPoundHitBox(inst, offset, radius)
	if inst:HasTag("elite") then
		radius = radius * 0.8 -- Need to scale down if elite for hitboxes to match FX
	end
	inst.components.hitbox:PushCircle(offset, 0.00, radius, HitPriority.MOB_DEFAULT)

	-- Remove these once FX are in. Have to add 1 here to match with the actual hitbox radius...?
	--DebugDraw.GroundCircle(inst:GetPosition().x + offset, inst:GetPosition().z, radius + 1, UICOLORS.GOLD, 8)

	-- Show 1 extra frame so debug circles are more visible. Remove later!
	--inst:DoTaskInAnimFrames(1, function(inst) DebugDraw.GroundCircle(inst:GetPosition().x + offset, inst:GetPosition().z, radius + 1, UICOLORS.GOLD, 8) end)
end

local function GroakSuckForceAccelerate(inst, progress)
	local def = Power.FindPowerByName("groak_suck")
	local rarity = Power.GetBaseRarity(def)
	local max_speed = def.tuning[rarity]["speed"] or 0

	local speed = Vector3.lerp(0, max_speed, progress)
	inst.components.groaksync.suck_force = speed
end

local states =
{
	-- Taunt
	State({
		name = "taunt",
		tags = { "busy", "caninterrupt", "nointerrupt" },

		onenter = function(inst)
			inst.AnimState:PlayAnimation("behavior1")
		end,

		events =
		{
			EventHandler("animover", function(inst)
				inst.sg:GoToState("idle")
			end),
		},
	}),

	-- Groundpound attack
	State({
		name = "groundpound",
		tags = { "attack", "busy", "nointerrupt" },

		onenter = function(inst, target)
			inst.AnimState:PlayAnimation("groundpound_loop", true)
			inst.sg.statemem.target = target
			inst.components.hitbox:StartRepeatTargetDelayAnimFrames(8)
			inst.sg:SetTimeoutAnimFrames(51) -- Loop this anim 3x
		end,

		timeline =
		{
			FrameEvent(2, function(inst) SpawnGroundPoundHitBox(inst, OFFSET_1, GROUNDPOUND_CLOSE_RADIUS) end),
			FrameEvent(4, function(inst) SpawnGroundPoundHitBox(inst, OFFSET_1, GROUNDPOUND_RADIUS) end),

			FrameEvent(10, function(inst) SpawnGroundPoundHitBox(inst, OFFSET_2, GROUNDPOUND_CLOSE_RADIUS) end),
			FrameEvent(12, function(inst) SpawnGroundPoundHitBox(inst, OFFSET_2, GROUNDPOUND_RADIUS) end),

			FrameEvent(20, function(inst) SpawnGroundPoundHitBox(inst, OFFSET_1, GROUNDPOUND_CLOSE_RADIUS) end),
			FrameEvent(22, function(inst) SpawnGroundPoundHitBox(inst, OFFSET_1, GROUNDPOUND_RADIUS) end),

			FrameEvent(28, function(inst) SpawnGroundPoundHitBox(inst,OFFSET_2, GROUNDPOUND_CLOSE_RADIUS) end),
			FrameEvent(30, function(inst) SpawnGroundPoundHitBox(inst,OFFSET_2, GROUNDPOUND_RADIUS) end),

			FrameEvent(38, function(inst) SpawnGroundPoundHitBox(inst, OFFSET_1, GROUNDPOUND_CLOSE_RADIUS) end),
			FrameEvent(40, function(inst) SpawnGroundPoundHitBox(inst, OFFSET_1, GROUNDPOUND_RADIUS) end),

			FrameEvent(46, function(inst) SpawnGroundPoundHitBox(inst, OFFSET_2, GROUNDPOUND_CLOSE_RADIUS) end),
			FrameEvent(48, function(inst) SpawnGroundPoundHitBox(inst, OFFSET_2, GROUNDPOUND_RADIUS) end),
		},

		ontimeout = function(inst)
			inst.sg:GoToState("groundpound_pst")

			inst.components.hitbox:StopRepeatTargetDelay()
		end,

		events =
		{
			EventHandler("hitboxtriggered", OnGroundPoundHitboxTriggered),
		},
	}),

	State({
		name = "groundpound_pst",
		tags = { "attack", "busy", "nointerrupt" },

		onenter = function(inst)
			inst.AnimState:PlayAnimation("groundpound")
			inst.components.hitbox:StartRepeatTargetDelayAnimFrames(6)
		end,

		events =
		{
			EventHandler("hitboxtriggered", OnGroundPoundFinalHitboxTriggered),
			EventHandler("animover", function(inst)
				inst.sg:GoToState("groundpound_pst_loop")
			end),
		},

		timeline =
		{
			FrameEvent(11, function(inst)
				if inst:HasTag("elite") then
					local shockwave = SGCommon.Fns.SpawnAtDist(inst, "groak_shockwave", 0)
					if shockwave then
						shockwave:Setup(inst)
					end
				end

				SpawnGroundPoundHitBox(inst, 0.00, GROUNDPOUND_CLOSE_RADIUS)
			end),

			FrameEvent(12, function(inst)
				SpawnGroundPoundHitBox(inst, 0.00, GROUNDPOUND_RADIUS)
			end),

			FrameEvent(13, function(inst)
				SpawnGroundPoundHitBox(inst, 0.00, GROUNDPOUND_FINAL_RADIUS)
			end),
		},

		onexit = function(inst)
			inst.components.hitbox:StopRepeatTargetDelay()
			inst.components.attacktracker:CompleteActiveAttack()
		end,
	}),

	State({
		name = "groundpound_pst_loop",
		tags = { "attack", "busy", "nointerrupt" },

		onenter = function(inst)
			inst.AnimState:PlayAnimation("groundpound_pst_loop", true)
			inst.sg:SetTimeout(GROUNDPOUND_PST_RECOVERY_TIME)
		end,

		ontimeout = function(inst)
			inst.sg:GoToState("groundpound_pst_pst")
		end,
	}),

	State({
		name = "groundpound_pst_pst",
		tags = { "busy" },

		onenter = function(inst)
			inst.AnimState:PlayAnimation("groundpound_pst")
		end,

		events =
		{
			EventHandler("animover", function(inst)
				inst.sg:GoToState("idle")
			end),
		},
	}),

	-- Swallow attack
	State({
		name = "swallow",
		tags = { "attack", "busy", "nointerrupt" },

		onenter = function(inst, target)
			inst.AnimState:PlayAnimation("swallow")
			inst.sg.statemem.target = target
			inst.components.auraapplyer:Enable()
			inst.components.groaksync:ResetData()
			inst.components.groaksync:SetStatusSucking()

			-- Force the Groak's rotation angle to left or right so that its particle effect spawns in the correct place.
			inst.Transform:SetRotation(inst.Transform:GetFacing() == FACING_LEFT and -180 or 0)

			monsterutil.StartCannotBePushed(inst)

			inst.components.groaksync.suck_force = 0
			inst:DoDurationTaskForAnimFrames(45, GroakSuckForceAccelerate)
		end,

		onupdate = function(inst)
			CheckForRemoteSwallowedEnts(inst)
		end,

		events =
		{
			EventHandler("animover", function(inst)
				inst.sg.statemem.animover = true
				inst.sg:GoToState("swallow_loop", true)
			end),
		},

		onexit = function(inst)
			monsterutil.StopCannotBePushed(inst)

			if not inst.sg.statemem.animover then
				inst.components.auraapplyer:Disable()
			end
		end,
	}),

	State({
		name = "swallow_loop",
		tags = { "attack", "busy", "nointerrupt" },

		onenter = function(inst, aura_enabled)
			inst.AnimState:PlayAnimation("swallow_loop", true)
			inst.sg:SetTimeout(5)
			monsterutil.StartCannotBePushed(inst)

			if not aura_enabled then
				inst.components.auraapplyer:Enable()
			else
				-- Because auraapplyer hitbox triggered occurs after onupdate, and onhitfoxtriggered doesn't happen when entering a new state, set this flag to prevent things from losing its aura source.
				inst.components.auraapplyer.ignoreauratargetcheck = true
			end

			-- If damaged too much while swallowing, transition out of this state.
			SGCommon.Fns.StartTrackingIncomingDamage(inst, inst.GUID, 200,
				function(inst)
					SGCommon.Fns.StopTrackingIncomingDamage(inst, inst.GUID)
					inst.sg:GoToState("swallow_no")
				end)

			inst.sg.statemem.facingawaytarget_delayticks = 0
		end,

		onupdate = function(inst)
			CheckForRemoteSwallowedEnts(inst)

			-- Cancel out of swallow if groak is not facing its target for some time, or too far away on the z-axis
			local target = inst.components.combat:GetTarget()
			if inst.components.groaksync:IsSucking() and target then
				local trange = TargetRange(inst, target)
				if not trange:IsFacingTarget() or trange:IsOutOfZRange(GROUNDPOUND_FACE_AWAY_Z_RANGE) then
					inst.sg.statemem.facingawaytarget_delayticks = inst.sg.statemem.facingawaytarget_delayticks + 1 or 0
				end

				if inst.sg.statemem.facingawaytarget_delayticks > GROUNDPOUND_FACE_AWAY_TIMEOUT_TICKS then
					inst.sg:GoToState("swallow_no")
				end
			end
		end,

		ontimeout = function(inst)
			inst.sg:GoToState("swallow_no")
		end,

		onexit = function(inst)
			inst.components.auraapplyer:Disable()
			monsterutil.StopCannotBePushed(inst)
			SGCommon.Fns.StopTrackingIncomingDamage(inst, inst.GUID)
		end,
	}),

	State({
		name = "swallow_yes",
		tags = { "attack", "busy", "nointerrupt", "vulnerable" },

		onenter = function(inst)
			inst.AnimState:PlayAnimation("swallow_yes")
		end,

		events = lume.concat(_SwallowedCommonEvents(),
		{
			EventHandler("animover", function(inst)
				local targets = inst.components.groaksync:FindSwallowedEntities()
				for _, target in pairs(targets) do
					if inst.components.combat:CanTargetEntity(target) then
						inst.sg:GoToState("swallow_chew")
						return
					end
				end

				-- Only swallowed allies; have groak spit them out immediately.
				local target = inst.components.combat:GetTarget()
				if target then
					SGCommon.Fns.TurnAndActOnTarget(inst, target, true, "spitout", target)
				else
					inst.sg:GoToState("spitout")
				end
			end),
		}),

		timeline =
		{
			FrameEvent(21, function(inst) inst.components.groaksync:Chew() end),
		}
	}),

	State({
		name = "swallow_chew",
		tags = { "attack", "busy", "nointerrupt", "vulnerable" },

		events = _SwallowedCommonEvents(),

		onenter = function(inst)
			inst.AnimState:PlayAnimation("swallow_chew", true)
			inst.sg:SetTimeout(2)
		end,

		timeline =
		{
			FrameEvent(6, function(inst) inst.components.groaksync:Chew() end),
			FrameEvent(20, function(inst) inst.components.groaksync:Chew() end),
			FrameEvent(34, function(inst) inst.components.groaksync:Chew() end),
			FrameEvent(48, function(inst) inst.components.groaksync:Chew() end),
		},

		ontimeout = function(inst)
			inst.sg:GoToState("spitout")
		end,
	}),

	State({
		name = "spitout",
		tags = { "attack", "busy", "nointerrupt" },

		onenter = function(inst, data)
			inst.AnimState:PlayAnimation("spitout")
			inst.components.attacktracker:CompleteActiveAttack()
		end,

		events = lume.concat(_SwallowedCommonEvents(),
		{
			EventHandler("animover", function(inst)
				local targets = inst.components.groaksync:FindSwallowedEntities()
				if lume.count(targets) > 0 then
					inst.sg:GoToState("taunt")
				else
					inst.sg:GoToState("idle")
				end
			end),
		}),

		timeline =
		{
			FrameEvent(10, function(inst)
				inst.components.groaksync:SetStatusSpitOut()
			end),
		},

		onexit = function(inst)
			inst.components.groaksync:ResetData()
		end,
	}),

	State({
		name = "spitout_cinematic",
		tags = { "attack", "busy", "nointerrupt" },

		onenter = function(inst, data)
			inst.AnimState:PlayAnimation("spitout")
			inst.components.attacktracker:CompleteActiveAttack()
		end,

		events = lume.concat(_SwallowedCommonEvents(),
		{
			EventHandler("animover", function(inst)
				inst.sg:GoToState("taunt")
			end),
		}),

		timeline =
		{
			FrameEvent(10, function(inst)
				inst.components.groaksync:SetStatusSpitOut(true)
			end),
		},

		onexit = function(inst)
			inst.components.groaksync:ResetData()
		end,
	}),

	State({
		name = "swallow_no",
		tags = { "attack", "busy", "nointerrupt" },

		onenter = function(inst)
			inst.AnimState:PlayAnimation("swallow_no")
			inst.components.attacktracker:CompleteActiveAttack()
		end,

		events =
		{
			EventHandler("animover", function(inst)
				local target = inst.components.combat:GetTarget()
				if target and target:IsValid() and not target:IsDead() then
					SGCommon.Fns.TurnAndActOnTarget(inst, target, true, "groundpound_pre") -- Didn't swallow anything, go to groundpound attack.
				else
					inst.sg:GoToState("idle")
				end
			end),
		},
	}),

	State({
		name = "burrow",
		tags = { "attack", "busy", "nointerrupt" },

		onenter = function(inst)
			inst.AnimState:PlayAnimation("burrow")

			inst.components.powermanager:ResetData()
			inst.components.powermanager:SetCanReceivePowers(false)
			inst.components.hitbox:StartRepeatTargetDelay()
		end,

		timeline =
		{
			FrameEvent(19, function(inst)
				inst.HitBox:SetInvincible(true)
				inst.HitBox:SetEnabled(false)
				inst.Physics:SetEnabled(false)
			end),

			-- Hitbox
			FrameEvent(8, function(inst)
				inst.components.hitbox:PushOffsetBeam(-3.00, 0.00, 2.00, 1.00, HitPriority.MOB_DEFAULT)
			end),
			FrameEvent(9, function(inst)
				inst.components.hitbox:PushOffsetBeam(-5.50, -1.50, 2.00, 1.00, HitPriority.MOB_DEFAULT)
			end),
			FrameEvent(10, function(inst)
				inst.components.hitbox:PushOffsetBeam(-5.50, -1.50, 2.00, 1.00, HitPriority.MOB_DEFAULT)
			end),

			FrameEvent(13, function(inst)
				inst.components.hitbox:PushOffsetBeam(3.00, 1.00, 2.00, 1.00, HitPriority.MOB_DEFAULT)
			end),
			FrameEvent(14, function(inst)
				inst.components.hitbox:PushOffsetBeam(5.50, 3.00, 2.00, 1.00, HitPriority.MOB_DEFAULT)
			end),
			FrameEvent(15, function(inst)
				inst.components.hitbox:PushOffsetBeam(5.50, 3.00, 2.00, 1.00, HitPriority.MOB_DEFAULT)
			end),

			FrameEvent(21, function(inst)
				inst.components.hitbox:PushOffsetBeam(-5.00, -1.50, 2.00, 1.00, HitPriority.MOB_DEFAULT)
			end),
			FrameEvent(22, function(inst)
				inst.components.hitbox:PushOffsetBeam(-5.00, -1.50, 2.00, 1.00, HitPriority.MOB_DEFAULT)
			end),
			FrameEvent(23, function(inst)
				inst.components.hitbox:PushOffsetBeam(-6.00, -2.00, 2.00, 1.00, HitPriority.MOB_DEFAULT)
			end),

			FrameEvent(29, function(inst)
				inst.components.hitbox:PushOffsetBeam(5.50, 2.00, 2.00, 1.00, HitPriority.MOB_DEFAULT)
			end),
		},

		events =
		{
			EventHandler("hitboxtriggered", OnBurrowHitboxTriggered),
			EventHandler("animover", function(inst)
				inst.sg:GoToState("burrow2")
			end),
		},

		onexit = function(inst)
			inst.components.hitbox:StopRepeatTargetDelay()
			inst.components.attacktracker:CompleteActiveAttack()
			inst.components.powermanager:SetCanReceivePowers(true)

			inst.HitBox:SetInvincible(false)
			inst.HitBox:SetEnabled(true)
			inst.Physics:SetEnabled(true)
		end,
	}),

	State({
		name = "burrow2",
		tags = { "attack", "busy", "nointerrupt" },

		onenter = function(inst)
			-- No animation for this state. Groak is hidden 'underground'.
			inst:Hide()

			inst.components.powermanager:ResetData()
			inst.components.powermanager:SetCanReceivePowers(false)

			inst.HitBox:SetInvincible(true)
			inst.HitBox:SetEnabled(false)
			inst.Physics:SetEnabled(false)

			inst.sg:SetTimeout(1.5)
		end,

		ontimeout = function(inst)
			inst.sg:GoToState("burrow_spawn_pre")
		end,

		onexit = function(inst)
			inst.components.hitbox:StopRepeatTargetDelay()
			inst.components.attacktracker:CompleteActiveAttack()
			inst.components.powermanager:SetCanReceivePowers(true)

			inst.HitBox:SetInvincible(false)
			inst.HitBox:SetEnabled(true)
			inst.Physics:SetEnabled(true)

			inst:Show()
		end,
	}),

	-- Spawn from underground states
	State({
		name = "spawn_pre",
		tags = { "attack", "busy", "nointerrupt", "spawn_swallowing" },

		onenter = function(inst)
			inst.AnimState:PlayAnimation("spawn_pre")
			inst.Physics:StartPassingThroughObjects()
		end,

		timeline =
		{
			FrameEvent(6, function(inst)
				EffectEvents.MakeEventSpawnLocalEntity(inst, "groak_spawn_swallow", "idle")
			end),
		},

		events =
		{
			EventHandler("animover", function(inst)
				local swallowed_ents = inst.components.groaksync:FindSwallowedEntities()
				if #swallowed_ents > 0 then
					inst.components.groaksync:SetStatusJustSwallowed()
				end

				inst.sg:GoToState("spawn_swallow")
			end),
		},

		onexit = function(inst)
			inst.Physics:StopPassingThroughObjects()
		end,
	}),

	State({
		name = "spawn_swallow",
		tags = { "attack", "busy", "nointerrupt", "spawn_swallowing" },

		onenter = function(inst)
			inst.AnimState:PlayAnimation("spawn_swallow")
		end,

		events = lume.concat(_SwallowedCommonEvents(),
		{
			EventHandler("animover", function(inst)
				local targets = inst.components.groaksync:FindSwallowedEntities()
				for _, target in pairs(targets) do
					if inst.components.combat:CanTargetEntity(target) then
						inst.components.groaksync:SetStatusJustSwallowed()
						inst.sg:GoToState("swallow_chew")
						return
					end
				end

				-- Only allies swallowed; have groak spit them out immediately.
				if lume.count(targets) > 0 then
					inst.sg:GoToState("spitout")
				else
					inst.sg:GoToState("spawn_swallow_none")
				end
			end),
		}),
	}),

	--[[State({
		name = "spawn_none",
		tags = { "attack", "busy", "nointerrupt" },

		onenter = function(inst)
			inst.AnimState:PlayAnimation("spawn_none")
		end,

		events =
		{
			EventHandler("animover", function(inst)
				inst.sg:GoToState("taunt")
			end),
		},
	}),]]

	State({
		name = "spawn_swallow_none",
		tags = { "attack", "busy", "nointerrupt" },

		onenter = function(inst)
			inst.AnimState:PlayAnimation("spawn_swallow_none")
		end,

		events =
		{
			EventHandler("animover", function(inst)
				inst.sg:GoToState("taunt")
			end),
		},
	}),

	-- Burrow spawn states
	State({
		name = "burrow_spawn_pre",
		tags = { "attack", "busy", "nointerrupt", "spawn_swallowing" },

		onenter = function(inst)
			inst.AnimState:PlayAnimation("burrow_spawn_pre")
			inst.AnimState:PushAnimation("burrow_spawn_hold")

			inst.HitBox:SetInvincible(true)
			inst.HitBox:SetEnabled(false)
			inst.Physics:SetEnabled(false)

			ShakeAllCameras(CAMERASHAKE.VERTICAL, 1.0, 0.02, 1)

			local target = inst.components.combat:GetTarget()
			if target and target:IsValid() and not target:IsDead() then
				local pos = target:GetPosition()
				inst.Transform:SetPosition(pos:Get())
			end

			inst.sg:SetTimeout(0.6)
		end,

		ontimeout = function(inst)
			inst.sg:GoToState("burrow_spawn_swallow")
		end,

		onexit = function(inst)
			inst.HitBox:SetInvincible(false)
			inst.HitBox:SetEnabled(true)
			inst.Physics:SetEnabled(true)
		end,
	}),

	State({
		name = "burrow_spawn_swallow",
		tags = { "attack", "busy", "nointerrupt", "spawn_swallowing" },

		onenter = function(inst)
			inst.AnimState:PlayAnimation("burrow_spawn_swallow")

			EffectEvents.MakeEventSpawnLocalEntity(inst, "groak_spawn_swallow", "idle")
		end,

		events = lume.concat(_SwallowedCommonEvents(),
		{
			EventHandler("animover", function(inst)
				local targets = inst.components.groaksync:FindSwallowedEntities()
				for _, target in pairs(targets) do
					if inst.components.combat:CanTargetEntity(target) then
						inst.components.groaksync:SetStatusJustSwallowed()
						inst.sg:GoToState("swallow_chew")
						return
					end
				end

				-- Only allies swallowed; have groak spit them out immediately.
				if lume.count(targets) > 0 then
					inst.sg:GoToState("spitout")
				else
					inst.sg:GoToState("spawn_swallow_none")
				end
			end),
		}),
	}),

	--[[State({
		name = "burrow_spawn_none",
		tags = { "attack", "busy", "nointerrupt" },

		onenter = function(inst)
			inst.AnimState:PlayAnimation("burrow_spawn_none")
		end,

		events =
		{
			EventHandler("animover", function(inst)
				inst.sg:GoToState("taunt")
			end),
		},
	}),]]
}

SGCommon.States.AddAttackPre(states, "groundpound",
{
	tags = { "attack", "busy", "nointerrupt" }
})
SGCommon.States.AddAttackHold(states, "groundpound",
{
	tags = { "attack", "attack_hold", "busy", "nointerrupt" }
})

SGCommon.States.AddSpawnPerimeterStates(states,
{
	pre_anim = "groundpound_pre",
	hold_anim = "groundpound_pre_hold",
	land_anim = "groundpound",
	pst_anim = "groundpound_pst",

	fadeduration = 0.25,
	fadedelay = 0,
	jump_time = 1.05,

	land_timeline =
	{
		FrameEvent(11, function(inst)
			inst.components.hitbox:StartRepeatTargetDelay()
			inst.components.hitbox:PushCircle(0.00, 0.00, 4.00, HitPriority.MOB_DEFAULT)
		end),
		FrameEvent(12, function(inst)
			inst.components.hitbox:PushCircle(0.00, 0.00, 5.00, HitPriority.MOB_DEFAULT)
		end),
		FrameEvent(13, function(inst)
			inst.components.hitbox:PushCircle(0.00, 0.00, 6.00, HitPriority.MOB_DEFAULT)
		end),
		FrameEvent(14, function(inst)
			inst.components.hitbox:StopRepeatTargetDelay()
		end),
	},

	land_events =
	{
		EventHandler("hitboxtriggered", OnGroundPoundEnterHitboxTriggered),
	},
})

SGCommon.States.AddAttackPre(states, "swallow",
{
	tags = { "attack", "busy", "nointerrupt" }
})
SGCommon.States.AddAttackHold(states, "swallow",
{
	tags = { "attack", "busy", "attack_hold", "nointerrupt" }
})

SGCommon.States.AddAttackPre(states, "burrow",
{
	tags = { "attack", "busy", "nointerrupt" }
})
SGCommon.States.AddAttackHold(states, "burrow",
{
	tags = { "attack", "busy", "attack_hold", "nointerrupt" }
})

SGCommon.States.AddHitStates(states)
SGCommon.States.AddKnockbackStates(states, { movement_frames = 11 })
SGCommon.States.AddKnockdownStates(states, { movement_frames = 7 })
SGCommon.States.AddKnockdownHitStates(states)

SGCommon.States.AddIdleStates(states,
{
	addtags = { "nointerrupt" },
})
SGCommon.States.AddLocomoteStates(states, "walk",
{
	addtags = { "nointerrupt" },
})
SGCommon.States.AddTurnStates(states,
{
	addtags = { "nointerrupt" },
})

SGCommon.States.AddMonsterDeathStates(states)
SGMinibossCommon.States.AddMinibossDeathStates(states)

local fns =
{
	OnResumeFromRemote = SGCommon.Fns.ResumeFromRemoteHandleKnockingAttack,
}

SGRegistry:AddData("sg_groak", states)

return StateGraph("sg_groak", states, events, "idle", fns)
