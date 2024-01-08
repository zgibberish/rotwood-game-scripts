local Power = require("defs.powers.power")
local SGCommon = require "stategraphs.sg_common"
local lume = require "util.lume"

function Power.AddSeedPower(id, data)
	if not data.power_category then
		data.power_category = Power.Categories.SUPPORT
	end
	Power.AddPower(Power.Slots.SEED, id, "seed_powers", data)
end

Power.AddPowerFamily("SEED")

-- Your Light Attack does 50% damage, but applies Seed.
Power.AddSeedPower("seeded_on_light_attack",
{
	can_drop = false,
	tags = { POWER_TAGS.PROVIDES_SEED },

	prefabs =
	{
	},

	tuning =
	{
		[Power.Rarity.LEGENDARY] = { stacks = 25 },
	},

	tooltips =
	{
		"SEEDED",
		"LIGHT_ATTACK",
	},

	attack_fx_mods = { light_attack = "electric" },

	-- damage_mod_fn = function(pow, attack, output_data)
	-- 	if attack:IsLightAttack() then
	-- 		local dmg = attack:GetDamage()
	-- 		output_data.damage_delta = (dmg/-2)
	-- 	end
	-- end,

	event_triggers =
	{
		["light_attack"] = function(pow, inst, data)
			if #data.targets_hit > 0 then
				local seeded_def = Power.Items.SEED.seeded
				assert(seeded_def)
				for i, target in ipairs(data.targets_hit) do
					if target:IsValid() and target.components.powermanager then
						target.components.powermanager:AddPower(target.components.powermanager:CreatePower(seeded_def), pow.persistdata:GetVar("stacks"))
						-- spawn_charge_applied_fx(target)
					end
				end
				inst:PushEvent("used_power", pow.def)
			end
		end,
	},
})

-- Your Heavy Attack applies Seed in a large radius.
Power.AddSeedPower("seeded_on_heavy_attack",
{
	can_drop = false,
	tags = { POWER_TAGS.PROVIDES_SEED },

	prefabs =
	{
	},

	tuning =
	{
		[Power.Rarity.LEGENDARY] = { stacks = 25, radius = 10 },
	},

	tooltips =
	{
		"SEEDED",
		"HEAVY_ATTACK",
	},

	attack_fx_mods = { heavy_attack = "electric" },

	-- damage_mod_fn = function(pow, attack, output_data)
	-- 	if attack:IsHeavyAttack() then
	-- 		local dmg = attack:GetDamage()
	-- 		output_data.damage_delta = -dmg
	-- 		attack:DisableDamageNumber()
	-- 	end
	-- end,

	event_triggers =
	{
		["heavy_attack"] = function(pow, inst, targets_hit)
			local x,z = inst.Transform:GetWorldXZ()
			local radius = pow.persistdata:GetVar("radius")
			local ents = FindEnemiesInRange(x, z, radius)

			if #ents > 0 then
				local seeded_def = Power.Items.SEED.seeded
				assert(seeded_def)
				for i, target in ipairs(ents) do
					if target:IsValid() and target.components.powermanager then
						target.components.powermanager:AddPower(target.components.powermanager:CreatePower(seeded_def), pow.persistdata:GetVar("stacks"))
						-- spawn_charge_applied_fx(target)
					end
				end
				inst:PushEvent("used_power", pow.def)
			end
		end,
	},
})

local function DropAoE(inst)
	print(inst.Transform:GetRotation())

	local aoe = SGCommon.Fns.SpawnAtDist(inst, "mossquito_aoe", 0)
	local aoepos = aoe:GetPosition()
	aoe.Transform:SetPosition(aoepos.x, aoepos.y, aoepos.z)
	aoe:Setup(inst, 7)

	local burst = SGCommon.Fns.SpawnAtDist(inst, "mosquito_trail_burst", 0)
	burst.Transform:SetPosition(aoepos.x, aoepos.y, aoepos.z)
	burst:DoTaskInAnimFrames(15, function()
		burst.components.particlesystem:StopThenRemoveEntity()
	end)
	burst:ListenForEvent("onremove", function() burst:Remove() end, aoe)
end

-- Your Roll applies Seed in a large radius. 
Power.AddSeedPower("acid_on_dodge",
{
	can_drop = false,
	tags = { POWER_TAGS.PROVIDES_SEED },
	-- required_tags = { WEAPON HAS A ROLL } TODO #seed add tag when weapon has a roll or not

	prefabs =
	{
		GroupPrefab("fx_battoad"),
		"jointaoeparent",
	},

	tuning =
	{
		[Power.Rarity.LEGENDARY] = { spurts = 6, framesbetweenspurts = 2 },
	},

	tooltips =
	{
		-- TODO #seed add tooltip for dodge, add to other dodge powers
	},

	attack_fx_mods = { heavy_attack = "electric" },

	event_triggers =
	{
		["dodge"] = function(pow, inst, data)
			local spurts = pow.persistdata:GetVar("spurts")
			local delay = pow.persistdata:GetVar("framesbetweenspurts")

			DropAoE(inst)
			spurts = spurts - 1

			for i=1,spurts do
				inst:DoTaskInAnimFrames(delay * i, function(inst)
					if inst ~= nil and inst:IsValid() then
						DropAoE(inst)
					end
				end)
			end

			inst:PushEvent("used_power", pow.def)
		end,
	},
})
