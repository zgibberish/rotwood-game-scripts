local Power = require("defs.powers.power")
local lume = require "util.lume"
local SGCommon = require "stategraphs.sg_common"


function Power.AddTonicPower(id, data)
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

	if data.tags ~= nil and not table.contains("tonic") then
		table.insert(data.tags, "tonic")
	else
		data.tags = {"tonic"}
	end

	data.power_type = Power.Types.RELIC
	data.show_in_ui = false
	data.can_drop = false

	Power.AddPower(Power.Slots.TONIC, id, "tonic_powers", data)
end

Power.AddPowerFamily("TONIC")

Power.AddTonicPower("tonic_rage",
{
	power_category = Power.Categories.SUPPORT,
	tuning =
	{
		[Power.Rarity.COMMON] = { damage = 1000, time = 5 },
	},

	clear_on_new_room = true,

	on_add_fn = function(pow, inst)
		inst.components.combat:SetDamageDealtMult(pow.def.name, pow.persistdata:GetVar("damage") * 0.01)
		pow:StartPowerTimer(inst)
	end,

	on_remove_fn = function(pow, inst)
		inst.components.timer:StopTimer(pow.def.name)
		inst.components.combat:SetDamageDealtMult(pow.def.name, nil)
	end,

	event_triggers = {
		["timerdone"] = function(pow, inst, data)
			if data.name == pow.def.name then
				inst.components.combat:SetDamageDealtMult(pow.def.name, nil)
			end
		end,
	}
})

Power.AddTonicPower("tonic_speed", 
{
	power_category = Power.Categories.SUPPORT,

	tuning =
	{
		[Power.Rarity.COMMON] = { speed = 33 },
	},

	clear_on_new_room = true,
	on_add_fn = function(pow, inst)
		inst.components.locomotor:AddSpeedMult(pow.def.name, pow.persistdata:GetVar("speed") * 0.01)
	end,

	on_remove_fn = function(pow, inst)
		inst.components.locomotor:RemoveSpeedMult(pow.def.name)
	end,
})

Power.AddTonicPower("tonic_explode",
{
	power_category = Power.Categories.DAMAGE,
	clear_on_new_room = true,

	tuning =
	{
		[Power.Rarity.COMMON] = { tick_time = 1, duration = 10, damage = 100, radius = 10 },
	},

	on_add_fn = function(pow, inst)
		pow.mem.tick_time_elapsed  = 0
		pow.mem.total_time_elapsed = 0

		pow.mem.tick_time = pow.persistdata:GetVar("tick_time")
		pow.mem.duration  = pow.persistdata:GetVar("duration")
		pow.mem.damage    = pow.persistdata:GetVar("damage")
		pow.mem.radius   = pow.persistdata:GetVar("radius")
	end,

	on_update_fn = function(pow, inst, dt)
		pow.mem.tick_time_elapsed = pow.mem.tick_time_elapsed + dt
		pow.mem.total_time_elapsed = pow.mem.total_time_elapsed + dt

		if pow.mem.tick_time_elapsed > pow.mem.tick_time then
			pow.mem.tick_time_elapsed = 0

			local x,z = inst.Transform:GetWorldXZ()
			local ents = FindEnemiesInRange(x, z, pow.mem.radius)

			for i, ent in ipairs(ents) do
				inst:DoTaskInAnimFrames(math.random(1, 5), function()
					if ent:IsValid() then
						local power_attack = Attack(inst, ent)

						power_attack:SetDamage(pow.mem.damage)
						power_attack:SetHitstunAnimFrames(10)
						power_attack:SetPushback(2)
						power_attack:SetSource(pow.def.name)
						-- TODO: add hitstop to the attack
						inst.components.combat:DoPowerAttack(power_attack)
						-- do I need to copy the chain from the last attack?
						SpawnHitFx("hits_bomb", inst, ent, 0, 0, nil, 5)
					end
				end)
			end

			local bomb_fx = SGCommon.Fns.SpawnAtDist(inst, "bomb_explosion", 0)
			bomb_fx.AnimState:SetScale(0.5, 0.5)
		end

		if pow.mem.total_time_elapsed >= pow.mem.duration then
			inst.components.powermanager:RemovePower(pow.def, true)
		end
	end
})

Power.AddTonicPower("tonic_freeze",
{
	power_category = Power.Categories.SUPPORT,
	clear_on_new_room = true,

	tuning =
	{
		[Power.Rarity.COMMON] = { time = 10 },
	},

	on_add_fn = function(pow, inst)
		--pow:StartPowerTimer(inst)
		local enemies = TheWorld.components.roomclear:GetEnemies()
		local freeze_def = Power.Items.STATUSEFFECT.freeze
		for enemy, _ in pairs(enemies) do
			if enemy.components.powermanager and enemy:IsValid() then
				enemy.components.powermanager:AddPower(enemy.components.powermanager:CreatePower(freeze_def))
			end
		end

		inst:DoTaskInTime(0, function() inst.components.powermanager:RemovePower(pow.def, true) end)
	end,

	-- TODO: keeping this here in case we wanna incorporate sounds/UI things for the timer
	-- event_triggers = {
	-- 	["timerdone"] = function(pow, inst, data)
	-- 		if data.name == pow.def.name then
	-- 			inst.components.powermanager:RemovePower(pow.def, true)
	-- 		end
	-- 	end,
	-- }

})

local function SpawnProjectiles(inst, pow, count, damage, offset)
	local increment = 360 / count
	local angle = 0

	if offset then
		angle = angle + offset
	end

	for i = 1, count do
		local bullet = SGCommon.Fns.SpawnAtAngleDist(inst, "generic_projectile", 0, angle)
		bullet:Setup(inst, nil, pow.def.name, damage)
		angle = angle + increment
	end
end

Power.AddTonicPower("tonic_projectile",
{
	power_category = Power.Categories.DAMAGE,
	clear_on_new_room = true,

	tuning =
	{
		[Power.Rarity.COMMON] = { projectiles = 8, damage = 500 },
	},

	on_add_fn = function(pow, inst)
		local count = pow.persistdata:GetVar("projectiles")
		local damage = pow.persistdata:GetVar("damage")

		SpawnProjectiles(inst, pow, count, damage)

		inst:DoTaskInTime(0, function() inst.components.powermanager:RemovePower(pow.def, true) end)
	end,
})

-- TODO: make this repeatable power a template
Power.AddTonicPower("tonic_projectile_repeat",
{
	power_category = Power.Categories.DAMAGE,
	clear_on_new_room = true,

	tuning =
	{
		[Power.Rarity.COMMON] = { tick_time = 1, duration = 10, damage = 50, projectiles = 4 },
	},

	on_add_fn = function(pow, inst)
		pow.mem.tick_time_elapsed  = 0
		pow.mem.total_time_elapsed = 0

		pow.mem.tick_time = pow.persistdata:GetVar("tick_time")
		pow.mem.duration  = pow.persistdata:GetVar("duration")
		pow.mem.damage    = pow.persistdata:GetVar("damage")

		pow.mem.offset_spawn = true
	end,

	on_update_fn = function(pow, inst, dt)
		pow.mem.tick_time_elapsed = pow.mem.tick_time_elapsed + dt
		pow.mem.total_time_elapsed = pow.mem.total_time_elapsed + dt

		if pow.mem.tick_time_elapsed > pow.mem.tick_time then
			pow.mem.tick_time_elapsed = 0

			local count = pow.persistdata:GetVar("projectiles")
			local damage = pow.persistdata:GetVar("damage")

			local offset = pow.mem.offset_spawn and 45 or 0
			pow.mem.offset_spawn = not pow.mem.offset_spawn

			SpawnProjectiles(inst, pow, count, damage, offset)
		end

		if pow.mem.total_time_elapsed >= pow.mem.duration then
			inst.components.powermanager:RemovePower(pow.def, true)
		end
	end
})
