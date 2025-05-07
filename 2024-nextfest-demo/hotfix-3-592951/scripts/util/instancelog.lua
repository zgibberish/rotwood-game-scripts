local lume = require "util.lume"


-- Basic table only for use as a mixin.
local InstanceLog = {}


-- Logging is only displayed in DebugEntity after you click Start Logging.
-- Default noop so no cost when not using. Don't do any work to construct
-- arguments to Logf (string concat, etc)!
-- Pass a format string and values. You can use %s for all values.
function InstanceLog:Logf()
end
local function _LogFormatImpl(self, fmt, ...)
	local line = ("%i  %s"):format(GetTick(), fmt:format(...))
	table.insert(self.log, line)
end

-- Logging is only displayed in DebugEntity after you click Start Logging.
-- Default noop so no cost when not using. Don't do any work to construct
-- arguments to Logf (string concat, etc)!
-- Pass a format string and values. You can use %s for all values.
function InstanceLog:LogTable(name, t, depth)
end
local function _LogTableImpl(self, name, t, depth)
	local line = ("%i  %s = %s"):format(GetTick(), name or tostring(t), table.inspect(t, { depth = depth or 1, process = table.inspect.processes.skip_mt, }))
	table.insert(self.log, line)
end

function InstanceLog:StartLogging()
	self.log = {}
	self.Logf = _LogFormatImpl
	self.LogTable = _LogTableImpl
end

function InstanceLog:DebugDraw_Log(ui, panel, colors)
	if not self.log then
		if ui:Button("Start Logging") then
			self:StartLogging()
		end
		return
	end

	if ui:CollapsingHeader("Log", ui.TreeNodeFlags.DefaultOpen) then
		ui:Indent() do
			if ui:Button("Clear Log") then
				self.log = {}
			end
			self.log_filter = ui:_FilterBar(self.log_filter, nil, "Filter lines...")
			if #self.log > 0 then
				local log = self.log
				if self.log_filter then
					log = lume.filter(log, function(v)
						return v:find(self.log_filter)
					end)
				end
				ui:TextWrapped(table.concat(log, "\n"))
			end
		end ui:Unindent()
	end
end

return InstanceLog
