local monsterutil = require "util.monsterutil"
local prefabutil = require "prefabs.prefabutil"
local fmodtable = require "defs.sound.fmodtable"

local assets =
{
	Asset("ANIM", "anim/zucco_bank.zip"),
	Asset("ANIM", "anim/zucco_build.zip"),
}

local elite_assets =
{
	Asset("ANIM", "anim/zucco_bank.zip"),
	Asset("ANIM", "anim/zucco_elite_build.zip"),
}

local prefabs =
{
	"fx_hurt_sweat",
	"fx_low_health_ring",

	"trap_zucco",

	--Drops
	GroupPrefab("drops_generic"),
	GroupPrefab("drops_zucco"),
}
prefabutil.SetupDeathFxPrefabs(prefabs, "zucco")

local attacks =
{
	swipe =
	{
		priority = 2,
		damage_mod = 0.6,
		startup_frames = 20,
		cooldown = 8.67, --This used to be 5, but the entire swipe, swipe2, swipe3 sequence takes roughly 5sec so Zucco would be constantly swiping. This gives a chance for some breathing room.
		initialCooldown = 0,
		pre_anim = "swipe_pre",
		hold_anim = "swipe_hold",
		max_attacks_per_target = 1,
		start_conditions_fn = function(inst, data, trange)
			local result = false
			if trange:IsInRange(8) then
				result = monsterutil.MaxAttacksPerTarget(inst, data)
			end
			return result
		end
	},

	swipe2 =
	{
		priority = 3,
		damage_mod = 0.7,
		startup_frames = 5,
		cooldown = 0.67,
		pre_anim = "swipe2_pre",
		hold_anim = "swipe2_hold",
		start_conditions_fn = function(inst, data, trange)
			if inst.sg.statemem.chainattack == 2 then
				return true
			end
		end
	},

	swipe3 =
	{
		priority = 4,
		damage_mod = 0.9,
		cooldown = 0.67,
		startup_frames = 5,
		pre_anim = "swipe3_pre",
		hold_anim = "swipe3_hold",
		start_conditions_fn = function(inst, data, trange)
			if inst.sg.statemem.chainattack == 3 then
				return true
			end
		end
	},

	windmill =
	{
		priority = 1,
		damage_mod = 1,
		startup_frames = 20,
		cooldown = 3.33,
		initialCooldown = 0,
		pre_anim = "windmill_pre",
		hold_anim = "windmill_hold",
		max_attacks_per_target = 1,
		is_hitstun_pressure_attack = true,
		start_conditions_fn = function(inst, data, trange)
			local result = false
			if not inst.sg.statemem.chainattack and trange:TestBeam(0, 10, 3) then
				result = monsterutil.MaxAttacksPerTarget(inst, data)
			end
			return result
		end
	},
}

local elite_attacks =
{
	swipe =
	{
		priority = 2,
		damage_mod = 0.6,
		startup_frames = 20,
		cooldown = 8.67,
		initialCooldown = 0,
		pre_anim = "swipe_pre",
		hold_anim = "swipe_hold",
		start_conditions_fn = function(inst, data, trange)
			if trange:IsInRange(8) then
				return true
			end
		end
	},

	swipe2 =
	{
		priority = 3,
		damage_mod = 0.8,
		startup_frames = 5,
		cooldown = 0.67,
		pre_anim = "swipe2_pre",
		hold_anim = "swipe2_hold",
		--max_interrupts = 1,
		start_conditions_fn = function(inst, data, trange)
			if inst.sg.statemem.chainattack == 2 then
				return true
			end
		end
	},

	swipe3 =
	{
		priority = 4,
		damage_mod = 1,
		cooldown = 0.67,
		startup_frames = 5,
		pre_anim = "swipe3_pre",
		hold_anim = "swipe3_hold",
		--max_interrupts = 1,
		start_conditions_fn = function(inst, data, trange)
			if inst.sg.statemem.chainattack == 3 then
				return true
			end
		end
	},

	swipe4 =
	{
		priority = 5,
		damage_mod = 1,
		cooldown = 0.67,
		startup_frames = 15,
		pre_anim = "swipe4_pre",
		hold_anim = "swipe4_hold",
		--max_interrupts = 1,
		start_conditions_fn = function(inst, data, trange)
			if inst.sg.statemem.chainattack == 4 then
				return true
			end
		end
	},

	windmill =
	{
		priority = 1,
		damage_mod = 1,
		startup_frames = 20,
		cooldown = 3.33,
		initialCooldown = 0,
		pre_anim = "windmill_pre",
		hold_anim = "windmill_hold",
		is_hitstun_pressure_attack = true,
		start_conditions_fn = function(inst, data, trange)
			if not inst.sg.statemem.chainattack and trange:TestBeam(0, 10, 3) then
				return true
			end
		end
	},
}

local function ShouldHide(inst)
	-- are only zuccos left in the room?
	if not TheWorld.components.roomclear then
		return false
	end

	local should_hide = false

	local enemies = TheWorld.components.roomclear:GetEnemies()

	for enemy, _ in pairs(enemies) do
		if not enemy:HasTag("zucco") then
			should_hide = true
		end
	end

	return should_hide
end

local function CalculateSpawnerWeight(spawner)
	-- give the spawner a "score" based on the current battlefield.
	local players = TheNet:GetPlayersOnRoomChange()
	if players and #players > 0 then
		local total_dist = 0
		for _, player in pairs(players) do
			total_dist = total_dist + spawner:GetDistanceSqTo(player)
		end
		local average_distance_from_players = total_dist / #players
		return average_distance_from_players
	end
	return 0
end

local function OnTakeDamage(inst, attack)
	if inst:IsValid()
		and inst.brain.brain
		and inst:IsAlive()
		and attack:GetAttacker()
		and IsEntityInTargetTagGroup(attack:GetAttacker(), TargetTagGroups.Players)
	then
		inst.brain.brain.in_sneak_mode = false
		inst.brain.brain:Reset()
	end
end

local MONSTER_SIZE = 1.4

local function fn(prefabname)
	local inst = CreateEntity()
	inst:SetPrefabName(prefabname)

	monsterutil.MakeBasicMonster(inst, MONSTER_SIZE, monsterutil.MonsterSize.MEDIUM)

	inst:AddTag("zucco")

	inst.AnimState:SetBank("zucco_bank")
	inst.AnimState:SetBuild("zucco_build")
	inst.AnimState:PlayAnimation("idle", true)
	inst.AnimState:SetFrame(math.random(inst.AnimState:GetCurrentAnimationNumFrames()) - 1)

	inst.components.combat:SetFrontKnockbackOnly(true)
	inst.components.combat:SetVulnerableKnockdownOnly(true)
	inst.components.combat:SetBlockKnockback(true)

	inst.components.attacktracker:SetMinimumCooldown(4.67) -- default is 2, most of which is eaten up by the long 3slice attack

	inst:ListenForEvent("take_damage", OnTakeDamage)

	inst:SetStateGraph("sg_zucco")
	inst:SetBrain("brain_zucco")

	inst:ListenForEvent("charmed", function() inst.brain.brain.in_sneak_mode = false end)

	inst.CalculateSpawnerWeight = CalculateSpawnerWeight
	inst.ShouldHide = ShouldHide

	---foleysounder
	inst.components.foleysounder:SetFootstepSound(fmodtable.Event.zucco_footstep)
	inst.components.foleysounder:SetBodyfallSound(fmodtable.Event.zucco_bodyfall)

	-- inst.components.foleysounder:SetHitStartSound(fmodtable.Event.AAAA_default_event)
    inst.components.foleysounder:SetKnockbackStartSound(fmodtable.Event.zucco_hit)
    inst.components.foleysounder:SetKnockdownStartSound(fmodtable.Event.zucco_knockdown)

	return inst
end

local function normal_fn(prefabname)
	local inst = fn(prefabname)

	inst.components.attacktracker:AddAttacks(attacks)

	return inst
end

local function elite_fn(prefabname)
	local inst = fn(prefabname)

	inst.AnimState:SetBuild("zucco_elite_build")

	inst.components.attacktracker:AddAttacks(elite_attacks)

	monsterutil.ExtendToEliteMonster(inst)

	return inst
end

return Prefab("zucco", normal_fn, assets, prefabs, nil, NetworkType_SharedHostSpawn)
	, Prefab("zucco_elite", elite_fn, elite_assets, prefabs, nil, NetworkType_SharedHostSpawn)
