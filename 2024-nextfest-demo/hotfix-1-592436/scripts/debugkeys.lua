local DebugNodes = require "dbui.debug_nodes"
local DebugPanel = require "dbui.debug_panel"
local EditorBase = require "debug.inspectors.editorbase"
local ScriptLoader = require "questral.scriptloader"
local TextTest = require "screens.featuretests.texttest"
local WidgetTest = require "screens.featuretests.widgettest"
local kstring = require "util.kstring"
local lume = require "util.lume"
require "consolecommands"
require "util"


-- Import debug ui and inspectors so they add themselves to DebugNodes.
ScriptLoader:LoadAllScript("scripts/dbui")
ScriptLoader:LoadAllScript("scripts/debug/inspectors")


local function DebugKeyPlayer()
	return ConsoleCommandPlayer() or nil
end

local handlers = {}

-- DoDebugKey gets called by the frontend code if a rawkey event has not been
-- consumed by the current screen.
function DoDebugKey(key, down)
	if handlers[key] then
		for k,v in ipairs(handlers[key]) do
			if v(down) then
				return true
			end
		end
	end
end

-- Use this to register debug key handlers from within this file or customcommands.lua
function AddGameDebugKey(key, fn, down)
	assert(key, "Input key is unknown. See valid values in inputconstants.lua.")
	assert(fn, "Need a callback function.")
	-- default to requiring down
	down = down or down == nil
	handlers[key] = handlers[key] or {}
	table.insert( handlers[key], function(_down) if _down == down and InGamePlay() then return fn() end end)
end

function AddGlobalDebugKey(key, fn, down)
	assert(key, "Input key is unknown. See valid values in inputconstants.lua.")
	assert(fn, "Need a callback function.")
	down = down or down == nil
	handlers[key] = handlers[key] or {}
	table.insert( handlers[key], function(_down) if _down == down then return fn() end end)
end

function SimBreakPoint()
	if not TheSim:IsDebugPaused() then
		TheSim:ToggleDebugPause()
	end
end

-------------------------------------DEBUG KEYS

global("c_ent")
global("c_ang")

local userName = TheSim:GetUsersName()
--
-- Put your own username in here to enable "dprint"s to output to the log window
if CHEATS_ENABLED and userName == "My Username" then
	global("CHEATS_KEEP_SAVE")
	global("CHEATS_ENABLE_DPRINT")
	global("DPRINT_USERNAME")
	global("c_ps")

	DPRINT_USERNAME = "My Username"
	CHEATS_KEEP_SAVE = true
	CHEATS_ENABLE_DPRINT = true
end

local function HotkeyShowDebugPanel(nodeType, hotkey_pressed)
	-- Check if an instance of a node is already open. If so, close the panel
	-- if it was activated via hotkey, otherwise open a panel with the node.
	DebugNodes.ShowDebugPanel(nodeType, hotkey_pressed)
end

MENU_KEY_BINDINGS =
{
	{
		binding = { key = InputConstants.Keys.COMMA, CTRL = true },
		name = "Back",
		skip_palette = true,
		isEnabled = function()
			local panel = TheFrontEnd:GetSelectedDebugPanel()
			return panel and panel.idx > 1 or false
		end,
		fn = function()
			local panel = TheFrontEnd:GetSelectedDebugPanel()
			if panel and panel.idx > 1 then
				panel:GoBack()
			end
		end,
	},
	{
		binding = { key = InputConstants.Keys.PERIOD, CTRL = true },
		name = "Forward",
		skip_palette = true,
		isEnabled = function()
			local panel = TheFrontEnd:GetSelectedDebugPanel()
			return panel and panel.idx < #panel.nodes or false
		end,
		fn = function()
			local panel = TheFrontEnd:GetSelectedDebugPanel()
			if panel and panel.idx < #panel.nodes then
				panel:GoForward()
			end
		end,
	},
	{ separator = true },
	{
		binding = { key = InputConstants.Keys.ENTER, CTRL = true },
		name = "Maximize",
		skip_palette = true,
		isChecked = function()
			local panel = TheFrontEnd:GetSelectedDebugPanel()
			return panel and panel.is_maximized or false
		end,
		fn = function()
			local panel = TheFrontEnd:GetSelectedDebugPanel()
			if panel then
				panel.did_maximize = true
			end
		end,
	},
	{
		isSubMenu = true,
		name = "Maximize Mode",
		skip_palette = true,
		menuItems = (function()
			local t = {}
			for i,key in ipairs(DebugPanel.maximize.values) do
				local mode = DebugPanel.maximize.modes[key]
				table.insert(t, {
						name = kstring.first_to_upper(key),
						isChecked = function()
							local panel = TheFrontEnd:GetSelectedDebugPanel()
							return panel and panel.layout_options.current_maximize == mode
						end,
						fn = function()
							local panel = TheFrontEnd:GetSelectedDebugPanel()
							if panel then
								panel.layout_options:Set("current_maximize", mode)
								panel.layout_options:Save()
							end
						end,
					})
			end
			return t
		end)(),
	},
	{
		name = "Sticky",
		tooltip = "Sticky windows re-open after Ctrl-R or going between rooms.",
		skip_palette = true,
		isEnabled = function()
			local node = TheFrontEnd:GetFocusedDebugNode()
			return node and node:CanReopenNodeAfterReset()
		end,
		isChecked = function()
			local node = TheFrontEnd:GetFocusedDebugNode()
			return node and node:WillReopenNodeAfterReset()
		end,
		fn = function()
			local node = TheFrontEnd:GetFocusedDebugNode()
			return node and node:ToggleReopenNodeAfterReset()
		end,
	},
	{ separator = true },
	{
		isSubMenu = true,
		name = "Text Size",
		menuItems =
		{
			{
				binding = { key = InputConstants.Keys.NUM_1, CTRL = true },
				name = "75%",
				isChecked = function()
					return TheFrontEnd.imgui_font_size == 0.75
				end,
				fn = function()
					TheFrontEnd:SetImguiFontSize(0.75)
				end,
			},
			{
				binding = { key = InputConstants.Keys.NUM_2, CTRL = true },
				name = "100%",
				isChecked = function()
					return TheFrontEnd.imgui_font_size == 1
				end,
				fn = function()
					TheFrontEnd:SetImguiFontSize(1)
				end,
			},
			{
				binding = { key = InputConstants.Keys.NUM_3, CTRL = true },
				name = "150%",
				isChecked = function()
					return TheFrontEnd.imgui_font_size == 1.5
				end,
				fn = function()
					TheFrontEnd:SetImguiFontSize(1.5)
				end,
			},
			{
				binding = { key = InputConstants.Keys.NUM_4, CTRL = true },
				name = "200%",
				isChecked = function()
					return TheFrontEnd.imgui_font_size == 2
				end,
				fn = function()
					TheFrontEnd:SetImguiFontSize(2)
				end,
			},
		},
	},
	{ separator = true },
	{
		name = "View World",
		skip_palette = true,
		isEnabled = function()
			return TheWorld
		end,
		fn = function()
			local panel = TheFrontEnd:GetSelectedDebugPanel()
			panel:PushNode( DebugNodes.DebugTable( TheWorld ) )
		end,
	},
	{
		name = "View This Panel",
		skip_palette = true,
		fn = function()
			local panel = TheFrontEnd:GetSelectedDebugPanel()
			panel:PushNode( DebugNodes.DebugTable( panel ) )
		end,
	},
	{
		name = "View This Debug Node",
		skip_palette = true,
		fn = function()
			local panel = TheFrontEnd:GetSelectedDebugPanel()
			panel:PushNode( DebugNodes.DebugTable( panel:GetNode() ) )
		end,
	},
	{ separator = true },
	{
		binding = { key = InputConstants.Keys.W, CTRL = true },
		name = "Close",
		skip_palette = true,
		fn = function()
			local panel = TheFrontEnd:GetSelectedDebugPanel()
			if panel and panel.show then
				panel.show = false
			end
		end,
	},
}

local function CreateBiomeLocationLauncher(fn)
	local function launch_fn(params)
		return fn(params.name)
	end

	local biomes = require "defs.biomes"
	local run_list = {}
	for id, def in pairs(biomes.locations) do
		if def.type == biomes.location_type.DUNGEON then
			run_list[id] = launch_fn
		end
	end
	TheFrontEnd.debugMenu.quickfind:OpenListOfCommands(run_list)
end

GLOBAL_KEY_BINDINGS = -- Labelled "Actions" in imgui.
{
	{
		binding = { key = InputConstants.Keys.P, CTRL = true},
		name = "Command Palette",
		fn = function(params)
			-- Gobbles all input, so it can't be toggled with the same key.
			local menus = table.appendarrays(
				{},
				MENU_KEY_BINDINGS,
				GLOBAL_KEY_BINDINGS,
				PROGRAMMER_KEY_BINDINGS,
				WINDOW_KEY_BINDINGS,
				EDITOR_KEY_BINDINGS,
				HELP_KEY_BINDINGS)
			TheFrontEnd.debugMenu.quickfind:OpenCommandPalette(menus)
		end,
	},
	{
		name = "Quick Spawn",
		isSubMenu = true,
		menuItems = (function()
			local t = {}
			local fns = {
				c_spawn = c_spawn,
				c_spawndumb = c_spawndumb,
				c_spawnstage = c_spawnstage,
				d_estimate_distance = d_estimate_distance,
			}
			for fn_name,fn in pairs(fns) do
				table.insert(t, {
						name = fn_name,
						fn = function()
							local function spawn(params)
								local prefab = params.name
								AppendConsoleHistoryItem(("%s'%s'"):format(fn_name, prefab))
								return fn(prefab)
							end
							local spawnlist = {}
							for _,prefab in ipairs(EditorBase.GetAllPrefabNames()) do
								spawnlist[prefab] = spawn
							end
							TheFrontEnd.debugMenu.quickfind:OpenListOfCommands(spawnlist)
						end,
					})
			end
			return t
		end)(),
	},
	{
		name = "Open Save Game Folder",
		fn = function()
			TheSim:OpenGameSaveFolder()
		end,
	},
	{
		binding = { key = InputConstants.Keys.R },
		name = "Repeat Last Console Command",
		fn = function()
			c_repeatlastcommand()
		end,
	},
	{
		binding = { key = InputConstants.Keys.R, CTRL = true },
		name = "Reload Scene",
		fn = function()
			c_reset()
		end,
		tooltip = "Reloads changes to lua files"
	},
	{
		binding = { key = InputConstants.Keys.HOME },
		name = "Pause / Step Game",
		fn = function()
			if not TheSim:IsDebugPaused() then
				print("Home key pressed PAUSING GAME")
				TheSim:ToggleDebugPause()
			else
				print("Home key pressed STEPPING")
				TheSim:Step()
			end
		end,
	},
	{
		binding = { key = InputConstants.Keys.HOME, CTRL = true },
		name = "Toggle Pause Game",
		fn = function()
			print("Home key pressed TOGGLING")
			TheSim:ToggleDebugPause()
		end,
	},
	{
		binding = { key = InputConstants.Keys.M, CTRL = true },
		name = "Toggle mute",
		fn = c_mute,
	},
	{
		--binding = { key = InputConstants.Keys.G },
		name = function()
			local on_off = TheFrontEnd.debugMenu.history:IsEnabled() and "OFF" or "ON"
			return "Turn "..on_off.." History Recording"
		end,
		fn = function()
			TheFrontEnd.debugMenu.history:ToggleHistoryRecording()
		end
	},
	{
		binding = { key = InputConstants.Keys.F1 },
		name = "Select Entity under mouse",
		fn = function()
			c_selectany_cycle()
		end,
	},
	{
		binding = { key = InputConstants.Keys.Q, CTRL = true },
		name = "Toggle IMGUI",
		fn = function()
			TheFrontEnd:ToggleImgui()
		end,
	},
	{
		binding = { key = InputConstants.Keys.F4 },
		name = "Toggle Camera Limits",
		fn = function()
			if TheWorld ~= nil and TheWorld.components.cameralimits ~= nil then
				TheWorld.components.cameralimits:SetEnabled(not TheWorld.components.cameralimits:IsEnabled())
			end
		end,
	},
	{
		name = "Lighting",
		isSubMenu = true,
		menuItems = (function()
			return {
				{
					name = "World Lighting",
					isIntSlider = true,
					intMin = 0,
					intMax = 100,
					initalVal = function()
						return 100
					end,
					cb = function(newval)
						local lightcoordinator = TheWorld.components.lightcoordinator
						lightcoordinator:SetIntensity(newval / 100)
					end,
				},
				{
					name = "Player Lighting Override",
					isIntSlider = true,
					intMin = 0,
					intMax = 100,
					initalVal = function()
						return 0
					end,
					cb = function(newval)
						local intensity = newval / 100
						for _,inst in ipairs(AllPlayers) do
							inst.AnimState:SetLightOverride(intensity)
						end
					end,
				},
			}
		end)()
	},
	{
		binding = { key = InputConstants.Keys.F3, SHIFT = true  },
		name = "Dump inputs",
		fn = function()
			c_inputdump()
		end,
	},
	{
		name = "Load Level",
		isSubMenu = true,
		menuItems = (function()
			local t = {}
			local plan = {
				[d_loadroom] = {
					test_empty_room = "Completely Empty Room",
				},
				[d_loadempty] = {
					test_training_room = "Training Room",
					startingforest_arena_nesw = "Empty Combat Room",
					startingforest_small_nesw = "Empty Interaction Room",
				}
			}
			for load_fn,rooms in pairs(plan) do
				for k,v in pairs(rooms) do
					table.insert(t, {
							name = v,
							isEnabled = DebugNodes.EditableEditor.IsLevelPristine,
							fn = function()
								load_fn(k)
							end
						})
				end
			end
			return t
		end)()
	},
	{
		name = "Start Playing",
		isSubMenu = true,
		menuItems = (function()
			local t = {
				{
					name = "Start Run",
					isEnabled = DebugNodes.EditableEditor.IsLevelPristine,
					fn = function()
						return CreateBiomeLocationLauncher(d_startrun)
					end,
				},
				{
					name = "Start Daily Run",
					isEnabled = DebugNodes.EditableEditor.IsLevelPristine,
					fn = function()
						return CreateBiomeLocationLauncher(d_startdailyrun)
					end,
				},
				{
					name = "Start Miniboss",
					isEnabled = DebugNodes.EditableEditor.IsLevelPristine,
					fn = function()
						return CreateBiomeLocationLauncher(d_startminiboss)
					end,
				},
				{
					name = "Start Hype Room",
					isEnabled = DebugNodes.EditableEditor.IsLevelPristine,
					fn = function()
						return CreateBiomeLocationLauncher(d_starthype)
					end,
				},
				{
					name = "Start Boss",
					isEnabled = DebugNodes.EditableEditor.IsLevelPristine,
					fn = function()
						return CreateBiomeLocationLauncher(d_startboss)
					end,
				},
				{
					name = "Start Market",
					isEnabled = DebugNodes.EditableEditor.IsLevelPristine,
					fn = function()
						return CreateBiomeLocationLauncher(d_startmarket)
					end,
				},
			}
			return t
		end)()
	},
	{
		binding = { key = InputConstants.Keys.F3 },
		name = "Identify Players",
		fn = function()
			mp_identifyinputs()
		end,
	},
	{
		binding = { key = InputConstants.Keys.F4, SHIFT = true },
		name = "Toggle Max Camera Distance Limit for Player Edge Detection",
		fn = function()
			if TheFocalPoint ~= nil and TheCamera ~= nil then
				if TheFocalPoint._hasBackupEdgeDetectSettings then
					TheFocalPoint:EnableEntityEdgeDetection(TheFocalPoint._hasBackupEdgeDetectSettings.isEnabled)
					TheFocalPoint.components.focalpoint:_SetDesiredDistance(TheFocalPoint._hasBackupEdgeDetectSettings.defaultCameraDistance)
					TheFocalPoint._hasBackupEdgeDetectSettings = nil
				else
					TheFocalPoint._hasBackupEdgeDetectSettings =
					{
						isEnabled = TheFocalPoint:IsEntityEdgeDetectionEnabled(),
						defaultCameraDistance = TheFocalPoint.components.focalpoint:GetDefaultCameraDistance(),
					}
					local maxCameraDistance = TheFocalPoint.components.focalpoint.edgeDetectCameraDistanceMax
					TheFocalPoint:EnableEntityEdgeDetection(false)
					TheFocalPoint.components.focalpoint:_SetDesiredDistance(maxCameraDistance)
				end
			end
		end,
	},
	{
		--binding = { key = InputConstants.Keys.F3 },
		name = "Set Ascension",
		isSubMenu = true,
		menuItems = (function()
			-- if TheWorld == nil then
			-- 	return {
			-- 		{
			-- 			name = "Cannot Change Ascension without 'TheWorld'",
			-- 			tooltip = "Please enter the game before trying to change ascension values",
			-- 			fn = function() end,
			-- 		}
			-- 	}
			-- else
				local biomes = require"defs.biomes"
				local location_options = {}
				for id, def in pairs(biomes.locations) do
					if def.type == biomes.location_type.DUNGEON then
						table.insert(location_options, id)
					end
				end

				local ascension_selection
				local start_run_button
				local location_selection =
				{
					name = "Location Selection",
					isDropDown = true,
					options = location_options,
					cb = function(newval)
						ascension_selection.did_init = false
					end,
					initalVal = function() return 1 end,
				}

				ascension_selection =
				{
					name = "Ascension",
					isIntSlider = true,
					intMin = 0,
					intMax = function() return TheDungeon and TheDungeon.progression.components.ascensionmanager.num_ascensions or 0 end,
					initalVal = function() return TheDungeon and TheDungeon.progression.components.ascensionmanager:GetSelectedAscension(location_options[location_selection.val]) or 0 end,
					cb = function(newval)
						if TheDungeon then
							printf("Setting ascension for %s to %s", location_options[location_selection.val], newval)
							TheDungeon.progression.components.ascensionmanager:Debug_SetAscension(math.floor(newval), location_options[location_selection.val])
						end
					end,
				}

				-- Add "Increase Ascension" so you can modify in Ctrl-p.
				local ascension_increment =
				{
					name = "Increase Ascension",
					fn = function()
						location_selection.val = 1
						local ascension = ascension_selection.initalVal()
						ascension_selection.cb(ascension + 1)
					end,
				}

				start_run_button =
				{
					name = "Start New Run",
					fn = function()
						d_startrun(location_options[location_selection.val])
					end,
				}

				return {
					location_selection,
					ascension_selection,
					ascension_increment,
					start_run_button,
				}
			-- end
		end)()
	},
	{
		name = "Change Weapon",
		isSubMenu = true,
		menuItems = (function()
			local t = {
				{
					name = "Hammer",
					fn = function()
						c_give("weapon", "hammer_basic")
						TheSaveSystem:SaveAll()
					end
				},
				{
					name = "Polearm (Spear)",
					fn = function()
						c_give("weapon", "polearm_basic")
						TheSaveSystem:SaveAll()
					end
				},
				{
					name = "Shotput",
					fn = function()
						c_give("weapon", "shotput_basic")
						TheSaveSystem:SaveAll()
					end
				},
				{
					name = "Cannon",
					fn = function()
						c_give("weapon", "cannon_basic")
						TheSaveSystem:SaveAll()
					end
				},
				{
					name = "Greatsword",
					fn = function()
						c_give("weapon", "cleaver_basic")
						TheSaveSystem:SaveAll()
					end
				},
			}
			return t

		end)()
	},
	{
		name = "Cheats", -- grouping gameplay cheats together for discoverability
		isSubMenu = true,
		menuItems = (function()
			local t = {
				{
					name = "God Mode",
					isSubMenu = true,
					menuItems = (function()
						local t = {
							{
								name = "No Damage - 0x",
								fn = function()
									c_godmodeall(0, true)
								end,
							},
							{
								name = "Normal Damage - 1x",
								fn = function()
									c_godmodeall(1, true)
								end,
							},
							{
								name = "Big Damage - 5x",
								binding = { key = InputConstants.Keys.G },
								fn = function()
									if GetDebugPlayer() then
										local force_enable = GetDebugPlayer().components.combat.damagedealtmult:GetModifier("cheat") ~= 5
										c_godmodeall(5, force_enable)
									end
								end
							},
							{
								name = "Bigger Damage - 100x",
								fn = function()
									c_godmodeall(100, true)
								end,
							},
							{
								name = "MEGA UBER Damage - 1000x",
								fn = function()
									c_godmodeall(1000, true)
								end,
							},
						}
						return t
					end)()
				},
				{
					name = "Villager NPC",
					isEnabled = function()
						return TheWorld and TheWorld.components.plotmanager
					end,
					fn = function()
						local NPCS =
						{
							"npc_apothecary",
							"npc_armorsmith",
							"npc_blacksmith",
							"npc_cook",
							"npc_refiner",
						}

						local function fn(params)
							c_spawnnpc(params.name)
						end

						local spawnlist = {}

						for _, id in ipairs(NPCS) do
							spawnlist[id] = fn
						end

						TheFrontEnd.debugMenu.quickfind:OpenListOfCommands(spawnlist)
					end,
				},
				{
					name = "Heart",
					fn = function()
						local biomes = require"defs/biomes"
						local bosses = {}
						for id, def in pairs(biomes.locations) do
							if def.monsters and def.monsters.bosses then
								for _, boss in ipairs(def.monsters.bosses) do
									table.insert(bosses, boss)
								end
							end
						end

						local commands = {}
						for _, boss in ipairs(bosses) do
							commands[boss] = function() c_konjurheart(boss) end
						end

						TheFrontEnd.debugMenu.quickfind:OpenListOfCommands(commands)
					end,
				},
				{
					name = "Give Power",
					fn = function()
						local Power = require "defs.powers"
						local spawnlist = {}

						local function fn(params)
							return c_power(params.name)
						end

						local power_names = Power.GetQualifiedNames()
						for _,name in ipairs(power_names) do
							spawnlist[name] = fn
						end

						-- This list doesn't include all powers because some
						-- may not have pretty names.
						local power_pretty = Power.GetQualifiedNamesToPrettyString()
						for pwr,name in pairs(power_pretty) do
							local pow = Power.FindPowerByQualifiedName(pwr)
							name = ("%s/%s"):format(pow.slot, name)
							spawnlist[name] = function()
								c_power(pwr)
							end
						end
						TheFrontEnd.debugMenu.quickfind:OpenListOfCommands(spawnlist)
					end,
				},
				{
					name = "Upgrade All Powers",
					fn = function()
						c_upgradepower()
					end,
				},
				{
					name = "Upgrade Power...",
					fn = function()
						local player = ConsoleCommandPlayer()
						local powers = player.components.powermanager:GetUpgradeablePowers()
						local cmd_list = {}
						for _,pow in ipairs(powers) do
							local fn = function(params)
								return player.components.powermanager:UpgradePower(pow.def)
							end
							cmd_list[pow.def.name] = fn
							cmd_list[pow.def.pretty.name] = fn
						end

						TheFrontEnd.debugMenu.quickfind:OpenListOfCommands(cmd_list)
					end,
				},
				{
					name = "Super Power Up",
					fn = function()
						d_powerup()
					end,
				},
				{
					name = "Give Full Shield",
					fn = function()
						d_shield(10)
					end,
				},
				{
					name = "Armour Set",
					fn = function()
						local function fn(params)
							return c_give_armorset(params.name)
						end
						local Equipment = require "defs.equipment"
						local prefabs = Equipment.GetArmourSets()
						local spawnlist = {}
						for key,val in ipairs(prefabs) do
							spawnlist[val] = fn
						end
						TheFrontEnd.debugMenu.quickfind:OpenListOfCommands(spawnlist)
					end,
				},
				{
					name = "Upgrade Equipment",
					fn = function()
						local SLOTS =
						{
							"WEAPON",
							"HEAD",
							"BODY",
							"WAIST",
						}
						for _,p in ipairs(AllPlayers) do
							local inventoryhoard = p.components.inventoryhoard
							for i, slot in ipairs(SLOTS) do
								local item = inventoryhoard:GetEquippedItem(slot)
								if item then
									item:UpgradeItemLevel()
								end
							end
							inventoryhoard:OnLoadoutChanged()
						end
					end,
				},
				{
					name = "Give Equipment",
					fn = function()
						for _,p in ipairs(AllPlayers) do
							local inventoryhoard = p.components.inventoryhoard
							inventoryhoard:Debug_GiveRelevantEquipment()
						end
					end,
				},


				{
					name = "Unlock All Cosmetics",
					fn = function(params)
						d_unlock_all_cosmetics()
					end,
				},
				{
					name = "Purchase All Cosmetics",
					fn = function(params)
						d_purchase_all_cosmetics()
					end,
				},

				{
					name = "Give Materials",
					fn = function()
						for _,p in ipairs(AllPlayers) do
							local inventoryhoard = p.components.inventoryhoard
							inventoryhoard:Debug_GiveRelevantMaterials()
						end
					end,
				},
				{
					name = "Reset Inventory",
					fn = function()
						for _,p in ipairs(AllPlayers) do
							local inventoryhoard = p.components.inventoryhoard
							inventoryhoard:ResetData()
						end
					end,
				},

				{
					name = "All NPCs",
					fn = function()
						if not TheWorld:HasTag("town") then
							print ("CAN'T USE THAT CHEAT IN DUNGEON")
							return
						end

						local npcs = { "npc_refiner", "npc_armorsmith", "npc_blacksmith", "npc_cook", "npc_apothecary", --[["npc_dojo_master"]]}
						for _, v in ipairs(npcs) do
							c_spawnnpc(v)
						end

						local quests = { "twn_shop_apothecary", "twn_armorsmith_arrival", "twn_shop_weapon", "twn_shop_cook", "twn_shop_research" }

						playerutil.DoForAllLocalPlayers(function(player)
							local qm = player.components.questcentral:GetQuestManager()
							for _, v in ipairs(quests) do
								qm:SpawnQuest(v)
							end
						end)

						--Sorry this is ugly and hardcoded lol (I need the flags unlocked to test certain convos) --Kris
						TheWorld:UnlockFlag("wf_town_has_blacksmith")
						TheWorld:UnlockFlag("wf_town_has_armorsmith")
						TheWorld:UnlockFlag("wf_town_has_cook")
						TheWorld:UnlockFlag("wf_town_has_apothecary")
						TheWorld:UnlockFlag("wf_town_has_research")
						--TheWorld:UnlockFlag("wf_town_has_dojo")

					end,
				},
				{
					name = "Unlock All Locations",
					fn = function()
						d_unlock_all_locations()
					end,
				},
			}
			return t

		end)()
	},
	{ separator = true },

	{
		name = "Quickstart", -- grouping gameplay cheats together for discoverability
		isSubMenu = true,
		menuItems = d_quickstart("create_menu")
	},

	{ separator = true },
	{
		--binding = { key = InputConstants.Keys.F3 },
		name = "UI Test Screen",
		fn = function()
			d_open_screen("screens.uitestscreen")
		end,
	},

	{ separator = true },
	-- NW: Can't do this anymore. You need a valid input ID to add a player.
--	{
--		--binding = { key = InputConstants.Keys.F3 },
--		name = "Add a player",
--		fn = function()
--			net_addplayer()
--		end,
--	},
	{
		--binding = { key = InputConstants.Keys.F3 },
		name = "Remove a player",
		isSubMenu = true,
		menuItems = (function()
			local t = {{
					name = "Any",
					fn = function()
						net_removeplayer()
					end,
			}}
			for i = 2, 4 do
				table.insert(t, {
						name = "P"..i,
						fn = function()
							-- kiln network player ids are 0-based
							net_removeplayer(i - 1)
						end
				})
			end
			return t
		end)(),
	},
	{
		name = "Preview HUD - all local players",
		fn = function()
			TheDungeon.HUD.player_unit_frames:Debug_FillAllLocalPlayerSlots()
		end,
	},
	{
		name = "Customize Character",
		isSubMenu = true,
		menuItems = (function()
			local actions = {}

			for i = 1, 4 do
				local button =
				{
					name = string.format("Customize Character %s", i),-- "Customize Character",
					fn = function()
						mp_customizecharacter(i)
					end,
				}

				table.insert(actions, button)
			end

			local all = {
				name = "Randomize All Characters",
				fn = function()
					for _,p in ipairs(AllPlayers) do
						p.components.charactercreator:Randomize()
					end
				end,
			}
			table.insert(actions, all)

			return actions
		end)()
	},
}

PROGRAMMER_KEY_BINDINGS =
{
	{
		binding = { key = InputConstants.Keys.BACKSPACE },
		name = "Debug Render",
		isEnabled = function()
			local screen = TheFrontEnd:GetActiveScreen()
			return not screen or not screen:IsEditing()
		end,
		isChecked = function()
			return TheSim:GetDebugRenderEnabled()
		end,
		fn = function()
			TheSim:SetDebugRenderEnabled(not TheSim:GetDebugRenderEnabled())
		end,
	},
	{
		name = "Start Debuggee (Attach vscode)",
		fn = function()
			d_attachdebugger()
		end,
	},
	{
		binding = { key = InputConstants.Keys.F1, ALT = true },
		name = "Select World",
		fn = function()
			c_select(TheWorld)
		end,
	},
	{
		name = "Inspect TheWorld",
		fn = function()
			d_viewinpanel(TheWorld)
		end,
	},
	{
		name = "Inspect TheDungeon (and worldmap)",
		fn = function()
			-- Need to open the worldmap section manually.
			d_viewinpanel(TheDungeon)
		end,
	},
	{
		name = "Inspect progression",
		fn = function()
			d_viewinpanel(TheDungeon.progression)
		end,
	},
	{
		name = "Inspect spawned prefab...",
		fn = function()
			-- Pick from all prefabs in the world.
			local function fn(params)
				return d_viewinpanel(c_selectprefab(params.name))
			end
			local cmd_list = {}
			for guid,ent in pairs(Ents) do
				if ent.prefab then
					cmd_list[ent.prefab] = fn
				end
			end
			TheFrontEnd.debugMenu.quickfind:OpenListOfCommands(cmd_list)
		end,
	},
	{
		binding = { key = InputConstants.Keys.F1, CTRL = true },
		name = "Toggle Perf Graph",
		fn = function()
			TheSim:TogglePerfGraph() -- Currently doesn't display?
		end,
	},
	{
		binding = { key = InputConstants.Keys.F2, ALT = true },
		name = "Toggle BGFX stats",
		fn = function()
			TheSim:ToggleBGFXStatsDisplay()
		end,
	},
	{
		binding = { key = InputConstants.Keys.Z, CTRL = true },
		name = "Undo last prop move",
		fn = function()
			UndoLastPropMove()
		end,
	},
	{
		binding = { key = InputConstants.Keys.B, CTRL = true },
		name = "Draw Selected AABB", -- Needs to be implemented in the new Debug menu system
		isChecked = function()
			return TheDebugSettings.showActiveAABB
		end,
		fn = function()
			TheDebugSettings.showActiveAABB = not TheDebugSettings.showActiveAABB
		end,
	},
	{
		binding = { key = InputConstants.Keys.INSERT, },
		name = "Draw Physics Colliders",
		isEnabled = function()
			return TheInput:IsDebugToggleEnabled()
		end,
		isChecked = function()
			return TheSim:GetDebugRenderEnabled() and TheSim:GetDebugPhysicsRenderEnabled()
		end,
		fn = function()
			TheSim:SetDebugRenderEnabled(true)
			TheSim:SetDebugPhysicsRenderEnabled(not TheSim:GetDebugPhysicsRenderEnabled())
		end,
	},
	{
		binding = { key = InputConstants.Keys.INSERT, SHIFT = true, },
		name = "Toggle Debug Camera",
		isEnabled = function()
			return TheInput:IsDebugToggleEnabled()
		end,
		fn = function()
			-- Not sure this camera is useful on Rotwood unless you're calling
			-- SetDebugCameraTarget.
			TheSim:ToggleDebugCamera()
		end,
	},
	{
		name = "Always Show On-screen Log",
		isChecked = function()
			return TheFrontEnd.settings.console_log_always_on
		end,
		fn = function()
			-- Modify setting only through the debug menu and not Ctrl-L
			-- so shortcut doesn't silently set a persistent setting.
			TheFrontEnd.settings:Set("console_log_always_on", not TheFrontEnd.settings.console_log_always_on)
				:Save()
			if TheFrontEnd.settings.console_log_always_on then
				TheFrontEnd:ShowConsoleLog()
			else
				TheFrontEnd:HideConsoleLog()
			end
		end,
	},
	{
		isSubMenu = true,
		name = "On-screen Log Layout",
		menuItems = (function()
			local haligns = {
				"left",
				"center",
				"right",
			}
			local valigns = {
				"top",
				"center",
				"bottom",
			}

			local t = {}
			for _,halign in ipairs(haligns) do
				table.insert(t, {
						name = halign,
						isChecked = function()
							return TheFrontEnd.settings.console_log_h == halign
						end,
						fn = function()
							TheFrontEnd:SetConsoleLogCorner(halign, TheFrontEnd.settings.console_log_v)
						end,
					})
			end
			for _,valign in ipairs(valigns) do
				table.insert(t, {
						name = valign,
						isChecked = function()
							return TheFrontEnd.settings.console_log_v == valign
						end,
						fn = function()
							TheFrontEnd:SetConsoleLogCorner(TheFrontEnd.settings.console_log_h, valign)
						end,
					})
			end
			return t
		end)(),
	},
	{
		binding = { key = InputConstants.Keys.N, SHIFT = true, ALT = true },
		name = "Draw Network Debugging",
		isEnabled = function()
			return TheInput:IsDebugToggleEnabled()
		end,
		isChecked = function()
			return TheSim:GetDebugRenderEnabled() and TheSim:GetDebugNetworkRenderEnabled()
		end,
		fn = function()
			TheSim:SetDebugRenderEnabled(true)
			TheSim:SetDebugNetworkRenderEnabled(not TheSim:GetDebugNetworkRenderEnabled())
		end,
	},
}

WINDOW_KEY_BINDINGS =
{
	{
		binding = { key = InputConstants.Keys.R, SHIFT = true },
		name = "Prefabs",
		fn = function(params)
			HotkeyShowDebugPanel( DebugNodes.DebugPrefabs, params.from_hotkey)
		end,
	},
	{
		binding = { key = InputConstants.Keys.F, SHIFT = true },
		name = "Fx Log",
		fn = function(params)
			HotkeyShowDebugPanel( DebugNodes.DebugFX, params.from_hotkey)
		end,
	},
	{
		--~ binding = { key = InputConstants.Keys.A, CTRL = true, SHIFT = true },
		name = "Animation Log",
		fn = function(params)
			if not c_sel() then
				c_select(GetDebugPlayer())
			end
			HotkeyShowDebugPanel( DebugNodes.DebugAnimation, params.from_hotkey)
		end,
	},
	{
		binding = { key = InputConstants.Keys.A, CTRL = true, SHIFT = true },
		name = "Audio",
		fn = function(params)
			HotkeyShowDebugPanel( DebugNodes.DebugAudio, params.from_hotkey)
		end,
	},
	{
		name = "Missing Assets",
		fn = function(params)
			HotkeyShowDebugPanel(DebugNodes.DebugMissingAssets, params.from_hotkey)
		end,
	},
	{
		binding = { key = InputConstants.Keys.A, ALT = true },
		name = "Anim Tester",
		fn = function(params)
			HotkeyShowDebugPanel( DebugNodes.AnimTester, params.from_hotkey)
		end,
	},
	{
		binding = { key = InputConstants.Keys.A, CTRL = true },
		name = "Anim Tagger",
		fn = function(params)
			HotkeyShowDebugPanel( DebugNodes.AnimTagger, params.from_hotkey)
		end,
	},
	{
		binding = { key = InputConstants.Keys.W, SHIFT = true },
		name = "Widget",
		fn = function(params)
			HotkeyShowDebugPanel( DebugNodes.DebugWidget, params.from_hotkey)
		end,
	},
	{
		binding = { key = InputConstants.Keys.X, SHIFT = true },
		name = "Widget Explorer",
		fn = function(params)
			HotkeyShowDebugPanel( DebugNodes.DebugWidgetExplorer, params.from_hotkey)
		end,
	},
	{
		binding = { key = InputConstants.Keys.E, SHIFT = true },
		name = "Entity",
		fn = function(params)
			HotkeyShowDebugPanel( DebugNodes.DebugEntity, params.from_hotkey)
			if GetDebugEntity() == nil then
				c_selectany_cycle()
			end
		end,
	},
	{
		name = "Entity Explorer",
		fn = function(params)
			HotkeyShowDebugPanel( DebugNodes.DebugEntityExplorer, params.from_hotkey)
		end,
	},
	{
		binding = { key = InputConstants.Keys.C, SHIFT = true, CTRL = true },
		name = "Camera",
		fn = function(params)
			local panel = TheFrontEnd:FindOpenDebugPanel(DebugNodes.DebugCamera)
			if panel then
				HotkeyShowDebugPanel( DebugNodes.DebugCamera, params.from_hotkey)
			else
				--jcheng: use the debug menu one instead of creating a new one
				-- this is so the settings are saved and used properly
				TheFrontEnd:CreateDebugPanel(TheFrontEnd.debugMenu.debug_camera)
			end
		end,
	},
	{
		--binding = { key = InputConstants.Keys.E, SHIFT = true },
		name = "Anything",
		fn = function(params)
			HotkeyShowDebugPanel( DebugNodes.DebugAnything, params.from_hotkey)
		end,
	},
	{
		name = "Anything - Global",
		fn = function(params)
			DebugNodes.DebugAnything.ChooseFromGlobals()
		end,
	},
	{
		--binding = { key = InputConstants.Keys.E, SHIFT = true },
		name = "Brain",
		fn = function(params)
			HotkeyShowDebugPanel( DebugNodes.DebugBrain, params.from_hotkey)
		end,
	},
	{
		binding = { key = InputConstants.Keys.TILDE, SHIFT = true },
		name = "Console",
		fn = function(params)
			HotkeyShowDebugPanel( DebugNodes.DebugConsole, params.from_hotkey)
		end,
	},
	{
		--binding = { key = InputConstants.Keys.E, SHIFT = true },
		name = "Watch",
		fn = function(params)
			HotkeyShowDebugPanel( DebugNodes.DebugWatch, params.from_hotkey)
		end,
	},
	{
		binding = { key = InputConstants.Keys.H },
		name = "History",
		fn = function(params)
			HotkeyShowDebugPanel( DebugNodes.DebugHistory, params.from_hotkey)
		end,
	},
	{
		--binding = { key = InputConstants.Keys.E, SHIFT = true },
		name = "Modifier Keys",
		fn = function(params)
			HotkeyShowDebugPanel( DebugNodes.DebugModifiers, params.from_hotkey)
		end,
	},
	{
		binding = { key = InputConstants.Keys.P, SHIFT = true },
		name = "Player",
		fn = function(params)
			HotkeyShowDebugPanel( DebugNodes.DebugPlayer, params.from_hotkey)
		end,
	},
	{
		binding = { key = InputConstants.Keys.C, ALT = true },
		name = "Encounter",
		fn = function(params)
			HotkeyShowDebugPanel( DebugNodes.DebugEncounter, params.from_hotkey)
		end,
	},
	{
		binding = { key = InputConstants.Keys.N, ALT = true },
		name = "Network",
		fn = function(params)
			HotkeyShowDebugPanel( DebugNodes.DebugNetwork, params.from_hotkey)
		end,
	},
	{
		binding = { key = InputConstants.Keys.C, SHIFT = true },
		name = "Color Transform Inspector",
		fn = function(params)
			HotkeyShowDebugPanel( DebugNodes.ColorTransform, params.from_hotkey)
		end,
	},
	{
		name = "Easing Functions",
		fn = function(params)
			HotkeyShowDebugPanel( DebugNodes.DebugEasing, params.from_hotkey)
		end,
	},
	{
		--~ binding = { key = InputConstants.Keys.M, CTRL = true, SHIFT = true, },
		name = "Dungeon Map Layout",
		fn = function(params)
			HotkeyShowDebugPanel(DebugNodes.MapPathEditor, params.from_hotkey)
		end,
	},
	{
		binding = { key = InputConstants.Keys.Q, CTRL = true, SHIFT = true, },
		name = "Quest",
		isEnabled = function()
			-- Without questcentral, the quest system isn't likely to function.
			return ConsoleCommandPlayer() and ConsoleCommandPlayer().components.questcentral
		end,
		fn = function(params)
			HotkeyShowDebugPanel(DebugNodes.DebugQuestManager, params.from_hotkey)
		end,
	},
	{
		--~ binding = { key = InputConstants.Keys.Q, ALT = true, SHIFT = true, },
		name = "CastManager (Quests)",
		isEnabled = function()
			return TheDungeon and TheDungeon.progression.components.castmanager
		end,
		fn = function(params)
			HotkeyShowDebugPanel(DebugNodes.DebugCastManager, params.from_hotkey)
		end,
	},
	{
		binding = { key = InputConstants.Keys.G, CTRL = true },
		name = "Proc Gen",
		fn = function(params)
			HotkeyShowDebugPanel( DebugNodes.DebugProcGen, params.from_hotkey)
		end,
	},
	{
		name = "Cosmetic Lister",
		fn = function(params)
			HotkeyShowDebugPanel(DebugNodes.CosmeticLister, params)
		end,
	},
}

EDITOR_KEY_BINDINGS =
{
	{
		binding = { key = InputConstants.Keys.I, ALT = true},
		name = "Item Editor",
		fn = function(params)
			HotkeyShowDebugPanel( DebugNodes.ItemEditor, params.from_hotkey)
		end,
	},
	{
		binding = { key = InputConstants.Keys.P, ALT = true, SHIFT = true },
		name = "Fx Editor",
		fn = function(params)
			HotkeyShowDebugPanel( DebugNodes.FxEditor, params.from_hotkey)
		end,
	},
	{
		binding = { key = InputConstants.Keys.W, ALT = true },
		name = "World Editor",
		fn = function(params)
			HotkeyShowDebugPanel( DebugNodes.WorldEditor, params.from_hotkey)
		end,
	},
	{
		--~ binding = { key = InputConstants.Keys.C, CTRL = true },
		name = "Curve Editor",
		fn = function(params)
			HotkeyShowDebugPanel(DebugNodes.CurveEditor, params)
		end,
	},
	{
		binding = { key = InputConstants.Keys.D, ALT = true },
		name = "Drop Editor",
		fn = function(params)
			HotkeyShowDebugPanel( DebugNodes.DropEditor, params.from_hotkey)
		end,
	},
	{
		binding = { key = InputConstants.Keys.E, CTRL = true },
		name = "Embellisher",
		fn = function(params)
			HotkeyShowDebugPanel( DebugNodes.Embellisher, params.from_hotkey)
		end,
	},

	{
		binding = { key = InputConstants.Keys.C, ALT = true, SHIFT = true },
		name = "Cinematics",
		fn = function(params)
			HotkeyShowDebugPanel( DebugNodes.CineEditor, params.from_hotkey)
		end,
	},

	{
		binding = { key = InputConstants.Keys.N, SHIFT = true },
		name = "NPC Editor",
		fn = function(params)
			HotkeyShowDebugPanel( DebugNodes.NpcEditor, params.from_hotkey)
		end,
	},
	{
		binding = { key = InputConstants.Keys.R, ALT = true },
		name = "Prop Editor",
		fn = function(params)
			HotkeyShowDebugPanel( DebugNodes.PropEditor, params.from_hotkey)
		end,
	},
	{
		binding = { key = InputConstants.Keys.P, ALT = true },
		name = "Particle Editor",
		fn = function(params)
			HotkeyShowDebugPanel( DebugNodes.ParticleEditor, params.from_hotkey)
		end,
	},
	{
		binding = { key = InputConstants.Keys.E, ALT = true },
		name = "Level Layout Editor",
		fn = function(params)
			HotkeyShowDebugPanel( DebugNodes.EditableEditor, params.from_hotkey)
		end,
	},
	{
		binding = { key = InputConstants.Keys.G, ALT = true },
		name = "SceneGen Editor",
		fn = function(params)
			HotkeyShowDebugPanel( DebugNodes.SceneGenEditor, params.from_hotkey)
		end,
	},
	{
		name = "Cosmetic Editor",
		fn = function(params)
			HotkeyShowDebugPanel(DebugNodes.CosmeticEditor, params)
		end,
	},
}

HELP_KEY_BINDINGS =
{
	{
		binding = { key = InputConstants.Keys.F11 },
		name = "ImGui Lua Demo",
		fn = function(params)
			HotkeyShowDebugPanel( DebugNodes.ImGuiDemo, params.from_hotkey)
		end,

		tooltip = "Demo of ImGui functions already implemented."
	},
	{
		name = "Text Test",
		fn = function()
			TheFrontEnd:PushScreen(TextTest())
		end,
	},
	{
		name = "Widget Test",
		fn = function()
			TheFrontEnd:PushScreen(WidgetTest())
		end,
	},
	{
		name = "Blur Test",
		fn = function()
			d_viewinpanel(TheWorld)
			print("Blur Test requires you to expand the 'Component: blurcoordinator' section of the world's DebugEntity.")
		end,
	},
	{ separator = true },
	{
		name = "ImGui C Demo",
		fn = function()
			local panel = TheFrontEnd:GetSelectedDebugPanel()
			panel.show_test_window = true
		end,
		skip_palette = true,

		tooltip = "Show ImGui Test Window (Not Lua, to see features we could have)"
	},

}

local function BindKeys( bindings )
	for _,v in pairs(bindings) do
		if v.binding then
			--~ if handlers[v.binding.key] then
			--~ 	local lume = require "util.lume"
			--~ 	local key_lookup = lume.invert(InputConstants.Keys)
			--~ 	TheLog.ch.DebugKey:printf("Binding %s [%s] to '%s', but it's already bound. Using: %s", key_lookup[v.binding.key], v.binding.key, v.name, table.inspect(v.binding, {newline = ' ',}))
			--~ end
			AddGlobalDebugKey( v.binding.key,
				function()
					if (v.binding.CTRL and not TheInput:IsKeyDown(InputConstants.Keys.CTRL)) or
						(v.binding.CTRL == nil and TheInput:IsKeyDown(InputConstants.Keys.CTRL)) then
						return false
					end

					if (v.binding.SHIFT and not TheInput:IsKeyDown(InputConstants.Keys.SHIFT)) or
						(v.binding.SHIFT == nil and TheInput:IsKeyDown(InputConstants.Keys.SHIFT)) then
						return false
					end

					if (v.binding.ALT and not TheInput:IsKeyDown(InputConstants.Keys.ALT)) or
						(v.binding.ALT == nil and TheInput:IsKeyDown(InputConstants.Keys.ALT)) then
						return false
					end

					print("Activating hotkey: "..v.name)
					-- Same table keys in DebugPanel, Quickfind, and BindKeys.
					return v.fn({
							name = v.name,
							from_hotkey = true,
						})
				end, v.down)
		elseif v.isSubMenu then
			BindKeys(v.menuItems)
		end
	end
end

BindKeys( MENU_KEY_BINDINGS )
BindKeys( GLOBAL_KEY_BINDINGS )
BindKeys( PROGRAMMER_KEY_BINDINGS )
BindKeys( WINDOW_KEY_BINDINGS )
BindKeys( EDITOR_KEY_BINDINGS )
BindKeys( HELP_KEY_BINDINGS )

local function OpenEditableEditor(did_dirty_prop_persist)
	if not did_dirty_prop_persist then
		return
	end
	local showEditableEditorOnDirty = Profile:GetValue("showEditableEditorOnDirty")
	if TheWorld ~= nil
		and TheWorld.components.propmanager ~= nil
		and showEditableEditorOnDirty
		and not TheFrontEnd:FindOpenDebugPanel(DebugNodes.EditableEditor)
	then
		local panel = TheFrontEnd:CreateDebugPanel( DebugNodes.EditableEditor() )
		panel.openCollapsed = true
	end
end

AddGameDebugKey(InputConstants.Keys.F6, function()
	-- F6 is used by the hot-reload functionality! See reload.lua
end)

-- Slow down and speed up.
AddGlobalDebugKey(InputConstants.Keys.LEFTBRACKET, function()
	if TheInput:IsKeyDown(InputConstants.Keys.CTRL) then
		TheSim:SetTimeScale(1)
	elseif TheInput:IsKeyDown(InputConstants.Keys.SHIFT) then
		TheSim:SetTimeScale(0)
	else
		TheSim:SetTimeScale(TheSim:GetTimeScale() - .25)
	end
	return true
end)

AddGlobalDebugKey(InputConstants.Keys.RIGHTBRACKET, function()
	if TheInput:IsKeyDown(InputConstants.Keys.CTRL) then
		TheSim:SetTimeScale(1)
	elseif TheInput:IsKeyDown(InputConstants.Keys.SHIFT) then
		TheSim:SetTimeScale(4)
	else
		TheSim:SetTimeScale(TheSim:GetTimeScale() + .25)
	end
	return true
end)

AddGameDebugKey(InputConstants.Keys.KP_PLUS, function()
	local player = DebugKeyPlayer()

	-- Revive if dead
	if player ~= nil and player.components.health ~= nil and not player:IsAlive() then
		player.components.health:SetRevivable()
		player.components.health:SetRevived()

		-- Pop the run summary screen if it's active.
		local screen = TheFrontEnd:GetActiveScreen()
		if screen and screen._widgetname == "RunSummaryScreen" then
			TheFrontEnd:PopScreen(screen)
		end
	else
		c_sethealth(1)
	end
	return true
end)

AddGameDebugKey(InputConstants.Keys.KP_MINUS, function()
	local player = DebugKeyPlayer()
	if player ~= nil and player.components.health ~= nil then
		local delta = player.components.health:GetMax() / 2.3
		if TheInput:IsKeyDown(InputConstants.Keys.SHIFT) then
			delta = delta / 10
		end
		player.components.health:DoDelta(-math.floor(delta))
	end
	return true
end)

AddGameDebugKey(InputConstants.Keys.T, function()
	local target
	if TheInput:IsKeyDown(InputConstants.Keys.ALT) then
		target = c_sel()
	else
		target = DebugKeyPlayer()
	end

	local x, z = TheInput:GetWorldXZ()
	if target and x and z then
		local x1, y1, z1 = target.Transform:GetWorldPosition()
		if target.components.locomotor ~= nil then
			-- locomotors must stay on the ground?
			y1 = 0
		end

		if target.Physics then
			target.Physics:Teleport(x, y1, z)
		else
			target.Transform:SetPosition(x, y1, z)
		end
	end
	return true
end)

local DebugTextureVisible = false
local MapLerpVal = 0.0

AddGlobalDebugKey(InputConstants.Keys.KP_DIVIDE, function()
	if TheInput:IsKeyDown(InputConstants.Keys.ALT) then
		print("ToggleFrameProfiler")
		TheSim:ToggleFrameProfiler()
	else
		TheSim:ToggleDebugTexture(TheInput:IsKeyDown(InputConstants.Keys.CTRL))

		DebugTextureVisible = not DebugTextureVisible
		print("DebugTextureVisible",DebugTextureVisible)
	end
	return true
end)

AddGlobalDebugKey(InputConstants.Keys.EQUALS, function()
	if DebugTextureVisible then
		local val = 1
		if TheInput:IsKeyDown(InputConstants.Keys.ALT) then
			val = 10
		elseif TheInput:IsKeyDown(InputConstants.Keys.CTRL) then
			val = 100
		end
		TheSim:UpdateDebugTexture(val)
	else
		if TheWorld then
			TheWorld:ToggleGroundVisibility()
		end
	end
	return true
end)

AddGlobalDebugKey(InputConstants.Keys.MINUS, function()
	if DebugTextureVisible then
		local val = 1
		if TheInput:IsKeyDown(InputConstants.Keys.ALT) then
			val = 10
		elseif TheInput:IsKeyDown(InputConstants.Keys.CTRL) then
			val = 100
		end
		TheSim:UpdateDebugTexture(-val)
	else
		if TheWorld then
			MapLerpVal = MapLerpVal - 0.1
			TheWorld.Map:SetOverlayLerp(MapLerpVal)
		end
	end

	return true
end)

AddGameDebugKey(InputConstants.Keys.S, function()
	if TheInput:IsKeyDown(InputConstants.Keys.CTRL) then
		c_save()
		return true
	end
end)

AddGlobalDebugKey(InputConstants.Keys.PAUSE, function()
	print("Pause key: Toggle pause")

	TheSim:ToggleDebugPause()


	if TheCamera.targetpos or TheCamera.headingtarget then
		-- Try running in console before pressing pause:
		--		TheCamera.targetpos = GetDebugPlayer():GetPosition() ; TheCamera.headingtarget = -65
		TheSim:ToggleDebugCamera()
		TheSim:SetDebugRenderEnabled(true)

		if TheCamera.targetpos then
			TheSim:SetDebugCameraTarget(TheCamera.targetpos.x, TheCamera.targetpos.y, TheCamera.targetpos.z)
		end

		if TheCamera.headingtarget then
			TheSim:SetDebugCameraRotation(-TheCamera.headingtarget-90)
		end
	end
	return true
end)

AddGameDebugKey(InputConstants.Keys.F, function()
	if TheInput:IsKeyDown(InputConstants.Keys.ALT) then
		local prop = GetDebugEntity()
		if prop ~= nil and prop.components.prop ~= nil then
			prop:PushEvent("flipprop")
		end
	end
end)

-- Select the player entity
AddGameDebugKey(InputConstants.Keys.NUM_1, function()
	if TheInput:IsKeyDown(InputConstants.Keys.CTRL) then
		SetDebugEntity(DebugKeyPlayer())
	end
end)


local function DebugCompleteConversation()
	local prompt = TheDungeon.HUD.prompt
	local npc = prompt.npc

	local interactable = npc.components.interactable
	if interactable and interactable.lock then
		-- Only complete a conversation if it has been started
		local conversation = npc.components.conversation

		local convoplayer = conversation.convoplayer
		local quest = convoplayer:GetQuest()

		local current_convo = convoplayer:GetCurrentConvo()
		local current_objective_id = current_convo.objective_id

		convoplayer.convo_done = true
		conversation:EndConvo()
		quest:Complete(current_objective_id)
	end
end

-- Auto-complete the current conversation
AddGameDebugKey(InputConstants.Keys.C, function()
	if TheInput:IsKeyDown(InputConstants.Keys.CTRL) then
		-- Only execute if a conversation is open
		if TheDungeon.HUD:GetPromptTarget() then
			DebugCompleteConversation()
		end
	end
end)

-------------------------------------------MOUSE HANDLING
local DEBUGRMB_NOT_TAGS = { "INLIMBO" }
local function DebugRMB(x,y)
	local MouseCharacter = TheInput:GetWorldEntityUnderMouse()
	local x, z = TheInput:GetWorldXZ()
	local target_pos = TheInput:GetWorldPosition()

	if TheInput:IsKeyDown(InputConstants.Keys.CTRL)
		and TheInput:IsKeyDown(InputConstants.Keys.SHIFT)
		and c_sel()
		and c_sel().prefab
	then
		local prefab = c_sel().prefab
		local editable_panel = TheFrontEnd:FindOpenDebugPanel(DebugNodes.EditableEditor)
		if editable_panel then
			-- Use editable so it follows settings and extra features there.
			local editable_editor = editable_panel:GetNode()
			editable_editor:PlacePrefab(prefab, c_sel(), target_pos)
		else
			local spawn = c_spawn(prefab)
			if spawn then
				spawn.Transform:SetPosition(target_pos:unpack())
			end
		end

	elseif TheInput:IsKeyDown(InputConstants.Keys.CTRL)
		and TheWorld
	then
		if MouseCharacter ~= nil and MouseCharacter ~= GetDebugPlayer() then
			if MouseCharacter.components.health ~= nil then
				MouseCharacter.components.health:Kill()
			else
				MouseCharacter:Remove()
			end
		else
			local ents = TheSim:FindEntitiesXZ(x, z, 5, nil, DEBUGRMB_NOT_TAGS)
			for i = 1, #ents do
				local v = ents[i]
				if v.components.health ~= nil and v ~= DebugKeyPlayer() then
					v.components.health:Kill()
				end
			end
		end

	elseif TheInput:IsKeyDown(InputConstants.Keys.ALT) then
		local player = c_sel() or DebugKeyPlayer()
		if player then
			print(tostring(player).." to ("..tostring(x)..", 0, "..tostring(z).."): Dist = " .. tostring(math.sqrt(player:GetDistanceSqToXZ(x, z))) .. ", Angle = " .. tostring(player:GetAngleToXZ(x, z)))
		end

	elseif TheInput:IsKeyDown(InputConstants.Keys.SHIFT) then
		print("shift rmb")
		print("MouseCharacter:",MouseCharacter)
		if MouseCharacter then
			SetDebugEntity(MouseCharacter)
		elseif TheWorld then
			SetDebugEntity(TheWorld)
		end
	end
end

local function DebugLMB(x,y)
	if TheSim:IsDebugPaused() then
		SetDebugEntity(TheInput:GetWorldEntityUnderMouse())
	end
end

function DoPropsDebugMouseDown(button, x, y)
	local is_relevant = button == InputConstants.MouseButtons.LEFT
		or button == InputConstants.MouseButtons.RIGHT
		or button == InputConstants.MouseButtons.MIDDLE
		or button == InputConstants.MouseButtons.SCROLL_UP
		or button == InputConstants.MouseButtons.SCROLL_DOWN
	if not is_relevant then
		return
	end


	local curprop = TheInput.hoverprop

	-- determine active prop in stack of props
	local allprops = TheInput:GetAllWorldEntitiesUnderMouse(function(ent)
		return ent.components.prop
			and ent.components.prop.edit_listeners
	end)
	if #allprops == 0 then
		return false
	end
	local index = 1
	for i,v in pairs(allprops) do
		if v == curprop then
			index = i
		end
	end
	-- and potentially cycle through them
	if button == InputConstants.MouseButtons.SCROLL_UP then
		index = index + 1
	elseif button == InputConstants.MouseButtons.SCROLL_DOWN then
		index = index - 1
	end
	index = circular_index_number(#allprops, index)
	local prop = allprops[index]
	if prop ~= curprop then
		-- selection changed, drop the old prop just in case
		if TheInput.lockedprop then
			TheInput.lockedprop:PushEvent("stopdraggingprop")
		end
		TheInput:SetHoverProp(prop)
		TheInput.lockedprop = nil
	end

	if prop and prop.components.prop then
		if button == InputConstants.MouseButtons.MIDDLE
			or button == InputConstants.MouseButtons.SCROLL_UP
			or button == InputConstants.MouseButtons.SCROLL_DOWN
			then
			SetDebugEntity(prop)
		elseif button == InputConstants.MouseButtons.LEFT then
			SetDebugEntity(prop)
			TheInput.lockedprop = prop
			prop:PushEvent("startdraggingprop")
		elseif button == InputConstants.MouseButtons.RIGHT then
			prop:PushEvent("deleteprop")

			-- Open the prop layout editor if a prop was removed
			OpenEditableEditor(prop.persists)
		end

	else
		SetDebugEntity(nil)
	end
	return false
end

function DoPropsDebugMouseUp(button, x, y)
	if button == InputConstants.MouseButtons.LEFT then
		local prop = TheInput.hoverprop
		if prop and prop.components.prop then
			prop:PushEvent("stopdraggingprop")
			TheInput.lockedprop = nil

			-- Open the prop layout editor if a prop was dragged
			if TheInput:IsKeyDown(InputConstants.Keys.ALT) then
				OpenEditableEditor(prop.persists)
			end
		end
	end
	return false
end

function DoDebugMouse(button, down, x, y)
	if TheInput:IsEditMode() and TheInput:IsKeyDown(InputConstants.Keys.ALT) then
		if down then
			return DoPropsDebugMouseDown(button, x, y)
		else
			return DoPropsDebugMouseUp(button, x, y)
		end
	end

	if not down then
		return DoPropsDebugMouseUp(button, x, y)
	end

	if button == InputConstants.MouseButtons.RIGHT then
		DebugRMB(x, y)
	elseif button == InputConstants.MouseButtons.LEFT then
		DebugLMB(x, y)
	end
end

-- Show/Hide all props
AddGameDebugKey(InputConstants.Keys.H, function()
	if TheInput:IsKeyDown(InputConstants.Keys.CTRL) and TheInput:IsKeyDown(InputConstants.Keys.SHIFT) then
		TheDebugSettings.propshidden = not TheDebugSettings.propshidden
		if TheDebugSettings.propshidden then
			for i,v in pairs(Ents) do
				if v.components.prop and not v.Light then
					v:Hide()
				end
			end
		else
			for i,v in pairs(Ents) do
				if v.components.prop and not v.Light then
					v:Show()
				end
			end
		end
	elseif TheInput:IsKeyDown(InputConstants.Keys.CTRL) then
		TheDebugSettings.propshidden = not TheDebugSettings.propshidden
		if TheDebugSettings.propshidden then
			for i,v in pairs(Ents) do
				if v.components.prop then
					v:Hide()
					if v.Light then
						v.Light:Enable(false)
					end
				end
			end
		else
			for i,v in pairs(Ents) do
				if v.components.prop then
					v:Show()
					if v.Light then
						v.Light:Enable(true)
					end
				end
			end
		end
	elseif TheInput:IsKeyDown(InputConstants.Keys.ALT) then
		local v = c_sel()
		if v then
			if v:IsVisible() then
				v:Hide()
			else
				v:Show()
			end
		end
	end
end)
