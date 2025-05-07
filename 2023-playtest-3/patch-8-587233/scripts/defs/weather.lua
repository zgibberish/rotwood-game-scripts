local lume = require "util.lume"
local Power = require("defs.powers.power")

local Weather = {
	Defs = {}
}

function Weather.CollectPrefabs(tbl)
	for _, weather in pairs(Weather.Defs) do
		if weather.prefabs then
			for _, prefab in ipairs(weather.prefabs) do
				table.insert(tbl, prefab)
			end
		end
	end
end

function Weather.AddWeather(name, data)
	local weathers = Weather.Defs

	local def = {
		name = name,
		tags = data.tags or {},
		prefabs = data.prefabs,
		assets = data.assets,
		event_triggers = data.event_triggers or {},
		prerequisite_fn = data.prerequisite_fn,
		on_init_fn = data.on_init_fn,
		on_start_fn = data.on_start_fn,
		on_update_fn = data.on_update_fn,
		on_finish_fn = data.on_finish_fn,
		mem = {},
	}

	weathers[name] = def

	return def
end

local function CreateAuraApplyer(inst, power)
	inst:DoTaskInTicks(1, function()
		local aura = CreateEntity("weather")

		aura.entity:AddHitBox()
		aura.entity:AddTransform()

		aura.Transform:SetPosition(0,0,0)

		aura:AddComponent("hitbox") -- For applying the aura
		aura.components.hitbox:SetHitGroup(HitGroup.NONE)
		aura.components.hitbox:SetHitFlags(HitGroup.ALL)

		aura:AddComponent("powermanager") -- For applying the aura

		local aa = aura:AddComponent("auraapplyer")
		aa:SetEffect(power)
		aa:SetRadius(30)
		aa:Enable()
	end)
end

local function ModifyColorCube(thing)
	-- print(thing)
end


Weather.AddWeather("rain",
{
	prefabs = { },

	on_init_fn = function(weather, inst)
	end,

	on_start_fn = function(weather, inst)
		SpawnPrefab("rain_forge_test", inst)
		CreateAuraApplyer(inst, "running_shoes")
		ModifyColorCube("blah")
	end,

	on_update_fn = function(weather, inst)

	end,

	on_finish_fn = function(weather, inst)
	end,

	event_triggers =
	{
	}
})


Weather.AddWeather("rain_lightning",
{
	prefabs = { },

	on_init_fn = function(weather, inst)
	end,

	on_start_fn = function(weather, inst)
		SpawnPrefab("rain_forge_test", inst)
	end,

	on_finish_fn = function(weather, inst)
	end,

	event_triggers =
	{
	}
})

Weather.AddWeather("night",
{
	prefabs = { },

	on_init_fn = function(weather, inst)
	end,

	on_start_fn = function(weather, inst)
		-- CreateAuraApplyer(inst, "night")
		-- inst:DoTaskInTicks(1, function()
		-- 	TheWorld.components.lightcoordinator:SetDefaultAmbient( 127/255, 124/255, 146/255 )
		-- 	TheWorld.components.lightcoordinator:SetIntensity(0.35)
		-- end)
	end,

	on_finish_fn = function(weather, inst)
	end,

	event_triggers =
	{
	}
})

-- Weather.AddWeather("wind",
-- {
-- 	prefabs = { },

-- 	on_init_fn = function(weather, inst)
-- 	end,

-- 	on_start_fn = function(weather, inst)
-- 		SpawnPrefab("wind", inst)
-- 		CreateAuraApplyer(inst, "groak_swallow")
-- 	end,

-- 	on_update_fn = function(weather, inst)
-- 	end,

-- 	on_finish_fn = function(weather, inst)
-- 	end,

-- 	event_triggers =
-- 	{
-- 	}
-- })

return Weather