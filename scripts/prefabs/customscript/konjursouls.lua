local Consumable = require 'defs.consumable'
local lume = require "util.lume"
local kstring = require "util.kstring"
require "util.tableutil"

local konjursouls = {
	default = {},
}

function konjursouls.default.GetKonjurSouls()
	local defs = Consumable.GetItemList(Consumable.Slots.MATERIALS, { 'crafting_resource', 'currency' })
	local souls = {}
	for _, def in ipairs(defs) do
		table.insert(souls, def.name)
	end
	return souls
end

function konjursouls.default.CustomInit(inst, opts)
	assert(opts)
	inst:SetStateGraph("sg_rotating_drop")
	konjursouls.ConfigureKonjurSoul(inst, opts)
	-- soul_drops.lua sets up OnEditorSpawn.
end

local function GetLoot(inst, player, opts)
	local item = Consumable.FindItem(opts.soul_type)
	player:PushEvent("get_loot", { item = item, count = 1 })
end

function konjursouls.ConfigureKonjurSoul(inst, opts)
	-- If looking for souldrop component (from sg), it's on core_drop. If
	-- it has subdrops (e.g., player powers), it may not have a stategraph but
	-- it coordinates souldrop behaviour. The subdrops will have
	-- core_drop to find the entity with a souldrop component.

	inst.core_drop = inst

	if opts.soul_type then
		inst.soul_type = opts.soul_type
				
		inst:ListenForEvent("consume_drop", function(_, player)
			GetLoot(inst, player, opts)
		end)

		if opts.drop_prefabs then 
			inst:AddComponent("cineactor")
			inst:AddComponent("interactable")

			inst:AddComponent("rotatingdrop")
			inst.components.rotatingdrop:SetBuildDropsFn(opts.build_drops_fn)

			inst:AddComponent("souldrop")
			inst.components.souldrop:SetOnPrepareToShowGem(function()
				inst.components.rotatingdrop:PrepareToShowDrops()
			end)


			inst:ListenForEvent("took_drop", function(_, player)
				inst.components.rotatingdrop:ConsumeDrop(player)
				if inst.components.rotatingdrop:GetDropCount() == 0 then
					inst.components.souldrop:OnFullyConsumed()
				end
			end)

			if opts.interact_radius then
				inst.components.souldrop.interact_radius = opts.interact_radius
			end

			inst.components.souldrop:ConfigureInteraction()
		end
	end
end

function konjursouls.PropEdit(editor, ui, params)
	local args = params.script_args

	local all_soul_types = konjursouls.default.GetKonjurSouls()
	local no_selection = 1
	table.insert(all_soul_types, no_selection, "")

	local changed
	changed, args.soul_type = ui:ComboAsString("Soul Type", args.soul_type, all_soul_types, true)

	if params.parallax then
		if params.parallax_use_baseanim_for_idle then
			editor:WarningMsg(ui, "!!! Warning !!!", "Drops using parallax should be setup with idle animations. Each parallax item should have a name used as a suffix to their animations. So you might have 'spike1', 'spike2' in the parallax list and 'idle_spike1', 'idle_spike2' in the flash file.")
		end
		local main_layer = lume.match(params.parallax, function(layerparams)
			return layerparams.dist == nil or layerparams.dist == 0
		end)
		if not main_layer then
			editor:WarningMsg(ui, "!!! Warning !!!", "Drops using parallax need one parallax layer at dist 0 so it can act as the main anim that drives the stategraph. Otherwise we never receive animover and animations loop infinitely.")
		end
	end
end

return konjursouls
