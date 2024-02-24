local DebugNodes = require "dbui.debug_nodes"
local DebugSettings = require "debug.inspectors.debugsettings"
local EditorBase = require "debug.inspectors.editorbase"
local LuaCompleter = require "util.luacompleter"
local Screen = require "widgets/screen"
local Text = require "widgets/text"
local TextEdit = require "widgets/textedit"
local Widget = require "widgets/widget"
local lume = require "util.lume"
require "util.colorutil"
require "util"


-- History saves between game runs.
--
-- To enforce a consistent MRU on each game start, add to your customcommands.lua:
--      require "screens/consolescreen"
--      AppendConsoleHistoryItem('c_give("batbat")')
-- Or to start each session with an empty history:
--      SetConsoleHistory({''})

local console_options = DebugSettings("consolescreen.console_options")
	:Option("history", {})
	:Option("history_max_count", 20)

local ConsoleScreen = Class(Screen, function(self)
	Screen._ctor(self, "ConsoleScreen")
    self.runtask = nil
	self:DoInit()

	self.ctrl_pasting = false

	-- Typing shift will change debugwidget focus which is usually not what you want.
	local panel = TheFrontEnd:FindOpenDebugPanel(DebugNodes.DebugWidget)
	if panel then
		local node = panel:GetNode()
		node.can_select = false
	end

	if IsPaused() then
		-- Pause: We get stuck if sim is paused after running a command.
		SetGameplayPause(false)
	end
end)

function ConsoleScreen:DebugDraw_AddSection(ui, panel)
	ConsoleScreen._base.DebugDraw_AddSection(self, ui, panel)

	ui:Spacing()
	ui:Text("ConsoleScreen")
	ui:Indent() do
		self.completer:DebugDraw_AddSection(ui, panel)
	end
	ui:Unindent()
end

function ConsoleScreen:OnBecomeActive()
	ConsoleScreen._base.OnBecomeActive(self)
	TheFrontEnd:ShowConsoleLog()

	self.console_edit:SetFocus()
	self.console_edit:SetEditing(true)

	self.completer:ClearState()

    self:ToggleRemoteExecute(true) -- if we are admin, start in remote mode
end

function ConsoleScreen:OnBecomeInactive()
    ConsoleScreen._base.OnBecomeInactive(self)

    if self.runtask ~= nil then
        self.runtask:Cancel()
        self.runtask = nil
    end
end

function ConsoleScreen:OnControl(controls, down)
	if self.runtask ~= nil or ConsoleScreen._base.OnControl(self, controls, down) then return true end

	if not down and controls:Has(Controls.Digital.CANCEL, Controls.Digital.OPEN_DEBUG_CONSOLE) then
		self:Close()
		return true
	end
end

function ConsoleScreen:ToggleRemoteExecute(force)
    local is_valid_time_to_use_remote = false -- NW networking2022: remove this: TheNet:GetIsClient() and (TheNet:GetIsServerAdmin() or Platform.IsConsole())
    if is_valid_time_to_use_remote then
        self.console_remote_execute:Show()
        if force == nil then
            self.toggle_remote_execute = not self.toggle_remote_execute
        elseif force == true then
            self.toggle_remote_execute = true
        elseif force == false then
            self.toggle_remote_execute = false
        end

        if self.toggle_remote_execute then
			self.console_remote_execute:SetText(STRINGS.UI.CONSOLESCREEN.REMOTEEXECUTE)
			self.console_remote_execute:SetGlyphColor(0.7,0.7,1,1)
        else
			self.console_remote_execute:SetText(STRINGS.UI.CONSOLESCREEN.LOCALEXECUTE)
			self.console_remote_execute:SetGlyphColor(1,0.7,0.7,1)
        end
    elseif self.toggle_remote_execute then
        self.console_remote_execute:Hide()
        self.toggle_remote_execute = false
    end
end

function ConsoleScreen:OnRawKey(key, down)
	if TheInput:IsKeyDown(InputConstants.Keys.CTRL) and TheInput:IsPasteKey(key) then
		self.ctrl_pasting = true
	end

	if down then return end

	if self.runtask ~= nil then return true end
	if ConsoleScreen._base.OnRawKey(self, key, down) then
		return true
	end

	return self:OnRawKeyHandler(key, down)
end

function ConsoleScreen:OnRawKeyHandler(key, down)
	if TheInput:IsKeyDown(InputConstants.Keys.CTRL) and TheInput:IsPasteKey(key) then
		self.ctrl_pasting = true
	end

	if down then return end

	if key == InputConstants.Keys.UP then
		self:_CycleHistory(-1)
	elseif key == InputConstants.Keys.DOWN then
		self:_CycleHistory(1)
	elseif (key == InputConstants.Keys.LCTRL or key == InputConstants.Keys.RCTRL) and not self.ctrl_pasting then
       self:ToggleRemoteExecute()
	end

	if self.ctrl_pasting and (key == InputConstants.Keys.LCTRL or key == InputConstants.Keys.RCTRL) then
		self.ctrl_pasting = false
	end

	return true
end

function ConsoleScreen:_CycleHistory(direction)
	-- Prediction is never valid while cycling history.
	self.console_edit.prediction_widget:Dismiss()

	local len = #console_options.history
	if len > 0 then
		local before = self.history_idx
		if self.history_idx then
			self.history_idx = lume.clamp(self.history_idx + direction, 1, len)
		elseif direction < 0 then
			self.history_idx = len
		elseif direction > 0 then
			self.history_idx = 1
		end
		if before == self.history_idx and self.history_idx == len then
			-- Past the bottom.
			self.console_edit:SetString("")
		else
			self.console_edit:SetString( console_options.history[ self.history_idx ] )
			self:_ShowHistoryPosition(self.history_idx, len)
		end
	end
end

function ConsoleScreen:_ShowHistoryPosition(idx, count)
	if self.history_hide_task then
		self.history_hide_task:Cancel()
	end
	self.history_display:SetText(("%d/%d"):format(idx, count))
		:Show()
	self.history_hide_task = self.inst:DoTaskInTime(1, function(inst_)
		self.history_display:Hide()
	end)
end

function ConsoleScreen:Run()
	local fnstr = self.console_edit:GetText()

	SuUsedAdd("console_used")

	if fnstr ~= "" then
		AppendConsoleHistoryItem(fnstr)
	end

	if self.toggle_remote_execute then
		local x, z = TheSim:ScreenToWorldXZ(TheInput:GetMousePos())
		TheNet:SendRemoteExecute(fnstr, x, z)
	else
		local success = ExecuteConsoleCommand(fnstr)
		self.did_last_run_fail = not success
	end
end

function ConsoleScreen:Close()
	--SetPause(false)
	TheInput:EnableDebugToggle(true)
	TheFrontEnd:PopScreen(self)
	local always_on = DEV_MODE and TheFrontEnd.settings.console_log_always_on
	if not self.did_last_run_fail
		and not always_on
	then
		TheFrontEnd:HideConsoleLog()
	end
end

local function DoRun(inst, self)
    self.runtask = nil
    self:Run()
    self:Close()
    if TheFrontEnd.consoletext.closeonrun then
        TheFrontEnd:HideConsoleLog()
    end
end

function ConsoleScreen:OnTextEntered(text)
    if self.runtask ~= nil then
        self.runtask:Cancel()
    end
    self.runtask = self.inst:DoTaskInTime(0, DoRun, self)
end

function GetConsoleHistory()
	return console_options.history
end

function SetConsoleHistory(history)
    if type(history) == "table" and type(history[1]) == "string" then
        console_options:Set("history", history)
        console_options:Save()
    end
end

function AppendConsoleHistoryItem(cmdstr)
	-- Remove if already exists to avoid scrolling through duplicates. Need
	-- latest command is at the end of history for run last command to
	-- work.
	local history = console_options.history
	lume.remove(history, cmdstr)
	table.insert(history, cmdstr)
	history = lume.last(history, console_options.history_max_count)
	console_options:Set("history", history)
	console_options:Save()
end

function ConsoleScreen:DoInit()
	--SetPause(true,"console")
	TheInput:EnableDebugToggle(false)

	local fontsize = 30 * HACK_FOR_4K
	local edit_width = 900 * HACK_FOR_4K

	self.edit_width   = edit_width

	self.anchor = self:AddChild(Widget())
    self.anchor:SetAnchors("center","bottom")
	self.root = self.anchor:AddChild(Widget())
	self.root:SetPosition(0,100 * HACK_FOR_4K,0)

	self.console_remote_execute = self.root:AddChild( Text( FONTFACE.DEFAULT, fontsize ) )
	self.console_remote_execute:SetText( STRINGS.UI.CONSOLESCREEN.REMOTEEXECUTE )
	self.console_remote_execute:SetRegionSize( 200 * HACK_FOR_4K, fontsize + 5 )
	self.console_remote_execute:SetPosition( -edit_width*0.5 - 130, 0 )
	self.console_remote_execute:SetHAlign( ANCHOR_RIGHT )
	self.console_remote_execute:SetGlyphColor( 0.7, 0.7, 1, 1 )
	self.console_remote_execute:Hide()

	self.history_display = self.root:AddChild( Text( FONTFACE.DEFAULT, fontsize ) )
		:SetAnchors("right", "center")
		:Offset(50 * HACK_FOR_4K, 0)
		:Hide()

	self.console_edit = self.root:AddChild(TextEdit(FONTFACE.CODE))
		:SetSize(edit_width)
		:SetHelpTextEdit("...")
		:SetHAlign(ANCHOR_LEFT)
		:LayoutBounds("center", "bottom", 0, 0)
    self.console_edit.ignoreVirtualKeyboard = true

	self.console_edit.OnTextEntered = function(self_, text) self:OnTextEntered(text) end
	self.console_edit:SetInvalidCharacterFilter( [[`	]] )
    self.console_edit:SetPassControlToScreen(Controls.Digital.CANCEL, true)

	self.console_edit:SetString("")

	--setup prefab keys
	local prefab_names = EditorBase.GetAllPrefabNames()

	local Power = require "defs.powers"
	local power_names = Power.GetQualifiedNames()

	self.completer = LuaCompleter()

	self.console_edit:EnableWordPrediction({width = self.edit_width + 20 * HACK_FOR_4K, pad_x = -15 * HACK_FOR_4K, pad_y = 20 * HACK_FOR_4K, mode=Profile:GetConsoleAutocompleteMode()})

	for _,delim in ipairs({'"', "'",}) do
		self.console_edit:AddWordPredictionDictionary({name = "prefab", words = prefab_names, prefix = delim, postfix = delim, })
		-- TODO(dbriscoe): Can we require a function (c_power) before these words to reduce noise?
		self.console_edit:AddWordPredictionDictionary({name = "power",  words = power_names,  prefix = delim, postfix = delim, })
	end

	self.console_edit:AddWordPredictionDictionary(self.completer:CreateWordPredictionDictionary())

	self.console_edit:SetForceEdit(true)
    self.console_edit.OnStopForceEdit = function() self:Close() end
    self.console_edit.OnRawKey = function(s, key, down) if TextEdit.OnRawKey(self.console_edit, key, down) then return true end self:OnRawKeyHandler(key, down) end

	self.console_edit.validrawkeys[InputConstants.Keys.LCTRL] = true
	self.console_edit.validrawkeys[InputConstants.Keys.RCTRL] = true
	self.console_edit.validrawkeys[InputConstants.Keys.UP] = true
	self.console_edit.validrawkeys[InputConstants.Keys.DOWN] = true
	self.toggle_remote_execute = false

end

return ConsoleScreen
