local Power = require("defs.powers.power")
local Consumable = require "defs.consumable"
local lume = require"util.lume"
local fmodtable = require "defs.sound.fmodtable"
local soundutil = require "util.soundutil"
local powerutil = require "util.powerutil"
local LootEvents = require "lootevents"

function Power.AddRevivePower(id, data)
	data.power_type = Power.Types.RELIC
	data.minimum_player_count = 2
	Power.AddPower(Power.Slots.PLAYER, id, "player_powers", data)
end

local function IsAValidRevive(pow, inst, data)
	local valid = true
	if data.health <= 1 then
		-- Prevent infinite reviving with no health.
		valid = false
	end

	return valid
end

-- Gain konjur when you revive an ally
Power.AddRevivePower("revive_gain_konjur",
{
	--JAMBELL: try % of health given
	power_category = Power.Categories.SUSTAIN,
	tuning =
	{
		[Power.Rarity.COMMON] = { konjur = 50 },
		[Power.Rarity.EPIC] = { konjur = 150 },
		[Power.Rarity.LEGENDARY] = { konjur = 250 },
	},

	event_triggers =
	{
		["revive"] = function(pow, inst, data)
			if not IsAValidRevive(pow, inst, data) then
				return
			end

			LootEvents.MakeEventSpawnCurrency(pow.persistdata:GetVar("konjur"), inst:GetPosition(), inst, false, true)
		end,
	}
})

Power.AddRevivePower("revive_explosion",
{
	--JAMBELL: this is basically grand entrance. Fine for prototype, but how to make more unique? Is it OK if it's not unique?
	-- TODO: make it in an area around the downed player
	power_category = Power.Categories.DAMAGE,
	tuning =
	{
		[Power.Rarity.COMMON] = { damage = 300 },
		[Power.Rarity.EPIC] = { damage = 500 },
		[Power.Rarity.LEGENDARY] = { damage = 1000 },
	},

	event_triggers =
	{
		["revive"] = function(pow, inst, data)
			if not IsAValidRevive(pow, inst, data) then
				return
			end

			local proced = false
			local ents = FindEnemiesInRange(0, 0, 1000)
			for i, ent in ipairs(ents) do
				proced = true
				inst:DoTaskInAnimFrames(math.random(10), function()
					if ent:IsValid() then
						local power_attack = Attack(inst, ent)
						power_attack:SetDamage(pow.persistdata:GetVar("damage"))
						power_attack:SetHitstunAnimFrames(5)
						power_attack:SetPushback(0)
						power_attack:SetSource(pow.def.name)

						inst.components.combat:DoPowerAttack(power_attack)

						ent.components.combat:SetTarget(inst)
						powerutil.SpawnPowerHitFx("hits_first_contact", inst, ent, 0, 0, HitStopLevel.NONE) --SLOTH: revive_explosion fx
					end
				end)
			end
			if proced then
				--sound
				local params = {}
				params.fmodevent = fmodtable.Event.Power_bigStick_Explode --LUCA: revive_explosion sound
				params.sound_max_count = 1
				soundutil.PlaySoundData(inst, params)
			end
			inst:PushEvent("used_power", pow.def)
		end
	}
})

local get_revive_damage_bonus_total = function(pow)
	-- Count up the amount of procs we had, respecting what rarity the power was at when it proc'd.
	local tuning = pow.def.tuning

	local total_percent = 0
	if pow.persistdata.procs then
		for rarity,count in pairs(pow.persistdata.procs) do
			local amount_per_count = tuning[rarity].percent_per_revive
			total_percent = total_percent + amount_per_count*count
		end
	end

	return total_percent
end

Power.AddRevivePower("revive_damage_bonus",
{
	--JAMBELL:
	power_category = Power.Categories.DAMAGE,
	tuning =
	{
		[Power.Rarity.COMMON] = { percent_per_revive = 10 },
		[Power.Rarity.EPIC] = { percent_per_revive = 20 },
		[Power.Rarity.LEGENDARY] = { percent_per_revive = 30 }, -- Getting many procs of this will be rare -- you'll have to get this power, upgrade it twice, THEN have an ally die. Try being very spiky! Maybe more than this?
	},

	damage_mod_fn = function(pow, attack, output_data)
		local damage_mod = get_revive_damage_bonus_total(pow) * 0.01
		output_data.damage_delta = output_data.damage_delta + (attack:GetDamage() * damage_mod)
		return true
	end,

	get_counter_text = powerutil.GetCounterTextPlusPercent,

	on_add_fn = function(pow, inst)
		if not pow.persistdata.did_init then
			pow.persistdata.procs =
			{
				COMMON = 0,
				EPIC = 0,
				LEGENDARY = 0,
			}
			pow.persistdata.counter = 0
			inst:PushEvent("update_power", pow.def)
			pow.persistdata.did_init = true
		end
	end,

	event_triggers =
	{
		["enter_room"] = function(pow, inst, data)
			-- update the UI to show percentage
			local bonus = get_revive_damage_bonus_total(pow)
			pow.persistdata.counter = bonus
			inst:PushEvent("update_power", pow.def)
		end,
		["revive"] = function(pow, inst, data)
			if not IsAValidRevive(pow, inst, data) then
				return
			end

			local current_rarity = pow.persistdata.rarity
			pow.persistdata.procs[current_rarity] = pow.persistdata.procs[current_rarity] + 1

			local bonus = get_revive_damage_bonus_total(pow)
			pow.persistdata.counter = bonus
			inst:PushEvent("update_power", pow.def)
		end
	},
})

Power.AddRevivePower("revive_borrow_power",
{
	--JAMBELL:
	power_category = Power.Categories.SUPPORT,
	can_drop = false,
	tuning =
	{
		[Power.Rarity.COMMON] = { powers_borrowed = 1 },
		[Power.Rarity.EPIC] = { powers_borrowed = 2 },
		[Power.Rarity.LEGENDARY] = { powers_borrowed = 3 }, -- Getting many procs of this will be rare -- you'll have to get this power, upgrade it twice, THEN have an ally die. Try being very spiky! Maybe more than this?
	},

	on_add_fn = function(pow, inst)
		pow.mem.borrowed_powers = {}
	end,

	event_triggers =
	{
		["exit_room"] = function(pow, inst, data)
			for _,pow in ipairs(pow.mem.borrowed_powers) do
				inst.components.powermanager:RemovePower(pow.def, true)
			end
		end,

		["revive"] = function(pow, inst, data)
			local my_pm = inst.components.powermanager
			local revivee = data.revivee
			local powers = revivee.components.powermanager:GetAllRelicPowersInAcquiredOrder()

			local rng = TheDungeon:GetDungeonMap():GetRNG() --TODO: replace with a player RNG
			powers = rng:Shuffle(powers)

			for i=0, pow.persistdata:GetVar("powers_borrowed") do
				local borrowed_power
				for _,pow in pairs(powers) do
					if not my_pm:HasPower(pow.def) then
						borrowed_power = pow
						break
					end
				end

				if borrowed_power then
					my_pm:AddPower(my_pm:CreatePower(borrowed_power.def))

					local new_power = my_pm:GetPower(borrowed_power.def)
					if borrowed_power.persistdata.rarity ~= new_power.persistdata.rarity then
						new_power.persistdata:SetRarity(borrowed_power.persistdata.rarity)
						inst:PushEvent("update_power", new_power.def)
					end

					table.insert(pow.mem.borrowed_powers, new_power)
				end
			end
		end
	},
})

-- Power.AddRevivePower("revive_heal",
-- {
-- 	--JAMBELL:
-- 	power_category = Power.Categories.SUSTAIN,
-- 	tuning =
-- 	{
-- 		[Power.Rarity.COMMON] = { heal = 50 },
-- 		[Power.Rarity.EPIC] = { heal = 100 },
-- 		[Power.Rarity.LEGENDARY] = { heal = 150 }, -- Getting many procs of this will be rare -- you'll have to get this power, upgrade it twice, THEN have an ally die. Try being very spiky! Maybe more than this?
-- 	},

-- 	on_add_fn = function(pow, inst)
-- 		pow.mem.borrowed_powers = {}
-- 	end,

-- 	event_triggers =
-- 	{
-- 		["revive"] = function(pow, inst, data)
-- 			local power_heal = Attack(inst, inst)
-- 			power_heal:SetHeal(pow.persistdata:GetVar("heal"))
-- 			power_heal:SetSource(pow.def.name)
-- 			inst.components.combat:ApplyHeal(power_heal)
-- 			inst:PushEvent("used_power", pow.def)
-- 		end
-- 	},
-- })



-- When reviving, all enemies within a radius are slowed
