local lume = require"util/lume"

local shopitems = {
	default = {},
}

function shopitems.default.GetShopItems()
	local shop_item_prefab_defs = require"defs/shopitem_prefabs"
	return lume.sort(lume.keys(shop_item_prefab_defs))
end

function shopitems.default.CustomInit(inst, opts)
	assert(opts)
	shopitems.ConfigureShopItem(inst, opts)
end

function shopitems.ConfigureShopItem(inst, opts)
	inst:AddComponent("interactable")
		:SetRadius(1.75)
		:SetupTargetIndicator("interact_pointer")

	inst:AddComponent("singlepickup")

	-- These have hitboxes so that they can do an 'attack' which clears out props / traps as they land.
	-- They cannot be attacked.
	-- TODO @chrisp #soleoccupant - The SoleOccupant component does something similar, perhaps less effectively as it 
	-- does not work for network MP. Consolidate.
	inst:AddComponent("combat")
	inst.entity:AddHitBox()
	inst:AddComponent("hitbox")
	inst.components.hitbox:SetHitGroup(HitGroup.NONE)
	inst.components.hitbox:SetHitFlags(HitGroup.NEUTRAL)

	if opts.item_type then
		local shop_item_prefab_defs = require "defs/shopitem_prefabs"
		local custom_init = shop_item_prefab_defs[opts.item_type]

		-- If shop items need to have custom initialization done, define it in the function in shopitems.lua

		if custom_init.fn then
			custom_init.fn(inst)
		end
	end
end

function shopitems.PropEdit(editor, ui, params)
	local args = params.script_args

	local all_shop_items = shopitems.default.GetShopItems()
	local no_selection = 1
	table.insert(all_shop_items, no_selection, "")

	if not args.item_type and table.find(all_shop_items, params.__displayName) then
		args.item_type = params.__displayName
	end

	local changed, item_type = ui:ComboAsString("Item Type", args.item_type, all_shop_items, true)
	if item_type ~= args.item_type then
		args.item_type = item_type
	end
end

return shopitems
