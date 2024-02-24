local DebugEntity = require "dbui.debug_entity"
local DebugNodes = require "dbui.debug_nodes"
local DebugSettings = require "debug.inspectors.debugsettings"
local SaveAlert = require "debug.inspectors.savealert"
local iterator = require "util.iterator"
local lume = require "util.lume"
local strict = require "util.strict"

-------------------------------------------------
-- Renders a debug panel with immediate mode GUI.
--
-- This is port of some features from DST with DebugNodes.
-- Reference it to add more functionality here.

local next_uid = 1

local DebugPanel = Class(function(self, node)

	self.show = true
	self.nodes = {} -- stack of debug nodes
	self.idx = 0 -- Current index into self.nodes

	self.uid = next_uid
	next_uid = next_uid + 1

	if node then
		self:PushNode(node)
	end
	--self:StartFrame()

	self.isSelected = false
	self.ui = nil

	-- To force maximize from customcommands:
	--   local editor, panel = DebugNodes.ParticleEditor:FindOrCreateEditor()
	--   panel.layout_options:Set("current_maximize", panel.maximize.modes.left) -- set default
	--   panel.did_maximize = true -- trigger maximixe
	self.layout_options = DebugSettings("debugpanel.layout_options")
		:Option("current_maximize", self.maximize.modes.full)

	self.saveAlert = SaveAlert()
end)

DebugPanel.can_listen_to_ctrl = true


local default_netdisplay = {
	display = function(ui, panel, v)
		ui:Text(tostring(v:value()))
	end,
}

DebugPanel.USERDATA_REGISTRY = {
	net_ushortint = {
		display = function(ui, panel, v)
			local changed, new_v = ui:DragInt("##"..tostring(v), v:value() )
			if changed and new_v ~= v:value() then
				v:set(new_v)
			end
		end,
	},

	net_entity = {
		display = function(ui, panel, v)
			if ui:Button(tostring(v:value())) then
				panel:PushNode(DebugEntity(v:value()))
			end
		end,
	},
}

DebugPanel.maximize = {
	values = { -- for order and count
		"full",
		"left",
		"right",
	},
}
DebugPanel.maximize.modes = lume.invert(DebugPanel.maximize.values) -- map name to int id


local function GetDebuggerNodeClass(t)
	if not strict.is_strict(t)
		and t.DebugNodeName
	then
		return DebugNodes[t.DebugNodeName], t.CanUseDebugNodeOnClass
	end
end


-- You must call StartFrame before other functions!
function DebugPanel:StartFrame()
	-- For ensuring ID uniqueness of different widgets with the same values.
	self.frame_uid = self.uid * 1000
end

function DebugPanel:WantsToClose()
	return not self.show
end

function DebugPanel:GetNode()
	return self.nodes[self.idx]
end

function DebugPanel:OnClose()
	local node = self:GetNode()
	if node then
		if node.OnDeactivate then
			node:OnDeactivate(self)
		else
			-- This check is to catch programmer error. If you hit this and
			-- need OnClose, remove it.
			assert(node.OnClose == nil, "Nodes should implement OnDeactivate instead of OnClose. (panels are closed, nodes are deactivated.)")
		end
	end
end

function DebugPanel:OnSelected(ui)
	self.isSelected = true
end

function DebugPanel:OnUnselected(ui)
	self.isSelected = false
end

function DebugPanel:RenderPanel(ui, panelID, dt)

	self.frame_uid = 0 -- For ensuring ID uniqueness of different widgets with the same values.
	self.ui = ui
	--self:StartFrame()

	local node = self:GetNode()
	if node ~= self.last_node then
		if self.last_node and self.last_node.OnDeactivate then
			self.last_node:OnDeactivate()
		end

		self.last_node = node

		if node and node.OnActivate then
			node:OnActivate(self)
		end
	end

	local flags = ui.WindowFlags.MenuBar
	local isDirty = node.IsDirty and node:IsDirty()
	local dirtyText = isDirty and "   *** Changes Detected! ***" or ""

	local title = string.format("%s (%d/%d) %s###%d", node:GetName(), self.idx, #self.nodes, dirtyText, self.uid)

	if self.is_maximized then
		flags = flags + ui.WindowFlags.NoTitleBar + ui.WindowFlags.NoResize + ui.WindowFlags.NoMove
		local w, h = TheSim:GetWindowSize()
		w = w / TheFrontEnd.imgui_font_size
		h = h / TheFrontEnd.imgui_font_size
		local x = 0
		if self.layout_options.current_maximize ~= DebugPanel.maximize.modes.full then
			local totalw = w
			-- using golden ratio since it does well at showing the player
			w = w * 0.381966
			if self.layout_options.current_maximize == DebugPanel.maximize.modes.right then
				x = totalw - w
			end
		end
		ui:SetNextWindowSize(w, h, ui.Cond.Always)
		ui:SetNextWindowPos(x, 0, ui.Cond.Always)

	elseif node.PANEL_AUTOSIZE then
		flags = flags and ui.WindowFlags.AlwaysAutoResize

	elseif self.set_width or self.set_height then
		ui:SetNextWindowSize(self.set_width or -1, self.set_height or -1, ui.Cond.Always)
		self.set_width, self.set_height = nil, nil
	end

	-- Make menu bar red on applicable menus if unsaved changes
	if isDirty then
		local headerColor = RGB(204, 12, 12)
		ui:PushStyleColor(ui.Col.TitleBgActive, headerColor)
		ui:PushStyleColor(ui.Col.TitleBgCollapsed, headerColor)
		ui:PushStyleColor(ui.Col.TitleBg, headerColor)
	end

	local expanded, show = ui:Begin(title, self.show, flags)
	self.show = show -- becomes false when user closes window

	-- Show the panel collapsed if the openCollapsed flag was set
	if self.openCollapsed then
		ui:SetWindowCollapsed(self.openCollapsed or false)
		self.openCollapsed = false
	end

	if isDirty then
		ui:PopStyleColor()
		ui:PopStyleColor()
		ui:PopStyleColor()
	end

	-- Trigger panel selected event if the window focus changed
	if not self.isSelected and ui:IsWindowFocused() then
		self:OnSelected()
	elseif self.isSelected and not ui:IsWindowFocused() then
		self:OnUnselected()
	end

	ui:SetDisplayScale(TheFrontEnd.imgui_font_size)

	if self.current_error then
		ui:Text(self.current_error)

	elseif self.show and expanded then
		if ui:BeginMenuBar() then
			if ui:Button(ui.icon.arrow_left, nil, nil, self.idx <= 1) then
				self:GoBack()
			end
			ui:SameLine(nil, 5)

			if ui:Button(ui.icon.arrow_right, nil, nil, self.idx >= #self.nodes) then
				self:GoForward()
			end
			ui:SameLine(nil, 20)

			self:CreateDebugMenu("Menu", MENU_KEY_BINDINGS)
			self:CreateDebugMenu("Actions", GLOBAL_KEY_BINDINGS)
			self:CreateDebugMenu("Programmer", PROGRAMMER_KEY_BINDINGS)

			if node.menu_param and ui:BeginMenu("Table") then
				ui:SetDisplayScale(TheFrontEnd.imgui_font_size)

				local v = node.menu_param
				if ui:MenuItem(string.format("set t = %s", tostring(v))) then
					rawset(_G, "t", v)
				end
				ui:EndMenu()
			end

			self:CreateDebugMenu("Windows", WINDOW_KEY_BINDINGS)
			self:CreateDebugMenu("Editors", EDITOR_KEY_BINDINGS)
			self:CreateDebugMenu("Help", HELP_KEY_BINDINGS)

			if node.MENU_BINDINGS then
				for i, menu in ipairs(node.MENU_BINDINGS) do
					local name =  menu.name or "???"
					-- Our debug menu format is different from gln's AddDebugMenu!
					self:CreateDebugMenu(name, menu.bindings)
				end
			end

			-- if node.menu_params and ui:BeginMenu( debug_menus.TABLE_BINDINGS.name ) then
			--     self:AddDebugMenu( ui, debug_menus.TABLE_BINDINGS, node.menu_params )
			--     ui:EndMenu()
			-- end

			-- for i, bindings in ipairs(TheGame:GetDebug().debug_bindings) do
			--     if ui:BeginMenu( bindings.name or "???" ) then
			--         self:AddDebugMenu( ui, bindings, node.menu_params )
			--         ui:EndMenu()
			--     end
			-- end

			ui:EndMenuBar()
		end

		if node.RenderPanel then
			local ok, result = xpcall( function() node:RenderPanel( ui, self, dt ) end, generic_error )
			if not ok then
				print(result)
				self.current_error = result
				ui:EmergencyCleanUpStackForError()
				-- Return immediately because imgui will likely assert on any
				-- kind of End() until it does ErrorCheckEndFrameRecover.
				return true
			end
		else
			ui:TextColored(RGB(255, 255, 0), "NOT YET IMPLEMENTED")
		end

		if self.did_maximize then
			-- Requested fill screen with this panel.
			self.is_maximized = not self.is_maximized
			if self.is_maximized then
				-- Keep track of original size
				self.set_width, self.set_height = ui:GetWindowSize()
			end
			self.did_maximize = false
		end
	end

	ui:End()

	if self.show_test_window then
		local ret = ui:ShowTestWindow(self.show_test_window)
		if not ret then
			self.show_test_window = false
		end
	end

	-- Check if the panel's node is dirty when closing the panel & open save alert if applicable
	if not self.show and node.IsDirty and node:IsDirty() then
		self.saveAlert:Activate(ui, node, panelID, function()
			self.show = false
		end)
		self.show = true
	elseif self.saveAlert:IsActive() then
		self.saveAlert:Render(ui)
	end

	return self.show
end

function DebugPanel:GetBindingString(name, binding)
	if type(name) == "function" then
		name = name()
	end

	assert(type(name) == "string", tostring(name).." is not a string in keybindings")

	if not binding then
		return name
	end

	local key_str = InputConstants.KeyById[binding.key]
	if binding.CTRL  then key_str = "CTRL+"..key_str end
	if binding.ALT   then key_str = "ALT+"..key_str end
	if binding.SHIFT then key_str = "SHIFT+"..key_str end

	return string.format("%s\t(%s)", name, key_str)
end

function DebugPanel:CreateDebugMenu(menu_name, bindings)
	local ui = self.ui

	if ui:BeginMenu(menu_name) then
		ui:SetDisplayScale(TheFrontEnd.imgui_font_size)
		self.isSelected = true -- When a menu item is opened, the panel loses window focus. Maintain panel selection status in this case

		for _, debug_action in pairs(bindings) do
			if debug_action.separator then
				ui:Separator()
			elseif debug_action.isDropDown then
				if debug_action.initalVal and not debug_action.did_init then
					debug_action.val = debug_action.initalVal()
					debug_action.did_init = true
				end

				debug_action.val = debug_action.val or 0
				local changed, newval = ui:Combo(debug_action.name, debug_action.val, debug_action.options)

				if changed then
					debug_action.val = newval
					if debug_action.cb then
						debug_action.cb(newval)
					end
				end

			elseif debug_action.isIntSlider then

				if debug_action.initalVal and not debug_action.did_init then
					debug_action.val = debug_action.initalVal()
					debug_action.did_init = true
				end

				debug_action.val = debug_action.val or 0

				local min = debug_action.intMin
				if type(debug_action.intMin) == "function" then
					min = debug_action.intMin()
				end

				local max = debug_action.intMax
				if type(debug_action.intMax) == "function" then
					max = debug_action.intMax()
				end

				local changed, newval = ui:SliderInt(debug_action.name, debug_action.val, min, max)

				if changed then
					debug_action.val = newval
					if debug_action.cb then
						debug_action.cb(newval)
					end
				end

			elseif debug_action.isSubMenu then
				self:CreateDebugMenu(debug_action.name, debug_action.menuItems)
			else
				local isChecked = debug_action.isChecked and debug_action.isChecked() or false
				local isDisabled = debug_action.isEnabled and not debug_action.isEnabled() or false
				if ui:MenuItem(
						self:GetBindingString(debug_action.name, debug_action.binding),
						nil,
						isChecked,
						not isDisabled)
				then
					-- Pass command name so we don't need a closure for every
					-- single action. Same table keys in DebugPanel, Quickfind,
					-- and BindKeys.
					debug_action.fn({
							name = debug_action.name,
							from_menu = true,
							panel = self,
						})
				end

				if debug_action.tooltip and ui:IsItemHovered() then
					ui:SetTooltip(debug_action.tooltip)
				end
			end
		end
		ui:EndMenu()
	end
end

function DebugPanel:RenderContextMenu(ui)
	self.frame_uid = 0 -- For ensuring ID uniqueness of different widgets with the same values.
	local node = self:GetNode()
	if node.RenderContextMenu then
		node:RenderContextMenu(ui, self)
	end
end

function DebugPanel:PushNode(node)

	if (self.open_next_in_new_panel
			or (TheInput:IsKeyDown(InputConstants.Keys.CTRL)
				and DebugPanel.can_listen_to_ctrl))
		and #self.nodes > 0
	then
		self.open_next_in_new_panel = nil
		TheFrontEnd:CreateDebugPanel(node)
		return node
	end

	-- if not is_instance( node, DebugNode ) then
	--     node = DebugUtil.CreateDebugNode( node )
	-- end

	-- Clear forward history.
	while #self.nodes > self.idx do
		table.remove(self.nodes)
	end
	table.insert(self.nodes, node)
	self.idx = #self.nodes

	self.set_width, self.set_height = node.PANEL_WIDTH, node.PANEL_HEIGHT

	return node
end

function DebugPanel:PushDebugValue(v)
	-- if is_instance( v, DebugNode ) then
	--     node = v
	-- else
	--     node = DebugUtil.CreateDebugNode( v )
	-- end
	return self:PushNode(self:CreateDebugNode(v))

	-- if TheInput:IsModifierShift() then
	--     TheGame:GetDebug():CreatePanel( node )
	-- else
	--     self:PushNode( node )
	-- end
end

function DebugPanel:GoBack()
	self.idx = self.idx - 1
	assert(self.idx >= 1)
end

function DebugPanel:GoForward()
	self.idx = self.idx + 1
	assert(self.idx <= #self.nodes)
end

----------------------------------------------------------------------
-- Helper wrappers for composite imgui rendering.

function DebugPanel:AppendTable(ui, v, name, clr)
	-- Add a Button that allows pushing a new debug node for the table.
	local to_pop = 0
	if type(v) == "table" and next(v) == nil then -- empty table
	    ui:PushStyleColor( ui.Col.Button, HexToRGB(0x214A7D66) ) -- button colour with reduced value
		to_pop = 1
	elseif clr then
	    ui:PushStyleColor( ui.Col.Button, clr )
		to_pop = 1
	end
	ui:PushID(self.frame_uid)
	if ui:Button(tostring(name or v) or "??") and v then
		self:PushDebugValue(v)
	end

	-- if ui:BeginPopupContextItem( "cxt" ) then
	--     ui:TextColored( HexToRGB(0x00FFFFFF), name or tostring(v) )

	--     ui:Separator()
	--     self:AddDebugMenu( ui, debug_menus.TABLE_BINDINGS, { v } )

	--     local debug_class = GetDebuggerNodeClass(v)
	--     if debug_class and debug_class.MENU_BINDINGS then
	--         for i, menu in ipairs( debug_class.MENU_BINDINGS ) do
	--             ui:Separator()
	--             self:AddDebugMenu( ui, menu, { v } )
	--         end
	--     end
	--     ui:EndPopup()
	-- end

	ui:PopID()
	ui:PopStyleColor(to_pop)
	self.frame_uid = self.frame_uid + 1
end

function DebugPanel:AppendTableInline(ui, t, name)
	ui:PushID(self.frame_uid)
	if ui:TreeNode(name or tostring(t)) then
		for k, v in iterator.sorted_pairs(t) do
			if type(v) == "table" then
				self:AppendTableInline(ui, v, tostring(k))
			else
				-- Key
				ui:Text(tostring(k) .. ":")
				ui:SameLine(nil, 10)
				-- Value
				if type(v) == "string" then
					ui:TextColored(RGB(117, 117, 255), v)

				elseif type(v) == "function" then
					ui:TextColored(RGB(255, 117, 85), tostring(v))

				elseif type(v) == "userdata" then
					ui:TextColored(RGB(85, 204, 186), tostring(v))

				else
					ui:Text(tostring(v))
				end
			end
		end
		ui:TreePop()
	end
	ui:PopID()
	self.frame_uid = self.frame_uid + 1
end

-- Pass owning_ arguments to allow editing.
function DebugPanel:AppendValue( ui, v, owning_table, owning_table_key )
	if type(v) == "table" then

		self:AppendTable( ui, v )

	elseif type(v) == "boolean" and owning_table and owning_table_key then

		ui:TextColored( RGB(204, 204, 255), tostring(v) )
		ui:SameLine()
		ui:Dummy(10,0)
		ui:SameLine()
		if ui:Button("Toggle".."##"..tostring(owning_table)..tostring(owning_table_key)) then
			owning_table[owning_table_key] = not v
		end

	elseif type(v) == "string" then
		ui:Text( v )

	elseif type(v) == "thread" then
		if ui:Button(tostring(v)) then
			self:PushNode(DebugNodes.DebugCoroutine(v))
		end

	elseif type(v) == "function" then
		ui:TextColored( RGB(255, 117, 85), tostring(v) )

	elseif type(v) == "userdata" then

		local userdata_name = string.match( tostring(v), "([%w_]+).*%(.*%)")
		local userdata_node = DebugPanel.USERDATA_REGISTRY[ userdata_name ]

		if userdata_node and userdata_node.display then
			userdata_node.display(ui, self, v)
		else
			ui:TextColored( RGB(85, 204, 186), tostring(v) )
		end

	elseif type(v) == "number" and owning_table and owning_table_key and v < 2^31 then
		local key = "##"..tostring(owning_table)..tostring(owning_table_key)
		local changed, new_v = ui:DragFloat(key, v)
		if changed then
			owning_table[owning_table_key] = new_v
		end
	else
		ui:Text( tostring(v) )
	end
end

function DebugPanel:AppendKeyValue( ui, key, v, t )
	-- Key
	self:AppendValue( ui, key )
	ui:NextColumn()

	-- Value
	self:AppendValue( ui, v, t, key )
	ui:NextColumn()

	local str = DebugNodes.DebugWatch.IsWatching(key, t) and "unwatch" or "watch"
	local id = "###"..tostring(key)..tostring(t)
	if ui:Button(ui.icon.copy .. id .."copy") then
		ui:SetClipboardText(v)
	end
	ui:SameLineWithSpace()
	if ui:Button(str .. id) then
		DebugNodes.DebugWatch.ToggleWatch(key, t, self:GetNode().debug_entity)
	end
	ui:NextColumn()

end

-- Ensure filter is safe to avoid crash if user inputs a % (since we evaluate
-- every frame and not when they complete their input).
local function safe_find(str, filter)
	local ok, found = pcall(function()
		return tostring(str):find(filter)
	end)
	return ok and found
end

-- We could compare any kinds of keys, so convert anything weird to string.
local function safe_cmp(a, b)
	if type(a) == "userdata"
		or type(a) == "table"
		or type(a) == "function"
		or type(a) ~= type(b)
	then
		return tostring(a) < tostring(b)
	end
	return a < b
end

function DebugPanel:AppendKeyValues(ui, t, offset, filter)
	offset = offset or 0

	ui:Columns(3, "keyvalues", false)

	local accept_all = filter == nil or filter == ""
	for k, v in iterator.sorted_pairs(t, safe_cmp) do
		if accept_all or safe_find(k, filter) then
			self:AppendKeyValue(ui, k, v, t)
		end
	end

	ui:Columns(1) -- return to normal
end

-- Draw a table with each column_headers as a column and used as a key to get
-- values out of each item in t.
--   column_headers = { 'name', 'age', ... }
--   t = { { name = "Wilson", age = 4, ... }, ... }
--   draw_fn (optional) = function(panel, ui, item_attribute, item, column_name)
--   column_widths (optional) = { 100, 100, ... }
function DebugPanel:AppendTabularKeyValues(ui, column_headers, t, draw_fn, column_widths)
	draw_fn = draw_fn or self.AppendValue
	ui:Columns(#column_headers, "tabular", true)
	for i, header in ipairs(column_headers) do
		ui:TextColored(RGB(85, 204, 273), tostring(header))
		if column_widths then
			ui:SetColumnWidth(-1, column_widths[i])
		end
		ui:NextColumn()
	end
	ui:Separator()

	for _, item in pairs(t) do
		for i, header in ipairs(column_headers) do
			draw_fn(self, ui, item[header], item, header)
			ui:NextColumn()
		end
		ui:Separator()
	end
	ui:Separator()
	ui:Columns(1)
end


function DebugPanel:AppendTabularData(ui, column_headers, data)
	ui:Columns(#column_headers, "tabular", true)
	for k, v in ipairs(column_headers) do
		ui:TextColored(RGB(85, 204, 273), tostring(v))
		ui:NextColumn()
	end
	ui:Separator()
	for k, v in ipairs(data) do
		for c = 1, #column_headers do
			if c <= #v then
				if type(v[c]) == "table" and v[c].name and v[c].table then
					self:AppendTable(ui, v[c].table, v[c].name)
				else
					ui:Text(tostring(v[c]))
				end
			end
			ui:NextColumn()
		end
	end
	ui:Separator()
	ui:Columns(1)
end


function DebugPanel:AppendBitField(ui, flags, bit_field, bit_field_strings)
	ui:PushID(self.frame_uid)
	flags = DebugUtil.RenderBitField(ui, flags, bit_field, bit_field_strings)
	ui:PopID()
	self.frame_uid = self.frame_uid + 1

	return flags
end


function DebugPanel:CreateDebugNode(v, offset)
	if v == nil then
		return DebugNodes.DebugNil()
	elseif type(v) == "function" then
		return DebugNodes.DebugCustom(v)
	elseif type(v) == "thread" then
		return DebugNodes.DebugCoroutine(v)
	elseif type(v) == "table" then
		-- Try to link this table to a specialized DebugNode.
		local class, allow_debug_node_on_class = GetDebuggerNodeClass(v)
		if class
			and (allow_debug_node_on_class or not Class.IsClass(v))
		then
			return class(v)
		end

		-- return DebugTable( v, nil, offset )
		return DebugNodes.DebugTable(v)
	else
		return DebugNodes.DebugValue(v)
	end
end

return DebugPanel
