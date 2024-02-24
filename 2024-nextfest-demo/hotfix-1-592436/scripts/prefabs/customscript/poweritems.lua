-- Extra editing logic for poweritem prefabs.
--
-- Here we do extra setup after the prefab spawns which is mostly configuring
-- the poweritem component.

local Power = require 'defs.powers'
local lume = require "util.lume"
require "util.tableutil"

local poweritems = {
	default = {},
}

local function OnInteract( inst, player, opts )
	local GemScreen = require "screens.town.gemscreen"
	TheFrontEnd:PushScreen(GemScreen(player))
	player.sg:GoToState('idle_accept')
end

function poweritems.default.GetPowerTypes()
	local types = {}
	for _, type in pairs(Power.Types) do
		table.insert(types, type)
	end
	table.sort(types)
	return types
end

function poweritems.default.GetPowerCategories()
	local categories = {}
	for _, category in pairs(Power.Categories) do
		table.insert(categories, category)
	end
	table.sort(categories)
	return categories
end

function poweritems.default.GetPowerFamilies()
	local families = {}
	for _, slot in pairs(Power.Slots) do
		table.insert(families, slot)
	end
	table.sort(families)
	return families
end

local function OnEditorSpawn(inst, editor)
	-- if inst.components.powerdrop then
	-- 	inst.components.powerdrop:PrepareToShowGem({
	-- 			appear_delay_ticks = TUNING.POWERS.DROP_SPAWN_INITIAL_DELAY_FRAMES,
	-- 		})
	-- else
	-- 	-- Not a proper flow, but trying to set it up enough to see the power drop.
	-- 	poweritems.ConfigurePowerDrop(inst, {
	-- 			power_type = Power.Types.FABLED_RELIC,
	-- 		})
	-- 	OnPrepareToShowGem(inst)
	-- end
end

function poweritems.default.CustomInit(inst, opts)
	assert(opts)
	poweritems.ConfigurePowerDrop(inst, opts)
	inst.OnEditorSpawn = OnEditorSpawn
end

local function _on_drop_spawn_fn(player, drop)
	-- drop:AddTag("powerdrop")
end

function poweritems.ConfigurePowerDrop(inst, opts)
	inst:AddComponent("interactable")

	inst:AddComponent("poweritem")
	inst.components.poweritem:ConfigureInteraction()
	inst.components.poweritem:AllowInteraction()
	-- inst.components.interactable:SetRadius(3.5)
	-- 	:SetInteractStateName("powerup_interact")
	-- 	:SetInteractConditionFn(function(_, player, is_focused) return true end)
	-- 	:SetOnInteractFn(function(_, player) OnInteract(inst, player, opts) end)
	-- 	:SetupForButtonPrompt("<p bind='Controls.Digital.ACTION' color=0> Manage Gems") -- TODO: move to string table for localization

end

function poweritems.PropEdit(editor, ui, params)
	-- local args = params.script_args

	-- local all_power_types = poweritems.default.GetPowerTypes()
	-- local no_selection = 1
	-- table.insert(all_power_types, no_selection, "")

	-- local changed
	-- changed, args.power_type = ui:ComboAsString("Power Type", args.power_type, all_power_types, true)

	-- if args.power_type then
	-- 	-- No longer makes sense to include category since powerdrop appearance
	-- 	-- is now directly tied to family instead.
	-- 	--~ local all_power_categories = poweritems.default.GetPowerCategories()
	-- 	--~ table.insert(all_power_categories, no_selection, "")
	-- 	--~ changed, args.power_category = ui:ComboAsString("Power Category", args.power_category, all_power_categories, true)

	-- 	local all_power_families = poweritems.default.GetPowerFamilies()
	-- 	table.insert(all_power_families, no_selection, "")
	-- 	changed, args.power_family = ui:ComboAsString("Power Family", args.power_family, all_power_families, true)
	-- end

	-- if params.parallax then
	-- 	if params.parallax_use_baseanim_for_idle then
	-- 		editor:WarningMsg(ui, "!!! Warning !!!", "Drops using parallax should be setup with idle animations. Each parallax item should have a name used as a suffix to their animations. So you might have 'spike1', 'spike2' in the parallax list and 'idle_spike1', 'idle_spike2' in the flash file.")
	-- 	end
	-- 	local main_layer = lume.match(params.parallax, function(layerparams)
	-- 		return layerparams.dist == nil or layerparams.dist == 0
	-- 	end)
	-- 	if not main_layer then
	-- 		editor:WarningMsg(ui, "!!! Warning !!!", "Drops using parallax need one parallax layer at dist 0 so it can act as the main anim that drives the stategraph. Otherwise we never receive animover and animations loop infinitely.")
	-- 	end
	-- end
end

return poweritems
