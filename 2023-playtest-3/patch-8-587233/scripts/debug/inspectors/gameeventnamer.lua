local AnimtagAutogenData = require "prefabs.animtag_autogen_data"
local DebugSettings = require "debug.inspectors.debugsettings"
local eventfuncs = require "eventfuncs"
local lume = require "util.lume"
require "class"


local code_events = lume.invert(require("gen.eventslist"))
local NO_PREFIX = "None"

local GameEventNamer = Class(function(self)
	self.edit_options = DebugSettings("gameeventnamer.edit_options")
		:Option("prefix", NO_PREFIX)
end)

function GameEventNamer:IsEventSentFromCode(event_name)
	return code_events[event_name]
end

function GameEventNamer:GetEventDataOrigin(event_name)
	for tagname,tagset in pairs(AnimtagAutogenData) do
		for key,bank in pairs(tagset.anim_events or {}) do
			for anim,params in pairs(bank) do
				for _,ev in ipairs(params.events or {}) do
					if ev.name == event_name then
						return ("AnimTag: %s\nAnim: %s"):format(tagname, anim)
					end
				end
			end
		end
	end

	local gameevent = eventfuncs.gameevent.name
	for ev, embellishment, sg_name in embellishutil.EventIterator() do
		if ev.eventtype == gameevent
			and ev.param
			and ev.param.event_name == event_name
		then
			return ev.param.event_source or "Embellishment"
		end
	end
end

function GameEventNamer:GetEventUsage(event_name)
	local c = WEBCOLORS.YELLOW
	local tip = [[
Unknown event. Looked in:
	* Embellisher ("Fire Event")
	* AnimTagger (animtag_autogen_data.lua)
	* Code (eventslist.lua)
]]
	local source = self:GetEventDataOrigin(event_name)
	if source then
		c = WEBCOLORS.PALEGREEN
		tip = source
	elseif self:IsEventSentFromCode(event_name) then
		c = WEBCOLORS.GREENYELLOW
		tip = "Sent from code"
	end
	return c, tip
end

function GameEventNamer:RenderEventName(ui, event_name)
	local c, tip = self:GetEventUsage(event_name)
	ui:TextColored(c, event_name)
	if ui:IsItemHovered() then
		ui:SetTooltip(tip)
	end
end


function GameEventNamer:GetEventPrefix()
	if self.edit_options.prefix and self.edit_options.prefix ~= NO_PREFIX then
		return self.edit_options.prefix .. "-"
	end
	return ""
end

function GameEventNamer:EditEventPrefix(ui)
	local changed
	ui:Text("Event Prefix:")
	ui:SameLineWithSpace()
	local categories = {
		NO_PREFIX,
		"gp",
		"sfx",
		"vfx",
	}
	local prefix_selected = lume.find(categories, self.edit_options.prefix) or 1
	for i, v in pairs(categories) do
		local clicked, selection = ui:RadioButton(v, prefix_selected, i)
		ui:SameLineWithSpace()
		if clicked then
			changed = true
			self.edit_options:Set("prefix", v)
			self.edit_options:Save()
		end
	end
	ui:Dummy(0,0)
	return changed
end

-- Render editor for events we're sending from data.
function GameEventNamer:EditEventName(ui, event_name)
	local changed_prefix = self:EditEventPrefix(ui)

	local unprefixed_name = event_name or ""
	local prefix = self:GetEventPrefix()
	if changed_prefix then
		-- Force remove any existing prefix.
		unprefixed_name = unprefixed_name:gsub("^%w-%-", "")
	else
		-- Only remove prefix if it matches current.
		local starts_with_prefix = unprefixed_name:find(prefix, nil, true) == 1
		if starts_with_prefix then
			unprefixed_name = unprefixed_name:sub(prefix:len() + 1)
		end
	end

	ui:Text(string.format("%8s", prefix))
	ui:SameLine()
	local changed, newname = ui:InputText("Event##GameEventNamer", unprefixed_name, ui.InputTextFlags.CharsNoBlank)
	newname = newname or unprefixed_name
	if changed or changed_prefix then
		if newname == "" then
			event_name = nil
		else
			event_name = prefix .. newname
		end
	end
	if self:IsEventSentFromCode(event_name) then
		ui:TextColored(WEBCOLORS.RED, ("Event '%s' is already sent from code."):format(event_name))
	end

	-- Do .. here to avoid getting picked up by exportevents.lua
	local listener = ('inst:ListenForEvent'..'("%s", fn)'):format(event_name)
	if ui:Button("Copy##listener") then
		ui:SetClipboardText(event_name)
	end
	ui:SameLineWithSpace()
	if ui:Button("Copy Code##listener") then
		ui:SetClipboardText(listener)
	end
	ui:Value("Listen with", listener)
	return event_name, changed
end

-- Render editor for events we're receiving in data.
function GameEventNamer:EditReceivedEventName(ui, event_name)
	local changed, newname = ui:InputText("Event", event_name, ui.InputTextFlags.CharsNoBlank)
	if changed then
		if newname == "" then
			event_name = nil
		else
			event_name = newname
		end
	end
	ui:Indent() do
		if event_name then
			local c, tip = self:GetEventUsage(event_name)
			ui:TextColored(c, tip)
		else
			ui:NewLine()
		end
	end ui:Unindent()

	return event_name, changed
end

return GameEventNamer
