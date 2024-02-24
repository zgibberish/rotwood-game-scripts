local spawnutil = require "util.spawnutil"


local ns_hitbox = { -15, -1, 15, 1 }

local function OnPlayerNear(inst)
	inst:Remove()
end

-- A touch trigger to keep the room locked until touched.
local function fn(prefabname)
	local inst = CreateEntity()
	inst:SetPrefabName(prefabname)

	inst.entity:AddTransform()

	inst:AddTag("CLASSIFIED")
	--[[Non-networked entity]]

	inst:AddComponent("roomlock")
	inst:AddComponent("playerproxrect")
	inst:AddComponent("prop")

	inst.components.playerproxrect:SetRect(table.unpack(ns_hitbox))

	if TheDungeon:GetDungeonMap():IsDebugMap() then
		inst.components.playerproxrect:SetOnNearFn(function() end) -- noop so it draws
		inst.components.playerproxrect:SetDebugDrawEnabled(true)
		spawnutil.MakeEditable(inst, "square")
		inst.AnimState:SetScale(table.unpack(ns_hitbox))
		inst.AnimState:SetMultColor(table.unpack(WEBCOLORS.ORANGE))
	else
		inst.components.playerproxrect:SetOnNearFn(OnPlayerNear)
	end

	return inst
end

return Prefab("room_unlock_trigger", fn)
