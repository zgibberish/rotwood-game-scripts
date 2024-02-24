local Consumable = require "defs.consumable"
local DebugDraw = require "util.debugdraw"
local DebugNodes = require "dbui.debug_nodes"
local Enum = require "util.enum"
local iterator = require "util.iterator"
local lume = require "util.lume"
require "consolecommands"
require "constants"

local DebugPlayer = Class(DebugNodes.DebugNode, function(self, inst)
	DebugNodes.DebugNode._ctor(self, "Debug Player")
	self.inst = inst
	self.autoselect = not inst
end)

DebugPlayer.PANEL_WIDTH = 800
DebugPlayer.PANEL_HEIGHT = 1000


local function CaptureAnimList(player)
	local data = {
		sg_name = player.sg.sg.name,
		anims_found = lume.invert(player.AnimState:GetCurrentBankAnimNames()),
		anims_required = {},
		failures = {},
	}

	local inst = DebugSpawn("player_side")
	inst.components.inventoryhoard:Debug_CopyWeaponFrom(player)
	inst:Debug_WrapNativeComponent("AnimState")

	function inst.AnimState:PlayAnimation(anim_name)
		data.anims_required[anim_name] = inst.current_state
	end
	inst.AnimState.PushAnimation = inst.AnimState.PlayAnimation
	inst.AnimState.IsCurrentAnimation = inst.AnimState.PlayAnimation

	inst.sg.mem.heavyspinloops = 1
	inst.sg.mem.speedmult = 1

	local forbidden = lume.invert{
		-- Add any state names here that shouldn't be allowed.
		--~ 'default_dodge',
	}
	local state_cleanup = {
		spawned = {},
		cb = {},
	}
	for name,state in pairs(inst.sg.sg.states) do
		if not forbidden[name] then
			inst.current_state = name
			-- If you have a hard time tracking things down, change to xpcall.
			-- But otherwise, it's just more noisy.
			local status, msg = pcall(function()
				local state_data = state:Debug_GetDefaultDataForTools(inst, state_cleanup) or {}
				if state.onenterpre then
					state.onenterpre(inst, state_data)
				end
				if state.onenter then
					state.onenter(inst, state_data)
				end
			end, generic_error)
			if not status then
				data.failures[name] = msg
				print("CaptureAnimList:", name, msg)
			end
		end
	end
	for key,val in pairs(inst.sg.mem) do
		if EntityScript.is_instance(val) and val:IsValid() then
			val:Remove()
		end
	end
	inst:Remove()
	return data
end

local function RenderAnimList(ui, panel, data)
	ui:TextWrapped("Lists the anims that seem to be used by StateGraph states to help track down missing animations. Heavily reliant on default_data_for_tools being setup for each state.\nNot exhaustive -- only checks anims played from onenter.")
	data.filter = ui:_FilterBar(data.filter, "##animlist_filter")
	ui:SameLineWithSpace()
	data.show_only_missing = ui:_Checkbox("Show Only Missing", data.show_only_missing)
	local title_color = WEBCOLORS.SKYBLUE
	ui:Columns(2)
	ui:TextColored(title_color, "Anim Name")
	ui:NextColumn()
	ui:TextColored(title_color, "State Name")
	ui:NextColumn()
	local function PickColor(is_okay)
		return is_okay and WEBCOLORS.WHITE or WEBCOLORS.YELLOW
	end
	local function MatchesFilter(name)
		return not data.filter or name:find(data.filter)
	end
	for anim_name,state_name in iterator.sorted_pairs(data.anims_required) do
		local has_anim = data.anims_found[anim_name:lower()]
		if (not data.show_only_missing or not has_anim)
			and (MatchesFilter(anim_name) or MatchesFilter(state_name))
		then
			local c = PickColor(has_anim)
			ui:TextColored(c, anim_name)
			ui:NextColumn()
			ui:Text(state_name)
			ui:NextColumn()
		end
	end
	for state_name,msg in iterator.sorted_pairs(data.failures) do
		if MatchesFilter(state_name) then
			-- These probably just need default_data_for_tools.
			ui:Text("<unknown>")
			if ui:IsItemHovered() then
				ui:SetTooltip(msg)
			end
			ui:NextColumn()
			ui:Text(state_name)
			ui:NextColumn()
		end
	end
	ui:Columns()
end

local function GetHunterId_Forced(inst)
	return inst.forced_hunter_id
end

local NetworkState = Enum{ "Default", "Local", "Remote" }
local function IsLocal_Forced(inst)
	return inst.forced_network_state == NetworkState.s.Local
end

function DebugPlayer:RenderPanel( ui, panel )

	local debug_player = ConsoleCommandPlayer()
	if debug_player ~= self.inst then
		ui:Value("ConsoleCommandPlayer", debug_player)
		if self.autoselect or ui:Button("Select", nil, nil, debug_player) then
			TheLog.ch.Player:printf("Changing DebugPlayer target '%s' -> '%s'", self.inst, debug_player)
			self.inst = debug_player
		end
		ui:SameLineWithSpace()
		if not self.autoselect
			and debug_player
			and ui:Button("Open in new Window")
		then
			TheFrontEnd:CreateDebugPanel(DebugNodes.DebugPlayer(debug_player))
		end
		ui:SameLineWithSpace()
	end
	self.autoselect = ui:_Checkbox("Autoselect Player", self.autoselect)
	ui:Separator()


	self.menu_param = self.inst

	if not self.inst then
		ui:TextColored(RGB(204, 255, 255), "No player")
		return
	end

	local c = self.inst.uicolor or WEBCOLORS.ORANGE
	DebugDraw.GroundCircle(self.inst:GetPosition(), nil, 1, c)
	ui:ColorButton("Player Indicator", c)
	ui:SameLineWithSpace()

	ui:Value("Hunter id", self.inst:GetHunterId())
	if AllPlayers[self.inst:GetHunterId()] ~= self.inst then
		ui:Value("AllPlayers index", lume.find(AllPlayers, self.inst))
	end
	ui:SameLineWithSpace()
	if ui:Button(ui.icon.playback_step_fwd) then
		local i = lume.find(AllPlayers, self.inst)
		self.inst = circular_index(AllPlayers, i + 1)
		self.autoselect = false
	end

	ui:Value("Network", self.inst:IsLocal() and "Local" or "Remote")

	if ui:Button("Debug Player Entity") then
		panel:PushNode(DebugNodes.DebugEntity(self.inst))
	end

	if ui:CollapsingHeader("Manipulate Player State") then
		ui:Indent()

		local forced_tip = "This is lua-only, so network may not apply these changes.  May break or behave differently from real multiplayer!\nCtrl-r to reset to normal player state."
		local changed, new_v = ui:SliderInt("Force Hunter Id", GetHunterId_Forced(self.inst) or -1, 1, MAX_PLAYER_COUNT)
		if changed then
			self.inst.forced_hunter_id = new_v
			self.inst.GetHunterId = GetHunterId_Forced
			self.inst:_SetSpawnInstigator(self.inst) -- some audio is setup here on spawn
		end
		ui:SetTooltipIfHovered(forced_tip)

		changed, new_v = ui:Enum("Force Player Local/Remote", self.inst.forced_network_state or NetworkState.s.Default, NetworkState)
		if changed then
			if new_v == NetworkState.s.Default then
				new_v = NetworkState.s.Local
			end
			self.inst.forced_network_state = new_v
			self.inst.IsLocal = IsLocal_Forced
			self.inst:_SetSpawnInstigator(self.inst) -- some audio is setup here on spawn
		end
		ui:SetTooltipIfHovered(forced_tip)

		ui:Unindent()
	end


	local combat = self.inst.components.combat

	if ui:Checkbox("God Mode", combat.godmode) then
		c_godmode(self.inst)
	end

	ui:Value("damage dealt x", combat.damagedealtmult:Get(), "%.2f")
	ui:Value("damage received x", combat.damagereceivedmult:Get(), "%.3f")

	local changed, new_v = ui:SliderInt( "Health", self.inst.components.health.current, 0, self.inst.components.health.max )
	if changed then
		local percent = new_v / self.inst.components.health.max
		self.inst.components.health:SetPercent(percent)
	end

	local inventoryhoard = self.inst.components.inventoryhoard
	ui:Value("Konjur", inventoryhoard:GetStackableCount(Consumable.Items.MATERIALS.konjur))
	ui:Value("glitz", inventoryhoard:GetStackableCount(Consumable.Items.MATERIALS.glitz))
	local multiplier = ui:PickValueMultiplier(1, 10, 100)
	if ui:Button(ui.icon.arrow_down .." currency") then
		c_currency(-1 * multiplier)
	end
	ui:SameLineWithSpace()
	if ui:Button(ui.icon.arrow_up .." currency") then
		c_currency(1 * multiplier)
	end

	if ui:Button("Refill Potion") then
		local player = GetDebugPlayer()
		if player then 
			player.components.potiondrinker:InitializePotions()
		end
	end

	if ui:Button("Upgrade All Powers") then
		c_upgradepower(nil, self.inst)
	end


	if ui:CollapsingHeader("Anim List: ".. (self.anim_list and self.anim_list.sg_name or self.inst.sg.sg.name)) then
		if self.anim_list then
			if ui:Button("Load ".. self.inst.sg.sg.name .."##anim_list") then
				self.anim_list = nil
			else
				RenderAnimList(ui, panel, self.anim_list)
			end
		else
			self.anim_list = CaptureAnimList(self.inst)
		end
	end
end

DebugNodes.DebugPlayer = DebugPlayer

return DebugPlayer
