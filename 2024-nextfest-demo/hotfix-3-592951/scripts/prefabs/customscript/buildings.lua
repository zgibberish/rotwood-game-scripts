---------------------------------------------------------------------------------------
--Custom script for auto-generated prop prefabs
---------------------------------------------------------------------------------------
local lume = require "util.lume"

local buildings = {
	default = {},
	forge = {},
	test_building = {},
	plot = {}
}

local spawn_offsets = {
	apothecary            = { 0.6, -3 },
	armorer               = { 0.6, -3 },
	armorer_1             = { 1, -2 },
	chemist               = { 0.6, -3 },
	chemist_1             = { 1, -2 },
	forge                 = { 0.6, -3 },
	forge_1               = { -1, -2 },
	kitchen_1             = { -1, -2 },
	kitchen               = { -1, -2 },
	power_upgrader        = { -1, -2 },
	scout_tent            = { -0.6, -3 },
	scout_tent_1          = { -3.5, -3 },
	specialevent_host     = { -1, -2 },
	traveling_potion_shop = { -1, -2 },
	refinery 			  = { -1, -2 },
	refinery_1 			  = { -1, -2 },
	marketroom_shop 	  = { 0.6, -2 },
	dojo_1 	 			  = { 1.5, -2  },

	test_building         = { 0.6, -3},
}

-- These buildings are *always* occupied by npcs (wanderers).
local spawn_default_npcs = {
	power_upgrader = "npc_konjurist",
	kitchen_1 = "npc_cook",
	kitchen = "npc_cook",
	specialevent_host = "npc_specialeventhost",
	scout_tent_1 = "npc_scout",
	traveling_potion_shop = "npc_potionmaker_dungeon",
	refinery_1 = "npc_refiner",
	armorer_1 = "npc_armorsmith",
	forge_1 = "npc_blacksmith",
	chemist_1 = "npc_apothecary",
	marketroom_shop = "npc_market_merchant",
	dojo_1 = "npc_dojo_master",
}

local function TryAddNpcHome(inst, prefab)
	local offset = spawn_offsets[prefab]
	if offset then
		inst:AddComponent("npchome")
		inst.components.npchome:SetSpawnXZOffset(table.unpack(offset))
	end

	local npc = spawn_default_npcs[prefab]
	if not TheInput:IsEditMode() and npc then
		assert(offset, "Missing offset for where to spawn the npc: ".. prefab)
		inst.OnPostLoadWorld = function(_, data)
			-- Fake load our default npc.
			if not inst.components.npchome:HasNpcByName(npc) then
				inst.components.npchome:OnLoad({
						npcs =
						{
							{
								name = npc,
							}
						},
					})
			end
		end
	end
end

function buildings.default.CollectPrefabs(prefabs, args)
	assert(args.prefab)
	local npc = spawn_default_npcs[args.prefab]
	if npc then
		table.insert(prefabs, npc)
	end
end

function buildings.default.CustomInit(inst, opts)
	assert(opts.prefab)
	TryAddNpcHome(inst, opts.prefab)

	if opts.skins and opts.skins.groups and opts.skins.sets and
		#opts.skins.groups > 0 and #opts.skins.sets > 0 then

		local symbol_groups = {}
		for _, group in ipairs(opts.skins.groups) do
			symbol_groups[group.name] = group.symbols
		end

		inst:AddComponent("buildingskinner")
		inst.components.buildingskinner:SetSkinSymbolGroups(symbol_groups)
		inst.components.buildingskinner:SetSkinSets(opts.skins.sets)
	end

	if opts.upgrades then
		if opts.upgrades.has_upgrade then
			inst:AddComponent("buildingupgrader")
			inst.components.buildingupgrader:SetUpgrade(opts.upgrades.prefab, opts.upgrades.prefab .. "_placer")
		end
	end
end

function buildings.forge.CollectPrefabs(prefabs, args)
	buildings.default.CollectPrefabs(prefabs, args)
end

function buildings.forge.CustomInit(inst, opts)
	buildings.default.CustomInit(inst, opts)

	local layer4 = inst.highlightchildren[3]
	local particles = SpawnPrefab("embers_chimney", inst)
	particles.entity:SetParent(layer4.entity)
	particles.entity:AddFollower()
	particles.Follower:FollowSymbol(layer4.GUID, "swap_fx")
end

function buildings.plot.CollectPrefabs(prefabs, args)
	buildings.default.CollectPrefabs(prefabs, args)
end

function buildings.plot.CustomInit(inst, opts)
	buildings.default.CustomInit(inst, opts)
	inst:AddComponent("plot")
end

-- function buildings.forge_1.CustomInit(inst, opts)
-- 	TryAddNpcHome(inst, "forge_1")
-- 	inst:AddComponent("buildingupgrader")
-- 	inst.components.buildingupgrader:SetUpgrade("forge", "forge_placer")
-- end

function buildings.test_building.CustomInit(inst, opts)
	inst:AddComponent("buildingskinner")
	inst.components.buildingskinner:SetSkinSymbolGroups({ front = {"anvil", "fence"}, middle = {"decor", "forge01", "brick"}, back = {"shelf"}})
	inst.components.buildingskinner:SetSkinSets({"bone", "cottage", "witch"})
	inst:DoTaskInTime(1, function()
		local BuildingSkinScreen = require "screens.town.buildingskinscreen"
		TheFrontEnd:PushScreen(BuildingSkinScreen(inst, GetDebugPlayer()))
	end)
end

function buildings.PropEdit(editor, ui, params)
	-- Dany wants to add sound to all buildings.
	params.sound = true

	local args = params.script_args or {}

	if args.skins == nil then
		args.skins = { sets = {}, symbols = {} }
	else
		if args.skins.sets == nil then
			args.skins.sets = {}
		end

		if args.skins.groups == nil then
			args.skins.groups = {}
		end
	end

	if args.upgrades == nil then
		args.upgrades = {}
	end

	if ui:TreeNode("Upgradeable##skins") then
		local has_upgrade = args.upgrades.has_upgrade ~= nil or false
		local changed, new_has_upgrade = ui:Checkbox("Upgradeable", has_upgrade)
		if changed then
			args.upgrades.has_upgrade = new_has_upgrade
		end

		if new_has_upgrade then
			local changed, newvalue = ui:InputText("Upgrade Prefab", args.upgrades.prefab or "", imgui.InputTextFlags.CharsNoBlank)
			if changed then
				args.upgrades.prefab = newvalue
			end
		end

		editor:AddTreeNodeEnder(ui)
	end

	if ui:TreeNode("Sets##skins") then
		for i, set in ipairs(args.skins.sets) do
			ui:Columns(2, nil, false)
			local changed, newvalue = ui:InputText("Set " .. tostring(i) .. "##skins", args.skins.sets[i] or "", imgui.InputTextFlags.CharsNoBlank)
			if changed then
				args.skins.sets[i] = newvalue
			end

			ui:NextColumn()
			if ui:Button(ui.icon.remove .. "##removeset"..tostring(i)) then
				table.remove(args.skins.sets, i)
			end

			ui:Columns()
		end

		if ui:Button("Add Set##skins") then
			table.insert(args.skins.sets, "")
		end

		editor:AddTreeNodeEnder(ui)
	end

	-- symbol_groups = { groupA = {"symbol1", "symbol2"}, groupB = {"symbol3"}, etc.. }
	--TODO: Clear the id stuff
	if ui:TreeNode("Symbol Groupings##skins") then
		for i, group in ipairs(args.skins.groups) do
			local group_index_id = tostring(i)


			ui:Columns(2, nil, false)
			local changed, newvalue = ui:InputText("Group "..group_index_id.."##skins"..group_index_id, group.name or "", imgui.InputTextFlags.CharsNoBlank)
			if changed then
				group.name = newvalue
			end

			ui:NextColumn()
			if ui:Button(ui.icon.remove .. "##removegroup"..group_index_id) then
				table.remove(args.skins.groups, i)
				break
			end

			ui:Columns()

			for k, symbol in ipairs(args.skins.groups[i].symbols) do
				ui:Columns(2, nil, false)

				local symbol_index_id = tostring(k)
				local unique_id = group_index_id .. symbol_index_id

				ui:Indent()
					local changed, newvalue = ui:InputText("Symbol "..symbol_index_id.."##skins"..unique_id, symbol or "", imgui.InputTextFlags.CharsNoBlank)
					if changed then
						args.skins.groups[i].symbols[k] = newvalue
					end

					ui:NextColumn()

					if ui:Button(ui.icon.remove .. "##removesymbol"..unique_id) then
						table.remove(args.skins.groups[i].symbols, k)
						break
					end
				ui:Unindent()

				ui:Columns()
			end

			if ui:Button("Add Symbol##skins" .. group_index_id) then
				table.insert(args.skins.groups[i].symbols, "")
			end

		end

		if ui:Button("Add Group##skins") then
			table.insert(args.skins.groups, {name = "", symbols = {}})
		end

		editor:AddTreeNodeEnder(ui)
	end

	if editor.testprop and editor.testprop.components.buildingskinner then
		if ui:TreeNode("Skin Preview", ui.TreeNodeFlags.DefaultOpen) then

			if #args.skins.sets then
				-- Adding default manually here
				local _sets = lume.clone(args.skins.sets)
				table.insert(_sets, 1, "default")

				for i, group in ipairs(args.skins.groups) do
					local current_set = editor.testprop.components.buildingskinner:GetCurrentSet(group.name)
					local current_index = lume.find (_sets, current_set)

					if current_index ~= nil then
						ui:Value(group.name, current_set)
						local changed, new_value = ui:SliderInt("Set##skinpreview" .. tostring(i), current_index, 1, #_sets)

						if changed then
							if new_value == 1 then
								editor.testprop.components.buildingskinner:ResetSymbolSkin(group.name)
							else
								local new_set = _sets[new_value]
								editor.testprop.components.buildingskinner:SetSymbolSkin(group.name, new_set)
							end

						end
					end
				end
			end

			editor:AddTreeNodeEnder(ui)
		end
	end

	if next(args) then
		params.script_args = args
	else
		params.script_args = nil
	end

end

return buildings
