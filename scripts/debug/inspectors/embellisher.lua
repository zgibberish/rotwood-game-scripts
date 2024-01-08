-- editor for adding events to stategraphs.

local DebugDraw = require "util.debugdraw"
local DebugNodes = require "dbui.debug_nodes"
local DebugSettings = require "debug.inspectors.debugsettings"
local Equipment = require "defs.equipment"
local EventFuncEditor = require "debug.inspectors.eventfunceditor"
local PrefabEditorBase = require "debug.inspectors.prefabeditorbase"
local kstring = require "util.kstring"
local lume = require "util.lume"
require "mathutil"

eventfuncs = require "eventfuncs"


--Make sure our util functions are loaded
require "prefabs.fx_autogen"

local _static = PrefabEditorBase.MakeStaticData("stategraph_autogen_data")

local actionLabels

local w_ok = 70
local w_cancel = 70

local function FrameNumber(ui, event)
	local changed, frame = ui:DragInt("Frame", event.frame, 1, 0, 99999)
	if changed then
		event.frame = math.clamp(math.floor(frame), 0, 99999)
	end
end

local function GetActionLabels()
	if not actionLabels then
		actionLabels = {
			actions = {},
			pretty = {},
		}
		for _, v in pairs(eventfuncs) do
			if not v.required_editor
				or v.required_editor == "embellisher"
			then
				table.insert(actionLabels.actions, v.name)
			end
		end
		table.sort(actionLabels.actions)
		for _, action in ipairs(actionLabels.actions) do
			table.insert(actionLabels.pretty, eventfuncs[action].nicename)
		end
	end
	return actionLabels.actions, actionLabels.pretty
end

local function ActionDropDown(self, ui, force_open_dropdown)
	local actionlabels, prettyactions = GetActionLabels()
	for i, v in pairs(actionlabels) do
		if v == self.name then
			self.actionindex = i
		end
	end
	assert(self.actionindex)

	local newidx = ui:_Combo("Action", self.actionindex, prettyactions, nil, force_open_dropdown)
	ui:Spacing()
	ui:Separator()
	ui:Spacing()
	if newidx ~= self.actionindex then
		-- we need to change our current action
		return actionlabels[newidx]
	end
end

local HitBoxShape =
{
	Beam = 0,
	Circle = 1,
}

local Embellisher = Class(PrefabEditorBase, function(self)
	PrefabEditorBase._ctor(self, _static)

	self.name = "Embellisher"
	self.editor = EventFuncEditor(self)

	self:WantHandle()

	self.prefab_label = "Preset"
	self.test_label = "Spawn"

	self.edit_options = DebugSettings("embellisher.edit_options")
		:Option("spawnpaused", true)
		:Option("showhitbox")
		:Option("blockexitstate")
		:Option("enablebrain")
		:Option("disablephysics", false)
		:Option("dontdespawn")
		:Option("lockposition", true)
		:Option("prefabname", "")
		:Option("selectedstate", "")
		:Option("weapon_idx", nil)

	self:LoadLastSelectedPrefab("embellisher")

	-- empty set until we actually pick a prefab
	if self.prefabname then
		self.embellishments = nil
	else
		self.embellishments = {}
	end

	self.pushedEvents = {}
	-- to force spawn a handle on open
	if GetDebugPlayer() then
		PrefabEditorBase.Test(self)
	end
	self.hotReloadCallback = RegisterHotReloadCallback(function(isPreHotReload)
		self:HotReload(isPreHotReload)
	end)

	-- data for test hitbox
	self.testhitbox =
	{
		enabled = false,
		shape = HitBoxShape.Beam,

		-- Beam parameters
		beam =
		{
			start_dist = 0,
			end_dist = 1,
			thickness = 1,
			zoffset = 0,
		},

		-- Circle parameters
		circle =
		{
			distance = 0,
			rotation = 0,
			radius = 1,
			zoffset = 0,
		},
	}
end)

Embellisher.PANEL_WIDTH = 660
Embellisher.PANEL_HEIGHT = 990

Embellisher.TAG_EXPLAIN = [[
A tag on the anim indicates 'I may want to do something here, this could be
interesting for sound, fx, etc whereas doing it directly in the StateGraph (in
lua or Embellisher's Timeline) it means "I want this sound on this stategraph
frame" (*not* the same as animation frame both due to loops and because
animations are not inherently tied to states).

Tag on Anim:
* Play this sound whenever this ANIMATION plays
* i.e. unsheathe -- that anim can be used in 500 different states, but we don't
  want to have to tag all of those states.

Tag on StateGraph:
* I don't care what animation is playing, play a sound when this STATE is active
* i.e. running -- it's one state that plays 500 different animations -- we
  don't want to have to tag every single anim for every single weapon forever.
]]
Embellisher.MENU_BINDINGS = {
	{
		name = "Help",
		bindings = {
			{
				name = "About Embellisher",
				fn = function(params)
					params.panel:PushNode(DebugNodes.DebugValue([[
The Embellisher lets you add all kinds of actions events on specific frames of
a state or in response to events. Many events are fired by game logic, but you
can also fire events when animations hit specific frames using the AnimTagger.

StateGraphs are written in lua (files prefixed with sg_) and can be debugged
with History and Debug Entity.

The Embellisher has three main sections:
* State Timeline
* State Events
* StateGraph Events

State Timeline fires actions at a certain animframe number for the entity's state.
State Events fires actions when an event is received in that state.
StateGraph Events fires actions when an event is received in *any* state.

]] .. Embellisher.TAG_EXPLAIN))
				end,
			},
		},
	},
}

function Embellisher:PreSave(data)
	embellishutil.DeAnnotateEmbellishments(data)
end

function Embellisher:PostSave(data)
	embellishutil.AnnotateEmbellishments(data)
end

local function MakeSafeGoToState(editor)
	local function SafeGoToState(self, name, data)
		editor.lua_error = nil
		local status, msg = pcall(function()
			StateGraphInstance.GoToState(self, name, data)
		end)
		if not status then
			TheLog.ch.Embellisher:print("Error - " .. msg)
			editor.lua_error = msg
		end
	end
	return SafeGoToState
end

function Embellisher:HotReload(isPreHotReload)
	if not isPreHotReload then
		return
	end
	if self.testprefab and self.testprefab.sg then
		local sg = self.testprefab.sg.sg
		if not sg.autoGenerated then
			local currentstate = self.testprefab.sg.currentstate.name
			local default_data_for_tools = self.testprefab.sg.currentstate:Debug_GetDefaultDataForTools(self.testprefab, self.editor.state_cleanup)
			self.testprefab:UncacheStateGraph()
			local sgname = sg.name
			self.testprefab:SetStateGraph(sgname)
			self.testprefab.sg.sg = deepcopy(self.testprefab.sg.sg)
			self:InitEmbellishments()
			local params = _static.data[self.prefabname]
			self:Embellish(params.events)
			if self.testprefab.sg and self.testprefab.sg.currentstate then
				self.testprefab.sg:GoToState(currentstate, default_data_for_tools)
			end
			if self.testprefab.sg then
				self.testprefab.sg.GoToState = MakeSafeGoToState(self)
				self:SafeUpdate()
			end
		end
	end
end

-- Generate the stategraph
function MakeAutogenStategraph(name)
	local events = {}

	local states = {
		State({
			name = "idle",
		}),
	}

	local sg = StateGraph(name, states, events, "idle")
	sg.autoGenerated = true
	return sg
end

local EventType = {
	Frame = 0,
	State = 1,
	StateGraph = 2,
}

function Embellisher:EditEvent(event, ui, prefab, eventtype)
	-- Copy and paste full event
	ui:Columns(1)
	local colw = ui:GetColumnWidth()
	ui:Columns(2, "", false)
	ui:SetColumnOffset(1, colw - 90)
	ui:NextColumn()
	if ui:SmallTooltipButton("Copy##fullevent", "Copy Full Event") then
		Embellisher.copypastefullevent = deepcopy(event)
	end
	local canpaste = Embellisher.copypastefullevent
	ui:SameLine()
	ui:Dummy(4, 0)
	ui:SameLine()
	if ui:SmallTooltipButton("Paste##fullevent", "Paste Full Event", not canpaste) then
		event.name = Embellisher.copypastefullevent.name
		event.frame = Embellisher.copypastefullevent.frame
		event.eventtype = Embellisher.copypastefullevent.eventtype
		event.param = deepcopy(Embellisher.copypastefullevent.param)
	end
	ui:Columns(1)


	local eventdef = eventfuncs[event.eventtype]

	if eventtype == EventType.Frame then
		FrameNumber(ui, event)
	else
		event.name = self.editor.eventnamer:EditReceivedEventName(ui, event.name)
	end
	local newaction = ActionDropDown(eventdef, ui, self.force_open_dropdown)
	self.force_open_dropdown = false
	if newaction then
		return newaction
	end

	if eventdef.edit then
		-- copy and paste event params
		ui:Columns(1)
		local colw = ui:GetColumnWidth()
		ui:Columns(2, "", false)
		ui:SetColumnOffset(1, colw - 90)
		ui:NextColumn()
		if ui:SmallTooltipButton("Copy##eventparams", "Copy Event Params") then
			self.copypasteevent = deepcopy(event)
		end
		local canpaste = self.copypasteevent and self.copypasteevent.eventtype == event.eventtype
		ui:SameLine()
		ui:Dummy(4, 0)
		ui:SameLine()
		if ui:SmallTooltipButton("Paste##eventparams", "Paste Event Params", not canpaste) then
			event.param = deepcopy(self.copypasteevent.param)
		end
		ui:Columns(1)

		if self.testprefab then
			eventdef:edit(self.editor, ui, event, self.testprefab)
		end
	end
	if eventtype == EventType.State then
		ui:Spacing()
		ui:Separator()
		ui:Spacing()
		event.param.fallthrough = ui:_Checkbox("Fallthrough to StateGraph Event Handlers", event.param.fallthrough) or nil
		if ui:IsItemHovered() then
			ui:SetTooltipMultiline({
					"By default, the existence of state handlers skip stategraph handlers from running.",
					"StateGraph handlers apply across the whole SG, so they're likely",
					"not relevant when states have their own handling for the event.",
					"",
					"Check to allow sg event handlers to handle this event.",
					"All *state* event handlers always run regardless.",
				})
		end
	end

	if eventdef.testbtn
		and self.testprefab
		and ui:Button("Test Event")
	then
		eventdef.func(self.testprefab, event.param)
		self.editor:RequestSeeWorld(true)
	end
end

function Embellisher:EditEventOkButton(ui, event, testprefab, requires_name)
	local eventdef = eventfuncs[event.eventtype]
	local is_valid = eventdef:isvalid(self.editor, event, testprefab)
	local invalid_reason = nil
	if requires_name and not event.name then
		invalid_reason = "Missing event name."
	elseif not is_valid then
		invalid_reason = "Invalid event! Please fill in missing data above."
	end
	local pressed = ui:Button("OK", w_ok, nil, invalid_reason)
	if invalid_reason and ui:IsItemHovered() then
		ui:SetTooltip(invalid_reason)
	end
	return pressed
end

function Embellisher:VizEvent(event, ui)
	return self.editor:DrawViz(ui, event, self.testprefab)
end

function Embellisher:OnRevert(params)
	if params then
		-- params have already been reset
		self:Embellish(params.events)
	end
	-- else we're reverting the addition of a new thing.
end

function Embellisher:IsExistingPrefabName(prefab)
	--~ local grouplist, groupmap = self:GetGroupList()
	return self.static.data[prefab] and true
end

function Embellisher:OnPrefabDropdownChanged(prefabname)
	Embellisher._base.OnPrefabDropdownChanged(self, prefabname)

	self.animbank_selection = nil
	self:DespawnPrefab()
	self.embellishments = nil
	self:InitEmbellishments()
end

function Embellisher:OnDeactivate()
	Embellisher._base.OnDeactivate(self)
	self:DespawnPrefab()
	UnregisterHotReloadCallback(self.hotReloadCallback)
end

function Embellisher:SetupHandle(handle)
	handle.move_fx = function(inst)
		local is_dragging = inst.components.prop:IsDragging()
		if self.testprefab then
			if is_dragging or self.edit_options.lockposition then
				self.testprefab.Transform:SetPosition(inst.Transform:GetWorldPosition())
			end
			if is_dragging ~= inst.was_dragging then
				if self.testprefab then
					self.editor:RemoveAllParticles()
					self.editor:RemoveAllFX()
				end
			end
		end
		inst.was_dragging = is_dragging
	end

	handle:DoPeriodicTask(0, handle.move_fx)
end

function Embellisher:DespawnPrefab()
	if self.testprefab then
		self.forceRemove = true
		self.testprefab:Remove()
		self.testprefab = nil
		self.forceRemove = false
	end
end

-- Calling with nill will remove embellishments
function Embellisher:Embellish(events)
	local preset = _static.data[self.prefabname]
	embellishutil.SortStateGraphEmbellishments()
	local embellishments = {}
	for i, v in pairs(self.embellishments) do
		if v then
			table.insert(embellishments, i)
		end
	end
	if self.testprefab and self.testprefab.sg then
		self.testprefab.sg:Embellish(embellishments, true, self.editor)
	end
	self:CheckHasSound(preset)
end

function Embellisher:InitEmbellishments()
	if not self.embellishments then
		self.embellishments = {}
		if self.prefabname then
			self.embellishments[self.prefabname] = true
			local preset = _static.data[self.prefabname]
			if preset then
				local prefabname = preset.prefab
				local def = STATEGRAPH_EMBELLISHMENTS[prefabname] or {}
				for i, v in pairs(def.embellishments or {}) do
					if v == self.prefabname then
						self.embellishments[v] = true
					else
						local preset = _static.data[v]
						if preset and preset.isfinal then
							self.embellishments[v] = true
						else
							self.embellishments[v] = false
						end
					end
				end
			end
		end
	end
end

function Embellisher:EmbellisherScriptError(msg)
	TheLog.ch.Embellisher:print("Error - " .. msg)
	self.lua_error = msg
	self.testprefab.sg.updatingstate = false
end

function Embellisher:SafeUpdate()
	self.testprefab.sg.Update = function(this, currenttick)
		local retval
		local status, msg = pcall(function()
			retval = StateGraphInstance.Update(this, currenttick)
		end)
		if not status then
			self:EmbellisherScriptError(msg)
		end
		return retval
	end
end

function Embellisher:DisablePhysics(inst, disable)
	d_disablephysics(inst, disable)
end

function Embellisher:EventPushed(name)
	if self.testprefab then
		if name then
			self.pushedEvents[name] = 1
		end
	end
end

function Embellisher:WrapPushEvent()
	local embellisher = self
	local function WrappedPushEvent(self, name, data)
		embellisher:EventPushed(name)
		StateGraphInstance.PushEvent(self, name, data)
	end
	self.testprefab.sg.PushEvent = WrappedPushEvent
end

function Embellisher:WrapOnUpdates()
	local inst = self.testprefab
	for i,v in pairs(inst.components) do
		local onUpdate = v.OnUpdate
		if onUpdate then
			v.OnUpdate = function(...)
				if self.allow_OnUpdates then
					onUpdate(...)
				end
			end
		end
	end
end

function Embellisher:AllowOnUpdates(enabled)
	self.allow_OnUpdates = enabled
	if enabled then
		self:ClearCachedHitBoxes()
	end
end

function Embellisher:Test(prefab, params)
	self.lua_error = nil

	if params.prefab == nil then
		return
	end
	Embellisher._base.Test(self, prefab, params)
	self:DespawnPrefab()
	ExecuteConsoleCommand("d_allprefabs()")

	local prefab = type(params.prefab == "table") and params.prefab[self.animbank_selection or 1] or params.prefab
	TheSim:LoadPrefabs({ prefab })

	-- This code (and the uninstall right after spawn) is commented out for now. It attempts to prevent a despawn from the
	-- prefab constructor, but we really should not do that.
	-- If we ever want something to despawn itself right after construction it should use spawnutil.FlagForRemoval(entity) instead
--[[
	-- If we don't want to despawn we have to intercept the remove handler. Since this is stored in a closure we have to do shitty things
	local oldEntityRemove = EntityScript.Remove
	if self.edit_options.dontdespawn then
		local editor = self
		EntityScript.Remove = function(self)
			if editor.forceRemove then
				oldEntityRemove(self)
			else
				if self.prefab == prefab then -- it's as close as we can get...
					editor.needrespawn = true
				end
			end
		end
	end
]]


	-- Force a soundEmitter on this prefab, so that it won't be added afterwards. We need it in case sound events are added
	-- if sounds events are indeed added it will be added on spawn of the prefab
	-- (new entities may have been spoawned and we can't add it anymore at that point)
	local def = STATEGRAPH_EMBELLISHMENTS_FINAL[prefab]
	if not def then
		STATEGRAPH_EMBELLISHMENTS_FINAL[prefab] = {needSoundEmitter = true, embellishments = {}}
		self.testprefab = DebugSpawn(prefab)
		STATEGRAPH_EMBELLISHMENTS_FINAL[prefab] = nil
	else
		local backup = def.needSoundEmitter
		def.needSoundEmitter = true
		self.testprefab = DebugSpawn(prefab)
		def.needSoundEmitter = backup
	end

--[[
	EntityScript.Remove = oldEntityRemove
]]

	self.hitboxesvis = nil

	if self.testprefab then
		self:CaptureHitBox(true)
		self:WrapOnUpdates()
		self:AllowOnUpdates(true)
		self.testprefab.in_embellisher = true
		self.testprefab.persists = false

		if self.testprefab and self.testprefab.components.inventoryhoard then
			local inventoryhoard = self.testprefab.components.inventoryhoard
			local slot = Equipment.Slots.WEAPON
			local current = inventoryhoard:GetEquippedItem(slot)

			self.weapons = lume.sort(lume.keys(Equipment.Items.WEAPON))
			local cur_idx = self.edit_options.weapon_idx or lume.find(self.weapons, current and current.id) or 1
			self:SetWeapon(self.weapons[cur_idx])
		end

		SetDebugEntity(self.testprefab)

		if not self.testprefab.sg then
			self.testprefab.has_autogen_sg = true
			local sgname = self.testprefab.sgname_override or self.testprefab.prefab
			self.testprefab:SetStateGraph(self.testprefab.prefab, MakeAutogenStategraph(sgname))
		end

		self:WrapPushEvent()

		-- make a copy of the stategraph, that way we don't affect existing spawns
		if self.testprefab.sg then
			self.testprefab.sg.sg = deepcopy(self.testprefab.sg.sg)
		end

		self.testprefab.Transform:SetPosition(self.handle.Transform:GetWorldPosition())
		self.testprefab:ListenForEvent("onremove", function()
			self.testprefab = nil
			self.editor:RemoveAllParticles()
			self.editor:RemoveAllFX()
		end)

		if self.testprefab.brain then
			if not self.edit_options.enablebrain then
				self.testprefab.brain:Pause("SGEDitor")
			end
		end

		self:InitEmbellishments()
		self:Embellish(params.events)
		if self.edit_options.selectedstate and self.testprefab.sg:HasState(self.edit_options.selectedstate) then
			self:RestartState(self.edit_options.selectedstate)
		elseif self.testprefab.sg and self.testprefab.sg.currentstate then
			self.testprefab.sg:GoToState(self.testprefab.sg.currentstate.name)
		end
		if self.testprefab.sg then
			self.testprefab.sg.GoToState = MakeSafeGoToState(self)
			self:SafeUpdate()
		end

		if self.testprefab.OnEditorSpawn then
			self.testprefab:OnEditorSpawn(self)
		end
	end
	self.paused = self.edit_options.spawnpaused
	if self.paused then
		self:Pause()
	end
end

function Embellisher:SetDeltaTimeMultiplier(m)
	if self.testprefab.AnimState then
		self.testprefab.AnimState:SetDeltaTimeMultiplier(m)
	end
	self.editor:SetDeltaTimeMultiplier(m)
end

function Embellisher:ClearCachedHitBoxes()
	self.hitbox_cache = nil
end

function Embellisher:DrawHitBoxes()

	if self.testprefab and self.testprefab.HitBox then
		if self.hitbox_cache then
			local x, z = self.testprefab.Transform:GetWorldXZ()
			local arr = self.hitbox_cache or self.testprefab.HitBox:GetHitRects()
			for i, v in pairs(arr) do
				DebugDraw.GroundRect(x + v[1], z + v[2], x + v[3], z + v[4], BGCOLORS.CYAN)
			end
		end
	end
end

function Embellisher:Pause()
	if not self.testprefab then
		return
	end

	if self.testprefab.sg then
		self.testprefab.sg:Pause("SGEDitor")
	end
	if self.testprefab.Physics then
		self.testprefab.Physics:Pause()
	end
	if self.testprefab.brain then
		self.testprefab.brain:Pause("SGEDitor")
	end
	self:SetDeltaTimeMultiplier(0)
end

function Embellisher:Resume()
	if self.testprefab and self.testprefab.sg then
		self.testprefab.sg:Resume("SGEDitor")
	end
	if self.testprefab.Physics then
		self.testprefab.Physics:Resume()
	end
	if self.testprefab.brain and self.edit_options.enablebrain then
		self.testprefab.brain:Resume("SGEDitor")
	end

	self:SetDeltaTimeMultiplier(1)
end

local function GotoState_BlockedExitState(self, tostate, params)
	local curstate = self.currentstate and self.currentstate.name or ""
	if curstate ~= tostate then
		TheLog.ch.Embellisher:print("blocked exit to state", tostate)
	else
		local SafeGoToState = MakeSafeGoToState(self)
		SafeGoToState(self, tostate, params)
	end
end

function Embellisher:RestartState(statename)
	self.editor:RemoveAllParticles()
	self.editor:RemoveAllFX()

	if self.testprefab then
		local state = self.testprefab.sg.sg.states[statename]
		local default_data_for_tools = state:Debug_GetDefaultDataForTools(self.testprefab, self.editor.state_cleanup)
		local SafeGoToState = MakeSafeGoToState(self)
		SafeGoToState(self.testprefab.sg, statename, default_data_for_tools)
	end
	self:AllowOnUpdates(true)
end

function Embellisher:RunToFrame(frame)
	self.testprefab.sg:GoToState(self.testprefab.sg.currentstate.name)
	self.paused = false
	self.wantsruntoframe = true
	self.testprefab.Transform:SetPosition(self.handle.Transform:GetWorldPosition())
	self:AllowOnUpdates(true)
end



function Embellisher:PauseButtons(ui)

	self.runtoframe = self.runtoframe or 1

	if ui:Button("Restart##restart_current_state") then
		if self.testprefab and self.testprefab.sg then
			self:RestartState(self.testprefab.sg.currentstate.name)
			self.wantsruntoframe = false
			self.testprefab.Transform:SetPosition(self.handle.Transform:GetWorldPosition())
		end
	end
	if ui:IsItemHovered() then
		ui:SetTooltip("Restart current active state (" .. self.testprefab.sg.currentstate.name .. ")")
	end

	ui:SameLineWithSpace(20)

	if ui:Button("Run to frame") then
		--self.looptoframe = math.clamp(math.floor(frame), 1, 99999)
		if self.testprefab and self.testprefab.sg then
			self:RunToFrame(self.runtoframe)
		end
	end
	ui:SameLineWithSpace(2)

	if ui:SmallButton(ui.icon.playback_step_back) then
		self.runtoframe = self.runtoframe - 1
	end

	ui:SameLineWithSpace(1)

	ui:PushItemWidth(100)
	local num_frames = self.testprefab and self.testprefab.AnimState and self.testprefab.AnimState:GetCurrentAnimationNumFrames() or 1
	local changed, frame = ui:SliderInt("##runttoframe_slider", self.runtoframe or 1, 1, num_frames)
	if ui:IsItemHovered() then
		ui:SetTooltip("Selects frame for 'Run to Frame'")
	end
	if changed then
		self.runtoframe = math.clamp(math.floor(frame), 1, num_frames)
		self:RunToFrame(self.runtoframe)
	end
	ui:PopItemWidth()

	ui:SameLineWithSpace(1)

	if ui:SmallButton(ui.icon.playback_step_fwd) then
		self.runtoframe = self.runtoframe + 1
	end

	ui:SameLineWithSpace(20)

	if ui:Button(self.paused and ui.icon.playback_play or ui.icon.playback_pause, 60) then
		self.paused = not self.paused
		if not self.paused then
			self:AllowOnUpdates(true)
		end
	end
	if self.currentstepframe then
		if self.testprefab then
			if self.testprefab.sg:GetAnimFramesInState() ~= self.currentstepframe then
				self.currentstepframe = nil
				self.paused = true
				self:AllowOnUpdates(false)
			end
		end
	end
	if self.runtoframe and self.wantsruntoframe then
		if self.testprefab then
			if self.testprefab.AnimState:GetCurrentAnimationFrame() == self.runtoframe then
				self.wantsruntoframe = false
				self.paused = true
				self:AllowOnUpdates(false)
			else
				self:ClearCachedHitBoxes()
			end
		end
	end

	ui:SameLineWithSpace(4)
	if ui:Button("Step") then
		-- step doesn't run to curframe + 1, but to the next frame that isn't currentframe (cuz we might be jumping to another anim)
		self.currentstepframe = self.testprefab.sg:GetAnimFramesInState()
		self:AllowOnUpdates(true)
		self.paused = false
	end

	-- run to frame

	if self.testprefab then
		if self.paused then
			self:Pause()
		else
			self:Resume()
		end
	end
end

function Embellisher:CaptureHitBox(capture)

	if capture then
		if self.testprefab.HitBox and not self.testprefab.HitBox.UnwrapNativeComponent then
			print("self.testprefab.HitBox.FindHitBoxesInRect",self.testprefab.HitBox.FindHitBoxesInRect)
			self.testprefab:Debug_WrapNativeComponent("HitBox")
			local editor = self
			self.testprefab.HitBox.FindHitBoxesInRect =
				function(self, x0, z0, x1, z1, maxsize)
					self._original:FindHitBoxesInRect(x0, z0, x1, z1, maxsize)
					local x, z = editor.testprefab.Transform:GetWorldXZ()
					editor.hitbox_cache = editor.hitbox_cache or {}
					local arr = {x0 - x, z0 - z, x1 - x, z1 - z}
					table.insert(editor.hitbox_cache, arr)
				end
		end
	else
		if self.testprefab.HitBox and self.testprefab.HitBox.UnwrapNativeComponent then
			self.testprefab.HitBox.UnwrapNativeComponent()
		end
	end
end

function Embellisher:StateGraphInfo(ui, active_state)
	if not self.testprefab then
		ui:Text("Click 'Spawn' to begin.")
		return
	elseif self.testprefab.AnimState and not self.testprefab.AnimState:GetCurrentAnimationFile() then
		self:WarningMsg(ui, "Invalid StateGraph", ("State '%s' is playing an invalid/missing animation."):format(active_state))
		return
	end

	if active_state then
		ui:Columns(1)
		local colw = ui:GetColumnWidth()

		local num = math.floor(self.testprefab.sg:GetAnimFramesInState())
		ui:Columns(2, "StateInfoHeader", false)
		ui:SetColumnOffset(1, colw - 70)

		if self.lua_error then
			if ui:SmallButton("Clear") then
				self.lua_error = nil
			end
			ui:SameLine()
			ui:Dummy(5,0)
			ui:SameLine()
			if ui:SmallButton("Copy Error to Clipboard") then
				local s = "Error in embellishment: "..self.prefabname.."\n"
				s = s .. "Prefab: "..self.testprefab.prefab.."\n"
				s = s .. "State: "..active_state.."\n"
				s = s .. "Error: "..self.lua_error.."\n"
				ui:SetClipboardText(s)
			end
			ui:SameLine()
			ui:Dummy(5,0)
			ui:SameLine()
			ui:TextColored(WEBCOLORS.RED, "Lua error! (hover for info)")
			if ui:IsItemHovered() then
				ui:SetTooltip(self.lua_error
				)
			end
		end
		local mismatch = active_state ~= self.focused_state
		local state_color = mismatch and WEBCOLORS.KHAKI or WEBCOLORS.PALEGREEN
		ui:TextColored(state_color, "Active State: " .. active_state .. " - " .. num)
		if mismatch and ui:IsItemHovered() then
			ui:SetTooltipMultiline({
					"This state is not the same as the selection in Go To State.",
					"Try checking 'Block ExitState' to force staying in your selected state.",
				})
		end
		ui:NextColumn()

		if ui:SmallButton("Flip Entity") then
			self.testprefab:SnapToFacingRotation()
			local rot = self.testprefab.Transform:GetRotation()
			self.testprefab.Transform:SetRotation(rot + 180)
		end
		ui:NextColumn()
		state_color = self.testprefab.has_autogen_sg and WEBCOLORS.KHAKI or WEBCOLORS.WHITE
		local params = _static.data[self.prefabname]
		ui:TextColored(state_color, "StateGraph: " .. self.testprefab.sg.sg.name)
		if params and params.sg_wildcard then
			ui:SameLine()
			ui:Dummy(4,4)
			ui:SameLine()
			ui:TextColored(WEBCOLORS.YELLOW, "** Common Embellishment **")
		end
		if self.testprefab.has_autogen_sg and ui:IsItemHovered() then
			ui:SetTooltipMultiline({
					"This object doesn't have its own stategraph so we've",
					"autocreated one that only contains an idle state.",
				})
		end
		ui:NextColumn()
		if ui:SmallButton("Kill Sound") then
			if self.testprefab.SoundEmitter then
				self.testprefab.SoundEmitter:KillAllNamedSounds()
			end
		end
		ui:Columns(1)

		local tags = self.testprefab.sg.currentstate.tags or {}
		local tagstring = ""
		for i, v in pairs(tags) do
			tagstring = tagstring .. " " .. v
		end
		ui:Text("Tags:" .. tagstring)

		local open_animtagger = TheFrontEnd:FindOpenDebugPanel(DebugNodes.AnimTagger)
		local can_tag_anim = false
		if open_animtagger then
			if #open_animtagger.nodes == 1 then
				can_tag_anim = open_animtagger.nodes[1]:CanTag(
					self.testprefab.AnimState:GetCurrentAnimationFile(),
					self.testprefab.AnimState:GetCurrentAnimationName()
				)
			end
		end

		if ui:SmallButton("Tag", not can_tag_anim) then
			if self.testprefab.SoundEmitter then
				open_animtagger.nodes[1]:StartTagging(
					self.testprefab.AnimState:GetCurrentAnimationFile(),
					self.testprefab.AnimState:GetCurrentAnimationName(),
					self.testprefab.AnimState:GetCurrentAnimationFrame(),
					self.curweapon
				)
			end
		end
		ui:SameLine()
		ui:Dummy(5, 5)
		ui:SameLine()

		if self.testprefab.AnimState then
			local animfile = self.testprefab.AnimState:GetCurrentAnimationFile()
			assert(animfile, "We should have caught this above.")
			animfile = animfile:sub(6)
			animfile = animfile:sub(1, #animfile - #".zip")
			ui:Text(
				string.format(
					"Active Anim: %s/%s - %d/%d",
					animfile,
					self.testprefab.AnimState:GetCurrentAnimationName() or "<None>",
					self.testprefab.AnimState:GetCurrentAnimationFrame(),
					self.testprefab.AnimState:GetCurrentAnimationNumFrames()
				)
			)
		end
		self:PauseButtons(ui)
	end

	if self.testprefab.sg:GetAnimFramesInState() ~= self.lastticksinstate then
		local outEvents = {}
		for i, v in pairs(self.pushedEvents) do
			if v > 0 then
				outEvents[i] = v - 1
			end
		end
		self.pushedEvents = outEvents
		self.lastticksinstate = self.testprefab.sg:GetAnimFramesInState()
	end
end



function Embellisher:DeleteEvent(sgname, currentstate, params, event)
	-- actually delete the event
	local name = currentstate.name

	local stategraphs = params.stategraphs or {}
	local stategraph = stategraphs[sgname] or {}

	local stategraphevents = stategraph.events or {}
	local genevents = stategraphevents[name] or {}
	for j, k in pairs(genevents) do
		if k == event then
			table.remove(genevents, j)
			break
		end
	end

	stategraphevents = stategraph.state_events or {}
	genevents = stategraphevents[name] or {}
	for j, k in pairs(genevents) do
		if k == event then
			table.remove(genevents, j)
			break
		end
	end

	stategraphevents = nil
	genevents = stategraph.sg_events or {}
	for j, k in pairs(genevents) do
		if k == event then
			table.remove(genevents, j)
			break
		end
	end
	-- Re-apply the events to the timeline
	self:Embellish(params.events)
	self:SetDirty()
end

function Embellisher:CopyEvent(sgname, currentstate, params, event)
	-- actually delete the event
	local name = currentstate.name

	local stategraphs = params.stategraphs or {}
	local stategraph = stategraphs[sgname] or {}

	local stategraphevents = stategraph.events or {}
	local genevents = stategraphevents[name] or {}
	for j, k in pairs(genevents) do
		if k == event then
			table.insert(genevents, deepcopy(event))
			break
		end
	end

	stategraphevents = stategraph.state_events or {}
	genevents = stategraphevents[name] or {}
	for j, k in pairs(genevents) do
		if k == event then
			table.insert(genevents, deepcopy(event))
			break
		end
	end

	stategraphevents = nil
	genevents = stategraph.sg_events or {}
	for j, k in pairs(genevents) do
		if k == event then
			table.insert(genevents, deepcopy(event))
			break
		end
	end
	-- Re-apply the events to the timeline
	self:Embellish(params.events)
	self:SetDirty()
end

-- this moves an event from state to stategraph event list of vice versa
function Embellisher:MoveEvent(sgname, currentstate, params, event)
	local name = currentstate.name

	local stategraphs = params.stategraphs or {}
	local stategraph = stategraphs[sgname] or {}

	local moved = false

	local stategraphevents = stategraph.state_events or {}
	local genevents = stategraphevents[name] or {}
	for j, k in pairs(genevents) do
		if k == event then
			stategraph.sg_events = stategraph.sg_events or {}
			table.insert(stategraph.sg_events, event)
			table.remove(genevents, j)
			moved = true
			break
		end
	end

	if not moved then
		local genevents = stategraph.sg_events or {}
		for j, k in pairs(genevents) do
			if k == event then
				stategraph.state_events = stategraph.state_events or {}
				stategraph.state_events[name] = stategraph.state_events[name] or {}
				table.insert(stategraph.state_events[name], event)
				table.remove(genevents, j)
				break
			end
		end
	end

	-- Re-apply the events to the timeline
	self:Embellish(params.events)
	self:SetDirty()
end

local soundfuncs = { playsound = true, playcountedsound = true, playfoleysound = true }

function Embellisher:CheckHasSound(params)
	local hasSound = nil
	for _, stategraph in pairs(params.stategraphs or {}) do
		for _, state in pairs(stategraph.events or {}) do
			for _, event in pairs(state) do
				if soundfuncs[event.eventtype] then
					hasSound = true
				end
			end
		end
		for _, state in pairs(stategraph.state_events or {}) do
			for _, event in pairs(state) do
				if soundfuncs[event.eventtype] then
					hasSound = true
				end
			end
		end
		for _, event in pairs(stategraph.sg_events or {}) do
			if soundfuncs[event.eventtype] then
				hasSound = true
			end
		end
	end
	hasSound = hasSound and true or nil

	if params.needSoundEmitter ~= hasSound then
		-- Do we want this? Not sure, but if we add a sound as the first event it won't trigger until a restart
		self:RestartState(self.testprefab.sg.currentstate.name)
		self:SetDirty()
	end
	params.needSoundEmitter = hasSound
end

function Embellisher:UpdateTick()
	self.tick = self.tick or 0
	if self.testprefab and self.testprefab.sg then
		self.tick = self.testprefab.sg:GetAnimFramesInState()
	end
end

function Embellisher:_RenderEventListOptions(ui, params)
	self.showbuiltinevents = self.showbuiltinevents == nil and false or self.showbuiltinevents
	self.showeditevents = self.showeditevents == nil and true or self.showeditevents
	ui:Columns(3, "toggles", false)
	self.showbuiltinevents = ui:_Checkbox("Show original SG events", self.showbuiltinevents)
	ui:NextColumn()
	self.showeditevents = ui:_Checkbox("Show editable events", self.showeditevents)
	ui:NextColumn()
	if self.animatetimeline == nil then
		self.animatetimeline = true
	end
	self.animatetimeline = ui:_Checkbox("Animate TimeLine", self.animatetimeline)
	ui:Columns(1)

	self:AddSectionEnder(ui)
end

function Embellisher:_RenderNamedEventList(ui, params, tlevents, isState)
	if ui:Button("Add Event") then
		if self.testprefab then
			local num = math.floor(self.testprefab.sg:GetAnimFramesInState())
			num = math.clamp(num, 1, 99999)
			self.editevent = {
				eventtype = "playsound",
				param = {},
			}
			self.workevent = deepcopy(self.editevent)
			self.editevent.tempevent = true -- to ensure we're different
			ui:OpenPopup("Edit Event")
			ui:SetNextWindowSize(400, 400)
		end
	end
	ui:Spacing()

	table.sort(tlevents, function(a, b)
		if a.event.name < b.event.name then
			return true
		else
			return a.event.name == b.event.name and a.index < b.index
		end
	end)
	local lastframe
	local colw = ui:GetColumnWidth()

	local currentstate = self.testprefab.sg.currentstate

	for i, v in pairs(tlevents) do
		local event = v.event

		ui:Columns(1, "", false)

		if self.pushedEvents[event.name] and self.animatetimeline then
			local layer = ui.Layer.WindowGlobal
			local col = 0.4
			local color = { col, col, col }
			local sx, sy = ui:GetCursorScreenPos()
			ui:DrawRectFilled(layer, sx, sy - 3, sx + colw, sy + 22, color)
		end

		local w = ui:GetColumnWidth()
		ui:Columns(3, "events", false)
		local namewidth = math.max(w * .4, 140)
		ui:SetColumnOffset(0, 0)
		ui:SetColumnOffset(1, namewidth)
		ui:SetColumnOffset(2, namewidth + 120)

		if event.name ~= lastframe then
			if ui:SmallTooltipButton(ui.icon.receive .."##".. i, string.format("Send Event '%s'\n Test firing the event.",event.name)) then
				TheLog.ch.Embellisher:printf("Firing event '%s' on '%s'", event.name, self.testprefab)
				self.testprefab:PushEvent(event.name)
			end
			ui:SameLineWithSpace()
			self.editor.eventnamer:RenderEventName(ui, event.name)
			ui:SameLine()
			ui:NextColumn()

			lastframe = event.name
		else
			ui:NextColumn()
		end
		if event.eventtype then
			if ui:SmallTooltipButton(ui.icon.edit .. "##edit_event" .. i, "Edit Event") then
				self.editevent = v.event
				self.workevent = deepcopy(self.editevent)
				ui:OpenPopup("Edit Event")
				ui:SetNextWindowSize(400, 400)
			end
			ui:SameLineWithSpace(4)
			if ui:SmallTooltipButton(ui.icon.remove .. "##delete_event" .. i, "Delete Event (CRTL for no confirm)") then
				if not TheInput:IsKeyDown(InputConstants.Keys.CTRL) then
					ui:OpenPopup(" Confirm delete?##" .. i)
				else
					-- delete immediately
					local sgname = self:GetEmbellishSGName(params)
					self:DeleteEvent(sgname, currentstate, params, v.event)
				end
			end
			if ui:BeginPopupModal(" Confirm delete?##" .. i, false, ui.WindowFlags.AlwaysAutoResize) then
				ui:Spacing()
				self:PushRedButtonColor(ui)
				ui:SameLineWithSpace(20)
				if ui:Button("Delete##confirm") then
					ui:CloseCurrentPopup()
					local sgname = self:GetEmbellishSGName(params)
					self:DeleteEvent(sgname, currentstate, params, v.event)
				end
				self:PopButtonColor(ui)
				ui:SameLineWithSpace()
				if ui:Button("Cancel##delete") then
					ui:CloseCurrentPopup()
				end
				ui:SameLine()
				ui:Dummy(20, 0)
				ui:Spacing()
				ui:EndPopup()
			end

			ui:SameLineWithSpace(3)
			if ui:SmallTooltipButton(ui.icon.copy .."##duplicate_event_".. i, "Duplicate Event (CTRL for Copy Event)") then
				if TheInput:IsKeyDown(InputConstants.Keys.CTRL) then
					Embellisher.copypastefullevent = deepcopy(event)
				else
					local sgname = self:GetEmbellishSGName(params)
					self:CopyEvent(sgname, currentstate, params, v.event)
				end
			end
			local arrow_icon
			local arrow_tooltip

			if isState then
				arrow_icon = ui.icon.arrow_right
				local sgname = self:GetEmbellishSGName(params)
				if sgname == "*" then
					arrow_tooltip = "Move Event To Stategraph"
				else
					arrow_tooltip = string.format("Move Event To Stategraph '%s'", sgname)
				end
			else
				arrow_icon = ui.icon.arrow_left
				local statename = currentstate.name
				arrow_tooltip = string.format("Move Event To State '%s'", currentstate.name)
			end

			ui:SameLineWithSpace(3)
			if ui:SmallTooltipButton(arrow_icon .. "##move_event" .. i, arrow_tooltip) then
				local sgname = self:GetEmbellishSGName(params)
				self:MoveEvent(sgname, currentstate, params, v.event)
			end

			ui:NextColumn()
			self:VizEvent(event, ui)
			ui:NextColumn()
		else
			ui:NextColumn()
			if event.eventname then
				self.editor.eventnamer:RenderEventName(ui, event.eventname)
			else
				local info = debug.getinfo(event.fn, "LnS")
				ui:Text(string.format("%s", info.source .. ":" .. tostring(info.linedefined)))
			end

			ui:NextColumn()
		end
	end
	ui:Columns(1)
end

function Embellisher:StateEvents(ui, params, active_state)
	self:_RenderEventListOptions(ui, params)

	if self.testprefab then
		local currentstate = self.testprefab.sg.currentstate
		-- get the built-in events
		local tlevents = {}
		if self.showbuiltinevents then
			for _, tbl in pairs(currentstate.events or {}) do
				for _, v in pairs(tbl) do
					if not v.gen_eventname then
						table.insert(tlevents, { event = v, index = #tlevents })
					end
				end
			end
		end
		-- get the synthetic events

		local name = currentstate.name
		if self.showeditevents then
			local sgname = self:GetEmbellishSGName(params)
			local stategraphs = params.stategraphs or {}
			local stategraph = stategraphs[sgname] or {}
			local stategraphevents = stategraph.state_events or {}
			local genevents = stategraphevents[name] or {}
			for _, v in pairs(genevents) do
				table.insert(tlevents, { event = v, index = #tlevents })
			end
		end

		self:_RenderNamedEventList(ui, params, tlevents, true)

		local can_paste = false
		if Embellisher.copypastefullevent and Embellisher.copypastefullevent.name then
			can_paste = true
		end
		ui:SameLine()
		ui:Dummy(4,4)
		ui:SameLine()
		if can_paste then
			if ui:Button("Paste Event", nil, nil, not can_paste) then
				local name = currentstate.name
				local sgname = self:GetEmbellishSGName(params)
				params.stategraphs = params.stategraphs or {}
				params.stategraphs[sgname] = params.stategraphs[sgname] or {}
				params.stategraphs[sgname].state_events = params.stategraphs[sgname].state_events or {}
				params.stategraphs[sgname].state_events[name] = params.stategraphs[sgname].state_events[name] or {}
				local genevents = params.stategraphs[sgname].state_events[name]
				-- insert the new event
				table.insert(genevents, deepcopy(Embellisher.copypastefullevent))
				-- Re-apply the events to the timeline
				self:Embellish(params.events)
				self:SetDirty()
				Embellisher.copypastefullevent = false
			end
		end

		local styles_to_pop = self.editor:PushModalStyle(ui)
		if ui:BeginPopupModal("Edit Event", true, ui.WindowFlags.AlwaysAutoResize) then
			local event = self.workevent
			local changed_to_action = self:EditEvent(event, ui, self.testprefab, EventType.State)
			if changed_to_action then
				self.workevent = {
					name = self.workevent.name,
					eventtype = changed_to_action,
					param = {},
				}
			end
			if self:EditEventOkButton(ui, event, self.testprefab, true) then
				-- need to apply the changes
				assert(self.workevent.name, "Shouldn't be able to click OK without a name!")
				TheLog.ch.Embellisher:print("Apply changes!")
				if not deepcompare(self.editevent, self.workevent) then
					TheLog.ch.Embellisher:print("changed!")
					-- remove the old event
					local name = currentstate.name
					local sgname = self:GetEmbellishSGName(params)
					params.stategraphs = params.stategraphs or {}
					params.stategraphs[sgname] = params.stategraphs[sgname] or {}
					params.stategraphs[sgname].state_events = params.stategraphs[sgname].state_events or {}
					params.stategraphs[sgname].state_events[name] = params.stategraphs[sgname].state_events[name]
						or {}
					local genevents = params.stategraphs[sgname].state_events[name]
					for i, v in pairs(genevents) do
						if v == self.editevent then
							table.remove(genevents, i)
							break
						end
					end
					-- insert the new event
					table.insert(genevents, self.workevent)
					self.editevent = nil
					self.workevent = nil
					-- Re-apply the events to the timeline
					self:Embellish(params.events)
					self:SetDirty()
				end
				ui:CloseCurrentPopup()
			end
			ui:SameLineWithSpace(30)
			if ui:Button("Cancel", w_cancel) then
				ui:CloseCurrentPopup()
			end
			ui:EndPopup()
		end
		ui:PopStyleColor(styles_to_pop)
	end
end

function Embellisher:StateGraphEvents(ui, params)
	self:_RenderEventListOptions(ui, params)

	if self.testprefab then
		local stategraph = self.testprefab.sg.sg
		local currentstate = self.testprefab.sg.currentstate
		-- get the built-in events
		local tlevents = {}
		if self.showbuiltinevents then
			for _, tbl in pairs(stategraph.events or {}) do
				for _, v in pairs(tbl) do
					if not v.gen_eventname then
						table.insert(tlevents, { event = v, index = #tlevents })
					end
				end
			end
		end
		-- get the synthetic events

		local name = currentstate.name
		if self.showeditevents then
			local sgname = self:GetEmbellishSGName(params)
			local stategraphs = params.stategraphs or {}
			local stategraph = stategraphs[sgname] or {}
			local genevents = stategraph.sg_events or {}
			for _, v in pairs(genevents) do
				table.insert(tlevents, { event = v, index = #tlevents })
			end
		end

		self:_RenderNamedEventList(ui, params, tlevents)

		local can_paste = false
		if Embellisher.copypastefullevent and Embellisher.copypastefullevent.name then
			can_paste = true
		end
		ui:SameLine()
		ui:Dummy(4,4)
		ui:SameLine()
		if can_paste then
			if ui:Button("Paste Event", nil, nil, not can_paste) then
				local sgname = self:GetEmbellishSGName(params)
				params.stategraphs = params.stategraphs or {}
				params.stategraphs[sgname] = params.stategraphs[sgname] or {}
				params.stategraphs[sgname].sg_events = params.stategraphs[sgname].sg_events or {}
				local genevents = params.stategraphs[sgname].sg_events
				-- insert the new event
				table.insert(genevents, deepcopy(Embellisher.copypastefullevent))
				-- Re-apply the events to the timeline
				self:Embellish(params.events)
				self:SetDirty()
				Embellisher.copypastefullevent = false
			end
		end
		local styles_to_pop = self.editor:PushModalStyle(ui)
		if ui:BeginPopupModal("Edit Event", true, ui.WindowFlags.AlwaysAutoResize) then
			local event = self.workevent
			local changed_to_action = self:EditEvent(event, ui, self.testprefab, EventType.StateGraph)
			if changed_to_action then
				self.workevent = {
					name = self.workevent.name,
					eventtype = changed_to_action,
					param = {},
				}
			end
			if self:EditEventOkButton(ui, event, self.testprefab, true) then
				assert(self.workevent.name, "Shouldn't be able to click OK without a name!")
				-- need to apply the changes
				TheLog.ch.Embellisher:print("Apply changes!")
				if not deepcompare(self.editevent, self.workevent) then
					TheLog.ch.Embellisher:print("changed!")
					-- remove the old event
					local name = currentstate.name
					local sgname = self:GetEmbellishSGName(params)
					params.stategraphs = params.stategraphs or {}
					params.stategraphs[sgname] = params.stategraphs[sgname] or {}
					params.stategraphs[sgname].sg_events = params.stategraphs[sgname].sg_events or {}
					local genevents = params.stategraphs[sgname].sg_events
					for i, v in pairs(genevents) do
						if v == self.editevent then
							table.remove(genevents, i)
							break
						end
					end
					-- insert the new event
					table.insert(genevents, self.workevent)
					self.editevent = nil
					self.workevent = nil
					-- Re-apply the events to the timeline
					self:Embellish(params.events)
					self:SetDirty()
				end
				ui:CloseCurrentPopup()
			end
			ui:SameLineWithSpace(30)
			if ui:Button("Cancel", w_cancel) then
				ui:CloseCurrentPopup()
			end
			ui:EndPopup()
		end
		ui:PopStyleColor(styles_to_pop)
	end
end

function Embellisher:TimelinePanel(ui, params)
	self:_RenderEventListOptions(ui, params)

	if self.testprefab then
		if ui:Button("Add Event") then
			if self.testprefab then
				local num = math.floor(self.testprefab.sg:GetAnimFramesInState())
				num = math.clamp(num, 1, 99999)
				self.editevent = {
					frame = num,
					eventtype = "playsound",
					param = {},
				}
				self.workevent = deepcopy(self.editevent)
				self.editevent.tempevent = true -- to ensure we're different
				ui:OpenPopup("Edit Event")
				ui:SetNextWindowSize(400, 400)
				self.force_open_dropdown = true
			end
		end
		ui:Spacing()

		local currentstate = self.testprefab.sg.currentstate
		-- get the built-in events
		local tlevents = {}
		if self.showbuiltinevents then
			for _, v in pairs(currentstate.timeline or {}) do
				if not v.gen_eventname then
					table.insert(tlevents, { event = v, index = #tlevents })
				end
			end
		end
		-- get the synthetic events
		local name = currentstate.name
		if self.showeditevents then
			local sgname = self:GetEmbellishSGName(params)
			local stategraphs = params.stategraphs or {}
			local stategraph = stategraphs[sgname] or {}
			local stategraphevents = stategraph.events or {}
			local genevents = stategraphevents[name] or {}
			for _, v in pairs(genevents) do
				table.insert(tlevents, { event = v, index = #tlevents })
			end
		end
		table.sort(tlevents, function(a, b)
			if a.event.frame < b.event.frame then
				return true
			else
				return a.event.frame == b.event.frame and a.index < b.index
			end
		end)
		local lastframe
		local colw = ui:GetColumnWidth()

		local num = math.floor(self.testprefab.sg:GetAnimFramesInState())
		local lastvalidframe
		for i, v in pairs(tlevents) do
			local event = v.event
			if event.frame <= num then
				lastvalidframe = event.frame
			end
		end
		for i, v in pairs(tlevents) do
			local event = v.event

			ui:Columns(1, "", false)
			if event.frame == lastvalidframe and self.animatetimeline then
				local layer = ui.Layer.WindowGlobal
				local col = event.frame == num and 0.4 or 0.2
				local color = { col, col, col }
				local sx, sy = ui:GetCursorScreenPos()
				ui:DrawRectFilled(layer, sx, sy - 3, sx + colw, sy + 22, color)
			end

			ui:Columns(3, "events", false)
			ui:SetColumnOffset(0, 0)
			ui:SetColumnOffset(1, 40)
			ui:SetColumnOffset(2, 135)

			if event.frame ~= lastframe then
				ui:Text(event.frame)
				ui:SameLine()
				ui:NextColumn()

				lastframe = event.frame
			else
				ui:NextColumn()
			end
			if event.eventtype then
				local eventdef = eventfuncs[event.eventtype]
				if ui:SmallTooltipButton(ui.icon.edit .. "##edit_event" .. i, "Edit Event") then
					self.editevent = v.event
					self.workevent = deepcopy(self.editevent)
					ui:OpenPopup("Edit Event")
					ui:SetNextWindowSize(400, 400)
				end
				ui:SameLineWithSpace(4)
				if ui:SmallTooltipButton(
						ui.icon.remove .."##delete_event".. i,
						"Delete Event (CRTL for no confirm)",
						eventdef.runfunc == nil)
				then
					if not TheInput:IsKeyDown(InputConstants.Keys.CTRL) then
						ui:OpenPopup(" Confirm delete?##" .. i)
					else
						-- delete immediately
						local sgname = self:GetEmbellishSGName(params)
						self:DeleteEvent(sgname, currentstate, params, v.event)
					end
				end
				ui:SameLineWithSpace(3)
				if ui:SmallTooltipButton(ui.icon.copy .."##duplicate_event_".. i, "Duplicate Event (CTRL for Copy Event)") then
					if TheInput:IsKeyDown(InputConstants.Keys.CTRL) then
						Embellisher.copypastefullevent = deepcopy(v.event)
					else
						local sgname = self:GetEmbellishSGName(params)
						self:CopyEvent(sgname, currentstate, params, v.event)
					end
				end

				if ui:BeginPopupModal(" Confirm delete?##" .. i, false, ui.WindowFlags.AlwaysAutoResize) then
					ui:Spacing()
					self:PushRedButtonColor(ui)
					ui:SameLineWithSpace(20)
					if ui:Button("Delete##confirm") then
						ui:CloseCurrentPopup()
						local sgname = self:GetEmbellishSGName(params)
						self:DeleteEvent(sgname, currentstate, params, v.event)
					end
					self:PopButtonColor(ui)
					ui:SameLineWithSpace()
					if ui:Button("Cancel##delete") then
						ui:CloseCurrentPopup()
					end
					ui:SameLine()
					ui:Dummy(20, 0)
					ui:Spacing()
					ui:EndPopup()
				end

				ui:NextColumn()
				self:VizEvent(event, ui)
				ui:NextColumn()
			else
				ui:NextColumn()
				if event.eventname then
					self.editor.eventnamer:RenderEventName(ui, event.eventname)
				else
					local info = debug.getinfo(event.fn, "LnS")
					ui:Text(string.format("%s", info.source .. ":" .. tostring(info.linedefined)))
				end

				ui:NextColumn()
			end
		end
		ui:Columns(1)
		local can_paste = false
		if Embellisher.copypastefullevent and Embellisher.copypastefullevent.frame then
			can_paste = true
		end
		ui:SameLine()
		ui:Dummy(4,4)
		ui:SameLine()
		if can_paste then
			if ui:Button("Paste Event", nil, nil, not can_paste) then
				local sgname = self:GetEmbellishSGName(params)
				params.stategraphs = params.stategraphs or {}
				params.stategraphs[sgname] = params.stategraphs[sgname] or {}
				params.stategraphs[sgname].events = params.stategraphs[sgname].events or {}
				params.stategraphs[sgname].events[name] = params.stategraphs[sgname].events[name] or {}
				local genevents = params.stategraphs[sgname].events[name]
				for i, v in pairs(genevents) do
					if v == self.editevent then
						table.remove(genevents, i)
						break
					end
				end
				-- insert the new event
				table.insert(genevents, deepcopy(Embellisher.copypastefullevent))
				-- Re-apply the events to the timeline
				self:Embellish(params.events)
				self:SetDirty()
				Embellisher.copypastefullevent = false
			end
		end


		local styles_to_pop = self.editor:PushModalStyle(ui)
		if ui:BeginPopupModal("Edit Event", true, ui.WindowFlags.AlwaysAutoResize) then
			local event = self.workevent
			local changed_to_action = self:EditEvent(event, ui, self.testprefab, EventType.Frame)
			if changed_to_action then
				self.workevent = {
					frame = self.workevent.frame,
					eventtype = changed_to_action,
					param = {},
				}
			end
			if self:EditEventOkButton(ui, event, self.testprefab) then
				-- need to apply the changes
				TheLog.ch.Embellisher:print("Apply changes!")
				if not deepcompare(self.editevent, self.workevent) then
					TheLog.ch.Embellisher:print("changed!")
					-- remove the old event
					local name = currentstate.name

					local sgname = self:GetEmbellishSGName(params)
					params.stategraphs = params.stategraphs or {}
					params.stategraphs[sgname] = params.stategraphs[sgname] or {}
					params.stategraphs[sgname].events = params.stategraphs[sgname].events or {}
					params.stategraphs[sgname].events[name] = params.stategraphs[sgname].events[name] or {}
					local genevents = params.stategraphs[sgname].events[name]
					for i, v in pairs(genevents) do
						if v == self.editevent then
							table.remove(genevents, i)
							break
						end
					end
					-- insert the new event
					table.insert(genevents, self.workevent)
					self.editevent = nil
					self.workevent = nil
					-- Re-apply the events to the timeline
					self:Embellish(params.events)
					self:SetDirty()
				end
				ui:CloseCurrentPopup()
			end
			ui:SameLineWithSpace(30)
			if ui:Button("Cancel", w_cancel) then
				ui:CloseCurrentPopup()
			end
			ui:EndPopup()
		end
		ui:PopStyleColor(styles_to_pop)
	end
end

function Embellisher:GetEmbellishSGName(params)
	local sgname = self.testprefab.sg.sg.name
	if params.sg_wildcard then
		sgname = "*"
	end
	return sgname
end

function Embellisher:TabBar(ui, name, panels, tooltips, activepanel)
	local function CenterText(s)
		local cw = ui:GetColumnWidth()
		local w = ui:CalcTextSize(s)
		local x = ui:GetCursorPosX()
		ui:SetCursorPosX(x + cw / 2 - w / 2)
		ui:Text(s)
	end

	activepanel = activepanel or 1
	ui:Columns(#panels, "panes_tab##" .. name, true)

	local hilited = { 0.2, 0.2, 0.2, 1 }
	local active = { 0.4, 0.4, 0.4, 1 }

	for i, v in pairs(panels) do
		local cw = ui:GetColumnWidth()
		local layer = ui.Layer.WindowGlobal
		local cx, cy = ui:GetCursorScreenPos()
		ui:InvisibleButton(v, cw, 20)
		if activepanel == i then
			ui:DrawRectFilled(layer, cx, cy, cx + cw, cy + 20, active)
		elseif ui:IsItemHovered() then
			ui:DrawRectFilled(layer, cx, cy, cx + cw, cy + 20, hilited)
		end
		if ui:IsItemHovered() then
			ui:SetTooltip(tooltips[i])
		end
		if ui:IsItemClicked() then
			activepanel = i
		end
		ui:SetCursorScreenPos(cx, cy)
		CenterText(v)

		ui:NextColumn()
	end
	return activepanel
end

function Embellisher:SetWeapon(weapon)
	local inventoryhoard = self.testprefab.components.inventoryhoard
	if inventoryhoard then
		local slot = Equipment.Slots.WEAPON
		inventoryhoard:Debug_GiveItem(slot, weapon, 1, true)
		self.curweapon = weapon
	else
		self.curweapon = nil
	end
end

function Embellisher:HaveEvents(params)
	for i,sg in pairs(params.stategraphs or {}) do
		for i,v in pairs(sg.events or {}) do
			for state in pairs(v or {}) do
				return true
			end
		end
		for i,v in pairs(sg.state_events or {}) do
			for state in pairs(v or {}) do
				return true
			end
		end
		for i,v in pairs(sg.sg_events or {}) do
			return true
		end
	end
end

function Embellisher:AddEditableOptions(ui, params)
	self:UpdateTick()

	-- Do we need a respawn?
	if self.needrespawn then
		self.needrespawn = nil
		self:Test(self.prefab, params)
	end

	local function TextField(label, params, paramname)
		local _, newvalue = ui:InputText(label, params[paramname], imgui.InputTextFlags.CharsNoBlank)
		if newvalue ~= nil then
			if string.len(newvalue) == 0 then
				newvalue = nil
			end
			if params[paramname] ~= newvalue then
				params[paramname] = newvalue
				self:SetDirty()
			end
		end
	end

	-- The actual current state in the stategraph.
	local active_state = (self.testprefab
		and self.testprefab.sg
		and self.testprefab.sg.currentstate.name)

	if ui:CollapsingHeader("Entity Prefab", ui.TreeNodeFlags.DefaultOpen) then
		ui:Columns(1)
		local disabled = self:HaveEvents(params)

		if disabled then
			ui:BeginDisabled()
		end
		local iswildcard = ui:_Checkbox("##sg_wildcard", params.sg_wildcard or false)
		local tooltip = "When enabled this embellishment will be applied to any stategraph the prefabs may have.\nCan be useful when a prefab can switch stategraphs, or when stategraphs share common states.\n\nCan only be toggled before events are added"
		if ui:IsItemHovered() then
			ui:SetTooltip(tooltip)
		end
		if disabled then
			ui:EndDisabled()
		end
		ui:SameLine()
		ui:Dummy(4,4)
		ui:SameLine()
		if disabled then
			ui:PushStyleColor(ui.Col.Text, { 0.6, 0.6, 0.6, 1 })
		end
		ui:Text("Common Embellishment")
		if disabled then
			ui:PopStyleColor(1)
		end
		if ui:IsItemHovered() then
			ui:SetTooltip(tooltip)
		end

		local colw = ui:GetColumnWidth()
		ui:Columns(2, "Entity Prefab", false)
		ui:SetColumnOffset(1, colw - 90)
		ui:Text("Prefab:")
		ui:NextColumn()
		local isfinal = ui:_Checkbox("##shippable", params.isfinal or false)
		ui:SameLineWithSpace(4)
		local state_color = params.isfinal and WEBCOLORS.WHITE or WEBCOLORS.RED
		ui:TextColored(state_color, "Shippable")
		if not isfinal then
			isfinal = nil
		end
		if isfinal ~= params.isfinal then
			params.isfinal = isfinal
			self:SetDirty()
		end
		ui:Columns(1)
--		if ui:Button(ui.icon.add .."##"..i) then
--			-- insert a line before this one
--			table.insert(record, i, { bank = record[i].bank, anim = "" })
--		end
--		ui:SameLineWithSpace(3)


		--~ local oldprefab = deepcopy(params.prefab)
		local prefabs = type(params.prefab) == "table" and params.prefab or { params.prefab }
		if #prefabs == 0 then
			prefabs[1] = ""
		end
		local oldprefabs = deepcopy(prefabs)
		ui:Columns(2, "embellisher prefabs", false)
		ui:SetColumnOffset(1, 30)
		self.animbank_selection = self.animbank_selection or 1
		local animbank_selection = self.animbank_selection
		for i = 1, #prefabs do
			local clicked
			clicked, animbank_selection = ui:RadioButton("##animbank_selection" .. i, animbank_selection, i)
			if clicked then
				self.animbank_selection = i
			end
			ui:NextColumn()
			local prefab = prefabs[i]
			if ui:Button(ui.icon.add .."##".. i) then
				-- insert another line after this one
				table.insert(prefabs, i + 1, "")
				params.prefab = deepcopy(prefabs)
				if self.animbank_selection > i then
					self.animbank_selection = self.animbank_selection + 1
				end
				self:SetDirty()
			end
			ui:SameLineWithSpace(3)
			if ui:Button(ui.icon.remove .."##".. i, nil, nil, i == 1 and #prefabs == 1) then
				-- delete this line
				table.remove(prefabs, i)
				params.prefab = deepcopy(prefabs)
				if self.animbank_selection > i then
					self.animbank_selection = self.animbank_selection - 1
				end
				self:SetDirty()
			end
			ui:SameLineWithSpace(3)

			local newvalue = PrefabEditorBase.PrefabPicker(ui, "##prefab" .. i, prefabs[i])
			if newvalue ~= nil then
				if string.len(newvalue) == 0 then
					newvalue = ""
				end
				if prefabs[i] ~= newvalue then
					prefabs[i] = newvalue
					params.prefab = deepcopy(prefabs)
					self:SetDirty()
				end
			end
			ui:NextColumn()
		end
		ui:Columns(1)
		if not deepcompare(params.prefab, oldprefabs) then
			embellishutil.SortStateGraphEmbellishments()
			self.embellishments = nil
			self:InitEmbellishments()
		end

		-- Select weapon for prefab since those change the stategraphs.
		if self.testprefab and self.testprefab.components.inventoryhoard then
			-- Line up combo with prefab name.
			local w = ui:GetItemWidth()
			ui:PushItemWidth(w - 70)

			local inventoryhoard = self.testprefab.components.inventoryhoard
			local slot = Equipment.Slots.WEAPON
			local current = inventoryhoard:GetEquippedItem(slot)

			local cur_idx = lume.find(self.weapons, current.id) or 1
			local changed, new_idx = ui:Combo("Weapon", cur_idx, self.weapons)
			if changed then
				-- This will give redundant items, but it ensures we can select
				-- any weapon for testing on the target.
				self:SetWeapon(self.weapons[new_idx])

				self.edit_options:Set("weapon_idx", new_idx)
				self.edit_options:Save()
			end

			ui:PopItemWidth()
		end

		ui:SameLineWithSpace(4)
		if not iswildcard then
			iswildcard = nil
		end
		if iswildcard ~= params.sg_wildcard then
			params.sg_wildcard = iswildcard
			params.stategraphs = nil
			self:SetDirty()
		end

		self:AddSectionEnder(ui)
	end

	if self.testprefab and self.testprefab.sg then
		if self.edit_options.blockexitstate then
			self.testprefab.sg.GoToState = GotoState_BlockedExitState
		else
			self.testprefab.sg.GoToState = MakeSafeGoToState(self)
		end
	end

	if --[[active_state and ]]
		ui:CollapsingHeader("Debug Toggles")
	then
		ui:Columns(2, "debugflags", false)
		self.edit_options:Toggle(ui, "Block ExitState", "blockexitstate")
		ui:NextColumn()
		self.edit_options:Toggle(ui, "Enable Brain", "enablebrain")
		ui:NextColumn()
		if self.testprefab and self.testprefab.brain then
			if self.edit_options.enablebrain then
				self.testprefab.brain:Resume("SGEDitor")
			else
				self.testprefab.brain:Pause("SGEDitor")
			end
		end

		self.edit_options:Toggle(ui, "Disable Physics", "disablephysics")
		if self.testprefab then
			self:DisablePhysics(self.testprefab, self.edit_options.disablephysics)
		end

		ui:NextColumn()
		self.edit_options:Toggle(ui, "Spawn Paused", "spawnpaused")

		ui:NextColumn()
		if self.edit_options:Toggle(ui, "Show HitBox", "showhitbox") then
			self:CaptureHitBox(self.edit_options.showhitbox)
		end
		ui:NextColumn()
		if self.edit_options:Toggle(ui, "Don't Despawn", "dontdespawn") then
			-- I need to respawn so I can override the Remove function
			if self.testprefab then
				self:DespawnPrefab()
				self.needrespawn = true
			end
		end

		ui:NextColumn()
		self.edit_options:Toggle(ui, "Lock Position", "lockposition")
		if ui:IsItemHovered() then
			ui:SetTooltip("Prevent the entity from moving away from the red circle handle.")
		end

		ui:Columns(1)
		ui:Separator()

		-- Hitbox test visualizer for setting hitbox size & offset
		if ui:TreeNode("Hitbox Test Visualizer") then
			ui:PushItemWidth(200)
			local changed, value = ui:Checkbox("Enable Test Hitbox", self.testhitbox.enabled)
			if changed then
				self.testhitbox.enabled = value
			end

			if self.testhitbox.enabled then
				-- Select hitbox shape
				local _, selectedHitbox = nil, self.testhitbox.shape
				_, selectedHitbox = ui:RadioButton("Beam", selectedHitbox, HitBoxShape.Beam)
				ui:SameLineWithSpace()
				_, selectedHitbox = ui:RadioButton("Circle", selectedHitbox, HitBoxShape.Circle)

				if selectedHitbox ~= self.testhitbox.shape then
					self.testhitbox.shape = selectedHitbox
				end

				-- Beam Hitbox Shape UI
				if self.testhitbox.shape == HitBoxShape.Beam then
					-- Start Distance
					if ui:Button("Reset##BeamStartDistance") then
						self.testhitbox.beam.start_dist = 0
					end

					ui:SameLineWithSpace()

					local changedStartDist, start_dist = ui:DragFloat("Start Distance", self.testhitbox.beam.start_dist, 0.01, -100, -100)
					if changedStartDist then
						self.testhitbox.beam.start_dist = start_dist
					end

					-- End Distance
					if ui:Button("Reset##BeamEndDistnace") then
						self.testhitbox.beam.end_dist = 1
					end

					ui:SameLineWithSpace()

					local changedEndDist, end_dist = ui:DragFloat("End Distance", self.testhitbox.beam.end_dist, 0.01, -100, 100)
					if changedEndDist then
						self.testhitbox.beam.end_dist = end_dist
					end

					-- Thickness
					if ui:Button("Reset##BeamThickness") then
						self.testhitbox.beam.thickness = 1
					end

					ui:SameLineWithSpace()


					local changedThickness, thickness = ui:DragFloat("Thickness", self.testhitbox.beam.thickness, 0.01, 0, 100)
					if changedThickness then
						self.testhitbox.beam.thickness = thickness
					end

					-- z-Offset
					if ui:Button("Reset##BeamZoffset") then
						self.testhitbox.beam.zoffset = 0
					end

					ui:SameLineWithSpace()

					local changedZoffset, zoffset = ui:DragFloat("z-Offset", self.testhitbox.beam.zoffset, 0.01, -100, 100)
					if changedZoffset then
						self.testhitbox.beam.zoffset = zoffset
					end

					if ui:Button("Copy values to Clipboard##BeamHitbox") then
						if self.testhitbox.beam.zoffset ~= 0 then
							ui:SetClipboardText(string.format("inst.components.hitbox:PushOffsetBeam(%.2f, %.2f, %.2f, %.2f, HitPriority.??)", self.testhitbox.beam.start_dist, self.testhitbox.beam.end_dist, self.testhitbox.beam.thickness, self.testhitbox.beam.zoffset))
						else
							ui:SetClipboardText(string.format("inst.components.hitbox:PushBeam(%.2f, %.2f, %.2f, HitPriority.??)",self.testhitbox.beam.start_dist, self.testhitbox.beam.end_dist, self.testhitbox.beam.thickness))
						end
					end

					-- Draw the test hitbox
					if self.testprefab then
						local x, z = self.testprefab.Transform:GetWorldXZ()
						local start_x = x + self.testhitbox.beam.start_dist
						local start_z = z - self.testhitbox.beam.thickness + self.testhitbox.beam.zoffset
						local end_x = x + self.testhitbox.beam.end_dist
						local end_z = z + self.testhitbox.beam.thickness + self.testhitbox.beam.zoffset
						local scale = self.testprefab.Transform:GetScale()

						DebugDraw.GroundRect(start_x, start_z, end_x * scale, end_z * scale, BGCOLORS.YELLOW, 4)
					end
				elseif self.testhitbox.shape == HitBoxShape.Circle then
					-- Distance
					if ui:Button("Reset##CircleDistance") then
						self.testhitbox.circle.distance = 0
					end

					ui:SameLineWithSpace()

					local changedDist, distance = ui:DragFloat("Distance", self.testhitbox.circle.distance, 0.01, -100, -100)
					if changedDist then
						self.testhitbox.circle.distance = distance
					end

					-- Rotation
					if ui:Button("Reset##CircleRotation") then
						self.testhitbox.circle.rotation = 0
					end

					ui:SameLineWithSpace()

					local changedRotation, rotation = ui:DragFloat("Rotation", self.testhitbox.circle.rotation, 0.1, -180, 180)
					if changedRotation then
						self.testhitbox.circle.rotation = rotation
					end

					-- Radius
					if ui:Button("Reset##CircleRadius") then
						self.testhitbox.circle.radius = 1
					end

					ui:SameLineWithSpace()


					local changedRadius, radius = ui:DragFloat("Radius", self.testhitbox.circle.radius, 0.01, 0, 100)
					if changedRadius then
						self.testhitbox.circle.radius = radius
					end

					-- z-Offset
					if ui:Button("Reset##CircleZoffset") then
						self.testhitbox.circle.zoffset = 0
					end

					ui:SameLineWithSpace()

					local changedZoffset, zoffset = ui:DragFloat("z-Offset", self.testhitbox.circle.zoffset, 0.01, -100, 100)
					if changedZoffset then
						self.testhitbox.circle.zoffset = zoffset
					end

					if ui:Button("Copy values to Clipboard##CircleHitbox") then
						if self.testhitbox.circle.zoffset ~= 0 then
							ui:SetClipboardText(string.format("inst.components.hitbox:PushOffsetCircle(%.2f, %.2f, %.2f, %.2f, HitPriority.??)", self.testhitbox.circle.distance, self.testhitbox.circle.rotation, self.testhitbox.circle.radius, self.testhitbox.circle.zoffset))
						else
							ui:SetClipboardText(string.format("inst.components.hitbox:PushCircle(%.2f, %.2f, %.2f, HitPriority.??)", self.testhitbox.circle.distance, self.testhitbox.circle.rotation, self.testhitbox.circle.radius))
						end
					end

					-- Draw the test hitbox
					if self.testprefab then
						local x, z = self.testprefab.Transform:GetWorldXZ()
						local scale = self.testprefab.Transform:GetScale()
						local distance = self.testhitbox.circle.distance * scale
						local radius = self.testhitbox.circle.radius * scale
						local rot = math.rad(self.testhitbox.circle.rotation + self.testprefab.Transform:GetFacingRotation() or self.testprefab.Transform:GetRotation())
						x = x + distance * math.cos(rot)
						z = z - distance * math.sin(rot) + self.testhitbox.circle.zoffset

						DebugDraw.GroundCircle(x, z, radius, BGCOLORS.YELLOW, 4)
					end
				end
			end

			ui:PopItemWidth()
			self:AddTreeNodeEnder(ui)
		end

		ui:Columns(1)

		-- draw the hitbox....
		if not self.hitboxesvis then
			self.hitboxesvis = {}
			for i, v in pairs(self.testprefab and self.testprefab.hitboxes or { body = self.testprefab }) do
				self.hitboxesvis[i] = false
			end
		end
		if ui:TreeNode("HurtBoxes", ui.TreeNodeFlags.DefaultOpen) then
			if ui:Button("Show all") then
				for i, v in pairs(self.hitboxesvis) do
					self.hitboxesvis[i] = true
				end
			end
			ui:SameLineWithSpace(10)
			if ui:Button("Hide all") then
				for i, v in pairs(self.hitboxesvis) do
					self.hitboxesvis[i] = false
				end
			end
			for i, v in pairs(self.testprefab and self.testprefab.hitboxes or { body = self.testprefab }) do
				--ui:Text(i)
				self.hitboxesvis[i] = ui:_Checkbox(i, self.hitboxesvis[i])
			end
			self:AddTreeNodeEnder(ui)
		end


		if self.embellishments and ui:TreeNode("Additional embellishments", ui.TreeNodeFlags.DefaultOpen) then
			local old_embellishments = deepcopy(self.embellishments)
			if ui:Button("Shippable") then
				for i, v in pairs(self.embellishments) do
					if i ~= self.prefabname then
						local preset = _static.data[i]
						if preset and preset.isfinal then
							self.embellishments[i] = true
						else
							self.embellishments[i] = false
						end
					end
				end
			end
			ui:SameLineWithSpace(10)
			if ui:Button("all") then
				for i, v in pairs(self.embellishments) do
					if i ~= self.prefabname then
						self.embellishments[i] = true
					end
				end
			end
			ui:SameLineWithSpace(10)
			if ui:Button("None") then
				for i, v in pairs(self.embellishments) do
					if i ~= self.prefabname then
						self.embellishments[i] = false
					end
				end
			end
			for i, v in pairs(self.embellishments) do
				--ui:Text(i)
				if i ~= self.prefabname then
					self.embellishments[i] = ui:_Checkbox(i, self.embellishments[i])
				end
			end
			if not deepcompare(self.embellishments, old_embellishments) then
				self:Embellish()
			end
			self:AddTreeNodeEnder(ui)
		end
	end

	if self.edit_options.showhitbox and self.testprefab and self.testprefab.HitBox then
		self:DrawHitBoxes()
	end

	if self.allow_OnUpdates then
		if self.paused or self.currentstepframe then
			self:AllowOnUpdates(false)
		else
			if not self.wantsruntoframe then
				self:ClearCachedHitBoxes()
			end
		end
	end

	if self.testprefab then
		for i, v in pairs(self.testprefab and (self.testprefab.hitboxes or { body = self.testprefab })) do
			--ui:Text(i)
			if self.hitboxesvis and self.hitboxesvis[i] then
				local w = v.HitBox:GetSize()
				local h = v.HitBox:GetDepth()
				local pt = v:GetPosition()
				local enabled = v.HitBox:IsEnabled()
				if enabled then
					DebugDraw.GroundRect(pt.x - w, pt.z - h, pt.x + w, pt.z + h, BGCOLORS.WHITE)
				end
			end
		end
	end

	if active_state and ui:CollapsingHeader("StateGraph", ui.TreeNodeFlags.DefaultOpen) then
		local statelist = {}
		-- focused_state is where the UI is choosing to jump.
		self.focused_state = self.focused_state or active_state
		if self.testprefab then
			for i, v in pairs(self.testprefab.sg.sg.states) do
				table.insert(statelist, i)
			end
		end
		table.sort(statelist, function(a, b)
			return a < b
		end)
		local stateidx = table.arrayfind(statelist, self.focused_state)
		local gobutton = ui:Button("Restart##restart_combo_state")
		if ui:IsItemHovered() then
			ui:SetTooltip("Restart this state (" .. statelist[stateidx] .. ").")
		end

		ui:SameLineWithSpace(6)
		if ui:SmallButton(ui.icon.arrow_down .. "##nextstate", stateidx == #statelist) then
			-- next entry
			self.focused_state = statelist[stateidx + 1] or ""
			self:RestartState(self.focused_state)
		end
		ui:SameLineWithSpace(3)
		if ui:SmallButton(ui.icon.arrow_up .. "##prevstate", stateidx == 1) then
			-- prev entry
			self.focused_state = statelist[stateidx - 1] or ""
			self:RestartState(self.focused_state)
		end
		ui:SameLineWithSpace(3)


		local newstateidx = ui:_Combo("Go To State", stateidx or 1, statelist)
		if gobutton or newstateidx ~= stateidx then
			self.focused_state = statelist[newstateidx]
			self.edit_options:Set("selectedstate", self.focused_state)
			self.edit_options:Save()
			self:RestartState(self.focused_state)
		end

		self:AddSectionEnder(ui)
		self:StateGraphInfo(ui, active_state)
		self:AddSectionEnder(ui)

		self.activepane = self.activepane or 1

		local short_state = kstring.abbreviate(active_state, 18)
		local timeline = ("'%s' Timeline"):format(short_state)
		local events = ("'%s' Events"):format(short_state)
		local sgname = self:GetEmbellishSGName(params)

		local sg = ("'%s' Events"):format(self.testprefab and sgname or "StateGraph")
		if sgname == "*" then
			sg = "StateGraph Events"
		end

		local panels = { timeline, events, sg }
		local tooltips = {
			"Frame number event handlers in the Active State",
			"Named event handlers for any point while in Active State",
			"Named event handlers for any state in the current StateGraph",
		}

		self.activepanel = self:TabBar(
			ui,
			"eventcategory",
			panels,
			tooltips,
			self.activepanel
		)

		-- show the timelines
		if self.activepanel == 1 then
			self:TimelinePanel(ui, params)
		elseif self.activepanel == 2 then
			self:StateEvents(ui, params)
		else
			self:StateGraphEvents(ui, params)
		end
	end
end

DebugNodes.Embellisher = Embellisher

return Embellisher
