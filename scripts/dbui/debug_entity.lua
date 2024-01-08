local DebugNodes = require "dbui.debug_nodes"
local iterator = require "util.iterator"
local lume = require "util.lume"
require "consolecommands"
require "constants"

local DebugEntity = Class(DebugNodes.DebugNode, function(self, inst)
	DebugNodes.DebugNode._ctor(self, "Debug Entity")
	assert(not inst or inst.IsValid, "inst doesn't look like an entity.")
	self.inst = inst
	self.autoselect = inst == nil
	self.component_filter = nil
	self.animlists_cfg = {
		play_on_click = true,
		sort = true,
	}

	self.state_cleanup = {
		spawned = {},
		cb = {},
	}
end)

DebugEntity.PANEL_WIDTH = 600
DebugEntity.PANEL_HEIGHT = 600

DebugEntity.RenderAnimStateCurrentAnim = function(ui, animstate)
	if not animstate then
		return
	end

	-- If no anim is playing, current_anim_name is nil and some
	-- AnimState functions will crash.
	local current_anim_name = animstate:GetCurrentAnimationName()
	if ui:CollapsingHeader("Current Anim") and current_anim_name then
		local anim_info = ("Frame %02d/%02d of %s"):format(
			animstate:GetCurrentAnimationFrame(),
			animstate:GetCurrentAnimationNumFrames(),
			current_anim_name)
		ui:Text(anim_info)
		local progress = animstate:GetCurrentAnimationTime() / animstate:GetCurrentAnimationLength()
		ui:ProgressBar(progress)
		ui:SameLine(45)
		ui:TextColored(WEBCOLORS.WHITE, ("%.0f%% Complete"):format(progress * 100))
	end
	return current_anim_name
end

function DebugEntity.DrawAnimList(ui, animstate, getter, cfg)
	cfg = cfg or {
		play_on_click = true,
		sort = true,
	}
	local fn = animstate["Get".. getter]
	local t = fn(animstate)
	if cfg.sort then
		table.sort(t)
	end
	local clicked, idx = ui:ListBox(("%s\n%i items"):format(getter, #t), t, 1)
	if cfg.play_on_click and clicked then
		local anim = t[idx]
		TheLog.ch.Cheat:print("DebugEntity playing animation:", anim)
		animstate:PlayAnimation(anim)
	end
	if ui:Button("Copy List##".. getter) then
		ui:SetClipboardText(table.inspect(t))
	end
	return clicked, idx and t[idx]
end

DebugEntity.RenderStateGraph = function( ui, panel, sg )
	ui:Columns(2)

	ui:Text("Name")
	ui:NextColumn()
	ui:Text(sg.name)
	ui:NextColumn()

	ui:Text("Current State")
	ui:NextColumn()
	ui:Text(sg.current)
	ui:NextColumn()

	ui:Text("Embellish Name")
	ui:NextColumn()
	ui:Text(sg.embellish_name)
	ui:NextColumn()

	ui:Text("Ticks")
	ui:NextColumn()
	ui:Text(sg.ticks)
	ui:NextColumn()

	-- always draw because it causes flickering of table entries due to hitstop
	-- if sg.paused then
	ui:Text("Pause Reason")
	ui:NextColumn()
	ui:Text(sg.paused or "(not paused)")
	ui:NextColumn()
	-- end

	ui:Text("Tags")
	ui:NextColumn()
	ui:Text(sg.tags and table.concat(table.getkeys(sg.tags), ", " ) or "(no tags)")
	ui:NextColumn()

	ui:Text("Can Take Control")
	ui:NextColumn()
	ui:Text(sg.cantakecontrol and "true" or "false")
	ui:NextColumn()

	if sg.is_transferable then
		ui:Text("Can Take Control by Knockback")
		ui:NextColumn()
		ui:Text(sg.cantakecontrolbyknockback and "true" or "false")
		ui:NextColumn()

		ui:Text("Can Take Control by Knockdown")
		ui:NextColumn()
		ui:Text(sg.cantakecontrolbyknockdown and "true" or "false")
		ui:NextColumn()

		ui:Text("Remote State")
		ui:NextColumn()
		ui:Text(SGRegistry:HasData(sg.name) and (sg.remote_state or "n/a: local") or "SGRegistry:AddData needed")
		ui:NextColumn()

		ui:Text("Remote Ticks in State")
		ui:NextColumn()
		local ticks_text
		if not SGRegistry:HasData(sg.name) then
			ticks_text = "SGRegistry:AddData needed"
		elseif not SGRegistry:HasHint(StateGraphRegistry.Hints.SerializeTicksInState) then
			ticks_text = "SerializeTicksInState hint needed"
		elseif not sg.remote_ticksinstate then
			ticks_text = "n/a: local"
		else
			ticks_text = tostring(sg.remote_ticksinstate)
		end
		ui:Text(ticks_text)
		ui:NextColumn()

		ui:Text("Remote Knockdown Idle")
		ui:NextColumn()
		ui:Text(sg.remote_knockdown_idle and "true" or "false")
		ui:NextColumn()

		ui:Text("Remote Hit")
		ui:NextColumn()
		ui:Text(sg.remote_hit and "true" or "false")
		ui:NextColumn()

		ui:Text("Remote Dead")
		ui:NextColumn()
		ui:Text(sg.remote_dead and "true" or "false")
		ui:NextColumn()
	end

	ui:Columns()

	if ui:TreeNode("Remote Attack Hold") then
		ui:Columns(2)
		ui:Text("Remote Attack Hold")
		ui:NextColumn()
		ui:Text(sg.remote_attack_hold and "true" or "false")
		ui:NextColumn()

		ui:Text("Remote Attack Hold Ticks")
		ui:NextColumn()
		ui:Text(tostring(sg.remote_attack_hold_ticks))
		ui:NextColumn()

		ui:Text("Remote Attack Hold ID")
		ui:NextColumn()
		ui:Text(sg.remote_attack_hold_id)
		ui:NextColumn()

		ui:Columns()
		ui:TreePop()
	end

	if ui:TreeNode("sg.statemem") then
		panel:AppendKeyValues(ui, sg.statemem)
		ui:TreePop()
	end
end

local function SpawnSymbolMarker()
	TheSim:LoadPrefabs({"debug_draggable"})
	local inst = SpawnPrefab("debug_draggable")
	inst.entity:AddFollower()
	inst.AnimState:SetOrientation(ANIM_ORIENTATION.BillBoard)
	inst.AnimState:SetMultColor(table.unpack(WEBCOLORS.BLUE))
	-- Seems this scale is ignored because we're using followers.
	local s = 0.3
	inst.AnimState:SetScale(s, s)
	return inst
end

local function PushEvent_Logged(inst, event, data)
	local info = {
		tick = TheSim:GetTick(),
		name = event,
		data = data,
	}
	local add_callstack = inst._eventlog.capture_callstacks
	if inst._eventlog.pause_on_event_received == event then
		TheSim:ToggleDebugPause()
		add_callstack = true
	end
	if add_callstack then
		info.callstack = debug.traceback(("DebugEntity: '%s' received event '%s'"):format(inst, event))
	end
	inst._eventlog:Add(info)
	inst:_PushEvent_Vanilla(event, data)
end

local function WatchEvents(inst)
	if inst._PushEvent_Vanilla then
		return
	end
	inst._PushEvent_Vanilla = inst.PushEvent
	inst._eventlog = RingBuffer(1000)
	inst.PushEvent = PushEvent_Logged
end

local function ClearEventLog(inst)
	if not inst._eventlog then
		return
	end
	inst._eventlog:Clear()
	inst._eventlog = nil
end

local function UnwatchEvents(inst)
	if not inst._PushEvent_Vanilla then
		return
	end
	inst.PushEvent = inst._PushEvent_Vanilla
	inst._PushEvent_Vanilla = nil
end

local sg_debug_table = {}
function DebugEntity:RenderPanel( ui, panel )

	if self.inst and not self.inst:IsValid() then
		ui:TextColored(WEBCOLORS.YELLOW, "Entity is not valid! (Something called Remove() on it.)")
		ui:Text(self.inst:GetDebugString())
		self:AddFilteredAll(ui, panel, self.inst)
		return
	end

	self.name = self.inst and tostring( self.inst ) or "Debug Entity"

	local debug_entity = GetDebugEntity()

	ui:Text("Hover over an entity and press F1 to set Debug Entity")

	if debug_entity ~= self.inst then
		ui:Value("Debug Entity", debug_entity)
		if self.autoselect or ui:Button("Select", nil, nil, debug_entity) then
			self.inst = debug_entity
		end
		ui:SameLineWithSpace()
		if not self.autoselect
			and debug_entity
			and ui:Button("Open in new Window")
		then
			TheFrontEnd:CreateDebugPanel(DebugNodes.DebugEntity(debug_entity))
		end
		ui:SameLineWithSpace()
	end
	self.autoselect = ui:_Checkbox("Autoselect Debug Entity", self.autoselect)
	ui:Separator()

	if not self.inst then
		ui:TextColored( {0.8, 1.0, 0.0, 1.0}, "No entity selected" )
		return
	end

	ui:Value("Selected Entity", self.inst)

	ui:SameLineWithSpace()
	if ui:Button(ui.icon.copy.. "##name") then
		ui:SetClipboardText(tostring(self.inst))
	end

	ui:SameLineWithSpace()
	ui:PushDisabledStyle()
	ui:Checkbox("Visible", self.inst:IsVisible())
	ui:PopDisabledStyle()

	if ui:Button("Teleport to") then
		c_goto( self.inst )
	end

	ui:SameLineWithSpace()
	if ui:Button("Kill") then
		if self.inst.components.health then
			self.inst.components.health:Kill()
		elseif self.inst.Remove then
			self.inst:Remove()
		end
		return -- since entity is likely now invalid
	end

	ui:SameLineWithSpace()
	local should_hide = self.inst:IsVisible()
	if ui:Button(should_hide and "Hide" or "Show") then
		if should_hide then
			self.inst:Hide()
		else
			self.inst:Show()
		end
	end

	ui:SameLineWithSpace()
	if ui:Button("Toggle Follow") then
		local target = self.inst
		if TheCamera:GetTarget() == target then
			target = TheFocalPoint
		end
		TheCamera:SetTarget(target)
		TheCamera:SetDistance(30)
	end

	ui:SameLineWithSpace()
	if self.inst ~= GetDebugEntity()
		and ui:Button("SetDebugEntity")
	then
		SetDebugEntity(self.inst)
	end
	ui:Dummy(0,0)


	if self.inst.entity:GetParent()
		and ui:CollapsingHeader("Ancestors")
	then
		ui:Indent()
		ui:Selectable(tostring(self.inst) .." (self)", false)
		local p = self.inst.entity:GetParent()
		while p do
			if ui:Selectable(tostring(p), false) then
				panel:PushNode(DebugNodes.DebugEntity(p))
			end
			p = p.entity:GetParent()
		end
		ui:Unindent()
	end

	if ui:CollapsingHeader("Component List") then

		self.component_filter = ui:_FilterBar(self.component_filter, nil, "Filter components...")

		ui:Columns(2, "components")

		ui:Text( "Components" )
		ui:NextColumn()

		ui:Separator()

		for k, v in iterator.sorted_pairs(self.inst.components) do
			if not self.component_filter or k:find(self.component_filter) then
				if ui:Selectable( tostring(k), false ) then
					local node = panel:PushDebugValue( v )
					node.debug_entity = self.inst
				end
			end
			ui:NextColumn()
		end

		ui:Columns(1)
	end

	local debug_string = self.inst.entity:GetDebugString()

	if ui:CollapsingHeader("Tags") then
		local tags = string.match( debug_string, "Tags: ([%w_ ]+)\n.*")
		if tags then
			local tag_list = {}
			for tag in string.gmatch( tags, "([%w_]+)") do
				table.insert( tag_list, tag )
			end

			table.sort( tag_list )

			for k, v in pairs(tag_list) do
				ui:Text(v)
			end
		else
			ui:Text("No tags")
		end
	end

	if ui:CollapsingHeader("Received Events") then
		self.eventopts = self.eventopts or {}
		local log = self.inst._eventlog
		local is_watching = self.inst._PushEvent_Vanilla
		local prefix = is_watching and "Stop" or "Start"
		if ui:Button(prefix .." Watching") then
			if is_watching then
				UnwatchEvents(self.inst)
			else
				WatchEvents(self.inst)
			end
		end
		if ui:IsItemHovered() then
			ui:SetTooltip("Shows events *received* by this entity via PushEvent.")
		end
		ui:SameLineWithSpace()
		if ui:Button("Clear Eventlog", nil, nil, log == nil) then
			UnwatchEvents(self.inst)
			ClearEventLog(self.inst)
		end
		self.eventopts.show_reverse = ui:_Checkbox("Show newest first", self.eventopts.show_reverse)
		if ui:IsItemHovered() then
			ui:SetTooltip("Useful for seeing events while you play.")
		end
		ui:SameLineWithSpace()
		self.eventopts.capture_callstacks = ui:_Checkbox("Capture callstacks", self.eventopts.capture_callstacks)
		if ui:IsItemHovered() then
			ui:SetTooltip("Can make game slow. If disabled, we only capture Pause on Receive events.")
		end
		self.eventopts.filter = ui:_InputTextWithHint("##eventfilter", "Filter...", self.eventopts.filter)
		ui:SameLineWithSpace()
		if ui:Button(ui.icon.remove .."##filter", ui.icon.width) then
			self.eventopts.filter = nil
		end
		if log then
			log.pause_on_event_received = ui:_InputTextWithHint("##eventpause", "Pause on Receive...", log.pause_on_event_received)
			log.capture_callstacks = self.eventopts.capture_callstacks
			if ui:IsItemHovered() then
				ui:SetTooltipMultiline({
					"Debug pause when this entity receives this event.",
					"(Like pressing Home.)",
					"Requires event exact name match (unlike filter).",
				})
			end
			ui:SameLineWithSpace()
			if ui:Button(ui.icon.remove .."##pause", ui.icon.width) then
				log.pause_on_event_received = nil
			end
			ui:SameLineWithSpace()
			local play_label = TheSim:IsDebugPaused() and ui.icon.playback_play or ui.icon.playback_pause
			if ui:Button(play_label, ui.icon.width) then
				TheSim:ToggleDebugPause()
			end
			ui:SameLineWithSpace()
			if ui:Button(ui.icon.playback_step_fwd, ui.icon.width) then
				-- Step eventually crashes if game isn't already paused.
				if TheSim:IsDebugPaused() then
					TheSim:Step()
				else
					TheSim:ToggleDebugPause()
				end
			end

			ui:Columns(4)
			for _,label in ipairs({"Tick", "Event Name", "Event Data", "Callstack",}) do
				ui:TextColored(self.colorscheme.header, label)
				ui:NextColumn()
			end
			local start,stop,step = 1,log.entries,1
			if self.eventopts.show_reverse then
				start,stop,step = log.entries,1,-1
			end
			for index=start,stop,step do
				local info = log:Get(index)
				if not self.eventopts.filter
					or info.name:find(self.eventopts.filter)
				then
					ui:Text(("%i"):format(info.tick))
					ui:NextColumn()

					if ui:Button(info.name .."##".. index) then
						ui:SetClipboardText(info.name)
						self.eventopts.filter = info.name
					end
					ui:NextColumn()

					if info.data then
						panel:AppendTable(ui, info.data, "event data##"..index)
					else
						-- Disabled button to match the height of AppendTable button.
						ui:Button("<no data>", nil, nil, true)
					end
					ui:NextColumn()

					if info.callstack then
						if ui:Button("Copy##callstack"..index) then
							ui:SetClipboardText(info.callstack)
						end
						ui:SameLineWithSpace()
						if ui:Button("View##callstack"..index) then
							panel:PushDebugValue(info.callstack)
						end
						if ui:IsItemHovered() then
							ui:SetTooltip(info.callstack)
						end
					end
					ui:NextColumn()
				end
			end
			ui:Columns()
		end
	end

	if self.inst.brain and ui:CollapsingHeader("Brain") then
		local is_brain_active = self.inst.brain.brain
		if ui:Button("Brain Debugger") then
			panel:PushNode( DebugNodes.DebugBrain( self.inst ) )
		end
		if ui:Checkbox("Enabled", is_brain_active) then
			local reason = "debug_entity"
			if is_brain_active then
				self.inst.brain:Pause(reason)
			else
				self.inst.brain:Resume(reason)
			end
		end
		ui:Text( self.inst:GetBrainString() )
	end

	if self.inst.sg and ui:CollapsingHeader("State Graph") then
		DebugEntity.RenderStateGraph(ui, panel, self.inst.sg:GetDebugTable(sg_debug_table))
		lume.clear(sg_debug_table)
		if ui:TreeNode("sg.mem") then
			panel:AppendKeyValues(ui, self.inst.sg.mem)
			ui:TreePop()
		end
		if ui:TreeNode("sg") then
			panel:AppendKeyValues(ui, self.inst.sg)
			ui:TreePop()
		end
		if ui:TreeNode("Jump To State") then
			ui:Text("Warning: Might crash the game")
			local names = lume.keys(self.inst.sg.sg.states)
			table.sort(names)
			for _,name in ipairs(names) do
				if ui:Button(name .."##sg states") then
					TheLog.ch.Cheat:printf("DebugEntity is jumping '%s' to state '%s'.", self.inst, name)
					local state = self.inst.sg.sg.states[name]
					local default_data_for_tools = state:Debug_GetDefaultDataForTools(self.inst, self.state_cleanup)
					self.inst.sg:GoToState(name, default_data_for_tools)
				end
			end
			ui:TreePop()
		end
	end

	if self.inst.DebugDrawEntity and ui:CollapsingHeader("Entity: ".. tostring(self.inst)) then
		self.inst:DebugDrawEntity(ui, panel, self.colorscheme)
	end

	if self.inst.AnimState and ui:CollapsingHeader("Component: AnimState") then
		ui:Indent() do
			if ui:Button("Edit Colors") then
				panel:PushNode(DebugNodes.ColorTransform(self.inst))
			end
			ui:SameLineWithSpace()
			if ui:Button("Watch Anims") then
				panel:PushNode(DebugNodes.DebugAnimation(self.inst))
			end

			local changed
			local s = self.inst.AnimState:GetScale()
			changed, s = ui:SliderFloat("Scale", s, 0.001, 10)
			if changed then
				self.inst.AnimState:SetScale(s, s)
			end

			local current_anim = DebugEntity.RenderAnimStateCurrentAnim(ui, self.inst.AnimState)
			if ui:Button("Restart Anim", nil, nil, not current_anim) then
				self.inst.AnimState:PlayAnimation(current_anim)
			end
			if ui:CollapsingHeader("Anim Info") and current_anim then
				self.animlists_cfg.sort = ui:_Checkbox("Sort", self.animlists_cfg.sort)
				-- PERF: Calling GetSymbolNames becomes slow when you have a follower.
				local clicked, symbol = DebugEntity.DrawAnimList(ui, self.inst.AnimState, "SymbolNames", {
						sort = self.animlists_cfg.sort,
						play_on_click = false,
					})
				ui:Value("Marked Symbol", self.symbol_marker and self.symbol_marker.symbol or "<None> Click to select")
				if clicked then
					print("Spawning symbol_marker on", symbol)
					self.symbol_marker = self.symbol_marker or SpawnSymbolMarker()
					self.symbol_marker.entity:SetParent(self.inst.entity)
					self.symbol_marker.Follower:FollowSymbol(self.inst.GUID, symbol)
					self.symbol_marker.symbol = symbol
				end
				if self.symbol_marker then
					-- Can't scale because it scales the parent too?!
					--~ s = self.symbol_marker.scale
					--~ s = ui:_SliderFloat("Scale", s or 1, 0.01, 10)
					--~ self.symbol_marker.AnimState:SetScale(s, s)
					--~ self.symbol_marker.scale = s

					-- Using GetSymbolPosition and drawing lags behind and
					-- doens't show when there are multiple of the same symbol.
					--~ local x,y,z = self.inst.AnimState:GetSymbolPosition(self.symbol_marker.symbol, Vector3.zero:unpack())
					--~ x,y = TheSim:WorldToScreenXY(x,y,z)
					--~ local color = WEBCOLORS.GREEN
					--~ ui:ScreenLine({x-10,y},{x+10,y}, color)
					--~ ui:ScreenLine({x,y-10},{x,y+10}, color)
					--~ ui:ScreenLine({x-7,y-7},{x+7,y+7}, color)
					--~ ui:ScreenLine({x-7,y+7},{x+7,y-7}, color)
				end
				if ui:Button("Remove symbol marker", nil, nil, self.symbol_marker == nil) then
					self.symbol_marker:Remove()
					self.symbol_marker = nil
				end
				ui:Separator()

				DebugEntity.DrawAnimList(ui, self.inst.AnimState, "CurrentBankAnimNames",  self.animlists_cfg)
				DebugEntity.DrawAnimList(ui, self.inst.AnimState, "AnimNamesFromAnimFile", self.animlists_cfg)
				DebugEntity.DrawAnimList(ui, self.inst.AnimState, "CurrentBankAnimFiles",  self.animlists_cfg)
			end
		end ui:Unindent()
	end

	if self.inst.Follower and ui:CollapsingHeader("Component: Follower") then
		ui:Indent() do
			self.follower_offset = self.follower_offset or Vector3()
			local limit = 1000
			if ui:DragVec3f("Offset", self.follower_offset, 0.1, -limit, limit) then
				self.inst.Follower:SetOffset(self.follower_offset:Get())
			end
			ui:Value("IsLeaderHidden", self.inst.Follower:IsLeaderHidden())
		end ui:Unindent()
	end

	if self.inst.Network and ui:CollapsingHeader("Component: Network") then
		ui:Indent() do
			ui:Value("IsLocal", self.inst:IsLocal())
			ui:Value("EntityID", self.inst.Network:GetEntityID())
			ui:Value("Lua State Size", self.inst.Network:GetLuaStateSize())
			ui:Value("Is In Limbo (C++)", self.inst.entity:IsInLimbo())
			ui:Value("Deserialize Counter", self.inst.Network:GetDeserializeCounter())
		end ui:Unindent()
	end

	local components = lume.filter(self.inst.components, "DebugDrawEntity", true)
	for cmp_name,cmp in iterator.sorted_pairs(components) do
		if ui:CollapsingHeader("Component: ".. cmp_name) then
			ui:Indent()
			ui:PushID(cmp_name)
			cmp:DebugDrawEntity(ui, panel, self.colorscheme)
			ui:PopID()
			ui:Unindent()
		end
	end

	if ui:CollapsingHeader("Debug String") then
		if ui:Button(ui.icon.copy.. "##DebugString") then
			ui:SetClipboardText(debug_string)
		end
		ui:Text(debug_string)
	end

	self:AddFilteredAll(ui, panel, self.inst)
end

function DebugEntity:OnDeactivate(panel)
	if self.symbol_marker then
		self.symbol_marker:Remove()
		self.symbol_marker = nil
	end
	if self.inst then
		UnwatchEvents(self.inst)
		-- Don't clear the log or going into event data will clear the list.
		--~ ClearEventLog(self.inst)
	end
end

DebugNodes.DebugEntity = DebugEntity

return DebugEntity
