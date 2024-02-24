local bossutil = require "prefabs.bossutil"
local prefabutil = require "prefabs.prefabutil"
local monsterutil = require "util.monsterutil"
local spawnutil = require "util.spawnutil"

local assets =
{
	Asset("ANIM", "anim/megatreemon_build.zip"),
	Asset("ANIM", "anim/megatreemon_bank.zip"),

	-- for debris FX
	Asset("ANIM", "anim/treemon_bank.zip"),
	Asset("ANIM", "anim/treemon_build.zip"),
}

local prefabs =
{
	"cine_megatreemon_intro",
	"fx_hurt_woodchips",
	"megatreemon_growth_root",
	"megatreemon_bomb_projectile",
	"trap_bomb_pinecone",
	--Drops
	GroupPrefab("drops_megatreemon"),
	GroupPrefab("fx_warning"),
}

local attacks =
{
	swipe =
	{
		cooldown = 3.33,
		startup_frames = 35,
		start_conditions_fn = function(inst, data, trange)
			if trange:TestCone45(0, 8, 8) and inst.components.rootattacker:IsIdle() then
				return true
			end
		end
	},

	root =
	{
		initialCooldown = 10,
		cooldown = 3.33,
		startup_frames = 35,
		start_conditions_fn = function(inst, data, trange)
			if not trange:TestCone45(0, 8, 8) and inst.components.rootattacker:IsIdle() then
				return true
			end
		end
	},
}

local function OnCombatTargetChanged(inst, data)
	if data.old == nil and data.new ~= nil then
		inst.boss_coro:Start()
	end
end

local function DebugDrawEntity(inst, ui, panel, colors)
	inst.eye_bloom = inst.eye_bloom or { 1,1,1,1, }
	ui:Text("Alpha is bloom intensity")
	local changed, r,g,b,a = ui:ColorEdit4("Eye Bloom Color", table.unpack(inst.eye_bloom))
	if changed then
		inst.eye_bloom[1] = r
		inst.eye_bloom[2] = g
		inst.eye_bloom[3] = b
		inst.eye_bloom[4] = a
		inst.AnimState:SetSymbolBloom("eye_untex", table.unpack(inst.eye_bloom))
	end
end

local function fn(prefabname)
	local inst = CreateEntity()
	inst:SetPrefabName(prefabname)

	monsterutil.MakeStationaryMonster(inst, 1.75, monsterutil.MonsterSize.GIANT) -- TODO: Needs a different physics shape
	monsterutil.ExtendToBossMonster(inst)
	inst.HitBox:SetNonPhysicsRect(2)
	inst:AddTag("giant")

	inst.AnimState:SetBank("megatreemon_bank")
	inst.AnimState:SetBuild("megatreemon_build")
	inst.AnimState:PlayAnimation("idle", true)

	local scale = 2
	inst.AnimState:SetScale(scale, scale)
	local r, g, b = HexToRGBFloats(StrToHex("EA914DFF"))
	local intensity = 0.6
	inst.AnimState:SetSymbolBloom("eye_untex", r, g, b, intensity)

	TheFocalPoint.components.focalpoint:StartFocusSource(inst, FocusPreset.BOSS)

	inst:AddComponent("prop")
	inst:AddComponent("snaptogrid")
	inst.components.snaptogrid:SetDimensions(3, 3, 0) --3x3 trunk on the ground
	inst.components.snaptogrid:SetDimensions(5, 5, 1) --5x5 leaves in the air

	inst.components.combat:SetHurtFx("fx_hurt_woodchips")

	inst.components.attacktracker:AddAttacks(attacks)

	inst:AddComponent("rootattacker")

	inst:ListenForEvent("combattargetchanged", OnCombatTargetChanged)
	bossutil.SetupLastPlayerDeadEventHandlers(inst)

	monsterutil.AddOffsetHitbox(inst, 2.75)

	inst:DoPeriodicTicksTask(1, function()
		local offsethitbox = inst.components.offsethitboxes:Get("offsethitbox")
		local size = offsethitbox.HitBox:GetSize() * 0.9
		local theta = math.rad(-inst.Transform:GetRotation() - 90 )
		offsethitbox.Transform:SetPosition(size * math.cos(theta), 0, -size * math.sin(theta))
	end)

	inst:DoTaskInTicks(1, function()
		-- something randomly rotates the megatreemon which messes with the local positioning of the offset hitbox
		inst.Transform:SetRotation(0)
		local offsethitbox = inst.components.offsethitboxes:Get("offsethitbox")
		offsethitbox.Transform:SetPosition(0, 0, 2.5)
		offsethitbox.HitBox:SetEnabled(true)
	end)

	inst:SetStateGraph("sg_megatreemon")
	inst:SetBrain("brain_megatreemon")
	inst:SetBossCoro("bc_megatreemon")

	inst:AddComponent("cineactor")
	inst.components.cineactor:AfterEvent_PlayAsLeadActor("dying", "cine_boss_death_hit_hold", { "cine_megatreemon_death" })
	inst.components.cineactor:QueueIntro("cine_megatreemon_intro")

	inst.DebugDrawEntity = DebugDrawEntity

	return inst
end

---------------------------------------------------------------------------------------

local function SetupLinked(inst, owner)
	inst.owner = owner

	owner.components.bloomer:AttachChild(inst)
	owner.components.colormultiplier:AttachChild(inst)
	owner.components.coloradder:AttachChild(inst)
	owner.components.hitstopper:AttachChild(inst)

	local function oninterrupted()
		inst.sg:PushEvent("interrupted")
	end

	local function on_owner_removed()
		inst.sg:PushEvent("interrupted")
	end

	local function on_removed()
		if inst.owner ~= nil then
			if inst.owner.components.rootattacker.summoned_roots[inst] then
				inst.owner.components.rootattacker.summoned_roots[inst] = nil
			end
		end
	end

	inst:ListenForEvent("treemon_growth_interrupted", oninterrupted, owner)
	inst:ListenForEvent("onremove", on_owner_removed, owner)
	inst:ListenForEvent("onremove", on_removed)
end

local function rootfn(prefabname)
	local inst = CreateEntity()
	inst:SetPrefabName(prefabname)

	inst.entity:AddTransform()
	inst.entity:AddAnimState()
	inst.entity:AddHitBox()

	local scale = 1.5
	inst.AnimState:SetScale(scale, scale)

	inst.HitBox:SetEnabled(false)

	inst.Transform:SetTwoFaced()

	inst.AnimState:SetBank("megatreemon_bank")
	inst.AnimState:SetBuild("megatreemon_build")
	inst.AnimState:PlayAnimation("root_spike_pre")
	inst.AnimState:SetShadowEnabled(true)
	inst.AnimState:SetRimEnabled(true)
	inst.AnimState:SetRimSize(3)
	inst.AnimState:SetRimSteps(3)

	inst:AddComponent("bloomer")
	inst:AddComponent("colormultiplier")
	inst:AddComponent("coloradder")
	inst:AddComponent("hitstopper")

	inst:AddComponent("hitbox")
	inst.components.hitbox:SetHitGroup(HitGroup.MOB)
	inst.components.hitbox:SetHitFlags(HitGroup.CHARACTERS)

	inst:AddComponent("combat")

	inst:SetStateGraph("sg_megatreemon_growth_root")

	inst.persists = false

	inst.Setup = SetupLinked

	return inst
end

local function rootplayerfn(prefabname)
	local inst = CreateEntity()
	inst:SetPrefabName(prefabname)

	inst.entity:AddTransform()
	inst.entity:AddAnimState()
	inst.entity:AddHitBox()

	local scale = 1.5
	inst.AnimState:SetScale(scale, scale)

	inst.HitBox:SetEnabled(false)

	inst.Transform:SetTwoFaced()

	inst.AnimState:SetBank("megatreemon_bank")
	inst.AnimState:SetBuild("megatreemon_build")
	inst.AnimState:PlayAnimation("root_spike_pre")
	inst.AnimState:SetShadowEnabled(true)
	inst.AnimState:SetRimEnabled(true)
	inst.AnimState:SetRimSize(3)
	inst.AnimState:SetRimSteps(3)
	inst.serializeHistory = true -- TODO: networking2022, roots -- check bandwidth use

	inst:AddComponent("bloomer")
	inst:AddComponent("colormultiplier")
	inst:AddComponent("coloradder")
	inst:AddComponent("hitstopper")

	inst:AddComponent("hitbox")
	inst.components.hitbox:SetHitGroup(HitGroup.PLAYER)
	inst.components.hitbox:SetHitFlags(HitGroup.CREATURES | HitGroup.RESOURCE)

	inst:AddComponent("combat")

	inst:SetStateGraph("sg_megatreemon_growth_root_player")

	inst.persists = false

	inst.Setup = SetupLinked

	return inst
end

---------------------------------------------------------------------------------------

local bomb_prefabs =
{
	GroupPrefab("bombs_traps"),
}

local function bomb_projectile_fn(prefabname)
	local inst = spawnutil.CreateComplexProjectile(
	{
		name = prefabname,
		bank = "trap_bomb_pinecone",
		build = "trap_bomb_pinecone",
		start_anim = "idle_cone",
		stategraph = "sg_megatreemon_bomb_projectile",
	})

	inst:AddComponent("snaptogrid")
	inst.components.snaptogrid:SetDimensions(1, 1, -1)

	return inst
end

---------------------------------------------------------------------------------------

return Prefab("megatreemon", fn, assets, prefabs, nil, NetworkType_HostAuth)
	, Prefab("megatreemon_growth_root", rootfn, assets, nil, nil, NetworkType_None)
	, Prefab("megatreemon_bomb_projectile", bomb_projectile_fn, assets, bomb_prefabs, nil, NetworkType_ClientAuth) -- TODO: networking2022, use one specifically for player power (bomb_on_dodge)?
	, Prefab("megatreemon_growth_root_player", rootplayerfn, assets, nil, nil, NetworkType_ClientAuth)
