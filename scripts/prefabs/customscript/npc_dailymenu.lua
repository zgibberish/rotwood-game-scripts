---------------------------------------------------------------------------------------
-- Custom script for minigame behaviour on auto-generated npc prefabs
---------------------------------------------------------------------------------------

local npc_dailymenu = {
	default = {},
	npc_cook = {},
}


function npc_dailymenu.default.CollectPrefabs(prefabs, args)
end


function npc_dailymenu.npc_cook.OnDeactivate(inst, player)
end

function npc_dailymenu.npc_cook.CustomInit(inst, opts)
	inst:AddComponent("dailymenu")
end

return npc_dailymenu
