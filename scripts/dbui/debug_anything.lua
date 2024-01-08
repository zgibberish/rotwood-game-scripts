local DebugNodes = require "dbui.debug_nodes"
local DebugSettings = require "debug.inspectors.debugsettings"
local iterator = require "util.iterator"
local lume = require "util.lume"

local DebugAnything = Class(DebugNodes.DebugNode, function(self)
	DebugNodes.DebugNode._ctor(self, "Debug Anything")
	self.text = ""
	self.history_idx = 1
	self.error_str = nil
	self.saved = DebugSettings("debuganything.saved")
		:Option("history", {})
end)

DebugAnything.PANEL_WIDTH = 500
DebugAnything.PANEL_HEIGHT = 500

local MAX_HISTORY = 20

local function InputTextCallback(self, ui, flags, key, str)
	-- TODO: use history and completion from ConsoleScreen. This is code copied from GL.
	if flags == ui.InputTextFlags.CallbackHistory then
		local ImGuiKey_UpArrow = 3
		local ImGuiKey_DownArrow = 4
		if key == ImGuiKey_UpArrow then
			self.history_idx = math.max(1, self.history_idx - 1)
		elseif key == ImGuiKey_DownArrow then
			self.history_idx = math.min(#self.saved.history, self.history_idx + 1)
		end
		return self.saved.history[ self.history_idx ]
	end
end

function DebugAnything:RenderPanel( ui, panel )

	if ui:Button("G") then
		DebugAnything.ChooseFromGlobals()
	end
	if ui:IsItemHovered() then
		ui:SetTooltip("Select from list of globals")
	end
	ui:SameLineWithSpace()

	local flags = (ui.InputTextFlags.EnterReturnsTrue
		| ui.InputTextFlags.CallbackHistory)
	local changed, text = ui:InputText("Variable to debug", self.text, flags, InputTextCallback, self, ui)

	if changed then
		self:LoadExpression(text)
		ui:SetKeyboardFocusHere(-1)
		self.text = ""
	end

	if self.error_str ~= nil then
		ui:Text(self.error_str)
	end

	if GetDebugTable() ~= nil then
		panel:AppendTable(ui, GetDebugTable())
		ui:SameLineWithSpace()
		ui:Text(self.saved.history[#self.saved.history])
	end

	ui:Spacing()
	ui:Separator()
	ui:TextColored(WEBCOLORS.KHAKI, "History")
	for _,val in iterator.ripairs(self.saved.history) do
		if ui:Button(val) then
			self:LoadExpression(val)
		end
	end
end

function DebugAnything:LoadExpression(text)
	local fn, err = load('SetDebugTable('.. text..')')
	if not fn then
		self.error_str = err
	else
		local ok, err = pcall(fn)
		if not ok then
			self.error_str = err
		else
			self.error_str = nil
		end
	end

	lume.remove(self.saved.history, text)
	table.insert(self.saved.history, text)
	if #self.saved.history > MAX_HISTORY then
		table.remove(self.saved.history, 1)
	end
	self.history_idx = #self.saved.history + 1
	self.saved:Set("history", self.saved.history)
	self.saved:Save()
end

function DebugAnything.OpenWithExpression(query)
	local panel = TheFrontEnd:FindOpenDebugPanel(DebugAnything) or DebugNodes.ShowDebugPanel(DebugAnything)
	local node = panel:GetNode()
	node:LoadExpression(query)
end

function DebugAnything.ChooseFromGlobals()
	local spawnlist = {}
	local interesting_types = {
		["table"] = true,
		userdata = true,
	}
	for key,val in pairs(_G) do
		if interesting_types[type(val)] then
			spawnlist[key] = DebugAnything.OpenWithExpression
		end
	end
	TheFrontEnd.debugMenu.quickfind:OpenListOfCommands(spawnlist)
end

DebugNodes.DebugAnything = DebugAnything

return DebugAnything
