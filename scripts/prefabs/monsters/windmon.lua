local monsterutil = require "util.monsterutil"
local prefabutil = require "prefabs.prefabutil"
local spawnutil = require "util.spawnutil"
local lume = require "util.lume"

local assets =
{
	Asset("ANIM", "anim/windmon_bank.zip"),
	Asset("ANIM", "anim/windmon_build.zip"),
	--Asset("ANIM", "anim/windmon_elite_build.zip"),
	Asset("ANIM", "anim/trap_owlitzer_hairball.zip")
}

local prefabs =
{
	"owlitzer_spikeball",

	--Drops
	GroupPrefab("drops_windmon")
}
prefabutil.SetupDeathFxPrefabs(prefabs, "windmon")

local MAX_SPIKE_BALLS = 30
local function GetNumOwnedSpikeballs(inst)
	-- Don't spawn additional spikeballs if there's already too many on the map.
	local num_owned_spikeballs = 0
	local spikeballs = TheSim:FindEntitiesXZ(0, 0, 100, { "spikeball" })
	for _, spikeball in ipairs(spikeballs) do
		if spikeball.spawner == inst then
			num_owned_spikeballs = num_owned_spikeballs + 1
		end
	end
	return num_owned_spikeballs
end

local attacks =
{
	wind_gust =
	{
		priority = 1,
		damage_mod = 1,
		startup_frames = 15,
		cooldown = 2,
		initialCooldown = 0,
		pre_anim = "wind_spin_pre",
		hold_anim = "wind_spin_hold",
		start_conditions_fn = function(inst, data, trange)
			return not inst:HasTag("elite") and trange:IsInRange(20)
		end
	},

	shoot =
	{
		priority = 2,
		startup_frames = 20,
		cooldown = 7,
		initialCooldown = 0,
		pre_anim = "trap_pre",
		hold_anim = "trap_hold",
		start_conditions_fn = function(inst, data, trange)
			return trange:IsInRange(30) and GetNumOwnedSpikeballs(inst) < MAX_SPIKE_BALLS
		end
	},
}

local elite_attacks = lume.merge(attacks,
{
	elite_wind_gust =
	{
		priority = 1,
		damage_mod = 1,
		startup_frames = 15,
		cooldown = 2,
		initialCooldown = 0,
		pre_anim = "wind_spin_pre",
		hold_anim = "wind_spin_hold",
		start_conditions_fn = function(inst, data, trange)
			return trange:IsInRange(20)
		end
	},
})

local function OnAttacked(inst, data)
	if data ~= nil and data.attack:GetAttacker() ~= nil then
		inst.components.combat:SetTarget(data.attack:GetAttacker())
	end
end

local MONSTER_SIZE = 1

local function fn(prefabname)
	local inst = CreateEntity()
	inst:SetPrefabName(prefabname)

	monsterutil.MakeStationaryMonster(inst, MONSTER_SIZE)

	inst.AnimState:SetBank("windmon_bank")

	inst:AddComponent("snaptogrid")
	inst.components.snaptogrid:SetDimensions(2, 2, 0) --2x2 trunk on the ground
	inst.components.snaptogrid:SetDimensions(4, 4, 1) --4x4 leaves in the air

	inst:AddComponent("auraapplyer")
	inst.components.auraapplyer:SetHitFlags(Attack.HitFlags.GROUND)

	inst:AddComponent("attackangle")

	inst.AnimState:PlayAnimation("idle", true) -- Need to set an animation in order for SetFrame to work below.
	local frame = math.random(inst.AnimState:GetCurrentAnimationNumFrames()) - 1
	inst.AnimState:SetFrame(frame)

	inst:SetStateGraph("sg_windmon")
	inst:SetBrain("brain_treemon")

	inst:ListenForEvent("attacked", OnAttacked)
	inst:ListenForEvent("knockback", OnAttacked)

	-- Add a random cooldown so that all windmon don't attack at the same time after spawning.
	-- local delay = math.random() * ATTACK_COOLDOWN
	-- inst.components.combat:StartCooldown(delay)

	return inst
end

local function normal_fn(prefabname)
	local inst = fn(prefabname)

	inst.AnimState:SetBuild("windmon_build")

	inst.components.attacktracker:AddAttacks(attacks)

	return inst
end

local function elite_fn(prefabname)
	local inst = fn(prefabname)

	inst.AnimState:SetBuild("windmon_build") -- Temp, remove once elite build is made!
	--inst.AnimState:SetBuild("windmon_elite_build")

	inst.components.attacktracker:AddAttacks(elite_attacks)

	monsterutil.ExtendToEliteMonster(inst)

	monsterutil.AddOffsetHitbox(inst)

	return inst
end

return Prefab("windmon", normal_fn, assets, prefabs, nil, NetworkType_SharedHostSpawn)
	, Prefab("windmon_elite", elite_fn, assets, nil, nil, NetworkType_SharedHostSpawn)
