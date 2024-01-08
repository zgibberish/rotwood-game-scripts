---------------------------------------------------------------------------------------
-- Custom script for minigame behaviour on auto-generated npc prefabs
---------------------------------------------------------------------------------------

local npc_minigame = {
	default = {},
	npc_cook = {},
}

local function noop() end


function npc_minigame.default.CollectPrefabs(prefabs, args)
end


function npc_minigame.npc_cook.OnDeactivate(inst, player)
	if TheDungeon:GetDungeonMap():IsDebugMap() then
		return
	end

	inst.components.cooker:StopCookingSong()

	inst.components.conversation:DeactivatePrompt(player)
end

function npc_minigame.npc_cook.CustomInit(inst, opts)
	inst:AddComponent("cooker")
	inst.components.interactable:SetOnLoseInteractFocusFn(npc_minigame.npc_cook.OnDeactivate)
end

return npc_minigame
