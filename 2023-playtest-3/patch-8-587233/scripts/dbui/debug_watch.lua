local DebugAnimHistory = require "dbui.debug_animhistory"
local DebugEntity = require "dbui.debug_entity"
local DebugNodes = require "dbui.debug_nodes"
require "constants"

local DebugWatchList = Class(DebugNodes.DebugNode, function(self, locals_list)
	DebugNodes.DebugNode._ctor(self, "Debug Watch List")
	self.locals_list = locals_list
end)

function DebugWatchList:RenderPanel( ui, node )
	ui:Text("NOTE: The is a shallow copy of local data at this time slice.\nWe do not deep copy the table data so digging into tables may not reflect the state when the value changed.")
	for i, locals in ipairs(self.locals_list) do
		if ui:CollapsingHeader( string.format("%s###%s%d", locals.line, locals.line, i) ) then
			node:AppendKeyValues(ui, locals.values)
		end
	end
end


local DebugWatch = Class(DebugNodes.DebugNode, function(self)
	DebugNodes.DebugNode._ctor(self, "Debug Watch")
end)

local shallowcompare = function(a, b)
	return a == b
end

DebugWatch.PANEL_WIDTH = 720
DebugWatch.PANEL_HEIGHT = 300
DebugWatch.watch_table = {}
DebugWatch.min_tick = 0
DebugWatch.max_tick = 0
DebugWatch.sim_tick_selected = 0
DebugWatch.animhistory = DebugAnimHistory(100)
DebugWatch.compare_fn = shallowcompare

local MAX_HISTORY = 20
local DEFAULT_MAX_DEPTH = 1

local record_value = function( v, depth )
	depth = depth or 0
	if EntityScript.is_instance(v) then
		-- Don't dig deep inside entities.
		depth = 0
	end
	if type(v) == "table" and depth > 0 then
		return deepcopy(v)
	end

	return v
end

local locals = function(level)
    local variables = {}
    local idx = 1
    while true do
        local ln, lv = debug.getlocal(level, idx)
        if ln ~= nil then
            variables[ln] = lv
        else
            break
        end
        idx = 1 + idx
    end
    return variables
end

function deepcompare_with_maxdepth(a, b, max_depth)
	if type(a) ~= type(b) then
		return false
	end

	if type(a) == "table" then
		for k, v in pairs(a) do
			if max_depth == 0 then
				return true
			elseif not deepcompare_with_maxdepth(v, b[k], max_depth-1) then
				return false
			end
		end

		for k, v in pairs(b) do
			if a[k] == nil then
				return false
			end
		end

		return true
	else
		return a == b
	end
end

local update_ticks = function()
	--push the selected tick forward if we're at head
	if DebugWatch.sim_tick_selected == DebugWatch.max_tick then
		DebugWatch.sim_tick_selected = TheSim:GetTick()
	end

	DebugWatch.min_tick = TheSim:GetTick()
	DebugWatch.max_tick = TheSim:GetTick()

	--determine the min tick
	for k, v in pairs(DebugWatch.watch_table) do
		if v.history[1].sim_tick < DebugWatch.min_tick then
			DebugWatch.min_tick = v.history[1].sim_tick
		end
	end

	--record the anim state at this tick
	DebugWatch.animhistory:RecordState(TheSim:GetTick())
end

local getlocals = function()
	local locals_tbl = {}
	local start = 4
	local count = start
    while debug.getinfo(count) do
            count = count + 1
    end
	for i = start, count do
		local locals = {
			line = debugstack_oneline(i),
			values = locals(i)
		}
		table.insert( locals_tbl, locals )
	end

	return locals_tbl
end

local watch_hook = function()
	local changed = false
	for k, v in pairs(DebugWatch.watch_table) do
		local new_val = rawget(v.parent,v.key)
		--every line of code, let's check if any of our watch values have changed
		if not DebugWatch.compare_fn(v.value, new_val) and (v.condition_fn == nil or v.condition_fn(v.value, new_val)) then
			local last_stack = debugstack_oneline(3)
			last_stack = last_stack:gsub(".*/", "")

			table.insert(v.history,
			{
				sim_tick = TheSim:GetTick(),
				value = record_value(new_val, v.max_depth),
				last_stack = last_stack,
				last_stack_full = debugstack(),
				locals_list = getlocals(),
			})

			if v.pause_when_changed then
				if not TheSim:IsDebugPaused() then
					local str = string.format("PAUSING GAME: Watch value for '%s' changed from '%s' to '%s'", v.key, tostring(v.value), tostring(new_val))
					if v.entity then
						str = string.format("%s (%s)", str, tostring(v.entity))
					end
					print(str)
					TheSim:ToggleDebugPause()
				end
			end

			v.value = record_value(new_val, v.max_depth)

			if #v.history > MAX_HISTORY then
				table.remove(v.history, 1)
			end
			v.history_index = #v.history

			changed = true
		end
	end

	if changed then
		--something has changed this tick, so do some updates
		update_ticks()
	end
end

function DebugWatch:OnDeactivate(panel)
	self.animhistory:ShutdownTracker()
end

function DebugWatch:SetTick(new_tick)
	DebugWatch.sim_tick_selected = new_tick

	for k, v in pairs(DebugWatch.watch_table) do
		v.history_index = #v.history
		for i, history_val in ipairs(v.history) do
			if history_val.sim_tick <= new_tick then
				v.history_index = i
			end
		end
	end

	DebugWatch.animhistory:PlayState(DebugWatch.sim_tick_selected)
end

function DebugWatch:RenderPanel( ui, node )

	if ui:TreeNode("Help") then
		ui:Text("To watch a variable do either of the following:")
		ui:Text("1. Call d_watch( key, parent_table, [optional entity], [optional table depth search])")
		ui:Text("2. Use the Imgui debug windows and click 'watch' when viewing a table")
		ui:TreePop()
	end

	local cmp_tables_changed, cmp_tables = ui:Checkbox("Compare Tables", DebugWatch.compare_fn ~= shallowcompare)
	if cmp_tables_changed then
		DebugWatch.compare_fn = cmp_tables and deepcompare_with_maxdepth or shallowcompare
	end
	if ui:IsItemHovered() then
		ui:SetTooltip("Watch whether the contents of watched tables has changed.\nNote that this may slow down your game significantly.")
	end

	local changed, new_tick = ui:SliderInt("Sim Tick", DebugWatch.sim_tick_selected, DebugWatch.min_tick, DebugWatch.max_tick)
	if changed then
		self:SetTick(new_tick)
	end

	ui:SameLineWithSpace()
	if ui:Button(TheSim:IsDebugPaused() and "Unpause" or "Pause") then
		if TheSim:IsDebugPaused() then
			DebugWatch.animhistory:ResumeState()
		end
		TheSim:ToggleDebugPause()
		DebugWatch.sim_tick_selected = DebugWatch.max_tick
	end

	ui:Columns( 7, "watchvalues", true )

	local unwatch_offset = 80
	local entity_offset = 60
	local key_offset = 80
	local val_offset = 120
	local tick_offset = 80
	local history_offset = 120
	ui:SetColumnOffset(1, unwatch_offset)
	ui:SetColumnOffset(2, unwatch_offset + entity_offset)
	ui:SetColumnOffset(3, unwatch_offset + entity_offset + key_offset)
	ui:SetColumnOffset(4, unwatch_offset + entity_offset + key_offset + val_offset)
	ui:SetColumnOffset(5, unwatch_offset + entity_offset + key_offset + val_offset + tick_offset)
	ui:SetColumnOffset(6, unwatch_offset + entity_offset + key_offset + val_offset + tick_offset + history_offset)

	ui:NextColumn()

	ui:Text("Entity")
	ui:NextColumn()

	ui:Text("Key")
	ui:NextColumn()

	ui:Text("Value")
	ui:NextColumn()

	ui:Text("Sim Tick")
	ui:NextColumn()

	ui:Text("History")
	ui:NextColumn()

	ui:Text("Changed By")
	ui:NextColumn()

	ui:Separator()

	for k, v in pairs(DebugWatch.watch_table) do

		if v.history[1].sim_tick <= DebugWatch.sim_tick_selected then

			local id = tostring(v.key)..tostring(v.parent)

			local history_val = v.history[ v.history_index ]

			if ui:Button(ui.icon.remove .."###unwatch_"..id) then
				DebugNodes.DebugWatch.ToggleWatch(v.key, v.parent)
			end
			if ui:IsItemHovered() then
				ui:SetTooltip("unwatch")
			end

			ui:SameLineWithSpace(5)
			local pause_changed, pause_new_val = ui:Checkbox("###pause_when_changed_"..id, v.pause_when_changed)
			if pause_changed then
				v.pause_when_changed = pause_new_val
			end
			if ui:IsItemHovered() then
				ui:SetTooltip("Pause simulation if this value changes")
			end

			ui:SameLineWithSpace(5)
			if ui:Button("?###locals_"..id) then
				node:PushNode( DebugWatchList(history_val.locals_list) )
			end

			if ui:IsItemHovered() then
				ui:SetTooltip("View locals")
			end

			ui:NextColumn()

			if v.entity then
				if ui:Button( string.format("%d", v.entity.GUID) ) then
					node:PushNode( DebugEntity(v.entity) )
				end
				if ui:IsItemHovered() then
					ui:SetTooltip(tostring(v.entity))
				end
			else
				ui:Text("N/A")
			end

			ui:NextColumn()

			ui:Text(v.key)
			if ui:IsItemHovered() then
				ui:SetTooltip( string.format("Key: %s\nParent: %s", v.key, tostring(v.parent) ) )
			end

			ui:NextColumn()

			if type(history_val.value) ~= "table" then
				--allow edit of the current value
				if v.history_index == #v.history then
					node:AppendValue( ui, history_val.value, v.parent, v.key )
				else
					ui:Text(history_val.value)
				end
			else
				if ui:Button( tostring(history_val.value) ) then
					if v.history_index == #v.history then
						--push the current one so you can edit it
						node:PushDebugValue( v.value )
					else
						node:PushDebugValue( history_val.value )
					end
				end
			end

			if ui:IsItemHovered() then
				if type(history_val.value) == "table" then
					ui:SetTooltip( string.format("Value: %s\nMax Depth:%d", tostring(history_val.value), v.max_depth) )
				else
					ui:SetTooltip( tostring(history_val.value) )
				end
			end

			ui:NextColumn()

			ui:Text( string.format("%d", history_val.sim_tick) )

			ui:NextColumn()

			ui:PushItemWidth(history_offset-15)
			local changed, new_index = ui:SliderInt( "##history_"..id, v.history_index, 1, #v.history)
			if changed then
				v.history_index = new_index
				self:SetTick(v.history[ v.history_index ].sim_tick)
			end
			ui:PopItemWidth()

			ui:NextColumn()

			if ui:Button(ui.icon.copy .."##stack_"..id) then
				ui:SetClipboardText(history_val.last_stack_full)
			end
			ui:SameLineWithSpace()
			ui:Text(history_val.last_stack)
			if ui:IsItemHovered() then
				ui:SetTooltip(history_val.last_stack_full)
			end

			ui:NextColumn()
		end
	end
	ui:Columns(1)
end

DebugWatch.IsWatching = function( key, tbl )
	for k, v in pairs(DebugWatch.watch_table) do
		local watch = v
		if watch.parent == tbl and watch.key == key then
			return k
		end
	end

	return
end

local function OnHotReload(is_pre_hot_reload)
	if is_pre_hot_reload then
		DebugWatch._RemoveAllWatches()
		-- Could we restart watches after reload completes?
	end
end

function DebugWatch._EnableWatches()
	if not DebugWatch.hot_reload_callback then
		DebugWatch.hot_reload_callback = RegisterHotReloadCallback(OnHotReload)
		debug.sethook(watch_hook, 'l')
	end
end

function DebugWatch._RemoveAllWatches()
	if DebugWatch.hot_reload_callback then
		UnregisterHotReloadCallback(DebugWatch.hot_reload_callback)
		DebugWatch.hot_reload_callback = nil

		debug.sethook(nil)
		DebugWatch.animhistory:Reset()
	end
end


DebugWatch.ToggleWatch = function( key, tbl, entity, max_depth, condition_fn )
	local watch_key = DebugNodes.DebugWatch.IsWatching( key, tbl )
	if watch_key then
		table.remove(DebugWatch.watch_table, watch_key)

		--if no more watches, clean up
		if table.numkeys(DebugWatch.watch_table) == 0 then
			DebugWatch._RemoveAllWatches()
		end
	else
		--first watch, set up hook
		if table.numkeys(DebugWatch.watch_table) == 0 then
			DebugWatch._EnableWatches()
			local panel = TheFrontEnd:FindOpenDebugPanel(DebugWatch)
			if not panel then
				TheFrontEnd:CreateDebugPanel(DebugWatch())
			end
		end

		max_depth = max_depth ~= nil and max_depth or DEFAULT_MAX_DEPTH
		--fill in details of this watch
		table.insert(DebugWatch.watch_table, {
			max_depth = max_depth,
			entity = entity,
			pause_when_changed = false,
			parent = tbl,
			key = key,
			value = record_value( rawget(tbl,key), max_depth ),
			history = {
				{
					sim_tick = TheSim:GetTick(),
					value = record_value( rawget(tbl,key) ),
					last_stack = "N/A",
					last_stack_full = "No change in this value since watch began",
					locals_list = getlocals()
				}
			},
			history_index = 1,
			condition_fn = condition_fn,
		})

		update_ticks()
	end
end

DebugNodes.DebugWatch = DebugWatch

return DebugWatch
