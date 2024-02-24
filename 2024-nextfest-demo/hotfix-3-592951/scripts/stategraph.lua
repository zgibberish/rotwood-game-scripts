local ParticleSystemHelper = require "util.particlesystemhelper"
local SGCommon = require "stategraphs.sg_common"
local embellishments = require "prefabs/stategraph_autogen_data"
local kassert = require "util.kassert"
local lume = require "util.lume"
local soundutil = require "util.soundutil"


local StateGraphWrangler = Class(function(self)
	self.lasttick = 0
	self.postupdatetick = nil
	self.updaters = {}
	self.swapupdaters = {}
	self.tickwaiters = {}
	self.waiterspool = SimpleTablePool()
end)

SGManager = StateGraphWrangler()

function StateGraphWrangler:SendToList(sginst, list)
	dbassert(not sginst.retired)
	if sginst.activelist ~= list and not sginst.retired then
		if sginst.activelist ~= nil then
			sginst.activelist[sginst] = nil
		end
		sginst.activelist = list
		if list ~= nil then
			list[sginst] = true
		end
	end
end

function StateGraphWrangler:OnEnterNewState(sginst)
	self:SendToList(sginst, self.updaters)
end

function StateGraphWrangler:OnSetTimeout(sginst)
	self:SendToList(sginst, self.updaters)
end

function StateGraphWrangler:AddInstance(sginst)
	self:SendToList(sginst, self.updaters)
end

function StateGraphWrangler:RemoveInstance(sginst)
	self:SendToList(sginst, nil)
end

function StateGraphWrangler:Sleep(sginst, targettick)
	local waiters = self.tickwaiters[targettick]
	if waiters == nil then
		waiters = self.waiterspool:Get()
		self.tickwaiters[targettick] = waiters
	end
	self:SendToList(sginst, waiters)
end

function StateGraphWrangler:ProcessUpdaters(currenttick)
	TheSim:ProfilerPush("updaters")
	local sginst = next(self.updaters)
	while sginst ~= nil do
		TheSim:ProfilerPush(sginst.inst.prefab or "entity")
		local sleepticks = sginst:Update(currenttick)
		TheSim:ProfilerPop()
		if sginst.activelist ~= nil then
			if sleepticks == nil then
				self:SendToList(sginst, nil)
			elseif sleepticks > 1 then
				self:Sleep(sginst, currenttick + sleepticks)
			else
				self:SendToList(sginst, self.swapupdaters)
			end
		end
		sginst = next(self.updaters)
	end
	TheSim:ProfilerPop()
end

function StateGraphWrangler:OnPostEnterNewState(sginst)
	--If we missed post update, do our 0 frame update immediately
	if self.postupdatetick == nil and self.lasttick == GetTick() and sginst.activelist == self.updaters then
		TheSim:ProfilerPush("updaters")
		TheSim:ProfilerPush(sginst.inst.prefab or "entity")
		local sleepticks = sginst:Update(self.lasttick)
		TheSim:ProfilerPop()
		if sginst.activelist ~= nil then
			if sleepticks == nil then
				self:SendToList(sginst, nil)
			elseif sleepticks > 1 then
				self:Sleep(sginst, self.lasttick + sleepticks)
			end
		end
		TheSim:ProfilerPop()
	end
end

function StateGraphWrangler:Update(currenttick)
	dbassert(currenttick == self.lasttick + 1)

	local waiters = self.tickwaiters[currenttick]
	if waiters ~= nil then
		for k in pairs(waiters) do
			k.activelist = self.updaters
			self.updaters[k] = true
			waiters[k] = nil
		end
		self.tickwaiters[currenttick] = nil
		self.waiterspool:Recycle(waiters)
	end

	dbassert(self.postupdatetick == nil)
	self:ProcessUpdaters(currenttick)
	self.lasttick = currenttick
	self.postupdatetick = currenttick
end

function StateGraphWrangler:PostUpdate()
	if self.postupdatetick == nil then
		--Ignore post updates in between sim ticks
		return
	end

	dbassert(self.postupdatetick == GetTick())
	self:ProcessUpdaters(self.postupdatetick)
	self.postupdatetick = nil

	local temp = self.updaters
	self.updaters = self.swapupdaters
	self.swapupdaters = temp
end

function StateGraphWrangler:GetLastUpdateTick()
	return self.lasttick
end

ActionHandler = Class(function(self)
	--deprecated
end)

EventHandler = Class(function(self, name, fn)
	local info = debug.getinfo(3, "Sl")
	self.defline = string.format("%s:%d", info.short_src, info.currentline)
	kassert.typeof("string", name)
	kassert.typeof("function", fn)
	self.name = string.lower(name)
	self.fn = fn
end)

-- victorc: 60Hz, add multiplier that defaults to scaling up 30Hz data
FrameEvent = Class(function(self, frame, fn, optname, multiplier)
	multiplier = multiplier or ANIM_FRAMES

	local info = debug.getinfo(3, "Sl")
	self.defline = string.format("%s:%d", info.short_src, info.currentline)
	kassert.typeof("number", frame)
	kassert.typeof("function", fn)
	self.frame = frame * multiplier
	self.time = frame * multiplier * TICKS
	self.idx = nil
	self.fn = fn
	self.eventname = optname
end)

-- victorc: 60Hz, convenience class for "full resolution" 60Hz frame events
FrameEvent60 = Class(FrameEvent, function(self, frame, fn, optname, fallback)
	fallback = fallback or FrameEvent60.LEGACY_TIMING_FLOOR
	FrameEvent._ctor(self, frame, fn, optname, 1)
	self.frame60hz = frame
	self.frame30hz = (fallback == FrameEvent60.LEGACY_TIMING_FLOOR) and math.floor(frame / 2) * 2 or math.ceil(frame / 2) * 2
end)

FrameEvent60.LEGACY_TIMING_FLOOR = 1
FrameEvent60.LEGACY_TIMING_CEIL = 2

TimeEvent = Class(FrameEvent, function(self, time, fn)
	FrameEvent._ctor(self, math.ceil(time * SECONDS), fn)
	self.time = time
end)

local function Chronological(a, b)
	return a.time < b.time or (a.time == b.time and a.idx < b.idx)
end

local function CleanEvents(events)
	local clean_events
	if events then
		clean_events = {}
		for name,tbl in pairs(events) do
			local result
			for i,event in pairs(tbl) do
				if not event.gen_eventname then
					result = result or {}
					table.insert(result, event)
				end
			end
			if result then
				clean_events[name] = result
			end
		end
	end
	return clean_events
end

local function AddEvents(inst, event_list, error_msg)
	for i = 1, #event_list do
		local v = event_list[i]
		assert(v:is_a(EventHandler), error_msg)
		inst.events[v.name] = inst.events[v.name] or {}
		table.insert(inst.events[v.name], v)
	end
end

State = Class(function(self, args)
	local info = debug.getinfo(3, "Sl")
	self.defline = string.format("%s:%d", info.short_src, info.currentline)

	assert(type(args.name) == "string", "State needs name")
	self.name = args.name
	self.onenter = args.onenter
	self.onexit = args.onexit
	self.onupdate = args.onupdate
	self.ontimeout = args.ontimeout
	self.tags = args.tags
	self.default_data_for_tools = args.default_data_for_tools

	self.events = {}
	if args.events ~= nil then
		self:AddEvents(args.events)
	end

	if args.timeline ~= nil and #args.timeline > 0 then
		self.timeline = args.timeline
		for i = 1, #args.timeline do
			local v = args.timeline[i]
			assert(v:is_a(FrameEvent), "Non-FrameEvent in timeline")
			v.idx = i --Use array index to achieve stable sort
		end
		table.sort(self.timeline, Chronological)
	end
end)

function State:AddEvents(event_list)
	AddEvents(self, event_list, "Non-EventHandler in event list")
end

function State:DisEmbellish()
	if self.timeline then
		local timeline = self.timeline
		for i=#timeline,1,-1 do
			local event = timeline[i]
			if event.gen_eventname then
				table.remove(timeline, i)
			end
		end
		if #timeline == 0 then
			self.timeline = nil
		end
	end
	-- and clean up any generated events on this stategraph
	self.events = CleanEvents(self.events)
	if self.orig_onexit then
		self.onexit = self.orig_onexit
	end
end

-- Pass in a table that you hold on to so we cleanup on next use:
--   self.state_cleanup = {
--   	spawned = {},
--   	cb = {},
--   }
function State:Debug_GetDefaultDataForTools(inst, cleanup)
	-- Cleanup the last default data.
	for _,ent in ipairs(cleanup.spawned) do
		if ent:IsValid() then
			ent:Remove()
		end
	end
	for _,cb in ipairs(cleanup.cb) do
		cb()
	end
	lume.clear(cleanup.spawned)
	lume.clear(cleanup.cb)

	if type(self.default_data_for_tools) == "function" then
		return self.default_data_for_tools(inst, cleanup)
	end
	return self.default_data_for_tools or {}
end

function State:DebugRefreshTimeline(use_30hz_timing)
	if self.timeline == nil then
		return false
	end

	use_30hz_timing = use_30hz_timing or false

	local dirty = false
	for i = 1, #self.timeline do
		local v = self.timeline[i]
		if v:is_a(FrameEvent60) then
			local old_frame = v.frame
			local old_time = v.time
			v.frame = use_30hz_timing and v.frame30hz or v.frame60hz
			v.time = v.frame * TICKS
			if old_frame ~= v.frame then
				TheLog.ch.StateGraph:printf("  FrameEvent changed: frame=%d (old=%d) time=%1.3f (old=%1.3f)",
					v.frame, old_frame,
					v.time, old_time)
				dirty = true
			end
		end
		-- v.idx = i --Use array index to achieve stable sort
	end

	if dirty then
		table.sort(self.timeline, Chronological)
		return true
	end
	return false
end

-- ===========================================================================

-- count bits needed to represent a contiguous array of bools/tags/flags
local function _CalculateNrBitsForCount(count)
	local bits = 0
	while count > 0 do
		bits = bits + 1
		count = count >> 1
	end
	return bits
end

-- count bits needed to represent a contiguous array of bools/tags/flags
local function _CalculateNrBits(array)
	assert(lume.isarray(array))
	local bits = 0
	local count = #array
	count = count + 1 -- let 0 be an invalid/unknown state
	while count > 0 do
		bits = bits + 1
		count = count >> 1
	end
	return bits
end

-- Store static lookup data for various sg_ definitions
StateGraphRegistry = Class(function(self)
	self.data = {} -- k: sg_name, v: data (see AddData)

	self.statetags = require("gen.sgtagslist")
	table.sort(self.statetags)

	self.statetags_reverse = {}
	for i=1,#self.statetags do
		self.statetags_reverse[self.statetags[i]] = i
	end

	self.statetags_nrbits = _CalculateNrBitsForCount(#self.statetags)
	TheLog.ch.StateGraphRegistry:printf("%d bits required to represent %d state tags", self.statetags_nrbits, #self.statetags)
end)

StateGraphRegistry.Hints =
{
	SerializeMetadata = 0x1, -- include the sg name, stateid_nrbits, etc. in serialization (needed if the entity can change sg in its lifetime, i.e. cabbage rolls <-> towers)
	SerializeTicksInState = 0x2, -- not included by default due to data delta churn

	Default = 0,
}

function StateGraphRegistry:GetStateTagNrBits()
	return self.statetags_nrbits
end


local NR_TAGS_BITS <const> = 4


-- tags is expected to be a dictionary (k:tag, v:true)
function StateGraphRegistry:SerializeStateTags(e, tags)
	local nr_tags = 0

	-- First, count the tags we actually know how to save:
	for tag,_ in pairs(tags) do
		local index = self.statetags_reverse[tag] and self.statetags_reverse[tag] - 1	-- -1 because this index is 1-based
		if index then
			nr_tags = nr_tags + 1
		else
			TheLog.ch.StateGraphRegistry:printf("Warning: Unable to find id for tag %s (it will not be serialized). Run update_string_lists.bat!", tag)
		end
	end

	e:SerializeUInt(nr_tags, NR_TAGS_BITS)

	for tag,_ in pairs(tags) do
		local index = self.statetags_reverse[tag] and self.statetags_reverse[tag] - 1	-- -1 because this index is 1-based
		if index then
			e:SerializeUInt(index, SGRegistry:GetStateTagNrBits())
		end
	end
end

-- out_tags is expected to be a dictionary (k:tag, v:true)
function StateGraphRegistry:DeserializeStateTags(e, out_tags)
	out_tags = out_tags or {}
	assert(type(out_tags) == "table")
	lume.clear(out_tags)

	local nr_tags = e:DeserializeUInt(NR_TAGS_BITS)
	if nr_tags and nr_tags > 0 then
		for i=1,nr_tags do
			local index = e:DeserializeUInt(SGRegistry:GetStateTagNrBits())
			if index then
				local statename = self.statetags[index + 1]	-- +1 because index is 0-based
				if statename then
					out_tags[statename] = true
				end
			end
		end
	end
end

-- sg_name : the stategraph name, used as a unique identifier
-- states : array of SG states that are also passed into the StateGraph constructor
-- hints : see StateGraphRegistry.Hints for bit-flags to pass in
function StateGraphRegistry:AddData(sg_name, states, hints)
	assert(#states > 0, "Why are we caching data for an empty stategraph?")
	hints = hints or StateGraphRegistry.Hints.Default

	if self.data[sg_name] then
		assert(#self.data[sg_name].lookup == #states)
		TheLog.ch.StateGraphRegistry:printf("Already added data for %s with %d states", sg_name, #states)
		return
	end

	-- k: state id, v: name (or a table with more data)
	local lookup = {}
	for i = 1, #states do
		local v = states[i]
		assert(v:is_a(State), "Non-State added in state list")
		table.insert(lookup, v.name) -- add more static data here if needed
	end
	table.sort(lookup)

	-- k: state name, v: state id
	local reverselookup = {}
	for i = 1, #states do
		local name = lookup[i]
		reverselookup[name] = i
	end

	-- number of bits needed to represent all states for serialization
	-- StateGraphInstance:OnNetSerialize/Deserialize will offset by 1
	-- to account for Lua's one-based indices
	local bits = _CalculateNrBits(lookup)

	self.data[sg_name] =
	{
		default = lookup,
		reverse = reverselookup,
		nr_bits = bits,
		hints = hints,
	}

	-- TODO: ModManager stuff (see StateGraphInstance)

	TheLog.ch.StateGraphRegistry:printf("Added data for %s with %d states (nrbits=%d)", sg_name, #states, bits)
end

function StateGraphRegistry:HasData(sg_name)
	return self.data[sg_name] ~= nil
end

function StateGraphRegistry:HasHint(sg_name, hint)
	return self.data[sg_name] and (self.data[sg_name].hints & hint) == hint
end

function StateGraphRegistry:GetStateID(sg_name, state_name)
	if self.data[sg_name] and state_name then
		-- assert(self.data[sg_name].reverse[state_name], "SGRegistry " .. sg_name .. " cannot find state id for " .. state_name)
		return self.data[sg_name].reverse[state_name]
	end
end

function StateGraphRegistry:GetStateName(sg_name, state_id)
	if self.data[sg_name] then
		return self.data[sg_name].default[state_id]
	end
end

function StateGraphRegistry:GetStateNrBits(sg_name)
	if self.data[sg_name] then
		return self.data[sg_name].nr_bits
	end
	assert(false, "SGRegistry could not find data for " .. sg_name)
end

SGRegistry = StateGraphRegistry()

-- ===========================================================================

-- fns: custom handlers for sg tests
--    CanTakeControl() : returns whether or not a client can take control of this entity
--    OnResumeFromRemote(sg_instance) : called when an entity becomes local (resumes from remote ownership); returns new sg state for GotoState
StateGraph = Class(function(self, name, states, events, defaultstate, fns)
	local info = debug.getinfo(3, "Sl")
	self.defline = string.format("%s:%d", info.short_src, info.currentline)

	assert(type(name) == "string", "StateGraph needs name")
	self.name = name
	self.defaultstate = defaultstate

	self.events = {}
	if events ~= nil then
		AddEvents(self, events, "Non-EventHandler in event list")
	end
	local modevents = ModManager:GetPostInitData("StateGraphEvent", self.name)
	for i = 1, #modevents do
		local modhandlers = modevents[i]
		AddEvents(self, modhandlers, "Non-EventHandler added in mod event list")
	end

	self.states = {}
	if states ~= nil then
		for i = 1, #states do
			local v = states[i]
			assert(v:is_a(State), "Non-State added in state list")
			self.states[v.name] = v
		end
	end

	if fns then
		for fn_name,fn in pairs(fns) do
			dbassert(type(fn_name) == "string" and type(fn) == "function")
		end
		self.fns = fns
	else
		self.fns = {}
	end


	local modstates = ModManager:GetPostInitData("StateGraphState", self.name)
	for i = 1, #modstates do
		local v = modstates[i]
		assert(v:is_a(State), "Non-State added in mod state list")
		self.states[v.name] = v
	end

	local modfns = ModManager:GetPostInitFns("StateGraphPostInit", self.name)
	for i = 1, #modfns do
		modfns[i](self)
	end
end)

function StateGraph:__tostring()
	return "StateGraph : "..self.name
end

function StateGraph:DisEmbellish()
	if self.embellish_name then
		for i,state in pairs(self.states) do
			state:DisEmbellish()
		end
		-- and clean up any generated events on this stategraph
		self.events = CleanEvents(self.events)

		self.embellish_name = nil
	end
end

function StateGraph:Embellish(names, force, editor)
	local name = table.concat(names,":")
	local needSoundEmitter = false
	if name ~= self.embellish_name or force then
		self:DisEmbellish()
		for i,v in pairs(names) do
			local def = embellishments[v]

--			local sgdef = def.stategraphs and def.stategraphs[self.name] or {}
			local sgdef = def.stategraphs and (def.stategraphs["*"] or def.stategraphs[self.name]) or {}
			if sgdef then
				local events = sgdef.events or nil
				needSoundEmitter = needSoundEmitter or def.needSoundEmitter
				if events then
					for i,v in pairs(events) do
						self:ApplyGeneratedStateEvents(i,v,editor)
					end
				end
				local events = sgdef.state_events or nil
				if events then
					for i,v in pairs(events) do
						self:ApplyGeneratedStateAnimEvents(i,v,editor)
					end
				end
				local events = sgdef.sg_events or nil
				if events then
					self:ApplyGeneratedStateGraphAnimEvents(events,editor)
				end
			end
		end
		self.embellish_name = name
		self.needSoundEmitter = needSoundEmitter
		-- Wrap all exitstates....I guess?
		self:WrapAllExitStates()
	end
	return needSoundEmitter
end

local function _HandleSGRunStopAutogen(inst)
	-- if this is set to true, a RunStopAutogen event will be sent over the network for remote clients
	local stopped_something = false

	-- stop any named sounds that need stopping
	if inst.sg.mem.autogen_stopsounds then
		for k,v in pairs(inst.sg.mem.autogen_stopsounds) do
			soundutil.KillSound(inst, k)
		end
		inst.sg.mem.autogen_stopsounds = nil
		-- soundutil.KillSound auto-handles this for networked entities
		-- stopped_something = stopped_something or true
	end

	if inst.sg.mem.autogen_stopfx then
		-- TODO: networking2022, ignore swipes stored here? A bespoke system takes care of that...
		local has_nonnetworked_fx = false
		for fx,_data in pairs(inst.sg.mem.autogen_stopfx) do
			-- TODO: add a system to stop gracefully like the particle system's StopAndNotify()
			-- On Kaj's advice, not checking if this is valid but these effects
			-- are registered to look for "onremove" event, which removes from
			-- this list.
			has_nonnetworked_fx = has_nonnetworked_fx or not fx:IsNetworked()
			fx:Remove()
		end
		inst.sg.mem.autogen_stopfx = nil
		-- fx_autogen can auto-handle stopping for networked fx prefabs
		-- examples of non-networked ones: trap_zucco_trigger_radius
		stopped_something = stopped_something or has_nonnetworked_fx
	end

	if inst.sg.mem.autogen_stopparticles then
		for k,_v in pairs(inst.sg.mem.autogen_stopparticles) do
			k.components.particlesystem:StopAndNotify()
		end
		inst.sg.mem.autogen_stopparticles = nil
		stopped_something = stopped_something or true
	end

	if inst.sg.mem.autogen_detachentities then
		for k,v in pairs(inst.sg.mem.autogen_detachentities) do
			SGCommon.Fns.DetachChild(k)
		end
		inst.sg.mem.autogen_detachentities = nil
		-- TODO: networking2022 -- see if this is needed
		-- stopped_something = stopped_something or true
	end

	if inst.sg.mem.autogen_onexitfns then
		for k,func in pairs(inst.sg.mem.autogen_onexitfns) do
			func(inst)
		end
		inst.sg.mem.autogen_onexitfns = nil
		-- TODO: networking2022 -- see if this is needed
		-- stopped_something = stopped_something or true
	end
	return stopped_something
end

local function RunStopAutogen(inst)
	local modified = _HandleSGRunStopAutogen(inst)
	if modified and inst:IsNetworked() then
		TheNetEvent:SGRunStopAutogen(inst.GUID)
	end
end

local function WrappedExitState(inst, fromstate, tostate)
	if fromstate ~= tostate then
		RunStopAutogen(inst)
	end
	if fromstate.orig_onexit then
		fromstate.orig_onexit(inst, fromstate, tostate)
	end
end

function StateGraph:WrapExitState(statename)
	local state = self.states[statename]
	assert(state)
	local onexit = state.onexit
	if onexit ~= WrappedExitState then
		state.orig_onexit = onexit
		state.onexit = WrappedExitState
	end
end

function StateGraph:ApplyGeneratedStateEvents(statename, events, editor)
	local eventfuncs = require "eventfuncs" -- requiring here rather than top of file to avoid circular requires

	if #events > 0 then
		if not self.states[statename] then
			self.states[statename] = State({name = statename})
		end
		local state = self.states[statename]
		if not state.timeline then
			state.timeline = {}
		end
		local timeline = state.timeline
		for i,v in pairs(events) do
			local eventdef = eventfuncs[v.eventtype]
			assert(eventdef, v.eventtype) -- probably you renamed the eventtype but have old data
			local event
			if editor then
				local editorfunc = eventdef.editorfunc
				assert(editorfunc)
				event = editorfunc(eventdef, editor, v.frame, v.param)
			else
				local runfunc = eventdef.runfunc
				assert(runfunc)
				event = runfunc(eventdef, v.frame, v.param)
			end
			event.gen_eventname = v.eventtype
			table.insert(timeline, event) --func(v.frame, v.param))
		end
		table.sort(timeline, function(a,b) return a.frame < b.frame end)
--		assert(#timeline > 0)
	end
end

function StateGraph:ApplyGeneratedStateAnimEvents(statename, events, editor)
	local eventfuncs = require "eventfuncs" -- requiring here rather than top of file to avoid circular requires

	if #events > 0 then
		if not self.states[statename] then
			self.states[statename] = State({name = statename})
		end
		local state = self.states[statename]
		if not state.events then
			state.events = {}
		end
		local state_events = state.events
		for i,v in pairs(events) do
			local eventdef = eventfuncs[v.eventtype]
			assert(eventdef, v.eventtype) -- probably you renamed the eventtype but have old data
			local event
			if editor then
				local editorfunc = eventdef.editorfunc
				assert(editorfunc)
				event = editorfunc(eventdef, editor, v.name, v.param)
			else
				local runfunc = eventdef.runfunc
				assert(runfunc)
				event = runfunc(eventdef, v.name, v.param)
			end
			event.gen_eventname = v.eventtype
			--state_events[v.name] = event
			state_events[v.name] = state_events[v.name] or {}
			table.insert(state_events[v.name], event)
		end
	end
end

function StateGraph:WrapAllExitStates()
	for i,v in pairs(self.states) do
		self:WrapExitState(i)
	end
end

function StateGraph:ApplyGeneratedStateGraphAnimEvents(events, editor)
	local eventfuncs = require "eventfuncs" -- requiring here rather than top of file to avoid circular requires

	if #events > 0 then
		dbassert(self.events)
		local sg_events = self.events
		for i,v in pairs(events) do
			local eventdef = eventfuncs[v.eventtype]
			assert(eventdef, v.eventtype) -- probably you renamed the eventtype but have old data
			local event
			if editor then
				local editorfunc = eventdef.editorfunc
				assert(editorfunc)
				event = editorfunc(eventdef, editor, v.name, v.param)
			else
				local runfunc = eventdef.runfunc
				assert(runfunc)
				event = runfunc(eventdef, v.name, v.param)
			end
			event.gen_eventname = v.eventtype
			sg_events[v.name] = sg_events[v.name] or {}
			table.insert(sg_events[v.name], event)
		end
		-- Hmmmm, should I wrap all existstates in that case? Not sure this is a use case
	end
end

StateGraphInstance = Class(function (self, inst, stategraph)
	self.inst = inst
	self.sg = stategraph
	self.currentstate = nil
	self.laststate = nil
	self.ticksinstate = 0
	self.statestarttick = 0
	self.lastupdatetick = 0
	self.lasttickinstate = nil
	self.pausestarttick = nil
	self.timelineindex = nil
	self.statemem = {}
	self.mem = {}
	self.tags = {}
	--self.retired = false --can leave this as nil
	self.paused = {}
	self.activelist = nil --used by StateGraphWrangler
	self.updatingstate = false --used during Update to manage recursive updates
	self.stayedinstate = false --used during UpdateState to detect state changes
	self.gotostatedepth = 0
	self.canexitstate = true
	self.lockstatetransitiontags = {}

	self.cantakecontrol = true
	self.cantakecontrolbyknockback = false
	self.cantakecontrolbyknockdown = false
end)

function StateGraphInstance:RenderDebugUI(ui, panel)
	-- Don't have a specific stategraph debugger for DebugNodeName, but viewing
	-- our History is pretty useful.
	if ui:Button("Open History for: ".. tostring(self.inst)) then
		local DebugNodes = require "dbui.debug_nodes"
		SetDebugEntity(self.inst)
		panel:PushNode(DebugNodes.DebugHistory())
	end
end

-- if outtable is nil, a new table will be returned
function StateGraphInstance:GetDebugTable(outtable)
	TheSim:ProfilerPush("[SGI] GetDebugTable")

	local hitbox
	if self.inst.HitBox then
		hitbox =
		{
			w = self.inst.HitBox:GetSize(),
			h = self.inst.HitBox:GetDepth(),
			enabled = self.inst.HitBox:IsEnabled(),
			hitrects = deepcopy(self.inst.HitBox:GetHitRects()),
			hitcircles = deepcopy(self.inst.HitBox:GetHitCircles())
		}
	end

	-- Table is rendered with DebugEntity.RenderStateGraph
	outtable = outtable or {}
	outtable.name = self.sg.name
	outtable.is_transferable = self.inst:IsTransferable()
	outtable.cantakecontrol = self.cantakecontrol
	-- begin cantakecontrol details
	outtable.cantakecontrolbyknockback = self.cantakecontrolbyknockback
	outtable.cantakecontrolbyknockdown = self.cantakecontrolbyknockdown
	outtable.remote_knockdown_idle = self.remote_knockdown_idle
	outtable.remote_hit = self.remote_hit
	outtable.remote_dead = self.remote_dead
	outtable.remote_attack_hold = self.remote_attack_hold
	outtable.remote_attack_hold_ticks = self.remote_attack_hold_ticks
	outtable.remote_attack_hold_id = self.remote_attack_hold_id
	-- end cantakecontrol details
	outtable.remote_state = self.remote_state
	outtable.remote_ticksinstate = self.remote_ticksinstate
	outtable.current = self.currentstate and self.currentstate.name or "<None>"
	outtable.embellish_name = self.sg.embellish_name and self.sg.embellish_name or ""
	outtable.ticks = self:GetTicksInState()
	outtable.tags = shallowcopy(self.tags)
	outtable.statemem = shallowcopy(self.statemem)
	outtable.hitbox = hitbox
	outtable.paused = next(self.paused) or nil

	TheSim:ProfilerPop()

	return outtable
end

function StateGraphInstance:GetDebugString()
    local str = string.format(
        'sg="%s%s", state="%s", ticks=%i, tags = ',
        self.sg.name,
        self.sg.embellish_name and ":" .. self.sg.embellish_name and (string.len(self.sg.embellish_name) > 32 and (string.sub(self.sg.embellish_name, 1, 32) .. " ...") or self.sg.embellish_name) or "",
        self.currentstate and self.currentstate.name or "<None>",
        self:GetTicksInState()
    )
	local c = '"'
	for k in pairs(self.tags) do
		str = str..c..k
		c = ','
	end
	return str..'"'
end

-- Call in onenter to ensure you have your data when in a tool, but give a good
-- error message at runtime.
function StateGraphInstance:ExpectMem(label, default_value_for_tools)
	if self.mem[label] ~= nil then -- accept false too
		return

	elseif self.inst.in_embellisher then
		self.mem[label] = default_value_for_tools
	else
		error("Expected value: inst.sg.mem.".. label)
	end
end

function StateGraphInstance:Embellish(names, force, editor)
	self.sg:Embellish(names, force, editor)
	local needSoundEmitter = self.sg.needSoundEmitter
--	if needSoundEmitter and not self.inst.SoundEmitter then
--		self.inst.entity:AddSoundEmitter()
--	end
	return needSoundEmitter
end


function StateGraphInstance:GetCurrentState()
	return self.currentstate ~= nil and self.currentstate.name or nil
end

function StateGraphInstance:GetTicksInState()
	return math.max(0, (self.pausestarttick or SGManager:GetLastUpdateTick()) - self.statestarttick)
end

function StateGraphInstance:GetAnimFramesInState()
	return math.floor(self:GetTicksInState() / ANIM_FRAMES)
end

function StateGraphInstance:GetTimeInState()
	return self:GetTicksInState() * TICKS
end

function StateGraphInstance:PushEvent(event, data)
	dbassert(not self.retired)

	local handlers = self.currentstate ~= nil and self.currentstate.events[event]
	if handlers then
		-- By default state handlers *override* the stategraph, but this can be
		-- sidestepped by returning true. Always run all *state* handlers.
		local fallthrough
		for i,handler in pairs(handlers) do
			fallthrough = handler.fn(self.inst, data) or fallthrough
			if self.retired then
				TheLog.ch.StateGraph:printf("Warning: %s PushEvent entity removed by handler %s", self.inst, handler.defline)
				return
			end
		end
		if not fallthrough then
			return
		end
	end

	if self.inst:IsLocalOrMinimal() then	-- Only run stategraph events from embellisher on LOCAL entities.
		handlers = self.sg.events[event]
		if handlers then
			for i,handler in pairs(handlers) do
				handler.fn(self.inst, data)
				if self.retired then
					TheLog.ch.StateGraph:printf("Warning: %s PushEvent entity removed by handler %s", self.inst, handler.defline)
					return
				end
			end
		end
	end
end

function StateGraphInstance:HasState(statename)
	return self.sg.states[statename] ~= nil
end

function StateGraphInstance:AddLockStateTransitionTag(excludetag)
	self.lockstatetransitiontags[excludetag] = true
end

function StateGraphInstance:RemoveLockStateTransitionTag(excludetag)
	self.lockstatetransitiontags[excludetag] = nil
end

function StateGraphInstance:CanLockedStateTransition(statename)
	if not self.sg.states[statename] or lume.count(self.lockstatetransitiontags) == 0 then
		return true
	end

	for _, tag in ipairs(self.sg.states[statename].tags) do
		if self.lockstatetransitiontags[tag] then
			return true
		end
	end

	return false
end

function StateGraphInstance:ForceGoToState(statename, params)
	self.inst:RemoveTag("no_state_transition")
	self.lockstatetransitiontags = {}
	self:GoToState(statename, params)
end

function StateGraphInstance:GoToState(statename, params)
	if self.retired then
		dbassert(false)
		return
	end

	if not self.inst:IsLocalOrMinimal() then
		return
	end

	local function _PrintLockKeys(tags)
		local tagslist = ""
		for key, _ in pairs(tags) do
			tagslist = tagslist .. " " .. key
		end
		return tagslist
	end

	-- If the 'no_state_transition' tag is present, prevent GoToState from happening. Used to prevent post-death transitions back to living ones.
	if self.currentstate and (self.inst:HasTag("no_state_transition") or not self:CanLockedStateTransition(statename)) then
		TheLog.ch.StateGraph:printf("GUID %d EntityID %d Trying to transition from state %s into state: %s. Reason: %s",
				self.inst.GUID, self.inst.Network and self.inst.Network:GetEntityID() or "", self.inst.sg:GetCurrentState(), statename,
				self.inst:HasTag("no_state_transition") and "Has no_state_transition tag." or "Trying to transition into a state without locked transition tags:" .. _PrintLockKeys(self.lockstatetransitiontags) or "")
		return
	end

	local state = self.sg.states[statename]
	if state == nil then
		dbassert(statename, "No state name provided")
		dbassert(false, "TRIED TO GO TO INVALID STATE: "..statename)
		return
	end

	--For handling recursive calls in the onenter and onexit handlers.
	local depth = self.gotostatedepth + 1
	self.gotostatedepth = depth
	if depth == 1 then
		--Save this as laststatename for the final "newstate" event.
		statename = self.currentstate ~= nil and self.currentstate.name or nil
	end

	if self.canexitstate then
		self.canexitstate = false
		if self.currentstate ~= nil and self.currentstate.onexit ~= nil then
			self.currentstate.onexit(self.inst, self.currentstate, state)
			if self.retired then
				return
			end
		end
	end

	if depth == self.gotostatedepth then
		for k in pairs(self.statemem) do
			self.statemem[k] = nil
		end

		for k in pairs(self.tags) do
			-- self.tags[k] = nil
			self:RemoveStateTag(k)
		end

		if state.tags ~= nil then
			-- for i = 1, #state.tags do
			-- 	self.tags[state.tags[i]] = true
			-- end
			for i, tag in ipairs(state.tags) do
				self:AddStateTag(tag)
			end
		end

		self.stayedinstate = false
		self.laststate = self.currentstate
		self.currentstate = state
		self.timeoutticks = nil
		self.timelineindex = state.timeline ~= nil and 1 or nil
		self.ticksinstate = 0
		self.statestarttick = GetTick() --Can be ahead of SGManager:GetLastUpdateTick()
		self.lastupdatetick = self.statestarttick
		self.lasttickinstate = nil
		self.pausestarttick = self.pausestarttick ~= nil and self.statestarttick or nil
		SGManager:OnEnterNewState(self)

		self.canexitstate = true
		if state.onenter ~= nil then
			state.onenter(self.inst, params)
			if self.retired then
				return
			end
		end
	end

	if depth == 1 then
		repeat
			depth = self.gotostatedepth
			local newstatename = self.currentstate.name
			self.inst:PushEvent("newstate", { statename = newstatename, laststatename = statename })
			if self.retired then
				return
			end
			statename = newstatename
		until depth == self.gotostatedepth

		self.gotostatedepth = 0

		if not self.updatingstate then
			SGManager:OnPostEnterNewState(self)
		end
	end
end

function StateGraphInstance:AddStateTag(tag)
	self.tags[tag] = true
	self.inst:PushEvent("add_state_tag", tag)
end

function StateGraphInstance:RemoveStateTag(tag)
	self.tags[tag] = nil
	self.inst:PushEvent("remove_state_tag", tag)
end

function StateGraphInstance:HasStateTag(tag)
	return self.tags[tag] == true
end

function StateGraphInstance:SetTimeoutTicks(ticks)
	if self.currentstate.ontimeout ~= nil then
		self.timeoutticks = ticks
		SGManager:OnSetTimeout(self)
	end
end

function StateGraphInstance:GetTimeoutTicks()
	return self.timeoutticks
end

function StateGraphInstance:SetTimeoutAnimFrames(animframes)
	self:SetTimeoutTicks(animframes * ANIM_FRAMES)
end

function StateGraphInstance:SetTimeout(time)
	self:SetTimeoutTicks(math.ceil(time * SECONDS))
end

function StateGraphInstance:UpdateState(ticks)
	self.stayedinstate = true
	self.ticksinstate = self.ticksinstate + ticks

	if self.timeoutticks ~= nil then
		if self.timeoutticks > ticks then
			self.timeoutticks = self.timeoutticks - ticks
		else
			local extraticks = ticks - self.timeoutticks
			self.timeoutticks = nil
			self.currentstate.ontimeout(self.inst)
			if self.activelist == nil then
				return
			elseif not self.stayedinstate then
				self:UpdateState(self.pausestarttick == nil and extraticks or 0)
				return
			end
		end
	end

	while self.timelineindex ~= nil do
		local frameevent = self.currentstate.timeline[self.timelineindex]
		if frameevent.frame > self.ticksinstate then
			break
		elseif self.timelineindex < #self.currentstate.timeline then
			self.timelineindex = self.timelineindex + 1
		else
			self.timelineindex = nil
		end

		local extraticks = self.ticksinstate - frameevent.frame
		frameevent.fn(self.inst)
		if self.activelist == nil then
			return
		elseif not self.stayedinstate then
			self:UpdateState(self.pausestarttick == nil and extraticks or 0)
			return
		end
	end

	if self.currentstate.onupdate ~= nil and (ticks > 0 or self.lasttickinstate == nil) then
		dbassert(ticks == 1 or (ticks == 0 and self.ticksinstate == 0), "ticks = " .. ticks)
		self.currentstate.onupdate(self.inst)
		if self.activelist == nil then
			return
		elseif not self.stayedinstate then
			self:UpdateState(0)
			return
		end
	end
end

-- only "public" because networking needs access to it; call RunStopAutogen from within stategraph
function StateGraphInstance:HandleSGRunStopAutogen()
	_HandleSGRunStopAutogen(self.inst)
end

function StateGraphInstance:OnRemoveFromEntity()
	-- Don't run the normal onexit to avoid side effects that might put us
	-- into different states.
	RunStopAutogen(self.inst)
	if self.sg.fns.OnRemoveFromEntity then
		self.sg.fns.OnRemoveFromEntity(self)
	end
	SGManager:RemoveInstance(self)
	self.retired = true
end

StateGraphInstance.OnRemoveEntity = StateGraphInstance.OnRemoveFromEntity

function StateGraphInstance:Start()
	if self.pausestarttick == nil then
		SGManager:AddInstance(self)
	end
	dbassert(self.currentstate == nil)
	self:GoToState(self.sg.defaultstate)
end

function StateGraphInstance:Pause(reason)
	if reason == nil then
		print(self.inst, "StateGraph paused without [reason].")
	elseif reason == "remote" then
		self:PreparePauseToRemoteState()
	end
	self.paused[reason or ""] = true
	if self.pausestarttick == nil then
		self.pausestarttick = math.max(SGManager:GetLastUpdateTick(), self.lastupdatetick)
		if self.lasttickinstate ~= nil then
			SGManager:RemoveInstance(self)
		end
	end
end

function StateGraphInstance:Resume(reason)
	if reason == nil then
		print(self.inst, "StateGraph resumed without [reason].")
	elseif reason == "remote" and self.paused[reason] then
		local resume_state, used_remote_state = self:PredictResumeFromRemoteState()
		if resume_state then
			TheLog.ch.StateGraph:printf("GUID %d EntityID %d Resuming from remote into state: %s",
				self.inst.GUID, self.inst.Network:GetEntityID(), resume_state)
			self:GoToState(resume_state)

			if self.retired then
				-- switched stategraph instances while going into a state (i.e. cabbagetowers on knockdown)
				TheLog.ch.StateGraph:printf("GUID %d EntityID %d SG %s retired while resuming from remote state.  New SG: %s",
					self.inst.GUID, self.inst.Network:GetEntityID(), self.sg.name, self.inst.sg.sg.name)
				return
			end
		end

		if self.inst.components.attacktracker then
			-- Either the previous owner completed the attack on their end, or we should cancel any lingering old attacks from last time we controlled it.
			self.inst.components.attacktracker:CancelActiveAttack()
		end
		if self.remote_attack_hold and self.remote_attack_hold_id then
			-- Handling resuming into an attack's "_hold" state.

			--TODO: support data.alwaysforceattack
			--TODO: support data.addevents

			self.inst.components.attacktracker:StartActiveAttack(self.remote_attack_hold_id)
			self.inst.components.attacktracker:SetRemainingStartupFrames(math.floor(self.remote_attack_hold_ticks / ANIM_FRAMES)) -- Override its remaining startup frames with the value we got from the other owner.
			self:SetTimeoutTicks(self.remote_attack_hold_ticks) -- Manually set the timeoutticks so we stay in the attack hold state
		end
		self:ClearResumeFromRemoteHints()
	end
	if self.pausestarttick ~= nil then
		self.paused[reason or ""] = nil
		if next(self.paused) == nil then
			local elapsed = math.max(SGManager:GetLastUpdateTick(), self.lastupdatetick) - self.pausestarttick
			if elapsed > 0 then
				self.lastupdatetick = self.lastupdatetick + elapsed
				self.statestarttick = self.statestarttick + elapsed
			end
			self.pausestarttick = nil
			SGManager:AddInstance(self)
		end
	end
end

function StateGraphInstance:Update(currenttick)
	if self.lasttickinstate == currenttick then
		dbassert(self.pausestarttick == nil)
		return 0
	end

	local ticks = 0
	if self.pausestarttick == nil then
		ticks = currenttick - self.lastupdatetick
		self.lastupdatetick = currenttick
		dbassert(ticks >= 0)
	end

	dbassert(not self.updatingstate)
	self.updatingstate = true
	self:UpdateState(ticks)
	self.updatingstate = false
	self.lasttickinstate = currenttick

	if self.activelist == nil or self.pausestarttick ~= nil then
		return
	elseif self.currentstate.onupdate ~= nil then
		return 0
	end

	local tickstosleep = nil
	if self.timelineindex ~= nil then
		tickstosleep = self.currentstate.timeline[self.timelineindex].frame - self.ticksinstate
	end
	if self.timeoutticks ~= nil and (tickstosleep == nil or tickstosleep > self.timeoutticks) then
		tickstosleep = self.timeoutticks
	end
	return tickstosleep
end

function StateGraphInstance:CanTakeControl()
	return self.cantakecontrol
end

-- if this returns true, it has an internal side effect of setting
-- the resume takecontrol hint to "knocking_attack"
function StateGraphInstance:CanTakeControlByKnockingAttack(attack)
	if attack then
		if (attack:IsKnockdown() and self.cantakecontrolbyknockdown)
			or (attack:GetKnocked() and self.cantakecontrolbyknockback) then
			if self.resume_takecontrol_hint then
				TheLog.ch.StateGraph:printf("Warning: Overriding resume takecontrol hint %s with knocking_attack", self.resume_takecontrol_hint)
			end
			self.resume_takecontrol_hint = "knocking_attack"
			return true
		end
	end
	return false
end

local TimeoutTicksNrBits <const> = 8

-- serialize transferable entity details (i.e. mobs)
function StateGraphInstance:_OnNetSerializeTransferable()
	assert(self.inst:IsTransferable())
	if self.sg.fns.CanTakeControl then
		self.cantakecontrol = self.sg.fns.CanTakeControl(self)
	else
		self.cantakecontrol = SGCommon.Fns.CanTakeControlDefault(self)
	end
	self.cantakecontrolbyknockback = false
	self.cantakecontrolbyknockdown = false
	local combat = self.inst.components.combat
	if combat then
		local nointerrupt = self:HasStateTag("nointerrupt") or (self.inst:HasTag("nointerrupt") and not self:HasStateTag("caninterrupt") and not self:HasStateTag("vulnerable"))
		self.cantakecontrolbyknockback =
			-- Knockbacks
			combat.hasknockback and not nointerrupt
		self.cantakecontrolbyknockdown =
			-- Knockdowns
			combat.hasknockdown and not nointerrupt
			and (not combat.vulnerableknockdownonly or (self:HasStateTag("vulnerable") and self:HasStateTag("knockback_becomes_knockdown")))
	end

	local e = self.inst.entity
	e:SerializeBoolean(self.cantakecontrol)
	e:SerializeBoolean(self.cantakecontrolbyknockdown)
	e:SerializeBoolean(self.cantakecontrolbyknockback)

	-- serialize remote state, ticks in state if available
	local has_registry_data = SGRegistry:HasData(self.sg.name)
	if not has_registry_data then
		e:SerializeBoolean(self:HasStateTag("knockdown") and not self:HasStateTag("getup"))
		e:SerializeBoolean(self:HasStateTag("hit"))
		e:SerializeBoolean(self:GetCurrentState() == "dead" or self:GetCurrentState() == "death")
	end

	-- remote_attack_hold : requires an active attack in addition to attack_hold state tag
	if self:HasStateTag("attack_hold") and not self.inst:HasTag("no_state_transition") and self.inst.components.attacktracker:GetActiveAttack() then
		e:SerializeBoolean(true)
		e:SerializeUInt(math.max(0, (self:GetTimeoutTicks() or 0) - self:GetTicksInState()), TimeoutTicksNrBits)
		local active_attack = self.inst.components.attacktracker:GetActiveAttack()
		dbassert(active_attack.id, "Active attack needs non-nil id")
		e:SerializeString(active_attack.id) --TODO: if this works, pack these into networkstrings for find a better way of storing attack names
	else
		e:SerializeBoolean(false)
	end
end

-- deserialize transferable entity details (i.e. mobs)
function StateGraphInstance:_OnNetDeserializeTransferable()
	local e = self.inst.entity
	self.cantakecontrol = e:DeserializeBoolean()
	self.cantakecontrolbyknockdown = e:DeserializeBoolean()
	self.cantakecontrolbyknockback = e:DeserializeBoolean()

	local has_registry_data = SGRegistry:HasData(self.sg.name)
	if not has_registry_data then
		self.remote_knockdown_idle = e:DeserializeBoolean()
		self.remote_hit = e:DeserializeBoolean()
		self.remote_dead = e:DeserializeBoolean()
	else
		-- shim to derive from remote state when sg registry data is available
		self.remote_knockdown_idle = self:HasStateTag("knockdown") and not self:HasStateTag("getup")
		self.remote_hit = self:HasStateTag("hit")
		self.remote_dead = self.remote_state == "dead" or self.remote_state == "death"
	end

	self.remote_attack_hold = e:DeserializeBoolean()
	if self.remote_attack_hold then
		self.remote_attack_hold_ticks = e:DeserializeUInt(TimeoutTicksNrBits)
		self.remote_attack_hold_id = e:DeserializeString()
	else
		self.remote_attack_hold = nil
		self.remote_attack_hold_ticks = nil
		self.remote_attack_hold_id = nil
	end
end


function StateGraphInstance:OnNetSerialize()
	local e = self.inst.entity

	if self.inst:IsTransferable() then
		self:_OnNetSerializeTransferable()
	end

	if self.mem.idlesize then
		e:SerializeBoolean(true)
		e:SerializeDouble(self.mem.idlesize, 16, 0, 100)
	else
		e:SerializeBoolean(false)
	end

	local has_registry_data = SGRegistry:HasData(self.sg.name)
	if has_registry_data then
		-- serialize SGRegistry-based remote state data
		local stateid = SGRegistry:GetStateID(self.sg.name, self:GetCurrentState()) or 0
		local stateid_nrbits = SGRegistry:GetStateNrBits(self.sg.name)
		assert(stateid_nrbits > 0, "SGRegistry nr bits is invalid for %s", self.sg.name)

		if SGRegistry:HasHint(self.sg.name, StateGraphRegistry.Hints.SerializeMetadata) then
			e:SerializeString(self.sg.name)
			e:SerializeUInt(stateid_nrbits, 6)
		end

		e:SerializeUInt(stateid, stateid_nrbits)	-- current state

		SGRegistry:SerializeStateTags(e, self.tags)
		if SGRegistry:HasHint(self.sg.name, StateGraphRegistry.Hints.SerializeTicksInState) then
			e:SerializeUInt(math.clamp(self.ticksinstate, 0, 1023), 10)
		end
	else
		-- TODO: networking2022, legacy support, transition to SGRegistry?
		e:SerializeBoolean(self:HasStateTag("block"))
		e:SerializeBoolean(self:HasStateTag("notarget"))
		e:SerializeBoolean(self:HasStateTag("death"))
	end
end

function StateGraphInstance:OnNetDeserialize()
	local e = self.inst.entity
	if e:IsTransferable() then
		self:_OnNetDeserializeTransferable()
	else
		self.cantakecontrol = false
	end

	if e:DeserializeBoolean() then
		self.mem.idlesize = e:DeserializeDouble(16, 0, 100)
	end

	local has_registry_data = SGRegistry:HasData(self.sg.name)
	if has_registry_data then
		local sg_name = self.sg.name
		local stateid_nrbits
		if SGRegistry:HasHint(self.sg.name, StateGraphRegistry.Hints.SerializeMetadata) then
			sg_name = e:DeserializeString()
			stateid_nrbits = e:DeserializeUInt(6)
		else
			stateid_nrbits = SGRegistry:GetStateNrBits(sg_name)
		end

		-- deserialize SGRegistry-based remote state data
		local state_id = e:DeserializeUInt(stateid_nrbits)

		SGRegistry:DeserializeStateTags(e, self.tags)

		if SGRegistry:HasHint(self.sg.name, StateGraphRegistry.Hints.SerializeTicksInState) then
			self.remote_ticksinstate = e:DeserializeUInt(10)
		end
		if SGRegistry:HasData(sg_name) then
			self.remote_state = SGRegistry:GetStateName(sg_name, state_id) or "Unknown"
		end


		if sg_name ~= self.sg.name then
			TheLog.ch.StateGraph:printf("Warning: Received stale stategraph registry data.  Discarding...")
			self.remote_state = nil
			self.remote_ticksinstate = nil
			lume.clear(self.tags)
		end
	else
		if e:DeserializeBoolean() then
			self:AddStateTag("block")
		else
			self:RemoveStateTag("block")
		end
		if e:DeserializeBoolean() then
			self:AddStateTag("notarget")
		else
			self:RemoveStateTag("notarget")
		end
		if e:DeserializeBoolean() then
			self:AddStateTag("death")
		else
			self:RemoveStateTag("death")
		end
	end
end

function StateGraphInstance:PreparePauseToRemoteState()
	-- Explicit cleanup of tags prior to pause for loss of ownership
	for k,_ in pairs(self.tags) do
		self:RemoveStateTag(k)
	end
end

function StateGraphInstance:PredictResumeFromRemoteState()
	-- If we're already dead, don't go into any state!
	if not self.remote_dead and self.inst.components.health and (self.inst.components.health:GetCurrent() <= 0 or not self.inst:IsAlive()) then
		TheLog.ch.Stategraph:printf("Warning! Took control over & resumed on a dead entity!")
		TheLog.ch.Stategraph:printf("GUID %d", self.inst.GUID or 0)
		TheLog.ch.Stategraph:printf("EntityID %d", self.inst.Network:GetEntityID() or 0)
		if self.inst.components.health then
			TheLog.ch.Stategraph:printf("Status: %d", self.inst.components.health.status)
			TheLog.ch.Stategraph:printf("Health: %d",  self.inst.components.health:GetCurrent())
		end
		TheLog.ch.Stategraph:printf("Hitbox Enabled: %s", self.inst.HitBox:IsEnabled())
		TheLog.ch.Stategraph:printf("In Limbo: %s", self.inst:IsInLimbo())
		TheLog.ch.Stategraph:printf("Last State: %s", self.inst.sg.laststate and self.inst.sg.laststate.name or "")
		TheLog.ch.Stategraph:printf("Current State: %s", self.inst.sg:GetCurrentState() or "")
		return nil
	end

	if self.sg.fns.OnResumeFromRemote then
		local resume_state, allow_empty_state = self.sg.fns.OnResumeFromRemote(self)
		if resume_state or allow_empty_state then
			return resume_state
		end
	end

	-- try to resume into a reasonable state based on some remote hints
	if self.remote_dead and self:HasState("dead") then -- Only applicable to props
		return "dead"
	elseif self.remote_knockdown_idle and self:HasState("knockdown_idle") then
		return "knockdown_idle"
	elseif self.remote_hit then
		if self:HasState("hit_pst") then
			return "hit_pst" -- include front or back bool as params?  Can derive from local facing
		elseif self:HasState("hit_actual") then
			return "hit_actual"
		end

	elseif self.remote_attack_hold and self.remote_attack_hold_id then
		local hold_state = self.remote_attack_hold_id.."_hold"
		if self:HasState(hold_state) then
			return hold_state
		else
			-- TODO: jambell - how did we get here lolol. Just let it fail out to the default state.
		end
	end

	if self.sg.defaultstate and self:GetCurrentState() ~= self.sg.defaultstate then
		return self.sg.defaultstate -- assumed to be idle
	end

	return nil
end

function StateGraphInstance:GetResumeTakeControlHint()
	return self.resume_takecontrol_hint
end

function StateGraphInstance:ClearResumeFromRemoteHints()
	self.remote_knockdown_idle = nil
	self.remote_hit = nil
	self.remote_dead = nil

	self.remote_attack_hold = nil
	self.remote_attack_hold_id = nil
	self.remote_attack_hold_ticks = nil

	self.remote_state = nil
	self.remote_ticksinstate = nil

	self.resume_takecontrol_hint = nil
end
