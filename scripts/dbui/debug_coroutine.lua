local DebugNodes = require "dbui.debug_nodes"

--------------------------------------------------------------------
-- A debug source for a coroutine.

local DebugCoroutine = Class(DebugNodes.DebugNode, function(self, ...)
	self:init(...)
end)

DebugCoroutine.REGISTERED_TYPE = "thread"

function DebugCoroutine:init(c, msg)
	DebugNodes.DebugNode._ctor(self, "DebugCoroutine")
	self.forbid_sticky = true -- Won't know what thread we were looking at.
	self.c = c
	self.msg = msg
	self.locals = {}
end

function DebugCoroutine:SetCoro(c)
	self.c = c
end

function DebugCoroutine:RenderPanel(ui, panel)
	if self.msg then
		ui:Text(self.msg)
		ui:Spacing()
	end

	ui:Text("Status:")
	ui:SameLine(0, 5)
	ui:TextColored(WEBCOLORS.ORCHID, coroutine.status(self.c))
	ui:Text("stack traceback:")
	ui:SameLineWithSpace()
	local wants_copy = ui:Button(ui.icon.copy)

	local lines = {}

	local i = 1
	while true do
		local info = debug.getinfo(self.c, i)
		if info then
			local fnname = info.name or string.format("<%s:%d>", info.short_src, info.linedefined)
			-- info.short_src with this format string matches output of
			-- debug.traceback() aside from leading whitespace.
			local txt = string.format("%s:%d: in function '%s'", info.short_src, info.currentline, fnname)
			table.insert(lines, txt)
			local is_selected = self.selected_frame == i
			if ui:Selectable(txt, is_selected) then
				if is_selected then
					self.selected_frame = nil
				else
					self.selected_frame = i
				end
			end
			if self.selected_frame == i then
				ui:Indent(20)
				self:RenderLocals(ui, panel, i, info)
				ui:Unindent(20)
			end
			i = i + 1
		else
			break
		end
	end

	if wants_copy then
		-- Include leading tab to better match debug.traceback.
		ui:SetClipboardText(table.concat(lines, "\n\t"))
	end
end

function DebugCoroutine:RenderLocals(ui, panel, frame_idx, info)
	table.clear(self.locals)
	local i = 1
	while true do
		local k, v = debug.getlocal(self.c, frame_idx, i)
		if k == nil then
			break
		else
			self.locals[ k ] = v
			i = i + 1
		end
	end
	panel:AppendKeyValues(ui, self.locals)
end


DebugNodes.DebugCoroutine = DebugCoroutine

return DebugCoroutine
