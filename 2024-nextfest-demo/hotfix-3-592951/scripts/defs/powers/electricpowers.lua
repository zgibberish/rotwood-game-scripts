local Power = require "defs.powers.power"
local lume = require "util.lume"
local SGCommon = require "stategraphs.sg_common"
local powerutil = require "util.powerutil"
local EffectEvents = require "effectevents"

local CHAIN_DELAY_INITIAL = 4 -- Number of anim frames before a chain reaction begins
local CHAIN_DELAY = 10 -- Number of anim frames between triggers of damage in one chain reaction, decreases with every bounce
local MIN_DELAY = 4 -- Since the timing decreases every bounce, what's the smallest delay we should allow, so it doesn't just become chaos at the end.


function Power.AddElectricPower(id, data)
	if not data.power_category then
		data.power_category = Power.Categories.DAMAGE
	end

	data.power_type = Power.Types.FABLED_RELIC

	Power.AddPower(Power.Slots.ELECTRIC, id, "electric_powers", data)
end

function Power.AddElectricPlayerPower(id, data)
	if not data.required_tags then
		data.required_tags = { POWER_TAGS.PROVIDES_ELECTRIC }
	else
		if not lume.find(data.required_tags, POWER_TAGS.PROVIDES_ELECTRIC) then
			table.insert(data.required_tags, POWER_TAGS.PROVIDES_ELECTRIC)
		end
	end

	if not data.power_category then
		data.power_category = Power.Categories.DAMAGE
	end

	data.power_type = Power.Types.RELIC

	Power.AddPower(Power.Slots.ELECTRIC, id, "electric_powers", data)
end

local function piecewise_fn(distance, data)
	local p1 = nil
	local p2 = nil
	for i,v in ipairs(data) do
		if p2 == nil then
			if p1 == nil or distance > v[1] then
				p1 = v
			else
				p2 = v
			end
		end
	end
	if p1 and p2 then
		local segment_len = p2[1] - p1[1]
		-- print("p1[1]:", p1[1], "p2[1]:", p2[1])
		-- print("distance:", distance)
		-- print("(distance - p1[1]):", (distance - p1[1]))
		-- print("segment_len:", segment_len)
		-- print("distance / segment_len:", (distance - p1[1]) / segment_len)
		-- print("lume.lerp(p1[2], p2[2], distance / segment_len):", lume.lerp(p1[2], p2[2], (distance - p1[1]) / segment_len))
		return lume.lerp(p1[2], p2[2], (distance - p1[1]) / segment_len)
	end
	-- TODO: handle out of range
end

-- Banded data for scaling the FX based on distance, broken up into two FX to retain visual integrity
local smalldata =
{
	-- distance, scale
	{0, 	0.5},
	{1.8, 	0.9},
	{3.2, 	1.15},
	{5.7, 	1.5},
	{9.2, 	1.9},
	{13.2, 	2.3},
	{15, 	2.35},
}
local largedata =
{
	-- distance, scale
	{15, 	1.35},
	{16, 	1.45},
	{19.5, 	1.57},
	{22, 	1.67},
	{25, 	1.8},
	{30, 	1.95},
	{35, 	2.125},
	{40, 	2.25},
	{45, 	2.415},
	{100, 	4}, --just a guess!
}

local chain_reaction_tags =
{
	"character",
	"prop",
	"mob",
	"boss",
}

-- eventdata : expected to contain attack info that caused chain reaction
local function chain_reaction(pow, inst, eventdata)
	if not eventdata or not eventdata.attack then
		TheLog.ch.ElectricPowers:printf("Warning: no event or attack data for chain_reaction (needs to be fixed)")
		return
	end

	local x,z = inst.Transform:GetWorldXZ()
	local ents = TheSim:FindEntitiesXZ(x, z, pow.persistdata:GetVar("radius"), nil, {"INLIMBO"}, chain_reaction_tags)
	local fx

	if #ents > 0 then
		local current_node_pos = inst:GetPosition()
		local delay = CHAIN_DELAY_INITIAL
		local valid_nodes = 0

		for i, ent in ipairs(ents) do
			if ent:IsValid() and ent ~= inst and ent.components.powermanager and ent.components.powermanager:HasPower(pow.def) then
				local addition = math.max(MIN_DELAY, CHAIN_DELAY - i) --reduce the time between bounces over time, to a minimum of MIN_DELAY
				delay = delay + addition
				valid_nodes = valid_nodes + 1
				ent:DoTaskInAnimFrames(delay, function()
					-- TODO: networking2022, ownership of this entity could change by the time this delay is triggered
					if ent:IsValid() and not ent:IsInLimbo() and ent.components.powermanager:HasPower(pow.def) then -- POSSIBLE OPTIMIZATION: don't check HasPower twice (once above), only on this time around.
						local inst1position = current_node_pos
						local inst2position = ent:GetPosition()

						local delta = inst2position - inst1position
						local delta_xz = Vector2(delta.x, delta.z)
						local angle = delta_xz:angle_to(Vector2.unit_x)
						angle = math.deg(angle)

						local mid_x = (inst1position.x + inst2position.x) / 2
						local mid_y = (inst1position.y + inst2position.y) / 2
						local mid_z = (inst1position.z + inst2position.z) / 2

						local distsq = ent:GetDistanceSqToXZ(inst1position.x, inst1position.z)
						local dist = math.sqrt(distsq)

						local fxname = "electric_chain_arc_sml"
						local dataset = smalldata
						if dist >= 15 then
							fxname = "electric_chain_arc_lrg"
							dataset = largedata
						end

						local scale = piecewise_fn(dist, dataset)
						if fx ~= nil and fx:IsValid() then -- optimization: only allow this instance of this chain reaction to have one FX live at a time. might play funky with sloth's final fx, check again then
							fx:Remove()
						end

						-- TODO: networking2022  -  cannot set an absolute rotation, cannot set an absolute position
						fx = SpawnPrefab(fxname)
						fx.AnimState:SetOrientation(ANIM_ORIENTATION.OnGround)
						fx.Transform:SetScale(scale, 1 + scale*0.1, scale) -- don't scale Y as heavily as the others, because it begins to look very wide and stretchy
						fx.Transform:SetRotation(angle)
						fx.Transform:SetPosition(mid_x, mid_y, mid_z)

						current_node_pos = inst2position

						ent:PushEvent("power_charged_damage", eventdata.attack)
					end
				end)
			end
		end

		if valid_nodes > 0 then
			inst:DoTaskInAnimFrames(HitStopLevel.KILL, function()
				--JAMBELL todo: Known issue, if a thing gets killed by a chain reaction/other power, it doesn't exist in HitStopLevel.KILL ticks to spawn this prefab, so this effect doesn't get added
				local suffix = GetEntitySizeSuffix(inst)
				powerutil.SpawnFxOnEntity("electric_chain_start"..suffix, inst, { ischild = true })
				powerutil.SpawnFxOnEntity("electric_chain_identifier"..suffix, inst, { ischild = true })
			end)
		end
	end
end

local function spawn_charge_applied_fx(inst)
	if not inst.components.powermanager:CanReceivePowers() then
		return
	end

	local suffix = GetEntitySizeSuffix(inst)
	powerutil.SpawnFxOnEntity("hits_electric"..suffix, inst, { ischild = true} )

	-- jambell: an older version of this optimized by killed any existing FX if a new one was applied
	-- jambell: simplifying for network, but here's the old version:

	-- If it's already currently playing a charge applied FX, kill the old one and play a new one
	-- if inst.charge_applied_fx ~= nil and inst.charge_applied_fx:IsValid() then
	-- 	inst.charge_applied_fx:Remove()
	-- 	inst.charge_applied_fx = nil
	-- end

	-- local x, z = inst.Transform:GetWorldXZ()
	-- local suffix = GetEntitySizeSuffix(inst)

	-- inst.charge_applied_fx = SpawnPrefab("hits_electric"..suffix, inst)
	-- inst.charge_applied_fx.Transform:SetPosition(x, 0, z)
	-- inst.charge_applied_fx:ListenForEvent("onremove", function()
	-- 	if inst ~= nil and inst:IsValid() then
	-- 		inst.charge_applied_fx = nil
	-- 	end
	-- end)
end

Power.AddPowerFamily("ELECTRIC")

Power.AddElectricPower("charged",
{
	prefabs = {
		"hits_electric_sml",
		"hits_electric_med",
		"hits_electric_lrg",
		"electric_charged_tier1_sml",
		"electric_charged_tier1_med",
		"electric_charged_tier1_lrg",
		"fx_charged_chain_reaction",
		"electric_charge_start_sml",
		"electric_charge_start_med",
		"electric_charge_start_lrg",
		"electric_charge_start_gnt",
	},
	tuning = {
		[Power.Rarity.COMMON] = { radius = 100, damage_mod = 150 },
	},
	show_in_ui = false,
	stackable = true,
	can_drop = false,
	selectable = false,
	event_triggers =
	{
		["power_charged_damage"] = function(pow, inst, attack)
			if attack ~= nil then
				local power_attack = Attack(attack:GetAttacker(), inst)
				power_attack:CloneChainDataFromAttack(attack)
				local damage_mod = pow.persistdata:GetVar("damage_mod")
				local stacks_consumed = 1
				local attacker = attack:GetAttacker()

				if attacker.components.powermanager and attacker.components.powermanager:HasPower(Power.FindPowerByName("charge_consume_all_stacks")) then
					stacks_consumed = pow.persistdata.stacks
				end

				local damage_boost_power_def = Power.FindPowerByName("charge_consume_extra_damage")
				if attacker.components.powermanager and attacker.components.powermanager:HasPower(damage_boost_power_def) then
					local damage_boost_power = attacker.components.powermanager:GetPower(damage_boost_power_def)
					-- TODO: networking2022, this needs to be synced or reimplemented
					damage_mod = damage_mod + damage_boost_power.persistdata:GetVar("damage_bonus_percent")
				end

				damage_mod = (damage_mod * stacks_consumed) * 0.01 --deal damage per stack consumed

				power_attack:SetDamageMod(damage_mod)
				power_attack:SetSource(pow.def.name)
				power_attack:SetHitstunAnimFrames(10)
				power_attack:InitDamageAmount()
				-- TODO: networking2022, this likely doesn't work when the attacker is remote
				attack:GetAttacker().components.combat:DoPowerAttack(power_attack)

				local suffix = GetEntitySizeSuffix(inst)
				powerutil.SpawnFxOnEntity("hits_electric"..suffix, inst, { ischild = true })
				powerutil.SpawnFxOnEntity("electric_chain_identifier"..suffix, inst, { ischild = true })

				inst.components.powermanager:DeltaPowerStacks(pow.def, -stacks_consumed)

				inst:PushEvent("used_power", pow.def)
			end
		end,

		["power_stacks_changed"] = function(pow, inst, data)
			if inst.AnimState then
				inst.AnimState:SetBloom(math.min(data.new, 5) * 0.05) -- temp, testing: TODO shouldn't just be a white glow -- check with dan and sloth
			end
		end,

		["dying"] = function(pow, inst, data)
			chain_reaction(pow, inst, data)
		end
	},

	on_add_fn = function(pow, inst)
		--jambell todo: change this fx based on charged amount
		local suffix = GetEntitySizeSuffix(inst)
		inst[pow.def.name.."_fx"] = powerutil.SpawnFxOnEntity("electric_charged_tier1"..suffix, inst, { ischild = true })

		powerutil.SpawnFxOnEntity("electric_charge_start"..suffix, inst, { ischild = true })
		TheLog.ch.ElectricPowers:printf("%s EntityID %d charged: electric_charge_start%s",
			inst,
			inst:IsNetworked() and inst.Network:GetEntityID() or -1,
			suffix)
	end,

	on_remove_fn = function(pow, inst)
		if inst[pow.def.name.."_fx"] then
			inst[pow.def.name.."_fx"]:Remove()
			inst[pow.def.name.."_fx"] = nil
		end
	end,
})

Power.AddElectricPower("charge_apply_on_light_attack",
{
	tags = {POWER_TAGS.PROVIDES_ELECTRIC},
	prefabs = {
		"hits_electric_sml",
		"hits_electric_med",
		"hits_electric_lrg",
		"electric_charged_tier1_sml",
		"electric_charged_tier1_med",
		"electric_charged_tier1_lrg",
		GroupPrefab("fx_hammer_electric"),
		GroupPrefab("fx_polearm_electric"),
		GroupPrefab("fx_cannon_electric"),
		GroupPrefab("fx_shotput_electric"),
	},
	tuning = {
		[Power.Rarity.LEGENDARY] = { stacks = 2 },
	},
	tooltips =
	{
		"CHARGE",
		"CHAIN_REACTION",
		"LIGHT_ATTACK",
	},
	attack_fx_mods = { light_attack = "electric" },
	event_triggers =
	{
		["light_attack"] = function(pow, inst, data)
			if #data.targets_hit > 0 then
				local charge_def = Power.Items.ELECTRIC.charged
				assert(charge_def)
				for i, target in ipairs(data.targets_hit) do
					if target:IsValid() and target.components.powermanager then
						target.components.powermanager:AddPower(target.components.powermanager:CreatePower(charge_def), pow.persistdata:GetVar("stacks"))
						spawn_charge_applied_fx(target)
					end
				end
				inst:PushEvent("used_power", pow.def)
			end
		end,
	},
})

Power.AddElectricPower("charge_apply_on_heavy_attack",
{
	tags = {POWER_TAGS.PROVIDES_ELECTRIC},
	prefabs = {
		"hits_electric_sml",
		"hits_electric_med",
		"hits_electric_lrg",
		"electric_charged_tier1_sml",
		"electric_charged_tier1_med",
		"electric_charged_tier1_lrg",
		GroupPrefab("fx_hammer_electric"),
		GroupPrefab("fx_polearm_electric"),
	},
	tuning = {
		[Power.Rarity.LEGENDARY] = { stacks = 1, radius = 10 },
	},
	tooltips =
	{
		"CHARGE",
		"CHAIN_REACTION",
		"HEAVY_ATTACK",
	},
	attack_fx_mods = { heavy_attack = "electric" },
	event_triggers =
	{
		["heavy_attack"] = function(pow, inst, data)
			if #data.targets_hit > 0 then
				for _, target in ipairs(data.targets_hit) do
					if target:IsValid() then
						local x,z = target.Transform:GetWorldXZ()
						local ents = FindEnemiesInRange(x, z, pow.persistdata:GetVar("radius"))
						if #ents > 0 then
							local charge_def = Power.Items.ELECTRIC.charged
							assert(charge_def)
							for i, ent in ipairs(ents) do
								if ent.components.powermanager and ent:IsValid() then -- checking CanReceivePowers here too so we don't erroneously spawn FX if AddPower() dumps the power add
									if ent:TryToTakeControl() then
										ent.components.powermanager:AddPower(ent.components.powermanager:CreatePower(charge_def), pow.persistdata:GetVar("stacks"))
										spawn_charge_applied_fx(ent)
									else
										-- networking2022  if can't take control, send an event to add a Charged power + play the FX
									end
								end
							end
							inst:PushEvent("used_power", pow.def)
						end
						break
					end
				end
			end
		end,
	}
})

Power.AddElectricPower("charge_orb_on_dodge",
{
	tags = {POWER_TAGS.PROVIDES_ELECTRIC},
	prefabs = {
		"hits_electric_sml",
		"hits_electric_med",
		"hits_electric_lrg",
		"hits_electric_ground",
		"orb_charge",
		"electric_charged_orb_area",
	},
	tuning = {
		[Power.Rarity.LEGENDARY] = { cd = 2.75, stacks = 2, pulses = 2 }, --cooldown is set roughly so that you can only have one active at a time, with a BIT of overlap
	},
	tooltips =
	{
		"CHARGE",
		"CHAIN_REACTION",
	},
	event_triggers =
	{
		["dodge"] = function(pow, inst, data)
			if not inst.components.timer:HasTimer(pow.def.name) then
				EffectEvents.MakeEventSpawnLocalEntity(inst, "orb_charge", "electric_orb_pre")
				inst.components.timer:StartTimer(pow.def.name, pow.persistdata:GetVar("cd"))
				inst:PushEvent("used_power", pow.def)
			end
		end,
	},
})

Power.AddElectricPlayerPower("charge_consume_on_focus",
{
	power_category = Power.Categories.DAMAGE,
	can_drop = false, -- JAMBELL: this power is broken right now because chain_reaction()'s pow argument is expecting the chainreacting creature's Charged pow. more work needed, disabling for VS
	tuning = {
		[Power.Rarity.EPIC] = { radius = 100 },
	},
	tooltips =
	{
		"CHARGE",
		"CHAIN_REACTION",
	},
	event_triggers =
	{
		["do_damage"] = function(pow, inst, attack)
			if attack:GetFocus() then
				chain_reaction(pow, inst, attack)
			end
		end
	}
})

Power.AddElectricPlayerPower("charge_consume_on_crit",
{
	power_category = Power.Categories.DAMAGE,
	can_drop = false, -- JAMBELL: this power is broken right now because chain_reaction()'s pow argument is expecting the chainreacting creature's Charged pow. more work needed, disabling for VS
	tuning = {
		[Power.Rarity.EPIC] = { radius = 100 },
	},
	event_triggers =
	{
		["do_damage"] = function(pow, inst, attack)
			if attack:GetCrit() then
				chain_reaction(pow, inst, attack)
			end
		end
	}
})

Power.AddElectricPlayerPower("charge_consume_all_stacks", --Player Power
{
	power_category = Power.Categories.DAMAGE,
	tuning = {
		[Power.Rarity.LEGENDARY] = { },
	},
	tooltips =
	{
		"CHARGE",
		"CHAIN_REACTION",
	},
	event_triggers =
	{
	}
})

Power.AddElectricPlayerPower("charge_consume_extra_damage", --Player Power
{
	power_category = Power.Categories.DAMAGE,
	tooltips =
	{
		"CHARGE",
		"CHAIN_REACTION",
	},
	tuning = {
		[Power.Rarity.EPIC] = { damage_bonus_percent = 50 },
	},
})
