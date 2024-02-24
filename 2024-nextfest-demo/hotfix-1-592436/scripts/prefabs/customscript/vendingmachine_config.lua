local vendingmachine_prefab_defs = require"defs/vendingmachine_prefabs"

local lume = require"util/lume"

local vendingmachines = {
	default = {},
}

function vendingmachines.default.GetVendingMachines()
	return lume.sort(lume.keys(vendingmachine_prefab_defs))
end

function vendingmachines.default.CustomInit(inst, opts)
	assert(opts)
	vendingmachines.ConfigureShopItem(inst, opts)
end

function vendingmachines.default.CollectAssets(assets, script_args)
	if script_args.machine_type then
		vendingmachine_prefab_defs[script_args.machine_type].collect_assets_fn(assets)
	end
end

function vendingmachines.default.CollectPrefabs(prefabs, script_args)
	if script_args.machine_type then
		vendingmachine_prefab_defs[script_args.machine_type].collect_prefabs_fn(prefabs)
	end
end

function vendingmachines.ConfigureShopItem(inst, opts)
	inst:AddComponent("interactable")
		:SetRadius(3)
		:SetupTargetIndicator("interact_pointer")

	inst:AddComponent("vendingmachine")
	inst:AddComponent("soundtracker")

	if opts.machine_type then
		-- If vending machines need to have custom components, stategraphs, etc. done, define it in the function in vendingmachines.lua
		vendingmachine_prefab_defs[opts.machine_type].custom_init_fn(inst)
	end
end

function vendingmachines.PropEdit(editor, ui, params)
	local args = params.script_args

	local all_shop_items = vendingmachines.default.GetVendingMachines()
	local no_selection = 1
	table.insert(all_shop_items, no_selection, "")

	if not args.machine_type and table.find(all_shop_items, params.__displayName) then
		args.machine_type = params.__displayName
	end

	local changed, machine_type = ui:ComboAsString("Item Type", args.machine_type, all_shop_items, true) 
	if machine_type ~= args.machine_type then
		args.machine_type = machine_type
	end
end

return vendingmachines
