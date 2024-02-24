local Power = require("defs.powers.power")
local Equipment = require("defs.equipment")
local SGCommon = require "stategraphs.sg_common"
local slotutil = require("defs.slotutil")
local power_icons = require "gen.atlas.ui_ftf_power_icons"
local Consumable = require "defs.consumable"
local fmodtable = require "defs.sound.fmodtable"
local powerutil = require "util.powerutil"
local combatutil = require "util.combatutil"
local lume = require "util.lume"
local LootEvents = require "lootevents"
local EffectEvents = require "effectevents"
local soundutil = require "util.soundutil"
local fmodtable = require "defs.sound.fmodtable"
local ParticleSystemHelper = require "util.particlesystemhelper"

local function GetIcon(name)
	local icon_name = ("icon_equipment_%s"):format(name)

	local atlas = power_icons
	local icon = atlas.tex[icon_name]

	if not icon then
		printf("Failed to find icon: %s", icon_name)
		icon = "images/icons_ftf/item_temp.tex"
	end

	return icon
end

function Power.AddEquipmentPower(name, data)
	if data.toolips == nil then
		data.tooltips = {}
	end

	data.icon = GetIcon(name)
	data.pretty = slotutil.GetPrettyStrings(Power.Slots.EQUIPMENT, name)

	data.power_type = Power.Types.EQUIPMENT
	data.can_drop = false
	data.selectable = false
	data.show_in_ui = false

	data.stackable = true

	name = ("equipment_%s"):format(name):lower()
	Power.AddPower(Power.Slots.EQUIPMENT, name, "equipmentpowers", data)
end

Power.AddPowerFamily("EQUIPMENT", nil, 5)

Power.AddEquipmentPower("basic_head",
{
	power_category = Power.Categories.SUPPORT,
	max_stacks = 150,

	stacks_per_usage_level =  { 50, 100, 150 },
	tuning =
	{
		[Power.Rarity.COMMON] = {
			health = StackingVariable(1):SetFlat(),
		},
	},

	on_add_fn = function(pow, inst)
		if not pow.persistdata.did_init then
			local health_mod = pow.persistdata:GetVar("health")
			inst.components.health:AddHealthAddModifier(pow.def.name, health_mod)
			inst.components.health:DoDelta(health_mod, true)
			pow.persistdata.did_init = true
		end
	end,

	on_stacks_changed_fn = function(pow, inst)
		local health_mod = pow.persistdata:GetVar("health")
		inst.components.health:AddHealthAddModifier(pow.def.name, health_mod)
		inst.components.health:DoDelta(health_mod, true)
	end,

	on_remove_fn = function(pow, inst)
		inst.components.health:RemoveHealthAddModifier(pow)
		pow.persistdata.did_init = false
	end,
})

Power.AddEquipmentPower("basic_body",
{
	power_category = Power.Categories.SUPPORT,

	max_stacks = 150,
	stacks_per_usage_level =  { 0, 50, 100 }, -- can't have 0 stacks baseline or it removes itself
	tuning =
	{
		[Power.Rarity.COMMON] = {
			health = StackingVariable(1):SetFlat(),
		},
	},

	on_add_fn = function(pow, inst)
		if not pow.persistdata.did_init then
			local health_mod = pow.persistdata:GetVar("health")
			inst.components.health:AddHealthAddModifier(pow.def.name, health_mod)
			inst.components.health:DoDelta(health_mod, true)
			pow.persistdata.did_init = true
		end
	end,

	on_stacks_changed_fn = function(pow, inst)
		local health_mod = pow.persistdata:GetVar("health")
		inst.components.health:AddHealthAddModifier(pow.def.name, health_mod)
		inst.components.health:DoDelta(health_mod, true)
	end,

	on_remove_fn = function(pow, inst)
		inst.components.health:RemoveHealthAddModifier(pow)
		pow.persistdata.did_init = false
	end,
})

Power.AddEquipmentPower("basic_waist",
{
	power_category = Power.Categories.SUPPORT,

	max_stacks = 150,
	stacks_per_usage_level = { 0, 50, 100 }, -- can't have 0 stacks baseline or it removes itself
	tuning =
	{
		[Power.Rarity.COMMON] = {
			health = StackingVariable(1):SetFlat(),
		},
	},

	on_add_fn = function(pow, inst)
		if not pow.persistdata.did_init then
			local health_mod = pow.persistdata:GetVar("health")
			inst.components.health:AddHealthAddModifier(pow.def.name, health_mod)
			inst.components.health:DoDelta(health_mod, true)
			pow.persistdata.did_init = true
		end
	end,

	on_stacks_changed_fn = function(pow, inst)
		local health_mod = pow.persistdata:GetVar("health")
		inst.components.health:AddHealthAddModifier(pow.def.name, health_mod)
		inst.components.health:DoDelta(health_mod, true)
	end,

	on_remove_fn = function(pow, inst)
		inst.components.health:RemoveHealthAddModifier(pow)
		pow.persistdata.did_init = false
	end,
})


local function _on_cabbageroll_head_hitboxtriggered(pow, inst, data)
	if pow.mem.attacking then
		local hitstun = 0
		for i = 1, #data.targets do
			local v = data.targets[i]
			local attack = Attack(inst, v)
			attack:SetDamageMod(pow.persistdata:GetVar("damage_mod"))
			local dir = inst:GetAngleTo(v)
			attack:SetDir(dir)
			attack:SetHitstunAnimFrames(hitstun)
			attack:SetFocus(false)
			attack:SetPushback(1.5)
			attack:SetID(pow.def.name)
			inst.components.combat:DoKnockbackAttack(attack)
			inst.SoundEmitter:PlaySound(fmodtable.Event.Hit_bonionRoll)
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

Power.AddEquipmentPower("cabbageroll_head",
{
	power_category = Power.Categories.DAMAGE,
	tags = { POWER_TAGS.PROVIDES_MOVESPEED, POWER_TAGS.ROLL_BECOMES_ATTACK },

	stacks_per_usage_level = { 100, 110, 120 }, -- % of extra weapon damage dealt
	tuning =
	{
		[Power.Rarity.COMMON] = {
			-- %
			damage_mod = StackingVariable(1):SetPercentage(),
		},
	},

	on_update_fn = function(pow, inst, dt)
		if pow.mem.attacking then
			local animframe = inst.sg:GetAnimFramesInState()
			local statename = inst.sg:GetCurrentState()

			-- Only attack a few frames into the state, and only attack for one frame.
			-- Wait until the roll has momentum before actually pushing back, so we don't pushback on frame 1 before we've even moved.

			if animframe >= 2 and (inst.sg:HasStateTag("dodge") and (not inst.sg:HasStateTag("dodge_pre") and not inst.sg:HasStateTag("dodge_pst"))) then
				local dir = ConvertRotationToRoughDirection(inst)

				local scale_x = 1
				if inst.sg:HasStateTag("dodging_backwards") then
					scale_x = -1
				end
				local fx_name = "fx_player_roll_damage_cabbageroll"
				if not pow.mem.spawned_fx then
					local params =
					{
						ischild = true,
						inheritrotation = true,
						scalex = scale_x,
					}
					powerutil.SpawnFxOnEntity(fx_name, inst, params)
					pow.mem.spawned_fx = true
				end

				-- Only push a hitbox in front of the player, so that stuff behind us doesn't get pushed back.

				if dir == "FORWARD" then
					inst.components.hitbox:PushBeam(1 * scale_x, 1.5 * scale_x, 0.50, HitPriority.PLAYER_DEFAULT)
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
		["hitboxtriggered"] = _on_cabbageroll_head_hitboxtriggered,

		["newstate"] = function(pow, inst, data)
			if not inst.sg:HasStateTag("dodge") then
				if pow.mem.attacking then
					pow.mem.attacking = false
					combatutil.EndMeleeAttack(inst)
					inst.components.hitbox:StopRepeatTargetDelay()
				end
			end
		end,

		["dodge"] = function(pow, inst, data)
			if pow.mem.attacking then
				-- This would have happened if they canceled from one dodge into another dodge. Finish the last attack, so we can start a new one.
				pow.mem.attacking = false
				combatutil.EndMeleeAttack(inst)
				inst.components.hitbox:StopRepeatTargetDelay()
			end

			if not pow.mem.attacking then
				pow.mem.attacking = true
				pow.mem.spawned_fx = false

				inst.sg.mem.attack_type = "equipment_attack"
				combatutil.StartMeleeAttack(inst)
				inst.components.hitbox:StartRepeatTargetDelayAnimFrames(20)

				inst:PushEvent("used_power", pow.def)
			end
		end,
	}
})

local function cabbageroll_GetBonusIFrames(pow, inst)
	local percent = pow.persistdata:GetVar("percent_extra_iframes")
	local normal_frames = inst.components.playerroller:GetIframes()

	local bonus_frames = math.ceil(normal_frames * percent) -- ceil makes it so that each level gives at least 1f even for Light Dodge

	-- print("percent:", percent, "normal frames:", normal_frames, "bonus frames:", bonus_frames)

	return bonus_frames

end

Power.AddEquipmentPower("cabbageroll_body",
{
	-- MORE IFRAMES ON DODGE
	-- Provide another moment where players are told that their dodge does have invincibility.
	-- Make it more likely that players will discover perfect-dodges because of the increased timing.

	power_category = Power.Categories.SUPPORT,
	stacks_per_usage_level = { 10, 20, 30 }, -- % multiplier of iframes
	tuning =
	{
		[Power.Rarity.COMMON] = {
			percent_extra_iframes = StackingVariable(1):SetPercentage(),
		},
	},

	on_stacks_changed_fn = function(pow, inst)
		if pow.persistdata.init then
			inst.components.playerroller:RemoveIframeModifier(pow.def.name)
		end

		pow.persistdata.init = true
		local bonus_frames = cabbageroll_GetBonusIFrames(pow, inst)
		inst.components.playerroller:AddIframeModifier(pow.def.name, bonus_frames)
	end,

	on_remove_fn = function(pow, inst)
		if pow.persistdata.init then
			pow.persistdata.init = false
			inst.components.playerroller:RemoveIframeModifier(pow.def.name)
		end
	end,

	event_triggers =
	{
		["weightchanged"] = function(pow, inst, data)
			if pow.persistdata.init then
				-- Recalculate frames because their weight class may have changed, resulting in more or
				inst.components.playerroller:RemoveIframeModifier(pow.def.name)

				local bonus_frames = cabbageroll_GetBonusIFrames(pow, inst)
				inst.components.playerroller:AddIframeModifier(pow.def.name, bonus_frames)
			end
		end,
	}
})

Power.AddEquipmentPower("cabbageroll_waist",
{
	-- FARTHER ROLL
	-- An early player complaint is that the dodge is too stubby. This will likely not be as true for Light dodges, but show players that they will be adjusting their build.

	power_category = Power.Categories.SUPPORT,
	stacks_per_usage_level = { 20, 30, 40 }, -- % distance multiplier
	tuning =
	{
		[Power.Rarity.COMMON] = {
			percent_speed_bonus = StackingVariable(1):SetPercentage(),
		},
	},

	on_stacks_changed_fn = function(pow, inst)
		if pow.persistdata.init then
			inst.components.playerroller:RemoveTicksMultModifier(pow.def.name)
		end

		pow.persistdata.init = true
		local percent = pow.persistdata:GetVar("percent_speed_bonus")
		inst.components.playerroller:AddTicksMultModifier(pow.def.name, -percent)
	end,

	on_remove_fn = function(pow, inst)
		if pow.persistdata.init then
			pow.persistdata.init = false
			inst.components.playerroller:RemoveTicksMultModifier(pow.def.name)
		end
	end,
})

Power.AddEquipmentPower("blarmadillo_head",
{
	power_category = Power.Categories.SUSTAIN,
	stacks_per_usage_level = { 30, 40, 50 },  -- Projectile damage reduction -- projectiles are pretty rare, and can catch newer players off guard. Allow a big boost to help them out!
	tuning =
	{
		[Power.Rarity.COMMON] = {
			projectile_damage_reduction = StackingVariable(1):SetPercentage(),
		},
	},

	defend_mod_fn = function(pow, attack, output_data)
		local attacker = attack:GetAttacker()
		if attack:GetDamage() > 0 and attack:GetAttacker() ~= attack:GetTarget() and attack:GetProjectile() ~= nil then
			local damage = attack:GetDamage()
			local prevented = damage * pow.persistdata:GetVar("projectile_damage_reduction")
			output_data.damage_delta = output_data.damage_delta - (math.ceil(prevented))

			return true
		end
	end
})

Power.AddEquipmentPower("blarmadillo_body",
{
		-- MINIBOSS
	power_category = Power.Categories.SUPPORT,
	stacks_per_usage_level = { 20, 30, 40 },  -- Miniboss damage reduction
	tuning	=
	{
		[Power.Rarity.COMMON] = {
			miniboss_damage_reduction = StackingVariable(1):SetPercentage(),
		},
	},

	defend_mod_fn = function(pow, attack, output_data)
		local attacker = attack:GetAttacker()
		if attack:GetDamage() > 0 and attacker ~= attack:GetTarget() and attacker:HasTag("miniboss") then
			local damage = attack:GetDamage()
			local prevented = damage * pow.persistdata:GetVar("miniboss_damage_reduction")
			output_data.damage_delta = output_data.damage_delta - (math.ceil(prevented))
			return true
		end
	end
})

Power.AddEquipmentPower("blarmadillo_waist",
{
	power_category = Power.Categories.SUPPORT,
	stacks_per_usage_level = { 30, 40, 50 }, -- Trap damage reduction
	tuning =
	{
		[Power.Rarity.COMMON] = {
			trap_damage_reduction = StackingVariable(1):SetPercentage(),
		},
	},

	defend_mod_fn = function(pow, attack, output_data)
		if attack:GetDamage() > 0 and attack:GetAttacker() ~= attack:GetTarget() and attack:GetAttacker():HasTag("trap") then
			local damage = attack:GetDamage()
			local prevented = damage * pow.persistdata:GetVar("trap_damage_reduction")
			output_data.damage_delta = output_data.damage_delta - (math.ceil(prevented))

			return true
		end
	end
})


-- Deal bonus damage when airborne
-- Power.AddEquipmentPower("battoad_head",
-- {
-- 	power_category = Power.Categories.DAMAGE,
-- 	stacks_per_usage_level = { 10, 20, 30 },
-- 	tuning =
-- 	{
-- 		[Power.Rarity.COMMON] =
-- 		{
-- 			airborne_bonus_damage = StackingVariable(1):SetPercentage(), -- %
-- 		},
-- 	},

-- 	damage_mod_fn = function(pow, attack, output_data)
-- 		if attack:GetAttacker() ~= attack:GetTarget() then
-- 			if attack:GetAttacker().sg:HasStateTag("airborne") then
-- 				local damagemult = pow.persistdata:GetVar("airborne_bonus_damage")
-- 				output_data.damage_delta = output_data.damage_delta + (attack:GetDamage() * damagemult)
-- 			end
-- 		end
-- 	end,
-- })

Power.AddEquipmentPower("battoad_head",
{
	power_category = Power.Categories.SUPPORT,
	stacks_per_usage_level = { 10, 15, 20 },
	tuning =
	{
		[Power.Rarity.COMMON] =
		{
			bonus_percent = StackingVariable(1):SetPercentage(),
		},
	},
	event_triggers =
	{
		["gain_konjur"] = function(pow, inst, amount)
			if amount > 0 then
				local bonus_percent = pow.persistdata:GetVar("bonus_percent")
				local bonus = math.ceil(amount * bonus_percent)

				-- TODO: This implementation may cause issues if gaining konjur while leaving the room. If so, put any 'bonus' konjur into a bucket and deliver it entirely on 'leave_room' or whatever.
				-- When delivering konjur like this, remove it from the bucket. Make sure player gets all konjur.
				inst:DoTaskInAnimFrames(7, function()
					if inst ~= nil and inst:IsValid() then
						inst.components.inventoryhoard:AddStackable(Consumable.Items.MATERIALS.konjur, bonus, true)
						LootEvents.DisplayKonjurAmountInWorld(inst, bonus)
					end
				end)
			end
		end,
	}
})


Power.AddEquipmentPower("battoad_body",
{
	-- When hit, lose 10 Konjur and heal for a percentage of damage taken.
	power_category = Power.Categories.SUSTAIN,
	stacks_per_usage_level = { 10, 15, 20 }, -- This is equivalent to damage reduction, but is delivered as a heal which touches more systems + allows more builds, while reminding the player of their armour more actively.
											 -- This also allows a player to die if they would have died, whereas damage reduction would prevent the death.
											 -- When tuning, compare to other armour pieces and keep in mind we are also spending Konjur to do this.
											 -- However, proccing a heal also provides value that just straight damage reduction doesn't have.
	tuning =
	{
		[Power.Rarity.COMMON] =
		{
			heal_percent = StackingVariable(1):SetPercentage(), -- % of the damage gotten back
			cost = 2,	-- Cost is steady, but bonus increases as it is upgraded.
			--[[
				TUNING NOTES:
					Our basic potion gives 500 HP for 75 konjur.

					This establishes an exchange rate to compare to:
						1 konjur = 6.66HP

					Assume an average attack by a trash mob is 90HP. Five attacks would be 450 DMG.

					If we healed 10% of every attack, five attacks would Heal us for 45HP.

					Using our exchange rate, matching potion rates exactly would make this cost:
						1 konjur / 6.66HP
						45HP / 6.66 = 6.75 konjur
						6.75 konjur / 5 hits = 1.35 konjur per hit

					If we want this to be better than Potion rate, let's make it an even 1konjur.

					5 Attacks dealing 450DMG:
						Healing 10%
							Heal 45HP
							Cost 5
								 = 9 HP per konjur
						Healing 15%
							Heal 67.5HP
							Cost 5
								= 13.5 HP per konjur
						Healing 20%
							Heal 90HP
							Cost 5
								= 18 HP per konjur

					This would of course be much better against big mobs or bosses: for one attack that did 250 dmg, you'd get 25 HP per konjur.

					That's pretty strong. Let's double the cost to 2konjur. This way, it starts out slightly worse than a Potion, but gets better than Potion at max level for trash mobs.

					And of course, for big mobs dealing 250dmg per hit, you're still getting about 12.5HP per konjur which is -much- better than potion.
			]]
		},
	},

	event_triggers =
	{
		["take_damage"] = function(pow, inst, attack)
			local damage = attack:GetDamage()
			if damage > 0 and attack:GetAttacker() ~= attack:GetTarget() then
				local inv = attack:GetTarget().components.inventoryhoard
				local to_remove = math.min(pow.persistdata:GetVar("cost"), inv:GetStackableCount(Consumable.Items.MATERIALS.konjur))
				if to_remove > 0 then

					-- Remove the damage at the time of hit, then delay a bit to give the heal.
					inv:RemoveStackable(Consumable.Items.MATERIALS.konjur, to_remove)
					local fade_t = 1.5
					TheDungeon.HUD:MakePopText({ target = attack:GetTarget(), button = string.format(STRINGS.UI.INVENTORYSCREEN.KONJUR, -to_remove), color = UICOLORS.KONJUR, size = 65, fade_time = fade_t })

					local heal = lume.round(damage * pow.persistdata:GetVar("heal_percent"))
					-- Delay a bit to let the mind register what's happening, and give some time for health to leave the player.
					inst:DoTaskInTime(fade_t * 0.6, function()
						if inst ~= nil and inst:IsValid() then
							local power_heal = Attack(inst, inst)
							power_heal:SetHeal(heal)
							power_heal:SetSource(pow.def.name)
							inst.components.combat:ApplyHeal(power_heal)
						end
					end)
				end
			end
		end
	},
})

Power.AddEquipmentPower("battoad_waist",
{
	-- Gain Konjur when destroying a prop
	power_category = Power.Categories.SUPPORT,
	stacks_per_usage_level = { 5, 10, 15 },
	tuning =
	{
		[Power.Rarity.COMMON] =
		{
			konjur = StackingVariable(1):SetFlat(),
		},
	},

	event_triggers =
	{
		["kill"] = function(pow, inst, data)
			local victim = data.attack:GetTarget()
			if victim and victim:HasTag("prop") then
				LootEvents.MakeEventSpawnCurrency(pow.persistdata:GetVar("konjur"), victim:GetPosition(), inst, false, true)
			end
		end,
	},
})

-- Make a burst of wind behind the player
Power.AddEquipmentPower("windmon_head",
{
	power_category = Power.Categories.DAMAGE,
	tags = { },

	prefabs = {
		-- These are all so that we can do one EffectEvents.MakeEventSpawnLocalEntity() call and not need to configure anything past that.
		-- Weak applies 1 stack, Medium applies 2, Strong applies 3
		-- left / right / up / down are different hitbox layouts
		"player_wind_gust_dummy_weak_left",
		"player_wind_gust_dummy_medium_left",
		"player_wind_gust_dummy_strong_left",
		"player_wind_gust_dummy_weak_right",
		"player_wind_gust_dummy_medium_right",
		"player_wind_gust_dummy_strong_right",
		"player_wind_gust_dummy_weak_down",
		"player_wind_gust_dummy_medium_down",
		"player_wind_gust_dummy_strong_down",
		"player_wind_gust_dummy_weak_up",
		"player_wind_gust_dummy_medium_up",
		"player_wind_gust_dummy_strong_up",
	},

	stacks_per_usage_level = { 100, 150, 200 }, -- wind power
	tuning =
	{
		[Power.Rarity.COMMON] = {
			-- %
			wind_strength = StackingVariable(1):SetPercentage(), -- This is only a display value, really. This gets crunched down into a 1/2/3 value.
		},
	},

	event_triggers =
	{
		["newstate"] = function(pow, inst, data)
			if inst.sg:HasStateTag("dodge") and not pow.mem.attacked then
				pow.mem.attacked = true

				local display_value = pow.persistdata:GetVar("wind_strength")
				local dummy_level
				if display_value == 1.0 then
					dummy_level = "weak"
				elseif display_value == 1.5 then
					dummy_level = "medium"
				elseif display_value == 2.0 then
					dummy_level = "strong"
				else
					-- Sometimes stacks don't initialize properly, so here's a catch-all.
					dummy_level = "weak"
				end

				local dir = ConvertRotationToRoughDirection(inst)
				inst:DoTaskInAnimFrames(2, function()
					if SGCommon.Fns.SanitizeTarget(inst) then
						local gust
						local pos = inst:GetPosition()
						if dir == "FORWARD" then
							local facing = inst.Transform:GetFacing()
							if facing == FACING_RIGHT then
								local prefab = "player_wind_gust_dummy_"..dummy_level.."_left"
								EffectEvents.MakeEventSpawnLocalEntity(inst, prefab, "idle")
								pos.x = pos.x - 1
								ParticleSystemHelper.MakeOneShotAtPosition(pos, "windmon_armor_helm_gust", 2, inst, { use_entity_facing = true })
							elseif facing == FACING_LEFT then
								local prefab = "player_wind_gust_dummy_"..dummy_level.."_right"
								EffectEvents.MakeEventSpawnLocalEntity(inst, prefab, "idle")
								pos.x = pos.x + 1
								ParticleSystemHelper.MakeOneShotAtPosition(pos, "windmon_armor_helm_gust", 2, inst, { use_entity_facing = true })
							end
						elseif dir == "UP" then
							local prefab = "player_wind_gust_dummy_"..dummy_level.."_down"
							EffectEvents.MakeEventSpawnLocalEntity(inst, prefab, "idle")
							pos.z = pos.z + 2 -- These are both intentionally moving up. If you're moving up, we want to push it up so the gap isn't so big.
							ParticleSystemHelper.MakeOneShotAtPosition(pos, "windmon_armor_helm_gust_down", 2, inst, { use_entity_facing = true })
						elseif dir == "DOWN" then
							local prefab = "player_wind_gust_dummy_"..dummy_level.."_up"
							EffectEvents.MakeEventSpawnLocalEntity(inst, prefab, "idle")
							pos.z = pos.z + 2  -- These are both intentionally moving up. If you're moving down, we want to push it up so we can actually see it.
							ParticleSystemHelper.MakeOneShotAtPosition(pos, "windmon_armor_helm_gust_up", 2, inst, { use_entity_facing = true })
						end

						--sound
						local params = {}
						params.fmodevent = fmodtable.Event.Gustree_Dodge
						soundutil.PlaySoundData(inst, params)
					end
				end)
			else
				if pow.mem.attacked then
					pow.mem.attacked = false
				end
			end
		end,
	}
})

-- Leave a Spike Ball
Power.AddEquipmentPower("windmon_body",
{
	power_category = Power.Categories.DAMAGE,
	tags = { },
	prefabs = { "owlitzer_spikeball" },
	stacks_per_usage_level = { 1, 2, 3 }, -- % of extra weapon damage dealt
	tuning =
	{
		[Power.Rarity.COMMON] = {
			number_of_balls = StackingVariable(1):SetFlat(),
		},
	},

	event_triggers =
	{
		["newstate"] = function(pow, inst, data)
			if not inst.sg:HasStateTag("dodge") and pow.mem.attacked then
				-- Allow only one spurt per dodge.
				pow.mem.attacked = false
			end
		end,

		["hitboxcollided_invincible"] = function(pow, inst, data)
			if inst.sg:HasStateTag("dodge") and not pow.mem.attacked then
				-- Allow only one spurt per dodge.
				pow.mem.attacked = true
				local num_balls = pow.persistdata:GetVar("number_of_balls")
				for i=1, num_balls do
					-- Stagger them out
					inst:DoTaskInAnimFrames((i-1) * 2, function()
						if inst ~= nil and inst:IsValid() then
							local ball = SpawnPrefab("owlitzer_spikeball")
							ball:Setup(inst)
							ball.sg:GoToState("land")

							local x, z = inst:GetPosition():GetXZ()
							local facing = inst.Transform:GetFacing() == FACING_LEFT and 1 or -1
							ball.Transform:SetPosition(x + 1.25 + i * facing, 0, z)

							--sound
							local params = {}
							params.max_count = 3
							params.fmodevent = fmodtable.Event.Gustree_Spikeball
							soundutil.PlaySoundData(inst, params)
						end
					end)
				end
			end
		end,
	}
})


Power.AddEquipmentPower("windmon_waist",
{
	power_category = Power.Categories.SUSTAIN,
	stacks_per_usage_level = { 33, 66, 100 },
	tuning =
	{
		[Power.Rarity.COMMON] =
		{
			-- %Amount of Wind Negation while standing still
			wind_resistance = StackingVariable(1, 0):SetPercentage(),
		},
	},

	on_update_fn = function(pow, inst)
		local stationary = not ((inst.sg:HasStateTag("busy") and not inst.sg:HasStateTag("turning")) or inst.sg:HasStateTag("moving"))

		if stationary then
			if not pow.mem.active then
				local wind_resistance = pow.persistdata:GetVar("wind_resistance")
				inst.components.pushforce:AddPushForceModifier(pow, 1 - wind_resistance)
				pow.mem.active = true
			end
		else
			if pow.mem.active then
				inst.components.pushforce:RemovePushForceModifier(pow)
				pow.mem.active = false
			end
		end
	end,
})


local motorvel_to_damage_mult =
{
	-- Average, unaffected runspeed is about 8
	-- 20% Bonus (Running Shoes Common) is 9.2
	-- 35% Bonus (Running Shoes Epic) is 10.1
	-- 50% Bonus (Running Shoes Legendary) is 11
	-- 75% Bonus (Cheese It) is 12.5

	-- motorvel, damage multiplier
	{0,		0},
	{6,		0},
	{8,		1}, -- Basic
	{10,	1.5}, 
	{12,	2}, 
	{15,	4}, --
	{17,	5}, --
	{20,	6}, --
	{25,	7}, --
	{30,	10}, -- how are you this fast, sonic
}

local function _on_gnarlic_head_hitboxtriggered(pow, inst, data)
	if pow.mem.canattack and pow.mem.attackstarted then
		local motorvel = inst.Physics:GetMotorVel()
		local damagemult = PiecewiseFn(motorvel, motorvel_to_damage_mult)

		local base_damagemod = 0.8 -- Do 0.8 of base damage by default (Combined with Level1 = 100% of weapon)
		local damagemod =  (base_damagemod + pow.persistdata:GetVar("damage_bonus")) * damagemult

		-- Base Damage is 0.3 of your weapon damage (So that Level 1 + Base Damage = 50% of your weapon damage)
		-- Multiply that by a value based on your speed
		-- Multiply that by the level of the power (Base level is 20%)

		local hitstun = 0
		for i = 1, #data.targets do
			local v = data.targets[i]
			if pow.mem.touched[v] or not (damagemod > 0) then
				return
			end

			local attack = Attack(inst, v)
			attack:SetDamageMod(damagemod)
			local dir = inst:GetAngleTo(v)
			attack:SetDir(dir)
			attack:SetHitstunAnimFrames(hitstun)
			attack:SetFocus(false)
			attack:SetPushback(0.5)
			attack:SetID(pow.def.name)

			inst.components.combat:DoKnockbackAttack(attack)


			local hitstoplevel = 0
			local hitfx_x_offset = 1.5
			local hitfx_y_offset = 1.5

			local distance = inst:GetDistanceSqTo(v)
			if distance >= 30 then
				hitfx_x_offset = hitfx_x_offset + 1.25
			elseif distance >= 25 then
				hitfx_x_offset = hitfx_x_offset + 0.75
			end

			inst.components.combat:SpawnHitFxForPlayerAttack(attack, "hits_player_pierce", v, inst, hitfx_x_offset, hitfx_y_offset, dir, hitstoplevel)

			pow.mem.touched[v] = true
		end
	end
end

Power.AddEquipmentPower("gnarlic_head",
{
	power_category = Power.Categories.DAMAGE,
	stacks_per_usage_level = { 20, 35, 50 },
	tuning =
	{
		[Power.Rarity.COMMON] =
		{
			damage_bonus = StackingVariable(1):SetPercentage()
		},
	},

	on_add_fn = function(pow, inst)
		pow.mem.attacking = false
	end,

	on_update_fn = function(pow, inst, dt)
		if pow.mem.canattack then
			local animframe = inst.sg:GetAnimFramesInState()

			-- Only attack a few frames into the run.
			-- Wait until we have a LITTLE bit of momentum before we attack.

			if animframe >= 2 then -- Make this number 0 and equip Pew Pew! for a really fun time.
				local dir = ConvertRotationToRoughDirection(inst)

				if not pow.mem.attackstarted then
					inst.sg.mem.attack_type = "equipment_attack"
					combatutil.StartMeleeAttack(inst)
					pow.mem.touched = {}

					pow.mem.attackstarted = true

					-- Start fx
				end

				-- Only push a hitbox in front of the player, so that stuff behind us doesn't get pushed back.
				if dir == "FORWARD" then
					inst.components.hitbox:PushBeam(0, 0.5, 1, HitPriority.PLAYER_DEFAULT)
				elseif dir == "UP" then
					inst.components.hitbox:PushOffsetBeam(-0.5, 0.5, 0.75, 0.5, HitPriority.PLAYER_DEFAULT)
				elseif dir == "DOWN" then
					inst.components.hitbox:PushOffsetBeam(-0.5, 0.5, 0.75, -0.5, HitPriority.PLAYER_DEFAULT)
				end
			end
		end
	end,

	event_triggers =
	{
		["hitboxtriggered"] = _on_gnarlic_head_hitboxtriggered,

		["newstate"] = function(pow, inst, data)
			local still_moving = inst.sg:HasStateTag("moving") and not inst.sg:HasStateTag("turning")

			if still_moving then
				-- Set the flag that the attack is possible. In onupdate, we will actually start a new attack if we've been running for a few frames.
				pow.mem.canattack = true
			else
				if pow.mem.canattack then
					-- We're not attacking anymore -- stop the attack.
					pow.mem.canattack = false
					pow.mem.attackstarted = false
					combatutil.EndMeleeAttack(inst)
				end
			end
		end,
	},
})

Power.AddEquipmentPower("gnarlic_body",
{
	power_category = Power.Categories.SUSTAIN,
	stacks_per_usage_level = { 20, 30, 40 },
	tuning =
	{
		[Power.Rarity.COMMON] =
		{
			speed_bonus_per_second = StackingVariable(1):SetPercentage(),
		},
	},

	on_add_fn = function(pow, inst)
		pow.mem.active = false
		pow.mem.active_ticks = 0
		pow.mem.seconds_activated = 0
	end,

	on_update_fn = function(pow, inst)
		if pow.mem.active then
			local seconds = math.floor(pow.mem.active_ticks / 45) -- Under the hood, be slightly better than 1s
			if seconds > pow.mem.seconds_activated then
				inst.components.locomotor:AddSpeedMult(pow.def.name, pow.persistdata:GetVar("speed_bonus_per_second") * seconds)

				pow.mem.seconds_activated = seconds
			end
		else
			inst.components.locomotor:RemoveSpeedMult(pow.def.name)
			pow.mem.active_ticks = 0
			pow.mem.seconds_activated = 0
		end

		pow.mem.active_ticks = pow.mem.active_ticks + 1
	end,

	event_triggers =
	{
		["newstate"] = function(pow, inst, data)
			local still_moving = inst.sg:HasStateTag("moving") and not inst.sg:HasStateTag("turning")
			if still_moving then
				pow.mem.active = true
			else
				pow.mem.active = false
			end
		end,
	},
})

Power.AddEquipmentPower("gnarlic_waist",
{
	-- FARTHER ROLL

	power_category = Power.Categories.SUPPORT,
	stacks_per_usage_level = { 20, 30, 40 }, -- % distance multiplier
	tuning =
	{
		[Power.Rarity.COMMON] = {
			percent_distance_bonus = StackingVariable(1):SetPercentage(),
		},
	},

	on_stacks_changed_fn = function(pow, inst)
		if pow.persistdata.init then
			inst.components.playerroller:RemoveDistanceMultModifier(pow.def.name)
		end

		pow.persistdata.init = true
		local percent = pow.persistdata:GetVar("percent_distance_bonus")
		inst.components.playerroller:AddDistanceMultModifier(pow.def.name, percent)
	end,

	on_remove_fn = function(pow, inst)
		if pow.persistdata.init then
			pow.persistdata.init = false
			inst.components.playerroller:RemoveDistanceMultModifier(pow.def.name)
		end
	end,
})

Power.AddEquipmentPower("zucco_head",
{
	power_category = Power.Categories.SUPPORT,
	tags = { POWER_TAGS.PROVIDES_MOVESPEED },
	stacks_per_usage_level = { 5, 7, 10 }, -- bonus runspeed
	tuning =
	{
		[Power.Rarity.COMMON] = {
			-- %
			speed = StackingVariable(1, 5):SetPercentage(),
		},
	},

	on_add_fn = function(pow, inst)
		if not pow.persistdata.did_init and inst.components.locomotor ~= nil then
			inst.components.locomotor:AddSpeedMult(pow.def.name, pow.persistdata:GetVar("speed"))
			pow.persistdata.did_init = true
		end
	end,

	on_stacks_changed_fn = function(pow, inst)
		inst.components.locomotor:AddSpeedMult(pow.def.name, pow.persistdata:GetVar("speed"))
	end,

	on_remove_fn = function(pow, inst)
		if inst.components.locomotor ~= nil then
			inst.components.locomotor:RemoveSpeedMult(pow.def.name)
		end
		pow.persistdata.did_init = false
	end,
})

Power.AddEquipmentPower("zucco_body",
{
	power_category = Power.Categories.SUPPORT,
	tags = { },
	stacks_per_usage_level = { 5, 7, 10 }, -- bonus focus damage
	tuning =
	{
		[Power.Rarity.COMMON] =
		{
			focus_damage_bonus = StackingVariable(1):SetPercentage(), -- %
		},
	},

	damage_mod_fn = function(pow, attack, output_data)
		if attack:GetFocus() then
			local bonus_damage = attack:GetDamage() * pow.persistdata:GetVar("focus_damage_bonus")
			output_data.damage_delta = output_data.damage_delta + bonus_damage
			return true
		end
	end,
})

Power.AddEquipmentPower("zucco_waist",
{
	power_category = Power.Categories.SUPPORT,
	tags = { },
	stacks_per_usage_level = { 1, 2, 3 },
	tuning =
	{
		[Power.Rarity.COMMON] =
		{
		},
	},
})

Power.AddEquipmentPower("gourdo_head",
{
	power_category = Power.Categories.SUSTAIN,
	tags = { POWER_TAGS.PROVIDES_HEALING },
	stacks_per_usage_level = { 10, 15, 20 },
	tuning =
	{
		[Power.Rarity.COMMON] = {
			bonus_heal = StackingVariable(1):SetPercentage(),
		},
	},

	heal_mod_fn = function(pow, heal, output_data)
		local heal_amount = heal:GetHeal()
		local bonus = math.floor(heal_amount * pow.persistdata:GetVar("bonus_heal"))
		output_data.heal_delta = bonus
		return true
	end,
})

Power.AddEquipmentPower("gourdo_body",
{
	power_category = Power.Categories.SUSTAIN,
	tags = { POWER_TAGS.PROVIDES_HEALING },
	stacks_per_usage_level = { 10, 15, 20 },
	tuning =
	{
		[Power.Rarity.COMMON] = {
			shared_heal = StackingVariable(1):SetPercentage(),
		},
	},

	event_triggers =
	{
		["take_heal"] = function(pow, inst, heal)
			-- find all friendly targets on the stage
			local shared_heal = pow.persistdata:GetVar("shared_heal")
			local delta = heal:GetHeal() * shared_heal

			local x,z = inst.Transform:GetWorldXZ()
			local range = 100
			local ents = FindFriendliesInRange(x, z, range)

			local ents_near, ents_med, ents_far = powerutil.SortEntitiesIntoRanges(ents, x, z, range)

			local function do_heal(ent)
				local new_heal = Attack(inst, ent)
				new_heal:SetHeal(delta)
				ent.components.combat:GetHealed(new_heal)
			end

			inst:DoTaskInAnimFrames(2, function()
				for i, ent in ipairs(ents_near) do
					if ent ~= inst then
						inst:DoTaskInAnimFrames(math.random(0, 2), function() do_heal(ent) end)
					end
				end
			end)

			inst:DoTaskInAnimFrames(4, function()
				for i, ent in ipairs(ents_med) do
					if ent ~= inst then
						inst:DoTaskInAnimFrames(math.random(0, 2), function() do_heal(ent) end)
					end
				end
			end)

			inst:DoTaskInAnimFrames(6, function()
				for i, ent in ipairs(ents_far) do
					if ent ~= inst then
						inst:DoTaskInAnimFrames(math.random(0, 2), function() do_heal(ent) end)
					end
				end
			end)
		end,
	}
})

Power.AddEquipmentPower("gourdo_waist",
{
	power_category = Power.Categories.SUSTAIN,
	tags = { POWER_TAGS.PROVIDES_HEALING },
	stacks_per_usage_level = { 10, 15, 20 },
	tuning =
	{
		[Power.Rarity.COMMON] = {
			-- Raw healing amount, applied when entering room
			heal_on_enter = StackingVariable(1):SetFlat(),
		},
	},

	description_fn = function(pow, tuning)
		if tuning.heal_on_enter then
			tuning.heal_on_enter = tuning.heal_on_enter * pow.stacks
		end
		return tuning
	end,

	event_triggers =
	{
		["start_gameplay"] = function(pow, inst, data)
			local power_heal = Attack(inst, inst)
			power_heal:SetHeal(pow.persistdata:GetVar("heal_on_enter"))
			power_heal:SetSource(pow.def.name)
			inst.components.combat:ApplyHeal(power_heal)
			inst:PushEvent("used_power", pow.def)
		end,
	}
})

Power.AddEquipmentPower("yammo_head",
{
	power_category = Power.Categories.DAMAGE,
	tags = { },
	-- % heavy attack bonus damage
	stacks_per_usage_level = { 10, 20, 30 },
	tuning =
	{
		[Power.Rarity.COMMON] =
		{
			-- % per stack.
			damage_bonus = StackingVariable(1):SetPercentage(),
		},
	},

	damage_mod_fn = function(pow, attack, output_data)
		local damagemult = 0

		if attack:GetID() == "heavy_attack" and attack:GetFocus() then
			damagemult = pow.persistdata:GetVar("damage_bonus")
		end

		output_data.damage_delta = output_data.damage_delta + (attack:GetDamage() * damagemult)
	end,

	event_triggers =
	{
	}
})

Power.AddEquipmentPower("yammo_body",
{
	-- TAKE LESS DAMAGE FROM BOSSES
	-- This is in the same slot as the other "miniboss" armor, so the player has to choose between the two.
	-- This is Heavy armour, so it takes an attractive power and makes player deal with Weight in order to use it.

	power_category = Power.Categories.SUPPORT,
	stacks_per_usage_level = { 20, 30, 40 },  -- Boss damage reduction
	tuning	=
	{
		[Power.Rarity.COMMON] = {
			boss_damage_reduction = StackingVariable(1):SetPercentage(),
		},
	},

	defend_mod_fn = function(pow, attack, output_data)
		local attacker = attack:GetAttacker()
		if attack:GetDamage() > 0 and attacker ~= attack:GetTarget() and attacker:HasTag("boss") then
			local damage = attack:GetDamage()
			local prevented = damage * pow.persistdata:GetVar("boss_damage_reduction")
			output_data.damage_delta = output_data.damage_delta - (math.ceil(prevented))
			return true
		end
	end
})

Power.AddEquipmentPower("yammo_waist",
{
	power_category = Power.Categories.SUPPORT,
	tags = { },
	stacks_per_usage_level = { 20, 30, 40 }, -- Take less damage while not attacking
	tuning =
	{
		[Power.Rarity.COMMON] =
		{
			damage_reduction = StackingVariable(1):SetPercentage(), -- %
		},
	},
	defend_mod_fn = function(pow, attack, output_data)
		if attack:GetDamage() > 0 and attack:GetAttacker() ~= attack:GetTarget() then
			if not attack:GetTarget().sg:HasStateTag("attack") then
				local damage = attack:GetDamage()
				local prevented = damage * (pow.persistdata:GetVar("damage_reduction"))
				output_data.damage_delta = output_data.damage_delta - (math.ceil(prevented))

				return true
			end
		end
	end
})

Power.AddEquipmentPower("megatreemon_head",
{
	-- bonus damage to non-elite
	power_category = Power.Categories.DAMAGE,
	stacks_per_usage_level = { 5, 7, 10, 13, 16, 20, 24, 28, 35 }, -- bonus damage % to regular enemies
	tuning =
	{
		[Power.Rarity.COMMON] =
		{
			damage_bonus = StackingVariable(1):SetPercentage(),
		},
	},

	description_fn = function(pow, tuning)
		if tuning.damage_bonus then
			tuning.damage_bonus = tuning.damage_bonus * pow.stacks
		end
		return tuning
	end,

	damage_mod_fn = function(pow, attack, output_data)
		if attack:GetAttacker() ~= attack:GetTarget() then
			if attack:GetTarget():HasTag("elite") or attack:GetTarget():HasTag("boss") then
				return false
			end

			local damagemult = pow.persistdata:GetVar("damage_bonus")

			if damagemult then
				output_data.damage_delta = output_data.damage_delta + (attack:GetDamage() * damagemult)
			end

			return true
		end
	end,
})

local function _spawn_guard_root(inst, x, z)
	local root = SpawnPrefab("megatreemon_growth_root_player", inst)
	root.Transform:SetPosition(x, 0, z)
	root.Transform:SetRotation(math.random(360)) -- don't care about rotation for sync purposes
	root:PushEvent("guard")
	root.owner = inst
	return root
end

local function _on_root_hitbox(inst, data)
	local monsterutil = require "util.monsterutil"

	SGCommon.Events.OnHitboxTriggered(inst.owner, data, {
		hitstoplevel = HitStopLevel.HEAVY,
		set_dir_angle_to_target = true,
		pushback = 1.5,
		combat_attack_fn = "DoKnockbackAttack",
		hit_fx = monsterutil.defaultAttackHitFX,
		hit_fx_offset_x = 0.5,
		disable_self_hitstop = true,
	})
end

-- when you get hit, chance to summon a guard root at your location that deals damage 
Power.AddEquipmentPower("megatreemon_body",
{
	-- bonus damage to non-elite
	power_category = Power.Categories.DAMAGE,
	prefabs =
	{
		'megatreemon_growth_root_player'
	},

	stacks_per_usage_level = { 10, 15, 20, 25, 30, 35, 40, 45, 50 }, -- % to summon a defensive root
	tuning =
	{
		[Power.Rarity.COMMON] =
		{
			chance_to_summon = StackingVariable(1):SetPercentage(),
			root_lifetime = 5,
		},
	},

	on_add_fn = function(pow, inst)
		pow.mem.roots = {}
	end,

	on_update_fn = function(pow, inst, dt)
		-- loop through roots, do updates
		for root, time in pairs(pow.mem.roots) do
			if root.sg:HasStateTag("attack") then
				local animframe = root.AnimState:GetCurrentAnimationFrame()
				if animframe >= 2 and animframe <= 5 then
					root.components.hitbox:PushOffsetBeamFromChild(-1, -4, 2, 0, root, HitPriority.PLAYER_DEFAULT)
				elseif animframe >= 10 and animframe <= 13 then
					root.components.hitbox:PushOffsetBeamFromChild(1, 4, 2, 0, root, HitPriority.PLAYER_DEFAULT)
				end 
			end
		end
	end,

	event_triggers =
	{
		["take_damage"] = function(pow, inst, attack)
			if math.random() > pow.persistdata:GetVar("chance_to_summon") then
				return
			end

			local combatutil = require"util.combatutil"
			local pos = combatutil.GetWalkableOffsetPositionFromEnt(attack:GetAttacker(), 0, 1)
			local root = _spawn_guard_root(attack:GetTarget(), pos.x, pos.z)

			root.components.hitbox:StartRepeatTargetDelayAnimFrames(10)

			root.components.hitbox:SetHitGroup(HitGroup.PLAYER)
			root.components.hitbox:SetHitFlags(HitGroup.CREATURES | HitGroup.RESOURCE)

			root:ListenForEvent("hitboxtriggered", _on_root_hitbox)

			root:DoTaskInTime(pow.persistdata:GetVar("root_lifetime"), function()
				pow.mem.roots[root] = nil
				root:PushEvent("stop_guard")
			end)

			pow.mem.roots[root] = root
		end,
	}
})

Power.AddEquipmentPower("megatreemon_waist",
{
	-- bonus damage to non-elite
	power_category = Power.Categories.DAMAGE,
	prefabs =
	{
	},


	stacks_per_usage_level = { 1, 2, 3, 4, 5, 6 },
	tuning =
	{
		[Power.Rarity.COMMON] =
		{
		},
	},
})

Power.AddEquipmentPower("owlitzer_head",
{
	stacks_per_usage_level = { 1, 2, 3, 4, 5, 6 },
	tuning =
	{
		[Power.Rarity.COMMON] = {},
	}
})

Power.AddEquipmentPower("owlitzer_body",
{
	power_category = Power.Categories.DAMAGE,

	tags = { },
	stacks_per_usage_level = { 1, 2, 3, 4, 5, 6 },
	tuning =
	{
		[Power.Rarity.COMMON] =
		{
		},
	},
})

Power.AddEquipmentPower("owlitzer_waist",
{
	power_category = Power.Categories.DAMAGE,

	tags = { },
	stacks_per_usage_level = { 1, 2, 3, 4, 5, 6 },
	tuning =
	{
		[Power.Rarity.COMMON] =
		{
		},
	},
})


local function mothball_detect_nearby_allies(inst)
	local x, z = inst.Transform:GetWorldXZ()
	local allies = FindFriendliesInRange(x, z, 8)
	local num_allies = #allies - 1 -- (don't count yourself as an ally)

	return num_allies
end

Power.AddEquipmentPower("mothball_head",
{
	power_category = Power.Categories.DAMAGE,
	stacks_per_usage_level = { 20, 30, 40 },
	tuning =
	{
		[Power.Rarity.COMMON] =
		{
			damage_bonus = StackingVariable(1):SetPercentage(),
		},
	},

	on_add_fn = function(pow, inst)
		pow.persistdata.update_rate_ticks = 10 -- How many ticks should pass before we check our status again?
		pow.mem.ticks_left = pow.persistdata.update_rate_ticks
		pow.mem.active = false
	end,

	on_update_fn = function(pow, inst, dt)
		-- Only check every 'update_rate_ticks' ticks

		pow.mem.ticks_left = pow.mem.ticks_left - 1

		if pow.mem.ticks_left <= 0 then
			local num_allies = mothball_detect_nearby_allies(inst)
			if num_allies > 0 then
				if not pow.mem.active then
					-- Apply FX, apply damagedealtmult
					local bonus = 1 + pow.persistdata:GetVar("damage_bonus")
					inst.components.combat:SetDamageDealtMult(pow.def.name, bonus)
					powerutil.AttachParticleSystemToEntity(pow, inst, "extroverted_trail") -- TODO: add correct pfx from Sloth
					pow.mem.active = true
				end
			else
				if pow.mem.active then
					-- Remove damage bonus + FX
					powerutil.StopAttachedParticleSystem(inst, pow)
					inst.components.combat:RemoveDamageDealtMult(pow.def.name)
					pow.mem.active = false
				end
			end

			pow.mem.ticks_left = pow.persistdata.update_rate_ticks -- reset tick timer for checking for friendlies again
		end
	end,
})

Power.AddEquipmentPower("mothball_body",
{
	-- Receive less damage while fighting near an Ally
	power_category = Power.Categories.DAMAGE,
	tags = { },

	stacks_per_usage_level = { 20, 30, 40 },
	tuning =
	{
		[Power.Rarity.COMMON] =
		{
			damage_reduction = StackingVariable(1):SetPercentage(),
		},
	},

	on_add_fn = function(pow, inst)
		pow.persistdata.update_rate_ticks = 10 -- How many ticks should pass before we check our status again?
		pow.mem.ticks_left = pow.persistdata.update_rate_ticks
		pow.mem.active = false
	end,

	on_update_fn = function(pow, inst, dt)
		-- Only check every 'update_rate_ticks' ticks

		pow.mem.ticks_left = pow.mem.ticks_left - 1

		if pow.mem.ticks_left <= 0 then
			local num_allies = mothball_detect_nearby_allies(inst)
			if num_allies > 0 then
				if not pow.mem.active then
					-- Apply FX, apply damagereceivedmult
					local bonus = 1 - pow.persistdata:GetVar("damage_reduction")
					inst.components.combat:SetDamageReceivedMult(pow.def.name, bonus)
					-- powerutil.AttachParticleSystemToEntity(pow, inst, "extroverted_trail") -- TODO: add correct pfx from Sloth
					pow.mem.active = true
				end
			else
				if pow.mem.active then
					-- Remove damage mult + FX
					-- powerutil.StopAttachedParticleSystem(inst, pow)
					inst.components.combat:RemoveDamageDealtMult(pow.def.name)
					pow.mem.active = false
				end
			end

			pow.mem.ticks_left = pow.persistdata.update_rate_ticks -- reset tick timer for checking for friendlies again
		end
	end,
})

Power.AddEquipmentPower("mothball_waist",
{
	-- Gain Health when destroying a prop
	power_category = Power.Categories.SUPPORT,
	stacks_per_usage_level = { 20, 30, 40 },
	tuning =
	{
		[Power.Rarity.COMMON] =
		{
			heal_bonus = StackingVariable(1):SetPercentage(),
		},
	},

	on_add_fn = function(pow, inst)
		pow.persistdata.update_rate_ticks = 10 -- How many ticks should pass before we check our status again?
		pow.mem.ticks_left = pow.persistdata.update_rate_ticks
		pow.mem.active = false
	end,

	on_update_fn = function(pow, inst, dt)
		-- Only check every 'update_rate_ticks' ticks
		-- Doing it this way so we can attach FX and actually visualize "closeness", rather than just checking in heal_mod_fn

		pow.mem.ticks_left = pow.mem.ticks_left - 1

		if pow.mem.ticks_left <= 0 then
			local num_allies = mothball_detect_nearby_allies(inst)
			if num_allies > 0 then
				if not pow.mem.active then
					-- Apply FX, set 'active' to true so heal_mod_fn knows
					-- powerutil.AttachParticleSystemToEntity(pow, inst, "extroverted_trail") -- TODO: add correct pfx from Sloth
					pow.mem.active = true
				end
			else
				if pow.mem.active then
					-- Remove damage bonus
					-- powerutil.StopAttachedParticleSystem(inst, pow)
					pow.mem.active = false
				end
			end

			pow.mem.ticks_left = pow.persistdata.update_rate_ticks -- reset tick timer for checking for friendlies again
		end
	end,

	heal_mod_fn = function(pow, heal, output_data)
		if pow.mem.active then
			output_data.heal_delta = output_data.heal_delta + (heal:GetHeal() * (pow.persistdata:GetVar("heal_bonus")))
			return true
		end
	end,
})

Power.AddEquipmentPower("eyev_head",
{
	-- TODO: NOV2023 this power will not work over the network -- can't add a power to an entity unless you own it, and the DoTaskInTime() will break if control is lost
	-- Rework this so that "vulnerable" handles itself independently.

	power_category = Power.Categories.DAMAGE,
	stacks_per_usage_level = { 10, 20, 30 },
	tuning =
	{
		[Power.Rarity.COMMON] =
		{
			time = 5,
			debuff_stacks = StackingVariable(1):SetPercentage(),
		},
	},

	tooltips =
	{
		"IFRAME_DODGE",
	},

	event_triggers =
	{
		["newstate"] = function(pow, inst, data)
			if inst.sg:HasStateTag("dodge") and not pow.persistdata.active then
				local target = SGCommon.Fns.SanitizeTarget(data.inst)
				local debuff_def = Power.Items.STATUSEFFECT.vulnerable
				assert(debuff_def)
				if target and target.components.powermanager then
					local stacks = math.floor(pow.persistdata:GetVar("debuff_stacks") * 100)
					target.components.powermanager:AddPower(target.components.powermanager:CreatePower(debuff_def), stacks)

					target:DoTaskInTime(pow:GetVar("time"), function()
						target.components.powermanager:DeltaPowerStacks(debuff_def, -stacks)
					end)
				end
			end
		end,

		["hitboxcollided_invincible"] = function(pow, inst, data)
			if inst.sg:HasStateTag("dodge") and not pow.persistdata.active then
				local target = SGCommon.Fns.SanitizeTarget(data.inst)
				local debuff_def = Power.Items.STATUSEFFECT.vulnerable
				assert(debuff_def)
				if target and target.components.powermanager then
					local stacks = math.floor(pow.persistdata:GetVar("debuff_stacks") * 100)
					target.components.powermanager:AddPower(target.components.powermanager:CreatePower(debuff_def), stacks)

					target:DoTaskInTime(pow:GetVar("time"), function()
						target.components.powermanager:DeltaPowerStacks(debuff_def, -stacks)
					end)
				end
			end
		end,
	}
})

Power.AddEquipmentPower("eyev_body",
{
	power_category = Power.Categories.DAMAGE,
	stacks_per_usage_level = { 10, 20, 30 },
	tuning =
	{
		[Power.Rarity.COMMON] =
		{
			time = 5,
			critchance_bonus = StackingVariable(1):SetPercentage(),
		},
	},

	tooltips =
	{
		"IFRAME_DODGE",
	},

	event_triggers =
	{
		["hitboxcollided_invincible"] = function(pow, inst, data)
			if inst.sg:HasStateTag("dodge") then
				inst.components.combat:SetCritChanceModifier(pow, pow.persistdata:GetVar("critchance_bonus"))
				pow:StartPowerTimer(inst, "update_"..pow.def.name, "time")
			end
		end,

		["timerdone"] = function(pow, inst, data)
			local timer_name = "update_"..pow.def.name
			if data.name == timer_name then
				inst.components.combat:RemoveCritChanceModifier(pow)
			end
		end,
	}
})

Power.AddEquipmentPower("eyev_waist",
{
	-- Your dodge moves faster and moves through enemies.
	power_category = Power.Categories.SUPPORT,
	stacks_per_usage_level = { 10, 20, 30 }, -- % distance multiplier -- TUNED LOWER THAN CABBAGEROLL because this armor adds pass-through
	tuning =
	{
		[Power.Rarity.COMMON] = {
			percent_speed_bonus = StackingVariable(1):SetPercentage(),
		},
	},

	on_stacks_changed_fn = function(pow, inst)
		if pow.persistdata.init then
			inst.components.playerroller:RemoveTicksMultModifier(pow.def.name)
		end

		pow.persistdata.init = true
		local percent = pow.persistdata:GetVar("percent_speed_bonus")
		inst.components.playerroller:AddTicksMultModifier(pow.def.name, -percent)
	end,

	on_remove_fn = function(pow, inst)
		if pow.persistdata.init then
			pow.persistdata.init = false
			inst.components.playerroller:RemoveTicksMultModifier(pow.def.name)
		end
	end,

	event_triggers =
	{
		["newstate"] = function(pow, inst, data)
			if pow.mem.active and not inst.sg:HasStateTag("dodge") then
				inst.Physics:StopPassingThroughObjects()
				pow.mem.active = false
			end
		end,

		["dodge"] = function(pow, inst, data)
			if not pow.mem.active then
				inst.Physics:StartPassingThroughObjects()
				pow.mem.active = true
			end
		end,
	}
})

Power.AddEquipmentPower("bulbug_head",
{
	-- When a shield Blocks your attack, deal damage to them anyway.

	-- This power relies on order of operations.
	-- damage_mod_fn happens first, at which point we still know what amount of damage the attack was trying to do
	-- then, do_damage is triggered after the attack is resolved. the "damage" at this point is modified, so it may be "1" because a shield broke it
	-- if the shield got broken, then go back and see how much damage we tried to do and then use that as our basis

	power_category = Power.Categories.DAMAGE,
	stacks_per_usage_level = { 300, 500, 700 },
	tuning =
	{
		[Power.Rarity.COMMON] =
		{
			damage_mult_of_blocked_attack = StackingVariable(1):SetPercentage(),
		},
	},

	damage_mod_fn = function(pow, attack, output_data)
		if attack:GetAttacker() ~= attack:GetTarget() then
			pow.mem.attempted_damage = attack:GetDamage() -- Store the amount of damage we tried to do
			return true
		end
	end,

	event_triggers =
	{
		["do_damage"] = function(pow, inst, attack)
			-- We don't have a strong and direct way to tell if we just broke someone's shield...
			-- But at the time of this event, they still have shield
			-- If we determine that the attack IS going to do damage, we know that we will break their shield.
			-- If the attack did 0 damage, it will not break their shield.

			local target = attack:GetTarget()
			local pm = target.components.powermanager
			if pm then
				local shield_def = Power.Items.SHIELD.shield
				local stacks = pm:GetPowerStacks(shield_def)
				if stacks == shield_def.max_stacks then
					local damage_dealt = attack:GetDamage()
					if damage_dealt > 0 and pow.mem.attempted_damage then
						-- This will only be true if their shield broke.

						local damage = pow.mem.attempted_damage * pow.persistdata:GetVar("damage_mult_of_blocked_attack")

						local power_attack = Attack(inst, target)
						power_attack:SetDamage(damage)
						power_attack:CloneChainDataFromAttack(attack)
						power_attack:SetSource(pow.def.name)
						power_attack:SetHitstunAnimFrames(12)
						power_attack:SetPushback(0)
						inst:DoTaskInAnimFrames(7, function(inst)
							if SGCommon.Fns.SanitizeTarget(inst) and SGCommon.Fns.SanitizeTarget(target) then
								inst.components.combat:DoPowerAttack(power_attack)
								powerutil.SpawnPowerHitFx("hits_volatile", inst, target, 0, 0, HitStopLevel.NONE)
							end
						end)
					end
				end
			end

			-- Reset our attempted damage, to get ready for the next attack.
			pow.mem.attempted_damage = nil
		end
	}
})


Power.AddEquipmentPower("bulbug_body",
{
	power_category = Power.Categories.SUPPORT,
	stacks_per_usage_level = { 1, 2, 3 },
	tuning =
	{
		[Power.Rarity.COMMON] =
		{
			shield_segments = StackingVariable(1):SetFlat(),
		},
	},

	tooltips =
	{
	},

	event_triggers =
	{
		["do_damage"] = function(pow, inst, attack)
			-- We don't have a strong and direct way to tell if we just broke someone's shield...
			-- But at the time of this event, they still have shield
			-- If we determine that the attack IS going to do damage, we know that we will break their shield.
			-- If the attack did 0 damage, it will not break their shield.

			local target = attack:GetTarget()
			local pm = target.components.powermanager
			if pm then
				local shield_def = Power.Items.SHIELD.shield
				local stacks = pm:GetPowerStacks(shield_def)
				if stacks == shield_def.max_stacks then
					local segments = pow.persistdata:GetVar("shield_segments")
					inst.components.powermanager:AddPowerByName("shield", segments)
					return true
				end
			end
		end
	}
})

Power.AddEquipmentPower("bulbug_waist",
{
	-- When you get a full shield, break shield and explode.

	power_category = Power.Categories.DAMAGE,
	stacks_per_usage_level = { 100, 150, 200 },
	tuning =
	{
		[Power.Rarity.COMMON] =
		{
			weapon_damage_percent = StackingVariable(1):SetPercentage(),
		},
	},

	tooltips =
	{
	},

	event_triggers =
	{
		["power_stacks_changed"] = function(pow, inst, data)
			local shield_def = Power.Items.SHIELD.shield
			if data.power_def == shield_def then
				if data.new == shield_def.max_stacks then
					pow.mem.pending_break = true -- So any incoming attacks don't deal damage

					local x,z = inst.Transform:GetWorldXZ()
					local radius = 8
					local ents_near, ents_med, ents_far = powerutil.GetEntitiesInRangesFromPoint(x, z, radius)

					local initial_delay = 15
					inst:DoTaskInAnimFrames(initial_delay, function()
						inst:PushEvent("shield_force_break")
					end)

					local damage = inst.components.combat:GetBaseDamage()
					damage = damage * pow.persistdata:GetVar("weapon_damage_percent")
					local function do_attack(ent)
						local power_attack = Attack(inst, ent)
						power_attack:SetDamage(damage)
						power_attack:SetHitstunAnimFrames(10)
						power_attack:SetPushback(2)
						power_attack:SetSource(pow.def.name)
						inst.components.combat:DoPowerAttack(power_attack)
						powerutil.SpawnPowerHitFx("hits_volatile", inst, ent, 0, 0, 0)
					end

					for i, ent in ipairs(ents_near) do
						-- Wait at least 2 frame because first we attack ourselves.
						inst:DoTaskInAnimFrames(math.random(initial_delay + 2, initial_delay + 4), function()
							if SGCommon.Fns.SanitizeTarget(ent) then
								do_attack(ent)
							end
						end)
					end
					for i, ent in ipairs(ents_med) do
						inst:DoTaskInAnimFrames(math.random(initial_delay + 4, initial_delay + 6), function()
							if SGCommon.Fns.SanitizeTarget(ent) then
								do_attack(ent)
							end
						end)
					end
					for i, ent in ipairs(ents_far) do
						inst:DoTaskInAnimFrames(math.random(initial_delay + 6, initial_delay + 8), function()
							if SGCommon.Fns.SanitizeTarget(ent) then
								do_attack(ent)
							end
						end)
					end
				end
			end
		end,
	},
})

Power.AddEquipmentPower("groak_head",
{
	-- Heavy attacks apply more hitstun
	power_category = Power.Categories.DAMAGE,
	stacks_per_usage_level = { 20, 35, 50 },
	tuning = {
		[Power.Rarity.COMMON] = {
			bonus_percent = StackingVariable(1):SetPercentage(),
		},
	},

	tooltips =
	{
	},

	damage_mod_fn = function(pow, attack, output_data)
		if attack:IsHeavyAttack() then
			local default = attack:GetHitstunAnimFrames()
			local bonus = lume.round(default * pow.persistdata:GetVar("bonus_percent"))
			attack:SetHitstunAnimFrames(default + bonus)
		end
	end,
})

Power.AddEquipmentPower("groak_body",
{
	power_category = Power.Categories.DAMAGE,

	tags = { POWER_TAGS.PROVIDES_CRITCHANCE },
	stacks_per_usage_level = { 33, 66, 100 },
	tuning = {
		[Power.Rarity.COMMON] = {
			pull_factor = StackingVariable(1):SetPercentage(),
		},
	},

	tooltips =
	{
	},

	damage_mod_fn = function(pow, attack, output_data)
		if attack:IsHeavyAttack() then
			local default = attack:GetPushback()
			local mult = pow.persistdata:GetVar("pull_factor")
			attack:SetPushback(default * mult * -1)
		end
	end,
})

Power.AddEquipmentPower("groak_waist",
{
	power_category = Power.Categories.SUPPORT,

	tags = { },
	stacks_per_usage_level = { 33, 66, 100 },
	tuning =
	{
		[Power.Rarity.COMMON] =
		{
			chance = StackingVariable(1):SetPercentage(),
		},
	},

	heal_mod_fn = function(pow, heal, output_data)
		-- Nullify heals given by spores.
		local healer = heal:GetAttacker()

		if SGCommon.Fns.SanitizeTarget(healer) and healer:HasTag("spore") then
			local roll = math.random()
			if roll <= pow.persistdata:GetVar("chance") then
				local amt = heal:GetHeal()
				if amt > 0 then
					output_data.heal_delta = -amt
				end
			end
		end

		return true
	end,

	defend_mod_fn = function(pow, attack, output_data)
		-- Nullify damage dealt by spores.

		local attacker = attack:GetAttacker()

		if SGCommon.Fns.SanitizeTarget(attacker) and attacker:HasTag("spore") then
			local roll = math.random()
			if roll <= pow.persistdata:GetVar("chance") then
				local dmg = attack:GetDamage()
				if dmg > 0 then
					output_data.damage_delta = -dmg
				end
			end
		end

		return true
	end,

	event_triggers =
	{
		["add_power"] = function(pow, inst, added_power)
			--[[
			jambell: 
				I don't love the way this is implemented... this still goes through the entire add/remove flow. Sounds still play, etc.
				We would ideally insert ourselves into the addpower flow to see if anything wants to negate the adding of a power.
			]]
			local roll = math.random()
			if roll <= pow.persistdata:GetVar("chance") then
				local relevant_powers = { "confused", "juggernaut", "smallify" }
				local pow_name = added_power.def.name
				if table.contains(relevant_powers, pow_name) then
					inst:PushEvent("juggernaut_force_remove")
					inst.components.powermanager:RemovePower(added_power.def, true)
				end
			end
		end,
	}
})

Power.AddEquipmentPower("floracrane_head",
{
	power_category = Power.Categories.DAMAGE,
	stacks_per_usage_level = { 5, 7, 10, 13, 16, 20 },
	tuning = {
		[Power.Rarity.COMMON] = {
			bonus = StackingVariable(5):SetPercentage(),
		},
	},

	tooltips =
	{
		"CRITICAL_HIT",
	},

	damage_mod_fn = function(pow, attack, output_data)
		if attack:GetFocus() then
			attack:DeltaBonusCritDamageMult(pow.persistdata:GetVar("bonus"))
			return true
		end
	end,
})

Power.AddEquipmentPower("floracrane_body",
{
	power_category = Power.Categories.DAMAGE,

	tags = { POWER_TAGS.PROVIDES_CRITCHANCE },
	stacks_per_usage_level = { 5, 7, 10, 13, 16, 20 },
	tuning = {
		[Power.Rarity.COMMON] = {
			bonus = StackingVariable(1):SetPercentage(),
		},
	},

	tooltips =
	{
		"FOCUS_HIT",
		"CRIT_CHANCE",
		"CRITICAL_HIT",
	},

	damage_mod_fn = function(pow, attack, output_data)
		if attack:GetFocus() then
			attack:DeltaBonusCritChance(pow.persistdata:GetVar("bonus"))
			return true
		end
	end,
})

Power.AddEquipmentPower("floracrane_waist",
{
	power_category = Power.Categories.DAMAGE,

	tags = { },
	stacks_per_usage_level = { 1, 2, 3 },
	tuning =
	{
		[Power.Rarity.COMMON] =
		{
		},
	},
})

Power.AddEquipmentPower("bandicoot_head",
{
	power_category = Power.Categories.DAMAGE,
	stacks_per_usage_level = { 5, 7, 10, 13, 16, 20, 24, 28, 35 },
	tuning =
	{
		[Power.Rarity.COMMON] =
		{
			chance = StackingVariable(0.25, 1.25):SetPercentage(),
		},
	},

	event_triggers =
	{
		["do_damage"] = function(pow, inst, attack)
			if math.random() <= pow:GetVar("chance") then
				local target = attack:GetTarget()
				local multistrike_attack = Attack(inst, target)
				multistrike_attack:SetDamage(attack:GetDamage())
				multistrike_attack:SetID(attack:GetID())
				multistrike_attack:SetPushback(0)
				multistrike_attack:SetHitstunAnimFrames(0)

				inst:DoTaskInAnimFrames(math.random(5, 10), function()
					if target:IsValid() then
						inst.components.combat:DoPowerAttack(multistrike_attack)
					end
				end)
			end
		end,
	},
})

Power.AddEquipmentPower("bandicoot_body",
{
	power_category = Power.Categories.DAMAGE,

	tags = { POWER_TAGS.PROVIDES_CRITCHANCE },
	stacks_per_usage_level = { 1, 2, 3 },
	tuning = {
		[Power.Rarity.COMMON] = {
			bonus = StackingVariable(1):SetPercentage(),
		},
	},

	tooltips =
	{
		"FOCUS_HIT",
		"CRIT_CHANCE",
		"CRITICAL_HIT",
	},

	damage_mod_fn = function(pow, attack, output_data)
		if attack:GetFocus() then
			attack:DeltaBonusCritChance(pow.persistdata:GetVar("bonus"))
			return true
		end
	end,
})

Power.AddEquipmentPower("bandicoot_waist",
{
	power_category = Power.Categories.DAMAGE,

	tags = { },
	stacks_per_usage_level = { 1, 2, 3 },
	tuning =
	{
		[Power.Rarity.COMMON] =
		{
		},
	},
})

-- increase stats
	-- luck
	-- health
	-- crit
	-- movespeed
	-- damage reduction

-- when you crit, ...
	-- heal
	-- + movespeed

-- when you heal, ...
	-- heal a nearby ally for x% of the healing amount

-- when hitting from behind, ...
	-- extra crit chance
	-- extra damage

-- when doing a focus hit, ...
	-- extra crit chance

-- increase movespeed during dodge

-- when you use your skill, ...

-- % damage reduction
	-- melee damage
	-- projectile damage
	-- trap damage
	-- all damage
	-- from behind
	-- from infront
	-- from bosses
	-- from elites
	-- from regular mobs
	-- based on # of nearby enemies
	-- while attacking

-- % damage increase
	-- to elites
	-- to bosses
	-- to regular mobs
	-- light attacks
	-- heavy attacks
	-- when airborne
	-- focus hits
	-- to far enemies
	-- to close enemies
	-- based on # of nearby enemies
	-- to airborne/ flying enemies

-- Deal AoE damage when ...
	-- kill
	-- crit
	-- focus hit

-- can't be knocked back

-- % damage reduction while attacking

-- % health recovery (attack immediately after taking damage)

-- when you quickrise, ...

-- when you prefect dodge, ...
	-- buff next attack
	-- apply debuff to enemy (flat footed?)

-- % cost reduction in shops

-- if you took 0 damage in a room, ...

-- if you clear a room quickly, ...

-- when on a hitstreak above X, ...

-- _____ drop more loot

-- enemies you knockback deal damage

-- cannot be pushed/ pulled

-- attacks push/ pull enemies

-- Does something when your allies are doing well?
	-- whenever something that you damaged dies, do X

-- powers that make it so you can't help but help your allies out
	-- apply weakness/ other status effects

-- as you dodge, build static charge. When you get hit, apply that static charge?

-- when you attack an enemy that's in the windup for an attack, ...

-- if you haven't been attacked in X seconds, ...

-- for the first X seconds after entering a room, ...

-- when you take fatal damage, ...
	-- leave you with 1 health instead?
	-- revive, but reduce max health?

-- for every person in the party with this equipped, ...

-- for every ally, ...

-- every room, give yourself a random power for that room

-- killing an enemy creates a spore explosion of a random type

-- whenever you gain teffra
-- 		-- have a chance of gaining +10% teffra

-- gain health when you destroy a destructible prop

-- deal extra damage to enemies during:
--		-- recovery frames
--		-- startup frames

-- konjur related
--		deal bonus damage based on konjur amount
--		reduce damage based on konjur amount
