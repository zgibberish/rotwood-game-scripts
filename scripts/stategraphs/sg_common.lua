local Enum = require "util.enum"
local Power = require "defs.powers.power"
local camerautil = require "util.camerautil"
local easing = require "util.easing"
local fmodtable = require "defs.sound.fmodtable"
local kassert = require "util.kassert"
local lume = require "util.lume"
local monsterutil = require "util.monsterutil"
local playerutil = require "util.playerutil"
local strict = require "util.strict"
local soundutil = require "util.soundutil"
local Weight = require "components.weight"

--local DebugDraw = require "util.debugdraw"

local ParticleSystemHelper = require "util.particlesystemhelper"

local SGCommon =
{
	States = {},
	Events = {},
	Fns = {},
}

local function GetModifyAnimName(inst, data, default_name)
	local animname = data and data.modifyanim
	if animname and type(animname) == "function" then
		return data.modifyanim(inst, default_name)
	else
		return animname
	end
end

-- Returns either a valid target or nil. You *must* pass a table or nil.
function SGCommon.Fns.SanitizeTarget(target)
	-- Targets can be multiple types of tables:
	if target
		and (not target.IsValid  -- a position
			or target:IsValid()) -- a valid entity
	then
		return target
	end
end

local function AddEliteTags(inst, tags)
	-- Add elite-only tags to a state
	if inst:HasTag("elite") and tags then
		for _, elite_tag in ipairs(tags) do
			inst.sg:AddStateTag(elite_tag)
		end
	end
end

--------------------------------------------------------------------------
function SGCommon.Events.OnLocomote(params)
	local canrun = params and params.run or false
	local canwalk = params and params.walk or false
	local canturn = params and params.turn or false
	local walkrun_fn = params and params.walkrun_fn or nil

	return EventHandler("locomote", function(inst, data)
		if type(walkrun_fn) == "function" then
			local val = walkrun_fn(inst)
			canrun = val.run
			canwalk = val.walk
			canturn = val.turn
		end

		local walkname = inst.sg.mem.walkname or "walk"
		local runname = inst.sg.mem.runname or "run"
		local shouldturn
		if data ~= nil and data.dir ~= nil then
			local oldfacing = inst.Transform:GetFacing()
			if inst.sg:HasStateTag("turning") then
				inst.Transform:SetRotation(data.dir + 180)
			else
				inst.Transform:SetRotation(data.dir)
			end
			shouldturn = canturn and oldfacing ~= inst.Transform:GetFacing()
		end
		if inst.sg:HasStateTag("busy") then
			return
		elseif data ~= nil and data.move then
			if not inst.sg:HasStateTag("moving") or shouldturn or (canrun and canwalk and inst.sg:HasStateTag("running") == not data.run) then
				if canrun and (data.run or not canwalk) then
					if shouldturn then
						if not inst.sg:HasStateTag("turning") then
							inst:FlipFacingAndRotation()
						end
						inst.sg:GoToState("turn_pre_" .. runname .. "_pre")
					else
						inst.sg:GoToState(runname .. "_pre")
					end
				elseif canwalk then
					if shouldturn then
						if not inst.sg:HasStateTag("turning") then
							inst:FlipFacingAndRotation()
						end
						inst.sg:GoToState("turn_pre_" .. walkname .. "_pre")
					else
						inst.sg:GoToState(walkname .. "_pre")
					end
				end
			end
		elseif shouldturn then
			if not inst.sg:HasStateTag("turning") then
				inst:FlipFacingAndRotation()
			end
			inst.sg:GoToState("turn_pre")
		elseif inst.sg:HasStateTag("moving") then
			if inst.sg:HasStateTag("turning") then
				inst:FlipFacingAndRotation()
			end
			inst.sg:GoToState(inst.sg:HasStateTag("running") and runname .. "_pst" or walkname .. "_pst")
		end
	end)
end

-- Calculate an amount of hitstun frames for an attack based on what percentage of the target's health the attack could do.
-- Used mainly for enemies attacking players. Player hitstun values are tuned per-attack for feel and balance purposes.
function SGCommon.Fns.CalculateHitstunFrames(inst, attack)
	local frames = 4
	local target = attack:GetTarget()
	if target.components.health ~= nil then
		local base_damage = inst.components.combat:GetBaseDamage()
		local damage_mod = attack:GetDamageMod()
		local estimated_damage = base_damage * damage_mod

		local target_max = target.components.health:GetMax() -- POSSIBLE ALTERNATIVE: this could also be based off CURRENT HEALTH, not MAX HEALTH.
																-- If so, then attacks deal more hitstun the closer to death you get, increasing tension.

		local percent = estimated_damage / target_max
		if percent > .75 then
			frames = 20
		elseif percent > .5 then
			frames = 15
		elseif percent > .25 then
			frames = 7
		else
			frames = 4
		end
	end
	return frames
end

function SGCommon.Fns.ApplyHitConfirmEffects(attack)
	-- TODO: ApplyHitstop needs to be separated into attacker and target side effects so
	-- they can be handled based on hit confirm
	local hitstoplevel, allow_multiple_on_attacker, disable_enemy_on_enemy, disable_self_hitstop = attack:GetHitStopData()
	if hitstoplevel ~= HitStopLevel.NONE then
		hitstoplevel = SGCommon.Fns.ApplyHitstop(
			attack,
			hitstoplevel,
			{
				allow_multiple_on_attacker = allow_multiple_on_attacker or false,
				disable_enemy_on_enemy = disable_enemy_on_enemy or false,
				disable_self_hitstop = disable_self_hitstop or false,
			}
		)
	end

	local hit_fx, fx_offset_x, fx_offset_y = attack:GetHitFxData()
	fx_offset_x = fx_offset_x or 0
	fx_offset_y = fx_offset_y or 0

	local target = attack:GetTarget()
	local attacker = attack:GetAttacker()
	local attacking_entity = attack:GetProjectile() or attacker

	if target:IsLocal() and hit_fx then
		-- TheLog.ch.SGCommon:printf("ApplyHitConfirmEffects Spawning FX")
		local dir = attack:GetDir()
		SpawnHitFx(hit_fx, attacking_entity, target, fx_offset_x, fx_offset_y, dir, hitstoplevel)
		SpawnHurtFx(attacking_entity, target, fx_offset_x, dir, hitstoplevel)
	end
end

--------------------------------------------------------------------------
-- Common hitboxtriggered event handler function
-- (Currently intended for monsters only!)
-- TODO: victorc - move more "data" into attacktracker's attack data that is keyed off data.attackdata_id
-- TODO: victorc - rename data to something more specific like attack_override_data

-- Possible parameters for 'data':
-- hitstoplevel: The amount of hitstop to apply to the hit target(s). Refer to hitstopmanager.HitStopLevel for levels.
-- multiplehitstop: Bool to enable applying multiple hitstop instances to targets.
-- attackdata_id: A string ID value referencing attack data that's added to the attacktracker component. Usually found in the prefab file.
-- damage_override: Set override damage. Supercedes damage_mod & player_damage_mod parameters.
-- damage_mod: Damage modifier to apply to the attack. Overrides damage_mod defined in attackdata_id's attacktracker table.
-- player_damage_mod: Damage modifier to apply if the target has the 'player' tag.
-- set_dir_angle_to_target: Bool to set attack direction based on the angle to the target, instead of using the monster's facing rotation.
-- dir_flipped: Bool to add 180 to the SetDir.
-- pushback: The amount of pushback to apply to the hit target(s).
-- hitstun_anim_frames: The amount of hitstun frames to apply to the target(s)
-- focus_attack: Whether or not this attack is a Focus Attack, when displaying the Damage Number and triggering Powers (PLAYER ONLY)
-- force_crit: Force this attack to be a critical hit, ignoring the usual combat rolls.
-- disable_damage_number: Whether or not we should disable visible damage numbers for this attack.
-- disable_hit_reaction: Should we not apply a hit reaction to the target?
-- hitflags: Sets hit flags to determine if hits are made to the target(s). Refer to Attack.HitFlags.
-- source: Sets the source of the attack.
-- combat_attack_fn: Name of the function defined in the combat component to apply attack data to the target(s). Defaults to combat:DoBasicAttack().
-- custom_attack_fn: Use a custom function to apply an attack on the hit target(s). Needs to return a bool whether or not the target was hit. Takes precedence over combat_attack_fn.
-- hit_fx: Add a hit FX to play on the hit target(s).
-- hit_fx_offset_x, hit_fx_offset_y: X & Y-offsets for hit & hurt FX.
-- spawn_hit_fx_fn: Instead of playing the normal hit fx, do something else like a specific hit fx function.
-- hit_target_pre_fn: Custom function to perform before applying an attack to a target.
-- hit_target_pst_fn: Custom function to perform after applying an attack to a target.
-- bypass_posthit_invincibility: Disable the player's post-hit invincibility frames, if this is meant to be a rapidly-hitting attack.
-- can_hit_self: Allow this hitbox to hit the thing that pushed the hitbox.
-- ignore_tags: Ignore hits on entities containing the specified tags.
-- disable_enemy_on_enemy_hitstop: If this is an enemy attacking another enemy, should we disable the hitstop?
-- disable_self_hitstop: Don't apply hitstop to this entity, only the target
-- attack_id: Override the attack's ID, used typically on projectiles for "light_attack" or "heavy_attack"
-- reduce_friendly_fire: If friendly fire damage, reduce the damage.
-- knockdown_becomes_projectile: If this attack is a knockdown, should it do damage to things on the way down?
-- ignore_knockdown: Ignores processing the hit if the target has a 'knockdown' state tag
-- keep_it_local: (network hack) Keep this attack from being sent to remote entities (see special case for megatreemon roots)
--------------------------------------------------------------------------
function SGCommon.Events.OnHitboxTriggered(inst, hitbox_data, data)
	local hitstoplevel = data.hitstoplevel or HitStopLevel.MINOR

	-- Get the attacker's attacktracker component, if it's located on itself or its owner
	local attacktracker = inst.owner ~= nil and inst.owner.components.attacktracker or inst.components.attacktracker
	local damage_mod = 1

	if data.damage_mod then
		damage_mod = data.damage_mod
	elseif attacktracker ~= nil then
		local attack_data = attacktracker:GetAttackData(data.attackdata_id)
		damage_mod = attack_data ~= nil and attack_data.damage_mod or 1
	end

	local dir = inst.Transform:GetFacingRotation()
	if data.dir_flipped then
		dir = dir + 180
	end

	local hit = false
	for i = 1, #hitbox_data.targets do
		local v = hitbox_data.targets[i]

		local hitting_self = (v.owner or v) == (inst.owner or inst)
		if hitting_self and not data.can_hit_self then
			return
		end

		for _, tag in ipairs(data and data.ignore_tags or {}) do
			if v:HasTag(tag) and not hitting_self then
				return
			end
		end

		if data.ignore_knockdown and v.sg and v.sg:HasStateTag("knockdown") then
			return
		end

		if v:IsValid() -- Earlier hitbox handler may have removed the target.
			-- Net: Enabling this forces remote targets to confirm hits (i.e. a "late hit-confirm")
			-- Early hit-confirms: Remote target appear to get hit, but aren't hit in their sim.  That remote target never has the projectile reach them because it's cancelled by this local sim.
			-- Late hit-confirms: Bullet passes through remote clients locally until they confirm they're hit.
			-- TODO:  Take latency into account ahead of initial projectile creation
			-- and (inst.netProjectileGUID == nil or v:IsLocal())
		then
			if data.hit_target_pre_fn then
				data.hit_target_pre_fn(inst, v)
			end

			local attack = Attack(inst, v)

			if data.damage_override then
				attack:SetOverrideDamage(data.damage_override)
			else
				if data.player_damage_mod ~= nil and v.entity:HasTag("player") then
					damage_mod = data.player_damage_mod
				end
				attack:SetDamageMod(damage_mod)
			end

			if data.force_crit then
				attack:SetForceCriticalHit(data.force_crit)
			end

			if data.critchance_bonus then
				attack:DeltaBonusCritChance(data.critchance_bonus)
			end

			if data.critdamage_mult then
				attack:DeltaBonusCritDamageMult(data.critdamage_mult)
			end

			if data.reduce_friendly_fire then
				if (v.entity:HasTag("mob") or v.entity:HasTag("boss")) and not inst:HasTag("playerminion") then
					damage_mod = damage_mod * TUNING.ENEMY_FRIENDLY_FIRE_DAMAGE_MULTIPLIER
					attack:SetDamageMod(damage_mod)
				end
			end

			if data.disable_damage_number then
				attack:DisableDamageNumber()
			end

			if data.set_dir_angle_to_target then
				dir = inst:GetAngleTo(v)
			end
			attack:SetDir(dir)

			attack:SetPushback(data.pushback or 1)
			attack:SetHitstunAnimFrames(data.hitstun_anim_frames or SGCommon.Fns.CalculateHitstunFrames(inst, attack))
			attack:SetHitFlags(data.hitflags or Attack.HitFlags.DEFAULT)

			if data.attack_id then
				attack:SetID(data.attack_id)
			end

			if data.disable_hit_reaction then
				attack:DisableHitReaction()
			end

			if data.bypass_posthit_invincibility then
				attack:DisablePostHitInvincibility()
			end

			if data.source then
				attack:SetSource(data.source)
			end

			if data.focus_attack then
				attack:SetFocus(data.focus_attack)
			end

			if hitbox_data.hitbox then
				attack:SetHitBoxData(hitbox_data.hitbox)
			end

			if data.knockdown_becomes_projectile then
				attack:SetKnockdownBecomesProjectile(true)
			end

			-- need instigator concept here?
			if inst.owner then
				attack:SetProjectile(inst)
			end

			if data.keep_it_local then
				-- TheLog.ch.StateGraph:printf("OnHitboxTriggered: Forcing attack (attacker GUID %d, target GUID %d) to be local only", inst.GUID, v.GUID)
				attack._keep_it_local = true
			end

			-- pack hitstop data for remote ApplyDamage
			attack:SetHitStopData(hitstoplevel, data.multiplehitstop or false, data.disable_enemy_on_enemy_hitstop or false, data.disable_self_hitstop or false)
			attack:SetHitFxData(data.hit_fx, data.hit_fx_offset_x, data.hit_fx_offset_y)

			-- If combat_attack_fn nor custom_attack_fn are defined, default to combat:DoBasicAttack()
			if data.custom_attack_fn ~= nil then
				hit = data.custom_attack_fn(inst, attack)
			elseif data.combat_attack_fn ~= nil then
				hit = inst.components.combat[data.combat_attack_fn](inst.components.combat, attack)
			else
				hit = inst.components.combat:DoBasicAttack(attack)
			end

			if hit then
				if data.spawn_hit_fx_fn then
					data.spawn_hit_fx_fn(inst, v, attack, data)
				end

				-- Play this immediately when:
				-- 1. Attacking entity is a simple projectile (because it will be removed after this hitbox resolution), or
				-- 2a. It is a purely local attack (i.e. megatreemon roots), or
				-- 2b. When attacker or target are non-networked entities.  The results can then
				--     still be transmitted across the network.
				local is_nonplayer_local_simple_projectile = attack:GetProjectile()
					and not attack:GetProjectile().components.complexprojectile
					and not attack:GetProjectile().owner:HasTag("player")
				local do_local_hit_confirm =
					is_nonplayer_local_simple_projectile
					or attack._keep_it_local
					or not inst:IsNetworked() -- attacking entity (attacker or projectile)
					or not v:IsNetworked() -- target

				if do_local_hit_confirm then
					-- TheLog.ch.Combat:printf("Do local hit confirm: attacking_entity %s target %s", inst, v)
					SGCommon.Fns.ApplyHitConfirmEffects(attack)
				end

				-- TODO: does this need network hit confirm?
				if data.hit_target_pst_fn then
					data.hit_target_pst_fn(inst, v, attack)
				end
			end
		end
	end

	return hit
end

--------------------------------------------------------------------------
-- Helper function for projectile hitboxes being triggered.

-- Possible parameters for 'data' (See SGCommon.Events.OnHitboxTriggered for more parameters):
-- keep_alive: bool to prevent the projectile from not destroying itself upon hit. Enable for piercing projectiles.
--------------------------------------------------------------------------
function SGCommon.Events.OnProjectileHitboxTriggered(inst, hitbox_data, data)
	local hit = SGCommon.Events.OnHitboxTriggered(inst, hitbox_data, data)

	-- Remove the projectile
	if hit and not data.keep_alive then
		SGCommon.Fns.RemoveProjectile(inst)
	end

	return hit
end

function SGCommon.Fns.RemoveProjectile(inst)
--[[	if inst.netProjectileGUID then
		local projectileGUID = inst.netProjectileGUID
		inst.netProjectileGUID = nil -- hack: identify local handling by removing this GUID
		EffectEvents.MakeEventCancelProjectile(projectileGUID)
	else]]
		SGCommon.Fns.HandleRemoveProjectile(inst)
	--end
end

function SGCommon.Fns.HandleRemoveProjectile(inst)
	inst:Hide()
	inst:DoTaskInTicks(2, inst.DelayedRemove)
	inst:PushEvent("projectileremoved")
end

--------------------------------------------------------------------------
-- Event handlers/Functions for special movement (e.g. dash) states
--------------------------------------------------------------------------
SGCommon.SPECIAL_MOVEMENT_DIR = MakeEnum{ "FORWARD", "UP", "DOWN", }

-- Possible parameters for 'data':
-- min_up_down_angle, max_up_down_angle: override of angle bounds for the 'up' & 'down' direction.
-- min_down_angle, max_down_angle: override of angle bounds for the 'down' direction.
function SGCommon.Fns.GetSpecialMovementDirection(inst, target, data)
	local angle_a, angle_b = (data and data.min_up_down_angle or 45), (data and data.max_up_down_angle or 135)
	return (inst:IsWithinAngleTo(target, angle_a, angle_b) and SGCommon.SPECIAL_MOVEMENT_DIR.UP) or
			(inst:IsWithinAngleTo(target, -angle_b, -angle_a) and SGCommon.SPECIAL_MOVEMENT_DIR.DOWN) or
			SGCommon.SPECIAL_MOVEMENT_DIR.FORWARD
end

--------------------------------------------------------------------------
-- AddLocomoteStates
--------------------
-- Possible parameters for 'data':
-- isRunState: Set states to use 'run' state transitions instead of 'walk' ones.
-- addtags: Add additional tags to each states defined here.
-- addtags_elite: Add additional tags for elite monsters only.

-- modifyanim: A value or function that returns a base anim name to use for each state.
-- modifyanim_onupdate: A function that return a base anim to use in the onupdate part of a state.

-- onenterpre: A function that runs additional actions in the onenter for the 'pre' state defined here.
-- onenterloop: As above, but in 'loop'.
-- onenterpst: As above, but in 'pst'.
-- onenterturnpre: As above, but in 'turn pre'.
-- onenterturnpst: As above, but in 'turn pst'.

-- preevents: A table of events to add to the events list in the 'pre' state defined here.
-- loopevents: As above, but in 'loop'.
-- pstevents: As above, but in 'pst'.

-- walk_move_delay: Number of frames to delay movement on the walk_pre state.
-- turn_move_delay: Number of frames to delay movement on the turn_pre_<name>_pre state.

-- pretimeline: A table of FrameEvents that get called in the 'pre' state defined here.
-- looptimeline: As above, but in 'loop'.
-- psttimeline: As above, but in 'pst'.
-- turnpretimeline: As above, but in 'turn pre'.
-- turnpsttimeline: As above, but in 'turn pst'.

-- onexitpre: A function that runs additional actions in the onexit for the 'pre' state defined here.
-- onexitloop: As above, but in 'loop'.
-- onexitpst: As above, but in 'pst'.
-- onexitturnpre: As above, but in 'turn pre'.
-- onexitturnpst: As above, but in 'turn pst'.
function SGCommon.States.AddLocomoteStates(states, name, data)
	local run = data ~= nil and data.isRunState or false
	local tag = run and "running" or "walking"

	states[#states + 1] = State({
		name = name.."_pre",
		tags = table.appendarrays({ "moving", tag }, data ~= nil and data.addtags or {}),

		onenter = function(inst, ...)
			local animname = GetModifyAnimName(inst, data, name) or name
			SGCommon.Fns.PlayAnimOnAllLayers(inst, animname.."_pre")

			AddEliteTags(inst, data and data.addtags_elite or nil)

			if data ~= nil and data.onenterpre ~= nil then
				data.onenterpre(inst, ...)
			end
		end,

		timeline = table.appendarrays({}, data ~= nil and data.pretimeline or {},
		{
			FrameEvent(data ~= nil and data.walk_move_delay or 0, function(inst)
				SGCommon.Fns.SetMotorVelScaled(inst, run and inst.components.locomotor:GetBaseRunSpeed() or inst.components.locomotor:GetBaseWalkSpeed())
			end)
		}),

		events =
		{
			EventHandler("animover", function(inst)
				inst.sg.statemem.moving = true
				inst.sg:GoToState(name.."_loop")
			end),
			data ~= nil and data.preevents ~= nil and table.unpack(data.preevents) or nil,
		},

		onexit = function(inst)
			if not inst.sg.statemem.moving then
				inst.Physics:Stop()
			end
			if data ~= nil and data.onexitpre ~= nil then
				data.onexitpre(inst)
			end
		end,
	})

	states[#states + 1] = State({
		name = name.."_loop",
		tags = table.appendarrays({ "moving", tag }, data ~= nil and data.addtags or {}),

		default_data_for_tools = function(inst, cleanup)
			-- _loop generally uses data from onenterpre
			if data ~= nil and data.onenterpre ~= nil then
				data.onenterpre(inst)
			end
		end,

		onenter = function(inst)
			local animname = GetModifyAnimName(inst, data, name) or name
			if not inst.AnimState:IsCurrentAnimation(animname.."_loop") then
				SGCommon.Fns.PlayAnimOnAllLayers(inst, animname.."_loop", true)
			end

			AddEliteTags(inst, data and data.addtags_elite or nil)

			SGCommon.Fns.SetMotorVelScaled(inst, run and inst.components.locomotor:GetBaseRunSpeed() or inst.components.locomotor:GetBaseWalkSpeed())
			if data ~= nil and data.onenterloop ~= nil then
				data.onenterloop(inst)
			end
		end,

		onupdate = function(inst)
			if data ~= nil and data.modifyanim_onupdate ~= nil then
				local animname = name
				animname = data.modifyanim_onupdate(inst, animname)

				if not inst.AnimState:IsCurrentAnimation(animname.."_loop") then
					SGCommon.Fns.PlayAnimOnAllLayers(inst, animname.."_loop", true)
					inst.AnimState:SetFrame(inst.sg.statemem.currentframe_runanim+1)
				end
			end
		end,

		timeline = data ~= nil and data.looptimeline or nil,

		events =
		{
			EventHandler("animover", function(inst)
				inst.sg.statemem.moving = true
				inst.sg:GoToState(name.."_loop")
			end),

			data ~= nil and data.loopevents ~= nil and table.unpack(data.loopevents) or nil,
		},

		onexit = function(inst)
			if not inst.sg.statemem.moving then
				inst.Physics:Stop()
			end
			if data ~= nil and data.onexitloop ~= nil then
				data.onexitloop(inst)
			end
		end,
	})

	states[#states + 1] = State({
		name = name.."_pst",
		tags = data ~= nil and data.addtags or {},

		onenter = function(inst)
			local animname = GetModifyAnimName(inst, data, name) or name
			SGCommon.Fns.PlayAnimOnAllLayers(inst, animname.."_pst")

			AddEliteTags(inst, data and data.addtags_elite or nil)

			if data ~= nil and data.onenterpst ~= nil then
				data.onenterpst(inst)
			end
		end,

		timeline = data ~= nil and data.psttimeline or nil,

		events =
		{
			EventHandler("animover", function(inst)
				inst.sg:GoToState("idle")
			end),
			data ~= nil and data.pstevents ~= nil and table.unpack(data.pstevents) or nil,
		},

		onexit = data ~= nil and data.onexitpst or nil,
	})

	states[#states + 1] = State({
		name = "turn_pre_"..name.."_pre",
		tags = table.appendarrays({ "moving", tag, "turning", "busy" }, data ~= nil and data.addtags or {}),  -- jambell: This used to have 'caninterrupt', not sure if that was needed...

		onenter = function(inst)
			local animname = GetModifyAnimName(inst, data, name) or name
			if data ~= nil and data.modifyanim ~= nil then
				inst.sg.statemem.invertrotationforanim = true
			end
			SGCommon.Fns.PlayAnimOnAllLayers(inst, "turn_pre_"..animname.."_pre")

			AddEliteTags(inst, data and data.addtags_elite or nil)

			if data ~= nil and data.onenterturnpre ~= nil then
				data.onenterturnpre(inst)
			end
		end,

		timeline = table.appendarrays({}, data ~= nil and data.turnpretimeline or {},
		{
			FrameEvent(data ~= nil and data.turn_move_delay or 0, function(inst)
				inst.Physics:SetMotorVel(-(run and inst.components.locomotor:GetBaseRunSpeed() or inst.components.locomotor:GetBaseWalkSpeed()))
			end)
		}),

		events =
		{
			EventHandler("animover", function(inst)
				inst:FlipFacingAndRotation()
				--if still holding button, go run_pre version
				-- if not still holding, just go to
				inst.sg:GoToState("turn_pst_"..name.."_pre")
			end),
		},

		onexit = function(inst)
			if not inst.sg.statemem.moving then
				inst.Physics:Stop()
			end
			if data ~= nil and data.onexitturnpre ~= nil then
				data.onexitturnpre(inst)
			end
		end,
	})

	states[#states + 1] = State({
		name = "turn_pst_"..name.."_pre",
		tags = table.appendarrays({ "moving", tag, "busy" }, data ~= nil and data.addtags or {}), -- jambell: This used to have 'caninterrupt', not sure if that was needed...

		onenter = function(inst)
			local animname = GetModifyAnimName(inst, data, name) or name
			if data ~= nil and data.modifyanim ~= nil then
				inst.sg.statemem.invertrotationforanim = false
			end
			SGCommon.Fns.PlayAnimOnAllLayers(inst, "turn_pst_"..animname.."_pre")

			AddEliteTags(inst, data and data.addtags_elite or nil)

			SGCommon.Fns.SetMotorVelScaled(inst, run and inst.components.locomotor:GetBaseRunSpeed() or inst.components.locomotor:GetBaseWalkSpeed())
			if data ~= nil and data.onenterturnpst ~= nil then
				data.onenterturnpst(inst)
			end
		end,

		timeline = data ~= nil and data.turnpsttimeline or nil,

		events =
		{
			EventHandler("animover", function(inst)
				inst.sg.statemem.moving = true
				inst.sg:GoToState(name.."_loop")
			end),
		},

		onexit = function(inst)
			if not inst.sg.statemem.moving then
				inst.Physics:Stop()
			end
			if data ~= nil and data.onexitturnpst ~= nil then
				data.onexitturnpst(inst)
			end
		end,
	})
end

--------------------------------------------------------------------------
-- AddAttackPreState
--------------------
-- Possible parameters for 'data':
-- tags: A list of tags for this state.
-- addtags: Add additional tags to each state defined here.
-- addevents: Add additional event handlers to each state defined here.
-- alwaysforceattack: makes the state non-interruptable (uses the nointerrupt state tag.)

-- onenter_fn: A function that runs additional actions in onenter.
-- update_fn: As above, but in onupdate.
-- onexit_fn: As above, but in onexit.

-- timeline: A table of FrameEvents that goes into timeline.
function SGCommon.States.AddAttackPre(states, attack_id, data)
	if not data then data = {} end

	states[#states + 1] = State({
		name = attack_id.."_pre",
		tags = table.appendarrays(data.tags or {"attack", "busy", "caninterrupt"}, data.addtags or {}),

		default_data_for_tools = function(inst)
			return GetDebugPlayer()
		end,

		onenter = function(inst, target)
			local attack_data = inst.components.attacktracker:GetAttackData(attack_id)
			local anim_name = attack_data.pre_anim or attack_id.."_pre"

			inst.components.attacktracker:StartActiveAttack(attack_data.id)
			if data.alwaysforceattack or inst.components.attacktracker:IsForcedAttack() then
				inst.sg:RemoveStateTag("caninterrupt")
				inst.sg:AddStateTag("nointerrupt")
			end

			-- Add additional events if specified.
			if data.addevents then
				inst.sg.currentstate:AddEvents(data.addevents)
			end

			SGCommon.Fns.PlayAnimOnAllLayers(inst, anim_name)
			inst.sg.statemem.target = target
			inst.sg.statemem.attack_data = attack_data
			if data.onenter_fn then
				data.onenter_fn(inst, target)
			end
		end,

		onexit = function(inst)
			if data.onexit_fn then
				data.onexit_fn(inst)
			end

			if not inst.sg.statemem.attack_cancelled then
				inst.components.attacktracker:DoStartupFrames(inst.sg:GetAnimFramesInState())
			end
		end,

		onupdate = data.update_fn,

		timeline = data.timeline,

		events =
		{
			EventHandler("animover", function(inst)
				local attack_data = inst.components.attacktracker:GetAttackData(attack_id)
				local next_state = attack_data.attack_state_override or attack_id

				if inst.sg.statemem.attack_data.has_hold then
					next_state = attack_id.."_hold"
				end

				inst.sg:GoToState(next_state, SGCommon.Fns.SanitizeTarget(inst.sg.statemem.target))
			end),
		},
	})
end

--------------------------------------------------------------------------
-- AddAttackHoldState
--------------------
-- Possible parameters for 'data':
-- tags: A list of tags for this state.
-- addtags: Add additional tags to each state defined here.
-- addevents: Add additional event handlers to each state defined here.
-- alwaysforceattack: makes the state non-interruptable (uses the nointerrupt state tag.)

-- onenter_fn: A function that runs additional actions in onenter.
-- update_fn: As above, but in onupdate.
-- onexit_fn: As above, but in onexit.

-- loop_anim: makes the anim loop while in the hold state. Use only if the animator made the hold anim loopable.

-- timeline: A table of FrameEvents that goes into timeline.
function SGCommon.States.AddAttackHold(states, attack_id, data)
	if not data then data = {} end

	states[#states + 1] = State({
		name = attack_id.."_hold",
		tags = table.appendarrays(data.tags or {"attack", "attack_hold", "busy", "caninterrupt"}, data.addtags or {}),
		onenter = function(inst, target)
			local attack_data = inst.components.attacktracker:GetAttackData(attack_id)
			local remaining_startup_frames = inst.components.attacktracker:GetRemainingStartupFrames()
			local anim_name = attack_data.hold_anim or attack_id.."_hold"

			local looping = false
			if data ~= nil and data.loop_anim then
				looping = true
			end
			SGCommon.Fns.PlayAnimOnAllLayers(inst, anim_name, looping)
			inst.sg.statemem.target = target

			if data.alwaysforceattack or inst.components.attacktracker:IsForcedAttack() then
				inst.sg:RemoveStateTag("caninterrupt")
				inst.sg:AddStateTag("nointerrupt")
			end

			-- Add additional events if specified.
			if data.addevents then
				inst.sg.currentstate:AddEvents(data.addevents)
			end

			if remaining_startup_frames >= 0 then
				inst.sg:SetTimeoutAnimFrames(remaining_startup_frames)
			end

			if data.onenter_fn then
				data.onenter_fn(inst)
			end
		end,

		timeline = data.timeline,

		onupdate = data.update_fn,

		events = {
			EventHandler("animover", function(inst)
				local attack_data = inst.components.attacktracker:GetAttackData(attack_id)
				if attack_data.loop_hold_anim then
					inst.sg:GoToState(attack_id.."_hold", SGCommon.Fns.SanitizeTarget(inst.sg.statemem.target))
				end
			end)
		},

		ontimeout = function(inst)
			local attack_data = inst.components.attacktracker:GetAttackData(attack_id)
			local attack_state = attack_data.attack_state_override or attack_id
			inst.sg:GoToState(attack_state, SGCommon.Fns.SanitizeTarget(inst.sg.statemem.target))
		end,

		onexit = function(inst)
			if data.onexit_fn then
				data.onexit_fn(inst)
			end
			inst.components.attacktracker:DoStartupFrames(inst.sg:GetAnimFramesInState())
		end,
	})
end

local function Debug_AttackDataForHitStates(inst)
	return {
		front = true,
		attack = Attack(GetDebugPlayer(), inst)
			:SetDir(GetDebugPlayer().Transform:GetFacingRotation())
			:SetHitstunAnimFrames(10)
			:SetDamage(0)
			:SetPushback(0.4),
	}
end

--------------------------------------------------------------------------
-- AddHitStates
--------------------
-- Possible parameters for 'configdata':
-- addtags: Add additional tags to each state defined here.
-- modifyanim: optional value or function to modifiy the animation that is called
-- onenterhit: A function that runs in the 'hit' onenter, which determines whether or not to transition to another state.

function SGCommon.States.AddHitStates(states, chooseattack_fn, configdata)
	if not configdata then configdata = {} end

	chooseattack_fn = chooseattack_fn or SGCommon.Fns.ChooseAttack

	local base_anim_name = "hit"

	states[#states + 1] = State({
		name = "hit",
		tags = table.appendarrays({ "hit", "busy" }, configdata.addtags or {}),

		default_data_for_tools = Debug_AttackDataForHitStates,

		onenter = function(inst, data)
			local animname =  GetModifyAnimName(inst, configdata, base_anim_name) or base_anim_name
			local animend = data ~= nil and data.front and "_hold" or "_back_hold"

			SGCommon.Fns.PlayAnimOnAllLayers(inst, animname..animend)
			inst.sg.statemem.front = data.front
			local attack = data.attack

			inst.sg:SetTimeoutAnimFrames(attack:GetHitstunAnimFrames())

			if inst.components.hitshudder then
				inst.components.hitshudder:DoShudder(TUNING.HITSHUDDER_AMOUNT_LIGHT, attack:GetHitstunAnimFrames())
			end

			if inst.components.pushbacker then
				inst.components.pushbacker:DoPushBack(attack:GetAttacker(), attack:GetPushback(), attack:GetHitstunAnimFrames())
			end

			if inst.components.foleysounder then
				inst.components.foleysounder:PlayHitStartSound()
			end

			inst.Physics:Stop()

			if configdata.onenterhit ~= nil then
				configdata.onenterhit(inst, data)
			end
		end,


		onexit = function(inst)
			if inst.components.hitshudder then
				inst.components.hitshudder:Stop()
			end

			if inst.components.pushbacker then
				inst.components.pushbacker:Stop()
			end
		end,

		ontimeout = function(inst)
			inst.sg:GoToState("hit_pst", inst.sg.statemem.front)
		end,
	})

	states[#states + 1] = State({
		name = "hit_pst",
		tags = table.appendarrays({ "hit", "busy" }, configdata.addtags or {}),

		onenter = function(inst, front)
			local animname =  GetModifyAnimName(inst, configdata, base_anim_name) or base_anim_name
			local animend = front and "_pst" or "_back_pst"
			SGCommon.Fns.PlayAnimOnAllLayers(inst, animname..animend)
		end,

		timeline =
		{
			FrameEvent(0, function(inst)
				inst.sg:RemoveStateTag("busy")
				if chooseattack_fn then
					SGCommon.Fns.TryQueuedAttack(inst, chooseattack_fn)
				end
			end),
		},

		events =
		{
			SGCommon.Events.OnQueueAttack(chooseattack_fn),
			EventHandler("animover", function(inst)
				inst.sg:GoToState("idle")
			end),
		},
	})
end

--------------------------------------------------------------------------
-- AddLeftRightHitStates
--------------------

-- hit anims for stationary creatures that do hit anims depending on which side they're hit from

-- Possible parameters for 'configdata':
-- addtags: Add additional tags to each state defined here.
-- modifyanim: optional value or function to modifiy the animation that is called
-- onenterhit: A function that runs in the 'hit' onenter, which determines whether or not to transition to another state.

function SGCommon.States.AddLeftRightHitStates(states, chooseattack_fn, configdata)
	if not configdata then configdata = {} end

	chooseattack_fn = chooseattack_fn or SGCommon.Fns.ChooseAttack

	local base_anim_name = "hit"

	states[#states + 1] = State({ name = "hit" })

	states[#states + 1] = State({
		name = "hit_actual",
		tags = { "hit", "busy" },

		default_data_for_tools = Debug_AttackDataForHitStates,

		onenter = function(inst, data)
			local animname =  GetModifyAnimName(inst, configdata, base_anim_name) or base_anim_name
			local animend = data.right and "_r_hold" or "_l_hold"
			SGCommon.Fns.PlayAnimOnAllLayers(inst, animname..animend)
			inst.sg.statemem.right = data.right
			local attack = data.attack

			inst.sg:SetTimeoutAnimFrames(attack:GetHitstunAnimFrames())

			if inst.components.hitshudder then
				inst.components.hitshudder:DoShudder(TUNING.HITSHUDDER_AMOUNT_LIGHT, attack:GetHitstunAnimFrames())
			end

			if configdata.onenterhit ~= nil then
				configdata.onenterhit(inst, data)
			end
		end,

		onexit = function(inst)
			if inst.components.hitshudder then
				inst.components.hitshudder:Stop()
			end
		end,

		ontimeout = function(inst)
			inst.sg:GoToState("hit_pst", inst.sg.statemem.right)
		end,
	})

	states[#states + 1] = State({
		name = "hit_pst",
		tags = table.appendarrays({ "hit", "busy" }, configdata.addtags or {}),

		onenter = function(inst, right)
			local animname = GetModifyAnimName(inst, configdata, base_anim_name) or base_anim_name
			local animend = right and "_r_pst" or "_l_pst"
			SGCommon.Fns.PlayAnimOnAllLayers(inst, animname..animend)
		end,

		timeline =
		{
			FrameEvent(0, function(inst)
				inst.sg:RemoveStateTag("busy")
				if chooseattack_fn then
					SGCommon.Fns.TryQueuedAttack(inst, chooseattack_fn)
				end
			end),
		},

		events =
		{
			SGCommon.Events.OnQueueAttack(chooseattack_fn),
			EventHandler("animover", function(inst)
				inst.sg:GoToState("idle")
			end),
		},
	})
end

--------------------------------------------------------------------------
-- AddKnockbackStates
--------------------
-- Possible parameters for 'configdata':
-- addtags: Add additional tags to each state defined here.
-- movement_frames: how long is the creature in the air in the animation?
-- knockback_pst_timeline: Additional FrameEvents to handle in the 'pst' timeline.
-- modifyanim: optional value or function that can modify the start of the anim name that is played each state

local weight_to_knockdistmult =
{
	knockdown =
	{
		[Weight.Status.s.Light] = 3,
		[Weight.Status.s.Normal] = 1,
		[Weight.Status.s.Heavy] = 0.2,
	},

	knockback =
	{
		[Weight.Status.s.Light] = 2,
		[Weight.Status.s.Normal] = 1,
		[Weight.Status.s.Heavy] = 0.5,
	},
}

function SGCommon.States.AddKnockbackStates(states, configdata)
	if not configdata then configdata = {} end

	local movement_frames = configdata.movement_frames or 8

	local base_anim_name = "flinch"

	states[#states + 1] = State({
		name = "knockback",
		tags = table.appendarrays({ "hit", "knockback", "busy", "nointerrupt" }, configdata.addtags or {}),

		default_data_for_tools = Debug_AttackDataForHitStates,

		onenter = function(inst, data)
			inst.Physics:Stop()
			local attack = data.attack

			local animname = GetModifyAnimName(inst, configdata, base_anim_name) or base_anim_name
			inst.AnimState:PlayAnimation(animname.."_hold")
			inst.sg:SetTimeoutAnimFrames(attack:GetHitstunAnimFrames())
			inst.sg.statemem.data = data

			if inst.components.hitshudder then
				inst.components.hitshudder:DoShudder(TUNING.HITSHUDDER_AMOUNT_MEDIUM, attack:GetHitstunAnimFrames())
			end

			if inst.components.foleysounder then
				inst.components.foleysounder:PlayKnockbackStartSound()
			end

			if configdata.onenter_fn ~= nil then
				configdata.onenter_fn(inst, data)
			end
		end,

		onexit = function(inst)
			if inst.components.hitshudder then
				inst.components.hitshudder:Stop()
			end
		end,

		ontimeout = function(inst)
			inst.sg:GoToState("knockback_pst", inst.sg.statemem.data)
		end,
	})

	states[#states + 1] = State({
		name = "knockback_pst",
		tags = table.appendarrays({ "hit", "knockback", "busy", "nointerrupt" }, configdata.addtags or {}),

		onenter = function(inst, data)
			local animname = GetModifyAnimName(inst, configdata, base_anim_name) or base_anim_name
			inst.AnimState:PlayAnimation(animname.."_pst")

			local pushback = (data and data.attack and data.attack:GetPushback()) or 1
			local weightmult = (inst.components.weight and weight_to_knockdistmult["knockback"][inst.components.weight:GetStatus()]) or 1

			local ticks = movement_frames * ANIM_FRAMES
			local distance = inst.knockback_distance * pushback * weightmult
			local speed = (distance/ticks) * SECONDS

			inst.Physics:SetMotorVel(-speed)
		end,

		timeline = lume.concat(
		{
			FrameEvent(movement_frames, function(inst) inst.Physics:Stop() end), -- stop moving backwards
		}, configdata ~= nil and configdata.knockback_pst_timeline or {}),

		events =
		{
			EventHandler("animover", function(inst)
				inst.sg:GoToState("idle")
			end),
		},

		onexit = function(inst)
			inst.Physics:Stop()
		end,
	})
end

--------------------
-- Knockdown do damage functions
local function KnockdownDoDamageOnStart(inst, data)
	-- Allow the knockdown to hit other things.
	if data.does_damage then
		inst.sg.statemem.does_damage = true

		if data.owner then
			inst.owner = data.owner
		end

		inst.Physics:StartPassingThroughObjects() -- Knockback passes through other objects.
		inst.sg.statemem.currentHitFlags = inst.components.hitbox:GetHitFlags() -- Save hitflag status to reset later.

		 -- Inherit the owner's hit flags, if there is one.
		local ownerHitFlags = inst.owner and inst.owner.components.hitbox:GetHitFlags() or HitGroup.ALL
		inst.components.hitbox:SetHitFlags(ownerHitFlags)

		local powermanager = inst.components.powermanager
		if powermanager ~= nil then

			local def = Power.FindPowerByName("bodydamage")
			if not powermanager:HasPower(def) then
				powermanager:AddPowerByName("bodydamage")
			end
		end
	end
end

local function KnockdownDoDamageOnExit(inst, data)
	if not inst.sg.statemem.does_damage then return end
	inst.sg.statemem.does_damage = nil

	if data.owner then
		inst.owner = nil
	end

	inst.Physics:StopPassingThroughObjects()
	if inst.sg.statemem.currentHitFlags then
		inst.components.hitbox:SetHitFlags(inst.sg.statemem.currentHitFlags)
	end

	local powermanager = inst.components.powermanager
	if powermanager ~= nil then
		powermanager:RemovePowerByName("bodydamage", true)
	end
end

--------------------------------------------------------------------------
-- AddKnockdownStates
--------------------
-- Possible parameters for 'configdata':
-- addtags: Add additional tags to each state defined here.
-- knockdown_size: Set the physics size of the entity (no default, if it doesn't exist then don't change.)
-- getup_frames: How long does the get up animation take (physics size is reset after this.) Only necessary if knockdown_size is defined.
-- movement_frames: How long is the creature in the air in the animation?
-- knockdown_pre_timeline: Additional FrameEvents to handle in the 'pre' timeline.
-- knockdown_pre_onexit: A function that runs additional actions in the onexit for the 'pre' state defined here.
-- modifyanim: optional value or function that can modify the start of the anim name that is played each state
	-- NOTE: Does NOT effect the knockdown_idle state.
-- modifyanim_idle: optional function that can modify that start of the anim name played during knockdown_idle

-- Custom functions that can be called in onenter/onexit of their respective states:
	-- onenter_hold_fn
	-- onexit_hold_fn
	-- onenter_pre_fn
	-- onexit_pre_fn
	-- onenter_idle_fn
	-- onexit_idle_fn
	-- onenter_getup_fn
	-- onexit_getup_fn
function SGCommon.States.AddKnockdownStates(states, configdata)
	if not configdata then configdata = {} end

	local getup_frames = configdata.getup_frames or 10
	local movement_frames = configdata.movement_frames or 10

	local base_anim_name = "knockdown"

	states[#states + 1] = State({
		name = "knockdown",
		tags = table.appendarrays({ "hit", "knockdown", "busy", "nointerrupt" }, configdata.addtags or {}),

		default_data_for_tools = Debug_AttackDataForHitStates,

		onenter = function(inst, data)
			inst.Physics:Stop()

			local animname = GetModifyAnimName(inst, configdata, base_anim_name) or base_anim_name
			inst.AnimState:PlayAnimation(animname.."_hold")

			inst.sg:SetTimeoutAnimFrames(data.attack:GetHitstunAnimFrames())
			inst.sg.statemem.data = data
			inst.sg.statemem.ignorehitshudder = data.ignorehitshudder
			if inst.components.hitshudder and not inst.sg.statemem.ignorehitshudder then
				inst.components.hitshudder:DoShudder(TUNING.HITSHUDDER_AMOUNT_HEAVY, data.attack:GetHitstunAnimFrames())
			end

			if configdata.onenter_hold_fn then
				configdata.onenter_hold_fn(inst)
			end

			if inst.components.foleysounder then
				inst.components.foleysounder:PlayKnockdownStartSound()
			end

			KnockdownDoDamageOnStart(inst, data)
		end,

		onexit = function(inst)
			if inst.components.hitshudder and not inst.sg.statemem.ignorehitshudder then
				inst.components.hitshudder:Stop()
			end

			if configdata.onexit_hold_fn then
				configdata.onexit_hold_fn(inst)
			end

			KnockdownDoDamageOnExit(inst, inst.sg.statemem.data)
		end,

		ontimeout = function(inst)
			inst.sg:GoToState("knockdown_pre", inst.sg.statemem.data)
		end,
	})

	states[#states + 1] = State({
		name = "knockdown_pre",
		tags = table.appendarrays({ "hit", "knockdown", "busy", "nointerrupt", "airborne" }, configdata ~= nil and configdata.addtags or {}),

		default_data_for_tools = Debug_AttackDataForHitStates,

		onenter = function(inst, data)
			local animname = GetModifyAnimName(inst, configdata, base_anim_name) or base_anim_name
			inst.AnimState:PlayAnimation(animname.."_pre")

			inst.sg.statemem.data = data

			local pushback = (data and data.attack and data.attack:GetPushback()) or 1
			local weightmult = (inst.components.weight and weight_to_knockdistmult["knockdown"][inst.components.weight:GetStatus()]) or 1

			local ticks = movement_frames * ANIM_FRAMES
			local distance = inst.knockdown_distance * pushback * weightmult
			local speed = (distance/ticks) * SECONDS

			inst.Physics:SetMotorVel(-speed)

			if configdata.onenter_pre_fn then
				configdata.onenter_pre_fn(inst)
			end

			KnockdownDoDamageOnStart(inst, data)
		end,

		timeline = lume.concat(
		{
			FrameEvent(movement_frames, function(inst)
				if configdata.knockdown_size then
					inst.Physics:SetSize(configdata.knockdown_size)
				end
				inst.Physics:Stop()
				inst.sg:RemoveStateTag("airborne")
				inst.sg:RemoveStateTag("nointerrupt")
				KnockdownDoDamageOnExit(inst, inst.sg.statemem.data) -- Reset optional knockback damage if set
			end)
		},
		configdata ~= nil and configdata.knockdown_pre_timeline or {}),

		events =
		{
			EventHandler("getup", function(inst)
				inst.sg.statemem.getup = true
			end),
			EventHandler("animover", function(inst)
				inst.sg.statemem.knockdown = true
				inst.sg:GoToState(inst.sg.statemem.getup and "knockdown_getup" or "knockdown_idle")
			end),
		},

		onexit = function(inst)
			inst.Physics:SetSize(inst.sg.mem.idlesize)
			inst.Physics:Stop()
			if not inst.sg.statemem.knockdown then
				inst.components.timer:StopTimer("knockdown")
			end
			if configdata.knockdown_pre_onexit then
				configdata.knockdown_pre_onexit(inst)
			end

			if configdata.onexit_pre_fn then
				configdata.onexit_pre_fn(inst)
			end

			KnockdownDoDamageOnExit(inst, inst.sg.statemem.data)
		end,
	})

	states[#states + 1] = State({
		name = "knockdown_idle",
		tags = table.appendarrays({ "knockdown", "busy", "caninterrupt" }, configdata ~= nil and configdata.addtags or {}),

		onenter = function(inst, data)
			local animname = "knockdown"
			if configdata.modifyanim_idle then
				animname = configdata.modifyanim_idle(inst, data)
			end
			inst.AnimState:PlayAnimation(animname.."_idle")

			if configdata.knockdown_size then
				inst.Physics:SetSize(configdata.knockdown_size)
			end

			if configdata.onenter_idle_fn then
				configdata.onenter_idle_fn(inst)
			end
		end,

		events =
		{
			EventHandler("animover", function(inst)
				inst.sg.statemem.knockdown = true
				inst.sg:GoToState("knockdown_idle")
			end),

			EventHandler("getup", function(inst)
				inst.sg:GoToState("knockdown_getup")
			end),
		},

		onexit = function(inst)
			inst.Physics:SetSize(inst.sg.mem.idlesize)
			if not inst.sg.statemem.knockdown then
				inst.components.timer:StopTimer("knockdown")
			end

			if configdata.onexit_idle_fn then
				configdata.onexit_idle_fn(inst)
			end
		end,
	})

	states[#states + 1] = State({
		name = "knockdown_getup",
		tags = table.appendarrays({ "getup", "knockdown", "busy", "nointerrupt" }, configdata ~= nil and configdata.addtags or {}),

		onenter = function(inst)
			local animname = GetModifyAnimName(inst, configdata, base_anim_name) or base_anim_name
			inst.AnimState:PlayAnimation(animname.."_getup")

			inst.components.timer:StopTimer("knockdown")
			if configdata.knockdown_size then
				inst.Physics:SetSize(configdata.knockdown_size)
			end

			if configdata.onenter_getup_fn then
				configdata.onenter_getup_fn(inst)
			end
		end,

		timeline = lume.concat({FrameEvent(getup_frames, function(inst) inst.Physics:SetSize(inst.sg.mem.idlesize) end)}, configdata ~= nil and configdata.knockdown_getup_timeline or {}),

		events =
		{
			EventHandler("animover", function(inst)
				inst.sg:GoToState("idle")
			end),
		},

		onexit = function(inst)
			inst.Physics:Stop()
			inst.Physics:SetSize(inst.sg.mem.idlesize)

			if configdata.onexit_getup_fn then
				configdata.onexit_getup_fn(inst)
			end
		end,
	})
end

--------------------------------------------------------------------------
-- AddKnockdownHitStates
--------------------
-- Possible parameters for 'configdata':
-- addtags: Add additional tags to each state defined here.
-- hit_pst_busy_frames: How many frames into the _pst should they be able to try getting up.

-- Custom functions that can be called in onenter/onexit of their respective states:
	-- onenter_hit_fn
	-- onexit_hit_fn
	-- onenter_pst_fn
	-- onexit_pst_fn
function SGCommon.States.AddKnockdownHitStates(states, configdata)
	if not configdata then configdata = {} end

	local hit_pst_busy_frames = configdata.hit_pst_busy_frames or 4

	states[#states + 1] = State({
		name = "knockdown_hit",
		tags = table.appendarrays({ "hit", "busy", "knockdown" }, configdata.addtags or {}),

		default_data_for_tools = Debug_AttackDataForHitStates,

		onenter = function(inst, data)
			SGCommon.Fns.PlayAnimOnAllLayers(inst, "knockdown_hit_hold")
			inst.sg.statemem.data = data

			local attack = data.attack
			inst.sg:SetTimeoutAnimFrames(attack:GetHitstunAnimFrames())

			if inst.components.hitshudder then
				inst.components.hitshudder:DoShudder(TUNING.HITSHUDDER_AMOUNT_LIGHT, attack:GetHitstunAnimFrames())
			end

			if configdata.onenter_hit_fn then
				configdata.onenter_hit_fn(inst)
			end
		end,

		onexit = function(inst)
			if inst.components.hitshudder then
				inst.components.hitshudder:Stop()
			end

			if configdata.onexit_hit_fn then
				configdata.onexit_hit_fn(inst)
			end
		end,

		ontimeout = function(inst)
			inst.sg:GoToState("knockdown_hit_pst", inst.sg.statemem.data)
		end,
	})

	states[#states + 1] = State({
		name = "knockdown_hit_pst",
		tags = table.appendarrays({ "hit", "busy", "knockdown" }, configdata.addtags or {}),

		onenter = function(inst, data)
			SGCommon.Fns.PlayAnimOnAllLayers(inst, "knockdown_hit_pst")
			inst.sg.statemem.getup = data.getup

			if configdata.onenter_pst_fn then
				configdata.onenter_pst_fn(inst)
			end
		end,

		timeline = {
			FrameEvent(hit_pst_busy_frames, function(inst)
				if inst.sg.statemem.getup then
					inst.sg.statemem.knockdown = true
					inst.sg:GoToState("knockdown_getup")
				else
					inst.sg:AddStateTag("caninterrupt")
				end
			end)
		},

		events =
		{
			EventHandler("getup", function(inst)
				if inst.sg:HasStateTag("caninterrupt") then
					inst.sg.statemem.knockdown = true
					inst.sg:GoToState("knockdown_getup")
				else
					inst.sg.statemem.getup = true
				end
			end),
			EventHandler("animover", function(inst)
				inst.sg.statemem.knockdown = true
				inst.sg:GoToState("knockdown_idle")
			end),
		},

		onexit = function(inst)
			if not inst.sg.statemem.knockdown then
				inst.components.timer:StopTimer("knockdown")
			end

			if configdata.onexit_pst_fn then
				configdata.onexit_pst_fn(inst)
			end
		end,
	})
end

--------------------------------------------------------------------------
-- AddIdleStates
--------------------
-- Possible parameters for 'data':
-- addtags: Add additional tags to each state defined here.
-- addtags_elite: Add additional tags for elite monsters only.
-- num_idle_behaviours: Number of possible idle behaviour anims to play.
-- modifyanim: Optional value or function that returns a value that can be used to modify the anim being played
function SGCommon.States.AddIdleStates(states, data)

	if not data then data = {} end

	data.num_idle_behaviours = data.num_idle_behaviours or 1

	local base_anim_name = ""

	states[#states + 1] = State({
		name = "idle",
		tags = table.appendarrays({ "idle" }, data.addtags or {}),

		onenter = function(inst)
			local anim_mod = GetModifyAnimName(inst, data, base_anim_name) or base_anim_name
			local anim_end = "idle"
			local animname = anim_mod..anim_end

			AddEliteTags(inst, data and data.addtags_elite or nil)

			if not inst.AnimState:IsCurrentAnimation(animname) then
				inst.AnimState:PlayAnimation(animname, true)
			end

			--Used by brain behaviors in case our size varies a lot
			if inst.sg.mem.idlesize == nil then
				inst.sg.mem.idlesize = inst.Physics:GetSize()
				--Used by block states
				inst.sg.mem.idlemass = inst.Physics:GetMass()
			end
		end,

		timeline = {
			FrameEvent(1, function(inst)
				if inst.sg.mem.idle_bb == nil then
					-- used by fx system to determine how large fx around feet should be
					-- if this is set in onenter it is incorrect, so it must be set here
					inst.sg.mem.idle_bb = { inst.entity:GetWorldAABB() }
					-- max_x - min_x
					inst.sg.mem.idle_bb_width = inst.sg.mem.idle_bb[4] - inst.sg.mem.idle_bb[1]
				end
			end),
		},

		events =
		{
			EventHandler("animover", function(inst)
				inst.sg:GoToState("idle")
			end),
		},
	})

	if data.num_idle_behaviours > 0 then
		states[#states + 1] = State({
			name = "idle_behaviour",
			tags = table.appendarrays({ "busy" }, data.addtags or {}),

			onenter = function(inst)
				inst.components.timer:StartTimer("idlebehavior_cd", math.random(6, 10), true)

				local anim_mod = GetModifyAnimName(inst, data, base_anim_name) or base_anim_name
				local anim_end = "behavior"
				local animname = anim_mod..anim_end

				inst.AnimState:PlayAnimation(animname..math.random(1, data.num_idle_behaviours))

				AddEliteTags(inst, data and data.addtags_elite or nil)
				inst.sg:SetTimeoutAnimFrames(300)
			end,

			ontimeout = function(inst)
				TheLog.ch.StateGraph:printf("Warning: %s EntityID %d timed out in state '%s'",
					inst,
					inst:IsNetworked() and inst.Network:GetEntityID() or -1,
					inst.sg:GetCurrentState())
				inst.sg:GoToState("idle")
			end,

			events =
			{
				EventHandler("animover", function(inst)
					inst.sg:GoToState("idle")
				end),
			},
		})
	end
end

--------------------------------------------------------------------------
-- Deprecated states. Remove these eventually!
--------------------

-- Deprecated; use AddLocomoteStates instead!
function SGCommon.States.AddWalkStates(states, data)
	SGCommon.States.AddLocomoteStates(states, "walk", data)
end

-- Deprecated; use AddLocomoteStates instead!
function SGCommon.States.AddRunStates(states, data)
	if data == nil then
		data = {}
	end
	data["isRunState"] = true
	SGCommon.States.AddLocomoteStates(states, "run", data)
end

--------------------------------------------------------------------------

local function AddTurnAroundForcedAttackTags(inst, nextstate)
	-- For monsters if they're going to transition into a non-interrutable attack, set this state to nointerrupt.
	if nextstate and inst.components.attacktracker and inst.components.attacktracker:IsForcedAttack() then
		inst.sg:RemoveStateTag("caninterrupt")
		inst.sg:AddStateTag("nointerrupt")
	end
end

--------------------------------------------------------------------------
-- AddTurnStates
--------------------
-- Possible parameters for 'data':
-- chooseattackfn: A function that returns an attack to try after turning.
-- addtags: Add additional tags to each state defined here.
-- addtags_elite: Add additional tags for elite monsters only.
-- modifyanim: A value or function that returns a base anim name to use for each state.

-- onenterpre: A function that runs additional actions in the onenter for the 'pre' state defined here.
-- onenterpst: As above, but in 'pst'.

-- onupdatepre: A function that runs additional actions in the update for the 'pre' state.
-- onupdatepst: A function that runs additional actions in the update for the 'pst' state.


-- preevents: A table of events to add to the events list in the 'pre' state defined here.
-- pstevents: As above, but in 'pst'.

-- pretimeline: A table of FrameEvents that get called in the 'pre' state defined here.
-- psttimeline: As above, but in 'pst'.

-- onexitpre: A function that runs additional actions in the onexit for the 'pre' state defined here.
-- onexitpst: As above, but in 'pst'.
function SGCommon.States.AddTurnStates(states, data) -- needs to pass in a "choose attack" state
	if not data then data = {} end

	local name = data.name_override or "turn"
	local chooseattack_fn = data ~= nil and data.chooseattackfn or SGCommon.Fns.ChooseAttack

	states[#states + 1] = State({
		name = name.."_pre",
		tags = table.appendarrays({ "turning", "busy" }, data.addtags or {}),

		onenter = function(inst, nextstate)
			local animname = GetModifyAnimName(inst, data, name) or name
			SGCommon.Fns.PlayAnimOnAllLayers(inst, animname.."_pre")

			AddEliteTags(inst, data and data.addtags_elite or nil)
			AddTurnAroundForcedAttackTags(inst, nextstate)

			inst.sg.statemem.nextstate = nextstate
			if data ~= nil and data.onenterpre ~= nil then
				data.onenterpre(inst, nextstate)
			end
		end,

		onupdate = function(inst)
			if data ~= nil and data.onupdatepre ~= nil then
				data.data.onupdatepre(inst)
			end
		end,

		timeline = data ~= nil and data.pretimeline or nil,

		events =
		{
			EventHandler("animover", function(inst)
				inst.sg:GoToState(name.."_pst", inst.sg.statemem.nextstate)
			end),
			data ~= nil and data.preevents ~= nil and table.unpack(data.preevents) or nil,
		},

		onexit = data ~= nil and data.onexitpre or nil,
	})

	states[#states + 1] = State({
		name = name.."_pst",
		tags = table.appendarrays({ "busy" }, data.addtags or {}),

		onenter = function(inst, nextstate)
			local animname = GetModifyAnimName(inst, data, name) or name
			SGCommon.Fns.PlayAnimOnAllLayers(inst, animname.."_pst")

			AddEliteTags(inst, data and data.addtags_elite or nil)
			AddTurnAroundForcedAttackTags(inst, nextstate)

			inst:FlipFacingAndRotation()
			inst.sg.statemem.nextstate = nextstate
			if data ~= nil and data.onenterpst ~= nil then
				data.onenterpst(inst)
			end
		end,

		onupdate = function(inst)
			if data ~= nil and data.onupdatepst ~= nil then
				data.onupdatepst(inst)
			end
		end,


		timeline = {
			FrameEvent(2, function(inst)
				if inst.sg.statemem.nextstate ~= nil then
					inst.sg:GoToState(table.unpack(inst.sg.statemem.nextstate))
				else
					inst.sg:RemoveStateTag("busy")
					inst.sg:AddStateTag("idle")
					SGCommon.Fns.TryQueuedAttack(inst, chooseattack_fn)
				end
			end),
			data ~= nil and data.psttimeline ~= nil and table.unpack(data.psttimeline) or nil,
		},

		events =
		{
			EventHandler("animover", function(inst)
				if inst.sg.statemem.nextstate ~= nil then
					inst.sg:GoToState(table.unpack(inst.sg.statemem.nextstate))
				else
					inst.sg:GoToState("idle")
				end
			end),
			SGCommon.Events.OnQueueAttack(chooseattack_fn),
			data ~= nil and data.pstevents ~= nil and table.unpack(data.pstevents) or nil,
		},

		onexit = data ~= nil and data.onexitpst or nil,
	})
end

--------------------------------------------------------------------------
-- AddSpawnWalkableStates
--------------------
-- Possible parameters for 'data':
-- anim: The spawn in anim to play.
-- addtags: Add additional tags to each state defined here.
-- fadeduration: The duration to fade in.
-- fadedelay: The time to delay spawning in.

-- onenter_fn: A function that runs additional actions in onenter.
-- onupdate_fn: As above, but in onupdate.
-- onexit_fn: As above, but in onexit.
-- events: A table of events to add to the events list in the state defined here.
-- timeline: A table of FrameEvents that get called in the state defined here.

-- spawn_tell_prefab: What is spawned to indicate that an enemy will be appearing there
-- spawn_tell_time: how long do I show the tell prefab before entering the spawn state

SGCommon.States.AddSpawnWalkableStates = function(states, data)
	if not data then data = {} end

	-- Creature must have the "spawn_walkable" tag added on construction to work with this

	states[#states + 1] = State({
		name = "spawn_walkable_wait",
		tags = table.appendarrays({ "busy", "nointerrupt" }, data.addtags or {}),
		onenter = function(inst, spawn_data)
			inst.sg.statemem.spawn_data = spawn_data
			if data.spawn_tell_prefab then
				inst.sg.statemem.spawn_data.spawn_tell =  SpawnPrefab(data.spawn_tell_prefab)
				inst.sg.statemem.spawn_data.spawn_tell.Transform:SetPosition(spawn_data.pos.x, 0, spawn_data.pos.z)
			end

			inst:RemoveFromScene()

			inst:DoTaskInTime(data.spawn_tell_time or 2, function()
				inst:ReturnToScene()
				inst.sg:GoToState("spawn_walkable", inst.sg.statemem.spawn_data)
			end)
		end,
	})

	states[#states + 1] = State({
		name = "spawn_walkable",
		tags = table.appendarrays({ "busy", "nointerrupt" }, data.addtags or {}),

		onenter = function(inst, spawn_data)
			SGCommon.Fns.PlayAnimOnAllLayers(inst, data.anim)

			inst.sg.statemem.spawn_data = spawn_data

			if inst.components.spawnfader then
				inst.components.spawnfader:StartSpawn(data.fadeduration, data.fadedelay)
			end

			if data ~= nil and data.onenter_fn ~= nil then
				data.onenter_fn(inst)
			end
		end,

		onupdate = data ~= nil and data.onupdate_fn or nil,

		timeline = data ~= nil and data.timeline or nil,

		events =
		{
			EventHandler("animover", function(inst)
				inst.sg:GoToState("idle", inst.sg.statemem.nextstate)
			end),
			data ~= nil and data.events ~= nil and table.unpack(data.events) or nil,
		},

		onexit = function(inst)
			if inst.sg.statemem.spawn_data.spawn_tell and inst.sg.statemem.spawn_data.spawn_tell:IsValid() then
				inst.sg.statemem.spawn_data.spawn_tell:Remove()
			end

			if data ~= nil and data.onexit_fn ~= nil then
				data.onexit_fn(inst)
			end
		end,
	})
end

--------------------------------------------------------------------------
-- AddSpawnBattlefieldStates
--------------------
-- Possible parameters for 'data':
-- anim: The spawn in anim to play.
-- addtags: Add additional tags to each state defined here.
-- fadeduration: The duration to fade in.
-- fadedelay: The time to delay spawning in.

-- onenter_fn: A function that runs additional actions in onenter.
-- onupdate_fn: As above, but in onupdate.
-- onexit_fn: As above, but in onexit.
-- events: A table of events to add to the events list in the state defined here.
-- timeline: A table of FrameEvents that get called in the state defined here.
function SGCommon.States.AddSpawnBattlefieldStates(states, data)
	if not data then data = {} end

	states[#states + 1] = State({
		name = "spawn_battlefield",
		tags = table.appendarrays({ "busy", "nointerrupt" }, data.addtags or {}),

		default_data_for_tools = function(inst, cleanup)
			local item = DebugSpawn("spawner_plant1")
			table.insert(cleanup.spawned, item)
			return {
				dir = 0,
				spawner = item,
			}
		end,

		onenter = function(inst, spawn_data)
			SGCommon.Fns.PlayAnimOnAllLayers(inst, data.anim)

			inst.sg.statemem.spawn_data = spawn_data

			if inst.components.spawnfader then
				inst.components.spawnfader:StartSpawn(data.fadeduration, data.fadedelay)
			end

			if data ~= nil and data.onenter_fn ~= nil then
				data.onenter_fn(inst)
			end
		end,

		onupdate = data ~= nil and data.onupdate_fn or nil,

		timeline = data ~= nil and data.timeline or nil,

		events =
		{
			EventHandler("animover", function(inst)
				inst.sg:GoToState("idle", inst.sg.statemem.nextstate)
			end),
			data ~= nil and data.events ~= nil and table.unpack(data.events) or nil,
		},

		onexit = data ~= nil and data.onexit_fn or nil,
	})
end


local function jump_update_fn(inst)
	inst.sg.statemem.jump_data.ticks_passed = math.min(inst.sg.statemem.jump_data.ticks_passed + 1, inst.sg.statemem.jump_data.total_jump_ticks)
	local x = easing.linear(inst.sg.statemem.jump_data.ticks_passed, inst.sg.statemem.jump_data.startpos[1], inst.sg.statemem.jump_data.target_loc[1] - inst.sg.statemem.jump_data.startpos[1], inst.sg.statemem.jump_data.total_jump_ticks)
	local z = easing.linear(inst.sg.statemem.jump_data.ticks_passed, inst.sg.statemem.jump_data.startpos[2], inst.sg.statemem.jump_data.target_loc[2] - inst.sg.statemem.jump_data.startpos[2], inst.sg.statemem.jump_data.total_jump_ticks)
	inst.Transform:SetPosition(x, 0, z)
end

--------------------------------------------------------------------------
-- AddSpawnPerimeterStates
--------------------
-- Possible parameters for 'data':
-- addtags: Add additional tags to each state defined here.
-- pre_anim: The anim to play in the 'pre' state.
-- pst_anim: Same as above, but in 'pst'.
-- hold_anim: The anim to play while entering.
-- land_anim: The anim to play when landing in the play area.

-- jump_time: The time it takes to enter.

-- fadeduration: The duration to fade in.
-- fadedelay: The time to delay spawning in.

-- land_timeline: A table of FrameEvents that get called in the 'land' state defined here.
-- pst_timeline: A table of FrameEvents that get called in the 'pst' state defined here.

-- land_events: A table of EventHandlers that get called in the 'land' state defined here.
-- pst_events: A table of EventHandlers that get called in the 'pst' state defined here.

-- exit_state: The state to transition to after the 'pst' state.
function SGCommon.States.AddSpawnPerimeterStates(states, data)
	if not data then data = {} end
	states[#states + 1] = State({
		name = "spawn_perimeter_pre",
		tags = table.appendarrays({ "busy", "nointerrupt", "airborne" }, data.addtags or {}),

		default_data_for_tools = function(inst)
			-- Target pos cannot be the same position as the object or it'll hit the assert on enter, so return an offset target_pos
			inst.Transform:SetPosition(Vector3.zero:Get())
			return Vector3.unit_x
		end,

		onenter = function(inst, target_pos)
			inst.Physics:SetEnabled(false)
			SGCommon.Fns.PlayAnimOnAllLayers(inst, data.pre_anim)

			inst:FaceXZ(target_pos.x, target_pos.z)

			-- victorc: 60Hz, consider expressing as anim frames
			-- Tricky thing is that jump_update_fn uses ticks as part of its update loop
			local pre_anim_ticks = inst.AnimState:GetAnimationNumFrames(data.pre_anim) * ANIM_FRAMES
			local hold_anim_ticks = inst.AnimState:GetAnimationNumFrames(data.hold_anim) * ANIM_FRAMES
			local land_anim_ticks = inst.AnimState:GetAnimationNumFrames(data.land_anim) * ANIM_FRAMES
			local fixed_anim_length = pre_anim_ticks + land_anim_ticks

			local dist = math.sqrt(inst:GetDistanceSqToXZ(target_pos.x, target_pos.z))
			data.jump_speed = dist/data.jump_time
			if dist == 0 then
				--TEMP(jambell): SUPER temporary for now until the 'holes' are not considered walkable space, or another solution. Find a tile which is ground, spawn there.
				local x,z = inst.Transform:GetWorldXZ()
				local final_x, final_z = monsterutil.BruteForceFindWalkableTileFromXZ(x, z)

				target_pos.x = final_x
				target_pos.z = final_z
				dist = inst:GetDistanceSqToXZ(target_pos.x, target_pos.z)
				data.jump_speed = dist/data.jump_time
			end

			local time_to_travel = dist/data.jump_speed
			local ticks_to_travel = math.ceil(time_to_travel / TICKS)
			local hold_anim_length = ticks_to_travel - fixed_anim_length

			-- printf("Dist: %f, Travel Time: %f, Travel Frames: %f, Fixed Anim Length: %f, Hold Anim Length: %f", dist, time_to_travel, ticks_to_travel, fixed_anim_length, hold_anim_length)

			assert(hold_anim_length <= hold_anim_ticks,
				string.format("Hold animation (%f ticks, %f frames) is not long enough to properly travel %f units @ %f speed! It would need to be %f ticks (%f frames).",
					hold_anim_ticks, hold_anim_ticks / ANIM_FRAMES, dist, data.jump_speed, hold_anim_length, hold_anim_length / ANIM_FRAMES))
			-- assert(ticks_to_travel > fixed_anim_length, string.format("Jump animation is too long to properly do jump! (%f, %f)", dist, data.jump_speed))

			inst.sg.statemem.jump_data = {
				["target_pos"] = target_pos,
				["target_loc"] = { target_pos.x, target_pos.z },
				["startpos"] = { inst.Transform:GetWorldXZ() },
				["ticks_passed"] = 0,
				["fixed_anim_length"] = fixed_anim_length,
				["hold_anim_length"] = hold_anim_length,
				["total_jump_ticks"] = ticks_to_travel,
			}

			if inst.components.spawnfader then
				inst.components.spawnfader:StartSpawn(data.fadeduration, data.fadedelay)
			end
		end,

		onupdate = jump_update_fn,

		events =
		{
			EventHandler("animover", function(inst)
				if inst.sg.statemem.jump_data.hold_anim_length > 0 then
					inst.sg:GoToState("spawn_perimeter", inst.sg.statemem.jump_data)
				else
					inst.sg:GoToState("spawn_perimeter_pst", inst.sg.statemem.jump_data)
				end
			end),
		},

		onexit = function(inst)
			inst.Physics:SetEnabled(true)
		end,
	})

	states[#states + 1] = State({
		name = "spawn_perimeter",
		tags = table.appendarrays({ "busy", "nointerrupt", "airborne" }, data.addtags or {}),

		default_data_for_tools = function(inst, cleanup)
			return {
				["target_pos"] = Vector3.unit_x,
				["target_loc"] = { 1, 0 },
				["startpos"] = { 0, 0 },
				["ticks_passed"] = 0,
				["fixed_anim_length"] = 30,
				["hold_anim_length"] = 30,
				["total_jump_ticks"] = 30,
				["hold_anim"] = "spawn_hold",
			}
		end,

		onenter = function(inst, jump_data)
			inst.sg.statemem.jump_data = jump_data
			inst.sg:SetTimeoutTicks(inst.sg.statemem.jump_data.hold_anim_length)
			-- printf("Timeout Ticks %f", inst.sg.statemem.jump_data.hold_anim_length)
			inst.Physics:SetEnabled(false)
			SGCommon.Fns.PlayAnimOnAllLayers(inst, data.hold_anim)
		end,

		onupdate = jump_update_fn,

		ontimeout = function(inst)
			inst.sg:GoToState("spawn_perimeter_land", inst.sg.statemem.jump_data)
		end,

		onexit = function(inst)
			inst.Physics:SetEnabled(true)
		end,
	})

	states[#states + 1] = State({
		name = "spawn_perimeter_land",
		tags = table.appendarrays({ "busy", "nointerrupt" }, data.addtags or {}),

		default_data_for_tools = function(inst, cleanup)
			return {
				["target_pos"] = Vector3.unit_x,
				["target_loc"] = { 1, 0 },
				["startpos"] = { 0, 0 },
				["ticks_passed"] = 0,
				["fixed_anim_length"] = 30,
				["hold_anim_length"] = 30,
				["total_jump_ticks"] = 30,
				["hold_anim"] = "spawn_land",
			}
		end,

		onenter = function(inst, jump_data)
			inst.sg.statemem.jump_data = jump_data
			SGCommon.Fns.PlayAnimOnAllLayers(inst, data.land_anim)
		end,

		onupdate = jump_update_fn,

		timeline = data ~= nil and data.land_timeline or nil,

		events =
		{
			EventHandler("animover", function(inst)
				inst.sg:GoToState("spawn_perimeter_pst")
			end),
		},
	})
	if data.land_events ~= nil then
		for id,event in ipairs(data.land_events) do
			states[#states].events[event.name] = {}
			table.insert(states[#states].events[event.name], event)
		end
	end

	states[#states + 1] = State({
		name = "spawn_perimeter_pst",
		tags = table.appendarrays({ "busy", "nointerrupt" }, data.addtags or {}),

		onenter = function(inst, jump_data)
			SGCommon.Fns.PlayAnimOnAllLayers(inst, data.pst_anim)
		end,

		timeline = data ~= nil and data.pst_timeline or nil,

		events =
		{
			EventHandler("animover", function(inst)
				inst.sg:GoToState(data.exit_state or "idle")
			end),
		},
	})
	if data.pst_events ~= nil then
		for id,event in ipairs(data.pst_events) do
			states[#states].events[event.name] = {}
			table.insert(states[#states].events[event.name], event)
		end
	end
end

--------------------------------------------------------------------------
-- AddMonsterDeathStates
--------------------
-- Possible parameters for 'data':
-- onenter_fn: A function that runs additional actions in onenter.

function SGCommon.States.AddMonsterDeathStates(states, data)
	if not data then data = {} end

	states[#states + 1] = State({
		name = "death",
		tags = { "busy", "death" },

		onenter = function(inst, spawn_data)
			if data ~= nil and data.onenter_fn ~= nil then
				data.onenter_fn(inst)
			end

			inst:AddTag("no_state_transition")
			inst.sg:Pause("death")
		end,
	})
end

--------------------------------------------------------------------------
-- AddMinibossDeathStates
--------------------
-- Possible parameters for 'data':
-- anim: The spawn in anim to play.
-- addtags: Add additional tags to each state defined here.
-- timeout: The length to remain in this state before removing itself.

-- onenter_fn: A function that runs additional actions in onenter.
-- onupdate_fn: As above, but in onupdate.
-- timeline: A table of FrameEvents that get called in the state defined here.
function SGCommon.States.AddMinibossDeathStates(states, data)
	if not data then data = {} end

	states[#states + 1] = State({
		name = "death_miniboss",
		tags = table.appendarrays({ "busy", "nointerrupt", "death_miniboss" }, data.addtags or {}),

		default_data_for_tools = function(inst, cleanup)
			return { timeout = 10000, }
		end,

		onenter = function(inst, spawn_data)
			SGCommon.Fns.PlayAnimOnAllLayers(inst, data.anim or "elite_death_hit_hold")
			SGCommon.Fns.BlinkAndFadeColor(inst, { 255/255, 255/255, 255/255, 1 }, 15)

			--death_miniboss
			local params = {}
			params.fmodevent = fmodtable.Event.miniboss_death
			params.autostop = false
			soundutil.PlaySoundData(inst, params)

			local audioid = require "defs.sound.audioid"
			local enemies = TheWorld.components.roomclear:GetEnemies()
			local num_minibosses = 0
			for enemy in pairs(enemies) do
				if (enemy:HasTag("miniboss")) then
					num_minibosses = num_minibosses + 1
				end
			end

			if num_minibosses >= 1 then
				TheAudio:SetPersistentSoundParameter(audioid.persistent.boss_music, "local_discreteBinary", 0) -- more intense music after miniboss is dead
			end

			if data ~= nil and data.onenter_fn ~= nil then
				data.onenter_fn(inst)
			end

			inst.components.hitshudder:DoShudder(TUNING.HITSHUDDER_AMOUNT_HEAVY * 2, 30)

			inst:DoTaskInTime(data.timeout or (spawn_data and spawn_data.timeout) or 1, function()
				-- Using DoTaskInTime instead of ontimeout to better sync with death presentation FX
				--inst.sg.mem.deathtask = inst:DoTaskInTicks(0, inst.DelayedRemove)
				inst:PushEvent("done_dying")
			end)
		end,

		onupdate = data ~= nil and data.onupdate_fn or nil,

		timeline = data ~= nil and data.timeline or nil,
	})
end

--------------------------------------------------------------------------
-- AddBossDeathStates
--------------------
-- Possible parameters for 'data':
-- cine_timeline: timeline data to be run during the death_cinematic state.
function SGCommon.States.AddBossDeathStates(states, data)

	-- This state only gets entered via bosses without death cinematics, or debug spawned.
	states[#states + 1] = State({
		name = "death_hit_hold",
		tags = {"death", "busy", "nointerrupt"},
		onenter = function(inst)
			inst.AnimState:PlayAnimation("death_hit_hold")
			inst.sg:SetTimeout(0.5)
		end,
		ontimeout = function(inst)
			inst.sg:GoToState("death_cinematic")
		end,
	})

	states[#states + 1] = State({
		name = "death_cinematic",
		tags = {"death", "busy", "nointerrupt"},
		onenter = function(inst)
			inst.AnimState:PlayAnimation("death")
			-- prevent soft-lock if no state transition and animover event is not triggered
			-- longest death cine is currently ~180 frames
			inst.sg:SetTimeoutAnimFrames(300)
		end,
		timeline = lume.concat(data and data.cine_timeline or {},
		{
		}),
		onupdate = function(inst)
			-- Make sure the boss doesn't move out of bounds.
			local pos = inst:GetPosition()
			local rot = inst.Transform:GetFacingRotation()
			local movedir = Vector3(math.cos(math.rad(rot)), 0, math.sin(math.rad(rot)))
			local PADDING_FROM_EDGE = 4
			local padding = movedir * PADDING_FROM_EDGE
			local testpos = pos + padding
			local isPointOnGround = TheWorld.Map:IsGroundAtPoint(testpos)
			if not isPointOnGround then
				local newPos = TheWorld.Map:FindClosestWalkablePoint(testpos) - padding
				inst.Transform:SetPosition(newPos:Get())
			end
		end,

		ontimeout = function(inst)
			TheLog.ch.StateGraph:printf("Warning: %s Timed out in death_cinematic.  Going to death_idle.", inst)
			inst.sg:GoToState("death_idle")
		end,

		onexit = function(inst)
			-- prevent soft-lock if the animover event isn't received before exiting this state
			if inst.components.health:IsDying() then
				TheLog.ch.StateGraph:printf("Warning: %s Exiting death_cinematic while dying.  Pushing done_dying event now.", inst)
				inst:PushEvent("done_dying")
			end
		end,

		events =
		{
			EventHandler("animover", function(inst)
				-- Bosses stay on screen after they die, so don't push the "done_dying" event - it will remove them!
				inst:PushEvent("done_dying")

				-- Disable eye bloom
				inst.AnimState:SetSymbolBloom("eye_untex", 0, 0, 0, 0)
			end)
		},
	})

	states[#states + 1] = State({
		name = "death_idle",
		tags = {"death", "busy", "nointerrupt"},
		onenter = function(inst)
			-- prevent soft-lock if the animover event isn't received before entering this state
			if inst.components.health:IsDying() then
				TheLog.ch.StateGraph:printf("Warning: %s Entering death_idle while dying.  Pushing done_dying event now.", inst)
				inst:PushEvent("done_dying")
			end

			inst.HitBox:SetEnabled(false)
			inst.Physics:SetEnabled(false)
			inst.components.lootdropper:DropLoot()
		end,
	})
end

--------------------------------------------------------------------------
-- Common Stategraph behaviour functions
--------------------------------------------------------------------------
local function PlayerRotateToFace(inst, dir, snap)
	if dir ~= nil then
		if snap then
			local angle_clamp = TUNING.player.attack_angle_clamp
			local zero_deadzone = TUNING.player.attack_angle_zero_deadzone

			-- First, if the rotation is outside of 'angle_clamp' degrees, clamp it to 'angle_clamp' degrees.
			-- Keep the player from being able to attack directly up or directly down.
			if math.abs(dir) < 90 then
				-- dir = 0
				dir = math.clamp(dir, -angle_clamp, angle_clamp)
			elseif math.abs(dir) > 90 then
				-- dir = 180
				if dir < 0 then
					dir = math.clamp(dir, -180, -180 + angle_clamp)
				else
					dir = math.clamp(dir, 180 - angle_clamp, 180)
				end
			else
				dir = inst.Transform:GetFacingRotation()
			end

			-- Now, apply a deadzone. When clicking at an angle within 'zero_deadzone' degrees relative to directly left/right, snap the angle to directly left/right.
			-- Make it easier for the player to be attacking directly left/right.
			if math.abs(dir) <= zero_deadzone then
				-- Facing right, snap to directly right
				dir = 0
			elseif math.abs(dir - 180) <= zero_deadzone then
				-- Facing left-down, snap to directly left
				dir = 180
			elseif math.abs(dir + 180) <= zero_deadzone then
				-- Facing left-up, snap to directly left
				dir = 180
			end
		end
		inst.Transform:SetRotation(dir)
	elseif snap then
		inst:SnapToFacingRotation()
	end
end

local function RotateToFace(inst, dir, snap)
	if dir ~= nil then
		inst.Transform:SetRotation(dir)
	elseif snap then
		inst:SnapToFacingRotation()
	end
end

function SGCommon.Fns.FaceTarget(inst, target, snap)
	if not target then
		return
	end
	RotateToFace(inst, inst:GetAngleTo(target), snap)
end

function SGCommon.Fns.FaceActionTarget(inst, targetordata, snap, player)
	local target, dir
	if EntityScript.is_instance(targetordata) then
		target = targetordata
	else
		target = targetordata.target
		dir = targetordata.dir
	end
	target = SGCommon.Fns.SanitizeTarget(target)
	if player then
		PlayerRotateToFace(inst, target and inst:GetAngleTo(target) or dir, snap)
	else
		RotateToFace(inst, target and inst:GetAngleTo(target) or dir, snap)
	end
end

function SGCommon.Fns.FaceAwayActionTarget(inst, targetordata, snap)
	local target, dir
	if EntityScript.is_instance(targetordata) then
		target = targetordata
	else
		target = targetordata.target
		dir = targetordata.dir
	end
	target = SGCommon.Fns.SanitizeTarget(target)
	RotateToFace(inst, (target and target:GetAngleTo(inst)) or (dir ~= nil and ReduceAngle(dir + 180)) or nil, snap)
end

function SGCommon.Fns.FaceActionLocation(inst, x, z, snap)
	RotateToFace(inst, inst:GetAngleToXZ(x, z), snap)
end

function SGCommon.Fns.TurnAndActOnTarget(inst, targetordata, snap, nextstate, nextdata, player)
	local canturn = inst.sg:HasState("turn_pre")
	local oldfacing = canturn and inst.Transform:GetFacing() or nil
	SGCommon.Fns.FaceActionTarget(inst, targetordata, snap, player)
	if canturn and oldfacing ~= inst.Transform:GetFacing() then
		inst:FlipFacingAndRotation()
		inst.sg:GoToState("turn_pre", nextstate ~= nil and { nextstate, nextdata } or nil)
	else
		-- TheLog.ch.Player:print("TurnAndActOnTarget", nextstate, nextdata)
		inst.sg:GoToState(nextstate, nextdata)
	end
end

function SGCommon.Fns.TurnAwayFromTargetAndAct(inst, targetordata, snap, nextstate, nextdata)
	local canturn = inst.sg:HasState("turn_pre")
	local oldfacing = canturn and inst.Transform:GetFacing() or nil
	SGCommon.Fns.FaceAwayActionTarget(inst, targetordata, snap)
	if canturn and oldfacing ~= inst.Transform:GetFacing() then
		inst:FlipFacingAndRotation()
		inst.sg:GoToState("turn_pre", nextstate ~= nil and { nextstate, nextdata } or nil)
	else
		-- TheLog.ch.Player:print("TurnAwayFromTargetAndAct", nextstate, nextdata)
		inst.sg:GoToState(nextstate, nextdata)
	end
end

function SGCommon.Fns.TurnAndActOnLocation(inst, x, z, snap, nextstate, nextdata)
	local canturn = inst.sg:HasState("turn_pre")
	local oldfacing = canturn and inst.Transform:GetFacing() or nil
	SGCommon.Fns.FaceActionLocation(inst, x, z, snap)
	if canturn and oldfacing ~= inst.Transform:GetFacing() then
		inst:FlipFacingAndRotation()
		inst.sg:GoToState("turn_pre", nextstate ~= nil and { nextstate, nextdata } or nil)
	else
		TheLog.ch.Player:print("TurnAndActOnLocation", nextstate, nextdata)
		inst.sg:GoToState(nextstate, nextdata)
	end
end

local TargetRange = require "targetrange"
function SGCommon.Fns.ChooseAttack(inst, data)
	if data.target ~= nil and data.target:IsValid() then
		local attacktracker = inst.components.attacktracker
		local trange = TargetRange(inst, data.target)
		local next_attack, backoff_time = attacktracker:PickNextAttack(data, trange)
		if next_attack ~= nil and string.len(next_attack) > 0 then
			TheLog.ch.AI:printf("[%s]	Next attack: %s", inst, next_attack)
			local state_name = attacktracker:GetStateNameForAttack(next_attack)
			SGCommon.Fns.TurnAndActOnTarget(inst, data, false, state_name, data.target)
			return true
		elseif backoff_time and backoff_time > 0 then
			-- TheLog.ch.AI:printf("[%s] Backoff next attack: %1.2f", inst, backoff_time)
			inst.components.combat:StartCooldown(backoff_time)
		end
	end
	return false
end

function SGCommon.Fns.ChooseHitStunPressureAttack(inst, data)
	if data.target ~= nil and data.target:IsValid() then
		local attacktracker = inst.components.attacktracker
		local trange = TargetRange(inst, data.target)
		local next_attack, backoff_time = attacktracker:PickHitStunPressureAttack(data, trange)
		if next_attack ~= nil and string.len(next_attack) > 0 then
			TheLog.ch.AI:printf("[%s]	Next attack: %s", inst, next_attack)
			attacktracker.force_attack = true -- Force the pressure attack to be non-interruptable
			local state_name = attacktracker:GetStateNameForAttack(next_attack)
			SGCommon.Fns.TurnAndActOnTarget(inst, data, false, state_name, data.target)
			return true
		end
	end
	return false
end

--------------------------------------------------------------------------
local function AddHitStunPressureFrames(inst, attack)
	-- Add hitstun frames to the pressure buffer
	local combat = inst.components.combat
	if combat then
		local hitstunframes = attack and attack:GetHitstunAnimFrames() or 0
		combat:AddToCurrentHitStunPressureFrames(hitstunframes)
	end
end

--------------------------------------------------------------------------
local function OnAttacked(inst, data)
	-- jambell: in case you're looking here, I think this is only for the Player attacking an Enemy. Not Enemy attacking Player, or Enemy attacking Enemy.

	local didHit = false

	local attack = data.attack
	dbassert(kassert.assert_fmt(attack:GetHitstunAnimFrames() ~= nil, "Hitstun cannot be nil: [%s] - [%s]", attack._attacker.prefab, attack.id))
	if attack ~= nil and attack:GetHitstunAnimFrames() > 0 then

		local nointerrupt = (inst.sg:HasStateTag("nointerrupt") or inst:HasTag("nointerrupt")) and not inst.sg:HasStateTag("caninterrupt")

		-- For basic attacks, we normally don't trigger hit state during a busy state.
		-- Also used later to send an "attack interrupted" event to the target
		-- However, we -will- allow the enemy to be put back into the 'hit' state
		local isbusy = inst.sg:HasStateTag("busy") and not inst.sg:HasStateTag("hit") and not inst.sg:HasStateTag("turning")

		-- "nointerrupt" tag supercedes everything. Anything with "nointerrupt" and not "caninterrupt" can not do a hit reaction.
		local candohit = not isbusy and (attack:DoHitReaction() or inst.sg:HasStateTag("hit")) and not inst:HasTag("boss") -- re-enter hit state if they're in the hit state already
		candohit = candohit and not nointerrupt

		--This was originally triggered by a knockback or knockdown attack:
		local isknocked = attack ~= nil and attack:GetKnocked()
		isknocked = isknocked and not nointerrupt

		if inst.sg:HasStateTag("knockdown") then
			if inst.components.combat ~= nil and inst.components.combat.hasknockdownhits then
				if candohit or isknocked then
					local getup = inst.sg.statemem.getup or inst.sg:HasStateTag("getup")
					data.getup = getup
					inst.sg.statemem.knockdown = true

					if inst.components.combat.hasknockdownhitdir then
						inst.sg:ForceGoToState(data ~= nil and data.front and "knockdown_hit_front" or "knockdown_hit_back", getup) --TODO: change 'getup' to data, once those states can handle it
					elseif data.attack:IsKnockdown() then
						inst.sg:ForceGoToState("knockdown", data)
					else
						inst.sg:ForceGoToState("knockdown_hit", data)
					end
					didHit = true
				end
			elseif candohit then
				inst.sg:ForceGoToState("hit", data)
				didHit = true
			end
		elseif inst.sg:HasStateTag("block") then
			if candohit or isknocked then
				local unblock = inst.sg.statemem.unblock or inst.sg:HasStateTag("unblock")
				inst.sg.statemem.blocking = true
				if inst.components.combat ~= nil and inst.components.combat.hasblockdir then
					inst.sg:ForceGoToState(data ~= nil and data.front and "block_hit_front" or "block_hit_back", unblock)
					didHit = true
				else
					inst.sg:ForceGoToState("block_hit", unblock)	--JAMBELLHITSTUN
					didHit = true
				end
			end
		elseif inst.sg:HasStateTag("dormant") then
			if candohit or isknocked then
				inst.sg.statemem.dormant = true
				inst.sg:ForceGoToState("dormant_hit")	--JAMBELLHITSTUN
				didHit = true
			end
		elseif candohit then
			inst.sg:ForceGoToState("hit", data)
			didHit = true
		end

		if didHit and isbusy then
			-- is already in the hit state at this point
			inst:PushEvent("attack_interrupted")
		end

		if not didHit then
			if inst.components.hitshudder then
				-- do some hit shudder anyways
				inst.components.hitshudder:DoShudder(TUNING.HITSHUDDER_AMOUNT_LIGHT, attack:GetHitstunAnimFrames())
			end

			--[[
			-- This was causing issues with the Physics:Stop() that is called at the end of the PushBacker logic
			-- That was making attacks like enemy charges stop when they shouldn't.
			-- Disabling this logic for that reason.

			if inst.components.pushbacker then
				-- do some pushback anyways
				inst.components.pushbacker:DoPushBack(attack:GetAttacker(), attack:GetPushback(), attack:GetHitstunAnimFrames())
			end
			--]]
		end

		AddHitStunPressureFrames(inst, attack)
	end
end

function SGCommon.Events.OnAttacked()
	return EventHandler("attacked", OnAttacked)
end

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

local function OnAttackedLeftRight(inst, data)
	SGCommon.Fns.OnAttacked(inst, data)
	if inst.sg:GetCurrentState() == "hit" then
		local right = not IsRightDir(data ~= nil and data.attack:GetDir() or nil)
		inst.sg:GoToState("hit_actual", { right = right, attack = data.attack })
	end
end

function SGCommon.Events.OnAttackedLeftRight()
	return EventHandler("attacked", OnAttackedLeftRight)
end

SGCommon.Fns.OnAttacked = OnAttacked

--------------------------------------------------------------------------
local function OnKnockdown(inst, data)
	-- "vulnerable" state tag allows Knockdown attacks to connect, even if otherwise non-interruptible

	local nointerrupt = (inst.sg:HasStateTag("nointerrupt") or inst:HasTag("nointerrupt")) and not (inst.sg:HasStateTag("caninterrupt") or inst.sg:HasStateTag("vulnerable"))

	if not nointerrupt then
		local state = "knockdown"
		local attack = data and data.attack
		if attack ~= nil then
			if attack:GetKnockdownDuration() ~= nil and inst.components.timer ~= nil then
				local combat = inst.components.combat
				local knockdown_length_modifier = 1
				if combat ~= nil then
					knockdown_length_modifier = combat:GetKnockdownLengthModifier()
				end

				local ticks = math.ceil(attack:GetKnockdownDuration() * knockdown_length_modifier / TICKS)
				inst.components.timer:StartTimerTicks("knockdown", ticks, true)
			end

			if attack:GetDir() ~= nil then
				RotateToFace(inst, attack:GetDir() + 180, true)
			end

			if attack:GetKnockdownBecomesProjectile() then
				data.does_damage = true
				data.owner = attack:GetAttacker()
			end

			if attack:IsHigh() and inst.sg:HasState("knockdown_high") then
				state = "knockdown_high"
			end

			if inst.sg:HasStateTag("airborne_high") and inst.sg:HasState("knockdown_high") then
				state = "knockdown_high"
			end

		end
		inst.sg.statemem.knockdown = true

		inst.sg:ForceGoToState(state, data) --GoToState("knockdown    <-- for easier searchability
	end

	AddHitStunPressureFrames(inst, data and data.attack or nil)
end

function SGCommon.Events.OnKnockdown()
	return EventHandler("knockdown", OnKnockdown)
end

SGCommon.Fns.OnKnockdown = OnKnockdown

--------------------------------------------------------------------------
local function OnKnockback(inst, data)
	local attack = data and data.attack

	AddHitStunPressureFrames(inst, data and data.attack or nil)

	if attack ~= nil and not data.attack:DoHitReaction() then
		return
	end

	--For knockdown attacks, we force hit state except during "nointerrupt".
	local nointerrupt = (inst.sg:HasStateTag("nointerrupt") or inst:HasTag("nointerrupt")) and not inst.sg:HasStateTag("caninterrupt")

	local wasbusy = inst.sg:HasStateTag("busy")

	if not nointerrupt then
		if attack ~= nil and attack:GetDir() ~= nil then
			RotateToFace(inst, attack:GetDir() + 180, true)
		end

		inst.sg:ForceGoToState(inst.sg:HasStateTag("block") and "block_knockback" or "knockback", data) --JAMBELLHITSTUN

		if wasbusy then
			inst:PushEvent("attack_interrupted")
		end
	end
end

function SGCommon.Events.OnKnockback()
	return EventHandler("knockback", OnKnockback)
end

SGCommon.Fns.OnKnockback = OnKnockback

--------------------------------------------------------------------------

local function OnSpawnWalkable(inst, data)
	inst.sg:GoToState("spawn_walkable_wait", data)
end

function SGCommon.Events.OnSpawnWalkable()
	return EventHandler("spawn_walkable", OnSpawnWalkable)
end

local function OnSpawnBattlefield(inst, data)
	inst.sg:GoToState("spawn_battlefield", data)
end

function SGCommon.Events.OnSpawnBattlefield()
	return EventHandler("spawn_battlefield", OnSpawnBattlefield)
end

local function OnSpawnPerimeter(inst, target)
	inst.sg:GoToState("spawn_perimeter_pre", target)
end

function SGCommon.Events.OnSpawnPerimeter()
	return EventHandler("spawn_perimeter", OnSpawnPerimeter)
end

function SGCommon.Fns.OnCinematicSkipped(inst, data)
	if not data then return end

	local cineutil = require "prefabs.cineutil"
	cineutil.ShowActor(inst)
	inst:CancelAllTasks()

	if data.end_pos and data.end_pos.pos then
		local root_pos = data.root_pos or Vector3.zero
		local pos = data.end_pos.pos
		inst.Transform:SetPosition(root_pos.x + pos.x, root_pos.y + pos.y, root_pos.z + pos.z)
	end

	inst.sg:GoToState(data.skip_cine_state or "idle")
end

function SGCommon.Events.OnCinematicSkipped()
	return EventHandler("cine_skipped", SGCommon.Fns.OnCinematicSkipped)
end

--------------------------------------------------------------------------
-- Common Swallowed event handlers
--------------------------------------------------------------------------
function SGCommon.Fns.AddCommonSwallowedEvents(events)
	events[#events + 1] = SGCommon.Events.OnPreSwallowed()
	events[#events + 1] = SGCommon.Events.OnSwallowed()
end

function SGCommon.Fns.OnPreSwallowedCommon(inst, data)
	assert(data.swallower ~= nil, "No swallower exists!")

	inst.sg.mem.swallower = data.swallower
end

--local SWALLOW_PRE_KNOCKBACK = 1
local function OnPreSwallowed(inst, data)
	TheLog.ch.Groak:printf("Pre Swallowed! inst: %s (%d), swallower: %s (%d)", inst.prefab, inst.Network:GetEntityID(), data.swallower and data.swallower.prefab or "", data.swallower and data.swallower.Network:GetEntityID() or "")
	-- [NOTE] The player uses a different implementation of this function! See sg_player_common.lua

	SGCommon.Fns.OnPreSwallowedCommon(inst, data)

	inst.sg:AddStateTag("pre_swallowed")

	-- [TODO]: Transition into a custom pre-swallowed state?

	--[[local swallow_pre_data = Attack(data.swallower, inst)
	swallow_pre_data:SetPushback(SWALLOW_PRE_KNOCKBACK)
	inst.sg:GoToState("knockback", { attack = swallow_pre_data })]]
end

function SGCommon.Events.OnPreSwallowed()
	return EventHandler("pre_swallowed", OnPreSwallowed)
end

function SGCommon.Fns.OnSwallowed(inst, data)
	local swallower = data.swallower
	if not swallower or not swallower:IsValid() then return end

	TheLog.ch.Groak:printf("Swallowed! inst: %s (%d), swallower: %s (%d)", inst.prefab, inst.Network:GetEntityID(), swallower.prefab, swallower.Network:GetEntityID() or "")

	inst.sg:RemoveStateTag("pre_swallowed")
	inst.sg:AddStateTag("swallowed")

	-- Tell the swallower it has swallowed something.
	if swallower.components.groaksync then
		swallower.components.groaksync:SwallowTarget(inst, data)
	end
end

function SGCommon.Events.OnSwallowed()
	return EventHandler("swallowed", SGCommon.Fns.OnSwallowed)
end

function SGCommon.Fns.ExitSwallowed(inst, data)
	TheLog.ch.Groak:printf("Exit Swallowed! inst: %s (%d)", inst.prefab, inst.Network:GetEntityID())

	-- Reset the entity's rotation so that they shoot out in the correct direction.
	--inst.Transform:SetRotation(inst.Transform:GetFacing() == FACING_LEFT and -180 or 0)

	-- If the entity is dying, go to the death_hit state instead of knockdown since the former handles death hit handling & knockback better.
	if not inst:IsAlive() then
		if inst:HasTag("character") then
			if inst:IsRevivable() then
				inst.sg:GoToState("revivable_hit")
			else
				inst.sg:ForceGoToState("death")
			end
		end
	elseif data.swallower then
		local knockbackdata = Attack(data.swallower, inst)
		local size = inst.Physics:GetSize()
		local knockback = data and data.knockback or 0
		knockbackdata:SetPushback(knockback * size)
		local exit_state = inst.sg:HasState("knockdown") and "knockdown" or "idle"
		inst.sg:GoToState(exit_state, { attack = knockbackdata, owner = data.swallower, does_damage = data and data.spitout, ignorehitshudder = true, ignore_face_attacker = true })
	end

	inst.sg.mem.swallower = nil
end

--------------------------------------------------------------------------
-- Death Event Handlers/Functions

local function OnQuickDeathPaused(inst)
	if inst.sg.mem.deathtask then
		inst.sg.mem.deathtask:Cancel()
		inst.sg.mem.deathtask = nil
	end
	inst:RemoveEventCallback("paused", OnQuickDeathPaused)
	inst:ListenForEvent("resumed", inst.DelayedRemove)
end

-- Common actions to perform on entities when dying (Players excluded):
local function OnDying(inst, data)
	--Disable entity
	if inst.Physics ~= nil then
		inst.Physics:SetEnabled(false)
	end
	if inst.HitBox ~= nil then
		inst.HitBox:SetEnabled(false)
	end
	if inst.brain ~= nil then
		inst.brain:Pause("death")
	end

	inst:AddTag("no_state_transition")
end

local function OnDyingCancelled(inst)
	inst:RemoveTag("no_state_transition")

	if inst.Physics ~= nil then
		inst.Physics:SetEnabled(true)
	end
	if inst.HitBox ~= nil then
		inst.HitBox:SetEnabled(true)
	end
	if inst.brain ~= nil then
		inst.brain:Resume("death")
	end
end

SGCommon.Fns.HasSignsOfDying = function(inst)
	if inst:HasTag("no_state_transition") then
		TheLog.ch.StateGraph:printf("HasSignsOfDying: %s EntityID %d has no_state_transition",
			inst,
			inst:IsNetworked() and inst.Network:GetEntityID() or -1)
		return true
	end
	-- brain is local
	if inst.brain ~= nil and inst.brain:IsPausedFor("death") then
		TheLog.ch.StateGraph:printf("HasSignsOfDying: %s EntityID %d has death brain",
			inst,
			inst:IsNetworked() and inst.Network:GetEntityID() or -1)
		return true
	end
	-- this deathtask is also local
	if inst.sg and inst.sg.mem.deathtask then
		TheLog.ch.StateGraph:printf("HasSignsOfDying: %s EntityID %d has death task",
			inst,
			inst:IsNetworked() and inst.Network:GetEntityID() or -1)
		return true
	end

	return false
end

-- TODO: remove this function once it no longer serves use as a reference
local function OnQuickDeathRevived(inst, data)
	if data ~= nil and data.new > 0 then
		TheLog.ch.StateGraph:printf("OnQuickDeathRevived: GUID %d EntityID %d (%s) local=%s old hp=%1.3f new hp=%1.3f",
			inst.GUID, inst.Network and inst.Network:GetEntityID() or -1,
			inst.prefab,
			tostring(inst:IsLocal()),
			data.old, data.new)

		if inst:IsLocal() then
			dbassert(false)
		elseif inst:IsInDelayedRemove() then
			inst:CancelDelayedRemove()
		end

		if inst.sg.mem.deathtask ~= nil then
			inst.sg.mem.deathtask:Cancel()
			inst.sg.mem.deathtask = nil
		end

		inst:RemoveEventCallback("paused", OnQuickDeathPaused)
		inst:RemoveEventCallback("resumed", inst.DelayedRemove)

		OnDyingCancelled(inst)
		inst.sg:Resume("death")

		inst.sg:GoToState("idle")
	end
end

local function DoDeathTask(inst)
	if inst:IsLocal() then
		inst:DelayedRemove()
	else
		TheLog.ch.StateGraph:printf("Warning: DoDeathTask failed to start delayed remove of entity %s EntityID %d because it is no longer local (zombie).",
			inst,
			inst:IsNetworked() and inst.Network:GetEntityID() or -1)
		-- This tries to undo dying state similar to OnQuickDeathRevived
		inst.sg.mem.deathtask = nil
		inst:RemoveEventCallback("paused", OnQuickDeathPaused)
		inst:RemoveEventCallback("resumed", inst.DelayedRemove)

		OnDyingCancelled(inst)
		inst.sg:Resume("death")
	end
end

function SGCommon.Fns.OnMinibossDying(inst, data)
	OnDying(inst, data)

	-- Go to miniboss death state; this state should send out the done_dying event upon completion.
	if inst:HasTag("miniboss") then
		if not inst.sg:HasStateTag("death_miniboss") then
			inst.sg:ForceGoToState("death_miniboss")
		end
	else
		-- We're a regular enemy; go straight to death
		inst.sg:ForceGoToState("death")
		inst:PushEvent("done_dying")
	end
end

function SGCommon.Fns.OnBossDying(inst, data)
	OnDying(inst, data)

	-- Some stategraph event handlers are shared between bosses and non-bosses (e.g. bandicoot & clones).
	-- Check for the boss tag before proceeding with the below boss-specific code.
	if not inst:HasTag("boss") then
		inst.sg:ForceGoToState("death")
		return
	end

	-- Kill all mobs that are alive, clear the encounter
	TheWorld.components.spawncoordinator:SetEncounterCleared()

	-- (TODO: make this not be two separate cinematics?) Cinematic death flow: boss_death_hit_hold -> boss death cinematic.
	if not (inst.components.cineactor and inst.components.cineactor.onevent["dying"]) then
		-- No cinematic or debug spawned; directly go to the death hit state.
		inst.sg:ForceGoToState("death_hit_hold")
	end
end

-- Data parameters:
-- callback_fn: Use this callback function instead of the default behaviour if specified.
-- additional_fn: Custom function to call upon receiving the callback.
function SGCommon.Events.OnDying(data)
	return EventHandler("dying", function(inst, event_data)
		if data and data.callback_fn then
			data.callback_fn(inst)
		else
			OnDying(inst, data)
			-- Go straight to death
			inst.sg:ForceGoToState("death")
			inst:PushEvent("done_dying")
		end
		if data and data.ondying_fn then
			data.ondying_fn(inst, event_data)
		end
	end)
end

local function OnQuickDeath(inst)
	-- Prepare for removal after hitstop, except bosses - leave their corpses on the ground.
	if not inst:HasTag("boss") then
		inst.persists = false
		inst.sg.mem.deathtask = inst:DoTaskInTicks(0, function() DoDeathTask(inst) end)
		inst:ListenForEvent("paused", OnQuickDeathPaused)
	end
end

function SGCommon.Events.OnQuickDeath(ondeathfn)
	return EventHandler("death", function(inst, data)
		OnQuickDeath(inst)
		if ondeathfn ~= nil then
			ondeathfn(inst, data)
		end
	end)
end

local function OnBossDeath(inst)
	if not inst:HasTag("boss") then
		return
	end

	-- Cine will handle death anim and presentation.
	-- Make all players immune to damage - will need to revisit this when we have multiple bosses to fight at the same time.
	for _, player in ipairs(AllPlayers) do
		if player.components.combat then
			player.components.combat:SetDamageReceivedMult("boss_dead", 0)
		end
	end
end

function SGCommon.Events.OnBossDeath()
	return EventHandler("death", OnBossDeath)
end

--------------------------------------------------------------------------
local function OnAttack(inst, data)
	if not inst.sg:HasStateTag("busy") then
		if data.target ~= nil and data.target:IsValid() then
			SGCommon.Fns.TurnAndActOnTarget(inst, data, true, "attack")
		end
	end
end

function SGCommon.Events.OnAttack(chooseattackfn)
	if chooseattackfn ~= nil then
		return EventHandler("doattack", function(inst, data)
			if not inst.sg:HasStateTag("busy") then
				chooseattackfn(inst, data)
			end
		end)
	end
	return EventHandler("doattack", OnAttack)
end

--------------------------------------------------------------------------
local function OnQueueAttack(inst, data)
	if inst.sg:HasStateTag("busy") then
		inst.sg.statemem.queuedattack = data
	elseif data.target ~= nil and data.target:IsValid() then
		SGCommon.Fns.TurnAndActOnTarget(inst, data, true, "attack")
	end
end

function SGCommon.Events.OnQueueAttack(chooseattackfn)
	if chooseattackfn ~= nil then
		return EventHandler("doattack", function(inst, data)
			if inst.sg:HasStateTag("busy") then
				inst.sg.statemem.queuedattack = data
			else
				chooseattackfn(inst, data)
			end
		end)
	end
	return EventHandler("doattack", OnQueueAttack)
end

function SGCommon.Fns.TryQueuedAttack(inst, chooseattackfn)
	local data = inst.sg.statemem.queuedattack
	if data ~= nil then
		if chooseattackfn ~= nil then
			return chooseattackfn(inst, data)
		elseif data.target ~= nil and data.target:IsValid() then
			SGCommon.Fns.TurnAndActOnTarget(inst, data, true, "attack")
			return true
		end
	end
	return false
end

--------------------------------------------------------------------------
function SGCommon.Events.OnHitStunPressureAttack()
	return EventHandler("dohitstunpressureattack", function(inst, data)
		if not inst.sg:HasStateTag("attack")
			and (not inst.sg:HasStateTag("busy") or (inst.sg:HasStateTag("hit") and not inst.sg:HasStateTag("knockdown")))
			and data.target ~= nil and data.target:IsValid() then
			SGCommon.Fns.ChooseHitStunPressureAttack(inst, data)
		end
	end)
end

--------------------------------------------------------------------------
local function OnBattleCry(inst, data)
	if not inst.sg:HasStateTag("busy") then
		if data.target ~= nil and data.target:IsValid() then
			SGCommon.Fns.TurnAndActOnTarget(inst, data, true, "battlecry")
		end
	end
end

function SGCommon.Events.OnBattleCry(choosebattlecryfn)
	if choosebattlecryfn ~= nil then
		return EventHandler("battlecry", function(inst, data)
			if not inst.sg:HasStateTag("busy") then
				choosebattlecryfn(inst, data)
			end
		end)
	end
	return EventHandler("battlecry", OnBattleCry)
end

--------------------------------------------------------------------------
local function OnIdleBehavior(inst)
	if inst.sg:HasStateTag("idle") then
		inst.sg.mem.doidlebehavior = false
		if not (inst.components.timer ~= nil and inst.components.timer:HasTimer("idlebehavior_cd")) then
			local target = inst.components.combat ~= nil and inst.components.combat:GetTarget() or nil
			if target ~= nil then
				SGCommon.Fns.TurnAndActOnTarget(inst, target, true, "idlebehavior")
			else
				inst.sg:GoToState("idlebehavior")
			end
		end
	else
		inst.sg.mem.doidlebehavior = true
	end
end

function SGCommon.Events.OnIdleBehavior(chooseidlebehaviorfn)
	if chooseidlebehaviorfn ~= nil then
		return EventHandler("idlebehavior", function(inst)
			if inst.sg:HasStateTag("idle") then
				inst.sg.mem.doidlebehavior = false
				chooseidlebehaviorfn(inst)
			else
				inst.sg.mem.doidlebehavior = true
			end
		end)
	end
	return EventHandler("idlebehavior", OnIdleBehavior)
end

function SGCommon.Fns.TryIdleBehavior(inst, chooseidlebehaviorfn)
	if inst.sg.mem.doidlebehavior then
		inst.sg.mem.doidlebehavior = false
		if chooseidlebehaviorfn ~= nil then
			return chooseidlebehaviorfn(inst)
		elseif not (inst.components.timer ~= nil and inst.components.timer:HasTimer("idlebehavior_cd")) then
			local target = inst.components.combat ~= nil and inst.components.combat:GetTarget() or nil
			if target ~= nil then
				SGCommon.Fns.TurnAndActOnTarget(inst, target, true, "idlebehavior")
			else
				inst.sg:GoToState("idlebehavior")
			end
			return true
		end
	end
	return false
end

--------------------------------------------------------------------------
local function OnEmote(inst, emote)
	if not inst.sg:HasStateTag("busy") then
		inst.sg.mem.doemote = nil
		inst.sg:GoToState("emote")
	else
		inst.sg.mem.doemote = emote
	end
end

function SGCommon.Events.OnEmote(chooseemotefn)
	if chooseemotefn ~= nil then
		return EventHandler("emote", function(inst, emote)
			if not inst.sg:HasStateTag("busy") then
				inst.sg.mem.doemote = nil
				chooseemotefn(inst, emote)
			else
				inst.sg.mem.doemote = emote
				if inst.sg.statemem.emotepst ~= nil then
					inst.sg.statemem.endingemote = true
					inst.sg:GoToState(inst.sg.statemem.emotepst)
				end
			end
		end)
	end
	return EventHandler("emote", OnEmote)
end

function SGCommon.Fns.TryEmote(inst, chooseemotefn)
	if inst.sg.mem.doemote ~= nil then
		local emote = inst.sg.mem.doemote
		inst.sg.mem.doemote = nil
		if chooseemotefn ~= nil then
			return chooseemotefn(inst, emote)
		end
		inst.sg:GoToState("emote")
		return true
	end
end

function SGCommon.Fns.TryEndEmote(inst, nextstate)
	if inst.sg.mem.doemote ~= nil then
		inst.sg.statemem.endingemote = true
		inst.sg:GoToState(nextstate)
		return true
	end
	inst.sg.statemem.emotepst = nextstate
	return false
end

--------------------------------------------------------------------------
function SGCommon.Fns.MoveToPoint(inst, target_pos, duration)
	local start_pos = inst:GetPosition()

	local fn = function(inst_, progress)
		local dest = target_pos
		local pos = Vector3.lerp(start_pos, dest, progress)
		inst.Transform:SetPosition(pos:unpack())
		if progress >= 1 then
			inst:PushEvent("movetopoint_complete")
		end
	end

	return inst:DoDurationTaskForTicks(duration / TICKS, fn)
end

function SGCommon.Fns.MoveToTarget(inst, data)
	if not data then return end

	local start_pos = inst:GetPosition()

	local fn = function(inst_, progress)
		local dest = data.target:GetPosition() + (data.offset or Vector3.zero)
		local pos = Vector3.lerp(start_pos, dest, progress)
		if TheWorld.Map:IsGroundAtPoint(pos) then
			inst.Transform:SetPosition(pos:unpack())
		end
		if progress >= 1 then
			inst:PushEvent("movetopoint_complete")
		end
	end

	return inst:DoDurationTaskForTicks(data.duration / TICKS, fn)
end

function SGCommon.Fns.MoveToDist(inst, ent, dist, flip)
	if ent then
		local x, z = inst.Transform:GetWorldXZ()
		local facingrot = inst.Transform:GetFacingRotation()
		if dist ~= 0 then
			local theta = math.rad(facingrot)
			ent.Transform:SetPosition(x + dist * math.cos(theta), 0, z - dist * math.sin(theta))
		else
			ent.Transform:SetPosition(x, 0, z)
		end
		ent.Transform:SetRotation(facingrot)
		if flip then
			ent.AnimState:SetScale(-1, 1)
		end
		return ent
	end
end

function SGCommon.Fns.SpawnAtDist(inst, prefab, dist, flip, forceLocal)
	if not prefab then return end
	local ent = SpawnPrefab(prefab, inst, nil, forceLocal)
	if ent then
		local x, z = inst.Transform:GetWorldXZ()
		local facingrot = inst.Transform:GetFacingRotation()
		if dist ~= 0 then
			local theta = math.rad(facingrot)
			ent.Transform:SetPosition(x + dist * math.cos(theta), 0, z - dist * math.sin(theta))
		else
			ent.Transform:SetPosition(x, 0, z)
		end
		ent.Transform:SetRotation(facingrot)
		if flip then
			ent.AnimState:SetScale(-1, 1)
		end
		return ent
	else
		TheLog.ch.Player:print("SpawnAtDist: could not spawn prefab:", prefab)
	end
end

function SGCommon.Fns.SpawnAtAngleDist(inst, prefab, dist, angle, flip)
	local ent = SpawnPrefab(prefab, inst)
	if ent then
		local x, z = inst.Transform:GetWorldXZ()

		local angle_mod = inst.Transform:GetFacing() == FACING_LEFT and -1 or 1
		local facingrot = inst.Transform:GetFacingRotation() + (angle * angle_mod)

		if dist ~= 0 then
			local theta = math.rad(facingrot)
			ent.Transform:SetPosition(x + dist * math.cos(theta), 0, z - dist * math.sin(theta))
		else
			ent.Transform:SetPosition(x, 0, z)
		end
		ent.Transform:SetRotation(facingrot)
		if flip then
			ent.AnimState:SetScale(-1, 1)
		end
		return ent
	else
		TheLog.ch.Player:print("SpawnAtDist: could not spawn prefab:", prefab)
	end
end

function SGCommon.Fns.CalculateFacingXZOffsets(inst, dist, facingrot)
	if dist ~= 0 then
		facingrot = facingrot or inst.Transform:GetFacingRotation()
		local theta = math.rad(facingrot - inst.Transform:GetRotation())
		return dist * math.cos(theta), -dist * math.sin(theta)
	else
		return 0,0
	end
end

function SGCommon.Fns.SpawnChildAtDist(inst, prefab, dist, isFX)
	local ent = SpawnPrefab(prefab, inst)
	if ent then
		local facingrot = inst.Transform:GetFacingRotation()
		if dist ~= 0 then
			local ox, oz = SGCommon.Fns.CalculateFacingXZOffsets(inst, dist, facingrot)
			ent.Transform:SetPosition(ox, 0, oz)
		end
		ent.Transform:SetRotation(facingrot)
		local flip = false -- add this back in as an argument if it is ever used
		if flip then
			ent.AnimState:SetScale(-1, 1)
		end
		ent.entity:SetParent(inst.entity)
		return ent
	else
		TheLog.ch.Player:print("SpawnChildAtDist: could not spawn prefab:", prefab)
	end
end

-- For networking, use EffectEvents.MakeEventSpawnEffect instead! Use only for spawning attack swipe FX.
function SGCommon.Fns.SpawnFXChildAtDist(inst, prefab, dist)
	return SGCommon.Fns.SpawnChildAtDist(inst, prefab, dist, true)
end

function SGCommon.Fns.SpawnChildrenInRadius(inst, prefab, rad, spacing, flip)
	local perimeter = 2 * math.pi * rad
	local resolution = math.floor(perimeter/spacing)
	local angle_between_children = 360/resolution
	local positions = {}

	for angle = 0, 360, angle_between_children do
		table.insert(positions, Vector2(math.sin(math.rad(angle)), math.cos(math.rad(angle))))
	end

	local children = {}

	for _, spawn_offset in ipairs(positions) do
		local offset = Vector2(spawn_offset.x * rad, spawn_offset.y * rad)
		local child = SpawnPrefab(prefab, inst)
		child.entity:SetParent(inst.entity)
		child.Transform:SetPosition(offset.x, 0, offset.y)
		local angle = inst:GetAngleTo(child)
		if flip then angle = child:GetAngleTo(inst) end
		child.Transform:SetRotation(angle)
		child:SnapToFacingRotation()
		table.insert(children, child)
	end

	return children
end

function SGCommon.Fns.SpawnFollower(inst, prefab)
	local ent = SpawnPrefab(prefab, inst)
	ent.entity:SetParent(inst.entity)
	ent.Follower:FollowSymbol(inst.GUID, prefab)
	return ent
end

--------------------------------------------------------------------------
-- Non-looping fx may have already destroyed themselves, so use this to prevent
-- crashes and ensure proper cleanup.
function SGCommon.Fns.DestroyFx(inst, fx_name)
	kassert.typeof("string", fx_name)
	local fx = inst.sg.statemem[fx_name]
	if fx and fx:IsValid() then
		fx:Remove()
	end
	inst.sg.statemem[fx_name] = nil
end

--------------------------------------------------------------------------
-- This function seems to only ever be used for hitboxes ...
function SGCommon.Fns.MoveChildToDist(child, dist)
	local parent = child.entity:GetParent()
	local theta = math.rad(parent.Transform:GetFacingRotation() - parent.Transform:GetRotation())
	child.Transform:SetPosition(dist * math.cos(theta), 0, -dist * math.sin(theta))
end

function SGCommon.Fns.DetachChild(child)
	local x, z = child.Transform:GetWorldXZ()
	child.entity:SetParent()
	child.Transform:SetPosition(x, 0, z)
end

--------------------------------------------------------------------------

function SGCommon.Fns.SpawnParticlesInRadius(inst, effect_name, rad, spacing, lifetime)
	local perimeter = 2 * math.pi * rad
	local resolution = math.floor(perimeter/spacing)
	local angle_between_children = 360/resolution
	local positions = {}

	for angle = 0, 360, angle_between_children do
		table.insert(positions, Vector2(math.sin(math.rad(angle)), math.cos(math.rad(angle))))
	end

	local children = {}

	for _, spawn_offset in ipairs(positions) do
		local offset = Vector2(spawn_offset.x * rad, spawn_offset.y * rad)

		local child = ParticleSystemHelper.MakeOneShot(nil, effect_name, nil, lifetime)

		child.entity:SetParent(inst.entity)
		child.Transform:SetPosition(offset.x, 0, offset.y)
		table.insert(children, child)
	end

	return children
end

--------------------------------------------------------------------------
local function ResolveLayerAnim(anim, baseanim)
	return #anim > 0 and #baseanim > 0 and (anim.."_"..baseanim) or (anim..baseanim)
end

local function CallAnimStateFn(inst, fn_name, ...)
	-- Helper to hide this ugliness.
	return inst.AnimState[fn_name](inst.AnimState, ...)
end
local function OnAllLayers(inst, fn_name, anim, ...)
	local isRemote = inst.Network and not inst:IsLocalOrMinimal()
	if not isRemote then
		-- the "parent" anim state is already synchronized for remote entities
		CallAnimStateFn(inst, fn_name, ResolveLayerAnim(anim, inst.baseanim or ""), ...)
	end
	if inst.highlightchildren ~= nil then
		for i = 1, #inst.highlightchildren do
			local child = inst.highlightchildren[i]
			if child.baseanim ~= nil then
				-- if isRemote and child.AnimState:GetCurrentAnimationName() ~= ResolveLayerAnim(anim, child.baseanim) then
				-- 	TheLog.ch.StateGraph:printf("%d changing anim: %s to %s",
				-- 		i, child.AnimState:GetCurrentAnimationName(),
				-- 		ResolveLayerAnim(anim, child.baseanim));
				-- end
				CallAnimStateFn(child, fn_name, ResolveLayerAnim(anim, child.baseanim), ...)
			end
		end
	end
end

function SGCommon.Fns.PlayAnimOnAllLayers(inst, anim, looping)
	OnAllLayers(inst, 'PlayAnimation', anim, looping)
end

function SGCommon.Fns.SetAnimPercentOnAllLayers(inst, anim, percent)
	OnAllLayers(inst, 'SetPercent', anim, percent)
end

function SGCommon.Fns.SetRemoteUpdateOnAllLayers(inst, anim, looping, time)
	OnAllLayers(inst, 'SetRemoteUpdate', anim, looping, time)
end

function SGCommon.Fns.PauseAnimOnAllLayers(inst, anim)
	OnAllLayers(inst, 'Pause', anim)
end

function SGCommon.Fns.RemoteAnimUpdate(inst, data)
	if inst.highlightchildren ~= nil then
		-- strip resolved base anim suffix
		-- i.e. hit_r_front -> hit_r, "broken_front" -> "broken"
		-- TODO: what about use_baseanim_for_idle, parallax_use_baseanim_for_idle?
		if inst.baseanim then
			if inst.baseanim == data.name then
				data.name = ""
			elseif #inst.baseanim < #data.name then
				data.name = string.sub(data.name, 1, (#data.name - #inst.baseanim) - 1) -- -1 for "_"
				-- TheLog.ch.StateGraph:printf("RemoteAnimUpdate: ent=%s GUID=%d name=%s", inst.prefab, inst.GUID, data.name)
			end
		end
		-- compare between using remote update and unsynchronized anim playback
		local useRemoteUpdate = false
		if useRemoteUpdate then
			SGCommon.Fns.SetRemoteUpdateOnAllLayers(inst, data.name, data.looping, data.time)
		else
			-- this is basically an unrolled version of PlayAnimationOnAllLayers
			-- with a change to only call the AnimState fn when the anim is different
			local fn_name = "PlayAnimation"
			local anim = data.name
			local looping = data.looping
			if inst.highlightchildren ~= nil then
				for i = 1, #inst.highlightchildren do
					local child = inst.highlightchildren[i]
					if child.baseanim ~= nil then
						local resolved_layer_anim = ResolveLayerAnim(anim, child.baseanim)
						if child.AnimState:GetCurrentAnimationName() ~= resolved_layer_anim then
							-- prop variations concatenate variant to animation name
							if inst.components.prop and inst.components.prop:GetVariation() then
								resolved_layer_anim = resolved_layer_anim .. inst.components.prop:GetVariation()
							end
							CallAnimStateFn(child, fn_name, resolved_layer_anim, looping)
						end
					end
				end
			end
		end
	else
		-- why would this happen?
		inst.AnimState:SetSendRemoteUpdatesToLua(false)
		inst:RemoveEventCallback("remoteanimupdate", SGCommon.Fns.RemoteAnimUpdate)
	end
end

function SGCommon.Fns.SetSaturationOnAllLayers(inst, sat)
	inst.AnimState:SetSaturation(sat)
	if inst.highlightchildren ~= nil then
		for i = 1, #inst.highlightchildren do
			local child = inst.highlightchildren[i]
			child.AnimState:SetSaturation(sat)
		end
	end
end

function SGCommon.Fns.OverrideSymbolOnAllLayers(inst, symbol, build, override_symbol)
	inst.AnimState:OverrideSymbol(symbol, build, override_symbol)
	if inst.highlightchildren ~= nil then
		for i = 1, #inst.highlightchildren do
			local child = inst.highlightchildren[i]
			child.AnimState:OverrideSymbol(symbol, build, override_symbol)
		end
	end
end

function SGCommon.Fns.ClearOverrideSymbolOnAllLayers(inst, symbol)
	inst.AnimState:ClearOverrideSymbol(symbol)
	if inst.highlightchildren ~= nil then
		for i = 1, #inst.highlightchildren do
			local child = inst.highlightchildren[i]
			child.AnimState:ClearOverrideSymbol(symbol)
		end
	end
end
--------------------------------------------------------------------------
SGCommon.SGSpeedScale =
{
	-- Sets of data to represent different amounts that an entity's locomotorspeedmult can affect a stategraph state's speedmult
	-- For example, use MEDIUM for most attacks, but if there's one attack which should be less affected by speedmult, use LIGHT scaling
	TINY =
	{
		m = 0.33,
		b = 0.67,
	},
	LIGHT =
	{
		m = 0.5,
		b = 0.5,
	},

	MEDIUM =
	{
		m = 0.75,
		b = 0.25,
	},

	HEAVY =
	{
		m = 1,
		b = 0,
	},
}

local function validate_sgspeedscales()
	for scalename,scaledata in pairs(SGCommon.SGSpeedScale) do
		assert(scaledata.m + scaledata.b == 1, string.format("SGCommon.SGSpeedScale data sets must add to 1.0. If it doesn't, the scaling gets applied even if locomotor scale is 1.0. This setting does not equal 1.0: [SGCommon.SGSpeedScale.%s]", scalename))
	end
end

validate_sgspeedscales()
function SGCommon.Fns.GetSGSpeedmult(inst, scaleeffect)
	local scalingdata = scaleeffect

	-- y = mx + b, where x = locomotor speedmult and y = our scaled amount
	local m = scalingdata.m
	local b = scalingdata.b
	local locomotor_speedmult = inst.components.locomotor.total_speed_mult

	return (m * locomotor_speedmult) + b
end

function SGCommon.Fns.SetMotorVelScaled(inst, value, scalingamount)
	local scaleeffect --= SGCommon.SGSpeedScale.MEDIUM
	if scalingamount then
		-- If the designer has passed in a specific amount for this call, override everything
		scaleeffect = scalingamount
	elseif inst.sg.mem.sgspeedscaleamount then
		-- Otherwise, if the designer has set a stategraph-wide setting, use that one
		scaleeffect = inst.sg.mem.sgspeedscaleamount
	else
		-- Otherwise, fall back to default MEDIUM for this function.
		scaleeffect = SGCommon.SGSpeedScale.MEDIUM
	end

	local sgspeedmult = SGCommon.Fns.GetSGSpeedmult(inst, scaleeffect)
	local moveDir = Vector3(value * sgspeedmult, 0, 0)

	-- print("SetMotorVelScaled", inst, " | value", value, " | sgspeedmult", sgspeedmult, " | value * sgspeedmult", value * sgspeedmult)
	--DebugDraw.GroundArrow_Vec(inst:GetPosition(), Vector3(inst.entity:LocalToWorldSpace(moveDir:unpack())), WEBCOLORS.GREEN)
	--DebugDraw.GroundArrow_Vec(inst:GetPosition(), inst:GetPosition() + inst.components.pushforce:GetTotalPushForce(), WEBCOLORS.MAGENTA)

	-- Final move direction is the move direction + external forces
	local rot = inst.Transform:GetRotation()

	-- Convert to world space to make clamping calculations easier!
	local push_force = inst.components.pushforce:GetTotalPushForceWithModifiers()
	local moveDir_world = Vector3.rotate(moveDir, math.rad(rot), Vector3.unit_y)
	local total_force_world = moveDir_world + push_force

	-- If moving in the direction of the force, clamp it to the speed of the force itself.
	--[[local total_force_x = total_force_world.x > push_force.x and push_force.x > math.abs(moveDir.x) and push_force.x or total_force_world.x
	local total_force_y = total_force_world.y > push_force.y and push_force.y > math.abs(moveDir.y) and push_force.y or total_force_world.y
	local total_force_z = total_force_world.z > push_force.z and push_force.z > math.abs(moveDir.z) and push_force.z or total_force_world.z
	local total_force_clamped = Vector3(total_force_x, total_force_y, total_force_z)

	local total_force = Vector3.rotate(total_force_clamped, math.rad(-rot), Vector3.unit_y)]]
	local total_force = Vector3.rotate(total_force_world, math.rad(-rot), Vector3.unit_y)
	local final_force = inst.components.pushforce:ClampMaxPushForce(total_force)

	--DebugDraw.GroundArrow_Vec(inst:GetPosition(), inst:GetPosition() + final_force, WEBCOLORS.CYAN)
	inst.Physics:SetMotorVel(final_force:unpack())
	--inst.Physics:SetMotorVel(moveDir:unpack())
end

function SGCommon.Fns.MoveRelFacingScaled(inst, value, scalingamount)
	local scaleeffect
	if scalingamount then
		-- If the designer has passed in a specific amount for this call, override everything
		scaleeffect = scalingamount
	elseif inst.sg.mem.sgspeedscaleamount then
		-- Otherwise, if the designer has set a stategraph-wide setting, use that one
		scaleeffect = inst.sg.mem.sgspeedscaleamount
	else
		-- Otherwise, fall back to default LIGHT for this function.
		scaleeffect = SGCommon.SGSpeedScale.LIGHT
	end

	local sgspeedmult = SGCommon.Fns.GetSGSpeedmult(inst, scaleeffect)
	inst.Physics:MoveRelFacing(math.min(value * sgspeedmult, 2)) -- Cap at 2 so we never go more than 2 units per frame
end

--------------------------------------------------------------------------

function SGCommon.Fns.GetSineWaveForState(mod, abs, sg, timemod)
    local time = ((sg and sg:GetTimeInState()) + (timemod or 0)) * (mod or 1)
    local val = math.sin(math.pi * time)
    if abs then
        return math.abs(val)
    else
        return val
    end
end

function SGCommon.Fns.ApplyHitstop(attack, hitstop, data)
	-- allow_multiple_on_attacker: If this attack has hit multiple targets, should it apply hitstop on the subsequent targets after the first?
	-- projectile: If this is a projectile, specify that so that the projectile is hitstopped, not the sender of the projectile
	-- disable_enemy_on_enemy: If this is an enemy, and the target is an enemy, opt out of hitstopping for this hit.

	-- jambell: this should be split out, it does way more than "apply hitstop" now

	local attacker = attack:GetAttacker()
	local target = attack:GetTarget()

	local target_is_player = target:HasTag("player")

	assert(hitstop ~= nil, "HitboxTriggered event needs a hitstop level defined!")
	local hitstoplevel = hitstop
	if attack:GetCrit() then
		hitstoplevel = hitstoplevel + TUNING.CRIT_HITSTOP_EXTRA_FRAMES
	end

	-- Set these parameters below depending on who the target is:
	local screenshake = false -- Shake the screen?
	local targetblink = false -- Flash the target white?
	local hitoverlay = nil -- Show a hit overlay?
	local impactsound = nil -- Play an extra sound when the hit connects?
	local snapshot = nil -- Trigger snapshot when hitstop occurs?
	local snapshot_mutemusic = nil -- This snapshot will trigger on death hitstop, if specified
	local snapshot_muteamb = nil -- This snapshot will trigger on death hitstop, if specified
	local posthitstopsound = nil -- Play an extra sound after the hitstop finishes?
	local hitstopdelayframes = nil -- Wait some frames before applying hitstop, so the character is in better frame?

	local cameratarget = nil
	local lightintensity = nil
	local timescale_mult = nil

	local kill = (target.sg == nil or not target.sg:HasStateTag("nokill")) and target:IsDying()

	if target.components.hitstopper ~= nil then
		-- Figure out what extra effects we should be playing, first. Play them below.
		if kill
			and ((attacker ~= nil and attacker.sg ~= nil and not attacker.sg.statemem.haskillstopped) or target_is_player)
			and (target ~= nil and not target.sg.mem.hasbeenkillstopped)
		then
			-- Player died
			if target_is_player then
				hitstoplevel = HitStopLevel.PLAYERKILL
				screenshake = true
				targetblink = TUNING.BLINK_AND_FADES.PLAYER_DEATH
				--hitoverlay = TheDungeon.HUD and TheDungeon.HUD.effects.death_stop
				hitstopdelayframes = TUNING.HITSTOP_PLAYER_KILL_DELAY_FRAMES
				impactsound = fmodtable.Event.Hit_player_death

				-- We were the last player alive (and are now dead).
				if playerutil.AreAllPlayersNotAlive() then
					timescale_mult = 0.5
					cameratarget = target
					lightintensity = true
					snapshot = fmodtable.Snapshot.HitstopCutToBlack
					snapshot_mutemusic = fmodtable.Snapshot.Mute_Music_NonMenuMusic
					snapshot_muteamb = fmodtable.Snapshot.Mute_Ambience_Levels
					posthitstopsound = fmodtable.Event.Hit_player_death_ring
				end
			-- Miniboss died
			elseif target:HasTag("miniboss") then
				hitstoplevel = HitStopLevel.MINIBOSSKILL
				--hitstopdelayframes = TUNING.HITSTOP_BOSS_KILL_DELAY_FRAMES
			-- Boss died
			elseif target:HasTag("boss") then
				hitstoplevel = HitStopLevel.BOSSKILL
				screenshake = true
				-- hitstopdelayframes = TUNING.HITSTOP_BOSS_KILL_DELAY_FRAMES
				--TODO sound: extrasound for boss kill hitstop sweetener?
			-- Normal mob or something else died
			else
				hitstoplevel = HitStopLevel.KILL
			end

			if attacker.sg ~= nil then
				attacker.sg.statemem.haskillstopped = true
			end
			-- target.sg.mem.hasbeenkillstopped = true    --DISABLING because it's kind of cool to get killstopped multiple times, I think!
		else
			if target_is_player then
				hitstoplevel = hitstoplevel + TUNING.HITSTOP_TO_PLAYER_EXTRA_FRAMES
			end
		end

		if attacker:HasTag("mob") and target:HasTag("mob") then
			if data ~= nil and data.disable_enemy_on_enemy then
				hitstoplevel = 0
			end
		end

		local target_mult = target.components.hitstopper:GetHitStopMultiplier()
		hitstoplevel = hitstoplevel * target_mult

		local function play_extra_effects(sound, snapshot, screenshake, hitoverlay, targetblink)
			if sound then
				--sound
				local params = {}
				params.fmodevent = sound
				soundutil.PlaySoundData(target, params)

			end
			if snapshot then
				TheAudio:StartFMODSnapshot(snapshot)
			end
			if screenshake then
				ShakeAllCameras(CAMERASHAKE.FULL, 1, .02, .2)
			end
			if hitoverlay ~= nil then
				hitoverlay:StartOneShot()
			end
			if targetblink then
				SGCommon.Fns.BlinkAndFadeColor(target, targetblink.COLOR, targetblink.FRAMES)
			end
		end

		local function stop_extra_effects(snapshot)
			if snapshot then
				TheAudio:StopFMODSnapshot(snapshot)
			end
		end

		local original_timescale = not target.sg.mem.deathstop_timescaling and TheSim:GetTimeScale() or target.sg.mem.original_timescale -- in case we need it later
		target.sg.mem.original_timescale = not target.sg.mem.deathstop_timescaling and original_timescale or target.sg.mem.original_timescale

		-- Two sequences here... first up is one that delays the HitStop for a few frames for presentation reasons.

		-- SEQUENCE TYPE ONE: IMPACT, then a slight delay, HITSTOP, then a third segment which happens after hitstop has completed
		if hitstopdelayframes ~= nil then
			--ON IMPACT:
			if screenshake ~= nil then
				ShakeAllCameras(CAMERASHAKE.FULL, 1, .04, .2)
			end
			if targetblink then
				-- Push the color immediately to make a strong impact, and then pop it after hitstop + Blink it to fade it out
				target.components.coloradder:PushColor("PlayerDeathHitstop", targetblink.COLOR[1]*.8, targetblink.COLOR[2]*.8, targetblink.COLOR[3]*.8, .8)
			end
			if impactsound then
				--sound
				local params = {}
				params.fmodevent = impactsound
				soundutil.PlaySoundData(target, params)
			end
			if snapshot then
				TheAudio:StartFMODSnapshot(snapshot)
			end
			if snapshot_mutemusic then
				TheAudio:StartFMODSnapshot(snapshot_mutemusic)
			end
			if snapshot_muteamb then
				TheAudio:StartFMODSnapshot(snapshot_muteamb)
			end

			if cameratarget then
				camerautil.StartTarget(target, {dist=25, offset={ x=0, y=0, z=-2 }}) --TODO: would like to make the camera move more quicker, without being an explicit snapcut
				TheDungeon:SetHudVisibility(false)
			end

			if lightintensity then
				local param = { target_intensity=1.0, attacker_intensity=1.0, world_intensity=0.1 }
				target.AnimState:SetLightOverride(param.target_intensity)
				attacker.AnimState:SetLightOverride(param.attacker_intensity)
				TheWorld.components.lightcoordinator:SetIntensity(param.world_intensity)
			end

			-- WHEN HITSTOP STARTS:
			target:DoTaskInAnimFrames(hitstopdelayframes, function()
				target = SGCommon.Fns.SanitizeTarget(target)
				if target then
					target.components.hitstopper:PushHitStop(hitstoplevel)
					if hitoverlay ~= nil then
						hitoverlay:StartOneShot()
					end
				end
			end)

			-- AFTER HITSTOP:
			target:DoTaskInAnimFrames(hitstopdelayframes + hitstoplevel, function()
				target = SGCommon.Fns.SanitizeTarget(target)
				if not target then
					return
				end
				TheDungeon:SetHudVisibility(true)

				if snapshot then
					TheAudio:StopFMODSnapshot(snapshot)
				end
				-- Music and Ambience are not unmuted in this case, and those snapshots are instead stopped on the death screen

				if targetblink then
					target.components.coloradder:PopColor("PlayerDeathHitstop")
					SGCommon.Fns.BlinkAndFadeColor(target, targetblink.COLOR, targetblink.FRAMES)
				end

				if cameratarget then
					camerautil:ReleaseCamera()
				end

				if lightintensity then
					-- Clearing the AnimState's self light override is unsupported.
					TheWorld.components.lightcoordinator:ResetColor()
				end

				if timescale_mult and not target.sg.mem.deathstop_timescaling then
					target.sg.mem.deathstop_timescaling = true
					TheSim:SetTimeScale(original_timescale * timescale_mult)
					local deathanimframes = 20 + hitstoplevel --target.AnimState:GetCurrentAnimationNumFrames()
					target:DoTaskInAnimFrames(math.floor(deathanimframes*0.5), function()
						local lerped_value = lume.lerp(original_timescale * timescale_mult, original_timescale, 0.33)
						TheSim:SetTimeScale(lerped_value)
					end)
					target:DoTaskInAnimFrames(math.floor(deathanimframes*0.75), function()
						local lerped_value = lume.lerp(original_timescale * timescale_mult, original_timescale, 0.66)
						TheSim:SetTimeScale(lerped_value)
					end)
						target:DoTaskInAnimFrames(deathanimframes, function()
						TheSim:SetTimeScale(original_timescale)
						target.sg.mem.deathstop_timescaling = false
					end)
				end
				if posthitstopsound then
					--sound
					local params = {}
					params.fmodevent = posthitstopsound
					soundutil.PlaySoundData(target, params)
				end
				target:PushEvent("playerfollowhealthbar_hide")
			end)
		-- SEQUENCE TYPE TWO: no delay between impact and hitstop. Still provides "After hitstop" choice.
		else
			--ON IMPACT:
			target.components.hitstopper:PushHitStop(hitstoplevel)
			play_extra_effects(impactsound, snapshot, screenshake, hitoverlay, targetblink)

			-- AFTER HITSTOP:
			target:DoTaskInAnimFrames(hitstoplevel, function()
				play_extra_effects(posthitstopsound, nil, nil, nil, nil)
				stop_extra_effects(snapshot)
			end)
		end
	end

	if data ~= nil and data.projectile ~= nil then
		attacker = data.projectile -- If this was a projectile, hitstop the projectile instead of the attacker themself
	end

	local disable_self_hitstop = data ~= nil and data.disable_self_hitstop or false

	if attacker:IsValid() and attacker.components.hitstopper ~= nil and not disable_self_hitstop then
		if not attacker.sg.statemem.hashitstopped or data ~= nil and data.allow_multiple_on_attacker then
			-- TODO: networking2022, clients won't have this extra effect because they can't confirm
			-- if the room is complete without the host confirming or doing duplicate bookkeeping
			if kill and (TheWorld.components.roomclear == nil or TheWorld.components.roomclear:IsRoomComplete()) and target:HasTag("mob") and attacker:HasTag("player") then
				hitstoplevel = hitstoplevel + TUNING.HITSTOP_LAST_KILL_EXTRA_FRAMES
				attacker.AnimState:SetDeltaTimeMultiplier(TUNING.LAST_KILL_DELTATIME_MULTIPLIER)
				attacker:DoTaskInAnimFrames(TUNING.LAST_KILL_DELTATIME_MULTIPLIER_FRAMES, function()
					if attacker ~= nil and attacker:IsValid() then
						attacker.AnimState:SetDeltaTimeMultiplier(1)
					end
				end)
				TheFrontEnd:GetSound():PlaySound(fmodtable.Event.lastMobKilled)
			end
			attacker.components.hitstopper:PushHitStop(hitstoplevel)
			attacker.sg.statemem.hashitstopped = true
		end
	end

	return hitstoplevel
end

local function DoBlinkAndFadeColor(inst, color, i, numticks)
	if inst:IsValid() then
		dbassert(inst.components.coloradder ~= nil, "Trying to BlinkAndFadeColor on something that doesn't have a coloradder.")
		if i < numticks then
			local r, g, b = table.unpack(color)
			local k = 1 - easing.linear(i, 0, 1, numticks) -- ADJUST CURVE OF FLICKER FADING
			inst.components.coloradder:PushColor("DoBlinkAndFadeColor", r * k, g * k, b * k, 1 * k)
			inst:DoTaskInTicks(2, function() -- fade on 1's
				DoBlinkAndFadeColor(inst, color, i + 1, numticks)
			end)
		else
			inst.components.coloradder:PopColor("DoBlinkAndFadeColor")
		end
	end
end
function SGCommon.Fns.BlinkAndFadeColor(inst, color, numframes)
	DoBlinkAndFadeColor(inst, color, 0, numframes * ANIM_FRAMES)
end

local flicker_piecewise_data =
{
	{0, 0.5},
	{1, 1},
	{2, 0.5},
	{3, 0}
}
local function DoFlickerColor(inst, color, i, numticks, fade, addtweens)
	if inst:IsValid() then
		dbassert(inst.components.coloradder ~= nil, "Trying to FlickerColor on something that doesn't have a coloradder.")
		if i < numticks then
			local r, g, b = table.unpack(color)
			local fadevalue = fade and 1 - easing.linear(i, 0, 1, numticks) or 1 -- ADJUST CURVE OF FLICKER FADING -- or in future, add Curve Editor support
			if addtweens then
				local iterator = i % 4
				local intensity = PiecewiseFn(iterator, flicker_piecewise_data)
				inst.components.coloradder:PushColor("DoFlickerColor", (r * fadevalue)*intensity, (g * fadevalue)*intensity, (b * fadevalue)*intensity, (1 * fadevalue)*intensity)

				inst:DoTaskInTicks(2, function() -- SET THIS NUMBER TO "4" TO FLICKER ON TWO'S
					DoFlickerColor(inst, color, i + 1, numticks, fade, addtweens)
				end)
			else
				if i % 2 == 0 then
					inst.components.coloradder:PushColor("DoFlickerColor", r * fadevalue, g * fadevalue, b * fadevalue, 1 * fadevalue)
				else
					inst.components.coloradder:PushColor("DoFlickerColor", 0, 0, 0, 0)
				end
				inst:DoTaskInTicks(2, function() -- SET THIS NUMBER TO "4" TO FLICKER ON TWO'S
					DoFlickerColor(inst, color, i + 1, numticks, fade, addtweens)
				end)
			end
		else
			inst.components.coloradder:PopColor("DoFlickerColor")
		end
	end
end

function SGCommon.Fns.FlickerColor(inst, color, numflickers, fade, addtweens)
	local numticks = numflickers * 2
	if addtweens then
		numticks = numticks + (numflickers * ANIM_FRAMES)
	end
	if inst:ShouldSendNetEvents() then
		TheNetEvent:FlickerColor(inst.GUID, color, numticks, fade, addtweens)
	else
		DoFlickerColor(inst, color, 0, numticks, fade, addtweens)
	end
end

function SGCommon.Fns.HandleFlickerColor(inst, color, numticks, fade, addtweens)
	assert(inst:IsNetworked())
	DoFlickerColor(inst, color, 0, numticks, fade, addtweens)
end

local function DoFlickerSymbolBloom(inst, symbol, color, i, numticks, fade, addtweens)
	if inst:IsValid() then
		if i < numticks then
			local r, g, b, a = table.unpack(color)
			local fadevalue = fade and 1 - easing.linear(i, 0, 1, numticks) or 1 -- ADJUST CURVE OF FLICKER FADING -- or in future, add Curve Editor support
			if addtweens then
				local iterator = i % 4
				local intensity = PiecewiseFn(iterator, flicker_piecewise_data)
				inst.AnimState:SetSymbolBloom(symbol, (r * fadevalue)*intensity, (g * fadevalue)*intensity, (b * fadevalue)*intensity, (a * fadevalue)*intensity)

				inst:DoTaskInTicks(2, function() -- SET THIS NUMBER TO "4" TO FLICKER ON TWO'S
					DoFlickerSymbolBloom(inst, symbol, color, i + 1, numticks, fade, addtweens)
				end)
			else
				if i % 2 == 0 then
					inst.AnimState:SetSymbolBloom(symbol, r * fadevalue, g * fadevalue, b * fadevalue, a * fadevalue)
				else
					inst.AnimState:SetSymbolBloom(symbol, 0, 0, 0, 0)
				end
				inst:DoTaskInTicks(2, function() -- SET THIS NUMBER TO "4" TO FLICKER ON TWO'S
					DoFlickerSymbolBloom(inst, symbol, color, i + 1, numticks, fade, addtweens)
				end)
			end
		else
			inst.components.coloradder:PopColor("DoFlickerColor")
		end
	end
end

function SGCommon.Fns.FlickerSymbolBloom(inst, symbol, color, numflickers, fade, addtweens)
	local numticks = numflickers * 2
	if addtweens then
		numticks = numticks + (numflickers * ANIM_FRAMES)
	end
	if inst:ShouldSendNetEvents() then
		TheNetEvent:FlickerColor(inst.GUID, color, numticks, fade, addtweens, symbol)
	else
		DoFlickerSymbolBloom(inst, symbol, color, 0, numticks, fade, addtweens) -- multiply by 2/3 because this function counts in ticks, not frames. If we're flickering on two's later, add that as an argument here and propagate it in the function
	end
end

function SGCommon.Fns.HandleFlickerSymbolBloom(inst, symbol, color, numticks, fade, addtweens)
	assert(inst:IsNetworked())
	DoFlickerSymbolBloom(inst, symbol, color, 0, numticks, fade, addtweens)
end

function SGCommon.Fns.DoPotionColorSequence(inst, on_complete_cb)
	local function StillExists(inst)
		return inst ~= nil and inst:IsValid()
	end

	inst:DoTaskInAnimFrames(0, function(inst)
		if inst ~= nil and inst:IsValid() then
			inst.components.coloradder:PushColor("potion", 0, 1 / 25, 0, 0)
		end
	end)
	inst:DoTaskInAnimFrames(1, function(inst)
		if inst ~= nil and inst:IsValid() then
			inst.components.coloradder:PushColor("potion", 0, 4 / 25, 0, 0)
		end
	end)
	inst:DoTaskInAnimFrames(2, function(inst)
		if inst ~= nil and inst:IsValid() then
			inst.components.coloradder:PushColor("potion", 0, 9 / 25, 0, 0)
		end
	end)
	inst:DoTaskInAnimFrames(3, function(inst)
		if inst ~= nil and inst:IsValid() then
			inst.components.coloradder:PushColor("potion", 0, 16 / 25, 0, 0)
		end
	end)
	inst:DoTaskInAnimFrames(4, function(inst)
		if inst ~= nil and inst:IsValid() then
			inst.components.coloradder:PushColor("potion", 0, 1, 0, 0)
			inst.components.bloomer:PushBloom("potion", 1)
			if on_complete_cb then
				on_complete_cb(inst)
			end
		end
	end)
	inst:DoTaskInAnimFrames(6, function(inst)
		if inst ~= nil and inst:IsValid() then
			inst.components.coloradder:PopColor("potion")
			inst.components.bloomer:PopBloom("potion")
		end
	end)
end

-- Ground Impact FX
GroundImpactFXSizes = Enum{
	"Small",
	"Medium",
	"Large"
}

GroundImpactFXTypes = Enum{
	"ParticleSystem",
	"FX",
}

local impact_prefix = {
	[GroundImpactFXTypes.id.ParticleSystem] = "",
	[GroundImpactFXTypes.id.FX] = "fx_",
}
function TileToImpactFx(prefix_id, tile, impact_size)
	local prefix = impact_prefix[prefix_id]
	return string.format("%simpact_%s_%s", prefix, tile, impact_size):lower()
end
function SGCommon.Fns.PlayGroundImpact(inst, param)
	local impactGUID = TheNetEvent:PlayGroundImpact(inst.GUID, param)
	return impactGUID and Ents[impactGUID] or nil
end

function SGCommon.Fns.HandlePlayGroundImpact(inst, param)
	--[[
		- followsymbol = if the impact should be attached to a symbol or not
		- impact_type = what type of impact this is
		- impact_size = small, medium, large
		- inheritrotation = whether or not this impact should inherit the rotation of its parent
		- offx, offz = x,z offsets
		- scalex, scalez - XZ scaling factors
	]]
	local y = 0
	local x, z = inst.Transform:GetWorldXZ()

	if param.followsymbol then
		x, y, z = inst.AnimState:GetSymbolPosition(param.followsymbol, param.offx, 0, param.offz)
	else
		local offdir = inst.Transform:GetFacing() == FACING_LEFT and -1 or 1
		x = x + ((param.offx or 0) * offdir)
		z = z + (param.offz or 0)
	end

	local impact_type = param.impact_type or GroundImpactFXTypes.id.FX

	local tile_at_location
	if TheWorld.zone_grid then
		local _tile
		_tile, tile_at_location = TheWorld.zone_grid:GetTile({x = x, z = z})
	else
		tile_at_location = TheWorld.Map:GetNamedTileAtXZ(x, z)
	end
	local fx_name = TileToImpactFx(
		impact_type,
		tile_at_location,
		GroundImpactFXSizes:FromId(param.impact_size))

	if not PrefabExists(fx_name) then
		-- fall back to a default
		TheLog.ch.Art:printf("Missing FX: %s! Fell back to default FX.", fx_name)
		fx_name = "impact_dirt_small"
		impact_type = GroundImpactFXTypes.id.ParticleSystem
	end

	local testfx = nil
	if impact_type == GroundImpactFXTypes.id.ParticleSystem then
		testfx = ParticleSystemHelper.MakeOneShotAtPosition(Vector3(x, y, z), fx_name)
	else
		-- Animated FX
		testfx = SpawnPrefab(fx_name, inst)
		testfx.AnimState:SetScale(param.scalex or 1, param.scalez or 1)
		testfx.Transform:SetPosition(x, y, z)
	end

	if param.inheritrotation then
		local dir = inst.Transform:GetFacingRotation()
		testfx.Transform:SetRotation(dir)
	end

	return testfx
end

function SGCommon.Fns.TellTemp(inst)
	TheDungeon.HUD:MakePopText({ target = inst, button = "TEMP! :D", color = UICOLORS.WHITE, size = 32, fade_time = .5 })
end

function SGCommon.Fns.PlaySound(inst, eventname)
	if inst.Network then
		TheNetEvent:PlaySound(inst.GUID, eventname)
	else
		inst.SoundEmitter:PlaySound(eventname)
	end
end

--------------------------------------------------------------------------

-- Functions for allowing entities to jump over holes in the middle of the play field.
function SGCommon.Fns.StartJumpingOverHoles(inst)
	inst.Physics:ClearCollidesWith(COLLISION.HOLE_LIMITS)
	local pos = inst:GetPosition()
	inst.sg.mem.lastjumppoint = pos
end

function SGCommon.Fns.StopJumpingOverHoles(inst)
	inst.Physics:CollidesWith(COLLISION.HOLE_LIMITS)
end

--------------------------------------------------------------------------

-- Opening and closing a window that makes scoring a knockback counter-hit during a non-interruptible attack result in a knockdown.
-- Used in yammo, slowpoke.
-- Different than just adding the "vulnerable" tag -- that tag just allows a knockdown hit to connect. This stops nointerrupt + upgrades a knockback into a knockdown
function SGCommon.Fns.StartCounterHitKnockdownWindow(inst)
	assert(inst.sg:HasStateTag("nointerrupt")) -- To make sure we're using this correctly... otherwise, we'll add an erroneous 'nointerrupt' statetag back when closing the window.
	inst.sg:AddStateTag("caninterrupt")
	inst.sg:RemoveStateTag("nointerrupt")
	inst.sg:AddStateTag("vulnerable") --vulnerable means any knockDOWN hits can connect
	inst.sg:AddStateTag("knockback_becomes_knockdown") --this means any knockBACK hits will get upgraded to knockDOWN hits
end

function SGCommon.Fns.StopCounterHitKnockdownWindow(inst)
	inst.sg:RemoveStateTag("caninterrupt")
	inst.sg:RemoveStateTag("vulnerable")
	inst.sg:AddStateTag("nointerrupt")
	inst.sg:RemoveStateTag("knockback_becomes_knockdown")
end

function SGCommon.Fns.StartVulnerableToKnockdownWindow(inst)
	inst.sg:AddStateTag("vulnerable") --vulnerable means any knockDOWN hits can connect
	inst.sg:AddStateTag("knockback_becomes_knockdown") --this means any knockBACK hits will get upgraded to knockDOWN hits
end

function SGCommon.Fns.StopVulnerableToKnockdownWindow(inst)
	inst.sg:RemoveStateTag("vulnerable")
	inst.sg:RemoveStateTag("knockback_becomes_knockdown")
end

function SGCommon.Fns.StartCanBeKnockedBack(inst)
	assert(inst.sg:HasStateTag("nointerrupt")) -- To make sure we're using this correctly... otherwise, we'll add an erroneous 'nointerrupt' statetag back when closing the window.
	inst.sg:AddStateTag("caninterrupt")
end

function SGCommon.Fns.StopCanBeKnockedBack(inst)
	inst.sg:RemoveStateTag("caninterrupt")
end

function SGCommon.Fns.StartCanBeKnockedDown(inst)
	inst.sg:AddStateTag("vulnerable")
end

function SGCommon.Fns.StopCanBeKnockedDown(inst)
	inst.sg:RemoveStateTag("vulnerable")
end

--------------------------------------------------------------------------

-- Use StartTrackingIncomingDamage to open a window to track how much damage is incoming.
-- Once 'threshold' damage is reached, call the function 'cb'.
-- Give it an id to be able to track multiple things at once.
-- Use StopTrackingIncomingDamage(inst, id) to stop tracking that situation.

-- Use case: during a state, a monster wants to cancel into a "get off me!" attack if it has taken enough damage in that state.

local function OnTakeTrackedDamage(inst, attack)
	local damage = attack:GetDamage()

	for id, tbl in pairs(inst.sg.mem.damage_thresholds) do
		tbl.amount = tbl.amount + damage

		if tbl.amount >= tbl.threshold then
			tbl.cb(inst)
			SGCommon.Fns.StopTrackingIncomingDamage(inst, id)
		end
	end
end
function SGCommon.Fns.StartTrackingIncomingDamage(inst, id, threshold, cb)
	assert(id)
	assert(threshold)
	assert(cb)
	if not inst.sg.mem.damage_thresholds then
		inst.sg.mem.damage_thresholds = {}
	end

	if not inst.sg.mem.damage_thresholds[id] then
		inst.sg.mem.damage_thresholds[id] = {}
		inst.sg.mem.damage_thresholds[id].amount = 0
		inst.sg.mem.damage_thresholds[id].threshold = threshold
		inst.sg.mem.damage_thresholds[id].cb = cb
	end

	inst:ListenForEvent("take_damage", OnTakeTrackedDamage)
end

function SGCommon.Fns.StopTrackingIncomingDamage(inst, id)
	inst.sg.mem.damage_thresholds[id] = nil

	if not next(inst.sg.mem.damage_thresholds) then
		inst:RemoveEventCallback("take_damage", OnTakeTrackedDamage)
	end
end

function SGCommon.Fns.CanTakeControlDefault(sg)
	return not sg.inst:HasTag("no_state_transition")
		and (
			sg:HasStateTag("idle")
			-- TODO: networking2022 - victorc, this is currently inconsistent due to how "hit" tags may not align with a state
			-- example: eyev evade sets "hit" tag but is not in a hit state
			or sg:GetCurrentState() == "hit"
			or sg:GetCurrentState() == "hit_pst"
			or sg:GetCurrentState() == "hit_actual"
			or sg:HasStateTag("attack_hold")
			or (not sg:HasStateTag("attack") and not next(sg.statemem))
		)
end

function SGCommon.Fns.ResumeFromRemoteHandleKnockingAttack(sg)
	if sg:GetResumeTakeControlHint() == "knocking_attack"
		and (sg.cantakecontrolbyknockback or sg.cantakecontrolbyknockdown)
		and sg:HasStateTag("vulnerable") then
		-- intentionally resume with a nil state so the vulnerable state tags don't get cleared
		-- and combat can put mob into a knockback/knockdown state
		TheLog.ch.StateGraph:printf("Resuming from remote via knocking attack")
		return nil, true
	end
end

--------------------------------------------------------------------------
strict.strictify(SGCommon.Events, "SGCommon.Events")
strict.strictify(SGCommon.Fns,    "SGCommon.Fns")
strict.strictify(SGCommon.States, "SGCommon.States")


return SGCommon
