local Power = require("defs.powers.power")
local lume = require "util.lume"
local monsterutil = require "util.monsterutil"
local ParticleSystemHelper = require "util.particlesystemhelper"
local powerutil = require "util.powerutil"

local DOUBLE_TAP_TICK_THRESHOLD = 11
local MINIMUM_DISTANCE_SQ_BETWEEN_PORTALS = 30

function Power.AddSummonPower(id, data)
	if not data.power_category then
		data.power_category = Power.Categories.SUPPORT
	end

	data.power_type = Power.Types.FABLED_RELIC

	Power.AddPower(Power.Slots.SUMMON, id, "summon_powers", data)
end

function Power.AddSummonPlayerPower(id, data)
	if not data.required_tags then
		data.required_tags = { POWER_TAGS.PROVIDES_SUMMON }
	else
		if not lume.find(data.required_tags, POWER_TAGS.PROVIDES_SUMMON) then
			table.insert(data.required_tags, POWER_TAGS.PROVIDES_SUMMON)
		end
	end

	if not data.power_category then
		data.power_category = Power.Categories.SUPPORT
	end

	data.power_type = Power.Types.RELIC

	Power.AddPower(Power.Slots.SUMMON, id, "summon_powers", data)
end

Power.AddPowerFamily("SUMMON")

Power.AddSummonPower("summon_slots",
{
	tuning =
	{
		[Power.Rarity.COMMON] = { summons = 2 },
		[Power.Rarity.EPIC] = { summons = 3 },
		[Power.Rarity.LEGENDARY] = { summons = 4 },
	},

	can_drop = false,
	selectable = false,

	on_add_fn = function(pow, inst)
		pow.persistdata.summons = {}
	end,

	remote_event_triggers = {
		room_complete = {
			fn = function(pow, inst, source, data)
				for _,v in pairs(pow.persistdata.summons) do
					if v:IsValid() then
						v:PushEvent("despawn")
					end
				end
				pow.persistdata.summons = {}
			end,
			source = function() return TheWorld end,
		},
	},

	event_triggers =
	{
		["death"] = function(pow, inst, data)
			for _,v in pairs(pow.persistdata.summons) do
				if v:IsValid() then
					v.components.health:Kill()
				end
			end
		end,

		["end_current_run"] = function(pow, inst, data)
			for _,v in pairs(pow.persistdata.summons) do
				if v:IsValid() then
					v:Remove()
				end
			end
			pow.persistdata.summons = {}
		end,

		["enter_room"] = function(pow, inst, data)
			pow.persistdata.summons = {}
		end,

		["summon_minion"] = function(pow, inst, data)
			local x, z = data.victim.Transform:GetWorldXZ()
			inst:DoTaskInTime(.25, function() -- If this time = 0, some issues can occur on room clear. Be cautious setting it to 0/removing this!
				if #pow.persistdata.summons < pow.persistdata:GetVar("summons") and not TheWorld.components.roomclear:IsRoomComplete() then
					local summon_types = data.summon_types

					local minion = SpawnPrefab(summon_types[math.random(#summon_types)], inst)
					minion.Transform:SetPosition(x, 0, z)
					minion.summoner = inst
					minion:FaceAwayFrom(inst)

					table.insert(pow.persistdata.summons, minion)
				end
			end)
		end,

		["minion_unsummoned"] = function(pow, inst, minion)
			pow.persistdata.summons[minion] = nil
			for i,summon in pairs(pow.persistdata.summons) do
				if summon == minion then
					table.remove(pow.persistdata.summons, i)
					break
				end
			end
		end,
	},
})

Power.AddSummonPower("summon_on_kill",
{
	tags = {POWER_TAGS.PROVIDES_SUMMON},
	prefabs = { "minion_melee", "minion_ranged" },
	tuning = { [Power.Rarity.LEGENDARY] = {} },

	on_add_fn = function(pow, inst)
		if not pow.persistdata.did_init then
			local summonslots_def = Power.FindPowerByName("summon_slots")
			inst.components.powermanager:AddPower(inst.components.powermanager:CreatePower(summonslots_def))
			pow.persistdata.did_init = true
		end
	end,

	on_remove_fn = function(pow, inst)
		pow.persistdata.did_init = false
	end,

	event_triggers =
	{
		["kill"] = function(pow, inst, data)
			local victim = data.attack:GetTarget()
			if victim:HasTag("mob") then
				inst:PushEvent("summon_minion", {
					victim = victim,
					summon_types = { "minion_melee", "minion_ranged" }
				})
				-- inst:PushEvent("used_power", pow.def) -- TODO jambell, only send this on successful summon? might need to do summon logic in here
			end
		end,
	},
})

local function spawn_charmed_creature(summoner, prefab, x, z)
	if prefab ~= nil then
		local creature = SpawnPrefab(prefab, summoner)
		if creature then
			creature.Transform:SetPosition(x, 0, z)
			monsterutil.CharmMonster(creature, summoner)
			return creature
		else
			TheLog.ch.SummonPowers:printf("spawn_charmed_creature failed (network support not implemented)")
		end
	end
end

Power.AddSummonPower("charm_on_kill",
{
	tags = { },
	prefabs = { },
	tuning = { [Power.Rarity.LEGENDARY] = {} },

	on_add_fn = function(pow, inst)
		if not pow.persistdata.did_init then
			pow.mem.charmedcreature = nil
			pow.persistdata.did_init = true
		end
		powerutil.AttachParticleSystemToSymbol(pow, inst, "heart_weapon_trail", "swap_fx")
	end,

	event_triggers =
	{
		["kill"] = function(pow, inst, data)
			-- TODO: networking2022, this needs to be rewritten to support networking
			local victim = data.attack:GetTarget()

			if pow.mem.charmedcreature == nil and victim:HasTag("mob") and not victim:HasTag("nocharm") then
				pow.mem.charmedcreature = true

				powerutil.StopAttachedParticleSystem(inst, pow)

				TheNetEvent:RequestSpawnCharmedCreature(inst.GUID, victim.GUID)

				inst:PushEvent("used_power", pow.def)
			end
		end,
	},
})

function DoSpawnCharmedCreature(spawner, victim)
	if victim:HasTag("mob") then
		local x, z = victim.Transform:GetWorldXZ()
		local prefab = victim.prefab

		-- FX spawning
		local heart_burst = ParticleSystemHelper.MakeOneShot(nil, "burst_heart_spawn", nil, 2)
		heart_burst.Transform:SetPosition(x, 0, z)

		local px, pz = spawner.Transform:GetWorldXZ()

		local heart_burst_summoner = ParticleSystemHelper.MakeOneShot(nil, "charming_on_player", nil, 2)
		heart_burst_summoner.Transform:SetPosition(px, 0, pz)

		if TheNet:IsHost() then	-- Charmed creature can only be spawned on the host
			spawner:DoTaskInTime(.25, function()
				-- Request the host to spawn the charmed creature
				spawn_charmed_creature(spawner, prefab, x, z)
				-- No longer store the spawned charmed creature, as the stored value was never used.
			end)
		end
	end
end

Power.AddSummonPower("summon_wormhole_on_dodge",
	-- IDEA: moving through the portal makes that entity's next hit deal extra damage.
{
	tags = { },
	prefabs = { "summoned_wormhole", "fx_portal", "electric_chain_arc_sml", "electric_chain_arc_lrg", "fx_portal_pulse_in3", "fx_portal_pulse_out3", "fx_portal_pulse_in2", "fx_portal_pulse_out2", "fx_portal_pulse_in", "fx_portal_pulse_out" },
	tuning = { [Power.Rarity.LEGENDARY] = {} },

	on_add_fn = function(pow, inst)
		pow.mem.wormholes = {}
		pow.mem.wormhole_id = 1
	end,

	on_remove_fn = function(pow, inst)
		pow.mem.wormholes = nil
	end,

	remote_event_triggers = {
		exit_room = {
			fn = function(pow, inst, source, data)
				for i,v in ipairs(pow.mem.wormholes) do
					if v:IsValid() then
						v.components.wormhole:RemoveWormhole()
						pow.mem.wormholes[i] = nil
					end
				end
			end,
			source = function() return TheWorld end,
		},
	},

	event_triggers =
	{
		["death"] = function(pow, inst, data)
			for i,v in ipairs(pow.mem.wormholes) do --boilerplate
				if v:IsValid() then
					v.components.wormhole:RemoveWormhole()
					pow.mem.wormholes[i] = nil
				end
			end
		end,

		["end_current_run"] = function(pow, inst, data)
			for i,v in ipairs(pow.mem.wormholes) do --boilerplate
				if v:IsValid() then
					v.components.wormhole:RemoveWormhole()
					pow.mem.wormholes[i] = nil
				end
			end
		end,

		["enter_room"] = function(pow, inst, data)
			pow.mem.wormholes = {}
			pow.mem.wormhole_id = 1
		end,

		["dodge"] = function(pow, inst, data) -- "dodge" is sent at the start of every dodge, so clear up our ability to summon a wormhole this dodge
			inst.sg.mem.has_dodgewormholed = false
		end,

		["controlevent"] = function(pow, inst, data)

			-- wormhole_id is either 1 or 2, depending on which wormhole is about to be summoned.
			-- only allow one wormhole to be placed per dodge. once a wormhole is placed, set has_dodgewormholed = true

			local last_press = pow.mem.last_dodge or TheSim:GetTick()
			pow.mem.last_dodge = TheSim:GetTick()
			if data.control == "dodge" and inst.sg:HasStateTag("dodge") and not inst.sg.mem.has_dodgewormholed then
				if TheSim:GetTick() - last_press <= DOUBLE_TAP_TICK_THRESHOLD then

					local remove_other_wormhole = true
					-- If there's already a wormhole near where we're trying to summon a new one, just replace that wormhole with this one.
					for existing_id, existing_wormhole in pairs(pow.mem.wormholes) do
						local dist_sq = inst:GetDistanceSqTo(existing_wormhole)
						if dist_sq <= MINIMUM_DISTANCE_SQ_BETWEEN_PORTALS then
							-- Set us up to replace that portal
							pow.mem.wormhole_id = existing_id

							-- Remove the old portal
							existing_wormhole.components.wormhole:RemoveWormhole()
							pow.mem.wormholes[existing_id] = nil
							remove_other_wormhole = false
						end
					end

					local wormhole_id = pow.mem.wormhole_id

					-- Set up a new wormhole
					local wormhole = SpawnPrefab("summoned_wormhole", inst)
					wormhole.components.wormhole:Setup(inst, wormhole_id)

					-- In case we've already summoned two wormholes, we're cycling back around to the first slot.
					-- If so, remove the wormhole so we can create a new one for that slot.
					if pow.mem.wormholes[wormhole_id] ~= nil and remove_other_wormhole then
						pow.mem.wormholes[wormhole_id].components.wormhole:RemoveWormhole()
						pow.mem.wormholes[wormhole_id] = nil
					end

					-- Place our new wormhole in the correct slot.
					pow.mem.wormholes[wormhole_id] = wormhole

					-- Cycle to the next wormhole_id, or back to 1 if this was our second one.
					pow.mem.wormhole_id = wormhole_id == 1 and 2 or 1

					-- Tell the other wormhole about the new wormhole & pair them
					if pow.mem.wormholes[pow.mem.wormhole_id] then
						pow.mem.wormholes[pow.mem.wormhole_id].components.wormhole:PairWormhole(wormhole)
					end

					if math.fmod(pow.mem.wormhole_id, 2) ~= 0 then
						wormhole.AnimState:SetAddColor( 74/255, 113/255, 239/255, 1)
					else
						wormhole.AnimState:SetAddColor( 250/255, 230/255, 46/255, 1)
					end

					inst.sg.mem.has_dodgewormholed = true
					inst:PushEvent("used_power", pow.def)
				end
			end
		end,
	},
})

-- TODO: re-enable after making work with new, non-stacks system
-- Power.AddSummonPlayerPower("extra_summon_slots",
-- {
-- 	power_category = Power.Categories.SUPPORT,
-- 	tuning = {
-- 		[Power.Rarity.COMMON] = { amount = 1 },
-- 		[Power.Rarity.EPIC] =   { amount = 2 },
-- 		[Power.Rarity.LEGENDARY] = { amount = 3 },
-- 	},

-- 	on_add_fn = function(pow, inst)
-- 		local summonslots_def = Power.FindPowerByName("summon_slots")
-- 		if inst.components.powermanager:HasPower(summonslots_def) then
-- 			local current_slots = inst.components.powermanager:GetPowerStacks(summonslots_def)
-- 			inst.components.powermanager:SetPowerStacks(summonslots_def, current_slots + pow.persistdata:GetVar("amount"))
-- 			print("new slots: ", inst.components.powermanager:GetPowerStacks(summonslots_def))
-- 		end
-- 	end,

-- 	on_remove_fn = function(pow, inst)
-- 		local summonslots_def = Power.FindPowerByName("summon_slots")
-- 		if inst.components.powermanager:HasPower(summonslots_def) then
-- 			local current_slots = inst.components.powermanager:GetPowerStacks(summonslots_def)
-- 			inst.components.powermanager:SetPowerStacks(summonslots_def, current_slots - pow.persistdata:GetVar("amount"))
-- 		end
-- 	end,
-- })
