local bossutil = require "prefabs.bossutil"
local prefabutil = require "prefabs.prefabutil"
local monsterutil = require "util.monsterutil"
local playerutil = require "util.playerutil"
local fmodtable = require "defs.sound.fmodtable"

local assets =
{
	Asset("ANIM", "anim/bandicoot_bank.zip"),
	Asset("ANIM", "anim/bandicoot_build.zip"),

}

local prefabs =
{
	"fx_bandicoot_bite",
	"fx_bandicoot_howl_wind",
	"fx_bandicoot_howl_wave",
	"fx_bandicoot_slobber",
	"fx_bandicoot_tail_dust",
	"fx_hurt_sweat",
	"fx_step_puff_med",
	"tombstone",

	"swamp_stalactite",

	--Drops
	GroupPrefab("drops_generic"),
	GroupPrefab("drops_bandicoot"),
}

local BASIC_ATTACKS_PHASE_MAX = 3
local MELEE_RANGE = 6
local MELEE_LONG_RANGE = 10

local function GetPhase(inst)
	-- Clones always use the parent's current phase
	local parent = inst:HasTag("clone") and inst.parent or inst
	return parent.boss_coro:CurrentPhase()
end

local attacks =
{
	-- Basic attacks
	swipe =
	{
		priority = 2,
		damage_mod = 1.2,
		startup_frames = 20,
		cooldown = 2,
		initialCooldown = 0,
		pre_anim = "swipe_pre",
		hold_anim = "swipe_hold",
		start_conditions_fn = function(inst, data, trange)
			local current_phase = GetPhase(inst)
			return current_phase <= BASIC_ATTACKS_PHASE_MAX and trange:IsInRange(MELEE_RANGE)
		end
	},

	--[[swipe2 =
	{
		priority = 1,
		damage_mod = 1,
		startup_frames = 15,
		cooldown = 3.33,
		initialCooldown = 0,
		pre_anim = "swipe2_pre",
		hold_anim = "swipe2_hold",
		start_conditions_fn = function(inst, data, trange)
			return false -- This attack can be transitioned into from the swipe OnEnter.
		end
	},]]

	swipe_to_tail_sweep =
	{
		priority = 1,
		damage_mod = 1.2,
		startup_frames = 11,
		cooldown = 0,
		initialCooldown = 0,
		pre_anim = "swipe_to_tail_sweep_pre",
		hold_anim = "swipe_to_tail_sweep_hold",
		start_conditions_fn = function(inst, data, trange)
			return false -- This attack gets called from swipe.
		end
	},

	tailspin =
	{
		priority = 1,
		damage_mod = 1,
		startup_frames = 40,
		cooldown = 2.67,
		initialCooldown = 0,
		pre_anim = "tailspin_pre",
		hold_anim = "tailspin_loop",
		start_conditions_fn = function(inst, data, trange)
			local current_phase = GetPhase(inst)
			return current_phase <= BASIC_ATTACKS_PHASE_MAX and trange:IsInRange(MELEE_LONG_RANGE)
		end
	},

	--[[tailwhip =
	{
		priority = 3,
		damage_mod = 1,
		startup_frames = 7,
		cooldown = 3.33,
		initialCooldown = 0,
		pre_anim = "tailwhip_pre",
		hold_anim = "tailwhip_loop",
		start_conditions_fn = function(inst, data, trange)
			-- Attack any players behind
			local current_phase = inst.boss_coro:CurrentPhase()
			local precheck = current_phase <= BASIC_ATTACKS_PHASE_MAX
			if precheck then
				local facing = inst.Transform:GetFacing() == FACING_LEFT and -1 or 1
				local range = 3
				local pos = inst:GetPosition()
				return playerutil.FindClosestPlayerInRange(pos.x - range * facing, pos.z, range, true)
			end

			return false
		end
	},]]

	taunt =
	{
		priority = 3,
		startup_frames = 40,
		cooldown = 6.67,
		initialCooldown = 10,
		pre_anim = "taunt_pre",
		hold_anim = "taunt_loop",
		start_conditions_fn = function(inst, data, trange)
			local current_phase = GetPhase(inst)
			return current_phase <= BASIC_ATTACKS_PHASE_MAX
		end
	},

	-- Mid-phase attacks
	bite =
	{
		priority = 1,
		damage_mod = 1.2,
		startup_frames = 22,
		cooldown = 3.33,
		initialCooldown = 0,
		pre_anim = "bite_pre",
		hold_anim = "bite_step",
		start_conditions_fn = function(inst, data, trange)
			local current_phase = GetPhase(inst)
			local target = inst.components.combat:GetTarget()
			return current_phase > BASIC_ATTACKS_PHASE_MAX and trange:IsInRange(MELEE_LONG_RANGE) and inst:IsWithinAngleTo(target, -45, 45)
		end
	},

	bite_down =
	{
		priority = 1,
		damage_mod = 1.2,
		startup_frames = 22,
		cooldown = 3.33,
		initialCooldown = 0,
		pre_anim = "bite_down_pre",
		start_conditions_fn = function(inst, data, trange)
			local current_phase = GetPhase(inst)
			local target = inst.components.combat:GetTarget()
			return current_phase > BASIC_ATTACKS_PHASE_MAX and trange:IsInRange(MELEE_LONG_RANGE) and inst:IsWithinAngleTo(target, -135, -45)
		end
	},

	-- Rage transition
	rage_transition =
	{
		damage_mod = 0.5,
		start_conditions_fn = function(inst, data, trange)
			return false -- Called when health goes below rage threshold
		end
	},

	-- Special attacks
	peekaboo =
	{
		damage_mod = 1.2,
		start_conditions_fn = function(inst, data, trange)
			return false -- Called via boss coroutine.
		end
	},

	-- Low health phase attacks.
	rage =
	{
		damage_mod = 1.5,
		start_conditions_fn = function(inst, data, trange)
			return false -- Called via boss coroutine.
		end
	},

	-- Clone's explosion attack.
	clone_explode =
	{
		damage_mod = 3,
		start_conditions_fn = function(inst, data, trange)
			return false -- Called via clone death.
		end
	},
}

local function OnCombatTargetChanged(inst, data)
	if data.old == nil and data.new ~= nil then
		inst.boss_coro:Start()
	end
end

local function DoRageModeFaceSwap(inst)
	-- Change eye colour to red
	local hsb = HSB(160, 120, 90)
	inst.AnimState:SetSymbolColorShift("eye_untex", table.unpack(hsb))

	-- Change eye bloom to red
	local r, g, b = HexToRGBFloats(StrToHex("9322D4C9"))
	local intensity = 0.6
	inst.AnimState:SetSymbolBloom("eye_untex", r, g, b, intensity)

	-- Set angry face symbol on anim
	inst.AnimState:ShowLayer("rage")
end

local MONSTER_SIZE = 2.8

local function fn(prefabname)
	local inst = CreateEntity()
	inst:SetPrefabName(prefabname)

	monsterutil.MakeBasicMonster(inst, MONSTER_SIZE, monsterutil.MonsterSize.GIANT)

	inst.AnimState:SetBank("bandicoot_bank")
	inst.AnimState:SetBuild("bandicoot_build")
	--inst.AnimState:PlayAnimation("idle", true)

	-- Hide angry face symbol on anim
	inst.AnimState:HideLayer("rage")

	-- Eye bloom
	local r, g, b = HexToRGBFloats(StrToHex("3867FFFF"))
	local intensity = 0.6
	inst.AnimState:SetSymbolBloom("eye_untex", r, g, b, intensity)

	inst:AddComponent("bossdata")
	inst.components.bossdata:SetBossPhaseChangedFunction(DoRageModeFaceSwap)

	--TheFocalPoint.components.focalpoint:StartFocusSource(inst, FocusPreset.BOSS)

	monsterutil.AddOffsetHitbox(inst, nil, "offsethitbox")

	inst.components.combat:SetFrontKnockbackOnly(true)
	inst.components.combat:SetVulnerableKnockdownOnly(true)
	inst.components.combat:SetBlockKnockback(true)

	inst:AddComponent("fallingobject") -- Used only for falling stalactite Peek-A-Boom attack when bandicoot rides a stalactite to the ground

	inst.components.attacktracker:AddAttacks(attacks)

	inst:SetStateGraph("sg_bandicoot")
	inst:SetBrain("brain_bandicoot")
	inst:SetBossCoro("bc_bandicoot")

	inst.components.foleysounder:SetFootstepSound(fmodtable.Event.bandicoot_footstep)
	inst.components.foleysounder:SetBodyfallSound(fmodtable.Event.bandicoot_bodyfall)


	return inst
end

local function bandicoot_boss_fn(prefabname)
	local inst = fn(prefabname)
	monsterutil.ExtendToBossMonster(inst)

	inst:ListenForEvent("combattargetchanged", OnCombatTargetChanged)
	bossutil.SetupLastPlayerDeadEventHandlers(inst)

	inst:AddComponent("cineactor")
	inst.components.cineactor:AfterEvent_PlayAsLeadActor("dying", "cine_boss_death_hit_hold", { "cine_bandicoot_death" })
	inst.components.cineactor:QueueIntro("cine_bandicoot_intro")

	-- inst.components.foleysounder:SetFootstepSound(fmodtable.Event.badicoot_footstep)
	-- inst.components.foleysounder:SetBodyfallSound(fmodtable.Event.badicoot_bodyfall)

	return inst
end

local function bandicoot_clone_fn(prefabname)
	local inst = fn(prefabname)

	inst:AddTag("clone")

	inst:AddComponent("cororun")
	inst:ListenForEvent("combattargetchanged", OnCombatTargetChanged)

	inst.components.hitbox:SetHitGroup(HitGroup.BOSS) -- Set to the same hit group so that it doesn't get hit with the rage bite

	-- Clones listen for parent death. Need to do this here, since it shares boss event handlers in the stategraph file.
	--inst:ListenForEvent("dying", function() inst.sg:GoToState("death") end, inst)

	-- Clones have no shadows!
	inst.AnimState:SetShadowEnabled(false)

	-- inst.components.foleysounder:SetFootstepSound(fmodtable.Event.badicoot_footstep)
	-- inst.components.foleysounder:SetBodyfallSound(fmodtable.Event.badicoot_bodyfall)

	return inst
end

return Prefab("bandicoot", bandicoot_boss_fn, assets, prefabs, nil, NetworkType_HostAuth)
	, Prefab("bandicoot_clone", bandicoot_clone_fn, assets, prefabs, nil, NetworkType_HostAuth)
