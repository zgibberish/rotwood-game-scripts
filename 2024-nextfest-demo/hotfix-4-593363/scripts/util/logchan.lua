--
-- logchan -- print channeled logs
--
-- Copyright (c) 2021, David Briscoe
-- Released under the MIT license.
--

local kassert = require "util.kassert"


-- Feel free to replace with your own class implementation.
local class_mt = {
    __call = function(cls, ...)
        local obj = setmetatable({}, cls)
        obj:ctor(...)
        return obj
    end
}
local function Class()
    local cls = {}
    cls.__index = cls
    setmetatable(cls, class_mt)
    return cls
end


local Channel = Class()

function Channel:ctor(name)
    self.label = ("[%s]"):format(name)
	self.indent_level = 0
	self.seen_once = {}
end

local function MakeIndentString(n)
	local indent = ""
	for _ = 0, n - 1 do
		indent = indent.."  "
	end
	return indent
end

-- Strip off the first argument and append it to the indent string to form the first printed item to appear after the
-- label.
function Channel:_indented_print(first, ...)
    print(self.label, string.format("%s%s", MakeIndentString(self.indent_level), tostring(first)), ...)
end

function Channel:print(...)
    self:_indented_print(...)
end

function Channel:printf(fmt, ...)
    self:_indented_print(fmt:format(...))
end

-- Print the first time we see input identifier and ignore subsequent calls.
-- Identifiers are per-channel, but common across all _once methods. They can
-- be anything that's a valid table key: string, entity, etc.
-- They don't persist between lua sim resets.
function Channel:print_once(identifier, ...)
    if self.seen_once[identifier] then
        return
    end
    self.seen_once[identifier] = true
    self:print(identifier, ...)
end

function Channel:printf_once(identifier, fmt, ...)
    kassert.typeof("string", fmt)
    if self.seen_once[identifier] then
        return
    end
    self.seen_once[identifier] = true
    self:_indented_print(identifier, fmt:format(...))
end

local function dumptable_process(item, path)
	item = table.inspect.processes.stringify_keys(item, path)
	item = table.inspect.processes.skip_mt(item, path)
	return item
end

-- Print a table. Like dumptable, prettyprint, etc. See inspect.lua for opts.
function Channel:dumptable(t, opts)
    opts = opts or { depth = 5, process = dumptable_process, }
    print(self.label, table.inspect(t, opts))
end

function Channel:indent()
	self.indent_level = self.indent_level + 1
end

function Channel:unindent()
	self.indent_level = self.indent_level - 1
end


local function noop() end

local void_channel = Channel("Void")
void_channel.print = noop
void_channel.printf = noop
void_channel.print_once = noop
void_channel.printf_once = noop
void_channel.indent = noop
void_channel.unindent = noop
void_channel.dumptable = noop



local LogChan = Class()

function LogChan:ctor()
    self.auto_enable = true

    local autoget_mt = {
        __index = function(t, key)
            assert(type(key) == 'string', key)
            return self:_get_or_create_channel(key)
        end,
    }
    self.ch = {}
    setmetatable(self.ch, autoget_mt)
end

function LogChan:_get_or_create_channel(chan_name)
    local ch = rawget(self.ch, chan_name)
    if not ch then
        if self.auto_enable
            and not chan_name:find("Spam", nil, true)
        then
            ch = Channel(chan_name)
        else
            ch = void_channel
        end
        self.ch[chan_name] = ch
    end
    return ch
end

function LogChan:print(chan_name, ...)
    local ch = self:_get_or_create_channel(chan_name)
    ch:print(...)
end

function LogChan:printf(chan_name, ...)
    local ch = self:_get_or_create_channel(chan_name)
    ch:printf(...)
end

function LogChan:dumptable(chan_name, ...)
    local ch = self:_get_or_create_channel(chan_name)
    ch:dumptable(...)
end

function LogChan:enable_channel(chan_name)
    self.ch[chan_name] = Channel(chan_name)
end

function LogChan:disable_channel(chan_name)
    print("[Log]", "Disabling channel:", chan_name)
    self.ch[chan_name] = void_channel
end

function LogChan:enable_all()
    for chan_name,ch in pairs(self.ch) do
        self:enable_channel(chan_name)
    end
    self.auto_enable = true
end

function LogChan:disable_all()
    print("[Log]", "Disabling all channels")
    for chan_name,ch in pairs(self.ch) do
        self:disable_channel(chan_name)
    end
    self.auto_enable = false
end


-- Test with testy.lua {{{

local function test_multiple_channels()
    local log = LogChan()
    print()
    log:print("Audio", "Can you hear this?")
    log:printf("Camera", "Look %s and %s for %0.2f s", "left", "right", 10.5)
end

local function test_disable_all()
    local log = LogChan()
    print()
    log:print("Audio", "Audible")
    log:disable_all()
    log:print("Audio", "Inaudible")
    log:print("NewChan", "Invisible")
end

local function test_disable_all_enable_one()
    local log = LogChan()
    print()
    log:print("Audio", "Audible")
    log:print("Rendering", "Visible")
    log:disable_all()
    log:enable_channel("Audio")
    log:print("Audio", "Loud noises")
    log:print("Rendering", "Invisible")
end

local function test_preconfigure()
    local log = LogChan()
    print()
    log:disable_all()
    log:enable_channel("Audio")
    log:enable_channel("Camera")
    log:print("Audio", "Loud noises")
    log:print("Rendering", "Invisible")
    log:printf("Camera", "Look %s", "left")
    log.ch.Audio:print("Loud noises")
    log.ch.Rendering:print("Invisible")
    log.ch.Camera:printf("Look %s", "left")
end


local function test_dot_syntax()
    local log = LogChan()
    print()
    log.ch.Audio:print("Audible")
    log.ch.Rendering:print("Visible")
    log:disable_channel("Rendering")
    log.ch.Audio:print("Loud noises")
    log.ch.Rendering:print("Invisible")
    log:disable_all()
    log.ch.Audio:print("Inaudible")
    log.ch.Rendering:print("Invisible")
    log.ch.NewChan:print("Unprinted")
end

-- }}}

return LogChan
