local Power = require("defs.powers.power")
local combatutil = require "util.combatutil"
local ParticleSystemHelper = require "util.particlesystemhelper"
local powerutil = require "util.powerutil"

function Power.AddSkillPower(id, data)
	if data.tooltips == nil then
		data.tooltips = {}
	end
	table.insert(data.tooltips, 1, "SKILL")

	data.power_type = Power.Types.SKILL
	data.can_drop = true
	data.selectable = false

	local skillstate_name = ("skill_%s"):format(id)

	local on_add_fn = data.on_add_fn
	data.on_add_fn = nil

	data.on_add_fn = function(pow, inst)
		inst.sg.mem.skillstate = skillstate_name
		if on_add_fn then
			on_add_fn(pow, inst)
		end
	end

	local on_remove_fn = data.on_remove_fn
	data.on_remove_fn = nil

	data.on_remove_fn = function(pow, inst)
		inst.sg.mem.skillstate = nil
		if on_remove_fn then
			on_remove_fn(pow, inst)
		end
	end

	if not data.event_triggers then
		data.event_triggers = {}
	end

	local enter_room_fn = data.event_triggers.enter_room
	data.event_triggers.enter_room = nil

	data.event_triggers.enter_room = function(pow, inst, data)
		inst.sg.mem.skillstate = skillstate_name
		if enter_room_fn then
			enter_room_fn(pow, inst, data)
		end
	end

	local loadout_changed_fn = data.event_triggers.loadout_changed
	data.event_triggers.loadout_changed = nil

	data.event_triggers.loadout_changed = function(pow, inst, data)
		inst.sg.mem.skillstate = skillstate_name
		if loadout_changed_fn then
			loadout_changed_fn(pow, inst, data)
		end
	end


	Power.AddPower(Power.Slots.SKILL, id, "skillpowers", data)
end

Power.AddPowerFamily("SKILL", nil, 1)

--TODO: commonize on_add_fn/enter_room setting skillstate to parry, OR make a GetSkillState in PowerManager

Power.AddSkillPower("parry",
{
	power_category = Power.Categories.SUPPORT,
	tags = { POWER_TAGS.PROVIDES_CRITCHANCE, POWER_TAGS.PARRY },
	required_tags = { POWER_TAGS.DO_NOT_DROP },

	tuning =
	{
		[Power.Rarity.COMMON] = { },
	},
})

Power.AddSkillPower("buffnextattack",
{
	power_category = Power.Categories.DAMAGE,
	tags = { POWER_TAGS.PROVIDES_CRITCHANCE },

	stackable = true,
	max_stacks = 100, -- 0 to 100 percent
	permanent = true,

	tooltips =
	{
		"CRITICAL_HIT",
	},

	tuning =
	{
		[Power.Rarity.COMMON] = { stackspertrigger = 10 },
	},

	on_stacks_changed_fn = function(pow, inst)
		inst.components.combat:SetCritChanceModifier("skill_buffnextattack", pow.persistdata.stacks*0.01)
		inst:PushEvent("update_power", pow.def)
	end,

	event_triggers =
	{
		["do_damage"] = function(pow, inst, attack)
			if attack:GetCrit() then -- Consume the buff once we've gotten a crit.
				if attack:GetProjectile() then -- This is a ranged attack. Consume the buff now.
					inst.components.powermanager:SetPowerStacks(pow.def, 0)
					inst:PushEvent("update_power", pow.def)
				else -- This is a melee attack. Consume the buff at the end of the attack, below in "attack_end". This is so the entire attack has crit.
					pow.persistdata.consumebuff = true
				end
			end
		end,

		-- melee attack logic
		["attack_end"] = function(pow, inst)
			if pow.persistdata.consumebuff then
				inst.components.powermanager:SetPowerStacks(pow.def, 0)
				pow.persistdata.consumebuff = false
				inst:PushEvent("update_power", pow.def)
			end
		end,

		["enter_room"] = function(pow, inst, data)
			inst.components.combat:SetCritChanceModifier("skill_buffnextattack", pow.persistdata.stacks*0.01)
			inst:PushEvent("update_power", pow.def)
		end,
	}
})

Power.AddSkillPower("bananapeel",
{
	power_category = Power.Categories.SUPPORT,
	tags = { POWER_TAGS.PROVIDES_CRITCHANCE },
	prefabs = { "banana_peel", "banana_skill_recharge" },

	tooltips =
	{
	},

	tuning =
	{
		[Power.Rarity.COMMON] = {
			heal = 3, -- How much does the banana heal?
			max_bananas = 3, -- How many bananas can I have
			damage_til_new_banana = 1000, -- How much damage do I have to do to get a re-stock of a banana?
		}, 
	},

	on_add_fn = function(pow, inst)
		if not pow.persistdata.did_init then
			pow.persistdata.bananas_left = pow.persistdata:GetVar("max_bananas")
			pow.persistdata.damage_dealt = 0

			pow.persistdata.did_init = true
		end

		inst:DoTaskInTicks(1, function(inst)
			inst:PushEvent("update_banana_counter", pow.def)
		end)

	end,

	event_triggers =
	{
		["bananaeat"] = function(pow, inst, data)
			local power_heal = Attack(inst, inst)
			power_heal:SetHeal(pow.persistdata:GetVar("heal"))
			power_heal:SetSource(pow.def.name)
			inst.components.combat:ApplyHeal(power_heal)
			
			pow.persistdata.bananas_left = math.max(0, pow.persistdata.bananas_left - 1)

			-- TheDungeon.HUD:MakePopText({ target = inst, button = pow.persistdata.bananas_left.." bananas", color = UICOLORS.GOLD, size = 150, fade_time = 1.5, y_offset = 10 })

			inst:PushEvent("update_banana_counter", pow.def)
		end,

		["do_damage"] = function(pow, inst, data)
			if not powerutil.TargetIsEnemyOrDestructibleProp(data) then
				return
			end

			local damage = data:GetDamage()
			pow.persistdata.damage_dealt = pow.persistdata.damage_dealt + damage

			local threshold = pow.persistdata:GetVar("damage_til_new_banana")

			if pow.persistdata.damage_dealt >= threshold then

				if pow.persistdata.bananas_left < pow.persistdata:GetVar("max_bananas") then
					-- They have dealt enough damage and have space for more bananas. Refill a banana stock!
					pow.persistdata.bananas_left = pow.persistdata.bananas_left + 1

					local target = data:GetTarget()
					local target_pos = target:GetPosition()
					TheDungeon.HUD:MakePopText({ target = target, button = pow.persistdata.bananas_left, color = HexToRGB(0xE0B32AFF), size = 100, fade_time = 2, y_offset = 450, x_offset = -25 })
					
					ParticleSystemHelper.MakeOneShotAtPosition(target_pos, "banana_skill_recharge", 2.25, inst)
					
					local difference = pow.persistdata.damage_dealt - threshold
					pow.persistdata.damage_dealt = difference


					inst:PushEvent("update_banana_counter", pow.def)
				end

				-- Don't let them build up a huge budget of surplus damage. 
				pow.persistdata.damage_dealt = math.min(threshold, pow.persistdata.damage_dealt)
			end
		end,

		["update_banana_counter"] = function(pow, inst, data)
			pow.persistdata.counter = pow.persistdata.bananas_left
			inst:PushEvent("update_power", pow.def)
		end,

	}
})

Power.AddSkillPower("throwstone",
{
	power_category = Power.Categories.DAMAGE,
	tags = { },
	prefabs = { "player_throwstone_projectile" },

	tooltips =
	{
	},

	tuning =
	{
		[Power.Rarity.COMMON] = { },
	},
})

-- POLEARM
Power.AddSkillPower("polearm_shove",
{
	power_category = Power.Categories.SUPPORT,
	prefabs = { "" },
	required_tags = { POWER_TAGS.POLEARM },

	tooltips =
	{
	},

	tuning =
	{
		[Power.Rarity.COMMON] = { },
	},
})

Power.AddSkillPower("polearm_vault",
{
	power_category = Power.Categories.SUPPORT,
	prefabs = { "" },
	required_tags = { POWER_TAGS.POLEARM },

	tooltips =
	{
	},

	tuning =
	{
		[Power.Rarity.COMMON] = { },
	},
})

-- Recall that sends ball into an upward arc
Power.AddSkillPower("shotput_recall",
{
	power_category = Power.Categories.SUPPORT,
	prefabs = { "" },
	required_tags = { POWER_TAGS.SHOTPUT },

	tooltips =
	{
	},

	tuning =
	{
		[Power.Rarity.COMMON] = { },
	},
})

-- Recall that sends ball into a fast, horizontal arc
Power.AddSkillPower("shotput_summon",
{
	power_category = Power.Categories.DAMAGE,
	prefabs = { "" },
	required_tags = { POWER_TAGS.SHOTPUT },

	tooltips =
	{
	},

	tuning =
	{
		[Power.Rarity.COMMON] = { },
	},
})

-- Launch yourself in a tackle towards your ball
Power.AddSkillPower("shotput_seek",
{
	power_category = Power.Categories.DAMAGE,
	prefabs = { "" },
	required_tags = { POWER_TAGS.SHOTPUT },

	tooltips =
	{
	},

	tuning =
	{
		[Power.Rarity.COMMON] = { },
	},
})

-- HAMMER SKILLS
-- Slam hammer onto ground, knocking back any nearby enemies
Power.AddSkillPower("hammer_thump",
{
	power_category = Power.Categories.SUPPORT,
	prefabs = { "" },
	required_tags = { POWER_TAGS.HAMMER },
	tags = { POWER_TAGS.HAMMER_THUMP },

	tooltips =
	{
	},

	tuning =
	{
		[Power.Rarity.COMMON] = { },
	},
})

-- Toss out a buff totem
Power.AddSkillPower("hammer_totem",
{
	power_category = Power.Categories.DAMAGE,
	prefabs = { "plushies_lrg", "fx_dust_up2", "fx_ground_heal_area" },
	required_tags = { POWER_TAGS.HAMMER },

	tooltips =
	{
	},

	tuning =
	{
		[Power.Rarity.COMMON] = { healthtocreate = 25, bonusdamagepercent = 50, radius = 10 },
	},
})

-- CANNON SKILLS
Power.AddSkillPower("cannon_butt",
{
	power_category = Power.Categories.DAMAGE,
	prefabs = { },
	required_tags = { POWER_TAGS.CANNON },

	tooltips =
	{
	},

	tuning =
	{
		[Power.Rarity.COMMON] = { },
	},
})

-- BOSS SKILLS

local function SummonMegatreemonRoots(inst, x, z)
	local facingrot = inst.Transform:GetFacingRotation()
	local roots = {}

	for i=1,10 do
		inst:DoTaskInAnimFrames(i*2, function()
			local dist = i * 2
			local theta = math.rad(facingrot)
			local root = SpawnPrefab("megatreemon_growth_root_player")
			root.owner = inst
			root.Transform:SetPosition(x + dist * math.cos(theta), 0, z - dist * math.sin(theta))
			root:PushEvent("poke")

			table.insert(roots, root)
			if i == 10 then
				inst:PushEvent("projectile_launched", roots)
			end
		end)
	end
end

Power.AddSkillPower("megatreemon_weaponskill",
{
	power_category = Power.Categories.DAMAGE,
	prefabs =
	{
		'megatreemon_growth_root_player'
	},

	required_tags = { POWER_TAGS.DO_NOT_DROP },

	tooltips =
	{
	},

	tuning =
	{
		[Power.Rarity.COMMON] = { queued_blink = { 255/255, 255/255, 255/255, 1 }, blink_frames = 4 },
	},

	event_triggers =
	{
		-- If the player presses SKILL during a heavyattack, queue a Skill to be released when dealing damage.
		["controlevent"] = function(pow, inst, data)

			if inst.sg:HasStateTag("attack")
				and data.control == "skill"
				and inst.sg:HasStateTag("heavy_attack")
				and not inst.sg:HasStateTag("attack_recovery")
				and not pow.mem.attack_charged
				and not pow.mem.skill_executed
			then
				pow.mem.attack_charged = true
				local SGCommon = require "stategraphs.sg_common"
				local fmodtable = require "defs.sound.fmodtable"
				-- SGCommon.Fns.SpawnAtDist(inst, "fx_skill_megatree_launch", 0)
				inst.SoundEmitter:PlaySound(fmodtable.Event.Skill_Megatreek_Queue)
				SGCommon.Fns.BlinkAndFadeColor(inst, pow.persistdata:GetVar("queued_blink"), pow.persistdata:GetVar("blink_frames"))
			end
		end,

		["activate_skill"] = function(pow, inst, data)
			local x, z = inst.Transform:GetWorldXZ()
			SummonMegatreemonRoots(inst, x, z)
		end,

		["do_damage"] = function(pow, inst, data)
			local target = data:GetTarget()
			if data.id == "heavy_attack" then
				if pow.mem.attack_charged then
					local x, z
					if target ~= nil then
						x, z = target.Transform:GetWorldXZ()
					else
						x, z = inst.Transform:GetWorldXZ()
					end
					SummonMegatreemonRoots(inst, x, z)
				end
				pow.mem.attack_charged = false
			end
		end,

		["newstate"] = function(pow, inst, data)
			pow.mem.skill_executed = false
		end,
	}
})


-- SKILL-SPECIFIC PLAYER POWERS

-- Parry
Power.AddPlayerPower("moment37",
{
	power_category = Power.Categories.DAMAGE,
	required_tags = { POWER_TAGS.PARRY },

	prefabs = { },
	tuning =
	{
		[Power.Rarity.EPIC] = { time = 5 }, -- Tuned to be the length of the EVO Moment 37 parry, not including the kill combo
		[Power.Rarity.LEGENDARY] = { time = 9 }, -- Include the kill combo.
	},

	on_add_fn = function(pow, inst)
		inst:PushEvent("update_power", pow.def)
	end,

	event_triggers =
	{
		["parry"] = function(pow, inst, data)
			inst.components.combat:SetCritChanceModifier(pow.def.name, 1)
			pow:StartPowerTimer(inst)
			inst:PushEvent("used_power", pow.def)
		end,
		["timerdone"] = function(pow, inst, data)
			if data.name == pow.def.name then
				inst.components.combat:RemoveCritChanceModifier(pow.def.name)
			end
		end,
	},

	on_remove_fn = function(pow, inst)
		inst.components.timer:StopTimer(pow.def.name)
		inst.components.locomotor:RemoveSpeedMult(pow.def.name)
	end,
})

-- Hammer_thump: Deal 100 damage per consecutive hit.
Power.AddPlayerPower("jury_and_executioner",
{
	power_category = Power.Categories.DAMAGE,
	required_tags = { POWER_TAGS.HAMMER_THUMP },

	prefabs = { },
	stackable = true,
	permanent = true,
	max_stacks = 10,
	tuning =
	{
		[Power.Rarity.LEGENDARY] = { time = 1.25, damage_per_consecutive_hit = 100 },
	},

	on_add_fn = function(pow, inst)
		-- inst:PushEvent("update_power", pow.def)
	end,

	event_triggers =
	{
		["hammer_thumped"] = function(pow, inst, data)
			inst.components.powermanager:DeltaPowerStacks(pow.def, 1) -- Gain a stack, then set a timer to reset all stacks.
			pow:StartPowerTimer(inst)
			inst:PushEvent("used_power", pow.def)
			inst:PushEvent("update_power", pow.def)
		end,
		["timerdone"] = function(pow, inst, data)
			if data.name == pow.def.name then
				inst.components.powermanager:SetPowerStacks(pow.def, 1)
				inst:PushEvent("update_power", pow.def)
			end
		end,

		["update_power"] = function(pow, inst)
			if pow.persistdata.stacks > 0 then
				pow.persistdata.counter = (pow.persistdata.stacks-1) * pow.persistdata:GetVar("damage_per_consecutive_hit")
			else
				pow.persistdata.counter = 0
			end
		end,
	},

	on_remove_fn = function(pow, inst)
		inst.components.timer:StopTimer(pow.def.name)
	end,
})

-- BANANA Skill power: Sam's Bananas
-- Bananas heal for 50 HP. Never get Stuffed.
-- Name is reference to this person: https://klei.slack.com/archives/C05BFEBEP1D/p1686886234035829
