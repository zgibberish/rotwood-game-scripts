local storageChest = {
	default = {},
}

function start_interact(inst, player)
    if TheDungeon.HUD.townHud then
        TheDungeon.HUD.townHud:OnInventoryButtonClicked(player)
    end
end

function storageChest.default.CustomInit(inst, opts)
    assert(opts)

    inst:AddComponent("interactable")
    inst.components.interactable:SetRadius(5)
    :SetOnInteractFn(start_interact)
    :SetupForButtonPrompt(STRINGS.UI.ACTIONS.OPEN_STORAGE, nil, nil, 3.5)
end

return storageChest