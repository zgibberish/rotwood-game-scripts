local DebugNodes = require "dbui.debug_nodes"
require "constants"

local DebugConsole = Class(DebugNodes.DebugNode, function(self)
	DebugNodes.DebugNode._ctor(self, "Debug Console")
	self.logtext = GetConsoleOutputList()
	self.text = ""
	self.auto_scroll_to_bottom = true
	self.auto_focus = true
	self.history = {}
	self.history_idx = 1

	self:SetScrollToBottom()

	AddPrintLogger( function(...) self:OnPrint(...) end )
end)

DebugConsole.PANEL_WIDTH = 800
DebugConsole.PANEL_HEIGHT = 600

function DebugConsole:OnPrint(...)
	if self.auto_scroll_to_bottom then
		self:SetScrollToBottom()
	end
end

function DebugConsole:SetScrollToBottom()
	--jcheng: unclear why we have to set the scroll for a few frames...
	self.scroll_to_bottom = 10
end

local function InputTextCallback(self, ui, flags, key, str)
	-- TODO: use history and completion from ConsoleScreen. This is code copied from GL.
	if flags == ui.InputTextFlags.CallbackHistory then
		local ImGuiKey_UpArrow = 3
		local ImGuiKey_DownArrow = 4
		if key == ImGuiKey_UpArrow then
			self.history_idx = math.max(1, self.history_idx - 1)
		elseif key == ImGuiKey_DownArrow then
			self.history_idx = math.min(#self.history, self.history_idx + 1)
		end
		return self.history[ self.history_idx ]

	elseif flags == ui.InputTextFlags.CallbackCompletion then
		--~ local AutoComplete = require "util/autocomplete"
		--~ local t = AutoComplete( str, self:GetDebugEnv() )
		--~ return t and t[1]

	elseif flags == ui.InputTextFlags.CallbackAlways then
		self.text = str
	end
end

function DebugConsole:RenderPanel( ui, node )

	local offset = -30

	ui:BeginChild("Output", 0, offset, true, ui.WindowFlags.HorizontalScrollbar)
	ui:Text(table.concat(self.logtext, "\n"))

	if self.scroll_to_bottom > 0 then
		ui:SetScrollHereY(1)
		self.scroll_to_bottom = self.scroll_to_bottom - 1
	end

	ui:EndChild()

	local flags = (ui.InputTextFlags.EnterReturnsTrue
		| ui.InputTextFlags.CallbackHistory
		| ui.InputTextFlags.CallbackCompletion
		| ui.InputTextFlags.CallbackAlways)
	local changed, text = ui:InputText("##Console", self.text, flags, InputTextCallback, self, ui)

	if self.auto_focus then
		ui:SetKeyboardFocusHere(-1)
		self.auto_focus = false
	end

	if changed then
		ExecuteConsoleCommand(text)
		ui:SetKeyboardFocusHere(-1)
		table.insert(self.history, text)
		self.history_idx = #self.history + 1
		self.text = ""
		self:SetScrollToBottom()
	end

	ui:SameLineWithSpace()
	local changed, v = ui:Checkbox("Auto scroll", self.auto_scroll_to_bottom)
	if changed then
		self.auto_scroll_to_bottom = v
	end

end

DebugNodes.DebugConsole = DebugConsole

return DebugConsole
