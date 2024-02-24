local assets =
{
}

local function setup_all(prefabname)
	local inst = CreateEntity()
	inst:SetPrefabName(prefabname)

	inst.entity:AddTransform()
	inst.entity:AddHitBox()

	inst:AddComponent("hitbox")
	inst.components.hitbox:SetUtilityHitbox(true)
	inst.components.hitbox:SetHitGroup(HitGroup.PLAYER)
	inst.components.hitbox:SetHitFlags(HitGroup.CREATURES | HitGroup.RESOURCE)

	inst:AddComponent("powermanager")
	inst.components.powermanager:EnsureRequiredComponents()

	inst:SetStateGraph("sg_windguster")

	return inst
end

-- CONFIGURATION FUNCTIONS
local function make_weak(inst)
	inst.powerlevel = 1
	return inst
end
local function make_medium(inst)
	inst.powerlevel = 2
	return inst
end
local function make_strong(inst)
	inst.powerlevel = 3
	return inst
end

-- BASIC LEFT/RIGHT/DOWN/UP functions
local function left_fn(prefabname)
	local inst = setup_all(prefabname)
	inst.sg.mem.hitbox_data = { -4, 0, 1.5, 0 }
 
	return inst
end
local function right_fn(prefabname)
	local inst = setup_all(prefabname)
	inst.sg.mem.hitbox_data =  { 0, 4, 1.5, 0 }
 
	return inst
end
local function down_fn(prefabname)
	local inst = setup_all(prefabname)

	inst.sg.mem.hitbox_data =  { -1, 1, 3, -4 }
 
	return inst
end
local function up_fn(prefabname)
	local inst = setup_all(prefabname)

	inst.sg.mem.hitbox_data = { -1, 1, 3, 4 }

	return inst
end

-- CONSTRUCTOR FUNCTIONS
local function weak_left_fn(prefabname)
	return make_weak(left_fn(prefabname))
end
local function medium_left_fn(prefabname)
	return make_medium(left_fn(prefabname))
end
local function strong_left_fn(prefabname)
	return make_strong(left_fn(prefabname))
end
local function weak_right_fn(prefabname)
	return make_weak(right_fn(prefabname))
end
local function medium_right_fn(prefabname)
	return make_medium(right_fn(prefabname))
end
local function strong_right_fn(prefabname)
	return make_strong(right_fn(prefabname))
end
local function weak_up_fn(prefabname)
	return make_weak(up_fn(prefabname))
end
local function medium_up_fn(prefabname)
	return make_medium(up_fn(prefabname))
end
local function strong_up_fn(prefabname)
	return make_strong(up_fn(prefabname))
end
local function weak_down_fn(prefabname)
	return make_weak(down_fn(prefabname))
end
local function medium_down_fn(prefabname)
	return make_medium(down_fn(prefabname))
end
local function strong_down_fn(prefabname)
	return make_strong(down_fn(prefabname))
end

-- These are all so that we can do one EffectEvents.MakeEventSpawnLocalEntity() call and not need to configure anything past that.
return Prefab("player_wind_gust_dummy_weak_left", weak_left_fn, assets),
	Prefab("player_wind_gust_dummy_medium_left", medium_left_fn, assets),
	Prefab("player_wind_gust_dummy_strong_left", strong_left_fn, assets),
	Prefab("player_wind_gust_dummy_weak_right", weak_right_fn, assets),
	Prefab("player_wind_gust_dummy_medium_right", medium_right_fn, assets),
	Prefab("player_wind_gust_dummy_strong_right", strong_right_fn, assets),
	Prefab("player_wind_gust_dummy_weak_down", weak_down_fn, assets),
	Prefab("player_wind_gust_dummy_medium_down", medium_down_fn, assets),
	Prefab("player_wind_gust_dummy_strong_down", strong_down_fn, assets),
	Prefab("player_wind_gust_dummy_weak_up", weak_up_fn, assets),
	Prefab("player_wind_gust_dummy_medium_up", medium_up_fn, assets),
	Prefab("player_wind_gust_dummy_strong_up", strong_up_fn, assets)