---------------------------------------------------------------------------------------
--Custom script for auto-generated prop prefabs
---------------------------------------------------------------------------------------
local lume = require "util.lume"

local plots = {
	default = {},
}

local function CollectPlotFlags()
	local flags = require "gen/flagslist"
	local plot_flags = {""}
	
	for _, flag in ipairs(flags) do
		if string.find(flag, "town_has_") then
			table.insert(plot_flags, flag)
		end
	end

	return plot_flags
end

function plots.default.CustomInit(inst, opts)
	TheWorld.components.plotmanager:RegisterPlot(inst, opts.owner_prefab)
	
	inst:AddComponent("plot")
	inst.components.plot:SetBuildingPrefab(opts.building_prefab)
	inst.components.plot:SetSpawnFlag(opts.spawn_flag)
	inst.components.plot:SetNPCPrefab(opts.owner_prefab)
end

function plots.PropEdit(editor, ui, params)
	local args = params.script_args or {}

	local owner_prefab = args.owner_prefab or ""
	local changed, newvalue = ui:InputText("NPC Prefab", owner_prefab or "", imgui.InputTextFlags.CharsNoBlank)

	if changed then
		owner_prefab = newvalue
		args.owner_prefab = owner_prefab
	end

	local building_prefab = args.building_prefab or ""
	changed, newvalue = ui:InputText("Building Prefab", building_prefab or "", imgui.InputTextFlags.CharsNoBlank)

	if changed then
		building_prefab = newvalue
		args.building_prefab = building_prefab
	end


	local plot_flags = CollectPlotFlags()
	local spawn_flag = args.spawn_flag or ""
	local spawn_flag_idx = lume.find(plot_flags, spawn_flag)

	changed, newvalue = ui:Combo("Spawn Flag", spawn_flag_idx, plot_flags)

	if changed and newvalue ~= spawn_flag_idx then
		spawn_flag_idx = newvalue
		args.spawn_flag = plot_flags[spawn_flag_idx]
	end


	if next(args) then
		params.script_args = args
	else
		params.script_args = nil
	end
end

return plots