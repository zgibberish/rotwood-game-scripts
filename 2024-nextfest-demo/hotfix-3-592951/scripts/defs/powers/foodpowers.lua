local Power = require("defs.powers.power")
local Consumable = require "defs.consumable"
local lume = require "util.lume"
local powerutil = require "util.powerutil"

function Power.AddFoodPower(id, data)
	if not data.power_category then
		data.power_category = Power.Categories.SUSTAIN
	end

	if data.tags ~= nil and not lume.find(data.tags, "food") then
		table.insert(data.tags, "food")
	else
		data.tags = {"food"}
	end

	data.power_type = Power.Types.FOOD
	data.can_drop = false
	data.upgradeable = false

	Power.AddPower(Power.Slots.FOOD_POWER, id, "food_powers", data)
end

Power.AddPowerFamily("FOOD_POWER")

Power.AddFoodPower("thick_skin",
{
	power_category = Power.Categories.SUSTAIN,
	tuning = {
		[Power.Rarity.COMMON] = { reduction = 10 },
		[Power.Rarity.EPIC] = { reduction = 15 },
		[Power.Rarity.LEGENDARY] = { reduction = 20 },
	},

	on_add_fn = function(pow, inst)
		inst.components.combat:SetDamageReduction(pow, pow.persistdata:GetVar("reduction"))
	end,

	on_remove_fn = function(pow, inst)
		inst.components.combat:RemoveDamageReduction(pow)
	end,
})

Power.AddFoodPower("heal_on_enter",
{
	power_category = Power.Categories.SUSTAIN,
	tags = { POWER_TAGS.PROVIDES_HEALING },
	tuning = {
		[Power.Rarity.COMMON] = { heal = 20 },
		[Power.Rarity.EPIC] = { heal = 40 },
		[Power.Rarity.LEGENDARY] = { heal = 60 },
	},
	event_triggers =
	{
		["start_gameplay"] = function(pow, inst, data)
			local power_heal = Attack(inst, inst)
			power_heal:SetHeal(pow.persistdata:GetVar("heal"))
			power_heal:SetSource(pow.def.name)
			inst.components.combat:ApplyHeal(power_heal)

			inst:PushEvent("used_power", pow.def)
		end,
	}
})

Power.AddFoodPower("max_health",
{
	power_category = Power.Categories.SUSTAIN,
	can_drop = false,
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

Power.AddFoodPower("max_health_on_enter",
{
	power_category = Power.Categories.SUSTAIN,
	tuning =
	{
		[Power.Rarity.COMMON] = { max_health = 20, heal = 10, },
		[Power.Rarity.EPIC] = { max_health = 40, heal = 20, },
		[Power.Rarity.LEGENDARY] = { max_health = 60, heal = 30, },
	},

	get_counter_text = powerutil.GetCounterTextPlus,

	on_add_fn = function(pow, inst, is_upgrade)
		if not pow.persistdata.did_init then
			inst.components.health:AddHealthAddModifier(pow.def.name, 0)
			pow.persistdata.upgrade_data = {}
			pow.persistdata.counter = 0
			pow.persistdata.did_init = true
		end
	end,

	event_triggers =
	{
		["start_gameplay"] = function(pow, inst, data)
			table.insert(pow.persistdata.upgrade_data, pow.persistdata:GetVar("health"))

			local health_mod = 0
			for _, mod in ipairs(pow.persistdata.upgrade_data) do
				health_mod = health_mod + mod
			end

			pow.persistdata.counter = math.floor(health_mod)
			inst.components.health:AddHealthAddModifier(pow.def.name, health_mod)

			local power_heal = Attack(inst, inst)
			power_heal:SetHeal(pow.persistdata:GetVar("health"))
			power_heal:SetSource(pow.def.name)
			inst.components.combat:ApplyHeal(power_heal)

			inst:PushEvent("used_power", pow.def)
		end,
	}
})

-- Retail Therapy: When you enter a shop, heal X HP
Power.AddFoodPower("retail_therapy",
{
	power_category = Power.Categories.SUSTAIN,
	tuning =
	{
		[Power.Rarity.COMMON] = { heal = 100 },
		[Power.Rarity.EPIC] = { heal = 200 },
		[Power.Rarity.LEGENDARY] = { heal = 300 },
	},

	event_triggers =
	{
		["enter_room"] = function(pow, inst, data)
			local valid_rooms =
			{
				food = true,
				potion = true,
				powerupgrade = true,
			}

			local roomtype = TheDungeon:GetDungeonMap():GetCurrentRoomType()

			if valid_rooms[roomtype] then
				local power_heal = Attack(inst, inst)
				power_heal:SetHeal(pow.persistdata:GetVar("heal"))
				power_heal:SetSource(pow.def.name)
				inst.components.combat:ApplyHeal(power_heal)
				inst:PushEvent("used_power", pow.def)
			end
		end,
	},
})

-- Potion heals for more
Power.AddFoodPower("perfect_pairing",
{
	power_category = Power.Categories.SUSTAIN,
	tuning =
	{
		[Power.Rarity.COMMON] = { bonus_heal = 25 },
		[Power.Rarity.EPIC] = { bonus_heal = 50 },
		[Power.Rarity.LEGENDARY] = { bonus_heal = 75 },
	},

	heal_mod_fn = function(pow, heal, output_data)
		if heal:IsPotionHeal() then
			output_data.heal_delta = output_data.heal_delta + (heal:GetHeal() * (pow.persistdata:GetVar("bonus_heal") * 0.01))
			return true
		end
	end,
})

-- start the run with X Konjur
Power.AddFoodPower("pocket_money",
{
	power_category = Power.Categories.SUSTAIN,
	tuning =
	{
		[Power.Rarity.COMMON] = { konjur = 30 },
		[Power.Rarity.EPIC] = { konjur = 60 },
		[Power.Rarity.LEGENDARY] = { konjur = 90 },
	},

	on_add_fn = function(pow, inst)
		if not pow.persistdata.did_init then
			inst.components.inventoryhoard:AddStackable(Consumable.Items.MATERIALS.konjur, pow.persistdata:GetVar("konjur"))
			pow.persistdata.did_init = true
		end
	end
})

-- heal +X% whenever you pick up Konjur
Power.AddFoodPower("private_healthcare",
{
	power_category = Power.Categories.SUSTAIN,
	tuning =
	{
		[Power.Rarity.COMMON] = { percent = 50 },
		[Power.Rarity.EPIC] = { percent = 100 },
		[Power.Rarity.LEGENDARY] = { percent = 150 },
	},

	event_triggers =
	{
		["add_stackable"] = function(pow, inst, data)
			if data.def == Consumable.Items.MATERIALS.konjur and data.quantity > 0 then
				local heal_amount = math.max(data.quantity * (pow.persistdata:GetVar("percent") * 0.01), 1)
				heal_amount = math.ceil(heal_amount)
				local power_heal = Attack(inst, inst)
				power_heal:SetHeal(heal_amount)
				power_heal:SetSource(pow.def.name)
				inst.components.combat:ApplyHeal(power_heal)
				inst:PushEvent("used_power", pow.def)
			end
		end,
	}
})
