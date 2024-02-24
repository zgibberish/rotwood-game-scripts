local DebugEntity = require "dbui.debug_entity"
local DebugNodes = require "dbui.debug_nodes"
local EventFuncEditor = require "debug.inspectors.eventfunceditor"
local eventfuncs = require "eventfuncs"
local fmodtable = require "defs.sound.fmodtable"
local kstring = require "util.kstring"
local lume = require "util.lume"
require "consolecommands"
require "constants"


if Profile:GetValue("auto_start_audio_debugging") then
	require "debugsounds"
end


local SoundDebug

local DebugAudio = Class(DebugNodes.DebugNode, function(self)
	DebugNodes.DebugNode._ctor(self, "Debug Audio")

	if not package.loaded["debugsounds"] then
		require "debugsounds"
	end

	SoundDebug = SoundEmitter.SoundDebug

	SOUNDDEBUG_ENABLED = true
	SOUNDDEBUGUI_ENABLED = true

	self.auto_start = Profile:GetValue("auto_start_audio_debugging") or false

	self.recent_filters = {}

	self.efeditor = EventFuncEditor(self)
	self.test_sounds = {}

end)

DebugAudio.PANEL_WIDTH = 900
DebugAudio.PANEL_HEIGHT = 600


local function SoundGlobalParam(ui, param)
	local soundnames = lume.keys(fmodtable.GlobalParameter)
	table.sort(soundnames, kstring.cmp_alpha_case_insensitive)
	table.insert(soundnames, 1, "")

	param.sound_globparamname = ui:_ComboAsString("GlobalParameter", param.sound_globparamname, soundnames, true)

	do ui:Indent()
		if param.sound_globparamname then
			local param_name = fmodtable.GlobalParameter[param.sound_globparamname]
			local val, final_val = TheAudio:GetGlobalParameter(param_name)
			local changed, newval = ui:DragFloat("Set Param##globparam", val, 0.01, -100, 100)
			if changed then
				TheAudio:SetGlobalParameter(param_name, newval)
			end
			-- When fmod changes params, the value is unchanged but the final value changes.
			-- Fmod docs:
			--   The final value of the parameter after applying adjustments
			--   due to automation, modulation, seek speed, and parameter
			--   velocity to value.
			ui:Value("Final Value", final_val)
		else
			ui:PushDisabledStyle()
			ui:DragFloat("Param Value##globparam", 0, 1, -100, 100)
			ui:PopDisabledStyle()
		end

		if ui:Button("Log Global Parameter Names") then
			TheAudio:LogGlobalParameters()
			print("GlobalParameters logging does't show up in lua log, so check TheSim:OpenGameLogFolder()")
		end
		ui:SameLineWithSpace()
		if ui:Button("Log Folder") then
			TheSim:OpenGameLogFolder()
		end
	end ui:Unindent()

	return param.sound_globparamname
end

function DebugAudio:TogglePauseCapture()
	SOUNDDEBUG_ENABLED = not SOUNDDEBUG_ENABLED
end

function DebugAudio:PauseButton(ui)
	local win_w = ui:GetColumnWidth()
	ui:SameLine(win_w-60)
	if SOUNDDEBUG_ENABLED then
		if ui:Button("Pause",60) then
			SOUNDDEBUG_ENABLED = false
		end
	else
		if ui:Button("Resume",60) then
			SOUNDDEBUG_ENABLED = true
		end
	end
end

function DebugAudio:_MatchesFilter(filter_text, info, name)
	return (not filter_text
		or string.find(info.event, filter_text)
		or string.find(name or "", filter_text))
end

function DebugAudio:RenderPanel( ui, panel )

	if ui:CollapsingHeader("Test Sounds") then
		self.efeditor:SoundEffect(ui, self.test_sounds, true)
		self.efeditor:SoundSnapshot(ui, self.test_sounds, true)
		SoundGlobalParam(ui, self.test_sounds)
	end

	if ui:CollapsingHeader("Settings") then

		local auto_start_changed, auto_start = ui:Checkbox("Auto Start Audio Debugging", self.auto_start )
		if auto_start_changed then
			self.auto_start = auto_start
			Profile:SetValue("auto_start_audio_debugging", self.auto_start)
			Profile.dirty = true
			Profile:Save()
		end
		if ui:IsItemHovered() then
			ui:SetTooltip( "This value saves and requires a reload to take into effect." )
		end

		if ui:Checkbox("Show error screen on missing audio", self.error_on_missing) then
			self.error_on_missing = true
			d_audio_error_on_missing()
		end
		if ui:IsItemHovered() then
			ui:SetTooltip("Crashes with callstack when using an invalid fmodtable entry. Restart to disable.")
		end

		local volume_slider = function( title, setting_name )
			ui:Text(title)
			ui:NextColumn()

			local volume = TheGameSettings:Get(setting_name)
			local changed, new_v = ui:SliderInt("##"..setting_name, volume, 0, 100 )
			if changed then
				TheGameSettings:Set(setting_name, new_v)
			end
			ui:NextColumn()
		end

		ui:Columns(2, "volume", false)

		volume_slider("SFX Volume", "audio.sfx_volume")
		volume_slider("Music Volume", "audio.music_volume")
		volume_slider("Ambience Volume", "audio.ambience_volume")
		volume_slider("Voice Volume", "audio.voice_volume")

		ui:Text("Max Recent Sounds")
		ui:NextColumn()
		local changed, new_v = ui:SliderInt("###max_recent_sounds", SoundDebug.maxRecentSounds, 5, 100 )
		SoundDebug.maxRecentSounds = changed and new_v or SoundDebug.maxRecentSounds
		ui:NextColumn()

		ui:Text("Max Distance")
		ui:NextColumn()
		local changed, new_v = ui:SliderInt("###max_distance", SoundDebug.maxDistance, 5, 100 )
		SoundDebug.maxDistance = changed and new_v or SoundDebug.maxDistance
		ui:NextColumn()

		ui:Columns(1)

	end

	if ui:CollapsingHeader("Devices") then
		local devices = TheAudio:GetOutputDevices() or table.empty
		for _,dev in ipairs(devices) do
			local is_selected = self.selected_device == dev.id
			if ui:Selectable(dev.name, is_selected) then
				self.selected_device = dev.id
				TheAudio:SelectOutputDeviceById(dev.id)
				TheLog.ch.Debug:print("TheAudio:SelectOutputDeviceById", dev.name, dev.id)
			end
		end
	end

	local show_params = function(info)
		local params = ""

		if info.params then
			for k,v in pairs(info.params) do
				params = k.."="..v.."\n"..params
			end
		end

		ui:Text(params)
		ui:SetTooltipIfHovered(params)
	end

	local show_event = function(info)
		local idstr = info.count and "["..tostring(info.count).."] " or ""
		local event_str = info.event

		if info.event:find("dontstarve/") then
			event_str = string.match( info.event, "dontstarve%/(.*)" ) or ""
		end

		if info.event:find("together/") then
			event_str = string.match( info.event, "together%/(.*)" ) or ""
		end

		local clicked
		if info.event_source then
			ui:PushStyleColor(ui.Col.Text, WEBCOLORS.YELLOW)
			clicked = ui:Selectable( idstr..event_str, false )
			ui:PopStyleColor(1)
		else
			clicked = ui:Selectable( idstr..event_str, false )
		end

		if clicked then
			ui:SetClipboardText(info.callstack)
		end

		if ui:IsItemHovered() then
			local tooltip = info.event.."\n\n"
			if info.event_source then
				tooltip = tooltip..info.event_source.."\n\n"
			end
			tooltip = tooltip..info.callstack
			ui:SetTooltip( tooltip )
		end
	end

	local function show_widget(info, id)
		local label = ("%s##widget_%i"):format(tostring(info.widget), id)
		if ui:Selectable(label, false) and info.widget then
			d_viewinpanel_autosize(info.widget)
		end
		ui:SetTooltipIfHovered({
				"Click to inspect the widget.",
				"For buttons, Name is usually their text label.",
				"Name: ".. tostring(info.widget and info.widget.name),
				"Entity: ".. tostring(info.widget and info.widget.inst),
			})
	end

	local show_guid_button = function(info)
		if ui:Button( "Inspect"..string.format("###_guid_%s_%d", info.count or "", info.guid), Ents[info.guid] ) then
			panel:PushNode( DebugEntity(Ents[info.guid]) )
		end

		ui:SameLine()

		if ui:Button( "Teleport to"..string.format("###_teleport_%s_%d", info.count or "", info.guid), Ents[info.guid] ) then
			c_goto(Ents[info.guid])
		end
	end

	local kill_btn_w = 25
	local guid_btn_w = 140
	local volume_w = 58
	local widget_w = 100
	local dist_w = 80

	if ui:CollapsingHeader("Named UI Sounds") then
		self.recent_filters.namedui = ui:_FilterBar(self.recent_filters.namedui, nil, "Filter named ui sounds...")

		local col_w = ui:GetColumnWidth()
		col_w = col_w - (kill_btn_w + volume_w + widget_w)

		ui:Columns(6, "named ui sounds")

		ui:SetColumnWidth(-1, 15 + kill_btn_w)
		ui:Text("Actions")
		ui:NextColumn()
		ui:SetColumnWidth(-1, col_w * 0.35)
		ui:Text("Name")
		ui:NextColumn()
		ui:SetColumnWidth(-1, col_w * 0.35)
		ui:Text("Event")
		ui:NextColumn()
		ui:SetColumnWidth(-1, volume_w)
		ui:Text("Volume")
		ui:NextColumn()
		ui:Text("Widget")
		ui:SetColumnWidth(-1, widget_w)
		ui:NextColumn()
		ui:Text("Params")
		ui:NextColumn()

		local i = 0
		for name, info in pairs(SoundDebug.loopingUISounds) do
			info.count = i
			i = i + 1

			if self:_MatchesFilter(self.recent_filters.namedui, info, name) then
				ui:Separator()

				if ui:Button( "Kill###kill_"..info.count ) then
					info.owner.SoundEmitter:KillSound(name)
				end
				ui:NextColumn()

				ui:Text(name)
				ui:NextColumn()
				show_event(info)
				ui:NextColumn()
				ui:Text(info.volume)
				ui:NextColumn()

				show_widget(info, i)
				ui:NextColumn()

				show_params(info)
				ui:NextColumn()
			end
		end

		ui:Columns(1)
	end

	if ui:CollapsingHeader("Recent UI Sounds") then
		self.recent_filters.ui = ui:_FilterBar(self.recent_filters.ui, nil, "Filter recent ui sounds...")

		ui:Columns(3, "recent ui sounds")

		ui:Text("Event")
		ui:NextColumn()
		ui:SetColumnWidth(-1, volume_w)
		ui:Text("Volume")
		ui:NextColumn()
		ui:Text("Widget")
		ui:NextColumn()

		for i = SoundDebug.uiSoundCount - SoundDebug.maxRecentSounds + 1, SoundDebug.uiSoundCount do
			local index = (i % SoundDebug.maxRecentSounds)+1
			local info = SoundDebug.uiSounds[index]
			if SoundDebug.uiSounds[index]
				and self:_MatchesFilter(self.recent_filters.ui, info)
			then

				ui:Separator()

				show_event(info)
				ui:NextColumn()

				ui:Text(info.volume)
				ui:NextColumn()

				show_widget(info, i)
				ui:NextColumn()
			end
		end

		ui:Columns(1)
	end


	if ui:CollapsingHeader("Named World Sounds") then
		local col_w = ui:GetColumnWidth()
		local pos_w = math.min(col_w * 0.1, 140)

		self.recent_filters.namedworld = ui:_FilterBar(self.recent_filters.namedworld, nil, "Filter named world sounds...")

		ui:Columns(8, "named sounds")

		col_w = col_w - (kill_btn_w + guid_btn_w + pos_w)

		ui:SetColumnWidth(-1, kill_btn_w + guid_btn_w)
		ui:Text("Actions")
		ui:NextColumn()

		ui:SetColumnWidth(-1, col_w * 0.2)
		ui:Text("Name")
		ui:NextColumn()

		ui:SetColumnWidth(-1, col_w * 0.3)
		ui:Text("Event")
		ui:NextColumn()

		ui:SetColumnWidth(-1, col_w * 0.2)
		ui:Text("Prefab")
		ui:NextColumn()

		ui:SetColumnWidth(-1, pos_w)
		ui:Text("Pos")
		ui:NextColumn()

		ui:SetColumnWidth(-1, dist_w)
		ui:Text("Distance")
		ui:NextColumn()
		ui:SetColumnWidth(-1, volume_w)
		ui:Text("Volume")
		ui:NextColumn()
		ui:Text("Params")
		ui:NextColumn()

		local i = 0
		for ent,sounds in pairs(SoundDebug.loopingSounds) do
			for name, info in pairs(sounds) do
				if self:_MatchesFilter(self.recent_filters.namedworld, info, name)
					and (info.dist < SoundDebug.maxDistance
						or not info.pos
						or info.pos:is_zero())
				then

					info.count = i
					i = i + 1

					ui:Separator()

					if ui:Button( "Kill###kill_"..info.count ) then
						info.owner.SoundEmitter:KillSound(name)
					end
					ui:SameLine()
					show_guid_button(info)
					ui:NextColumn()

					ui:Text(name)
					ui:NextColumn()
					show_event(info)
					ui:NextColumn()
					ui:Text(info.prefab)
					ui:NextColumn()
					ui:Text(tostring(info.pos))
					ui:NextColumn()
					ui:Text(info.dist)
					ui:NextColumn()
					ui:Text(info.volume)
					ui:NextColumn()
					show_params(info)
					ui:NextColumn()

				end
			end
		end

		ui:Columns(1)
	end

	if ui:CollapsingHeader("Recent World Sounds") then
		local col_w = ui:GetColumnWidth()
		col_w = col_w - (guid_btn_w + dist_w + volume_w)

		self.recent_filters.world = ui:_FilterBar(self.recent_filters.world, nil, "Filter recent world sounds...")

		self:PauseButton(ui)

		ui:Columns(6, "recent sounds")

		ui:SetColumnWidth(-1, guid_btn_w)
		ui:Text("Actions")
		ui:NextColumn()
		ui:SetColumnWidth(-1, col_w * 0.4)
		ui:Text("Event")
		ui:NextColumn()
		ui:SetColumnWidth(-1, col_w * 0.3)
		ui:Text("Prefab")
		ui:NextColumn()
		-- ui:Text("Pos")
		-- ui:NextColumn()
		ui:SetColumnWidth(-1, dist_w)
		ui:Text("Distance")
		ui:NextColumn()
		ui:SetColumnWidth(-1, volume_w)
		ui:Text("Volume")
		ui:NextColumn()
		ui:Text("Params")
		ui:NextColumn()

		for i = SoundDebug.soundCount, SoundDebug.soundCount - SoundDebug.maxRecentSounds + 1, -1 do
			local index = (i % SoundDebug.maxRecentSounds)+1
			if SoundDebug.nearbySounds[index] then

				local info = SoundDebug.nearbySounds[index]

				if self:_MatchesFilter(self.recent_filters.world, info) then
					ui:Separator()

					show_guid_button(info)
					ui:NextColumn()

					show_event(info)
					ui:NextColumn()

					ui:Text(info.prefab)
					ui:NextColumn()

					ui:Text(info.dist)
					ui:NextColumn()

					ui:Text(info.volume)
					ui:NextColumn()

					show_params(info)
					ui:NextColumn()
				end
			end
		end

		ui:Columns(1)
	end


	if ui:CollapsingHeader("Tracked Sounds") then
		if ui:Button("Search data for tracking") then
			local FxAutogenData = require "prefabs.fx_autogen_data"

			local playsound = eventfuncs.playsound.name
			local tracked = {}
			for ev, embellishment, sg_name in embellishutil.EventIterator() do
				if ev.eventtype == playsound and ev.param.sound_max_count then
					local t = tracked[embellishment] or {}
					tracked[embellishment] = t
					table.insert(t, {
							source = "embellisher",
							name = embellishment,
							soundevent = ev.param.soundevent,
							max_count = ev.param.sound_max_count,
						})
				end
			end

			for prefab,params in pairs(FxAutogenData) do
				dbassert(not tracked[prefab], "Duplicate embellisher and fx name!")
				if params.sound_max_count then
					tracked[prefab] = {
						source = "fx",
						name = prefab,
						soundevent = params.soundevent,
						max_count = params.sound_max_count,
					}
				end
			end

			TheSim:SetPersistentString("trackedsounds.json", json.encode_compliant(tracked))
			TheSim:OpenGameSaveFolder()

			ui:SetClipboardText(table.inspect(tracked))
			-- Convert entries to string to make them easier to view.
			tracked = lume.map(tracked, table.inspect)
			panel:PushNode(DebugNodes.DebugTable(tracked), "Tracked Sounds")
		end
		for guid,ent in pairs(Ents) do
			if ent:IsValid()
				and ent.components.soundtracker
			then
				ui:TextColored(self.colorscheme.header, "Tracker: ".. tostring(ent))
				ui:Indent() do
					ent.components.soundtracker:DebugDrawEntity(ui, nil, self.colorscheme)
				end ui:Unindent()
			end
		end
	end

end

DebugNodes.DebugAudio = DebugAudio

return DebugAudio
