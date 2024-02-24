---------------------------------------------------------------------------------------
-- Custom script for props that react to touch
---------------------------------------------------------------------------------------


local hitboxtrigger = {
	default = {},
}

function hitboxtrigger.default.CollectPrefabs(prefabs, args)
end

local function OnEditorSpawn(inst, editor)
end

function hitboxtrigger.default.CustomInit(inst, opts)
	local is_gameplay = not TheDungeon:GetDungeonMap():IsDebugMap()

	inst.OnEditorSpawn = OnEditorSpawn

	if opts.lock_until_hit then
		inst:AddComponent("roomlock")
	end
	inst.entity:AddHitBox()
	inst:AddComponent("hitbox")
	if is_gameplay then
		inst.components.hitbox:SetHitGroup(HitGroup.NEUTRAL)
		inst.components.hitbox:SetHitFlags(HitGroup.PLAYER)
	end
	inst:AddComponent("hitshudder")
end

function hitboxtrigger.PropEdit(editor, ui, params)
	ui:TextWrapped("Sets up a hitbox so we can react to player touch in the StateGraph.")
	ui:TextWrapped([[Call inst.components.hitbox:PushCircle(0, 0, 4, HitPriority.PLAYER_DEFAULT) (or similar) in your idle state's onupdate and use EventHandler("hitboxtriggered", fn) to listen for the trigger event.]])
	-- We could provide a function that builds the idle state, but that feels
	-- too rigid and having it all in the sg file seems easier to follow.
	ui:TextWrapped("See sg_konjur_reward_drop.lua for an example.")

	ui:Separator()

	params.script_args.lock_until_hit = ui:_Checkbox("Lock Room Until Hit", params.script_args.lock_until_hit) or nil
end

return hitboxtrigger
