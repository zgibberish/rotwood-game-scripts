local Power = require("defs.powers.power")
local lume = require "util.lume"
local SGCommon = require "stategraphs.sg_common"
local monsterutil = require "util.monsterutil"
local audioid = require "defs.sound.audioid"
local fmodtable = require "defs.sound.fmodtable"
local soundutil = require "util.soundutil"
local powerutil = require "util.powerutil"

--local DebugDraw = require "util.debugdraw"

function Power.AddStatusEffectPower(id, data)
	if not data.power_category then
		data.power_category = Power.Categories.SUSTAIN
	end

	if data.clear_on_new_room then
		local previous_trigger = data.event_triggers ~= nil and data.event_triggers["exit_room"] or nil

		if data.event_triggers == nil then
			data.event_triggers = {}
		elseif previous_trigger ~= nil then
			print ("POWER ALREADY HAS AN EXIT ROOM TRIGGER EVENT, ATTEMPTING MERGE")
		end

		data.event_triggers["exit_room"] = function(pow, inst, data)
			if previous_trigger then
				previous_trigger(pow, inst, data)
			end
			inst.components.powermanager:RemovePower(pow.def, true)
		end
	end

	data.power_type = Power.Types.RELIC
	data.show_in_ui = false
	data.can_drop = false

	Power.AddPower(Power.Slots.STATUSEFFECT, id, "statuseffectpowers", data)
end

Power.AddPowerFamily("STATUSEFFECT", nil, 8)

local function PlaySmallifySound(inst)
	local params = {}
	local soundevent = fmodtable.Event.status_smallify_enemy
	if inst:HasTag("player") then
		soundevent = fmodtable.Event.status_smallify_friendly
	end
	params.fmodevent = soundevent
	params.sound_max_count = 3 -- intentional, we mean to track this
	soundutil.PlaySoundData(inst, params)
end

Power.AddStatusEffectPower("smallify",
{
	power_category = Power.Categories.SUPPORT,
	clear_on_new_room = true,

	tuning =
	{
		[Power.Rarity.COMMON] = { scale = 75, speed = 150, damage = 150 },
	},

	on_add_fn = function(pow, inst)
		if inst.components.scalable ~= nil then
			inst.components.scalable:AddScaleModifier(pow, pow.persistdata:GetVar("scale") * 0.01)
		end
		if inst.components.locomotor ~= nil then
			inst.components.locomotor:AddSpeedMult(pow.def.name, pow.persistdata:GetVar("speed") * 0.01)
		end
		inst.components.combat:SetDamageReceivedMult("smallify", pow.persistdata:GetVar("damage") * 0.01)
		PlaySmallifySound(inst)

		if inst.components.weight then
			inst.components.weight:AddWeightAddModifier("smallify", -10)
		end
		inst.SoundEmitter:SetPitchMultiplier(soundutil.PitchMult.id.SizeMushroom, 2)
	end,

	on_remove_fn = function(pow, inst)
		if inst.components.scalable ~= nil then
			inst.components.scalable:RemoveScaleModifier(pow)
		end
		if inst.components.locomotor ~= nil then
			inst.components.locomotor:RemoveSpeedMult(pow.def.name)
		end
		inst.components.combat:SetDamageReceivedMult("smallify", nil)

		if inst.components.weight then
			inst.components.weight:RemoveWeightAddModifier("smallify")
		end

		inst.SoundEmitter:SetPitchMultiplier(soundutil.PitchMult.id.SizeMushroom, 1)
	end,
})

local function RemoveJuggernautStacks(inst, pow)
	local remove_stack

	remove_stack = function(ent)
		ent.components.powermanager:DeltaPowerStacks(pow.def, -1)
		if ent.components.powermanager:GetPowerStacks(pow.def) > 0 then
			ent:DoTaskInTime(0.0667, remove_stack)
		end
	end

	remove_stack(inst)
end

local JUGGERNAUT_SIZE_GAIN_SEQUENCE =
{
	-- How much of the bonus size is added per frame while we transition from OLDSCALE to FINALSCALE
	0.5,
	0.5,
	0,
	0,
	0.5,
	0.5,
	0,
	0,
	0.5,
	0.5,
	0,
	0,
	0.5,
	0.5,
	1,
	1,
	0.5,
	0.5,
	1,
	1,
	1,
	1,
}

local function GetBonusSizeForAnimFrame(originalscale, finalsize, frame)
	return JUGGERNAUT_SIZE_GAIN_SEQUENCE[frame] * (finalsize - originalscale)
end

local function GainJuggernautSequence(inst, originalscale, finalscale, frame, pow)
	if pow.mem.force_remove_requested then
		return
	end

	if frame >= #JUGGERNAUT_SIZE_GAIN_SEQUENCE then
		-- Sequence Complete!
		inst.components.scalable:AddScaleModifier(pow, finalscale, pow)
		inst.SoundEmitter:SetPitchMultiplier(soundutil.PitchMult.id.SizeMushroom, 0.75)
		return
	end

	local bonus_size = GetBonusSizeForAnimFrame(originalscale, finalscale, frame)
	inst.components.scalable:AddScaleModifier(pow, originalscale + bonus_size, pow)

	-- print(frame, originalscale, finalscale, bonus_size)

	frame = frame + 1
	inst:DoTaskInAnimFrames(1, function() GainJuggernautSequence(inst, originalscale, finalscale, frame, pow) end)
end

local function PlayJuggernautSound(inst, pow)
	local params = {}
	local soundevent = fmodtable.Event.fx_heal_burst
	if inst:HasTag("player") then
		soundevent = fmodtable.Event.fx_heal_burst
	end
	params.fmodevent = soundevent
	soundutil.PlaySoundData(inst, params)
end

Power.AddStatusEffectPower("juggernaut",
{
	power_category = Power.Categories.DAMAGE,
	tuning = {
		[Power.Rarity.LEGENDARY] = {
			damage = 1,
			scale = 1,
			damagereceivedmult = 0.5, -- 0.5% per stack -- maximum 100 stacks = 50% damage reduction
			speed = -0.7, -- 0.7% per stack, maximum reduction of -70%
			nointerruptstacks = 50, -- TODO @jambell #weight set this back to 25 or 50
			knockdownstacks = 50,
		},
	},

	stackable = true,
	can_drop = false,
	selectable = false,
	clear_on_new_room = true,
	max_stacks = 100,

	on_add_fn = function(pow, inst)
		if inst.components.weight then
			inst.components.weight:AddWeightAddModifier("juggernaut", 10)
		end
	end,

	on_remove_fn = function(pow, inst)
		if inst.components.scalable ~= nil then
			inst.components.scalable:RemoveScaleModifier(pow)
		end
		inst.components.combat:RemoveDamageDealtMult(pow)
		inst.components.combat:SetDamageReceivedMult("superarmor", nil)

		if inst.components.locomotor then
			inst.components.locomotor:RemoveSpeedMult(pow.def.name)
		end

		if inst.components.weight then
			inst.components.weight:RemoveWeightAddModifier("juggernaut")
		end

		inst.SoundEmitter:SetPitchMultiplier(soundutil.PitchMult.id.SizeMushroom, 1)
	end,

	on_stacks_changed_fn = function(pow, inst, delta)
		-- TODO @jambell #weight figure out how much of this DamageDealt, DamageReceived, and Speed mults is inherent to 'weight', if any?

		if pow.mem.force_remove_requested then
			return
		end

		if inst.components.scalable ~= nil then
			if delta > 0 then
				local originalscale = inst.components.scalable:GetTotalScaleModifier()
				local newscale = 1 + (pow.persistdata.stacks * pow.persistdata:GetVar("scale") * 0.01)
				inst.components.hitstopper:PushHitStop(#JUGGERNAUT_SIZE_GAIN_SEQUENCE) -- Hitstop for an amount of frames it takes to do the whole sequence
				GainJuggernautSequence(inst, originalscale, newscale, 1, pow)
				PlayJuggernautSound(inst, pow)
			else
				inst.components.scalable:AddScaleModifier(pow, 1 + (pow.persistdata.stacks * pow.persistdata:GetVar("scale") * 0.01))
			end
		end
		inst.components.combat:SetDamageDealtMult(pow, 1 + (pow.persistdata.stacks * pow.persistdata:GetVar("damage") * 0.01))

		if inst.components.locomotor then
			inst.components.locomotor:AddSpeedMult(pow.def.name, pow.persistdata.stacks * pow.persistdata:GetVar("speed") * 0.01)
		end

		if inst.components.combat then
			local damage_mult = pow.persistdata.stacks * pow.persistdata:GetVar("damagereceivedmult") * 0.01
			inst.components.combat:SetDamageReceivedMult("superarmor", 1 - damage_mult)
		end
	end,

	damage_mod_fn = function(pow, attack, output_data)
		-- TODO: this doesn't work, because the attack function is already being run at this point. need to find some other way to make juggernaut hits all knock down.
		if pow.persistdata.stacks >= pow.persistdata:GetVar("knockdownstacks") then
			attack:SetIsKnockdown(true)
			attack:SetForceKnockdown(true)
		end
	end,

	remote_event_triggers =
	{
		room_complete = {
			fn = function(pow, inst, source, data)
				RemoveJuggernautStacks(inst, pow)
			end,
			source = function() return TheWorld end,
		},
	},

	event_triggers = {
		["newstate"] = function(pow, inst, data)
			if pow.persistdata.stacks >= pow.persistdata:GetVar("nointerruptstacks") then
				inst.sg:AddStateTag("nointerrupt")
			end
		end,

		["juggernaut_force_remove"] = function(pow, inst)
			pow.mem.force_remove_requested = true
			inst.components.powermanager:RemovePower(pow.def, true)
		end,
	}
})

Power.AddStatusEffectPower("freeze",
{
	power_category = Power.Categories.SUPPORT,
	clear_on_new_room = true,

	tuning =
	{
		[Power.Rarity.COMMON] = { time = 10 },
	},

	on_add_fn = function(pow, inst)
		pow.mem.original_mass = inst.Physics:GetMass()
		pow.mem.original_saturation = inst.AnimState:GetSaturation()

		SGCommon.Fns.SetSaturationOnAllLayers(inst, 0)

		inst.Physics:SetMass(0.1)

		inst:Pause()
		pow:StartPowerTimer(inst)
	end,

	on_remove_fn = function(pow, inst)
		inst.components.timer:StopTimer(pow.def.name)
		inst.Physics:SetMass(pow.mem.original_mass)
		SGCommon.Fns.SetSaturationOnAllLayers(inst,pow.mem.original_saturation)
		inst:Resume()
	end,

	event_triggers = {
		["timerdone"] = function(pow, inst, data)
			if data.name == pow.def.name then
				inst.components.powermanager:RemovePower(pow.def, true)
			end
		end,

		["attacked"] = function (pow, inst, data)
			inst.components.timer:StopTimer(pow.def.name)
			inst.components.powermanager:RemovePower(pow.def, true)
		end,
	}
})

Power.AddStatusEffectPower("poison",
{
	power_category = Power.Categories.DAMAGE,
	clear_on_new_room = true,

	tuning =
	{
		[Power.Rarity.COMMON] = { tick_time = 1, duration = 10, damage = 25 },
	},

	on_add_fn = function(pow, inst)
		pow.mem.tick_time_elapsed  = 0
		pow.mem.total_time_elapsed = 0

		pow.mem.tick_time = pow.persistdata:GetVar("tick_time")
		pow.mem.duration  = pow.persistdata:GetVar("duration")
		pow.mem.damage    = pow.persistdata:GetVar("damage")
	end,

	on_update_fn = function(pow, inst, dt)
		pow.mem.tick_time_elapsed = pow.mem.tick_time_elapsed + dt
		pow.mem.total_time_elapsed = pow.mem.total_time_elapsed + dt

		if pow.mem.tick_time_elapsed > pow.mem.tick_time then
			pow.mem.tick_time_elapsed = 0

			local poison_dmg = Attack(inst, inst)
			poison_dmg:SetDamage(pow.mem.damage)
			poison_dmg:SetIgnoresArmour(true)
			inst.components.combat:ApplyDamage(poison_dmg)
		end

		if pow.mem.total_time_elapsed >= pow.mem.duration then
			inst.components.powermanager:RemovePower(pow.def, true)
		end
	end
})

Power.AddStatusEffectPower("hammer_totem_buff",
{
	power_category = Power.Categories.SUPPORT,
	prefabs = { "impact_dirt_totem" },
	required_tags = { },

	can_drop = false,

	tooltips =
	{
	},

	tuning =
	{
		[Power.Rarity.COMMON] = { damage = 25 },
	},

	damage_mod_fn = function(pow, attack, output_data)
		if attack:GetAttacker() ~= attack:GetTarget() then
			local totem_skill_def = Power.Items.SKILL.hammer_totem

			local damage = (totem_skill_def.tuning.COMMON.bonusdamagepercent * 0.01) * attack:GetDamage()
			output_data.damage_delta = output_data.damage_delta + damage
			return true
		end
	end,

	on_add_fn = function(pow, inst)
		if inst:HasTag("player") then
			powerutil.AttachParticleSystemToSymbol(pow, inst, "extroverted_trail", "swap_fx")
			if inst.sg.mem.totem_snapshot_lp then
				soundutil.SetLocalInstanceParameter(inst, inst.sg.mem.totem_snapshot_lp, "isLocalPlayerInTotem", 1)
				TheAudio:SetGlobalParameter(fmodtable.GlobalParameter.isLocalPlayerInTotem, 1)
			end
		else
			powerutil.AttachParticleSystemToEntity(pow, inst, "extroverted_trail")
		end
	end,

	on_remove_fn = function(pow, inst)
		powerutil.StopAttachedParticleSystem(inst, pow)
		if inst:HasTag("player") and inst.sg.mem.totem_snapshot_lp then
			soundutil.SetLocalInstanceParameter(inst, inst.sg.mem.totem_snapshot_lp, "isLocalPlayerInTotem", 0)
			TheAudio:SetGlobalParameter(fmodtable.GlobalParameter.isLocalPlayerInTotem, 0)
		end
	end,

	event_triggers =
	{
	}
})


local function CONFUSED_target_enemies(pow, inst)
	-- Store the old hitflags in the memory and make them able to attack anything
	pow.mem.old_hitflags = pow.mem.old_hitflags or inst.components.hitbox:GetHitFlags()
	inst.components.hitbox:SetHitFlags(HitGroup.ALL)

	-- Store the old target tags in the memory and clear them out, so we can replace them with Enemies only
	pow.mem.old_targettags = pow.mem.old_targettags or inst.components.combat:GetTargetTags()
	pow.mem.old_friendlytargettags = pow.mem.old_friendlytargettags or inst.components.combat:GetFriendlyTargetTags()
	inst.components.combat:ClearTargetTags()
	inst.components.combat:ClearFriendlyTargetTags()

	-- Add target tags to attack enemies
	inst.components.combat:AddTargetTags(TargetTagGroups.Enemies)
	inst.components.combat:AddFriendlyTargetTags(TargetTagGroups.Players)

	-- Pick a new target with the new target tags
	inst.components.combat:ForceRetarget()
end

local function CONFUSED_reset_targettags(pow, inst)
	inst.components.hitbox:SetHitFlags(pow.mem.old_hitflags)

	-- Clear out the temp target tags we set
	inst.components.combat:ClearTargetTags()
	inst.components.combat:ClearFriendlyTargetTags()

	-- Replace the target tags and friendly target tags with the ones that were there before
	for _,targettag in pairs(pow.mem.old_targettags) do
		inst.components.combat:AddTargetTags( { targettag } ) -- Target tags are in tables, so put the old tag in a table
	end
	for _,friendlytargettag in pairs(pow.mem.old_friendlytargettags) do
		inst.components.combat:AddFriendlyTargetTags({ friendlytargettag } ) -- Target tags are in tables, so put the old tag in a table
	end

	-- Pick a new target with the new target tags
	inst.components.combat:ForceRetarget()
end

local function PlayConfusedSound(inst)
	local params = {}
	local soundevent = fmodtable.Event.status_confused_enemy
	if inst:HasTag("player") then
		soundevent = fmodtable.Event.status_confused_friendly
	end
	params.fmodevent = soundevent
	params.sound_max_count = 3 -- intentional, we mean to track this
	soundutil.PlaySoundData(inst, params, nil, inst)
end

local confused_symbol_anchors =
{
	"head",
	"face",
	"body",
}
Power.AddStatusEffectPower("confused",
{
	--TODO: does not support player minions yet
	power_category = Power.Categories.SUPPORT,
	clear_on_new_room = true,
	prefabs = { "" },
	required_tags = { },

	can_drop = false,
	reset_on_stack = true,

	tooltips =
	{
	},

	tuning =
	{
		[Power.Rarity.COMMON] = { mintime = 8, maxtime = 12 },
	},

	on_add_fn = function(pow, inst)
		if inst:HasTag("player") then
			powerutil.AttachParticleSystemToSymbol(pow, inst, "confused", "head01")
		elseif inst:HasTag("mob") then
			local animstate = inst.AnimState
			for _,symbol in ipairs(confused_symbol_anchors) do
				if animstate:BuildHasSymbol(symbol) then
					powerutil.AttachParticleSystemToSymbol(pow, inst, "confused", symbol)
					break
				end
			end
		end

		PlayConfusedSound(inst)
		pow.persistdata.active = true
		inst:PushEvent("update_power", pow.def)
	end,

	on_remove_fn = function(pow, inst)
		powerutil.StopAttachedParticleSystem(inst, pow)
		if inst:HasTag("player") then
		-- This is all handled in the eventlisteners, but leaving this here in case it's needed for anything.
		elseif inst:HasTag("mob") then
			CONFUSED_reset_targettags(pow, inst)
		end
	end,

	event_triggers = {
		-- TODO(jambell): on controlevent, mirror the player's data.dir if they're using a controller or keyboard-only, but not MKB
		-- TODO(jambell): if Confused happens again, add the new time to the timer? Or reset timer?

		["locomote"] = function(pow, inst, data)
			-- Mirror the player's inputs -- if they press up, replace it with a down. If they press left, replace it with a right.
			if pow.persistdata.active and inst:HasTag("player") then
				if data.dir ~= nil then
					if data.dir >= 0 then
						data.dir = data.dir - 180
					else
						data.dir = data.dir + 180
					end
				end
			end
		end,

		["dodge"] = function(pow, inst, data)
			-- TODO(jambell): fix visible 'turn' before mirrored dodge?

			-- If the player tries to roll left, roll them right instead. Same for up/down.
			if pow.persistdata.active and inst:HasTag("player") then
				local old_rot = inst.Transform:GetRotation()

				local new_rot
				if old_rot >= 0 then
					new_rot = old_rot - 180
				else
					new_rot = old_rot + 180
				end
				inst.Transform:SetRotation(new_rot)
			end
		end,

		["timerdone"] = function(pow, inst, data)
			if data.name == pow.def.name then
				inst.components.powermanager:RemovePower(pow.def, true)
			end
		end,

		["update_power"] = function (pow, inst, data)
			local time = math.random(pow.persistdata:GetVar("mintime"), pow.persistdata:GetVar("maxtime"))
			if inst:HasTag("player") then
				-- This is all handled in the eventlisteners, but leaving this here in case it's needed for anything.
			elseif inst:HasTag("mob") then
				-- More time for confusion for mobs
				time = time * 1.5
				if pow.persistdata.active then
					CONFUSED_target_enemies(pow, inst)
				else
					CONFUSED_reset_targettags(pow, inst)
				end
			end
			inst.components.timer:StartTimer(pow.def.name, time, true)
		end,

		["enter_room"] = function (pow, inst, data)
			inst.components.powermanager:RemovePower(pow.def, true)
		end,
	}
})

local function DoAcidDamage(inst, pow)
	if inst.sg ~= nil and (inst.sg:HasStateTag("flying") or inst.sg:HasStateTag("airborne") or inst.sg:HasStateTag("airborne_high") or inst.sg:HasStateTag("dodge")) then
		return
	elseif inst:HasTag("ACID_IMMUNE") then
	-- This is to prevent acidic monsters in the swamp from taking damage from acid traps and abilities
	-- Ideally this would use the stats of the entities involved and combat system for ignoring attacks marked as acid, which isnt implemented at the time
		return
	end

	local damage = TUNING.TRAPS.trap_acid.BASE_DAMAGE
	if inst:HasTag("mob") or inst:HasTag("boss") then
		damage = damage * TUNING.TRAPS.trap_acid.DAMAGE_TO_MOBS_MULTIPLIER
	end

	-- self damage doesn't cause hit reactions
	local acid_attack = Attack(inst, inst)
	acid_attack:SetDamage(damage)
	-- not sure what the benefit is of using the real source ... is this supposed to be like a projectile?
	-- acid_attack:SetSource(pow.persistdata.realsource)
	acid_attack:SetSource(pow.def.name)
	acid_attack:SetID(pow.def.name)
	acid_attack:SetIgnoresArmour(true)
	inst.components.combat:DoPowerAttack(acid_attack)

	SGCommon.Fns.BlinkAndFadeColor(inst, { 255/255, 50/255, 50/255, 1 }, 8)
end

Power.AddStatusEffectPower("acid",
{
	-- Apply damage over time as long as this power is active.
	-- Ideally appliyed by an aura.
	-- Listens for 'foley_footstep' event and plays a 'footstep step' visual FX

	power_category = Power.Categories.SUPPORT,
	prefabs = { "" },
	required_tags = { },
	has_sources = true,

	tuning =
	{
		-- TUNING in TUNING.TRAPS.trap_acid.BASE_DAMAGE
	},

	can_drop = false,

	tooltips =
	{
	},

	tuning =
	{
		[Power.Rarity.COMMON] = { },
	},

	on_add_fn = function(pow, inst)
		pow.mem.ticksactive = 0
		-- Wait a tick so that the sources can be established
		inst:DoTaskInTicks(1, function(xinst)
			-- If we have a list of possible sources, grab the first one.
			local guid = pow.persistdata.sources and next(pow.persistdata.sources) or nil
			if guid then
				pow.persistdata.realsource = pow.persistdata.sources[guid]
			else
				-- Otherwise, just use the inst
				pow.persistdata.realsource = xinst
			end
			DoAcidDamage(xinst, pow)
		end)
	end,


	on_update_fn = function(pow, inst)
		pow.mem.ticksactive = pow.mem.ticksactive + 1
		if pow.mem.ticksactive >= TUNING.TRAPS.trap_acid.TICKS_BETWEEN_PROCS then
			DoAcidDamage(inst, pow)
			pow.mem.ticksactive = 0
		end
		-- TODO: timeout if not reapplied by auraapplyer?
	end,

	event_triggers = {
		["foley_footstep"] = function(pow, inst, data)
			SGCommon.Fns.SpawnAtDist(inst, "fx_acid_footstep", 0)
		end,
	}
})

Power.AddStatusEffectPower("bodydamage",
{
	-- Applies a hitbox on the entity that does damage
	power_category = Power.Categories.DAMAGE,

	tuning =
	{
		[Power.Rarity.COMMON] = { move_speed_modifier = 0.5, speed = 6, swallow_point_offset = {2.5, 0, -1}, swallow_distance = 2 },
	},

	on_add_fn = function(pow, inst)
		inst.components.hitbox:StartRepeatTargetDelay()
	end,

	event_triggers = {
		["hitboxtriggered"] = function(pow, inst, data)
			SGCommon.Events.OnHitboxTriggered(inst, data, {
				attackdata_id = "bite",
				hitstoplevel = HitStopLevel.MEDIUM,
				pushback = 0.4,
				hitflags = Attack.HitFlags.LOW_ATTACK,
				combat_attack_fn = "DoKnockbackAttack",
				hit_fx = monsterutil.defaultAttackHitFX,
				hit_fx_offset_x = 0.5,
				reduce_friendly_fire = true,
			})
		end,
	},

	on_update_fn = function(pow, inst, dt)
		local size = inst.Physics:GetSize() + 0.1
		inst.components.hitbox:PushBeam(-size, size, size * 1.5, HitPriority.MOB_DEFAULT)
	end,

	on_remove_fn = function(pow, inst)
		inst.components.hitbox:StopRepeatTargetDelay()
	end,
})

Power.AddStatusEffectPower("vulnerable",
{
	-- take extra damage, 1% per stack
	power_category = Power.Categories.DAMAGE,
	stackable = true,
	max_stacks = 100,
	tuning =
	{
		[Power.Rarity.COMMON] = {
			damage = StackingVariable(1):SetPercentage(),
		},
	},

	defend_mod_fn = function(pow, attack, output_data)
		local damage_bonus = attack:GetDamage() * pow.persistdata:GetVar("damage")
		output_data.damage_delta = damage_bonus
		return true
	end,
})

local slowed_stacks_to_speedmult =
{
	{ 0 , 0 },
	{ 25 , -50 },
	{ 50 , -70 },
	{ 75 , -90 },
	{ 100 , -100 },
}

local function UpdateSlowedVisuals(inst, stacks, pow)
	if inst.components.bloomer ~= nil then
		-- Fully applied should be rgb 100, 80, 140

		-- Don't lerp to fully clear (255),  because we should see a clear pop when we become "nothing"
		local r = lume.lerp(100, 200, 1-stacks/100)
		local g = lume.lerp(80, 200, 1-stacks/100)
		local b = lume.lerp(140, 200, 1-stacks/100)
		inst.components.colormultiplier:PushColor("slowed", r/255, g/255, b/255, 1)

		pow.mem.emitter1:SetEmitRateMult(stacks/100)
		pow.mem.emitter2:SetEmitRateMult(stacks/100)
	end
end

Power.AddSeedPower("slowed",
{
	prefabs =
	{
		"sticky",
	},
	tuning = {
		[Power.Rarity.COMMON] = { stacksonlocomote = -1, stacksonattack_mob = -25, stacksonattack_player = -10, stacksondodge = -25, stackedonattacked = -10 }, -- TODO #seed might need to be different for player -- -stacksonlocomote 0.5, stacksonattack -10
	},

	stackable = true,
	max_stacks = 100, 	-- 50%, 50%, 75%, 100%
	show_in_ui = false,
	can_drop = false,
	selectable = false,

	get_counter_text = powerutil.GetCounterTextPercent,

	on_add_fn = function(pow, inst)
		pow.persistdata.counter = 0
		pow.persistdata.stacks = 1

		local pfx = SpawnPrefab("sticky", inst)
		pfx.entity:SetParent(inst.ent)
		pfx.entity:AddFollower()
		pfx.entity:SetParent(inst.entity)
		pow.mem.pfx = pfx
		pow.mem.emitter1 = pfx.components.particlesystem:GetEmitter(1)
		pow.mem.emitter2 = pfx.components.particlesystem:GetEmitter(2)

		inst:PushEvent("update_power", pow.def)

		pow.mem.isplayer = inst:HasTag("player")
		if pow.mem.isplayer then
			pow.mem.locomotetoggle = true -- Only update every second 'locomote' event for player
		end

		if inst.components.locomotor ~= nil then
			if pow.persistdata.stacks > 0 then
				local speedmult = PiecewiseFn(pow.persistdata.stacks or 1, slowed_stacks_to_speedmult)
				inst.components.locomotor:AddSpeedMult(pow.def.name, speedmult * 0.01)
			else
				inst.components.locomotor:RemoveSpeedMult(pow.def.name)
			end
		end
	end,

	on_stacks_changed_fn = function(pow, inst)
		pow.persistdata.counter = pow.persistdata.stacks
		inst:PushEvent("update_power", pow.def)

		if inst.components.locomotor ~= nil then
			if pow.persistdata.stacks > 0 then
				local speedmult = PiecewiseFn(pow.persistdata.stacks or 1, slowed_stacks_to_speedmult)
				inst.components.locomotor:AddSpeedMult(pow.def.name, speedmult * 0.01)
			else
				inst.components.locomotor:RemoveSpeedMult(pow.def.name)
			end
		end
	end,

	on_remove_fn = function(pow, inst)
		if inst.components.locomotor ~= nil then
			inst.components.locomotor:RemoveSpeedMult(pow.def.name)
		end
		inst.components.colormultiplier:PopColor("slowed")
		if pow.mem.pfx ~= nil and pow.mem.pfx:IsValid() then
			pow.mem.pfx.components.particlesystem:StopThenRemoveEntity()
		end
	end,

	event_triggers =
	{
		["enter_room"] = function(pow, inst, data)
			-- update the UI to show percentage
			inst.components.powermanager:SetPowerStacks(pow.def, 0)
		end,

		["update_power"] = function(pow, inst)
			UpdateSlowedVisuals(inst, pow.persistdata.stacks or 1, pow)
		end,

		["locomote"] = function(pow, inst)
			if pow.mem.isplayer then
				pow.mem.locomotetoggle = not pow.mem.locomotetoggle
				if not pow.mem.locomotetoggle then
					return
				end
			end

			inst.components.powermanager:DeltaPowerStacks(pow.def, pow.persistdata:GetVar("stacksonlocomote"))
		end,

		["completeactiveattack"] = function(pow, inst)
			if not pow.mem.isplayer then
				inst.components.powermanager:DeltaPowerStacks(pow.def, pow.persistdata:GetVar("stacksonattack_mob"))
			end
		end,

		["attack_start"] = function(pow, inst)
			if pow.mem.isplayer then
				inst.components.powermanager:DeltaPowerStacks(pow.def, pow.persistdata:GetVar("stacksonattack_player"))
			end
		end,

		["dodge"] = function(pow, inst)
			inst.components.powermanager:DeltaPowerStacks(pow.def, pow.persistdata:GetVar("stacksondodge"))
		end,

		-- ["attacked"] = function(pow, inst)
		-- 	inst.components.powermanager:DeltaPowerStacks(pow.def, pow.persistdata:GetVar("stackedonattacked"))
		-- end,
	},
})

Power.AddSeedPower("armoured",
{
	prefabs =
	{
	},
	tuning = {
		[Power.Rarity.COMMON] = { amount = 500 },
	},

	show_in_ui = false,
	can_drop = false,
	selectable = false,

	on_add_fn = function(pow, inst)
		inst:AddComponent("shield")
		inst.components.shield:SetMax(500)
		inst.components.shield:SetCurrent(500, true)
	end,

	on_remove_fn = function(pow, inst)
		inst:RemoveComponent("shield")
	end,

	event_triggers =
	{
	},
})
