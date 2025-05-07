-- Extra editing logic for powerdrop prefabs.
--
-- Here we do extra setup after the prefab spawns which is mostly configuring
-- the powerdrop component.

local Power = require 'defs.powers'
local lume = require "util.lume"
require "util.tableutil"

local powerdrops = {
	default = {},
}

function powerdrops.default.GetPowerTypes()
	local types = {}
	for _, type in pairs(Power.Types) do
		table.insert(types, type)
	end
	table.sort(types)
	return types
end

function powerdrops.default.GetPowerCategories()
	local categories = {}
	for _, category in pairs(Power.Categories) do
		table.insert(categories, category)
	end
	table.sort(categories)
	return categories
end

function powerdrops.default.GetPowerFamilies()
	local families = {}
	for _, slot in pairs(Power.Slots) do
		table.insert(families, slot)
	end
	table.sort(families)
	return families
end

local function OnPrepareToShowGem(inst)
	inst.sg:GoToState("spawn_pre")
end

local function OnEditorSpawn(inst, editor)
	if inst.components.powerdrop then
		inst.components.powerdrop:PrepareToShowGem({
				appear_delay_ticks = TUNING.POWERS.DROP_SPAWN_INITIAL_DELAY_FRAMES,
			})
	else
		-- Not a proper flow, but trying to set it up enough to see the power drop.
		powerdrops.ConfigurePowerDrop(inst, {
				power_type = Power.Types.FABLED_RELIC,
			})
		OnPrepareToShowGem(inst)
	end
end

function powerdrops.default.CustomInit(inst, opts)
	assert(opts)
	inst:SetStateGraph("sg_rotating_drop")
	local is_subdrop = opts.power_type == Power.Types.RELIC or opts.power_type == Power.Types.SKILL
	if not is_subdrop then
		powerdrops.ConfigurePowerDrop(inst, opts)
	end
	inst.OnEditorSpawn = OnEditorSpawn
end

local function _on_drop_spawn_fn(player, drop)
	drop:AddTag("powerdrop")
end

function powerdrops.ConfigurePowerDrop(inst, opts)
	-- If looking for powerdrop component (from sg), it's on core_powerdrop. If
	-- it has subdrops (e.g., player powers), it may not have a stategraph but
	-- it coordinates powerdrop behaviour. The subdrops will have
	-- core_powerdrop to find the entity with a powerdrop component.
	inst.core_drop = inst

	if opts.power_type then
		inst:AddComponent("cineactor")
		inst:AddComponent("interactable")

		inst:AddComponent("rotatingdrop")
		inst.components.rotatingdrop:SetOnDropSpawnFn(_on_drop_spawn_fn)

		if opts.build_drops_fn == nil then
			local build_drops_fn = function()
				local drops = {}
				drops[1] = inst.prefab
				return drops
			end
			inst.components.rotatingdrop:SetBuildDropsFn(build_drops_fn)
		else
			inst.components.rotatingdrop:SetBuildDropsFn(opts.build_drops_fn)
		end

		inst:AddComponent("powerdrop")

		inst.components.powerdrop:SetOnPrepareToShowGem(function()
			inst.components.rotatingdrop:PrepareToShowDrops()
		end)

		inst:ListenForEvent("selected_power", function()
			inst.components.rotatingdrop:ConsumeAllDrops()
		end)

		if opts.interact_radius then
			inst.components.powerdrop.interact_radius = opts.interact_radius
		end

		inst.components.powerdrop:SetPowerType(opts.power_type)
		inst.components.powerdrop:SetPowerCategory(opts.power_category)
		inst.components.powerdrop:ConfigureInteraction()
	end
end

function powerdrops.PropEdit(editor, ui, params)
	local args = params.script_args

	local all_power_types = powerdrops.default.GetPowerTypes()
	local no_selection = 1
	table.insert(all_power_types, no_selection, "")

	local changed
	changed, args.power_type = ui:ComboAsString("Power Type", args.power_type, all_power_types, true)

	if args.power_type then
		-- No longer makes sense to include category since powerdrop appearance
		-- is now directly tied to family instead.
		--~ local all_power_categories = powerdrops.default.GetPowerCategories()
		--~ table.insert(all_power_categories, no_selection, "")
		--~ changed, args.power_category = ui:ComboAsString("Power Category", args.power_category, all_power_categories, true)

		local all_power_families = powerdrops.default.GetPowerFamilies()
		table.insert(all_power_families, no_selection, "")
		changed, args.power_family = ui:ComboAsString("Power Family", args.power_family, all_power_families, true)
	end

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

return powerdrops
