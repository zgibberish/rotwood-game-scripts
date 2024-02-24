---------------------------------------------------------------------------------------
-- Custom script for minigame behaviour on auto-generated npc prefabs
--
-- Likely each npc would have a completely different minigame, so don't put
-- anything in default and make everything specific to one npc. That way you
-- can drive all the logic from code and artists just enable minigame on
-- applicable npcs.
---------------------------------------------------------------------------------------

local npc_minigame = {
	default = {},
	npc_cook = {},
}


function npc_minigame.default.CollectPrefabs(prefabs, args)
end


------------------------------ {{{
-- Cooking rhythm game

local function Cook_StartInteract(inst, player)
	inst.components.cooker:PlayCookingSong(player)
end

local function Cook_OnDeactivate(inst, player)
	if TheDungeon:GetDungeonMap():IsDebugMap() then
		return
	end

	inst.components.cooker:StopCookingSong()

	inst.components.conversation:DeactivatePrompt(player)
end

function npc_minigame.npc_cook.CustomInit(inst, opts)
	inst:AddComponent("cooker")
	inst.components.interactable
		:SetOnInteractFn(Cook_StartInteract)
		:SetOnLoseInteractFocusFn(Cook_OnDeactivate)
end
-- }}}


return npc_minigame
