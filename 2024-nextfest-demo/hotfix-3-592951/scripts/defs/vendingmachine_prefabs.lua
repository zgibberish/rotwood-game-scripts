local BORDERS_BUILD = "images/shop_anim_icon_borders.xml"

-- TODO @chrisp #vending - copy/paste from global.lua...should be centralized somewhere
local ICON_FRAME_SIZE = 240

local vendingmachines =
{
	dye_bottle_shop =
	{
		custom_init_fn = function(inst)
			inst:AddComponent("networkedsymbolswapper")
			inst.components.networkedsymbolswapper:SetSymbolSlots{
				["HEAD"] = {"icon_armor_head"},
				["BODY"] = {"icon_armor_body"},
				["WAIST"] = {"icon_armor_waist"},
			}
		end,
		collect_assets_fn = function(assets) table.appendarrays(assets, {}) end,
		collect_prefabs_fn = function(prefabs) table.appendarrays(prefabs, {}) end,
	},

	meta_item_shop =
	{
		custom_init_fn = function(inst)
			inst:AddComponent("inventory")
			inst.AnimState:SetSymbolFG("weapon_back01", true)
		end,

		collect_assets_fn = function(assets) table.appendarrays(assets, {}) end,
		collect_prefabs_fn = function(prefabs) table.appendarrays(prefabs, {}) end,
	},

	run_item_shop =
	{
		BORDERS_BUILD = BORDERS_BUILD,
		custom_init_fn = function(inst)
			inst:AddComponent("warevisualizer")
			inst:SetStateGraph("sg_vending_machine")
			inst.components.interactable:SetRadius(2.5)
		end,
		collect_assets_fn = function(assets)
			-- TODO @chrisp #vend - collect these from WareVisualizer?
			table.appendarrays(assets, {
				Asset("ATLAS", BORDERS_BUILD),
				Asset("IMAGE", "images/shop_anim_icon_borders.tex"),
				Asset("ATLAS_BUILD", BORDERS_BUILD, ICON_FRAME_SIZE, 0, -0.8),
				Asset("ANIM", "anim/drops_currency.zip"),
				Asset("ANIM", "anim/drops_potion.zip"),
			})
		end,
		collect_prefabs_fn = function(prefabs) table.appendarrays(prefabs, {}) end,
	},

	healing_fountain =
	{
		custom_init_fn = function(inst)
			inst:AddComponent("healingfountain")
			inst:SetStateGraph("sg_healing_fountain")
			local initialize_healing_fountain = function()
				local healing_fountain = inst.components.vendingmachine
				healing_fountain:Initialize("healing_fountain", "", "")
				healing_fountain:InitializeUi()
			end
			if TheDungeon.HUD then
				initialize_healing_fountain()
			else
				inst:ListenForEvent("on_hud_created", initialize_healing_fountain, TheDungeon)
			end
		end,
		collect_assets_fn = function(assets)
		end,
		collect_prefabs_fn = function(prefabs) table.appendarrays(prefabs, {}) end,
	},
}

return vendingmachines
