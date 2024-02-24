local Power = require("defs.powers.power")
local lume = require "util.lume"
local SGCommon = require "stategraphs.sg_common"
local easing = require "util.easing"
local ParticleSystemHelper = require "util.particlesystemhelper"
local powerutil = require "util.powerutil"

Power.AddPowerFamily("SHIELD", nil, 8)

function Power.AddShieldPower(id, data)
	if not data.power_category then
		data.power_category = Power.Categories.SUSTAIN
	end

	data.power_type = Power.Types.FABLED_RELIC

	Power.AddPower(Power.Slots.SHIELD, id, "shield_powers", data)
end

function Power.AddShieldPlayerPower(id, data)
	if not data.required_tags then
		data.required_tags = { POWER_TAGS.PROVIDES_SHIELD }
	else
		if not lume.find(data.required_tags, POWER_TAGS.PROVIDES_SHIELD) then
			table.insert(data.required_tags, POWER_TAGS.PROVIDES_SHIELD)
		end
	end

	if not data.power_category then
		data.power_category = Power.Categories.SUSTAIN
	end

	data.power_type = Power.Types.RELIC

	Power.AddPower(Power.Slots.SHIELD, id, "shield_powers", data)
end

local function DeltaShield(inst, delta)
	local shield_def = Power.Items.SHIELD.shield
	local pm = inst.components.powermanager
	local shield = pm:GetPower(shield_def)

	if shield then
		pm:DeltaPowerStacks(shield_def, delta)
	elseif not shield and delta > 0 then
		pm:AddPower(pm:CreatePower(shield_def), delta)
	end
end

local function GetCurrentShieldCount(inst)
	local shield_def = Power.Items.SHIELD.shield
	local pm = inst.components.powermanager
	return pm:GetPowerStacks(shield_def)
end

local function HasFullShield(inst)
	local shield_def = Power.Items.SHIELD.shield
	local stacks = GetCurrentShieldCount(inst)
	return stacks >= shield_def.max_stacks
end

-- Shield Base Powers --
Power.AddShieldPower("shield_heavy_attack",
{
	tags = { POWER_TAGS.PROVIDES_SHIELD, POWER_TAGS.PROVIDES_SHIELD_SEGMENTS },
	tuning = {
		[Power.Rarity.LEGENDARY] = { targets_required = 2, shield = 1 },
	},
	tooltips =
	{
		"SHIELD_SEGMENTS",
		"SHIELD",
		"HEAVY_ATTACK",
	},
	event_triggers =
	{
		["heavy_attack"] = function(pow, inst, data)
			if #data.targets_hit >= pow.persistdata:GetVar("targets_required") then
				DeltaShield(inst, pow.persistdata:GetVar("shield"))
				inst:PushEvent("used_power", pow.def)
			end
		end,
	}
})

Power.AddShieldPower("shield_focus_kill",
{
	tags = { POWER_TAGS.PROVIDES_SHIELD, POWER_TAGS.PROVIDES_SHIELD_SEGMENTS },
	tuning = {
		[Power.Rarity.LEGENDARY] = { shield = 1 },
	},
	tooltips =
	{
		"SHIELD_SEGMENTS",
		"SHIELD",
		"FOCUS_HIT",
	},
	event_triggers =
	{
		["kill"] = function(pow, inst, data)
			if data.attack:GetFocus() then
				DeltaShield(inst, pow.persistdata:GetVar("shield"))
				inst:PushEvent("used_power", pow.def)
			end
		end,
	}
})

Power.AddShieldPower("shield_dodge",
{
	tags = { POWER_TAGS.PROVIDES_SHIELD, POWER_TAGS.PROVIDES_SHIELD_SEGMENTS },
	tuning = {
		[Power.Rarity.LEGENDARY] = { shield = 2 },
	},
	tooltips =
	{
		"SHIELD_SEGMENTS",
		"SHIELD",
		"IFRAME_DODGE",
	},
	event_triggers =
	{
		["hitboxcollided_invincible"] = function(pow, inst, data)
			if inst.sg:HasStateTag("dodge") then
				DeltaShield(inst, pow.persistdata:GetVar("shield"))
				inst:PushEvent("used_power", pow.def)
			end
		end,
	}
})

Power.AddShieldPower("shield_hit_streak",
{
	tags = { POWER_TAGS.PROVIDES_SHIELD, POWER_TAGS.PROVIDES_SHIELD_SEGMENTS, POWER_TAGS.USES_HITSTREAK },
	tuning = {
		[Power.Rarity.LEGENDARY] = { shield = 1, hitstreak = 10 }, -- jambell: playtesting w/ hammer: 5 seems too easy, 7 seems too hard. 6 seems just right!
	},
	tooltips =
	{
		"HIT_STREAK",
		"SHIELD_SEGMENTS",
		"SHIELD",
	},
	event_triggers =
	{
		["hitstreak"] = function(pow, inst, data)
			if not inst:IsLocal() then
				return
			end
			local hitstreak = inst.components.combat:GetHitStreak()
			if hitstreak ~= 0 and hitstreak % pow.persistdata:GetVar("hitstreak") == 0 then
				DeltaShield(inst, pow.persistdata:GetVar("shield"))
			end
		end,
	}
})

Power.AddShieldPower("shield_when_hurt",
{
	can_drop = false,
	tags = { POWER_TAGS.PROVIDES_SHIELD, POWER_TAGS.PROVIDES_SHIELD_SEGMENTS },
	tuning = {
		[Power.Rarity.LEGENDARY] = { shield = 1 },
	},
	tooltips =
	{
		"SHIELD_SEGMENTS",
		"SHIELD",
	},
	event_triggers =
	{
		["healthchanged"] = function(pow, inst, data)
			if data.hurt then
				pow.persistdata.counter = 1
				DeltaShield(inst, pow.persistdata:GetVar("shield"))
			end
		end,
	}
})

-- Shield Player Powers --
local shield_on_coloradd = { 0/255, 50/255, 100/255 }
local shield_on_colormult = { 200/255, 255/255, 255/255 }
local shield_off_coloradd = { 0/255, 0/255, 0/255 }
local shield_off_colormult = { 255/255, 255/255, 255/255 }

Power.AddShieldPlayerPower("shield",
{
	power_category = Power.Categories.SUSTAIN,
	prefabs = { "shield_acquire_groundring_frnt", "shield_acquire_groundring_back" },
	tuning = {
		[Power.Rarity.LEGENDARY] = { damage = 1 },
	},
	tags = { POWER_TAGS.SHIELD },
	stackable = true,
	permanent = true,
	max_stacks = 4,
	can_drop = false,
	show_in_ui = false,
	selectable = false,

	on_add_fn = function(pow, inst)
		pow.mem.current_coloradd = { 0, 0, 0 }
		pow.mem.current_colormult = { 1, 1, 1 }
		pow.mem.color_pulse_queue = {}
	end,

	defend_mod_fn = function(pow, attack, output_data)
		local stacks = pow.persistdata.stacks or 0
		if stacks == pow.def.max_stacks and attack:GetDamage() > 1 and not attack:GetIgnoresShield() then
			if pow.mem and pow.mem.pending_break then
				return
			end

			local damage_prevented = (attack:GetDamage() - pow.persistdata:GetVar("damage"))
			output_data.damage_delta = -damage_prevented

			pow.mem.pending_break = { damage_prevented = damage_prevented, attacker = attack:GetAttacker() }
			return true
		end
	end,

	on_update_fn = function(pow, inst, dt)
		if #pow.mem.color_pulse_queue > 0 then
			if pow.mem.target_coloradd == nil then
				pow.mem.target_coloradd = pow.mem.color_pulse_queue[1] == "on" and shield_on_coloradd or shield_off_coloradd
			end
			if pow.mem.target_colormult == nil then
				pow.mem.target_colormult = pow.mem.color_pulse_queue[1] == "on" and shield_on_colormult or shield_off_colormult
			end
			local PULSE_LENGTH = pow.mem.pulse_length

			pow.mem.updating_color_time = (pow.mem.updating_color_time or 0) + dt
			local t = pow.mem.updating_color_time

			-- Color Add
			local add_r = easing.linear(t, pow.mem.current_coloradd[1], pow.mem.target_coloradd[1] - (pow.mem.current_coloradd[1]), PULSE_LENGTH)
			local add_g = easing.linear(t, pow.mem.current_coloradd[2], pow.mem.target_coloradd[2] - (pow.mem.current_coloradd[2]), PULSE_LENGTH)
			local add_b = easing.linear(t, pow.mem.current_coloradd[3], pow.mem.target_coloradd[3] - (pow.mem.current_coloradd[3]), PULSE_LENGTH)
			pow.mem.current_coloradd[1] = add_r
			pow.mem.current_coloradd[2] = add_g
			pow.mem.current_coloradd[3] = add_b
			inst.components.coloradder:PushColor("shield", add_r, add_g, add_b, 0)

			-- Color Mult
			local mult_r = easing.linear(t, pow.mem.current_colormult[1], pow.mem.target_colormult[1] - (pow.mem.current_colormult[1]), PULSE_LENGTH)
			local mult_g = easing.linear(t, pow.mem.current_colormult[2], pow.mem.target_colormult[2] - (pow.mem.current_colormult[2]), PULSE_LENGTH)
			local mult_b = easing.linear(t, pow.mem.current_colormult[3], pow.mem.target_colormult[3] - (pow.mem.current_colormult[3]), PULSE_LENGTH)
			pow.mem.current_colormult[1] = mult_r
			pow.mem.current_colormult[2] = mult_g
			pow.mem.current_colormult[3] = mult_b
			inst.components.colormultiplier:PushColor("shield", mult_r, mult_g, mult_b, 1)

			if pow.mem.updating_color_time >= PULSE_LENGTH then
				pow.mem.updating_color_time = nil
				pow.mem.target_coloradd = nil
				pow.mem.target_colormult = nil
				table.remove(pow.mem.color_pulse_queue, 1)
				if pow.mem.pulse_off and #pow.mem.color_pulse_queue == 0 then
					table.insert(pow.mem.color_pulse_queue, "off")
					pow.mem.pulse_off = false
				end
			end
		end
	end,

	on_remove_fn = function(pow, inst)
		inst.components.colormultiplier:PopColor("shield")
		inst.components.coloradder:PopColor("shield")
	end,

	event_triggers =
	{

		["take_damage"] = function(pow, inst, attack)
			if pow.mem.pending_break and attack:GetAttacker() == pow.mem.pending_break.attacker then
				local damage_prevented = pow.mem.pending_break.damage_prevented
				inst:PushEvent("consume_shield", damage_prevented)
				DeltaShield(inst, -pow.persistdata.stacks)

				pow.mem.pending_break = nil
			end
		end,

		["power_stacks_changed"] = function(pow, inst, data)
			if data.pow ~= pow then return end

			if data.new == pow.def.max_stacks then
				-- Play one-shot FX
				powerutil.SpawnFxOnEntity("shield_acquire_groundring_frnt", inst, { ischild = true} )

				powerutil.SpawnFxOnEntity("shield_acquire_groundring_back", inst, { ischild = true} )

				-- Tint the body
				pow.mem.color_pulse_queue = {}
				pow.mem.pulse_off = false
				table.insert(pow.mem.color_pulse_queue, "on")
				pow.mem.pulse_length = 1

			elseif data.new > data.old then
				local fx_prefab = "shield_acquire_charge"..data.new
				powerutil.SpawnFxOnEntity(fx_prefab, inst, { ischild = true} )
				table.insert(pow.mem.color_pulse_queue, "on")
				pow.mem.pulse_off = true
				pow.mem.pulse_length = 0.25
			end
		end,

		["enter_room"] = function(pow, inst, data)
			if HasFullShield(inst) then
				inst.components.coloradder:PushColor("shield", shield_on_coloradd[1], shield_on_coloradd[2], shield_on_coloradd[3], 0)
				inst.components.colormultiplier:PushColor("shield", shield_on_colormult[1], shield_on_colormult[2], shield_on_colormult[3], 1)
			end
		end,

		["consume_shield"] = function(pow, inst, data)
			-- Play burst particles
			powerutil.SpawnParticlesAtPosition(inst:GetPosition(), "shield_break_burst", 1, inst)

			-- Tint character body back to normal
			table.insert(pow.mem.color_pulse_queue, "off")
			pow.mem.pulse_length = 0.5
		end,

		["shield_force_break"] = function(pow, inst)
			pow.mem.pending_break = true
			inst:PushEvent("consume_shield", 0)
			DeltaShield(inst, -pow.persistdata.stacks)

			pow.mem.pending_break = nil
		end,
	}
})

Power.AddShieldPlayerPower("shield_heavy_attack_bonus_damage",
{
	power_category = Power.Categories.DAMAGE,
	tuning = {
		[Power.Rarity.COMMON] = { percent = 50 },
		[Power.Rarity.EPIC] = { percent = 75 },
		[Power.Rarity.LEGENDARY] = { percent = 100 },
	},
	tooltips =
	{
		"SHIELD",
		"HEAVY_ATTACK",
	},
	damage_mod_fn = function(pow, attack, output_data)
		local attacker = attack:GetAttacker()
		if attack:IsHeavyAttack() and HasFullShield(attacker) then
			local bonus_percent = pow.persistdata:GetVar("percent") * 0.01
			local bonus_damage = attack:GetDamage() * bonus_percent
			output_data.damage_delta = output_data.damage_delta + bonus_damage
			return true
		end
	end,
})

-- When you reach full shield, CONSUME it and give yourself a buff that prevents 50% damage for 15 seconds.
-- Power.AddShieldPower("shield_damage_debuff",
-- {

-- })

local function OnDodgeHitBoxTriggered(pow, inst, data)
	if pow.mem.attacking then
		local hitstun = 3
		for i = 1, #data.targets do
			local v = data.targets[i]
			local attack = Attack(inst, v)
			attack:SetDamageMod(pow.persistdata:GetVar("damage_mod") * 0.01)
			local dir = inst:GetAngleTo(v)
			attack:SetDir(dir)
			attack:SetHitstunAnimFrames(hitstun)
			attack:SetFocus(false)
			attack:SetPushback(2)
			attack:SetID(pow.def.name)
			inst.components.combat:DoKnockbackAttack(attack)
		end
	end
end

local function ConvertRotationToRoughDirection(inst)
	local rot = inst.Transform:GetRotation()
	local dir
	--[[
			-90
		-135	-45
	-180 			0
		 135	 45
			 90
	]]

	if rot > 45 and rot < 135 then
		dir = "DOWN"
	elseif rot < -45 and rot > -135 then
		dir = "UP"
	else
		dir = "FORWARD"
	end

	return dir
end

-- When you have full shield, your DODGES knock enemies back.
Power.AddShieldPlayerPower("shield_dodge_knockback",
{
	power_category = Power.Categories.DAMAGE,
	tags = { POWER_TAGS.ROLL_BECOMES_ATTACK },
	exclusive_tags = { POWER_TAGS.ROLL_BECOMES_ATTACK },
	tuning = {
		[Power.Rarity.EPIC] = { damage_mod = 50, fx_name = "fx_player_roll_damage_shield", },
		[Power.Rarity.LEGENDARY] = { damage_mod = 100, fx_name = "fx_player_roll_damage_shield", },
	},
	tooltips =
	{
		"SHIELD",
	},

	on_update_fn = function(pow, inst, dt)
		if pow.mem.attacking then

			local animframe = inst.sg:GetAnimFramesInState()
			local statename = inst.sg:GetCurrentState()

			-- Only attack a few frames into the state, and only attack for one frame.
			-- Wait until the roll has momentum before actually pushing back, so we don't pushback on frame 1 before we've even moved.

			if animframe >= 2 and statename == "roll_loop" then
				local dir = ConvertRotationToRoughDirection(inst)
				local fx_name = pow.persistdata:GetVar("fx_name")
				if not pow.mem.spawned_fx then
					local params =
					{
						ischild = true,
						inheritrotation = true,
					}
					powerutil.SpawnFxOnEntity(fx_name, inst, params)
					pow.mem.spawned_fx = true
				end

				-- Only push a hitbox in front of the player, so that stuff behind us doesn't get pushed back.

				if dir == "FORWARD" then
					inst.components.hitbox:PushBeam(1, 1.5, 0.50, HitPriority.PLAYER_DEFAULT)
				elseif dir == "UP" then
					inst.components.hitbox:PushOffsetBeam(-0.5, 0.5, 0.5, 1.5, HitPriority.PLAYER_DEFAULT)
				elseif dir == "DOWN" then
					inst.components.hitbox:PushOffsetBeam(-0.5, 0.5, 0.5, -1.5, HitPriority.PLAYER_DEFAULT)
				end
			end
		end
	end,

	event_triggers =
	{
		["hitboxtriggered"] = OnDodgeHitBoxTriggered,

		["newstate"] = function(pow, inst, data)
			if HasFullShield(inst) and inst.sg:HasStateTag("dodge") then
				inst.components.hitbox:StartRepeatTargetDelayAnimFrames(20)
				pow.mem.attacking = true
			else
				if pow.mem.attacking then
					local fx_name = pow.persistdata:GetVar("fx_name")
					pow.mem.attacking = false
					inst.components.hitbox:StopRepeatTargetDelay()

					if pow.mem[fx_name] ~= nil and pow.mem[fx_name]:IsValid() then
						pow.mem[fx_name]:Remove()
					end
					pow.mem[fx_name] = nil
				end
			end
		end,

		["dodge"] = function(pow, inst, data)
			pow.mem.spawned_fx = false
		end,
	}
})

-- Move 5% faster for every shield segment that you have.
Power.AddShieldPlayerPower("shield_move_speed_bonus",
{
	power_category = Power.Categories.SUPPORT,
	tuning = {
		[Power.Rarity.COMMON] = { speed = 7.5 },
		[Power.Rarity.EPIC] = { speed = 15 },
		[Power.Rarity.LEGENDARY] = { speed = 25 },
	},
	can_drop = false,
	tooltips =
	{
		"SHIELD_SEGMENTS",
	},
	event_triggers =
	{
		["power_stacks_changed"] = function(pow, inst, data)
			local shield_def = Power.Items.SHIELD.shield
			if data.pow.def == shield_def then
				if data.new > 0 then
					inst.components.locomotor:AddSpeedMult(pow.def.name, (pow.persistdata:GetVar("speed") * 0.01) * data.new)
				else
					inst.components.locomotor:RemoveSpeedMult(pow.def.name)
				end
			end
		end,
	}
})

Power.AddShieldPlayerPower("shield_explosion_on_break",
{
	power_category = Power.Categories.DAMAGE,
	tuning = {
		[Power.Rarity.LEGENDARY] = { damage = 500, radius = 10 },
	},
	tooltips =
	{
		"SHIELD",
	},
	prefabs = { "bomb_explosion", "hits_bomb" },
	event_triggers =
	{
		["power_stacks_changed"] = function(pow, inst, data)
			local shield_def = Power.Items.SHIELD.shield
			if data.pow.def == shield_def and data.old == shield_def.max_stacks and data.new == 0 then
				local x,z = inst.Transform:GetWorldXZ()
				local ents = FindEnemiesInRange(x, z, pow.persistdata:GetVar("radius"))

				for i, ent in ipairs(ents) do
					inst:DoTaskInAnimFrames(math.random(1, 5), function()
						if ent:IsValid() then
							local power_attack = Attack(inst, ent)
							power_attack:SetDamage(pow.persistdata:GetVar("damage"))
							power_attack:SetHitstunAnimFrames(10)
							power_attack:SetPushback(2)
							power_attack:SetSource(pow.def.name)
							-- TODO: add hitstop to the attack
							inst.components.combat:DoPowerAttack(power_attack)
							-- do I need to copy the chain from the last attack?
							powerutil.SpawnPowerHitFx("hits_bomb", inst, ent, 0, 0, HitStopLevel.HEAVY)
						end
					end)
				end

				local params =
				{
					scalex = 0.5,
					scalez = 0.5,
				}
				powerutil.SpawnFxOnEntity("bomb_explosion", inst, params)
				inst:PushEvent("used_power", pow.def)
			end
		end,
	},
})

Power.AddShieldPlayerPower("shield_to_health",
{
	power_category = Power.Categories.SUSTAIN,
	tuning = {
		[Power.Rarity.EPIC] = { amount = 0.5, },
		[Power.Rarity.LEGENDARY] = { amount = 1, },
	},
	tooltips =
	{
		"SHIELD",
	},
	event_triggers =
	{
		["consume_shield"] = function(pow, inst, data)
			if data >= 1 then
				local heal = Attack(inst, inst)
				heal:SetHeal(data * pow.persistdata:GetVar("amount"))
				heal:SetSource(pow.def.name)
				inst.components.combat:ApplyHeal(heal)
				inst:PushEvent("used_power", pow.def)
			end
		end,
	}
})

Power.AddShieldPlayerPower("shield_steadfast",
{
	power_category = Power.Categories.SUPPORT,
	tuning = {
		[Power.Rarity.EPIC] = { segments_required = 4, },
		[Power.Rarity.LEGENDARY] = { segments_required = 0, },
	},
	tooltips =
	{
		"SHIELD",
	},
	event_triggers =
	{
		["newstate"] = function(pow, inst, data)
			if GetCurrentShieldCount(inst) >= pow.persistdata:GetVar("segments_required") and inst.sg:HasStateTag("attack") then
				inst.sg:AddStateTag("nointerrupt")
			end
		end,
	}
})

-- ??: When your shield breaks, knock back all surrounding enemies
Power.AddShieldPlayerPower("shield_knockback_on_break",
{
	power_category = Power.Categories.SUPPORT,
	tuning = {
		[Power.Rarity.EPIC] = { damage = 0, radius = 10 },
		[Power.Rarity.LEGENDARY] = { damage = 0, radius = 15 },
	},
	tooltips =
	{
		"SHIELD",
	},
	prefabs = { "bomb_explosion", "hits_bomb" },
	event_triggers =
	{
		["power_stacks_changed"] = function(pow, inst, data)
			local shield_def = Power.Items.SHIELD.shield
			if data.pow.def == shield_def and data.old == shield_def.max_stacks and data.new == 0 then
				local x,z = inst.Transform:GetWorldXZ()
				local ents = FindEnemiesInRange(x, z, pow.persistdata:GetVar("radius"))

				for i, ent in ipairs(ents) do
					inst:DoTaskInAnimFrames(math.random(1, 5), function()
						if ent:IsValid() then
							local power_attack = Attack(inst, ent)
							power_attack:SetDamage(pow.persistdata:GetVar("damage"))
							power_attack:SetHitstunAnimFrames(10)
							power_attack:SetPushback(2)
							power_attack:SetSource(pow.def.name)
							inst.components.combat:DoKnockbackAttack(power_attack)
							-- do I need to copy the chain from the last attack?
							powerutil.SpawnPowerHitFx("hits_bomb", inst, ent, 0, 0, HitStopLevel.HEAVY)
						end
					end)
				end

				local params =
				{
					scalex = 0.5,
					scalez = 0.5,
				}
				powerutil.SpawnFxOnEntity("bomb_explosion", inst, params)
				inst:PushEvent("used_power", pow.def)
			end
		end,
	},
})


--[[
-- Power.AddShieldPlayerPower("shield_reduced_damage_on_break",
-- {
-- 	tuning = {
-- 		[Power.Rarity.COMMON] = { percent = 50, time = 10 },
-- 	},
-- 	event_triggers =
-- 	{
-- 		["shieldremoved"] = function(pow, inst, data)
-- 			inst.components.timer:StartTimer(pow.def.name, pow.persistdata:GetVar("time"))
-- 		end,
-- 	},
-- 	defend_mod_fn = function(pow, attack, output_data)
-- 		local target = attack:GetTarget()
-- 		if target.components.timer:HasTimer(pow.def.name) then
-- 			local damage = attack:GetDamage()
-- 			local reduction = damage * (pow.persistdata:GetVar("percent") * 0.01)
-- 			output_data.damage_delta = output_data.damage_delta - reduction
-- 			return true
-- 		end
-- 	end,
-- })

-- Power.AddShieldPlayerPower("shield_bonus_damage_on_break",
-- {
-- 	tuning = {
-- 		[Power.Rarity.COMMON] = { percent = 50, time = 10 },
-- 	},
-- 	event_triggers =
-- 	{
-- 		["shieldremoved"] = function(pow, inst, data)
-- 			inst.components.timer:StartTimer(pow.def.name, pow.persistdata:GetVar("time"))
-- 		end,
-- 	},

-- 	damage_mod_fn = function(pow, attack, output_data)
-- 		local attacker = attack:GetAttacker()
-- 		if attacker.components.timer:HasTimer(pow.def.name) then
-- 			local damage = attack:GetDamage()
-- 			local bonus = damage * (pow.persistdata:GetVar("percent") * 0.01)
-- 			output_data.damage_delta = output_data.damage_delta + bonus
-- 			return true
-- 		end
-- 	end,
-- })

-- Power.AddShieldPlayerPower("shield_move_speed_on_break",
-- {
-- 	tuning = {
-- 		[Power.Rarity.COMMON] = { percent = 50, time = 10 },
-- 	},
-- 	event_triggers =
-- 	{
-- 		["shieldremoved"] = function(pow, inst, data)
-- 			inst.components.timer:StartTimer(pow.def.name, pow.persistdata:GetVar("time"))
-- 			inst.components.locomotor:AddSpeedMult(pow.def.name, pow.persistdata:GetVar("percent") * 0.01)
-- 		end,
-- 		["timerdone"] = function(pow, inst, data)
-- 			if data.name == pow.def.name then
-- 				inst.components.locomotor:RemoveSpeedMult(pow.def.name)
-- 			end
-- 		end,
-- 	},
-- })
--]]
