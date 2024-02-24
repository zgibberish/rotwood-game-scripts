local screenopener = {
	default = {},
}

local function OnInteract( inst, player, opts )
	local screen_ctor = require(opts.screen_require)
	-- Screen can access inst with
	-- player.components.playercontroller:GetInteractTarget() but we don't
	-- assume much about what arguments the screen accepts.
	TheFrontEnd:PushScreen(screen_ctor(player))
	player.sg:GoToState('idle_accept')
end

local function CanInteract(inst, player, is_focused)
	return TheWorld:HasTag("town")
end

local function GetInteractionString(prefab_name)
	local str = STRINGS.UI.SCREENOPENER_PROP[prefab_name]
		or STRINGS.UI.SCREENOPENER_PROP.default
	return "<p bind='Controls.Digital.ACTION' color=0> ".. str
end

function screenopener.default.CustomInit(inst, opts)
	if not inst.components.interactable then
		inst:AddComponent("interactable")
	end

	inst.components.interactable:SetRadius(3.5)
		:SetInteractStateName("powerup_interact")
		:SetInteractConditionFn(function(_, player, is_focused) return CanInteract(inst, player, is_focused) end)
		:SetOnInteractFn(function(_, player) OnInteract(inst, player, opts) end)
		:SetupForButtonPrompt(GetInteractionString(inst.prefab), nil, nil, opts.y_world_offset)
end

function screenopener.PropEdit(editor, ui, params)
	local args = params.script_args
	assert(args)

	ui:PushDisabledStyle()
	ui:InputText("Interact Label", GetInteractionString(editor.prefabname))
	ui:PopDisabledStyle()
	ui:SetTooltipIfHovered("Modify STRINGS.UI.SCREENOPENER_PROP in strings.lua")

	args.screen_require = ui:_InputText("Require Path", args.screen_require, imgui.InputTextFlags.CharsNoBlank)
	if args.screen_require and args.screen_require:len() > 0 then
		local mod = pcall(require, args.screen_require)
		if not mod then
			ui:TextColored(WEBCOLORS.RED, "Invalid require path: module not found.")
		end
	else
		ui:TextColored(WEBCOLORS.RED, "Require path for screen to open is mandatory.")
	end

	-- Unfortunately no easy tuning for offset here, but not sure it's useful anyway.
	local use_default = 0
	args.y_world_offset = ui:_SliderFloat("Button Y Offset", args.y_world_offset or use_default, 0, 200, "%0.2f world units")
	if args.y_world_offset == use_default then
		args.y_world_offset = nil
	end
end

return screenopener
