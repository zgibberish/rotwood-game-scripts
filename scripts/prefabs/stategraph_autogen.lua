--------------------------------------------------------------------------
-- This prefab file is for loading embellishment dependencies
--------------------------------------------------------------------------

local SGAutogenData = require "prefabs.stategraph_autogen_data"
local eventfuncs = require "eventfuncs"
local iterator = require "util.iterator"


embellishutil = {}

function embellishutil.AnnotateEmbellishments(data)
	for embellishment_name,embellishment in pairs(data) do
		for i,sg in pairs(embellishment.stategraphs or {}) do
			for statename,events in pairs(sg.events or {}) do
				for i,event in pairs(events) do
					assert(event.param)
					local event_source = "Embellishment: "..embellishment_name.."\nState: "..statename.."\nFrame:"..event.frame
					if event_source ~= event.param.event_source then
						event.param.event_source = event_source
					end
				end
			end
			for statename,state in pairs(sg.state_events or {}) do
				for i,event in pairs(state) do
					assert(event.param)
					local event_source = "Embellishment: "..embellishment_name.."\nState:"..statename.."\nEvent: "..event.name
					--print("event_source:",event_source)
					if event_source ~= event.param.event_source then
						event.param.event_source = event_source
					end
				end
			end
			for i,event in pairs(sg.sg_events or {}) do
				assert(event.param)
				local event_source = "Embellishment: "..embellishment_name.."\nStateGraph Event\nEvent: "..event.name
				--print("event_source:",event_source)
				if event_source ~= event.param.event_source then
					event.param.event_source = event_source
				end
			end
		end
	end
end

function embellishutil.DeAnnotateEmbellishments(data)
	for embellishment_name,embellishment in pairs(data) do
		for i,sg in pairs(embellishment.stategraphs or {}) do
			for statename,events in pairs(sg.events or {}) do
				for i,event in pairs(events) do
					assert(event.param)
					event.param.event_source = nil
				end
			end
			for statename,state in pairs(sg.state_events or {}) do
				for i,event in pairs(state) do
					assert(event.param)
					event.param.event_source = nil
				end
			end
			for i,event in pairs(sg.sg_events or {}) do
				assert(event.param)
				event.param.event_source = nil
			end
		end
	end
end


function embellishutil.SortStateGraphEmbellishments()
	STATEGRAPH_EMBELLISHMENTS = {}
	STATEGRAPH_EMBELLISHMENTS_FINAL = {}
	for name, params in pairs(SGAutogenData) do
		--~ TheLog.ch.Embellisher:print("data:", name, params.prefab)
		local prefabs = type(params.prefab) == "table" and params.prefab or {params.prefab}
		for i,prefab in pairs(prefabs) do
			if prefab ~= "" then
				STATEGRAPH_EMBELLISHMENTS[prefab] = STATEGRAPH_EMBELLISHMENTS[prefab] or {embellishments = {}}
				table.insert(STATEGRAPH_EMBELLISHMENTS[prefab].embellishments, name)
				if params.needSoundEmitter then
					STATEGRAPH_EMBELLISHMENTS[prefab].needSoundEmitter = true
				end
				if params.isfinal then
					STATEGRAPH_EMBELLISHMENTS_FINAL[prefab] = STATEGRAPH_EMBELLISHMENTS_FINAL[prefab] or {embellishments = {}}
					table.insert(STATEGRAPH_EMBELLISHMENTS_FINAL[prefab].embellishments, name)
					if params.needSoundEmitter then
						STATEGRAPH_EMBELLISHMENTS_FINAL[prefab].needSoundEmitter = true
					end
				end
			end
		end
	end
	embellishutil.AnnotateEmbellishments(SGAutogenData)
end

function embellishutil.GetEmbellishmentForPrefab(inst)
	local embellishment = STATEGRAPH_EMBELLISHMENTS_FINAL[inst.embellisher_prefab_override or inst.prefab]
	return embellishment
end

local function AllEventsCoro()
	for embellishment,emb in pairs(SGAutogenData) do
		for sg_name,sg in pairs(emb.stategraphs or {}) do
			for tab,eventlist in pairs(sg) do
				if tab ~= "sg_events" then
					for state,data in pairs(eventlist) do
						for _,ev in ipairs(data) do
							coroutine.yield(ev, embellishment, sg_name)
						end
					end
				end
			end
			for _,ev in ipairs(sg.sg_events or {}) do
				coroutine.yield(ev, embellishment, sg_name)
			end
		end
	end
end
-- Iterates over all events in all sections of stategraph_autogen_data.
-- Each loop returns: event table, embellishment name, sg name
function embellishutil.EventIterator()
	return iterator.coroutine(AllEventsCoro)
end

function RegisterEmbellishmentDependencies(prefab)
	local def = STATEGRAPH_EMBELLISHMENTS_FINAL[prefab.name]
	if def and def.embellishments then
		for i,embellishmentname in pairs(def.embellishments) do

			local assets = {}
			local prefabs = {}

			local embellishment = SGAutogenData[embellishmentname]

			for _,stategraph in pairs(embellishment.stategraphs or {}) do
				for statename, data in pairs(stategraph.events or {}) do
					for i,v in pairs(data) do
						local eventdef = eventfuncs[v.eventtype]
						if eventdef then
							eventdef.collectassets(v.param, assets, prefabs)
						end
					end
				end
				for statename, data in pairs(stategraph.state_events or {}) do
					for i,v in pairs(data) do
						local eventdef = eventfuncs[v.eventtype]
						if eventdef then
							eventdef.collectassets(v.param, assets, prefabs)
						end
					end
				end
				for i,v in pairs(stategraph.sg_events or {}) do
					local eventdef = eventfuncs[v.eventtype]
					if eventdef then
						eventdef.collectassets(v.param, assets, prefabs)
					end
				end
			end
			if #assets > 0 then
				local prefab_assets = prefabs.assets == table.empty and {} or prefab.assets
				for i,newasset in pairs(assets) do
					local found = false
					for i,existing in pairs(prefab_assets) do
						if newasset == existing then
							found = true
							break
						end
					end
					if not found then
						table.insert(prefab_assets, newasset)
					end
				end
				prefab.assets = prefab_assets
			end
			if #prefabs > 0 then
				local prefab_deps = prefab.deps == table.empty and {} or prefab.deps
				for i,newprefab in pairs(prefabs) do
					local found = false
					for i,existing in pairs(prefab_deps) do
						if newprefab == existing then
							found = true
							break
						end
					end
					if not found then
						table.insert(prefab_deps, newprefab)
					end
				end
				prefab.deps = prefab_deps
			end
		end
	end
end

STATEGRAPH_EMBELLISHMENTS = {}
STATEGRAPH_EMBELLISHMENTS_FINAL = {}

embellishutil.SortStateGraphEmbellishments()
