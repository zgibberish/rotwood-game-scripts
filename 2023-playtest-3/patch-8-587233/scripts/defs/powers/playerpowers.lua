local Power = require("defs.powers.power")

-- for specific powers
local Consumable = require "defs.consumable"
local EffectEvents = require "effectevents"
local SGCommon = require "stategraphs.sg_common"
local combatutil = require "util.combatutil"
local easing = require("util.easing")
local fmodtable = require "defs.sound.fmodtable"
local krandom = require "util.krandom"
local soundutil = require "util.soundutil"
local powerutil = require "util.powerutil"
local LootEvents = require "lootevents"
require "util.kstring"
require "prefabs"

-- FX helper, counter text functions are found in 'powerutil'

function Power.AddPlayerPower(id, data)
	data.power_type = Power.Types.RELIC
	Power.AddPower(Power.Slots.PLAYER, id, "player_powers", data)
end

Power.AddPowerFamily("PLAYER", nil, 20)

Power.AddPlayerPower("snowball_effect",
{
	power_category = Power.Categories.DAMAGE,

	tooltips =
	{
		function()
			return Power.POWER_AS_TOOLTIP_FMT:subfmt(STRINGS.ITEMS.PLAYER.damage_until_hit)
		end,
	},

	tuning = {
		[Power.Rarity.EPIC] = { stacks = 1 },
		[Power.Rarity.LEGENDARY] = { stacks = 3 },
	},

	on_add_fn = function(pow, inst)
		local buff_def = Power.Items.PLAYER.damage_until_hit
		inst.components.powermanager:AddPower(inst.components.powermanager:CreatePower(buff_def), 0)
	end,

	event_triggers =
	{
		["kill"] = function(pow, inst, data)
			local victim = data.attack:GetTarget()
			if victim and not victim:HasTag("prop") then
				local buff_def = Power.Items.PLAYER.damage_until_hit
				inst.components.powermanager:AddPower(inst.components.powermanager:CreatePower(buff_def), pow.persistdata:GetVar("stacks"))
				inst:PushEvent("used_power", pow.def)

			end
		end,
	}
})

Power.AddPlayerPower("damage_until_hit",
{
	power_category = Power.Categories.DAMAGE,

	tuning = {
		[Power.Rarity.LEGENDARY] = {},
	},

	stackable = true,
	can_drop = false,
	selectable = false,
	permanent = true,

	damage_mod_fn = function(pow, attack, output_data)
		local damage_mod = (pow.persistdata.stacks or 0) * 0.01
		output_data.damage_delta = output_data.damage_delta + (attack:GetDamage() * damage_mod)
		return true
	end,

	get_counter_text = powerutil.GetCounterTextPlusPercent,

	on_add_fn = function(pow, inst)
		pow.persistdata.counter = 0
		inst:PushEvent("update_power", pow.def)
	end,

	on_stacks_changed_fn = function(pow, inst)
		pow.persistdata.counter = pow.persistdata.stacks
		inst:PushEvent("update_power", pow.def)
	end,

	event_triggers =
	{
		["enter_room"] = function(pow, inst, data)
			-- update the UI to show percentage
			pow.persistdata.counter = pow.persistdata.stacks
			inst:PushEvent("update_power", pow.def)
		end,
		["healthchanged"] = function(pow, inst, data)
			if data.hurt and not data.silent then
				inst.components.powermanager:SetPowerStacks(pow.def, 0)
			end
		end,
	}
})


Power.AddPlayerPower("undamaged_target",
{
	power_category = Power.Categories.DAMAGE,
	tuning = {
		[Power.Rarity.COMMON] = { bonus = 25, },
		[Power.Rarity.EPIC] = { bonus = 50, },
		[Power.Rarity.LEGENDARY] = { bonus = 75, },
	},
	damage_mod_fn = function(pow, attack, output_data)
		local target = attack:GetTarget()
		if target and target.components.health and target.components.health:GetPercent() >= 1 then
			local bonus_damage = attack:GetDamage() * (pow.persistdata:GetVar("bonus") * 0.01)
			output_data.damage_delta = output_data.damage_delta + bonus_damage
			return true
		end
	end,
})

Power.AddPlayerPower("thorns",
{
	power_category = Power.Categories.DAMAGE,
	tuning = {
		[Power.Rarity.COMMON] = { reflect = 250, },
		[Power.Rarity.EPIC] = { reflect = 500, },
		[Power.Rarity.LEGENDARY] = { reflect = 750, },
	},
	prefabs = { "fx_relics_retaliation_player", "fx_relics_retaliation_target" },

	event_triggers =
	{
		["take_damage"] = function(pow, inst, attack)
			if attack:GetDamage() > 0 and attack:GetAttacker() ~= attack:GetTarget() and attack:GetAttacker().components.health then
				local thorn_recipient = attack:GetAttacker()
				local inst = attack:GetTarget()

				local relatiation_attack = Attack(inst, thorn_recipient)
				relatiation_attack:SetDamage(pow.persistdata:GetVar("reflect"))
				relatiation_attack:SetSource(pow.def.name)
				relatiation_attack:SetID(pow.def.name)
				relatiation_attack:SetPushback(1)
				relatiation_attack:SetHitstunAnimFrames(10)

				--FX
				powerutil.SpawnFxOnEntity("fx_relics_retaliation_player", inst)
				local distance_to_delay =
				{
					{ 0, 2 },
					{ 5, 4 },
					{ 10, 6 },
					{ 15, 8 },
				}
				if thorn_recipient ~= nil and inst ~= nil then
					local dist = inst:GetDistanceSqTo(thorn_recipient)
					local delay = PiecewiseFn(math.sqrt(dist), distance_to_delay)
					thorn_recipient:DoTaskInAnimFrames(math.ceil(delay), function()
						if thorn_recipient ~= nil and inst ~= nil then
							inst.components.combat:DoPowerAttack(relatiation_attack)
							powerutil.SpawnPowerHitFx("fx_relics_retaliation_target", inst, thorn_recipient, 0, 1, HitStopLevel.HEAVY)
						end
					end)
				end
				return true
			end
		end
	}
})

Power.AddPlayerPower("heal_on_focus_kill",
{
	power_category = Power.Categories.SUSTAIN,
	tags = { POWER_TAGS.PROVIDES_FREQUENT_HEALING, POWER_TAGS.PROVIDES_HEALING },
	tuning = {
		[Power.Rarity.EPIC] = { heal = 5, },
		[Power.Rarity.LEGENDARY] = { heal = 10, },
	},
	tooltips =
	{
		"FOCUS_HIT",
	},
	event_triggers =
	{
		["kill"] = function(pow, inst, data)
			if powerutil.TargetIsEnemyOrDestructibleProp(data.attack) and data.attack:GetFocus() then
				local power_heal = Attack(inst, inst)
				power_heal:SetHeal(pow.persistdata:GetVar("heal"))
				power_heal:SetSource(pow.def.name)
				inst.components.combat:ApplyHeal(power_heal)
				inst:PushEvent("used_power", pow.def)
			end
		end,
	}
})

Power.AddPlayerPower("berserk",
{
	power_category = Power.Categories.DAMAGE,
	tuning = {
		[Power.Rarity.EPIC] = { health = 500, bonus = 50 },
		[Power.Rarity.LEGENDARY] = { health = 250, bonus = 100 },
	},
	damage_mod_fn = function(pow, attack, output_data)
		if attack:GetAttacker().components.health:GetCurrent() < pow.persistdata:GetVar("health") then
			local bonus_damage = attack:GetDamage() * (pow.persistdata:GetVar("bonus") * 0.01)
			output_data.damage_delta = output_data.damage_delta + bonus_damage
			return true
		end
	end,
})

Power.AddPlayerPower("max_health_and_heal",
{
	power_category = Power.Categories.SUSTAIN,
	tuning =
	{
		-- [Power.Rarity.EPIC] = { health = 100 },
		[Power.Rarity.LEGENDARY] = { health = 500 },
	},

	on_add_fn = function(pow, inst)
		if not pow.persistdata.did_init then
			inst.components.health:AddHealthAddModifier(pow.def.name, pow.persistdata:GetVar("health"))

			local power_heal = Attack(inst, inst)
			power_heal:SetHeal(inst.components.health:GetMissing())
			power_heal:SetSource(pow.def.name)
			inst.components.combat:ApplyHeal(power_heal)
			pow.persistdata.did_init = true
		end
	end,

	on_remove_fn = function(pow, inst)
		pow.persistdata.did_init = false
	end,
})

Power.AddPlayerPower("bomb_on_dodge", -- should make sure the landing spot is valid tile. LEGENDARY: spawn multiple bombs? you're already doing chaos, let's have some more
									  -- could make it closer? 5-7 instead of 5-10?
									  -- TODO: refill charge by getting a hitstreak, not time-based cooldown?
{
	power_category = Power.Categories.DAMAGE,
	prefabs = { "megatreemon_bomb_projectile", "trap_bomb_pinecone", GroupPrefab("fx_warning"), },

	tuning =
	{
		[Power.Rarity.EPIC] = { cd = 10, num_bombs = 1, text = STRINGS.ITEMS.PLAYER.bomb_on_dodge.text_single }, --TODO: move to localizable
		[Power.Rarity.LEGENDARY] = { cd = 10, num_bombs = 2, text = STRINGS.ITEMS.PLAYER.bomb_on_dodge.text_multiple },
	},

	event_triggers =
	{
		["dodge"] = function(pow, inst, data)
			if not inst.components.timer:HasTimer(pow.def.name) then
				for i = 1, pow.persistdata:GetVar("num_bombs"), 1 do
					local bomb = SpawnPrefab("megatreemon_bomb_projectile", inst)
					local pos = inst:GetPosition()
					pos.y = 0
					bomb.Transform:SetPosition(pos.x, 2, pos.z)
					local target_pos = combatutil.GetWalkableOffsetPosition(inst:GetPosition(), 5, 10)
					inst.components.timer:StartTimer(pow.def.name, pow.persistdata:GetVar("cd"))
					bomb:PushEvent("thrown", {x = target_pos.x, z = target_pos.z})
					inst:PushEvent("used_power", pow.def)
				end
			end
		end,
	}
})

-- make sure things like Volatile Weaponry respect this, then make sure this is explained in a way that shows it triggers other powers
-- could do Attack Die as a common powerup, 1d6 instea
Power.AddPlayerPower("attack_dice",
{
	power_category = Power.Categories.DAMAGE,
	tuning =
	{
		[Power.Rarity.EPIC] = { min = 1, max = 6, count = 1 },
		[Power.Rarity.LEGENDARY] = { min = 1, max = 6, count = 2 },
	},

	event_triggers =
	{
		["do_damage"] = function(pow, inst, attack)
			local victim = attack:GetTarget()
			if victim ~= inst and attack:CheckChain(pow.def.name) == nil then
				local used_power = false
				local count = pow.persistdata:GetVar("count")
				for i = 1, count do
					if not victim:IsValid() then
						break
					end
					local power_attack = Attack(inst, victim)
					power_attack:CloneChainDataFromAttack(attack)
					power_attack:SetSource(pow.def.name)
					power_attack:SetDamage(math.random(pow.persistdata:GetVar("min"), pow.persistdata:GetVar("max")))
					power_attack:SetID(pow.def.name)
					power_attack:SetPushback(0)
					power_attack:SetHitstunAnimFrames(0)

					inst:DoTaskInAnimFrames(math.random(5, 10), function()
						if victim:IsValid() then
							inst.components.combat:DoPowerAttack(power_attack) --DO NORMAL ATTACK
							if victim.SoundEmitter then
								local params = {}
								params.fmodevent = fmodtable.Event.Power_AttackDice
								local dice_sound = soundutil.PlaySoundData(victim, params)
								soundutil.SetInstanceParameter(victim, dice_sound, "upgrade_level", Power.GetRarityAsParameter(pow.persistdata))
							end
						end
					end)
					-- May not actually apply the power if they die too soon
					-- (especially if the first dice kills).
					used_power = true

					-- do I need to copy the chain over from the last attack?
				end
				if used_power then
					inst:PushEvent("used_power", pow.def)
				end
			end
		end,
	}
})

Power.AddPlayerPower("running_shoes",
{
	power_category = Power.Categories.SUPPORT,
	tuning =
	{
		[Power.Rarity.COMMON] = { speed = 20 },
		[Power.Rarity.EPIC] = { speed = 35 },
		[Power.Rarity.LEGENDARY] = { speed = 50 },
	},
	tags = { POWER_TAGS.PROVIDES_MOVESPEED },

	on_add_fn = function(pow, inst)
		if not pow.persistdata.did_init and inst.components.locomotor ~= nil then
			inst.components.locomotor:AddSpeedMult(pow.def.name, pow.persistdata:GetVar("speed") * 0.01)
			pow.persistdata.did_init = true
		end
	end,

	on_remove_fn = function(pow, inst)
		if inst.components.locomotor ~= nil then
			inst.components.locomotor:RemoveSpeedMult(pow.def.name)
		end
		pow.persistdata.did_init = false
	end,
})

-- jambell: disabling this one for now because it encourages players to avoid every other power in the game to feed this one.
-- 			it could work as a powerful Epic or a Legendary, maybe? because then it would be a build-around power when appearing rarely

-- Power.AddPlayerPower("coin_purse", --figure out the math on the upgrade of this one... must be worth spending the konjur
-- {
-- 	tuning =
-- 	{
-- 		[Power.Rarity.COMMON] = { currency = 100, bonus = 10 },
-- 		[Power.Rarity.EPIC] = { currency = 100, bonus = 20 }, --75 to upgrade     --- NOTE this epic and legendary value is not intentionally tuned! math to be done!
-- 		[Power.Rarity.LEGENDARY] = { currency = 100, bonus = 30 }, --150 to upgrade
-- 	},

-- 	damage_mod_fn = function(pow, attack, output_data)
-- 		local inventory
-- 		local attacker = attack:GetAttacker()
-- 		inventory = attacker.components.inventoryhoard
-- 		local konjur = inventory:GetStackableCount(Consumable.Items.MATERIALS.konjur)
-- 		local damage_mod = math.floor((konjur / pow.persistdata:GetVar("currency")) + 0.5) * (pow.persistdata:GetVar("bonus") * 0.01)
-- 		output_data.damage_delta = output_data.damage_delta + (attack:GetDamage() * damage_mod)
-- 		return true
-- 	end,
-- })

local extended_range_fn = function(pow, inst)
	pow.persistdata.counter = (pow.persistdata.counter or 0) + 1
	if pow.persistdata.counter >= pow.persistdata:GetVar("swings") then
		if pow.persistdata:GetVar("projectiles") == 1 then
			local bullet = SGCommon.Fns.SpawnAtDist(inst, "generic_projectile", 3.5) -- generic_projectile is already networked on the prefab level
			bullet:Setup(inst, pow.persistdata:GetVar("damage") * 0.01, pow.def.name)
		else
			local bullet = SGCommon.Fns.SpawnAtAngleDist(inst, "generic_projectile", 3.5, -15)
			bullet:Setup(inst, pow.persistdata:GetVar("damage") * 0.01, pow.def.name) -- generic_projectile is already networked on the prefab level

			local bullet2 = SGCommon.Fns.SpawnAtDist(inst, "generic_projectile", 3.5)
			bullet2:Setup(inst, pow.persistdata:GetVar("damage") * 0.01, pow.def.name) -- generic_projectile is already networked on the prefab level

			local bullet3 = SGCommon.Fns.SpawnAtAngleDist(inst, "generic_projectile", 3.5, 15)
			bullet3:Setup(inst, pow.persistdata:GetVar("damage") * 0.01, pow.def.name) -- generic_projectile is already networked on the prefab level
		end
		pow.persistdata.counter = 0
		inst:PushEvent("used_power", pow.def)
	end
	inst:PushEvent("update_power", pow.def)
end

Power.AddPlayerPower("extended_range",
{
	power_category = Power.Categories.DAMAGE,
	tuning =
	{
		[Power.Rarity.EPIC] = { swings = 3, damage = 200, projectiles = 1, description = STRINGS.ITEMS.PLAYER.extended_range.epic_desc }, --TODO: tuning, this is OP. essentially "every 3rd attack deals triple damage" vs pump+dump's "every 5th attack deals double damage"
		[Power.Rarity.LEGENDARY] = { swings = 3, damage = 150, projectiles = 3, description = STRINGS.ITEMS.PLAYER.extended_range.legendary_desc }, --TODO: also too much DPS
	},

	prefabs = { "generic_projectile" },
	event_triggers =
	{
		["attack_start"] = extended_range_fn,
		["projectile_launched"] = extended_range_fn,
	}
})

Power.AddPlayerPower("bloodthirsty",
{
	power_category = Power.Categories.SUSTAIN,
	tags = { POWER_TAGS.PROVIDES_FREQUENT_HEALING, POWER_TAGS.PROVIDES_HEALING },
	tuning =
	{
		[Power.Rarity.LEGENDARY] = { time = 5, damage = 50, heal = 10, health_penalty = 50, blink_color = { 255/255, 50/255, 50/255, 1 }, blink_frames = 8 }, -- TODO(sloth): adjust blink color/frames
	},

	on_add_fn = function(pow, inst)
		pow:StartPowerTimer(inst, "update_"..pow.def.name)
		if not pow.persistdata.did_init then
			pow.persistdata.did_init = true
			inst.components.health:AddHealthMultModifier(pow.def.name, 1 - (pow.persistdata:GetVar("health_penalty") * 0.01))
		end
	end,

	on_remove_fn = function(pow, inst)
		pow.persistdata.did_init = false
		inst.components.health:RemoveHealthMultModifier(pow.def.name)
	end,

	event_triggers =
	{
		["do_damage"] = function(pow, inst, attack)
			-- We only heal if there are enemies to attack.
			local is_attacking_with_enemies = attack:GetTarget() ~= inst and powerutil.TargetIsEnemyOrDestructibleProp(attack) and not TheWorld.components.roomclear:IsRoomComplete()
			local is_alive = attack:GetAttacker():IsAlive()
			if is_attacking_with_enemies and is_alive then
				local heal_amount = math.ceil(attack:GetDamage() * (pow.persistdata:GetVar("heal") * 0.01))
				if heal_amount >= 1 then
					local power_heal = Attack(inst, inst)
					power_heal:SetHeal(heal_amount)
					power_heal:SetSource(pow.def.name)
					inst.components.combat:ApplyHeal(power_heal)

					inst:PushEvent("used_power", pow.def)
				end
			end
		end,
		["timerdone"] = function(pow, inst, data)
			local timer_name = "update_"..pow.def.name
			if data.name == timer_name then
				inst.components.timer:StartTimer(timer_name, pow.persistdata:GetVar("time"))
				if not TheWorld.components.roomclear:IsRoomComplete() then
					local damage = math.min(inst.components.health:GetCurrent() - 1, pow.persistdata:GetVar("damage"))
					if damage > 0 then
						local power_attack = Attack(inst, inst)
						power_attack:SetDamage(damage)
						power_attack:SetIgnoresArmour(true)
						power_attack:SetSkipPowerDamageModifiers(true)
						power_attack:SetSource(pow.def.name)
						power_attack:SetCannotKill(true)
						inst.components.combat:DoPowerAttack(power_attack)
						powerutil.SpawnParticlesAtPosition(inst:GetPosition(), "burst_bloodthirsty", 1, inst)
						SGCommon.Fns.BlinkAndFadeColor(inst, pow.persistdata:GetVar("blink_color"), pow.persistdata:GetVar("blink_frames"))
						inst:PushEvent("used_power", pow.def)
					end
				end
			end
		end,
	},
})

Power.AddPlayerPower("lucky_revive",
{
	power_category = Power.Categories.SUSTAIN,
	show_in_ui = false,
	can_drop = false,
	selectable = false,

	event_triggers =
	{
		["process_lucky_revive"] = function(pow, inst, data)
			if inst.components.lucky:DoLuckRoll() then
				local lucky_heal = Attack(inst, inst)
				lucky_heal:SetHeal( inst.components.health:GetMax() * 0.33 )
				lucky_heal:SetSource("luck")
				lucky_heal:SetHealForced(true)
				inst.components.combat:ApplyHeal(lucky_heal)
				inst.components.hitstopper:PushHitStop(1)
				--sound
				local params = {}
				params.fmodevent = fmodtable.Event.revive
				params.sound_max_count = 1
				soundutil.PlaySoundData(inst, params)

				TheLog.ch.Player:printf("Lucky Revived!")
			end
		end,

		["canactuallydie"] = function(pow, inst, data)
			return inst.components.health:GetCurrent() <= 0
		end,
	}
})

Power.AddPlayerPower("mulligan",
{
	power_category = Power.Categories.SUSTAIN,
	tuning =
	{
		[Power.Rarity.EPIC] = { heal = 50 },
		[Power.Rarity.LEGENDARY] = { heal = 100 },
	},

	event_triggers =
	{
		["death_landed"] = function(pow, inst, data)
			-- Don't proc if the player already has health; allows for lucky revive to proc instead of this.
			if inst.components.health:GetCurrent() > 0 then
				return
			end

			local playerutil = require "util.playerutil"
			if playerutil.AreAllPlayersDead() then
				TheAudio:StartFMODSnapshot(fmodtable.Snapshot.PitchMusicDown24Semitones)
			end

			inst:PushEvent("used_power", pow.def)
			local power_heal = Attack(inst, inst)
			power_heal:SetHeal(inst.components.health:GetMax() * (pow.persistdata:GetVar("heal") * 0.01))
			power_heal:SetSource(pow.def.name)
			power_heal:SetHealForced(true)
			inst.components.combat:ApplyHeal(power_heal)

			inst.components.powermanager:RemovePower(pow.def)

			inst.HitBox:SetInvincible(true)
			SGCommon.Fns.FlickerColor(inst, TUNING.FLICKERS.POWERS.MULLIGAN.COLOR, TUNING.FLICKERS.POWERS.MULLIGAN.FLICKERS, TUNING.FLICKERS.POWERS.MULLIGAN.FADE, TUNING.FLICKERS.POWERS.MULLIGAN.TWEENS)
			inst:DoTaskInAnimFrames(TUNING.PLAYER.ROLL.NORMAL.IFRAMES * 2, function() inst.HitBox:SetInvincible(false) end)

			-- local fx_pos = inst:GetPosition()
			powerutil.SpawnParticlesAtPosition(inst:GetPosition(), "player_revive", 1, inst)

			--sound
			local params = {}
			params.fmodevent = fmodtable.Event.Power_Mulligan_Revive
			soundutil.PlaySoundData(inst, params)

			TheAudio:StopFMODSnapshot(fmodtable.Snapshot.PitchMusicDown24Semitones)
			TheAudio:StopFMODSnapshot(fmodtable.Snapshot.Mute_Music_NonMenuMusic) -- undoes this snapshot, which otherwise would persist until relod
			TheAudio:StopFMODSnapshot(fmodtable.Snapshot.Mute_Ambience_Bed) -- undoes this snapshot, which otherwise would persist until reload
			TheAudio:StopFMODSnapshot(fmodtable.Snapshot.Mute_Ambience_Birds) -- undoes this snapshot, which otherwise would persist until reload

			TheLog.ch.Player:printf("Mulligan activated!")
		end,

		["canactuallydie"] = function(pow, inst, data)
			return false -- Can't die while this is active!
		end,
	}
})

Power.AddPlayerPower("iron_brew",
{
	power_category = Power.Categories.SUSTAIN,
	tuning =
	{
		[Power.Rarity.EPIC] = { bonus_heal = 50 },
		[Power.Rarity.LEGENDARY] = { bonus_heal = 100 },
	},
	tooltips =
	{
		"SHIELD",
	},

	on_add_fn = function(pow, inst)
		if not pow.persistdata.did_init then
			local potiondrinker = inst.components.potiondrinker
			if potiondrinker ~= nil and potiondrinker:GetRemainingPotionUses() <= 0 then
				potiondrinker:RefillPotion()
			end
			pow.persistdata.did_init = true
		end
	end,

	on_remove_fn = function(pow, inst)
		pow.persistdata.did_init = false
	end,

	heal_mod_fn = function(pow, heal, output_data)
		if heal:IsPotionHeal() then
			output_data.heal_delta = output_data.heal_delta + (heal:GetHeal() * (pow.persistdata:GetVar("bonus_heal") * 0.01))
			return true
		end
	end,

	event_triggers = {
		["drink_potion"] = function(pow, inst, potion)
			local shield_def = Power.Items.SHIELD.shield
			local pm = inst.components.powermanager
			pm:AddPower(pm:CreatePower(shield_def), shield_def.max_stacks)
			inst:PushEvent("used_power", pow.def)
		end,
	},
})

Power.AddPlayerPower("risk_reward",
{
	power_category = Power.Categories.DAMAGE,
	tuning =
	{
		[Power.Rarity.EPIC] = { incoming = 30, outgoing = 40 },
		[Power.Rarity.LEGENDARY] = { incoming = 40, outgoing = 60 },
	},

	damage_mod_fn = function(pow, attack, output_data)
		if attack:GetAttacker() ~= attack:GetTarget() then
			output_data.damage_delta = output_data.damage_delta + (attack:GetDamage() * (pow.persistdata:GetVar("outgoing") * 0.01))
			return true
		end
	end,
	defend_mod_fn = function(pow, attack, output_data)
		output_data.damage_delta = output_data.damage_delta + (attack:GetDamage() * (pow.persistdata:GetVar("incoming") * 0.01))
		return true
	end,
})

Power.AddPlayerPower("retribution",
{
	power_category = Power.Categories.DAMAGE,
	tuning =
	{
		[Power.Rarity.COMMON] = { percent = 100 },
		[Power.Rarity.EPIC] = { percent = 200 },
		[Power.Rarity.LEGENDARY] = { percent = 300 },
	},

	damage_mod_fn = function(pow, attack, output_data)
		if pow.persistdata.counter and pow.persistdata.counter > 0 and attack:GetAttacker() ~= attack:GetTarget() then
			local damage = ((pow.persistdata:GetVar("percent") * 0.01) * pow.persistdata.counter) * attack:GetDamage()
			output_data.damage_delta = output_data.damage_delta + damage
			pow.persistdata.counter = 0
			return true
		end
	end,

	event_triggers =
	{
		["healthchanged"] = function(pow, inst, data)
			if data.hurt then
				pow.persistdata.counter = 1
				inst:PushEvent("update_power", pow.def)
			end
		end,
	},
})

Power.AddPlayerPower("pump_and_dump",
{
	prefabs = { "pump_and_dump_proc_burst", "pump_and_dump_proc_burst_OLD", "pump_and_dump_trail" },

	power_category = Power.Categories.DAMAGE,
	tuning =
	{
		[Power.Rarity.LEGENDARY] = { attacks = 5, percent = 200 },
	},

	damage_mod_fn = function(pow, attack, output_data)
		if (pow.persistdata.active or combatutil.IsPowerActiveForProjectileAttack(attack, pow)) and attack:GetTarget() ~= attack:GetAttacker() then
			local damage = (pow.persistdata:GetVar("percent") * 0.01) * attack:GetDamage()
			output_data.damage_delta = output_data.damage_delta + damage

			-- FX --
			powerutil.SpawnParticlesAtPosition(attack:GetTarget():GetPosition(), "pump_and_dump_proc_burst", 1, attack:GetAttacker())
			powerutil.StopAttachedParticleSystem(attack:GetAttacker(), pow)
			return true
		end
	end,

	event_triggers =
	{
		-- melee attack logic
		["attack_start"] = function(pow, inst)
			pow.persistdata.counter = (pow.persistdata.counter or 0) + 1
			if pow.persistdata.counter == pow.persistdata:GetVar("attacks") then
				pow.persistdata.active = true
			elseif pow.persistdata.counter == pow.persistdata:GetVar("attacks") - 1 then
				powerutil.AttachParticleSystemToSymbol(pow, inst, "pump_and_dump_trail", "swap_fx")
				--sound
				--only play the pump and dump start sound if it activates during combat, not on entering a room
				local params = {}
				params.fmodevent = fmodtable.Event.Power_pump_n_dump_start
				params.sound_max_count = 1
				soundutil.PlaySoundData(inst, params)
			end
			inst:PushEvent("update_power", pow.def)
		end,

		["attack_end"] = function(pow, inst)
			if pow.persistdata.active then
				pow.persistdata.counter = 0
				powerutil.StopAttachedParticleSystem(inst, pow)
				pow.persistdata.active = false
				inst:PushEvent("update_power", pow.def)
			end
		end,

		-- ranged attack logic
		["projectile_launched"] = function(pow, inst, projectiles)
			pow.persistdata.counter = (pow.persistdata.counter or 0) + 1
			if pow.persistdata.counter == pow.persistdata:GetVar("attacks") then
				-- buff the projectile for its lifetime
				combatutil.ActivatePowerForProjectile(projectiles, pow)
				pow.persistdata.counter = 0
				powerutil.StopAttachedParticleSystem(inst, pow)
				pow.persistdata.active = false
				inst:PushEvent("update_power", pow.def)
			elseif pow.persistdata.counter == pow.persistdata:GetVar("attacks") - 1 then
				powerutil.AttachParticleSystemToSymbol(pow, inst, "pump_and_dump_trail", "swap_fx")
				--sound
				--only play the pump and dump start sound if it activates during combat, not on entering a room
				local params = {}
				params.fmodevent = fmodtable.Event.Power_pump_n_dump_start
				params.sound_max_count = 1
				soundutil.PlaySoundData(inst, params)
			end
			inst:PushEvent("update_power", pow.def)
		end,

		-- fx logic
		["enter_room"] = function(pow, inst, data)
			if pow.persistdata.counter == pow.persistdata:GetVar("attacks") - 1 then
				powerutil.AttachParticleSystemToSymbol(pow, inst, "pump_and_dump_trail", "swap_fx")
			end
		end,
	}
})

local function do_volatile_weaponry(pow, inst, attack)
	if not attack:GetTarget():IsValid() then return end
	local x,z = attack:GetTarget().Transform:GetWorldXZ()
	local radius = pow.persistdata:GetVar("radius")
	local ents_near, ents_med, ents_far = powerutil.GetEntitiesInRangesFromPoint(x, z, radius)

	-- have volatile weaponry trigger off the latest attack in the chain (i.e. the delayed attack dice hit)
	local master_attack_data = attack:GetLastDamageSourceInChain()
	assert(master_attack_data.damage ~= nil)
	local damage = master_attack_data.damage
	local focus = master_attack_data.focus

	--sound
	local params = {}
	params.fmodevent = fmodtable.Event.Power_VolatileWeaponry_Transient  -- Playing this off the bat so the rest can be windowed sounds, with maximum responsiveness
	soundutil.PlaySoundData(inst, params)

	local function do_attack(target)
		if target:IsValid() then
			local power_attack = Attack(inst, target)
			power_attack:CloneChainDataFromAttack(attack)
			power_attack:SetSource(pow.def.name)
			power_attack:SetDamage(damage)
			power_attack:SetFocus(focus)
			power_attack:SetHitstunAnimFrames(12)
			power_attack:SetPushback(0)
			inst.components.combat:DoPowerAttack(power_attack)
			-- do I need to copy the chain from the last attack?
			powerutil.SpawnPowerHitFx("hits_volatile", inst, target, 0, 0, HitStopLevel.NONE)
		end
	end

	-- if inst.components.hitstopper ~= nil then
	-- 	inst.components.hitstopper:PushHitStop(HitStopLevel.MEDIUM)
	-- end
	-- if attack:GetTarget().components.hitstopper ~= nil then
	-- 	attack:GetTarget().components.hitstopper:PushHitStop(HitStopLevel.MEDIUM)
	-- end

	-- Intention:
	-- Leave a slight delay before the explosion to accentuate the impact (start all of this at 6 frames from now)
	-- Apply attacks/FX in 3 bands: close, medium, far, to create the effect that the explosion is moving outwards
	-- Within a given band, randomize the timing by a couple frames to create variation. Never randomize such that the timing enters the next band's timing.
	inst:DoTaskInAnimFrames(2, function()
		powerutil.SpawnParticlesAtPosition(attack:GetTarget():GetPosition(), "volatile_weapon_proc_burst", 1, inst)

		for i, ent in ipairs(ents_near) do
			inst:DoTaskInAnimFrames(math.random(0, 2), function() do_attack(ent) end)
		end
	end)

	inst:DoTaskInAnimFrames(4, function()
		for i, ent in ipairs(ents_med) do
			inst:DoTaskInAnimFrames(math.random(0, 2), function() do_attack(ent) end)
		end
	end)

	inst:DoTaskInAnimFrames(6, function()
		for i, ent in ipairs(ents_far) do
			inst:DoTaskInAnimFrames(math.random(0, 2), function() do_attack(ent) end)
		end
	end)
end

Power.AddPlayerPower("volatile_weaponry",
{
	power_category = Power.Categories.DAMAGE,
	tuning =
	{
		[Power.Rarity.LEGENDARY] = { count = 10, radius = 8, damage = 100, bloomfadetime = .35 },
	},
	tags = { POWER_TAGS.USES_HITSTREAK },
	prefabs = { "hits_volatile", "volatile_weapon_proc_burst" },
	tooltips =
	{
		"HIT_STREAK",
	},

	on_add_fn = function(pow, inst)
		pow.mem.bloom_i = 0
		pow.mem.bloom_g = 0
	end,

	on_update_fn = function(pow, inst, dt)
		if pow.mem.fadingbloom then
			pow.mem.fadingtime = (pow.mem.fadingtime or 0) + dt
			local t = pow.mem.fadingtime
			local i = pow.mem.bloom_i or 0
			local g = pow.mem.bloom_g or 0
			local lerped_i = easing.linear(t, i, -i, pow.persistdata:GetVar("bloomfadetime"))
			inst.AnimState:SetSymbolBloom("weapon_back01", 1, g, 0, lerped_i)

			if pow.mem.fadingtime >= pow.persistdata:GetVar("bloomfadetime") then
				pow.mem.fadingbloom = false
				pow.mem.fadingtime = nil
			end
		end
	end,

	event_triggers =
	{
		["do_damage"] = function(pow, inst, attack)
			if attack:GetTarget() ~= inst and attack:CheckChain(pow.def.name) == nil then
				local hitstreak = inst.components.combat:GetHitStreak() + 1 -- kinda gross! order of operations: GetHitStreak() is updated after this function is evaluated, so +1 to account for this new hit
				local target = pow.persistdata:GetVar("count")
				local hitstreak_percent = (hitstreak % target) / 10

				local g
				local i

				if hitstreak_percent > 0 and hitstreak_percent < 0.2 then
					g = 220/255
					i = 0.1
				elseif hitstreak_percent >= 0.2 and hitstreak_percent < 0.4 then
					g = 200/255
					i = 0.25
				elseif hitstreak_percent >= 0.4 and hitstreak_percent < 0.6 then
					g = 150/255
					i = 0.5
				elseif hitstreak_percent >= 0.6 and hitstreak_percent < 0.8 then
					g = 100/255
					i = 0.75
				elseif hitstreak_percent >= 0.8 then
					g = 80/255
					i = 1
				else
					g = 0
					i = 0
				end

				inst.AnimState:SetSymbolBloom("weapon_back01", 1, g, 0, i)

				if hitstreak ~= 0 and hitstreak % target == 0 then
					inst.AnimState:SetSymbolBloom("weapon_back01", 0, 0, 0, 0)
					do_volatile_weaponry(pow, inst, attack)
					g = 0
					i = 0
					inst:PushEvent("used_power", pow.def)
				end

				pow.mem.bloom_g = g
				pow.mem.bloom_i = i
			end
		end,

		["hitstreak_killed"] = function(pow, inst, data)
			if not inst:IsLocal() then
				return
			end
			pow.mem.fadingbloom = true
		end,

		["enter_room"] = function(pow, inst, data) --a bit of a hack
			pow.mem.bloom_i = 0
			pow.mem.bloom_g = 0
		end,
	}
})

Power.AddPlayerPower("momentum",
{
	power_category = Power.Categories.SUPPORT,
	tuning =
	{
		[Power.Rarity.COMMON] = { speed = 40, time = 4 },
		[Power.Rarity.EPIC] = { speed = 40, time = 6 },
		[Power.Rarity.LEGENDARY] = { speed = 40, time = 8 },
	},

	tags = { POWER_TAGS.PROVIDES_MOVESPEED },

	event_triggers =
	{
		["dodge"] = function(pow, inst, data)
			inst.components.locomotor:AddSpeedMult(pow.def.name, pow.persistdata:GetVar("speed") * 0.01)
			pow:StartPowerTimer(inst)
			inst:PushEvent("used_power", pow.def)
		end,
		["timerdone"] = function(pow, inst, data)
			if data.name == pow.def.name then
				inst.components.locomotor:RemoveSpeedMult(pow.def.name)
			end
		end,
	},

	on_remove_fn = function(pow, inst)
		inst.components.timer:StopTimer(pow.def.name)
		inst.components.locomotor:RemoveSpeedMult(pow.def.name)
	end,
})

Power.AddPlayerPower("down_to_business",
{
	power_category = Power.Categories.SUPPORT,
	tuning =
	{
		[Power.Rarity.COMMON] = { speed = 30, time = 30 },
		[Power.Rarity.EPIC] = { speed = 50, time = 30 },
		[Power.Rarity.LEGENDARY] = { speed = 50, time = 60 },
	},

	tags = { POWER_TAGS.PROVIDES_MOVESPEED },

	event_triggers =
	{
		["start_gameplay"] = function(pow, inst, data)
			inst.components.locomotor:AddSpeedMult(pow.def.name, pow.persistdata:GetVar("speed") * 0.01)
			pow:StartPowerTimer(inst)
			inst:PushEvent("used_power", pow.def)
		end,
		["timerdone"] = function(pow, inst, data)
			if data.name == pow.def.name then
				inst.components.locomotor:RemoveSpeedMult(pow.def.name)
			end
		end,
	},

	on_remove_fn = function(pow, inst)
		inst.components.timer:StopTimer(pow.def.name)
		inst.components.locomotor:RemoveSpeedMult(pow.def.name)
	end,
})


Power.AddPlayerPower("grand_entrance", -- rename prefab now that this is First Contact?
{
	power_category = Power.Categories.DAMAGE,
	tuning =
	{
		[Power.Rarity.COMMON] = { damage = 150 },
		[Power.Rarity.EPIC] = { damage = 300 },
		[Power.Rarity.LEGENDARY] = { damage = 500 },
	},

	prefabs = { "hits_first_contact" },
	tooltips =
	{
		"HEAVY_ATTACK",
	},

	on_add_fn = function(pow, inst)
		powerutil.AttachParticleSystemToSymbol(pow, inst, "first_impact_weapon_trail", "swap_fx")
		local params = {}
		params.fmodevent = fmodtable.Event.Power_bigStick_Start
		params.sound_max_count = 1
		local handle = soundutil.PlaySoundData(inst, params)
		--this is the only place I use this for right now
		soundutil.SetInstanceParameter(inst, handle, "upgrade_level", Power.GetRarityAsParameter(pow.persistdata))
	end,

	event_triggers =
	{
		["do_damage"] = function(pow, inst, attack)
			if pow.persistdata.counter and pow.persistdata.counter > 0  and attack:IsHeavyAttack() then
				local proced = false
				local ents = FindEnemiesInRange(0, 0, 1000)
				--local delay_frames_base = 4
				--local delay_frames_scalar = (#ents > 4) and ((#ents - 3) * 2) or 4
				local delay_frames = math.random(8)
				for i, ent in ipairs(ents) do
					proced = true
					inst:DoTaskInAnimFrames(delay_frames, function()
						if ent:IsValid() then
							local power_attack = Attack(inst, ent)
							power_attack:SetDamage(pow.persistdata:GetVar("damage"))
							power_attack:SetHitstunAnimFrames(5)
							power_attack:SetPushback(0)
							power_attack:SetSource(pow.def.name)

							inst.components.combat:DoPowerAttack(power_attack)

							ent.components.combat:SetTarget(inst)
							powerutil.SpawnPowerHitFx("hits_first_contact", inst, ent, 0, 0, HitStopLevel.NONE)
						end
					end)
				end
				if proced then
					--sound
					local params = {}
					params.fmodevent = fmodtable.Event.Power_bigStick_Explode
					soundutil.PlaySoundData(inst, params)

					powerutil.StopAttachedParticleSystem(inst, pow)
				end
				pow.persistdata.counter = 0
				inst:PushEvent("used_power", pow.def)
			end
		end,

		["enter_room"] = function(pow, inst, data)
			pow.persistdata.counter = 1
			inst:PushEvent("update_power", pow.def)
		end,
	}
})

Power.AddPlayerPower("extroverted",
{
	power_category = Power.Categories.DAMAGE,
	tuning =
	{
		[Power.Rarity.COMMON] = { time = 30, damage = 25 },
		[Power.Rarity.EPIC] = { time = 30, damage = 35 },
		[Power.Rarity.LEGENDARY] = { time = 30, damage = 50 },
	},

	damage_mod_fn = function(pow, attack, output_data)
		if attack:GetAttacker().components.timer:HasTimer(pow.def.name) and attack:GetAttacker() ~= attack:GetTarget() then
			local damage = (pow.persistdata:GetVar("damage") * 0.01) * attack:GetDamage()
			output_data.damage_delta = output_data.damage_delta + damage
			return true
		end
	end,
	event_triggers =
	{
		["start_gameplay"] = function(pow, inst, data)
			pow:StartPowerTimer(inst)
			powerutil.AttachParticleSystemToSymbol(pow, inst, "extroverted_trail", "swap_fx")
			inst:PushEvent("used_power", pow.def)
		end,
		["timerdone"] = function(pow, inst, data)
			if data.name == pow.def.name then
				powerutil.StopAttachedParticleSystem(inst, pow)
			end
		end,
	}
})

-- Power.AddPlayerPower("extra_damage_after_iframe_dodge",
-- {
-- 	prefabs = { "sting_like_a_bee_proc_burst", "sting_like_a_bee_trail" },
-- 	power_category = Power.Categories.DAMAGE,
-- 	tuning =
-- 	{
-- 		[Power.Rarity.EPIC] = { damage_mult = 2 },
-- 		[Power.Rarity.LEGENDARY] = { damage_mult = 3 },
-- 	},

-- 	damage_mod_fn = function(pow, attack, output_data)
-- 		if pow.persistdata.active then
-- 			local damage = (pow.persistdata:GetVar("damage_mult")-1) * attack:GetDamage()
-- 			output_data.damage_delta = output_data.damage_delta + damage
-- 			-- local fx_pos = attack:GetTarget():GetPosition()
-- 			powerutil.SpawnParticlesAtPosition(attack:GetTarget():GetPosition(), "sting_like_a_bee_proc_burst", 1, attack:GetAttacker())
-- 			powerutil.StopAttachedParticleSystem(inst, pow)
-- 			return true
-- 		end
-- 	end,

-- 	event_triggers =
-- 	{
-- 		["hitboxcollided_invincible"] = function(pow, inst, data)
-- 			if inst.sg:HasStateTag("dodge") and not pow.persistdata.active then
-- 				pow.persistdata.active = true
-- 				powerutil.AttachParticleSystemToSymbol(pow, inst, "sting_like_a_bee_trail", "swap_fx")
-- 			end
-- 		end,
-- 		["enter_room"] = function(pow, inst, data)
-- 			if pow.persistdata.active then
-- 				powerutil.AttachParticleSystemToSymbol(pow, inst, "sting_like_a_bee_trail", "swap_fx")
-- 			end
-- 		end,
-- 		["light_attack"] = function(pow, inst, data)
-- 			if pow.persistdata.active and #data.targets_hit > 0 then
-- 				pow.persistdata.active = false
-- 			end
-- 		end,
-- 		["heavy_attack"] = function(pow, inst, data)
-- 			if pow.persistdata.active and #data.targets_hit > 0 then
-- 				pow.persistdata.active = false
-- 			end
-- 		end,
-- 	}
-- })

-- BELOW is a version of heal_on_quick_rise that does a % of health lost
-- Power.AddPlayerPower("heal_on_quick_rise",
-- {
-- 	prefabs = {  },
-- 	tags = { POWER_TAGS.PROVIDES_HEALING, POWER_TAGS.PROVIDES_FREQUENT_HEALING },
-- 	power_category = Power.Categories.SUSTAIN,
-- 	tuning =
-- 	{
-- 		-- Old healing was EPIC:75, LEGENDARY:125.
-- 		-- tuning value spreadsheet:
-- 		-- https://docs.google.com/spreadsheets/d/16jsmGanW1CrxVzwa8aQIWU5OhTqUoZyJAf-PAIuQ8L8/edit#gid=0

-- 		-- Tune so that quick-rising big attacks should help a lot, and quick-rising little attacks should help a little.
-- 		-- Old version of this power had flat values which allowed for strategies of forcing knockdowns with no damage and getting free healing.
-- 		-- This is really cool and could be great, but kind of knocks the balance of this power out of whack.

-- 		[Power.Rarity.EPIC] = { percent = 25 },
-- 		[Power.Rarity.LEGENDARY] = { percent = 40 },
-- 	},
-- 	tooltips =
-- 	{
-- 		"QUICK_RISE",
-- 	},
-- 	event_triggers =
-- 	{
-- 		["knockdown"] = function(pow, inst, data)
-- 			local attack = data.attack
-- 			if attack then
-- 				local damage = attack:GetDamage()
-- 				pow.persistdata.lastdamage = damage
-- 			end
-- 		end,
-- 		["quick_rise"] = function(pow, inst, data)
-- 			local damage = pow.persistdata.lastdamage
-- 			if damage then
-- 				local mult = pow.persistdata:GetVar("percent") * 0.01
-- 				local heal = damage * mult

-- 				local power_heal = Attack(inst, inst)
-- 				power_heal:SetHeal(heal)
-- 				power_heal:SetSource(pow.def.name)
-- 				inst.components.combat:ApplyHeal(power_heal)
-- 				inst:PushEvent("used_power", pow.def)
-- 			end
-- 		end,
-- 	}
-- })
-- ABOVE is a version of heal_on_quick_rise that does a % of health lost
Power.AddPlayerPower("heal_on_quick_rise",
{
	prefabs = {  },
	tags = { POWER_TAGS.PROVIDES_HEALING, POWER_TAGS.PROVIDES_FREQUENT_HEALING },
	power_category = Power.Categories.SUSTAIN,
	tuning =
	{
		-- Example damage amounts:
		-- 	Yammo swing: 297
		-- 	Mother Treek swing: 270
		--	Cabbageroll: 70
		--	Blarmadillo shoot: 135
		--	Blarmadillo roll: 90

		-- jambell:
		-- It's likely that this needs to be turned into "gain % of the health you just lost back" but quick_rise doesn't know about the attack yet. Nerfing this for now.
		[Power.Rarity.EPIC] = { heal = 50 },
		[Power.Rarity.LEGENDARY] = { heal = 100 },
	},
	tooltips =
	{
		"QUICK_RISE",
	},
	event_triggers =
	{
		["quick_rise"] = function(pow, inst, data)
			local power_heal = Attack(inst, inst)
			power_heal:SetHeal(pow.persistdata:GetVar("heal"))
			power_heal:SetSource(pow.def.name)
			inst.components.combat:ApplyHeal(power_heal)
			inst:PushEvent("used_power", pow.def)
		end,
	}
})
Power.AddPlayerPower("introverted",
{
	power_category = Power.Categories.SUSTAIN,
	tuning =
	{
		-- [Power.Rarity.EPIC] = { shield = 1 },
		[Power.Rarity.LEGENDARY] = { shield = 1 },
	},

	-- on_add_fn = function(pow, inst)
	-- 	if not pow.persistdata.did_init then
	-- 		local shield_def = Power.Items.SHIELD.shield
	-- 		local pm = inst.components.powermanager
	-- 		pm:AddPower(pm:CreatePower(shield_def), 0)
	-- 		pow.persistdata.did_init = true
	-- 	end
	-- end,
	tooltips =
	{
		"SHIELD",
	},
	event_triggers = {
		["start_gameplay"] = function(pow, inst, data)
			local shield_def = Power.Items.SHIELD.shield
			local pm = inst.components.powermanager
			pm:AddPower(pm:CreatePower(shield_def), shield_def.max_stacks)
		end,
	},
})

Power.AddPlayerPower("wrecking_ball",
{
	power_category = Power.Categories.DAMAGE,
	tuning =
	{
		[Power.Rarity.LEGENDARY] = {},
	},

	required_tags = { POWER_TAGS.PROVIDES_MOVESPEED },

	damage_mod_fn = function(pow, attack, output_data)
		if attack:GetAttacker() ~= attack:GetTarget() then
			local move_speed_bonus = attack:GetAttacker().components.locomotor.total_speed_mult - 1
			local damage = attack:GetDamage() * move_speed_bonus
			output_data.damage_delta = output_data.damage_delta + damage
			return true
		end
	end,

	event_triggers =
	{
		["speed_mult_changed"] = function(pow, inst, data)
			if pow.persistdata.counter then
				local move_speed_bonus = (data.new - 1)
				pow.persistdata.counter = math.floor(move_speed_bonus * 100 + 0.5)
				inst:PushEvent("update_power", pow.def)
			end
		end,
	},

	get_counter_text = powerutil.GetCounterTextPlusPercent,

	on_add_fn = function(pow, inst)
		if not pow.persistdata.did_init then
			pow.persistdata.did_init = true
			pow.persistdata.counter = 0
			-- delay by one frame to allow UI to be initialized
			inst:DoTaskInTicks(1, function(inst) inst.components.locomotor:UpdateTotalSpeedMult(true) end)
		end
	end,

	on_remove_fn = function(pow, inst)
		pow.persistdata.did_init = false
	end,

})

Power.AddPlayerPower("getaway",
{
	power_category = Power.Categories.SUPPORT,
	tuning =
	{
		[Power.Rarity.COMMON] = { speed = 75, time = 2 }, --some of this time is eaten up by attack recovery
		[Power.Rarity.EPIC] = { speed = 75, time = 3 }, --some of this time is eaten up by attack recovery
		[Power.Rarity.LEGENDARY] = { speed = 75, time = 4 }, --some of this time is eaten up by attack recovery
	},

	tags = { POWER_TAGS.PROVIDES_MOVESPEED },

	event_triggers =
	{
		["kill"] = function(pow, inst, data)
			inst.components.locomotor:AddSpeedMult(pow.def.name, pow.persistdata:GetVar("speed") * 0.01)
			pow:StartPowerTimer(inst)
			inst:PushEvent("used_power", pow.def)
		end,
		["timerdone"] = function(pow, inst, data)
			if data.name == pow.def.name then
				inst.components.locomotor:RemoveSpeedMult(pow.def.name)
			end
		end,
	},

	on_remove_fn = function(pow, inst)
		inst.components.timer:StopTimer(pow.def.name)
		inst.components.locomotor:RemoveSpeedMult(pow.def.name)
	end,
})

-- jambell: Removing these basic "stronger X" powers for now because flat damage improvements aren't particularly interesting. Could come back later.
-- Power.AddPlayerPower("stronger_light_attack", --TODO: make this a power given in a Special Event
-- {
-- 	tuning =
-- 	{
-- 		[Power.Rarity.LEGENDARY] = { bonus = 25 },
-- 	},


-- 	damage_mod_fn = function(pow, attack, output_data)
-- 		if attack:GetAttacker().sg.mem.attack_type == "light_attack" then
-- 			local bonus_damage = attack:GetDamage() * (pow.persistdata:GetVar("bonus") * 0.01)
-- 			output_data.damage_delta = output_data.damage_delta + bonus_damage
-- 			return true
-- 		end
-- 	end,
-- })

-- Power.AddPlayerPower("stronger_heavy_attack", --TODO: make this a power given in a Special Event
-- {
-- 	tuning =
-- 	{
-- 		[Power.Rarity.LEGENDARY] = { bonus = 25 },
-- 	},


-- 	damage_mod_fn = function(pow, attack, output_data)
-- 		if attack:GetAttacker().sg.mem.attack_type == "heavy_attack" then
-- 			local bonus_damage = attack:GetDamage() * (pow.persistdata:GetVar("bonus") * 0.01)
-- 			output_data.damage_delta = output_data.damage_delta + bonus_damage
-- 			return true
-- 		end
-- 	end,
-- })

-- Power.AddPlayerPower("stronger_focuses", --TODO: make this a power given in a Special Event
-- {
-- 	tuning =
-- 	{
-- 		[Power.Rarity.LEGENDARY] = { bonus = 25 },
-- 	},


-- 	damage_mod_fn = function(pow, attack, output_data)
-- 		if attack:GetFocus() then
-- 			local bonus_damage = attack:GetDamage() * (pow.persistdata:GetVar("bonus") * 0.01)
-- 			output_data.damage_delta = output_data.damage_delta + bonus_damage
-- 			return true
-- 		end
-- 	end,
-- })

-- Power.AddPlayerPower("increased_pushback", --rewrite this to do a big pushback every X hits, but not in the pushback system. it's not designed to push back very far, and looks silly.
-- {
-- 	tuning =
-- 	{
-- 		[Power.Rarity.COMMON] = { bonus = 200 }, -- too much more pushback is actually a strong nerf and breaks a lot of combos, so upgrading this is kind of tricky
-- 	},


-- 	damage_mod_fn = function(pow, attack, output_data)
-- 		local default = attack:GetPushback()
-- 		attack:SetPushback(default * pow.persistdata:GetVar("bonus") * 0.01)
-- 	end,
-- })

Power.AddPlayerPower("no_pushback",
{
	power_category = Power.Categories.SUPPORT,
	tuning =
	{
		[Power.Rarity.COMMON] = {  },
	},


	damage_mod_fn = function(pow, attack, output_data)
		local default = attack:GetPushback()
		attack:SetPushback(default * 0)
	end,
})

Power.AddPlayerPower("increased_hitstun", -- TODO: make this % based
{
	power_category = Power.Categories.SUPPORT,
	tuning =
	{
		[Power.Rarity.COMMON] = { bonus = 2, desc = STRINGS.ITEMS.PLAYER.increased_hitstun.common_desc },
		[Power.Rarity.EPIC] = { bonus = 3, desc = STRINGS.ITEMS.PLAYER.increased_hitstun.epic_desc },
		[Power.Rarity.LEGENDARY] = { bonus = 4, desc = STRINGS.ITEMS.PLAYER.increased_hitstun.legendary_desc },
	},

	damage_mod_fn = function(pow, attack, output_data)
		local default = attack:GetHitstunAnimFrames()
		attack:SetHitstunAnimFrames(default + pow.persistdata:GetVar("bonus"))
	end,
})

-- Power.AddPlayerPower("stronger_counter_hits",
-- {
-- 	tuning =
-- {
-- 	[Power.Rarity.EPIC] = { bonus = 100 },
-- },
-- 	damage_mod_fn = function(pow, attack, output_data)
-- 		local target = attack:GetTarget()
-- 		if target.sg ~= nil and target.sg:HasStateTag("attack") and not target.sg.statemem.recovering then
-- 			local bonus_damage = attack:GetDamage() * (pow.persistdata:GetVar("bonus") * 0.01)
-- 			output_data.damage_delta = output_data.damage_delta + bonus_damage
-- 			return true
-- 		end
-- 	end,
-- })

Power.AddPlayerPower("combo_wombo", -- increase your damage by your current hit streak
{
	power_category = Power.Categories.DAMAGE,
	tags = { POWER_TAGS.USES_HITSTREAK },
	tuning =
	{
		[Power.Rarity.EPIC] = { bonus = 1 , upgrade_text = "" },
		[Power.Rarity.LEGENDARY] = { bonus = 2, upgrade_text = STRINGS.ITEMS.PLAYER.combo_wombo.upgrade_text },
	},
	tooltips =
	{
		"HIT_STREAK",
	},
	damage_mod_fn = function(pow, attack, output_data)
		local damage_mod = attack:GetAttacker().components.combat:GetHitStreak() * pow.persistdata:GetVar("bonus")
		output_data.damage_delta = output_data.damage_delta + damage_mod
		return true
	end,
})

Power.AddPlayerPower("battle_fame", -- at the end of a room, gain an amount of konjur equal to your largest hit streak
{
	power_category = Power.Categories.SUPPORT,
	tags = { POWER_TAGS.USES_HITSTREAK },
	tuning =
	{
		[Power.Rarity.COMMON] = { bonus = 1, upgrade_text = "" },
		[Power.Rarity.EPIC] = { bonus = 2, upgrade_text = STRINGS.ITEMS.PLAYER.battle_fame.upgrade_text_epic },
		[Power.Rarity.LEGENDARY] = { bonus = 3, upgrade_text = STRINGS.ITEMS.PLAYER.battle_fame.upgrade_text_legendary },
	},
	tooltips =
	{
		"HIT_STREAK",
		"KONJUR",
	},
	event_triggers =
	{
		["enter_room"] = function(pow, inst, data)
			pow.persistdata.highest = 0
			pow.persistdata.counter = 0
			inst:PushEvent("used_power", pow.def)
		end,

		["hitstreak"] = function(pow, inst, data)
			if inst:IsLocal() and not pow.persistdata.highest or (pow.persistdata.highest and data.hitstreak > pow.persistdata.highest) and not TheWorld.components.spawncoordinator:GetIsRoomComplete() then
				pow.persistdata.highest = data.hitstreak

				pow.mem.new_high = pow.persistdata.highest -- Later, once this hitstreak ends, we'll update the player on their new high.
				pow.persistdata.counter = pow.persistdata.highest
				inst:PushEvent("used_power", pow.def)
			end
		end,

		["hitstreak_killed"] = function(pow, inst, data)
			if inst:IsLocal() and pow.mem.new_high and pow.mem.new_high > 0 then
				-- TheDungeon.HUD:MakePopText({ target = inst, button = update_str, color = UICOLORS.KONJUR, size = 80, fade_time = 1, y_offset = 70 })

				local name = "<p img='images/ui_ftf_pausescreen/ic_plain1.tex' color=0 scale=1> "..pow.def.pretty.name
				local update_str = string.format(STRINGS.ITEMS.PLAYER.battle_fame.new_highest_popup, pow.persistdata.highest)
				TheDungeon.HUD:MakePopText({ target = inst, button = name, color = UICOLORS.GOLD_FOCUS, size = 80, fade_time = 2, y_offset = 460 })
				TheDungeon.HUD:MakePopText({ target = inst, button = update_str, color = UICOLORS.WHITE, size = 60, fade_time = 2, y_offset = 400 })

				pow.mem.new_high = nil
			end
		end,
	},

	remote_event_triggers =
	{
		["room_complete"] =
		{
			fn = function(pow, inst, source, data)
				if pow.persistdata.highest > 0 then
					local amount = pow.persistdata.highest
					amount = amount * pow.persistdata:GetVar("bonus")

					inst:DoTaskInAnimFrames(2, function()
						if inst ~= nil and inst:IsValid() then
							TheDungeon.HUD:MakePopText({ target = inst, button = STRINGS.ITEMS.PLAYER.battle_fame.name, color = UICOLORS.KONJUR, size = 100, fade_time = amount >= 10 and 3 or 1, y_offset = 70 })
							LootEvents.MakeEventSpawnCurrency(amount, inst:GetPosition(), inst, false, true)

							pow.persistdata.highest = 0
						end
					end)
				end
			end,
			source = function() return TheWorld end,
		}
	},
})

Power.AddPlayerPower("streaking", -- Increase move speed based on hit streak
{
	power_category = Power.Categories.SUPPORT,
	tuning =
	{
		[Power.Rarity.COMMON] = { bonus = 1, upgrade_text = "" },
		[Power.Rarity.EPIC] = { bonus = 2, upgrade_text = STRINGS.ITEMS.PLAYER.streaking.upgrade_text },
		[Power.Rarity.LEGENDARY] = { bonus = 3, upgrade_text = STRINGS.ITEMS.PLAYER.streaking.upgrade_text_legendary },
	},
	tooltips =
	{
		"HIT_STREAK",
	},
	tags = { POWER_TAGS.USES_HITSTREAK },
	event_triggers =
	{
		["hitstreak"] = function(pow, inst, data)
			if not inst:IsLocal() then
				return
			end
			local bonus = data.hitstreak * pow.persistdata:GetVar("bonus")
			inst.components.locomotor:AddSpeedMult(pow.def.name, bonus * 0.01)

			pow.persistdata.counter = math.floor(bonus)
			inst:PushEvent("used_power", pow.def)
		end,
	},

	get_counter_text = powerutil.GetCounterTextPlusPercent,

	on_add_fn = function(pow, inst)
		if not pow.persistdata.did_init then
			pow.persistdata.did_init = true
			pow.persistdata.counter = 0
		end
	end,
})

Power.AddPlayerPower("crit_streak",
{
	power_category = Power.Categories.DAMAGE,
	tags = { POWER_TAGS.PROVIDES_CRITCHANCE, POWER_TAGS.USES_HITSTREAK },
	tuning =
	{
		[Power.Rarity.EPIC] = { bonus = 1, upgrade_text = "" },
		[Power.Rarity.LEGENDARY] = { bonus = 2, upgrade_text = STRINGS.ITEMS.PLAYER.crit_streak.upgrade_text },
	},
	tooltips =
	{
		"HIT_STREAK",
		"CRIT_CHANCE",
		"CRITICAL_HIT",
	},
	event_triggers =
	{
		['hitstreak'] = function(pow, inst, data)
			local crit_bonus = data.hitstreak * pow.persistdata:GetVar("bonus")
			inst.components.combat:SetCritChanceModifier(pow, crit_bonus * 0.01)
			pow.persistdata.counter = math.floor(crit_bonus)
			inst:PushEvent("used_power", pow.def)
		end,
	},

	get_counter_text = powerutil.GetCounterTextPlusPercent,

	on_add_fn = function(pow, inst)
		if not pow.persistdata.did_init then
			pow.persistdata.did_init = true
			pow.persistdata.counter = 0
		end
	end,
})

Power.AddPlayerPower("crit_movespeed",
{
	power_category = Power.Categories.DAMAGE,
	tuning =
	{
		[Power.Rarity.LEGENDARY] = { bonus = 1, upgrade_text = "" },
		-- [Power.Rarity.LEGENDARY] = { bonus = 2, upgrade_text = STRINGS.ITEMS.PLAYER.crit_movespeed.upgrade_text },
	},
	tooltips =
	{
		"CRIT_CHANCE",
		"CRITICAL_HIT",
	},
	required_tags = { POWER_TAGS.PROVIDES_MOVESPEED },

	damage_mod_fn = function(pow, attack, output_data)
		if attack:GetAttacker() ~= attack:GetTarget() then
			local bonus = pow.persistdata.move_speed_bonus or 0
			attack:DeltaBonusCritChance(bonus)
			return true
		end
	end,

	event_triggers =
	{
		["speed_mult_changed"] = function(pow, inst, data)
			local move_speed_bonus = (data.new - 1)
			pow.persistdata.move_speed_bonus = math.floor(move_speed_bonus * 100 + 0.5) * (pow.persistdata:GetVar("bonus") * 0.01)
			pow.persistdata.counter = math.floor(pow.persistdata.move_speed_bonus * 100)
			inst:PushEvent("update_power", pow.def)
		end,
	},

	get_counter_text = powerutil.GetCounterTextPlusPercent,

	on_add_fn = function(pow, inst)
		if not pow.persistdata.did_init then
			pow.persistdata.did_init = true
			pow.persistdata.move_speed_bonus = 0
			pow.persistdata.counter = 0
			-- delay by one frame to allow UI to be initialized
			inst:DoTaskInTicks(1, function(inst) inst.components.locomotor:UpdateTotalSpeedMult(true) end)
		end
	end,

	on_remove_fn = function(pow, inst)
		pow.persistdata.did_init = false
	end,
})

Power.AddPlayerPower("sting_like_a_bee",
{
	prefabs = { "sting_like_a_bee_proc_burst", "sting_like_a_bee_trail" },
	tags = { POWER_TAGS.PROVIDES_CRITCHANCE },
	power_category = Power.Categories.DAMAGE,
	tuning =
	{
		[Power.Rarity.LEGENDARY] = {},
	},

	tooltips =
	{
		"IFRAME_DODGE",
		"CRITICAL_HIT",
	},

	damage_mod_fn = function(pow, attack, output_data)
		if pow.persistdata.active then
			attack:SetCrit(true)
			-- uses attacker as ref entity but will play at fx_pos
			powerutil.SpawnParticlesAtPosition(attack:GetTarget():GetPosition(), "sting_like_a_bee_proc_burst", 1, attack:GetAttacker())
			powerutil.StopAttachedParticleSystem(attack:GetAttacker(), pow)
			return true
		end
	end,

	event_triggers =
	{
		["hitboxcollided_invincible"] = function(pow, inst, data)
			if inst.sg:HasStateTag("dodge") and not pow.persistdata.active then
				pow.persistdata.active = true
				powerutil.AttachParticleSystemToSymbol(pow, inst, "sting_like_a_bee_trail", "swap_fx")
			end
		end,
		["enter_room"] = function(pow, inst, data)
			if pow.persistdata.active then
				powerutil.AttachParticleSystemToSymbol(pow, inst, "sting_like_a_bee_trail", "swap_fx")
			end
		end,
		["light_attack"] = function(pow, inst, data)
			if pow.persistdata.active and #data.targets_hit > 0 then
				pow.persistdata.active = false
			end
		end,
		["heavy_attack"] = function(pow, inst, data)
			if pow.persistdata.active and #data.targets_hit > 0 then
				pow.persistdata.active = false
			end
		end,
	}
})

Power.AddPlayerPower("advantage",
{
	power_category = Power.Categories.DAMAGE,
	tags = { POWER_TAGS.PROVIDES_CRITCHANCE },
	tuning = {
		[Power.Rarity.EPIC] = { percent = 100, desc = "full" }, --TODO: move this to localizable spot
		[Power.Rarity.LEGENDARY] = { percent = 50, desc = "more than half" }, --TODO: move this to localizable spot
	},
	tooltips =
	{
		"CRITICAL_HIT",
	},
	damage_mod_fn = function(pow, attack, output_data)
		local target = attack:GetTarget()
		-- test for health component when hitting "non-health" entities like the shotput
		if target and target.components.health and target.components.health:GetPercent() >= pow.persistdata:GetVar("percent")/100 then
			attack:SetCrit(true)
			return true
		end
	end,
})

Power.AddPlayerPower("salted_wounds",
{
	power_category = Power.Categories.DAMAGE,
	tags = { POWER_TAGS.PROVIDES_CRITCHANCE },
	tuning = {
		[Power.Rarity.COMMON] = { bonus = 10 },
		[Power.Rarity.EPIC] = { bonus = 20 },
		[Power.Rarity.LEGENDARY] = { bonus = 30 },
	},
	tooltips =
	{
		"FOCUS_HIT",
		"CRIT_CHANCE",
		"CRITICAL_HIT",
	},
	damage_mod_fn = function(pow, attack, output_data)
		if attack:GetFocus() then
			attack:DeltaBonusCritChance(pow.persistdata:GetVar("bonus") * 0.01)
			return true
		end
	end,
})

Power.AddPlayerPower("heal_on_crit",
{
	power_category = Power.Categories.SUSTAIN,
	tags = { POWER_TAGS.PROVIDES_HEALING, POWER_TAGS.PROVIDES_FREQUENT_HEALING },
	required_tags = { POWER_TAGS.PROVIDES_CRITCHANCE },
	tuning = {
		[Power.Rarity.EPIC] = { heal = 10, },
		[Power.Rarity.LEGENDARY] = { heal = 20, },
	},
	tooltips =
	{
		"CRITICAL_HIT",
	},
	event_triggers =
	{
		["do_damage"] = function(pow, inst, attack)
			if powerutil.TargetIsEnemyOrDestructibleProp(attack) and attack:GetCrit() then
				local power_heal = Attack(inst, inst)
				power_heal:SetHeal(pow.persistdata:GetVar("heal"))
				power_heal:SetSource(pow.def.name)
				inst.components.combat:ApplyHeal(power_heal)
				inst:PushEvent("used_power", pow.def)
			end
		end,
	}
})

Power.AddPlayerPower("crit_knockdown",
{
	power_category = Power.Categories.DAMAGE,
	tags = { POWER_TAGS.PROVIDES_CRITCHANCE },
	tuning = {
		[Power.Rarity.COMMON] = { chance = 20 },
		[Power.Rarity.EPIC] = { chance = 35 },
		[Power.Rarity.LEGENDARY] = { chance = 50 },
	},
	tooltips =
	{
		"KNOCKED_DOWN",
		"CRIT_CHANCE",
		"CRITICAL_HIT",
	},
	damage_mod_fn = function(pow, attack, output_data)
		local target = attack:GetTarget()
		if target and target.sg ~= nil and target.sg:HasStateTag("knockdown") then
			attack:DeltaBonusCritChance(pow.persistdata:GetVar("chance") * 0.01)
			return true
		end
	end,
})


Power.AddPlayerPower("konjur_on_crit",
{
	power_category = Power.Categories.SUPPORT,
	prefabs = { 'drop_konjur' },
	tuning =
	{
		[Power.Rarity.COMMON] = { konjur = 1 },
		[Power.Rarity.EPIC] = { konjur = 2 },
		[Power.Rarity.LEGENDARY] = { konjur = 3 },
	},
	tooltips =
	{
		"KONJUR",
	},
	event_triggers =
	{
		["do_damage"] = function(pow, inst, attack)
			if powerutil.TargetIsEnemyOrDestructibleProp(attack) and attack:GetCrit() then
				LootEvents.MakeEventSpawnCurrency(pow.persistdata:GetVar("konjur"), attack:GetTarget():GetPosition(), inst, false, true)
			end
		end,
	},
})

-- Power.AddPlayerPower("reprieve",
-- {
-- 	power_category = Power.Categories.SUPPORT,
-- 	required_tags = { POWER_TAGS.PROVIDES_CRITCHANCE },
-- 	tuning =
-- 	{
-- 		[Power.Rarity.COMMON] = { percent = 10 },
-- 		[Power.Rarity.EPIC] = { percent = 20 },
-- 		[Power.Rarity.LEGENDARY] = { percent = 30 },
-- 	},
-- 	tooltips =
-- 	{
-- 		"HIT_STREAK",
-- 	},
-- 	event_triggers =
-- 	{
-- 		["do_damage"] = function(pow, inst, attack)
-- 			local delta = TUNING.PLAYER.HIT_STREAK.BASE_DECAY * (pow.persistdata:GetVar("percent") * 0.01)
-- 			attack:GetAttacker().components.combat:DeltaHitStreakDecay(delta)
-- 		end,
-- 	},
-- })

local function refresh_stacking_crit_buff(pow, inst)
	local crit_bonus = 0
	for _, data in ipairs(pow.persistdata.buff_stacks) do
		crit_bonus = crit_bonus + data.bonus
	end

	-- TheLog.ch.Player:printf("Refresh Stacking Crit Buff: %1.1f%%", crit_bonus)
	inst.components.combat:SetCritChanceModifier(pow, crit_bonus * 0.01)
	pow.persistdata.counter = math.floor(crit_bonus)
end

local function on_add_stacking_crit_buff_power(pow, inst)
	if not pow.persistdata.did_init then
		pow.persistdata.buff_stacks = {}
		pow.persistdata.counter = 0
	end
end

local function on_remove_stacking_crit_buff_power(pow, inst)
	inst.components.combat:RemoveCritChanceModifier(pow)
end

local function add_stacking_crit_buff(pow, inst, crit_bonus)
	table.insert(pow.persistdata.buff_stacks, { time = GetTime() + pow.persistdata:GetVar("time"), bonus = crit_bonus })
	refresh_stacking_crit_buff(pow, inst)
	inst:PushEvent("used_power", pow.def)
end

local function stacking_crit_buff_onupdate(pow, inst, dt)
	local time = GetTime()
	local old_count = #pow.persistdata.buff_stacks
	local should_update = false

	for i = old_count, 1, -1 do
		if pow.persistdata.buff_stacks[i].time < time then
			table.remove(pow.persistdata.buff_stacks, i)
			should_update = true
		end
	end

	if should_update or old_count ~= #pow.persistdata.buff_stacks then
		-- TheLog.ch.Player:printf("Buff Stacks Count: old=%d new=%d", old_count, #pow.persistdata.buff_stacks)
		refresh_stacking_crit_buff(pow, inst)
		inst:PushEvent("update_power", pow.def)
	end
end

Power.AddPlayerPower("sanguine_power",
{
	power_category = Power.Categories.DAMAGE,
	tags = { POWER_TAGS.PROVIDES_CRITCHANCE },
	tuning =
	{
		[Power.Rarity.EPIC] = { bonus = 5, time = 10 },
		[Power.Rarity.LEGENDARY] = { bonus = 5, time = 15 },
	},

	get_counter_text = powerutil.GetCounterTextPlusPercent,
	on_add_fn = on_add_stacking_crit_buff_power,
	on_update_fn = stacking_crit_buff_onupdate,
	on_remove_fn = on_remove_stacking_crit_buff_power,
	tooltips =
	{
		"CRIT_CHANCE",
		"CRITICAL_HIT",
	},
	event_triggers =
	{
		['kill'] = function(pow, inst, data)
			add_stacking_crit_buff(pow, inst, pow.persistdata:GetVar("bonus"))
		end,
	}
})

Power.AddPlayerPower("feedback_loop",
{
	power_category = Power.Categories.DAMAGE,
	required_tags = { POWER_TAGS.PROVIDES_CRITCHANCE },
	tuning =
	{
		[Power.Rarity.EPIC] = { bonus = 2.5, time = 5 },
		[Power.Rarity.LEGENDARY] = { bonus = 5, time = 5 },
	},

	get_counter_text = powerutil.GetCounterTextPlusPercent,
	on_add_fn = on_add_stacking_crit_buff_power,
	on_update_fn = stacking_crit_buff_onupdate,
	on_remove_fn = on_remove_stacking_crit_buff_power,
	tooltips =
	{
		"CRIT_CHANCE",
		"CRITICAL_HIT",
	},
	event_triggers =
	{
		['do_damage'] = function(pow, inst, attack)
			if attack:GetCrit() then
				add_stacking_crit_buff(pow, inst, pow.persistdata:GetVar("bonus"))
			end
		end,
	}
})

Power.AddPlayerPower("lasting_power",
{
	power_category = Power.Categories.DAMAGE,
	tags = { POWER_TAGS.PROVIDES_CRITCHANCE, POWER_TAGS.USES_HITSTREAK },
	tuning =
	{
		[Power.Rarity.EPIC] = { bonus = 1, time = 10 },
		[Power.Rarity.LEGENDARY] = { bonus = 1, time = 15 },
	},

	get_counter_text = powerutil.GetCounterTextPlusPercent,
	on_add_fn = on_add_stacking_crit_buff_power,
	on_update_fn = stacking_crit_buff_onupdate,
	on_remove_fn = on_remove_stacking_crit_buff_power,
	tooltips =
	{
		"HIT_STREAK",
		"CRIT_CHANCE",
		"CRITICAL_HIT",
	},
	event_triggers =
	{
		['hitstreak_killed'] = function(pow, inst, data)
			if not inst:IsLocal() then
				return
			end
			local crit_bonus = data.hitstreak * pow.persistdata:GetVar("bonus")
			add_stacking_crit_buff(pow, inst, crit_bonus)
		end,
	}
})

-- Power.AddPlayerPower("critical_roll",
-- {
-- 	power_category = Power.Categories.DAMAGE,
-- 	tuning =
-- 	{
-- 		[Power.Rarity.COMMON] = { bonus = 10, time = 10 },
-- 		[Power.Rarity.EPIC] = { bonus = 25, time = 10 },
-- 		[Power.Rarity.LEGENDARY] = { bonus = 50, time = 10 },
-- 	},

-- 	on_add_fn = on_add_stacking_crit_buff_power,
-- 	on_update_fn = stacking_crit_buff_onupdate,
-- 	on_remove_fn = on_remove_stacking_crit_buff_power,

-- 	event_triggers =
-- 	{
-- 		["hitboxcollided_invincible"] = function(pow, inst, data)
-- 			if inst.sg:HasStateTag("dodge") then
-- 				add_stacking_crit_buff(pow, inst, pow.persistdata:GetVar("bonus"))
-- 			end
-- 		end,
-- 	},
-- })

Power.AddPlayerPower("optimism",
{
	power_category = Power.Categories.DAMAGE,
	tags = { POWER_TAGS.PROVIDES_CRITCHANCE },
	required_tags = { POWER_TAGS.PROVIDES_FREQUENT_HEALING },
	tuning =
	{
		[Power.Rarity.COMMON] = { bonus = 2.5, time = 10 },
		[Power.Rarity.EPIC] = { bonus = 7.5, time = 10 },
		[Power.Rarity.LEGENDARY] = { bonus = 15, time = 10 },
	},

	get_counter_text = powerutil.GetCounterTextPlusPercent,
	on_add_fn = on_add_stacking_crit_buff_power,
	on_update_fn = stacking_crit_buff_onupdate,
	on_remove_fn = on_remove_stacking_crit_buff_power,
	tooltips =
	{
		"CRIT_CHANCE",
		"CRITICAL_HIT",
	},
	event_triggers =
	{
		["healthchanged"] = function(pow, inst, data)
			if data.new > data.old then
				add_stacking_crit_buff(pow, inst, pow.persistdata:GetVar("bonus"))
			end
		end,
	},
})

-- Power.AddPlayerPower("crit_to_crit_damage",
-- {
-- 	power_category = Power.Categories.DAMAGE,
-- 	required_tags = { POWER_TAGS.PROVIDES_CRITCHANCE },
-- 	tuning =
-- 	{
-- 		[Power.Rarity.EPIC] = {},
-- 	},
-- 	tooltips =
-- 	{
-- 		"CRIT_DAMAGE",
-- 		"CRIT_CHANCE",
-- 	},
-- 	damage_mod_fn = function(pow, attack, output_data)
-- 		local bonus = 0
-- 		if attack:GetCrit() then
-- 			bonus = 1
-- 		else
-- 			bonus = attack:GetTotalCritChance()
-- 		end
-- 		attack:DeltaBonusCritDamageMult(bonus)
-- 		return true
-- 	end,
-- })

Power.AddPlayerPower("bad_luck_protection",
{
	power_category = Power.Categories.DAMAGE,
	tags = { POWER_TAGS.PROVIDES_CRITCHANCE },
	tuning =
	{
		[Power.Rarity.EPIC] = { bonus = 1 },
		[Power.Rarity.LEGENDARY] = { bonus = 3 },
	},
	tooltips =
	{
		"CRIT_CHANCE",
		"CRITICAL_HIT",
	},

	get_counter_text = powerutil.GetCounterTextPlusPercent,

	on_add_fn = function(pow, inst)
		if not pow.persistdata.did_init then
			pow.persistdata.crit_bonus = 0
			pow.persistdata.did_init = true
		end
	end,

	event_triggers =
	{
		["do_damage"] = function(pow, inst, attack)
			if not attack:GetCrit() then
				pow.persistdata.crit_bonus = pow.persistdata.crit_bonus + pow.persistdata:GetVar("bonus")
			else
				pow.persistdata.crit_bonus = 0
			end

			inst.components.combat:SetCritChanceModifier(pow, pow.persistdata.crit_bonus * 0.01)
			pow.persistdata.counter = math.floor(pow.persistdata.crit_bonus)
			inst:PushEvent("update_power", pow.def)
		end,
	},
})

Power.AddPlayerPower("precision_weaponry",
{
	power_category = Power.Categories.DAMAGE,
	tags = { POWER_TAGS.PROVIDES_CRITCHANCE, POWER_TAGS.USES_HITSTREAK },
	tuning =
	{
		[Power.Rarity.EPIC] = { count = 10 },
		[Power.Rarity.LEGENDARY] = { count = 5 },
	},
		tooltips =
	{
		"HIT_STREAK",
		"CRITICAL_HIT",
	},
	damage_mod_fn = function(pow, attack, output_data)
		if attack:GetAttacker() ~= attack:GetTarget() and attack:CheckChain(pow.def.name) == nil then
			local hitstreak = attack:GetAttacker().components.combat:GetHitStreak() + 1 -- kinda gross! order of operations: GetHitStreak() is updated after this function is evaluated, so +1 to account for this new hit
			local target = pow.persistdata:GetVar("count")

			if hitstreak ~= 0 and hitstreak % target == 0 then
				attack:SetCrit(true)
				return true
			end
		end
	end,
})


Power.AddPlayerPower("pick_of_the_litter",
{
	power_category = Power.Categories.SUPPORT,
	tags = { "" },
	tuning =
	{
		-- [Power.Rarity.EPIC] = { count = 1, options = STRINGS.ITEMS.PLAYER.pick_of_the_litter.single_string }, -- jambell: disabling this for now because this breaks our screen layout.
		[Power.Rarity.LEGENDARY] = { count = 1,  options = STRINGS.ITEMS.PLAYER.pick_of_the_litter.single_string },
	},
		tooltips =
	{
	},

	on_add_fn = function(pow, inst, is_upgrade)
		local more_choices = is_upgrade and pow.persistdata:GetVar("count") - 1 or pow.persistdata:GetVar("count")
		inst.components.powermanager.power_drop_choices = inst.components.powermanager.power_drop_choices + more_choices
	end,
})



-- First One's Free: When you choose a relic, it is automatically upgraded

Power.AddPlayerPower("free_upgrade",
{
	power_category = Power.Categories.SUPPORT,
	tuning =
	{
		[Power.Rarity.LEGENDARY] = {},
	},

	event_triggers =
	{
		["add_power"] = function(pow, inst, added_power)
			inst.components.powermanager:UpgradePower(added_power.def)
			inst:PushEvent("used_power", pow.def)
		end,
	},
})

-- Shrapnel: Destroying a destructible prop spawns a projectile

Power.AddPlayerPower("shrapnel",
{
	power_category = Power.Categories.DAMAGE,
	tuning =
	{
		[Power.Rarity.EPIC] = { damage = 500, projectiles = 2 },
		[Power.Rarity.LEGENDARY] = { damage = 500, projectiles = 4 },
	},

	event_triggers =
	{
		["kill"] = function(pow, inst, data)
			local victim = data.attack:GetTarget()
			if victim and victim:HasTag("prop") then
				local angles = { 0, 180, 90, -90 }
				for i = 1, pow.persistdata:GetVar("projectiles") do
					local angle = angles[i]
					local bullet = SGCommon.Fns.SpawnAtAngleDist(victim, "generic_projectile", 0, angle)
					-- why does this look different from other projectile Setup functions?
					bullet:Setup(inst, nil, pow.def.name, pow.persistdata:GetVar("damage"))
				end
				inst:PushEvent("used_power", pow.def)

				local params = {}
				params.fmodevent = fmodtable.Event.Power_Shrapnel
				params.sound_max_count = 1
				local handle = soundutil.PlaySoundData(inst, params)
				soundutil.SetInstanceParameter(inst, handle, "upgrade_level", Power.GetRarityAsParameter(pow.persistdata))
			end
		end,
	},
})

Power.AddPlayerPower("fractured_weaponry",
{
	power_category = Power.Categories.DAMAGE,
	prefabs = { "megatreemon_bomb_projectile", "trap_bomb_pinecone", GroupPrefab("fx_warning"), },
	tuning =
	{
		[Power.Rarity.EPIC] = { count = 10,  num_bombs = 1 },
		[Power.Rarity.LEGENDARY] = { count = 5,  num_bombs = 1 },
	},
	tags = { POWER_TAGS.USES_HITSTREAK },
	tooltips =
	{
		"HIT_STREAK",
	},

	event_triggers =
	{
		["do_damage"] = function(pow, inst, attack)
			if attack:GetTarget() ~= inst and attack:CheckChain(pow.def.name) == nil then
				local hitstreak = inst.components.combat:GetHitStreak() + 1 -- kinda gross! order of operations: GetHitStreak() is updated after this function is evaluated, so +1 to account for this new hit
				local target = pow.persistdata:GetVar("count")
				if hitstreak ~= 0 and hitstreak % target == 0 then
					for i = 1, pow.persistdata:GetVar("num_bombs"), 1 do
							-- This is a copy of bomb_on_dodge's logic.
						local bomb = SpawnPrefab("megatreemon_bomb_projectile", inst)
						local pos = inst:GetPosition()
						pos.y = 0
						bomb.Transform:SetPosition(pos.x, 2, pos.z)
						local target_pos = combatutil.GetWalkableOffsetPosition(inst:GetPosition(), 5, 10)
						bomb:PushEvent("thrown", {x = target_pos.x, z = target_pos.z})
					end
					inst:PushEvent("used_power", pow.def)
				end
			end
		end,
	}
})

Power.AddPlayerPower("weighted_weaponry",
{
	power_category = Power.Categories.DAMAGE,
	tuning =
	{
		[Power.Rarity.EPIC] = { count = 10,  percent = 100 },
		[Power.Rarity.LEGENDARY] = { count = 10,  percent = 200 },
	},
	tags = { POWER_TAGS.USES_HITSTREAK },
	tooltips =
	{
		"HIT_STREAK",
		"CRITICAL_HIT",
	},

	event_triggers =
	{
		["hitstreak"] = function(pow, inst, data)
			if inst:IsLocal() and data.hitstreak > (pow.persistdata:GetVar("count") - 1) and not pow.persistdata.active then
				pow.persistdata.active = true
				inst.components.combat:SetCritDamageMult(pow, pow.persistdata:GetVar("percent") * 0.01)
			end
		end,

		["hitstreak_killed"] = function(pow, inst, data)
			if not inst:IsLocal() then
				return
			end
			pow.persistdata.active = false
			inst.components.combat:RemoveCritDamageModifier(pow)
		end,
	}
})

-- If you go x seconds without attacking, deal extra damage
Power.AddPlayerPower("analytical",
{
	power_category = Power.Categories.DAMAGE,
	tuning =
	{
		[Power.Rarity.EPIC] = { seconds = 5,  percent = 200 },
		[Power.Rarity.LEGENDARY] = { seconds = 8,  percent = 400 },
	},
	tags = { },
	tooltips =
	{
	},

	on_add_fn = function(pow, inst)
		pow:StartPowerTimer(inst, "update_"..pow.def.name, "seconds")
	end,

	damage_mod_fn = function(pow, attack, output_data)
		if (pow.persistdata.active or combatutil.IsPowerActiveForProjectileAttack(attack, pow)) and attack:GetAttacker() ~= attack:GetTarget() then
			local damage = (pow.persistdata:GetVar("percent") * 0.01) * attack:GetDamage()
			output_data.damage_delta = output_data.damage_delta + damage
			attack:GetAttacker():PushEvent("used_power", pow.def)
			return true
		end
	end,

	on_remove_fn = function(pow, inst)
	end,

	event_triggers =
	{
		["timerdone"] = function(pow, inst, data)
			local timer_name = "update_"..pow.def.name
			if data.name == timer_name then
				pow.persistdata.active = true
				powerutil.AttachParticleSystemToSymbol(pow, inst, "pump_and_dump_trail", "swap_fx") --TODO: replace with specific FX
				inst:PushEvent("update_power", pow.def)
			end
		end,

		--Melee attack
		["attack_end"] = function(pow, inst, data)
			local timer_name = "update_"..pow.def.name
			pow.persistdata.active = false
			inst.components.timer:StartTimer(timer_name, pow.persistdata:GetVar("seconds"), true)
			powerutil.StopAttachedParticleSystem(inst, pow) --TODO: replace with specific FX
			inst:PushEvent("update_power", pow.def)
		end,

		-- Projectile attack
		["projectile_launched"] = function(pow, inst, projectiles)
			if pow.persistdata.active then
				-- buff the projectile for its lifetime
				combatutil.ActivatePowerForProjectile(projectiles, pow)
			end

			inst.components.timer:StartTimer("update_"..pow.def.name, pow.persistdata:GetVar("seconds"), true)
			powerutil.StopAttachedParticleSystem(inst, pow) --TODO: replace with specific FX
			inst:PushEvent("update_power", pow.def)
			pow.persistdata.active = false
		end,
	}
})

-- Your Light Attack damages you when it whiffs, but deals extra damage
Power.AddPlayerPower("dont_whiff",
{
	power_category = Power.Categories.DAMAGE,
	tuning =
	{
		[Power.Rarity.EPIC] = { selfdamage = 25,  otherdamage = 25, blink_color = { 255/255, 50/255, 50/255, 1 }, blink_frames = 8 },
		[Power.Rarity.LEGENDARY] = { selfdamage = 50,  otherdamage = 50, blink_color = { 255/255, 25/255, 25/255, 1 }, blink_frames = 8 },
	},
	tags = { },

	tooltips =
	{
		"LIGHT_ATTACK",
	},

	on_add_fn = function(pow, inst)
	end,

	damage_mod_fn = function(pow, attack, output_data)
		if (attack:IsLightAttack() or combatutil.IsPowerActiveForProjectileAttack(attack, pow)) and attack:GetAttacker() ~= attack:GetTarget() then
			-- local damage = (pow.persistdata:GetVar("percent") * 0.01) * attack:GetDamage()
			output_data.damage_delta = output_data.damage_delta + pow.persistdata:GetVar("otherdamage")
			attack:GetAttacker():PushEvent("used_power", pow.def)
			return true
		end
	end,

	event_triggers =
	{
		--Melee attack
		["attack_end"] = function(pow, inst, targetshit)
			if #targetshit == 0 and inst.sg.mem.attack_type == "light_attack" then
				inst:DoTaskInAnimFrames(4, function()
					local power_attack = Attack(inst, inst)
					power_attack:SetDamage(pow.persistdata:GetVar("selfdamage"))
					power_attack:SetIgnoresArmour(true)
					power_attack:SetSkipPowerDamageModifiers(true)
					power_attack:SetSource(pow.def.name)
					-- power_attack:SetCannotKill(true)
					inst.components.combat:DoPowerAttack(power_attack)
					powerutil.SpawnParticlesAtPosition(inst:GetPosition(), "burst_bloodthirsty", 1, inst)

					SGCommon.Fns.BlinkAndFadeColor(inst, pow.persistdata:GetVar("blink_color"), pow.persistdata:GetVar("blink_frames"))
					inst:PushEvent("used_power", pow.def)
				end)
			end
		end,

		-- Projectile attack
		["projectile_launched"] = function(pow, inst, projectiles)
			-- buff the projectile for its lifetime
			combatutil.ActivatePowerForProjectile(projectiles, pow)

			inst:PushEvent("update_power", pow.def)
		end,
	}
})


Power.AddPlayerPower("dizzyingly_evasive",
{
	can_drop = false,
	power_category = Power.Categories.SUPPORT,
	tuning =
	{
		[Power.Rarity.LEGENDARY] = { rolls = 10 },
	},

	tags = { },

	tooltips =
	{
	},

	on_add_fn = function(pow, inst)
		inst.sg.mem.chainrolls = true
		-- inst.sg.mem.numrolls = pow.persistdata:GetVar("rolls")
	end,

	event_triggers =
	{
		-- Projectile attack
		["enter_room"] = function(pow, inst, projectiles)
			inst.sg.mem.chainrolls = true
			-- inst.sg.mem.numrolls = pow.persistdata:GetVar("rolls")
		end,
	}
})

-- When you hit with a light attack, gain Critical Chance. When you miss with a light attack, lose all bonus.
Power.AddPlayerPower("carefully_critical",
{
	power_category = Power.Categories.DAMAGE,

	stackable = true,
	permanent = true,

	tuning = {
		[Power.Rarity.LEGENDARY] = { bonus = 1 },
	},

	tooltips =
	{
		"LIGHT_ATTACK",
	},

	max_stacks = 100,

	get_counter_text = powerutil.GetCounterTextPlusPercent,

	on_add_fn = function(pow, inst)
		pow.persistdata.counter = 0
		inst:PushEvent("update_power", pow.def)
	end,

	on_stacks_changed_fn = function(pow, inst)
		pow.persistdata.counter = pow.persistdata.stacks
		inst.components.combat:SetCritChanceModifier(pow, pow.persistdata.stacks * 0.01)
		inst:PushEvent("update_power", pow.def)
	end,

	event_triggers =
	{
		["enter_room"] = function(pow, inst, data)
			-- update the UI to show percentage
			pow.persistdata.counter = pow.persistdata.stacks
			inst.components.combat:SetCritChanceModifier(pow, pow.persistdata.stacks * 0.01)
			inst:PushEvent("update_power", pow.def)
		end,

		["light_attack"] = function(pow, inst, data)
			if #data.targets_hit > 0 then
				local acceptable_target = false

				for i,target in ipairs(data.targets_hit) do
					if powerutil.EntityIsEnemyOrDestructibleProp(target) then
						acceptable_target = true
						break
					end
				end

				if acceptable_target then
					inst.components.powermanager:DeltaPowerStacks(pow.def, pow.persistdata:GetVar("bonus"))
				end
			else
				inst.components.powermanager:SetPowerStacks(pow.def, 0)
			end
		end,
	}
})

-- When you Dodge, reflect 50% of incoming damage for 4 seconds.
Power.AddPlayerPower("reflective_dodge",
{
	power_category = Power.Categories.DAMAGE,

	stackable = true,
	permanent = true,

	can_drop = false, --WARNING: this Attack may run multiple times over the network. If so, move the actual Attack creation + applying from defend_mod_fn --> "take_damage" eventlistener. Not fixing this for now because it's disabled anyway.
	show_in_ui = false,

	prefabs = { "fx_relics_retaliation_player", "fx_relics_retaliation_target" },
	tuning =
	{
		[Power.Rarity.EPIC] = { percent = 50, time = 2 },
		[Power.Rarity.LEGENDARY] = { percent = 75, time = 4 },
	},

	on_add_fn = function(pow, inst)
		inst:PushEvent("update_power", pow.def)
	end,

	--TODODEFEND
	defend_mod_fn = function(pow, attack, output_data)
		if pow.persistdata.active and attack:GetDamage() > 0 and attack:GetAttacker() ~= attack:GetTarget() and attack:GetAttacker().components.health then
			local reflect_recipient = attack:GetAttacker()
			local inst = attack:GetTarget()

			local dmg = attack:GetDamage()
			local reflected_dmg = dmg * (pow.persistdata:GetVar("percent")*0.01) -- send PERCENT of the damage to the attacker

			local relatiation_attack = Attack(inst, reflect_recipient)
			relatiation_attack:SetDamage(reflected_dmg)
			relatiation_attack:SetSource(pow.def.name)
			relatiation_attack:SetID(pow.def.name)
			relatiation_attack:SetPushback(1)
			relatiation_attack:SetHitstunAnimFrames(10)

			output_data.damage_delta = -(dmg * pow.persistdata:GetVar("percent")*0.01)

			--FX
			powerutil.SpawnFxOnEntity("fx_relics_retaliation_player", inst)
			local distance_to_delay =
			{
				{ 0, 2 },
				{ 5, 4 },
				{ 10, 6 },
				{ 15, 8 },
			}
			if reflect_recipient ~= nil and inst ~= nil then
				local dist = inst:GetDistanceSqTo(reflect_recipient)
				local delay = PiecewiseFn(math.sqrt(dist), distance_to_delay)
				reflect_recipient:DoTaskInAnimFrames(math.ceil(delay), function()
					if reflect_recipient ~= nil and inst ~= nil then
						inst.components.combat:DoPowerAttack(relatiation_attack)
						powerutil.SpawnPowerHitFx("fx_relics_retaliation_target", inst, reflect_recipient, 0, 1, HitStopLevel.HEAVY)
					end
				end)
			end
			return true
		end
	end,

	on_update_fn = function(pow, inst)
		if pow.persistdata.active then
			local timeleft = inst.components.timer:GetTimeRemaining("update_"..pow.def.name)
			pow.persistdata.counter = math.ceil(timeleft)
			inst.AnimState:SetSymbolBloom("head01", 200/255, 200/255, 200/255, timeleft/pow.persistdata:GetVar("time")) --TEMP FX
			inst:PushEvent("update_power", pow.def)
			-- print("UPDATE:", timeleft)
		else
			-- print("UPDATE: POWER NOT ACTIVE!")
			pow.persistdata.counter = 0
			inst:PushEvent("update_power", pow.def)
		end
	end,

	event_triggers =
	{
		["dodge"] = function(pow, inst, data)
			pow.persistdata.active = true
			pow:StartPowerTimer(inst, "update_"..pow.def.name)
			inst.AnimState:SetSymbolBloom("head01", 200/255, 200/255, 200/255, 1) --TEMP FX
			inst:PushEvent("update_power", pow.def)
		end,

		["timerdone"] = function(pow, inst, data)
			pow.persistdata.active = false
			pow.persistdata.counter = 0
			inst:PushEvent("update_power", pow.def)
			inst.AnimState:SetSymbolBloom("head01", 0, 0, 0, 0) --TEMP FX
		end,
	}
})

-- When you Light Attack, your next attack deals 50% Damage if it is another Light Attack but 200% Damage if it is a Heavy Attack.
Power.AddPlayerPower("ping",
{
	power_category = Power.Categories.DAMAGE,

	prefabs = { },
	tuning =
	{
		[Power.Rarity.LEGENDARY] = { buff = 200, nerf = 50 },
	},

	tooltips =
	{
		"LIGHT_ATTACK",
		"HEAVY_ATTACK",
	},

	on_add_fn = function(pow, inst)
		inst:PushEvent("update_power", pow.def)
	end,

	damage_mod_fn = function(pow, attack, output_data)
		local damagemult
		if attack:GetID() == pow.persistdata.buff then
			damagemult = pow.persistdata:GetVar("buff")/100
		-- elseif attack:GetID() == pow.persistdata.nerf then
		-- 	damagemult = -pow.persistdata:GetVar("nerf")/100
		end

		if damagemult then
			output_data.damage_delta = output_data.damage_delta + (attack:GetDamage() * damagemult)
		end
	end,

	on_net_serialize_fn = function(powinst, e)
		e:SerializeBoolean(powinst.persistdata.buff ~= nil)
		if powinst.persistdata.buff then
			e:SerializeString(powinst.persistdata.buff)
		end
	end,

	on_net_deserialize_fn = function(powinst, e)
		if e:DeserializeBoolean() then
			powinst.persistdata.buff = e:DeserializeString()
		else
			powinst.persistdata.buff = nil
		end
	end,

	event_triggers =
	{
		["light_attack"] = function(pow, inst, data)
			pow.persistdata.buff = "heavy_attack"
			-- pow.persistdata.nerf = "light_attack"
		end,

		["heavy_attack"] = function(pow, inst, data)
			pow.persistdata.buff = nil
			-- pow.persistdata.nerf = nil
		end,
	}
})

-- When you Heavy Attack, your next attack deals 50% Damage if it is another Heavy Attack but 200% Damage if it is a Light Attack.
Power.AddPlayerPower("pong",
{
	power_category = Power.Categories.DAMAGE,

	prefabs = { },
	tuning =
	{
		[Power.Rarity.LEGENDARY] = { buff = 200, nerf = 50 },
	},

	tooltips =
	{
		"HEAVY_ATTACK",
		"LIGHT_ATTACK",
	},

	on_add_fn = function(pow, inst)
		inst:PushEvent("update_power", pow.def)
	end,

	damage_mod_fn = function(pow, attack, output_data)
		local damagemult
		if attack:GetID() == pow.persistdata.buff then
			damagemult = pow.persistdata:GetVar("buff")/100
		-- elseif attack:GetID() == pow.persistdata.nerf then
			-- damagemult = -pow.persistdata:GetVar("nerf")/100
		end

		if damagemult then
			output_data.damage_delta = output_data.damage_delta + (attack:GetDamage() * damagemult)
		end
	end,

	on_net_serialize_fn = function(powinst, e)
		e:SerializeBoolean(powinst.persistdata.buff ~= nil)
		if powinst.persistdata.buff then
			e:SerializeString(powinst.persistdata.buff)
		end
	end,

	on_net_deserialize_fn = function(powinst, e)
		if e:DeserializeBoolean() then
			powinst.persistdata.buff = e:DeserializeString()
		else
			powinst.persistdata.buff = nil
		end
	end,

	event_triggers =
	{
		["light_attack"] = function(pow, inst, data)
			pow.persistdata.buff = nil
			-- pow.persistdata.nerf = nil
		end,

		["heavy_attack"] = function(pow, inst, data)
			pow.persistdata.buff = "light_attack"
			-- pow.persistdata.nerf = "heavy_attack"
		end,
	}
})


-- -- Loot Influencing Powers
-- -- For every mob, a power that increases chances of their loot

-- Only turn on a few of these per run, not all of them.
-- Only allow these to drop in biomes where the mob is.

-- WARNING: Don't show these as actual numerical values, unless you figure out a way to make it grokable to the player.
Power.AddPlayerPower("loot_increase_cabbageroll",
{
	power_category = Power.Categories.SUPPORT,

	can_drop = false, --TODO(jambell): restrict to biomes where cabbageroll spawns

	prefabs = { },
	tuning =
	{
		-- jambell: ugh, these values are pretty hard to make globally relevant for all mob types.
		-- probably need to systemize these drop loot_values to make these easier to make.
		[Power.Rarity.COMMON] = { delta = 2, upgrade_text = "" },
		[Power.Rarity.EPIC] = { delta = 4, upgrade_text = STRINGS.ITEMS.PLAYER.loot_increase_upgrade_epic},
		[Power.Rarity.LEGENDARY] = { delta = 6, upgrade_text = STRINGS.ITEMS.PLAYER.loot_increase_upgrade_legendary},
	},

	tooltips =
	{
		"MATERIALS",
	},

	on_add_fn = function(pow, inst)
		inst.components.lootdropmanager:AddMobDeltaModifier(pow.def.name, "cabbageroll", pow.persistdata:GetVar("delta"))
	end,

	on_remove_fn = function(pow, inst)
		inst.components.lootdropmanager:RemoveMobDeltaModifier(pow.def.name, "cabbageroll")
	end,
})

Power.AddPlayerPower("loot_increase_blarmadillo",
{
	power_category = Power.Categories.SUPPORT,

	can_drop = false, --TODO(jambell): restrict to biomes where cabbageroll spawns

	prefabs = { },
	tuning =
	{
		[Power.Rarity.COMMON] = { delta = 2, upgrade_text = "" },
		[Power.Rarity.EPIC] = { delta = 4, upgrade_text = STRINGS.ITEMS.PLAYER.loot_increase_upgrade_epic},
		[Power.Rarity.LEGENDARY] = { delta = 6, upgrade_text = STRINGS.ITEMS.PLAYER.loot_increase_upgrade_legendary},
	},

	tooltips =
	{
		"MATERIALS",
	},

	on_add_fn = function(pow, inst)
		inst.components.lootdropmanager:AddMobDeltaModifier(pow.def.name, "blarmadillo", pow.persistdata:GetVar("delta"))
	end,

	on_remove_fn = function(pow, inst)
		inst.components.lootdropmanager:RemoveMobDeltaModifier(pow.def.name, "blarmadillo")
	end,
})

Power.AddPlayerPower("max_health_wanderer",
{
	power_category = Power.Categories.SUSTAIN,
	can_drop = false, -- Only attainable from the wanderer
	tuning = {
		[Power.Rarity.COMMON] = { health = 250 },
		[Power.Rarity.EPIC] = { health = 500 },
		[Power.Rarity.LEGENDARY] = { health = 750 },
	},

	get_counter_text = powerutil.GetCounterTextPlus,

	on_add_fn = function(pow, inst, is_upgrade)
		if not pow.persistdata.did_init then
			pow.persistdata.did_init = true
			pow.persistdata.upgrade_data = {}
		end

		if pow.persistdata.upgrade_data[pow.persistdata.rarity] == nil then -- We haven't yet added health for this rarity level
			pow.persistdata.upgrade_data[pow.persistdata.rarity] = true
			local health_mod = pow.persistdata:GetVar("health")
			pow.persistdata.counter = math.floor(health_mod)
			inst.components.health:AddHealthAddModifier(pow.def.name, health_mod)

			inst.components.health:DoDelta(health_mod, true)
			-- local power_heal = Attack(inst, inst)
			-- power_heal:SetHeal(health_mod)
			-- power_heal:SetSource(pow)
			-- inst.components.combat:ApplyHeal(power_heal)
		end

		inst:PushEvent("used_power", pow.def)
	end,
})

-- ??: Toss a bomb each time you hit a Hit Streak of 10 (or multiples)

-- ??: Crits when on a Hit Streak of 10+ do double damage

-- POWER IDEAS:

-- when you crit, gain x% move speed for y seconds

-- when you crit, gain 1 shield segment

-- when you crit, apply 1 charge

-- when you hit 100% crit chance, additional crit chance becomes additional damage

-- "Float like a Butterfly" (extra iFrame window on dodge)

-- Dead Weight: power that does nothing, but does something really really good on remove

-- On My Fingers: hitstreak power that does something if you do consecutive hitstreaks in numerical order (1 2 3, or 4 5 6, or 7 8 9, etc)

-- Hammer power: overhead spin slam causes explosion (which does hit the player)

-- Drop Glitz on hitstreak / etc

-- Powers that last for a specific set of rooms
		-- Challenge powers to take on -- e.g. get 20 iframe dodges in 5 rooms: fail, get a curse -- succeed, get a powerful power
		-- Powerful power that lasts temporarily
		-- Negative power that gets removed after X rooms, and is replaced with a great power
