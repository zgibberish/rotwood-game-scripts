local Power = require("defs.powers.power")

function Power.AddPotionPower(id, data)
	if not data.power_category then
		data.power_category = Power.Categories.SUSTAIN
	end

	if data.tags ~= nil and not table.contains("potion") then
		table.insert(data.tags, "potion")
	else
		data.tags = {"potion"}
	end

	data.power_type = Power.Types.RELIC
	data.show_in_ui = false
	data.can_drop = false

	Power.AddPower(Power.Slots.POTION_POWER, id, "potion_powers", data)
end

-- TODO(jambell): lots temp here
local function _DoCooperativeHeal(inst, pow)
	local x,z = inst.Transform:GetWorldXZ()
	local friendlies = FindTargetTagGroupEntitiesInRange(x, z, pow.persistdata:GetVar("radius"), inst.components.combat:GetFriendlyTargetTags(), nil)
	for _,ent in ipairs(friendlies) do
		if ent.components.health and inst ~= ent then
			local friendly_heal = Attack(inst, ent)
			friendly_heal:SetHeal(pow.persistdata:GetVar("heal") * TUNING.POTION_AOE_PERCENT) --TODO(jambell) prototype: tune + implement smarter
			friendly_heal:SetID("potion_heal_friendly")
			ent.components.combat:ApplyHeal(friendly_heal)
		end
	end
end

local function _MakeFlatHealPower(common_heal, epic_heal, legendary_heal, radius)
	return {
		power_category = Power.Categories.SUSTAIN,
		tuning =
		{
			[Power.Rarity.COMMON] = { heal = common_heal, radius = radius },
			-- [Power.Rarity.EPIC] = { heal = epic_heal },
			-- [Power.Rarity.LEGENDARY] = { heal = legendary_heal },
		},

		event_triggers =
		{
			-- use event trigger instead of on_add_fn because it fires after all the setup for the power is done, which is necessary if we're removing it immediately.
			["add_power"] = function(pow, inst, data)
				if pow == data then
					local power_heal = Attack(inst, inst)
					power_heal:SetHeal(pow.persistdata:GetVar("heal"))
					power_heal:SetID("potion_heal")
					inst.components.combat:ApplyHeal(power_heal)
					_DoCooperativeHeal(inst, pow)

					inst.components.powermanager:RemovePower(pow.def)
				end
			end,
		}
	}
end

Power.AddPowerFamily("POTION_POWER")

Power.AddPotionPower("soothing_potion", _MakeFlatHealPower(500, 750, 1000, TUNING.POTION_AOE_RANGE))

Power.AddPotionPower("bubbling_potion", _MakeFlatHealPower(300, 450, 600, TUNING.POTION_AOE_RANGE))

local function _DoTickHeal(inst, pow)
	if not pow.persistdata.heals_left then
		pow.persistdata.heals_left = pow.persistdata:GetVar("num_heals")
	end

	pow.persistdata.tick_timer = pow.persistdata:GetVar("tick_time")
	pow.persistdata.heals_left = pow.persistdata.heals_left - 1

	local power_heal = Attack(inst, inst)
	power_heal:SetHeal(pow.persistdata:GetVar("heal"))
	power_heal:SetID("potion_heal")
	inst.components.combat:ApplyHeal(power_heal)

	local x,z = inst.Transform:GetWorldXZ()
	_DoCooperativeHeal(inst, pow)
end

Power.AddPotionPower("misting_potion",
{
	power_category = Power.Categories.SUSTAIN,

	tuning =
	{
		[Power.Rarity.COMMON] = { heal = 50, tick_time = 1, num_heals = 15, radius = TUNING.POTION_AOE_RANGE },
		-- [Power.Rarity.EPIC] = { heal = 75, tick_time = 1, num_heals = 15, },
		-- [Power.Rarity.LEGENDARY] = { heal = 100, tick_time = 1, num_heals = 15, },
	},

	on_add_fn = function(pow, inst)
		if not pow.persistdata.did_init then
			pow.persistdata.did_init = true
			local x,z = inst.Transform:GetWorldXZ()
			_DoTickHeal(inst, pow)
		end
	end,

	on_update_fn = function(pow, inst, dt)
		pow.persistdata.tick_timer = pow.persistdata.tick_timer - dt
		if pow.persistdata.tick_timer <= 0 then
			local x,z = inst.Transform:GetWorldXZ()
			_DoTickHeal(inst, pow)
		end

		if pow.persistdata.heals_left <= 0 then
			inst.components.powermanager:RemovePower(pow.def)
		end
	end,

	event_triggers =
	{
		["death"] = function(pow, inst, data)
			inst.components.powermanager:RemovePower(pow.def)
		end,
	},
})
