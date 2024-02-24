local kstring = require "util.kstring"


PRINT_SOURCE = false

local print_loggers = {}

function AddPrintLogger( fn )
    table.insert(print_loggers, fn)
end

global("CWD")

local dir = CWD or ""
dir = string.gsub(dir, "\\", "/") .. "/"
local oldprint = print

matches =
{
	["^"] = "%^",
	["$"] = "%$",
	["("] = "%(",
	[")"] = "%)",
	["%"] = "%%",
	["."] = "%.",
	["["] = "%[",
	["]"] = "%]",
	["*"] = "%*",
	["+"] = "%+",
	["-"] = "%-",
	["?"] = "%?",
	["\0"] = "%z",
}
function escape_lua_pattern(s)
	return (s:gsub(".", matches))
end


local function packstring(...)
    local str = ""
    local n = select('#', ...)
    local args = toarray(...)
    for i=1,n do
        str = str..tostring(args[i]).."\t"
    end
    return str
end
-- Wraps print in code that shows what line number it is coming from, and pushes it out to all of the print loggers
print = function(...)

    local str = ""
    if PRINT_SOURCE then
        local info = debug.getinfo(2, "Sl")
        local source = info and info.source
        if source then
            str = string.format("%s(%d,1) %s", source, info.currentline, packstring(...))
        else
            str = packstring(...)
        end
    else
        str = packstring(...)
    end

	-- Enable to track down where spam comes from.
	--~ str = str .. debug.traceback("")

    for i,v in ipairs(print_loggers) do
        v(str)
    end

end

-- Print without showing your line number (in the interactive console)
nolineprint = function(...)
	local str = packstring(...)
    for i,v in ipairs(print_loggers) do
        v(str)
    end
end


-- Keeps a record of the last n print lines, so that we can feed it into the debug console when it is visible
local debugstr = {}
local MAX_CONSOLE_LINES = 200

local consolelog = function(...)
    local str = packstring(...)
    str = string.gsub(str, dir, "")

    for idx,line in ipairs(kstring.split(str, "\r\n")) do
        table.insert(debugstr, line)
    end

    while #debugstr > MAX_CONSOLE_LINES do
        table.remove(debugstr,1)
    end
end

function GetConsoleOutputList()
    return debugstr
end

-- add our print loggers
if Platform.IsNotConsole() then
	AddPrintLogger(consolelog)
end

