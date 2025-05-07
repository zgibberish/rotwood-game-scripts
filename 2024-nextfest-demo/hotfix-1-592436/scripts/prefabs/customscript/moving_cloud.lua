---------------------------------------------------------------------------------------
--Custom script for auto-generated prop prefabs
---------------------------------------------------------------------------------------

local moving_cloud = {
	default = {},
}

function moving_cloud.LivePropEdit(editor, ui, params, defaults)
	local args = params.script_args

	ui:Text("Boundaries")
	local changed, newmin = ui:SliderFloat("Left", args.min or defaults.min, -100, 100)
	if changed then
		args.min = newmin ~= defaults.min and newmin or nil
	end
	local changed, newmax = ui:SliderFloat("Right", args.max or defaults.max, -100, 100)
	if changed then
		args.max = newmax ~= defaults.max and newmax or nil
	end

	ui:Text("Move Speed")
	local changed, newminspeed = ui:SliderFloat("Min Speed", args.minspeed or defaults.minspeed, -3, 3)
	if changed then
		args.minspeed = newminspeed ~= defaults.minspeed and newminspeed or nil
	end
	local changed, newmaxspeed = ui:SliderFloat("Max Speed", args.maxspeed or defaults.maxspeed, -3, 3)
	if changed then
		args.maxspeed = newmaxspeed ~= defaults.maxspeed and newmaxspeed or nil
	end

	if ui:SmallButton("Reset to defaults") then
		args = {}
	end

	params.script_args = args
end

function moving_cloud.Apply(inst, args)
	inst.components.automover.min = args.min or moving_cloud.Defaults.min
	inst.components.automover.max = args.max or moving_cloud.Defaults.max

	inst.components.automover.minspeed = args.minspeed or moving_cloud.Defaults.minspeed
	inst.components.automover.maxspeed = args.maxspeed or moving_cloud.Defaults.maxspeed

	inst.components.automover:Refresh()
end


function moving_cloud.default.CustomInit(inst, args)
	inst:AddComponent("automover")

	inst.components.automover.min = args.min or moving_cloud.Defaults.min
	inst.components.automover.max = args.max or moving_cloud.Defaults.max

	inst.components.automover.minspeed = args.minspeed or moving_cloud.Defaults.minspeed
	inst.components.automover.maxspeed = args.maxspeed or moving_cloud.Defaults.maxspeed

	inst.components.automover:Refresh()

	if TheInput:IsEditMode() then
		inst:StopUpdatingComponent(inst.components.automover) -- Not sure if this should be in the component instead. Something to be said for either solution
	end
end

moving_cloud.Defaults = {
			min = -300,
			max = 300,
			minspeed = -3,
			maxspeed = 3,
}

return moving_cloud