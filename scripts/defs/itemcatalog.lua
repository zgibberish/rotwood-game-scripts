local slotutil = require "defs.slotutil"

-- Catalog of all of our items. When dynamically looking up items, prefer to
-- get them from All so you don't need to handle different catalog types.
local itemcatalog = {
	All = {
		Items = {},
		Slots = {},
		SlotDescriptor = {},
	},
	Constructable = require "defs.constructable",
	Consumable = require "defs.consumable",
	Equipment = require "defs.equipment",
	Power = require "defs.powers",
	MetaProgress = require"defs.metaprogression",
	Mastery = require"defs.masteries",
	EquipmentGem = require "defs.equipmentgems",
}

for cat_name,cat in pairs(itemcatalog) do
	if cat_name ~= "All" then
		for key,val in pairs(cat.Slots) do
			assert(not itemcatalog.All.Slots[key], key)
			itemcatalog.All.Slots[key] = val
		end
		for key,val in pairs(cat.Items) do
			assert(not itemcatalog.All.Items[key], key)
			itemcatalog.All.Items[key] = val
		end
		for key,val in pairs(cat.SlotDescriptor) do
			assert(not itemcatalog.All.SlotDescriptor[key], key)
			itemcatalog.All.SlotDescriptor[key] = val
		end
	end
end


local rarity_icons = {
	[ITEM_RARITY.s.COMMON] = "images/ui_ftf_shop/inventory_slot_common.tex",
	[ITEM_RARITY.s.UNCOMMON] = "images/ui_ftf_shop/inventory_slot_uncommon.tex",
	[ITEM_RARITY.s.RARE] = "images/ui_ftf_shop/inventory_slot_rare.tex",
	[ITEM_RARITY.s.EPIC] = "images/ui_ftf_shop/inventory_slot_epic.tex",
	[ITEM_RARITY.s.LEGENDARY] = "images/ui_ftf_shop/inventory_slot_legendary.tex",
	[ITEM_RARITY.s.TITAN] = "images/ui_ftf_shop/inventory_slot_titan.tex",
	[ITEM_RARITY.s.SET] = "images/ui_ftf_shop/inventory_slot_set.tex",
}
function itemcatalog.GetRarityIcon(rarity)
	return rarity_icons[rarity] or "images/ui_ftf_shop/inventory_slot_common.tex"
end

--~ local inspect = require "inspect"
--~ print("all_items =", inspect(itemcatalog.All.Items, { depth = 3, }))

slotutil.ValidateSlotStrings(itemcatalog.All)

return itemcatalog
