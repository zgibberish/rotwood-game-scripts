local prefabutil = require "prefabs.prefabutil"
local ParticleSystemHelper = require "util.particlesystemhelper"
local spawnutil = require "util.spawnutil"
local SteeringLimit = require "components.steeringlimit"
local fmodtable = require "defs.sound.fmodtable"
local lume = require("util/lume")

local monsterutil = {}

monsterutil.MonsterSize = MakeEnum {
	"SMALL", -- smaller than a player character (cabbageroll, mothball)
	"MEDIUM", -- roughly equal to a player character (zucco, blarma)
	"LARGE", -- much larger than a player character (gourdo, yammo)
	"GIANT", -- Huge. Bosses only?
}

------------------------------

-- Local Functions & Variables

local MonsterSize_to_Foley =
{
	[monsterutil.MonsterSize.SMALL] = "small",
	[monsterutil.MonsterSize.MEDIUM] = "medium",
	[monsterutil.MonsterSize.LARGE] = "large",
	[monsterutil.MonsterSize.GIANT] = "giant",
}

local MonsterSize_to_Mass =
{
	[monsterutil.MonsterSize.SMALL] = 10000,
	[monsterutil.MonsterSize.MEDIUM] = 10000,
	[monsterutil.MonsterSize.LARGE] = 100000,
	[monsterutil.MonsterSize.GIANT] = 100000,
}

local function OnCombatTargetChanged(inst, data)
	if data ~= nil then
		if data.new ~= nil then
			if data.old == nil then
				for _, attack in pairs(inst.components.attacktracker.attack_data) do
					if attack.timer_id then
						inst.components.timer:ResumeTimer(attack.timer_id)
					end
				end
			end
		end
	end
end

local function _on_flying_state_changed(inst, is_flying)
	if is_flying then
		inst.Physics:StartPassingThroughObjects()
	else
		inst.Physics:StopPassingThroughObjects()
	end
end

local function _state_tags_changed(inst, tag)
	if inst.sg:HasStateTag("flying") and not inst.sg:HasStateTag("idle") then
		_on_flying_state_changed(inst, true)
		inst.components.offsethitboxes:Get("flyinghitbox").HitBox:SetEnabled(true)
	elseif inst.sg:HasStateTag("flying") and inst.sg:HasStateTag("idle") then
		_on_flying_state_changed(inst, false)
		inst.components.offsethitboxes:Get("flyinghitbox").HitBox:SetEnabled(true)
	elseif not inst.sg:HasStateTag("flying") then
		inst.components.offsethitboxes:Get("flyinghitbox").HitBox:SetEnabled(false)
	end

end

------------------------------

-- Monster Def Functions

function monsterutil.GetDefaultMass(monstersize)
	return MonsterSize_to_Mass[monstersize]
end

function monsterutil.MakeAttackable(inst)
	-- mob tag tells weapons they can target it.
	inst:AddTag("mob")
	inst:AddComponent("attacktracker") -- mobs must have an attacktracker
end

-- TODO: examine if it's worth caching these tables so they are not created
-- uniquely per monster entity per run.  They are currently stored in each
-- lootdrop component and then used without modification by lootdropmanager
function monsterutil.BuildDropTable(inst)
	local ld = inst.components.lootdropper
	local name = inst.prefab:gsub("_elite", "")
	-- Monster Drops

	-- for now, everything drops the same loot.

	-- if inst:HasTag("elite") then
	-- 	ld:AddLootDropTags({LOOT_TAGS.ELITE, "drops_"..name})
	-- else
		ld:AddLootDropTags({LOOT_TAGS.NORMAL, "drops_"..name})
	-- end
end

local function OnMonsterPostSpawn(inst)
	TheWorld:PushEvent("spawnenemy", inst)
end

function monsterutil.MakeBasicMonster(inst, physics_size, size_category)
	size_category = size_category or monsterutil.MonsterSize.MEDIUM
	inst.monster_size = size_category


	monsterutil.BuildTuningTable(inst)

	inst.entity:AddTransform()
	inst.entity:AddAnimState()
	inst.entity:AddSoundEmitter()
	inst.entity:AddHitBox()


	inst.AnimState:SetShadowEnabled(true)
	inst.AnimState:SetRimEnabled(true)
	inst.AnimState:SetRimSize(3)
	inst.AnimState:SetRimSteps(3)

	inst.serializeHistory = true	-- Tell it to precisely sync animations

	inst.Transform:SetTwoFaced()

	inst.OnPostSpawn = OnMonsterPostSpawn

	-- Lock before other components since it fires room_locked and it's better
	-- to handle that before any components or after all of them.
	inst:AddComponent("roomlock")

	inst:AddComponent("hitbox")
	inst.components.hitbox:SetHitGroup(HitGroup.MOB)
	inst.components.hitbox:SetHitFlags(HitGroup.CHARACTERS)
	prefabutil.RegisterHitbox(inst, "main")

	monsterutil.MakeAttackable(inst)

	physics_size = physics_size or 1
	size_category = size_category or monsterutil.MonsterSize.MEDIUM

	inst:AddComponent("weight")
	inst:AddComponent("pushforce")
	inst:AddComponent("pushbacker")

	if size_category == monsterutil.MonsterSize.SMALL then
		MakeSmallMonsterPhysics(inst, physics_size)
		inst:AddTag("small")
		inst.knockdown_distance = 4 --600px
		inst.knockback_distance = 2 -- 300px
		--inst.components.pushforce:AddPushForceModifier("weight", 1)

	elseif size_category == monsterutil.MonsterSize.MEDIUM then
		MakeSmallMonsterPhysics(inst, physics_size)
		inst:AddTag("medium")
		inst.knockdown_distance = 3 --450px
		inst.knockback_distance = 1 -- 150px
		inst.components.pushforce:AddPushForceModifier("weight", 0.5)

	elseif size_category == monsterutil.MonsterSize.LARGE then
		inst.AnimState:SetSilhouetteMode(SilhouetteMode.Show)
		MakeGiantMonsterPhysics(inst, physics_size)
		inst:AddTag("large")
		inst.knockdown_distance = 2 -- 300px
		inst.knockback_distance = 0.5 --75px
		inst.components.pushforce:AddPushForceModifier("weight", 0.25)
		inst.components.pushbacker.weight = PushBackWeight.HEAVY

	elseif size_category == monsterutil.MonsterSize.GIANT then
		inst.AnimState:SetSilhouetteMode(SilhouetteMode.Show)
		MakeGiantMonsterPhysics(inst, physics_size)
		inst:AddTag("giant")
		inst.knockdown_distance = 1 -- 150px
		inst.knockback_distance = 0.25 --37px
		inst.components.pushforce:AddPushForceModifier("weight", 0.1)
		inst.components.pushbacker.weight = PushBackWeight.HEAVY
	end

	inst:AddComponent("bloomer")
	inst:AddComponent("colormultiplier")
	inst:AddComponent("coloradder")
	inst:AddComponent("hitstopper")
	inst:AddComponent("timer")
	inst:AddComponent("powermanager")
	inst:AddComponent("lowhealthindicator")
	inst:AddComponent("hitflagmanager")
	inst:AddComponent("scalable")
	inst:AddComponent("lootdropper")

	inst:AddComponent("colorshifter")
	if inst.tuning.colorshift then
		inst.components.colorshifter:PushVarianceShift("variance", inst.tuning.colorshift)
	end

	inst:AddComponent("locomotor")
	inst.components.locomotor:SetWalkSpeed(inst.tuning.walk_speed)
	if inst.tuning.run_speed then
		inst.components.locomotor:SetRunSpeed(inst.tuning.run_speed)
	end

	if inst.tuning.speedmult then
		inst.components.locomotor:AddSpeedMult("random", inst.tuning.speedmult.centered
			and SteppedRandomRangeCentered(inst.tuning.speedmult.steps, inst.tuning.speedmult.scale)
			or SteppedRandomRange(inst.tuning.speedmult.steps, inst.tuning.speedmult.scale))
	end

	dbassert(inst.tuning.steeringlimit, "Missing steeringlimit in tuning.lua. Should be max rotation degrees per second.")
	inst:AddComponent("steeringlimit", function(cmp, dt)
		return SteeringLimit.ConstantAngularRotationLimiter(cmp, dt, inst.tuning.steeringlimit)
	end)

	local modifiers = TUNING:GetEnemyModifiers(inst.prefab)

	inst:AddComponent("health")
	inst.components.health:SetMax(inst.tuning.health * (modifiers.HealthMult + modifiers.BasicHealthMult), true)

	inst:AddComponent("combat")
	inst.components.combat:SetDefaultTargettingForTuning()
	inst.components.combat:SetHurtFx("fx_hurt_sweat")
	inst.components.combat:SetHasKnockback(true)
	inst.components.combat:SetHasKnockdown(true)
	inst.components.combat:SetHasKnockdownHits(true)
	inst.components.combat:SetKnockdownDuration(1.7 + math.random() * .7)
	inst.components.combat:SetBaseDamage(inst, inst.tuning.base_damage)
	inst.components.combat:SetDungeonTierDamageMult(inst, modifiers.DungeonTierDamageMult)
	inst.components.combat:AddTargetTags(TargetTagGroups.Players)
	inst.components.combat:AddFriendlyTargetTags(TargetTagGroups.Enemies)
	inst.components.combat:SetHitStunPressureFrames(inst.tuning.hitstun_pressure_frames or math.huge)

	inst:AddComponent("damagebonus")

	inst:AddComponent("hitshudder")
	inst.components.hitshudder.scale_amount = 0.005

	if HITSTUN_VISUALIZER_ENABLED then
		inst:AddComponent("hitstunvisualizer")
	end

	----- now i'm still getting bugs and blocking people
	inst:AddComponent("foleysounder")
	-- inst.components.foleysounder:SetFootstepSound(fmodtable.Event.footstep_base_layer)
	-- inst.components.foleysounder:SetHandSound(fmodtable.Event.Dirt_hand)
	-- inst.components.foleysounder:SetJumpSound(fmodtable.Event.Dirt_jump)
	-- inst.components.foleysounder:SetLandSound(fmodtable.Event.Dirt_land)
	-- inst.components.foleysounder:SetBodyfallSound(fmodtable.Event.Dirt_bodyfall)
	inst.components.foleysounder:SetSize(MonsterSize_to_Foley[size_category])

	inst:ListenForEvent("combattargetchanged", OnCombatTargetChanged)

	-- local EnemyFollowHealthBar = require("widgets/ftf/enemyfollowhealthbar")

	-- inst:DoTaskInTicks(2, function(inst)
	-- 	if TheDungeon.HUD then
	-- 		inst.uicolor = { 255/255, 255/255, 255/255 }
	-- 		inst.follow_health_bar = TheDungeon.HUD:OverlayElement(EnemyFollowHealthBar(inst))
	-- 	end
	-- end)

	-- Push an event that monsters can listen for if they collide with map boundaries
	inst.Physics:SetCollisionCallback(function(inst)
		inst:PushEvent("mapcollision")
	end)

	inst.components.powermanager:EnsureRequiredComponents()
end

function monsterutil.MakeStationaryMonster(inst, physics_size, size_category)
	size_category = size_category or monsterutil.MonsterSize.MEDIUM
	inst.monster_size = size_category

	monsterutil.BuildTuningTable(inst)

	inst.entity:AddTransform()
	inst.entity:AddAnimState()
	inst.entity:AddSoundEmitter()
	inst.entity:AddHitBox()

	inst.AnimState:SetShadowEnabled(true)
	inst.AnimState:SetRimEnabled(true)
	inst.AnimState:SetRimSize(3)
	inst.AnimState:SetRimSteps(3)
	inst.serializeHistory = true	-- Tell it to precisely sync animations.

	inst.OnPostSpawn = OnMonsterPostSpawn
	-- inst.Transform:SetTwoFaced()

	monsterutil.MakeAttackable(inst)

	physics_size = physics_size or 1
	MakeObstacleMonsterPhysics(inst, physics_size)

	inst:AddComponent("bloomer")
	inst:AddComponent("colormultiplier")
	inst:AddComponent("coloradder")
	inst:AddComponent("colorshifter")
	inst:AddComponent("hitstopper")
	inst:AddComponent("roomlock")
	inst:AddComponent("timer")
	inst:AddComponent("powermanager")
	inst:AddComponent("lowhealthindicator")
	inst:AddComponent("hitflagmanager")
	inst:AddComponent("lootdropper")

	local modifiers = TUNING:GetEnemyModifiers(inst.prefab)

	inst:AddComponent("health")
	inst.components.health:SetMax(inst.tuning.health * (modifiers.HealthMult + modifiers.BasicHealthMult), true)

	inst:AddComponent("hitbox")
	inst.components.hitbox:SetHitGroup(HitGroup.MOB)
	inst.components.hitbox:SetHitFlags(HitGroup.CHARACTERS)
	prefabutil.RegisterHitbox(inst, "main")

	inst:AddComponent("combat")
	inst.components.combat:SetDefaultTargettingForTuning()
	inst.components.combat:SetHurtFx("fx_hurt_sweat")
	inst.components.combat:SetHasKnockback(false)
	inst.components.combat:SetHasKnockdown(false)
	inst.components.combat:SetHasKnockdownHits(false)
	inst.components.combat:SetBaseDamage(inst, inst.tuning.base_damage)
	inst.components.combat:SetDungeonTierDamageMult(inst, modifiers.DungeonTierDamageMult)
	inst.components.combat:AddTargetTags(TargetTagGroups.Players)
	inst.components.combat:AddFriendlyTargetTags(TargetTagGroups.Enemies)

	inst:AddComponent("damagebonus")

	inst:AddComponent("hitshudder")
	inst.components.hitshudder.scale_amount = 0.005
	inst.components.hitshudder.can_move = false

	inst:AddComponent("scalable")

	inst:ListenForEvent("combattargetchanged", OnCombatTargetChanged)

	inst.components.powermanager:EnsureRequiredComponents()
end

function monsterutil.ExtendToEliteMonster(inst)
	inst:AddTag("elite")
	inst:AddTag("nointerrupt")

	inst.components.attacktracker:UpdateModifiers() -- Configure modifiers again now that we have "elite" tag

	inst.components.scalable:AddScaleModifier("elite", ELITE_MOB_SCALE)
	inst:AddComponent("soundtracker")
end

function monsterutil.ExtendToBossMonster(inst)
	inst:AddTag("boss")

	inst:AddComponent("cororun")
	inst:AddComponent("boss")

	inst.components.attacktracker:UpdateModifiers() -- Configure modifiers again now that we have "boss" tag

	-- Explicitly merge Health and BossHealth multipliers.
	local modifiers = TUNING:GetEnemyModifiers(inst.prefab)
	local health_multiplier = modifiers.HealthMult + modifiers.BossHealthMult
	inst.components.health:SetMax(inst.tuning.health * health_multiplier, true)

	inst.components.hitbox:SetHitGroup(HitGroup.BOSS)

	inst.components.combat:SetHasKnockback(false)
	inst.components.combat:SetHasKnockdown(false)
	inst.components.combat:SetHasKnockdownHits(false)
end

function monsterutil.ExtendToFlyingMonster(inst)
	inst:ListenForEvent("add_state_tag", _state_tags_changed)
	inst:ListenForEvent("remove_state_tag", _state_tags_changed)

	inst.Physics:SetCollisionGroup(COLLISION.FLYERS)
	inst.Physics:ClearCollidesWith(COLLISION.HOLE_LIMITS)

	monsterutil.AddOffsetHitbox(inst, inst.hitboxes.main.HitBox:GetSize(), "flyinghitbox")

	inst:DoPeriodicTicksTask(1, function()
		local size = inst.components.offsethitboxes:Get("flyinghitbox").HitBox:GetSize() / 2
		local theta = math.rad(-inst.Transform:GetRotation() - 90 )
		inst.components.offsethitboxes:Get("flyinghitbox").Transform:SetPosition(size * math.cos(theta), 0, -size * math.sin(theta))
	end)
end

-- Generic setup function for a projectile that hits things. Normally called upon spawning the projectile.
function monsterutil.HandleBasicProjectileSetup(inst, owner, target)
	assert(owner and owner.GUID, "Owner must be a valid entity")
	inst.owner = owner
	inst.target = target
	spawnutil.ApplyCharmColors(inst, owner, "projectile")

	--inst.components.hitbox:SetHitGroup(HitGroup.NONE)
	inst.components.hitbox:SetHitFlags(owner ~= nil and owner.components.hitbox:GetHitFlags() or HitGroup.CHARACTERS)
end

function monsterutil.BasicProjectileSetup(inst, owner, target)
	if inst:ShouldSendNetEvents() then
		TheNetEvent:SetupProjectile(inst.GUID, owner.GUID, target and target.GUID or nil)
	else
		monsterutil.HandleBasicProjectileSetup(inst, owner, target)
	end
end

------------------------------
-- Monster common event handler setup functions

-- Override an existing event handler function
function monsterutil.OverrideEventHandler(events, name, override_fn)
	for i, event in ipairs(events) do
		if event.name == name then
			events[i].fn = override_fn
			return
		end
	end
end

-- Data Parameters:
-- locomote_data: Data to pass into the OnLocomote callback - see params in SGCommon.Events.OnLocomote.
-- ondying_data: Data to pass into the OnMonsterDying callback - see params in SGCommon.Events.OnMonsterDying.
-- ondeath_fn: Function to call when the death callback is called. Will be called after the default OnMonsterDeath function is called.
-- chooseattack_fn: Function to call to determine the next attack to perform. Defaults to SGCommon.Fns.ChooseAttack.
function monsterutil.AddMonsterCommonEvents(events, data)
	local SGCommon = require "stategraphs.sg_common"
	events[#events + 1] = SGCommon.Events.OnAttacked()
	events[#events + 1] = SGCommon.Events.OnKnockdown()
	events[#events + 1] = SGCommon.Events.OnKnockback()

	if data then
		events[#events + 1] = SGCommon.Events.OnLocomote(data.locomote_data or { walk = true, turn = true })
		events[#events + 1] = SGCommon.Events.OnAttack(data.chooseattack_fn or SGCommon.Fns.ChooseAttack)
		events[#events + 1] = SGCommon.Events.OnHitStunPressureAttack()

		events[#events + 1] = SGCommon.Events.OnDying(data.ondying_data or nil)

		-- AddMinibossCommonEvents and AddBossCommonEvents add their own OnQuickDeath handler instead.
		if not data.no_quick_death_handler then
			events[#events + 1] = SGCommon.Events.OnQuickDeath(data.ondeath_fn or nil)
		end
	end
	--[[
	events[#events + 1] = SGPlayerCommon.Events.OnAvoidedDying()
	events[#events + 1] = SGPlayerCommon.Events.OnAvoidedDeath()
	events[#events + 1] = SGPlayerCommon.Events.OnDeath()]]
	events[#events + 1] = SGCommon.Events.OnCinematicSkipped()
end

-- Data Parameters:
-- ondeath_fn: Function to call after the death callback is called.
-- chooseattack_fn: Function to call to determine the next attack to perform. Defaults to SGCommon.Fns.ChooseAttack.
function monsterutil.AddStationaryMonsterCommonEvents(events, data)
	local SGCommon = require "stategraphs.sg_common"
	if data then
		events[#events + 1] = SGCommon.Events.OnAttack(data.chooseattack_fn or SGCommon.Fns.ChooseAttack)
		events[#events + 1] = SGCommon.Events.OnHitStunPressureAttack()

		events[#events + 1] = SGCommon.Events.OnDying(data.ondying_data or nil)

		-- AddMinibossCommonEvents and AddBossCommonEvents add their own OnQuickDeath handler instead.
		if not data.no_quick_death_handler then
			events[#events + 1] = SGCommon.Events.OnQuickDeath(data.ondeath_fn or nil)
		end
	end
	events[#events + 1] = SGCommon.Events.OnAttackedLeftRight()
end

-- Data Parameters:
-- idlebehavior_fn: Function to cell to determine the idle behaviour to play. If this is not defined, SGCommon.Events.OnIdleBehavior is not added.
-- battlecry_fn:  Function to cell to determine the battlecry behaviour to play. If this is not defined, SGCommon.Events.OnBattleCry is not added.
-- spawn_battlefield (boolean): Flag to determine whether or not to add SGCommon.Events.OnSpawnBattlefield
-- spawn_perimeter (boolean): Flag to determine whether or not to add SGCommon.Events.OnSpawnPerimeter
function monsterutil.AddOptionalMonsterEvents(events, data)
	local SGCommon = require "stategraphs.sg_common"
	if not data then return end

	if data.idlebehavior_fn then
		events[#events + 1] = SGCommon.Events.OnIdleBehavior(data.idlebehavior_fn)
	end

	if data.battlecry_fn then
		events[#events + 1] = SGCommon.Events.OnBattleCry(data.battlecry_fn)
	end

	if data.spawn_battlefield then
		events[#events + 1] = SGCommon.Events.OnSpawnBattlefield()
	end

	if data.spawn_perimeter then
		events[#events + 1] = SGCommon.Events.OnSpawnPerimeter()
	end
end

-- Data Parameters:
-- See monsterutil.AddMonsterCommonEvents()
function monsterutil.AddMinibossCommonEvents(events, data)
	local SGCommon = require "stategraphs.sg_common"

	if not data then
		data = {}
	end
	if not data.ondying_data then
		data.ondying_data = {}
	end

	if not data.ondying_data.callback_fn then
		data.ondying_data.callback_fn = SGCommon.Fns.OnMinibossDying
	end

	monsterutil.AddMonsterCommonEvents(events, data)
end

function monsterutil.AddBossCommonEvents(events, data)
	local SGCommon = require "stategraphs.sg_common"

	if not data then
		data = {}
	end
	if not data.ondying_data then
		data.ondying_data = {}
	end

	if not data.ondying_data.callback_fn then
		data.ondying_data.callback_fn = SGCommon.Fns.OnBossDying
	end

	data.no_quick_death_handler = true
	monsterutil.AddMonsterCommonEvents(events, data)

	events[#events + 1] = SGCommon.Events.OnBossDeath()
end

------------------------------

function monsterutil.AddOffsetHitbox(inst, size, name_override)
	if not inst.components.offsethitboxes then
		inst:AddComponent("offsethitboxes")
	end

	inst.components.offsethitboxes:Add(
		size or inst.Physics:GetSize(),
		name_override or "offsethitbox")
end

local elite_str = "_elite"

function monsterutil.BuildTuningTable(inst, prefabname_override)
	local base_prefab, is_elite = string.gsub(prefabname_override or inst.prefab, elite_str, "")
	local tuning_tbl = {}

	if is_elite > 0 then
		tuning_tbl = shallowcopy(TUNING[base_prefab..elite_str])
	end

	for k, v in pairs(TUNING[base_prefab]) do
		if not tuning_tbl[k] then
			tuning_tbl[k] = v
		end
	end

	inst.tuning = tuning_tbl
end

function monsterutil.ReverseHitGroup(inst)
	if inst.components.hitbox:GetHitGroup() == HitGroup.PLAYER then
		inst.components.hitbox:SetHitGroup(HitGroup.MOB)
	else
		inst.components.hitbox:SetHitGroup(HitGroup.PLAYER)
	end
end

function monsterutil.ReverseHitFlags(inst)
	if inst.components.hitbox:GetHitFlags() == HitGroup.CREATURES then
		inst.components.hitbox:SetHitFlags(HitGroup.CHARACTERS)
	else
		inst.components.hitbox:SetHitFlags(HitGroup.CREATURES)
	end
end

function monsterutil.CharmMonster(monster, summoner)
	monster.summoner = summoner
	monster:Face(summoner)
	monster:RemoveTag("mob")
	monster:AddTag("playerminion")
	monster:RemoveComponent("roomlock")

	-- combat
	monster.components.combat:ClearTargetTags()
	monster.components.combat:AddTargetTags(TargetTagGroups.Enemies)
	monster.components.combat:ClearFriendlyTargetTags()
	monster.components.combat:AddFriendlyTargetTags(TargetTagGroups.Players)

	-- hitbox
	monster.components.hitbox:SetHitGroup(HitGroup.PLAYER)
	monster.components.hitbox:SetHitFlags(HitGroup.CREATURES)

	--attacktracker
	monster.components.attacktracker:SetMinimumCooldown(0)
	monster.components.attacktracker:ModifyAttackCooldowns(.5)
	monster.components.attacktracker:ModifyAllAttackTimers(0)

	-- charmed colouring
	local color_add = (TUNING[monster.prefab] and TUNING[monster.prefab].charm_colors) and TUNING[monster.prefab].charm_colors.color_add or TUNING.default_charm_colors.color_add
	local color_mult = (TUNING[monster.prefab] and TUNING[monster.prefab].charm_colors) and TUNING[monster.prefab].charm_colors.color_mult or TUNING.default_charm_colors.color_mult
	local bloom = (TUNING[monster.prefab] and TUNING[monster.prefab].charm_colors) and TUNING[monster.prefab].charm_colors.bloom or TUNING.default_charm_colors.bloom

	monster.components.coloradder:PushColor("charmed", color_add[1], color_add[2], color_add[3], color_add[4])
	monster.components.colormultiplier:PushColor("charmed", color_mult[1], color_mult[2], color_mult[3], color_mult[4])
	monster.components.bloomer:PushBloom("charmed", bloom[1], bloom[2], bloom[3], bloom[4])

	-- charmed fx appears to be auto-cleaned up on entity removal as a result of being a child
	local param =
	{
		particlefxname = "heart_trail",
		ischild = true,
	}
	ParticleSystemHelper.MakeEventSpawnParticles(monster, param)

	-- TODO: find a way to colour the death FX charmed colours

	monster:PushEvent("charmed") -- add an EventListener to the prefab definition for any creature-specific setup that may be necessary
end

function monsterutil.MakeMiniboss(ent)
	ent:AddTag("miniboss")
	ent:AddTag("nointerrupt")

	if ent.tuning.colorshift_miniboss then
		ent.components.colorshifter:PopColor("variance")
		ent.components.colorshifter:PushVarianceShift("variance", ent.tuning.colorshift_miniboss)
	end

	-- Explicitly merge Health and MinibossHealth multipliers.
	local modifiers = TUNING:GetEnemyModifiers(ent.prefab)
	local miniboss_health_mod = modifiers.HealthMult + modifiers.MinibossHealthMult

	ent.components.health:SetMax(ent.tuning.health * miniboss_health_mod)
end

local function CreateOffsetPhysicsCollider(name, size, mass)
	local inst = CreateEntity(name)

	inst.entity:AddTransform()

	local phys = inst.entity:AddPhysics()
	phys:SetMass(mass or 100000000)
	phys:SetCollisionGroup(COLLISION.CHARACTERS)
	phys:CollidesWith(COLLISION.CHARACTERS)
	-- phys:CollidesWith(COLLISION.GIANTS)
	phys:SetRoundRect(size)

	inst:AddTag("CLASSIFIED")
	--[[Non-networked entity]]
	inst.persists = false

	return inst
end

function monsterutil.AddOffsetPhysicsCollider(inst, size, mass, name_override)
	local name = name_override or "offsetphysicscollider"

	inst[name] = CreateOffsetPhysicsCollider(name, size, mass)
	-- inst[name].entity:SetParent(inst.entity)
end

--------------------------------------------------------------------------
-- Start/stop functions for making an entity immovable (other objects can collide with it, but the entity won't be pushed.)
monsterutil.StartCannotBePushed = function(inst)
	inst.sg.statemem.pb_weight = inst.components.pushbacker.weight
	inst.components.pushbacker.weight = 0

	inst.sg.statemem.mass = inst.Physics:GetMass()
	inst.Physics:SetMass(100000000)
end

monsterutil.StopCannotBePushed = function(inst)
	inst.Physics:SetMass(inst.sg.statemem.mass)
	inst.components.pushbacker.weight = inst.sg.statemem.pb_weight
end

------------------------------

function monsterutil.BruteForceFindWalkableTileFromXZ(x, z, tries, good_tiles_threshold)
	local THRESHOLD = good_tiles_threshold or 5 -- How many good tiles must we find before we accept this as a 'walkable' spot? Essentially, how deep in from the edge should we be?

	local good_tiles_found = 0 -- Wait until we've counted a few good tiles before spawning, so we make sure we spawn a bit deeper into the stage.
						 -- Don't just accept the first good tile because this is often directly on the shore, causing drowning.

	local check_dist = tries or 10 -- How many tries in each direction should we do?

	local final_x
	local final_z

	-- check up
	for i=1,check_dist do
		-- print(i)
		local tile = TheWorld.Map:GetNamedTileAtXZ(x, z + i)
		-- DebugDraw.GroundPoint(x, z + i, 1, UICOLORS.RED, 1, 1)
		-- print("check:", x, z + i, tile)
		if tile ~= "IMPASSABLE" then
			-- print("FOUND")
			good_tiles_found = good_tiles_found + 1
			if good_tiles_found >= THRESHOLD then
				final_x = x
				final_z = z + i
				break
			end
		end
	end

	good_tiles_found = 0
	-- check down
	if final_x == nil then
		-- print("check down")
		for i=1,check_dist do
			local tile = TheWorld.Map:GetNamedTileAtXZ(x, z - i)
			-- print("check:", x, z - i)
			-- DebugDraw.GroundPoint(x, z - i, 1, UICOLORS.RED, 1, 1)

			if tile ~= "IMPASSABLE" then
				-- print("FOUND")
				good_tiles_found = good_tiles_found + 1
				if good_tiles_found >= THRESHOLD then
					final_x = x
					final_z = z - i
					break
				end
			end
		end
	end

	good_tiles_found = 0
	--check left
	if final_x == nil then
		for i=1,check_dist do
			local tile = TheWorld.Map:GetNamedTileAtXZ(x - i, z)
			-- print("check:", x - i, z)
			-- DebugDraw.GroundPoint(x - i, z, 1, UICOLORS.RED, 1, 1)

			if tile ~= "IMPASSABLE" then
				-- print("FOUND")
				good_tiles_found = good_tiles_found + 1
				if good_tiles_found >= THRESHOLD then
					final_x = x - i
					final_z = z
					break
				end
			end
		end
	end

	good_tiles_found = 0
	--check right
	if final_x == nil then
		for i=1,check_dist do
			local tile = TheWorld.Map:GetNamedTileAtXZ(x + i, z)
			-- print("check:", x - i, z)
			-- DebugDraw.GroundPoint(x + i, z, 1, UICOLORS.RED, 1, 1)
			if tile ~= "IMPASSABLE" then
				-- print("FOUND")
				good_tiles_found = good_tiles_found + 1
				if good_tiles_found >= THRESHOLD then
					final_x = x + i
					final_z = z
					break
				end
			end
		end
	end

	return final_x, final_z
end

------------------------------

-- For use with SGCommon.Events.OnHitBoxTriggered()
monsterutil.defaultAttackHitFX = "fx_hit_player_round"

-- For use with SGCommon.Events.OnProjectileHitBoxTriggered()
monsterutil.defaultProjectileAttackHitFX = "fx_hit_player_round"

------------------------------

function monsterutil.MaxAttacksPerTarget(inst, data)
	if not data.max_attacks_per_target then
		return false
	elseif data.max_attacks_per_target <= 0 then
		return true
	end

	local max_attacks = data.max_attacks_per_target
	local musthavetags = {"mob"}
	local x, z = inst.Transform:GetWorldXZ()
	--local enemies = TheWorld.components.roomclear:GetEnemies()
	local neighbors = TheSim:FindEntitiesXZ(x, z, 100, musthavetags, nil, nil)
	if #neighbors > 0 then
		local attackcount = 0
		local mytarget = inst.components.combat:GetTarget()
		for i, ent in ipairs(neighbors) do
			local ent_target = ent.components.combat:GetTarget()
			local active_attack = ent.components.attacktracker:GetActiveAttack()
			local queued_attack = ent.sg.statemem.queuedattack
			--local active_check = active_attack and active_attack.type == data.type
			--local queued_check = queued_attack and queued_attack.type == data.type
			if ent ~= inst and ent_target == mytarget and (active_attack or queued_attack) then
				attackcount = attackcount + 1
				if attackcount >= max_attacks then
					return false
				end
			end
		end
	end
	return true
end

function monsterutil.GetMonstersInRegion(region)
	local mobs = {}

	for id, location in pairs(region.locations) do
		if location.monsters then
			for cat, monsters in pairs(location.monsters) do
				for _, monster in ipairs(monsters) do
					table.insert(mobs, monster)
				end
			end
		end
	end

	mobs = lume.unique(mobs)

	mobs = lume.sort(mobs, function(a, b)
		local a_health = TUNING[a] and TUNING[a].health or 0
		local b_health = TUNING[b] and TUNING[b].health or 0
		return a_health < b_health
	end)

	return mobs
end

function monsterutil.GetMonstersInLocation(location)
	local mobs = {}

	if location.monsters then
		for cat, monsters in pairs(location.monsters) do
			for _, monster in ipairs(monsters) do
				table.insert(mobs, monster)
			end
		end
	end

	mobs = lume.unique(mobs)

	mobs = lume.sort(mobs, function(a, b)
		local a_health = TUNING[a] and TUNING[a].health or 0
		local b_health = TUNING[b] and TUNING[b].health or 0
		return a_health < b_health
	end)

	return mobs
end

return monsterutil
