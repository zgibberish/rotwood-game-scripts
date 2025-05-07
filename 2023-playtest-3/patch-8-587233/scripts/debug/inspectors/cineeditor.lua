-- Author cinematics.

local DebugNodes = require "dbui.debug_nodes"
local EventFuncEditor = require "debug.inspectors.eventfunceditor"
local PrefabEditorBase = require "debug.inspectors.prefabeditorbase"
local Timeline = require "util.timeline"
local cineutil = require "prefabs.cineutil"
local color = require "math.modules.color"
local eventfuncs = require "eventfuncs"
local kstring = require "util.kstring"
local lume = require "util.lume"
require "mathutil"

local _static = PrefabEditorBase.MakeStaticData("cine_autogen_data")

local timeline = {
	ui = {
		prettyname = {},
	},
	actions = {},
}
for key,eventdef in pairs(eventfuncs) do
	if not eventdef.required_editor
		or eventdef.required_editor == "cineeditor"
	then
		timeline.ui.prettyname[eventdef.name] = eventdef.nicename
		table.insert(timeline.actions, eventdef.name)
	end
end
table.sort(timeline.actions)

local function AddSubActor(params)

	local subactor =
	{
		prefabname = nil,
		label = "",
		start_pos = nil,
		use_lead_actor_pos = nil,
		show_on_spawn = true,
		face_left = false,
		kill_on_end = true,
		assigned_at_runtime = false,
	}

	params.subactors = params.subactors or {}
	table.insert(params.subactors, subactor)
end

local function RemoveSubActor(params, index)
	table.remove(params.subactors, index)

	-- Update events that depend on the removed subactor
	if params.timelines then
		for _, event in pairs(params.timelines) do
			for _, eventdata in ipairs(event) do
				for _, entry in ipairs(eventdata) do
					if type(entry) == "table" and entry.sub_actor_idx then
						if entry.sub_actor_idx == index then
							entry.sub_actor_idx = nil
							entry.sub_actor_removed = true -- Warning flag to show that the selected sub actor has been removed.
						elseif entry.sub_actor_idx > index then
							entry.sub_actor_idx = entry.sub_actor_idx - 1
						end
					end
				end
			end
		end
	end
end

-- Function to revert fade outs in the cine editor, which can soft-lock the game.
local function RevertFadeOut()
	TheFrontEnd:Fade(true, 0)
end

local CineEditor = Class(PrefabEditorBase, function(self)
	PrefabEditorBase._ctor(self, _static)

	self.name = "Cine Editor"
	self.prefab_label = "Cutscene"
	self.test_label = "Watch"

	self.leadactor = nil
	self.testprefab = nil

	self.subactors = {} -- table containing spawned sub actor prefabs

	self.cinename = ""

	self._oncine_end = function(source) self:Pause() end

	self.roles = {
		"scene",
		"lead",
		"sub",
		"players",
	}
	self.roles_pretty = {
		"Scene",
		"Lead Actor",
		"Sub Actor",
		"Players",
	}

	local default_color = 0xFF8800FF -- close but not the same as default 0xFFAA8080
	local start = color(imgui.ConvertImU32ToRGBFloats(default_color))
	self.actor_colors = {}
	for i,label in ipairs(self.roles) do
		local c = start:hue_shift(-0.18 * i)
		self.actor_colors[label] = {
			im_uint = imgui.ConvertRGBFloatsToImU32(c:unpack()),
			color = c,
		}
	end

	self.editor = EventFuncEditor(self)

	self:LoadLastSelectedPrefab("cineeditor")

	self:WantHandle()

	self.timeline = {
		editor = Timeline(),
	}
	self.timeline.editor:set_row_color_fn(function(key, event)
		local data = event[3]
		local c = self.actor_colors[data.target_role or "scene"]
		return c.im_uint
	end)


	self.OnRevert = RevertFadeOut
end)

CineEditor.PANEL_WIDTH = 860
CineEditor.PANEL_HEIGHT = 990

CineEditor.MENU_BINDINGS = {
	{
		name = "Help",
		bindings = {
			{
				name = "About CineEditor",
				fn = function(params)
					params.panel:PushNode(DebugNodes.DebugValue([[
The CineEditor lets you sequence actions events on a single timeline. It's
similar to Embellisher but less generic, can be skipped, has a slightly
different set of events, and has special behaviour online. Additionally, you
can embellish a state and goto that state from within the cinematic.

Generally, our pattern for cinematics:
* If the actor is doing an action used in gameplay (like a taunt) or heavily
  embellished, embellish a state and use GotoState. That way it can use the
  same setup during gameplay and uses an editor familiar to fx/sfx. The entity
  may need to handle the cine_skipped event to put itself into the right
  post-cine game state. (We force it into "State On Resume" but it may need
  other data set.)
* If the actor is doing custom cine animation, then handle it with cinematic.
  This automatically handles cinematic skipping easier.

Regardless, we can still use AnimTagger and handle those events in sg Events
section of the Embellisher during a cinematic.
]]))
				end,
			},
		},
	},
}

function CineEditor:SetupHandle(handle)
	handle.track_cine = function(inst)
		local frame_number = -1
		if self.testprefab then
			if self.testprefab.sg:GetCurrentState() == "playing" then
				frame_number = self.testprefab.sg:GetAnimFramesInState()
			end
			-- Don't move anything because they might move about on their own
			-- during the cine.
		end
		self.timeline.editor:set_editor_frame(frame_number)
	end
	handle:DoPeriodicTask(0, handle.track_cine)
	-- Usually want it far from the player.
	handle.Transform:SetPosition(Vector3.zero:unpack())
end

function CineEditor:OnPrefabDropdownChanged(prefabname)
	CineEditor._base.OnPrefabDropdownChanged(self, prefabname)

	self.cinename = prefabname
	self:_RemoveAndClearSpawns()
end

function CineEditor:OnDeactivate()
	CineEditor._base.OnDeactivate(self)
	self:_RemoveAndClearSpawns()
end

function CineEditor:_RemoveAndClearSpawns()
	self.is_lead_prefab_missing_cineactor = nil
	if self.testprefab ~= nil then
		self.testprefab:SkipCinematic()
		self.testprefab:Remove()
		self.testprefab = nil
	end
	if self.leadactor ~= nil then
		self.leadactor:Remove()
		self.leadactor = nil
	end

	if self.subactors then
		for i, subactor in ipairs(self.subactors) do
			if subactor and subactor:IsValid() then
				subactor:Remove()
			end
		end
		self.subactors = {}
	end

	RevertFadeOut()
end

function CineEditor:Pause()
	self.is_paused = true
	if not TheSim:IsDebugPaused() then
		TheSim:ToggleDebugPause()
	end
end
function CineEditor:Resume(params)
	self.is_paused = false
	if TheSim:IsDebugPaused() then
		TheSim:ToggleDebugPause()
	end
	if self.testprefab
		and self.testprefab.sg:GetCurrentState() == "complete"
	then
		self:RestartCine(params)
	end
end

function CineEditor:RestartCine(params)
	if self.testprefab then
		self.testprefab:SkipCinematic()
	end
	self:Test(self.prefabname, params)
end

function CineEditor:Test(cine, params)
	if not GetDebugPlayer() then
		return
	end
	CineEditor._base.Test(self, cine, params)
	self:_RemoveAndClearSpawns()

	RegisterPrefabs(cineutil.MakeAutogenCine(cine, params, true))
	TheSim:LoadPrefabs({ cine })

	self.is_lead_prefab_missing_cineactor = nil

	local x,z = self.handle.Transform:GetWorldXZ()
	if params.scene_init and params.scene_init.pos then
		x = params.scene_init.pos.x
		z = params.scene_init.pos.z
	end
	if params.leadprefab then
		self.leadactor, self.is_lead_prefab_missing_cineactor = cineutil.Debug_SpawnLeadActor(params.leadprefab)
		self.leadactor.Transform:SetPosition(x, 0, z)

		self.testprefab = self.leadactor.components.cineactor:PlayAsLeadActor(cine, nil, true)
		self.testprefab.isEditorPrefab = true -- Set this flag to handle editor-only vs. runtime things.

		if self.leadactor.OnEditorSpawn then
			self.leadactor:OnEditorSpawn(self)
		end
	else
		self.testprefab = SpawnPrefab(cine, TheDebugSource)
	end
	self.testprefab.persists = false

	-- Set up prefabs generated by cineutil.SetupCinematic() so that they don't attack you afterwards...
	if self.testprefab.cine and self.testprefab.cine.subactors then
		for i, subactor in ipairs(self.testprefab.cine.subactors) do
			cineutil.Debug_SetupActor(subactor, params.subactors[i])
		end
	end
	self.subactors = self.testprefab.cine.subactors or {}

	if self.pause_at_end then
		self.testprefab:ListenForEvent("cine_end", self._oncine_end)
	end

	if self.testprefab.OnEditorSpawn then
		self.testprefab:OnEditorSpawn(self)
	end

	self.testprefab.Transform:SetPosition(x, 0, z)

	--~ self.testprefab:SetStateGraph()
	SetDebugEntity(self.leadactor or self.testprefab)
	-- insert the states to play the anim sequence
	self.curframe = 0
	--~ self:SetFrame(self.testprefab, self.curframe)

	self.handle:track_cine()

	if self.is_paused then
		self:Pause()
	end
end

function CineEditor:SetFrame(inst, frame)
	inst.AnimState:SetFrame(frame)
	local children = inst.highlightchildren
	if children then
		for i, v in pairs(children) do
			if v.AnimState then
				v.AnimState:SetFrame(frame)
			end
		end
	end
end

function CineEditor:IsExistingPrefabName(prefab)
	return self.static.data[prefab] and true
end

function CineEditor:ApplyNameRestrictions(new_name)
	local prefix = "cine_"
	if not kstring.startswith(new_name, prefix) then
		return prefix .. new_name
	end
end


local function ensure_complete_timeline_data(params, element_keys)
	-- Ensure all tables exist.
	local tl = params.timelines or {}
	for _,key in ipairs(element_keys) do
		tl[key] = tl[key] or {}
	end
	params.timelines = tl
end

function CineEditor:_CreateTimelineEvent(element, prev_event)
	local eventdef = eventfuncs[element]
	dbassert(lume.find(self.roles, "lead"))
	local role = (not eventdef.is_targetless and self.leadactor) and "lead" or nil
	local event = {
		eventtype = element,
		param = {},
		target_role = role,
		is_unedited = true,
	}
	if eventdef.no_nil_duration then
		event.param.duration = 0
	end
	-- Default to filling the rest of the timeline.
	return self.params.scene_duration, event
end

function CineEditor:_DrawTimelineEvent(ui, element, event, timecode_start, timecode_end)
	local changed
	ui:TextColored(self.colorscheme.header, element)
	ui:SameLineWithSpace(350)
	ui:Value("Begin Frame", timecode_start)
	ui:SameLineWithSpace()
	ui:Value("End Frame", timecode_end)

	local target_inst = self.testprefab
	local eventdef = eventfuncs[element]
	if not eventdef.is_targetless then
		-- Default to scene if nil (we skip nil roles at runtime), but we try
		-- to pre-assign roles on creation for convenience. See
		-- _CreateTimelineEvent.
		local idx = lume.find(self.roles, event.target_role) or 1
		idx = ui:_Combo("Role", idx, self.roles_pretty)
		if idx == 2 then -- Lead actor
			event.target_role = self.roles[idx]

			if event.target_role then
				target_inst = self.testprefab.cine.roles[event.target_role]
			end
		elseif idx == 3 then -- Sub actor
			event.target_role = self.roles[idx]
			event.sub_actor_idx = event.sub_actor_idx or 1

			if event.sub_actor_removed then
				ui:TextColored(WEBCOLORS.YELLOW, "WARNING: selected sub actor has been removed! Please select another target.")
			end

			if self.params.subactors and #self.params.subactors > 0 then
				local names = {}
				for _, subactor in ipairs(self.params.subactors) do
					local subactor_name = subactor.label .. " (" .. subactor.prefabname .. ")"
					table.insert(names, subactor_name)
				end
				local sub_actor_changed, sub_actor_idx = ui:Combo("Sub Actor:", event.sub_actor_idx or 1, names)
				if sub_actor_changed then
					event.sub_actor_idx = sub_actor_idx
					event.sub_actor_removed = nil -- Reset sub actor removed flag after selecting a proper sub actor
				end

				target_inst = self.testprefab.cine.subactors[event.sub_actor_idx or 1]
			end
		elseif idx == 4 then -- Player
			event.target_role = self.roles[idx]
			target_inst = GetDebugPlayer()
			event.apply_to_all_players = ui:_Checkbox("Apply to All Players", event.apply_to_all_players)
		else -- Scene
			event.target_role = nil
		end

		if idx ~= 3 then
			event.sub_actor_removed = nil
		end
	end

	if not target_inst then
		-- Needs to respawn.
		TheLog.ch.Cine:print("WARNING: Invalid target instance! Need to reload timeline.")
		self:_RemoveAndClearSpawns()
		return
	end

	if event.param and next(event.param) and not event.is_unedited then
		-- viz expects data filled in by editor's default state.
		self.editor:DrawViz(ui, event, target_inst)
	end
	if eventdef.edit then
		eventdef:edit(self.editor, ui, event, target_inst)
		event.is_unedited = nil
		-- eventfuncs don't track changes, so assume it changed.
		changed = true
	end

	local is_valid = eventdef:isvalid(self.editor, event, target_inst)
	if not is_valid then
		ui:TextColored(WEBCOLORS.RED, "Invalid event! Please fill in missing data above.")
	end

	if eventdef.testbtn
		and target_inst
		and ui:Button("Test Event")
	then
		eventdef.func(target_inst, event.param)
		self.editor:RequestSeeWorld(true)
	end

	ui:Spacing()
	ui:Separator()
	ui:Spacing()
	ui:Text(table.inspect(event))
	return changed
end

function CineEditor:_ActorColorLabel(ui, role, skip_tooltip)
	ui:ColorButton("Timeline color legend", self.actor_colors[role].color)
	if not skip_tooltip and ui:IsItemHovered() then
		ui:BeginTooltip()
		for _,key in ipairs(self.roles) do
			self:_ActorColorLabel(ui, key, true)
			ui:SameLineWithSpace()
			local pretty_key = self.roles_pretty[lume.find(self.roles, key)] or "<unknown>"
			ui:Text(pretty_key)
		end
		ui:Dummy(0,0)
		ui:EndTooltip()
	end
end

function CineEditor:AddEditableOptions(ui, params)
	-- Assume dirty since last frame since some checking is too annoying.
	self:SetDirty()

	-- Exists so we can access params from timeline functions.
	self.params = params

	if ui:Button(ui.icon.playback_jump_back, ui.icon.width) then
		self:RestartCine(params)
		if self.is_paused then
			self:Resume(params)
		end
	end
	if ui:IsItemHovered() then
		ui:SetTooltip("Restart cinematic")
	end
	ui:SameLineWithSpace()
	if self.is_paused then
		if ui:Button(ui.icon.playback_play, ui.icon.width) then
			self:Resume(params)
		end
	else
		if ui:Button(ui.icon.playback_pause, ui.icon.width) then
			self:Pause()
		end
	end

	ui:SameLineWithSpace()
	if ui:Button(ui.icon.playback_step_fwd, ui.icon.width, nil, not TheSim:IsDebugPaused()) then
		TheSim:Step()
	end
	if ui:IsItemHovered() then
		ui:SetTooltip("Step frame")
	end

	ui:SameLineWithSpace()
	if ui:Button(ui.icon.playback_jump_fwd, ui.icon.width, nil, not self.testprefab) then
		self:Resume(params)
		self.testprefab:SkipCinematic()
	end
	if ui:IsItemHovered() then
		ui:SetTooltip("Skip cinematic")
	end

	ui:SameLineWithSpace()
	self.pause_at_end = ui:_Checkbox("Pause at End", self.pause_at_end)

	self:AddSectionEnder(ui)

	self:_ActorColorLabel(ui, "lead")
	ui:SameLineWithSpace()
	ui:Text("Lead Actor:")

	params.pause_role_sg = params.pause_role_sg or {}
	params.leadprefab = PrefabEditorBase.PrefabPicker(ui, "Lead Actor Prefab", params.leadprefab)
	if not params.leadprefab or params.leadprefab:len() == 0 then
		params.leadprefab = nil
		params.pause_role_sg.lead = nil
		params.use_lead_actor_pos = nil
	end
	if self.is_lead_prefab_missing_cineactor then
		self:WarningMsg(ui, ("Prefab '%s' doesn't have a cineactor component."):format(params.leadprefab), "")
	end

	if params.leadprefab then
		local use_lead_actor_pos_changed, use_lead_actor_pos = ui:Checkbox("Use Lead Actor Position", params.use_lead_actor_pos)
		if use_lead_actor_pos_changed then
			params.use_lead_actor_pos = use_lead_actor_pos
		end
	end

	if not params.use_lead_actor_pos then
		params.scene_init = params.scene_init or {}
		self.editor:WorldPosition(ui, "Scene Actor World Position", params.scene_init)
	end

	self:AddSectionEnder(ui)

	self:_ActorColorLabel(ui, "sub")
	ui:SameLineWithSpace()
	ui:Text("Sub-actors:")

	ui:SameLineWithSpace()
	if ui:Button("Add Sub Actor...") then
		AddSubActor(params)
	end

	self:AddSectionEnder(ui)

	if params.subactors then
		for i, subactor in ipairs(params.subactors) do
			ui:Text(i)

			ui:SameLineWithSpace()
			ui:PushItemWidth(250)
			local label_changed, label = ui:InputText("Label##" .. i, subactor.label)
			if label_changed then
				subactor.label = label
			end
			ui:PopItemWidth()

			ui:SameLineWithSpace()
			local asigned_runtime_changed, assigned_at_runtime = ui:Checkbox("Assigned at Runtime##" .. i, subactor.assigned_at_runtime)
			if asigned_runtime_changed then
				subactor.assigned_at_runtime = assigned_at_runtime
			end
			if ui:IsItemHovered() then
				ui:SetTooltip("Pair with a custom function in lua upon playing the cinematic to assign already-spawned entities as subactors in the cinematic.")
			end

			local old_prefab_name = subactor.prefabname
			local prefab_name = PrefabEditorBase.PrefabPicker(ui, "Prefab##" .. i, subactor.prefabname, true)
			if prefab_name ~= old_prefab_name then
				subactor.prefabname = prefab_name
				if self.subactors[i] then
					self.subactors[i]:Remove()
				end

				if PrefabExists(prefab_name)  then
					self.subactors[i] = cineutil.Debug_SpawnActor(prefab_name, subactor)
				end
			end

			ui:PushItemWidth(200)

			subactor.start_pos = subactor.start_pos or {}
			self.editor:WorldPosition(ui, "Position Offset##" .. i, subactor.start_pos)
			if ui:IsItemHovered() then
				ui:SetTooltip("NOTE: This is an offset to Scene Actor World Position.")
			end

			ui:PopItemWidth()

			ui:SameLineWithSpace()
			local show_on_spawn_changed, showOnSpawn = ui:Checkbox("Show on Spawn##" .. i, subactor.show_on_spawn)
			if show_on_spawn_changed then
				subactor.show_on_spawn = showOnSpawn
			end

			ui:SameLineWithSpace()
			local face_left_changed, face_left = ui:Checkbox("Face Left##" .. i, subactor.face_left)
			if face_left_changed then
				subactor.face_left = face_left
			end

			ui:SameLineWithSpace()
			local kill_on_end_changed, killOnEnd = ui:Checkbox("Kill at End##" .. i, subactor.kill_on_end)
			if kill_on_end_changed then
				subactor.kill_on_end = killOnEnd
			end
			if ui:IsItemHovered() then
				ui:SetTooltip("Remove the sub actor at the end of cinematic.")
			end

			ui:PushItemWidth(200)
			subactor.end_pos = subactor.end_pos or {}
			self.editor:WorldPosition(ui, "End Position##" .. i, subactor.end_pos)
			if ui:IsItemHovered() then
				ui:SetTooltip("The sub actor's offset from the root position if the cinematic is skipped.")
			end
			ui:PopItemWidth()

			ui:PushItemWidth(250)
			ui:SameLineWithSpace()
			local skip_cine_state_changed, skip_cine_state = ui:InputText("Skip Cinematic State##" .. i, subactor.skip_cine_state)
			if skip_cine_state_changed then
				subactor.skip_cine_state = skip_cine_state
			end
			if ui:IsItemHovered() then
				ui:SetTooltip("The sub actor state to resume in if the cinematic is skipped.")
			end
			ui:PopItemWidth()

			if ui:Button("Remove##" .. i) then
				RemoveSubActor(params, i)
			end

			if i < #params.subactors then
				self:AddSectionEnder(ui)
			end
		end
	end

	self:AddSectionEnder(ui)

	params.is_skippable = ui:_Checkbox("Is Skippable", params.is_skippable) or nil

	if not self.testprefab then
		ui:Text("Click ".. self.test_label)
		return
	end

	if self.leadactor then
		if ui:Checkbox("Pause StateGraph", params.pause_role_sg.lead) then
			if params.pause_role_sg.lead then
				params.pause_role_sg.lead = nil
			else
				params.pause_role_sg.lead = {}
			end
		end
		if params.pause_role_sg.lead then
			ui:Indent() do
				params.pause_role_sg.lead.resumestate = self.editor:StateGraphStateName(ui, "State On Resume", params.pause_role_sg.lead.resumestate, self.leadactor)
			end ui:Unindent()
		end
	end

	ui:Value("Scene", self.testprefab.sg:GetCurrentState())

	self.params = params

	params.scene_duration = ui:_SliderInt("Scene Duration", params.scene_duration or 100, 10, 30 * SECONDS, "%d frames") or 0
	ui:InputInt("Current Frame", self.timeline.editor:get_current_frame(), nil, nil, ui.InputTextFlags.ReadOnly)

	if params.timelines then
		ensure_complete_timeline_data(params, timeline.actions)

		self.timeline.editor:set_data(params.scene_duration, timeline.actions, params.timelines, timeline.ui.prettyname)
		local modified, timeline_modified = self.timeline.editor:RenderEditor(ui, self, CineEditor._CreateTimelineEvent, CineEditor._DrawTimelineEvent)
		if modified then
			-- Reconcile timeline duration with event duration.
			for tl_name,val in pairs(params.timelines) do
				for tl_idx,ev in ipairs(val) do
					local start = ev[1]
					local stop = ev[2]
					local data = ev[3].param
					local eventtype = ev[3].eventtype

					local snap = 3
					-- full meaning "until the end"
					local uses_full_timeline = stop >= (params.scene_duration - snap)
					local uses_full_state = not data.duration or data.duration == 0

					do
						if timeline_modified then
							local eventdef = eventfuncs[eventtype]
							local frames = stop - start
							if uses_full_timeline and not eventdef.no_nil_duration then
								frames = nil
							end
							data.duration = frames
						else
							if uses_full_state then
								ev[2] = params.scene_duration
							else
								ev[2] = start + data.duration
							end
						end
					end

					if data.duration then
						-- Durations are frame counts, so don't allow floats for consistent serialization.
						data.duration = math.floor(data.duration)
					end
				end
			end
		end
	else
		-- This button prevents us from adding timeline data to every
		-- edited event. Once we've added it, we let Timeline handle
		-- creation.
		if ui:Button("Add Timeline") then
			ensure_complete_timeline_data(params, timeline.actions)
			self.timeline.editor:set_data(params.scene_duration, timeline.actions, params.timelines, timeline.ui.prettyname)
			local create_only_one = true
			self.timeline.editor:add_default_timeline(self, CineEditor._CreateTimelineEvent, create_only_one)
		end
	end
end

DebugNodes.CineEditor = CineEditor

return CineEditor
