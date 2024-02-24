---------------------------------------------------------------------------------------
--Custom script for auto-generated prop prefabs
---------------------------------------------------------------------------------------
local EffectEvents = require "effectevents"
local SGCommon = require("stategraphs.sg_common")
local SceneGen = require "components.scenegen"
local bossdef = require  "defs.monsters.bossdata"
local lume = require "util.lume"


local prop_destructible = {
	default = {},
}

local CollectPrefabs = {
	destructible_wood_shorty = { "hit_wood", },
	destructible_wood_tall = { "hit_wood", },
	destructible_rock_shorty = { "hit_rock", },
	destructible_rock_tall = { "hit_rock", },
	destructible_owlrock_shorty = { "hit_rock", },
	destructible_owlrock_tall = { "hit_rock", },
	destructible_megatreemon_shorty = { "hit_konjur", "hit_wood_mega" },
	destructible_megatreemon_tall = { "hit_konjur", "hit_wood_mega" },
	destructible_twig_tall = { "hit_spore" },
	destructible_bandiforest_stalag = { "hit_stalag" },
	destructible_bandiforest_stalag_tall = { "hit_stalag" },
	destructible_deadbug_tall = { "hit_deadbug" },
	destructible_deadbug_shorty = { "hit_deadbug" },
	default = {},
}

function prop_destructible.default.CollectPrefabs(prefabs, args)
	table.appendarrays(prefabs, CollectPrefabs[args.prefab] or CollectPrefabs.default)
end

function prop_destructible.default.CustomInit(inst, args)
	local props =
	{
		default =
		{
			health = TUNING.PROP_DESTRUCTIBLE.HEALTH.LOW,
		},
		destructible_rock_shorty =
		{
			fx = { "rock" } ,
			health = TUNING.PROP_DESTRUCTIBLE.HEALTH.MEDIUM,
		},
		destructible_rock_tall =
		{
			fx = { "rock" } ,
			health = TUNING.PROP_DESTRUCTIBLE.HEALTH.HIGH,
		},
		destructible_owlrock_shorty =
		{
			fx = { "rock" } ,
			health = TUNING.PROP_DESTRUCTIBLE.HEALTH.MEDIUM,
		},
		destructible_owlrock_tall =
		{
			fx = { "rock" } ,
			health = TUNING.PROP_DESTRUCTIBLE.HEALTH.HIGH,
		},
		destructible_wood_shorty =
		{
			fx = { "wood" },
			health = TUNING.PROP_DESTRUCTIBLE.HEALTH.LOW,
		},
		destructible_wood_tall =
		{
			fx = { "wood" },
			health = TUNING.PROP_DESTRUCTIBLE.HEALTH.HIGH,
		},
		destructible_megatreemon_shorty =
		{
			fx = { "wood_mega", "konjur" },
			health = TUNING.PROP_DESTRUCTIBLE.HEALTH.HIGH,
		},
		destructible_megatreemon_tall =
		{
			fx = { "wood_mega", "konjur" },
			health = TUNING.PROP_DESTRUCTIBLE.HEALTH.VERY_HIGH,
		},
		destructible_twig_tall =
		{
			fx = { "spore" },
			health = TUNING.PROP_DESTRUCTIBLE.HEALTH.MEDIUM,
		},
		destructible_twig_shorty =
		{
			fx = { "spore" },
			health = TUNING.PROP_DESTRUCTIBLE.HEALTH.LOW,
		},
		destructible_bandiforest_stalag =
		{
			fx = { "stalag", "konjur" },
			health = TUNING.PROP_DESTRUCTIBLE.HEALTH.HIGH,
		},
		destructible_bandiforest_stalag_tall =
		{
			fx = { "stalag", "konjur" },
			health = TUNING.PROP_DESTRUCTIBLE.HEALTH.VERY_HIGH,
		},
		destructible_deadbug_tall =
		{
			fx = { "deadbug" },
			health = TUNING.PROP_DESTRUCTIBLE.HEALTH.MEDIUM,
		},
			destructible_deadbug_shorty =
		{
			fx = { "deadbug" },
			health = TUNING.PROP_DESTRUCTIBLE.HEALTH.LOW,
		},
	}
	local cfg = props[args.prefab] or props.default

	inst.entity:AddHitBox()
	inst.HitBox:SetNonPhysicsRect(0.5)
	inst.HitBox:SetHitGroup(HitGroup.NEUTRAL)

	inst:AddComponent("hitstopper")
	if inst.highlightchildren ~= nil then
		for i = 1, #inst.highlightchildren do
			inst.components.hitstopper:AttachChild(inst.highlightchildren[i])
		end

--		inst.AnimState:SetSendRemoteUpdatesToLua(true)
		--inst:ListenForEvent("remoteanimupdate", SGCommon.Fns.RemoteAnimUpdate)
	end

	inst:AddComponent("combat")
	inst.components.combat:SetHasKnockback(false)
	inst.components.combat:SetHasKnockdown(false)

	inst:AddComponent("health")
	inst.components.health:SetMax(cfg.health, true)
	inst.components.health:SetHealable(false)

	MakeObstaclePhysics(inst, 1)

	inst.SpawnHitRubble = prop_destructible.default.SpawnHitRubble
	inst.fx_types = cfg.fx

	inst:AddTag("prop_destructible")
	inst:AddTag("no_remove_on_death")

	inst:SetStateGraph("sg_prop_destructible")
end

function prop_destructible.default.SpawnHitRubble(inst, right)
	if inst.fx_types ~= nil then
		for _,fx_type in pairs(inst.fx_types) do
			local params =
			{
				["fxname"] = "hit_" .. fx_type,
				["flipfacingandrotation"] = right,
			}
			-- non-networked method placed it at inst x,0,z
			-- this method places at x,y,z ... should be fine since y is usually 0?
			EffectEvents.MakeEventSpawnEffect(inst, params)
		end
	end
end

function prop_destructible.PropEdit(editor, ui, params)
	local all_bosses = bossdef:GetBossIDs()
	local no_boss = 1
	table.insert(all_bosses, no_boss, "")

	local is_propdestructible = params.script == "prop_destructible"
	local idx = lume.find(all_bosses, is_propdestructible and params.script_args and params.script_args.boss)
	local changed
	changed, idx = ui:Combo("Boss Prop", idx or no_boss, all_bosses)
	if changed then
		if idx == no_boss then
			params.script = nil
			params.script_args = nil
		else
			params.script = "prop_destructible"
			params.script_args = {
				boss = all_bosses[idx],
			}
		end
		editor:SetDirty()
	end

	--TODO: choose hit fx (multiple or one) in this screen
	--TODO: choose health in this screen (from TUNING.PROP_DESTRUCTIBLE.HEALTH table)
end

return prop_destructible
